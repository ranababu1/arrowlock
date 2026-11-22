class_name LevelMetrics
extends RefCounted
## Difficulty descriptors for a board, used to shape the curve and to review
## generated levels. These describe a board; they are not a difficulty score.

## A blocked arrow is "bait" when its ray is clear for at least this many
## cells before the first blocker, so it looks free at a glance.
const BAIT_MIN_CLEAR_RUN := 2
## Search budget for each opening move when counting traps.
const TRAP_SEARCH_BUDGET := 4000


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
		# With turners or flippers the starting directions can block each
		# other in a ring that later turns or flips break: depth is undefined.
		if not board.has_turners() and not board.has_flippers():
			depth = maxi(depth, _depth_of(board, id, depth_memo))
	var out := {
		"arrows": board.remaining_count(),
		"width": board.width,
		"height": board.height,
		"free_at_start": free,
		"blocked_at_start": board.remaining_count() - free,
		"depth": depth,
		"bait": bait,
	}
	if board.has_turners():
		out.merge(turner_metrics(board))
	if board.has_flippers():
		out["flippers"] = board.flipper_count()
		out["timed_flips"] = timed_flips(board)
	return out


## Flippers that can only ever leave one of their two ways (the other is
## blocked by an arrow that waits for them): those need a well-timed tap.
static func timed_flips(board: BoardState) -> int:
	var count := 0
	for id in board.arrow_ids():
		if not board.is_flipper(id):
			continue
		var a := MoveValidator.first_blocker_toward(board, id, board.arrow_direction(id))
		var b := MoveValidator.first_blocker_toward(board, id, board.other_direction(id))
		if (a == -1) != (b == -1) or (a != -1 and b != -1):
			count += 1
	return count


## For boards with turners, measured along one winning line (the search's):
## "turners" (how many), "traps" (over every position on that line, the clear
## arrows whose removal leaves a board that can no longer be cleared),
## "trap_steps" (positions on the line with at least one such arrow) and
## "safe_starts" (clear opening moves that still win). A move the search
## cannot settle within `budget` counts as safe. `depth` is reported as 0 for
## such boards.
static func turner_metrics(board: BoardState, budget: int = TRAP_SEARCH_BUDGET) -> Dictionary:
	var traps := 0
	var trap_steps := 0
	var safe_starts := 0
	var dead: Dictionary = {}
	var line: Array = PuzzleSolver.solve_search(board, PuzzleSolver.SEARCH_BUDGET, dead)["order"]
	var work := board.duplicate_state()
	for step in line.size():
		var here := 0
		if work.has_turners():
			for id in MoveValidator.reachable_ids(work):
				var after := work.duplicate_state()
				after.remove_arrow(id)
				after.rotate_turners(1)
				if PuzzleSolver.solve_search(after, budget, dead)["status"] == PuzzleSolver.UNSOLVABLE:
					here += 1
				elif step == 0:
					safe_starts += 1
		elif step == 0:
			safe_starts = MoveValidator.reachable_ids(work).size()
		traps += here
		if here > 0:
			trap_steps += 1
		work.remove_arrow(line[step])
		work.rotate_turners(1)
	return {"turners": board.turner_count(), "traps": traps, "trap_steps": trap_steps, "safe_starts": safe_starts}


## 0 for an arrow with a clear ray; otherwise 1 + the deepest arrow it waits for.
static func _depth_of(board: BoardState, id: int, memo: Dictionary) -> int:
	if memo.has(id):
		return memo[id]
	var deepest := -1
	for other in MoveValidator.ray_arrows(board, id):
		deepest = maxi(deepest, _depth_of(board, other, memo))
	memo[id] = deepest + 1
	return memo[id]
