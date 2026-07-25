extends SceneTree

var failures := 0
var scene: Control
var model: SpaceObservationModel


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var game_manager := root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.language_mode = "en"
	game_manager.progress["space_intro_seen"] = true
	game_manager.progress["space_deployed"] = true
	game_manager.debug_jump_to_level(66, true)

	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.3)
	model = scene.get("model")
	var stages: Array = scene.get("stages")
	scene.set("stage", stages.find("wavefront"))
	scene.call("_rebuild")
	await _settle(0.08)

	var display := scene.find_child("WavefrontDisplay", true, false)
	var display_id := display.get_instance_id()
	var groups := [
		scene.find_child("WavefrontGroupA", true, false),
		scene.find_child("WavefrontGroupB", true, false),
		scene.find_child("WavefrontGroupC", true, false),
	]
	_check(groups.all(func(node): return node is Button), "three six-segment diagnostic banks are available")

	var dominant := model.max_wavefront_group()
	var wrong := (dominant + 1) % 3
	var wrong_before := model.wavefront_group_error(wrong)
	scene.call("_select_wavefront_group", wrong)
	scene.call("_execute_wavefront_group")
	await _settle(0.12)
	_check(str(display.get("actuation_mode")) == "COARSE", "coarse actuation enters a visible mechanical RUN state")
	await _settle(0.9)
	_check(not model.wavefront_coarse_complete, "a wrong bank cannot complete coarse phasing")
	_check(model.wavefront_group_error(wrong) < wrong_before, "a wrong bank produces a small physical improvement")
	_check(scene.find_child("WavefrontDisplay", true, false).get_instance_id() == display_id,
		"coarse actuation redraws the existing display instead of rebuilding the page")

	scene.call("_select_wavefront_group", dominant)
	scene.call("_execute_wavefront_group")
	await _settle(1.0)
	_check(model.wavefront_coarse_complete, "the dominant bank completes coarse phasing")
	_check(model.wavefront_anomaly_segments().size() == 4, "coarse phasing leaves four amber residual segments")
	_check(not model.wavefront_ok(), "coarse phasing alone cannot pass the precision threshold")

	var psf_before := model.psf_sharpness()
	for segment_index in model.wavefront_anomaly_segments().duplicate():
		scene.call("_select_wavefront_segment", segment_index)
		var before := absf(model.segment_phase_error(segment_index))
		var first_step := -0.12 if model.segment_phase_error(segment_index) > 0.0 else 0.12
		scene.call("_adjust_wavefront_segment", first_step)
		await _settle(0.8)
		_check(absf(model.segment_phase_error(segment_index)) < before,
			"segment %02d actuator moves its signed phase toward zero" % (segment_index + 1))
		while absf(model.segment_phase_error(segment_index)) > 0.12:
			var trim := -0.12 if model.segment_phase_error(segment_index) > 0.0 else 0.12
			scene.call("_adjust_wavefront_segment", trim)
			await _settle(0.8)
	await _settle(0.95)

	_check(model.wavefront_anomaly_segments().is_empty(), "all residual side peaks merge into the PSF core")
	_check(model.wavefront_error_nm < 150.0, "fine phasing reaches the wavefront-error threshold")
	_check(model.psf_sharpness() > psf_before, "PSF sharpness improves as residual segments settle")
	_check(bool(scene.get("wavefront_convergence_complete")), "phase retrieval plays the final convergence state")
	_check(scene.find_child("FineWavefrontMinus", true, false).visible == false,
		"fine controls yield to the clean converged state")
	var actuator_status := scene.get("wavefront_actuator_label") as Label
	_check(actuator_status.text == "PHASE RETRIEVAL CONVERGED",
		"the final engineering status is visible without terminal clipping")
	_check(scene.find_child("WavefrontDisplay", true, false).get_instance_id() == display_id,
		"fine phasing keeps the same continuously redrawn display")

	scene.call("_confirm_wavefront")
	await process_frame
	_check(str(scene.call("_key")) == "expose", "confirmed alignment advances to detector exposure")

	scene.queue_free()
	await process_frame
	await process_frame
	print("SPACE WAVEFRONT ALIGNMENT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok: ", description)
	else:
		failures += 1
		print("  FAIL: ", description)
