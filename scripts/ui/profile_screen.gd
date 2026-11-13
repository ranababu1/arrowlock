class_name ProfileScreen
extends Control
## The player's profile: who they are (Play Games name and picture when signed
## in, otherwise a local nickname and a built-in avatar), stats for the mode
## being played, the online leaderboard and every badge (earned or how to earn
## it). Presentation only.
##
## Play Games exists only in the Android build. Where it is not set up (iOS,
## desktop) the screen never mentions it: no sign-in button, no leaderboard
## card. The App Store rejects apps that refer to other platforms.

signal back_requested

const AVATAR_SIZE := 96.0
const PICKER_AVATAR_SIZE := 56.0

## Profile card (tests read these).
var avatar: AvatarView
var name_label: Label
var source_label: Label
var edit_button: Button
var sign_in_button: Button
## Local profile editor (hidden until Edit is pressed).
var editor: VBoxContainer
var name_edit: LineEdit
var avatar_buttons: Array[Button] = []
var save_button: Button

## Note under the editor: where the profile is kept.
var editor_note: Label

## The whole leaderboard card; hidden where Play Games is not set up.
var leaderboard_card: Control
var leaderboard_button: Button
var leaderboard_caption: Label
## Badge id -> the row shown for it (tests read these).
var badge_rows: Dictionary = {}
var stat_labels: Dictionary = {}

var _progress: Progress
var _save: SaveService
var _play_games: PlayGames
var _level_count := 100
var _picked_avatar := 0


func setup(progress: Progress, play_games: PlayGames = null, level_count: int = 100, save: SaveService = null) -> void:
	_progress = progress
	_play_games = play_games
	_level_count = level_count
	_save = save
	_build()
	if _play_games != null:
		_play_games.auth_changed.connect(_on_auth_changed)
		_play_games.player_changed.connect(_on_auth_changed.bind(true))
	_refresh_profile()
	_refresh_leaderboard()


## True while the Play Games profile is what the card shows.
func shows_play_games_profile() -> bool:
	return _play_games != null and _play_games.signed_in


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	var back := IconButton.new("back", 52)
	back.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back)
	var title := Label.new()
	title.text = "Profile"
	title.theme_type_variation = "Heading"
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	body.add_child(_profile_card())
	body.add_child(_stats_card())
	body.add_child(_leaderboard_card())
	body.add_child(_badges_card())


