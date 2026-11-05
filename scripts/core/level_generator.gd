class_name LevelGenerator
extends RefCounted
## Seeded, offline level generator. Never runs on a player's device.
##
## Boards are built backwards from a removal order: arrows are placed from
## last-removed to first-removed, and each new arrow must have a ray free of
## every arrow already placed. It may sit in the way of earlier arrows, which
## creates dependencies. So removing arrow IDs in ascending order is always a
## valid solution (ID 0 is removed first), and no blocking cycle can form.

const GENERATOR_VERSION := 1
const LEVELS_PER_WORLD := 10
const MAX_FILL := 0.55  ## arrows never occupy more than this share of the cells
const DEFAULT_MIN_SLACK := 2  ## spare moves every level gets unless its spec says otherwise
const DEFAULT_DEPTH_RATIO := 0.3
const NAME_ADJECTIVES: Array[String] = [
	"Amber", "Quiet", "Crimson", "Gentle", "Hidden", "Iron", "Lunar", "Misty", "Narrow", "Open",
	"Pale", "Rapid", "Silver", "Tidy", "Upper", "Velvet", "Winding", "Young", "Zesty", "Bright",
]
const NAME_NOUNS: Array[String] = [
	"Drift", "Gate", "Harbor", "Maze", "Orbit", "Path", "Quarry", "Ridge", "Signal", "Tower",
	"Valley", "Window", "Anchor", "Bridge", "Canyon", "Delta", "Ember", "Forest", "Glacier", "Island",
]


## Returns a board whose arrow IDs double as the reference removal order, or
## null when the board fills up before `count` arrows fit. `chain` (0..1) is
## the chance that a new arrow is placed on the ray of the arrow placed just
## before it, which builds long "A waits for B waits for C" chains.
static func generate_board(width: int, height: int, count: int, bias: float, rng: RandomNumberGenerator, chain: float = 0.0) -> BoardState:
	var board := BoardState.new(width, height)
	## cell -> number of placed arrows whose ray crosses it
	var cover: Dictionary = {}
	## cells on the ray of the arrow placed last
	var last_ray: Dictionary = {}
	for placed in count:
		var all: Array[Array] = []
		var shadowing: Array[Array] = []
		var chained: Array[Array] = []
		for y in height:
			for x in width:
				var pos := Vector2i(x, y)
				if board.arrow_at(pos) != -1:
					continue
				for dir in BoardState.DIRECTIONS.keys():
					if _ray_is_clear(board, pos, dir):
						all.append([pos, dir])
						if cover.get(pos, 0) > 0:
							shadowing.append([pos, dir])
						if last_ray.has(pos):
							chained.append([pos, dir])
		if all.is_empty():
			return null
		var pool := shadowing if (not shadowing.is_empty() and rng.randf() < bias) else all
		if chain > 0.0 and not chained.is_empty() and rng.randf() < chain:
			pool = chained
		var pick: Array = pool[rng.randi_range(0, pool.size() - 1)]
		board.add_arrow(count - 1 - placed, pick[0], pick[1])
		last_ray.clear()
		var step: Vector2i = BoardState.DIRECTIONS[pick[1]]
		var cell: Vector2i = pick[0] + step
		while board.in_bounds(cell):
			cover[cell] = cover.get(cell, 0) + 1
			last_ray[cell] = true
			cell += step
	return board


static func _ray_is_clear(board: BoardState, from: Vector2i, dir: String) -> bool:
	var step: Vector2i = BoardState.DIRECTIONS[dir]
	var cell := from + step
	while board.in_bounds(cell):
		if board.arrow_at(cell) != -1:
			return false
		cell += step
	return true


## Board size, arrow count and move limit for level `index` (0..9) of a world.
## With "breathers" (the default) every 5th level but the 10th drops two
## arrows; with "breathers": false the arrow count never goes down.
static func slot_params(spec: Dictionary, index: int) -> Dictionary:
	var t := float(index) / float(LEVELS_PER_WORLD - 1)
	var width := roundi(lerpf(spec["width"][0], spec["width"][1], t))
	var height := roundi(lerpf(spec["height"][0], spec["height"][1], t))
	var count := roundi(lerpf(spec["arrows"][0], spec["arrows"][1], t))
	if spec.get("breathers", true) and (index + 1) % 5 == 0 and index != LEVELS_PER_WORLD - 1:
		count = maxi(int(spec["arrows"][0]), count - 2)
	count = clampi(count, 1, maxi(1, floori(width * height * MAX_FILL)))
	return {
		"width": width,
		"height": height,
		"arrows": count,
		"moves_limit": moves_limit_for(count, float(spec["slack"]), int(spec.get("min_slack", DEFAULT_MIN_SLACK))),
	}


## Dependency depth the generator aims for. A spec "depth": [first, last]
## rises evenly across the world, like "arrows"; without it the target is a
## share of the arrow count ("depth_ratio") plus half a step per world.
static func target_depth_for(spec: Dictionary, world: int, index: int, count: int) -> int:
	if spec.has("depth"):
		var t := float(index) / float(LEVELS_PER_WORLD - 1)
		return roundi(lerpf(spec["depth"][0], spec["depth"][1], t))
	var depth_ratio := float(spec.get("depth_ratio", DEFAULT_DEPTH_RATIO))
	return roundi(count * depth_ratio + world * 0.5)


static func moves_limit_for(arrow_count: int, slack: float, min_slack: int = DEFAULT_MIN_SLACK) -> int:
	return maxi(arrow_count + min_slack, ceili(arrow_count * (1.0 + slack)))


