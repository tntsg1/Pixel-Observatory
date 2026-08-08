extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	_test_science_product_inputs()
	await _test_report_layout()
	print("FAST SCIENCE PRODUCT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _configured_model() -> RadioSignalModel:
	var model := RadioSignalModel.new()
	model.configure({
		"target_id": "pulsar_b0329",
		"kind": "pulsar",
		"azimuth": 145.0,
		"altitude": 52.0,
		"period_ms": 714.5,
		"dm": 26.8,
		"center_mhz": 1250.0,
		"bandwidth_mhz": 90.0,
		"required_integration_s": 180.0,
	})
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	return model


func _solve_rfi(model: RadioSignalModel) -> void:
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))


func _test_science_product_inputs() -> void:
	var correct := _configured_model()
	correct.azimuth = correct.true_azimuth
	correct.altitude = correct.true_altitude
	correct.az_velocity = 0.0
	correct.alt_velocity = 0.0
	_solve_rfi(correct)
	correct.trial_period_ms = correct.true_period_ms
	correct.trial_dm = correct.true_dm
	correct.trial_phase = correct.true_phase
	correct.set_integration(240.0)
	var correct_product := correct.science_product(48, 18)

	var wrong_period := _configured_model()
	wrong_period.azimuth = wrong_period.true_azimuth
	wrong_period.altitude = wrong_period.true_altitude
	_solve_rfi(wrong_period)
	wrong_period.trial_period_ms = wrong_period.true_period_ms + 34.0
	wrong_period.trial_dm = wrong_period.true_dm
	wrong_period.set_integration(240.0)
	var wrong_product := wrong_period.science_product(48, 18)
	_check(
		float(correct_product.get("period_quality", 0.0)) > float(wrong_product.get("period_quality", 0.0)),
		"correct period produces a stronger period-quality result"
	)
	_check(
		_profile_peak_concentration(correct_product.get("folded_two_cycles", []))
			> _profile_peak_concentration(wrong_product.get("folded_two_cycles", [])),
		"wrong period visibly splits or spreads the two-cycle folded profile"
	)

	var dirty := _configured_model()
	dirty.azimuth = dirty.true_azimuth
	dirty.altitude = dirty.true_altitude
	dirty.trial_period_ms = dirty.true_period_ms
	dirty.trial_dm = dirty.true_dm
	dirty.set_integration(240.0)
	var dirty_product := dirty.science_product(48, 18)
	_check(
		_spectrum_energy(dirty_product.get("raw_spectrum", []))
			> _spectrum_energy(correct_product.get("clean_spectrum", [])),
		"RFI cleaning lowers structured contamination energy"
	)
	_check(
		int(correct_product.get("removed_rfi_count", 0)) > int(dirty_product.get("removed_rfi_count", 0)),
		"science product records the number of rejected RFI features"
	)

	var low_aim := _configured_model()
	low_aim.azimuth = low_aim.true_azimuth + 16.0
	low_aim.altitude = low_aim.true_altitude - 8.0
	_solve_rfi(low_aim)
	low_aim.trial_period_ms = low_aim.true_period_ms
	low_aim.trial_dm = low_aim.true_dm
	low_aim.set_integration(240.0)
	var low_aim_product := low_aim.science_product(48, 18)
	_check(
		float(correct_product.get("pointing_quality", 0.0)) > float(low_aim_product.get("pointing_quality", 0.0)),
		"low pointing quality remains visible in the evidence chain"
	)
	_check(
		float(correct_product.get("confidence", 0.0)) > float(low_aim_product.get("confidence", 0.0)),
		"high-quality pointing produces a more credible final data product"
	)
	_check(
		(correct_product.get("raw_spectrum", []) as Array).size() == 18
			and ((correct_product.get("raw_spectrum", []) as Array)[0] as Array).size() == 48,
		"waterfall dimensions are deterministic and data-driven"
	)


