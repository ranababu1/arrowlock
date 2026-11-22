class_name BoardState
extends RefCounted
## Deterministic board model. Knows nothing about rendering or input.
## Arrows are keyed by stable integer IDs; each occupies one cell.
##
## A "turner" is an arrow that turns 90 degrees clockwise every time another
## arrow leaves the board (GameController calls rotate_turners). Turners only
## appear after level 100; plain boards behave exactly as before.
##
## A "flipper" points one way, then the opposite way, swapping on a timer
## (GameController calls flip_flippers). An arrow is never both.

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
## id -> {"pos": Vector2i, "dir": String, "turn": bool, "flip": bool}
var _arrows: Dictionary = {}
## Vector2i -> id, for remaining arrows only.
var _occupancy: Dictionary = {}
## Number of remaining turners.
var _turner_count: int = 0
## Number of remaining flippers.
var _flipper_count: int = 0
## How many times the flippers have swapped (only its parity matters).
var flip_parity: int = 0


func _init(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


## Returns true when the arrow was added. Rejects bad coordinates, unknown
## directions, duplicate IDs and occupied cells.
func add_arrow(id: int, pos: Vector2i, dir: String, turn: bool = false, flip: bool = false) -> bool:
	if not in_bounds(pos) or not DIRECTIONS.has(dir) or (turn and flip):
		return false
	if _arrows.has(id) or _occupancy.has(pos):
		return false
	_arrows[id] = {"pos": pos, "dir": dir, "turn": turn, "flip": flip}
	_occupancy[pos] = id
	if turn:
		_turner_count += 1
	if flip:
		_flipper_count += 1
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


func is_flipper(id: int) -> bool:
	return _arrows[id].get("flip", false)


## True while at least one flipper is still on the board.
func has_flippers() -> bool:
	return _flipper_count > 0


func flipper_count() -> int:
	return _flipper_count


## Every remaining flipper swaps to the opposite direction.
func flip_flippers() -> void:
	flip_parity += 1
	if _flipper_count == 0:
		return
	for id in _arrows.keys():
		var info: Dictionary = _arrows[id]
		if info.get("flip", false):
			info["dir"] = rotated(info["dir"], 2)


## The other direction a flipper can point (its own direction otherwise).
func other_direction(id: int) -> String:
	var dir := arrow_direction(id)
	return rotated(dir, 2) if is_flipper(id) else dir


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
	if info.get("flip", false):
		_flipper_count -= 1
	var out := info.duplicate()
	out["parity"] = flip_parity
	return out


## Re-adds a previously removed arrow (used by undo).
func restore_arrow(id: int, info: Dictionary) -> void:
	var back := info.duplicate()
	# A flipper put back keeps in step with the others.
	if back.get("flip", false):
		_flipper_count += 1
		if posmod(flip_parity - int(back.get("parity", flip_parity)), 2) == 1:
			back["dir"] = rotated(back["dir"], 2)
	back.erase("parity")
	_arrows[id] = back
	_occupancy[info["pos"]] = id
	if info.get("turn", false):
		_turner_count += 1


func duplicate_state() -> BoardState:
	var copy := BoardState.new(width, height)
	for id in _arrows.keys():
		var info: Dictionary = _arrows[id]
		copy._arrows[id] = {"pos": info["pos"], "dir": info["dir"], "turn": info.get("turn", false), "flip": info.get("flip", false)}
		copy._occupancy[info["pos"]] = id
	copy._turner_count = _turner_count
	copy._flipper_count = _flipper_count
	copy.flip_parity = flip_parity
	return copy
