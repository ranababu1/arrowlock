class_name Economy
extends RefCounted
## Tuning constants for rewards. Kept in one place so balancing never touches
## gameplay code. Not yet tested against real players.
##
## Balance rule (checked by the tests): a player who scrapes through every
## level with one star earns about one Hint per level (20 + 5 = 25 per level,
## plus 50 per finished world, against a 30-coin Hint), so a struggling player
## is never locked out of help. A perfect player earns roughly twice that.

const START_COINS := 100
const CLEAR_BASE_COINS := 20
const COINS_PER_STAR := 5
const WORLD_COMPLETE_BONUS := 50

## Difficult levels pay this many times the Easy reward.
const HARD_REWARD_MULTIPLIER := 2

const PRICE_UNDO := 20
const PRICE_HINT := 30
const PRICE_EXTRA_MOVES := 50
const EXTRA_MOVES := 3

const LEVELS_PER_WORLD := 10
const WORLD_UNLOCK_CLEARS := 8

const MAX_STARS := 3

## Score (the leaderboard number). A level's score is its stars plus a speed
## bonus; each level keeps its best score and the leaderboard posts the sum.
const POINTS_PER_STAR := 100
## The speed bonus approaches this for an instant solve and never reaches it.
const SPEED_BONUS_MAX := 200
## Par time per arrow, in seconds. Solving in exactly par time earns half of
## SPEED_BONUS_MAX; twice as fast earns two thirds, and so on.
const PAR_SECONDS_PER_ARROW := 1.5
## Highest possible score of one level (3 stars and a perfect speed bonus).
const MAX_LEVEL_POINTS := POINTS_PER_STAR * MAX_STARS + SPEED_BONUS_MAX


## 3 stars: no wasted taps. 2 stars: wasted taps used at most half the slack
## (slack = moves_limit - arrow_count). 1 star: cleared.
static func stars_for(wasted_taps: int, slack: int) -> int:
	if wasted_taps <= 0:
		return 3
	if wasted_taps * 2 <= slack:
		return 2
	return 1


## Speed bonus for clearing `arrow_count` arrows in `seconds`. It falls
## smoothly with time and never hits zero, so faster always scores more and two
## players rarely tie. Unknown time (negative) earns no bonus.
static func speed_bonus(seconds: float, arrow_count: int) -> int:
	if seconds < 0.0 or arrow_count < 1:
		return 0
	var par := PAR_SECONDS_PER_ARROW * arrow_count
	return roundi(SPEED_BONUS_MAX * par / (par + seconds))


## Score of one clear: stars plus the speed bonus.
static func level_points(stars: int, seconds: float, arrow_count: int) -> int:
	return POINTS_PER_STAR * stars + speed_bonus(seconds, arrow_count)
