extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_layout_zh"

var gm: Node
var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST Chinese layout capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene := await _open_scene()
	var model := scene.get("model") as RadioSignalModel
	_prepare_model(model)
	for stage_index in range(5):
		scene.set("stage", stage_index)
		if stage_index == 3:
			scene.set("fold_step", 1)
		if stage_index == 4:
			scene.set("prediction_confirmed", true)
			scene.set("report_choice", "stable_pulsar")
		scene.call("_rebuild")
		await process_frame
		await process_frame
		await create_timer(0.12).timeout
		if stage_index == 1:
			scene.call("_radio_operation_chain", "锁定馈源舱", "运动速度收束，缆索张力稳定", "接收机现在可以搜索射电频段")
			await create_timer(0.18).timeout
			_save("02_tune_operation_feedback.png")
		elif stage_index == 3:
			scene.call("_radio_operation_chain", "删除人造射频干扰", "规律污染峰消失，天体频段保留", "剩余时间序列可以寻找重复周期")
			await create_timer(0.18).timeout
			_save("04_fold_operation_feedback.png")
		else:
			_save("%02d_%s.png" % [stage_index + 1, ["aim", "tune", "rfi", "fold", "report"][stage_index]])
	scene.queue_free()
	await process_frame
	print("FAST CHINESE LAYOUT CAPTURE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _open_scene() -> Control:
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["tutorial_assistance"] = "free"
	gm.debug_jump_to_level(85, true)
	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	scene.call("_finish_array_takeover")
	await process_frame
	return scene


func _prepare_model(model: RadioSignalModel) -> void:
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for i in range(model.rfi_peaks.size()):
		model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)


func _save(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		failures += 1
		push_error("Viewport texture unavailable for " + file_name)
		return
	var image := texture.get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name))
	if error != OK:
		failures += 1
		push_error("Could not save " + file_name)
