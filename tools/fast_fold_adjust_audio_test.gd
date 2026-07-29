extends SceneTree

var failures := 0
var feedback_events: Array[String] = []


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	var audio := root.get_node_or_null("/root/AudioManager")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if gm == null or audio == null or feedback == null:
		_fail("required autoloads are available")
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(85, true)
	audio.sfx_enabled = true
	feedback.feedback_sfx_requested.connect(_record_feedback_event)

	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	await process_frame
	scene.call("_finish_array_takeover")
	scene.stage = 3
	scene.call("_reset_fold_capture_validation", true)
	scene.call("_rebuild")
	for _i in range(3):
		await process_frame

	scene.model.trial_dm += 0.2
	scene.call("_fold_parameters_changed", "dm")
	await process_frame
	_check(audio.is_event_loop_playing("fast_fold_adjust"),
		"holding a DM adjustment key starts the continuous mechanical loop")
	var active_loops := audio.get("_loop_event_players") as Dictionary
	var active_player := active_loops.get("fast_fold_adjust") as AudioStreamPlayer
	_check(active_player != null and active_player.stream is AudioStreamOggVorbis,
		"FAST fold adjustment uses the trimmed mechanical OGG loop")

	await create_timer(0.13).timeout
	await process_frame
	_check(not audio.is_event_loop_playing("fast_fold_adjust"),
		"the loop stops within 130 ms after values stop changing")

	feedback_events.clear()
	scene.model.trial_phase = fposmod(scene.model.trial_phase + 0.01, 1.0)
	scene.call("_fold_parameters_changed", "phase")
	await process_frame
	_check(audio.is_event_loop_playing("fast_fold_adjust"),
		"the visible phase adjustment keys reuse the same continuous loop")
	scene.call("_stop_fold_adjust_audio")
	await process_frame
	_check(not audio.is_event_loop_playing("fast_fold_adjust"),
		"releasing an adjustment key stops the loop immediately")
	_check(not feedback_events.has("ui_adjust"),
		"releasing FAST fold adjustment does not add a one-shot adjustment sound")

	for _i in range(5):
		scene.model.trial_period_ms += 0.25
		scene.call("_fold_parameters_changed", "period")
		await process_frame
	var loops := audio.get("_loop_event_players") as Dictionary
	_check(loops.keys().count("fast_fold_adjust") == 1,
		"continuous changes keep exactly one loop player")

	scene.queue_free()
	await process_frame
	_check(not audio.is_event_loop_playing("fast_fold_adjust"),
		"leaving the FAST scene stops the mechanical loop")
	# Let the audio mixer consume the stop command once before a headless
	# process exits.  This is teardown only; the assertion above still proves
	# the interaction loop stops immediately on scene exit.
	await create_timer(0.12).timeout
	_finish()


func _record_feedback_event(event_name: String) -> void:
	feedback_events.append(event_name)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST FOLD ADJUST AUDIO TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
