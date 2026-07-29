extends SceneTree

# A completed free observation returns to Sky Observation with the mission
# target selected. It must preserve the observing site and the mount's real
# pointing instead of teleporting into a centered eyepiece result.

const SAVE_PATH := "user://savegame.json"

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()
var test_finished := false


func _initialize() -> void:
	var watchdog := create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		if not test_finished:
			_fail("test completes before the 30 second watchdog")
			_finish()
	)
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
	await process_frame

	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is available")
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(5, true) # Jupiter mission
	gm.selected_object_id = "moon"
	gm.selected_object_level = int(gm.progress.get("current_level", 1))
	var southern_site := {
		"id": "return_test_south",
		"name_en": "Southern Test Site",
		"name_zh": "南半球测试地点",
		"country_en": "Australia",
		"country_zh": "澳大利亚",
		"lat": -33.8688,
		"lon": 151.2093,
		"bortle": 4
	}
	gm.set_observing_location(southern_site)
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": 42.0,
		"altitude": 18.0,
		"view_mode": "naked_eye"
	}
	var level_before := int(gm.progress.get("current_level", 0))
	var completed_before: Array = (gm.progress.get("completed_levels", []) as Array).duplicate()
	var equipped_before: Dictionary = (gm.progress.get("equipped_parts", {}) as Dictionary).duplicate(true)

	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	for _frame in range(10):
		await process_frame

	var mission_button := view.find_child("FreeObservationMissionButton", true, false) as Button
	_check(bool(view.get("is_free_observation")), "starts in free-observation mode")
	_check(mission_button != null, "free result exposes return-to-mission action")

	if mission_button != null:
		mission_button.pressed.emit()
	else:
		view.call("_return_to_mission_target")
	for _frame in range(30):
		await process_frame

	var sky := current_scene as Control
	_check(not is_instance_valid(view), "free-observation eyepiece closes")
	_check(sky != null and sky.name == "SkyObservation", "return routes to sky acquisition")
	_check(str(gm.selected_object_id) == "jupiter", "mission target becomes the active object")
	_check(not bool(gm.is_free_observation()), "mission observation context is restored")
	_check(str(gm.observing_location().get("id", "")) == "return_test_south", "observing site and hemisphere are preserved")
	_check(is_equal_approx(float(gm.last_sky_aim.get("azimuth", -1.0)), 42.0), "mount azimuth is not teleported to the mission")
	_check(is_equal_approx(float(gm.last_sky_aim.get("altitude", -1.0)), 18.0), "mount altitude is not teleported to the mission")
	if sky != null and sky.name == "SkyObservation":
		_check(str(sky.get("target_id")) == "jupiter", "sky view receives the mission navigation target")
		_check(is_equal_approx(float(sky.get("telescope_azimuth")), 42.0), "sky view restores the previous azimuth")
		_check(is_equal_approx(float(sky.get("telescope_altitude")), 18.0), "sky view restores the previous altitude")
		_check(not bool(sky.call("_is_target_centered", "jupiter")), "mission target is not auto-centered or auto-locked")
	_check(int(gm.progress.get("current_level", 0)) == level_before, "current level is unchanged")
	_check((gm.progress.get("completed_levels", []) as Array) == completed_before, "completed mission list is unchanged")
	_check((gm.progress.get("equipped_parts", {}) as Dictionary) == equipped_before, "equipped parts are unchanged")

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	await process_frame
	_finish()


func _finish() -> void:
	if test_finished:
		return
	test_finished = true
	_restore_save()
	if failures == 0:
		print("FREE OBSERVATION RETURN TO MISSION TEST PASS")
		quit(0)
	else:
		print("FREE OBSERVATION RETURN TO MISSION TEST FAIL (%d)" % failures)
		quit(1)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)
