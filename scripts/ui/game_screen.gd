class_name GameScreen
extends Control
## One level in play: HUD, board, helpers and the win / game-over panels.
## Rules live in GameController and Progress; this class only presents them.

signal menu_requested
signal next_requested(index: int)

const MIN_TOUCH_HEIGHT := 64.0
const BADGE_NAMES := {
	"first_clear": "First clear",
	"clears_10": "10 levels cleared",
	"clears_50": "50 levels cleared",
	"clears_100": "All 100 levels cleared",
	"perfect_clear": "Perfect level",
	"world_perfect": "Perfect world",
}

var controller := GameController.new()
var board_view: BoardView

var _levels: Array[Dictionary]
var _index: int
var _progress: Progress
var _save: SaveService
var _audio: AudioManager  ## optional; null in tests that do not need sound

var _title: Label
var _coins: Label
var _status: Label
var _note: Label
var _undo_button: Button
var _hint_button: Button
var _overlay: Control
var _overlay_title: Label
var _overlay_stars: StarRow
var _overlay_detail: Label
var _overlay_primary: Button
var _overlay_extra: Button
var _overlay_secondary: Button
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
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var menu := Button.new()
	menu.text = "Menu"
	menu.custom_minimum_size = Vector2(110, 52)
	menu.pressed.connect(func() -> void: menu_requested.emit())
	top.add_child(menu)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	top.add_child(_title)
	_coins = Label.new()
	_coins.custom_minimum_size = Vector2(110, 0)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins.add_theme_font_size_override("font_size", 20)
	top.add_child(_coins)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 26)
	root.add_child(_status)
	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_size_override("font_size", 18)
	_note.custom_minimum_size = Vector2(0, 24)
	root.add_child(_note)

	board_view = BoardView.new()
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.cell_tapped.connect(tap_cell)
	root.add_child(board_view)

	var helpers := HBoxContainer.new()
	helpers.add_theme_constant_override("separation", 10)
	root.add_child(helpers)
	_undo_button = _make_button("Undo %d" % Economy.PRICE_UNDO, helpers, use_undo)
	_hint_button = _make_button("Hint %d" % Economy.PRICE_HINT, helpers, use_hint)
	_make_button("Restart", helpers, restart)
	_build_overlay()


func _make_button(text: String, parent: Control, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, MIN_TOUCH_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if handler.is_valid():
		b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _build_overlay() -> void:
	# A full-screen dimmer absorbs taps so the board cannot be played behind a panel.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pad.add_child(box)
	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_overlay_title)
	_overlay_stars = StarRow.new()
	_overlay_stars.custom_minimum_size = Vector2(0, 56)
	box.add_child(_overlay_stars)
	_overlay_detail = Label.new()
	_overlay_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_detail.add_theme_font_size_override("font_size", 20)
	box.add_child(_overlay_detail)
	_overlay_primary = _make_button("", box, Callable())
	_overlay_extra = _make_button("", box, use_extra_moves)
	_overlay_secondary = _make_button("", box, func() -> void: menu_requested.emit())


func _load_level() -> void:
	var level: Dictionary = _levels[_index]
	controller = GameController.new()
	controller.completed.connect(_on_completed)
	controller.lost.connect(_on_lost)
	controller.arrow_removed.connect(func(_id: int, _info: Dictionary) -> void: _sfx("tap_clear"))
	controller.move_blocked.connect(func(_id: int, _blocker: int) -> void: _sfx("tap_blocked"))
	if not controller.start(level["board"], level["moves_limit"]):
		_status.text = "This level is misconfigured."
		return
	board_view.bind(controller)
	_title.text = "%d. %s" % [level["id"], level["name"]]
	_hide_overlay()
	_refresh()


func _refresh() -> void:
	if not controller.is_over():
		_status.text = "Moves left: %d   Arrows: %d" % [controller.moves_left(), controller.board.remaining_count()]
	_coins.text = "Coins %d" % _progress.coins
	_undo_button.disabled = not controller.can_undo() or not _progress.can_afford(Economy.PRICE_UNDO)
	_hint_button.disabled = controller.state != GameController.State.PLAYING \
		or not _progress.can_afford(Economy.PRICE_HINT)
	board_view.queue_redraw()


func _hide_overlay() -> void:
	_overlay_kind = ""
	_overlay.visible = false


func _show_overlay(kind: String) -> void:
	_overlay_kind = kind
	_overlay.visible = true


func _on_completed(moves: int) -> void:
	var level: Dictionary = _levels[_index]
	var result := _progress.record_result(
		level["id"], level["board"].remaining_count(), level["moves_limit"], moves, controller.wasted_taps)
	var detail := "%d moves, %d wasted" % [moves, controller.wasted_taps]
	var stars := 0
	if not result.is_empty():
		stars = result["stars"]
		detail += "\n+%d coins" % result["coins_earned"]
		if result["world_bonus"] > 0:
			detail += " (includes world bonus)"
		for badge in result["new_badges"]:
			detail += "\nNew badge: %s" % BADGE_NAMES.get(badge, badge)
	if not _save.save_data():
		detail += "\nProgress could not be saved"
	_overlay_title.text = "Level cleared!"
	_overlay_stars.set_stars(stars)
	_overlay_stars.visible = true
	_overlay_detail.text = detail
	_set_button(_overlay_primary, "Next" if _next_index() != -1 else "Menu", press_next)
	_set_button(_overlay_extra, "Replay", restart)
	_set_button(_overlay_secondary, "Menu", func() -> void: menu_requested.emit())
	_show_overlay("won")
	_play_win_sounds(stars, result.get("coins_earned", 0))
	_refresh()


func _on_lost(wasted: int) -> void:
	_overlay_title.text = "Out of moves"
	_overlay_stars.visible = false
	_overlay_detail.text = "%d arrows left, %d wasted taps" % [controller.board.remaining_count(), wasted]
	_set_button(_overlay_primary, "Retry", restart)
	var can_continue := controller.extra_moves_granted == 0
	_set_button(_overlay_extra, "+%d moves (%d coins)" % [Economy.EXTRA_MOVES, Economy.PRICE_EXTRA_MOVES], use_extra_moves)
	_overlay_extra.visible = can_continue
	_overlay_extra.disabled = not _progress.can_afford(Economy.PRICE_EXTRA_MOVES)
	_set_button(_overlay_secondary, "Menu", func() -> void: menu_requested.emit())
	_show_overlay("lost")
	_sfx("lose")
	_status.text = "Out of moves!"
	_refresh()


func _sfx(sound_name: String) -> void:
	if _audio != null:
		_audio.play(sound_name)


## Fanfare, then one rising ding per star, then the coin sound if coins were paid.
func _play_win_sounds(stars: int, coins_earned: int) -> void:
	if _audio == null:
		return
	_audio.play("win")
	var at := 0.6
	for i in stars:
		_audio.play_later("star%d" % (i + 1), at)
		at += 0.3
	if coins_earned > 0:
		_audio.play_later("coin", at + 0.1)


## Replaces the handler of a panel button (the same three buttons serve both panels).
func _set_button(button: Button, text: String, handler: Callable) -> void:
	for connection in button.pressed.get_connections():
		button.pressed.disconnect(connection["callable"])
	button.text = text
	button.visible = true
	button.disabled = false
	button.pressed.connect(handler)
