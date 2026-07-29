extends SceneTree

const SAVE_PATH := "user://savegame.json"
const OUTPUT_DIR := "res://artifacts/free_observation_return"

var had_save := false
var saved_bytes := PackedByteArray()
var capture_finished := false


func _initialize() -> void:
	var watchdog := create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		if not capture_finished:
			push_error("FREE OBSERVATION RETURN CAPTURE TIMEOUT")
			_restore_save()
			quit(1)
	)
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame

	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(5, true) # Jupiter mission
	gm.selected_object_id = "moon"
	gm.selected_object_level = int(gm.progress.get("current_level", 1))
	gm.set_observing_location({
		"id": "return_capture_south",
		"name_en": "Southern Test Site",
		"name_zh": "南半球测试地点",
		"country_en": "Australia",
		"country_zh": "澳大利亚",
		"lat": -33.8688,
		"lon": 151.2093,
		"bortle": 4
	})
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": 42.0,
		"altitude": 18.0,
		"view_mode": "naked_eye"
	}

	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await _settle()
	_capture("01_free_observation_actions.png")

	var mission_button := view.find_child("FreeObservationMissionButton", true, false) as Button
	if mission_button != null:
		mission_button.pressed.emit()
	await _settle()
	_capture("02_mission_returned_to_sky_acquisition.png")

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		current_scene = null
	await process_frame
	_restore_save()
	capture_finished = true
	print("FREE OBSERVATION RETURN CAPTURE PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _settle() -> void:
	for _frame in range(8):
		await process_frame
	await create_timer(0.35).timeout


func _capture(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Capture requires a graphical renderer: " + path)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("Could not read viewport image: " + path)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not capture " + path)
	else:
		print("CAPTURE " + path)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
