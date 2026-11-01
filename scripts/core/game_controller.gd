class_name GameController
extends RefCounted
## Coordinates a single puzzle session: taps, move limit, undo, restart.
## Pure logic; presentation listens to the signals below.
##
## Rules: every tap that lands on an arrow costs one move, whether or not the
## arrow can leave. Taps on empty cells are free. The level is lost when the
## moves run out while arrows remain.
##
## Optional countdown: the clock starts at the first tap on an arrow and is
## refilled by every later one (and by Undo and Hint). Running out of time
## loses the level.

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
## Moves added by continuing after a loss in this attempt (0 = none yet).
var extra_moves_granted: int = 0
## Seconds allowed between taps; 0 means the level has no clock.
var countdown: float = 0.0
var time_left: float = 0.0
var lost_by_time := false

var _clock_running := false
var _initial: BoardState
var _original_limit: int = 0
## Stack of {"id": int, "info": Dictionary}; removals only.
var _history: Array[Dictionary] = []


## Returns false (and leaves the controller unusable) when the limit is below
## the arrow count, because such a level could never be won.
func start(puzzle: BoardState, p_moves_limit: int, p_countdown: float = 0.0) -> bool:
	if p_moves_limit < puzzle.remaining_count():
		push_error("moves_limit %d is below arrow count %d" % [p_moves_limit, puzzle.remaining_count()])
		return false
	_initial = puzzle.duplicate_state()
	_original_limit = p_moves_limit
	countdown = maxf(0.0, p_countdown)
	restart()
	return true


func restart() -> void:
	board = _initial.duplicate_state()
	_history.clear()
	state = State.PLAYING
	moves_used = 0
	wasted_taps = 0
	extra_moves_granted = 0
	moves_limit = _original_limit
	time_left = countdown
	lost_by_time = false
	_clock_running = false


func moves_left() -> int:
	return moves_limit - moves_used


func is_over() -> bool:
	return state != State.PLAYING


func has_clock() -> bool:
	return countdown > 0.0


## True once the first arrow has been tapped and the clock is running.
func clock_running() -> bool:
	return _clock_running and state == State.PLAYING


## Advances the clock by `delta` seconds. Does nothing before the first tap,
## without a countdown, or once the level is over.
func tick(delta: float) -> void:
	if state != State.PLAYING or countdown <= 0.0 or not _clock_running:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		state = State.LOST
		lost_by_time = true
		lost.emit(wasted_taps)


## Refills the clock (Undo and Hint are deliberate actions, not stalling).
func refill_clock() -> void:
	if countdown > 0.0 and _clock_running and state == State.PLAYING:
		time_left = countdown


## Handles a tap on cell `pos`. Returns true if an arrow was removed.
func tap(pos: Vector2i) -> bool:
	if state != State.PLAYING:
		return false
	var id := board.arrow_at(pos)
	if id == -1:
		return false
	moves_used += 1
	if countdown > 0.0:
		_clock_running = true
		time_left = countdown
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


## ID of a currently clear arrow, or -1 if none. Costs no move; the caller
## charges coins.
func hint() -> int:
	if state != State.PLAYING:
		return -1
	var options := MoveValidator.removable_ids(board)
	return options[0] if not options.is_empty() else -1


## Continue a lost level with `count` more moves, once per attempt.
## Not possible after a timeout: more moves would not give back the time.
func grant_extra_moves(count: int) -> bool:
	if state != State.LOST or lost_by_time or extra_moves_granted > 0 or count <= 0:
		return false
	moves_limit += count
	extra_moves_granted = count
	state = State.PLAYING
	time_left = countdown
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
	refill_clock()
	arrow_restored.emit(entry["id"])
	return true


func _check_loss() -> void:
	if moves_used >= moves_limit and not board.is_empty():
		state = State.LOST
		lost.emit(wasted_taps)
