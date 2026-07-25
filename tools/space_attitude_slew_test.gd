extends SceneTree

const OUTPUT := "res://artifacts/space_attitude_slew"

var failures := 0
var scene: Control
var model: SpaceObservationModel


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)

	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.15)
	model = scene.get("model")
	_show_stage("guide")
	await _settle(0.08)

	var field := scene.get("guide_field") as Control
	var attitude := scene.get("guide_attitude_display") as Control
	_check(field != null, "guide sensor field exists")
	_check(attitude != null, "spacecraft attitude display exists")

	var rejected_index := _find_guide(false)
	var usable_index := _find_guide(true)
	scene.call("_on_guide_candidate_changed", rejected_index)
	scene.call("_choose_guide", rejected_index)
	_check(not bool(scene.get("guide_slew_active")), "unusable star is rejected without a false slew")
	_check(not model.guide_locked, "unusable star cannot lock")
	scene.call("_begin_guide_lock_ceremony")
	_check(not bool(scene.get("guide_lock_ceremony_active")), "failed candidate cannot trigger the success ceremony")

	scene.call("_on_guide_candidate_changed", usable_index)
	scene.call("_choose_guide", usable_index)
	_check(bool(scene.get("guide_slew_active")), "usable candidate begins spacecraft attitude slew")
	_check(model.chosen_guide < 0, "fine guidance does not start before attitude settles")
	_check(bool(field.get("input_locked")), "search box is frozen during spacecraft motion")
	_check((scene.get("guide_confirm_button") as Button).disabled, "confirm lock is disabled during slew")

	await _settle(0.50)
	_check(float(attitude.get("slew_progress")) > 0.25 and float(attitude.get("slew_progress")) < 0.8,
		"attitude display exposes visible mid-slew progress")
	_check(absf(float(attitude.get("yaw_deg")) + 14.0) > 1.0, "spacecraft yaw visibly changes")
	_check(float(attitude.call("coarse_error_arcsec")) < 7.0, "coarse-slew error visibly decreases")
	_save("01_spacecraft_mid_slew.png")

	await _settle(1.0)
	_check(not bool(scene.get("guide_slew_active")), "attitude slew completes")
	_check(model.chosen_guide == usable_index, "fine guidance starts only after the attitude hold")
	_check(not bool(field.get("input_locked")), "search input is restored after the slew")
	_check(bool(attitude.get("settled")), "attitude display enters hold state")
	var settled_roll := float(attitude.get("roll_deg"))
	await _settle(0.12)
	_check(absf(float(attitude.get("roll_deg")) - settled_roll) < 0.05,
		"fine guidance holds spacecraft attitude instead of rocking the whole observatory")

	for _frame in range(180):
		await process_frame
		if model.guide_locked:
			break
	_check(model.guide_locked, "fine guidance reaches lock after settling")
	_check(bool(scene.get("guide_lock_ceremony_active")), "real lock starts the precision-control ceremony")
	_check((scene.get("guide_confirm_button") as Button).disabled, "confirm stays disabled while lock verification plays")
	await _settle(0.90)
	_check(bool(scene.get("guide_lock_ceremony_complete")), "fine-lock ceremony retains a visible verified state")
	_check(not (scene.get("guide_confirm_button") as Button).disabled, "confirm becomes available after real lock")
	var log_text := "\n".join(scene.get("console_log"))
	_check(log_text.contains("FGS ACQUIRE") and log_text.contains("TRACK"), "terminal records guide-star tracking")
	_check(log_text.contains("FINE GUIDANCE") and log_text.contains("LOCKED"), "terminal records fine-guidance lock")
	_check(log_text.contains("POINTING STABILITY") and log_text.contains("NOMINAL"), "terminal records nominal pointing stability")
	_save("02_spacecraft_guide_locked.png")

	print("SPACE ATTITUDE SLEW TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _show_stage(stage_name: String) -> void:
	var stages: Array = scene.get("stages")
	var index := stages.find(stage_name)
	_check(index >= 0, "guide stage exists")
	if index >= 0:
		scene.set("stage", index)
		scene.call("_rebuild")


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _find_guide(usable: bool) -> int:
	for index in range(model.guide_stars.size()):
		var guide: Dictionary = model.guide_stars[index]
		if bool(guide.get("usable", false)) == usable:
			return index
	return -1


func _save(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP capture in headless display server: ", file_name)
		return
	var texture := root.get_texture()
	if texture == null:
		print("SKIP capture in dummy headless renderer: ", file_name)
		return
	var image := texture.get_image()
	if image == null:
		print("SKIP capture without framebuffer image: ", file_name)
		return
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	var error := image.save_png(path)
	_check(error == OK, "capture saved: " + file_name)
	if error == OK:
		print("CAPTURE ", path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures += 1
		push_error("FAIL " + message)
