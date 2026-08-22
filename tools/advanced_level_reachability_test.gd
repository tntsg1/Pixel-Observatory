extends SceneTree

# Per-level reachability for the two remote-observatory chapters. The larger
# vertical-slice tests prove the controls themselves; this matrix proves that
# every data profile can still satisfy those controls and produce a successful
# science report.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager is available")
		_finish()
		return

	var levels := _advanced_levels()
	_check(levels.size() > 0, "advanced level data is readable")
	for level_number in range(66, 76):
		var level: Dictionary = levels.get(level_number, {})
		_check(not level.is_empty(), "L%d exists" % level_number)
		if level_number == 71:
			await _check_multi_device_level(gm, level)
		else:
			_check_space_level(level_number, level)

	for level_number in range(76, 86):
		_check_fast_level(level_number, levels.get(level_number, {}))

	_finish()


func _advanced_levels() -> Dictionary:
	var file := FileAccess.open("res://data/advanced_levels.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		return {}
	var result := {}
	for value in parsed as Array:
		if value is Dictionary:
			result[int((value as Dictionary).get("level_number", 0))] = value
	return result


func _check_space_level(level_number: int, level: Dictionary) -> void:
	var profile_value: Variant = level.get("space_profile", {})
	_check(profile_value is Dictionary and not (profile_value as Dictionary).is_empty(),
		"L%d has a space profile" % level_number)
	if not profile_value is Dictionary or (profile_value as Dictionary).is_empty():
		return
	var profile := (profile_value as Dictionary).duplicate(true)
	var media_path := str(profile.get("science_image_path", ""))
	if media_path != "":
		_check(FileAccess.file_exists(media_path), "L%d science image exists" % level_number)

	var model := SpaceObservationModel.new()
	model.configure(profile)
	for deploy_step in model.DEPLOY_ORDER:
		model.deploy(str(deploy_step))
	model.instrument = model.best_instrument
	model.filter = model.best_filter
	model.exposure_time = 400.0
	model.integrations = 6
	model.dither = "box"
	model.rotate_to(model.thermal_target_deg)
	for _step in range(900):
		model.step_thermal(1.0 / 60.0)
		if model.thermal_locked:
			break

	var guide_index := -1
	for index in range(model.guide_stars.size()):
		if bool((model.guide_stars[index] as Dictionary).get("usable", false)):
			guide_index = index
			break
	if guide_index >= 0:
		model.choose_guide_star(guide_index)
		for _step in range(300):
			model.step_guiding(1.0 / 60.0)

	for bank_index in range(3):
		model.coarse_adjust_group(bank_index)
	for segment_index in model.wavefront_anomaly_segments().duplicate():
		var attempts := 0
		while absf(model.segment_phase_error(segment_index)) > 0.12 and attempts < 16:
			var trim := -0.12 if model.segment_phase_error(segment_index) > 0.0 else 0.12
			model.adjust_segment_phase(segment_index, trim)
			attempts += 1

	model.acquire()
	for frame_index in range(model.frames.size()):
		var frame: Dictionary = model.frames[frame_index]
		model.toggle_keep(frame_index, model.frame_should_keep(frame))
	model.align_frames()
	model.remove_cosmic_rays()
	model.subtract_background()
	model.stack()
	for channel in ["R", "G", "B"]:
		model.set_channel(channel, str(model.recommended_channel_map.get(channel, "")))
	model.choose_science(model.true_science)

	var report := model.report()
	_check(model.fully_deployed(), "L%d deploys fully" % level_number)
	_check(model.safe_to_observe(), "L%d reaches a thermally safe attitude" % level_number)
	_check(model.guide_locked, "L%d acquires a guide star" % level_number)
	_check(model.wavefront_ok(), "L%d wavefront converges" % level_number)
	_check(model.processing_ready(), "L%d processing chain completes" % level_number)
	_check(model.science_correct(), "L%d evidence mapping supports its science answer" % level_number)
	_check(bool(report.get("success", false)),
		"L%d produces a successful space-science report (SNR %.1f)" % [level_number, float(report.get("snr", 0.0))])


func _check_multi_device_level(gm: Node, level: Dictionary) -> void:
	_check(str(level.get("observation_mode", "")) == "multi_device", "L71 uses the evidence desk")
	_check(str(level.get("evidence_band", "")) == "infrared",
		"L71 explicitly requires infrared evidence for the warm-dust lesson")
	gm.new_game()
	gm.debug_jump_to_level(71, true)
	var scene: Node = load("res://scenes/multi_observation.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(str(scene.call("_expected_record")) == "infrared",
		"L71 evidence desk accepts the infrared record")
	scene.queue_free()
	await process_frame


func _check_fast_level(level_number: int, level: Dictionary) -> void:
	var profile_value: Variant = level.get("radio_profile", {})
	_check(profile_value is Dictionary and not (profile_value as Dictionary).is_empty(),
		"L%d has a FAST profile" % level_number)
	if not profile_value is Dictionary or (profile_value as Dictionary).is_empty():
		return
	var model := RadioSignalModel.new()
	model.configure((profile_value as Dictionary).duplicate(true))
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	var reachable_tuning := _best_keyboard_tuning(model)
	model.window_center_mhz = float(reachable_tuning.get("center_mhz", model.window_center_mhz))
	model.window_bandwidth_mhz = float(reachable_tuning.get("bandwidth_mhz", model.window_bandwidth_mhz))
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool((model.rfi_peaks[index] as Dictionary).get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(model.required_integration_s)

	var report := model.report()
	var conclusion := model.conclusion_state()
	_check(model.is_locked(), "L%d feed cabin can lock" % level_number)
	_check(model.tuning_quality() >= 0.55,
		"L%d receiver can tune a legal 5 MHz grid solution (%.0f/%.0f MHz, quality %.2f)" % [
			level_number,
			model.window_center_mhz,
			model.window_bandwidth_mhz,
			model.tuning_quality(),
		])
	_check(model.classification_score() >= model.rfi_threshold and model.residual_rfi_count() == 0,
		"L%d RFI evidence can be classified cleanly" % level_number)
	_check(model.fold_snr() >= model.report_snr_threshold,
		"L%d reaches its SNR threshold %.1f/%.1f" % [level_number, model.fold_snr(), model.report_snr_threshold])
	_check(bool(report.get("success", false)), "L%d produces a successful FAST report" % level_number)
	_check(model.evaluate_conclusion(conclusion),
		"L%d has an evidence-backed report choice (%s)" % [level_number, conclusion])


func _best_keyboard_tuning(model: RadioSignalModel) -> Dictionary:
	# The shipped controls change centre and width in 5 MHz steps. Search that
	# exact player-reachable grid instead of assuming that the physical source
	# centre is also the quietest receiver window.
	var best := {
		"center_mhz": model.window_center_mhz,
		"bandwidth_mhz": model.window_bandwidth_mhz,
		"quality": -1.0,
	}
	var center := model.BAND_MIN
	while center <= model.BAND_MAX + 0.01:
		var width := 20.0
		while width <= 180.0 + 0.01:
			model.window_center_mhz = center
			model.window_bandwidth_mhz = width
			var quality := model.tuning_quality()
			if quality > float(best["quality"]):
				best = {
					"center_mhz": center,
					"bandwidth_mhz": width,
					"quality": quality,
				}
			width += 5.0
		center += 5.0
	return best


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	print("ADVANCED LEVEL REACHABILITY TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
