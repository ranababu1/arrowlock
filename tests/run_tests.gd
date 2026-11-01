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
	s.progress.coins = 77
	_check(s.save_data(), "save succeeds")
	var loaded := SaveService.new(path)
	loaded.load_data()
	_check(loaded.progress.stars_of(3) == 3 and loaded.progress.levels[3]["best_moves"] == 6, "stars and best moves kept")
	_check(loaded.progress.coins == 77 and not loaded.progress.sound_enabled and loaded.load_error == "", "coins and settings round-trip")
	_check(loaded.progress.badges.has("first_clear"), "badges round-trip")
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
	_check(r["stars"] == 3 and r["first_clear"] and r["coins_earned"] == 10 + 5 * 3, "first clear pays base + stars")
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
	_check(p10["width"] == 8 and p10["height"] == 10 and p10["arrows"] == 34 and p10["moves_limit"] == 40, "world 10 last level parameters")
	_check(LevelGenerator.slot_params(worlds[2], 4)["arrows"] < LevelGenerator.slot_params(worlds[2], 3)["arrows"] + 1, "5th level of a world is a breather")
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


func _test_generation_is_deterministic() -> void:
	var config := _specs()
	config["worlds"] = config["worlds"].slice(0, 2)
	var first := JSON.stringify(LevelGenerator.generate_pack(config)["levels"])
	var second := JSON.stringify(LevelGenerator.generate_pack(config)["levels"])
	_check(first == second, "generating a pack twice gives identical levels")


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

	# Undo refunds the removal but not earlier wasted taps.
	var u := _controller_for(_board(3, 1, rows), 4)
	u.tap(Vector2i(0, 0))
	u.tap(Vector2i(1, 0))
	_check(u.moves_used == 2, "two moves used before undo")
	u.undo()
	_check(u.moves_used == 1 and u.wasted_taps == 1, "undo refunds removal only")

	# A limit below the arrow count can never be won and is rejected.
	var bad := GameController.new()
	_check(not bad.start(_board(3, 1, rows), 1), "limit below arrow count rejected")
