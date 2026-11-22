extends SceneTree
## Generates a level pack from its world specs and validates it.
## Easy:      godot --headless --path . -s tools/generate_levels.gd
##            (tools/world_specs.json -> data/packs)
## Difficult: godot --headless --path . -s tools/generate_levels.gd -- --hard
##            (tools/world_specs_hard.json -> data/packs_hard)
## Levels already frozen in data/levels.lock.json are read from their files
## and kept as they are; only the worlds after them are generated and written.
## Pass --all to regenerate every world (only before a pack is released), or
## --keep N to also keep levels 1..N from the files (whole worlds) even if
## they are not frozen yet, so only the worlds after them are generated.
## Output is a DRAFT until the owner has played and reviewed each world.

const LOCK_PATH := "res://data/levels.lock.json"

var SPEC_PATH := "res://tools/world_specs.json"
var OUT_DIR := "res://data/packs"
var LOCK_KEY := "packs"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--hard"):
		SPEC_PATH = "res://tools/world_specs_hard.json"
		OUT_DIR = "res://data/packs_hard"
		LOCK_KEY = "packs_hard"
	var spec_file := FileAccess.open(SPEC_PATH, FileAccess.READ)
	if spec_file == null:
		printerr("Cannot open %s" % SPEC_PATH)
		quit(1)
		return
	var config: Variant = JSON.parse_string(spec_file.get_as_text())
	if typeof(config) != TYPE_DICTIONARY:
		printerr("%s is not a JSON object" % SPEC_PATH)
		quit(1)
		return
	var keep_count := -1
	var at := args.find("--keep")
	if at != -1 and at + 1 < args.size():
		keep_count = int(args[at + 1])
	var keep: Array = [] if args.has("--all") else _locked_levels(keep_count)
	if keep.size() % LevelGenerator.LEVELS_PER_WORLD != 0:
		printerr("Locked levels (%d) do not fill whole worlds" % keep.size())
		quit(1)
		return
	config["keep_levels"] = keep
	config["verbose"] = true
	var first_new_world := keep.size() / LevelGenerator.LEVELS_PER_WORLD
	var result := LevelGenerator.generate_pack(config)
	var failed: bool = not result["failures"].is_empty()
	for f in result["failures"]:
		printerr(f)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var worlds: Array = config["worlds"]
	for w in range(first_new_world, worlds.size()):
		var slice: Array = result["levels"].filter(
			func(l: Dictionary) -> bool: return (int(l["id"]) - 1) / LevelGenerator.LEVELS_PER_WORLD == w)
		var path := "%s/world_%02d.json" % [OUT_DIR, w + 1]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
			failed = true
			continue
		file.store_string(JSON.stringify({"version": 2, "levels": slice}, "\t"))
		file.close()
		for l in slice:
			print("%d %dx%d arrows %d %s" % [l["id"], l["width"], l["height"], l["arrows"].size(), l["metrics"]])
	var repo := PuzzleRepository.new()
	if not repo.load_dir(OUT_DIR):
		for e in repo.errors:
			printerr(e)
		failed = true
	else:
		var problems := LevelValidator.validate_pack(repo.levels, {"expected_count": worlds.size() * LevelGenerator.LEVELS_PER_WORLD})
		for p in problems:
			printerr(p)
		failed = failed or not problems.is_empty()
	print("Kept %d locked levels, generated %d (%d variants), failures: %d" % [
		keep.size(), result["levels"].size() - keep.size(), result["variants"], result["failures"].size()])
	quit(1 if failed else 0)


## The pack's frozen levels (or the first `keep_count`, when given), read
## from the files as JSON, in id order.
func _locked_levels(keep_count: int = -1) -> Array:
	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCK_PATH))
	var count := 0
	if typeof(lock) == TYPE_DICTIONARY and lock.has(LOCK_KEY):
		count = lock[LOCK_KEY].size()
	count = maxi(count, keep_count)
	if count == 0:
		return []
	var all: Array = []
	var names := Array(DirAccess.get_files_at(OUT_DIR)).filter(func(f: String) -> bool: return f.ends_with(".json"))
	names.sort()
	for file_name in names:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT_DIR.path_join(file_name)))
		if typeof(parsed) == TYPE_DICTIONARY:
			all.append_array(parsed.get("levels", []))
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["id"]) < int(b["id"]))
	return all.slice(0, count)
