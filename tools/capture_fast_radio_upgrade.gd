extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_radio_upgrade"

var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST capture requires GameManager.")
		quit(1)
		return
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		feedback.set("guidance_highlights", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_array_takeover()
	await _capture_aim_inertia()
	await _capture_rfi_cleanup()
	await _capture_fold_discovery()
	await _capture_first_pulse()
	await _capture_report()
	await _capture_report_chinese()
	print("FAST RADIO VISUAL CAPTURE PASS")
	quit(0)


func _open_level(level_number: int) -> Control:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(level_number, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _settle()
	return scene


func _capture_array_takeover() -> void:
	var scene := await _open_level(76)
	await create_timer(1.45).timeout
	_save("00_array_takeover.png")
	await _remove_scene(scene)


func _capture_aim_inertia() -> void:
	var scene := await _open_level(79)
	var model: RadioSignalModel = scene.get("model")
	model.azimuth = model.true_azimuth - 3.2
	model.altitude = model.true_altitude + 2.4
	model.az_velocity = 2.15
	model.alt_velocity = -0.82
	for _i in range(5):
		model.step(0.06)
		scene.call("_record_aim_trail")
	scene.call("_refresh_aim")
	await process_frame
	_save("01_aim_inertia_and_cable_tension.png")
	await _remove_scene(scene)


func _capture_rfi_cleanup() -> void:
	var scene := await _open_level(83)
	var model: RadioSignalModel = scene.get("model")
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for i in range(model.rfi_peaks.size()):
		if i < 3:
			model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))
	scene.set("stage", 2)
	scene.set("selected_peak", min(3, model.rfi_peaks.size() - 1))
	scene.call("_rebuild")
	await create_timer(1.30).timeout
	_save("02_rfi_peak_cleanup.png")
	await _remove_scene(scene)


func _capture_fold_discovery() -> void:
	var scene := await _open_level(84)
	var model: RadioSignalModel = scene.get("model")
	_prepare_science_chain(model)
	model.trial_period_ms = model.true_period_ms + 2.0
	model.trial_dm = model.true_dm + 5.5
	model.set_integration(model.required_integration_s * 0.62)
	scene.set("stage", 3)
	scene.set("fold_step", 1)
	scene.call("_rebuild")
	await _settle()
	_save("03_fold_dm_alignment.png")
	await _remove_scene(scene)


func _capture_first_pulse() -> void:
	var scene := await _open_level(85)
	var model: RadioSignalModel = scene.get("model")
	_prepare_science_chain(model)
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.set_integration(model.required_integration_s)
	scene.set("stage", 3)
	scene.set("fold_step", 2)
	scene.call("_rebuild")
	await _settle()
	scene.call_deferred("_play_discovery_moment")
	await create_timer(1.72).timeout
	_save("03b_first_pulse.png")
	await create_timer(1.25).timeout
	await _remove_scene(scene)


func _capture_report() -> void:
	var scene := await _open_level(85)
	var model: RadioSignalModel = scene.get("model")
	_prepare_science_chain(model)
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.set_integration(model.required_integration_s)
	scene.set("stage", 4)
	scene.set("report_choice", "stable_pulsar")
	scene.call("_rebuild")
	await _settle()
	_save("04_evidence_report.png")
	await _remove_scene(scene)


func _capture_report_chinese() -> void:
	var scene := await _open_level(85)
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	var model: RadioSignalModel = scene.get("model")
	_prepare_science_chain(model)
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.set_integration(model.required_integration_s)
	scene.set("stage", 4)
	scene.set("report_choice", "stable_pulsar")
	scene.call("_rebuild")
	await _settle()
	_save("05_evidence_report_zh.png")
	await _remove_scene(scene)


func _prepare_science_chain(model: RadioSignalModel) -> void:
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for i in range(model.rfi_peaks.size()):
		model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.24).timeout


func _remove_scene(scene: Node) -> void:
	scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
