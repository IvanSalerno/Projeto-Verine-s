class_name MathTopics
extends RefCounted
## Banco de matérias além de razão e proporção. Cada gerador devolve um MathChallenge
## pronto; a consequência (desconto, bônus) é definida por quem usa (ver ChallengeFactory).
## Matérias: unidades, geometria, estatística, probabilidade, análise combinatória,
## álgebra (equações, função, sistema), sequências, juros compostos, raiz quadrada, matrizes.

const POOLS := {
	1: ["rule_of_three", "cost_matrix", "unit_convert", "rect_area", "stat_mean", "equation1"],
	2: ["rule_of_three_hard", "unit_price_compare", "circle_area", "stat_median", "stat_mode",
		"prob_simple", "combos", "pa_sequence", "linear_function"],
	3: ["margin_percent", "matrix_product", "cylinder_volume", "weighted_mean", "prob_two",
		"system_2x2", "compound_interest", "sqrt_area", "combination_pairs"],
}

## Sorteia um desafio do nível pedido (65% do próprio nível, 35% de níveis anteriores).
static func random(rng: RandomNumberGenerator, tier: int, history: Array = [], include_history: bool = false) -> MathChallenge:
	var t := clampi(tier, 1, 3)
	if include_history and history.size() >= 2 and rng.randf() < 0.5:
		return stat_mean_history(history)
	var ids: Array = []
	if rng.randf() < 0.65:
		ids = POOLS[t]
	else:
		for k in range(1, t + 1):
			ids.append_array(POOLS[k])
	return make(str(ids[rng.randi() % ids.size()]), rng)

static func make(id: String, rng: RandomNumberGenerator) -> MathChallenge:
	match id:
		"rule_of_three": return ChallengeFactory.rule_of_three(rng)
		"cost_matrix": return ChallengeFactory.cost_matrix(rng)
		"rule_of_three_hard": return ChallengeFactory.rule_of_three_hard(rng)
		"unit_price_compare": return ChallengeFactory.unit_price_compare(rng)
		"margin_percent": return ChallengeFactory.margin_percent(rng)
		"matrix_product": return ChallengeFactory.matrix_product(rng)
		"unit_convert": return unit_convert(rng)
		"rect_area": return rect_area(rng)
		"stat_mean": return stat_mean(rng)
		"equation1": return equation1(rng)
		"circle_area": return circle_area(rng)
		"stat_median": return stat_median(rng)
		"stat_mode": return stat_mode(rng)
		"prob_simple": return prob_simple(rng)
		"combos": return combos(rng)
		"pa_sequence": return pa_sequence(rng)
		"linear_function": return linear_function(rng)
		"cylinder_volume": return cylinder_volume(rng)
		"weighted_mean": return weighted_mean(rng)
		"prob_two": return prob_two(rng)
		"system_2x2": return system_2x2(rng)
		"compound_interest": return compound_interest(rng)
		"sqrt_area": return sqrt_area(rng)
		"combination_pairs": return combination_pairs(rng)
	return ChallengeFactory.rule_of_three(rng)

# ------------------------------------------------------------------ helpers
static func _base(id: String, tier: int, topic: String, type: MathChallenge.Type, operation: String) -> MathChallenge:
	var c := MathChallenge.new()
	c.id = id
	c.tier = tier
	c.topic = topic
	c.type = type
	c.operation = operation
	c.tolerance = 0.01
	c.consequence = {"type": "purchase_discount", "percent": 10.0}
	return c

static func _join(values: Array, sep: String = ", ") -> String:
	var parts: PackedStringArray = []
	for v in values:
		parts.append(str(v))
	return sep.join(parts)

# ------------------------------------------------------------------ nível 1
static func unit_convert(rng: RandomNumberGenerator) -> MathChallenge:
	var c := _base("unit_convert", 1, "Unidades de medida", MathChallenge.Type.DECIMAL, "Conversão de unidades")
	var kind := rng.randi() % 3
	if kind == 0:
		var values := [0.5, 0.75, 1.2, 2.5]
		var v: float = values[rng.randi() % values.size()]
		c.statement = "A receita pede %s kg de farinha. Quantos gramas são?" % Units.fmt_amount(v)
		c.expected = v * 1000.0
		c.hint = "1 kg = 1000 g."
	elif kind == 1:
		var values2 := [0.25, 0.5, 1.5, 2.0]
		var v2: float = values2[rng.randi() % values2.size()]
		c.statement = "Você comprou %s L de leite. Quantos mililitros são?" % Units.fmt_amount(v2)
		c.expected = v2 * 1000.0
		c.hint = "1 L = 1000 ml."
	else:
		var values3 := [0.75, 1.5, 2.5]
		var v3: float = values3[rng.randi() % values3.size()]
		c.statement = "O forno precisa ficar ligado por %s h. Quantos minutos são?" % Units.fmt_amount(v3)
		c.expected = v3 * 60.0
		c.hint = "1 hora = 60 minutos."
	return c

