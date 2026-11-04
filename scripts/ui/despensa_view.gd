class_name DespensaView
extends Control
## Página da DESPENSA: prateleira com uma barra por ingrediente (verde = ok, vermelho =
## estoque baixo) e o escritório com o saldo. Edite em scenes/despensa_view.tscn.

const BAR_LEFT := 70.0
const BAR_SPACING := 100.0
const BAR_WIDTH := 56.0
const BAR_BOTTOM := 165.0
const BAR_MAX_H := 110.0

var _bg: TextureRect
var _bars: Dictionary = {}     # ingredient_id -> ColorRect
var _labels: Dictionary = {}   # ingredient_id -> Label

@onready var _balance: Label = $Escritorio/Saldo/Texto

const BACKGROUND_PATH := "res://assets/cenarios/despensa.png"

func _ready() -> void:
	_bg = SceneBackground.create_layer(self)
	_build_bars()
	SceneBackground.show_image(self, _bg, SceneBackground.load_first([BACKGROUND_PATH]))
	Game.inventory_changed.connect(_update)
	Game.money_changed.connect(_on_money)
	Flow.state_changed.connect(_on_state)
	_update()

func _build_bars() -> void:
	var i := 0
	for id in GameData.ingredients:
		var ing: Ingredient = GameData.ingredients[id]
		var x := BAR_LEFT + i * BAR_SPACING
		var bar := ColorRect.new()
		bar.color = Color(0.4, 0.75, 0.4)
		bar.set_meta("keep", true)
		add_child(bar)
		_bars[id] = bar
		var lbl := Label.new()
		lbl.position = Vector2(x - 20, BAR_BOTTOM + 4)
		lbl.size = Vector2(BAR_WIDTH + 40, 30)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
		add_child(lbl)
		_labels[id] = lbl
		i += 1

func _update() -> void:
	var i := 0
	for id in GameData.ingredients:
		var ing: Ingredient = GameData.ingredients[id]
		var limit := Game.get_storage_limit(id)
		if limit <= 0:
			limit = ing.pack_size * 3
		var stock := Game.get_stock(id)
		var ratio := clampf(float(stock) / float(limit), 0.0, 1.0)
		var h := maxf(4.0, ratio * BAR_MAX_H)
		var bar: ColorRect = _bars[id]
		bar.position = Vector2(BAR_LEFT + i * BAR_SPACING, BAR_BOTTOM - h)
		bar.size = Vector2(BAR_WIDTH, h)
		bar.color = Color(0.85, 0.3, 0.25) if Game.needs_restock(id) else Color(0.4, 0.75, 0.4)
		var lbl: Label = _labels[id]
		lbl.text = "%s\n%d %s" % [ing.display_name, stock, Units.label(ing.unit)]
		i += 1
	_balance.text = "Saldo: " + Money.format(Game.money_cents)

func _on_money(_v: int) -> void:
	_update()

func _on_state(_s: int) -> void:
	_update()
