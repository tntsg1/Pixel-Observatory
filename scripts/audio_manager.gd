extends Node

const SFX_OUTPUT_ENABLED := true
const MUSIC_OUTPUT_ENABLED := true

var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume_db := -7.0
var music_volume_db := -22.0
var _players: Array[AudioStreamPlayer] = []
var _loop_event_players: Dictionary = {}
var _last_event_at: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music_path := ""
var _music_playback_positions: Dictionary = {}
var _music_player_paths: Dictionary = {}
var _music_transition_serial := 0
var _last_scene_path := ""
var _ambient_player: AudioStreamPlayer
var _ambient_tween: Tween
var _current_ambient_path := ""

const CONFIG_PATH := "user://audio.cfg"
const SFX_PREFERENCE_VERSION := 1
const EVENT_COOLDOWN := 0.08
const MUSIC_FADE_SECONDS := 2.2
const AMBIENCE_FADE_SECONDS := 1.2
const SILENT_MUSIC_CATEGORY := "silent"
const FAST_TERMINAL_AMBIENCE_PATH := "res://assets/audio/ambient/fast_terminal_hum.ogg"
const FAST_TERMINAL_AMBIENCE_MUSIC_OFFSET_DB := -12.0
const RETIRED_MUSIC_PATHS := {
	"res://assets/audio/music/giant_telescope.mp3": true,
}
const RETIRED_MUSIC_UIDS := {
	"uid://b4x44bsg33mdj": true,
}
const MUSIC_PATHS := {
	"lobby": "res://assets/audio/music/lobby.mp3",
	"assembly": "res://assets/audio/music/telescope_assembly.mp3",
	"outdoor": "res://assets/audio/music/outdoor_stargazing.mp3",
	"giant": "res://assets/audio/music/space_fast_theme.mp3"
}
const EVENT_PATHS := {
	"ui_confirm": ["res://assets/audio/sfx/ui_click_mechanical.ogg"],
	"ui_select": ["res://assets/audio/sfx/ui_click_mechanical.ogg"],
	"ui_adjust": ["res://assets/audio/sfx/mechanical_adjust.ogg"],
	"collimation_adjust_loop": ["res://assets/audio/sfx/collimation_adjust_loop.ogg"],
	"ui_error": ["res://assets/audio/sfx/ui_error.wav"],
	"ui_blocked": ["res://assets/audio/sfx/ui_error.wav"],
	"assembly_part_installed": ["res://assets/audio/sfx/assembly_drawer_open.ogg"],
	"tube_part_installed": ["res://assets/audio/sfx/assembly_drawer_open.ogg"],
	"focus_locked": ["res://assets/audio/sfx/focus_lock.wav"],
	"finder_lock": ["res://assets/audio/sfx/target_lock.wav"],
	"target_locked": ["res://assets/audio/sfx/target_lock.wav"],
	"mode_switch": ["res://assets/audio/sfx/mechanical_lock.ogg"],
	"assembly_completed": ["res://assets/audio/sfx/mechanical_lock.ogg"],
	"mission_completed": ["res://assets/audio/sfx/mechanical_lock.ogg"],
	"guide_locked": ["res://assets/audio/sfx/space_lock.wav"],
	"wavefront_locked": ["res://assets/audio/sfx/space_lock.wav"],
	"segment_actuator": ["res://assets/audio/sfx/mechanical_adjust.ogg"],
	"wavefront_converging": ["res://assets/audio/sfx/mechanical_adjust.ogg"],
	"fast_signal_confirmed": ["res://assets/audio/sfx/fast_signal.wav"],
	"fast_array_online": ["res://assets/audio/sfx/fast_signal.wav"],
	"fast_array_relay": ["res://assets/audio/sfx/ui_click_mechanical.ogg"],
	"fast_cabin_drive": ["res://assets/audio/sfx/mechanical_adjust.ogg"],
	"fast_cabin_brake": ["res://assets/audio/sfx/mechanical_lock.ogg"],
	"fast_cable_settle": ["res://assets/audio/sfx/mechanical_lock.ogg"],
	"fast_cabin_lock": ["res://assets/audio/sfx/mechanical_lock.ogg"],
	"fast_tune_window": ["res://assets/audio/sfx/mechanical_adjust.ogg"],
	"fast_tune_locked": ["res://assets/audio/sfx/space_lock.wav"],
	"fast_fold_adjust": ["res://assets/audio/sfx/collimation_adjust_loop.ogg"],
	"fast_rfi_mark": ["res://assets/audio/sfx/ui_click_mechanical.ogg"],
	"fast_rfi_clean": ["res://assets/audio/sfx/space_lock.wav"],
	"fast_fold_step": ["res://assets/audio/sfx/mechanical_adjust.ogg"],
	"fast_discovery": ["res://assets/audio/sfx/fast_signal.wav"],
	"fast_report_confirmed": ["res://assets/audio/sfx/ui_click_mechanical.ogg"]
}


