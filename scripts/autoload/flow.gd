extends Node
## Máquina de estados e regras do atendimento (autoload "Flow").
## Controla: pedidos, investigação, desafios, preparo, entrega, pagamento e progressão.

signal state_changed(new_state: int)
signal order_changed
signal dish_changed
signal challenge_started(challenge: MathChallenge)
signal challenge_finished(ok: bool, message: String)
signal notice(text: String)

# Balanceamento (valores provisórios — ajustar nos testes).
const WIN_ORDERS := 8
const BONUS_NO_MISTAKE_PERCENT := 10.0
const PENALTY_MISTAKE_PERCENT := 5.0
const PENALTY_HINT_PERCENT := 3.0
const MAX_PENALTY_PERCENT := 40.0
const UNLOCK_PUDIM_AT := 3

var state: GameStates.Id = GameStates.Id.MAIN_MENU
var return_state: GameStates.Id = GameStates.Id.RESTAURANT

var order: Order = null
var adjusted: AdjustedRecipe = null
var dish: Dish = null

var current_challenge: MathChallenge = null
var challenge_context: String = ""            # "order" | "delivery" | "planning"
var challenge_queue: Array[Dictionary] = []   # {kind: "recover"|"scale", ingredient_id}
var delivery_steps_done: Dictionary = {}
var delivery_bill_cents: int = 0
var delivery_given_cents: int = 0
var last_result: Dictionary = {}

var _current_spec: Dictionary = {}
var _next_order_id: int = 1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func say(text: String) -> void:
	notice.emit(text)

func go(new_state: GameStates.Id) -> void:
	state = new_state
	state_changed.emit(new_state)

# ------------------------------------------------------------------ menu / intro
func start_game() -> void:
	Game.new_game()
	order = null
	adjusted = null
	dish = null
	current_challenge = null
	challenge_queue.clear()
	delivery_steps_done.clear()
	last_result = {}
	_next_order_id = 1
	go(GameStates.Id.INTRO)

func finish_intro() -> void:
	go(GameStates.Id.RESTAURANT)

func open_admin() -> void:
	go(GameStates.Id.ADMINISTRATION)

func open_book() -> void:
	if state == GameStates.Id.RECIPE_BOOK:
		return
	return_state = state
	go(GameStates.Id.RECIPE_BOOK)

func close_book() -> void:
	go(return_state)

# ---------------------------------------------------------------------- pedidos
func call_next_customer() -> bool:
	if order != null and not order.is_closed():
		say("Termine ou cancele o atendimento atual primeiro.")
		return false
	var tpl := _pick_template()
	if tpl.is_empty():
		return false
	order = _create_order(tpl)
	adjusted = null
	dish = null
	challenge_queue.clear()
	order_changed.emit()
	go(GameStates.Id.ACTIVE_ORDER)
	return true

func _pick_template() -> Dictionary:
	var pool: Array[Dictionary] = []
	for t in GameData.order_templates:
		if t.get("tutorial", false):
			if Game.orders_completed == 0:
				return t
			continue
		if int(t.get("min_completed", 0)) <= Game.orders_completed:
			pool.append(t)
	if pool.is_empty():
		return {}
	return pool[_rng.randi() % pool.size()]

func _create_order(tpl: Dictionary) -> Order:
	var o := Order.new()
	o.id = _next_order_id
	_next_order_id += 1
	o.customer_name = tpl["customer"]
	o.kind = tpl["kind"]
	o.description = tpl["text"]
	o.correct_recipe_id = tpl["recipe_id"]
	o.servings = tpl["servings"]
	o.clue_ids.assign(tpl.get("clues", []))
	o.hidden_clue_ids.assign(tpl.get("hidden_clues", []))
	o.restrictions.assign(tpl.get("restrictions", []))
	var recipe: Recipe = GameData.recipes[o.correct_recipe_id]
	o.base_reward_cents = recipe.price_per_serving_cents * o.servings
	return o

func cancel_order() -> void:
	if order == null or order.is_closed():
		return
	order.transition(Order.State.CANCELLED)
	dish = null
	adjusted = null
	challenge_queue.clear()
	order_changed.emit()
	say("Atendimento cancelado.")
	go(GameStates.Id.RESTAURANT)

# ------------------------------------------------------------------ investigação
func open_investigation() -> void:
	if order == null:
		return
	if order.state == Order.State.CREATED:
		order.transition(Order.State.INVESTIGATING)
	go(GameStates.Id.INVESTIGATION)

func reveal_hint() -> void:
	if order == null or order.state != Order.State.INVESTIGATING:
		return
	if order.hints_used >= order.hidden_clue_ids.size():
		say("Não há mais pistas disponíveis.")
		return
	order.hints_used += 1
	order_changed.emit()
	say("Pista extra revelada (penalidade no pagamento).")

