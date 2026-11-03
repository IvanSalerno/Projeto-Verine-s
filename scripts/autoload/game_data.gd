extends Node
## Catálogo do jogo (autoload "GameData"): ingredientes, receitas, pistas, desafios,
## melhorias, pedidos e notas da história. O catálogo definitivo deve ser ampliado pela equipe.

var ingredients: Dictionary = {}   # id -> Ingredient
var recipes: Dictionary = {}       # id -> Recipe
var clues: Dictionary = {}         # id -> Clue
var challenges: Dictionary = {}    # id -> MathChallenge (modelos; use clone())
var upgrades: Dictionary = {}      # id -> Upgrade
var order_templates: Array[Dictionary] = []
var story_notes: Array[Dictionary] = []

func _ready() -> void:
	_build_ingredients()
	_build_recipes()
	_build_clues()
	_link_clues_to_recipes()
	_build_challenges()
	_build_upgrades()
	_build_orders()
	_build_story()
	_validate_data()

# ---------------------------------------------------------------- ingredientes
func _add_ingredient(id: String, nm: String, unit: Units.Unit, pack_size: int, cost: int,
		category: String, limit: int, min_stock: int) -> void:
	ingredients[id] = Ingredient.new(id, nm, unit, pack_size, cost, category, limit, min_stock)

func _build_ingredients() -> void:
	_add_ingredient("farinha", "Farinha", Units.Unit.G, 1000, 600, "Secos", 5000, 300)
	_add_ingredient("acucar", "Açúcar", Units.Unit.G, 1000, 450, "Secos", 5000, 300)
	_add_ingredient("macarrao", "Macarrão", Units.Unit.G, 500, 600, "Secos", 3000, 250)
	_add_ingredient("molho_tomate", "Molho de tomate", Units.Unit.G, 500, 700, "Molhos", 3000, 200)
	_add_ingredient("queijo", "Queijo", Units.Unit.G, 500, 1800, "Laticínios", 2000, 150)
	_add_ingredient("leite", "Leite", Units.Unit.ML, 1000, 500, "Laticínios", 5000, 300)
	_add_ingredient("ovo", "Ovos", Units.Unit.UN, 12, 900, "Frescos", 36, 4)

# -------------------------------------------------------------------- receitas
func _add_recipe(id: String, nm: String, desc: String, base: int, price: int,
		steps: Array, unlocked: bool = true) -> Recipe:
	var r := Recipe.new()
	r.id = id
	r.display_name = nm
	r.description = desc
	r.base_servings = base
	r.price_per_serving_cents = price
	r.steps.assign(steps)
	r.unlocked_by_default = unlocked
	recipes[id] = r
	return r

func _build_recipes() -> void:
	_add_recipe("bolo", "Bolo da Vovó", "Bolo simples e fofinho, clássico da casa.", 4, 800,
		["Separar os ingredientes", "Misturar a massa", "Assar no forno", "Finalizar", "Servir"]) \
		.add_line("farinha", 200, Units.Unit.G) \
		.add_line("ovo", 2, Units.Unit.UN) \
		.add_line("leite", 100, Units.Unit.ML) \
		.add_line("acucar", 150, Units.Unit.G)

	_add_recipe("lasanha", "Lasanha de Forno", "Massa em camadas com molho e queijo gratinado.", 4, 1500,
		["Separar os ingredientes", "Montar as camadas", "Assar no forno", "Finalizar", "Servir"]) \
		.add_line("macarrao", 250, Units.Unit.G) \
		.add_line("molho_tomate", 200, Units.Unit.G) \
		.add_line("queijo", 150, Units.Unit.G, true)   # página manchada: dado ilegível

	_add_recipe("macarrao_ao_molho", "Macarrão ao Molho", "Massa cozida na panela com molho de tomate.", 2, 1000,
		["Separar os ingredientes", "Cozinhar a massa", "Aquecer o molho", "Misturar", "Servir"]) \
		.add_line("macarrao", 200, Units.Unit.G) \
		.add_line("molho_tomate", 150, Units.Unit.G) \
		.add_line("queijo", 40, Units.Unit.G)

	_add_recipe("panqueca", "Panqueca Recheada", "Massa fina feita na frigideira e enrolada com recheio.", 2, 700,
		["Separar os ingredientes", "Misturar a massa", "Fritar na frigideira", "Rechear e enrolar", "Servir"]) \
		.add_line("farinha", 100, Units.Unit.G) \
		.add_line("ovo", 1, Units.Unit.UN) \
		.add_line("leite", 200, Units.Unit.ML)

	_add_recipe("pudim_verine", "Pudim do Verine", "Receita antiga do avô, página parcialmente apagada.", 4, 1800,
		["Separar os ingredientes", "Fazer a calda", "Bater a mistura", "Assar em banho-maria", "Servir"], false) \
		.add_line("leite", 500, Units.Unit.ML) \
		.add_line("ovo", 3, Units.Unit.UN) \
		.add_line("acucar", 200, Units.Unit.G, true)