static func rect_area(rng: RandomNumberGenerator) -> MathChallenge:
	var w := rng.randi_range(2, 6)
	var l := rng.randi_range(w + 1, 9)
	var c := _base("rect_area", 1, "Geometria", MathChallenge.Type.INTEGER, "Área e perímetro de retângulo")
	if rng.randi() % 2 == 0:
		c.statement = "A bancada da cozinha mede %d m de comprimento por %d m de largura.\nQual é a área da bancada, em m²?" % [l, w]
		c.expected = l * w
		c.hint = "Área do retângulo = comprimento × largura."
	else:
		c.statement = "Você vai colocar uma toalha de renda ao redor de uma mesa retangular de %d m por %d m.\nQuantos metros de renda são necessários para dar uma volta completa (perímetro)?" % [l, w]
		c.expected = 2 * (l + w)
		c.hint = "Perímetro = soma de todos os lados = 2 × (comprimento + largura)."
	return c

static func stat_mean(rng: RandomNumberGenerator) -> MathChallenge:
	var mu := rng.randi_range(14, 25)
	var vals: Array = []
	var total := 0
	for i in 4:
		var v := mu + rng.randi_range(-3, 3)
		vals.append(v)
		total += v
	vals.append(mu * 5 - total)
	vals.shuffle()
	var c := _base("stat_mean", 1, "Estatística", MathChallenge.Type.INTEGER, "Média aritmética")
	c.statement = "Pratos vendidos nos últimos 5 dias: %s.\nQual foi a média diária de pratos vendidos?" % _join(vals)
	c.expected = mu
	c.hint = "Média = soma dos valores ÷ quantidade de valores."
	return c

static func equation1(rng: RandomNumberGenerator) -> MathChallenge:
	var x := rng.randi_range(3, 9)
	var a := rng.randi_range(2, 4)
	var b := rng.randi_range(2, 10)
	var c := _base("equation1", 1, "Equação do 1º grau", MathChallenge.Type.INTEGER, "Equação do 1º grau")
	c.statement = "Você comprou %d pacotes iguais de macarrão e pagou R$ %d de entrega. O total foi R$ %d.\nQuanto custa cada pacote, em reais? (equação: %dx + %d = %d)" % [a, b, a * x + b, a, b, a * x + b]
	c.expected = x
	c.hint = "Subtraia a entrega do total e depois divida pelo número de pacotes."
	return c

# ------------------------------------------------------------------ nível 2
static func circle_area(rng: RandomNumberGenerator) -> MathChallenge:
	var radii := [10, 12, 15, 20]
	var r: int = radii[rng.randi() % radii.size()]
	var c := _base("circle_area", 2, "Geometria", MathChallenge.Type.DECIMAL, "Área do círculo")
	c.statement = "A forma do bolo é redonda, com raio de %d cm.\nQual é a área da base, em cm²? (use π = 3,14)" % r
	c.expected = 3.14 * r * r
	c.hint = "Área do círculo = π × raio × raio."
	return c

static func stat_median(rng: RandomNumberGenerator) -> MathChallenge:
	var pool := range(8, 31)
	pool.shuffle()
	var vals := pool.slice(0, 5)
	var sorted_vals := vals.duplicate()
	sorted_vals.sort()
	var c := _base("stat_median", 2, "Estatística", MathChallenge.Type.INTEGER, "Mediana")
	c.statement = "Clientes atendidos em 5 dias: %s.\nQual é a mediana desses valores?" % _join(vals)
	c.expected = sorted_vals[2]
	c.hint = "Coloque os valores em ordem crescente; a mediana é o valor do meio."
	return c

static func stat_mode(rng: RandomNumberGenerator) -> MathChallenge:
	var nums := range(1, 10)
	nums.shuffle()
	var list: Array = [nums[0], nums[0], nums[0], nums[1], nums[1], nums[2], nums[3]]
	list.shuffle()
	var c := _base("stat_mode", 2, "Estatística", MathChallenge.Type.INTEGER, "Moda")
	c.statement = "Quantidade de pratos pedidos em 7 mesas: %s.\nQual é a moda (o valor que mais se repete)?" % _join(list)
	c.expected = nums[0]
	c.hint = "A moda é o valor que aparece mais vezes na lista."
	return c