func _ready() -> void:
	_load_settings()
	if not SFX_OUTPUT_ENABLED:
		sfx_enabled = false
	if not MUSIC_OUTPUT_ENABLED:
		music_enabled = false
	_create_music_players()
	_create_ambience_player()
	call_deferred("_bind_feedback")
	call_deferred("_refresh_music_for_scene")
	call_deferred("_refresh_ambience_for_scene")


func _process(_delta: float) -> void:
	if not MUSIC_OUTPUT_ENABLED or not music_enabled:
		return
	var scene := get_tree().current_scene
	var scene_path := scene.scene_file_path if scene != null else ""
	if scene_path != _last_scene_path:
		_last_scene_path = scene_path
		_refresh_music_for_scene()
		_refresh_ambience_for_scene()


func _bind_feedback() -> void:
	var feedback := get_node_or_null("/root/InteractionFeedback")
	if feedback != null and feedback.has_signal("feedback_sfx_requested"):
		var callback := Callable(self, "play_event")
		if not feedback.is_connected("feedback_sfx_requested", callback):
			feedback.connect("feedback_sfx_requested", callback)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	# Earlier builds forced every SFX setting off while placeholder sounds were muted.
	# Treat that legacy preference as unset, while preserving choices made after this release.
	var saved_sfx_version := int(config.get_value("audio", "sfx_preference_version", 0))
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true)) if saved_sfx_version >= SFX_PREFERENCE_VERSION else true
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_volume_db = float(config.get_value("audio", "sfx_volume_db", -7.0))
	music_volume_db = float(config.get_value("audio", "music_volume_db", -22.0))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("audio", "sfx_preference_version", SFX_PREFERENCE_VERSION)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_volume_db", sfx_volume_db)
	config.set_value("audio", "music_volume_db", music_volume_db)
	config.save(CONFIG_PATH)


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled and SFX_OUTPUT_ENABLED
	if not sfx_enabled:
		stop_all_event_loops(0.0)
	_save_settings()


func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = clampf(value, -40.0, 3.0)
	for value_player in _loop_event_players.values():
		var player := value_player as AudioStreamPlayer
		if player != null and is_instance_valid(player):
			player.volume_db = sfx_volume_db
	_save_settings()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled and MUSIC_OUTPUT_ENABLED
	if music_enabled:
		_refresh_music_for_scene()
		_refresh_ambience_for_scene()
	else:
		_stop_music(true)
		_stop_ambience()
	_save_settings()


func set_music_volume_db(value: float) -> void:
	music_volume_db = clampf(value, -40.0, -8.0)
	if _active_music_player != null:
		_active_music_player.volume_db = music_volume_db
	if _ambient_player != null and _ambient_player.playing:
		_ambient_player.volume_db = music_volume_db + FAST_TERMINAL_AMBIENCE_MUSIC_OFFSET_DB
	_save_settings()


func play_event(event_name: String) -> void:
	if not SFX_OUTPUT_ENABLED or not sfx_enabled:
		return
	# Visual feedback events may intentionally be silent. Unknown names must not
	# turn into surprise generic clicks.
	var paths: Array = EVENT_PATHS.get(event_name, [])
	if paths.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_event_at.get(event_name, -10.0)) < EVENT_COOLDOWN:
		return
	_last_event_at[event_name] = now
	play_sfx(str(paths[randi() % paths.size()]), 0.025, sfx_volume_db)


