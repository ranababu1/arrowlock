class_name BoardView
extends Control
## Draws a GameController's board and forwards taps. Owns no puzzle rules.

signal cell_tapped(cell: Vector2i)

const BLOCKED_COLOR := Palette.RED
const HINT_COLOR := Palette.GOLD
const TILE_FILL := Color(1, 1, 1, 0.05)
const TILE_BORDER := Color(1, 1, 1, 0.08)
const EXIT_SECONDS := 0.25
const EXIT_TRAVEL_CELLS := 1.5
const BLOCKED_FLASH_SECONDS := 0.4
## Blocked arrows also shake, so the cue is not colour-only.
const SHAKE_CELLS := 0.07
const SHAKE_HZ := 18.0
const HINT_PULSE_HZ := 2.0
const SPARKS_PER_ARROW := 8
const SPARK_SECONDS := 0.5

var _controller: GameController
## id -> {"info": Dictionary, "t": float}; arrows animating off the board.
var _exiting: Dictionary = {}
## id -> seconds remaining of the blocked flash.
var _flashing: Dictionary = {}
## Each spark: [position, velocity, age, colour]. Decoration only.
var _sparks: Array[Array] = []
var _hint_id: int = -1
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tile_style := StyleBoxFlat.new()


func _init() -> void:
	_rng.seed = 7
	_tile_style.bg_color = TILE_FILL
	_tile_style.border_color = TILE_BORDER
	_tile_style.set_border_width_all(1)


func bind(controller: GameController) -> void:
	_controller = controller
	clear_animations()
	controller.arrow_removed.connect(_on_arrow_removed)
	controller.move_blocked.connect(func(id: int, _blocker: int) -> void: _flashing[id] = BLOCKED_FLASH_SECONDS)
	controller.arrow_restored.connect(func(id: int) -> void: _exiting.erase(id))


func clear_animations() -> void:
	_exiting.clear()
	_flashing.clear()
	_sparks.clear()
	_hint_id = -1
	queue_redraw()


func show_hint(id: int) -> void:
	_hint_id = id
	queue_redraw()


func clear_hint() -> void:
	if _hint_id != -1:
		_hint_id = -1
		queue_redraw()


func hint_id() -> int:
	return _hint_id


func is_flashing(id: int) -> bool:
	return _flashing.has(id)


func spark_count() -> int:
	return _sparks.size()


func _on_arrow_removed(id: int, info: Dictionary) -> void:
	_exiting[id] = {"info": info, "t": 0.0}
	var l := _layout()
	var center: Vector2 = l["origin"] + (Vector2(info["pos"]) + Vector2(0.5, 0.5)) * l["cell"]
	var color := Palette.direction_color(info["dir"])
	for i in SPARKS_PER_ARROW:
		var velocity := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 190.0)
		_sparks.append([center, velocity, 0.0, color])


func _process(delta: float) -> void:
	if _exiting.is_empty() and _flashing.is_empty() and _sparks.is_empty() and _hint_id == -1:
		return
	_clock += delta
	for id in _exiting.keys():
		_exiting[id]["t"] += delta / EXIT_SECONDS
		if _exiting[id]["t"] >= 1.0:
			_exiting.erase(id)
	for id in _flashing.keys():
		_flashing[id] -= delta
		if _flashing[id] <= 0.0:
			_flashing.erase(id)
	for i in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[i]
		spark[2] += delta
		spark[0] += spark[1] * delta
		spark[1] *= 1.0 - 3.0 * delta
		if spark[2] >= SPARK_SECONDS:
			_sparks.remove_at(i)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _controller == null:
		return
	# Touches arrive as emulated mouse clicks (project default). Handling
	# InputEventScreenTouch as well would count every tap twice, and taps cost moves.
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var cell := _cell_at(event.position)
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
	_tile_style.set_corner_radius_all(roundi(cell * 0.2))
	for y in b.height:
		for x in b.width:
			draw_style_box(_tile_style, Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)).grow(-3.0))
	for id in b.arrow_ids():
		var color := Palette.direction_color(b.arrow_direction(id))
		var offset := Vector2.ZERO
		if _flashing.has(id):
			color = BLOCKED_COLOR
			var strength: float = _flashing[id] / BLOCKED_FLASH_SECONDS
			offset = Vector2(sin(_clock * SHAKE_HZ * TAU) * SHAKE_CELLS * cell * strength, 0.0)
		if id == _hint_id:
			_draw_hint_frame(origin, cell, b.arrow_position(id))
			color = HINT_COLOR
		_draw_arrow(origin, cell, b.arrow_position(id), b.arrow_direction(id), color, 1.0, 0.0, offset, 1.0)
	for id in _exiting.keys():
		var info: Dictionary = _exiting[id]["info"]
		var t: float = _exiting[id]["t"]
		var color := Palette.direction_color(info["dir"])
		_draw_arrow(origin, cell, info["pos"], info["dir"], color, 1.0 - t, t * EXIT_TRAVEL_CELLS, Vector2.ZERO, 1.0 - 0.3 * t)
	for spark in _sparks:
		var life: float = 1.0 - float(spark[2]) / SPARK_SECONDS
		draw_circle(spark[0], maxf(1.5, cell * 0.05 * life), Color(spark[3], life))


## A pulsing outline, so the hint is visible without relying on colour.
func _draw_hint_frame(origin: Vector2, cell: float, pos: Vector2i) -> void:
	var pulse := 0.6 + 0.4 * sin(_clock * HINT_PULSE_HZ * TAU)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(HINT_COLOR, 0.14 * pulse)
	style.border_color = Color(HINT_COLOR, pulse)
	style.set_border_width_all(3)
	style.set_corner_radius_all(roundi(cell * 0.2))
	draw_style_box(style, Rect2(origin + Vector2(pos) * cell, Vector2(cell, cell)).grow(-3.0))


## Rounded arrow on a soft glow. Direction lives in the shape, not just the colour.
func _draw_arrow(origin: Vector2, cell: float, pos: Vector2i, dir: String, color: Color, alpha: float, shift_cells: float, offset: Vector2, scale: float) -> void:
	var step := Vector2(BoardState.DIRECTIONS[dir])
	var center := origin + (Vector2(pos) + Vector2(0.5, 0.5) + step * shift_cells) * cell + offset
	var perp := Vector2(-step.y, step.x)
	var unit := cell * scale
	var width := maxf(4.0, unit * 0.15)
	draw_circle(center, unit * 0.38, Color(color, 0.10 * alpha))
	var col := Color(color, alpha)
	var tail := center - step * unit * 0.28
	var neck := center + step * unit * 0.04
	draw_line(tail, neck, col, width, true)
	draw_circle(tail, width * 0.5, col)
	var tip := center + step * unit * 0.34
	var back_a := center - step * unit * 0.02 + perp * unit * 0.2
	var back_b := center - step * unit * 0.02 - perp * unit * 0.2
	draw_colored_polygon(PackedVector2Array([tip, back_a, back_b]), col)
	for corner in [tip, back_a, back_b]:
		draw_circle(corner.lerp(center, 0.12), width * 0.28, col)