func select_recipe(recipe_id: String) -> bool:
	if order == null or order.state != Order.State.INVESTIGATING:
		return false
	if not Game.is_recipe_unlocked(recipe_id):
		return false
	if recipe_id != order.correct_recipe_id:
		order.mistakes += 1
		say("Essa não parece ser a receita pedida. Releia as pistas e compare com o livro.")
		return false
	order.selected_recipe_id = recipe_id
	order.transition(Order.State.IDENTIFIED)
	_build_adjusted()
	say("Receita identificada!")
	order_changed.emit()
	go(GameStates.Id.ACTIVE_ORDER)
	return true

func _build_adjusted() -> void:
	var recipe: Recipe = GameData.recipes[order.selected_recipe_id]
	adjusted = AdjustedRecipe.build(recipe, order.servings, Game.recovered)
	challenge_queue.clear()
	for line in recipe.lines:
		if not Game.is_line_known(recipe, line):
			challenge_queue.append({"kind": "recover", "ingredient_id": line["ingredient_id"]})
	if order.servings != recipe.base_servings:
		for line in recipe.lines:
			challenge_queue.append({"kind": "scale", "ingredient_id": line["ingredient_id"]})

func is_ready_to_cook() -> bool:
	return order != null and order.state == Order.State.IDENTIFIED \
		and challenge_queue.is_empty() and adjusted != null and adjusted.is_complete()

# ----------------------------------------------------------------------- desafios
func begin_challenge(ch: MathChallenge, context: String) -> void:
	current_challenge = ch
	challenge_context = context
	go(GameStates.Id.MATH_CHALLENGE)
	challenge_started.emit(ch)

func next_order_challenge() -> bool:
	if challenge_queue.is_empty() or adjusted == null or order == null:
		return false
	var spec: Dictionary = challenge_queue.pop_front()
	var recipe: Recipe = GameData.recipes[adjusted.recipe_id]
	var ing_id: String = spec["ingredient_id"]
	var line := recipe.get_line(ing_id)
	var ch: MathChallenge = null
	if spec["kind"] == "recover":
		ch = GameData.make_recovery_challenge(recipe, ing_id)
	else:
		ch = ChallengeFactory.scaling(GameData.ingredients[ing_id], line["unit"],
			Game.get_known_amount(recipe, line), recipe.base_servings, order.servings)
	if ch == null:
		push_error("Sem desafio de recuperação para %s / %s" % [recipe.id, ing_id])
		return false
	_current_spec = spec
	begin_challenge(ch, "order")
	return true

func start_planning_challenge() -> void:
	var ch: MathChallenge = ChallengeFactory.rule_of_three(_rng) if _rng.randi() % 2 == 0 \
		else ChallengeFactory.cost_matrix(_rng)
	begin_challenge(ch, "planning")

func submit_answer(raw: Variant) -> Dictionary:
	if current_challenge == null:
		return {"ok": false, "message": ""}
	var res := current_challenge.validate(raw)
	if res["ok"]:
		_apply_consequence(current_challenge.consequence)
		_current_spec = {}
	elif order != null and challenge_context in ["order", "delivery"]:
		order.mistakes += 1
	challenge_finished.emit(res["ok"], res["message"])
	return res

func _apply_consequence(c: Dictionary) -> void:
	match c.get("type", ""):
		"recover_line":
			Game.recover_line(c["recipe_id"], c["ingredient_id"], float(c["amount"]))
			if adjusted != null and order != null:
				adjusted = AdjustedRecipe.build(GameData.recipes[adjusted.recipe_id], order.servings, Game.recovered)
		"scale_line":
			pass   # a fila de desafios já controla o avanço
		"delivery_step":
			delivery_steps_done[c["step"]] = true
		"purchase_discount":
			Game.next_purchase_discount_percent = float(c.get("percent", 0.0))

## Chamado pelo botão Continuar/Voltar da tela de desafio.
func leave_challenge() -> void:
	var solved := current_challenge != null and current_challenge.solved
	if not solved and not _current_spec.is_empty():
		challenge_queue.push_front(_current_spec)   # desafio não resolvido volta para a fila
	_current_spec = {}
	current_challenge = null
	order_changed.emit()
	match challenge_context:
		"order":
			go(GameStates.Id.ACTIVE_ORDER)
		"delivery":
			go(GameStates.Id.DELIVERY)
		"planning":
			go(GameStates.Id.ADMINISTRATION)
		_:
			go(GameStates.Id.RESTAURANT)

