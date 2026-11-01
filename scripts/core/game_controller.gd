class_name GameController
extends RefCounted
## Coordinates a single puzzle session: taps, undo, restart, completion.
## Pure logic; presentation listens to the signals below.

signal arrow_removed(id: int, info: Dictionary)
signal arrow_restored(id: int)
signal move_blocked(id: int, blocker_id: int)
signal completed(moves: int)

var board: BoardState
var move_count: int = 0
var is_complete: bool = false

var _initial: BoardState
## Stack of {"id": int, "info": Dictionary}.
var _history: Array[Dictionary] = []


func start(puzzle: BoardState) -> void:
	_initial = puzzle.duplicate_state()
	restart()


func restart() -> void:
	board = _initial.duplicate_state()
	_history.clear()
	move_count = 0
	is_complete = false


## Handles a tap on cell `pos`. Returns true if an arrow was removed.
func tap(pos: Vector2i) -> bool:
	if is_complete:
		return false
	var id := board.arrow_at(pos)
	if id == -1:
		return false
	var blocker := MoveValidator.first_blocker(board, id)
	if blocker != -1:
		move_blocked.emit(id, blocker)
		return false
	var info := board.remove_arrow(id)
	_history.append({"id": id, "info": info})
	move_count += 1
	arrow_removed.emit(id, info)
	if board.is_empty():
		is_complete = true
		completed.emit(move_count)
	return true


func can_undo() -> bool:
	return not _history.is_empty() and not is_complete


## Undo is disabled after completion so the result cannot be re-triggered.
func undo() -> bool:
	if not can_undo():
		return false
	var entry: Dictionary = _history.pop_back()
	board.restore_arrow(entry["id"], entry["info"])
	move_count -= 1
	arrow_restored.emit(entry["id"])
	return true
