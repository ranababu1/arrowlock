extends SceneTree
## Dependency-free test runner.
## Run: godot --headless --path . -s tests/run_tests.gd
## Exit code is non-zero when any check fails.

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_test_validator_directions_and_edges()
	_test_blockers()
	_test_empty_and_invalid()
	_test_controller_flow()
	_test_completion_fires_once()
	_test_undo_restart()
	_test_solver_detects_cycle()
	_test_repository_validation()
	_test_shipped_levels()
	_test_save_roundtrip_and_corruption()
	print("Tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL: " + label)


func _board(w: int, h: int, arrows: Array) -> BoardState:
	var b := BoardState.new(w, h)
	for i in arrows.size():
		var a: Array = arrows[i]
		b.add_arrow(i, Vector2i(a[0], a[1]), a[2])
	return b


func _test_validator_directions_and_edges() -> void:
	for dir in ["up", "down", "left", "right"]:
		var b := _board(3, 3, [[1, 1, dir]])
		_check(MoveValidator.can_remove(b, 0), "lone arrow exits " + dir)
	var edge := _board(3, 3, [[0, 0, "up"], [2, 2, "right"]])
	_check(MoveValidator.can_remove(edge, 0) and MoveValidator.can_remove(edge, 1), "edge arrows facing outward are clear")


func _test_blockers() -> void:
	var b := _board(4, 1, [[0, 0, "right"], [2, 0, "left"], [3, 0, "left"]])
	_check(MoveValidator.first_blocker(b, 0) == 1, "nearest blocker reported (not farther one)")
	_check(MoveValidator.first_blocker(b, 1) == 0, "left-facing arrow blocked by arrow behind its ray")
	var chain := _board(3, 1, [[0, 0, "right"], [1, 0, "right"], [2, 0, "right"]])
	var open := MoveValidator.removable_ids(chain)
	_check(open.size() == 1 and open[0] == 2, "only the front arrow of a chain is removable")


func _test_empty_and_invalid() -> void:
	var b := BoardState.new(2, 2)
	_check(b.is_empty() and PuzzleSolver.is_solvable(b), "empty board is complete/solvable")
	_check(not b.add_arrow(0, Vector2i(2, 0), "up"), "out-of-bounds rejected")
	_check(not b.add_arrow(0, Vector2i(-1, 0), "up"), "negative coordinate rejected")
	_check(not b.add_arrow(0, Vector2i(0, 0), "diagonal"), "unknown direction rejected")
	_check(b.add_arrow(0, Vector2i(0, 0), "up"), "valid arrow accepted")
	_check(not b.add_arrow(0, Vector2i(1, 1), "up"), "duplicate id rejected")
	_check(not b.add_arrow(1, Vector2i(0, 0), "up"), "occupied cell rejected")
	_check(not MoveValidator.can_remove(b, 99), "unknown id is not removable")


func _controller_for(b: BoardState) -> GameController:
	var c := GameController.new()
	c.start(b)
	return c


func _test_controller_flow() -> void:
	var c := _controller_for(_board(3, 1, [[0, 0, "right"], [1, 0, "up"]]))
	_check(not c.tap(Vector2i(0, 0)), "blocked tap does nothing")
	_check(c.move_count == 0 and c.board.remaining_count() == 2, "blocked tap leaves state unchanged")
	_check(not c.tap(Vector2i(2, 0)), "tap on empty cell ignored")
	_check(c.tap(Vector2i(1, 0)), "clear tap removes arrow")
	_check(c.move_count == 1, "move counted")


func _test_completion_fires_once() -> void:
	var c := _controller_for(_board(2, 1, [[0, 0, "left"], [1, 0, "right"]]))
	var count := [0]
	c.completed.connect(func(_m: int) -> void: count[0] += 1)
	c.tap(Vector2i(0, 0))
	c.tap(Vector2i(1, 0))
	c.tap(Vector2i(1, 0))
	_check(c.is_complete and count[0] == 1, "completion emitted exactly once")
	_check(not c.undo(), "undo disabled after completion")


