extends SceneTree

const OUTPUT := "res://artifacts/optical_focus_contrast"

var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(35, true)
	gm.set_collimation_score(100.0)
	_suppress_tutorials()

	await _capture("01_ring_nebula_severe_defocus.png", "far")
	await _capture("02_ring_nebula_near_focus.png", "near")
	await _capture("03_ring_nebula_sharp.png", "sharp")
	print("OPTICAL FOCUS CONTRAST CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _capture(file_name: String, state: String) -> void:
	gm.selected_object_id = "ring_nebula"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.24)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	view.set("focus_guide_active", false)
	view.set("dark_adaptation", 1.0)
	view.set("active_filter", "nebula")
	view.set("drift_enabled", false)
	view.set("drift_offset", Vector2.ZERO)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	var target := float(view.get("target_focus_value"))
	var tolerance := maxf(float(view.get("focus_tolerance")), 0.025)
	match state:
		"far":
			view.call("_set_focus_value", clampf(target + 0.30, 0.0, 1.0))
		"near":
			view.call("_set_focus_value", clampf(target + tolerance * 1.45, 0.0, 1.0))
		_:
			view.call("_set_focus_value", target)
	await _settle(0.32)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
	view.queue_free()
	await process_frame


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in [
		"first_focus_control",
		"first_averted_vision",
		"first_earth_drift",
		"focus_novice_guide",
	]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame
