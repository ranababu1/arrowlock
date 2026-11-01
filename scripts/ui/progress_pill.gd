class_name ProgressPill
extends Control
## A thin rounded progress bar.

var ratio := 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()
var color := Palette.PRIMARY:
	set(value):
		color = value
		queue_redraw()


func _init(p_height: float = 8.0) -> void:
	custom_minimum_size = Vector2(0, p_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var radius := int(size.y / 2.0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.10)
	track.set_corner_radius_all(radius)
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	if ratio > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(radius)
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * ratio), size.y)))
