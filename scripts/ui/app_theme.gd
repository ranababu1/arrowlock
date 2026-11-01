class_name AppTheme
extends RefCounted
## The shared look. Type variations (set `theme_type_variation` on a control):
##   Button:         PrimaryButton, DangerButton, IconButton
##   PanelContainer: Card
##   Label:          Heading, Subheading, Muted, Caption

const FONT_DIR := "res://assets/fonts/"


static func build() -> Theme:
	var theme := Theme.new()
	var regular: Font = load(FONT_DIR + "Poppins-Regular.ttf")
	var medium: Font = load(FONT_DIR + "Poppins-Medium.ttf")
	var semibold: Font = load(FONT_DIR + "Poppins-SemiBold.ttf")
	var bold: Font = load(FONT_DIR + "Poppins-Bold.ttf")
	theme.default_font = regular
	theme.default_font_size = 18

	_buttons(theme, semibold)
	_panels(theme)
	_labels(theme, regular, medium, semibold, bold)
	_scrollbars(theme)
	return theme


static func _buttons(theme: Theme, font: Font) -> void:
	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", 20)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", Palette.TEXT)
	theme.set_color("font_disabled_color", "Button", Color(Palette.TEXT, 0.4))
	theme.set_stylebox("normal", "Button", _box(Palette.GLASS, Palette.GLASS_BORDER, 18))
	theme.set_stylebox("hover", "Button", _box(Palette.GLASS_HOVER, Palette.GLASS_BORDER, 18))
	theme.set_stylebox("pressed", "Button", _box(Palette.GLASS_PRESSED, Palette.GLASS_BORDER, 18))
	theme.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 18))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	theme.set_type_variation("PrimaryButton", "Button")
	var glow := Color(Palette.PRIMARY, 0.45)
	theme.set_stylebox("normal", "PrimaryButton", _box(Palette.PRIMARY, Color(1, 1, 1, 0.18), 20, glow, 14, Vector2(0, 5)))
	theme.set_stylebox("hover", "PrimaryButton", _box(Palette.PRIMARY_HOVER, Color(1, 1, 1, 0.22), 20, glow, 16, Vector2(0, 5)))
	theme.set_stylebox("pressed", "PrimaryButton", _box(Palette.PRIMARY_PRESSED, Color(1, 1, 1, 0.12), 20, Color(Palette.PRIMARY, 0.25), 6, Vector2(0, 2)))
	theme.set_stylebox("disabled", "PrimaryButton", _box(Color("3a3566"), Color(1, 1, 1, 0.06), 20))

	theme.set_type_variation("DangerButton", "Button")
	var heat := Color(Palette.RED, 0.45)
	theme.set_stylebox("normal", "DangerButton", _box(Palette.RED.darkened(0.15), Color(1, 1, 1, 0.18), 20, heat, 14, Vector2(0, 5)))
	theme.set_stylebox("hover", "DangerButton", _box(Palette.RED, Color(1, 1, 1, 0.22), 20, heat, 16, Vector2(0, 5)))
	theme.set_stylebox("pressed", "DangerButton", _box(Palette.RED.darkened(0.35), Color(1, 1, 1, 0.12), 20, Color(Palette.RED, 0.25), 6, Vector2(0, 2)))
	theme.set_stylebox("disabled", "DangerButton", _box(Color("5a2f3d"), Color(1, 1, 1, 0.06), 20))

	theme.set_type_variation("IconButton", "Button")
	theme.set_stylebox("normal", "IconButton", _box(Palette.GLASS, Palette.GLASS_BORDER, 100))
	theme.set_stylebox("hover", "IconButton", _box(Palette.GLASS_HOVER, Palette.GLASS_BORDER, 100))
	theme.set_stylebox("pressed", "IconButton", _box(Palette.GLASS_PRESSED, Palette.GLASS_BORDER, 100))
	theme.set_stylebox("disabled", "IconButton", _box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.06), 100))


static func _panels(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer",
		_box(Color(Palette.SURFACE, 0.97), Color(1, 1, 1, 0.14), 28, Color(0, 0, 0, 0.55), 30, Vector2(0, 10), 8))
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", _box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.10), 22, Color(0, 0, 0, 0), 0, Vector2.ZERO, 6))


static func _labels(theme: Theme, regular: Font, medium: Font, semibold: Font, bold: Font) -> void:
	theme.set_color("font_color", "Label", Palette.TEXT)
	_label_variation(theme, "Heading", bold, 36, Palette.TEXT)
	_label_variation(theme, "Subheading", semibold, 22, Palette.TEXT)
	_label_variation(theme, "Muted", regular, 16, Palette.MUTED)
	_label_variation(theme, "Caption", medium, 13, Palette.MUTED)


static func _label_variation(theme: Theme, variation: String, font: Font, font_size: int, color: Color) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font("font", variation, font)
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _scrollbars(theme: Theme) -> void:
	var grabber := _box(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 4)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)


static func _box(fill: Color, border: Color, radius: int, shadow: Color = Color(0, 0, 0, 0),
		shadow_size: int = 0, shadow_offset: Vector2 = Vector2.ZERO, margin: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1 if border.a < 0.2 else 2)
	box.set_corner_radius_all(radius)
	box.shadow_color = shadow
	box.shadow_size = shadow_size
	box.shadow_offset = shadow_offset
	box.content_margin_left = margin + 4
	box.content_margin_right = margin + 4
	box.content_margin_top = margin - 2
	box.content_margin_bottom = margin - 2
	return box
