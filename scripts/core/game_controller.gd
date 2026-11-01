class_name GameController
extends RefCounted
## Coordinates a single puzzle session: taps, move limit, undo, restart.
## Pure logic; presentation listens to the signals below.
##
## Rules: every tap that lands on an arrow costs one move, whether or not the
## arrow can leave. Taps on empty cells are free. The level is lost when the
## moves run out while arrows remain.

enum State { PLAYING, WON, LOST }

signal arrow_removed(id: int, info: Dictionary)
signal arrow_restored(id: int)
signal move_blocked(id: int, blocker_id: int)
signal completed(moves_used: int)
signal lost(wasted_taps: int)

var board: BoardState
var state: State = State.PLAYING
var moves_limit: int = 0
var moves_used: int = 0
var wasted_taps: int = 0

var _initial: BoardState
## Stack of {"id": int, "info": Dictionary}; removals only.
var _history: Array[Dictionary] = []


## Returns false (and leaves the controller unusable) when the limit is below
## the arrow count, because such a level could never be won.
func start(puzzle: BoardState, p_moves_limit: int) -> bool:
	if p_moves_limit < puzzle.remaining_count():
		push_error("moves_limit %d is below arrow count %d" % [p_moves_limit, puzzle.remaining_count()])
		return false
	_initial = puzzle.duplicate_state()
	moves_limit = p_moves_limit
	restart()
	return true


func restart() -> void:
	board = _initial.duplicate_state()
	_history.clear()
	state = State.PLAYING
	moves_used = 0
	wasted_taps = 0


func moves_left() -> int:
	return moves_limit - moves_used


func is_over() -> bool:
	return state != State.PLAYING


## Handles a tap on cell `pos`. Returns true if an arrow was removed.
func tap(pos: Vector2i) -> bool:
	if state != State.PLAYING:
		return false
	var id := board.arrow_at(pos)
	if id == -1:
		return false
	moves_used += 1
	var blocker := MoveValidator.first_blocker(board, id)
	if blocker != -1:
		wasted_taps += 1
		move_blocked.emit(id, blocker)
		_check_loss()
		return false
	var info := board.remove_arrow(id)
	_history.append({"id": id, "info": info})
	arrow_removed.emit(id, info)
	# A win on the last allowed move counts as a win, so check it first.
	if board.is_empty():
		state = State.WON
		completed.emit(moves_used)
	else:
		_check_loss()
	return true


func can_undo() -> bool:
	return state == State.PLAYING and not _history.is_empty()


## Restores the last removed arrow and refunds the move that removed it.
## Wasted taps are not refunded. Disabled once the level is over.
func undo() -> bool:
	if not can_undo():
		return false
	var entry: Dictionary = _history.pop_back()
	board.restore_arrow(entry["id"], entry["info"])
	moves_used -= 1
	arrow_restored.emit(entry["id"])
	return true


func _check_loss() -> void:
	if moves_used >= moves_limit and not board.is_empty():
		state = State.LOST
		lost.emit(wasted_taps)
