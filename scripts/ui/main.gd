extends Control
## Root screen: wires services, controller and board view. Presentation only.

const LEVELS_PATH := "res://data/levels.json"
const MIN_TOUCH_HEIGHT := 64.0

var _repo := PuzzleRepository.new()
var _save := SaveService.new()
var _controller := GameController.new()
var _level_index := 0

var _title: Label
var _status: Label
var _board_view: BoardView
var _undo_button: Button
var _next_button: Button


func _ready() -> void:
	_save.load_data()
	if not _repo.load_file(LEVELS_PATH):
		push_error("Level load failed: %s" % "; ".join(_repo.errors))
	_build_ui()
	if _repo.levels.is_empty():
		_status.text = "No playable levels found."
		return
	_start_level(_first_incomplete_index())


func _first_incomplete_index() -> int:
	for i in _repo.levels.size():
		if not _save.is_completed(_repo.levels[i]["id"]):
			return i
	return 0


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	column.add_child(_title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	column.add_child(_status)

	_board_view = BoardView.new()
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view.cell_tapped.connect(_on_cell_tapped)
	column.add_child(_board_view)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_undo_button = _make_button("Undo", buttons, _on_undo)
	_make_button("Restart", buttons, _on_restart)
	_next_button = _make_button("Next", buttons, _on_next)
	_next_button.disabled = true


func _make_button(text: String, parent: Control, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, MIN_TOUCH_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _start_level(index: int) -> void:
	_level_index = index
	var level: Dictionary = _repo.levels[index]
	_controller = GameController.new()
	_controller.completed.connect(_on_completed)
	_controller.lost.connect(_on_lost)
	if not _controller.start(level["board"], level["moves_limit"]):
		_status.text = "This level is misconfigured."
		return
	_board_view.bind(_controller)
	_title.text = "%d. %s" % [level["id"], level["name"]]
	_next_button.disabled = true
	_refresh_status()


func _refresh_status() -> void:
	if not _controller.is_over():
		_status.text = "Moves left: %d   Arrows: %d" % [_controller.moves_left(), _controller.board.remaining_count()]
	_undo_button.disabled = not _controller.can_undo()


func _on_cell_tapped(cell: Vector2i) -> void:
	_controller.tap(cell)
	_refresh_status()
	_board_view.queue_redraw()


func _on_undo() -> void:
	_controller.undo()
	_refresh_status()
	_board_view.queue_redraw()


func _on_restart() -> void:
	_controller.restart()
	_board_view.clear_animations()
	_next_button.disabled = true
	_refresh_status()


func _on_next() -> void:
	_start_level((_level_index + 1) % _repo.levels.size())


func _on_lost(_wasted: int) -> void:
	_status.text = "Out of moves! Tap Restart."
	_undo_button.disabled = true


func _on_completed(moves: int) -> void:
	_status.text = "Cleared in %d moves!" % moves
	_save.record_completion(_repo.levels[_level_index]["id"], moves)
	if not _save.save_data():
		_status.text += " (progress could not be saved)"
	_next_button.disabled = false
	_undo_button.disabled = true