func start_event_loop(event_name: String, volume_offset_db := 0.0) -> void:
	if not SFX_OUTPUT_ENABLED or not sfx_enabled:
		return
	var current := _loop_event_players.get(event_name) as AudioStreamPlayer
	if current != null and is_instance_valid(current):
		current.volume_db = sfx_volume_db + volume_offset_db
		if not current.playing:
			current.play()
		return
	var paths: Array = EVENT_PATHS.get(event_name, [])
	if paths.is_empty():
		return
	var source := load(str(paths[0])) as AudioStream
	if source == null:
		push_warning("Missing looping SFX for event: %s" % event_name)
		return
	var stream := source.duplicate(true) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	var player := AudioStreamPlayer.new()
	player.name = "LoopEvent_" + event_name.to_pascal_case()
	player.stream = stream
	player.volume_db = sfx_volume_db + volume_offset_db
	player.pitch_scale = randf_range(0.985, 1.015)
	add_child(player)
	_loop_event_players[event_name] = player
	player.play()


func stop_event_loop(event_name: String, fade_seconds := 0.045) -> void:
	var player := _loop_event_players.get(event_name) as AudioStreamPlayer
	_loop_event_players.erase(event_name)
	if player == null or not is_instance_valid(player):
		return
	if fade_seconds <= 0.0 or not player.playing:
		player.stop()
		player.queue_free()
		return
	var tween := create_tween().bind_node(player)
	tween.tween_property(player, "volume_db", -60.0, fade_seconds)
	tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	)


func stop_all_event_loops(fade_seconds := 0.045) -> void:
	for event_name in _loop_event_players.keys().duplicate():
		stop_event_loop(str(event_name), fade_seconds)


func is_event_loop_playing(event_name: String) -> bool:
	var player := _loop_event_players.get(event_name) as AudioStreamPlayer
	return player != null and is_instance_valid(player) and player.playing


func play_sfx(path: String, pitch_variation := 0.08, volume_db := -8.0) -> void:
	if not SFX_OUTPUT_ENABLED or not sfx_enabled:
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Missing SFX: %s" % path)
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.finished.connect(_on_player_finished.bind(player))
	add_child(player)
	player.play()
	_players.append(player)


