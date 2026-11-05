class_name LevelFingerprint
extends RefCounted
## A short hash of everything that defines a level for a player: id, board
## size, move limit and every arrow. Stored in data/levels.lock.json so a
## released level can never change by accident (saved stars belong to it).


## `level` is a loaded level ({"id", "board": BoardState, "moves_limit"}).
static func of(level: Dictionary) -> String:
	var board: BoardState = level["board"]
	var parts: Array[String] = []
	for id in board.arrow_ids():
		var pos := board.arrow_position(id)
		parts.append("%d,%d,%s" % [pos.x, pos.y, board.arrow_direction(id)])
	parts.sort()
	var text := "%d|%dx%d|%d|%s" % [level["id"], board.width, board.height, level["moves_limit"], ";".join(parts)]
	return text.sha256_text().substr(0, 16)
