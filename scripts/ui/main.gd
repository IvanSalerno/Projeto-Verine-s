extends Control
## Interface do jogo. Controle EXCLUSIVAMENTE por mouse (teclado numérico na tela).
## O restaurante tem 3 páginas (Salão, Cozinha e Despensa), cada uma com sua cena visual.

const HIDE_VIEW_STATES := [
	GameStates.Id.MAIN_MENU, GameStates.Id.INTRO, GameStates.Id.CREDITS, GameStates.Id.SETTINGS,
	GameStates.Id.ENDING, GameStates.Id.MATH_CHALLENGE, GameStates.Id.RECIPE_BOOK,
]
const MENU_BG_PATHS: Array[String] = [
	"res://assets/cenarios/livro_receitas.png",
	"res://assets/cenarios/livro de receitas.png",
]
const VIEW_SCENES := [
	"res://scenes/salao_view.tscn",
	"res://scenes/cozinha_view.tscn",
	"res://scenes/despensa_view.tscn",
]

var _panels: Dictionary = {}          # GameStates.Id -> VBoxContainer
var _bar: Control
var _menu_bg: TextureRect
var _menu_tex: Texture2D
var _nav: HBoxContainer
var _nav_buttons: Array[Button] = []
var _views: Array[Control] = []
var _last_place: int = 0
var _menu_overlay: PanelContainer
var _menu_button: Button
var _book_button: Button
var _money_label: Label
var _day_label: Label
var _progress_label: Label
var _score_label: Label
var _msg_label: Label
var _confirm_exit: bool = false
var _confirm_delete: bool = false

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
	Game.money_changed.connect(_on_top_changed)
	Game.score_changed.connect(_on_top_changed)
	Game.day_changed.connect(_on_top_changed)
	Game.inventory_changed.connect(_on_inventory_changed)
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_on_state_changed(Flow.state)

func _apply_settings() -> void:
	var t := Theme.new()
	t.default_font_size = Settings.TEXT_SIZES[Settings.text_size]
	theme = t
	if Flow.state == GameStates.Id.SETTINGS:
		_refresh()

