extends SceneTree

const OUTPUT_DIR := "res://artifacts/cluster_starfield_focus"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("GameManager autoload is missing")
		quit(1)
		return

	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(4, true)
	gm.selected_object_id = "double_cluster"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	for index in range(3):
		await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	var target := float(view.get("target_focus_value"))
	var far_value := clampf(target + 0.30, 0.0, 1.0)
	if absf(far_value - target) < 0.20:
		far_value = clampf(target - 0.30, 0.0, 1.0)
	await _capture_focus(view, far_value, "01_double_cluster_defocused.png")
	await _capture_focus(view, target, "02_double_cluster_focused.png")
	quit(0)


func _capture_focus(view: Control, value: float, file_name: String) -> void:
	view.call("_set_focus_value", value)
	view.call("_advance_visual_smoothing", 1.0)
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
