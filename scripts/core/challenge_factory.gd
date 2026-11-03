class_name ChallengeFactory
extends RefCounted
## Gera desafios matemáticos dinâmicos, sempre ligados a uma ação do restaurante.

## Razão e proporção: ajustar a quantidade de um ingrediente ao nº de porções.
static func scaling(ing: Ingredient, unit: Units.Unit, base_amount: float, base_servings: int, servings: int) -> MathChallenge:
	var c := MathChallenge.new()
	c.id = "scale_" + ing.id
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

## Aritmética financeira: troco.
static func change(bill_cents: int, given_cents: int) -> MathChallenge:
	var c := MathChallenge.new()
	c.id = "change"
	c.topic = "Aritmética financeira"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Subtração com valores decimais"
	c.statement = "A conta foi de %s e o cliente pagou com %s.\nQuanto de troco você deve devolver? (em reais, ex.: 12,50)" % [
		Money.format(bill_cents), Money.format(given_cents)]
	c.expected = (given_cents - bill_cents) / 100.0
	c.tolerance = 0.001
	c.hint = "Troco = valor pago − valor da conta."
	c.success_feedback = "Troco correto!"
	c.consequence = {"type": "delivery_step", "step": "change"}
	return c

## Frações: parte do prato servida.
static func fraction_portion(rng: RandomNumberGenerator) -> MathChallenge:
	var options := [6, 8, 10, 12]
	var slices: int = options[rng.randi() % options.size()]
	var served := rng.randi_range(1, slices - 1)
	var c := MathChallenge.new()
	c.id = "portion"
	c.topic = "Frações"
	c.type = MathChallenge.Type.FRACTION
	c.operation = "Representação de parte de um todo"
	c.statement = "Você cortou o prato em %d pedaços iguais e %d já foram servidos à mesa.\nQue fração do prato foi servida? (ex.: 3/8)" % [slices, served]
	c.expected = [served, slices]
	c.hint = "Numerador = pedaços servidos; denominador = total de pedaços. Frações equivalentes também valem."
	c.success_feedback = "Correto! Prato dividido."
	c.consequence = {"type": "delivery_step", "step": "portion"}
	return c

## Regra de três aplicada a custos (planejamento de compras).
static func rule_of_three(rng: RandomNumberGenerator) -> MathChallenge:
	var packs := [250, 500, 1000]
	var costs := [400, 600, 800, 1200]
	var pack: int = packs[rng.randi() % packs.size()]
	var cost: int = costs[rng.randi() % costs.size()]
	var wanted := int(pack * 1.5)
	var c := MathChallenge.new()
	c.id = "rule_of_three"
	c.topic = "Regra de três"
	c.type = MathChallenge.Type.DECIMAL
	c.operation = "Regra de três simples"
	c.statement = "Um pacote com %d g de um ingrediente custa %s.\nMantendo o mesmo preço por grama, quanto custam %d g? (em reais)" % [
		pack, Money.format(cost), wanted]
	c.expected = cost * 1.5 / 100.0
	c.tolerance = 0.001
	c.hint = "Monte a proporção: %d g está para %s assim como %d g está para x." % [pack, Money.format(cost), wanted]
	c.success_feedback = "Ótima conta! Seu fornecedor deu 10% de desconto na próxima compra."
	c.consequence = {"type": "purchase_discount", "percent": 10.0}
	return c

## Matrizes: custo por prato = matriz de quantidades × vetor de preços.
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
	c.topic = "Matrizes"
	c.type = MathChallenge.Type.STRUCTURED
	c.operation = "Produto de matriz por vetor"
	c.statement = "Quantidades de pacotes por prato (linhas = pratos; colunas = Farinha, Ovos, Leite):\nBolo      [ %d  %d  %d ]\nPanqueca  [ %d  %d  %d ]\nPreço de cada pacote em R$ (Farinha, Ovos, Leite): [ %d  %d  %d ]\n\nCalcule o custo de cada prato (matriz × vetor de preços).\nResponda separando por ponto e vírgula: custo do Bolo; custo da Panqueca (ex.: 13; 14)" % [
		q[0][0], q[0][1], q[0][2], q[1][0], q[1][1], q[1][2], prices[0], prices[1], prices[2]]
	c.expected = expected
	c.tolerance = 0.001
	c.hint = "Custo do prato = soma de (quantidade × preço) de cada coluna da linha correspondente."
	c.success_feedback = "Correto! Seu fornecedor deu 10% de desconto na próxima compra."
	c.consequence = {"type": "purchase_discount", "percent": 10.0}
	return c
