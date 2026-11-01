class_name StarRow
extends Control
## Draws 0..total stars as shapes (filled vs outlined), so the count never
## depends on colour alone or on font glyph support.

const FILLED := Color(1.0, 0.82, 0.25)
const EMPTY_FILL := Color(1, 1, 1, 0.08)
const EMPTY_LINE := Color(1, 1, 1, 0.35)
const INNER_RATIO := 0.45
const POP_SECONDS := 0.4

var stars: int = 0
var total: int = Economy.MAX_STARS
## Per star: 0..1+ growth of the filled star (1 = full size); lets stars pop in.
var _pop: Array[float] = [1.0, 1.0, 1.0]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_stars(count: int) -> void:
	stars = clampi(count, 0, total)
	_pop = [1.0, 1.0, 1.0]
	queue_redraw()


## Shows `count` stars popping in one after another (matches the star sounds).
func animate_to(count: int, start_delay: float, step: float) -> void:
	stars = clampi(count, 0, total)
	_pop = [0.0, 0.0, 0.0]
	queue_redraw()
	if not is_inside_tree():
		_pop = [1.0, 1.0, 1.0]
		return
	var tween := create_tween().set_parallel(true)
	for i in stars:
		tween.tween_method(_set_pop.bind(i), 0.0, 1.0, POP_SECONDS) \
			.set_delay(start_delay + i * step).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_pop(value: float, index: int) -> void:
	_pop[index] = value
	queue_redraw()


func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in 10:
		var r := radius if p % 2 == 0 else radius * INNER_RATIO
		var angle := -PI / 2.0 + p * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


func _draw() -> void:
	var slot := size.x / total
	var radius := minf(size.y, slot) * 0.5 * 0.9
	for i in total:
		var center := Vector2(slot * (i + 0.5), size.y * 0.5)
		var points := _star_points(center, radius)
		draw_colored_polygon(points, EMPTY_FILL)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, EMPTY_LINE, 1.5, true)
		if i < stars and _pop[i] > 0.0:
			draw_colored_polygon(_star_points(center, radius * _pop[i]), FILLED)
