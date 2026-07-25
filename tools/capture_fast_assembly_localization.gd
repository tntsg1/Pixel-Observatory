extends SceneTree

const OUTPUT := "res://artifacts/localization/fast_assembly_complete_zh.png"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if gm == null:
		push_error("FAST assembly localization capture requires GameManager.")
		quit(1)
		return
	if feedback != null:
		feedback.set("guidance_highlights", true)
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.debug_jump_to_level(76, true)
	var plan: Array = gm.auto_equip_plan()
	gm.apply_auto_equip(plan)
	for entry_value in plan:
		var entry: Dictionary = entry_value
		gm.install_part(
			str(entry.get("part_type", "")),
			0,
			str(entry.get("part_id", ""))
		)
	if not gm.telescope_is_ready():
		push_error("FAST telescope did not become ready for capture.")
		quit(1)
		return
	gm.set_observatory_spawn("assembly")
	var room: Control = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	await process_frame
	room.call("_show_assembly_return_chain", "assembly")
	await create_timer(0.35).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/localization"))
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save FAST assembly localization capture.")
		quit(1)
		return
	print("CAPTURE ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)
