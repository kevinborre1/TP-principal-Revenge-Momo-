extends Node

@export var music_papas: AudioStream
@export var music_jefe_final: AudioStream
@export var music_escape_momo: AudioStream
@export var fade_duration: float = 0.8

@onready var _player_a: AudioStreamPlayer = $PlayerA
@onready var _player_b: AudioStreamPlayer = $PlayerB

var _active_player: AudioStreamPlayer
var _inactive_player: AudioStreamPlayer
var _current_track: AudioStream = null
var _tween: Tween

func _ready() -> void:
	_active_player = _player_a
	_inactive_player = _player_b
	_player_a.volume_db = -80.0
	_player_b.volume_db = -80.0

func play_papas() -> void:
	_switch_to(music_papas)

func play_jefe_final() -> void:
	_switch_to(music_jefe_final)

func play_escape_momo() -> void:
	_switch_to(music_escape_momo)

func stop_music() -> void:
	_current_track = null
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_active_player, "volume_db", -80.0, fade_duration)
	_tween.tween_property(_inactive_player, "volume_db", -80.0, fade_duration)
	_tween.chain().tween_callback(func():
		_active_player.stop()
		_inactive_player.stop()
	)

func _switch_to(new_stream: AudioStream) -> void:
	if new_stream == null or new_stream == _current_track:
		return

	_current_track = new_stream

	if _tween and _tween.is_valid():
		_tween.kill()

	var temp := _active_player
	_active_player = _inactive_player
	_inactive_player = temp

	_active_player.stream = new_stream
	_active_player.volume_db = -80.0
	_active_player.play()

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_active_player, "volume_db", 0.0, fade_duration)
	_tween.tween_property(_inactive_player, "volume_db", -80.0, fade_duration)
	_tween.chain().tween_callback(_inactive_player.stop)