static func prob_simple(rng: RandomNumberGenerator) -> MathChallenge:
	var totals := [12, 15, 20, 24]
	var picks := [3, 4, 5, 6]
	var n: int = totals[rng.randi() % totals.size()]
	var k: int = picks[rng.randi() % picks.size()]
	var c := _base("prob_simple", 2, "Probabilidade", MathChallenge.Type.FRACTION, "Probabilidade de um evento")
	c.statement = "Dos %d clientes de hoje, %d pediram pudim.\nSe um cliente for escolhido ao acaso, qual a probabilidade de ele ter pedido pudim? (fração, ex.: 1/4)" % [n, k]
	c.expected = [k, n]
	c.hint = "Probabilidade = casos favoráveis ÷ casos possíveis. Frações equivalentes valem."
	return c

static func combos(rng: RandomNumberGenerator) -> MathChallenge:
	var e := rng.randi_range(2, 4)
	var p := rng.randi_range(2, 5)
	var s := rng.randi_range(2, 3)
	var c := _base("combos", 2, "Análise combinatória", MathChallenge.Type.INTEGER, "Princípio fundamental da contagem")
	c.statement = "O cardápio do almoço tem %d entradas, %d pratos principais e %d sobremesas.\nQuantas refeições diferentes (uma entrada, um prato e uma sobremesa) podem ser montadas?" % [e, p, s]
	c.expected = e * p * s
	c.hint = "Multiplique o número de escolhas de cada etapa."
	return c

static func pa_sequence(rng: RandomNumberGenerator) -> MathChallenge:
	var a1 := rng.randi_range(8, 15)
	var r := rng.randi_range(2, 5)
	var n := rng.randi_range(6, 10)
	var c := _base("pa_sequence", 2, "Progressão aritmética", MathChallenge.Type.INTEGER, "Termo geral da PA")
	c.statement = "No 1º dia o restaurante vendeu %d pratos e, a cada dia, vende %d pratos a mais que no dia anterior.\nQuantos pratos vendeu no %dº dia?" % [a1, r, n]
	c.expected = a1 + (n - 1) * r
	c.hint = "Termo geral: a_n = a_1 + (n − 1) × razão."
	return c

static func linear_function(rng: RandomNumberGenerator) -> MathChallenge:
	var a := rng.randi_range(8, 15)
	var b := rng.randi_range(40, 70)
	var x := rng.randi_range(10, 20)
	var c := _base("linear_function", 2, "Função do 1º grau", MathChallenge.Type.INTEGER, "Valor numérico de função afim")
	c.statement = "O lucro diário do restaurante é L(x) = %d·x − %d (em reais), onde x é o número de pratos vendidos.\nQual é o lucro se forem vendidos %d pratos?" % [a, b, x]
	c.expected = a * x - b
	c.hint = "Substitua x por %d e calcule." % x
	return c

# ------------------------------------------------------------------ nível 3
static func cylinder_volume(rng: RandomNumberGenerator) -> MathChallenge:
	var radii := [5, 6, 8]
	var heights := [6, 8, 10]
	var r: int = radii[rng.randi() % radii.size()]
	var h: int = heights[rng.randi() % heights.size()]
	var c := _base("cylinder_volume", 3, "Geometria espacial", MathChallenge.Type.DECIMAL, "Volume do cilindro")
	c.statement = "A forma do pudim é um cilindro com raio de %d cm e altura de %d cm.\nQual é o volume, em cm³? (use π = 3,14)" % [r, h]
	c.expected = 3.14 * r * r * h
	c.hint = "Volume = π × raio² × altura."
	return c

static func weighted_mean(rng: RandomNumberGenerator) -> MathChallenge:
	var a := rng.randi_range(6, 10)
	var b := rng.randi_range(6, 10)
	var d := rng.randi_range(6, 10)
	var c := _base("weighted_mean", 3, "Estatística", MathChallenge.Type.DECIMAL, "Média ponderada")
	c.statement = "Avaliação do restaurante: comida (peso 3) nota %d, atendimento (peso 2) nota %d e ambiente (peso 1) nota %d.\nQual é a média ponderada? (arredonde para 1 casa decimal)" % [a, b, d]
	c.expected = snappedf((3.0 * a + 2.0 * b + d) / 6.0, 0.1)
	c.tolerance = 0.001
	c.hint = "Multiplique cada nota pelo peso, some tudo e divida pela soma dos pesos (6)."
	return c

