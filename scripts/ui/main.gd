extends Control
## Root: owns the services and switches between the level-select and game
## screens. Presentation only.

const PACK_DIR := "res://data/packs"
const MIN_MARGIN := 16.0
const FADE_SECONDS := 0.2

var _repo := PuzzleRepository.new()
var _save := SaveService.new()
var _host: MarginContainer
var _current: Control
var _last_index := -1
var _audio := AudioManager.new()
var _backdrop: Backdrop


func _ready() -> void:
	theme = AppTheme.build()
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	# Android back goes to the menu from a level instead of quitting the app.
	get_tree().set_auto_accept_quit(false)
	_save.load_data()
	add_child(_audio)
	_audio.apply_progress(_save.progress)
	_audio.start_music()
	# Every button, present and future, gets the click sound.
	get_tree().node_added.connect(_on_node_added)
	_host = MarginContainer.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	if not _repo.load_dir(PACK_DIR):
		push_error("Level load failed: %s" % "; ".join(_repo.errors))
	if _repo.levels.is_empty():
		var message := Label.new()
		message.text = "No playable levels found."
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_host.add_child(message)
		return
	_show_select()


## Keeps content clear of notches and system bars. On desktop the safe area is
## the whole screen, so the margins fall back to MIN_MARGIN.
func _apply_safe_area() -> void:
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	var view := get_viewport_rect().size
	var ratio := Vector2(view.x / maxf(screen.x, 1.0), view.y / maxf(screen.y, 1.0))
	var left := maxf(MIN_MARGIN, safe.position.x * ratio.x)
	var top := maxf(MIN_MARGIN, safe.position.y * ratio.y)
	var right := maxf(MIN_MARGIN, (screen.x - safe.end.x) * ratio.x)
	var bottom := maxf(MIN_MARGIN, (screen.y - safe.end.y) * ratio.y)
	_host.add_theme_constant_override("margin_left", roundi(left))
	_host.add_theme_constant_override("margin_top", roundi(top))
	_host.add_theme_constant_override("margin_right", roundi(right))
	_host.add_theme_constant_override("margin_bottom", roundi(bottom))


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func() -> void: _audio.play("click"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _current is GameScreen or _current is SettingsScreen:
			_show_select()
		else:
			get_tree().quit()


func _swap(screen: Control) -> void:
	if _current != null:
		_host.remove_child(_current)
		_current.queue_free()
	_current = screen
	# Decorative arrows would look like puzzle arrows behind the board, so they
	# only drift on menu screens.
	_backdrop.show_arrows = not (screen is GameScreen)
	_host.add_child(screen)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, FADE_SECONDS)


func _show_select() -> void:
	var select := LevelSelect.new()
	_swap(select)
	select.setup(_repo, _save.progress, _last_index if _last_index >= 0 else _first_uncleared_index())
	select.level_chosen.connect(_start_level)
	select.settings_requested.connect(_show_settings)


func _show_settings() -> void:
	var settings := SettingsScreen.new()
	_swap(settings)
	settings.setup(_save.progress, _save, _audio)
	settings.back_requested.connect(_show_select)


## First level the player has not cleared yet (the last level if all are done).
func _first_uncleared_index() -> int:
	for i in _repo.levels.size():
		if not _save.progress.is_cleared(_repo.levels[i]["id"]):
			return i
	return _repo.levels.size() - 1


func _start_level(index: int) -> void:
	_last_index = index
	var screen := GameScreen.new()
	_swap(screen)
	screen.setup(_repo.levels, index, _save.progress, _save, _audio)
	screen.menu_requested.connect(_show_select)
	screen.next_requested.connect(_start_level)
