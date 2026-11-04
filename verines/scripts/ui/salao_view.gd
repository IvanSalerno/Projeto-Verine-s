class_name SalaoView
extends Control
## Página do SALÃO. Fundo: assets/cenarios/salao.png (atendimento) e
## assets/cenarios/caixa_registradora.png (na hora de pagar e dar o troco).
## Sem imagens, usa a blocagem de scenes/salao_view.tscn.

const PATHS_SALAO: Array[String] = ["res://assets/cenarios/salao.png"]
const PATHS_CAIXA: Array[String] = ["res://assets/cenarios/caixa_registradora.png"]
## Imagens dos clientes. Para pixel art: aba Importar > Filtro = Nearest.
const CLIENT_TEXTURE_PATHS: Array[String] = [
	"res://assets/clientes/cliente_vermelho.png",
	"res://assets/clientes/cliente_azul.png",
	"res://assets/clientes/cliente_amarelo.png",
]
const CLIENT_BLOCK_COLORS: Array[Color] = [
	Color(0.8, 0.25, 0.25), Color(0.25, 0.4, 0.8), Color(0.9, 0.75, 0.2),
]

var _textures: Array = []
var _bg: TextureRect
var _tex_salao: Texture2D
var _tex_caixa: Texture2D

@onready var _client_sprite: TextureRect = $Cliente
@onready var _client_block: ColorRect = $ClienteBloco
@onready var _client_name: Label = $NomeCliente

func _ready() -> void:
	_client_block.set_meta("keep", true)
	_bg = SceneBackground.create_layer(self)
	_tex_salao = SceneBackground.load_first(PATHS_SALAO)
	_tex_caixa = SceneBackground.load_first(PATHS_CAIXA)
	SceneBackground.style_label_for_art(_client_name)
	for path in CLIENT_TEXTURE_PATHS:
		if ResourceLoader.exists(path):
			_textures.append(load(path))
		else:
			_textures.append(null)
	Flow.state_changed.connect(_update)
	Flow.order_changed.connect(_update)
	_update()

func _update(_unused: int = 0) -> void:
	# Na entrega (pagamento e troco) mostra a caixa registradora, se houver imagem.
	var at_register := Flow.state == GameStates.Id.DELIVERY and _tex_caixa != null
	var tex: Texture2D = _tex_caixa if at_register else _tex_salao
	SceneBackground.show_image(self, _bg, tex)

	var o := Flow.order
	var present := o != null and not o.is_closed() and not at_register
	_client_name.visible = present
	_client_sprite.visible = false
	_client_block.visible = false
	if present:
		var idx: int = int(o.customer_name.hash() % CLIENT_TEXTURE_PATHS.size())
		_client_name.text = o.customer_name
		var client_tex: Texture2D = _textures[idx]
		if client_tex != null:
			_client_sprite.texture = client_tex
			_client_sprite.visible = true
		else:
			_client_block.color = CLIENT_BLOCK_COLORS[idx]
			_client_block.visible = true