static func prob_two(rng: RandomNumberGenerator) -> MathChallenge:
	var sets := [[1, 2], [1, 3], [1, 4], [2, 3], [3, 5]]
	var s: Array = sets[rng.randi() % sets.size()]
	var c := _base("prob_two", 3, "Probabilidade", MathChallenge.Type.FRACTION, "Eventos independentes")
	c.statement = "Dois clientes chegam ao restaurante. Cada um tem probabilidade %d/%d de pedir pudim, de forma independente.\nQual a probabilidade de OS DOIS pedirem pudim? (fração)" % [s[0], s[1]]
	c.expected = [s[0] * s[0], s[1] * s[1]]
	c.hint = "Para eventos independentes, multiplique as probabilidades."
	return c

static func system_2x2(rng: RandomNumberGenerator) -> MathChallenge:
	var p := rng.randi_range(12, 30)
	var b := rng.randi_range(4, 10)
	var c := _base("system_2x2", 3, "Sistema de equações", MathChallenge.Type.INTEGER, "Sistema linear 2×2")
	c.statement = "Na mesa 1, 2 pratos e 1 bebida custaram R$ %d. Na mesa 2, 1 prato e 2 bebidas custaram R$ %d.\nQuanto custa 1 prato, em reais?" % [2 * p + b, p + 2 * b]
	c.expected = p
	c.hint = "Sistema: 2p + b = %d e p + 2b = %d. Multiplique a 1ª equação por 2 e subtraia a 2ª." % [2 * p + b, p + 2 * b]
	return c

static func compound_interest(rng: RandomNumberGenerator) -> MathChallenge:
	var principals := [100, 200, 500]
	var rates := [10, 20]
	var pr: int = principals[rng.randi() % principals.size()]
	var rate: int = rates[rng.randi() % rates.size()]
	var c := _base("compound_interest", 3, "Juros compostos", MathChallenge.Type.DECIMAL, "Montante com juros compostos")
	c.statement = "Você aplica R$ %d a %d%% ao mês, com juros compostos, por 2 meses.\nQual será o montante final, em reais?" % [pr, rate]
	c.expected = pr * pow(1.0 + rate / 100.0, 2)
	c.hint = "Montante = capital × (1 + taxa)². Aplique o reajuste mês a mês."
	return c

static func sqrt_area(rng: RandomNumberGenerator) -> MathChallenge:
	var areas := [144, 196, 225, 256, 324]
	var area: int = areas[rng.randi() % areas.size()]
	var c := _base("sqrt_area", 3, "Raiz quadrada e área", MathChallenge.Type.INTEGER, "Raiz quadrada")
	c.statement = "O salão do restaurante é um quadrado com %d m² de área.\nQuanto mede cada lado, em metros?" % area
	c.expected = roundi(sqrt(float(area)))
	c.hint = "Área do quadrado = lado × lado. Procure o número que multiplicado por ele mesmo dá %d." % area
	return c

static func combination_pairs(rng: RandomNumberGenerator) -> MathChallenge:
	var n := rng.randi_range(5, 8)
	var c := _base("combination_pairs", 3, "Análise combinatória", MathChallenge.Type.INTEGER, "Combinação simples")
	c.statement = "O cardápio tem %d sabores de pudim. Numa degustação, o cliente escolhe 2 sabores DIFERENTES (a ordem não importa).\nDe quantas maneiras ele pode escolher?" % n
	c.expected = n * (n - 1) / 2
	c.hint = "Combinação de n em 2: n × (n − 1) ÷ 2."
	return c

## Estatística com dados REAIS da partida: média do lucro dos últimos dias.
static func stat_mean_history(history: Array) -> MathChallenge:
	var recent: Array = history.slice(maxi(0, history.size() - 4))
	var profits: Array = []
	var total := 0
	for e in recent:
		var entry: Dictionary = e
		var pr: int = entry["profit"]
		profits.append(Money.format(pr))
		total += pr
	var c := _base("stat_mean_history", 2, "Estatística (seus dados)", MathChallenge.Type.DECIMAL, "Média aritmética")
	c.statement = "Os lucros dos seus últimos dias foram: %s.\nQual foi o lucro médio por dia? (em reais; arredonde para os centavos)" % _join(profits)
	c.expected = roundi(float(total) / recent.size()) / 100.0
	c.tolerance = 0.0101
	c.hint = "Média = soma dos lucros ÷ número de dias."
	return c
