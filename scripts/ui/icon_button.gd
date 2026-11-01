class_name IconButton
extends Button
## A round button showing one Glyphs icon.

var glyph := "":
	set(value):
		glyph = value
		queue_redraw()
var glyph_color := Palette.TEXT:
	set(value):
		glyph_color = value
		queue_redraw()


func _init(p_glyph: String = "", p_size: float = 56.0) -> void:
	glyph = p_glyph
	theme_type_variation = "IconButton"
	custom_minimum_size = Vector2(p_size, p_size)
	focus_mode = Control.FOCUS_NONE


func _draw() -> void:
	var tint := glyph_color if not disabled else Color(glyph_color, 0.35)
	Glyphs.draw(self, glyph, size * 0.5, minf(size.x, size.y) * 0.5, tint)
