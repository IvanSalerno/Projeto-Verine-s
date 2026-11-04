class_name SaveSystem
extends RefCounted
## Salvar/carregar a partida em user://verines_save.json (JSON legível).

const PATH := "user://verines_save.json"
const VERSION := 1

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

static func save() -> bool:
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game": Game.to_dict(),
		"flow": Flow.to_dict(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true

static func _read() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		return {}
	return data

## Carrega o save e aplica em Game e Flow. Retorna false se o arquivo for inválido.
static func load_into() -> bool:
	var data := _read()
	if data.is_empty() or not data.has("game") or not data.has("flow"):
		return false
	Game.from_dict(data["game"])
	Flow.from_dict(data["flow"])
	return true

static func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

static func info() -> String:
	var data := _read()
	if data.is_empty():
		return ""
	var g: Dictionary = data.get("game", {})
	return "Último save: dia %d • %d pontos • %d pedidos • %s" % [
		int(g.get("day", 1)), int(g.get("score", 0)), int(g.get("orders_completed", 0)),
		str(data.get("saved_at", "")).replace("T", " ")]
