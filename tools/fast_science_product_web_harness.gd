extends Node


func _ready() -> void:
	await get_tree().process_frame
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		push_error("FAST web harness requires GameManager.")
		return
	game_manager.new_game()
	game_manager.language_mode = "zh"
	game_manager.progress["language_mode"] = "zh"
	game_manager.debug_jump_to_level(85, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	add_child(scene)
	for _frame in range(8):
		await get_tree().process_frame
	var signal_model: RadioSignalModel = scene.get("model")
	signal_model.azimuth = signal_model.true_azimuth
	signal_model.altitude = signal_model.true_altitude
	signal_model.az_velocity = 0.0
	signal_model.alt_velocity = 0.0
	signal_model.window_center_mhz = signal_model.true_center_mhz
	signal_model.window_bandwidth_mhz = signal_model.true_bandwidth_mhz
	for index in range(signal_model.rfi_peaks.size()):
		signal_model.classify(index, bool(signal_model.rfi_peaks[index].get("is_rfi", false)))
	signal_model.trial_period_ms = signal_model.true_period_ms
	signal_model.trial_dm = signal_model.true_dm
	signal_model.trial_phase = signal_model.true_phase
	signal_model.set_integration(signal_model.required_integration_s)
	scene.set("intro_running", false)
	scene.set("stage", 4)
	scene.set("prediction_confirmed", true)
	scene.call("_rebuild")
	await get_tree().process_frame
	scene.call("_finish_report_analysis")
	scene.set("report_choice", "stable_pulsar")
	scene.call("_refresh_report_choice")