func _test_undo_restart() -> void:
	var c := _controller_for(_board(3, 1, [[0, 0, "right"], [1, 0, "up"]]))
	c.tap(Vector2i(1, 0))
	_check(c.undo(), "undo succeeds")
	_check(c.board.remaining_count() == 2 and c.move_count == 0, "undo restores arrow and count")
	_check(not c.undo(), "undo with empty history fails")
	c.tap(Vector2i(1, 0))
	c.restart()
	_check(c.board.remaining_count() == 2 and c.move_count == 0 and not c.is_complete, "restart resets")


func _test_solver_detects_cycle() -> void:
	# Four arrows each blocking the next in a ring: no legal first move.
	var cycle := _board(4, 4, [[0, 3, "up"], [0, 1, "right"], [1, 1, "down"], [1, 3, "left"]])
	_check(MoveValidator.removable_ids(cycle).is_empty(), "cycle has no legal move")
	_check(not PuzzleSolver.is_solvable(cycle), "greedy solver rejects cycle")
	_check(PuzzleSolver.solve_exhaustive(cycle) == 0, "exhaustive solver rejects cycle")


func _test_repository_validation() -> void:
	var good := '{"version":1,"levels":[{"id":1,"width":2,"height":2,"arrows":[{"x":0,"y":0,"dir":"up"}]}]}'
	var repo := PuzzleRepository.new()
	_check(repo.load_text(good) and repo.levels.size() == 1, "valid level loads")
	var bad_inputs := [
		"not json",
		'{"version":2,"levels":[]}',
		'{"version":1,"levels":[{"id":1,"width":2,"height":2,"arrows":[{"x":5,"y":0,"dir":"up"}]}]}',
		'{"version":1,"levels":[{"id":1,"width":2,"height":2,"arrows":[{"x":0,"y":0,"dir":"sideways"}]}]}',
		'{"version":1,"levels":[{"id":1,"width":2,"height":2,"arrows":[{"x":0,"y":0,"dir":"up"},{"x":0,"y":0,"dir":"down"}]}]}',
		'{"version":1,"levels":[{"id":1,"width":0,"height":2,"arrows":[]}]}',
	]
	for text in bad_inputs:
		var r := PuzzleRepository.new()
		_check(not r.load_text(text) and not r.errors.is_empty(), "rejects: " + text.left(50))


func _test_shipped_levels() -> void:
	var repo := PuzzleRepository.new()
	_check(repo.load_file("res://data/levels.json"), "shipped levels load: " + "; ".join(repo.errors))
	for level in repo.levels:
		var board: BoardState = level["board"]
		_check(PuzzleSolver.is_solvable(board), "level %d solvable (greedy)" % level["id"])
		_check(PuzzleSolver.solve_exhaustive(board) == 1, "level %d solvable (exhaustive)" % level["id"])
		# Replaying the reference solution through the controller must complete it.
		var c := _controller_for(board)
		for id in PuzzleSolver.solve(board):
			c.tap(board.arrow_position(id))
		_check(c.is_complete, "level %d reference solution completes" % level["id"])


func _test_save_roundtrip_and_corruption() -> void:
	var path := "user://test_save.json"
	var s := SaveService.new(path)
	s.record_completion(3, 9)
	s.record_completion(3, 5)
	s.record_completion(3, 7)
	s.sound_enabled = false
	_check(s.save_data(), "save succeeds")
	var loaded := SaveService.new(path)
	loaded.load_data()
	_check(loaded.completed.get(3, -1) == 5, "best move count kept")
	_check(not loaded.sound_enabled and loaded.load_error == "", "settings round-trip")
	# Overwrite with garbage: must fall back to defaults, not crash.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{{ not json")
	f.close()
	var corrupt := SaveService.new(path)
	corrupt.load_data()
	_check(corrupt.completed.is_empty() and corrupt.sound_enabled and corrupt.load_error != "", "corrupt save falls back safely")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var missing := SaveService.new("user://does_not_exist.json")
	missing.load_data()
	_check(missing.completed.is_empty() and missing.load_error == "", "missing save is a clean default")
