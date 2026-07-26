extends SceneTree

const OUTPUT := "res://artifacts/andromeda_infrared_stages"

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
	game_manager.progress["seen_teaching_steps"] = ["space_frame_processing_v2"]
	game_manager.debug_jump_to_level(66, true)

	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.35)
	model = scene.get("model")
	_prepare_complete_science_state()

	_show_stage("expose")
	await _settle(0.2)
	_save("01_exposure.png")

	_show_stage("process")
	await _settle(0.2)
	_save("02_processing.png")

	model.set_channel("R", "miri_dust")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "nir_short")
	model.choose_science(model.true_science)
	_show_stage("filter")
	await _settle(0.2)
	_save("03_filter_correct.png")

	model.set_channel("R", "nir_short")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "miri_dust")
	_show_stage("filter")
	await _settle(0.2)
	_save("04_filter_wrong.png")

	model.set_channel("R", "miri_dust")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "nir_short")
	model.choose_science(model.true_science)
	_show_stage("report")
	await _settle(0.85)
	_save("05_report.png")

	scene.queue_free()
	await process_frame
	print("ANDROMEDA INFRARED CAPTURE %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT)])
	quit(0 if failures == 0 else 1)


func _prepare_complete_science_state() -> void:
	model.acquired = true
	model.frames = [
		{"signal": 0.92, "event_type": "clean", "cosmic_ray": false, "saturated": false, "unusable": false, "kept": true},
		{"signal": 0.84, "event_type": "cosmic_streak", "cosmic_ray": true, "saturated": false, "unusable": false, "kept": true},
		{"signal": 0.89, "event_type": "hot_pixels", "cosmic_ray": false, "saturated": false, "unusable": false, "kept": true},
		{"signal": 0.78, "event_type": "guide_smear", "cosmic_ray": false, "saturated": false, "unusable": true, "kept": false},
	]
	model.frames_aligned = true
	model.cosmic_rays_removed = true
	model.stacked = true
	model.background_subtracted = true
	model.guide_locked = true
	model.pointing_error = 0.12
	model.drift_rate = 0.008
	model.thermal_locked = true
	model.cold_side_temp = 38.0
	model.segment_alignment = 1.0
	model.wavefront_error_nm = 85.0


func _show_stage(stage_id: String) -> void:
	var stages: Array = scene.get("stages")
	var index := stages.find(stage_id)
	if index < 0:
		failures += 1
		push_error("Missing stage: " + stage_id)
		return
	scene.set("stage", index)
	scene.call("_rebuild")


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
