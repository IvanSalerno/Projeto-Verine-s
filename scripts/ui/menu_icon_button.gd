class_name MenuIconButton
extends Button
## Botão com o símbolo de menu (três linhas) desenhado por código.

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(46, 40)

func _draw() -> void:
	var color := Color(0.95, 0.95, 0.95)
	var w := 22.0
	var x := (size.x - w) / 2.0
	var y0 := size.y / 2.0 - 8.0
	for i in 3:
		draw_rect(Rect2(x, y0 + i * 8.0, w, 3.0), color)
