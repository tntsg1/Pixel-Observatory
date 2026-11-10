extends SceneTree

const OUTPUT_DIR := "res://artifacts/ui_style_followup"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var game_manager := root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("GameManager is unavailable")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.progress["language_mode"] = "zh"
	game_manager.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1"]

	var graduation := (load("res://scenes/study_graduation.tscn") as PackedScene).instantiate()
	root.add_child(graduation)
	current_scene = graduation
	await _settle()
	if not _save("01_study_graduation_zh_1024x768.png"):
		quit(1)
		return
	graduation.queue_free()
	current_scene = null
	await process_frame

	game_manager.world_map_target_id = game_manager.current_target_object_id()
	var world_map := (load("res://scenes/world_map.tscn") as PackedScene).instantiate()
	root.add_child(world_map)
	current_scene = world_map
	await process_frame
	world_map.call("_skip_animation")
	await _settle()
	if not _save("02_world_map_zh_1024x768.png"):
		quit(1)
		return
	print("UI STYLE FOLLOW-UP CAPTURE PASS")
	quit(0)


func _settle() -> void:
	for _frame in range(12):
		await process_frame
	await create_timer(0.12).timeout


func _save(file_name: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Viewport image unavailable: " + file_name)
		return false
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save " + output)
		return false
	print("CAPTURE " + output)
	return true
