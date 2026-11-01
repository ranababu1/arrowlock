class_name LevelSelect
extends Control
## Home screen: worlds of levels with stars and lock state. Presentation only.

signal level_chosen(index: int)

const COLUMNS := 5
const BUTTON_HEIGHT := 92.0
## Pixels of vertical movement before a press becomes a scroll drag.
const DRAG_THRESHOLD := 12.0

var _repo: PuzzleRepository
var _progress: Progress
var _level_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _tracking := false
var _dragging := false
var _drag_origin := Vector2.ZERO
## True from a drag's release until the end of that frame, so the button under
## the finger does not also register a tap.
var _suppress_press := false


## `focus_index` is the level (index into repo.levels) to scroll into view.
func setup(repo: PuzzleRepository, progress: Progress, focus_index: int = -1) -> void:
	_repo = repo
	_progress = progress
	_build()
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


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = "Arrowlock"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	root.add_child(title)

	var summary := Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 20)
	summary.text = "Stars %d / %d     Coins %d" % [
		_progress.total_stars(), _repo.levels.size() * Economy.MAX_STARS, _progress.coins]
	root.add_child(summary)

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
		_add_world(worlds, w)


func _add_world(parent: VBoxContainer, world: int) -> void:
	var unlocked := _progress.is_world_unlocked(world)
	var header := Label.new()
	header.add_theme_font_size_override("font_size", 22)
	if unlocked:
		header.text = "World %d" % (world + 1)
	else:
		header.text = "World %d - clear %d of %d in World %d to unlock" % [
			world + 1, Economy.WORLD_UNLOCK_CLEARS, Economy.LEVELS_PER_WORLD, world]
		header.modulate = Color(1, 1, 1, 0.55)
	parent.add_child(header)

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var first := world * Economy.LEVELS_PER_WORLD
	for index in range(first, mini(first + Economy.LEVELS_PER_WORLD, _repo.levels.size())):
		var level: Dictionary = _repo.levels[index]
		grid.add_child(_make_button(index, level["id"], unlocked))


func _make_button(index: int, level_id: int, unlocked: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not unlocked
	b.pressed.connect(func() -> void:
		if not _suppress_press:
			level_chosen.emit(index))
	var number := Label.new()
	number.text = str(level_id)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.add_theme_font_size_override("font_size", 26)
	number.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	number.offset_top = 10
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(number)
	var stars := StarRow.new()
	stars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -30
	stars.offset_bottom = -8
	stars.offset_left = 8
	stars.offset_right = -8
	stars.set_stars(_progress.stars_of(level_id))
	b.add_child(stars)
	_level_buttons.append(b)
	return b
