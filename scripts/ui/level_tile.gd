class_name LevelTile
extends Button
## One level on the level-select grid. Draws itself: state decides the look.

enum State { LOCKED, OPEN, CLEARED, CURRENT }

const RADIUS := 16
const PULSE_HZ := 0.8

var level_id := 0
var accent := Palette.PRIMARY
var tile_state := State.OPEN
var _stars: StarRow
var _time := 0.0


func _init(p_level_id: int = 0, p_accent: Color = Palette.PRIMARY, p_state: State = State.OPEN, p_stars: int = 0) -> void:
	level_id = p_level_id
	accent = p_accent
	tile_state = p_state
	custom_minimum_size = Vector2(0, 88)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	disabled = p_state == State.LOCKED
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	_stars = StarRow.new()
	_stars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_stars.offset_top = -29
	_stars.offset_bottom = -9
	_stars.offset_left = 10
	_stars.offset_right = -10
	_stars.set_stars(p_stars)
	_stars.visible = p_state != State.LOCKED
	add_child(_stars)
	set_process(p_state == State.CURRENT)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(RADIUS)
	style.set_border_width_all(2)
	var pressed_boost := 0.10 if get_draw_mode() == DRAW_PRESSED else 0.0
	var label_alpha := 1.0
	match tile_state:
		State.LOCKED:
			style.bg_color = Color(1, 1, 1, 0.04)
			style.border_color = Color(1, 1, 1, 0.06)
			label_alpha = 0.0
		State.OPEN:
			style.bg_color = Color(accent, 0.12 + pressed_boost)
			style.border_color = Color(accent, 0.45)
		State.CLEARED:
			style.bg_color = Color(accent, 0.28 + pressed_boost)
			style.border_color = Color(accent, 0.9)
		State.CURRENT:
			var pulse := 0.5 + 0.5 * sin(_time * PULSE_HZ * TAU)
			style.bg_color = Color(accent, 0.20 + pressed_boost)
			style.border_color = Color(accent.lightened(0.25), 0.6 + 0.4 * pulse)
			style.shadow_color = Color(accent, 0.15 + 0.3 * pulse)
			style.shadow_size = 10
	draw_style_box(style, rect)
	if tile_state == State.LOCKED:
		Glyphs.draw(self, "lock", size * 0.5, 30.0, Color(1, 1, 1, 0.35))
		return
	var font := get_theme_font("font", "Button")
	draw_string(font, Vector2(0, size.y * 0.42), str(Difficulty.local_id(level_id)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1, 1, 1, label_alpha))
