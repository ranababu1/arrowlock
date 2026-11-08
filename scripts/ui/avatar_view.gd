class_name AvatarView
extends Control
## A round profile picture: the player's Play Games picture when there is one,
## otherwise one of the built-in designs (a glyph on a coloured disc).

## Built-in designs, index = Progress.profile_avatar. Keep the count equal to
## Progress.AVATAR_COUNT.
const CHOICES: Array = [
	["arrow", Color("6c5cff")], ["star", Color("ffc83d")], ["bulb", Color("35e0a1")], ["note", Color("ff6fb5")],
	["play", Color("2dd4ff")], ["coin", Color("ff8a5b")], ["check", Color("5b8cff")], ["person", Color("c084fc")],
]
const RING_WIDTH := 3.0

## Index into CHOICES, used when `picture` is null.
var choice := 0:
	set(value):
		choice = clampi(value, 0, CHOICES.size() - 1)
		queue_redraw()
## Play Games picture; drawn instead of the design when set.
var picture: Texture2D:
	set(value):
		picture = value
		queue_redraw()
## Draws a highlight ring (used for the selected design in the picker).
var selected := false:
	set(value):
		selected = value
		queue_redraw()


func _init(p_choice: int = 0, p_size: float = 96.0) -> void:
	choice = p_choice
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - RING_WIDTH
	if picture != null:
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 48:
			var dir := Vector2.from_angle(TAU * i / 48.0)
			points.append(center + dir * radius)
			uvs.append(Vector2(0.5, 0.5) + dir * 0.5)
		draw_colored_polygon(points, Color.WHITE, uvs, picture)
	else:
		var design: Array = CHOICES[choice]
		draw_circle(center, radius, Color(design[1], 0.28))
		Glyphs.draw(self, design[0], center, radius * 1.05, design[1])
	var ring := Palette.TEXT if selected else Palette.GLASS_BORDER
	draw_arc(center, radius, 0, TAU, 48, ring, RING_WIDTH * (1.6 if selected else 1.0), true)