# ------------------------------------------------------------------------ preparo
func start_preparation() -> bool:
	if not is_ready_to_cook():
		say("Resolva os desafios da receita antes de cozinhar.")
		return false
	var check := Game.has_ingredients(adjusted)
	if not check["ok"]:
		say(_missing_text(check["missing"]))
		return false
	if not Game.consume_ingredients(adjusted):   # consumo único dos ingredientes
		return false
	order.transition(Order.State.PREPARING)
	var recipe: Recipe = GameData.recipes[adjusted.recipe_id]
	dish = Dish.new(recipe.id, order.servings, recipe.steps)
	dish.ingredients_consumed = true
	dish.start()
	order_changed.emit()
	dish_changed.emit()
	go(GameStates.Id.PREPARATION)
	return true

func do_prep_step() -> void:
	if dish == null or not dish.advance():
		return
	if dish.state == Dish.State.READY:
		say("Prato pronto!")
	dish_changed.emit()

func _missing_text(missing: Array) -> String:
	var parts: PackedStringArray = []
	for m in missing:
		var ing: Ingredient = GameData.ingredients[m["ingredient_id"]]
		parts.append("%s (faltam %d %s)" % [ing.display_name, int(m["missing"]), Units.label(ing.unit)])
	return "Ingredientes insuficientes: " + ", ".join(parts) + ". Compre na Administração."

# ------------------------------------------------------------------------ entrega
func start_delivery() -> bool:
	if dish == null or dish.state != Dish.State.READY:
		say("O prato ainda não está pronto.")
		return false
	delivery_steps_done.clear()
	delivery_bill_cents = order.base_reward_cents
	var given := int(ceil(delivery_bill_cents / 1000.0)) * 1000
	if given == delivery_bill_cents:
		given += 1000
	delivery_given_cents = given
	go(GameStates.Id.DELIVERY)
	return true

func delivery_next_label() -> String:
	if not delivery_steps_done.has("portion"):
		return "Dividir o prato em porções (desafio)"
	if not delivery_steps_done.has("change"):
		return "Receber o pagamento e dar o troco (desafio)"
	return "Entregar o prato"

func delivery_next() -> void:
	if not delivery_steps_done.has("portion"):
		begin_challenge(ChallengeFactory.fraction_portion(_rng), "delivery")
	elif not delivery_steps_done.has("change"):
		begin_challenge(ChallengeFactory.change(delivery_bill_cents, delivery_given_cents), "delivery")
	else:
		finalize_delivery()

## Pagamento = preço-base + bônus − penalidades (calculado uma única vez por pedido).
func finalize_delivery() -> void:
	if order == null or dish == null or dish.state != Dish.State.READY:
		return
	if order.paid:
		return
	if not (delivery_steps_done.has("portion") and delivery_steps_done.has("change")):
		return
	var correct := dish.recipe_id == order.correct_recipe_id and dish.servings == order.servings
	var base := order.base_reward_cents if correct else 0
	var upgrade_bonus := roundi(base * Game.get_effect_total("price_bonus_percent") / 100.0)
	var perfect := order.mistakes == 0 and order.hints_used == 0
	var bonus := roundi(base * BONUS_NO_MISTAKE_PERCENT / 100.0) if perfect else 0
	var penalty_pct := minf(order.mistakes * PENALTY_MISTAKE_PERCENT + order.hints_used * PENALTY_HINT_PERCENT,
		MAX_PENALTY_PERCENT)
	var penalty := roundi(base * penalty_pct / 100.0)
	var total := maxi(0, base + upgrade_bonus + bonus - penalty)

	order.paid = true
	Game.add_money(total, "Pedido #%d (%s)" % [order.id, order.customer_name])
	dish.state = Dish.State.DELIVERED
	order.transition(Order.State.COMPLETED)
	Game.orders_completed += 1
	var story := _on_progress()

	last_result = {
		"customer": order.customer_name,
		"base": base, "upgrade_bonus": upgrade_bonus, "bonus": bonus, "penalty": penalty,
		"total": total, "mistakes": order.mistakes, "hints": order.hints_used, "story": story,
	}
	dish = null
	adjusted = null
	order_changed.emit()
	go(GameStates.Id.RESULT)

func _on_progress() -> String:
	var story := GameData.note_for(Game.orders_completed)
	if Game.orders_completed >= UNLOCK_PUDIM_AT and not Game.is_recipe_unlocked("pudim_verine"):
		Game.unlock_recipe("pudim_verine")
		story += "\nNova receita desbloqueada no livro: Pudim do Verine."
	return story

func continue_after_result() -> void:
	if Game.orders_completed >= WIN_ORDERS:
		go(GameStates.Id.ENDING)
	else:
		go(GameStates.Id.RESTAURANT)
