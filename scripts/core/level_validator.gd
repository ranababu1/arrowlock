class_name LevelValidator
extends RefCounted
## Content checks for level packs. Returns human-readable error strings;
## an empty array means the pack passes. Levels are PuzzleRepository entries.

const DEFAULT_POLICY := {
	"max_variants": 15,
	"min_variant_distance": 10,
	"no_variants_through_level": 10,
	"expected_count": 0,  ## 0 = do not check
}
## The exhaustive cross-check is only run up to this many arrows.
const EXHAUSTIVE_MAX_ARROWS := 16


static func validate_level(level: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id: int = level["id"]
	var board: BoardState = level["board"]
	var count := board.remaining_count()
	if level["moves_limit"] < count:
		errors.append("Level %d: moves_limit %d is below arrow count %d" % [id, level["moves_limit"], count])
	if PuzzleSolver.solve(board).size() != count:
		errors.append("Level %d: greedy solver cannot clear the board" % id)
	if not PuzzleSolver.topo_solvable(board):
		errors.append("Level %d: dependency graph has a cycle" % id)
	if count <= EXHAUSTIVE_MAX_ARROWS and PuzzleSolver.solve_exhaustive(board) == 0:
		errors.append("Level %d: exhaustive search finds no solution" % id)
	return errors


static func validate_pack(levels: Array[Dictionary], policy: Dictionary = {}) -> Array[String]:
	var rules := DEFAULT_POLICY.duplicate()
	rules.merge(policy, true)
	var errors: Array[String] = []
	var ids: Dictionary = {}
	var names: Dictionary = {}
	var canon_of: Dictionary = {}  ## level id -> canonical layout
	var first_with_canon: Dictionary = {}  ## canonical layout -> first level id
	var variants := 0
	if rules["expected_count"] > 0 and levels.size() != rules["expected_count"]:
		errors.append("Expected %d levels, found %d" % [rules["expected_count"], levels.size()])
	for level in levels:
		var id: int = level["id"]
		if ids.has(id):
			errors.append("Duplicate level id %d" % id)
		ids[id] = true
		var lowered := String(level["name"]).to_lower()
		if names.has(lowered):
			errors.append("Level %d: name '%s' already used by level %d" % [id, level["name"], names[lowered]])
		names[lowered] = id
		errors.append_array(validate_level(level))
		canon_of[id] = BoardCanon.canonical(level["board"])
	for level in levels:
		var id: int = level["id"]
		var canon: String = canon_of[id]
		var source: int = level.get("variant_of", -1)
		if source == -1:
			if first_with_canon.has(canon):
				errors.append("Level %d: same layout as level %d without variant_of" % [id, first_with_canon[canon]])
			else:
				first_with_canon[canon] = id
			continue
		variants += 1
		if not canon_of.has(source):
			errors.append("Level %d: variant_of %d does not exist" % [id, source])
		elif canon_of[source] != canon:
			errors.append("Level %d: not a rotation or mirror of level %d" % [id, source])
		if id <= rules["no_variants_through_level"]:
			errors.append("Level %d: variants are not allowed in the first %d levels" % [id, rules["no_variants_through_level"]])
		if id - source < rules["min_variant_distance"]:
			errors.append("Level %d: variant of level %d is closer than %d levels" % [id, source, rules["min_variant_distance"]])
	if variants > rules["max_variants"]:
		errors.append("%d variants exceed the limit of %d" % [variants, rules["max_variants"]])
	return errors
