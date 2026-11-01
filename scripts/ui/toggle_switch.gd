class_name ToggleSwitch
extends Control
## A pill switch with a sliding knob. Emits `toggled` only for user changes.

signal toggled(on: bool)

const TRACK_OFF := Color("3a4166")
const SLIDE_SECONDS := 0.16

var on := false
var _knob := 0.0  ## 0 = off position, 1 = on position


func _init() -> void:
	custom_minimum_size = Vector2(68, 40)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Sets the state without emitting `toggled` (used when loading settings).
func set_on(value: bool, animate: bool = true) -> void:
	on = value
	var target := 1.0 if value else 0.0
	if animate and is_inside_tree():
		create_tween().tween_method(_set_knob, _knob, target, SLIDE_SECONDS)
	else:
		_set_knob(target)


func knob_position() -> float:
	return _knob


func _set_knob(value: float) -> void:
	_knob = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_on(not on)
		toggled.emit(on)
		accept_event()


func _draw() -> void:
	var track := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = TRACK_OFF.lerp(Palette.PRIMARY, _knob)
	style.set_corner_radius_all(int(size.y / 2))
	draw_style_box(style, track)
	var radius := size.y * 0.37
	var x := lerpf(size.y * 0.5, size.x - size.y * 0.5, _knob)
	draw_circle(Vector2(x, size.y * 0.5 + 1.5), radius, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(x, size.y * 0.5), radius, Color.WHITE)
