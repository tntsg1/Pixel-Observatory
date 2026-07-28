extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_science_product"

var game_manager: Node
var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	game_manager = root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("FAST science-product capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_result(true, "success_report_1024x768.png")
	await _capture_result(false, "wrong_period_report_1024x768.png")
	print("FAST SCIENCE PRODUCT CAPTURE %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _capture_result(correct_period: bool, file_name: String) -> void:
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.progress["language_mode"] = "zh"
	game_manager.debug_jump_to_level(85, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(8):
		await process_frame
	var model: RadioSignalModel = scene.get("model")
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms if correct_period else model.true_period_ms + 34.0
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)
	scene.set("intro_running", false)
	scene.set("stage", 4)
	scene.set("prediction_confirmed", correct_period)
	scene.call("_rebuild")
	await process_frame
	await process_frame
	scene.call("_finish_report_analysis")
	if correct_period:
		scene.set("report_choice", "stable_pulsar")
	else:
		scene.set("report_choice", "insufficient_signal")
	scene.call("_refresh_report_choice")
	await create_timer(0.25).timeout
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		failures += 1
		push_error("Could not save FAST science-product capture: %s" % output_path)
	scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
