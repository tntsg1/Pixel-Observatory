extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_science_product"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var game_manager := root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.progress["language_mode"] = "zh"
	game_manager.debug_jump_to_level(85, true)
	var model := RadioSignalModel.new()
	model.configure({
		"target_id": "pulsar_b0329",
		"kind": "pulsar",
		"period_ms": 714.5,
		"dm": 26.8,
		"center_mhz": 1250.0,
		"bandwidth_mhz": 90.0,
	})
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(240.0)
	var product := model.science_product(48, 12)
	game_manager.last_learning_card = {
		"object": game_manager.get_object(game_manager.current_target_object_id()),
		"level": game_manager.current_level(),
		"observation": {
			"success": true,
			"quality": "Excellent",
			"observation_mode": "radio",
			"radio_target_kind": "pulsar",
			"pulse_period_ms": 714.5,
			"dispersion_measure": 26.8,
			"snr": model.fold_snr(),
			"integration_s": 240.0,
			"rfi_cleared": int(product.get("removed_rfi_count", 0)),
			"raw_rfi_count": int(product.get("raw_rfi_count", 0)),
			"pulse_width_ms": float(product.get("pulse_width_ms", 0.0)),
			"duty_cycle_percent": float(product.get("duty_cycle_percent", 0.0)),
			"confidence": float(product.get("confidence", 0.0)),
			"pointing_quality": float(product.get("pointing_quality", 0.0)),
			"tuning_quality": float(product.get("tuning_quality", 0.0)),
			"report_conclusion": "stable_pulsar",
			"radio_data_product": product,
		},
		"stats": {},
		"concept_card": {},
		"reward_summary": {"credits_awarded": 190},
	}
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	if teaching != null:
		teaching.active_card_mode = "complete"
	var packed_scene := load("res://scenes/learning_card.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(12):
		await process_frame
	await create_timer(0.5).timeout
	var image := root.get_texture().get_image()
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/fast_mission_complete_radio_record_1024x768.png"))
	print("FAST MISSION COMPLETE CAPTURE %s" % ("PASS" if result == OK else "FAIL"))
	quit(0 if result == OK else 1)
