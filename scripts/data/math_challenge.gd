class_name MathChallenge
extends RefCounted
## Desafio matemático (seção 4.4). Todo desafio tem: enunciado, dados, operação esperada,
## resposta correta, regra de validação (via type), feedback e consequência no jogo.

enum Type { INTEGER, DECIMAL, FRACTION, MULTIPLE_CHOICE, STRUCTURED }

var id: String = ""
var topic: String = ""
var type: Type = Type.INTEGER
var statement: String = ""
var data: Dictionary = {}
var operation: String = ""
var expected: Variant = null     # int | float | [num, den] | índice | Array de floats
var tolerance: float = 0.0
var choices: Array[String] = []
var hint: String = ""
var success_feedback: String = "Correto!"
var error_feedback: String = "Resposta incorreta. Revise os dados e tente novamente."
## Consequência: {"type": "recover_line" | "scale_line" | "delivery_step" | "purchase_discount", ...}
var consequence: Dictionary = {}
var max_attempts: int = 0        # 0 = ilimitado (definir no balanceamento)
var attempts: int = 0
var solved: bool = false

func validate(raw: Variant) -> Dictionary:
	attempts += 1
	var result := AnswerValidator.validate(self, raw)
	solved = result["ok"]
	return result

func clone() -> MathChallenge:
	var c := MathChallenge.new()
	c.id = id
	c.topic = topic
	c.type = type
	c.statement = statement
	c.data = data.duplicate(true)
	c.operation = operation
	c.expected = expected
	c.tolerance = tolerance
	c.choices = choices.duplicate()
	c.hint = hint
	c.success_feedback = success_feedback
	c.error_feedback = error_feedback
	c.consequence = consequence.duplicate(true)
	c.max_attempts = max_attempts
	return c