# ---------------------------------------------------------------------- pistas
func _add_clue(id: String, text: String, recipe_ids: Array) -> void:
	clues[id] = Clue.new(id, text, recipe_ids)

func _build_clues() -> void:
	_add_clue("c_doce", "Prato doce, servido de sobremesa.", ["bolo", "pudim_verine"])
	_add_clue("c_forno", "Vai ao forno.", ["bolo", "lasanha"])
	_add_clue("c_massa_assada", "Massa assada.", ["lasanha"])
	_add_clue("c_molho_tomate", "Leva molho de tomate.", ["lasanha", "macarrao_ao_molho"])
	_add_clue("c_queijo_gratinado", "Queijo derretido por cima.", ["lasanha"])
	_add_clue("c_camadas", "É montado em camadas.", ["lasanha"])
	_add_clue("c_massa_cozida", "Massa cozida na panela.", ["macarrao_ao_molho"])
	_add_clue("c_sem_forno", "Não precisa de forno.", ["macarrao_ao_molho", "panqueca"])
	_add_clue("c_massa_fina", "Massa bem fina e leve.", ["panqueca"])
	_add_clue("c_recheio", "É enrolado com recheio.", ["panqueca"])
	_add_clue("c_frigideira", "Feito na frigideira.", ["panqueca"])
	_add_clue("c_doce_domingo", "Era o doce de domingo do Verine.", ["pudim_verine"])
	_add_clue("c_cremoso", "Textura cremosa que balança no prato.", ["pudim_verine"])
	_add_clue("c_calda", "Coberto com calda dourada.", ["pudim_verine"])

func _link_clues_to_recipes() -> void:
	for cid in clues:
		var clue: Clue = clues[cid]
		for rid in clue.recipe_ids:
			var r: Recipe = recipes[rid]
			if not (cid in r.clue_ids):
				r.clue_ids.append(cid)

# ------------------------------------------------------------------- desafios
func _build_challenges() -> void:
	# Recuperação de dado ilegível: queijo da lasanha (razão e proporção).
	var c := MathChallenge.new()
	c.id = "rec_lasanha_queijo"
	c.topic = "Razão e proporção"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Proporção direta"
	c.statement = "Uma mancha cobriu a quantidade de queijo da Lasanha de Forno (receita para 4 porções).\nUma anotação do vovô diz: \"para 2 porções eu usava 75 g de queijo\".\nQuantos gramas de queijo a receita pede para 4 porções?"
	c.expected = 150.0
	c.tolerance = 0.01
	c.hint = "4 porções é o dobro de 2 porções."
	c.success_feedback = "Dado recuperado! O livro de receitas foi atualizado."
	c.consequence = {"type": "recover_line", "recipe_id": "lasanha", "ingredient_id": "queijo", "amount": 150.0}
	challenges[c.id] = c
	recipes["lasanha"].challenge_ids.append(c.id)

	# Recuperação: açúcar do pudim (fração de uma quantidade).
	var d := MathChallenge.new()
	d.id = "rec_pudim_acucar"
	d.topic = "Frações"
	d.type = MathChallenge.Type.INTEGER
	d.operation = "Fração de uma quantidade"
	d.statement = "A página do Pudim do Verine está apagada no trecho do açúcar.\nA nota na margem diz: \"o açúcar é 2/5 do volume de leite (considere 1 ml = 1 g)\".\nA receita leva 500 ml de leite. Quantos gramas de açúcar ela pede?"
	d.expected = 200
	d.hint = "Calcule 500 ÷ 5 e depois multiplique por 2."
	d.success_feedback = "Dado recuperado! Mais uma página do livro foi restaurada."
	d.consequence = {"type": "recover_line", "recipe_id": "pudim_verine", "ingredient_id": "acucar", "amount": 200.0}
	challenges[d.id] = d
	recipes["pudim_verine"].challenge_ids.append(d.id)

## Devolve uma cópia nova do desafio de recuperação da linha, ou null.
func make_recovery_challenge(recipe: Recipe, ingredient_id: String) -> MathChallenge:
	for cid in recipe.challenge_ids:
		var ch: MathChallenge = challenges[cid]
		if ch.consequence.get("ingredient_id", "") == ingredient_id:
			return ch.clone()
	return null

