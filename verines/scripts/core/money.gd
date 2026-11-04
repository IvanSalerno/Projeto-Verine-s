class_name Money
extends RefCounted
## Dinheiro SEMPRE em centavos inteiros (evita erros de ponto flutuante).

static func format(cents: int) -> String:
	var sign_text := "-" if cents < 0 else ""
	var a: int = absi(cents)
	return "%sR$ %d,%02d" % [sign_text, floori(a / 100.0), a % 100]

static func from_reais(value: float) -> int:
	return roundi(value * 100.0)
