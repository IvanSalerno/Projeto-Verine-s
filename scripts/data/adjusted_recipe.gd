class_name AdjustedRecipe
extends RefCounted
## Receita ajustada para UM pedido (porções do cliente). Não altera a receita original.

var recipe_id: String
var servings: int
var base_servings: int
## Cada linha: {ingredient_id, amount (na unidade da receita), unit, base_needed (int, unidade base), known}
var lines: Array[Dictionary] = []

static func build(recipe: Recipe, p_servings: int, recovered: Dictionary) -> AdjustedRecipe:
	var a := AdjustedRecipe.new()
	a.recipe_id = recipe.id
	a.servings = p_servings
	a.base_servings = recipe.base_servings
	for line in recipe.lines:
		var ing_id: String = line["ingredient_id"]
		var unit: Units.Unit = line["unit"]
		var ing: Ingredient = GameData.ingredients[ing_id]
		if not Units.compatible(unit, ing.unit):
			push_error("Unidade incompatível em %s / %s" % [recipe.id, ing_id])
		var known := true
		var base_amount: float = line["amount"]
		if line["hidden"]:
			known = recovered.has(recipe.id) and recovered[recipe.id].has(ing_id)
			if known:
				base_amount = recovered[recipe.id][ing_id]
		var scaled := 0.0
		var needed := 0
		if known:
			scaled = base_amount * p_servings / float(recipe.base_servings)
			needed = ceili(Units.to_base(scaled, unit))
		a.lines.append({
			"ingredient_id": ing_id,
			"amount": scaled,
			"unit": unit,
			"base_needed": needed,
			"known": known,
		})
	return a

func is_complete() -> bool:
	for line in lines:
		if not line["known"]:
			return false
	return true
