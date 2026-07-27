extends SceneTree

const OUTPUT_DIR := "res://artifacts/stage_handoff"

var finished := false


func _initialize() -> void:
	var watchdog := create_timer(28.0)
	watchdog.timeout.connect(func() -> void:
		if finished:
			return
		push_error("STAGE HANDOFF CAPTURE TIMEOUT")
		quit(2)
	)
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_fast()
	await _capture_space()
	finished = true
	print("STAGE HANDOFF CAPTURE PASS")
	quit(0)


func _capture_fast() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(76, true)
	gm.set_tutorial_assistance_mode(gm.TUTORIAL_ASSIST_FREE)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.12).timeout
	if bool(scene.get("intro_running")):
		scene.call("_finish_array_takeover")
		await process_frame
	var radio_model: RadioSignalModel = scene.get("model")
	radio_model.azimuth = radio_model.true_azimuth
	radio_model.altitude = radio_model.true_altitude
	radio_model.az_velocity = 0.0
	radio_model.alt_velocity = 0.0
	radio_model.cable_tension = 0.31
	scene.call("_advance", 1)
	await process_frame
	await _shot("fast_aim_to_tune_01_commit.png")
	await create_timer(0.46).timeout
	await _shot("fast_aim_to_tune_02_packet.png")
	await create_timer(0.62).timeout
	await _shot("fast_aim_to_tune_03_acquire.png")

	radio_model.window_center_mhz = radio_model.true_center_mhz
	radio_model.window_bandwidth_mhz = radio_model.true_bandwidth_mhz
	scene.call("_advance", 2)
	await process_frame
	await _shot("fast_tune_to_rfi_01_commit.png")
	await create_timer(0.46).timeout
	await _shot("fast_tune_to_rfi_02_packet.png")
	await create_timer(0.62).timeout
	await _shot("fast_tune_to_rfi_03_acquire.png")
	scene.queue_free()
	await process_frame


func _capture_space() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(66, true)
	gm.set_tutorial_assistance_mode(gm.TUTORIAL_ASSIST_FREE)
	var scene: Control = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(1.14).timeout
	scene.set("stages", ["plan", "thermal", "guide", "wavefront", "expose", "process", "filter", "report"])
	scene.set("stage", 3)
	scene.set("furthest_stage", 3)
	var space_model: SpaceObservationModel = scene.get("model")
	space_model.wavefront_error_nm = 138.0
	space_model.segment_alignment = 0.93
	scene.call("_rebuild")
	await process_frame
	scene.call("_advance")
	await process_frame
	await _shot("space_align_to_expose_01_commit.png")
	await create_timer(0.46).timeout
	await _shot("space_align_to_expose_02_packet.png")
	await create_timer(0.62).timeout
	await _shot("space_align_to_expose_03_acquire.png")
	scene.queue_free()
	await process_frame


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR + "/" + file_name)
	if error != OK:
		push_error("Could not save %s (%s)" % [file_name, error_string(error)])
