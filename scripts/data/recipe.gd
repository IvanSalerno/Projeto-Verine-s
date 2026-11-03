class_name Recipe
extends RefCounted
## Dados ORIGINAIS da receita. Nunca são alterados durante um atendimento:
## dados recuperados ficam em Game.recovered e quantidades ajustadas em AdjustedRecipe.

var id: String
var display_name: String
var description: String
var base_servings: int = 4
var price_per_serving_cents: int = 0
var prep_time_sec: int = 0                 # reservado para a mecânica de tempo
var unlocked_by_default: bool = true
var steps: Array[String] = []
var clue_ids: Array[String] = []           # preenchido a partir de Clue.recipe_ids
var challenge_ids: Array[String] = []      # desafios de recuperação de dados
## Cada linha: {ingredient_id: String, amount: float, unit: Units.Unit, hidden: bool}
## hidden = true -> dado deteriorado/ilegível; "amount" guarda o valor verdadeiro.
var lines: Array[Dictionary] = []

func add_line(ingredient_id: String, amount: float, unit: Units.Unit, hidden: bool = false) -> Recipe:
	lines.append({
		"ingredient_id": ingredient_id,
		"amount": amount,
		"unit": unit,
		"hidden": hidden,
	})
	return self

func get_line(ingredient_id: String) -> Dictionary:
	for line in lines:
		if line["ingredient_id"] == ingredient_id:
			return line
	return {}
