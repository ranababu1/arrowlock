class_name Economy
extends RefCounted
## Tuning constants for rewards. Kept in one place so balancing never touches
## gameplay code. Values come from docs/level-plan-100.md and are untested
## against real players.

const START_COINS := 100
const CLEAR_BASE_COINS := 10
const COINS_PER_STAR := 5
const WORLD_COMPLETE_BONUS := 25

const PRICE_UNDO := 20
const PRICE_HINT := 30
const PRICE_EXTRA_MOVES := 50
const EXTRA_MOVES := 3

const LEVELS_PER_WORLD := 10
const WORLD_UNLOCK_CLEARS := 8

const MAX_STARS := 3


## 3 stars: no wasted taps. 2 stars: wasted taps used at most half the slack
## (slack = moves_limit - arrow_count). 1 star: cleared.
static func stars_for(wasted_taps: int, slack: int) -> int:
	if wasted_taps <= 0:
		return 3
	if wasted_taps * 2 <= slack:
		return 2
	return 1
