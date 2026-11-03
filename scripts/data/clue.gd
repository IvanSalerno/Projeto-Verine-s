class_name Clue
extends RefCounted
## Pista associada a uma ou mais receitas (a solução vem dos dados, não do texto).

var id: String
var text: String
var recipe_ids: Array[String] = []

func _init(p_id: String, p_text: String, p_recipes: Array) -> void:
	id = p_id
	text = p_text
	recipe_ids.assign(p_recipes)
