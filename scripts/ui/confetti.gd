class_name Confetti
extends Control
## A short burst of falling coloured pieces for a win. Decoration only.

const PIECES := 70
const LIFETIME := 2.4
const GRAVITY := 520.0
const COLORS: Array[Color] = [
	Palette.PRIMARY, Palette.CYAN, Palette.MINT, Palette.CORAL, Palette.GOLD, Palette.PINK,
]

## Per piece: [position, velocity, angle, spin, size, colour index]
var _pieces: Array[Array] = []
var _age := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_rng.seed = 99  # decoration only


func is_active() -> bool:
	return is_processing()


## Starts a burst from the top-middle of this control.
func burst() -> void:
	_pieces.clear()
	_age = 0.0
	var origin := Vector2(size.x * 0.5, size.y * 0.28)
	for i in PIECES:
		var direction := Vector2.from_angle(_rng.randf_range(-PI * 0.95, -PI * 0.05))
		_pieces.append([origin, direction * _rng.randf_range(220.0, 720.0), _rng.randf() * TAU,
			_rng.randf_range(-9.0, 9.0), _rng.randf_range(7.0, 14.0), _rng.randi_range(0, COLORS.size() - 1)])
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	for piece in _pieces:
		piece[1].y += GRAVITY * delta
		piece[1] *= 1.0 - 0.9 * delta
		piece[0] += piece[1] * delta
		piece[2] += piece[3] * delta
	if _age >= LIFETIME:
		_pieces.clear()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var fade := clampf((LIFETIME - _age) / 0.8, 0.0, 1.0)
	for piece in _pieces:
		var half: float = piece[4] * 0.5
		var color := Color(COLORS[piece[5]], fade)
		var turn := Vector2.from_angle(piece[2])
		var side := Vector2(-turn.y, turn.x)
		draw_colored_polygon(PackedVector2Array([
			piece[0] + turn * half + side * half * 0.5, piece[0] - turn * half + side * half * 0.5,
			piece[0] - turn * half - side * half * 0.5, piece[0] + turn * half - side * half * 0.5]), color)
