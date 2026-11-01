class_name SaveService
extends RefCounted
## Versioned local save. Invalid or corrupt data falls back to defaults.

const SCHEMA_VERSION := 1

var path: String
var completed: Dictionary = {}  ## level id -> best move count
var sound_enabled: bool = true
var load_error: String = ""


func _init(p_path: String = "user://save.json") -> void:
	path = p_path


func is_completed(level_id: int) -> bool:
	return completed.has(level_id)


func record_completion(level_id: int, moves: int) -> void:
	if not completed.has(level_id) or moves < completed[level_id]:
		completed[level_id] = moves


func load_data() -> void:
	_reset()
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "Cannot open save (error %d)" % FileAccess.get_open_error()
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", -1)) != SCHEMA_VERSION:
		load_error = "Save is corrupt or has an unsupported version"
		return
	var raw: Variant = data.get("completed")
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw.keys():
			var moves := int(raw[key])
			if str(key).is_valid_int() and moves > 0:
				completed[int(str(key))] = moves
	sound_enabled = bool(data.get("sound_enabled", true))


## Writes via a temp file then renames, so a crash cannot truncate the save.
func save_data() -> bool:
	var out: Dictionary = {}
	for id in completed.keys():
		out[str(id)] = completed[id]
	var text := JSON.stringify({
		"version": SCHEMA_VERSION,
		"completed": out,
		"sound_enabled": sound_enabled,
	})
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: cannot open %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Save failed: rename error %d" % err)
		return false
	return true


func _reset() -> void:
	completed.clear()
	sound_enabled = true
	load_error = ""
