extends SceneTree

const OUTPUT := "res://artifacts/sirius_shared_focus"

var view: Control
var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(60.0)
	watchdog.timeout.connect(func() -> void:
		push_error("SIRIUS SHARED FOCUS CAPTURE TIMEOUT")
		quit(124)
	)
	if DisplayServer.get_name() == "headless":
		push_error("SIRIUS SHARED FOCUS CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		quit(2)
		return
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))

	var game_manager := root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.debug_jump_to_level(22, true)
	game_manager.selected_object_id = "sirius"
	_suppress_tutorials()

	view = load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	current_scene = view
	await _settle(0.35)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await _settle(0.12)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	# Keep all three captures on one optical axis. L22 normally teaches drift,
	# but motion would make a focus comparison look like three different stars.
	view.set("drift_enabled", false)
	view.set("drift_offset", Vector2.ZERO)
	var lens_center: Vector2 = view.get("lens_center")
	view.set("target_center", lens_center)
	view.set("visual_target_center", lens_center)
	view.call("_update_target_visuals")
	var main_sprite := view.get("main_sprite") as TextureRect
	if main_sprite != null:
		print("SIRIUS SPRITE position=", main_sprite.position, " size=", main_sprite.size, " scale=", main_sprite.scale)

	var target_focus := float(view.get("target_focus_value"))
	var tolerance := maxf(float(view.get("focus_tolerance")), 0.025)
	var far_value := clampf(target_focus + 0.32, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.24:
		far_value = clampf(target_focus - 0.32, 0.0, 1.0)
	await _set_focus_and_capture(far_value, "01_sirius_severe_defocus.png")

	var near_value := clampf(target_focus + tolerance * 1.35, 0.0, 1.0)
	if absf(near_value - target_focus) < tolerance:
		near_value = clampf(target_focus - tolerance * 1.35, 0.0, 1.0)
	await _set_focus_and_capture(near_value, "02_sirius_near_focus.png")
	await _set_focus_and_capture(target_focus, "03_sirius_sharp_focus.png")

	current_scene = null
	view.queue_free()
	await process_frame
	print("SIRIUS SHARED FOCUS CAPTURES %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT)
	])
	quit(0 if failures == 0 else 1)


func _set_focus_and_capture(value: float, file_name: String) -> void:
	view.call("_set_focus_value", value)
	await _settle(0.25)
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
		print("CAPTURE ", path, " focus=", value, " error=", view.get("focus_error"))


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
