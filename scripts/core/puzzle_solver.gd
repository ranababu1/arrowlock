class_name PuzzleSolver
extends RefCounted
## Offline solvability tooling. Not intended to run per-frame.
##
## Removing an arrow can only unblock others, never block them, so a board is
## solvable iff repeatedly removing any legal arrow clears it (a greedy order
## cannot get stuck unless a blocking cycle exists). `solve` uses this.
## `solve_exhaustive` is an independent DFS used by tests to cross-check it.
##
## Turners break that rule: after each removal they turn, so a clear arrow can
## become blocked and the order matters. Boards with turners are solved by
## `solve_search`, a depth-first search over removal orders. Because every
## removal turns every turner once, a turner's direction follows from how
## many arrows have left, so "which arrows remain" is the whole state.

const SOLVED := 1
const UNSOLVABLE := 0
const OUT_OF_BUDGET := -1
## Default search budget (positions visited) for boards with turners.
const SEARCH_BUDGET := 200000


## Returns a removal order clearing the board, or an empty array if the board
## is unsolvable or already empty. Use `BoardState.is_empty` to tell apart.
## Boards with turners use `solve_search`; an exhausted budget counts as
## unsolvable here.
static func solve(board: BoardState) -> Array[int]:
	if board.has_turners():
		var found := solve_search(board)
		var none: Array[int] = []
		return found["order"] if found["status"] == SOLVED else none
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


## Searches removal orders on a board with turners (works on plain boards
## too). Returns {"status": SOLVED | UNSOLVABLE | OUT_OF_BUDGET,
## "order": Array[int]} where order clears the board when status is SOLVED.
## `budget` caps the number of distinct positions visited. `dead` collects
## positions proven unsolvable; pass the same dictionary to several searches
## on positions of one level to reuse that work.
static func solve_search(board: BoardState, budget: int = SEARCH_BUDGET, dead: Variant = null) -> Dictionary:
	var order: Array[int] = []
	var left: Array[int] = [budget]
	var known: Dictionary = dead if dead is Dictionary else {}
	var ok := _search(board.duplicate_state(), known, left, order)
	if ok:
		return {"status": SOLVED, "order": order}
	return {"status": OUT_OF_BUDGET if left[0] < 0 else UNSOLVABLE, "order": [] as Array[int]}


## Removals only ever shrink the board, so a position cannot repeat on one
## path; a position whose every branch failed (budget left) is dead for good.
static func _search(board: BoardState, dead: Dictionary, left: Array[int], order: Array[int]) -> bool:
	if board.is_empty():
		return true
	# Without turners nothing can get blocked again: greedy settles it.
	if not board.has_turners():
		var rest := solve(board)
		if rest.size() == board.remaining_count():
			order.append_array(rest)
			return true
		return false
	var key: Variant = _state_key(board)
	if dead.has(key):
		return false
	left[0] -= 1
	if left[0] < 0:
		return false
	# Turners first: a clear turner may not stay clear, plain arrows will.
	var moves: Array[int] = []
	var plain: Array[int] = []
	for id in MoveValidator.removable_ids(board):
		if board.is_turner(id):
			moves.append(id)
		else:
			plain.append(id)
	moves.append_array(plain)
	for id in moves:
		var info := board.remove_arrow(id)
		board.rotate_turners(1)
		order.append(id)
		if _search(board, dead, left, order):
			return true
		order.pop_back()
		board.rotate_turners(-1)
		board.restore_arrow(id, info)
		if left[0] < 0:
			return false
	dead[key] = true
	return false


## The set of remaining ids as one int (ids below 62), else as text.
static func _state_key(board: BoardState) -> Variant:
	var ids := board.arrow_ids()
	if ids.is_empty() or ids[-1] < 62:
		var mask := 0
		for id in ids:
			mask |= 1 << id
		return mask
	return ",".join(ids.map(func(i: int) -> String: return str(i)))


## Replays `order` on a copy of `board` with the game's own rules
## (GameController), so a search result can be checked independently.
static func replay_wins(board: BoardState, order: Array[int]) -> bool:
	var c := GameController.new()
	if not c.start(board, board.remaining_count()):
		return false
	for id in order:
		if not c.board.has_arrow(id) or not c.tap(c.board.arrow_position(id)):
			return false
	return c.state == GameController.State.WON


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
