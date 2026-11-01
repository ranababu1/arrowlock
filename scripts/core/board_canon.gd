class_name BoardCanon
extends RefCounted
## Layout identity under rotation and mirroring, used to detect reused levels.
## Transform t: 0..3 = rotate clockwise t times, 4..7 = mirror then rotate (t-4) times.

const ROTATE_DIR: Dictionary = {"up": "right", "right": "down", "down": "left", "left": "up"}
const MIRROR_DIR: Dictionary = {"left": "right", "right": "left", "up": "up", "down": "down"}
const TRANSFORM_COUNT := 8


## Returns a new board with the same arrow IDs, transformed by `t`.
static func transform(board: BoardState, t: int) -> BoardState:
	var w := board.width
	var h := board.height
	var entries: Array[Array] = []
	for id in board.arrow_ids():
		entries.append([id, board.arrow_position(id), board.arrow_direction(id)])
	if t >= 4:
		for e in entries:
			var pos: Vector2i = e[1]
			e[1] = Vector2i(w - 1 - pos.x, pos.y)
			e[2] = MIRROR_DIR[e[2]]
	for _turn in t % 4:
		for e in entries:
			var pos: Vector2i = e[1]
			e[1] = Vector2i(h - 1 - pos.y, pos.x)
			e[2] = ROTATE_DIR[e[2]]
		var swap := w
		w = h
		h = swap
	var out := BoardState.new(w, h)
	for e in entries:
		out.add_arrow(e[0], e[1], e[2])
	return out


## Order-independent description of the layout alone (ignores arrow IDs).
static func layout_key(board: BoardState) -> String:
	var parts: Array[String] = []
	for id in board.arrow_ids():
		var pos := board.arrow_position(id)
		parts.append("%d,%d,%s" % [pos.x, pos.y, board.arrow_direction(id)])
	parts.sort()
	return "%dx%d|%s" % [board.width, board.height, ";".join(parts)]


## Same string for any rotation or mirror image of the same layout.
static func canonical(board: BoardState) -> String:
	var best := ""
	for t in TRANSFORM_COUNT:
		var key := layout_key(transform(board, t))
		if best == "" or key < best:
			best = key
	return best
