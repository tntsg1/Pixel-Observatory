extends SceneTree

const OUTPUT := "res://artifacts/optical_lens_effect"

var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(14, true)
	if not gm.progress["unlocked_parts"].has("basic_finder_scope"):
		gm.progress["unlocked_parts"].append("basic_finder_scope")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		gm.install_part(part_type, 0)
	await _capture_search_modes()
	await _capture_detailed_scope()
	await _capture_averted_scope()
	print("OPTICAL LENS CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _capture_search_modes() -> void:
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	# This capture tests optics, not the below-horizon teaching route.
	view.set("location_transition_active", true)
	await _settle(0.25)
	var target_id := str(view.get("target_id"))
	var sky_data: Dictionary = view.get("sky_data")
	var target: Dictionary = sky_data.get(target_id, {}).duplicate(true)
	target["azimuth"] = 180.0
	target["altitude"] = 45.0
	target["source"] = "optical_acceptance"
	sky_data[target_id] = target
	view.set("sky_data", sky_data)
	for spec in [["naked_eye", "01_eye_full_colour.png"], ["finder", "02_finder_full_colour.png"], ["telescope", "03_scope_search_full_colour.png"]]:
		view.set("telescope_azimuth", 180.0)
		view.set("display_azimuth", 180.0)
		view.set("telescope_altitude", 45.0)
		view.set("display_altitude", 45.0)
		view.call("_set_view_mode", str(spec[0]))
		view.call("_rebuild_view")
		await _settle(0.16)
		_save(str(spec[1]))
	view.queue_free()
	await process_frame


func _capture_detailed_scope() -> void:
	gm.selected_object_id = "jupiter"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.28)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	await _settle(0.12)
	view.set("focus_guide_active", false)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	var guide_text := view.get("focus_guide_text") as Control
	if guide_text != null:
		guide_text.visible = false
	_save("04_detailed_telescope_full_colour.png")
	view.queue_free()
	await process_frame


func _capture_averted_scope() -> void:
	gm.debug_jump_to_level(31, true)
	gm.selected_object_id = "sombrero_galaxy"
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		var seen: Dictionary = feedback.get("_tutorial_seen")
		seen["first_averted_vision"] = true
		seen["first_earth_drift"] = true
		seen["first_focus_control"] = true
		feedback.set("_tutorial_seen", seen)
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.28)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	await _settle(0.12)
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)
	var optimal: float = view.get("target_focus_value")
	if bool(view.get("requires_focus")):
		view.call("_set_focus_value", optimal)
	Input.action_press("dodge")
	await _settle(0.62)
	_save("05_averted_vision_hold_progress.png")
	await _settle(0.72)
	_save("06_averted_vision_confirmed_feather.png")
	Input.action_release("dodge")

	view.call("_set_focus_value", clampf(optimal + 0.42, 0.0, 1.0))
	await _settle(0.12)
	_save("07_sombrero_continuous_defocus.png")
	view.queue_free()
	await process_frame


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
