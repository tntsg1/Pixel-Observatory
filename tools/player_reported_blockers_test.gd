extends SceneTree

var failures := 0
var gm: Node

func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	gm.language_mode = "zh"
	root.size = Vector2i(1024, 768)
	for n in [30, 39, 43]:
		gm.new_game()
		gm.debug_jump_to_level(n, true)
		gm.selected_object_id = gm.current_target_object_id()
		var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
		view.set("quiz_brief_dismissed", true)
		root.add_child(view)
		await process_frame
		view.set_process(false)
		_check(bool(view.call("_visual_detection_techniques_available")), "L%d required side vision is available" % n)
		view.set("dark_adaptation", 1.0)
		view.set("drift_offset", Vector2.ZERO)
		var shift := InputEventKey.new()
		shift.keycode = KEY_SHIFT
		shift.physical_keycode = KEY_SHIFT
		shift.pressed = true
		Input.parse_input_event(shift)
		Input.flush_buffered_events()
		_check(Input.is_key_pressed(KEY_SHIFT), "L%d physical Shift event reaches input state" % n)
		view.call("_advance_dark_adaptation", 0.0)
		view.call("_update_averted_vision_guide", 1.26)
		_check(bool(view.get("averted_vision_confirmed")), "L%d centered Shift hold confirms" % n)
		var evaluated: Dictionary = view.call("_evaluate")
		_check(str(evaluated.get("technique_failure", {}).get("code", "")) != "averted_vision", "L%d evaluator accepts confirmed side vision" % n)
		view.call("_set_focus_value", float(view.get("target_focus_value")))
		view.call("_refresh_focus_ui")
		await _capture("L%d-side-vision" % n)
		view.set("averted_vision_hold_seconds", 0.0)
		view.set("averted_vision_confirmed", false)
		view.set("drift_offset", Vector2(80, 0))
		view.call("_update_averted_vision_guide", 1.26)
		_check(not bool(view.get("averted_vision_confirmed")), "L%d off-center target cannot confirm" % n)
		var released: InputEventKey = shift.duplicate()
		released.pressed = false
		Input.parse_input_event(released)
		Input.flush_buffered_events()
		view.queue_free()
		await process_frame
	gm.new_game()
	gm.debug_jump_to_level(55, true)
	gm.selected_object_id = gm.current_target_object_id()
	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	view.set("quiz_brief_dismissed", true)
	root.add_child(view)
	await process_frame
	view.set_process(false)
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	view.set("drift_offset", Vector2.ZERO)
	view.set("target_off_center", false)
	view.set("observation", {"quality":"Good"})
	view.call("_update_secondary_visuals")
	var button: Button = view.get("secondary_button")
	_check(button != null and not button.disabled, "L55 usable field exposes clickable Triton")
	var hint: Label = view.get("secondary_hint_label")
	_check(hint.text.begins_with("海卫一：点击"), "L55 click instruction leads the visible hint")
	_check(hint.get_theme_font("font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x <= hint.size.x, "L55 full instruction fits without clipping")
	if button != null and not button.disabled:
		await _capture("L55-triton-click")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = button.get_global_rect().get_center()
		click.pressed = true
		root.push_input(click, true)
		click.pressed = false
		root.push_input(click, true)
	_check(gm.secondary_target_found(), "L55 clicking Triton records confirmation")
	view.queue_free()
	await process_frame
	for n in range(76, 86):
		gm.new_game()
		gm.debug_jump_to_level(n, true)
		var radio: Control = load("res://scenes/radio_observation.tscn").instantiate()
		root.add_child(radio)
		await process_frame
		radio.set_process(false)
		radio.call("_finish_array_takeover")
		radio.set("stage", 3)
		radio.call("_reset_fold_capture_validation", true)
		radio.call("_rebuild")
		var model: RadioSignalModel = radio.get("model")
		model.azimuth = model.true_azimuth
		model.altitude = model.true_altitude
		model.az_velocity = 0.0
		model.alt_velocity = 0.0
		model.window_center_mhz = model.true_center_mhz
		model.window_bandwidth_mhz = model.true_bandwidth_mhz
		# The source's nominal width is not necessarily a clean receiver window.
		# Search only settings available through the existing tuning controls.
		var best_quality := -1.0
		var best_center := model.true_center_mhz
		var best_bandwidth := 20.0
		for offset in range(-40, 41, 4):
			for bandwidth in range(20, 141, 5):
				model.window_center_mhz = model.true_center_mhz + float(offset)
				model.window_bandwidth_mhz = float(bandwidth)
				var quality := model.tuning_quality()
				if quality > best_quality:
					best_quality = quality
					best_center = model.window_center_mhz
					best_bandwidth = model.window_bandwidth_mhz
		model.window_center_mhz = best_center
		model.window_bandwidth_mhz = best_bandwidth
		_check(model.tuning_quality() >= 0.55, "L%d has a reachable clean receiver window" % n)
		for i in range(model.rfi_peaks.size()):
			model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))
		model.trial_period_ms = model.true_period_ms + (12.0 if n == 78 else 10.0 if n == 85 else 0.0)
		model.trial_dm = model.true_dm
		model.trial_phase = model.true_phase
		radio.set("fold_monitor_phase_residual", 0.0)
		radio.call("_sync_fold_capture_state")
		if n in [78, 85]:
			_check(str(radio.call("_current_fold_adjust_parameter")) == "period", "L%d report-failing fundamental period remains adjustable" % n)
			_check(not bool(radio.call("_fold_capture_available")), "L%d invalid period cannot begin captures" % n)
			for i in range(24):
				if str(radio.call("_current_fold_adjust_parameter")) != "period":
					break
				radio.call("_apply_fold_adjust_step", "period", -1.0)
		model.trial_period_ms = model.true_period_ms
		if n in [84, 85]:
			model.trial_dm = model.true_dm + 3.0
			radio.call("_sync_fold_capture_state")
			_check(str(radio.call("_current_fold_adjust_parameter")) == "dm", "L%d 75%% DM match remains adjustable until report threshold" % n)
			_check(not bool(radio.call("_fold_capture_available")), "L%d invalid DM cannot begin captures" % n)
			for i in range(12):
				if str(radio.call("_current_fold_adjust_parameter")) != "dm":
					break
				radio.call("_apply_fold_adjust_step", "dm", -1.0)
		model.trial_phase = model.true_phase + 0.075
		radio.set("fold_monitor_phase_residual", 0.01)
		radio.call("_sync_fold_capture_state")
		_check(str(radio.call("_current_fold_adjust_parameter")) == "phase", "L%d small residual cannot lock unusable phase controls" % n)
		_check(not bool(radio.call("_fold_capture_available")), "L%d effective phase must pass capture threshold" % n)
		model.trial_phase = model.true_phase + 0.09
		radio.set("fold_monitor_phase_residual", -0.09)
		radio.call("_sync_fold_capture_state")
		_check(not bool(radio.call("_fold_capture_available")), "L%d drift cancellation cannot bypass report phase threshold" % n)
		model.trial_phase = model.true_phase
		radio.set("fold_monitor_phase_residual", 0.0)
		radio.call("_sync_fold_capture_state")
		_check(bool(radio.call("_fold_capture_available")), "L%d corrected parameters permit capture" % n)
		for i in range(3):
			radio.set("fold_capture_gate_phase", radio.call("_fold_capture_target_phase"))
			radio.call("_attempt_fold_pulse_capture", "regression")
		_check(bool(radio.get("fold_candidate_ready")), "L%d three captures meet actual report conditions" % n)
		if not bool(radio.get("fold_candidate_ready")):
			print("REPORT_DIAGNOSTIC ", JSON.stringify(model.report()), " count=",radio.get("fold_capture_count")," feedback=",radio.get("fold_capture_hint")," integration=",model.integration_s," lock=",model.is_locked()," tuning=",model.tuning_quality()," dm=",model.dm_match())
		await process_frame
		_check(bool(radio.get("fold_lock_sequence_running")), "L%d third capture starts automatic confirmation" % n)
		await create_timer(1.5).timeout
		_check(bool(radio.get("prediction_running")), "L%d confirmed captures advance to clock verification" % n)
		radio.queue_free()
		await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("release_transient_sfx"):
		audio.call("release_transient_sfx")
	await create_timer(0.12).timeout
	print("PLAYER REPORTED BLOCKERS TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var dir := "res://artifacts/player-blockers-fix"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var error := root.get_texture().get_image().save_png(dir + "/" + label + ".png")
	_check(error == OK, "saved runtime screenshot " + label)

func _check(ok: bool, message: String) -> void:
	print("  %s: %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures += 1
