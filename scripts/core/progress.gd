class_name Progress
extends RefCounted
## Player progress and reward logic. Pure data: no file access, no nodes.
## SaveService handles persistence; this class owns the rules.

const BADGES: Array[String] = [
	"first_clear", "clears_10", "clears_50", "clears_100", "perfect_clear", "world_perfect",
	"hard_clear",
]
## Title and how to earn it, for every badge in BADGES.
const BADGE_INFO := {
	"first_clear": ["First clear", "Clear any level."],
	"clears_10": ["10 levels cleared", "Clear 10 levels."],
	"clears_50": ["50 levels cleared", "Clear 50 levels."],
	"clears_100": ["All 100 levels cleared", "Clear every level of one mode."],
	"perfect_clear": ["Perfect level", "Clear a level without a wasted tap."],
	"world_perfect": ["Perfect world", "Get 3 stars on all 10 levels of a world."],
	"hard_clear": ["Difficult cleared", "Clear a level in Difficult mode."],
}

var coins: int = Economy.START_COINS
## level id -> {"stars": int, "best_moves": int, "best_wasted": int,
## "best_points": int, "best_seconds": float}.
## best_wasted and best_seconds are -1 when unknown (older saves).
var levels: Dictionary = {}
var badges: Array[String] = []
## Sound effects on/off.
var sound_enabled: bool = true
var music_enabled: bool = true
## 0..1 multipliers on the music and effects loudness (1 = the mixed level).
var music_volume: float = 1.0
var sfx_volume: float = 1.0
## Coaching on the first levels; switches off once level 3 is cleared.
var tips_enabled: bool = true
## Short vibrations on blocked taps, wins and losses (phones only).
var haptics_enabled: bool = true
## Local profile, used when the player is not signed in to Play Games. Stays on
## the phone; never sent anywhere. "" = not set ("Player" is shown).
var profile_name: String = ""
## Index into the built-in avatar designs (AvatarView.CHOICES).
var profile_avatar: int = 0
## Tier -> the score the online leaderboard last confirmed. Kept across a
## tier switch: the leaderboard keeps the best score anyway.
var leaderboard_sent: Dictionary = {}
## The tier the player is playing now (a Difficulty constant). Progress of both
## tiers lives side by side (Difficult ids are offset by HARD_ID_BASE).
var difficulty: int = Difficulty.EASY


## World index (0-based) within the level's own tier.
## Makes `tier` the mode in play. Keeps everything: each tier's levels, the
## shared coins and badges (owner rule 2026-11-08; before that a switch wiped
## progress). Returns false and changes nothing when `tier` is already the
## current one or is not a tier.
func switch_difficulty(tier: int) -> bool:
	if tier == difficulty or tier < 0 or tier >= Difficulty.COUNT:
		return false
	difficulty = tier
	return true


static func world_of(level_id: int) -> int:
	return (Difficulty.local_id(level_id) - 1) / Economy.LEVELS_PER_WORLD


func is_cleared(level_id: int) -> bool:
	return levels.has(level_id)


func stars_of(level_id: int) -> int:
	return levels[level_id]["stars"] if levels.has(level_id) else 0


## Cleared levels in one tier, or in both when `tier` is -1.
func cleared_count(tier: int = -1) -> int:
	if tier < 0:
		return levels.size()
	var count := 0
	for id in levels.keys():
		if Difficulty.of_level(id) == tier:
			count += 1
	return count


## Stars earned in one tier, or in both when `tier` is -1.
func total_stars(tier: int = -1) -> int:
	var total := 0
	for id in levels.keys():
		if tier < 0 or Difficulty.of_level(id) == tier:
			total += levels[id]["stars"]
	return total


## Best score of one level (0 when not cleared).
func points_of(level_id: int) -> int:
	return levels[level_id]["best_points"] if levels.has(level_id) else 0


## Score in one tier, or in both when `tier` is -1: the sum of every level's
## best score. This is the number the leaderboard shows.
func total_points(tier: int = -1) -> int:
	var total := 0
	for id in levels.keys():
		if tier < 0 or Difficulty.of_level(id) == tier:
			total += levels[id]["best_points"]
	return total


func world_clears(world: int, tier: int = Difficulty.EASY) -> int:
	var count := 0
	for id in levels.keys():
		if world_of(id) == world and Difficulty.of_level(id) == tier:
			count += 1
	return count


func _world_perfect_count(world: int, tier: int) -> int:
	var count := 0
	for id in levels.keys():
		if world_of(id) == world and Difficulty.of_level(id) == tier 				and levels[id]["stars"] == Economy.MAX_STARS:
			count += 1
	return count


