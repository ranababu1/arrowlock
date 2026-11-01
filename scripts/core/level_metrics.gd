class_name LevelMetrics
extends RefCounted
## Difficulty descriptors for a board, used to shape the curve and to review
## generated levels. These describe a board; they are not a difficulty score.

## A blocked arrow is "bait" when its ray is clear for at least this many
## cells before the first blocker, so it looks free at a glance.
const BAIT_MIN_CLEAR_RUN := 2


static func compute(board: BoardState) -> Dictionary:
	var free := 0
	var bait := 0
	var depth_memo: Dictionary = {}
	var depth := 0
	for id in board.arrow_ids():
		var ray := MoveValidator.ray_arrows(board, id)
		if ray.is_empty():
			free += 1
		else:
			var distance := (board.arrow_position(ray[0]) - board.arrow_position(id)).abs()
			if distance.x + distance.y - 1 >= BAIT_MIN_CLEAR_RUN:
				bait += 1
		depth = maxi(depth, _depth_of(board, id, depth_memo))
	return {
		"arrows": board.remaining_count(),
		"width": board.width,
		"height": board.height,
		"free_at_start": free,
		"blocked_at_start": board.remaining_count() - free,
		"depth": depth,
		"bait": bait,
	}


## 0 for an arrow with a clear ray; otherwise 1 + the deepest arrow it waits for.
static func _depth_of(board: BoardState, id: int, memo: Dictionary) -> int:
	if memo.has(id):
		return memo[id]
	var deepest := -1
	for other in MoveValidator.ray_arrows(board, id):
		deepest = maxi(deepest, _depth_of(board, other, memo))
	memo[id] = deepest + 1
	return memo[id]
