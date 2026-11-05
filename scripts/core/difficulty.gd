class_name Difficulty
extends RefCounted
## The two difficulty tiers. Difficult levels live in their own pack and use
## level ids offset by HARD_ID_BASE, so one save holds progress for both.

const EASY := 0
const DIFFICULT := 1
const COUNT := 2

## Difficult level n is saved as HARD_ID_BASE + n.
const HARD_ID_BASE := 1000

## Seconds a player has after each tap before the level is lost. Only
## Difficult has a clock; Easy lets players take as long as they like.
const HARD_COUNTDOWN := 10.0

const NAMES: Array[String] = ["Easy", "Difficult"]


static func of_level(level_id: int) -> int:
	return DIFFICULT if level_id > HARD_ID_BASE else EASY


## The number shown to the player (1..100 in either tier).
static func local_id(level_id: int) -> int:
	return level_id - HARD_ID_BASE if level_id > HARD_ID_BASE else level_id


static func make_id(difficulty: int, local: int) -> int:
	return HARD_ID_BASE + local if difficulty == DIFFICULT else local


## Seconds allowed between taps, or 0.0 when the level has no clock.
static func countdown_for(level_id: int) -> float:
	return HARD_COUNTDOWN if of_level(level_id) == DIFFICULT else 0.0


static func name_of(difficulty: int) -> String:
	return NAMES[clampi(difficulty, 0, COUNT - 1)]


## One line describing how the clock works, for menus.
static func rule_text(difficulty: int) -> String:
	if difficulty == DIFFICULT:
		return "Huge boards, almost no spare moves, and %d seconds per tap." % int(HARD_COUNTDOWN)
	return "Relaxed. No clock: take as long as you like."
