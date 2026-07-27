extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	_check(audio != null, "AudioManager autoload exists")
	_check(feedback != null, "InteractionFeedback autoload exists")
	if audio == null or feedback == null:
		quit(1)
		return
	var callback := Callable(audio, "play_event")
	_check(feedback.is_connected("feedback_sfx_requested", callback), "feedback signal reaches AudioManager")
	for path in [
		"res://assets/audio/sfx/ui_click_mechanical.ogg",
		"res://assets/audio/sfx/assembly_drawer_open.ogg",
		"res://assets/audio/sfx/mechanical_adjust.ogg",
		"res://assets/audio/sfx/collimation_adjust_loop.ogg",
		"res://assets/audio/sfx/mechanical_lock.ogg",
		"res://assets/audio/ambient/fast_terminal_hum.ogg"
	]:
		_check(ResourceLoader.exists(path), "resource exists: " + path)
	_check(str(audio.EVENT_PATHS.get("target_locked", [""])[0]) == "res://assets/audio/sfx/target_lock.wav", "target acquisition keeps its original sound")
	_check(str(audio.EVENT_PATHS.get("mode_switch", [""])[0]) == "res://assets/audio/sfx/mechanical_lock.ogg", "view mode changes have one explicit semantic sound")
	_check(str(audio.EVENT_PATHS.get("collimation_adjust_loop", [""])[0]) == "res://assets/audio/sfx/collimation_adjust_loop.ogg", "collimation uses the trimmed continuous ratchet loop")
	_check(str(audio.EVENT_PATHS.get("assembly_completed", [""])[0]) == "res://assets/audio/sfx/mechanical_lock.ogg", "assembly completion uses the completion sound")
	_check(str(audio.EVENT_PATHS.get("mission_completed", [""])[0]) == "res://assets/audio/sfx/mechanical_lock.ogg", "mission completion uses the completion sound")
	audio.sfx_enabled = true
	var player_count_before_unknown: int = audio._players.size()
	audio.play_event("unmapped_visual_feedback")
	await process_frame
	_check(audio._players.size() == player_count_before_unknown, "unknown visual events remain silent instead of falling back to ui_confirm")
	feedback.feedback_sfx_requested.emit("focus_locked")
	await process_frame
	_check(audio._players.size() > 0, "focus event creates an audio player")
	audio._play_ambience(audio.FAST_TERMINAL_AMBIENCE_PATH, audio.music_volume_db + audio.FAST_TERMINAL_AMBIENCE_MUSIC_OFFSET_DB)
	await process_frame
	_check(audio._ambient_player != null and audio._ambient_player.playing, "FAST terminal ambience starts")
	audio._stop_ambience()
	await create_timer(audio.AMBIENCE_FADE_SECONDS + 0.1).timeout
	_check(not audio._ambient_player.playing, "FAST terminal ambience fades out and stops")
	print("AUDIO SFX TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  fail: " + label)
