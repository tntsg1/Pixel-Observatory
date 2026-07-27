extends SceneTree

const OUTPUT := "res://artifacts/uranus_focus_states"

var game_manager: Node
var view: Control
var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(60.0)
	watchdog.timeout.connect(func() -> void:
		push_error("URANUS FOCUS CAPTURE TIMEOUT")
		quit(124)
	)
	if DisplayServer.get_name() == "headless":
		push_error("URANUS FOCUS CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		quit(2)
		return
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	game_manager = root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.language_mode = "en"
	game_manager.debug_jump_to_level(32, true)
	game_manager.selected_object_id = "uranus"
	_suppress_tutorials()

	view = load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	current_scene = view
	await _settle(0.35)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	var guide_text := view.get("focus_guide_text") as Control
	if guide_text != null:
		guide_text.visible = false

	var target_focus := float(view.get("target_focus_value"))
	var tolerance := maxf(float(view.get("focus_tolerance")), 0.025)
	var far_value := clampf(target_focus + 0.32, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.24:
		far_value = clampf(target_focus - 0.32, 0.0, 1.0)
	await _set_focus_and_capture(far_value, "01_uranus_severe_defocus.png")

	var near_value := clampf(target_focus + tolerance * 1.45, 0.0, 1.0)
	if absf(near_value - target_focus) < tolerance:
		near_value = clampf(target_focus - tolerance * 1.45, 0.0, 1.0)
	await _set_focus_and_capture(near_value, "02_uranus_near_focus.png")
	await _set_focus_and_capture(target_focus, "03_uranus_sharp_focus.png")

	current_scene = null
	view.queue_free()
	await process_frame
	print("URANUS FOCUS CAPTURES %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT)
	])
	quit(0 if failures == 0 else 1)


func _set_focus_and_capture(value: float, file_name: String) -> void:
	view.call("_set_focus_value", value)
	view.call("_advance_visual_smoothing", 1.0)
	view.call("_update_target_visuals")
	await _settle(0.30)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		push_error("Empty viewport image for " + file_name)
		return
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		failures += 1
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in ["first_focus_control", "focus_novice_guide"]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame
