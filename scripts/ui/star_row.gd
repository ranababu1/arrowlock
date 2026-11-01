class_name StarRow
extends Control
## Draws 0..total stars as shapes (filled vs outlined), so the count never
## depends on colour alone or on font glyph support.

const FILLED := Color(1.0, 0.82, 0.25)
const EMPTY_FILL := Color(1, 1, 1, 0.08)
const EMPTY_LINE := Color(1, 1, 1, 0.35)
const INNER_RATIO := 0.45

var stars: int = 0
var total: int = Economy.MAX_STARS


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_stars(count: int) -> void:
	stars = clampi(count, 0, total)
	queue_redraw()


func _draw() -> void:
	var slot := size.x / total
	var radius := minf(size.y, slot) * 0.5 * 0.9
	for i in total:
		var center := Vector2(slot * (i + 0.5), size.y * 0.5)
		var points := PackedVector2Array()
		for p in 10:
			var r := radius if p % 2 == 0 else radius * INNER_RATIO
			var angle := -PI / 2.0 + p * PI / 5.0
			points.append(center + Vector2(cos(angle), sin(angle)) * r)
		if i < stars:
			draw_colored_polygon(points, FILLED)
		else:
			draw_colored_polygon(points, EMPTY_FILL)
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, EMPTY_LINE, 1.5, true)
