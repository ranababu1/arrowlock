class_name MoveValidator
extends RefCounted
## Ray-cast legality checks. An arrow is blocked when any remaining arrow
## occupies a cell on its ray before the board boundary.


## Returns the ID of the nearest blocking arrow, or -1 when the path is clear
## (or the arrow does not exist).
static func first_blocker(board: BoardState, id: int) -> int:
	if not board.has_arrow(id):
		return -1
	var step: Vector2i = BoardState.DIRECTIONS[board.arrow_direction(id)]
	var pos: Vector2i = board.arrow_position(id) + step
	while board.in_bounds(pos):
		var other: int = board.arrow_at(pos)
		if other != -1:
			return other
		pos += step
	return -1


## Every remaining arrow on the ray, nearest first.
static func ray_arrows(board: BoardState, id: int) -> Array[int]:
	var found: Array[int] = []
	if not board.has_arrow(id):
		return found
	var step: Vector2i = BoardState.DIRECTIONS[board.arrow_direction(id)]
	var pos: Vector2i = board.arrow_position(id) + step
	while board.in_bounds(pos):
		var other: int = board.arrow_at(pos)
		if other != -1:
			found.append(other)
		pos += step
	return found


static func can_remove(board: BoardState, id: int) -> bool:
	return board.has_arrow(id) and first_blocker(board, id) == -1


static func removable_ids(board: BoardState) -> Array[int]:
	var result: Array[int] = []
	for id in board.arrow_ids():
		if can_remove(board, id):
			result.append(id)
	return result
