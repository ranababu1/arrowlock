class_name BoardView
extends Control
## Draws a GameController's board and forwards taps. Owns no puzzle rules.

signal cell_tapped(cell: Vector2i)

const BLOCKED_COLOR := Palette.RED
const HINT_COLOR := Palette.GOLD
const TILE_FILL := Color(1, 1, 1, 0.05)
const TILE_BORDER := Color(1, 1, 1, 0.08)
## Smallest cell (in base 540x960 units) the shipped boards may draw at; about
## 5 mm on a typical 6-inch phone. Checked by the tests against every pack.
const MIN_CELL_SIZE := 40
const EXIT_SECONDS := 0.25
const EXIT_TRAVEL_CELLS := 1.5
const BLOCKED_FLASH_SECONDS := 0.4
## Blocked arrows also shake, so the cue is not colour-only.
const SHAKE_CELLS := 0.07
const SHAKE_HZ := 18.0
const HINT_PULSE_HZ := 2.0
const SPARKS_PER_ARROW := 8
const SPARK_SECONDS := 0.5
const ARROW_SHAFT := 0.095  ## half-width of the shaft, in cells
const ARROW_HEAD := 0.26  ## half-width of the head
const ARROW_CORNER_STEPS := 5
## Draw size relative to the cell; the shape's own bounds stay well inside 0.5.
const ARROW_SCALE := 1.15
## The silhouette spans x = -0.30 .. 0.34; this recentres it on the cell.
const ARROW_CENTER_X := 0.02

var _controller: GameController
## id -> {"info": Dictionary, "t": float}; arrows animating off the board.
var _exiting: Dictionary = {}
## id -> seconds remaining of the blocked flash.
var _flashing: Dictionary = {}
## Each spark: [position, velocity, age, colour]. Decoration only.
var _sparks: Array[Array] = []
var _hint_id: int = -1
var _coach_id: int = -1
var _coach_kind := ""
var _coach_blocker: int = -1
var _clock: float = 0.0
var _rng := RandomNumberGenerator.new()
var _tile_style := StyleBoxFlat.new()
static var _shape_cache := PackedVector2Array()


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
	_coach_id = -1
	_coach_blocker = -1
	queue_redraw()


func show_hint(id: int) -> void:
	_hint_id = id
	queue_redraw()


func clear_hint() -> void:
	if _hint_id != -1:
		_hint_id = -1
		queue_redraw()


## Tutorial pointer: a pulsing outline, mint for "tap this", red for "blocked".
func set_coach(id: int, kind: String, blocker: int = -1) -> void:
	_coach_id = id
	_coach_kind = kind
	_coach_blocker = blocker
	queue_redraw()


func coach_id() -> int:
	return _coach_id


func coach_blocker() -> int:
	return _coach_blocker


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
	if _exiting.is_empty() and _flashing.is_empty() and _sparks.is_empty() and _hint_id == -1 and _coach_id == -1:
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


## Edge of one board cell as currently laid out.
func cell_size() -> float:
	return _layout()["cell"] if _controller != null else 0.0


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
		if id == _coach_blocker and _coach_id != -1:
			_draw_frame(origin, cell, b.arrow_position(id), Color.WHITE, 2.0)
		if id == _coach_id:
			_draw_frame(origin, cell, b.arrow_position(id), Palette.RED if _coach_kind == "blocked" else Palette.MINT, 2.0)
		if id == _hint_id:
			_draw_frame(origin, cell, b.arrow_position(id), HINT_COLOR, HINT_PULSE_HZ)
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


## A pulsing outline, so a pointer is visible without relying on colour.
func _draw_frame(origin: Vector2, cell: float, pos: Vector2i, color: Color, pulse_hz: float) -> void:
	var pulse := 0.75 + 0.25 * sin(_clock * pulse_hz * TAU)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color, 0.14 * pulse)
	style.border_color = Color(color, pulse)
	style.set_border_width_all(3)
	style.set_corner_radius_all(roundi(cell * 0.2))
	draw_style_box(style, Rect2(origin + Vector2(pos) * cell, Vector2(cell, cell)).grow(-3.0))


## One flat, rounded silhouette. Direction lives in the shape, not just the colour.
func _draw_arrow(origin: Vector2, cell: float, pos: Vector2i, dir: String, color: Color, alpha: float, shift_cells: float, offset: Vector2, scale: float) -> void:
	var step := Vector2(BoardState.DIRECTIONS[dir])
	var center := origin + (Vector2(pos) + Vector2(0.5, 0.5) + step * shift_cells) * cell + offset
	var perp := Vector2(-step.y, step.x)
	var unit := cell * scale * ARROW_SCALE
	var points := PackedVector2Array()
	for local in _arrow_shape():
		points.append(center + step * (local.x - ARROW_CENTER_X) * unit + perp * local.y * unit)
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(0.0, unit * 0.035))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28 * alpha))
	draw_colored_polygon(points, Color(color, alpha))


## The arrow outline in local units (one cell = 1.0), pointing along +x, with
## every corner rounded. Built once.
static func _arrow_shape() -> PackedVector2Array:
	if not _shape_cache.is_empty():
		return _shape_cache
	var corners := [
		[Vector2(-0.30, -ARROW_SHAFT), 0.05], [Vector2(0.04, -ARROW_SHAFT), 0.02],
		[Vector2(0.04, -ARROW_HEAD), 0.04], [Vector2(0.34, 0.0), 0.07],
		[Vector2(0.04, ARROW_HEAD), 0.04], [Vector2(0.04, ARROW_SHAFT), 0.02],
		[Vector2(-0.30, ARROW_SHAFT), 0.05],
	]
	var count := corners.size()
	for i in count:
		var corner: Vector2 = corners[i][0]
		var radius: float = corners[i][1]
		var to_prev: Vector2 = corners[(i + count - 1) % count][0] - corner
		var to_next: Vector2 = corners[(i + 1) % count][0] - corner
		var reach := minf(radius, minf(to_prev.length(), to_next.length()) * 0.5)
		var start := corner + to_prev.normalized() * reach
		var end := corner + to_next.normalized() * reach
		for s in ARROW_CORNER_STEPS + 1:
			var t := float(s) / ARROW_CORNER_STEPS
			_shape_cache.append(start * (1.0 - t) * (1.0 - t) + corner * 2.0 * (1.0 - t) * t + end * t * t)
	return _shape_cache