func _test_report_layout() -> void:
	var game_manager := root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		_check(false, "GameManager is available for report layout validation")
		return
	game_manager.new_game()
	game_manager.debug_jump_to_level(85, true)
	var scene: Node = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	for _frame in range(8):
		await process_frame
	scene.set("intro_running", false)
	scene.set("stage", 4)
	var model: RadioSignalModel = scene.get("model")
	# Regression fixture from the production L85 dead end: the old Fold stage
	# accepted three captures at these approximate values, but Report required
	# the stricter profile thresholds, leaving every conclusion invalid.
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	_solve_rfi(model)
	model.trial_period_ms = 702.0
	model.trial_dm = 23.5
	model.trial_phase = model.true_phase
	scene.call("_sync_fold_capture_state")
	_check(not bool(scene.call("_fold_capture_available")), "L85 blocks the former 702 ms / DM 23.5 report dead end before capture")
	_check(str(scene.call("_current_fold_adjust_parameter")) in ["period", "dm"], "L85 names the remaining calibration instead of exposing an invalid report")

	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	_solve_rfi(model)
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)
	_check(bool(model.report().get("success", false)), "fully aligned L85 evidence satisfies the same thresholds used by Fold")
	_check(model.evaluate_conclusion("stable_pulsar"), "fully aligned L85 evidence accepts the stable-pulsar conclusion")
	scene.call("_rebuild")
	for _frame in range(5):
		await process_frame
	var report_plot: Node = scene.get_node_or_null("FastStageWorkspace_report/FastScienceProductPlot")
	if report_plot == null:
		report_plot = _find_named(scene, "FastScienceProductPlot")
	_check(report_plot != null, "report creates the full FAST science-product plot")
	if report_plot != null:
		_check((report_plot as Control).size.x >= 570.0, "science-product plot is wide enough for a readable waterfall")
	var choices: Dictionary = scene.get("report_choice_buttons")
	_check(choices.size() == 3, "report keeps three evidence-based conclusions")
	var submit := scene.get("submit_button") as Button
	_check(submit != null and submit.disabled, "report cannot be submitted before analysis and a conclusion")
	var skip := scene.get("report_analysis_skip_button") as Button
	_check(skip != null and skip.disabled, "analysis cannot be skipped during its first second")
	scene.call("_advance_report_analysis", 1.05)
	_check(skip != null and not skip.disabled, "analysis becomes skippable after the protected first second")
	scene.call("_finish_report_analysis")
	await process_frame
	for choice in choices.values():
		_check(not (choice as Button).disabled, "analysis completion unlocks conclusion review")
		_check((choice as Button).text.begins_with("○"), "unselected conclusions use a visible shape marker")
	var stable_choice := choices.get("stable_pulsar") as Button
	_check(stable_choice != null, "pulsar report exposes the stable-candidate conclusion")
	if stable_choice != null:
		stable_choice.grab_focus()
		stable_choice.emit_signal("pressed")
		await process_frame
		_check(str(scene.get("report_choice")) == "stable_pulsar", "keyboard-focused conclusion activates the selected evidence ID")
		_check(stable_choice.text.begins_with("✓"), "selected conclusion has a stable check marker")
		_check(not submit.disabled, "Archive activates only after an explicit conclusion")
		for key in choices:
			if str(key) != "stable_pulsar":
				_check((choices[key] as Button).text.begins_with("○"), "other conclusions remain visibly unselected")
	_check(scene.get("report_reanalyse_button") != null, "report exposes a reanalysis route")
	scene.set("stage_transition_active", true)
	scene.call("_reanalyse_report")
	_check(str(scene.get("report_choice")) == "stable_pulsar", "blocked reanalysis cannot silently reset a selected conclusion")
	scene.set("stage_transition_active", false)
	scene.call("_reset_report_choice")
	_check(str(scene.get("report_choice")).is_empty(), "reanalysis resets the previous conclusion")
	_check(submit.disabled, "Archive returns to disabled after reanalysis reset")
	var free_started: bool = game_manager.begin_remote_free_observation("radio", "pulsar_clock")
	_check(free_started, "unlocked FAST catalog can enter free observation from the report test")
	scene.call("_rebuild")
	await process_frame
	scene.call("_finish_report_analysis")
	var next_target := scene.get("report_next_target_button") as Button
	_check(next_target != null, "free FAST report exposes an in-console next-target action")
	scene.set("report_choice", "stable_pulsar")
	scene.call("_refresh_report_choice")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		feedback.call("set_reduced_motion", true)
	scene.call("_archive_and_choose_next_target")
	await create_timer(0.18).timeout
	_check(bool(scene.get("acquisition_active")), "next target returns to FAST beam acquisition without leaving the instrument")
	if feedback != null:
		feedback.call("set_reduced_motion", false)
	scene.queue_free()
	await process_frame


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


func _profile_peak_concentration(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var peak := 0.0
	var energy := 0.0
	for value in values:
		var sample := maxf(float(value), 0.0)
		peak = maxf(peak, sample)
		energy += sample
	return peak / maxf(energy, 0.001)


func _spectrum_energy(rows: Array) -> float:
	var energy := 0.0
	for row_value in rows:
		for value in row_value as Array:
			energy += maxf(float(value) - 0.08, 0.0)
	return energy


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  PASS: %s" % description)
	else:
		failures += 1
		push_error("  FAIL: %s" % description)
