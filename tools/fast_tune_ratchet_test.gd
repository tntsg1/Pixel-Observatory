extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var manager := root.get_node_or_null("/root/AudioManager")
	if manager == null:
		_fail("AudioManager autoload is available")
		_finish()
		return

	var previous_sfx_enabled := bool(manager.get("sfx_enabled"))
	manager.set("sfx_enabled", true)
	manager.call("start_event_loop", "fast_tune_window", -1.5)
	await process_frame
	var loops := manager.get("_loop_event_players") as Dictionary
	_check(loops.has("fast_tune_window"), "dragging starts one persistent FAST ratchet player")
	var player := loops.get("fast_tune_window") as AudioStreamPlayer
	_check(player != null and is_instance_valid(player), "ratchet loop owns a valid audio player")
	if player != null and is_instance_valid(player):
		_check(player.stream is AudioStreamOggVorbis, "ratchet uses the approved mechanical OGG")
		_check((player.stream as AudioStreamOggVorbis).loop, "ratchet stream loops while the drag is held")

	manager.call("start_event_loop", "fast_tune_window", -1.5)
	var repeated_loops := manager.get("_loop_event_players") as Dictionary
	_check(repeated_loops.size() == 1, "repeated drag motion does not stack audio players")

	manager.call("stop_event_loop", "fast_tune_window", 0.0)
	await process_frame
	_check(not (manager.get("_loop_event_players") as Dictionary).has("fast_tune_window"),
		"releasing the drag stops and removes the ratchet player")
	manager.set("sfx_enabled", previous_sfx_enabled)

	var radio_source := FileAccess.get_file_as_string("res://scripts/ui/radio_observation.gd")
	_check(radio_source.contains("_start_tune_ratchet()"),
		"FAST tuning starts the ratchet from the drag interaction")
	_check(radio_source.contains("_stop_tune_ratchet()"),
		"FAST tuning stops the ratchet on release or interrupted input")
	_check(radio_source.contains("not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)"),
		"lost mouse release cannot leave the ratchet playing")
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	if failures == 0:
		print("FAST TUNE RATCHET TEST PASS")
		quit(0)
	else:
		print("FAST TUNE RATCHET TEST FAIL (%d)" % failures)
		quit(1)
