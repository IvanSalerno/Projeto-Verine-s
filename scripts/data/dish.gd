class_name Dish
extends RefCounted
## Prato em preparo. NÃO INICIADO → EM PREPARAÇÃO → PRONTO → ENTREGUE (ou INUTILIZADO).

enum State { NOT_STARTED, PREPARING, READY, DELIVERED, UNUSABLE }

var recipe_id: String
var servings: int
var steps: Array[String] = []
var steps_done: int = 0
var state: State = State.NOT_STARTED
var ingredients_consumed: bool = false

func _init(p_recipe_id: String, p_servings: int, p_steps: Array) -> void:
	recipe_id = p_recipe_id
	servings = p_servings
	steps.assign(p_steps)

func start() -> void:
	if state == State.NOT_STARTED:
		state = State.PREPARING

## Executa a próxima etapa. Retorna true se avançou.
func advance() -> bool:
	if state != State.PREPARING:
		return false
	steps_done += 1
	if steps_done >= steps.size():
		state = State.READY
	return true

func next_step_label() -> String:
	if steps_done < steps.size():
		return steps[steps_done]
	return ""