func _card(heading: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	if heading != "":
		var label := Label.new()
		label.text = heading
		label.theme_type_variation = "Subheading"
		box.add_child(label)
	return box


func _button(text: String, primary: bool, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "PrimaryButton" if primary else ""
	b.custom_minimum_size = Vector2(0, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(handler)
	return b


func _profile_card() -> Control:
	var box := _card("")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	avatar = AvatarView.new(_progress.profile_avatar, AVATAR_SIZE)
	row.add_child(avatar)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	name_label = Label.new()
	name_label.theme_type_variation = "Heading"
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(name_label)
	source_label = Label.new()
	source_label.theme_type_variation = "Caption"
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(source_label)

	edit_button = _button("Edit name and avatar", false, _open_editor)
	box.add_child(edit_button)
	sign_in_button = _button("Sign in with Play Games", true, func() -> void:
		if _play_games != null:
			_play_games.sign_in())
	box.add_child(sign_in_button)
	box.add_child(_editor())
	return box.get_parent()


func _editor() -> Control:
	editor = VBoxContainer.new()
	editor.add_theme_constant_override("separation", 10)
	editor.visible = false
	var label := Label.new()
	label.text = "Name"
	label.theme_type_variation = "Muted"
	editor.add_child(label)
	name_edit = LineEdit.new()
	name_edit.max_length = Progress.NAME_MAX_LENGTH
	name_edit.placeholder_text = "Player"
	name_edit.custom_minimum_size = Vector2(0, 56)
	name_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	name_edit.text_submitted.connect(func(_t: String) -> void: _save_profile())
	editor.add_child(name_edit)
	var pick := Label.new()
	pick.text = "Avatar"
	pick.theme_type_variation = "Muted"
	editor.add_child(pick)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	editor.add_child(grid)
	avatar_buttons.clear()
	for i in AvatarView.CHOICES.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(PICKER_AVATAR_SIZE + 8, PICKER_AVATAR_SIZE + 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var view := AvatarView.new(i, PICKER_AVATAR_SIZE)
		view.size = view.custom_minimum_size
		view.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
		b.add_child(view)
		b.pressed.connect(func() -> void: _pick_avatar(i))
		grid.add_child(b)
		avatar_buttons.append(b)
	editor_note = Label.new()
	editor_note.text = "Saved on this phone only."
	if _has_play_games():
		editor_note.text += " Sign in with Play Games to use your Play Games name and picture on the leaderboard."
	editor_note.theme_type_variation = "Caption"
	editor_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(editor_note)
	save_button = _button("Save", true, _save_profile)
	editor.add_child(save_button)
	editor.add_child(_button("Cancel", false, func() -> void:
		editor.visible = false
		_refresh_profile()))
	return editor


func _open_editor() -> void:
	name_edit.text = _progress.profile_name
	_pick_avatar(_progress.profile_avatar)
	editor.visible = true
	edit_button.visible = false


func _pick_avatar(index: int) -> void:
	_picked_avatar = index
	for i in avatar_buttons.size():
		(avatar_buttons[i].get_child(0) as AvatarView).selected = i == index


func _save_profile() -> void:
	_progress.profile_name = Progress.clean_name(name_edit.text)
	_progress.profile_avatar = _picked_avatar
	if _save != null and not _save.save_data():
		source_label.text = "Could not save your profile."
		return
	editor.visible = false
	_refresh_profile()


func _refresh_profile() -> void:
	if shows_play_games_profile():
		var gamer := _play_games.player_name
		name_label.text = gamer if gamer != "" else "Signed in"
		avatar.picture = _play_games.player_picture
		avatar.choice = _progress.profile_avatar
		source_label.text = "Google Play Games profile. Change your name and picture in the Play Games app."
		edit_button.visible = false
		sign_in_button.visible = false
		editor.visible = false
	else:
		name_label.text = _progress.display_name()
		avatar.picture = null
		avatar.choice = _progress.profile_avatar
		source_label.text = "Profile on this phone."
		edit_button.visible = not editor.visible
		sign_in_button.visible = _has_play_games()


func _stats_card() -> Control:
	var box := _card("%s mode" % Difficulty.name_of(_progress.difficulty))
	var s := _progress.stats(_progress.difficulty)
	var worlds := ceili(float(_level_count) / Economy.LEVELS_PER_WORLD)
	for row in [
		["points", "Score", str(s["points"])],
		["cleared", "Levels cleared", "%d / %d" % [s["cleared"], _level_count]],
		["stars", "Stars", "%d / %d" % [s["stars"], _level_count * Economy.MAX_STARS]],
		["perfect", "Perfect levels", str(s["perfect"])],
		["worlds", "Worlds complete", "%d / %d" % [s["worlds_complete"], worlds]],
		["coins", "Coins", str(_progress.coins)],
		["badges", "Badges", "%d / %d" % [_progress.badges.size(), Progress.BADGES.size()]],
	]:
		var line := HBoxContainer.new()
		box.add_child(line)
		var label := Label.new()
		label.text = row[1]
		label.theme_type_variation = "Muted"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var value := Label.new()
		value.text = row[2]
		value.theme_type_variation = "Subheading"
		line.add_child(value)
		stat_labels[row[0]] = value
	return box.get_parent()


func _leaderboard_card() -> Control:
	var box := _card("Leaderboard")
	leaderboard_caption = Label.new()
	leaderboard_caption.theme_type_variation = "Caption"
	leaderboard_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(leaderboard_caption)
	leaderboard_button = Button.new()
	leaderboard_button.theme_type_variation = "PrimaryButton"
	leaderboard_button.custom_minimum_size = Vector2(0, 56)
	leaderboard_button.focus_mode = Control.FOCUS_NONE
	leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	box.add_child(leaderboard_button)
	leaderboard_card = box.get_parent()
	return leaderboard_card


func _badges_card() -> Control:
	var box := _card("Badges  %d / %d" % [_progress.badges.size(), Progress.BADGES.size()])
	for badge in Progress.BADGES:
		var earned := _progress.badges.has(badge)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size = Vector2(0, 56)
		box.add_child(row)
		var icon := GlyphView.new("check" if earned else "lock", Palette.GOLD if earned else Palette.MUTED, 26)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var title := Label.new()
		title.text = Progress.badge_title(badge)
		title.theme_type_variation = "Subheading" if earned else "Muted"
		text.add_child(title)
		var hint := Label.new()
		hint.text = ("Earned. " if earned else "") + Progress.badge_hint(badge)
		hint.theme_type_variation = "Caption"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(hint)
		badge_rows[badge] = row
	return box.get_parent()


func _refresh_leaderboard() -> void:
	var tier := _progress.difficulty
	leaderboard_card.visible = _has_play_games()
	if _play_games == null or not _play_games.available(tier):
		leaderboard_caption.text = "The online leaderboard is not available for this mode."
		leaderboard_button.text = "Leaderboard unavailable"
		leaderboard_button.disabled = true
	elif not _play_games.signed_in:
		leaderboard_caption.text = "Optional. Sign in with Google Play Games to post your score. The game works the same without it."
		leaderboard_button.text = "Sign in with Play Games"
		leaderboard_button.disabled = false
	else:
		var shown_as := " You appear as %s." % _play_games.player_name if _play_games.player_name != "" else ""
		leaderboard_caption.text = "Your %s score is posted automatically. Each level counts its best clear: 100 points per star plus a speed bonus.%s" % [Difficulty.name_of(tier), shown_as]
		leaderboard_button.text = "Show leaderboard"
		leaderboard_button.disabled = false


## True when this build has Play Games set up, so it may be offered and named.
func _has_play_games() -> bool:
	return _play_games != null and _play_games.is_configured()


func _on_auth_changed(_signed_in: bool) -> void:
	_refresh_profile()
	_refresh_leaderboard()


func _on_leaderboard_pressed() -> void:
	if _play_games == null:
		return
	if _play_games.signed_in:
		_play_games.sync(_progress.difficulty)
		_play_games.show_leaderboard(_progress.difficulty)
	else:
		_play_games.sign_in()
