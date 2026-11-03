extends Control
## Interface do jogo. Controle EXCLUSIVAMENTE por mouse (teclado numérico na tela).
## Todos os painéis são criados por código; basta uma cena com um Control e este script.

var _panels: Dictionary = {}          # GameStates.Id -> VBoxContainer
var _money_label: Label
var _progress_label: Label
var _book_button: Button
var _msg_label: Label

# Estado da tela de desafio
var _answer: String = ""
var _selected_choice: int = -1
var _answer_label: Label
var _hint_label: Label
var _feedback_label: Label
var _submit_button: Button
var _continue_button: Button
var _keypad: GridContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()
	Flow.state_changed.connect(_on_state_changed)
	Flow.order_changed.connect(_refresh)
	Flow.dish_changed.connect(_refresh)
	Flow.notice.connect(_on_notice)
	Game.money_changed.connect(_on_money_changed)
	Game.inventory_changed.connect(_on_inventory_changed)
	_on_state_changed(Flow.state)

# ============================================================== layout / helpers
func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	top.add_child(_label("Verine's", 26))
	_progress_label = _label("")
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_progress_label)
	_money_label = _label("")
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_money_label)
	_book_button = _button("Livro de receitas", Flow.open_book)
	top.add_child(_book_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	for id in GameStates.Id.values():
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 8)
		content.add_child(panel)
		_panels[id] = panel

	_msg_label = _label("")
	_msg_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	root.add_child(_msg_label)

