class_name AudioManager
extends Node
## Plays UI/game sound effects and the looping music. Owns two buses so each
## can be muted independently from Settings. Holds no game rules.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MUSIC_PATH := "res://assets/audio/music/calm_loop.ogg"
const MUSIC_VOLUME_DB := -9.0
const SFX_POOL_SIZE := 6
## name -> [resource path, volume in dB]
const SOUNDS := {
	"tap_clear": ["res://assets/audio/sfx/tap_clear.wav", -4.0],
	"tap_blocked": ["res://assets/audio/sfx/tap_blocked.wav", -3.0],
	"hint": ["res://assets/audio/sfx/hint.wav", -5.0],
	"coin": ["res://assets/audio/sfx/coin.wav", -5.0],
	"star1": ["res://assets/audio/sfx/star1.wav", -5.0],
	"star2": ["res://assets/audio/sfx/star2.wav", -5.0],
	"star3": ["res://assets/audio/sfx/star3.wav", -5.0],
	"win": ["res://assets/audio/sfx/win.wav", -4.0],
	"lose": ["res://assets/audio/sfx/lose.wav", -5.0],
	"click": ["res://assets/audio/sfx/click.wav", -8.0],
}

var music_enabled := true
var sfx_enabled := true
## Counts sounds actually started, for tests and diagnostics.
var sfx_played := 0
var last_sfx := ""

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for sound_name in SOUNDS:
		var stream: AudioStream = load(SOUNDS[sound_name][0])
		if stream == null:
			push_error("Missing sound: %s" % SOUNDS[sound_name][0])
			continue
		_streams[sound_name] = stream
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.volume_db = MUSIC_VOLUME_DB
	var music_stream: AudioStream = load(MUSIC_PATH)
	if music_stream is AudioStreamOggVorbis:
		music_stream.loop = true
		_music.stream = music_stream
	else:
		push_error("Missing music: %s" % MUSIC_PATH)
	add_child(_music)
	_apply_mutes()


func apply_settings(music_on: bool, sfx_on: bool) -> void:
	music_enabled = music_on
	sfx_enabled = sfx_on
	_apply_mutes()


func start_music() -> void:
	if _music != null and _music.stream != null and not _music.playing:
		_music.play()


func is_music_playing() -> bool:
	return _music != null and _music.playing and not _music.stream_paused


func music_muted() -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(MUSIC_BUS))


func sfx_muted() -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(SFX_BUS))


## Returns true if the sound was started (false when effects are off or unknown).
func play(sound_name: String) -> bool:
	if not sfx_enabled or not _streams.has(sound_name):
		return false
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % _pool.size()
	player.stream = _streams[sound_name]
	player.volume_db = SOUNDS[sound_name][1]
	player.play()
	sfx_played += 1
	last_sfx = sound_name
	return true


## Plays `sound_name` after `delay` seconds without blocking the caller.
func play_later(sound_name: String, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void: play(sound_name))


func _notification(what: int) -> void:
	# Android: keep music silent while the app is in the background.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if _music != null:
			_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if _music != null:
			_music.stream_paused = false


func _apply_mutes() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not music_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not sfx_enabled)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
