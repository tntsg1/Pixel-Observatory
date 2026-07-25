extends SceneTree

# A completed free observation can return to the current mission target inside
# the same telescope-view instance. The switch must not advance or mutate the
# mission, equipment, or campaign state.

const SAVE_PATH := "user://savegame.json"

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
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
	var level_before := int(gm.progress.get("current_level", 0))
	var completed_before: Array = (gm.progress.get("completed_levels", []) as Array).duplicate()
	var equipped_before: Dictionary = (gm.progress.get("equipped_parts", {}) as Dictionary).duplicate(true)

	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	for _frame in range(10):
		await process_frame

	var original_instance_id := view.get_instance_id()
	var original_parent := view.get_parent()
	var mission_button := view.find_child("FreeObservationMissionButton", true, false) as Button
	_check(bool(view.get("is_free_observation")), "starts in free-observation mode")
	_check(mission_button != null, "free result exposes return-to-mission action")

	if mission_button != null:
		mission_button.pressed.emit()
	else:
		view.call("_return_to_mission_target")
	for _frame in range(30):
		await process_frame

	_check(is_instance_valid(view), "telescope view remains alive")
	_check(view.get_instance_id() == original_instance_id, "switch stays in the same telescope-view instance")
	_check(view.get_parent() == original_parent, "switch does not route to another scene")
	_check(str(gm.selected_object_id) == "jupiter", "mission target becomes the active object")
	_check(not bool(view.get("is_free_observation")), "mission observation mode is restored")
	_check(str((view.get("selected_object") as Dictionary).get("id", "")) == "jupiter", "mission target visual data is loaded")
	_check(int(gm.progress.get("current_level", 0)) == level_before, "current level is unchanged")
	_check((gm.progress.get("completed_levels", []) as Array) == completed_before, "completed mission list is unchanged")
	_check((gm.progress.get("equipped_parts", {}) as Dictionary) == equipped_before, "equipped parts are unchanged")

	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
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
