extends SceneTree

const OUTPUT_DIR := "res://artifacts/point_source_focus_continuity"

var view: Control
var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(60.0)
	watchdog.timeout.connect(func() -> void:
		push_error("POINT SOURCE FOCUS CAPTURE TIMEOUT")
		quit(124)
	)
	if DisplayServer.get_name() == "headless":
		push_error("POINT SOURCE FOCUS CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		quit(2)
		return
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_manager := root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.debug_jump_to_level(23, true)
	game_manager.selected_object_id = "vega"
	_suppress_tutorials()

	view = load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	current_scene = view
	await _settle(0.25)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await _settle(0.10)
	var guide := view.get("focus_guide_panel") as Control
	if guide != null:
		guide.visible = false
	view.set("drift_enabled", false)
	view.set("drift_offset", Vector2.ZERO)
	var lens_center: Vector2 = view.get("lens_center")
	view.set("target_center", lens_center)
	view.set("visual_target_center", lens_center)
	view.call("_update_target_visuals")

	var target_focus := float(view.get("target_focus_value"))
	var far_value := clampf(target_focus + 0.34, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.28:
		far_value = clampf(target_focus - 0.34, 0.0, 1.0)
	var middle_value := lerpf(far_value, target_focus, 0.48)
	await _capture_focus(far_value, "01_vega_severe_defocus.png")
	await _capture_focus(middle_value, "02_vega_mid_adjustment.png")
	await _capture_focus(target_focus, "03_vega_sharp_focus.png")

	current_scene = null
	view.queue_free()
	await process_frame
	print("POINT SOURCE FOCUS CAPTURES %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT_DIR)
	])
	quit(0 if failures == 0 else 1)


func _capture_focus(value: float, file_name: String) -> void:
	view.call("_set_focus_value", value)
	await _settle(0.18)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	if image.save_png(path) != OK:
		failures += 1


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in [
		"first_focus_control",
		"focus_novice_guide",
		"first_earth_drift",
		"manual_earth_drift_correction_v2"
	]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame
