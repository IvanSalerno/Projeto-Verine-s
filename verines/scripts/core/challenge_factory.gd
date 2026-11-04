class_name ChallengeFactory
extends RefCounted
## Gera desafios matemáticos dinâmicos, sempre ligados a uma ação do restaurante.
## O nível (tier) sobe conforme os pedidos concluídos (ver Flow.current_tier()):
##   Nível 1: operações básicas (proporção direta, frações simples, troco, regra de três simples)
##   Nível 2: soma de frações, troco com bebida, comparação de preço por grama, capacidade de produção
##   Nível 3: fração de fração, porcentagem (desconto e lucro), custo proporcional, produto de matrizes

static func _roundup_note(total_cents: int) -> int:
	var given := int(ceil(total_cents / 1000.0)) * 1000
	if given == total_cents:
		given += 1000
	return given

static func _reward_discount(c: MathChallenge, percent: float) -> void:
	c.consequence = {"type": "purchase_discount", "percent": percent}
	c.success_feedback = "Ótima conta! Desconto de %d%% na próxima compra." % int(percent)

# ============================================================ PEDIDO (receita)

## Razão e proporção: ajustar a quantidade de um ingrediente ao nº de porções. (nível 1)
static func scaling(ing: Ingredient, unit: Units.Unit, base_amount: float, base_servings: int, servings: int) -> MathChallenge:
	var c := MathChallenge.new()
	c.id = "scale_" + ing.id
	c.tier = 1
	c.topic = "Razão e proporção"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Proporção direta"
	c.statement = "A receita usa %s %s de %s para %d porções.\nQuanto de %s é necessário para %d porções? (responda em %s)" % [
		Units.fmt_amount(base_amount), Units.label(unit), ing.display_name, base_servings,
		ing.display_name, servings, Units.label(unit)]
	c.expected = base_amount * servings / float(base_servings)
	c.tolerance = 0.01
	c.hint = "Descubra a quantidade para 1 porção (divisão) e multiplique pelo número de porções do pedido."
	c.success_feedback = "Correto! Quantidade ajustada para o pedido."
	c.consequence = {"type": "scale_line", "ingredient_id": ing.id}
	return c

## Capacidade de produção: quantas porções cabem num estoque. (nível 2+)
static func capacity(rng: RandomNumberGenerator, ing: Ingredient, unit: Units.Unit, base_amount: float, base_servings: int) -> MathChallenge:
	var per_serving := base_amount / float(base_servings)
	var k := rng.randi_range(3, 9)
	var stock := roundi(per_serving * k) + rng.randi_range(0, maxi(0, ceili(per_serving) - 1))
	var c := MathChallenge.new()
	c.id = "capacity_" + ing.id
	c.tier = 2
	c.topic = "Razão, proporção e divisão"
	c.type = MathChallenge.Type.INTEGER
	c.operation = "Divisão com parte inteira"
	c.statement = "Planejamento de produção: a receita usa %s %s de %s para %d porções.\nSe você tivesse apenas %d %s de %s, quantas porções COMPLETAS conseguiria fazer?" % [
		Units.fmt_amount(base_amount), Units.label(unit), ing.display_name, base_servings,
		stock, Units.label(unit), ing.display_name]
	c.expected = floori(stock / per_serving + 0.0001)
	c.hint = "Calcule a quantidade de 1 porção, divida o estoque por ela e fique só com a parte inteira."
	c.success_feedback = "Correto! Você sabe até quantas porções o estoque aguenta."
	c.consequence = {"type": "scale_line", "ingredient_id": ing.id}
	return c

## Custo proporcional de um ingrediente no pedido. (nível 3)
static func order_cost(ing: Ingredient, needed_base: int, servings: int) -> MathChallenge:
	var cost_cents := roundi(float(ing.pack_cost_cents) * needed_base / float(ing.pack_size))
	var c := MathChallenge.new()
	c.id = "cost_" + ing.id
	c.tier = 3
	c.topic = "Regra de três e aritmética financeira"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Regra de três com valores decimais"
	c.statement = "Custo do pedido: um pacote de %d %s de %s custa %s.\nEste pedido (%d porções) usa %d %s. Quanto custa a quantidade usada? (em reais; arredonde para os centavos)" % [
		ing.pack_size, Units.label(ing.unit), ing.display_name, Money.format(ing.pack_cost_cents),
		servings, needed_base, Units.label(ing.unit)]
	c.expected = cost_cents / 100.0
	c.tolerance = 0.0101
	c.hint = "Preço por unidade = preço do pacote ÷ tamanho do pacote. Multiplique pela quantidade usada."
	c.success_feedback = "Correto! Agora você sabe quanto esse ingrediente pesa no custo do prato."
	c.consequence = {"type": "scale_line", "ingredient_id": ing.id}
	return c

