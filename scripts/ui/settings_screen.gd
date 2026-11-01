class_name SettingsScreen
extends Control
## Difficulty, music and sound-effect settings, plus credits. Changes apply and
## save at once, except a difficulty switch, which asks first because it wipes
## progress.

signal back_requested
## Fired after progress was reset for the new tier (already saved).
signal difficulty_switched(tier: int)

const VERSION_SETTING := "application/config/version"

var music_toggle: ToggleSwitch
var sfx_toggle: ToggleSwitch
var tips_toggle: ToggleSwitch
var music_volume_bar: VolumeBar
var sfx_volume_bar: VolumeBar
## One button per tier, index = Difficulty constant.
var difficulty_buttons: Array[Button] = []
var confirm_button: Button
var cancel_button: Button

var _progress: Progress
var _save: SaveService
var _audio: AudioManager
var _mode_rules: Label
var _confirm: Control
var _confirm_text: Label
var _pending_tier := -1


func setup(progress: Progress, save: SaveService, audio: AudioManager) -> void:
	_progress = progress
	_save = save
	_audio = audio
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	var back := IconButton.new("back", 52)
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)
	var title := Label.new()
	title.text = "Settings"
	title.theme_type_variation = "Heading"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)

	root.add_child(_difficulty_card())

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	root.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	card.add_child(rows)
	music_toggle = _row(rows, "note", Palette.CYAN, "Music", "Calm background loop", _progress.music_enabled, _on_music_toggled)
	rows.add_child(HSeparator.new())
	sfx_toggle = _row(rows, "speaker", Palette.MINT, "Sound effects", "Taps, hints and rewards", _progress.sound_enabled, _on_sfx_toggled)
	rows.add_child(HSeparator.new())
	tips_toggle = _row(rows, "bulb", Palette.GOLD, "Tutorial tips", "Short pointers on the first levels", _progress.tips_enabled, _on_tips_toggled)

	var volume_card := PanelContainer.new()
	volume_card.theme_type_variation = "Card"
	root.add_child(volume_card)
	var volume_rows := VBoxContainer.new()
	volume_rows.add_theme_constant_override("separation", 6)
	volume_card.add_child(volume_rows)
	var volume_title := Label.new()
	volume_title.text = "Volume"
	volume_title.theme_type_variation = "Subheading"
	volume_rows.add_child(volume_title)
	music_volume_bar = _volume_row(volume_rows, "Music", _progress.music_volume, _on_music_volume, _on_volume_released)
	sfx_volume_bar = _volume_row(volume_rows, "Effects", _progress.sfx_volume, _on_sfx_volume, _on_sfx_volume_released)

	var about := PanelContainer.new()
	about.theme_type_variation = "Card"
	root.add_child(about)
	var about_text := VBoxContainer.new()
	about_text.add_theme_constant_override("separation", 4)
	about.add_child(about_text)
	var heading := Label.new()
	heading.text = "About"
	heading.theme_type_variation = "Subheading"
	about_text.add_child(heading)
	for line in [
		"Arrowlock %s" % ProjectSettings.get_setting(VERSION_SETTING, "dev"),
		"Music and sound effects are original, generated for this game.",
		"Font: Poppins, SIL Open Font License 1.1.",
	]:
		var label := Label.new()
		label.text = line
		label.theme_type_variation = "Muted"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about_text.add_child(label)
	_build_confirm()


## What a tier switch will do, shown before anything is wiped.
static func warning_text(tier: int) -> String:
	return "Switching to %s mode erases all your stars, coins and badges. %s mode is locked until you switch back, and switching back erases your %s progress too. This cannot be undone." % [
		Difficulty.name_of(tier), Difficulty.name_of(1 - tier), Difficulty.name_of(tier)]


func confirm_visible() -> bool:
	return _confirm.visible


## Asks to switch to `tier` (what tapping a tier button does).
func request_difficulty(tier: int) -> void:
	if tier == _progress.difficulty or tier < 0 or tier >= Difficulty.COUNT:
		return
	_pending_tier = tier
	_confirm_text.text = warning_text(tier)
	_confirm.visible = true


func confirm_switch() -> void:
	if _pending_tier < 0:
		return
	var tier := _pending_tier
	cancel_switch()
	if _progress.switch_difficulty(tier):
		_save.save_data()
		_refresh_difficulty()
		difficulty_switched.emit(tier)


