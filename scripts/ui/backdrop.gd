class_name Backdrop
extends Control
## Full-screen background: a deep gradient, two soft colour glows and a few
## faint arrows drifting upward. Purely decorative; ignores all input.

const ARROW_COUNT := 9
const GLOW_TEXTURE_SIZE := 256

## Turn off on screens where drifting arrows could be mistaken for puzzle arrows.
var show_arrows := true:
	set(value):
		show_arrows = value
		queue_redraw()

var _time := 0.0
## Per arrow: [x fraction, phase, speed, size, direction index, alpha]
var _arrows: Array[Array] = []
var _violet_glow: GradientTexture2D
var _cyan_glow: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_violet_glow = _radial_glow(Palette.PRIMARY, 0.30)
	_cyan_glow = _radial_glow(Palette.CYAN, 0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024  # decoration only; fixed so the look is stable
	for i in ARROW_COUNT:
		_arrows.append([rng.randf_range(0.05, 0.95), rng.randf(), rng.randf_range(0.012, 0.03),
			rng.randf_range(26.0, 56.0), rng.randi_range(0, 3), rng.randf_range(0.05, 0.1)])


## A smooth radial fade rendered once as a texture: no banding, and far cheaper
## than redrawing stacked circles every frame.
static func _radial_glow(color: Color, strength: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(color, strength), Color(color, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = GLOW_TEXTURE_SIZE
	texture.height = GLOW_TEXTURE_SIZE
	return texture


func _process(delta: float) -> void:
	if show_arrows:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var colors := PackedColorArray([Palette.BG_TOP, Palette.BG_TOP, Palette.BG_BOTTOM, Palette.BG_BOTTOM])
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, 0), rect.end, Vector2(0, rect.end.y)]), colors)
	_draw_glow(_violet_glow, Vector2(size.x * 0.1, size.y * 0.08), size.x * 0.95)
	_draw_glow(_cyan_glow, Vector2(size.x * 0.95, size.y * 0.95), size.x * 0.9)
	if not show_arrows:
		return
	for a in _arrows:
		var progress := fposmod(a[1] + _time * a[2], 1.0)
		var pos := Vector2(size.x * a[0] + sin(_time * 0.4 + a[1] * 6.0) * 14.0, size.y * (1.1 - progress * 1.2))
		var edge := progress * 4.0
		var fade := clampf(minf(edge, 4.0 - edge), 0.0, 1.0)
		_faint_arrow(pos, a[3], a[4], Color(1, 1, 1, a[5] * fade))


func _draw_glow(texture: Texture2D, center: Vector2, radius: float) -> void:
	draw_texture_rect(texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)


func _faint_arrow(center: Vector2, edge: float, dir_index: int, color: Color) -> void:
	var step := Vector2.from_angle(dir_index * PI / 2.0)
	var perp := Vector2(-step.y, step.x)
	draw_line(center - step * edge * 0.4, center + step * edge * 0.1, color, edge * 0.14, true)
	draw_colored_polygon(PackedVector2Array([
		center + step * edge * 0.42, center + step * edge * 0.0 + perp * edge * 0.26,
		center + step * edge * 0.0 - perp * edge * 0.26]), color)
