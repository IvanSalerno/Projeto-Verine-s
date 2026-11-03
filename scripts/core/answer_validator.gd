class_name AnswerValidator
extends RefCounted
## Validação de respostas (seção 4.4). Cada tipo de questão tem sua regra.
## Entrada de texto aceita vírgula ou ponto como separador decimal.

static func validate(challenge: MathChallenge, raw: Variant) -> Dictionary:
	var ok := false
	match challenge.type:
		MathChallenge.Type.INTEGER:
			ok = _check_integer(str(raw), int(challenge.expected))
		MathChallenge.Type.DECIMAL:
			ok = _check_decimal(str(raw), float(challenge.expected), challenge.tolerance)
		MathChallenge.Type.FRACTION:
			ok = _check_fraction(str(raw), challenge.expected)
		MathChallenge.Type.MULTIPLE_CHOICE:
			ok = int(raw) == int(challenge.expected)
		MathChallenge.Type.STRUCTURED:
			ok = _check_structured(str(raw), challenge.expected, challenge.tolerance)
	return {
		"ok": ok,
		"message": challenge.success_feedback if ok else challenge.error_feedback,
	}

## Retorna float ou null.
static func parse_number(text: String) -> Variant:
	var t := text.strip_edges().replace("R$", "").replace(" ", "").replace(",", ".")
	if t.is_valid_float():
		return t.to_float()
	return null

## Retorna Vector2i(numerador, denominador) ou null.
static func parse_fraction(text: String) -> Variant:
	var t := text.strip_edges().replace(" ", "")
	if not t.contains("/"):
		return null
	var parts := t.split("/")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return null
	var den := parts[1].to_int()
	if den == 0:
		return null
	return Vector2i(parts[0].to_int(), den)

static func _check_integer(text: String, expected: int) -> bool:
	var n: Variant = parse_number(text)
	if n == null:
		return false
	var v: float = n
	return absf(v - roundf(v)) < 0.0001 and int(roundf(v)) == expected

static func _check_decimal(text: String, expected: float, tolerance: float) -> bool:
	var n: Variant = parse_number(text)
	if n == null:
		return false
	var v: float = n
	return absf(v - expected) <= maxf(tolerance, 0.0001)

## expected = [numerador, denominador]. Aceita frações equivalentes (6/16 == 3/8).
static func _check_fraction(text: String, expected: Array) -> bool:
	var num := int(expected[0])
	var den := int(expected[1])
	var f: Variant = parse_fraction(text)
	if f != null:
		var fv: Vector2i = f
		return fv.x * den == num * fv.y
	var n: Variant = parse_number(text)
	if n != null:
		var v: float = n
		return absf(v - float(num) / float(den)) < 0.001
	return false

## Respostas estruturadas: valores separados por ";" (ex.: "13; 14").
static func _check_structured(text: String, expected: Array, tolerance: float) -> bool:
	var parts := text.split(";", false)
	if parts.size() != expected.size():
		return false
	for i in parts.size():
		var n: Variant = parse_number(parts[i])
		if n == null:
			return false
		var v: float = n
		if absf(v - float(expected[i])) > maxf(tolerance, 0.0001):
			return false
	return true