# ------------------------------------------------------------------- melhorias
func _build_upgrades() -> void:
	_add_upgrade(Upgrade.new("u_despensa", "Despensa maior", "+50% de capacidade de estoque.", 4000,
		{"type": "storage_percent", "value": 50.0}))
	_add_upgrade(Upgrade.new("u_fornecedor", "Fornecedor parceiro", "10% de desconto em todas as compras.", 3000,
		{"type": "purchase_discount_percent", "value": 10.0}))
	_add_upgrade(Upgrade.new("u_cartaz", "Cartaz na calçada", "+10% no valor dos atendimentos.", 2500,
		{"type": "price_bonus_percent", "value": 10.0}))
	_add_upgrade(Upgrade.new("u_vitrine", "Vitrine renovada", "+15% no valor dos atendimentos.", 6000,
		{"type": "price_bonus_percent", "value": 15.0}, ["u_cartaz"]))

func _add_upgrade(u: Upgrade) -> void:
	upgrades[u.id] = u

# --------------------------------------------------------------------- pedidos
## kind: Order.Kind. "tutorial" aparece só no primeiro atendimento.
func _build_orders() -> void:
	order_templates.append({"tutorial": true, "customer": "Dona Maria", "kind": Order.Kind.DIRECT,
		"text": "Bom dia! Quero um Bolo da Vovó, por favor. Para 4 pessoas.",
		"recipe_id": "bolo", "servings": 4})
	order_templates.append({"customer": "João", "kind": Order.Kind.DESCRIPTIVE, "min_completed": 1,
		"text": "Estou com vontade de uma massa assada, com molho de tomate e queijo derretido por cima. Para 4, por favor.",
		"recipe_id": "lasanha", "servings": 4,
		"clues": ["c_massa_assada", "c_molho_tomate", "c_queijo_gratinado"], "hidden_clues": ["c_camadas"]})
	order_templates.append({"customer": "Dona Rosa", "kind": Order.Kind.DESCRIPTIVE, "min_completed": 1,
		"text": "Quero uma massa fininha, enrolada com recheio. Para 2 pessoas.",
		"recipe_id": "panqueca", "servings": 2,
		"clues": ["c_massa_fina", "c_recheio"], "hidden_clues": ["c_frigideira"]})
	order_templates.append({"customer": "Seu Carlos", "kind": Order.Kind.DIRECT, "min_completed": 1,
		"text": "Um Macarrão ao Molho para 6 pessoas. Vim com a família toda!",
		"recipe_id": "macarrao_ao_molho", "servings": 6})
	order_templates.append({"customer": "Bia", "kind": Order.Kind.DIRECT, "min_completed": 1,
		"text": "Um Bolo da Vovó para 6 pessoas, por favor.",
		"recipe_id": "bolo", "servings": 6})
	order_templates.append({"customer": "Dona Lúcia", "kind": Order.Kind.ENIGMATIC, "min_completed": 2,
		"text": "Procuro um prato que não vai ao forno, é de massa e leva molho vermelho. Para 4 pessoas.",
		"recipe_id": "macarrao_ao_molho", "servings": 4,
		"clues": ["c_sem_forno", "c_molho_tomate"], "hidden_clues": ["c_massa_cozida"]})
	order_templates.append({"customer": "Sr. Tavares", "kind": Order.Kind.ENIGMATIC, "min_completed": 3,
		"text": "Meu pai vinha aqui todo domingo por causa de um doce que o Verine fazia. Cremoso, balançava no prato... Você sabe qual é? Para 4.",
		"recipe_id": "pudim_verine", "servings": 4,
		"clues": ["c_doce_domingo", "c_cremoso"], "hidden_clues": ["c_calda"]})

# ------------------------------------------------------------------- história
## TEXTOS PROVISÓRIOS: a sequência dos mistérios e o desfecho ainda serão definidos pela equipe.
func _build_story() -> void:
	story_notes.append({"at": 1, "text": "Entre as páginas do livro cai uma anotação: \"O segredo não está só na receita.\""})
	story_notes.append({"at": 3, "text": "A página do Pudim do Verine volta a ser legível. Por que o vovô a escondeu?"})
	story_notes.append({"at": 6, "text": "Um cliente antigo comenta que o vovô guardava algo no fundo da despensa."})
	story_notes.append({"at": 8, "text": "Você reconstruiu o restaurante. O mistério do livro ainda guarda uma última página..."})

func note_for(completed_count: int) -> String:
	for n in story_notes:
		if int(n["at"]) == completed_count:
			return str(n["text"])
	return ""

# ------------------------------------------------------------------ validação
func _validate_data() -> void:
	for rid in recipes:
		var r: Recipe = recipes[rid]
		for line in r.lines:
			var iid: String = line["ingredient_id"]
			if not ingredients.has(iid):
				push_error("Receita %s usa ingrediente inexistente: %s" % [rid, iid])
				continue
			var ing: Ingredient = ingredients[iid]
			if not Units.compatible(line["unit"], ing.unit):
				push_error("Unidade incompatível em %s / %s" % [rid, iid])
	for t in order_templates:
		if not recipes.has(t["recipe_id"]):
			push_error("Pedido aponta para receita inexistente: %s" % t["recipe_id"])
