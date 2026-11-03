extends Node
## Estado persistente da partida (autoload "Game"). Toda alteração de dinheiro e
## estoque passa por aqui (regra 10 de integridade).

signal money_changed(new_balance: int)
signal inventory_changed
signal upgrade_purchased(upgrade_id: String)
signal recipe_unlocked(recipe_id: String)

const STARTING_MONEY := 5000   # R$ 50,00

var money_cents: int = 0
var inventory: Dictionary = {}                 # ingredient_id -> int (unidade base)
var unlocked_recipes: Array[String] = []
var recovered: Dictionary = {}                 # recipe_id -> {ingredient_id -> float}
var purchased_upgrades: Array[String] = []
var ledger: Array[Dictionary] = []             # {kind, cents, reason}
var orders_completed: int = 0
var total_income: int = 0
var total_expenses: int = 0
var next_purchase_discount_percent: float = 0.0

func new_game() -> void:
	money_cents = STARTING_MONEY
	inventory.clear()
	unlocked_recipes.clear()
	recovered.clear()
	purchased_upgrades.clear()
	ledger.clear()
	orders_completed = 0
	total_income = 0
	total_expenses = 0
	next_purchase_discount_percent = 0.0
	for id in GameData.ingredients:
		inventory[id] = 0
	inventory["farinha"] = 1000
	inventory["ovo"] = 6
	inventory["leite"] = 1000
	inventory["acucar"] = 500
	for rid in GameData.recipes:
		var r: Recipe = GameData.recipes[rid]
		if r.unlocked_by_default:
			unlocked_recipes.append(rid)
	money_changed.emit(money_cents)
	inventory_changed.emit()

# ---------------------------------------------------------------------- dinheiro
func add_money(cents: int, reason: String) -> void:
	if cents <= 0:
		return
	money_cents += cents
	total_income += cents
	ledger.append({"kind": "entrada", "cents": cents, "reason": reason})
	money_changed.emit(money_cents)

## Retorna false (sem alterar nada) se não houver saldo suficiente.
func spend_money(cents: int, reason: String) -> bool:
	if cents < 0 or cents > money_cents:
		return false
	money_cents -= cents
	total_expenses += cents
	ledger.append({"kind": "saida", "cents": cents, "reason": reason})
	money_changed.emit(money_cents)
	return true

func profit() -> int:
	return total_income - total_expenses

# ----------------------------------------------------------------------- estoque
func get_stock(ingredient_id: String) -> int:
	return int(inventory.get(ingredient_id, 0))

func get_storage_limit(ingredient_id: String) -> int:
	var ing: Ingredient = GameData.ingredients[ingredient_id]
	if ing.storage_limit <= 0:
		return 0
	return int(ing.storage_limit * (1.0 + get_effect_total("storage_percent") / 100.0))

func needs_restock(ingredient_id: String) -> bool:
	var ing: Ingredient = GameData.ingredients[ingredient_id]
	return get_stock(ingredient_id) <= ing.min_restock

func purchase_price(ingredient_id: String, packs: int) -> int:
	var ing: Ingredient = GameData.ingredients[ingredient_id]
	var base := ing.pack_cost_cents * packs
	var discount := get_effect_total("purchase_discount_percent") + next_purchase_discount_percent
	return roundi(base * (1.0 - minf(discount, 90.0) / 100.0))

func buy_ingredient(ingredient_id: String, packs: int) -> Dictionary:
	if packs <= 0 or not GameData.ingredients.has(ingredient_id):
		return {"ok": false, "message": "Compra inválida."}
	var ing: Ingredient = GameData.ingredients[ingredient_id]
	var added := ing.pack_size * packs
	var limit := get_storage_limit(ingredient_id)
	if limit > 0 and get_stock(ingredient_id) + added > limit:
		return {"ok": false, "message": "Sem espaço no estoque para %s." % ing.display_name}
	var price := purchase_price(ingredient_id, packs)
	if not spend_money(price, "Compra: %d× %s" % [packs, ing.display_name]):
		return {"ok": false, "message": "Saldo insuficiente (%s)." % Money.format(price)}
	inventory[ingredient_id] = get_stock(ingredient_id) + added
	next_purchase_discount_percent = 0.0   # desconto temporário usado uma única vez
	inventory_changed.emit()
	return {"ok": true, "message": "Comprado: %s por %s." % [ing.display_name, Money.format(price)]}

