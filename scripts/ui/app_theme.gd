class_name AppTheme
extends RefCounted
## One shared look: buttons and panels with visible edges on the dark background.

const BUTTON_FILL := Color(0.18, 0.22, 0.30)
const BUTTON_HOVER := Color(0.24, 0.29, 0.39)
const BUTTON_PRESSED := Color(0.30, 0.36, 0.48)
const BUTTON_DISABLED := Color(0.12, 0.14, 0.19)
const BUTTON_BORDER := Color(0.42, 0.50, 0.65)
const DISABLED_TEXT := Color(1, 1, 1, 0.4)
const PANEL_FILL := Color(0.10, 0.12, 0.17)
const PANEL_BORDER := Color(0.42, 0.50, 0.65)
const CORNER := 12


static func build() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _box(BUTTON_FILL, BUTTON_BORDER))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER, BUTTON_BORDER))
	theme.set_stylebox("pressed", "Button", _box(BUTTON_PRESSED, BUTTON_BORDER))
	theme.set_stylebox("disabled", "Button", _box(BUTTON_DISABLED, Color(BUTTON_BORDER, 0.25)))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color.WHITE))
	theme.set_color("font_disabled_color", "Button", DISABLED_TEXT)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL_FILL, PANEL_BORDER))
	return theme


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(CORNER)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
