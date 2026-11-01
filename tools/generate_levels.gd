extends SceneTree
## Generates a draft 100-level pack and validates it.
## Easy:      godot --headless --path . -s tools/generate_levels.gd
##            (tools/world_specs.json -> data/packs)
## Difficult: godot --headless --path . -s tools/generate_levels.gd -- --hard
##            (tools/world_specs_hard.json -> data/packs_hard)
## Output is a DRAFT until the owner has played and reviewed each world.

var SPEC_PATH := "res://tools/world_specs.json"
var OUT_DIR := "res://data/packs"


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--hard"):
		SPEC_PATH = "res://tools/world_specs_hard.json"
		OUT_DIR = "res://data/packs_hard"
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
	var result := LevelGenerator.generate_pack(config)
	var failed: bool = not result["failures"].is_empty()
	for f in result["failures"]:
		printerr(f)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var worlds: Array = config["worlds"]
	for w in worlds.size():
		var slice: Array = result["levels"].filter(
			func(l: Dictionary) -> bool: return (l["id"] - 1) / LevelGenerator.LEVELS_PER_WORLD == w)
		var path := "%s/world_%02d.json" % [OUT_DIR, w + 1]
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
			failed = true
			continue
		file.store_string(JSON.stringify({"version": 2, "levels": slice}, "\t"))
		file.close()
	var repo := PuzzleRepository.new()
	if not repo.load_dir(OUT_DIR):
		for e in repo.errors:
			printerr(e)
		failed = true
	else:
		var problems := LevelValidator.validate_pack(repo.levels, {"expected_count": 100})
		for p in problems:
			printerr(p)
		failed = failed or not problems.is_empty()
	print("Generated %d levels (%d variants), failures: %d" % [
		result["levels"].size(), result["variants"], result["failures"].size()])
	quit(1 if failed else 0)
