class_name PlayGames
extends Node
## Google Play Games sign-in, the player's Play Games profile (gamer name and
## picture, for the Profile screen) and the online score leaderboards.
##
## Talks to the Android singleton of the GodotPlayGameServices plugin
## (addons/GodotPlayGameServices, MIT, v3.4.0). On desktop, in tests, or when a
## leaderboard id is missing, everything here quietly does nothing, so the game
## stays fully playable offline and signed out. Sign-in is optional.
##
## Leaderboard ids are set in data/play_games.json once the Play Console game
## services project exists (see docs/release.md).

signal auth_changed(signed_in: bool)
## The signed-in player's name or picture arrived (or changed).
signal player_changed

const SINGLETON := "GodotPlayGameServices"
const CONFIG_PATH := "res://data/play_games.json"
## Config key per tier, indexed by Difficulty constant.
const TIER_KEYS: Array[String] = ["score_easy", "score_difficult"]

var signed_in := false
## Leaderboard id per tier ("" = not configured).
var leaderboard_ids: Array[String] = ["", ""]
## Play Games gamer name of the signed-in player ("" until loaded). This is the
## name other players see on the leaderboard.
var player_name := ""
## Play Games profile picture, or null until it has been downloaded.
var player_picture: Texture2D

var _plugin: Object
var _progress: Progress
var _save: SaveService
## Leaderboard id -> [tier, score] of a submit waiting for its answer.
var _in_flight: Dictionary = {}
## user:// file the plugin saves the profile picture to.
var _picture_path := ""


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
	_plugin.currentPlayerLoaded.connect(_on_current_player_loaded)
	_plugin.imageStored.connect(_on_image_stored)
	# Play Games v2 signs returning players in silently; this asks for the result.
	_plugin.isAuthenticated()


## True when the plugin is present and `tier` has a leaderboard id.
func available(tier: int) -> bool:
	return _plugin != null and tier >= 0 and tier < leaderboard_ids.size() and leaderboard_ids[tier] != ""


## True when Play Games is set up in this build (plugin present and at least
## one leaderboard id configured), so offering sign-in makes sense.
func is_configured() -> bool:
	return _plugin != null and leaderboard_ids.any(func(id: String) -> bool: return id != "")


func sign_in() -> void:
	if _plugin != null:
		_plugin.signIn()


## Opens Google's leaderboard screen for `tier`. Returns false if it cannot.
func show_leaderboard(tier: int) -> bool:
	if not available(tier) or not signed_in:
		return false
	_plugin.showLeaderboard(leaderboard_ids[tier])
	return true


## Sends the score for `tier` if the leaderboard does not have it yet.
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
	if signed_in:
		# Name and picture of the gamer profile; the plugin downloads the picture
		# through Google's ImageManager into the app's private files.
		_plugin.loadCurrentPlayer(false)
	if signed_in and _progress != null:
		sync(_progress.difficulty)


## `json` is the plugin's player record: displayName, hiResImageUri /
## iconImageUri (already user:// file paths), hasHiResImage, ...
func _on_current_player_loaded(json: String) -> void:
	var data: Variant = JSON.parse_string(json)
	if typeof(data) != TYPE_DICTIONARY:
		push_error("PlayGames: current player record is not a JSON object")
		return
	player_name = str(data.get("displayName", "")).strip_edges()
	var key := "hiResImageUri" if bool(data.get("hasHiResImage", false)) else "iconImageUri"
	var path := str(data.get(key, ""))
	_picture_path = path if path.begins_with("user://") else ""
	# A picture saved on an earlier launch can be shown right away.
	_load_picture()
	player_changed.emit()


func _on_image_stored(file_path: String) -> void:
	if file_path != "" and file_path == _picture_path:
		_load_picture()
		player_changed.emit()


func _load_picture() -> void:
	if _picture_path == "" or not FileAccess.file_exists(_picture_path):
		return
	var image := Image.load_from_file(_picture_path)
	if image == null or image.is_empty():
		push_warning("PlayGames: could not read the profile picture")
		return
	player_picture = ImageTexture.create_from_image(image)


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
