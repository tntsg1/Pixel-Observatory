extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)

	var submit_scene: Control = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(submit_scene)
	await _settle(0.06)
	submit_scene.call("_submit")
	await process_frame
	_check(submit_scene.find_child("SpaceConsoleShutdown", true, false) != null,
		"submitting a space report starts the shutdown transition")
	_check(submit_scene.get("shutdown_phase") == "archive",
		"shutdown begins by archiving the science report")
	submit_scene.queue_free()
	await process_frame

	var power_scene: Control = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(power_scene)
	await _settle(0.06)
	power_scene.set_meta("shutdown_callback", false)
	power_scene.call(
		"_power_down",
		func() -> void: power_scene.set_meta("shutdown_callback", true),
		true)
	await _settle(1.75)
	_check(bool(power_scene.get_meta("shutdown_callback", false)),
		"shutdown finishes before changing scene")
	_check(power_scene.get("shutdown_phase") == "complete",
		"shutdown reaches the complete state")
	power_scene.queue_free()
	await process_frame

	gm.last_learning_card = {
		"object": gm.current_target(),
		"level": gm.current_level(),
		"observation": {
			"success": true,
			"quality": "Good",
			"clarity": 78.0,
			"contrast": 74.0,
			"detail": 72.0,
		},
		"stats": gm.calculate_stats(),
		"concept_card": {},
		"reward_summary": {
			"credits_before": 0,
			"credits_awarded": 100,
			"credits_total": 100,
			"badges_awarded": [],
		},
	}
	var teaching := root.get_node("/root/TeachingFlowManager")
	teaching.active_card_mode = "complete"
	var card: Control = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	await _settle(0.06)
	_check(card.find_child("MayaMissionRecapPortrait", true, false) == null,
		"Maya is not left standing on a mission-complete page without dialogue")
	_check(card.find_child("ContinueButton", true, false) != null,
		"mission-complete controls remain intact")
	card.queue_free()
	await process_frame

	print("SPACE SHUTDOWN TRANSITION TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
