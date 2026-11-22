class_name GameController
extends RefCounted
## Coordinates a single puzzle session: taps, move limit, undo, restart.
## Pure logic; presentation listens to the signals below.
##
## Rules: every tap that lands on an arrow costs one move, whether or not the
## arrow can leave. Taps on empty cells are free. The level is lost when the
## moves run out while arrows remain.
##
## Turners: after every arrow that leaves, each remaining turner turns 90
## degrees clockwise (blocked taps turn nothing). Undo turns them back.
##
## Flippers: every `flip_period` seconds each flipper swaps to the opposite
## direction. A tap counts if it points at free space, or did until less than
## FLIP_GRACE seconds ago. Undo does not change the flip clock.
##
## Colour order (`color_count` > 0): each attempt draws a new order of that
## many colours. The next arrow to leave must have the colour at the current
## place in the order (which repeats). A clear arrow of another colour costs a
## move like a blocked tap. After every tap every arrow gets a new random
## colour, but always so that at least one arrow that keeps the level
## winnable has the colour needed next.
##
## Optional countdown: the clock starts at the first tap on an arrow and is
## refilled by every later one (and by Undo and Hint). Running out of time
## loses the level.

enum State { PLAYING, WON, LOST }

## Search budget (positions) for hints on boards with turners.
const HINT_SEARCH_BUDGET := 20000
## A tap this soon after a flip still counts for the direction just left.
const FLIP_GRACE := 0.1
## Colours a colour order can draw from (Palette.PASTELS has this many).
const COLOR_CHOICES := 10

signal arrow_removed(id: int, info: Dictionary)
signal arrow_restored(id: int)
## Remaining turners turned by `steps` quarter turns (1 after a removal,
## -1 when an undo takes one back).
signal turners_rotated(steps: int)
## Every flipper just swapped direction.
signal flipped
## The arrows were given new colours (colour levels only).
signal recolored
signal move_blocked(id: int, blocker_id: int)
## A clear arrow of the wrong colour was tapped (costs a move).
signal wrong_color(id: int)
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
## Seconds spent on this attempt so far, counted from the start (not the
## first tap, so studying the board counts too). Drives the speed bonus.
var elapsed: float = 0.0
## Seconds between flips; 0 when the level has no flippers.
var flip_period: float = 0.0
## Number of colours in the order; 0 when the level has no colour order.
var color_count: int = 0
## This attempt's colour order (indices 0..COLOR_CHOICES-1, drawn with Palette.PASTELS).
var color_sequence: Array[int] = []
## Random source for colours. Seed it for repeatable tests.
var rng := RandomNumberGenerator.new()

var _clock_running := false
var _initial: BoardState
var _original_limit: int = 0
var _flip_elapsed: float = 0.0
## Seconds since the last flip (large before the first one).
var _since_flip: float = 1000.0
## arrow id -> colour index, for remaining arrows.
var _colors: Dictionary = {}
## The arrow guaranteed to have the needed colour after the last recolour.
var _fair_id: int = -1
## One entry per move, oldest first: {"id": int, "info": Dictionary} for a
## removal, {"id": int, "blocked": true} for a wasted tap. On colour levels
## each also holds "colors" and "fair", the colours before the tap.
var _history: Array[Dictionary] = []


## Returns false (and leaves the controller unusable) when the limit is below
## the arrow count, because such a level could never be won.
func start(puzzle: BoardState, p_moves_limit: int, p_countdown: float = 0.0, p_flip_period: float = 0.0, p_color_count: int = 0) -> bool:
	if p_moves_limit < puzzle.remaining_count():
		push_error("moves_limit %d is below arrow count %d" % [p_moves_limit, puzzle.remaining_count()])
		return false
	_initial = puzzle.duplicate_state()
	_original_limit = p_moves_limit
	countdown = maxf(0.0, p_countdown)
	flip_period = maxf(0.0, p_flip_period) if puzzle.has_flippers() else 0.0
	color_count = clampi(p_color_count, 0, COLOR_CHOICES)
	restart()
	return true


