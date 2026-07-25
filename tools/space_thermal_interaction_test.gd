extends SceneTree

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish()
		return
	var mission_manager := root.get_node_or_null("/root/MissionManager")
	if mission_manager == null:
		_fail("MissionManager autoload is missing")
		_finish()
		return

	var target_angles: Dictionary = {}
	for level_number in [66, 67, 68, 69, 70, 72, 73, 74, 75]:
		var level: Dictionary = mission_manager.get_level(level_number)
		var profile: Dictionary = level.get("space_profile", {})
		var model := SpaceObservationModel.new()
		model.configure(profile)
		target_angles[int(round(model.thermal_target_deg))] = true
		_check(not model.attitude_in_corridor(), "L%d starts outside its thermal corridor" % level_number)
		_check(not model.thermal_locked, "L%d never reuses a previous thermal lock" % level_number)
		_check(model.thermal_target_deg >= model.SAFE_MIN and model.thermal_target_deg <= model.SAFE_MAX,
			"L%d target roll remains physically sun-safe" % level_number)
		_check(absf(model.thermal_drift_rate) >= 0.4, "L%d has visible attitude drift" % level_number)

		model.rotate_to(model.thermal_target_deg)
		for _i in range(30):
			model.step_thermal(1.0 / 60.0)
		_check(not model.thermal_locked, "L%d cannot instantly confirm after reaching the marker" % level_number)
		for _i in range(600):
			model.step_thermal(1.0 / 60.0)
			if model.thermal_locked:
				break
		_check(model.thermal_locked, "L%d acquires lock after cooling and holding" % level_number)

		model.configure(profile)
		_check(not model.thermal_locked and model.thermal_hold_progress == 0.0,
			"L%d new observation resets thermal interaction" % level_number)

	_check(target_angles.size() >= 4, "space targets produce multiple roll solutions")

	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(68, true)
	for part_type in gm.space_segmented_install_types():
		gm.install_part(part_type, 0)
	var scene := load("res://scenes/space_observation.tscn").instantiate() as Control
	root.add_child(scene)
	for _i in range(4):
		await process_frame
	var stage_list: Array = scene.get("stages")
	scene.set("stage", stage_list.find("thermal"))
	scene.call("_rebuild")
	await process_frame
	for node_name in [
		"AttitudeCoarseMinus", "AttitudeFineMinus",
		"AttitudeFinePlus", "AttitudeCoarsePlus", "ConfirmThermalLock",
	]:
		_check(scene.find_child(node_name, true, false) != null, "thermal UI exposes " + node_name)
	var scene_model: SpaceObservationModel = scene.get("model")
	scene.call("_confirm_thermal")
	await process_frame
	_check(str(scene.call("_key")) == "thermal", "confirm is blocked before a stable hold")
	scene_model.rotate_to(scene_model.thermal_target_deg)
	for _i in range(600):
		scene_model.step_thermal(1.0 / 60.0)
		if scene_model.thermal_locked:
			break
	scene.call("_confirm_thermal")
	await process_frame
	_check(str(scene.call("_key")) == "guide", "stable target-specific lock advances to guiding")
	scene.queue_free()
	await process_frame
	_finish()


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	_restore_save()
	print("SPACE THERMAL INTERACTION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
