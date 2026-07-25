extends SceneTree

const OUTPUT := "res://artifacts/space_complete"

var gm: Node
var scene: Control
var capture_failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)

	var room: Control = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await _settle(0.15)
	_save("01_hall_space_console.png")
	room.call("_enter_space_console")
	await _settle(0.24)
	_save("02_hall_console_transition.png")
	room.queue_free()
	await process_frame

	gm.progress["space_intro_seen"] = false
	gm.progress["space_deployed"] = false
	await _spawn_space()
	_save("03_intro_maya.png")
	scene.queue_free()
	await process_frame

	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = false
	await _spawn_space()
	scene.call("_try_deploy", "solar_array")
	await _settle(0.34)
	_save("04_deployment_in_motion.png")
	await _settle(0.48)
	var model: SpaceObservationModel = scene.get("model")
	for step in ["sunshield", "primary_mirror", "secondary_mirror", "hinges", "actuators"]:
		model.deploy(step)
	model.instrument = "nircam"
	model.filter = "near_infrared"
	model.dither = "three_point"
	model.exposure_time = 400.0
	model.integrations = 5
	_show_stage("plan")
	await _settle(0.06)
	_save("05_plan_recommendations.png")

	model.rotate_to(50.0)
	_show_stage("thermal")
	await _settle(0.06)
	scene.call("_animate_attitude_to", 110.0)
	await _settle(0.17)
	_save("06_attitude_slew.png")
	await _settle(0.30)

	_show_stage("guide")
	await _settle(0.06)
	_save("07_guide_search_field.png")
	scene.call("_choose_guide", 1)
	await _settle(1.65)
	for _i in range(240):
		model.step_guiding(1.0 / 60.0)
	scene.call("_refresh_guide")
	await process_frame
	_save("08_guide_locked.png")

	model.set_segment_alignment(0.14)
	_show_stage("wavefront")
	await _settle(0.06)
	scene.call("_animate_wavefront_step", 0.40, "COARSE")
	await _settle(0.28)
	_save("09_wavefront_converging.png")
	await _settle(0.40)
	model.set_segment_alignment(1.0)
	scene.call("_refresh_wavefront")
	await process_frame
	_save("10_wavefront_aligned.png")

	_show_stage("expose")
	await _settle(0.06)
	scene.call("_start_expose")
	scene.set("elapsed", 2.1)
	scene.call("_refresh_expose")
	await process_frame
	_save("11_photon_integration.png")
	scene.set("elapsed", 4.2)
	scene.call("_refresh_expose")
	await process_frame

	_show_stage("process")
	await _settle(0.06)
	scene.call("_run_process_step", "align")
	await _settle(0.25)
	_save("12_frame_alignment_motion.png")
	await _settle(0.60)
	scene.call("_run_process_step", "cosmic")
	await _settle(0.24)
	_save("13_cosmic_ray_scan.png")
	await _settle(0.62)
	scene.call("_run_process_step", "background")
	await _settle(0.24)
	_save("14_background_subtraction.png")
	await _settle(0.62)
	scene.call("_run_process_step", "stack")
	await _settle(0.25)
	_save("15_frame_stack_merge.png")
	await _settle(0.62)

	model.set_channel("R", "miri_dust")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "nir_short")
	_show_stage("filter")
	await _settle(0.06)
	_save("16_filter_structure_evidence.png")
	model.choose_science(model.true_science)
	_show_stage("report")
	await _settle(0.06)
	await _settle(0.32)
	_save("17_report_decoding.png")
	await _settle(0.72)
	_save("18_report_complete.png")

	scene.queue_free()
	await process_frame
	print("SPACE FINAL CAPTURES %s: %s" % [
		"PASS" if capture_failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT)])
	quit(0 if capture_failures == 0 else 1)


func _spawn_space() -> void:
	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.24)


func _show_stage(stage_name: String) -> void:
	var stages: Array = scene.get("stages")
	var index := stages.find(stage_name)
	if index < 0:
		capture_failures += 1
		push_error("Missing stage " + stage_name)
		return
	scene.set("stage", index)
	scene.call("_rebuild")


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _save(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		capture_failures += 1
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		capture_failures += 1
		return
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		capture_failures += 1
	else:
		print("CAPTURE ", path)
