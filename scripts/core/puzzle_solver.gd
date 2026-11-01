class_name PuzzleSolver
extends RefCounted
## Offline solvability tooling. Not intended to run per-frame.
##
## Removing an arrow can only unblock others, never block them, so a board is
## solvable iff repeatedly removing any legal arrow clears it (a greedy order
## cannot get stuck unless a blocking cycle exists). `solve` uses this.
## `solve_exhaustive` is an independent DFS used by tests to cross-check it.


## Returns a removal order clearing the board, or an empty array if the board
## is unsolvable or already empty. Use `BoardState.is_empty` to tell apart.
static func solve(board: BoardState) -> Array[int]:
	var work := board.duplicate_state()
	var order: Array[int] = []
	while not work.is_empty():
		var options := MoveValidator.removable_ids(work)
		if options.is_empty():
			return []
		work.remove_arrow(options[0])
		order.append(options[0])
	return order


static func is_solvable(board: BoardState) -> bool:
	return board.is_empty() or not solve(board).is_empty()


## Independent verification path: depth-first search over all legal orders,
## memoised by remaining-arrow set. Bounded by `node_budget`; returns -1 for
## "budget exceeded", 1 for solvable, 0 for unsolvable.
static func solve_exhaustive(board: BoardState, node_budget: int = 200000) -> int:
	var seen: Dictionary = {}
	var budget: Array[int] = [node_budget]
	var result := _dfs(board.duplicate_state(), seen, budget)
	if budget[0] < 0:
		return -1
	return 1 if result else 0


static func _dfs(board: BoardState, seen: Dictionary, budget: Array[int]) -> bool:
	if board.is_empty():
		return true
	var key := ",".join(board.arrow_ids().map(func(i: int) -> String: return str(i)))
	if seen.has(key):
		return false
	seen[key] = true
	budget[0] -= 1
	if budget[0] < 0:
		return false
	for id in MoveValidator.removable_ids(board):
		var info := board.remove_arrow(id)
		var ok := _dfs(board, seen, budget)
		board.restore_arrow(id, info)
		if ok:
			return true
	return false
