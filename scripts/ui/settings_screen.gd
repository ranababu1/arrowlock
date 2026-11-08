class_name SettingsScreen
extends Control
## Difficulty, music and sound-effect settings, plus credits. Changes apply and
## save at once. Switching difficulty keeps progress in both modes.

signal back_requested
## Fired after the mode in play changed (already saved).
signal difficulty_switched(tier: int)

const VERSION_SETTING := "application/config/version"
## Written by tools/build_android.sh for each build (gitignored); absent in the editor.
const BUILD_INFO_PATH := "res://data/build_info.json"

var music_toggle: ToggleSwitch
var sfx_toggle: ToggleSwitch
var tips_toggle: ToggleSwitch
var haptics_toggle: ToggleSwitch
var music_volume_bar: VolumeBar
var sfx_volume_bar: VolumeBar
## One button per tier, index = Difficulty constant.
var difficulty_buttons: Array[Button] = []

var _progress: Progress
var _save: SaveService
var _audio: AudioManager
var _mode_rules: Label


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
	rows.add_child(HSeparator.new())
	haptics_toggle = _row(rows, "play", Palette.CORAL, "Vibration", "Short buzz on blocked taps, wins and losses", _progress.haptics_enabled, _on_haptics_toggled)

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
		version_text(),
		"Music and sound effects are original, generated for this game.",
		"Font: Poppins, SIL Open Font License 1.1.",
	]:
		var label := Label.new()
		label.text = line
		label.theme_type_variation = "Muted"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about_text.add_child(label)


## "Arrowlock 0.3.0 (build 38)": the version name from project.godot and, in
## exported builds, the build number stamped by the build script.
static func version_text(build_info_path: String = BUILD_INFO_PATH) -> String:
	var text := "Arrowlock %s" % ProjectSettings.get_setting(VERSION_SETTING, "dev")
	if FileAccess.file_exists(build_info_path):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(build_info_path))
		if typeof(info) == TYPE_DICTIONARY and typeof(info.get("build")) in [TYPE_INT, TYPE_FLOAT]:
			text += " (build %d)" % int(info["build"])
	return text


## Switches to `tier` at once (what tapping a tier button does). Nothing is
## lost: each mode keeps its own levels, and coins and badges are shared.
func request_difficulty(tier: int) -> void:
	if _progress.switch_difficulty(tier):
		_save.save_data()
		_refresh_difficulty()
		difficulty_switched.emit(tier)


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
	note.text = "Switch any time. Each mode keeps its own progress; coins and badges are shared."
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


func _on_haptics_toggled(on: bool) -> void:
	_progress.haptics_enabled = on
	_save.save_data()
	Haptics.buzz(_progress, Haptics.WIN_MS)  # so the player feels it is on


func _apply_and_save() -> void:
	_audio.apply_progress(_progress)
	_save.save_data()
