class_name GameScreen
extends Control
## One level in play: HUD, board, helpers and the win / game-over panels.
## Rules live in GameController and Progress; this class only presents them.

signal menu_requested
signal next_requested(index: int)

const BADGE_NAMES := {
	"first_clear": "First clear",
	"clears_10": "10 levels cleared",
	"clears_50": "50 levels cleared",
	"clears_100": "All 100 levels cleared",
	"perfect_clear": "Perfect level",
	"world_perfect": "Perfect world",
}
const LOW_MOVES_RATIO := 0.25
const MID_MOVES_RATIO := 0.5
const OVERLAY_FADE_SECONDS := 0.2
const STAR_START_DELAY := 0.6
const STAR_STEP := 0.3

var controller := GameController.new()
var board_view: BoardView

var _levels: Array[Dictionary]
var _index: int
var _progress: Progress
var _save: SaveService
var _audio: AudioManager  ## optional; null in tests that do not need sound

var _title: Label
var _world_caption: Label
var _coins: Label
var _moves: Label
var _arrows: Label
var _moves_bar: ProgressPill
var _note: Label
var _undo_button: ActionButton
var _hint_button: ActionButton
var _overlay: Control
var _overlay_title: Label
var _overlay_stars: StarRow
var _overlay_detail: Label
var _overlay_primary: Button
var _overlay_extra: Button
var _overlay_secondary: Button
var _confetti: Confetti
var _overlay_kind := ""


## Call after adding to the tree.
func setup(levels: Array[Dictionary], index: int, progress: Progress, save: SaveService, audio: AudioManager = null) -> void:
	_audio = audio
	_levels = levels
	_index = index
	_progress = progress
	_save = save
	_build()
	_load_level()


func overlay_kind() -> String:
	return _overlay_kind


func tap_cell(cell: Vector2i) -> void:
	if _overlay_kind != "":
		return
	board_view.clear_hint()
	_note.text = ""
	controller.tap(cell)
	_refresh()


func use_undo() -> void:
	if not controller.can_undo():
		return
	if not _progress.spend(Economy.PRICE_UNDO):
		_note.text = "Undo costs %d coins" % Economy.PRICE_UNDO
		return
	board_view.clear_hint()
	controller.undo()
	_save.save_data()
	_refresh()


func use_hint() -> void:
	var id := controller.hint()
	if id == -1:
		return
	if not _progress.spend(Economy.PRICE_HINT):
		_note.text = "Hint costs %d coins" % Economy.PRICE_HINT
		return
	board_view.show_hint(id)
	_sfx("hint")
	_note.text = "Tap the highlighted arrow"
	_save.save_data()
	_refresh()


func use_extra_moves() -> void:
	if controller.state != GameController.State.LOST or controller.extra_moves_granted > 0:
		return
	if not _progress.spend(Economy.PRICE_EXTRA_MOVES):
		_note.text = "Extra moves cost %d coins" % Economy.PRICE_EXTRA_MOVES
		return
	controller.grant_extra_moves(Economy.EXTRA_MOVES)
	_sfx("coin")
	_save.save_data()
	_hide_overlay()
	_refresh()


func restart() -> void:
	controller.restart()
	board_view.clear_animations()
	_hide_overlay()
	_note.text = ""
	_refresh()


func press_next() -> void:
	var next := _next_index()
	if next == -1:
		menu_requested.emit()
	else:
		next_requested.emit(next)


## Index of the next playable level, or -1 if there is none (end of the pack
## or the next world is still locked).
func _next_index() -> int:
	var next := _index + 1
	if next < _levels.size() and _progress.is_level_unlocked(_levels[next]["id"]):
		return next
	return -1


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(_top_bar())
	root.add_child(_moves_card())

	_note = Label.new()
	_note.theme_type_variation = "Caption"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.custom_minimum_size = Vector2(0, 20)
	root.add_child(_note)

	var board_card := PanelContainer.new()
	board_card.theme_type_variation = "Card"
	board_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board_card)
	board_view = BoardView.new()
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.cell_tapped.connect(tap_cell)
	board_card.add_child(board_view)

	var helpers := HBoxContainer.new()
	helpers.add_theme_constant_override("separation", 10)
	root.add_child(helpers)
	_undo_button = ActionButton.new("undo", "Undo", Economy.PRICE_UNDO)
	_undo_button.pressed.connect(use_undo)
	helpers.add_child(_undo_button)
	_hint_button = ActionButton.new("bulb", "Hint", Economy.PRICE_HINT)
	_hint_button.pressed.connect(use_hint)
	helpers.add_child(_hint_button)
	var restart_button := ActionButton.new("restart", "Restart")
	restart_button.pressed.connect(restart)
	helpers.add_child(restart_button)
	_build_overlay()


