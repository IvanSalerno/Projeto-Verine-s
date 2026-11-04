class_name Upgrade
extends RefCounted
## Melhoria comprável. effect = {"type": String, "value": float}

var id: String
var display_name: String
var description: String
var cost_cents: int
var prerequisites: Array[String] = []
var effect: Dictionary = {}

func _init(p_id: String, p_name: String, p_desc: String, p_cost: int, p_effect: Dictionary, p_prereq: Array = []) -> void:
	id = p_id
	display_name = p_name
	description = p_desc
	cost_cents = p_cost
	effect = p_effect
	prerequisites.assign(p_prereq)
