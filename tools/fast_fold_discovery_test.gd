extends SceneTree

# Focused acceptance for FAST stage 4. It proves the playable discovery loop
# rather than only exercising the pure formulas: one input cannot skip the
# stage, bad aliases fail, direct manipulation responds, a trim recovers, and
# the exact measured packet reaches the report path.

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager is available")
		_finish()
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
	_prepare_chain(model)

	_check(str(scene.call("_current_fold_adjust_parameter")) == "period", "stage starts with a period search, not an answer slider")
	var initial_period := model.trial_period_ms
	scene.call("_apply_fold_adjust_step", "period", 1.0)
	_check(model.trial_period_ms > initial_period, "one period input immediately moves the trial clock")
	_check(scene.fold_control_response_serial == 1, "one input starts a visible correlation/fold response")
	_check(not scene.fold_candidate_ready and int(scene.stage) == 3, "one input cannot skip the discovery stage")

	var direct_period := model.trial_period_ms
	var belt_press := InputEventMouseButton.new()
	belt_press.button_index = MOUSE_BUTTON_LEFT
	belt_press.pressed = true
	belt_press.position = Vector2(28.0 + (scene.scope.size.x - 56.0) * 0.44, 62.0)
	scene.call("_fold_scope_input", belt_press)
	_check(not is_equal_approx(direct_period, model.trial_period_ms) and scene.fold_drag_mode == "period", "a real correlation-belt pointer press directly moves the candidate period")
	var belt_release := InputEventMouseButton.new()
	belt_release.button_index = MOUSE_BUTTON_LEFT
	belt_release.pressed = false
	belt_release.position = belt_press.position
	scene.call("_fold_scope_input", belt_release)
	_check(scene.fold_drag_mode == "", "releasing the scan belt ends its drag without changing stages")

	model.trial_period_ms = model.true_period_ms * 0.5
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)
	scene.call("_reset_fold_capture_validation", false)
	for _window in range(3):
		scene.call("_record_fold_validation_window")
	_check(not scene.fold_candidate_ready, "a half-period alias with a double-looking peak never completes")
	_check(scene.fold_stable_windows == 0, "wrong period leaves no false stable-window credit")

	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)
	scene.call("_reset_fold_capture_validation", false)
	scene.fold_monitor_phase_residual = 0.036
	scene.fold_stable_windows = 2
	scene.call("_apply_fold_adjust_step", "phase", -1.0)
	scene.call("_apply_fold_adjust_step", "phase", -1.0)
	_check(absf(scene.fold_monitor_phase_residual) <= scene.FOLD_MONITOR_TRIM_TOLERANCE, "a small phase trim clears the live clock drift")
	_check(scene.fold_stable_windows >= 1, "a recovery trim preserves evidence instead of clearing all progress")

	scene.call("_reset_fold_capture_validation", false)
	scene.fold_monitor_trim_completed = true
	for _window in range(3):
		scene.call("_record_fold_validation_window")
	_check(scene.fold_candidate_ready, "the correct period → DM → phase → stable-window flow completes")

	var packet: Dictionary = model.science_product(32, 10)
	var report: Dictionary = packet.get("report", {})
	var sky: Dictionary = report.get("sky_position", {})
	_check(is_equal_approx(float(report.get("trial_period_ms", 0.0)), model.trial_period_ms), "report period is the measured trial value")
	_check(is_equal_approx(float(report.get("trial_dm", 0.0)), model.trial_dm), "report DM is the measured trial value")
	_check(is_equal_approx(float(packet.get("confidence", 0.0)), float(report.get("confidence", 0.0))), "report and archive packet share one confidence value")
	_check(str(packet.get("candidate_model", "")) == str(report.get("candidate_model", "")) and not sky.is_empty(), "target model and sky position stay on the same data packet")

	model.trial_period_ms = model.true_period_ms * 0.8
	scene.call("_refresh_fold")
	gm.language_mode = "en"
	scene.call("_refresh_fold")
	_check(scene.fold_step_label.text.contains("FIND"), "English fold heading fits the four-step workflow")
	gm.language_mode = "zh"
	scene.call("_refresh_fold")
	_check(scene.fold_step_label.text.contains("找到"), "Chinese fold heading is localized without a separate state")

	# Restore the valid packet and verify the lock uses a bounded sequence before
	# the already-existing next-arrival test and report handoff.
	gm.language_mode = "en"
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)
	scene.call("_reset_fold_capture_validation", false)
	scene.fold_monitor_trim_completed = true
	for _window in range(3):
		scene.call("_record_fold_validation_window")
	scene.call("_confirm_fold")
	await create_timer(0.05).timeout
	_check(bool(scene.fold_lock_sequence_running) and scene.fold_confirm_button.disabled, "lock freeze replaces the confirmation control before the prediction handoff")
	await create_timer(0.72).timeout
	_check(bool(scene.prediction_running), "confirmed pulse uses a bounded lock sequence before the next-arrival proof")

	scene.queue_free()
	await process_frame
	_finish()


func _prepare_chain(model: RadioSignalModel) -> void:
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	print("FAST FOLD DISCOVERY TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
