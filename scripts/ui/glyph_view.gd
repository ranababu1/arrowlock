class_name GlyphView
extends Control
## A non-interactive icon, for chips, rows and headers.

var glyph := "":
	set(value):
		glyph = value
		queue_redraw()
var color := Palette.TEXT:
	set(value):
		color = value
		queue_redraw()


func _init(p_glyph: String = "", p_color: Color = Palette.TEXT, p_size: float = 28.0) -> void:
	glyph = p_glyph
	color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	Glyphs.draw(self, glyph, size * 0.5, minf(size.x, size.y), color)