func _label(text: String, font_size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	return l

func _button(text: String, callback: Callable, is_disabled: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = is_disabled
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(callback)
	return b

func _begin(id: GameStates.Id) -> VBoxContainer:
	var p: VBoxContainer = _panels[id]
	for c in p.get_children():
		p.remove_child(c)
		c.queue_free()
	return p

# ==================================================================== eventos
func _on_state_changed(s: int) -> void:
	for id in _panels:
		_panels[id].visible = (id == s)
	_book_button.visible = s in [GameStates.Id.RESTAURANT, GameStates.Id.ACTIVE_ORDER, GameStates.Id.INVESTIGATION]
	_refresh()

func _on_notice(text: String) -> void:
	_msg_label.text = text

func _on_money_changed(_balance: int) -> void:
	_update_top_bar()

func _on_inventory_changed() -> void:
	if Flow.state == GameStates.Id.ADMINISTRATION:
		_refresh()

func _update_top_bar() -> void:
	_money_label.text = "Saldo: " + Money.format(Game.money_cents)
	_progress_label.text = "Pedidos: %d/%d" % [Game.orders_completed, Flow.WIN_ORDERS]

func _refresh() -> void:
	_update_top_bar()
	match Flow.state:
		GameStates.Id.MAIN_MENU: _build_menu()
		GameStates.Id.INTRO: _build_intro()
		GameStates.Id.RESTAURANT: _build_restaurant()
		GameStates.Id.ACTIVE_ORDER: _build_order()
		GameStates.Id.INVESTIGATION: _build_investigation()
		GameStates.Id.RECIPE_BOOK: _build_book()
		GameStates.Id.MATH_CHALLENGE: _build_challenge()
		GameStates.Id.PREPARATION: _build_preparation()
		GameStates.Id.DELIVERY: _build_delivery()
		GameStates.Id.ADMINISTRATION: _build_admin()
		GameStates.Id.RESULT: _build_result()
		GameStates.Id.ENDING: _build_ending()

# ====================================================================== painéis
func _build_menu() -> void:
	var p := _begin(GameStates.Id.MAIN_MENU)
	p.add_child(_label("VERINE'S", 44))
	p.add_child(_label("Culinária, administração e matemática."))
	p.add_child(_button("Novo jogo", Flow.start_game))
	p.add_child(_button("Sair", get_tree().quit))

func _build_intro() -> void:
	var p := _begin(GameStates.Id.INTRO)
	p.add_child(_label("A herança do vovô", 30))
	p.add_child(_label("Você herdou de seu avô, Verine, um restaurante que precisa ser recuperado. Junto com ele veio um livro de receitas antigo, com páginas manchadas e incompletas.\n\nAtenda os clientes, descubra os pratos pedidos, recupere as receitas com matemática, cuide do estoque e reinvista o lucro. Cada pedido pode esconder uma pista sobre os segredos do restaurante."))
	p.add_child(_label("Controles: o jogo é jogado somente com o mouse. As respostas numéricas usam o teclado na tela."))
	p.add_child(_button("Abrir o restaurante", Flow.finish_intro))

func _build_restaurant() -> void:
	var p := _begin(GameStates.Id.RESTAURANT)
	p.add_child(_label("O restaurante do vovô Verine", 28))
	p.add_child(_label("Pedidos concluídos: %d de %d." % [Game.orders_completed, Flow.WIN_ORDERS]))
	if Flow.order != null and not Flow.order.is_closed():
		p.add_child(_label("Atendimento em andamento: %s" % Flow.order.customer_name))
		p.add_child(_button("Continuar atendimento", Flow.go.bind(GameStates.Id.ACTIVE_ORDER)))
	else:
		p.add_child(_button("Chamar próximo cliente", Flow.call_next_customer))
	p.add_child(_button("Administração (estoque e melhorias)", Flow.open_admin))

func _build_order() -> void:
	var p := _begin(GameStates.Id.ACTIVE_ORDER)
	var o := Flow.order
	if o == null:
		return
	p.add_child(_label("Cliente: %s" % o.customer_name, 26))
	p.add_child(_label("\"%s\"" % o.description))
	p.add_child(_label("Porções: %d   |   Situação: %s" % [o.servings, Order.state_name(o.state)]))

	match o.state:
		Order.State.CREATED, Order.State.INVESTIGATING:
			p.add_child(_button("Investigar e escolher a receita", Flow.open_investigation))
		Order.State.IDENTIFIED:
			var recipe: Recipe = GameData.recipes[o.selected_recipe_id]
			p.add_child(_label("Receita: %s" % recipe.display_name, 22))
			if Flow.adjusted != null:
				p.add_child(_label("Ingredientes para %d porções:" % o.servings, 18))
				for line in Flow.adjusted.lines:
					var ing: Ingredient = GameData.ingredients[line["ingredient_id"]]
					var amount_text := "???"
					if line["known"] and not (Flow.adjusted.servings != recipe.base_servings and not Flow.challenge_queue.is_empty()):
						amount_text = "%s %s" % [Units.fmt_amount(line["amount"]), Units.label(line["unit"])]
					p.add_child(_label("• %s: %s   (estoque: %d %s)" % [ing.display_name, amount_text,
						Game.get_stock(ing.id), Units.label(ing.unit)]))
			if not Flow.challenge_queue.is_empty():
				p.add_child(_label("Faltam %d desafio(s) para fechar as quantidades." % Flow.challenge_queue.size()))
				p.add_child(_button("Resolver próximo desafio", Flow.next_order_challenge))
			elif Flow.is_ready_to_cook():
				p.add_child(_button("Começar a preparar", Flow.start_preparation))
		Order.State.PREPARING:
			if Flow.dish != null and Flow.dish.state == Dish.State.READY:
				p.add_child(_button("Entregar ao cliente", Flow.start_delivery))
			else:
				p.add_child(_button("Continuar preparo", Flow.go.bind(GameStates.Id.PREPARATION)))
	p.add_child(_button("Cancelar pedido", Flow.cancel_order))

func _build_investigation() -> void:
	var p := _begin(GameStates.Id.INVESTIGATION)
	var o := Flow.order
	if o == null:
		return
	p.add_child(_label("Investigação — pedido de %s" % o.customer_name, 26))
	p.add_child(_label("\"%s\"" % o.description))
	p.add_child(_label("Pistas:", 20))
	var shown := o.visible_clues()
	if shown.is_empty():
		p.add_child(_label("(Sem pistas adicionais. Releia o pedido.)"))
	for cid in shown:
		var clue: Clue = GameData.clues[cid]
		p.add_child(_label("• " + clue.text))
	p.add_child(_button("Pedir pista extra (reduz o pagamento)", Flow.reveal_hint,
		o.hints_used >= o.hidden_clue_ids.size()))
	p.add_child(_label("Receitas do livro:", 20))
	for rid in Game.unlocked_recipes:
		p.add_child(_recipe_card(GameData.recipes[rid], true))
	p.add_child(_button("Voltar", Flow.go.bind(GameStates.Id.ACTIVE_ORDER)))

func _build_book() -> void:
	var p := _begin(GameStates.Id.RECIPE_BOOK)
	p.add_child(_label("Livro de receitas do vovô", 26))
	for rid in Game.unlocked_recipes:
		p.add_child(_recipe_card(GameData.recipes[rid], false))
	p.add_child(_button("Fechar o livro", Flow.close_book))

func _recipe_card(recipe: Recipe, selectable: bool) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	card.add_child(box)
	box.add_child(_label(recipe.display_name, 20))
	box.add_child(_label(recipe.description))
	box.add_child(_label("Rende %d porções (dados originais)" % recipe.base_servings))
	for line in recipe.lines:
		var ing: Ingredient = GameData.ingredients[line["ingredient_id"]]
		var unit: Units.Unit = line["unit"]
		if Game.is_line_known(recipe, line):
			var rec_note := " (recuperado)" if line["hidden"] else ""
			box.add_child(_label("• %s: %s %s%s" % [ing.display_name,
				Units.fmt_amount(Game.get_known_amount(recipe, line)), Units.label(unit), rec_note]))
		else:
			box.add_child(_label("• %s: ??? %s (página manchada)" % [ing.display_name, Units.label(unit)]))
	var clue_texts: PackedStringArray = []
	for cid in recipe.clue_ids:
		var clue: Clue = GameData.clues[cid]
		clue_texts.append(clue.text)
	box.add_child(_label("Pistas relacionadas: " + " / ".join(clue_texts)))
	if not selectable:
		box.add_child(_label("Preparo: " + " → ".join(recipe.steps)))
	else:
		box.add_child(_button("Escolher esta receita", Flow.select_recipe.bind(recipe.id)))
	return card

# ----------------------------------------------------------------- desafio
func _build_challenge() -> void:
	var p := _begin(GameStates.Id.MATH_CHALLENGE)
	var c := Flow.current_challenge
	if c == null:
		return
	_answer = ""
	_selected_choice = -1
	p.add_child(_label("Desafio: %s" % c.topic, 26))
	p.add_child(_label(c.statement))
	_hint_label = _label("")
	p.add_child(_hint_label)
	p.add_child(_button("Pedir uma dica", _on_hint))

	_answer_label = _label("Resposta: ", 22)
	p.add_child(_answer_label)

	if c.type == MathChallenge.Type.MULTIPLE_CHOICE:
		for i in c.choices.size():
			p.add_child(_button(c.choices[i], _on_choice.bind(i)))
	else:
		_keypad = GridContainer.new()
		_keypad.columns = 4
		var keys := ["7", "8", "9", "⌫", "4", "5", "6", "C", "1", "2", "3", ",", "0", "/", ";", "-"]
		for k in keys:
			var kb := _button(k, _on_key.bind(k))
			kb.custom_minimum_size = Vector2(70, 44)
			_keypad.add_child(kb)
		p.add_child(_keypad)

	_feedback_label = _label("")
	p.add_child(_feedback_label)
	_submit_button = _button("Responder", _on_submit)
	p.add_child(_submit_button)
	_continue_button = _button("Continuar", Flow.leave_challenge)
	_continue_button.visible = false
	p.add_child(_continue_button)
	p.add_child(_button("Voltar (resolver depois)", Flow.leave_challenge))

func _on_hint() -> void:
	if Flow.current_challenge != null:
		_hint_label.text = "Dica: " + Flow.current_challenge.hint

func _on_key(k: String) -> void:
	if k == "⌫":
		_answer = _answer.left(maxi(0, _answer.length() - 1))
	elif k == "C":
		_answer = ""
	else:
		_answer += k
	_answer_label.text = "Resposta: " + _answer

func _on_choice(index: int) -> void:
	_selected_choice = index
	var c := Flow.current_challenge
	_answer_label.text = "Resposta: " + c.choices[index]

func _on_submit() -> void:
	var c := Flow.current_challenge
	if c == null:
		return
	var raw: Variant
	if c.type == MathChallenge.Type.MULTIPLE_CHOICE:
		if _selected_choice < 0:
			_feedback_label.text = "Escolha uma alternativa."
			return
		raw = _selected_choice
	else:
		if _answer.strip_edges() == "":
			_feedback_label.text = "Digite uma resposta no teclado da tela."
			return
		raw = _answer
	var res := Flow.submit_answer(raw)
	_feedback_label.text = res["message"]
	if res["ok"]:
		_submit_button.disabled = true
		_continue_button.visible = true
		if _keypad != null:
			for kb in _keypad.get_children():
				(kb as Button).disabled = true

# ------------------------------------------------------------------- preparo
func _build_preparation() -> void:
	var p := _begin(GameStates.Id.PREPARATION)
	var d := Flow.dish
	if d == null:
		return
	var recipe: Recipe = GameData.recipes[d.recipe_id]
	p.add_child(_label("Preparando: %s (%d porções)" % [recipe.display_name, d.servings], 26))
	for i in d.steps.size():
		var mark := "[ ]"
		if i < d.steps_done:
			mark = "[x]"
		elif i == d.steps_done and d.state == Dish.State.PREPARING:
			mark = "[>]"
		p.add_child(_label("%s %s" % [mark, d.steps[i]]))
	if d.state == Dish.State.PREPARING:
		p.add_child(_button("Executar: %s" % d.next_step_label(), Flow.do_prep_step))
	elif d.state == Dish.State.READY:
		p.add_child(_label("O prato está pronto!", 22))
		p.add_child(_button("Levar ao cliente", Flow.start_delivery))

# ------------------------------------------------------------------- entrega
func _build_delivery() -> void:
	var p := _begin(GameStates.Id.DELIVERY)
	var o := Flow.order
	if o == null:
		return
	p.add_child(_label("Entrega para %s" % o.customer_name, 26))
	p.add_child(_label("Conta: %s" % Money.format(Flow.delivery_bill_cents)))
	for step in [["portion", "Dividir o prato"], ["change", "Receber pagamento e dar o troco"]]:
		var done: bool = Flow.delivery_steps_done.has(step[0])
		p.add_child(_label("%s %s" % ["[x]" if done else "[ ]", step[1]]))
	p.add_child(_button(Flow.delivery_next_label(), Flow.delivery_next))

# ------------------------------------------------------------ administração
func _build_admin() -> void:
	var p := _begin(GameStates.Id.ADMINISTRATION)
	p.add_child(_label("Administração", 28))
	p.add_child(_label("Saldo: %s   |   Receita: %s   |   Despesas: %s   |   Lucro: %s" % [
		Money.format(Game.money_cents), Money.format(Game.total_income),
		Money.format(Game.total_expenses), Money.format(Game.profit())]))
	if Game.next_purchase_discount_percent > 0.0:
		p.add_child(_label("Desconto ativo na próxima compra: %d%%" % int(Game.next_purchase_discount_percent)))

	p.add_child(_label("Estoque e compras", 20))
	for id in GameData.ingredients:
		var ing: Ingredient = GameData.ingredients[id]
		var limit := Game.get_storage_limit(id)
		var txt := "%s: %d %s" % [ing.display_name, Game.get_stock(id), Units.label(ing.unit)]
		if limit > 0:
			txt += " / %d" % limit
		if Game.needs_restock(id):
			txt += "  (estoque baixo)"
		var row := HBoxContainer.new()
		row.add_child(_label(txt))
		row.add_child(_button("Comprar %d %s (%s)" % [ing.pack_size, Units.label(ing.unit),
			Money.format(Game.purchase_price(id, 1))], _on_buy.bind(id)))
		p.add_child(row)
	p.add_child(_button("Planejar compras (desafio: 10% de desconto)", Flow.start_planning_challenge))

	p.add_child(_label("Melhorias", 20))
	for uid in GameData.upgrades:
		var u: Upgrade = GameData.upgrades[uid]
		var check := Game.can_buy_upgrade(uid)
		var owned: bool = uid in Game.purchased_upgrades
		var urow := HBoxContainer.new()
		urow.add_child(_label("%s — %s (%s)" % [u.display_name, u.description, Money.format(u.cost_cents)]))
		var btn_text := "Adquirida" if owned else ("Comprar" if check["ok"] else check["reason"])
		urow.add_child(_button(btn_text, _on_buy_upgrade.bind(uid), not check["ok"]))
		p.add_child(urow)

	p.add_child(_label("Últimas movimentações", 20))
	var start := maxi(0, Game.ledger.size() - 5)
	for i in range(Game.ledger.size() - 1, start - 1, -1):
		var e: Dictionary = Game.ledger[i]
		var sign_text := "+" if e["kind"] == "entrada" else "−"
		p.add_child(_label("%s %s  %s" % [sign_text, Money.format(e["cents"]), e["reason"]]))
	p.add_child(_button("Voltar ao restaurante", Flow.go.bind(GameStates.Id.RESTAURANT)))

func _on_buy(id: String) -> void:
	var r := Game.buy_ingredient(id, 1)
	Flow.say(r["message"])

func _on_buy_upgrade(uid: String) -> void:
	var r := Game.buy_upgrade(uid)
	Flow.say(r["message"])

# ------------------------------------------------------------ resultado / fim
func _build_result() -> void:
	var p := _begin(GameStates.Id.RESULT)
	var r := Flow.last_result
	if r.is_empty():
		return
	p.add_child(_label("Atendimento concluído — %s" % r["customer"], 26))
	p.add_child(_label("Preço-base: %s" % Money.format(r["base"])))
	p.add_child(_label("Bônus de melhorias: %s" % Money.format(r["upgrade_bonus"])))
	p.add_child(_label("Bônus por atendimento perfeito: %s" % Money.format(r["bonus"])))
	p.add_child(_label("Penalidades (%d erro(s), %d pista(s) extra): −%s" % [
		r["mistakes"], r["hints"], Money.format(r["penalty"])]))
	p.add_child(_label("Total recebido: %s" % Money.format(r["total"]), 22))
	if str(r["story"]) != "":
		p.add_child(_label(str(r["story"])))
	p.add_child(_button("Continuar", Flow.continue_after_result))

func _build_ending() -> void:
	var p := _begin(GameStates.Id.ENDING)
	p.add_child(_label("O restaurante renasceu!", 32))
	p.add_child(_label("Você atendeu %d pedidos e terminou com %s em caixa (lucro total: %s)." % [
		Game.orders_completed, Money.format(Game.money_cents), Money.format(Game.profit())]))
	p.add_child(_label("(Desfecho provisório: o final da história ainda será definido pela equipe.)"))
	p.add_child(_button("Voltar ao menu principal", Flow.go.bind(GameStates.Id.MAIN_MENU)))
