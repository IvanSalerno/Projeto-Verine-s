class_name Ingredient
extends RefCounted
## Ingrediente do estoque. Quantidades na unidade base (g, ml ou un).

var id: String
var display_name: String
var unit: Units.Unit                # unidade base do estoque
var pack_size: int                  # quanto vem em 1 pacote de compra (unidade base)
var pack_cost_cents: int            # custo de aquisição de 1 pacote
var category: String
var storage_limit: int              # 0 = sem limite
var min_restock: int                # abaixo disso o jogo avisa para repor

func _init(p_id: String, p_name: String, p_unit: Units.Unit, p_pack_size: int,
		p_cost_cents: int, p_category: String = "", p_limit: int = 0, p_min: int = 0) -> void:
	id = p_id
	display_name = p_name
	unit = p_unit
	pack_size = p_pack_size
	pack_cost_cents = p_cost_cents
	category = p_category
	storage_limit = p_limit
	min_restock = p_min
