class_name Order
extends RefCounted
## Pedido de um cliente. Transições controladas por transition().

enum State { CREATED, INVESTIGATING, IDENTIFIED, PREPARING, COMPLETED, CANCELLED, FAILED }
enum Kind { DIRECT, DESCRIPTIVE, ENIGMATIC }

const ALLOWED := {
	State.CREATED: [State.INVESTIGATING, State.CANCELLED],
	State.INVESTIGATING: [State.IDENTIFIED, State.CANCELLED, State.FAILED],
	State.IDENTIFIED: [State.PREPARING, State.CANCELLED],
	State.PREPARING: [State.COMPLETED, State.FAILED, State.CANCELLED],
}

var id: int = 0
var customer_name: String = ""
var kind: Kind = Kind.DIRECT
var description: String = ""
var correct_recipe_id: String = ""      # solução definida nos dados
var selected_recipe_id: String = ""     # receita escolhida (quando identificada)
var servings: int = 1
var clue_ids: Array[String] = []
var hidden_clue_ids: Array[String] = [] # pistas extras liberadas sob pedido
var restrictions: Array[String] = []
var deadline_sec: float = 0.0           # 0 = sem prazo (mecânica de tempo opcional)
var base_reward_cents: int = 0
var state: State = State.CREATED
var mistakes: int = 0
var hints_used: int = 0
var paid: bool = false

func transition(to: State) -> bool:
	var options: Array = ALLOWED.get(state, [])
	if to in options:
		state = to
		return true
	push_warning("Transição de pedido inválida: %s -> %s" % [state_name(state), state_name(to)])
	return false

func is_closed() -> bool:
	return state in [State.COMPLETED, State.CANCELLED, State.FAILED]

func visible_clues() -> Array[String]:
	var out: Array[String] = []
	out.append_array(clue_ids)
	for i in mini(hints_used, hidden_clue_ids.size()):
		out.append(hidden_clue_ids[i])
	return out

static func state_name(s: State) -> String:
	match s:
		State.CREATED:
			return "Criado"
		State.INVESTIGATING:
			return "Em investigação"
		State.IDENTIFIED:
			return "Identificado"
		State.PREPARING:
			return "Em preparação"
		State.COMPLETED:
			return "Concluído"
		State.CANCELLED:
			return "Cancelado"
		_:
			return "Falhou"
