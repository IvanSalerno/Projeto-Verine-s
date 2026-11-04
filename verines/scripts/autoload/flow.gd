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
const WIN_ORDERS := 10
const ORDERS_PER_DAY := 2   # pedidos concluídos para fechar o dia
const TIER2_AT := 3   # pedidos concluídos para o nível 2
const TIER3_AT := 6   # pedidos concluídos para o nível 3
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
var last_result: Dictionary = {}
var new_record: bool = false
var settings_return: GameStates.Id = GameStates.Id.MAIN_MENU

var _current_spec: Dictionary = {}
var _next_order_id: int = 1
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func say(text: String) -> void:
	notice.emit(text)

## Nível de dificuldade dos desafios (1 a 3), conforme os pedidos concluídos.
func current_tier() -> int:
	if Game.orders_completed >= TIER3_AT:
		return 3
	if Game.orders_completed >= TIER2_AT:
		return 2
	return 1

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
	go(GameStates.Id.RESTAURANT)
	say("Atendimento cancelado.")

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
	order_changed.emit()
	go(GameStates.Id.ACTIVE_ORDER)
	say("Receita identificada!")
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
	# Desafios extras conforme o nível (um ingrediente sorteado da receita).
	var tier := current_tier()
	if tier >= 2:
		var pick: Dictionary = recipe.lines[_rng.randi() % recipe.lines.size()]
		challenge_queue.append({"kind": "capacity", "ingredient_id": pick["ingredient_id"]})
	if tier >= 3:
		var pick2: Dictionary = recipe.lines[_rng.randi() % recipe.lines.size()]
		challenge_queue.append({"kind": "cost", "ingredient_id": pick2["ingredient_id"]})

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
	var ing: Ingredient = GameData.ingredients[ing_id]
	match spec["kind"]:
		"recover":
			ch = GameData.make_recovery_challenge(recipe, ing_id)
		"capacity":
			ch = ChallengeFactory.capacity(_rng, ing, line["unit"],
				Game.get_known_amount(recipe, line), recipe.base_servings)
		"cost":
			var needed := 0
			for al in adjusted.lines:
				if al["ingredient_id"] == ing_id:
					needed = int(al["base_needed"])
			ch = ChallengeFactory.order_cost(ing, needed, order.servings)
		_:
			ch = ChallengeFactory.scaling(ing, line["unit"],
				Game.get_known_amount(recipe, line), recipe.base_servings, order.servings)
	if ch == null:
		push_error("Sem desafio de recuperação para %s / %s" % [recipe.id, ing_id])
		return false
	_current_spec = spec
	begin_challenge(ch, "order")
	return true

func start_planning_challenge() -> void:
	var ch: MathChallenge = ChallengeFactory.planning(_rng, current_tier())
	begin_challenge(ch, "planning")

func start_daily_challenge() -> void:
	if Game.daily_challenge_done:
		say("O desafio de gestão de hoje já foi concluído.")
		return
	begin_challenge(ChallengeFactory.daily(_rng, current_tier(), Game.day_history), "daily")

