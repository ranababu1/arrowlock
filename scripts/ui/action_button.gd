class_name ActionButton
extends Button
## A helper button: icon on top, label below, and an optional coin price.

var glyph := ""
var label_text := ""
var price := 0:
	set(value):
		price = value
		queue_redraw()


func _init(p_glyph: String = "", p_label: String = "", p_price: int = 0) -> void:
	glyph = p_glyph
	label_text = p_label
	price = p_price
	custom_minimum_size = Vector2(0, 92)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_NONE
	text = ""


func _draw() -> void:
	var alpha := 0.4 if disabled else 1.0
	var font := get_theme_font("font", "Button")
	Glyphs.draw(self, glyph, Vector2(size.x * 0.5, size.y * 0.30), 30.0, Color(Palette.TEXT, alpha))
	draw_string(font, Vector2(0, size.y * 0.64), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(Palette.TEXT, alpha))
	if price > 0:
		var price_text := str(price)
		var width := font.get_string_size(price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var start := (size.x - (width + 20.0)) * 0.5
		Glyphs.draw(self, "coin", Vector2(start + 8.0, size.y * 0.82 - 4.0), 16.0, Color(Palette.GOLD, alpha))
		draw_string(font, Vector2(start + 20.0, size.y * 0.82), price_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Palette.GOLD, alpha))