# ============================================================== layout / helpers
func _build_layout() -> void:
	# fundo do menu inicial (livro de receitas), atrás de tudo e escurecido para leitura
	_menu_bg = TextureRect.new()
	_menu_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_menu_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_bg.visible = false
	add_child(_menu_bg)
	_menu_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_bg.add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_tex = SceneBackground.load_first(MENU_BG_PATHS)
	_menu_bg.texture = _menu_tex

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# ---- barra superior
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 58)
	root.add_child(_bar)

	# canto superior esquerdo: menu (☰), saldo e livro de receitas
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	_bar.add_child(left)
	_menu_button = MenuIconButton.new()
	_menu_button.tooltip_text = "Menu"
	_menu_button.pressed.connect(_toggle_menu)
	left.add_child(_menu_button)
	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 20)
	left.add_child(_money_label)
	_book_button = _button("Livro de receitas", Flow.open_book)
	left.add_child(_book_button)
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE)

	# centro superior: contador de dias
	var center := VBoxContainer.new()
	_bar.add_child(center)
	_day_label = Label.new()
	_day_label.add_theme_font_size_override("font_size", 28)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_day_label)
	_progress_label = Label.new()
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_progress_label)
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# canto superior direito: placar de pontos
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 24)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_bar.add_child(_score_label)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_score_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# ---- navegação entre as páginas do restaurante
	_nav = HBoxContainer.new()
	root.add_child(_nav)
	var place_names := ["Salão (atendimento)", "Cozinha", "Despensa e escritório"]
	for i in place_names.size():
		var b := _button(place_names[i], Flow.goto_place.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_nav.add_child(b)
		_nav_buttons.append(b)

	# ---- uma cena visual por página
	for path in VIEW_SCENES:
		var v: Control = load(path).instantiate()
		v.visible = false
		root.add_child(v)
		_views.append(v)

	# ---- painéis de conteúdo
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

	# ---- menu suspenso (☰), por cima de tudo
	_menu_overlay = PanelContainer.new()
	_menu_overlay.visible = false
	_menu_overlay.position = Vector2(16, 76)
	add_child(_menu_overlay)

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
	_msg_label.text = ""
	_menu_overlay.visible = false
	_confirm_exit = false
	_confirm_delete = false
	for id in _panels:
		_panels[id].visible = (id == s)
	var in_menus: bool = s in [GameStates.Id.MAIN_MENU, GameStates.Id.INTRO, GameStates.Id.CREDITS] \
		or (s == GameStates.Id.SETTINGS and Flow.settings_return == GameStates.Id.MAIN_MENU)
	_bar.visible = not in_menus
	_menu_bg.visible = in_menus and _menu_tex != null
	_menu_button.visible = s != GameStates.Id.ENDING
	_book_button.visible = s in [GameStates.Id.RESTAURANT, GameStates.Id.ACTIVE_ORDER,
		GameStates.Id.INVESTIGATION, GameStates.Id.KITCHEN]
	# navegação e cenas
	_nav.visible = GameStates.can_navigate(s)
	var place := GameStates.place_of(s)
	if place != -1:
		_last_place = place
	for i in _nav_buttons.size():
		_nav_buttons[i].disabled = (i == place)
	var views_visible := not (s in HIDE_VIEW_STATES)
	for i in _views.size():
		_views[i].visible = views_visible and i == _last_place
	_refresh()

func _on_notice(text: String) -> void:
	_msg_label.text = text

func _on_top_changed(_value: int) -> void:
	_update_top_bar()

func _on_inventory_changed() -> void:
	if Flow.state == GameStates.Id.ADMINISTRATION or Flow.state == GameStates.Id.KITCHEN:
		_refresh()

func _update_top_bar() -> void:
	_money_label.text = "Saldo: " + Money.format(Game.money_cents)
	_day_label.text = "Dia %d" % Game.day
	_score_label.text = "Pontos: %d" % Game.score
	_progress_label.text = "Pedidos: %d/%d  |  Nível %d" % [Game.orders_completed, Flow.WIN_ORDERS, Flow.current_tier()]

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
		GameStates.Id.KITCHEN: _build_kitchen()
		GameStates.Id.DELIVERY: _build_delivery()
		GameStates.Id.ADMINISTRATION: _build_admin()
		GameStates.Id.RESULT: _build_result()
		GameStates.Id.DAY_SUMMARY: _build_day_summary()
		GameStates.Id.SETTINGS: _build_settings()
		GameStates.Id.CREDITS: _build_credits()
		GameStates.Id.ENDING: _build_ending()

# ============================================================ menu suspenso (☰)
func _toggle_menu() -> void:
	if _menu_overlay.visible:
		_menu_overlay.visible = false
		return
	_confirm_exit = false
	_fill_menu_overlay()
	_menu_overlay.visible = true

func _fill_menu_overlay() -> void:
	for c in _menu_overlay.get_children():
		_menu_overlay.remove_child(c)
		c.queue_free()
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 0)
	box.add_theme_constant_override("separation", 6)
	_menu_overlay.add_child(box)
	box.add_child(_label("Menu", 22))
	box.add_child(_button("Salvar jogo", _on_menu_save, not Flow.can_save()))
	box.add_child(_button("Configurações", _on_menu_settings))
	if _confirm_exit:
		box.add_child(_label("O progresso não salvo será perdido."))
		box.add_child(_button("Confirmar: voltar ao menu principal", _on_menu_exit))
	else:
		box.add_child(_button("Voltar ao menu principal", _on_menu_exit_ask))
	box.add_child(_button("Fechar", _toggle_menu))

func _on_menu_save() -> void:
	_menu_overlay.visible = false
	Flow.save_now()

func _on_menu_settings() -> void:
	_menu_overlay.visible = false
	Flow.open_settings()