## A fresh attempt. Colour levels draw a new colour order every time.
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
	elapsed = 0.0
	_clock_running = false
	_flip_elapsed = 0.0
	_since_flip = 1000.0
	color_sequence.clear()
	_colors.clear()
	_fair_id = -1
	if color_count > 0:
		var pool: Array[int] = []
		for i in COLOR_CHOICES:
			pool.append(i)
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var swap := pool[i]
			pool[i] = pool[j]
			pool[j] = swap
		color_sequence = pool.slice(0, color_count)
		_recolor()


func moves_left() -> int:
	return moves_limit - moves_used


func is_over() -> bool:
	return state != State.PLAYING


func has_clock() -> bool:
	return countdown > 0.0


func has_colors() -> bool:
	return color_count > 0


## True once the first arrow has been tapped and the clock is running.
func clock_running() -> bool:
	return _clock_running and state == State.PLAYING


## Colour index of an arrow on a colour level (-1 otherwise).
func color_of(id: int) -> int:
	return _colors.get(id, -1)


## Place in the colour order of the arrow that must leave next.
func color_step() -> int:
	if color_count == 0:
		return -1
	return (_initial.remaining_count() - board.remaining_count()) % color_sequence.size()


## Colour index the next arrow to leave must have (-1 without colours).
func needed_color() -> int:
	return color_sequence[color_step()] if color_count > 0 else -1


## Advances time by `delta` seconds: the attempt's elapsed time and the flip
## clock always, and the countdown once the first arrow is tapped (when the
## level has one). Does nothing once the level is over.
func tick(delta: float) -> void:
	if state != State.PLAYING or delta <= 0.0:
		return
	elapsed += delta
	if flip_period > 0.0 and board.has_flippers():
		_flip_elapsed += delta
		_since_flip += delta
		while _flip_elapsed >= flip_period:
			_flip_elapsed -= flip_period
			_since_flip = _flip_elapsed
			board.flip_flippers()
			flipped.emit()
	if countdown <= 0.0 or not _clock_running:
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


## Seconds until the flippers next swap (0 when there are none).
func time_to_flip() -> float:
	return flip_period - _flip_elapsed if flip_period > 0.0 else 0.0


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
	var before := _color_snapshot()
	var exit_dir := _exit_direction(id)
	if exit_dir == "":
		wasted_taps += 1
		_history.append(_entry({"id": id, "blocked": true}, before))
		move_blocked.emit(id, MoveValidator.first_blocker(board, id))
		_recolor()
		_check_loss()
		return false
	if color_count > 0 and color_of(id) != needed_color():
		wasted_taps += 1
		_history.append(_entry({"id": id, "blocked": true}, before))
		wrong_color.emit(id)
		_recolor()
		_check_loss()
		return false
	var info := board.remove_arrow(id)
	_history.append(_entry({"id": id, "info": info}, before))
	# What the view animates: the arrow leaves the way that was clear (it may
	# have just flipped away), in its colour. Undo keeps the original info.
	var shown := info.duplicate()
	shown["dir"] = exit_dir
	if color_count > 0:
		shown["color"] = color_of(id)
	_colors.erase(id)
	var turned := board.has_turners()
	board.rotate_turners(1)
	arrow_removed.emit(id, shown)
	if turned:
		turners_rotated.emit(1)
	# A win on the last allowed move counts as a win, so check it first.
	if board.is_empty():
		state = State.WON
		completed.emit(moves_used)
	else:
		_recolor()
		_check_loss()
	return true


## The direction arrow `id` can leave in right now, or "" if blocked. A
## flipper that swapped less than FLIP_GRACE seconds ago may still leave the
## way it pointed before.
func _exit_direction(id: int) -> String:
	if MoveValidator.first_blocker(board, id) == -1:
		return board.arrow_direction(id)
	if board.is_flipper(id) and _since_flip < FLIP_GRACE:
		var previous := board.other_direction(id)
		if MoveValidator.first_blocker_toward(board, id, previous) == -1:
			return previous
	return ""