func cancel_switch() -> void:
	_pending_tier = -1
	_confirm.visible = false


func _difficulty_card() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var title := Label.new()
	title.text = "Difficulty"
	title.theme_type_variation = "Subheading"
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	difficulty_buttons.clear()
	for tier in Difficulty.COUNT:
		var button := Button.new()
		button.text = Difficulty.name_of(tier)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: request_difficulty(tier))
		difficulty_buttons.append(button)
		row.add_child(button)
	_mode_rules = Label.new()
	_mode_rules.theme_type_variation = "Caption"
	_mode_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mode_rules)
	var note := Label.new()
	note.text = "You play one mode at a time. Switching erases your progress."
	note.theme_type_variation = "Caption"
	note.add_theme_color_override("font_color", Palette.GOLD)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_refresh_difficulty()
	return card


func _refresh_difficulty() -> void:
	for tier in difficulty_buttons.size():
		var active := tier == _progress.difficulty
		var button := difficulty_buttons[tier]
		button.theme_type_variation = ("DangerButton" if tier == Difficulty.DIFFICULT else "PrimaryButton") if active else ""
		button.text = "%s  (playing)" % Difficulty.name_of(tier) if active else Difficulty.name_of(tier)
	_mode_rules.text = Difficulty.rule_text(_progress.difficulty)


func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.visible = false
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	pad.add_child(box)
	var heading := Label.new()
	heading.text = "Reset your progress?"
	heading.theme_type_variation = "Heading"
	heading.add_theme_font_size_override("font_size", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	_confirm_text = Label.new()
	_confirm_text.theme_type_variation = "Muted"
	_confirm_text.add_theme_font_size_override("font_size", 18)
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_confirm_text)
	confirm_button = Button.new()
	confirm_button.text = "Erase progress and switch"
	confirm_button.theme_type_variation = "DangerButton"
	confirm_button.custom_minimum_size = Vector2(0, 60)
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(confirm_switch)
	box.add_child(confirm_button)
	cancel_button = Button.new()
	cancel_button.text = "Keep my progress"
	cancel_button.theme_type_variation = "PrimaryButton"
	cancel_button.custom_minimum_size = Vector2(0, 60)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(cancel_switch)
	box.add_child(cancel_button)


func _row(parent: Control, glyph: String, color: Color, title: String, caption: String, value: bool, handler: Callable) -> ToggleSwitch:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0, 64)
	parent.add_child(row)
	var icon := GlyphView.new(glyph, color, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = title
	name_label.theme_type_variation = "Subheading"
	text.add_child(name_label)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.theme_type_variation = "Caption"
	text.add_child(caption_label)
	var toggle := ToggleSwitch.new()
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.set_on(value, false)
	toggle.toggled.connect(handler)
	row.add_child(toggle)
	return toggle


func _volume_row(parent: Control, label_text: String, value: float, on_change: Callable, on_release: Callable) -> VolumeBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.theme_type_variation = "Muted"
	label.custom_minimum_size = Vector2(80, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var bar := VolumeBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_value(value)
	bar.changed.connect(on_change)
	bar.released.connect(on_release)
	row.add_child(bar)
	return bar


func _on_music_volume(value: float) -> void:
	_progress.music_volume = value
	_audio.apply_progress(_progress)


func _on_sfx_volume(value: float) -> void:
	_progress.sfx_volume = value
	_audio.apply_progress(_progress)


func _on_volume_released(_value: float) -> void:
	_save.save_data()


func _on_sfx_volume_released(_value: float) -> void:
	_save.save_data()
	_audio.play("tap_clear")  # so the new loudness can be heard


func _on_music_toggled(on: bool) -> void:
	_progress.music_enabled = on
	_apply_and_save()
	if on:
		_audio.start_music()


func _on_sfx_toggled(on: bool) -> void:
	_progress.sound_enabled = on
	_apply_and_save()
	if on:
		_audio.play("tap_clear")  # a short sample so the player hears it is on


func _on_tips_toggled(on: bool) -> void:
	_progress.tips_enabled = on
	_save.save_data()


func _apply_and_save() -> void:
	_audio.apply_progress(_progress)
	_save.save_data()
