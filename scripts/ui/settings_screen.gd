class_name SettingsScreen
extends Control
## Music and sound-effect toggles, plus credits. Changes apply and save at once.

signal back_requested

const VERSION_SETTING := "application/config/version"

var music_toggle: ToggleSwitch
var sfx_toggle: ToggleSwitch

var _progress: Progress
var _save: SaveService
var _audio: AudioManager


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

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	root.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	card.add_child(rows)
	music_toggle = _row(rows, "note", Palette.CYAN, "Music", "Calm background loop", _progress.music_enabled, _on_music_toggled)
	rows.add_child(HSeparator.new())
	sfx_toggle = _row(rows, "speaker", Palette.MINT, "Sound effects", "Taps, hints and rewards", _progress.sound_enabled, _on_sfx_toggled)

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


func _apply_and_save() -> void:
	_audio.apply_settings(_progress.music_enabled, _progress.sound_enabled)
	_save.save_data()
