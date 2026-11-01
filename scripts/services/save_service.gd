class_name SaveService
extends RefCounted
## Versioned local save. Invalid or corrupt data falls back to defaults.
## Persists a Progress object; all reward rules live in Progress.

const SCHEMA_VERSION := 2

var path: String
var progress := Progress.new()
var load_error: String = ""


func _init(p_path: String = "user://save.json") -> void:
	path = p_path


func load_data() -> void:
	progress = Progress.new()
	load_error = ""
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "Cannot open save (error %d)" % FileAccess.get_open_error()
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		load_error = "Save is corrupt"
		return
	match int(data.get("version", -1)):
		1:
			progress = Progress.from_v1(data)
		SCHEMA_VERSION:
			progress = Progress.from_dict(data)
		_:
			load_error = "Save has an unsupported version"


## Writes via a temp file then renames, so a crash cannot truncate the save.
func save_data() -> bool:
	var body := progress.to_dict()
	body["version"] = SCHEMA_VERSION
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Save failed: cannot open %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(body))
	file.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Save failed: rename error %d" % err)
		return false
	return true
