class_name Progress
extends RefCounted
## Player progress and reward logic. Pure data: no file access, no nodes.
## SaveService handles persistence; this class owns the rules.

const BADGES: Array[String] = [
	"first_clear", "clears_10", "clears_50", "clears_100", "perfect_clear", "world_perfect",
]

var coins: int = Economy.START_COINS
## level id -> {"stars": int, "best_moves": int, "best_wasted": int}.
## best_wasted is -1 when unknown (migrated from save v1).
var levels: Dictionary = {}
var badges: Array[String] = []
var sound_enabled: bool = true


static func world_of(level_id: int) -> int:
	return (level_id - 1) / Economy.LEVELS_PER_WORLD


func is_cleared(level_id: int) -> bool:
	return levels.has(level_id)


func stars_of(level_id: int) -> int:
	return levels[level_id]["stars"] if levels.has(level_id) else 0


func cleared_count() -> int:
	return levels.size()


func total_stars() -> int:
	var total := 0
	for entry in levels.values():
		total += entry["stars"]
	return total


func world_clears(world: int) -> int:
	var count := 0
	for id in levels.keys():
		if world_of(id) == world:
			count += 1
	return count


func _world_perfect_count(world: int) -> int:
	var count := 0
	for id in levels.keys():
		if world_of(id) == world and levels[id]["stars"] == Economy.MAX_STARS:
			count += 1
	return count


func is_world_unlocked(world: int) -> bool:
	return world <= 0 or world_clears(world - 1) >= Economy.WORLD_UNLOCK_CLEARS


func is_level_unlocked(level_id: int) -> bool:
	return level_id >= 1 and is_world_unlocked(world_of(level_id))


func can_afford(price: int) -> bool:
	return price >= 0 and coins >= price


## Deducts `price`; returns false and changes nothing if it cannot be paid.
func spend(price: int) -> bool:
	if not can_afford(price):
		return false
	coins -= price
	return true


## Records a finished level and returns what was earned:
## {"stars", "coins_earned", "first_clear", "improved", "world_bonus", "new_badges"}.
## `moves_limit` is the level's original limit (not including extra moves).
## Returns {} for impossible inputs and changes nothing.
func record_result(level_id: int, arrow_count: int, moves_limit: int, moves_used: int, wasted_taps: int) -> Dictionary:
	if level_id < 1 or arrow_count < 1 or moves_limit < arrow_count \
			or moves_used < arrow_count or wasted_taps < 0 or wasted_taps > moves_used:
		push_error("record_result: inconsistent result for level %d" % level_id)
		return {}
	var stars := Economy.stars_for(wasted_taps, moves_limit - arrow_count)
	var world := world_of(level_id)
	var clears_before := world_clears(world)
	var first := not levels.has(level_id)
	var old_stars := stars_of(level_id)
	var earned := 0
	if first:
		earned = Economy.CLEAR_BASE_COINS + Economy.COINS_PER_STAR * stars
		levels[level_id] = {"stars": stars, "best_moves": moves_used, "best_wasted": wasted_taps}
	else:
		var entry: Dictionary = levels[level_id]
		if stars > old_stars:
			earned = Economy.COINS_PER_STAR * (stars - old_stars)
			entry["stars"] = stars
		entry["best_moves"] = mini(entry["best_moves"], moves_used)
		if entry["best_wasted"] < 0 or wasted_taps < entry["best_wasted"]:
			entry["best_wasted"] = wasted_taps
	var world_bonus := 0
	if clears_before < Economy.LEVELS_PER_WORLD and world_clears(world) == Economy.LEVELS_PER_WORLD:
		world_bonus = Economy.WORLD_COMPLETE_BONUS
	coins += earned + world_bonus
	return {
		"stars": stars,
		"coins_earned": earned + world_bonus,
		"first_clear": first,
		"improved": stars > old_stars,
		"world_bonus": world_bonus,
		"new_badges": _award_badges(world),
	}


func _award_badges(world: int) -> Array[String]:
	var earned: Array[String] = []
	var wanted: Array[String] = []
	var cleared := cleared_count()
	if cleared >= 1:
		wanted.append("first_clear")
	if cleared >= 10:
		wanted.append("clears_10")
	if cleared >= 50:
		wanted.append("clears_50")
	if cleared >= 100:
		wanted.append("clears_100")
	if _perfect_level_count() > 0:
		wanted.append("perfect_clear")
	if _world_perfect_count(world) == Economy.LEVELS_PER_WORLD:
		wanted.append("world_perfect")
	for b in wanted:
		if not badges.has(b):
			badges.append(b)
			earned.append(b)
	return earned


func _perfect_level_count() -> int:
	var count := 0
	for entry in levels.values():
		if entry["stars"] == Economy.MAX_STARS:
			count += 1
	return count


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for id in levels.keys():
		out[str(id)] = levels[id].duplicate()
	return {
		"coins": coins,
		"levels": out,
		"badges": badges.duplicate(),
		"sound_enabled": sound_enabled,
	}


## Builds a Progress from untrusted data. Invalid entries are dropped and
## numbers clamped, so a damaged save can never yield negative coins or stars
## outside 1..3.
static func from_dict(data: Dictionary) -> Progress:
	var p := Progress.new()
	p.coins = maxi(0, int(data.get("coins", Economy.START_COINS)))
	var raw_levels: Variant = data.get("levels")
	if typeof(raw_levels) == TYPE_DICTIONARY:
		for key in raw_levels.keys():
			var entry: Variant = raw_levels[key]
			if not str(key).is_valid_int() or typeof(entry) != TYPE_DICTIONARY:
				continue
			var id := int(str(key))
			var stars := int(entry.get("stars", 0))
			if id < 1 or stars < 1 or stars > Economy.MAX_STARS:
				continue
			p.levels[id] = {
				"stars": stars,
				"best_moves": maxi(0, int(entry.get("best_moves", 0))),
				"best_wasted": maxi(-1, int(entry.get("best_wasted", -1))),
			}
	var raw_badges: Variant = data.get("badges")
	if typeof(raw_badges) == TYPE_ARRAY:
		for b in raw_badges:
			if typeof(b) == TYPE_STRING and BADGES.has(b) and not p.badges.has(b):
				p.badges.append(b)
	p.sound_enabled = bool(data.get("sound_enabled", true))
	return p


## Save v1 stored only {"completed": {id: moves}, "sound_enabled"}. Each
## completed level becomes 1 star with unknown wasted taps.
static func from_v1(data: Dictionary) -> Progress:
	var p := Progress.new()
	var raw: Variant = data.get("completed")
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw.keys():
			var moves := int(raw[key])
			if str(key).is_valid_int() and int(str(key)) >= 1 and moves > 0:
				p.levels[int(str(key))] = {"stars": 1, "best_moves": moves, "best_wasted": -1}
	p.sound_enabled = bool(data.get("sound_enabled", true))
	return p
