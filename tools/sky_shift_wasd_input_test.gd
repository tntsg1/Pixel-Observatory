extends SceneTree

# Regression for the real sky-navigation input path: Shift is both the
# averted-vision hold and the fast-aim modifier, but it must never consume
# WASD movement.

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if gm == null or feedback == null:
		_fail("required autoloads are available")
		_finish()
		return

	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(30, true)
	gm.selected_object_id = "crab_nebula"
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	for _frame in range(4):
		await process_frame

	var shift_is_mapped := false
	for event in InputMap.action_get_events("dodge"):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT:
				shift_is_mapped = true
				break
	_check(shift_is_mapped, "the dodge/side-view action is mapped to Shift")

	var old_reduced_motion := bool(feedback.get("reduced_motion"))
	feedback.set("reduced_motion", true)
	view.set("fov_x", 120.0)
	view.set("telescope_altitude", 45.0)

	_reset_aim(view)
	Input.action_press("move_right")
	view.call("_handle_aim_input", 0.25)
	Input.action_release("move_right")
	var normal_right := float(view.get("telescope_azimuth")) - 100.0
	_check(normal_right > 0.0, "D moves the sky view to the right")

	_reset_aim(view)
	Input.action_press("dodge")
	Input.action_press("move_right")
	view.call("_handle_aim_input", 0.25)
	Input.action_release("move_right")
	Input.action_release("dodge")
	var shifted_right := float(view.get("telescope_azimuth")) - 100.0
	_check(shifted_right > normal_right * 1.9, "Shift+D keeps moving and applies the fast-aim multiplier")

	_reset_aim(view)
	Input.action_press("dodge")
	Input.action_press("move_up")
	view.call("_handle_aim_input", 0.25)
	Input.action_release("move_up")
	Input.action_release("dodge")
	_check(float(view.get("telescope_altitude")) > 45.0, "Shift+W changes telescope altitude")

	feedback.set("reduced_motion", old_reduced_motion)
	view.queue_free()
	await process_frame
	_finish()


func _reset_aim(view: Control) -> void:
	view.set("telescope_azimuth", 100.0)
	view.set("display_azimuth", 100.0)
	view.set("telescope_altitude", 45.0)
	view.set("display_altitude", 45.0)
	view.set("aim_velocity_az", 0.0)
	view.set("aim_velocity_alt", 0.0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	push_error("FAIL: " + label)


func _finish() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	Input.action_release("dodge")
	print("SKY SHIFT WASD INPUT TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