func _on_menu_exit_ask() -> void:
	_confirm_exit = true
	_fill_menu_overlay()

func _on_menu_exit() -> void:
	_menu_overlay.visible = false
	Flow.go(GameStates.Id.MAIN_MENU)

# ====================================================================== painéis
func _build_menu() -> void:
	var p := _begin(GameStates.Id.MAIN_MENU)
	p.add_child(_label("VERINE'S", 44))
	p.add_child(_label("Culinária, administração e matemática."))
	if Game.best_score > 0:
		p.add_child(_label("Recorde: %d pontos" % Game.best_score))
	p.add_child(_button("Novo jogo", Flow.start_game))
	var has_save := SaveSystem.has_save()
	p.add_child(_button("Continuar jogo salvo", Flow.continue_game, not has_save))
	if has_save:
		p.add_child(_label(SaveSystem.info(), 14))
	p.add_child(_button("Configurações", Flow.open_settings))
	p.add_child(_button("Créditos", Flow.open_credits))
	p.add_child(_button("Sair", get_tree().quit))

func _build_settings() -> void:
	var p := _begin(GameStates.Id.SETTINGS)
	p.add_child(_label("Configurações", 30))

	var vrow := HBoxContainer.new()
	vrow.add_child(_label("Volume: %d/10" % Settings.volume_steps))
	vrow.add_child(_button("−", Settings.change_volume.bind(-1)))
	vrow.add_child(_button("+", Settings.change_volume.bind(1)))
	p.add_child(vrow)

	var frow := HBoxContainer.new()
	frow.add_child(_label("Tela cheia: %s" % ("ligada" if Settings.fullscreen else "desligada")))
	frow.add_child(_button("Alternar", Settings.toggle_fullscreen))
	p.add_child(frow)

	var hrow := HBoxContainer.new()
	hrow.add_child(_label("Dicas do tutorial: %s" % ("ligadas" if Settings.show_hints else "desligadas")))
	hrow.add_child(_button("Alternar", Settings.toggle_hints))
	p.add_child(hrow)

	var trow := HBoxContainer.new()
	trow.add_child(_label("Tamanho do texto: %s" % Settings.TEXT_SIZE_NAMES[Settings.text_size]))
	for i in 3:
		trow.add_child(_button(Settings.TEXT_SIZE_NAMES[i], Settings.set_text_size.bind(i), i == Settings.text_size))
	p.add_child(trow)

	if SaveSystem.has_save():
		if _confirm_delete:
			p.add_child(_button("Clique de novo para APAGAR o jogo salvo", _on_delete_save))
		else:
			p.add_child(_button("Apagar jogo salvo", _on_delete_ask))
	p.add_child(_button("Voltar", Flow.close_settings))

func _on_delete_ask() -> void:
	_confirm_delete = true
	_refresh()

func _on_delete_save() -> void:
	SaveSystem.delete()
	_confirm_delete = false
	Flow.say("Jogo salvo apagado.")
	_refresh()

func _build_credits() -> void:
	var p := _begin(GameStates.Id.CREDITS)
	p.add_child(_label("VERINE'S", 40))
	for line in Credits.LINES:
		p.add_child(_label(line))
	p.add_child(_button("Voltar", Flow.close_credits))

func _build_intro() -> void:
	var p := _begin(GameStates.Id.INTRO)
	p.add_child(_label("A herança do vovô", 30))
	p.add_child(_label("Você herdou de seu avô, Verine, um restaurante que precisa ser recuperado. Junto com ele veio um livro de receitas antigo, com páginas manchadas e incompletas.\n\nAtenda os clientes no Salão, prepare os pratos na Cozinha, cuide do estoque na Despensa e reinvista o lucro. Cada pedido pode esconder uma pista sobre os segredos do restaurante."))
	p.add_child(_label("Controles: o jogo é jogado somente com o mouse. As respostas numéricas usam o teclado na tela. Use o botão de menu (três linhas, no canto superior esquerdo) para salvar."))
	p.add_child(_button("Abrir o restaurante", Flow.finish_intro))

