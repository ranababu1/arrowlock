class_name TrophiesScreen
extends Control
## Stats for the mode being played, every badge (earned or how to earn it) and
## the online leaderboard button. Presentation only.

signal back_requested

var leaderboard_button: Button
var leaderboard_caption: Label
## Badge id -> the row shown for it (tests read these).
var badge_rows: Dictionary = {}
var stat_labels: Dictionary = {}

var _progress: Progress
var _play_games: PlayGames
var _level_count := 100


func setup(progress: Progress, play_games: PlayGames = null, level_count: int = 100) -> void:
	_progress = progress
	_play_games = play_games
	_level_count = level_count
	_build()
	if _play_games != null:
		_play_games.auth_changed.connect(_on_auth_changed)
	_refresh_leaderboard()


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
	title.text = "Trophies"
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
	body.add_child(_stats_card())
	body.add_child(_leaderboard_card())
	body.add_child(_badges_card())


func _card(heading: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var label := Label.new()
	label.text = heading
	label.theme_type_variation = "Subheading"
	box.add_child(label)
	return box


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
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.theme_type_variation = "Muted"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var value := Label.new()
		value.text = row[2]
		value.theme_type_variation = "Subheading"
		line.add_child(value)
		stat_labels[row[0]] = value
	box.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	return box.get_parent()


func _badges_card() -> Control:
	var box := _card("Badges")
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
		var name_label := Label.new()
		name_label.text = Progress.badge_title(badge)
		name_label.theme_type_variation = "Subheading" if earned else "Muted"
		text.add_child(name_label)
		var hint := Label.new()
		hint.text = ("Earned. " if earned else "") + Progress.badge_hint(badge)
		hint.theme_type_variation = "Caption"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(hint)
		badge_rows[badge] = row
	return box.get_parent()


func _refresh_leaderboard() -> void:
	var tier := _progress.difficulty
	if _play_games == null or not _play_games.available(tier):
		leaderboard_caption.text = "The online leaderboard works in the Google Play version of the game."
		leaderboard_button.text = "Leaderboard unavailable"
		leaderboard_button.disabled = true
	elif not _play_games.signed_in:
		leaderboard_caption.text = "Optional. Sign in with Google Play Games to post your score. The game works the same without it."
		leaderboard_button.text = "Sign in with Play Games"
		leaderboard_button.disabled = false
	else:
		leaderboard_caption.text = "Your %s score is posted automatically. Each level counts its best clear: 100 points per star plus a speed bonus." % Difficulty.name_of(tier)
		leaderboard_button.text = "Show leaderboard"
		leaderboard_button.disabled = false


func _on_auth_changed(_signed_in: bool) -> void:
	_refresh_leaderboard()


func _on_leaderboard_pressed() -> void:
	if _play_games == null:
		return
	if _play_games.signed_in:
		_play_games.sync(_progress.difficulty)
		_play_games.show_leaderboard(_progress.difficulty)
	else:
		_play_games.sign_in()