# ================================================================== ENTREGA

## Frações: parte do prato. (níveis 1 a 3)
static func fraction_portion(rng: RandomNumberGenerator, tier: int) -> MathChallenge:
	var c := MathChallenge.new()
	c.id = "portion"
	c.tier = tier
	c.topic = "Frações"
	c.type = MathChallenge.Type.FRACTION
	c.hint = "Frações equivalentes também valem (ex.: 6/8 = 3/4)."
	c.success_feedback = "Correto! Prato dividido."
	c.consequence = {"type": "delivery_step", "step": "portion"}
	if tier <= 1:
		var options := [6, 8, 10, 12]
		var slices: int = options[rng.randi() % options.size()]
		var served := rng.randi_range(1, slices - 1)
		c.operation = "Representação de parte de um todo"
		c.statement = "Você cortou o prato em %d pedaços iguais e %d já foram servidos à mesa.\nQue fração do prato foi servida? (ex.: 3/8)" % [slices, served]
		c.expected = [served, slices]
	elif tier == 2:
		var pairs := [[1, 2, 1, 4], [1, 3, 1, 6], [1, 4, 1, 2], [1, 6, 1, 3], [1, 2, 1, 6], [1, 3, 1, 4]]
		var p: Array = pairs[rng.randi() % pairs.size()]
		c.operation = "Soma de frações com denominadores diferentes"
		c.statement = "Dois clientes dividem um prato: o primeiro comeu %d/%d do prato e o segundo comeu %d/%d.\nQue fração do prato foi comida ao todo? (ex.: 3/4)" % [p[0], p[1], p[2], p[3]]
		c.expected = [p[0] * p[3] + p[2] * p[1], p[1] * p[3]]
		c.hint = "Encontre um denominador comum antes de somar. Frações equivalentes também valem."
	else:
		var sets := [[3, 4, 2, 3], [2, 3, 3, 4], [3, 5, 5, 6], [4, 5, 5, 8], [2, 3, 3, 8], [3, 4, 4, 9]]
		var s: Array = sets[rng.randi() % sets.size()]
		c.operation = "Multiplicação de frações"
		c.statement = "Sobrou %d/%d do prato. O cliente levou %d/%d do que sobrou para viagem.\nQue fração do prato INTEIRO ele levou? (ex.: 1/2)" % [s[0], s[1], s[2], s[3]]
		c.expected = [s[0] * s[2], s[1] * s[3]]
		c.hint = "\"Fração de uma fração\" é multiplicação: multiplique numeradores e denominadores."
	return c

## Aritmética financeira: troco. (níveis 1 a 3)
static func change(rng: RandomNumberGenerator, bill_cents: int, tier: int) -> MathChallenge:
	var c := MathChallenge.new()
	c.id = "change"
	c.tier = tier
	c.topic = "Aritmética financeira"
	c.type = MathChallenge.Type.DECIMAL
	c.tolerance = 0.001
	c.success_feedback = "Troco correto!"
	c.consequence = {"type": "delivery_step", "step": "change"}
	var total := bill_cents
	if tier <= 1:
		var given := _roundup_note(total)
		c.operation = "Subtração com valores decimais"
		c.statement = "A conta foi de %s e o cliente pagou com %s.\nQuanto de troco você deve devolver? (em reais, ex.: 12,50)" % [
			Money.format(total), Money.format(given)]
		c.expected = (given - total) / 100.0
		c.hint = "Troco = valor pago − valor da conta."
	elif tier == 2:
		var drinks := [400, 500, 600, 800]
		var drink: int = drinks[rng.randi() % drinks.size()]
		total = bill_cents + drink
		var given2 := _roundup_note(total)
		c.operation = "Adição e subtração com valores decimais"
		c.statement = "O prato custou %s e o cliente também pediu uma bebida de %s.\nEle pagou a conta com %s. Quanto de troco você deve devolver? (em reais)" % [
			Money.format(bill_cents), Money.format(drink), Money.format(given2)]
		c.expected = (given2 - total) / 100.0
		c.hint = "Some o prato e a bebida primeiro; depois subtraia do valor pago."
	else:
		var percents := [10, 20, 25]
		var pct: int = percents[rng.randi() % percents.size()]
		var discount := roundi(bill_cents * pct / 100.0)
		total = bill_cents - discount
		var given3 := _roundup_note(total)
		c.operation = "Porcentagem (desconto) e subtração"
		c.statement = "O prato custa %s, mas o cliente tem um cupom de %d%% de desconto.\nEle pagou com %s. Quanto de troco você deve devolver? (em reais)" % [
			Money.format(bill_cents), pct, Money.format(given3)]
		c.expected = (given3 - total) / 100.0
		c.hint = "Calcule %d%% da conta, subtraia o desconto e só então calcule o troco." % pct
	return c

# =============================================================== PLANEJAMENTO

## Desafio de compras (Administração): matéria sorteada do nível; recompensa = desconto.
static func planning(rng: RandomNumberGenerator, tier: int) -> MathChallenge:
	var c := MathTopics.random(rng, tier)
	var discounts := [10.0, 15.0, 20.0]
	_reward_discount(c, discounts[clampi(tier, 1, 3) - 1])
	return c

## Desafio de gestão do fim do dia: recompensa = bônus em dinheiro + pontos.
static func daily(rng: RandomNumberGenerator, tier: int, history: Array) -> MathChallenge:
	var c := MathTopics.random(rng, tier, history, true)
	var t := clampi(tier, 1, 3)
	var cents: int = [500, 800, 1200][t - 1]
	var points: int = 30 * t
	c.consequence = {"type": "management_bonus", "cents": cents, "points": points}
	c.success_feedback = "Excelente gestão! Bônus de %s e +%d pontos." % [Money.format(cents), points]
	return c

## Regra de três simples (nível 1).
static func rule_of_three(rng: RandomNumberGenerator) -> MathChallenge:
	var packs := [250, 500, 1000]
	var costs := [400, 600, 800, 1200]
	var pack: int = packs[rng.randi() % packs.size()]
	var cost: int = costs[rng.randi() % costs.size()]
	var wanted := int(pack * 1.5)
	var c := MathChallenge.new()
	c.id = "rule_of_three"
	c.tier = 1
	c.topic = "Regra de três"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Regra de três simples"
	c.statement = "Um pacote com %d g de um ingrediente custa %s.\nMantendo o mesmo preço por grama, quanto custam %d g? (em reais)" % [
		pack, Money.format(cost), wanted]
	c.expected = cost * 1.5 / 100.0
	c.tolerance = 0.001
	c.hint = "Monte a proporção: %d g está para %s assim como %d g está para x." % [pack, Money.format(cost), wanted]
	_reward_discount(c, 10.0)
	return c

## Regra de três com quantidades "quebradas" (nível 2).
static func rule_of_three_hard(rng: RandomNumberGenerator) -> MathChallenge:
	var sets := [[300, 750, 800], [400, 600, 1000], [250, 500, 700], [600, 900, 1000]]
	var s: Array = sets[rng.randi() % sets.size()]
	var c := MathChallenge.new()
	c.id = "rule_of_three_hard"
	c.tier = 2
	c.topic = "Regra de três"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Regra de três com taxa unitária"
	c.statement = "Um pacote com %d g de um ingrediente custa %s.\nMantendo o mesmo preço por grama, quanto custam %d g? (em reais)" % [
		s[0], Money.format(s[1]), s[2]]
	c.expected = float(s[1]) * float(s[2]) / float(s[0]) / 100.0
	c.tolerance = 0.001
	c.hint = "Descubra o preço de 1 g (divisão) e multiplique por %d." % s[2]
	_reward_discount(c, 15.0)
	return c

## Comparação de preço por grama (múltipla escolha, nível 2).
static func unit_price_compare(rng: RandomNumberGenerator) -> MathChallenge:
	var per100: Array = [120, 140, 160, 180, 200, 220, 240]   # centavos por 100 g
	per100.shuffle()
	var sizes := [250, 500, 1000]
	var letters := ["A", "B", "C"]
	var c := MathChallenge.new()
	c.id = "unit_price"
	c.tier = 2
	c.topic = "Razão e comparação"
	c.type = MathChallenge.Type.MULTIPLE_CHOICE
	c.operation = "Comparação de razões (preço por grama)"
	var lines: PackedStringArray = []
	var best := 0
	for i in 3:
		var cost := roundi(float(sizes[i]) * float(per100[i]) / 100.0)
		var text := "Pacote %s: %d g por %s" % [letters[i], sizes[i], Money.format(cost)]
		c.choices.append(text)
		lines.append(text)
		if per100[i] < per100[best]:
			best = i
	c.statement = "O fornecedor vende o mesmo ingrediente em três pacotes:\n%s\nQual pacote tem o MENOR preço por grama?" % "\n".join(lines)
	c.expected = best
	c.hint = "Calcule o preço de 100 g de cada pacote (preço ÷ gramas × 100) e compare."
	_reward_discount(c, 15.0)
	return c

## Porcentagem: lucro sobre o custo (nível 3).
static func margin_percent(rng: RandomNumberGenerator) -> MathChallenge:
	var sets := [[400, 600, 50], [500, 600, 20], [800, 1000, 25], [600, 900, 50], [250, 300, 20]]
	var s: Array = sets[rng.randi() % sets.size()]
	var c := MathChallenge.new()
	c.id = "margin_percent"
	c.tier = 3
	c.topic = "Porcentagem"
	c.type = MathChallenge.Type.INTEGER
	c.operation = "Variação percentual"
	c.statement = "Uma porção custa %s em ingredientes e é vendida por %s.\nQual é o lucro em porcentagem sobre o custo? (só o número, ex.: 50)" % [
		Money.format(s[0]), Money.format(s[1])]
	c.expected = s[2]
	c.hint = "Lucro = venda − custo. Porcentagem = lucro ÷ custo × 100."
	_reward_discount(c, 20.0)
	return c

## Matrizes: custo por prato = matriz de quantidades × vetor de preços (nível 1).
static func cost_matrix(rng: RandomNumberGenerator) -> MathChallenge:
	var q: Array = []
	for r in 2:
		var row: Array = []
		for k in 3:
			row.append(rng.randi_range(1, 3))
		q.append(row)
	var prices: Array = []
	for k in 3:
		prices.append(rng.randi_range(2, 6))
	var expected: Array = []
	for r in 2:
		var total := 0.0
		for k in 3:
			total += float(q[r][k]) * float(prices[k])
		expected.append(total)
	var c := MathChallenge.new()
	c.id = "cost_matrix"
	c.tier = 1
	c.topic = "Matrizes"
	c.type = MathChallenge.Type.STRUCTURED
	c.operation = "Produto de matriz por vetor"
	c.statement = "Quantidades de pacotes por prato (linhas = pratos; colunas = Farinha, Ovos, Leite):\nBolo      [ %d  %d  %d ]\nPanqueca  [ %d  %d  %d ]\nPreço de cada pacote em R$ (Farinha, Ovos, Leite): [ %d  %d  %d ]\n\nCalcule o custo de cada prato (matriz × vetor de preços).\nResponda separando por ponto e vírgula: custo do Bolo; custo da Panqueca (ex.: 13; 14)" % [
		q[0][0], q[0][1], q[0][2], q[1][0], q[1][1], q[1][2], prices[0], prices[1], prices[2]]
	c.expected = expected
	c.tolerance = 0.001
	c.hint = "Custo do prato = soma de (quantidade × preço) de cada coluna da linha correspondente."
	_reward_discount(c, 10.0)
	return c

## Matrizes: produto de matriz 2×3 por matriz 3×2 (nível 3).
static func matrix_product(rng: RandomNumberGenerator) -> MathChallenge:
	var q: Array = []
	for r in 2:
		var row: Array = []
		for k in 3:
			row.append(rng.randi_range(1, 3))
		q.append(row)
	var p: Array = []
	for k in 3:
		var prow: Array = []
		for s in 2:
			prow.append(rng.randi_range(2, 6))
		p.append(prow)
	var expected: Array = []
	for r in 2:
		for s in 2:
			var total := 0.0
			for k in 3:
				total += float(q[r][k]) * float(p[k][s])
			expected.append(total)
	var c := MathChallenge.new()
	c.id = "matrix_product"
	c.tier = 3
	c.topic = "Matrizes"
	c.type = MathChallenge.Type.STRUCTURED
	c.operation = "Produto de matrizes"
	c.statement = "Quantidades de pacotes por prato (linhas: Bolo, Panqueca; colunas: Farinha, Ovos, Leite):\n[ %d  %d  %d ]\n[ %d  %d  %d ]\n\nPreço de cada pacote em R$ (linhas: Farinha, Ovos, Leite; colunas: Fornecedor A, Fornecedor B):\n[ %d  %d ]\n[ %d  %d ]\n[ %d  %d ]\n\nCalcule a matriz de custos (Quantidades × Preços): linhas = pratos, colunas = fornecedores.\nResponda em ordem de leitura (linha 1 e depois linha 2), separados por ponto e vírgula. Ex.: 13; 14; 15; 16" % [
		q[0][0], q[0][1], q[0][2], q[1][0], q[1][1], q[1][2],
		p[0][0], p[0][1], p[1][0], p[1][1], p[2][0], p[2][1]]
	c.expected = expected
	c.tolerance = 0.001
	c.hint = "Cada elemento = soma de (quantidade da linha × preço da coluna). Ex.: elemento 1 = linha 1 de Q × coluna 1 de P."
	_reward_discount(c, 20.0)
	return c
