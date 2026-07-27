extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_feed_geometry"

var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST feed capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_target(79, "01_pulsar_b0329_feed_projection.png", false)
	await _capture_target(85, "02_discovery_target_feed_projection.png", false)
	await _capture_target(79, "03_ten_second_cable_pulse.png", true)
	print("FAST FEED GEOMETRY CAPTURE PASS")
	quit(0)


func _capture_target(level_number: int, file_name: String, show_disturbance: bool) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(level_number, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.call("_finish_array_takeover")
	var model: RadioSignalModel = scene.get("model")
	if show_disturbance:
		model.aim_disturbance_timer_s = 0.02
		model.step(0.04)
	scene.call("_refresh_aim")
	await process_frame
	await create_timer(0.35).timeout
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save " + output)
	else:
		print("CAPTURE ", output)
	scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
