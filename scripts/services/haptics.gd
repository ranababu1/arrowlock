class_name Haptics
extends RefCounted
## Short vibrations for game events. Phones only, and only when the player has
## them switched on. Android needs the VIBRATE permission in the export preset.

const BLOCKED_MS := 35
const WIN_MS := 60
const LOSE_MS := 160

## Most recent durations requested (capped); tests read this instead of a motor.
const LOG_LIMIT := 32
static var log: Array[int] = []


## Returns true when a vibration was requested.
static func buzz(progress: Progress, duration_ms: int) -> bool:
	if progress == null or not progress.haptics_enabled or duration_ms <= 0:
		return false
	log.append(duration_ms)
	if log.size() > LOG_LIMIT:
		log.pop_front()
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
	return true
