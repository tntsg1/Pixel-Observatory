extends SceneTree

const OUTPUT_DIR := "res://artifacts/world_map_site_registration"


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1"]
	gm.language_mode = "zh"
	gm.world_map_target_id = gm.current_target_object_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var map := (load("res://scenes/world_map.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await process_frame
	map.call("_skip_animation")
	await create_timer(0.35).timeout
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/all_observatories_registered.png")
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not capture " + output)
		quit(1)
		return
	print("CAPTURE ", output)
	quit(0)
