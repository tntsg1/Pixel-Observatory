extends SceneTree

# Mobile Controller Mode acceptance: virtual joystick moves the player,
# Interact == E, drag changes Az/Alt with sensitivity, pinch switches view
# tiers, focus nudge buttons drive focus, settings persist, and PC paths
# stay untouched when mobile mode is off.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var ti: Node = root.get_node_or_null("/root/TouchInput")
	_check(ti != null, "TouchInput autoload present")
	gm.new_game()
	ti.set_mobile_mode(true)

	# 1. Virtual joystick moves the player through the same movement path.
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var start_pos: Vector2 = room.get("player_pos")
	ti.virtual_move = Vector2(1, 0)
	for _i in range(12):
		room.call("_move_player", 1.0 / 30.0)
	ti.virtual_move = Vector2.ZERO
	var moved: Vector2 = room.get("player_pos")
	_check(moved.x > start_pos.x + 10.0, "1. joystick vector moves the player east")

	# 2. Interact button drives the same handler as E near the mission board.
	room.set("player_pos", Vector2(690, 240))
	room.call("_update_nearby")
	_check(str(room.get("nearby_id")) == "mission", "2a. player stands near the mission board")
	room.call("_interact_with_nearby")
	await process_frame
	_check(room.get("mission_board_popup") != null, "2b. Interact opens the mission board like E")
	room.call("_close_mission_board", false)
	var overlay: Control = room.get("mobile_overlay")
	_check(overlay != null, "2c. mobile overlay exists in the lobby")
	_check((overlay.get("action_buttons") as Dictionary).has("interact"), "2d. Interact button present")
	room.queue_free()
	await process_frame

	# 3. Sky drag changes Az/Alt; sensitivity scales it; pinch switches tier.
	gm.debug_jump_to_level(4, true)
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await process_frame
	var before_az := float(sky.get("telescope_azimuth"))
	sky.set("mouse_aim_dragging", true)
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(80, 0)
	sky.call("_unhandled_input", drag) if sky.has_method("_unhandled_input") else sky.call("_input", drag)
	var after_az := float(sky.get("telescope_azimuth"))
	_check(absf(after_az - before_az) > 0.5, "3a. horizontal drag changes azimuth")
	ti.apply_setting("touch_sensitivity", 2.0)
	var az_before_sensitive := float(sky.get("telescope_azimuth"))
	sky.call("_unhandled_input", drag) if sky.has_method("_unhandled_input") else sky.call("_input", drag)
	var sensitive_delta := absf(float(sky.get("telescope_azimuth")) - az_before_sensitive)
	_check(sensitive_delta > absf(after_az - before_az) * 1.5, "3b. sensitivity scales drag response")
	ti.apply_setting("touch_sensitivity", 1.0)
	sky.set("mouse_aim_dragging", false)
	sky.call("_set_view_mode", "naked_eye")
	sky.call("_pinch_switch_mode", 1)
	_check(str(sky.get("view_mode")) != "naked_eye", "3c. pinch-out zooms into the next available tier")
	sky.call("_pinch_switch_mode", -1)
	_check(str(sky.get("view_mode")) == "naked_eye", "3d. pinch-in zooms back out")
	sky.queue_free()
	await process_frame

	# 4. Focus nudge buttons drive the focus value.
	gm.debug_jump_to_level(4, true)
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	await process_frame
	view.set("quiz_brief_dismissed", true)
	var quiz: Node = view.get("quiz_brief_overlay")
	if quiz != null:
		quiz.queue_free()
		view.set("quiz_brief_overlay", null)
		await process_frame
	var focus_before := float(view.get("focus_value"))
	ti.focus_direction = 1.0
	for _i in range(10):
		view.call("_handle_focus_input", 1.0 / 30.0)
	ti.focus_direction = 0.0
	_check(float(view.get("focus_value")) > focus_before + 0.02, "4. focus nudge button raises focus")
	view.queue_free()
	await process_frame

	# 5. Settings persist through a reload.
	ti.apply_setting("joystick_scale", 1.3)
	ti.apply_setting("invert_pitch", true)
	ti.call("_load_settings")
	_check(absf(float(ti.get("joystick_scale")) - 1.3) < 0.01, "5a. joystick scale persists")
	_check(bool(ti.get("invert_pitch")), "5b. pitch inversion persists")
	ti.apply_setting("invert_pitch", false)
	ti.apply_setting("joystick_scale", 1.0)

	# 6. PC mode: virtual state is inert.
	ti.set_mobile_mode(false)
	ti.virtual_move = Vector2(1, 0)
	_check(ti.call("move_vector") == Vector2.ZERO, "6. PC mode ignores virtual joystick state")
	ti.virtual_move = Vector2.ZERO

	if failures == 0:
		print("MOBILE CONTROLS TEST PASS")
		quit(0)
	else:
		print("MOBILE CONTROLS TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
