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


## Independent check used on boards too large for the exhaustive search:
## builds the full dependency graph (an arrow waits for every arrow on its
## ray) and runs Kahn's algorithm. Solvable iff the graph has no cycle.
static func topo_solvable(board: BoardState) -> bool:
	var waiting: Dictionary = {}
	var dependents: Dictionary = {}
	var ready: Array[int] = []
	for id in board.arrow_ids():
		var deps := MoveValidator.ray_arrows(board, id)
		waiting[id] = deps.size()
		for d in deps:
			if not dependents.has(d):
				dependents[d] = []
			dependents[d].append(id)
		if deps.is_empty():
			ready.append(id)
	var done := 0
	while not ready.is_empty():
		var id: int = ready.pop_back()
		done += 1
		for other in dependents.get(id, []):
			waiting[other] -= 1
			if waiting[other] == 0:
				ready.append(other)
	return done == board.remaining_count()


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