## {"ok": bool, "missing": [{ingredient_id, missing}]}
func has_ingredients(adjusted: AdjustedRecipe) -> Dictionary:
	var missing: Array[Dictionary] = []
	for line in adjusted.lines:
		var need: int = line["base_needed"]
		var have := get_stock(line["ingredient_id"])
		if have < need:
			missing.append({"ingredient_id": line["ingredient_id"], "missing": need - have})
	return {"ok": missing.is_empty(), "missing": missing}

func consume_ingredients(adjusted: AdjustedRecipe) -> bool:
	if not has_ingredients(adjusted)["ok"]:
		return false
	for line in adjusted.lines:
		var iid: String = line["ingredient_id"]
		inventory[iid] = maxi(0, get_stock(iid) - int(line["base_needed"]))
	inventory_changed.emit()
	return true

# ----------------------------------------------------------------------- receitas
func is_recipe_unlocked(recipe_id: String) -> bool:
	return recipe_id in unlocked_recipes

func unlock_recipe(recipe_id: String) -> void:
	if not is_recipe_unlocked(recipe_id):
		unlocked_recipes.append(recipe_id)
		recipe_unlocked.emit(recipe_id)

## Guarda o dado recuperado SEM alterar a receita original.
func recover_line(recipe_id: String, ingredient_id: String, amount: float) -> void:
	if not recovered.has(recipe_id):
		recovered[recipe_id] = {}
	recovered[recipe_id][ingredient_id] = amount

func is_line_known(recipe: Recipe, line: Dictionary) -> bool:
	if not line["hidden"]:
		return true
	return recovered.has(recipe.id) and recovered[recipe.id].has(line["ingredient_id"])

## Quantidade conhecida pelo jogador (receita para as porções-base) ou -1.0 se ilegível.
func get_known_amount(recipe: Recipe, line: Dictionary) -> float:
	if not line["hidden"]:
		return line["amount"]
	if is_line_known(recipe, line):
		return recovered[recipe.id][line["ingredient_id"]]
	return -1.0

# ---------------------------------------------------------------------- melhorias
func get_effect_total(effect_type: String) -> float:
	var total := 0.0
	for uid in purchased_upgrades:
		var u: Upgrade = GameData.upgrades[uid]
		if u.effect.get("type", "") == effect_type:
			total += float(u.effect.get("value", 0.0))
	return total

func can_buy_upgrade(upgrade_id: String) -> Dictionary:
	var u: Upgrade = GameData.upgrades[upgrade_id]
	if upgrade_id in purchased_upgrades:
		return {"ok": false, "reason": "Já adquirida."}
	for pre in u.prerequisites:
		if not (pre in purchased_upgrades):
			var pre_up: Upgrade = GameData.upgrades[pre]
			return {"ok": false, "reason": "Requer: %s" % pre_up.display_name}
	if money_cents < u.cost_cents:
		return {"ok": false, "reason": "Saldo insuficiente."}
	return {"ok": true, "reason": ""}

func buy_upgrade(upgrade_id: String) -> Dictionary:
	var check := can_buy_upgrade(upgrade_id)
	if not check["ok"]:
		return {"ok": false, "message": check["reason"]}
	var u: Upgrade = GameData.upgrades[upgrade_id]
	if not spend_money(u.cost_cents, "Melhoria: " + u.display_name):
		return {"ok": false, "message": "Saldo insuficiente."}
	purchased_upgrades.append(upgrade_id)
	upgrade_purchased.emit(upgrade_id)
	inventory_changed.emit()
	return {"ok": true, "message": "Melhoria adquirida: %s." % u.display_name}
