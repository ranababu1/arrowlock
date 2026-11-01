class_name Glyphs
extends RefCounted
## Small vector icons drawn with canvas primitives, so the game needs no icon
## font or image files. Call from a CanvasItem's _draw.

const NAMES := ["back", "gear", "coin", "undo", "bulb", "restart", "lock", "note", "speaker", "check", "arrow", "play"]


## Draws `glyph` centred on `center`, fitting a square of edge `size`.
static func draw(canvas: CanvasItem, glyph: String, center: Vector2, size: float, color: Color) -> void:
	var w := maxf(2.0, size * 0.11)
	match glyph:
		"back":
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(0.14, -0.38) * size, center + Vector2(-0.2, 0.0) * size,
				center + Vector2(0.14, 0.38) * size]), color, w, true)
		"gear":
			_gear(canvas, center, size, color, w)
		"coin":
			canvas.draw_circle(center, size * 0.46, color)
			canvas.draw_arc(center, size * 0.28, 0, TAU, 28, Color(0, 0, 0, 0.28), w * 0.8, true)
		"undo":
			_arc_arrow(canvas, center, size * 0.32, 20.0, 205.0, color, w)
		"restart":
			_arc_arrow(canvas, center, size * 0.32, 115.0, -155.0, color, w)
		"bulb":
			canvas.draw_arc(center + Vector2(0, -0.1) * size, size * 0.27, 0, TAU, 28, color, w, true)
			canvas.draw_line(center + Vector2(-0.12, 0.26) * size, center + Vector2(0.12, 0.26) * size, color, w, true)
			canvas.draw_line(center + Vector2(-0.08, 0.38) * size, center + Vector2(0.08, 0.38) * size, color, w, true)
		"lock":
			canvas.draw_rect(Rect2(center + Vector2(-0.28, -0.04) * size, Vector2(0.56, 0.44) * size), color)
			canvas.draw_arc(center + Vector2(0, -0.06) * size, size * 0.18, PI, TAU, 16, color, w, true)
			canvas.draw_line(center + Vector2(-0.18, -0.06) * size, center + Vector2(-0.18, 0.0) * size, color, w)
			canvas.draw_line(center + Vector2(0.18, -0.06) * size, center + Vector2(0.18, 0.0) * size, color, w)
		"note":
			canvas.draw_circle(center + Vector2(-0.12, 0.26) * size, size * 0.15, color)
			canvas.draw_line(center + Vector2(0.02, 0.26) * size, center + Vector2(0.02, -0.34) * size, color, w)
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(0.02, -0.34) * size, center + Vector2(0.3, -0.2) * size,
				center + Vector2(0.3, -0.05) * size]), color, w, true)
		"speaker":
			canvas.draw_rect(Rect2(center + Vector2(-0.4, -0.14) * size, Vector2(0.2, 0.28) * size), color)
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-0.22, -0.14) * size, center + Vector2(0.02, -0.34) * size,
				center + Vector2(0.02, 0.34) * size, center + Vector2(-0.22, 0.14) * size]), color)
			canvas.draw_arc(center + Vector2(0.02, 0) * size, size * 0.2, -0.9, 0.9, 12, color, w, true)
			canvas.draw_arc(center + Vector2(0.02, 0) * size, size * 0.36, -0.9, 0.9, 14, color, w, true)
		"check":
			canvas.draw_polyline(PackedVector2Array([
				center + Vector2(-0.3, 0.02) * size, center + Vector2(-0.08, 0.26) * size,
				center + Vector2(0.32, -0.24) * size]), color, w * 1.2, true)
		"arrow":
			_arrow(canvas, center, size, color, w * 1.3)
		"play":
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-0.2, -0.32) * size, center + Vector2(0.34, 0.0) * size,
				center + Vector2(-0.2, 0.32) * size]), color)


static func _gear(canvas: CanvasItem, c: Vector2, s: float, color: Color, w: float) -> void:
	canvas.draw_arc(c, s * 0.25, 0, TAU, 28, color, w * 1.3, true)
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		canvas.draw_line(c + dir * s * 0.33, c + dir * s * 0.46, color, w * 1.5, true)
	canvas.draw_arc(c, s * 0.37, 0, TAU, 32, color, w * 0.9, true)


## An arc from `from_deg` to `to_deg` (screen angles, y up) with an arrow head
## at the end, pointing along the direction of travel.
static func _arc_arrow(canvas: CanvasItem, c: Vector2, r: float, from_deg: float, to_deg: float, color: Color, w: float) -> void:
	var points := PackedVector2Array()
	var steps := 22
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		points.append(c + Vector2(cos(a), -sin(a)) * r)
	canvas.draw_polyline(points, color, w, true)
	var tip := points[steps]
	var heading := (tip - points[steps - 2]).normalized()
	var side := Vector2(-heading.y, heading.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip + heading * w * 1.6,
		tip - heading * w * 0.6 + side * w * 1.7,
		tip - heading * w * 0.6 - side * w * 1.7]), color)


static func _arrow(canvas: CanvasItem, c: Vector2, s: float, color: Color, w: float) -> void:
	canvas.draw_line(c + Vector2(-0.34, 0) * s, c + Vector2(0.1, 0) * s, color, w, true)
	canvas.draw_circle(c + Vector2(-0.34, 0) * s, w * 0.5, color)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0.4, 0) * s, c + Vector2(0.06, -0.3) * s, c + Vector2(0.06, 0.3) * s]), color)
