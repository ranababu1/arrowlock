class_name PlayGames
extends Node
## Google Play Games sign-in and the online star leaderboards.
##
## Talks to the Android singleton of the GodotPlayGameServices plugin
## (addons/GodotPlayGameServices, MIT, v3.4.0). On desktop, in tests, or when a
## leaderboard id is missing, everything here quietly does nothing, so the game
## stays fully playable offline and signed out. Sign-in is optional.
##
## Leaderboard ids are set in data/play_games.json once the Play Console game
## services project exists (see docs/release.md).

signal auth_changed(signed_in: bool)

const SINGLETON := "GodotPlayGameServices"
const CONFIG_PATH := "res://data/play_games.json"
## Config key per tier, indexed by Difficulty constant.
const TIER_KEYS: Array[String] = ["stars_easy", "stars_difficult"]

var signed_in := false
## Leaderboard id per tier ("" = not configured).
var leaderboard_ids: Array[String] = ["", ""]

var _plugin: Object
var _progress: Progress
var _save: SaveService
## Leaderboard id -> [tier, score] of a submit waiting for its answer.
var _in_flight: Dictionary = {}


## `plugin` is for tests; normally the Android singleton is looked up.
func start(progress: Progress, save: SaveService, plugin: Object = null, config_path: String = CONFIG_PATH) -> void:
	_progress = progress
	_save = save
	_load_config(config_path)
	if plugin == null and Engine.has_singleton(SINGLETON):
		plugin = Engine.get_singleton(SINGLETON)
	_plugin = plugin
	if _plugin == null:
		return
	_plugin.initialize()
	_plugin.userAuthenticated.connect(_on_authenticated)
	_plugin.scoreSubmitted.connect(_on_score_submitted)
	# Play Games v2 signs returning players in silently; this asks for the result.
	_plugin.isAuthenticated()


## True when the plugin is present and `tier` has a leaderboard id.
func available(tier: int) -> bool:
	return _plugin != null and tier >= 0 and tier < leaderboard_ids.size() and leaderboard_ids[tier] != ""


func sign_in() -> void:
	if _plugin != null:
		_plugin.signIn()


## Opens Google's leaderboard screen for `tier`. Returns false if it cannot.
func show_leaderboard(tier: int) -> bool:
	if not available(tier) or not signed_in:
		return false
	_plugin.showLeaderboard(leaderboard_ids[tier])
	return true


## Sends the star total for `tier` if the leaderboard does not have it yet.
## Returns true when a submit was started.
func sync(tier: int) -> bool:
	if not available(tier) or not signed_in or _progress == null:
		return false
	var score := LeaderboardSync.score_to_submit(_progress, tier)
	var id := leaderboard_ids[tier]
	if score < 0 or _in_flight.has(id):
		return false
	_in_flight[id] = [tier, score]
	_plugin.submitScore(id, score)
	return true


func _on_authenticated(is_authenticated: bool) -> void:
	signed_in = is_authenticated
	auth_changed.emit(signed_in)
	if signed_in and _progress != null:
		sync(_progress.difficulty)


func _on_score_submitted(is_submitted: bool, leaderboard_id: String) -> void:
	if not _in_flight.has(leaderboard_id):
		return
	var entry: Array = _in_flight[leaderboard_id]
	_in_flight.erase(leaderboard_id)
	if not is_submitted or _progress == null:
		return  # retried on the next sync
	LeaderboardSync.mark_submitted(_progress, entry[0], entry[1])
	if _save != null:
		_save.save_data()


func _load_config(path: String) -> void:
	leaderboard_ids = ["", ""]
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("%s is not a JSON object" % path)
		return
	var boards: Variant = data.get("leaderboards", {})
	if typeof(boards) != TYPE_DICTIONARY:
		return
	for tier in TIER_KEYS.size():
		leaderboard_ids[tier] = str(boards.get(TIER_KEYS[tier], "")).strip_edges()