# ------------------------------------------------------------------- SALÃO
func _build_restaurant() -> void:
	var p := _begin(GameStates.Id.RESTAURANT)
	p.add_child(_label("Salão do restaurante", 28))
	p.add_child(_label("Pedidos concluídos: %d de %d.   Pedidos de hoje: %d de %d." % [
		Game.orders_completed, Flow.WIN_ORDERS, Game.orders_today, Flow.ORDERS_PER_DAY]))
	p.add_child(_button("Chamar próximo cliente", Flow.call_next_customer))

func _build_order() -> void:
	var p := _begin(GameStates.Id.ACTIVE_ORDER)
	var o := Flow.order
	if o == null:
		return
	p.add_child(_label("Cliente: %s" % o.customer_name, 26))
	p.add_child(_label("\"%s\"" % o.description))
	p.add_child(_label("Porções: %d   |   Situação: %s" % [o.servings, Order.state_name(o.state)]))
	if Game.orders_completed == 0 and Settings.show_hints:
		p.add_child(_label(_tutorial_hint(o), 16))

	match o.state:
		Order.State.CREATED, Order.State.INVESTIGATING:
			p.add_child(_button("Investigar e escolher a receita", Flow.open_investigation))
		Order.State.IDENTIFIED:
			var recipe: Recipe = GameData.recipes[o.selected_recipe_id]
			p.add_child(_label("Receita escolhida: %s. Agora vá para a Cozinha: lá você ajusta as quantidades e prepara o prato." % recipe.display_name))
			p.add_child(_button("Ir para a cozinha", Flow.goto_place.bind(GameStates.Place.COZINHA)))
		Order.State.PREPARING:
			if Flow.dish != null and Flow.dish.state == Dish.State.READY:
				p.add_child(_label("O prato está pronto! Entregue ao cliente."))
				p.add_child(_button("Entregar ao cliente", Flow.start_delivery))
			else:
				p.add_child(_label("O prato ainda está sendo preparado na Cozinha."))
				p.add_child(_button("Ir para a cozinha", Flow.goto_place.bind(GameStates.Place.COZINHA)))
	p.add_child(_button("Cancelar pedido", Flow.cancel_order))

func _tutorial_hint(o: Order) -> String:
	match o.state:
		Order.State.CREATED, Order.State.INVESTIGATING:
			return "Dica: leia o pedido e compare com as receitas do livro. Neste pedido o cliente cita o prato."
		Order.State.IDENTIFIED:
			return "Dica: na Cozinha, resolva os desafios para ajustar as quantidades. Se faltar ingrediente, compre na Despensa."
		Order.State.PREPARING:
			return "Dica: execute cada etapa na Cozinha; com o prato pronto, volte ao Salão para entregar."
	return ""

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

func _build_delivery() -> void:
	var p := _begin(GameStates.Id.DELIVERY)
	var o := Flow.order
	if o == null:
		return
	p.add_child(_label("Entrega para %s" % o.customer_name, 26))
	p.add_child(_label("Valor do prato: %s" % Money.format(Flow.delivery_bill_cents)))
	for step in [["portion", "Dividir o prato"], ["change", "Receber pagamento e dar o troco"]]:
		var done: bool = Flow.delivery_steps_done.has(step[0])
		p.add_child(_label("%s %s" % ["[x]" if done else "[ ]", step[1]]))
	p.add_child(_button(Flow.delivery_next_label(), Flow.delivery_next))

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
	p.add_child(_label("Pontos ganhos neste pedido: +%d" % int(r["points"])))
	if str(r["story"]) != "":
		p.add_child(_label(str(r["story"])))
	p.add_child(_button("Continuar", Flow.continue_after_result))