func _top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	var back := IconButton.new("back", 52)
	back.pressed.connect(func() -> void: menu_requested.emit())
	bar.add_child(back)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 0)
	bar.add_child(names)
	_title = Label.new()
	_title.theme_type_variation = "Subheading"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_title)
	_world_caption = Label.new()
	_world_caption.theme_type_variation = "Caption"
	_world_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	names.add_child(_world_caption)
	var chip := PanelContainer.new()
	chip.theme_type_variation = "Card"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 6)
	chip.add_child(chip_row)
	var coin := GlyphView.new("coin", Palette.GOLD, 22)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip_row.add_child(coin)
	_coins = Label.new()
	_coins.theme_type_variation = "Subheading"
	chip_row.add_child(_coins)
	bar.add_child(chip)
	return bar


func _moves_card() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", -4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var moves_caption := Label.new()
	moves_caption.text = "MOVES LEFT"
	moves_caption.theme_type_variation = "Caption"
	left.add_child(moves_caption)
	_moves = Label.new()
	_moves.theme_type_variation = "Heading"
	_moves.add_theme_font_size_override("font_size", 52)
	left.add_child(_moves)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", -4)
	row.add_child(right)
	var arrows_caption := Label.new()
	arrows_caption.text = "ARROWS"
	arrows_caption.theme_type_variation = "Caption"
	arrows_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(arrows_caption)
	_arrows = Label.new()
	_arrows.theme_type_variation = "Heading"
	_arrows.add_theme_font_size_override("font_size", 52)
	_arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_arrows)
	_moves_bar = ProgressPill.new(10)
	box.add_child(_moves_bar)
	return card


func _build_overlay() -> void:
	# A full-screen dimmer absorbs taps so the board cannot be played behind a panel.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)
	_confetti = Confetti.new()
	_overlay.add_child(_confetti)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pad.add_child(box)
	_overlay_title = Label.new()
	_overlay_title.theme_type_variation = "Heading"
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_overlay_title)
	_overlay_stars = StarRow.new()
	_overlay_stars.custom_minimum_size = Vector2(0, 76)
	box.add_child(_overlay_stars)
	_overlay_detail = Label.new()
	_overlay_detail.theme_type_variation = "Muted"
	_overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_detail.add_theme_font_size_override("font_size", 19)
	box.add_child(_overlay_detail)
	_overlay_primary = _panel_button(box)
	_overlay_extra = _panel_button(box)
	_overlay_secondary = _panel_button(box)


func _panel_button(parent: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 60)
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _load_level() -> void:
	var level: Dictionary = _levels[_index]
	controller = GameController.new()
	controller.completed.connect(_on_completed)
	controller.lost.connect(_on_lost)
	controller.arrow_removed.connect(func(_id: int, _info: Dictionary) -> void: _sfx("tap_clear"))
	controller.move_blocked.connect(func(_id: int, _blocker: int) -> void: _sfx("tap_blocked"))
	if not controller.start(level["board"], level["moves_limit"]):
		_note.text = "This level is misconfigured."
		return
	board_view.bind(controller)
	var world := Progress.world_of(level["id"])
	_title.text = "%d  %s" % [level["id"], level["name"]]
	_world_caption.text = "WORLD %d  %s" % [world + 1, Palette.world_name(world).to_upper()]
	_world_caption.add_theme_color_override("font_color", Palette.world_color(world))
	_hide_overlay()
	_refresh()


