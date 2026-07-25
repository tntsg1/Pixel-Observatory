extends SceneTree

const OUTPUT := "res://artifacts/space_processing_events"

var failures := 0
var scene: Control
var model: SpaceObservationModel


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	var seen: Array = gm.progress.get("seen_teaching_steps", [])
	seen.erase("space_frame_processing_v2")
	gm.progress["seen_teaching_steps"] = seen
	gm.debug_jump_to_level(66, true)

	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.12)
	model = scene.get("model")
	model.instrument = model.best_instrument
	model.filter = model.best_filter
	model.dither = "three_point"
	model.exposure_time = 400.0
	model.integrations = 4
	model.acquire()
	model.guide_locked = true
	model.chosen_guide = 1
	model.pointing_error = 0.8
	model.rotate_to(model.thermal_target_deg)
	for _i in range(600):
		model.step_thermal(1.0 / 60.0)
		if model.thermal_locked:
			break
	model.set_segment_alignment(1.0)

	_show_stage("process")
	await _settle(0.08)
	_check(scene.get("process_tutorial_overlay") != null, "first processing visit opens Maya tutorial")
	_check(scene.find_child("MayaProcessPortrait", true, false) != null, "Maya portrait is visible in the lesson")
	_check((scene.get("process_tutorial_steps") as Array).size() == 5, "tutorial covers five processing decisions")
	scene.call("_show_process_tutorial_step", 1)
	await _settle(0.04)
	_save("01_maya_frame_review_tutorial.png")

	var event_types := {}
	var bad_index := -1
	for frame_index in range(model.frames.size()):
		var frame: Dictionary = model.frames[frame_index]
		event_types[str(frame.get("event_type", "clean"))] = true
		if not model.frame_should_keep(frame):
			bad_index = frame_index
	_check(event_types.size() >= 4, "the raw stack contains multiple distinct detector events")
	_check(bad_index >= 0, "one unrecoverable frame must be reviewed and dropped")
	var cosmic := scene.find_child("ProcessStep_cosmic", true, false) as Button
	var align := scene.find_child("ProcessStep_align", true, false) as Button
	_check(align != null and align.disabled, "step 1 waits until the frame review is correct")
	_check(cosmic != null and cosmic.disabled, "step 2 waits for frame alignment")
	var instruction := scene.find_child("ProcessNextInstruction", true, false) as Label
	_check(instruction != null and instruction.text.contains("REVIEW FRAMES"),
		"the right panel explicitly tells a novice what to do next")
	var generate := scene.find_child("GenerateScienceImage", true, false) as Button
	_check(generate != null and generate.disabled, "science image is blocked before processing is complete")

	while scene.get("process_tutorial_overlay") != null:
		scene.call("_advance_process_tutorial")
		await process_frame
	await process_frame
	_check(scene.get("process_tutorial_overlay") == null, "tutorial closes after the final Maya page")
	_check((gm.progress.get("seen_teaching_steps", []) as Array).has("space_frame_processing_v2"),
		"completed tutorial is remembered")
	_save("02_multiple_raw_events.png")

	scene.call("_toggle_process_frame", bad_index)
	await process_frame
	_check(model.frame_review_ready(), "dropping the unrecoverable event completes frame review")
	_save("03_review_complete_next_step.png")
	align = scene.find_child("ProcessStep_align", true, false) as Button
	_check(align != null and not align.disabled, "step 1 unlocks after correct frame review")
	scene.call("_run_process_step", "cosmic")
	_check(not model.cosmic_rays_removed, "out-of-order processing cannot bypass step 1")
	scene.call("_run_process_step", "align")
	await _settle(0.72)
	_check(model.frames_aligned, "step 1 performs frame alignment")
	cosmic = scene.find_child("ProcessStep_cosmic", true, false) as Button
	_check(cosmic != null and not cosmic.disabled, "step 2 unlocks after alignment")

	scene.call("_build_stage")
	await _settle(0.04)
	_check(scene.get("process_tutorial_overlay") == null, "Maya tutorial does not repeat after being learned")

	print("SPACE PROCESSING TUTORIAL TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _show_stage(stage_name: String) -> void:
	var stages: Array = scene.get("stages")
	var index := stages.find(stage_name)
	_check(index >= 0, "processing stage exists")
	if index >= 0:
		scene.set("stage", index)
		scene.call("_rebuild")


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)


func _save(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var texture := root.get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null:
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT + "/" + file_name))
	_check(error == OK, "capture saved: " + file_name)
