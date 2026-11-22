class_name ColorSequenceView
extends Control
## Shows a colour level's order for this attempt: one dot per colour, the
## one needed next drawn larger with a ring and a NEXT label above it.
## Hidden on levels without a colour order. Owns no rules.

const DOT := 22.0
const NEXT_DOT := 32.0
const GAP := 10.0
const RING_WIDTH := 3.0

var _controller: GameController


func _init() -> void:
	custom_minimum_size = Vector2(0, 58)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func bind(controller: GameController) -> void:
	_controller = controller
	visible = controller.has_colors()
	controller.recolored.connect(queue_redraw)
	queue_redraw()


## Place in the order marked NEXT (-1 when hidden).
func next_index() -> int:
	return _controller.color_step() if _controller != null and _controller.has_colors() else -1


func _draw() -> void:
	if _controller == null or not _controller.has_colors() or _controller.board.is_empty():
		return
	var order := _controller.color_sequence
	var step := _controller.color_step()
	var width := (order.size() - 1) * (DOT + GAP) + NEXT_DOT
	var x := (size.x - width) / 2.0
	var y := size.y - NEXT_DOT / 2.0 - 4.0
	var font := get_theme_default_font()
	for i in order.size():
		var big := i == step
		var radius := (NEXT_DOT if big else DOT) / 2.0
		var center := Vector2(x + radius, y)
		var color: Color = Palette.PASTELS[order[i]]
		draw_circle(center, radius, color)
		if big:
			draw_arc(center, radius + 4.0, 0.0, TAU, 32, Color.WHITE, RING_WIDTH, true)
			if font != null:
				var label := "NEXT"
				var font_size := 12
				var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				draw_string(font, Vector2(center.x - text_w / 2.0, y - radius - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.TEXT)
		x += radius * 2.0 + GAP
