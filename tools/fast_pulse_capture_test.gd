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
	model.trial_dm += 0.25
	var dispersed_after_step: Array = model.subband_offsets(7)
	_check(not is_equal_approx(float(dispersed[0]), float(dispersed_after_step[0])),
		"even a far-out DM adjustment moves the visible sweep immediately")
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
	# Level 78 is the first mission that exposed the production 3/3 stall. All
	# later FAST missions share this state machine, so keep the regression pinned
	# to the earliest affected route.
	gm.debug_jump_to_level(78, true)
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
	var fold_guidance: Array[Dictionary] = scene.call("_tutorial_steps_for_stage")
	_check(fold_guidance.size() >= 4, "fold tutorial teaches period, DM, phase, and active pulse capture without a passive wait step")
	_check(str(fold_guidance[0].get("wait", "")) == "fold_period_adjust", "the first fold tutorial screen starts with period searching")
	_check(str(fold_guidance[1].get("wait", "")) == "fold_dm_adjust", "the second fold step requires dispersion alignment")
	_check(str(fold_guidance[2].get("wait", "")) == "fold_phase_adjust", "phase gate has its own visible guided action")
	_check(fold_guidance[0].get("target") == scene.fold_adjust_panel, "period-search guidance points at the explicit adjustment console")
	scene.call("_refresh_fold")
	_check(scene.fold_action_button.disabled, "pulse capture stays disabled until DM, period and phase are physically aligned")
	scene.tutorial_active = true
	scene.status_label.text = "GUIDED STEP MUST REMAIN VISIBLE"
	scene.call("_refresh_fold")
	_check(scene.status_label.text == "GUIDED STEP MUST REMAIN VISIBLE", "live fold refresh does not overwrite the active tutorial instruction")
	scene.tutorial_active = false

	_check(scene.scope.mouse_filter == Control.MOUSE_FILTER_STOP, "science plot accepts explicit direct-manipulation drags")
	_check(scene.fold_adjust_minus_button != null and scene.fold_adjust_plus_button != null, "capture desk exposes two large holdable adjustment keys")
	_check(str(scene.call("_current_fold_adjust_parameter")) == "period", "capture desk initially exposes only period searching")
	var period_before := model.trial_period_ms
	var profile_before: Array = scene.call("_fold_display_profile")
	scene.call("_apply_fold_adjust_step", "period", 1.0)
	_check(model.trial_period_ms > period_before, "holding the visible plus control changes the active scientific parameter")
	_check(scene.fold_control_response_serial == 1, "a period press starts one immediate visual response")
	_check(scene.fold_control_response_progress > 0.0 and scene.fold_control_response_progress < 1.0,
		"the first rendered frame starts inside the response instead of waiting on a timer")
	var profile_visible: Array = scene.call("_fold_display_profile")
	var profile_after: Array = model.folded_profile_for_window(120, scene.fold_capture_count)
	_check(scene.fold_control_response_parameter == "period" and profile_visible.size() == profile_before.size(),
		"the first rendered frame binds the period response to the folded trace")
	_check(not is_equal_approx(float(profile_visible[0]), float(profile_after[0])) or scene.fold_control_response_progress < 1.0,
		"the period trace settles continuously instead of jumping to its final position")
	scene.call("_advance_fold_control_response", 0.2)
	_check(is_equal_approx(scene.fold_control_response_progress, 1.0),
		"the local receiver response settles within 140 ms")
	var period_after_first_step := model.trial_period_ms
	scene.call("_start_fold_adjust", 1.0)
	scene.call("_process_fold_adjust_controls", 0.2)
	scene.call("_stop_fold_button_adjust")
	_check(model.trial_period_ms > period_after_first_step, "holding a visible adjustment key repeats without waiting for release")
	_check(is_zero_approx(scene.fold_adjust_direction), "releasing the adjustment key stops continuous calibration immediately")

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
	model.trial_phase = fposmod(model.true_phase + 0.3, 1.0)
	scene.call("_refresh_fold")
	_check(str(scene.call("_current_fold_adjust_parameter")) == "phase", "period alignment naturally reveals arrival-phase control")
	model.trial_phase = model.true_phase
	model.set_integration(0.0)
	scene.call("_refresh_fold")
	_check(not scene.fold_action_button.disabled, "active pulse capture unlocks when the three calibration pictures agree")
	var normal_capture_window := float(scene.call("_fold_capture_window_phase"))
	gm.set_wide_pulse_capture_window(true)
	_check(float(scene.call("_fold_capture_window_phase")) > normal_capture_window, "wide capture setting expands the gate without auto-completing")
	gm.set_wide_pulse_capture_window(false)

	_check(scene.fold_slider == null and scene.fold_phase_slider == null, "capture desk no longer exposes answer sliders")
	_check(str(scene.call("_current_fold_adjust_parameter")) == "", "adjustment keys retire after DM, period and phase agree")

	# Edge-triggered keyboard input: a short press captures exactly once, while
	# repeat/long-hold events and a later release add nothing.
	scene.fold_capture_gate_phase = scene.call("_fold_capture_target_phase")
	var space_press := InputEventKey.new()
	space_press.keycode = KEY_SPACE
	space_press.pressed = true
	scene.call("_unhandled_input", space_press)
	_check(scene.fold_capture_count == 1, "one short Space press records capture 1/3")
	_check(model.integration_s > 0.0 and model.integration_s < model.required_integration_s, "one capture raises SNR without granting the whole integration")
	var key_repeat := InputEventKey.new()
	key_repeat.keycode = KEY_SPACE
	key_repeat.pressed = true
	key_repeat.echo = true
	scene.call("_unhandled_input", key_repeat)
	var key_release := InputEventKey.new()
	key_release.keycode = KEY_SPACE
	key_release.pressed = false
	scene.call("_unhandled_input", key_release)
	_check(scene.fold_capture_count == 1, "holding Space only records its first input edge")

	# A mistimed press gives an immediately directional reason but does not erase
	# the earlier recovery work.
	var target_phase := float(scene.call("_fold_capture_target_phase"))
	scene.fold_capture_gate_phase = fposmod(target_phase - 0.16, 1.0)
	scene.call("_attempt_fold_pulse_capture", "test_early")
	_check(scene.fold_capture_count == 1 and scene.fold_capture_feedback_kind == "early", "an early capture reports direction without clearing progress")
	scene.fold_capture_gate_phase = fposmod(target_phase + 0.16, 1.0)
	scene.call("_attempt_fold_pulse_capture", "test_late")
	_check(scene.fold_capture_count == 1 and scene.fold_capture_feedback_kind == "late", "a late capture reports direction without clearing progress")

	# Mouse uses the same function as Space. Focus changes do not create a stuck
	# key state because capture has no key-up dependency.
	target_phase = float(scene.call("_fold_capture_target_phase"))
	scene.fold_capture_gate_phase = target_phase
	scene.fold_action_button.emit_signal("pressed")
	_check(scene.fold_capture_count == 2, "main capture button records the same second capture as Space")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	target_phase = float(scene.call("_fold_capture_target_phase"))
	scene.fold_capture_gate_phase = target_phase
	# Regression: the fold stage must not depend on the final report's aggregate
	# SNR gate. Earlier production builds displayed 3/3 forever when that
	# unrelated flag was false.
	var original_report_threshold := model.report_snr_threshold
	model.report_snr_threshold = model.fold_snr() + 1000.0
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	var original_reduced_motion := bool(feedback.call("is_reduced_motion")) if feedback != null else false
	if feedback != null:
		feedback.call("set_reduced_motion", true)
	var recovered_focus_press := InputEventKey.new()
	recovered_focus_press.keycode = KEY_SPACE
	recovered_focus_press.pressed = true
	scene.call("_unhandled_input", recovered_focus_press)
	_check(scene.fold_capture_count == 3, "a new Space edge after focus loss completes the third capture")
	_check(not bool(model.report().get("success", false)), "regression fixture keeps the aggregate report flag false at capture 3/3")
	_check(scene.fold_candidate_ready, "three locally valid pulse captures unlock stage 4 independently of the final report gate")
	model.report_snr_threshold = original_report_threshold
	await process_frame
	_check(scene.fold_candidate_ready and scene.fold_lock_sequence_running, "three active captures immediately start the lock sequence with no extra confirmation")
	await create_timer(0.35).timeout
	_check(scene.prediction_running, "the lock sequence always opens the clock-verification step")
	_check(scene.find_child("PulsePredictionCapture", true, false) != null,
		"the next required action is visibly presented after capture 3/3")
	# Cancel the verification overlay so the remaining negative-path assertions
	# continue to exercise stage 3 in isolation.
	scene.prediction_running = false
	if scene.prediction_overlay != null and is_instance_valid(scene.prediction_overlay):
		scene.prediction_overlay.queue_free()
	scene.prediction_overlay = null
	if feedback != null:
		feedback.call("set_reduced_motion", original_reduced_motion)

	scene.call("_reset_fold_capture_validation", true)
	model.trial_period_ms = model.true_period_ms * 0.5
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	scene.call("_refresh_fold")
	_check(scene.fold_action_button.disabled, "a half-period alias cannot enable pulse capture")
	scene.call("_attempt_fold_pulse_capture", "bad_period")
	_check(scene.fold_capture_count == 0, "an unqualified parameter set cannot capture or auto-complete")

	gm.language_mode = "en"
	scene.call("_refresh_fold")
	_check(scene.fold_action_button.text.contains("SCAN") or scene.fold_action_button.text.contains("CAPTURE"), "English capture control remains compact")
	gm.language_mode = "zh"
	model.trial_period_ms = model.true_period_ms
	scene.call("_refresh_fold")
	_check(scene.fold_action_button.text.length() < 42, "Chinese capture control remains compact without overflow text")

	scene.queue_free()
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("release_transient_sfx"):
		audio.call("release_transient_sfx")
		await process_frame
	# The final lock cue is intentionally one-shot in the product.  Drain the
	# mixer before this short headless process exits so its decoder is released.
	await create_timer(0.12).timeout


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
