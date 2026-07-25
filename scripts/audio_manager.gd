extends Node

var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume_db := -7.0
var _players: Array[AudioStreamPlayer] = []
var _last_event_at: Dictionary = {}

const CONFIG_PATH := "user://audio.cfg"
const EVENT_COOLDOWN := 0.08
const EVENT_PATHS := {
	"ui_confirm": [
		"res://assets/audio/sfx/ui_confirm_01.wav",
		"res://assets/audio/sfx/ui_confirm_02.wav",
		"res://assets/audio/sfx/ui_confirm_03.wav"
	],
	"ui_adjust": ["res://assets/audio/sfx/ui_adjust.wav"],
	"ui_error": ["res://assets/audio/sfx/ui_error.wav"],
	"ui_blocked": ["res://assets/audio/sfx/ui_error.wav"],
	"assembly_part_installed": ["res://assets/audio/sfx/assembly_snap.wav"],
	"tube_part_installed": ["res://assets/audio/sfx/assembly_snap.wav"],
	"focus_locked": ["res://assets/audio/sfx/focus_lock.wav"],
	"finder_lock": ["res://assets/audio/sfx/target_lock.wav"],
	"target_locked": ["res://assets/audio/sfx/target_lock.wav"],
	"guide_locked": ["res://assets/audio/sfx/space_lock.wav"],
	"wavefront_locked": ["res://assets/audio/sfx/space_lock.wav"],
	"fast_signal_confirmed": ["res://assets/audio/sfx/fast_signal.wav"],
	"fast_array_online": ["res://assets/audio/sfx/fast_signal.wav"],
	"fast_array_relay": ["res://assets/audio/sfx/ui_confirm_01.wav"],
	"fast_cabin_drive": ["res://assets/audio/sfx/ui_adjust.wav"],
	"fast_cabin_brake": ["res://assets/audio/sfx/ui_adjust.wav"],
	"fast_cable_settle": ["res://assets/audio/sfx/assembly_snap.wav"],
	"fast_cabin_lock": ["res://assets/audio/sfx/assembly_snap.wav"],
	"fast_tune_window": ["res://assets/audio/sfx/ui_adjust.wav"],
	"fast_tune_locked": ["res://assets/audio/sfx/space_lock.wav"],
	"fast_rfi_mark": ["res://assets/audio/sfx/ui_confirm_01.wav"],
	"fast_rfi_clean": ["res://assets/audio/sfx/space_lock.wav"],
	"fast_fold_step": ["res://assets/audio/sfx/ui_confirm_02.wav"],
	"fast_discovery": ["res://assets/audio/sfx/fast_signal.wav"],
	"fast_report_confirmed": ["res://assets/audio/sfx/ui_confirm_03.wav"]
}


func _ready() -> void:
	_load_settings()
	call_deferred("_bind_feedback")


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
	sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))
	music_enabled = bool(config.get_value("audio", "music_enabled", true))
	sfx_volume_db = float(config.get_value("audio", "sfx_volume_db", -7.0))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sfx_volume_db", sfx_volume_db)
	config.save(CONFIG_PATH)


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_save_settings()


func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = clampf(value, -40.0, 3.0)
	_save_settings()


func play_event(event_name: String) -> void:
	if not sfx_enabled:
		return
	var paths: Array = EVENT_PATHS.get(event_name, EVENT_PATHS.get("ui_confirm", []))
	if paths.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_event_at.get(event_name, -10.0)) < EVENT_COOLDOWN:
		return
	_last_event_at[event_name] = now
	play_sfx(str(paths[randi() % paths.size()]), 0.025, sfx_volume_db)


func play_sfx(path: String, pitch_variation := 0.08, volume_db := -8.0) -> void:
	if not sfx_enabled:
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


func play_music(_path: String) -> void:
	if not music_enabled:
		return


func _on_player_finished(player: AudioStreamPlayer) -> void:
	_players.erase(player)
	player.queue_free()