func is_world_unlocked(world: int, tier: int = Difficulty.EASY) -> bool:
	return world <= 0 or world_clears(world - 1, tier) >= Economy.WORLD_UNLOCK_CLEARS


func is_level_unlocked(level_id: int) -> bool:
	return Difficulty.local_id(level_id) >= 1 and is_world_unlocked(world_of(level_id), Difficulty.of_level(level_id))


func can_afford(price: int) -> bool:
	return price >= 0 and coins >= price


## Deducts `price`; returns false and changes nothing if it cannot be paid.
func spend(price: int) -> bool:
	if not can_afford(price):
		return false
	coins -= price
	return true


## Records a finished level and returns what was earned:
## {"stars", "coins_earned", "first_clear", "improved", "world_bonus",
## "new_badges", "points", "best_points", "new_best"}.
## `moves_limit` is the level's original limit (not including extra moves).
## `seconds` is how long the attempt took (-1 when unknown: no speed bonus).
## Returns {} for impossible inputs and changes nothing.
func record_result(level_id: int, arrow_count: int, moves_limit: int, moves_used: int, wasted_taps: int, seconds: float = -1.0) -> Dictionary:
	if level_id < 1 or arrow_count < 1 or moves_limit < arrow_count \
			or moves_used < arrow_count or wasted_taps < 0 or wasted_taps > moves_used:
		push_error("record_result: inconsistent result for level %d" % level_id)
		return {}
	var stars := Economy.stars_for(wasted_taps, moves_limit - arrow_count)
	var world := world_of(level_id)
	var tier := Difficulty.of_level(level_id)
	var multiplier := Economy.HARD_REWARD_MULTIPLIER if tier == Difficulty.DIFFICULT else 1
	var clears_before := world_clears(world, tier)
	var first := not levels.has(level_id)
	var old_stars := stars_of(level_id)
	var old_points := points_of(level_id)
	var points := Economy.level_points(stars, seconds, arrow_count)
	var earned := 0
	if first:
		earned = (Economy.CLEAR_BASE_COINS + Economy.COINS_PER_STAR * stars) * multiplier
		levels[level_id] = {"stars": stars, "best_moves": moves_used, "best_wasted": wasted_taps,
			"best_points": points, "best_seconds": seconds if seconds >= 0.0 else -1.0}
	else:
		var entry: Dictionary = levels[level_id]
		if stars > old_stars:
			earned = Economy.COINS_PER_STAR * (stars - old_stars) * multiplier
			entry["stars"] = stars
		entry["best_moves"] = mini(entry["best_moves"], moves_used)
		if entry["best_wasted"] < 0 or wasted_taps < entry["best_wasted"]:
			entry["best_wasted"] = wasted_taps
		entry["best_points"] = maxi(entry["best_points"], points)
		if seconds >= 0.0 and (entry["best_seconds"] < 0.0 or seconds < entry["best_seconds"]):
			entry["best_seconds"] = seconds
	var world_bonus := 0
	if clears_before < Economy.LEVELS_PER_WORLD and world_clears(world, tier) == Economy.LEVELS_PER_WORLD:
		world_bonus = Economy.WORLD_COMPLETE_BONUS * multiplier
	coins += earned + world_bonus
	if first and level_id == Tutorial.LAST_TIP_LEVEL:
		tips_enabled = false
	return {
		"stars": stars,
		"coins_earned": earned + world_bonus,
		"first_clear": first,
		"improved": stars > old_stars,
		"world_bonus": world_bonus,
		"new_badges": _award_badges(world, tier),
		"points": points,
		"best_points": maxi(points, old_points),
		"new_best": points > old_points,
	}


func _award_badges(world: int, tier: int) -> Array[String]:
	var earned: Array[String] = []
	var wanted: Array[String] = []
	var cleared := cleared_count()
	if cleared >= 1:
		wanted.append("first_clear")
	if cleared >= 10:
		wanted.append("clears_10")
	if cleared >= 50:
		wanted.append("clears_50")
	if maxi(cleared_count(Difficulty.EASY), cleared_count(Difficulty.DIFFICULT)) >= 100:
		wanted.append("clears_100")
	if cleared_count(Difficulty.DIFFICULT) >= 1:
		wanted.append("hard_clear")
	if _perfect_level_count() > 0:
		wanted.append("perfect_clear")
	if _world_perfect_count(world, tier) == Economy.LEVELS_PER_WORLD:
		wanted.append("world_perfect")
	for b in wanted:
		if not badges.has(b):
			badges.append(b)
			earned.append(b)
	return earned


static func badge_title(badge: String) -> String:
	return BADGE_INFO[badge][0] if BADGE_INFO.has(badge) else badge


