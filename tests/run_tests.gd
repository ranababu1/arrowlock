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
	_test_move_limit()
	_test_solver_detects_cycle()
	_test_repository_validation()
	_test_shipped_levels()
	_test_stars()
	_test_rewards()
	_test_world_unlock_and_bonus()
	_test_wallet()
	_test_helpers()
	_test_save_roundtrip_and_corruption()
	_test_canon_and_transforms()
	_test_metrics()
	_test_topo_solver()
	_test_generator()
	_test_validator()
	_test_generated_pack_files()
	_test_generation_is_deterministic()
	_test_hard_pack()
	_test_chain_generation()
	await _test_level_select_ui()
	_test_audio_manager()
	_test_game_screen_sounds()
	_test_game_screen_ui()
	_test_design_components()
	_test_settings_screen()
	_test_level_select_design()
	_test_arrow_shape()
	_test_tutorial_steps()
	_test_coach_ui()
	_test_tips_setting_toggle()
	_test_volume()
	_test_difficulty_ids()
	_test_countdown()
	_test_difficulty_progress()
	await _test_difficulty_ui()
	_test_countdown_screen()
	_test_pack_ramp()
	_test_levels_frozen()
	await _test_board_fits_small_phone()
	_test_badges_and_stats()
	_test_haptics()
	_test_leaderboard_sync()
	_test_play_games_service()
	_test_trophies_screen()
	_test_economy_balance()
	_test_speed_score()
	_test_ad_policy()
	_test_ads_service()
	_test_ads_after_game()
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


func _controller_for(b: BoardState, limit: int = -1) -> GameController:
	var c := GameController.new()
	# Default: generous limit so rule tests are not affected by the budget.
	c.start(b, limit if limit >= 0 else b.remaining_count() * 2)
	return c


func _test_controller_flow() -> void:
	var c := _controller_for(_board(3, 1, [[0, 0, "right"], [1, 0, "up"]]))
	_check(not c.tap(Vector2i(0, 0)), "blocked tap does nothing")
	_check(c.board.remaining_count() == 2 and c.wasted_taps == 1, "blocked tap leaves board unchanged and is counted as wasted")
	_check(not c.tap(Vector2i(2, 0)), "tap on empty cell ignored")
	_check(c.tap(Vector2i(1, 0)), "clear tap removes arrow")
	_check(c.moves_used == 2, "blocked tap and clear tap each cost a move")


func _test_completion_fires_once() -> void:
	var c := _controller_for(_board(2, 1, [[0, 0, "left"], [1, 0, "right"]]))
	var count := [0]
	c.completed.connect(func(_m: int) -> void: count[0] += 1)
	c.tap(Vector2i(0, 0))
	c.tap(Vector2i(1, 0))
	c.tap(Vector2i(1, 0))
	_check(c.state == GameController.State.WON and count[0] == 1, "completion emitted exactly once")
	_check(not c.undo(), "undo disabled after completion")


func _test_undo_restart() -> void:
	var c := _controller_for(_board(3, 1, [[0, 0, "right"], [1, 0, "up"]]))
	c.tap(Vector2i(1, 0))
	_check(c.undo(), "undo succeeds")
	_check(c.board.remaining_count() == 2 and c.moves_used == 0, "undo restores arrow and refunds its move")
	_check(not c.undo(), "undo with empty history fails")
	c.tap(Vector2i(1, 0))
	c.restart()
	_check(c.board.remaining_count() == 2 and c.moves_used == 0 and c.wasted_taps == 0 and c.state == GameController.State.PLAYING, "restart resets")


func _test_solver_detects_cycle() -> void:
	# Four arrows each blocking the next in a ring: no legal first move.
	var cycle := _board(4, 4, [[0, 3, "up"], [0, 1, "right"], [1, 1, "down"], [1, 3, "left"]])
	_check(MoveValidator.removable_ids(cycle).is_empty(), "cycle has no legal move")
	_check(not PuzzleSolver.is_solvable(cycle), "greedy solver rejects cycle")
	_check(PuzzleSolver.solve_exhaustive(cycle) == 0, "exhaustive solver rejects cycle")