func _build_day_summary() -> void:
	var p := _begin(GameStates.Id.DAY_SUMMARY)
	p.add_child(_label("Fim do dia %d" % Game.day, 30))
	p.add_child(_label("Pedidos atendidos hoje: %d" % Game.orders_today))
	p.add_child(_label("Receita do dia: %s   |   Despesas do dia: %s   |   Lucro do dia: %s" % [
		Money.format(Game.day_income()), Money.format(Game.day_expenses()),
		Money.format(Game.day_income() - Game.day_expenses())]))
	if not Game.day_history.is_empty():
		p.add_child(_label("Dias anteriores:", 20))
		var start := maxi(0, Game.day_history.size() - 5)
		for i in range(start, Game.day_history.size()):
			var e: Dictionary = Game.day_history[i]
			p.add_child(_label("• Dia %d: lucro %s (%d pedidos)" % [e["day"], Money.format(e["profit"]), e["orders"]]))
	if Game.daily_challenge_done:
		p.add_child(_label("Desafio de gestão de hoje: concluído!"))
	else:
		p.add_child(_label("Desafio de gestão do dia (opcional): vale bônus em dinheiro e pontos."))
		p.add_child(_button("Resolver o desafio de gestão", Flow.start_daily_challenge))
	p.add_child(_button("Começar o dia %d (salva automaticamente)" % (Game.day + 1), Flow.start_next_day))

# ----------------------------------------------------------------- COZINHA
func _build_kitchen() -> void:
	var p := _begin(GameStates.Id.KITCHEN)
	p.add_child(_label("Cozinha", 28))
	var o := Flow.order
	if o == null or o.is_closed():
		p.add_child(_label("Nenhum pedido em andamento. Chame um cliente no Salão."))
		p.add_child(_button("Ir para o salão", Flow.goto_place.bind(GameStates.Place.SALAO)))
		return
	if Game.orders_completed == 0 and Settings.show_hints:
		p.add_child(_label(_tutorial_hint(o), 16))
	match o.state:
		Order.State.CREATED, Order.State.INVESTIGATING:
			p.add_child(_label("Ainda não sabemos qual prato %s pediu. Descubra a receita no Salão." % o.customer_name))
			p.add_child(_button("Ir para o salão", Flow.goto_place.bind(GameStates.Place.SALAO)))
		Order.State.IDENTIFIED:
			_build_kitchen_prep(p, o)
		Order.State.PREPARING:
			_build_kitchen_cooking(p)
		_:
			p.add_child(_label("Nada para cozinhar agora."))

func _build_kitchen_prep(p: VBoxContainer, o: Order) -> void:
	var recipe: Recipe = GameData.recipes[o.selected_recipe_id]
	p.add_child(_label("Receita: %s — %d porções" % [recipe.display_name, o.servings], 22))
	if Flow.adjusted != null:
		p.add_child(_label("Ingredientes para %d porções:" % o.servings, 18))
		for line in Flow.adjusted.lines:
			var ing: Ingredient = GameData.ingredients[line["ingredient_id"]]
			var amount_text := "???"
			var hidden_by_scaling: bool = Flow.adjusted.servings != recipe.base_servings and not Flow.challenge_queue.is_empty()
			if line["known"] and not hidden_by_scaling:
				amount_text = "%s %s" % [Units.fmt_amount(line["amount"]), Units.label(line["unit"])]
			p.add_child(_label("• %s: %s   (estoque: %d %s)" % [ing.display_name, amount_text,
				Game.get_stock(ing.id), Units.label(ing.unit)]))
	if not Flow.challenge_queue.is_empty():
		p.add_child(_label("Faltam %d desafio(s) para fechar as quantidades." % Flow.challenge_queue.size()))
		p.add_child(_button("Resolver próximo desafio", Flow.next_order_challenge))
	elif Flow.is_ready_to_cook():
		p.add_child(_button("Começar a preparar", Flow.start_preparation))
	p.add_child(_button("Comprar ingredientes na Despensa", Flow.goto_place.bind(GameStates.Place.DESPENSA)))