## ID of an arrow to tap next, or -1 if none. Costs no move; the caller
## charges coins. With turners on the board a clear arrow can be a trap, so
## the hint is the first move of a winning line; -1 means no line exists
## (see is_dead_end). If the search runs out of budget it falls back to any
## free arrow. A flipper may be suggested while it points the wrong way (tap
## it once it flips). On colour levels the hint has the needed colour.
func hint() -> int:
	if state != State.PLAYING:
		return -1
	if color_count > 0:
		return _fair_id if board.has_arrow(_fair_id) else -1
	var options := MoveValidator.reachable_ids(board)
	if options.is_empty() or not board.has_turners():
		return options[0] if not options.is_empty() else -1
	var found := PuzzleSolver.solve_search(board, HINT_SEARCH_BUDGET)
	if found["status"] == PuzzleSolver.SOLVED:
		return found["order"][0]
	if found["status"] == PuzzleSolver.UNSOLVABLE:
		return -1
	return options[0]


## True when arrows remain but no order of moves can clear them any more.
## Only possible with turners; other boards can never get stuck.
func is_dead_end() -> bool:
	if state != State.PLAYING or board.is_empty():
		return false
	if not board.has_turners():
		return MoveValidator.reachable_ids(board).is_empty()
	return PuzzleSolver.solve_search(board, HINT_SEARCH_BUDGET)["status"] == PuzzleSolver.UNSOLVABLE


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


## Takes back the last move and refunds it. A removal puts the arrow back; a
## wasted tap is simply forgotten (and no longer counts as wasted). Colours
## go back to what they were before that tap. Disabled once the level is over.
func undo() -> bool:
	if not can_undo():
		return false
	var entry: Dictionary = _history.pop_back()
	moves_used -= 1
	if entry.has("colors"):
		_colors = entry["colors"].duplicate()
		_fair_id = entry["fair"]
		recolored.emit()
	if entry.get("blocked", false):
		wasted_taps -= 1
		refill_clock()
		return true
	var turned := board.has_turners()
	board.rotate_turners(-1)
	board.restore_arrow(entry["id"], entry["info"])
	refill_clock()
	if turned:
		turners_rotated.emit(-1)
	arrow_restored.emit(entry["id"])
	return true


func _check_loss() -> void:
	if moves_used >= moves_limit and not board.is_empty():
		state = State.LOST
		lost.emit(wasted_taps)


func _color_snapshot() -> Dictionary:
	return {"colors": _colors.duplicate(), "fair": _fair_id} if color_count > 0 else {}


func _entry(base: Dictionary, snapshot: Dictionary) -> Dictionary:
	base.merge(snapshot)
	return base


## New random colours for every arrow, from this attempt's order. Then one
## arrow that can leave and keeps the level winnable gets the needed colour.
func _recolor() -> void:
	if color_count == 0 or board.is_empty():
		return
	_colors.clear()
	for id in board.arrow_ids():
		_colors[id] = color_sequence[rng.randi_range(0, color_sequence.size() - 1)]
	_fair_id = _safe_move()
	if _fair_id != -1:
		_colors[_fair_id] = needed_color()
	recolored.emit()


## A random arrow that can leave (now or after a flip) without making the
## level unwinnable, or -1 when there is none.
func _safe_move() -> int:
	var options := MoveValidator.reachable_ids(board)
	for i in range(options.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := options[i]
		options[i] = options[j]
		options[j] = swap
	if not board.has_turners():
		return options[0] if not options.is_empty() else -1
	var dead: Dictionary = {}
	for id in options:
		var after := board.duplicate_state()
		after.remove_arrow(id)
		after.rotate_turners(1)
		if PuzzleSolver.solve_search(after, HINT_SEARCH_BUDGET, dead)["status"] != PuzzleSolver.UNSOLVABLE:
			return id
	return options[0] if not options.is_empty() else -1
