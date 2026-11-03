class_name Units
extends RefCounted
## Unidades de medida. Estoque é sempre guardado na unidade base (g, ml, un).
## Unidades de dimensões diferentes nunca são comparadas sem conversão válida.

enum Unit { G, KG, ML, L, UN }

static func dimension(unit: Unit) -> String:
	match unit:
		Unit.G, Unit.KG:
			return "massa"
		Unit.ML, Unit.L:
			return "volume"
		_:
			return "unidade"

static func compatible(a: Unit, b: Unit) -> bool:
	return dimension(a) == dimension(b)

static func to_base(amount: float, unit: Unit) -> float:
	match unit:
		Unit.KG, Unit.L:
			return amount * 1000.0
		_:
			return amount

static func label(unit: Unit) -> String:
	match unit:
		Unit.G:
			return "g"
		Unit.KG:
			return "kg"
		Unit.ML:
			return "ml"
		Unit.L:
			return "L"
		_:
			return "un"

static func fmt_amount(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % value).replace(".", ",")
