extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_pulse_capture"

var game_manager: Node
var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	game_manager = root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("FAST pulse capture screenshots require GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	await _capture_state("01_initial_noise.png", "initial")
	await _capture_state("02_dm_near_alignment.png", "dm_near")
	await _capture_state("03_half_period_false_solution.png", "half_period")
	await _capture_state("04_three_window_candidate_lock.png", "locked")

	print("FAST PULSE CAPTURE SCREENSHOTS %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _capture_state(file_name: String, state: String) -> void:
	var scene := await _open_scene()
	var model: RadioSignalModel = scene.get("model")
	_prepare_science_chain(model)
	scene.set("stage", 3)

	match state:
		"initial":
			model.trial_dm = model.true_dm + 9.0
			model.trial_period_ms = model.true_period_ms * 1.035
			model.trial_phase = fposmod(model.true_phase + 0.31, 1.0)
			model.set_integration(model.required_integration_s * 0.12)
		"dm_near":
			model.trial_dm = model.true_dm + 0.85
			model.trial_period_ms = model.true_period_ms * 1.012
			model.trial_phase = fposmod(model.true_phase + 0.08, 1.0)
			model.set_integration(model.required_integration_s * 0.42)
		"half_period":
			model.trial_dm = model.true_dm
			model.trial_period_ms = model.true_period_ms * 0.5
			model.trial_phase = model.true_phase
			model.set_integration(model.required_integration_s * 0.72)
		"locked":
			model.trial_dm = model.true_dm
			model.trial_period_ms = model.true_period_ms
			model.trial_phase = model.true_phase
			model.set_integration(model.required_integration_s)

	scene.call("_rebuild")
	if state == "locked":
		scene.call("_reset_fold_capture_validation", false)
		for _window in range(3):
			scene.call("_record_fold_validation_window")
		scene.call("_refresh_fold")
	await _settle()
	_save(file_name)
	scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _open_scene() -> Control:
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.progress["language_mode"] = "zh"
	game_manager.debug_jump_to_level(85, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _settle()
	return scene


func _prepare_science_chain(model: RadioSignalModel) -> void:
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.28).timeout


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var texture := root.get_texture()
	if texture == null:
		failures += 1
		push_error("Viewport texture unavailable: " + path)
		return
	var image := texture.get_image()
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
