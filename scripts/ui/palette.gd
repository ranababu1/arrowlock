class_name Palette
extends RefCounted
## Colour system. One place to change the look of the whole game.

const BG_TOP := Color("0b1022")
const BG_BOTTOM := Color("1b1445")
const SURFACE := Color("151a33")

const TEXT := Color("f5f7ff")
const MUTED := Color("9aa3c7")

const PRIMARY := Color("6c5cff")
const PRIMARY_HOVER := Color("8174ff")
const PRIMARY_PRESSED := Color("5646e0")
const CYAN := Color("2dd4ff")
const MINT := Color("35e0a1")
const CORAL := Color("ff8a5b")
const LAVENDER := Color("c084fc")
const GOLD := Color("ffc83d")
const RED := Color("ff5d73")
const PINK := Color("ff6fb5")
const BLUE := Color("5b8cff")

const GLASS := Color(1, 1, 1, 0.07)
const GLASS_HOVER := Color(1, 1, 1, 0.12)
const GLASS_PRESSED := Color(1, 1, 1, 0.17)
const GLASS_BORDER := Color(1, 1, 1, 0.14)

const WORLD_COLORS: Array[Color] = [
	Color("6c5cff"), Color("2dd4ff"), Color("35e0a1"), Color("ff8a5b"), Color("ffc83d"),
	Color("ff6fb5"), Color("5b8cff"), Color("c084fc"), Color("2fd6c4"), Color("ff5d73"),
]
## Short names shown on each world card.
const WORLD_NAMES: Array[String] = [
	"First Steps", "Crossroads", "Long Lines", "Late Blockers", "Tight Squeeze",
	"Dense Lanes", "Deep Chains", "Pressure", "Expert", "Gridlock",
]


static func world_color(world: int) -> Color:
	return WORLD_COLORS[world % WORLD_COLORS.size()]


static func world_name(world: int) -> String:
	return WORLD_NAMES[world % WORLD_NAMES.size()]


## Arrow colour by direction. Direction is also in the arrow's shape, so colour
## is a help, not the only cue.
static func direction_color(dir: String) -> Color:
	match dir:
		"up":
			return CYAN
		"right":
			return MINT
		"down":
			return CORAL
		_:
			return LAVENDER