func _refresh() -> void:
	var left := maxi(0, controller.moves_left())
	_moves.text = str(left)
	_arrows.text = str(controller.board.remaining_count())
	_coins.text = str(_progress.coins)
	var ratio := float(left) / maxf(1.0, controller.moves_limit)
	_moves_bar.ratio = ratio
	var tint := Palette.MINT
	if ratio <= LOW_MOVES_RATIO:
		tint = Palette.RED
	elif ratio <= MID_MOVES_RATIO:
		tint = Palette.GOLD
	_moves_bar.color = tint
	_moves.add_theme_color_override("font_color", tint if ratio <= LOW_MOVES_RATIO else Palette.TEXT)
	_undo_button.disabled = not controller.can_undo() or not _progress.can_afford(Economy.PRICE_UNDO)
	_hint_button.disabled = controller.state != GameController.State.PLAYING \
		or not _progress.can_afford(Economy.PRICE_HINT)
	board_view.queue_redraw()


func _hide_overlay() -> void:
	_overlay_kind = ""
	_overlay.visible = false


func _show_overlay(kind: String) -> void:
	_overlay_kind = kind
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, OVERLAY_FADE_SECONDS)


func _on_completed(moves: int) -> void:
	var level: Dictionary = _levels[_index]
	var result := _progress.record_result(
		level["id"], level["board"].remaining_count(), level["moves_limit"], moves, controller.wasted_taps)
	var detail := "%d moves  -  %d wasted" % [moves, controller.wasted_taps]
	var stars := 0
	var coins_earned := 0
	if not result.is_empty():
		stars = result["stars"]
		coins_earned = result["coins_earned"]
		detail += "\n+%d coins" % coins_earned
		if result["world_bonus"] > 0:
			detail += "  (includes world bonus)"
		for badge in result["new_badges"]:
			detail += "\nNew badge: %s" % BADGE_NAMES.get(badge, badge)
	if not _save.save_data():
		detail += "\nProgress could not be saved"
	_overlay_title.text = "Level cleared!"
	_overlay_stars.visible = true
	_overlay_stars.animate_to(stars, STAR_START_DELAY, STAR_STEP)
	_overlay_detail.text = detail
	_set_button(_overlay_primary, "Next" if _next_index() != -1 else "Menu", press_next, true)
	_set_button(_overlay_extra, "Replay", restart)
	_set_button(_overlay_secondary, "Menu", func() -> void: menu_requested.emit())
	_show_overlay("won")
	_confetti.burst()
	_play_win_sounds(stars, coins_earned)
	_refresh()


func _on_lost(wasted: int) -> void:
	_overlay_title.text = "Out of moves"
	_overlay_stars.visible = false
	_overlay_detail.text = "%d arrows left  -  %d wasted taps" % [controller.board.remaining_count(), wasted]
	_set_button(_overlay_primary, "Retry", restart, true)
	var can_continue := controller.extra_moves_granted == 0
	_set_button(_overlay_extra, "+%d moves  (%d coins)" % [Economy.EXTRA_MOVES, Economy.PRICE_EXTRA_MOVES], use_extra_moves)
	_overlay_extra.visible = can_continue
	_overlay_extra.disabled = not _progress.can_afford(Economy.PRICE_EXTRA_MOVES)
	_set_button(_overlay_secondary, "Menu", func() -> void: menu_requested.emit())
	_show_overlay("lost")
	_sfx("lose")
	_refresh()


func _sfx(sound_name: String) -> void:
	if _audio != null:
		_audio.play(sound_name)


## Fanfare, then one rising ding per star, then the coin sound if coins were paid.
func _play_win_sounds(stars: int, coins_earned: int) -> void:
	if _audio == null:
		return
	_audio.play("win")
	var at := STAR_START_DELAY
	for i in stars:
		_audio.play_later("star%d" % (i + 1), at)
		at += STAR_STEP
	if coins_earned > 0:
		_audio.play_later("coin", at + 0.1)


## Replaces the handler and look of a panel button (the same three buttons
## serve both panels).
func _set_button(button: Button, text: String, handler: Callable, primary: bool = false) -> void:
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])
	button.text = text
	button.theme_type_variation = "PrimaryButton" if primary else ""
	button.visible = true
	button.disabled = false
	button.pressed.connect(handler)
