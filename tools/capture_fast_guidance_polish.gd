extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_guidance_polish"

var gm: Node
var feedback: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	feedback = root.get_node_or_null("/root/InteractionFeedback")
	if gm == null or feedback == null:
		push_error("FAST guidance capture requires GameManager and InteractionFeedback.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_aim_tutorial()
	await _capture_tune_tutorial()
	await _capture_rfi_recovery()
	await _capture_fold_tutorials()
	await _capture_first_pulse()
	await _capture_chinese_report()
	print("FAST GUIDANCE POLISH CAPTURE PASS")
	quit(0)


func _open(level_number: int, mode: String = "full", language: String = "en") -> Control:
	gm.new_game()
	gm.progress["tutorial_assistance"] = mode
	gm.language_mode = language
	gm.progress["language_mode"] = language
	gm.debug_jump_to_level(level_number, true)
	feedback.set("_tutorial_seen", {})
	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.call("_finish_array_takeover")
	await create_timer(0.28).timeout
	return scene


func _capture_aim_tutorial() -> void:
	var scene := await _open(79)
	var model := scene.get("model") as RadioSignalModel
	model.azimuth = model.true_azimuth - 3.4
	model.altitude = model.true_altitude + 2.2
	model.az_velocity = 1.8
	model.alt_velocity = -0.6
	scene.call("_record_aim_trail")
	scene.call("_refresh_aim")
	scene.call("_configure_stage_guidance")
	scene.call("_advance_fast_tutorial")
	await create_timer(0.18).timeout
	_save("01_aim_tutorial_500m.png")
	await _remove(scene)


func _capture_tune_tutorial() -> void:
	var scene := await _open(82)
	var model := scene.get("model") as RadioSignalModel
	_prepare_chain(model)
	model.window_center_mhz = model.true_center_mhz - 75.0
	model.window_bandwidth_mhz = model.true_bandwidth_mhz + 45.0
	scene.set("stage", 1)
	scene.call("_rebuild")
	await create_timer(0.24).timeout
	scene.call("_configure_stage_guidance")
	scene.call("_advance_fast_tutorial")
	await create_timer(0.18).timeout
	_save("02_tune_center_and_bandwidth_tutorial.png")
	await _remove(scene)


func _capture_rfi_recovery() -> void:
	var scene := await _open(83, "light")
	var model := scene.get("model") as RadioSignalModel
	_prepare_chain(model)
	scene.set("stage", 2)
	scene.call("_rebuild")
	await create_timer(0.24).timeout
	scene.set("selected_peak", 0)
	scene.call("_classify_selected", true)
	await create_timer(0.22).timeout
	_save("03_rfi_candidate_lost_restore_available.png")
	scene.call("_restore_raw_spectrum")
	await create_timer(0.22).timeout
	_save("04_rfi_raw_spectrum_restored.png")
	await _remove(scene)


func _capture_fold_tutorials() -> void:
	var scene := await _open(84)
	var model := scene.get("model") as RadioSignalModel
	_prepare_chain(model)
	model.trial_period_ms = model.true_period_ms + 18.0
	scene.set("stage", 3)
	scene.set("fold_step", 0)
	scene.call("_rebuild")
	await create_timer(0.24).timeout
	scene.call("_configure_stage_guidance")
	await create_timer(0.18).timeout
	_save("05_fold_period_tutorial.png")
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm + 7.0
	scene.set("fold_step", 1)
	scene.call("_rebuild")
	await create_timer(0.24).timeout
	scene.call("_configure_stage_guidance")
	await create_timer(0.18).timeout
	_save("06_fold_dm_tutorial.png")
	await _remove(scene)


func _capture_first_pulse() -> void:
	var scene := await _open(85, "free")
	var model := scene.get("model") as RadioSignalModel
	_prepare_chain(model)
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.set_integration(maxf(model.required_integration_s, 300.0))
	scene.set("stage", 3)
	scene.set("fold_step", 2)
	scene.call("_rebuild")
	await create_timer(0.24).timeout
	scene.call_deferred("_play_discovery_moment")
	await create_timer(1.18).timeout
	_save("07_first_pulse_alignment_keyframe.png")
	await create_timer(1.10).timeout
	await _remove(scene)


func _capture_chinese_report() -> void:
	var scene := await _open(85, "light", "zh")
	var model := scene.get("model") as RadioSignalModel
	_prepare_chain(model)
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.set_integration(maxf(model.required_integration_s, 300.0))
	scene.set("stage", 4)
	scene.set("report_choice", "stable_pulsar")
	scene.call("_rebuild")
	await create_timer(0.40).timeout
	_save("08_chinese_report_and_archive.png")
	await _remove(scene)


func _prepare_chain(model: RadioSignalModel) -> void:
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for i in range(model.rfi_peaks.size()):
		model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))


func _remove(scene: Node) -> void:
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