func submit_answer(raw: Variant) -> Dictionary:
	if current_challenge == null:
		return {"ok": false, "message": ""}
	var res := current_challenge.validate(raw)
	if res["ok"]:
		var pts := (10 if current_challenge.attempts == 1 else 5) * current_challenge.tier
		Game.add_score(pts, "Desafio resolvido")
		_apply_consequence(current_challenge.consequence)
		_current_spec = {}
	elif order != null and challenge_context in ["order", "delivery"]:
		order.mistakes += 1
		res["message"] = str(res["message"]) + " (erro registrado: reduz o pagamento)"
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
		"management_bonus":
			Game.add_money(int(c["cents"]), "Bônus de gestão")
			Game.add_score(int(c["points"]), "Desafio de gestão")
			Game.daily_challenge_done = true

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
			go(GameStates.Id.KITCHEN)
		"delivery":
			go(GameStates.Id.DELIVERY)
		"planning":
			go(GameStates.Id.ADMINISTRATION)
		"daily":
			go(GameStates.Id.DAY_SUMMARY)
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
	go(GameStates.Id.KITCHEN)
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
		begin_challenge(ChallengeFactory.fraction_portion(_rng, current_tier()), "delivery")
	elif not delivery_steps_done.has("change"):
		begin_challenge(ChallengeFactory.change(_rng, delivery_bill_cents, current_tier()), "delivery")
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
	var points := 100 + 20 * current_tier() + (50 if perfect else 0)
	Game.add_score(points, "Pedido concluído")
	Game.orders_completed += 1
	Game.orders_today += 1
	var story := _on_progress()

	last_result = {
		"customer": order.customer_name,
		"base": base, "upgrade_bonus": upgrade_bonus, "bonus": bonus, "penalty": penalty,
		"total": total, "points": points, "mistakes": order.mistakes, "hints": order.hints_used, "story": story,
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
		new_record = Game.register_final_score()
		SaveSystem.delete()   # partida terminada: o save deixa de existir
		go(GameStates.Id.ENDING)
	elif Game.orders_today >= ORDERS_PER_DAY:
		go(GameStates.Id.DAY_SUMMARY)
	else:
		go(GameStates.Id.RESTAURANT)

func start_next_day() -> void:
	Game.start_next_day()
	go(GameStates.Id.RESTAURANT)
	SaveSystem.save()   # salvamento automático no início de cada dia
	say("O dia %d começou! (jogo salvo automaticamente)" % Game.day)

# =============================================================== navegação / menus
## Vai para uma página do restaurante (Salão, Cozinha ou Despensa).
func goto_place(place: int) -> void:
	match place:
		GameStates.Place.SALAO:
			if order != null and not order.is_closed():
				go(GameStates.Id.ACTIVE_ORDER)
			else:
				go(GameStates.Id.RESTAURANT)
		GameStates.Place.COZINHA:
			go(GameStates.Id.KITCHEN)
		GameStates.Place.DESPENSA:
			go(GameStates.Id.ADMINISTRATION)

func open_settings() -> void:
	if state != GameStates.Id.SETTINGS:
		settings_return = state
		go(GameStates.Id.SETTINGS)

func close_settings() -> void:
	go(settings_return)

func open_credits() -> void:
	go(GameStates.Id.CREDITS)

func close_credits() -> void:
	go(GameStates.Id.MAIN_MENU)

# ======================================================================= salvamento
## Estado "real" da partida (o livro e as configurações são telas de passagem).
func _effective_state() -> int:
	if state == GameStates.Id.RECIPE_BOOK:
		return int(return_state)
	if state == GameStates.Id.SETTINGS:
		return int(settings_return)
	return int(state)

func can_save() -> bool:
	var s := _effective_state()
	return not (s in [GameStates.Id.MAIN_MENU, GameStates.Id.INTRO, GameStates.Id.CREDITS,
		GameStates.Id.ENDING, GameStates.Id.MATH_CHALLENGE])

func save_now() -> bool:
	if not can_save():
		say("Não é possível salvar agora. Termine ou saia do desafio primeiro.")
		return false
	if SaveSystem.save():
		say("Jogo salvo (dia %d, %d pontos)." % [Game.day, Game.score])
		return true
	say("Erro ao salvar o jogo.")
	return false

func continue_game() -> void:
	if SaveSystem.load_into():
		say("Jogo carregado.")
	else:
		say("Não foi possível carregar o jogo salvo.")

func to_dict() -> Dictionary:
	return {
		"state": _effective_state(),
		"order": order.to_dict() if order != null else {},
		"dish": dish.to_dict() if dish != null else {},
		"queue": challenge_queue,
		"delivery_steps": delivery_steps_done.keys(),
		"delivery_bill": delivery_bill_cents,
		"last_result": last_result,
		"next_order_id": _next_order_id,
	}

func from_dict(d: Dictionary) -> void:
	order = null
	dish = null
	adjusted = null
	current_challenge = null
	_current_spec = {}
	var od: Dictionary = d.get("order", {})
	if not od.is_empty():
		order = Order.from_dict(od)
	var dd: Dictionary = d.get("dish", {})
	if not dd.is_empty():
		dish = Dish.from_dict(dd)
	challenge_queue.clear()
	for q in d.get("queue", []):
		challenge_queue.append({"kind": str(q["kind"]), "ingredient_id": str(q["ingredient_id"])})
	delivery_steps_done.clear()
	for s in d.get("delivery_steps", []):
		delivery_steps_done[str(s)] = true
	delivery_bill_cents = int(d.get("delivery_bill", 0))
	last_result = _clean_result(d.get("last_result", {}))
	_next_order_id = int(d.get("next_order_id", 1))
	if order != null and order.selected_recipe_id != "" and GameData.recipes.has(order.selected_recipe_id):
		adjusted = AdjustedRecipe.build(GameData.recipes[order.selected_recipe_id], order.servings, Game.recovered)
	var target := _safe_state(int(d.get("state", GameStates.Id.RESTAURANT)))
	return_state = GameStates.Id.RESTAURANT
	go(target)

func _clean_result(r: Dictionary) -> Dictionary:
	if r.is_empty():
		return {}
	var out := {"customer": str(r.get("customer", "")), "story": str(r.get("story", ""))}
	for k in ["base", "upgrade_bonus", "bonus", "penalty", "total", "points", "mistakes", "hints"]:
		out[k] = int(r.get(k, 0))
	return out

## Garante que o estado carregado é coerente com os dados (pedido, prato, resultado).
func _safe_state(s: int) -> GameStates.Id:
	var has_order := order != null and not order.is_closed()
	match s:
		GameStates.Id.ACTIVE_ORDER, GameStates.Id.INVESTIGATION:
			return s as GameStates.Id if has_order else GameStates.Id.RESTAURANT
		GameStates.Id.DELIVERY:
			if has_order and dish != null and dish.state == Dish.State.READY:
				return GameStates.Id.DELIVERY
			return GameStates.Id.ACTIVE_ORDER if has_order else GameStates.Id.RESTAURANT
		GameStates.Id.RESULT:
			return GameStates.Id.RESULT if not last_result.is_empty() else GameStates.Id.RESTAURANT
		GameStates.Id.KITCHEN, GameStates.Id.ADMINISTRATION, GameStates.Id.DAY_SUMMARY, GameStates.Id.RESTAURANT:
			return s as GameStates.Id
	return GameStates.Id.RESTAURANT
