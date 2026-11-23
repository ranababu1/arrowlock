class_name GameCenterBridge
extends RefCounted
## Makes Apple Game Center look like the Play Games plugin to `PlayGames`, so
## sign-in, score sending, retries and the Profile screen are shared by both.
##
## Wraps the `GameCenterKit` singleton of the GameCenterKit GDExtension
## (addons/gamecenter, MIT, v1.0.1; fetched by tools/build_ios.sh, not in Git).
## It exists only in iOS builds made with Game Center switched on
## (docs/release-ios.md §8). Game Center has no profile picture in that plugin,
## so the Profile screen keeps the local avatar.

signal userAuthenticated(is_authenticated: bool)
signal scoreSubmitted(is_submitted: bool, leaderboard_id: String)
signal currentPlayerLoaded(player_json: String)
signal imageStored(file_path: String)

const SINGLETON := "GameCenterKit"
## Leaderboard ids as created in App Store Connect.
const CONFIG_PATH := "res://data/game_center.json"

var _kit: Object


## The GameCenterKit singleton on iOS when it is in the build, else null.
static func find_kit() -> Object:
	if OS.get_name() == "iOS" and Engine.has_singleton(SINGLETON):
		return Engine.get_singleton(SINGLETON)
	return null


func _init(kit: Object) -> void:
	_kit = kit


func initialize() -> void:
	_kit.authenticated.connect(_on_authenticated)
	_kit.score_submitted.connect(_on_score_submitted)
	_kit.panel_failed.connect(_on_panel_failed)


## Game Center asks once per launch: Apple shows its sign-in sheet, or a
## "Welcome back" banner when the player is already signed in on the device.
func isAuthenticated() -> void:
	if _kit.is_authenticated():
		_on_authenticated.call_deferred(true, "")
	else:
		_kit.authenticate()


func signIn() -> void:
	_kit.authenticate()


func submitScore(leaderboard_id: String, score: int) -> void:
	_kit.submit_score(leaderboard_id, score)


func showLeaderboard(leaderboard_id: String) -> void:
	_kit.show_leaderboard(leaderboard_id)


## Only the name is available; `PlayGames` keeps the picture empty.
func loadCurrentPlayer(_force_reload: bool) -> void:
	currentPlayerLoaded.emit.call_deferred(JSON.stringify({"displayName": str(_kit.player_display_name())}))


func _on_authenticated(ok: bool, error: String) -> void:
	if not ok and error != "":
		push_warning("Game Center sign-in: " + error)
	userAuthenticated.emit(ok)


func _on_score_submitted(ok: bool, leaderboard_id: String, error: String) -> void:
	if not ok:
		push_warning("Game Center score not sent (%s): %s" % [leaderboard_id, error])
	scoreSubmitted.emit(ok, leaderboard_id)


func _on_panel_failed(panel: String, error: String) -> void:
	push_warning("Game Center %s could not open: %s" % [panel, error])
