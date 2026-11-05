extends SceneTree
## Writes data/levels.lock.json: one fingerprint per level of each pack.
## Run once when a pack is final:
##   godot --headless --path . -s tools/freeze_levels.gd
## After release, only ever ADD levels at the end and re-run; never regenerate
## or edit a locked level. The tests fail if a locked level changes.

const PACKS := ["packs", "packs_hard"]
const OUT := "res://data/levels.lock.json"


func _initialize() -> void:
	var lock := {"_comment": "Fingerprints of released levels. Do not edit by hand; see tools/freeze_levels.gd."}
	for key in PACKS:
		var repo := PuzzleRepository.new()
		if not repo.load_dir("res://data/" + key):
			printerr("; ".join(repo.errors))
			quit(1)
			return
		var prints: Array[String] = []
		for level in repo.levels:
			prints.append(LevelFingerprint.of(level))
		lock[key] = prints
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write %s" % OUT)
		quit(1)
		return
	file.store_string(JSON.stringify(lock, "\t"))
	file.close()
	print("Locked %s" % ", ".join(PACKS))
	quit(0)
