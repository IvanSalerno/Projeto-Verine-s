class_name SceneBackground
extends RefCounted
## Fundo de imagem para as páginas (Salão, Cozinha, Despensa). Se a imagem não existir,
## a blocagem colorida continua aparecendo. Nós com o metadado "keep" (ex.: bloco do cliente,
## prato, barras de estoque) nunca são escondidos por aqui: o próprio script da página cuida deles.

const IMAGE_HEIGHT := 280.0   # altura da página quando há imagem
const BLOCK_HEIGHT := 230.0   # altura da página com a blocagem

## Cria a camada de imagem atrás dos blocos. Começa invisível.
static func create_layer(view: Control) -> TextureRect:
	var bg := TextureRect.new()
	bg.name = "FundoImagem"
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED   # preenche e corta o excesso
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.visible = false
	view.add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.move_child(bg, 0)
	return bg

## Primeira imagem que existir na lista de caminhos (ou null).
static func load_first(paths: Array) -> Texture2D:
	for p in paths:
		if ResourceLoader.exists(str(p)):
			var t := load(str(p)) as Texture2D
			if t != null:
				return t
	return null

## Primeira textura não nula da lista (ou null).
static func first_of(textures: Array) -> Texture2D:
	for t in textures:
		if t != null:
			return t
	return null

## Mostra a imagem; com tex == null mostra a blocagem. Retorna true se a imagem está ativa.
static func show_image(view: Control, bg: TextureRect, tex: Texture2D) -> bool:
	bg.texture = tex
	bg.visible = tex != null
	view.custom_minimum_size.y = IMAGE_HEIGHT if tex != null else BLOCK_HEIGHT
	for child in view.get_children():
		if child is ColorRect and not child.has_meta("keep"):
			child.visible = (tex == null)
	return tex != null

## Deixa um texto legível sobre qualquer imagem (branco com contorno preto).
static func style_label_for_art(label: Label) -> void:
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
