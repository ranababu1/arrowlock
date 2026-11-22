class_name LevelFingerprint
extends RefCounted
## A short hash of everything that defines a level for a player: id, board
## size, move limit, colour order size and every arrow (including whether it is
## a turner or a flipper). Stored in data/levels.lock.json so a
## released level can never change by accident (saved stars belong to it).


## `level` is a loaded level ({"id", "board": BoardState, "moves_limit"}).
static func of(level: Dictionary) -> String:
	var board: BoardState = level["board"]
	var parts: Array[String] = []
	for id in board.arrow_ids():
		var pos := board.arrow_position(id)
		# Turners get a suffix; plain arrows keep the original text so every
		# level frozen before turners existed keeps its fingerprint.
		var kind := ",t" if board.is_turner(id) else (",f" if board.is_flipper(id) else "")
		parts.append("%d,%d,%s%s" % [pos.x, pos.y, board.arrow_direction(id), kind])
	parts.sort()
	var text := "%d|%dx%d|%d|%s" % [level["id"], board.width, board.height, level["moves_limit"], ";".join(parts)]
	# Same rule for the colour order: only levels that have one say so.
	if int(level.get("colors", 0)) > 0:
		text += "|c%d" % int(level["colors"])
	return text.sha256_text().substr(0, 16)
