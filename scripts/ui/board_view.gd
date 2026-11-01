class_name BoardView
extends Control
## Draws a GameController's board and forwards taps. Owns no puzzle rules.

signal cell_tapped(cell: Vector2i)

const ARROW_COLOR := Color(0.93, 0.95, 0.98)
const BLOCKED_COLOR := Color(0.95, 0.35, 0.35)
const GRID_COLOR := Color(1, 1, 1, 0.08)
const CELL_COLOR := Color(1, 1, 1, 0.04)
const EXIT_SECONDS := 0.25
const EXIT_TRAVEL_CELLS := 1.5
const BLOCKED_FLASH_SECONDS := 0.35

var _controller: GameController
## id -> {"info": Dictionary, "t": float}; arrows animating off the board.
var _exiting: Dictionary = {}
## id -> seconds remaining of the blocked flash.
var _flashing: Dictionary = {}


func bind(controller: GameController) -> void:
	_controller = controller
	_exiting.clear()
	_flashing.clear()
	controller.arrow_removed.connect(func(id: int, info: Dictionary) -> void: _exiting[id] = {"info": info, "t": 0.0})
	controller.move_blocked.connect(func(id: int, _blocker: int) -> void: _flashing[id] = BLOCKED_FLASH_SECONDS)
	controller.arrow_restored.connect(func(id: int) -> void: _exiting.erase(id))
	queue_redraw()


func clear_animations() -> void:
	_exiting.clear()
	_flashing.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _exiting.is_empty() and _flashing.is_empty():
		return
	for id in _exiting.keys():
		_exiting[id]["t"] += delta / EXIT_SECONDS
		if _exiting[id]["t"] >= 1.0:
			_exiting.erase(id)
	for id in _flashing.keys():
		_flashing[id] -= delta
		if _flashing[id] <= 0.0:
			_flashing.erase(id)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _controller == null:
		return
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if not pressed:
		return
	var cell := _cell_at(pos)
	if _controller.board.in_bounds(cell):
		cell_tapped.emit(cell)


func _layout() -> Dictionary:
	var b := _controller.board
	var cell := floorf(minf(size.x / b.width, size.y / b.height))
	var board_size := Vector2(cell * b.width, cell * b.height)
	return {"cell": cell, "origin": ((size - board_size) / 2.0).floor()}


func _cell_at(pos: Vector2) -> Vector2i:
	var l := _layout()
	var local: Vector2 = (pos - l["origin"]) / l["cell"]
	return Vector2i(floori(local.x), floori(local.y))


func _draw() -> void:
	if _controller == null:
		return
	var b := _controller.board
	var l := _layout()
	var cell: float = l["cell"]
	var origin: Vector2 = l["origin"]
	for y in b.height:
		for x in b.width:
			var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-2.0)
			draw_rect(r, CELL_COLOR)
			draw_rect(r, GRID_COLOR, false, 1.0)
	for id in b.arrow_ids():
		var color := BLOCKED_COLOR if _flashing.has(id) else ARROW_COLOR
		_draw_arrow(origin, cell, b.arrow_position(id), b.arrow_direction(id), color, 1.0, 0.0)
	for id in _exiting.keys():
		var info: Dictionary = _exiting[id]["info"]
		var t: float = _exiting[id]["t"]
		_draw_arrow(origin, cell, info["pos"], info["dir"], ARROW_COLOR, 1.0 - t, t * EXIT_TRAVEL_CELLS)


## Arrow = shaft + head, so direction is readable without relying on colour.
func _draw_arrow(origin: Vector2, cell: float, pos: Vector2i, dir: String, color: Color, alpha: float, shift_cells: float) -> void:
	var step := Vector2(BoardState.DIRECTIONS[dir])
	var center := origin + (Vector2(pos) + Vector2(0.5, 0.5) + step * shift_cells) * cell
	var perp := Vector2(-step.y, step.x)
	var col := Color(color, alpha)
	var tail := center - step * cell * 0.3
	var neck := center + step * cell * 0.05
	draw_line(tail, neck, col, maxf(3.0, cell * 0.12), true)
	var head := PackedVector2Array([
		center + step * cell * 0.34,
		center - step * cell * 0.04 + perp * cell * 0.22,
		center - step * cell * 0.04 - perp * cell * 0.22,
	])
	draw_colored_polygon(head, col)
