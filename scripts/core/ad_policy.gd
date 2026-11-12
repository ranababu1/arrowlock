class_name AdPolicy
extends RefCounted
## When a finished game earns an interstitial. Pure logic: the Ads service
## supplies the clock and does the showing. Counters are persisted so a
## restart does not reset them.
##
## Owner rules (2026-11-12):
## 1. No ad until level 10 is crossed (level 11 and up in either tier).
##    Nothing overrides this.
## 2. Ads only after a round ends, when the player leaves the win or lose
##    panel. Never mid-round.
## 3. An ad is due only when both at least 3 eligible rounds (level 11+,
##    win or loss, including replays of the same level) have been finished
##    since the last ad, and at least 180 seconds have passed. The first ad
##    of a fresh install also needs both; the 180-second timer starts on
##    the first eligible finished round, not at install.

const DEFAULT_FIRST_LEVEL := 11
const DEFAULT_MIN_SECONDS_BETWEEN := 180.0
const DEFAULT_MIN_ROUNDS_BETWEEN := 3
const DEFAULT_STATE_PATH := "user://ad_policy.json"
const UNSET := -1.0

var enabled := true
## Lowest level number (as shown to the player, 1..100 in either tier) that shows ads.
var first_level := DEFAULT_FIRST_LEVEL
## Shortest gap between two ads. Also applied before the first ad, from the
## first eligible finished round.
var min_seconds_between := DEFAULT_MIN_SECONDS_BETWEEN
## Eligible rounds that must finish after the last ad (or from a fresh
## install) before another ad can show.
var min_rounds_between := DEFAULT_MIN_ROUNDS_BETWEEN
## Empty path means do not read or write state (used by unit tests).
var state_path := DEFAULT_STATE_PATH

## Wall-clock Unix time the frequency window started: the last ad, or the
## first eligible round when no ad has been shown yet. UNSET until then.
var _window_start := UNSET
## Eligible rounds finished in the current window.
var _rounds_since_ad := 0


## Builds a policy from the keys of data/ads.json. Missing or odd values
## fall back to the defaults.
static func from_config(config: Dictionary) -> AdPolicy:
	var p := AdPolicy.new()
	p.enabled = bool(config.get("enabled", true))
	var first: Variant = config.get("first_level", DEFAULT_FIRST_LEVEL)
	if typeof(first) in [TYPE_INT, TYPE_FLOAT] and int(first) >= 1:
		p.first_level = int(first)
	var gap: Variant = config.get("min_seconds_between", DEFAULT_MIN_SECONDS_BETWEEN)
	if typeof(gap) in [TYPE_INT, TYPE_FLOAT] and float(gap) >= 0.0:
		p.min_seconds_between = float(gap)
	var rounds: Variant = config.get("min_rounds_between", DEFAULT_MIN_ROUNDS_BETWEEN)
	if typeof(rounds) in [TYPE_INT, TYPE_FLOAT] and int(rounds) >= 1:
		p.min_rounds_between = int(rounds)
	return p


## True when this level number (in either tier) is allowed to show ads.
func is_eligible_level(level_id: int) -> bool:
	return Difficulty.local_id(level_id) >= first_level


## Records a finished round (win or loss) as the player leaves the end
## panel. Ineligible levels and a disabled policy are ignored. The first
## eligible round starts the time window.
func record_round(level_id: int, now: float) -> void:
	if not enabled or not is_eligible_level(level_id):
		return
	_clamp_window(now)
	_rounds_since_ad += 1
	if _window_start < 0.0:
		_window_start = now
	_save_state()


## True when leaving a finished game on `level_id` at clock time `now`
## should show an ad. Call after record_round for that same round.
func should_show(level_id: int, now: float) -> bool:
	if not enabled or not is_eligible_level(level_id):
		return false
	_clamp_window(now)
	if _rounds_since_ad < min_rounds_between or _window_start < 0.0:
		return false
	return now - _window_start >= min_seconds_between


## Starts a new frequency window; call when an ad actually appears.
func mark_shown(now: float) -> void:
	_window_start = now
	_rounds_since_ad = 0
	_save_state()


## Loads persisted counters. When `now` is a real clock time and the saved
## window start is in the future (clock skew), it is treated as now.
func load_state(now: float = UNSET) -> void:
	_window_start = UNSET
	_rounds_since_ad = 0
	if state_path == "" or not FileAccess.file_exists(state_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(state_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var rounds: Variant = parsed.get("rounds_since_ad", 0)
	if typeof(rounds) in [TYPE_INT, TYPE_FLOAT] and int(rounds) >= 0:
		_rounds_since_ad = int(rounds)
	var start: Variant = parsed.get("window_start", UNSET)
	if typeof(start) in [TYPE_INT, TYPE_FLOAT] and float(start) >= 0.0:
		_window_start = float(start)
	if now >= 0.0:
		_clamp_window(now)


## If the saved window start is in the future, treat it as now and persist
## the correction so a clock that stays behind cannot reset the timer forever.
func _clamp_window(now: float) -> void:
	if _window_start > now:
		_window_start = now
		_save_state()


func _save_state() -> void:
	if state_path == "":
		return
	var body := {
		"rounds_since_ad": _rounds_since_ad,
		"window_start": _window_start,
	}
	var tmp := state_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("AdPolicy: cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(body))
	file.close()
	var err := DirAccess.rename_absolute(tmp, state_path)
	if err != OK:
		push_error("AdPolicy: rename error %d" % err)
