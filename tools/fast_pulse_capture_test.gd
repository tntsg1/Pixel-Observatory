extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	_test_signal_model()
	await _test_capture_desk()
	print("FAST PULSE CAPTURE TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _test_signal_model() -> void:
	var model := RadioSignalModel.new()
	model.configure({
		"target_id": "pulse_capture_test",
		"kind": "pulsar",
		"period_ms": 714.5,
		"dm": 26.8,
		"pulse_phase": 0.5,
	})

	model.trial_dm = 0.0
	var dispersed: Array = model.subband_offsets(7)
	_check(absf(float(dispersed[0]) - float(dispersed[-1])) > 0.2, "wrong DM leaves a visible sub-band slope")
	model.trial_dm = model.true_dm
	var aligned: Array = model.subband_offsets(7)
	_check(absf(float(aligned[0]) - float(aligned[-1])) < 0.01, "correct DM aligns all sub-bands")

	model.trial_period_ms = model.true_period_ms * 0.5
	_check(model.period_solution_state() == "half_period", "half-period false solution is identified")
	var half_profile: Array = model.folded_profile_for_window(128, 0)
	_check(_local_peak_count(half_profile) >= 2, "half-period false solution produces a split profile")

	model.trial_period_ms = model.true_period_ms * 2.0
	_check(model.period_solution_state() == "double_period", "double-period false solution is identified")
	var double_even := _profile_energy(model.folded_profile_for_window(128, 0))
	var double_odd := _profile_energy(model.folded_profile_for_window(128, 1))
	_check(double_odd < double_even, "double-period false solution visibly misses alternating beats")

	model.trial_period_ms = model.true_period_ms + 24.0
	var drift_a := model.folded_peak_phase(0)
	var drift_b := model.folded_peak_phase(1)
	var drift := absf(fposmod(drift_b - drift_a + 0.5, 1.0) - 0.5)
	_check(drift > 0.035, "wrong period drifts between consecutive windows")

	model.trial_period_ms = model.true_period_ms
	model.trial_phase = model.true_phase
	var stable_peak := model.folded_peak_phase(0)
	_check(model.candidate_window_is_stable(stable_peak, 1), "correct period and DM remain stable across windows")


func _test_capture_desk() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		return
	gm.new_game()
	gm.debug_jump_to_level(85, true)
	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	for _frame in range(4):
		await process_frame
	scene.call("_finish_array_takeover")
	scene.stage = 3
	scene.call("_reset_fold_capture_validation", true)
	scene.call("_rebuild")
	for _frame in range(3):
		await process_frame

	var model: RadioSignalModel = scene.model
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)

	_check(scene.fold_slider == null and scene.fold_phase_slider == null, "capture desk no longer exposes answer sliders")
	_check(scene.scope.mouse_filter == Control.MOUSE_FILTER_STOP, "science plot accepts direct pointer manipulation")

	scene.call("_record_fold_validation_window")
	_check(scene.fold_stable_windows == 1, "one coincident peak is not enough evidence")
	_check(not scene.fold_candidate_ready, "one window cannot unlock candidate confirmation")
	scene.call("_record_fold_validation_window")
	_check(not scene.fold_candidate_ready, "two windows still cannot unlock confirmation")
	scene.call("_record_fold_validation_window")
	_check(scene.fold_stable_windows == 3, "three coherent windows establish stability")
	_check(scene.fold_candidate_ready, "three coherent windows plus valid science evidence unlock confirmation")

	model.trial_period_ms = model.true_period_ms * 0.5
	scene.call("_fold_parameters_changed", "period")
	for _window in range(4):
		scene.call("_record_fold_validation_window")
	_check(scene.fold_stable_windows == 0, "half-period alias never counts as a stable fundamental")
	_check(not scene.fold_candidate_ready, "alias cannot unlock candidate confirmation")

	scene.queue_free()
	await process_frame


func _local_peak_count(values: Array) -> int:
	var count := 0
	for index in range(1, values.size() - 1):
		var value := float(values[index])
		if value > 0.12 and value > float(values[index - 1]) and value >= float(values[index + 1]):
			count += 1
	return count


func _profile_energy(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
