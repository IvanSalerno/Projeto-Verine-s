class_name CozinhaView
extends Control
## Página da COZINHA. Imagens (em assets/cenarios/):
##   cozinha.png    - ajuste das quantidades e prato pronto
##   preparacao.png - etapas de preparo (separar, misturar, montar, finalizar...)
##   fogao.png      - etapas que usam fogo (assar, cozinhar, fritar, aquecer, calda)
## Sem imagens, usa a blocagem de scenes/cozinha_view.tscn.

const PATHS_COZINHA: Array[String] = ["res://assets/cenarios/cozinha.png"]
const PATHS_PREPARO: Array[String] = ["res://assets/cenarios/preparacao.png"]
const PATHS_FOGAO: Array[String] = ["res://assets/cenarios/fogao.png"]
## Palavras que indicam que a etapa usa o fogão/forno.
const HEAT_WORDS: Array[String] = ["assar", "cozinhar", "fritar", "aquecer", "calda", "forno"]

var _bg: TextureRect
var _tex_cozinha: Texture2D
var _tex_preparo: Texture2D
var _tex_fogao: Texture2D

@onready var _dish_block: ColorRect = $Prato
@onready var _dish_label: Label = $Prato/Texto
@onready var _recipe_label: Label = $Receita

func _ready() -> void:
	_dish_block.set_meta("keep", true)
	_bg = SceneBackground.create_layer(self)
	_tex_cozinha = SceneBackground.load_first(PATHS_COZINHA)
	_tex_preparo = SceneBackground.load_first(PATHS_PREPARO)
	_tex_fogao = SceneBackground.load_first(PATHS_FOGAO)
	SceneBackground.style_label_for_art(_recipe_label)
	Flow.state_changed.connect(_update)
	Flow.order_changed.connect(_update)
	Flow.dish_changed.connect(_update)
	_update()

## Escolhe a imagem conforme o que está acontecendo na cozinha.
func _pick_texture() -> Texture2D:
	var d := Flow.dish
	if d != null and d.state == Dish.State.PREPARING:
		var step := d.next_step_label().to_lower()
		for w in HEAT_WORDS:
			if step.contains(w):
				return SceneBackground.first_of([_tex_fogao, _tex_preparo, _tex_cozinha])
		return SceneBackground.first_of([_tex_preparo, _tex_cozinha])
	return _tex_cozinha

func _update(_unused: int = 0) -> void:
	var has_image := SceneBackground.show_image(self, _bg, _pick_texture())
	var o := Flow.order
	var active := o != null and not o.is_closed() and o.selected_recipe_id != ""
	_recipe_label.visible = active
	if active:
		var r: Recipe = GameData.recipes[o.selected_recipe_id]
		_recipe_label.text = "Pedido de %s: %s (%d porções)" % [o.customer_name, r.display_name, o.servings]
	var d := Flow.dish
	_dish_block.visible = d != null and not has_image   # com imagem, o painel abaixo mostra as etapas
	if d != null:
		var recipe: Recipe = GameData.recipes[d.recipe_id]
		if d.state == Dish.State.READY:
			_dish_block.color = Color(0.4, 0.8, 0.4)
			_dish_label.text = "%s\npronto!" % recipe.display_name
		else:
			_dish_block.color = Color(0.95, 0.65, 0.2)
			_dish_label.text = "%s\n%d/%d etapas" % [recipe.display_name, d.steps_done, d.steps.size()]
