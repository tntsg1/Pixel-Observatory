extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_rfi_guidance"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST RFI capture requires GameManager.")
		quit(1)
		return
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	var tutorial_seen_before: Dictionary = {}
	if feedback != null:
		tutorial_seen_before = feedback.get("_tutorial_seen").duplicate(true)
		feedback.set("guidance_highlights", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["tutorial_assistance"] = "full"
	gm.debug_jump_to_level(83, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.set("stage", 2)
	scene.call("_rebuild")
	await process_frame
	var keep_button := scene.get("rfi_keep_button") as Button
	var actions := keep_button.get_parent_control()
	if scene.get("rfi_tutorial_panel") == null:
		scene.call("_show_rfi_tutorial", actions)
	await create_timer(0.4).timeout
	_save("01_maya_rfi_tutorial_zh.png")

	while scene.get("rfi_tutorial_panel") != null:
		scene.call("_advance_rfi_tutorial")
		await process_frame
	var model: RadioSignalModel = scene.get("model")
	for i in range(mini(3, model.rfi_peaks.size())):
		scene.set("selected_peak", i)
		scene.call("_classify_selected", bool(model.rfi_peaks[i].get("is_rfi", false)))
		await create_timer(0.15).timeout
	scene.set("selected_peak", 0)
	scene.call("_refresh_rfi")
	await create_timer(0.55).timeout
	_save("02_rfi_state_colours_zh.png")
	if feedback != null:
		feedback.set("_tutorial_seen", tutorial_seen_before)
		feedback.call("_save_settings")
	print("FAST RFI GUIDANCE CAPTURE PASS")
	quit(0)


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
