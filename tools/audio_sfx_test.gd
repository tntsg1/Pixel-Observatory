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
		"res://assets/audio/sfx/ui_confirm_01.wav",
		"res://assets/audio/sfx/assembly_snap.wav",
		"res://assets/audio/sfx/focus_lock.wav",
		"res://assets/audio/sfx/space_lock.wav",
		"res://assets/audio/sfx/fast_signal.wav"
	]:
		_check(ResourceLoader.exists(path), "resource exists: " + path)
	audio.sfx_enabled = true
	feedback.feedback_sfx_requested.emit("focus_locked")
	await process_frame
	_check(audio._players.size() > 0, "focus event creates an audio player")
	print("AUDIO SFX TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  fail: " + label)
