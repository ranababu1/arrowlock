class_name Tutorial
extends RefCounted
## First-run coaching for the first three levels. Pure logic: given the level
## and the board, say what to tell the player and which arrow to point at.
## Tips switch themselves off once level 3 is cleared and can be turned back
## on in Settings.

const LAST_TIP_LEVEL := 3
## Taps after which the plain-text tips on levels 2 and 3 disappear.
const TEXT_TIP_TAPS := 3

const TEXT_TAP := "Tap a glowing arrow to slide it off the board."
const TEXT_BLOCKED := "The red arrow is blocked by the white one. Tapping a blocked arrow wastes a move, so clear the blocker first."
const TEXT_REST := "Nice! Now clear the rest of the board."
const TEXT_MOVES := "Every tap costs a move, even on a blocked arrow. Watch MOVES LEFT."
const TEXT_HINT := "Stuck? Hint shows an arrow that is free to go. It costs a few coins."
const TEXT_TURNER := "Arrows with a ring turn a quarter clockwise every time another arrow leaves. Plan the order!"
const TEXT_TURNER_TRAP := "A free arrow can be a trap: after it leaves, a ringed arrow may turn into a wall."
const TEXT_TURNER_HINT := "Hint knows which free arrows are safe. If it says there is no way out, undo or retry."
const TEXT_COLOR := "Clear arrows in the colour order shown above the board. Tap a free arrow in the colour marked NEXT."
const TEXT_COLOR_CHANGE := "Colours change after every tap, so look again each time. A wrong colour costs a move."
const TEXT_COLOR_ORDER := "Every try brings a new colour order. Learn it fast!"
const TEXT_FLIP := "Arrows with two dots flip back and forth. Tap one while it points to free space."
const TEXT_FLIP_TIMING := "Watch the rhythm: a flipping arrow pointing at a wall wastes a move."
const TEXT_FLIP_FAST := "Some flippers can only leave one way. Be quick!"
const TEXT_MIX := "Everything at once: rings turn, dots flip, and colours set the order."
const TEXT_MIX_PLAN := "Plan the turns, time the flips, and follow the colours."
const TEXT_MIX_HINT := "Hint picks a safe arrow in the right colour. Use it when stuck."
## First levels of each new rule (local numbers, both modes) -> tip text.
## These show even after the first-run tips have switched off.
const RULE_TIPS := {
	101: TEXT_TURNER, 102: TEXT_TURNER_TRAP, 103: TEXT_TURNER_HINT,
	121: TEXT_COLOR, 122: TEXT_COLOR_CHANGE, 123: TEXT_COLOR_ORDER,
	141: TEXT_FLIP, 142: TEXT_FLIP_TIMING, 143: TEXT_FLIP_FAST,
	161: TEXT_MIX, 162: TEXT_MIX_PLAN, 163: TEXT_MIX_HINT,
}

## What a pointer means: "clear" = tap this one, "blocked" = this one is stuck.
const KIND_CLEAR := "clear"
const KIND_BLOCKED := "blocked"


## Returns {"text", "target", "kind", "blocker"}: target is the arrow to point at
## (-1 for none) and blocker is the arrow in its way when kind is "blocked"
## (-1 otherwise). Returns {} when there is nothing to say.
static func step_for(level_id: int, board: BoardState, moves_used: int, tips_enabled: bool) -> Dictionary:
	var local := Difficulty.local_id(level_id)
	if RULE_TIPS.has(local) and not board.is_empty():
		return _text_only(RULE_TIPS[local], moves_used)
	if not tips_enabled or level_id < 1 or level_id > LAST_TIP_LEVEL or board.is_empty():
		return {}
	match level_id:
		1:
			return _first_level(board, moves_used)
		2:
			return _text_only(TEXT_MOVES, moves_used)
		_:
			return _text_only(TEXT_HINT, moves_used)


static func _first_level(board: BoardState, moves_used: int) -> Dictionary:
	var free := MoveValidator.removable_ids(board)
	if free.is_empty():
		return {}
	if moves_used == 0:
		return {"text": TEXT_TAP, "target": _teaching_arrow(board, free), "kind": KIND_CLEAR, "blocker": -1}
	for id in board.arrow_ids():
		if MoveValidator.first_blocker(board, id) != -1:
			return {"text": TEXT_BLOCKED, "target": id, "kind": KIND_BLOCKED, "blocker": MoveValidator.first_blocker(board, id)}
	return {"text": TEXT_REST, "target": -1, "kind": "", "blocker": -1}


## Prefer a free arrow that is not blocking anything, so after it leaves the
## blocked arrow is still visibly stuck and the next step can explain it.
static func _teaching_arrow(board: BoardState, free: Array[int]) -> int:
	var blockers: Dictionary = {}
	for id in board.arrow_ids():
		for other in MoveValidator.ray_arrows(board, id):
			blockers[other] = true
	for id in free:
		if not blockers.has(id):
			return id
	return free[0]


static func _text_only(text: String, moves_used: int) -> Dictionary:
	if moves_used >= TEXT_TIP_TAPS:
		return {}
	return {"text": text, "target": -1, "kind": "", "blocker": -1}