static func level_name(level_id: int) -> String:
	var idx := (level_id * 37 + 11) % (NAME_ADJECTIVES.size() * NAME_NOUNS.size())
	return "%s %s" % [NAME_ADJECTIVES[idx % NAME_ADJECTIVES.size()], NAME_NOUNS[idx / NAME_ADJECTIVES.size()]]


static func board_to_arrows(board: BoardState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in board.arrow_ids():
		var pos := board.arrow_position(id)
		out.append({"x": pos.x, "y": pos.y, "dir": board.arrow_direction(id)})
	return out


## Best of `candidates` seeded attempts whose layout is not in `used_canon`,
## judged by closeness of dependency depth to the world's target. A board whose
## depth is below `min_depth` is only used if nothing deeper turns up, so a
## pack can be made to never get shallower from one level to the next. Returns
## {"level": Dictionary, "canon": String} or {} when no unique board was found.
static func generate_level(spec: Dictionary, world: int, index: int, level_id: int, master_seed: int, candidates: int, used_canon: Dictionary, min_depth: int = 0) -> Dictionary:
	var params := slot_params(spec, index)
	var count: int = params["arrows"]
	var target_depth := mini(count - 1, maxi(min_depth, target_depth_for(spec, world, index, count)))
	## Optional pull toward boards that start with few free arrows.
	var free_weight := float(spec.get("free_weight", 0.0))
	var rng := RandomNumberGenerator.new()
	var best: Dictionary = {}
	var best_cost := 1 << 30
	for k in candidates:
		var seed_value := master_seed * 1000003 + level_id * 1009 + k
		rng.seed = seed_value
		var board := generate_board(params["width"], params["height"], count, float(spec["bias"]), rng, float(spec.get("chain", 0.0)))
		if board == null:
			continue
		var canon := BoardCanon.canonical(board)
		if used_canon.has(canon):
			continue
		var metrics := LevelMetrics.compute(board)
		var cost := absi(metrics["depth"] - target_depth) * 1000 + roundi(free_weight * metrics["free_at_start"])
		if metrics["depth"] < min_depth:
			cost += (min_depth - metrics["depth"]) * 1000000
		if cost < best_cost:
			best_cost = cost
			best = {
				"canon": canon,
				"level": {
					"id": level_id,
					"name": level_name(level_id),
					"moves_limit": params["moves_limit"],
					"width": params["width"],
					"height": params["height"],
					"arrows": board_to_arrows(board),
					"seed": seed_value,
					"generator_version": GENERATOR_VERSION,
					"metrics": metrics,
				},
			}
			if cost == 0:
				break
	return best


## A rotated or mirrored copy of `source` under a new id and name. `source` is
## a JSON-style level dictionary. Returns {} if every transform looks identical.
static func make_variant(source: Dictionary, new_id: int) -> Dictionary:
	var board := BoardState.new(source["width"], source["height"])
	var next_id := 0
	for a in source["arrows"]:
		board.add_arrow(next_id, Vector2i(a["x"], a["y"]), a["dir"])
		next_id += 1
	var original_key := BoardCanon.layout_key(board)
	for t in range(1, BoardCanon.TRANSFORM_COUNT):
		var moved := BoardCanon.transform(board, t)
		if BoardCanon.layout_key(moved) == original_key:
			continue
		return {
			"id": new_id,
			"name": level_name(new_id),
			"moves_limit": source["moves_limit"],
			"width": moved.width,
			"height": moved.height,
			"arrows": board_to_arrows(moved),
			"variant_of": source["id"],
			"generator_version": GENERATOR_VERSION,
			"metrics": LevelMetrics.compute(moved),
		}
	return {}


## Generates every level in `config` ({"master_seed", "candidates", "worlds": [...]}).
## Returns {"levels": Array[Dictionary], "failures": Array[String], "variants": int}.
## Optional config keys:
## - "breathers" (default true): see slot_params.
## - "rising_depth" (default false): each level's dependency depth is at least
##   the previous level's, so the pack never gets easier on that measure.
## - "allow_variants" (default true): a level with no unique board becomes a
##   variant of an earlier level (never in the first world, at least 10 levels
##   back). When false, or when no variant fits, it is reported as a failure.
static func generate_pack(config: Dictionary) -> Dictionary:
	var levels: Array[Dictionary] = []
	var failures: Array[String] = []
	var used: Dictionary = {}
	var variants := 0
	var master_seed := int(config["master_seed"])
	var candidates := int(config["candidates"])
	var worlds: Array = config["worlds"]
	var rising := bool(config.get("rising_depth", false))
	var allow_variants := bool(config.get("allow_variants", true))
	var previous_depth := 0
	for w in worlds.size():
		var spec: Dictionary = worlds[w].duplicate()
		spec["breathers"] = bool(config.get("breathers", true))
		for i in LEVELS_PER_WORLD:
			var level_id := w * LEVELS_PER_WORLD + i + 1
			var made := generate_level(spec, w, i, level_id, master_seed, candidates, used, previous_depth if rising else 0)
			if not made.is_empty():
				used[made["canon"]] = level_id
				levels.append(made["level"])
				previous_depth = made["level"]["metrics"]["depth"]
				continue
			var variant := {}
			if w > 0 and allow_variants:
				var sources: Array[Dictionary] = []
				for earlier in levels:
					if earlier["id"] <= level_id - LEVELS_PER_WORLD and not earlier.has("variant_of"):
						sources.append(earlier)
				if not sources.is_empty():
					variant = make_variant(sources[(level_id * 7) % sources.size()], level_id)
			if variant.is_empty():
				failures.append("Level %d: no unique board and no variant available" % level_id)
			else:
				variants += 1
				levels.append(variant)
	return {"levels": levels, "failures": failures, "variants": variants}
