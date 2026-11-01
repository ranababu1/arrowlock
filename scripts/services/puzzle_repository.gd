class_name PuzzleRepository
extends RefCounted
## Loads and validates curated level data. Level files are data only.

const SUPPORTED_VERSION := 2
const MAX_BOARD_SIZE := 16

## Parsed levels: {"id": int, "name": String, "board": BoardState, "moves_limit": int}.
var levels: Array[Dictionary] = []
## Human-readable validation errors from the last load.
var errors: Array[String] = []


func load_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("Cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	return load_text(file.get_as_text())


func load_text(text: String) -> bool:
	levels.clear()
	errors.clear()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Level file is not a JSON object")
		return false
	if int(parsed.get("version", -1)) != SUPPORTED_VERSION:
		errors.append("Unsupported level schema version")
		return false
	var raw_levels: Variant = parsed.get("levels")
	if typeof(raw_levels) != TYPE_ARRAY:
		errors.append("Missing 'levels' array")
		return false
	var seen_ids: Dictionary = {}
	for raw in raw_levels:
		var level := _parse_level(raw)
		if level.is_empty():
			continue
		if seen_ids.has(level["id"]):
			errors.append("Duplicate level id %d" % level["id"])
			continue
		seen_ids[level["id"]] = true
		levels.append(level)
	return errors.is_empty()


func _parse_level(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		errors.append("Level entry is not an object")
		return {}
	var id := int(raw.get("id", -1))
	var w := int(raw.get("width", 0))
	var h := int(raw.get("height", 0))
	if id < 0 or w < 1 or h < 1 or w > MAX_BOARD_SIZE or h > MAX_BOARD_SIZE:
		errors.append("Level %d has invalid id or dimensions" % id)
		return {}
	var raw_arrows: Variant = raw.get("arrows")
	if typeof(raw_arrows) != TYPE_ARRAY or raw_arrows.is_empty():
		errors.append("Level %d has no arrows" % id)
		return {}
	var board := BoardState.new(w, h)
	var next_id := 0
	for a in raw_arrows:
		if typeof(a) != TYPE_DICTIONARY \
				or not board.add_arrow(next_id, Vector2i(int(a.get("x", -1)), int(a.get("y", -1))), str(a.get("dir", ""))):
			errors.append("Level %d has an invalid, duplicate or out-of-bounds arrow" % id)
			return {}
		next_id += 1
	var moves_limit := int(raw.get("moves_limit", 0))
	if moves_limit < board.remaining_count():
		errors.append("Level %d moves_limit %d is below arrow count %d" % [id, moves_limit, board.remaining_count()])
		return {}
	return {"id": id, "name": str(raw.get("name", "Level %d" % id)), "board": board, "moves_limit": moves_limit}
