class_name BoardState
extends RefCounted
## Deterministic board model. Knows nothing about rendering or input.
## Arrows are keyed by stable integer IDs; each occupies one cell.
##
## A "turner" is an arrow that turns 90 degrees clockwise every time another
## arrow leaves the board (GameController calls rotate_turners). Turners only
## appear after level 100; plain boards behave exactly as before.

const DIRECTIONS: Dictionary = {
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
}
## Clockwise order, used to turn turners.
const CLOCKWISE: Array[String] = ["up", "right", "down", "left"]

var width: int
var height: int
## id -> {"pos": Vector2i, "dir": String, "turn": bool}
var _arrows: Dictionary = {}
## Vector2i -> id, for remaining arrows only.
var _occupancy: Dictionary = {}
## Number of remaining turners.
var _turner_count: int = 0


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


## Returns true when the arrow was added. Rejects bad coordinates, unknown
## directions, duplicate IDs and occupied cells.
func add_arrow(id: int, pos: Vector2i, dir: String, turn: bool = false) -> bool:
	if not in_bounds(pos) or not DIRECTIONS.has(dir):
		return false
	if _arrows.has(id) or _occupancy.has(pos):
		return false
	_arrows[id] = {"pos": pos, "dir": dir, "turn": turn}
	_occupancy[pos] = id
	if turn:
		_turner_count += 1
	return true


func has_arrow(id: int) -> bool:
	return _arrows.has(id)


func arrow_position(id: int) -> Vector2i:
	return _arrows[id]["pos"]


func arrow_direction(id: int) -> String:
	return _arrows[id]["dir"]


func is_turner(id: int) -> bool:
	return _arrows[id].get("turn", false)


## True while at least one turner is still on the board.
func has_turners() -> bool:
	return _turner_count > 0


func turner_count() -> int:
	return _turner_count


## `dir` turned clockwise `steps` times (negative steps turn it back).
static func rotated(dir: String, steps: int) -> String:
	return CLOCKWISE[posmod(CLOCKWISE.find(dir) + steps, 4)]


## Turns every remaining turner clockwise `steps` times (negative: back).
func rotate_turners(steps: int) -> void:
	if _turner_count == 0:
		return
	for id in _arrows.keys():
		var info: Dictionary = _arrows[id]
		if info.get("turn", false):
			info["dir"] = rotated(info["dir"], steps)


func arrow_at(pos: Vector2i) -> int:
	return _occupancy.get(pos, -1)


func remaining_count() -> int:
	return _arrows.size()


func is_empty() -> bool:
	return _arrows.is_empty()


## Remaining arrow IDs in ascending order (stable for determinism).
func arrow_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in _arrows.keys():
		ids.append(id)
	ids.sort()
	return ids


func remove_arrow(id: int) -> Dictionary:
	var info: Dictionary = _arrows[id]
	_arrows.erase(id)
	_occupancy.erase(info["pos"])
	if info.get("turn", false):
		_turner_count -= 1
	return info.duplicate()


## Re-adds a previously removed arrow (used by undo).
func restore_arrow(id: int, info: Dictionary) -> void:
	_arrows[id] = info.duplicate()
	_occupancy[info["pos"]] = id
	if info.get("turn", false):
		_turner_count += 1


func duplicate_state() -> BoardState:
	var copy := BoardState.new(width, height)
	for id in _arrows.keys():
		var info: Dictionary = _arrows[id]
		copy._arrows[id] = {"pos": info["pos"], "dir": info["dir"], "turn": info.get("turn", false)}
		copy._occupancy[info["pos"]] = id
	copy._turner_count = _turner_count
	return copy