func play_music(path: String) -> void:
	if not MUSIC_OUTPUT_ENABLED or not music_enabled or path == "":
		return
	if not _is_music_path_approved(path):
		_reject_retired_music(path)
		return
	_enforce_music_policy(path)
	if (
		path == _current_music_path
		and _active_music_player != null
		and _active_music_player.playing
		and _player_stream_path(_active_music_player) == path
	):
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Missing music: %s" % path)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	var next_player := _music_players[0]
	if next_player == _active_music_player:
		next_player = _music_players[1]
	var old_player := _active_music_player
	var old_path := _current_music_path
	_remember_music_position(old_player, old_path)
	_music_transition_serial += 1
	var transition_serial := _music_transition_serial
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	# The inactive channel may still be fading from a rapid previous switch.
	# Reclaim it explicitly; a stale tween callback is guarded by the serial.
	next_player.stop()
	next_player.stream = stream
	next_player.volume_db = -60.0
	var resume_position := _resume_position_for(path, stream)
	# seek() is harmless while stopped, while play(from_position) is the
	# reliable Godot path that guarantees no audible frame starts at zero.
	if resume_position > 0.0:
		next_player.seek(resume_position)
	next_player.play(resume_position)
	_music_player_paths[next_player.get_instance_id()] = path
	_active_music_player = next_player
	_current_music_path = path

	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(next_player, "volume_db", music_volume_db, MUSIC_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old_player != null and old_player.playing:
		_music_tween.tween_property(old_player, "volume_db", -60.0, MUSIC_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_music_tween.finished.connect(
			_finish_music_transition.bind(transition_serial, old_player)
		)


func _remember_music_position(player: AudioStreamPlayer, path: String) -> void:
	if player == null or path.is_empty() or not player.playing:
		return
	var assigned_path := str(_music_player_paths.get(player.get_instance_id(), path))
	if assigned_path != path:
		return
	var position := player.get_playback_position()
	if is_finite(position) and position >= 0.0:
		_music_playback_positions[path] = position


func _resume_position_for(path: String, stream: AudioStream) -> float:
	var saved := float(_music_playback_positions.get(path, 0.0))
	if not is_finite(saved) or saved <= 0.0:
		return 0.0
	var length := stream.get_length()
	if is_finite(length) and length > 0.1:
		var wrapped := fposmod(saved, length)
		# Avoid asking a decoder to begin inside its final packet.
		if wrapped >= length - minf(0.1, length * 0.01):
			return 0.0
		return wrapped
	# Some imported/streamed formats do not expose a reliable duration.
	# Their already-reported playback position is still the safest fallback.
	return saved


func _finish_music_transition(
	transition_serial: int,
	old_player: AudioStreamPlayer
) -> void:
	if transition_serial != _music_transition_serial:
		return
	if old_player == null or old_player == _active_music_player:
		return
	old_player.stop()
	old_player.volume_db = -60.0
	_music_player_paths.erase(old_player.get_instance_id())


func clear_music_progress(restart_current := true) -> void:
	_music_playback_positions.clear()
	if restart_current and _active_music_player != null and _active_music_player.playing:
		_active_music_player.seek(0.0)


func _create_music_players() -> void:
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % (index + 1)
		player.volume_db = -60.0
		add_child(player)
		_music_players.append(player)


func _create_ambience_player() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbiencePlayer"
	_ambient_player.volume_db = -60.0
	add_child(_ambient_player)


func _refresh_music_for_scene() -> void:
	if not MUSIC_OUTPUT_ENABLED or not music_enabled:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var category := _music_category_for_scene(scene.scene_file_path)
	if category == SILENT_MUSIC_CATEGORY:
		_enforce_music_policy("")
		_fade_music_to_silence()
		return
	if category == "":
		return
	var expected_path := str(MUSIC_PATHS.get(category, ""))
	_enforce_music_policy(expected_path)
	play_music(expected_path)


func _refresh_ambience_for_scene() -> void:
	if not MUSIC_OUTPUT_ENABLED or not music_enabled:
		return
	var scene := get_tree().current_scene
	var file_name := scene.scene_file_path.get_file().get_basename() if scene != null else ""
	if file_name == "radio_observation":
		_play_ambience(FAST_TERMINAL_AMBIENCE_PATH, music_volume_db + FAST_TERMINAL_AMBIENCE_MUSIC_OFFSET_DB)
	else:
		_stop_ambience()


func _music_category_for_scene(scene_path: String) -> String:
	var file_name := scene_path.get_file().get_basename()
	if file_name in ["main_menu", "observatory_room", "observatory_interior", "parts_cabinet", "learning_journal", "graduation_ceremony"]:
		return "lobby"
	if file_name in ["telescope_assembly", "advanced_assembly", "optical_tube_assembly", "telescope_types", "collimation"]:
		return "assembly"
	if file_name == "telescope_view":
		return SILENT_MUSIC_CATEGORY
	if file_name in ["sky_observation", "world_map", "constellation_observation"]:
		return "outdoor"
	if file_name in ["space_observation", "radio_observation", "multi_observation"]:
		return "giant"
	# Story and learning overlays retain the music of the scene they came from.
	return ""


func _is_music_path_approved(path: String) -> bool:
	if path.is_empty() or RETIRED_MUSIC_PATHS.has(path):
		return false
	return MUSIC_PATHS.values().has(path)


func _player_stream_path(player: AudioStreamPlayer) -> String:
	if player == null or player.stream == null:
		return ""
	var stream_path := str(player.stream.resource_path)
	if stream_path.begins_with("uid://") and RETIRED_MUSIC_UIDS.has(stream_path):
		return stream_path
	return stream_path


func _enforce_music_policy(expected_path: String) -> void:
	# Scene changes may reuse an Autoload player that was created by an older
	# build. Inspect the stream actually assigned to every channel; a retired
	# decoder is stopped immediately instead of being allowed to crossfade
	# into FAST or the space observatory.
	for player in _music_players:
		if player == null or not player.playing:
			continue
		var assigned_path := str(
			_music_player_paths.get(player.get_instance_id(), _player_stream_path(player))
		)
		var stream_path := _player_stream_path(player)
		var retired := (
			RETIRED_MUSIC_PATHS.has(assigned_path)
			or RETIRED_MUSIC_PATHS.has(stream_path)
			or RETIRED_MUSIC_UIDS.has(stream_path)
			or not _is_music_path_approved(assigned_path)
		)
		if retired:
			player.stop()
			player.stream = null
			player.volume_db = -60.0
			_music_player_paths.erase(player.get_instance_id())
			_music_playback_positions.erase(assigned_path)
			_music_playback_positions.erase(stream_path)
			if player == _active_music_player:
				_active_music_player = null
				_current_music_path = ""
	if RETIRED_MUSIC_PATHS.has(_current_music_path):
		_music_playback_positions.erase(_current_music_path)
		_current_music_path = ""
	if expected_path != "" and not _is_music_path_approved(expected_path):
		_reject_retired_music(expected_path)


func _reject_retired_music(path: String) -> void:
	_music_playback_positions.erase(path)
	for player in _music_players:
		if player == null:
			continue
		var assigned_path := str(
			_music_player_paths.get(player.get_instance_id(), _player_stream_path(player))
		)
		if assigned_path == path or _player_stream_path(player) == path:
			player.stop()
			player.stream = null
			player.volume_db = -60.0
			_music_player_paths.erase(player.get_instance_id())
			if player == _active_music_player:
				_active_music_player = null
				_current_music_path = ""
	if OS.is_debug_build():
		push_warning("Blocked non-approved music path: %s" % path)


func music_runtime_state() -> Dictionary:
	var channels: Array[Dictionary] = []
	for player in _music_players:
		channels.append({
			"name": player.name,
			"playing": player.playing,
			"assigned_path": str(
				_music_player_paths.get(player.get_instance_id(), "")
			),
			"stream_path": _player_stream_path(player),
			"position": player.get_playback_position() if player.playing else 0.0,
		})
	return {
		"current_path": _current_music_path,
		"active_stream_path": _player_stream_path(_active_music_player),
		"channels": channels,
	}


func _fade_music_to_silence() -> void:
	if _active_music_player == null or not _active_music_player.playing:
		_current_music_path = ""
		return
	if _current_music_path.is_empty():
		return
	var old_player := _active_music_player
	var old_path := _current_music_path
	_remember_music_position(old_player, old_path)
	_music_transition_serial += 1
	var transition_serial := _music_transition_serial
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_current_music_path = ""
	var fading_players: Array[AudioStreamPlayer] = []
	for player in _music_players:
		if player.playing:
			fading_players.append(player)
	_music_tween = create_tween().set_parallel(true)
	for player in fading_players:
		_music_tween.tween_property(
			player,
			"volume_db",
			-60.0,
			MUSIC_FADE_SECONDS
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_music_tween.finished.connect(
		_finish_music_silence.bind(transition_serial, fading_players)
	)


func _finish_music_silence(
	transition_serial: int,
	fading_players: Array[AudioStreamPlayer]
) -> void:
	if transition_serial != _music_transition_serial:
		return
	if not _current_music_path.is_empty():
		return
	for player in fading_players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.volume_db = -60.0
		_music_player_paths.erase(player.get_instance_id())
	_active_music_player = null


func _play_ambience(path: String, target_volume_db: float) -> void:
	if _ambient_player == null or path == "":
		return
	if path == _current_ambient_path and _ambient_player.playing:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Missing ambience: %s" % path)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_player.stop()
	_ambient_player.stream = stream
	_ambient_player.volume_db = -60.0
	_ambient_player.play()
	_current_ambient_path = path
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient_player, "volume_db", target_volume_db, AMBIENCE_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stop_ambience() -> void:
	_current_ambient_path = ""
	if _ambient_player == null:
		return
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	if not _ambient_player.playing:
		_ambient_player.volume_db = -60.0
		return
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(_ambient_player, "volume_db", -60.0, AMBIENCE_FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ambient_tween.tween_callback(Callable(self, "_finish_ambience_stop"))


func _finish_ambience_stop() -> void:
	if _current_ambient_path.is_empty() and _ambient_player != null:
		_ambient_player.stop()
		_ambient_player.volume_db = -60.0


func _stop_music(clear_session_progress := false) -> void:
	_music_transition_serial += 1
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for player in _music_players:
		player.stop()
		player.volume_db = -60.0
	_music_player_paths.clear()
	if clear_session_progress:
		_music_playback_positions.clear()
	_current_music_path = ""
	_active_music_player = null


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_players.erase(player)
	player.queue_free()
