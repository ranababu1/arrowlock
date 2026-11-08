class_name LevelSelect
extends Control
## Home screen: header, stat chips, a Continue button and one card per world.
## Presentation only.

signal level_chosen(index: int)
signal settings_requested
signal profile_requested

const COLUMNS := 5
## Pixels of vertical movement before a press becomes a scroll drag.
const DRAG_THRESHOLD := 12.0

var _repo: PuzzleRepository
var _progress: Progress
var _level_buttons: Array[Button] = []
var mode_label: Label
var _scroll: ScrollContainer
var _tracking := false
var _dragging := false
var _drag_origin := Vector2.ZERO
## True from a drag's release until the end of that frame, so the button under
## the finger does not also register a tap.
var _suppress_press := false


## `focus_index` is the level (index into repo.levels) to scroll into view; it
## is also the level the Continue button opens.
func setup(repo: PuzzleRepository, progress: Progress, focus_index: int = -1) -> void:
	_repo = repo
	_progress = progress
	_build(focus_index)
	if focus_index >= 0 and focus_index < _level_buttons.size():
		_focus_when_laid_out.call_deferred(_level_buttons[focus_index])


## Layout sizes are only known a frame after the tree is built.
func _focus_when_laid_out(button: Button) -> void:
	await get_tree().process_frame
	if is_instance_valid(button) and is_instance_valid(_scroll):
		_scroll.ensure_control_visible(button)


## Buttons swallow the touch, so the ScrollContainer never sees a drag that
## starts on one. Track drags here instead and scroll it ourselves.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tracking = true
			_dragging = false
			_drag_origin = event.position
		else:
			if _dragging:
				_suppress_press = true
				_clear_suppress.call_deferred()
			_tracking = false
			_dragging = false
	elif event is InputEventMouseMotion and _tracking:
		if not _dragging and absf(event.position.y - _drag_origin.y) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_scroll.scroll_vertical -= roundi(event.relative.y)
			get_viewport().set_input_as_handled()


func _clear_suppress() -> void:
	_suppress_press = false


func is_dragging() -> bool:
	return _dragging


func scroll_position() -> int:
	return _scroll.scroll_vertical


func level_button_count() -> int:
	return _level_buttons.size()


func enabled_level_count() -> int:
	var count := 0
	for b in _level_buttons:
		if not b.disabled:
			count += 1
	return count


func press_level(index: int) -> void:
	if index >= 0 and index < _level_buttons.size() and not _level_buttons[index].disabled:
		level_chosen.emit(index)


func _build(focus_index: int) -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	root.add_child(_header())
	root.add_child(_chips())
	root.add_child(_mode_line())
	root.add_child(_continue_button(focus_index))

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	var worlds := VBoxContainer.new()
	worlds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	worlds.add_theme_constant_override("separation", 14)
	_scroll.add_child(worlds)
	var world_count := ceili(float(_repo.levels.size()) / Economy.LEVELS_PER_WORLD)
	for w in world_count:
		worlds.add_child(_world_card(w, focus_index))


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var logo := PanelContainer.new()
	logo.theme_type_variation = "Card"
	logo.custom_minimum_size = Vector2(52, 52)
	logo.add_child(GlyphView.new("arrow", Palette.CYAN, 30))
	logo.get_child(0).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.get_child(0).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var title := Label.new()
	title.text = "Arrowlock"
	title.theme_type_variation = "Heading"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var profile := IconButton.new("person", 52)
	profile.pressed.connect(func() -> void: profile_requested.emit())
	row.add_child(profile)
	var gear := IconButton.new("gear", 52)
	gear.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(gear)
	return row


func _chips() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_chip("star", Palette.GOLD, "%d / %d" % [_progress.total_stars(_progress.difficulty), _repo.levels.size() * Economy.MAX_STARS]))
	row.add_child(_chip("coin", Palette.GOLD, str(_progress.coins)))
	return row


## The tier being played and its rules. It is changed in Settings.
func _mode_line() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	mode_label = Label.new()
	mode_label.text = "%s mode" % Difficulty.name_of(_progress.difficulty)
	mode_label.theme_type_variation = "Subheading"
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _progress.difficulty == Difficulty.DIFFICULT:
		mode_label.add_theme_color_override("font_color", Palette.RED)
	box.add_child(mode_label)
	var rules := Label.new()
	rules.text = Difficulty.rule_text(_progress.difficulty)
	rules.theme_type_variation = "Caption"
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rules)
	return box


func _chip(glyph: String, color: Color, text: String) -> Control:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "Card"
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	chip.add_child(box)
	var icon := GlyphView.new(glyph, color, 26)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "Subheading"
	box.add_child(label)
	return chip


func _continue_button(focus_index: int) -> Control:
	var button := Button.new()
	button.theme_type_variation = "PrimaryButton"
	button.custom_minimum_size = Vector2(0, 64)
	button.focus_mode = Control.FOCUS_NONE
	var index := focus_index if focus_index >= 0 else 0
	var level_id: int = _repo.levels[index]["id"] if not _repo.levels.is_empty() else 1
	button.text = ("Play  Level %d" if not _progress.is_cleared(level_id) else "Replay  Level %d") % Difficulty.local_id(level_id)
	button.pressed.connect(func() -> void:
		if not _suppress_press:
			level_chosen.emit(index))
	return button


func _world_card(world: int, focus_index: int) -> Control:
	var unlocked := _progress.is_world_unlocked(world, _progress.difficulty)
	var accent := Palette.world_color(world)
	var first := world * Economy.LEVELS_PER_WORLD
	var last := mini(first + Economy.LEVELS_PER_WORLD, _repo.levels.size())
	var cleared := _progress.world_clears(world, _progress.difficulty)
	var stars := 0
	for index in range(first, last):
		stars += _progress.stars_of(_repo.levels[index]["id"])

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var bar := ColorRect.new()
	bar.color = accent if unlocked else Color(1, 1, 1, 0.15)
	bar.custom_minimum_size = Vector2(6, 0)
	head.add_child(bar)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	head.add_child(text)
	var title := Label.new()
	title.text = "World %d  %s" % [world + 1, Palette.world_name(world)]
	title.theme_type_variation = "Subheading"
	title.modulate.a = 1.0 if unlocked else 0.55
	text.add_child(title)
	var caption := Label.new()
	caption.theme_type_variation = "Caption"
	if unlocked:
		caption.text = "%d / %d cleared   %d / %d stars" % [cleared, last - first, stars, (last - first) * Economy.MAX_STARS]
	else:
		caption.text = "Clear %d of %d in World %d to unlock" % [Economy.WORLD_UNLOCK_CLEARS, Economy.LEVELS_PER_WORLD, world]
	text.add_child(caption)
	if not unlocked:
		head.add_child(GlyphView.new("lock", Color(1, 1, 1, 0.45), 28))

	var pill := ProgressPill.new(6)
	pill.color = accent
	pill.ratio = float(cleared) / maxf(1.0, last - first)
	box.add_child(pill)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for index in range(first, last):
		var level_id: int = _repo.levels[index]["id"]
		var state := LevelTile.State.LOCKED
		if unlocked:
			state = LevelTile.State.OPEN
			if _progress.is_cleared(level_id):
				state = LevelTile.State.CLEARED
			if index == focus_index and not _progress.is_cleared(level_id):
				state = LevelTile.State.CURRENT
		var tile := LevelTile.new(level_id, accent, state, _progress.stars_of(level_id))
		tile.pressed.connect(func() -> void:
			if not _suppress_press:
				level_chosen.emit(index))
		_level_buttons.append(tile)
		grid.add_child(tile)
	return card
