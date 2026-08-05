extends SceneTree

const SAVE_PATH := "user://savegame.json"
const OUTPUT_DIR := "res://artifacts/sky_free_observation_switch"

var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame

	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(5, true)
	gm.selected_object_id = "moon"
	gm.selected_object_level = int(gm.progress.get("current_level", 1))
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": 102.75,
		"altitude": 37.35,
		"view_mode": "naked_eye"
	}

	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	for _frame in range(8):
		await process_frame
	_save("01_free_target_with_mission_switch.png")

	var button := view.find_child("ReturnToMissionTargetButton", true, false) as Button
	if button == null:
		push_error("Mission switch button is missing")
		_restore_save()
		quit(1)
		return
	button.pressed.emit()
	for _frame in range(5):
		await process_frame
	_save("02_mission_target_restored.png")

	view.queue_free()
	await process_frame
	_restore_save()
	print("SKY FREE OBSERVATION SWITCH CAPTURE PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
