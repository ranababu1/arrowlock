class_name VolumeBar
extends Control
## A draggable 0..1 level bar. `changed` fires while dragging, `released` once
## when the finger lifts (the moment to save).

signal changed(value: float)
signal released(value: float)

const TRACK_HEIGHT := 10.0
const KNOB_RADIUS := 15.0

var value := 1.0
var _dragging := false


func _init() -> void:
	custom_minimum_size = Vector2(120, 44)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Sets the level without emitting signals (used when loading settings).
func set_value(new_value: float) -> void:
	value = clampf(new_value, 0.0, 1.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_set_from_x(event.position.x)
		elif _dragging:
			_dragging = false
			released.emit(value)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()


func _set_from_x(x: float) -> void:
	var span := maxf(1.0, size.x - KNOB_RADIUS * 2.0)
	value = clampf((x - KNOB_RADIUS) / span, 0.0, 1.0)
	queue_redraw()
	changed.emit(value)


func _draw() -> void:
	var span := size.x - KNOB_RADIUS * 2.0
	var y := size.y * 0.5
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.12)
	track.set_corner_radius_all(int(TRACK_HEIGHT / 2.0))
	draw_style_box(track, Rect2(Vector2(KNOB_RADIUS, y - TRACK_HEIGHT / 2.0), Vector2(span, TRACK_HEIGHT)))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.PRIMARY
	fill.set_corner_radius_all(int(TRACK_HEIGHT / 2.0))
	draw_style_box(fill, Rect2(Vector2(KNOB_RADIUS, y - TRACK_HEIGHT / 2.0), Vector2(maxf(TRACK_HEIGHT, span * value), TRACK_HEIGHT)))
	var x := KNOB_RADIUS + span * value
	draw_circle(Vector2(x, y + 1.5), KNOB_RADIUS * 0.8, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(x, y), KNOB_RADIUS * 0.8, Color.WHITE)