static func badge_hint(badge: String) -> String:
	return BADGE_INFO[badge][1] if BADGE_INFO.has(badge) else ""


## Numbers for the stats screen, for one tier:
## {"cleared", "stars", "perfect", "worlds_complete", "points"}.
func stats(tier: int) -> Dictionary:
	var perfect := 0
	for id in levels.keys():
		if Difficulty.of_level(id) == tier and levels[id]["stars"] == Economy.MAX_STARS:
			perfect += 1
	var worlds := 0
	for w in Economy.LEVELS_PER_WORLD:
		if world_clears(w, tier) == Economy.LEVELS_PER_WORLD:
			worlds += 1
	return {
		"cleared": cleared_count(tier),
		"stars": total_stars(tier),
		"perfect": perfect,
		"worlds_complete": worlds,
		"points": total_points(tier),
	}


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
		"music_enabled": music_enabled,
		"tips_enabled": tips_enabled,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"difficulty": difficulty,
		"haptics_enabled": haptics_enabled,
		"leaderboard_sent": _sent_to_dict(),
		"profile_name": profile_name,
		"profile_avatar": profile_avatar,
	}


func _sent_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for tier in leaderboard_sent.keys():
		out[str(tier)] = leaderboard_sent[tier]
	return out


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
			# Saves from before the score existed get the stars-only score.
			var floor_points := Economy.POINTS_PER_STAR * stars
			p.levels[id] = {
				"stars": stars,
				"best_moves": maxi(0, int(entry.get("best_moves", 0))),
				"best_wasted": maxi(-1, int(entry.get("best_wasted", -1))),
				"best_points": clampi(int(entry.get("best_points", floor_points)), floor_points, Economy.MAX_LEVEL_POINTS),
				"best_seconds": maxf(-1.0, float(entry.get("best_seconds", -1.0))),
			}
	var raw_badges: Variant = data.get("badges")
	if typeof(raw_badges) == TYPE_ARRAY:
		for b in raw_badges:
			if typeof(b) == TYPE_STRING and BADGES.has(b) and not p.badges.has(b):
				p.badges.append(b)
	p.sound_enabled = bool(data.get("sound_enabled", true))
	p.music_enabled = bool(data.get("music_enabled", true))
	p.tips_enabled = bool(data.get("tips_enabled", true))
	p.music_volume = clampf(float(data.get("music_volume", 1.0)), 0.0, 1.0)
	p.sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
	p.difficulty = clampi(int(data.get("difficulty", Difficulty.EASY)), 0, Difficulty.COUNT - 1)
	p.haptics_enabled = bool(data.get("haptics_enabled", true))
	var sent: Variant = data.get("leaderboard_sent")
	if typeof(sent) == TYPE_DICTIONARY:
		for key in sent.keys():
			var tier := int(str(key)) if str(key).is_valid_int() else -1
			if tier >= 0 and tier < Difficulty.COUNT:
				p.leaderboard_sent[tier] = clampi(int(sent[key]), 0, Economy.MAX_LEVEL_POINTS * 100)
	p.profile_name = clean_name(str(data.get("profile_name", "")))
	p.profile_avatar = clampi(int(data.get("profile_avatar", 0)), 0, AVATAR_COUNT - 1)
	return p


## Longest local profile name, in characters.
const NAME_MAX_LENGTH := 16
## How many built-in avatar designs there are (AvatarView.CHOICES has this many).
const AVATAR_COUNT := 8


## A safe local profile name: control characters removed, runs of spaces
## collapsed, trimmed, at most NAME_MAX_LENGTH characters.
static func clean_name(text: String) -> String:
	var out := ""
	var last_space := true
	for ch in text:
		var code := ch.unicode_at(0)
		if code < 32 or code == 127 or ch == " " or ch == "\t":
			if not last_space:
				out += " "
			last_space = true
		else:
			out += ch
			last_space = false
	return out.strip_edges().left(NAME_MAX_LENGTH).strip_edges()


## Name to show for the local profile.
func display_name() -> String:
	return profile_name if profile_name != "" else "Player"


## Save v1 stored only {"completed": {id: moves}, "sound_enabled"}. Each
## completed level becomes 1 star with unknown wasted taps.
static func from_v1(data: Dictionary) -> Progress:
	var p := Progress.new()
	var raw: Variant = data.get("completed")
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw.keys():
			var moves := int(raw[key])
			if str(key).is_valid_int() and int(str(key)) >= 1 and moves > 0:
				p.levels[int(str(key))] = {"stars": 1, "best_moves": moves, "best_wasted": -1,
					"best_points": Economy.POINTS_PER_STAR, "best_seconds": -1.0}
	p.sound_enabled = bool(data.get("sound_enabled", true))
	return p