func _test_repository_validation() -> void:
	var good := '{"version":2,"levels":[{"id":1,"moves_limit":4,"width":2,"height":2,"arrows":[{"x":0,"y":0,"dir":"up"}]}]}'
	var repo := PuzzleRepository.new()
	_check(repo.load_text(good) and repo.levels.size() == 1, "valid level loads")
	var bad_inputs := [
		"not json",
		'{"version":1,"levels":[]}',
		'{"version":2,"levels":[{"id":1,"moves_limit":4,"width":2,"height":2,"arrows":[{"x":5,"y":0,"dir":"up"}]}]}',
		'{"version":2,"levels":[{"id":1,"moves_limit":4,"width":2,"height":2,"arrows":[{"x":0,"y":0,"dir":"sideways"}]}]}',
		'{"version":2,"levels":[{"id":1,"moves_limit":4,"width":2,"height":2,"arrows":[{"x":0,"y":0,"dir":"up"},{"x":0,"y":0,"dir":"down"}]}]}',
		'{"version":2,"levels":[{"id":1,"width":0,"height":2,"arrows":[]}]}',
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
		var c := _controller_for(board, level["moves_limit"])
		for id in PuzzleSolver.solve(board):
			c.tap(board.arrow_position(id))
		_check(c.state == GameController.State.WON, "level %d reference solution completes" % level["id"])


func _test_save_roundtrip_and_corruption() -> void:
	var path := "user://test_save.json"
	var s := SaveService.new(path)
	s.progress.record_result(3, 6, 12, 9, 3)
	s.progress.record_result(3, 6, 12, 6, 0)
	s.progress.sound_enabled = false
	s.progress.music_enabled = false
	s.progress.coins = 77
	s.progress.haptics_enabled = false
	s.progress.leaderboard_sent[Difficulty.EASY] = 3
	_check(s.save_data(), "save succeeds")
	var loaded := SaveService.new(path)
	loaded.load_data()
	_check(loaded.progress.stars_of(3) == 3 and loaded.progress.levels[3]["best_moves"] == 6, "stars and best moves kept")
	_check(loaded.progress.coins == 77 and not loaded.progress.sound_enabled and not loaded.progress.music_enabled and loaded.load_error == "", "coins and audio settings round-trip")
	_check(Progress.from_dict({}).music_enabled and Progress.from_dict({}).sound_enabled, "audio settings default to on")
	_check(loaded.progress.badges.has("first_clear"), "badges round-trip")
	_check(not loaded.progress.haptics_enabled and loaded.progress.leaderboard_sent.get(Difficulty.EASY, 0) == 3, "vibration setting and leaderboard state round-trip")
	_check(Progress.from_dict({}).haptics_enabled and Progress.from_dict({}).leaderboard_sent.is_empty(), "a save from the previous build gets vibration on and nothing sent")
	var odd := Progress.from_dict({"leaderboard_sent": {"0": -5, "1": 99999, "7": 3, "x": 1}})
	_check(odd.leaderboard_sent.get(0) == 0 and odd.leaderboard_sent.get(1) == Economy.MAX_LEVEL_POINTS * 100 and not odd.leaderboard_sent.has(7), "leaderboard state is clamped and unknown tiers dropped")
	_write_text(path, "{{ not json")
	var corrupt := SaveService.new(path)
	corrupt.load_data()
	_check(corrupt.progress.levels.is_empty() and corrupt.progress.coins == Economy.START_COINS and corrupt.load_error != "", "corrupt save falls back safely")
	_write_text(path, '{"version":99}')
	var future := SaveService.new(path)
	future.load_data()
	_check(future.load_error != "" and future.progress.levels.is_empty(), "unknown version falls back safely")
	# v1 save migrates: completed levels become 1 star, unknown wasted taps.
	_write_text(path, '{"version":1,"completed":{"1":3,"2":7,"x":4,"3":-1},"sound_enabled":false}')
	var old := SaveService.new(path)
	old.load_data()
	_check(old.load_error == "" and old.progress.cleared_count() == 2 and old.progress.stars_of(2) == 1, "v1 save migrates")
	_check(old.progress.levels[2]["best_wasted"] == -1 and not old.progress.sound_enabled, "migrated data keeps unknown wasted taps and settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var missing := SaveService.new("user://does_not_exist.json")
	missing.load_data()
	_check(missing.progress.levels.is_empty() and missing.load_error == "", "missing save is a clean default")


func _write_text(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _test_stars() -> void:
	_check(Economy.stars_for(0, 0) == 3 and Economy.stars_for(0, 10) == 3, "no wasted taps is 3 stars")
	_check(Economy.stars_for(2, 4) == 2, "wasted taps at half the slack is 2 stars")
	_check(Economy.stars_for(3, 4) == 1, "wasted taps above half the slack is 1 star")
	_check(Economy.stars_for(1, 0) == 1, "any waste with zero slack is 1 star")


func _test_rewards() -> void:
	var p := Progress.new()
	_check(p.coins == Economy.START_COINS, "starting coins")
	var r := p.record_result(1, 3, 6, 3, 0)
	_check(r["stars"] == 3 and r["first_clear"] and r["coins_earned"] == Economy.CLEAR_BASE_COINS + Economy.COINS_PER_STAR * 3, "first clear pays base + stars")
	_check(r["new_badges"].has("first_clear") and r["new_badges"].has("perfect_clear"), "first clear and perfect badges awarded")
	var again := p.record_result(1, 3, 6, 3, 0)
	_check(again["coins_earned"] == 0 and not again["first_clear"], "replay with no improvement pays nothing")
	_check(again["new_badges"].is_empty(), "badges are awarded once")
	var before := p.coins
	var worse := p.record_result(1, 3, 6, 6, 3)
	_check(worse["coins_earned"] == 0 and p.coins == before and p.stars_of(1) == 3, "worse replay never lowers stars or coins")
	p.record_result(2, 5, 10, 8, 3)
	_check(p.stars_of(2) == 1, "wasteful clear is 1 star")
	var up := p.record_result(2, 5, 10, 6, 1)
	_check(up["improved"] and up["coins_earned"] == 5 and p.stars_of(2) == 2, "improving stars pays the difference")
	_check(p.levels[2]["best_wasted"] == 1 and p.levels[2]["best_moves"] == 6, "best results tracked")
	_check(p.record_result(3, 3, 2, 3, 0).is_empty() and not p.is_cleared(3), "limit below arrow count rejected")
	_check(p.record_result(3, 3, 6, 2, 0).is_empty(), "moves used below arrow count rejected")
	_check(p.record_result(3, 3, 6, 4, 5).is_empty(), "wasted taps above moves used rejected")
	_check(p.total_stars() == 5, "total stars summed")


func _test_world_unlock_and_bonus() -> void:
	var p := Progress.new()
	_check(p.is_level_unlocked(1) and p.is_level_unlocked(10) and not p.is_level_unlocked(11), "only world 1 unlocked at start")
	for id in range(1, 8):
		p.record_result(id, 3, 6, 3, 0)
	_check(not p.is_world_unlocked(1), "7 clears do not unlock the next world")
	p.record_result(8, 3, 6, 3, 0)
	_check(p.is_world_unlocked(1) and p.is_level_unlocked(11) and not p.is_world_unlocked(2), "8 of 10 clears unlock the next world")
	p.record_result(9, 3, 6, 3, 0)
	var last := p.record_result(10, 3, 6, 3, 0)
	_check(last["world_bonus"] == Economy.WORLD_COMPLETE_BONUS, "completing a world pays the bonus")
	_check(last["new_badges"].has("clears_10") and last["new_badges"].has("world_perfect"), "10 clears and a perfect world earn badges")
	var replay := p.record_result(10, 3, 6, 3, 0)
	_check(replay["world_bonus"] == 0, "world bonus paid once")


func _test_wallet() -> void:
	var p := Progress.new()
	p.coins = 25
	_check(p.spend(Economy.PRICE_UNDO) and p.coins == 5, "spend deducts coins")
	_check(not p.spend(Economy.PRICE_UNDO) and p.coins == 5, "cannot overspend, balance unchanged")
	_check(not p.can_afford(-1), "negative price rejected")
	var bad := Progress.from_dict({
		"coins": -50,
		"levels": {"1": {"stars": 9}, "2": {"stars": 2, "best_moves": -4, "best_wasted": -9}, "abc": {"stars": 1}, "0": {"stars": 1}, "5": "oops"},
		"badges": ["first_clear", "hacker", "first_clear", 7],
	})
	_check(bad.coins == 0, "negative coins clamped to zero")
	_check(bad.cleared_count() == 1 and bad.stars_of(2) == 2, "invalid level entries dropped")
	_check(bad.levels[2]["best_moves"] == 0 and bad.levels[2]["best_wasted"] == -1, "level numbers clamped")
	_check(bad.badges.size() == 1 and bad.badges[0] == "first_clear", "unknown and duplicate badges dropped")


func _test_helpers() -> void:
	var rows := [[0, 0, "right"], [1, 0, "up"]]
	var c := _controller_for(_board(3, 1, rows), 2)
	_check(c.hint() == 1, "hint points at a clear arrow")
	_check(c.moves_used == 0, "hint costs no move")
	c.tap(Vector2i(0, 0))
	c.tap(Vector2i(0, 0))
	_check(c.state == GameController.State.LOST and c.hint() == -1, "no hint after loss")
	_check(c.grant_extra_moves(Economy.EXTRA_MOVES), "extra moves continue a lost level")
	_check(c.state == GameController.State.PLAYING and c.moves_left() == Economy.EXTRA_MOVES, "extra moves added to the budget")
	_check(not c.grant_extra_moves(Economy.EXTRA_MOVES), "extra moves only once per attempt")
	c.tap(Vector2i(1, 0))
	c.tap(Vector2i(0, 0))
	_check(c.state == GameController.State.WON, "level can be won after extra moves")
	var notlost := _controller_for(_board(3, 1, rows), 4)
	_check(not notlost.grant_extra_moves(3), "extra moves refused while still playing")
	c.restart()
	_check(c.moves_limit == 2 and c.extra_moves_granted == 0, "restart drops extra moves")


func _specs() -> Dictionary:
	var f := FileAccess.open("res://tools/world_specs.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _has(errors: Array[String], fragment: String) -> bool:
	for e in errors:
		if e.contains(fragment):
			return true
	return false


func _repo_levels(json_levels: Array) -> Array[Dictionary]:
	var repo := PuzzleRepository.new()
	var ok := repo.load_text(JSON.stringify({"version": 2, "levels": json_levels}))
	_check(ok, "test pack loads: " + "; ".join(repo.errors))
	return repo.levels


func _ascending_removal_is_valid(board: BoardState) -> bool:
	var work := board.duplicate_state()
	for id in board.arrow_ids():
		if not MoveValidator.can_remove(work, id):
			return false
		work.remove_arrow(id)
	return true


func _test_canon_and_transforms() -> void:
	var b := _board(4, 3, [[0, 0, "right"], [1, 0, "down"], [3, 2, "left"], [2, 1, "up"]])
	var canon := BoardCanon.canonical(b)
	for t in BoardCanon.TRANSFORM_COUNT:
		var moved := BoardCanon.transform(b, t)
		_check(BoardCanon.canonical(moved) == canon, "transform %d keeps the canonical layout" % t)
		_check(moved.remaining_count() == 4 and PuzzleSolver.is_solvable(moved) == PuzzleSolver.is_solvable(b), "transform %d keeps arrows and solvability" % t)
	_check(BoardCanon.layout_key(BoardCanon.transform(b, 0)) == BoardCanon.layout_key(b), "transform 0 is the identity")
	var spun := b
	for _i in 4:
		spun = BoardCanon.transform(spun, 1)
	_check(BoardCanon.layout_key(spun) == BoardCanon.layout_key(b), "four rotations return the original")
	_check(BoardCanon.layout_key(BoardCanon.transform(b, 1)) != BoardCanon.layout_key(b), "a rotation changes this asymmetric layout")
	var other := _board(4, 3, [[0, 0, "right"], [1, 0, "up"], [3, 2, "left"], [2, 1, "up"]])
	_check(BoardCanon.canonical(other) != canon, "a different layout has a different canonical form")
	var rotated := BoardCanon.transform(b, 1)
	_check(rotated.width == 3 and rotated.height == 4, "rotation swaps the board dimensions")


func _test_metrics() -> void:
	var chain := _board(4, 4, [[0, 0, "right"], [1, 0, "right"], [2, 0, "down"], [2, 2, "left"], [3, 3, "up"]])
	var m := LevelMetrics.compute(chain)
	_check(m["depth"] == 3 and m["free_at_start"] == 2 and m["blocked_at_start"] == 3 and m["bait"] == 0, "chain level metrics")
	var bait := _board(5, 1, [[0, 0, "right"], [3, 0, "up"]])
	_check(LevelMetrics.compute(bait)["bait"] == 1, "a long clear run before a late blocker counts as bait")
	_check(LevelMetrics.compute(_board(3, 3, [[1, 1, "up"]]))["depth"] == 0, "a lone arrow has depth 0")


func _test_topo_solver() -> void:
	var cycle := _board(4, 4, [[0, 3, "up"], [0, 1, "right"], [1, 1, "down"], [1, 3, "left"]])
	_check(not PuzzleSolver.topo_solvable(cycle), "topological solver rejects a cycle")
	_check(PuzzleSolver.topo_solvable(BoardState.new(2, 2)), "topological solver accepts an empty board")
	# Three independent solvers must agree on arbitrary (not constructed) boards.
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var dirs := ["up", "down", "left", "right"]
	var disagreements := 0
	var unsolvable_seen := 0
	for _i in 300:
		var b := BoardState.new(5, 5)
		var placed := 0
		while placed < 7:
			if b.add_arrow(placed, Vector2i(rng.randi_range(0, 4), rng.randi_range(0, 4)), dirs[rng.randi_range(0, 3)]):
				placed += 1
		var greedy := PuzzleSolver.is_solvable(b)
		unsolvable_seen += 0 if greedy else 1
		if greedy != PuzzleSolver.topo_solvable(b) or greedy != (PuzzleSolver.solve_exhaustive(b) == 1):
			disagreements += 1
	_check(disagreements == 0, "greedy, topological and exhaustive solvers agree on 300 random boards")
	_check(unsolvable_seen > 0, "the random boards include unsolvable ones (so agreement is meaningful)")


func _test_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := LevelGenerator.generate_board(5, 6, 10, 0.7, rng)
	rng.seed = 7
	var b := LevelGenerator.generate_board(5, 6, 10, 0.7, rng)
	_check(BoardCanon.layout_key(a) == BoardCanon.layout_key(b), "same seed gives the same board")
	rng.seed = 8
	var c := LevelGenerator.generate_board(5, 6, 10, 0.7, rng)
	_check(BoardCanon.layout_key(a) != BoardCanon.layout_key(c), "different seed gives a different board")
	_check(a.remaining_count() == 10 and a.arrow_ids().size() == 10 and a.arrow_ids()[0] == 0 and a.arrow_ids()[9] == 9, "requested arrow count with IDs 0..n-1")
	rng.seed = 1
	_check(LevelGenerator.generate_board(2, 2, 5, 0.5, rng) == null, "an overfull request returns null")

	# Property test: every constructed board is solvable by all solvers and
	# ascending-ID removal is a valid reference solution.
	var worlds: Array = _specs()["worlds"]
	var bad := 0
	for i in 1000:
		var spec: Dictionary = worlds[i % 10]
		var params := LevelGenerator.slot_params(spec, (i / 10) % 10)
		rng.seed = 100000 + i
		var board := LevelGenerator.generate_board(params["width"], params["height"], params["arrows"], float(spec["bias"]), rng)
		if board == null or board.remaining_count() != params["arrows"] \
				or not _ascending_removal_is_valid(board) \
				or PuzzleSolver.solve(board).size() != params["arrows"] \
				or not PuzzleSolver.topo_solvable(board):
			bad += 1
	_check(bad == 0, "1000 generated boards are all solvable (%d failed)" % bad)

	var p1 := LevelGenerator.slot_params(worlds[0], 0)
	_check(p1["width"] == 3 and p1["height"] == 3 and p1["arrows"] == 3 and p1["moves_limit"] == 6, "world 1 first level parameters")
	var p10 := LevelGenerator.slot_params(worlds[9], 9)
	_check(p10["width"] == 8 and p10["height"] == 11 and p10["arrows"] == 40 and p10["moves_limit"] == 44, "world 10 last level parameters")
	var with_breather: Dictionary = worlds[2].duplicate()
	with_breather["breathers"] = true
	_check(LevelGenerator.slot_params(with_breather, 4)["arrows"] < LevelGenerator.slot_params(with_breather, 3)["arrows"], "with breathers on, the 5th level of a world drops arrows")
	var without: Dictionary = worlds[2].duplicate()
	without["breathers"] = false
	var never_drops := true
	for i in range(1, 10):
		never_drops = never_drops and LevelGenerator.slot_params(without, i)["arrows"] >= LevelGenerator.slot_params(without, i - 1)["arrows"]
	_check(never_drops, "with breathers off, the arrow count never drops inside a world")
	_check(LevelGenerator.target_depth_for({"depth": [4, 6]}, 3, 0, 12) == 4 and LevelGenerator.target_depth_for({"depth": [4, 6]}, 3, 9, 16) == 6, "a depth range sets the target from first to last level")
	_check(LevelGenerator.moves_limit_for(4, 0.1) == 6, "move limit is at least arrow count + 2")
	var names: Dictionary = {}
	for id in range(1, 101):
		names[LevelGenerator.level_name(id)] = true
	_check(names.size() == 100, "100 level names are unique")


func _test_validator() -> void:
	var config := _specs()
	config["worlds"] = config["worlds"].slice(0, 2)
	var pack := LevelGenerator.generate_pack(config)
	_check(pack["failures"].is_empty() and pack["levels"].size() == 20, "two-world pack generates")
	var base: Array = pack["levels"]
	_check(LevelValidator.validate_pack(_repo_levels(base)).is_empty(), "generated pack passes validation")

	var shipped := PuzzleRepository.new()
	shipped.load_file("res://data/levels.json")
	_check(LevelValidator.validate_pack(shipped.levels).is_empty(), "shipped levels pass validation")

	var variant := LevelGenerator.make_variant(base[4], 15)
	_check(not variant.is_empty() and variant["variant_of"] == 5, "variant records its source")
	var with_variant := base.duplicate()
	with_variant[14] = variant
	_check(LevelValidator.validate_pack(_repo_levels(with_variant)).is_empty(), "a legal variant passes (10 levels apart, not in world 1)")
	_check(_has(LevelValidator.validate_pack(_repo_levels(with_variant), {"max_variants": 0}), "exceed"), "variant limit enforced")

	var close := base.duplicate()
	close[11] = LevelGenerator.make_variant(base[4], 12)
	_check(_has(LevelValidator.validate_pack(_repo_levels(close)), "closer than"), "variant too close to its source is rejected")

	var early := base.duplicate()
	early[9] = LevelGenerator.make_variant(base[0], 10)
	_check(_has(LevelValidator.validate_pack(_repo_levels(early)), "not allowed in the first"), "variant inside world 1 is rejected")

	var wrong := base.duplicate()
	var fake: Dictionary = variant.duplicate(true)
	fake["variant_of"] = 6
	wrong[14] = fake
	_check(_has(LevelValidator.validate_pack(_repo_levels(wrong)), "not a rotation or mirror"), "variant_of must point at the same layout")

	var copy := base.duplicate()
	var plain: Dictionary = variant.duplicate(true)
	plain.erase("variant_of")
	copy[14] = plain
	_check(_has(LevelValidator.validate_pack(_repo_levels(copy)), "without variant_of"), "undeclared reuse is reported")

	var dup_name := base.duplicate()
	var renamed: Dictionary = base[3].duplicate(true)
	renamed["name"] = String(base[2]["name"]).to_upper()
	dup_name[3] = renamed
	_check(_has(LevelValidator.validate_pack(_repo_levels(dup_name)), "already used"), "duplicate names are reported (case-insensitive)")
	_check(_has(LevelValidator.validate_pack(_repo_levels(base), {"expected_count": 100}), "Expected 100"), "wrong level count is reported")

	var cycle_board := _board(4, 4, [[0, 3, "up"], [0, 1, "right"], [1, 1, "down"], [1, 3, "left"]])
	var broken := {"id": 1, "name": "Loop", "board": cycle_board, "moves_limit": 8, "variant_of": -1}
	var errors := LevelValidator.validate_level(broken)
	_check(_has(errors, "greedy solver") and _has(errors, "cycle") and _has(errors, "exhaustive"), "an unsolvable level fails every check")
	var tight := {"id": 2, "name": "Tight", "board": _board(3, 1, [[0, 0, "left"]]), "moves_limit": 0, "variant_of": -1}
	_check(_has(LevelValidator.validate_level(tight), "below arrow count"), "move limit below arrow count is reported")


func _test_generated_pack_files() -> void:
	var repo := PuzzleRepository.new()
	_check(repo.load_dir("res://data/packs"), "draft pack loads: " + "; ".join(repo.errors))
	_check(repo.levels.size() == 100, "draft pack has 100 levels")
	var in_order := true
	for i in repo.levels.size():
		in_order = in_order and repo.levels[i]["id"] == i + 1
	_check(in_order, "draft pack ids run 1..100 in order")
	_check(LevelValidator.validate_pack(repo.levels, {"expected_count": 100}).is_empty(), "draft pack passes the content validator")
	var previous_mean := 0.0
	var rising := true
	for w in 10:
		var total := 0
		for i in 10:
			total += repo.levels[w * 10 + i]["board"].remaining_count()
		rising = rising and total / 10.0 > previous_mean
		previous_mean = total / 10.0
	_check(rising, "average arrow count rises every world")
	var empty := PuzzleRepository.new()
	_check(not empty.load_dir("res://data/no_such_dir") and not empty.errors.is_empty(), "missing pack folder is an error")


func _test_hard_pack() -> void:
	var repo := PuzzleRepository.new()
	_check(repo.load_dir("res://data/packs_hard"), "Difficult pack loads: " + "; ".join(repo.errors))
	_check(repo.levels.size() == 100, "Difficult pack has 100 levels")
	_check(LevelValidator.validate_pack(repo.levels, {"expected_count": 100}).is_empty(), "Difficult pack passes the content validator")
	var shifted := PuzzleRepository.new()
	_check(shifted.load_dir("res://data/packs_hard", Difficulty.HARD_ID_BASE), "Difficult pack loads with an id offset")
	_check(shifted.levels[0]["id"] == 1001 and shifted.levels[99]["id"] == 1100, "ids are offset into the Difficult range")
	var easy := PuzzleRepository.new()
	easy.load_dir("res://data/packs")
	var spare_ok := true
	var bigger := true
	for i in 100:
		var level: Dictionary = repo.levels[i]
		var count: int = level["board"].remaining_count()
		spare_ok = spare_ok and level["moves_limit"] - count <= 2
		bigger = bigger and count > easy.levels[i]["board"].remaining_count()
	_check(spare_ok, "Difficult levels leave at most two spare moves")
	_check(bigger, "every Difficult level has more arrows than its Easy counterpart")
	var tough := Array(repo.levels).filter(func(l: Dictionary) -> bool: return LevelMetrics.compute(l["board"])["depth"] >= 7)
	_check(tough.size() == 100, "every Difficult level has a dependency chain at least 7 deep")


func _test_chain_generation() -> void:
	var plain_depth := 0
	var chained_depth := 0
	for k in 12:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + k
		var plain := LevelGenerator.generate_board(7, 9, 26, 0.9, rng)
		rng.seed = 900 + k
		var chained := LevelGenerator.generate_board(7, 9, 26, 0.9, rng, 0.9)
		if plain == null or chained == null:
			continue
		_check(PuzzleSolver.solve(chained).size() == 26 and PuzzleSolver.topo_solvable(chained), "a chained board is solvable")
		plain_depth += LevelMetrics.compute(plain)["depth"]
		chained_depth += LevelMetrics.compute(chained)["depth"]
	_check(chained_depth > plain_depth, "chaining builds deeper dependency chains")
	_check(LevelGenerator.moves_limit_for(20, 0.0, 1) == 21 and LevelGenerator.moves_limit_for(20, 0.0) == 22, "min_slack sets the spare moves")


func _test_generation_is_deterministic() -> void:
	var config := _specs()
	config["worlds"] = config["worlds"].slice(0, 2)
	var first := JSON.stringify(LevelGenerator.generate_pack(config)["levels"])
	var second := JSON.stringify(LevelGenerator.generate_pack(config)["levels"])
	_check(first == second, "generating a pack twice gives identical levels")


func _pack_repo() -> PuzzleRepository:
	var repo := PuzzleRepository.new()
	var ok := repo.load_dir("res://data/packs")
	_check(ok, "pack loads for UI tests: " + "; ".join(repo.errors))
	return repo


func _blocked_cell(c: GameController) -> Vector2i:
	for id in c.board.arrow_ids():
		if MoveValidator.first_blocker(c.board, id) != -1:
			return c.board.arrow_position(id)
	return Vector2i(-1, -1)


func _test_level_select_ui() -> void:
	var repo := _pack_repo()
	var progress := Progress.new()
	var select := LevelSelect.new()
	root.add_child(select)
	select.setup(repo, progress)
	_check(select.level_button_count() == 100, "level select lists all 100 levels")
	_check(select.enabled_level_count() == 10, "only world 1 is playable at the start")
	var chosen := [-1]
	select.level_chosen.connect(func(i: int) -> void: chosen[0] = i)
	select.press_level(3)
	_check(chosen[0] == 3, "pressing an unlocked level selects it")
	select.press_level(15)
	_check(chosen[0] == 3, "pressing a locked level does nothing")

	# Dragging scrolls the list and swallows the tap at the end of the drag.
	await process_frame
	await process_frame
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(100, 600)
	select._input(press)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(100, 400)
	move.relative = Vector2(0, -200)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	select._input(move)
	_check(select.is_dragging() and select.scroll_position() > 0, "dragging up scrolls the level list")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(100, 400)
	select._input(release)
	chosen[0] = -1
	select.press_level(0)
	_check(chosen[0] == 0, "press_level still works as a direct call")
	var small := InputEventMouseMotion.new()
	small.position = Vector2(100, 605)
	small.relative = Vector2(0, 5)
	small.button_mask = MOUSE_BUTTON_MASK_LEFT
	select._input(press)
	select._input(small)
	_check(not select.is_dragging(), "a tiny movement is a tap, not a drag")
	select._input(release)
	select.queue_free()

	# The menu opens scrolled to the focus level.
	var open_progress := Progress.new()
	for id in range(1, 9):
		open_progress.record_result(id, 3, 6, 3, 0)
	var focused := LevelSelect.new()
	root.add_child(focused)
	focused.setup(repo, open_progress, 15)
	await process_frame
	await process_frame
	await process_frame
	_check(focused.scroll_position() > 0, "menu scrolls to the focus level")
	focused.queue_free()

	for id in range(1, 9):
		progress.record_result(id, 3, 6, 3, 0)
	var later := LevelSelect.new()
	root.add_child(later)
	later.setup(repo, progress)
	_check(later.enabled_level_count() == 20, "clearing 8 levels opens world 2")
	later.queue_free()


func _test_game_screen_sounds() -> void:
	var repo := _pack_repo()
	var audio := AudioManager.new()
	root.add_child(audio)
	var screen := GameScreen.new()
	root.add_child(screen)
	var progress := Progress.new()
	screen.setup(repo.levels, 0, progress, SaveService.new("user://test_sound_save.json"), audio)
	var blocked := _blocked_cell(screen.controller)
	screen.tap_cell(blocked)
	_check(audio.last_sfx == "tap_blocked", "a blocked tap plays the blocked sound")
	screen.use_hint()
	_check(audio.last_sfx == "hint", "a hint plays the hint sound")
	var board: BoardState = repo.levels[0]["board"]
	var first_id: int = PuzzleSolver.solve(board)[0]
	screen.tap_cell(board.arrow_position(first_id))
	_check(audio.last_sfx == "tap_clear", "clearing an arrow plays the clear sound")
	var played_before := audio.sfx_played
	for id in PuzzleSolver.solve(board).slice(1):
		screen.tap_cell(board.arrow_position(id))
	_check(audio.last_sfx == "win" and audio.sfx_played > played_before, "winning plays the win sound")
	screen.restart()
	var lose_board := screen.controller
	for _i in lose_board.moves_limit:
		screen.tap_cell(blocked)
	_check(audio.last_sfx == "lose", "game over plays the lose sound")
	audio.apply_settings(true, false)
	var silent_before := audio.sfx_played
	screen.restart()
	screen.tap_cell(blocked)
	_check(audio.sfx_played == silent_before, "no effects play when sound is off")
	screen.queue_free()
	audio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_sound_save.json"))


func _test_game_screen_ui() -> void:
	var repo := _pack_repo()
	var save := SaveService.new("user://test_ui_save.json")
	var progress := Progress.new()
	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup(repo.levels, 0, progress, save)
	var ctl := screen.controller
	_check(ctl.state == GameController.State.PLAYING and screen.overlay_kind() == "", "level starts playing with no panel")

	# Win by replaying the reference solution.
	var board: BoardState = repo.levels[0]["board"]
	for id in PuzzleSolver.solve(board):
		screen.tap_cell(board.arrow_position(id))
	_check(screen.overlay_kind() == "won" and progress.is_cleared(1), "winning shows the win panel and records progress")
	_check(progress.stars_of(1) == 3 and progress.coins == Economy.START_COINS + Economy.CLEAR_BASE_COINS + 3 * Economy.COINS_PER_STAR, "a clean win pays 3 stars and the clear reward")
	var used := ctl.moves_used
	screen.tap_cell(board.arrow_position(0))
	_check(ctl.moves_used == used, "taps are ignored while the win panel is up")
	var nexts := [-2]
	screen.next_requested.connect(func(i: int) -> void: nexts[0] = i)
	screen.press_next()
	_check(nexts[0] == 1, "Next goes to the following level")
	screen.restart()
	_check(screen.overlay_kind() == "" and ctl.moves_used == 0, "Replay resets the level")

	# Lose, then continue once with extra moves.
	var blocked := _blocked_cell(ctl)
	screen.tap_cell(blocked)
	_check(screen.board_view.is_flashing(ctl.board.arrow_at(blocked)), "a blocked tap starts the flash and shake on that arrow")
	for _i in ctl.moves_limit - 1:
		screen.tap_cell(blocked)
	_check(screen.overlay_kind() == "lost" and ctl.state == GameController.State.LOST, "running out of moves shows the game-over panel")
	var coins := progress.coins
	screen.use_extra_moves()
	_check(progress.coins == coins - Economy.PRICE_EXTRA_MOVES and screen.overlay_kind() == "", "extra moves cost coins and close the panel")
	_check(ctl.state == GameController.State.PLAYING and ctl.moves_left() == Economy.EXTRA_MOVES, "extra moves are added to the budget")
	for _i in Economy.EXTRA_MOVES:
		screen.tap_cell(blocked)
	var after_second_loss := progress.coins
	screen.use_extra_moves()
	_check(screen.overlay_kind() == "lost" and progress.coins == after_second_loss, "extra moves can be used only once per attempt")
	screen.queue_free()

	# Hint and undo cost coins and respect the wallet.
	var poor := Progress.new()
	var screen2 := GameScreen.new()
	root.add_child(screen2)
	screen2.setup(repo.levels, 0, poor, save)
	var free_id := screen2.controller.hint()
	screen2.use_hint()
	_check(poor.coins == Economy.START_COINS - Economy.PRICE_HINT and screen2.board_view.hint_id() == free_id, "hint costs coins and highlights a clear arrow")
	screen2.tap_cell(screen2.controller.board.arrow_position(free_id))
	_check(screen2.board_view.hint_id() == -1 and screen2.controller.moves_used == 1, "tapping clears the hint highlight and spends a move")
	poor.coins = 10
	screen2.use_undo()
	_check(poor.coins == 10 and screen2.controller.board.remaining_count() == 2, "undo without enough coins does nothing")
	poor.coins = 100
	screen2.use_undo()
	_check(poor.coins == 80 and screen2.controller.board.remaining_count() == 3, "undo costs coins and restores the arrow")
	poor.coins = 5
	screen2.use_hint()
	_check(poor.coins == 5 and screen2.board_view.hint_id() == -1, "hint without enough coins does nothing")
	screen2.queue_free()

	# Next at the edge of a locked world or the end of the pack returns to the menu.
	for index in [9, 99]:
		var fresh := Progress.new()
		var edge := GameScreen.new()
		root.add_child(edge)
		edge.setup(repo.levels, index, fresh, save)
		var menu_calls := [0]
		var next_calls := [0]
		edge.menu_requested.connect(func() -> void: menu_calls[0] += 1)
		edge.next_requested.connect(func(_i: int) -> void: next_calls[0] += 1)
		var edge_board: BoardState = repo.levels[index]["board"]
		for id in PuzzleSolver.solve(edge_board):
			edge.tap_cell(edge_board.arrow_position(id))
		edge.press_next()
		_check(edge.overlay_kind() == "won" and menu_calls[0] == 1 and next_calls[0] == 0, "Next returns to the menu when nothing is unlocked after level %d" % repo.levels[index]["id"])
		edge.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ui_save.json"))


func _test_audio_manager() -> void:
	var audio := AudioManager.new()
	root.add_child(audio)
	_check(AudioServer.get_bus_index("Music") != -1 and AudioServer.get_bus_index("SFX") != -1, "music and effects buses exist")
	for sound_name in AudioManager.SOUNDS:
		_check(audio.play(sound_name), "sound '%s' loads and plays" % sound_name)
	_check(audio.sfx_played == AudioManager.SOUNDS.size() and audio.last_sfx == "click", "played sounds are counted")
	_check(not audio.play("no_such_sound"), "unknown sound is ignored")
	audio.start_music()
	_check(audio.is_music_playing(), "music starts")
	audio.apply_settings(true, false)
	_check(audio.sfx_muted() and not audio.music_muted(), "effects can be muted without muting music")
	var before := audio.sfx_played
	_check(not audio.play("tap_clear") and audio.sfx_played == before, "no effect plays while effects are off")
	audio.apply_settings(false, true)
	_check(audio.music_muted() and not audio.sfx_muted(), "music can be muted without muting effects")
	_check(audio.play("tap_clear"), "effects play again when switched on")
	audio.apply_settings(true, true)
	_check(not audio.music_muted() and not audio.sfx_muted(), "both buses unmute")
	var stream: AudioStream = load(AudioManager.MUSIC_PATH)
	_check(stream is AudioStreamOggVorbis and stream.get_length() > 40.0, "music loop is a 40+ second Ogg Vorbis file")
	audio.queue_free()


func _test_design_components() -> void:
	_check(Palette.world_color(0) == Palette.WORLD_COLORS[0] and Palette.world_color(10) == Palette.WORLD_COLORS[0], "world colours wrap around")
	_check(Palette.world_name(0) == "First Steps" and Palette.world_name(9) == "Gridlock", "world names")
	var seen: Dictionary = {}
	for dir in ["up", "down", "left", "right"]:
		seen[Palette.direction_color(dir)] = true
	_check(seen.size() == 4, "each direction has its own colour")

	var toggle := ToggleSwitch.new()
	root.add_child(toggle)
	var changes: Array = []
	toggle.toggled.connect(func(v: bool) -> void: changes.append(v))
	toggle.set_on(true, false)
	_check(toggle.on and toggle.knob_position() == 1.0 and changes.is_empty(), "set_on moves the knob without emitting")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	toggle._gui_input(click)
	_check(not toggle.on and changes == [false], "a click flips the switch and emits once")
	toggle._gui_input(click)
	_check(toggle.on and changes == [false, true], "a second click flips it back")
	toggle.queue_free()

	var button := IconButton.new("gear")
	root.add_child(button)
	_check(button.glyph == "gear" and button.theme_type_variation == "IconButton" and button.custom_minimum_size.x >= 44.0, "icon button has a glyph and a touch-sized minimum")
	button.queue_free()
	_check(Glyphs.NAMES.has("back") and Glyphs.NAMES.has("note") and Glyphs.NAMES.has("speaker"), "glyph set covers navigation and audio icons")

	var theme := AppTheme.build()
	_check(theme.has_stylebox("normal", "PrimaryButton") and theme.has_stylebox("panel", "Card"), "theme defines the button and card variations")
	_check(theme.is_type_variation("PrimaryButton", "Button") and theme.is_type_variation("Heading", "Label"), "theme variations extend their base types")
	_check(theme.default_font != null and theme.default_font.get_font_name() == "Poppins", "theme uses the bundled Poppins font")

	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "backdrop never captures input")
	backdrop.queue_free()


func _click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	control._gui_input(event)


func _test_settings_screen() -> void:
	var path := "user://test_settings_save.json"
	var save := SaveService.new(path)
	var audio := AudioManager.new()
	root.add_child(audio)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.setup(save.progress, save, audio)
	_check(screen.music_toggle.on and screen.sfx_toggle.on, "both toggles start on by default")

	_click(screen.music_toggle)
	_check(not save.progress.music_enabled and audio.music_muted() and not audio.sfx_muted(), "turning music off mutes only the music")
	var reloaded := SaveService.new(path)
	reloaded.load_data()
	_check(not reloaded.progress.music_enabled and reloaded.progress.sound_enabled, "the music setting is saved")

	_click(screen.sfx_toggle)
	_check(not save.progress.sound_enabled and audio.sfx_muted(), "turning effects off mutes the effects bus")
	var before := audio.sfx_played
	audio.play("click")
	_check(audio.sfx_played == before, "no effect plays while effects are off")

	_click(screen.sfx_toggle)
	_check(save.progress.sound_enabled and not audio.sfx_muted() and audio.last_sfx == "tap_clear", "turning effects back on plays a sample")
	_click(screen.music_toggle)
	_check(save.progress.music_enabled and not audio.music_muted() and audio.is_music_playing(), "turning music back on resumes it")

	var backs := [0]
	screen.back_requested.connect(func() -> void: backs[0] += 1)
	screen.get_child(0).get_child(0).get_child(0).pressed.emit()
	_check(backs[0] == 1, "the back button leaves the screen")
	screen.queue_free()

	# A screen opened with saved-off settings shows them off.
	var off := Progress.new()
	off.music_enabled = false
	off.sound_enabled = false
	var again := SettingsScreen.new()
	root.add_child(again)
	again.setup(off, save, audio)
	_check(not again.music_toggle.on and not again.sfx_toggle.on, "toggles reflect saved settings")
	again.queue_free()
	audio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_level_select_design() -> void:
	var repo := _pack_repo()
	var progress := Progress.new()
	progress.record_result(1, 3, 6, 3, 0)
	progress.record_result(2, 3, 6, 4, 1)
	var select := LevelSelect.new()
	root.add_child(select)
	select.setup(repo, progress, 2)
	_check(select.level_button_count() == 100, "redesigned level select still lists 100 levels")
	var tiles: Array[LevelTile] = []
	for i in 12:
		tiles.append(select._level_buttons[i])
	_check(tiles[0].tile_state == LevelTile.State.CLEARED and tiles[1].tile_state == LevelTile.State.CLEARED, "cleared levels are marked cleared")
	_check(tiles[2].tile_state == LevelTile.State.CURRENT, "the next level is marked current")
	_check(tiles[3].tile_state == LevelTile.State.OPEN and tiles[10].tile_state == LevelTile.State.LOCKED, "open and locked levels are marked")
	_check(tiles[10].disabled and not tiles[3].disabled, "locked tiles cannot be pressed")
	var opened := [-1]
	select.level_chosen.connect(func(i: int) -> void: opened[0] = i)
	select.settings_requested.connect(func() -> void: opened[0] = -99)
	tiles[3].pressed.emit()
	_check(opened[0] == 3, "pressing a tile opens that level")
	select.queue_free()


func _test_arrow_shape() -> void:
	var shape := BoardView._arrow_shape()
	_check(shape.size() == 7 * (BoardView.ARROW_CORNER_STEPS + 1), "arrow outline has 7 rounded corners")
	var min_x := 99.0
	var max_x := -99.0
	var max_y := 0.0
	var sum_y := 0.0
	for p in shape:
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, absf(p.y))
		sum_y += p.y
	_check(max_x <= 0.35 and min_x >= -0.31 and max_y <= BoardView.ARROW_HEAD + 0.001, "arrow fits inside its cell with room to spare")
	_check(absf(sum_y) < 0.001, "arrow outline is symmetric about its axis")
	_check(max_x - min_x > 0.55, "arrow is longer than it is wide")
	var tip_ok := false
	for p in shape:
		tip_ok = tip_ok or (p.x > 0.30 and absf(p.y) < 0.03)
	_check(tip_ok, "the point of the arrow is on its axis")


func _test_tutorial_steps() -> void:
	var repo := _pack_repo()
	# Level 1: arrow 0 (left) blocks arrow 2 (down); arrow 1 (left) is free and blocks nothing.
	var board: BoardState = repo.levels[0]["board"].duplicate_state()
	var first := Tutorial.step_for(1, board, 0, true)
	_check(first["text"] == Tutorial.TEXT_TAP and first["kind"] == Tutorial.KIND_CLEAR and first["target"] == 1, "level 1 starts by pointing at a free arrow that blocks nothing")
	_check(MoveValidator.can_remove(board, 1) and not MoveValidator.can_remove(board, 2), "level 1 layout is as the tutorial expects")
	board.remove_arrow(1)
	var second := Tutorial.step_for(1, board, 1, true)
	_check(second["text"] == Tutorial.TEXT_BLOCKED and second["kind"] == Tutorial.KIND_BLOCKED and second["target"] == 2 and second["blocker"] == 0, "after one tap it points at the blocked arrow and at what blocks it")
	board.remove_arrow(0)
	var third := Tutorial.step_for(1, board, 2, true)
	_check(third["text"] == Tutorial.TEXT_REST and third["target"] == -1, "once nothing is blocked it just encourages")
	var wasted_first := Tutorial.step_for(1, repo.levels[0]["board"], 1, true)
	_check(wasted_first["kind"] == Tutorial.KIND_BLOCKED, "tapping the blocked arrow first still gets the explanation")

	var other: BoardState = repo.levels[1]["board"]
	_check(Tutorial.step_for(2, other, 0, true)["text"] == Tutorial.TEXT_MOVES and Tutorial.step_for(2, other, 0, true)["target"] == -1, "level 2 explains moves, no pointer")
	_check(Tutorial.step_for(2, other, Tutorial.TEXT_TIP_TAPS, true).is_empty(), "the level 2 tip goes away after a few taps")
	_check(Tutorial.step_for(3, other, 0, true)["text"] == Tutorial.TEXT_HINT, "level 3 mentions the hint")
	_check(Tutorial.step_for(4, other, 0, true).is_empty() and Tutorial.step_for(0, other, 0, true).is_empty(), "no tips beyond level 3")
	_check(Tutorial.step_for(1, repo.levels[0]["board"], 0, false).is_empty(), "no tips when tips are off")
	_check(Tutorial.step_for(1, BoardState.new(2, 2), 0, true).is_empty(), "no tips on an empty board")

	var progress := Progress.new()
	_check(progress.tips_enabled, "tips default to on")
	progress.record_result(1, 3, 6, 3, 0)
	progress.record_result(2, 3, 6, 3, 0)
	_check(progress.tips_enabled, "tips stay on until level 3 is cleared")
	progress.record_result(3, 3, 6, 3, 0)
	_check(not progress.tips_enabled, "clearing level 3 switches the tips off")
	progress.tips_enabled = true
	progress.record_result(3, 3, 6, 3, 0)
	_check(progress.tips_enabled, "replaying level 3 does not switch re-enabled tips off again")
	_check(Progress.from_dict(progress.to_dict()).tips_enabled and not Progress.from_dict({"tips_enabled": false}).tips_enabled, "the tips setting is saved and loaded")
	_check(Progress.from_dict({}).tips_enabled, "tips default to on in old saves")


func _test_coach_ui() -> void:
	var repo := _pack_repo()
	var save := SaveService.new("user://test_coach_save.json")
	var progress := Progress.new()
	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup(repo.levels, 0, progress, save)
	var board: BoardState = repo.levels[0]["board"]
	_check(screen.coach_text() == Tutorial.TEXT_TAP and screen.board_view.coach_id() == 1, "level 1 opens with a tip and a pointer on the free arrow")
	screen.tap_cell(board.arrow_position(1))
	_check(screen.coach_text() == Tutorial.TEXT_BLOCKED and screen.board_view.coach_id() == 2 and screen.board_view.coach_blocker() == 0, "after the first tap it outlines the blocked arrow and its blocker")
	screen.tap_cell(board.arrow_position(0))
	_check(screen.coach_text() == Tutorial.TEXT_REST and screen.board_view.coach_id() == -1, "once the blocker is gone it encourages")
	screen.tap_cell(board.arrow_position(2))
	_check(screen.overlay_kind() == "won" and screen.coach_text() == "" and screen.board_view.coach_id() == -1, "the tip disappears when the level is won")
	screen.queue_free()

	var second := GameScreen.new()
	root.add_child(second)
	second.setup(repo.levels, 1, progress, save)
	_check(second.coach_text() == Tutorial.TEXT_MOVES and second.board_view.coach_id() == -1, "level 2 explains moves with no pointer")
	second.queue_free()

	var later := GameScreen.new()
	root.add_child(later)
	later.setup(repo.levels, 3, progress, save)
	_check(later.coach_text() == "", "no tip after level 3")
	later.queue_free()

	var off := Progress.new()
	off.tips_enabled = false
	var quiet := GameScreen.new()
	root.add_child(quiet)
	quiet.setup(repo.levels, 0, off, save)
	_check(quiet.coach_text() == "" and quiet.board_view.coach_id() == -1, "nothing is shown when tips are off")
	quiet.queue_free()

	var finishing := Progress.new()
	var third := GameScreen.new()
	root.add_child(third)
	third.setup(repo.levels, 2, finishing, save)
	var third_board: BoardState = repo.levels[2]["board"]
	for id in PuzzleSolver.solve(third_board):
		third.tap_cell(third_board.arrow_position(id))
	_check(third.overlay_kind() == "won" and not finishing.tips_enabled, "clearing level 3 turns the tips off")
	third.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_coach_save.json"))


func _test_tips_setting_toggle() -> void:
	var path := "user://test_tips_save.json"
	var save := SaveService.new(path)
	var audio := AudioManager.new()
	root.add_child(audio)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.setup(save.progress, save, audio)
	_check(screen.tips_toggle.on, "tips toggle starts on")
	_click(screen.tips_toggle)
	_check(not save.progress.tips_enabled, "switching tips off updates the setting")
	var reloaded := SaveService.new(path)
	reloaded.load_data()
	_check(not reloaded.progress.tips_enabled, "the tips setting is saved")
	_click(screen.tips_toggle)
	_check(save.progress.tips_enabled, "switching tips back on works")
	screen.queue_free()
	audio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _mouse(control: Control, x: float, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(x, 10)
	control._gui_input(event)


func _drag(control: Control, x: float) -> void:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(x, 10)
	control._gui_input(event)


func _test_volume() -> void:
	_check(Progress.new().music_volume == 1.0 and Progress.new().sfx_volume == 1.0, "volumes default to full")
	var odd := Progress.from_dict({"music_volume": 7.5, "sfx_volume": -3})
	_check(odd.music_volume == 1.0 and odd.sfx_volume == 0.0, "saved volumes are clamped to 0..1")
	var quiet := Progress.new()
	quiet.music_volume = 0.4
	quiet.sfx_volume = 0.7
	var round_trip := Progress.from_dict(quiet.to_dict())
	_check(is_equal_approx(round_trip.music_volume, 0.4) and is_equal_approx(round_trip.sfx_volume, 0.7), "volumes are saved and loaded")

	var audio := AudioManager.new()
	root.add_child(audio)
	audio.apply_settings(true, true, 1.0, 1.0)
	_check(is_zero_approx(audio.bus_volume_db("Music")) and is_zero_approx(audio.bus_volume_db("SFX")), "full volume leaves the mix as designed")
	audio.apply_settings(true, true, 0.5, 0.25)
	_check(is_equal_approx(audio.bus_volume_db("Music"), linear_to_db(0.5)) and is_equal_approx(audio.bus_volume_db("SFX"), linear_to_db(0.25)), "half and quarter volume lower each bus")
	audio.apply_settings(true, true, 0.0, 1.0)
	_check(audio.bus_volume_db("Music") <= -79.0, "zero volume is silent")
	audio.apply_progress(quiet)
	_check(is_equal_approx(audio.bus_volume_db("Music"), linear_to_db(0.4)), "apply_progress uses the saved volumes")
	audio.apply_settings(true, true)
	audio.queue_free()

	var bar := VolumeBar.new()
	bar.size = Vector2(300, 44)
	root.add_child(bar)
	bar.size = Vector2(300, 44)
	var changes: Array = []
	var releases: Array = []
	bar.changed.connect(func(v: float) -> void: changes.append(v))
	bar.released.connect(func(v: float) -> void: releases.append(v))
	bar.set_value(0.3)
	_check(is_equal_approx(bar.value, 0.3) and changes.is_empty(), "set_value does not emit")
	_mouse(bar, 15.0, true)
	_check(is_zero_approx(bar.value) and changes.size() == 1, "pressing at the left end sets zero")
	_drag(bar, 150.0)
	_check(bar.value > 0.4 and bar.value < 0.6, "dragging to the middle sets about half")
	_mouse(bar, 150.0, false)
	_check(releases.size() == 1 and is_equal_approx(releases[0], bar.value), "releasing emits once with the final value")
	_drag(bar, 290.0)
	_check(releases.size() == 1 and bar.value < 0.6, "moving without pressing does nothing")
	_mouse(bar, 9999.0, true)
	_check(is_equal_approx(bar.value, 1.0), "pressing past the end clamps to full")
	_mouse(bar, 9999.0, false)
	bar.queue_free()

	var path := "user://test_volume_save.json"
	var save := SaveService.new(path)
	var sound := AudioManager.new()
	root.add_child(sound)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.setup(save.progress, save, sound)
	screen.music_volume_bar.size = Vector2(300, 44)
	screen.sfx_volume_bar.size = Vector2(300, 44)
	_mouse(screen.music_volume_bar, 15.0 + 270.0 * 0.5, true)
	_check(is_equal_approx(save.progress.music_volume, 0.5) and is_equal_approx(sound.bus_volume_db("Music"), linear_to_db(0.5)), "moving the music bar changes the setting and the bus")
	_mouse(screen.music_volume_bar, 15.0 + 270.0 * 0.5, false)
	var reloaded := SaveService.new(path)
	reloaded.load_data()
	_check(is_equal_approx(reloaded.progress.music_volume, 0.5), "the music volume is saved when the finger lifts")
	var before := sound.sfx_played
	_mouse(screen.sfx_volume_bar, 15.0 + 270.0 * 0.25, true)
	_mouse(screen.sfx_volume_bar, 15.0 + 270.0 * 0.25, false)
	_check(is_equal_approx(save.progress.sfx_volume, 0.25) and sound.sfx_played == before + 1, "releasing the effects bar saves and plays a sample")
	screen.queue_free()
	sound.apply_settings(true, true)
	sound.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_move_limit() -> void:
	# Two arrows; arrow 0 is blocked by arrow 1 until arrow 1 leaves.
	var rows := [[0, 0, "right"], [1, 0, "up"]]
	var c := _controller_for(_board(3, 1, rows), 3)
	var lost_count := [0]
	c.lost.connect(func(_w: int) -> void: lost_count[0] += 1)
	_check(not c.tap(Vector2i(2, 0)) and c.moves_used == 0, "tap on empty cell is free")
	c.tap(Vector2i(0, 0))
	c.tap(Vector2i(0, 0))
	_check(c.moves_used == 2 and c.wasted_taps == 2 and c.moves_left() == 1, "repeated blocked taps burn moves")
	c.tap(Vector2i(1, 0))
	_check(c.state == GameController.State.LOST and lost_count[0] == 1, "out of moves with arrows left is a loss, fired once")
	_check(not c.tap(Vector2i(0, 0)) and c.moves_used == 3, "taps ignored after loss")
	_check(not c.undo(), "undo disabled after loss")
	c.restart()
	_check(c.state == GameController.State.PLAYING and c.moves_left() == 3, "restart after loss resets budget")

	# Winning on the very last allowed move is a win, not a loss.
	var w := _controller_for(_board(3, 1, rows), 2)
	var won := [0]
	w.completed.connect(func(_m: int) -> void: won[0] += 1)
	w.tap(Vector2i(1, 0))
	w.tap(Vector2i(0, 0))
	_check(w.state == GameController.State.WON and won[0] == 1 and w.moves_left() == 0, "win on last allowed move")

	# Undo takes back exactly one tap, wasted or not.
	var u := _controller_for(_board(3, 1, rows), 4)
	u.tap(Vector2i(0, 0))
	u.tap(Vector2i(1, 0))
	_check(u.moves_used == 2, "two moves used before undo")
	u.undo()
	_check(u.moves_used == 1 and u.wasted_taps == 1 and u.board.remaining_count() == 2, "undo takes back the last removal only")
	_check(u.undo() and u.moves_used == 0 and u.wasted_taps == 0 and u.board.remaining_count() == 2, "a second undo takes back the wasted tap and refunds it")
	_check(not u.undo(), "nothing left to undo")
	u.tap(Vector2i(2, 0))
	_check(not u.can_undo(), "a tap on an empty cell is not a move and cannot be undone")

	# A limit below the arrow count can never be won and is rejected.
	var bad := GameController.new()
	_check(not bad.start(_board(3, 1, rows), 1), "limit below arrow count rejected")


func _test_difficulty_ids() -> void:
	_check(Difficulty.of_level(100) == Difficulty.EASY and Difficulty.of_level(1001) == Difficulty.DIFFICULT, "ids above 1000 are Difficult")
	_check(Difficulty.local_id(1007) == 7 and Difficulty.local_id(7) == 7, "local id strips the Difficult offset")
	_check(Difficulty.make_id(Difficulty.DIFFICULT, 12) == 1012 and Difficulty.make_id(Difficulty.EASY, 12) == 12, "make_id round-trips")
	_check(Difficulty.countdown_for(1) == 0.0 and Difficulty.countdown_for(100) == 0.0, "Easy never has a clock")
	_check(Difficulty.countdown_for(1001) == 10.0 and Difficulty.countdown_for(1100) == 10.0, "Difficult uses 10 s on every level")
	_check(Progress.world_of(1011) == 1 and Progress.world_of(11) == 1 and Progress.world_of(1010) == 0, "worlds are counted within a tier")


func _test_countdown() -> void:
	# Arrow 0 is blocked by arrow 1; arrow 2 is free.
	var rows := [[0, 0, "right"], [1, 0, "up"], [0, 2, "left"]]
	var c := GameController.new()
	c.start(_board(3, 3, rows), 6, 10.0)
	_check(c.has_clock() and is_equal_approx(c.time_left, 10.0) and not c.clock_running(), "clock is full but idle before the first tap")
	c.tick(30.0)
	_check(c.state == GameController.State.PLAYING and is_equal_approx(c.time_left, 10.0), "the clock does not run before the first tap")
	c.tap(Vector2i(0, 2))
	_check(c.clock_running(), "the first tap starts the clock")
	c.tick(4.0)
	_check(is_equal_approx(c.time_left, 6.0), "time counts down")
	c.tap(Vector2i(1, 1))
	_check(is_equal_approx(c.time_left, 6.0), "a tap on an empty cell does not refill the clock")
	c.tap(Vector2i(0, 0))
	_check(is_equal_approx(c.time_left, 10.0) and c.wasted_taps == 1, "a blocked tap also refills the clock")
	c.tick(9.9)
	_check(c.state == GameController.State.PLAYING, "still playing just before zero")
	var lost_count := [0]
	c.lost.connect(func(_w: int) -> void: lost_count[0] += 1)
	c.tick(0.2)
	_check(c.state == GameController.State.LOST and c.lost_by_time and lost_count[0] == 1, "running out of time loses the level once")
	c.tick(5.0)
	_check(lost_count[0] == 1, "no second loss after the clock is out")
	_check(not c.grant_extra_moves(3), "extra moves cannot rescue a timeout")
	c.restart()
	_check(c.state == GameController.State.PLAYING and not c.lost_by_time and is_equal_approx(c.time_left, 10.0) and not c.clock_running(), "restart resets the clock")

	c.tap(Vector2i(0, 2))
	c.tick(8.0)
	c.refill_clock()
	_check(is_equal_approx(c.time_left, 10.0), "refill_clock restores the full time")
	c.tap(Vector2i(1, 0))
	c.tick(7.0)
	c.undo()
	_check(is_equal_approx(c.time_left, 10.0), "undo refills the clock")

	var plain := _controller_for(_board(3, 3, rows), 6)
	plain.tap(Vector2i(0, 2))
	plain.tick(1000.0)
	_check(not plain.has_clock() and plain.state == GameController.State.PLAYING, "a level without a countdown never times out")

	# Running out of moves is still its own loss and may be extended.
	var moves := GameController.new()
	moves.start(_board(3, 3, rows), 3, 10.0)
	moves.tap(Vector2i(0, 0))
	moves.tap(Vector2i(0, 0))
	moves.tap(Vector2i(0, 0))
	_check(moves.state == GameController.State.LOST and not moves.lost_by_time, "a move-limit loss is not a timeout")
	_check(moves.grant_extra_moves(3) and is_equal_approx(moves.time_left, 10.0), "extra moves after a move-limit loss refill the clock")

	# Winning on the last tap ends the clock.
	var won := GameController.new()
	var single := _board(2, 1, [[0, 0, "left"]])
	won.start(single, 1, 5.0)
	won.tap(Vector2i(0, 0))
	won.tick(100.0)
	_check(won.state == GameController.State.WON and not won.lost_by_time, "a win stops the clock")


func _test_difficulty_progress() -> void:
	var p := Progress.new()
	_check(p.difficulty == Difficulty.EASY, "Easy is the default tier")
	var easy := p.record_result(1, 3, 4, 3, 0)
	_check(easy["coins_earned"] == Economy.CLEAR_BASE_COINS + Economy.COINS_PER_STAR * 3, "Easy pays the base reward")
	var hard := p.record_result(1001, 3, 4, 3, 0)
	_check(hard["coins_earned"] == (Economy.CLEAR_BASE_COINS + Economy.COINS_PER_STAR * 3) * Economy.HARD_REWARD_MULTIPLIER, "Difficult pays double")
	_check(p.is_cleared(1) and p.is_cleared(1001) and p.cleared_count() == 2, "both tiers are tracked separately")
	_check(p.cleared_count(Difficulty.EASY) == 1 and p.cleared_count(Difficulty.DIFFICULT) == 1, "cleared_count can filter by tier")
	_check(p.total_stars(Difficulty.DIFFICULT) == 3 and p.total_stars() == 6, "stars can be totalled by tier")
	_check(p.badges.has("hard_clear"), "the first Difficult clear awards its badge")
	_check(p.is_level_unlocked(1001) and not p.is_level_unlocked(1011), "Difficult world 2 starts locked")
	for n in range(2, 9):
		p.record_result(Difficulty.make_id(Difficulty.DIFFICULT, n), 3, 4, 4, 1)
	_check(p.world_clears(0, Difficulty.DIFFICULT) == 8 and p.world_clears(0, Difficulty.EASY) == 1, "world clears are counted per tier")
	_check(p.is_level_unlocked(1011) and not p.is_level_unlocked(11), "clearing Difficult world 1 does not unlock Easy world 2")
	for n in range(9, 11):
		p.record_result(Difficulty.make_id(Difficulty.DIFFICULT, n), 3, 4, 3, 0)
	var last := p.record_result(1010, 3, 4, 3, 0)
	_check(last["world_bonus"] == 0, "re-clearing a finished world pays no second bonus")

	p.difficulty = Difficulty.DIFFICULT
	var again := Progress.from_dict(p.to_dict())
	_check(again.difficulty == Difficulty.DIFFICULT and again.is_cleared(1005), "the chosen tier and Difficult clears are saved")
	_check(Progress.from_dict({"difficulty": 9}).difficulty == Difficulty.DIFFICULT and Progress.from_dict({"difficulty": -4}).difficulty == Difficulty.EASY, "a damaged tier value is clamped")
	_check(Progress.from_dict({}).difficulty == Difficulty.EASY, "old saves start on Easy")


func _hard_repo() -> PuzzleRepository:
	var repo := PuzzleRepository.new()
	_check(repo.load_dir("res://data/packs_hard", Difficulty.HARD_ID_BASE), "Difficult pack loads for UI tests: " + "; ".join(repo.errors))
	return repo


func _test_difficulty_ui() -> void:
	var hard := _hard_repo()
	var progress := Progress.new()
	progress.difficulty = Difficulty.DIFFICULT
	var select := LevelSelect.new()
	select.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(select)
	select.setup(hard, progress, 0)
	await process_frame
	_check(select.mode_label.text == "Difficult mode", "the menu names the mode being played")
	_check(select.level_button_count() == 100 and select.enabled_level_count() == 10, "Difficult starts with its first world open")
	var picked: Array = []
	select.level_chosen.connect(func(index: int) -> void: picked.append(index))
	select.press_level(3)
	_check(picked == [3], "Difficult levels can be opened")
	select.queue_free()

	var easy_select := LevelSelect.new()
	easy_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(easy_select)
	easy_select.setup(_pack_repo(), Progress.new(), 0)
	await process_frame
	_check(easy_select.mode_label.text == "Easy mode", "Easy is the default mode")
	easy_select.queue_free()

	# Switching mode lives in Settings and wipes progress after a warning.
	var path := "user://test_switch_save.json"
	var save := SaveService.new(path)
	save.progress.coins = 640
	save.progress.record_result(1, 3, 4, 3, 0)
	save.progress.record_result(2, 3, 4, 4, 1)
	save.progress.music_volume = 0.4
	save.progress.sound_enabled = false
	var audio := AudioManager.new()
	root.add_child(audio)
	var screen := SettingsScreen.new()
	root.add_child(screen)
	screen.setup(save.progress, save, audio)
	var switched: Array = []
	screen.difficulty_switched.connect(func(tier: int) -> void: switched.append(tier))
	_check(screen.difficulty_buttons.size() == 2 and screen.difficulty_buttons[0].text.contains("playing"), "Settings shows which mode is being played")
	_check(not screen.confirm_visible(), "no warning is shown at first")
	screen.request_difficulty(Difficulty.EASY)
	_check(not screen.confirm_visible(), "choosing the current mode does nothing")
	screen.difficulty_buttons[1].pressed.emit()
	_check(screen.confirm_visible(), "choosing the other mode asks first")
	var warning := SettingsScreen.warning_text(Difficulty.DIFFICULT)
	_check(warning.contains("erases") and warning.contains("Easy mode is locked") and warning.contains("cannot be undone"), "the warning says progress is erased and the old mode is locked")
	_check(save.progress.difficulty == Difficulty.EASY and save.progress.cleared_count() == 2 and save.progress.coins > 640 - 1, "nothing changes while the warning is open")
	screen.cancel_button.pressed.emit()
	_check(not screen.confirm_visible() and save.progress.cleared_count() == 2 and switched.is_empty(), "keeping progress changes nothing")
	screen.difficulty_buttons[1].pressed.emit()
	screen.confirm_button.pressed.emit()
	_check(not screen.confirm_visible() and switched == [Difficulty.DIFFICULT], "confirming switches and tells the app")
	_check(save.progress.difficulty == Difficulty.DIFFICULT and save.progress.cleared_count() == 0 and save.progress.badges.is_empty(), "levels and badges are erased")
	_check(save.progress.coins == Economy.START_COINS, "coins go back to the starting amount")
	_check(is_equal_approx(save.progress.music_volume, 0.4) and not save.progress.sound_enabled, "audio settings are kept")
	_check(screen.difficulty_buttons[1].text.contains("playing") and screen.difficulty_buttons[1].theme_type_variation == "DangerButton", "Settings now shows Difficult as the mode in play")
	var reloaded := SaveService.new(path)
	reloaded.load_data()
	_check(reloaded.progress.difficulty == Difficulty.DIFFICULT and reloaded.progress.cleared_count() == 0, "the switch is saved")
	save.progress.record_result(1001, 3, 4, 3, 0)
	screen.request_difficulty(Difficulty.EASY)
	screen.confirm_switch()
	_check(save.progress.difficulty == Difficulty.EASY and save.progress.cleared_count() == 0 and switched.size() == 2, "switching back also starts over")
	_check(not save.progress.switch_difficulty(Difficulty.EASY) and not save.progress.switch_difficulty(7), "switching to the current or an unknown mode is refused")
	screen.queue_free()
	audio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_countdown_screen() -> void:
	var save := SaveService.new("user://test_clock_save.json")
	var hard := _hard_repo()
	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup(hard.levels, 0, save.progress, save)
	_check(screen.controller.countdown == 10.0 and screen.time_text().contains("10 s per tap"), "a Difficult level shows its 10 s rule before the first tap")
	screen.advance_time(5.0)
	_check(screen.controller.state == GameController.State.PLAYING, "the clock waits for the first tap")
	var board: BoardState = hard.levels[0]["board"]
	var free_ids := MoveValidator.removable_ids(board)
	screen.tap_cell(board.arrow_position(free_ids[0]))
	_check(screen.time_text().begins_with("TIME") and screen.time_text().contains("10.0 s"), "the first tap shows a full clock")
	screen.advance_time(0.2)
	screen.advance_time(0.2)
	_check(screen.controller.time_left < 9.7 and screen.controller.time_left > 9.5, "the clock counts down while playing")
	screen.advance_time(9.0)
	screen.advance_time(9.0)
	_check(screen.controller.time_left > 8.0, "one long frame cannot eat the whole clock")
	var time_left_before := screen.controller.time_left
	screen.use_hint()
	_check(screen.controller.time_left > time_left_before - 0.001, "a Hint refills the clock (or leaves it if coins ran short)")
	screen.controller.time_left = 0.01
	screen.advance_time(0.1)
	_check(screen.overlay_kind() == "lost" and screen.controller.lost_by_time, "running out of time shows the game-over panel")
	_check(screen.time_text().contains("0.0"), "the clock reads zero after a timeout")
	var coins := save.progress.coins
	screen.use_extra_moves()
	_check(screen.controller.state == GameController.State.LOST and save.progress.coins == coins, "extra moves are refused after a timeout")
	screen.restart()
	_check(screen.overlay_kind() == "" and not screen.controller.lost_by_time and not screen.controller.clock_running(), "Retry gives a fresh, idle clock")
	screen.queue_free()

	var easy := _pack_repo()
	var early := GameScreen.new()
	root.add_child(early)
	early.setup(easy.levels, 29, Progress.new(), save)
	_check(early.controller.countdown == 0.0 and early.time_text() == "", "Easy level 30 has no clock")
	early.queue_free()
	var later := GameScreen.new()
	root.add_child(later)
	later.setup(easy.levels, 99, Progress.new(), save)
	_check(later.controller.countdown == 0.0 and later.time_text() == "", "Easy level 100 has no clock either")
	later.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_clock_save.json"))



func _pack_levels(dir: String) -> Array[Dictionary]:
	var repo := PuzzleRepository.new()
	repo.load_dir(dir)
	return repo.levels


## Both packs get harder level by level: never fewer arrows, never a shallower
## dependency chain, never more spare moves per arrow. Level 100 is the peak.
func _test_pack_ramp() -> void:
	for dir in ["res://data/packs", "res://data/packs_hard"]:
		var levels := _pack_levels(dir)
		var arrows_ok := true
		var depth_ok := true
		var spare_ok := true
		var max_arrows := 0
		var max_depth := 0
		var dips: Array[int] = []
		for i in levels.size():
			var board: BoardState = levels[i]["board"]
			var depth: int = LevelMetrics.compute(board)["depth"]
			var spare := float(levels[i]["moves_limit"] - board.remaining_count()) / board.remaining_count()
			max_arrows = maxi(max_arrows, board.remaining_count())
			max_depth = maxi(max_depth, depth)
			if i == 0:
				continue
			var prev: BoardState = levels[i - 1]["board"]
			var prev_spare := float(levels[i - 1]["moves_limit"] - prev.remaining_count()) / prev.remaining_count()
			arrows_ok = arrows_ok and board.remaining_count() >= prev.remaining_count()
			if depth < LevelMetrics.compute(prev)["depth"]:
				depth_ok = false
				dips.append(i + 1)
			# One move of leeway: limits are whole moves, rounded up.
			spare_ok = spare_ok and spare <= prev_spare + 1.0 / board.remaining_count() + 0.0001
		var last: BoardState = levels[99]["board"]
		_check(arrows_ok, "%s: the arrow count never drops from one level to the next" % dir)
		_check(depth_ok, "%s: the dependency chain never gets shallower (dips at %s)" % [dir, dips])
		_check(spare_ok, "%s: spare moves per arrow never grow (beyond one move of rounding)" % dir)
		_check(last.remaining_count() == max_arrows and LevelMetrics.compute(last)["depth"] == max_depth, "%s: level 100 has the most arrows and the deepest chain" % dir)
		_check(Array(levels).all(func(l: Dictionary) -> bool: return l["variant_of"] == -1), "%s: every level is a unique layout (no reuse)" % dir)


## Released levels must never change: a save's stars belong to a layout.
## data/levels.lock.json holds a fingerprint per level; new levels may be
## added after the last one, existing ones may not change.
func _test_levels_frozen() -> void:
	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.lock.json"))
	_check(typeof(lock) == TYPE_DICTIONARY, "the level lock file exists")
	if typeof(lock) != TYPE_DICTIONARY:
		return
	for key in ["packs", "packs_hard"]:
		var levels := _pack_levels("res://data/" + key)
		var frozen: Array = lock[key]
		var changed: Array[int] = []
		for i in frozen.size():
			if i >= levels.size() or LevelFingerprint.of(levels[i]) != frozen[i]:
				changed.append(i + 1)
		_check(frozen.size() == 100 and changed.is_empty(), "%s: all %d locked levels are unchanged (changed: %s)" % [key, frozen.size(), changed])
	var level: Dictionary = _pack_levels("res://data/packs")[0]
	var moved := level.duplicate()
	moved["moves_limit"] = int(level["moves_limit"]) + 1
	_check(LevelFingerprint.of(moved) != LevelFingerprint.of(level), "a different move limit changes the fingerprint")


## The largest board must keep cells big enough to tap on a narrow 9:16
## phone (the project's 540x960 base size, the tightest layout we support).
func _test_board_fits_small_phone() -> void:
	var save := SaveService.new("user://test_fit_save.json")
	for dir in ["res://data/packs", "res://data/packs_hard"]:
		var levels := _pack_levels(dir)
		var biggest := 0
		for i in levels.size():
			var b: BoardState = levels[i]["board"]
			var cur: BoardState = levels[biggest]["board"]
			if b.width * 100 + b.height > cur.width * 100 + cur.height:
				biggest = i
		var host := Control.new()
		host.size = Vector2(540 - 32, 960 - 32)
		root.add_child(host)
		var screen := GameScreen.new()
		host.add_child(screen)
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.size = host.size
		screen.setup(levels, biggest, Progress.new(), save)
		await process_frame
		await process_frame
		var cell := screen.board_view.cell_size()
		_check(cell >= BoardView.MIN_CELL_SIZE, "%s: the biggest board (%dx%d) keeps cells of at least %d px at 540x960 (got %.0f)" % [
			dir, levels[biggest]["board"].width, levels[biggest]["board"].height, BoardView.MIN_CELL_SIZE, cell])
		host.queue_free()


func _test_badges_and_stats() -> void:
	var all_described := true
	for b in Progress.BADGES:
		all_described = all_described and Progress.BADGE_INFO.has(b) and Progress.badge_hint(b) != ""
	_check(all_described, "every badge has a title and a how-to-earn line")
	var p := Progress.new()
	for id in range(1, 11):
		p.record_result(id, 5, 8, 5, 0)
	p.record_result(11, 5, 8, 7, 2)
	p.record_result(1001, 5, 6, 5, 0)
	var s := p.stats(Difficulty.EASY)
	_check(s["cleared"] == 11 and s["stars"] == 31 and s["perfect"] == 10 and s["worlds_complete"] == 1, "stats count clears, stars, perfect levels and full worlds")
	_check(p.stats(Difficulty.DIFFICULT)["cleared"] == 1, "stats are per mode")


func _test_haptics() -> void:
	var save := SaveService.new("user://test_haptics_save.json")
	Haptics.log.clear()
	var repo := _pack_repo()
	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup(repo.levels, 0, save.progress, save)
	var blocked := _blocked_cell(screen.controller)
	screen.tap_cell(blocked)
	_check(Haptics.log == [Haptics.BLOCKED_MS], "a blocked tap gives a short buzz")
	save.progress.haptics_enabled = false
	screen.tap_cell(blocked)
	_check(Haptics.log.size() == 1, "no buzz when vibration is off")
	screen.queue_free()
	_check(not Haptics.buzz(null, 10) and not Haptics.buzz(Progress.new(), 0), "nothing to buzz without progress or duration")

	var settings := SettingsScreen.new()
	root.add_child(settings)
	var audio := AudioManager.new()
	root.add_child(audio)
	var fresh := SaveService.new("user://test_haptics_save.json")
	settings.setup(fresh.progress, fresh, audio)
	_check(settings.haptics_toggle.on, "vibration starts on")
	_click(settings.haptics_toggle)
	var reloaded := SaveService.new("user://test_haptics_save.json")
	reloaded.load_data()
	_check(not reloaded.progress.haptics_enabled, "switching vibration off is saved")
	settings.queue_free()
	audio.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_haptics_save.json"))


func _test_leaderboard_sync() -> void:
	var p := Progress.new()
	_check(LeaderboardSync.score_to_submit(p, Difficulty.EASY) == -1, "nothing to send without stars")
	p.record_result(1, 3, 6, 3, 0)
	_check(LeaderboardSync.score_to_submit(p, Difficulty.EASY) == 300, "a new score is sent")
	LeaderboardSync.mark_submitted(p, Difficulty.EASY, 300)
	_check(LeaderboardSync.score_to_submit(p, Difficulty.EASY) == -1, "a confirmed total is not sent again")
	LeaderboardSync.mark_submitted(p, Difficulty.EASY, 1)
	_check(p.leaderboard_sent[Difficulty.EASY] == 300, "a confirmation never lowers what was sent")
	_check(LeaderboardSync.score_to_submit(p, Difficulty.DIFFICULT) == -1, "each mode has its own board")


class FakePlayGamesPlugin:
	extends RefCounted
	signal userAuthenticated(is_authenticated: bool)
	signal scoreSubmitted(is_submitted: bool, leaderboard_id: String)
	var calls: Array[String] = []

	func initialize() -> void:
		calls.append("initialize")

	func isAuthenticated() -> void:
		calls.append("isAuthenticated")

	func signIn() -> void:
		calls.append("signIn")

	func showLeaderboard(id: String) -> void:
		calls.append("show:" + id)

	func submitScore(id: String, score: int) -> void:
		calls.append("submit:%s:%d" % [id, score])


func _play_games_with(plugin: Object, save: SaveService, ids: Array) -> PlayGames:
	var config := "user://test_play_games.json"
	_write_text(config, JSON.stringify({"leaderboards": {"score_easy": ids[0], "score_difficult": ids[1]}}))
	var pg := PlayGames.new()
	root.add_child(pg)
	pg.start(save.progress, save, plugin, config)
	return pg


func _test_play_games_service() -> void:
	var save := SaveService.new("user://test_pg_save.json")
	save.progress.record_result(1, 3, 6, 3, 0)
	var offline := PlayGames.new()
	root.add_child(offline)
	offline.start(save.progress, save, null, "user://no_such_config.json")
	_check(not offline.available(Difficulty.EASY) and not offline.sync(Difficulty.EASY) and not offline.show_leaderboard(Difficulty.EASY), "without the plugin everything is a safe no-op")
	offline.queue_free()
	_check(FileAccess.file_exists(PlayGames.CONFIG_PATH), "the shipped Play Games config exists")

	var plugin := FakePlayGamesPlugin.new()
	var pg := _play_games_with(plugin, save, ["CgkI_easy", ""])
	_check(plugin.calls == ["initialize", "isAuthenticated"], "start initialises the plugin and asks for the silent sign-in result")
	_check(pg.available(Difficulty.EASY) and not pg.available(Difficulty.DIFFICULT), "a mode without a leaderboard id is unavailable")
	_check(not pg.sync(Difficulty.EASY), "nothing is sent while signed out")
	plugin.userAuthenticated.emit(true)
	_check(pg.signed_in and plugin.calls.has("submit:CgkI_easy:300"), "signing in sends the score")
	_check(not pg.sync(Difficulty.EASY), "no second submit while one is waiting")
	plugin.scoreSubmitted.emit(false, "CgkI_easy")
	_check(save.progress.leaderboard_sent.get(Difficulty.EASY, 0) == 0, "a failed submit is not recorded")
	_check(pg.sync(Difficulty.EASY), "a failed submit is retried")
	plugin.scoreSubmitted.emit(true, "CgkI_easy")
	var reloaded := SaveService.new("user://test_pg_save.json")
	reloaded.load_data()
	_check(reloaded.progress.leaderboard_sent.get(Difficulty.EASY, 0) == 300, "an accepted submit is recorded and saved")
	_check(not pg.sync(Difficulty.EASY), "an accepted total is not sent again")
	_check(pg.show_leaderboard(Difficulty.EASY) and plugin.calls.has("show:CgkI_easy"), "the leaderboard opens when signed in")
	pg.sign_in()
	_check(plugin.calls.has("signIn"), "sign_in asks the plugin")
	pg.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pg_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_play_games.json"))


func _test_trophies_screen() -> void:
	var save := SaveService.new("user://test_trophies_save.json")
	save.progress.record_result(1, 3, 6, 3, 0)
	var screen := TrophiesScreen.new()
	root.add_child(screen)
	screen.setup(save.progress, null, 100)
	_check(screen.stat_labels["cleared"].text == "1 / 100" and screen.stat_labels["stars"].text == "3 / 300", "the stats show clears and stars for the mode")
	_check(screen.badge_rows.size() == Progress.BADGES.size(), "every badge is listed")
	_check(screen.leaderboard_button.disabled, "the leaderboard button is off without Play Games")
	screen.queue_free()

	var plugin := FakePlayGamesPlugin.new()
	var pg := _play_games_with(plugin, save, ["CgkI_easy", "CgkI_hard"])
	var online := TrophiesScreen.new()
	root.add_child(online)
	online.setup(save.progress, pg, 100)
	_check(not online.leaderboard_button.disabled and online.leaderboard_button.text.contains("Sign in"), "signed out, the button offers sign-in")
	online.leaderboard_button.pressed.emit()
	_check(plugin.calls.has("signIn"), "pressing it starts the sign-in")
	plugin.userAuthenticated.emit(true)
	_check(online.leaderboard_button.text == "Show leaderboard", "after sign-in the button shows the leaderboard")
	online.leaderboard_button.pressed.emit()
	_check(plugin.calls.has("show:CgkI_easy"), "pressing it opens this mode's leaderboard")
	online.queue_free()
	pg.queue_free()

	var select := LevelSelect.new()
	root.add_child(select)
	select.setup(_pack_repo(), Progress.new(), 0)
	var asked := [false]
	select.trophies_requested.connect(func() -> void: asked[0] = true)
	var found := _find_icon_button(select, "star")
	_check(found != null, "the menu has a trophies button")
	if found != null:
		found.pressed.emit()
	_check(asked[0], "the trophies button opens the trophies screen")
	select.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_play_games.json"))


func _find_icon_button(node: Node, glyph: String) -> IconButton:
	for child in node.get_children():
		if child is IconButton and child.glyph == glyph:
			return child
		var deeper := _find_icon_button(child, glyph)
		if deeper != null:
			return deeper
	return null


## A player who clears every level with the fewest stars can still afford
## helpers along the way, and a perfect player never gets an absurd hoard.
func _test_economy_balance() -> void:
	for tier in [Difficulty.EASY, Difficulty.DIFFICULT]:
		var levels := _pack_levels("res://data/packs" if tier == Difficulty.EASY else "res://data/packs_hard")
		var careless := Progress.new()
		var perfect := Progress.new()
		var careless_ok := true
		for level in levels:
			var id := Difficulty.make_id(tier, level["id"])
			var arrows: int = level["board"].remaining_count()
			var limit: int = level["moves_limit"]
			# Careless: one star, and one Hint bought on every level.
			careless_ok = careless_ok and careless.spend(Economy.PRICE_HINT)
			careless.record_result(id, arrows, limit, limit, limit - arrows)
			perfect.record_result(id, arrows, limit, arrows, 0)
		_check(careless_ok, "%s: a one-star player can buy a Hint on every level" % Difficulty.name_of(tier))
		_check(perfect.coins <= Economy.START_COINS + 100 * 60 * Economy.HARD_REWARD_MULTIPLIER, "%s: a perfect run earns a bounded number of coins (%d)" % [Difficulty.name_of(tier), perfect.coins])


func _test_speed_score() -> void:
	# The bonus: half at par, falling smoothly, never zero, none without a time.
	var par := Economy.PAR_SECONDS_PER_ARROW * 10
	_check(Economy.speed_bonus(par, 10) == Economy.SPEED_BONUS_MAX / 2, "par time earns half the speed bonus")
	_check(Economy.speed_bonus(0.0, 10) == Economy.SPEED_BONUS_MAX, "an instant solve earns the whole bonus")
	_check(Economy.speed_bonus(-1.0, 10) == 0, "an unknown time earns no bonus")
	_check(Economy.speed_bonus(3600.0, 10) > 0, "even a very slow clear earns some bonus")
	var last := Economy.SPEED_BONUS_MAX + 1
	for t in [0.0, 5.0, 10.0, 15.0, 30.0, 60.0, 120.0]:
		var bonus := Economy.speed_bonus(t, 10)
		_check(bonus < last or t == 0.0, "the bonus falls with time (%.0f s)" % t)
		last = bonus
	_check(Economy.speed_bonus(30.0, 40) > Economy.speed_bonus(30.0, 10), "bigger boards get more time for the same bonus")
	_check(Economy.level_points(3, 0.0, 5) == Economy.MAX_LEVEL_POINTS, "max level points = 3 stars + full bonus")

	# Best score per level; the leaderboard number is the sum.
	var p := Progress.new()
	var first := p.record_result(1, 10, 14, 10, 0, 30.0)
	var expect := 300 + Economy.speed_bonus(30.0, 10)
	_check(first["points"] == expect and p.points_of(1) == expect and first["new_best"], "first clear scores stars + speed")
	var slower := p.record_result(1, 10, 14, 10, 0, 60.0)
	_check(not slower["new_best"] and slower["best_points"] == expect and p.points_of(1) == expect, "a slower replay keeps the best score")
	var faster := p.record_result(1, 10, 14, 10, 0, 12.0)
	_check(faster["new_best"] and p.points_of(1) == faster["points"] and p.levels[1]["best_seconds"] == 12.0, "a faster replay raises the score")
	_check(faster["coins_earned"] == 0, "speed alone pays no coins")
	var sloppy_fast := p.record_result(1, 10, 14, 14, 4, 1.0)
	_check(sloppy_fast["stars"] == 1 and p.stars_of(1) == 3, "stars stay the best ever")
	_check(p.points_of(1) == maxi(faster["points"], sloppy_fast["points"]), "the score is the best single clear")
	p.record_result(2, 5, 8, 5, 0, 20.0)
	p.record_result(1002, 5, 8, 5, 0, 20.0)
	_check(p.total_points(Difficulty.EASY) == p.points_of(1) + p.points_of(2), "the score sums one mode")
	_check(p.stats(Difficulty.EASY)["points"] == p.total_points(Difficulty.EASY), "stats show the score")
	_check(LeaderboardSync.score_to_submit(p, Difficulty.EASY) == p.total_points(Difficulty.EASY), "the leaderboard gets the score")

	# Ties: two perfect players a second apart on one level get different scores.
	_check(Economy.level_points(3, 20.0, 20) != Economy.level_points(3, 21.0, 20), "one second apart is not a tie")

	# Saves from before the score: stars-only score until replayed; bad numbers clamped.
	var old := Progress.from_dict({"levels": {"1": {"stars": 2, "best_moves": 5, "best_wasted": 1}, 		"2": {"stars": 3, "best_moves": 5, "best_wasted": 0, "best_points": 99999, "best_seconds": -7}}})
	_check(old.points_of(1) == 200 and old.levels[1]["best_seconds"] == -1.0, "an old save scores 100 per star")
	_check(old.points_of(2) == Economy.MAX_LEVEL_POINTS and old.levels[2]["best_seconds"] == -1.0, "damaged score fields are clamped")
	var round_trip := Progress.from_dict(p.to_dict())
	_check(round_trip.total_points() == p.total_points() and round_trip.levels[1]["best_seconds"] == 1.0, "score and fastest time survive a save")

	# The controller counts time from the start of the attempt, stops at the end and resets on restart.
	var c := GameController.new()
	c.start(_board(3, 1, [[0, 0, "left"]]), 2)
	c.tick(2.5)
	_check(is_equal_approx(c.elapsed, 2.5), "time counts before the first tap")
	c.tap(Vector2i(0, 0))
	c.tick(5.0)
	_check(c.state == GameController.State.WON and is_equal_approx(c.elapsed, 2.5), "time stops at the win")
	c.restart()
	_check(c.elapsed == 0.0, "restart resets the time")
	_check(GameScreen.format_seconds(42.25) == "42.2 s" or GameScreen.format_seconds(42.25) == "42.3 s", "seconds format")
	_check(GameScreen.format_seconds(65.2) == "1:05.2", "minutes format")


func _test_ad_policy() -> void:
	var p := AdPolicy.new()
	_check(not p.should_show(1, 0.0) and not p.should_show(10, 0.0), "levels 1-10 never show ads")
	_check(p.should_show(11, 0.0) and p.should_show(100, 0.0), "level 11 and up show an ad")
	_check(not p.should_show(Difficulty.make_id(Difficulty.DIFFICULT, 10), 0.0), "Difficult 1-10 never show ads")
	_check(p.should_show(Difficulty.make_id(Difficulty.DIFFICULT, 11), 0.0), "Difficult 11 and up show an ad")
	p.mark_shown(100.0)
	_check(not p.should_show(11, 159.0), "no second ad within 60 seconds")
	_check(p.should_show(11, 160.0), "an ad again once 60 seconds have passed")

	var tuned := AdPolicy.from_config({"first_level": 5, "min_seconds_between": 0})
	_check(tuned.first_level == 5 and tuned.min_seconds_between == 0.0 and tuned.should_show(5, 0.0), "config sets the first level and the gap")
	var odd := AdPolicy.from_config({"first_level": -3, "min_seconds_between": "soon"})
	_check(odd.first_level == AdPolicy.DEFAULT_FIRST_LEVEL and odd.min_seconds_between == AdPolicy.DEFAULT_MIN_SECONDS_BETWEEN, "bad config values fall back to the defaults")
	_check(not AdPolicy.from_config({"enabled": false}).should_show(50, 0.0), "enabled=false switches ads off")

	# Shipped config: owner rule, and the manifest app id switch agrees with the runtime switch.
	var shipped := Ads.load_config(Ads.CONFIG_PATH)
	var shipped_policy := AdPolicy.from_config(shipped)
	_check(shipped_policy.first_level == 11 and shipped_policy.min_seconds_between == 60.0, "shipped ads start at level 11 with a 60 second gap")
	var export_cfg := ConfigFile.new()
	_check(export_cfg.load("res://addons/AdmobPlugin/android_export.cfg") == OK, "the AdMob export config exists")
	var is_real: bool = export_cfg.get_value("General", "is_real", false)
	_check(is_real == bool(shipped.get("use_real_ads", false)), "android_export.cfg is_real matches ads.json use_real_ads")
	if is_real:
		_check(str(export_cfg.get_value("Release", "app_id", "")).begins_with("ca-app-pub-") and str(shipped.get("interstitial_unit_id", "")).begins_with("ca-app-pub-"), "real ads need the AdMob app id and the unit id")


## Stands in for the Admob node: same signals and methods, records calls.
class FakeAdmob:
	extends Node
	signal consent_info_updated
	signal consent_info_update_failed(error: Variant)
	signal consent_form_loaded
	signal consent_form_failed_to_load(error: Variant)
	signal consent_form_dismissed(error: Variant)
	signal initialization_completed(status: Variant)
	signal interstitial_ad_loaded(ad: Variant, info: Variant)
	signal interstitial_ad_failed_to_load(ad: Variant, error: Variant)
	signal interstitial_ad_dismissed_full_screen_content(ad: Variant)
	signal interstitial_ad_failed_to_show_full_screen_content(ad: Variant, error: Variant)
	var calls: Array[String] = []
	var consent := "NOT_REQUIRED"
	var form_available := true
	var ad_loaded := false

	func update_consent_info() -> void:
		calls.append("update_consent_info")

	func get_consent_status() -> UserConsent:
		return UserConsent.new(consent)

	func is_consent_form_available() -> bool:
		return form_available

	func load_consent_form() -> void:
		calls.append("load_consent_form")

	func show_consent_form() -> void:
		calls.append("show_consent_form")

	func initialize() -> void:
		calls.append("initialize")

	func load_interstitial_ad() -> void:
		calls.append("load")

	func is_interstitial_ad_loaded() -> bool:
		return ad_loaded

	func show_interstitial_ad() -> void:
		calls.append("show")
		ad_loaded = false


func _ads_with(fake: FakeAdmob, config: Dictionary) -> Ads:
	var path := "user://test_ads.json"
	_write_text(path, JSON.stringify(config))
	var ads := Ads.new()
	root.add_child(ads)
	ads.add_child(fake)
	ads.start(fake, path)
	return ads


func _test_ads_service() -> void:
	var offline := Ads.new()
	root.add_child(offline)
	offline.start(null, "user://no_such_ads.json")
	var ran := [0]
	_check(not offline.show_after_game(50, func() -> void: ran[0] += 1) and ran[0] == 1, "without the plugin the game just carries on")
	offline.queue_free()

	# Outside the EEA: no form, straight to init and a preload.
	var fake := FakeAdmob.new()
	var ads := _ads_with(fake, {"first_level": 11, "min_seconds_between": 60})
	var now := [1000.0]
	ads.clock = func() -> float: return now[0]
	_check(fake.calls == ["update_consent_info"], "consent is checked before anything else")
	_check(not ads.show_after_game(50, func() -> void: ran[0] += 1) and ran[0] == 2, "before init the game carries on without an ad")
	fake.consent_info_updated.emit()
	_check(fake.calls.has("initialize") and not fake.calls.has("load_consent_form"), "no form when consent is not required")
	fake.initialization_completed.emit(null)
	_check(ads.is_active() and fake.calls.count("load") == 1, "an interstitial is preloaded after init")
	fake.ad_loaded = true
	fake.interstitial_ad_loaded.emit(null, null)

	_check(not ads.show_after_game(10, func() -> void: ran[0] += 1) and ran[0] == 3, "level 10 goes on without an ad")
	var after := [0]
	_check(ads.show_after_game(11, func() -> void: after[0] += 1) and fake.calls.has("show"), "level 11 shows the ad")
	_check(after[0] == 0, "the game waits while the ad is up")
	fake.interstitial_ad_dismissed_full_screen_content.emit(null)
	_check(after[0] == 1 and fake.calls.count("load") == 2, "closing the ad carries on and preloads the next one")
	fake.ad_loaded = true
	now[0] += 30.0
	_check(not ads.show_after_game(12, func() -> void: after[0] += 1) and after[0] == 2, "a quick retry within 60 seconds has no ad")
	now[0] += 30.0
	_check(ads.show_after_game(12, func() -> void: after[0] += 1) and after[0] == 2, "60 seconds later the next game shows an ad")
	fake.interstitial_ad_failed_to_show_full_screen_content.emit(null, null)
	_check(after[0] == 3, "an ad that fails to show still lets the game go on")
	fake.ad_loaded = false
	now[0] += 100.0
	_check(not ads.show_after_game(12, func() -> void: after[0] += 1) and after[0] == 4, "no ad ready: no wait")
	fake.interstitial_ad_failed_to_load.emit(null, null)
	_check(ads._retry_seconds == Ads.RETRY_FIRST_SECONDS * 2.0, "a failed load backs off before retrying")
	ads.queue_free()

	# EEA: the form is shown, and ads start only after an answer.
	var eu := FakeAdmob.new()
	eu.consent = "REQUIRED"
	var eu_ads := _ads_with(eu, {})
	eu.consent_info_updated.emit()
	_check(eu.calls.has("load_consent_form") and not eu.calls.has("initialize"), "consent required: the form loads first")
	eu.consent_form_loaded.emit()
	_check(eu.calls.has("show_consent_form"), "the loaded form is shown")
	eu.consent = "OBTAINED"
	eu.consent_form_dismissed.emit(null)
	_check(eu.calls.has("initialize"), "after the answer the SDK starts")
	eu_ads.queue_free()

	# Consent check offline with no earlier answer: no ads this session.
	var cut := FakeAdmob.new()
	cut.consent = "UNKNOWN"
	var cut_ads := _ads_with(cut, {})
	cut.consent_info_update_failed.emit(null)
	_check(not cut.calls.has("initialize"), "no consent answer, no ads")
	cut_ads.queue_free()

	# enabled=false: the plugin is never touched.
	var off := FakeAdmob.new()
	var off_ads := _ads_with(off, {"enabled": false})
	_check(off.calls.is_empty(), "enabled=false never touches the plugin")
	off_ads.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ads.json"))


func _test_ads_after_game() -> void:
	var repo := _pack_repo()
	var save := SaveService.new("user://test_ads_game_save.json")
	var fake := FakeAdmob.new()
	var ads := _ads_with(fake, {"first_level": 11, "min_seconds_between": 0})
	fake.consent_info_updated.emit()
	fake.initialization_completed.emit(null)
	fake.ad_loaded = true

	var screen := GameScreen.new()
	root.add_child(screen)
	screen.setup(repo.levels, 10, Progress.new(), save, null, ads)
	var board: BoardState = repo.levels[10]["board"]
	for id in PuzzleSolver.solve(board):
		screen.tap_cell(board.arrow_position(id))
	_check(screen.overlay_kind() == "won", "level 11 can be won")
	_check(not fake.calls.has("show"), "no ad pops up over the win panel")
	var menus := [0]
	screen.menu_requested.connect(func() -> void: menus[0] += 1)
	screen._overlay_secondary.pressed.emit()
	_check(fake.calls.has("show") and menus[0] == 0, "leaving the win panel shows the ad first")
	fake.interstitial_ad_dismissed_full_screen_content.emit(null)
	_check(menus[0] == 1, "after the ad the menu opens")

	# Replay waits for its ad, then restarts.
	fake.ad_loaded = true
	screen._overlay_extra.pressed.emit()
	_check(screen.overlay_kind() == "won", "Replay waits while its ad is up")
	fake.interstitial_ad_dismissed_full_screen_content.emit(null)
	_check(screen.overlay_kind() == "" and screen.controller.moves_used == 0, "Replay restarts after its ad")

	# Lost: +3 moves continues the same game and never shows an ad.
	fake.ad_loaded = true
	var shows := fake.calls.count("show")
	var blocked := _blocked_cell(screen.controller)
	for _i in screen.controller.moves_limit:
		screen.tap_cell(blocked)
	_check(screen.overlay_kind() == "lost", "level 11 can be lost")
	screen._progress.coins = 1000
	screen._overlay_extra.disabled = false
	screen._overlay_extra.pressed.emit()
	_check(fake.calls.count("show") == shows and screen.overlay_kind() == "", "+3 moves never shows an ad")
	screen.queue_free()

	# Level 1: no ad at all.
	var early := GameScreen.new()
	root.add_child(early)
	early.setup(repo.levels, 0, Progress.new(), save, null, ads)
	var b0: BoardState = repo.levels[0]["board"]
	for id in PuzzleSolver.solve(b0):
		early.tap_cell(b0.arrow_position(id))
	var nexts := [0]
	early.next_requested.connect(func(_i: int) -> void: nexts[0] += 1)
	early._overlay_primary.pressed.emit()
	_check(nexts[0] == 1 and fake.calls.count("show") == shows, "level 1 goes straight to the next level")
	early.queue_free()
	ads.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ads_game_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ads.json"))
