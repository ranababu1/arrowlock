class_name AdPolicy
extends RefCounted
## When a finished game earns an interstitial. Pure logic: the Ads service
## supplies the clock and does the showing.
##
## Owner rule (2026-11-08): an ad after every game, won or lost, on level 11 and
## up in either tier, but never within 60 seconds of the previous ad.

const DEFAULT_FIRST_LEVEL := 11
const DEFAULT_MIN_SECONDS_BETWEEN := 60.0

var enabled := true
## Lowest level number (as shown to the player, 1..100 in either tier) that shows ads.
var first_level := DEFAULT_FIRST_LEVEL
## Shortest gap between two ads, so quick retries do not stack ads.
var min_seconds_between := DEFAULT_MIN_SECONDS_BETWEEN

## Clock time (seconds) the last ad was shown, or -1 when none yet this session.
var _last_shown := -1.0


## Builds a policy from the "enabled", "first_level" and "min_seconds_between"
## keys of data/ads.json. Missing or odd values fall back to the defaults.
static func from_config(config: Dictionary) -> AdPolicy:
	var p := AdPolicy.new()
	p.enabled = bool(config.get("enabled", true))
	var first: Variant = config.get("first_level", DEFAULT_FIRST_LEVEL)
	if typeof(first) in [TYPE_INT, TYPE_FLOAT] and int(first) >= 1:
		p.first_level = int(first)
	var gap: Variant = config.get("min_seconds_between", DEFAULT_MIN_SECONDS_BETWEEN)
	if typeof(gap) in [TYPE_INT, TYPE_FLOAT] and float(gap) >= 0.0:
		p.min_seconds_between = float(gap)
	return p


## True when ending a game on `level_id` at clock time `now` should show an ad.
func should_show(level_id: int, now: float) -> bool:
	if not enabled or Difficulty.local_id(level_id) < first_level:
		return false
	return _last_shown < 0.0 or now - _last_shown >= min_seconds_between


## Starts the gap; call when an ad actually appears.
func mark_shown(now: float) -> void:
	_last_shown = now
