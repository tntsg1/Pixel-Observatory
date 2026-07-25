extends SceneTree

const OUTPUT := "res://artifacts/space_wavefront_alignment"

var scene: Control
var model: SpaceObservationModel
var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))

	var game_manager := root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.language_mode = "en"
	game_manager.progress["space_intro_seen"] = true
	game_manager.progress["space_deployed"] = true
	game_manager.debug_jump_to_level(66, true)

	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.35)
	model = scene.get("model")
	await _show_wavefront_stage()

	var dominant_group := model.max_wavefront_group()
	scene.call("_select_wavefront_group", dominant_group)
	await _settle(0.08)
	_save("01_group_diagnosis.png")

	scene.call("_execute_wavefront_group")
	await _settle(1.0)
	var anomalies := model.wavefront_anomaly_segments()
	if anomalies.is_empty():
		failures += 1
	else:
		scene.call("_select_wavefront_segment", int(anomalies[0]))
	await _settle(0.08)
	_save("02_residual_segment_trim.png")

	for segment_index in model.wavefront_anomaly_segments().duplicate():
		scene.call("_select_wavefront_segment", segment_index)
		while absf(model.segment_phase_error(segment_index)) > 0.12:
			var trim := -0.12 if model.segment_phase_error(segment_index) > 0.0 else 0.12
			scene.call("_adjust_wavefront_segment", trim)
			await _settle(0.82)
	await _settle(1.85)
	if not bool(scene.get("wavefront_convergence_complete")):
		failures += 1
	_save("03_phase_retrieval_converged.png")

	scene.queue_free()
	await process_frame
	print("SPACE WAVEFRONT CAPTURE %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT)])
	quit(0 if failures == 0 else 1)


func _show_wavefront_stage() -> void:
	var stages: Array = scene.get("stages")
	var wavefront_index := stages.find("wavefront")
	if wavefront_index < 0:
		failures += 1
		return
	scene.set("stage", wavefront_index)
	scene.call("_rebuild")
	await _settle(0.08)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		return
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		failures += 1
	else:
		print("CAPTURE ", path)