func _build_kitchen_cooking(p: VBoxContainer) -> void:
	var d := Flow.dish
	if d == null:
		return
	var recipe: Recipe = GameData.recipes[d.recipe_id]
	p.add_child(_label("Preparando: %s (%d porções)" % [recipe.display_name, d.servings], 22))
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
		p.add_child(_label("O prato está pronto! Leve ao cliente no Salão.", 20))
		p.add_child(_button("Ir para o salão", Flow.goto_place.bind(GameStates.Place.SALAO)))

# ---------------------------------------------------------------- DESAFIO
func _build_challenge() -> void:
	var p := _begin(GameStates.Id.MATH_CHALLENGE)
	var c := Flow.current_challenge
	if c == null:
		return
	_answer = ""
	_selected_choice = -1
	p.add_child(_label("Desafio: %s (nível %d)" % [c.topic, c.tier], 26))
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

# ----------------------------------------------------------------- DESPENSA
func _build_admin() -> void:
	var p := _begin(GameStates.Id.ADMINISTRATION)
	p.add_child(_label("Despensa e escritório", 28))
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
	p.add_child(_button("Planejar compras (desafio nível %d: desconto na próxima compra)" % Flow.current_tier(), Flow.start_planning_challenge))
	if Game.can_ask_help():
		p.add_child(_button("Pedir ajuda ao vizinho (+%s, restam %d)" % [Money.format(Game.HELP_AMOUNT),
			Game.HELP_MAX_USES - Game.help_uses], _on_help))

	p.add_child(_label("Melhorias", 20))
	for uid in GameData.upgrades:
		var u: Upgrade = GameData.upgrades[uid]
		var check := Game.can_buy_upgrade(uid)
		var owned: bool = uid in Game.purchased_upgrades
		var urow := HBoxContainer.new()
		urow.add_child(_label("%s — %s (%s)" % [u.display_name, u.description, Money.format(u.cost_cents)]))
		var btn_text: String = "Adquirida" if owned else ("Comprar" if check["ok"] else str(check["reason"]))
		urow.add_child(_button(btn_text, _on_buy_upgrade.bind(uid), not check["ok"]))
		p.add_child(urow)

	p.add_child(_label("Últimas movimentações", 20))
	var start := maxi(0, Game.ledger.size() - 5)
	for i in range(Game.ledger.size() - 1, start - 1, -1):
		var e: Dictionary = Game.ledger[i]
		var sign_text := "+" if e["kind"] == "entrada" else "−"
		p.add_child(_label("%s %s  %s" % [sign_text, Money.format(e["cents"]), e["reason"]]))
	p.add_child(_button("Voltar ao salão", Flow.goto_place.bind(GameStates.Place.SALAO)))

func _on_help() -> void:
	if Game.ask_help():
		Flow.say("Seu vizinho emprestou um dinheiro para você repor o estoque.")

func _on_buy(id: String) -> void:
	var r := Game.buy_ingredient(id, 1)
	Flow.say(r["message"])

func _on_buy_upgrade(uid: String) -> void:
	var r := Game.buy_upgrade(uid)
	Flow.say(r["message"])

# ---------------------------------------------------------------------- FIM
func _build_ending() -> void:
	var p := _begin(GameStates.Id.ENDING)
	p.add_child(_label("O restaurante renasceu!", 32))
	p.add_child(_label("Você atendeu %d pedidos em %d dias e terminou com %s em caixa (lucro total: %s)." % [
		Game.orders_completed, Game.day, Money.format(Game.money_cents), Money.format(Game.profit())]))
	p.add_child(_label("Pontuação final: %d   |   Recorde: %d%s" % [
		Game.score, Game.best_score, "  (novo recorde!)" if Flow.new_record else ""], 22))
	p.add_child(_label("(Desfecho provisório: o final da história ainda será definido pela equipe.)"))
	p.add_child(_button("Voltar ao menu principal", Flow.go.bind(GameStates.Id.MAIN_MENU)))
