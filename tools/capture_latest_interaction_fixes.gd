extends SceneTree

const OUTPUT := "res://artifacts/latest_interaction_fixes"

var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")
	await _capture_l1_field_guide()
	await _capture_l3_lunar_detail()
	await _capture_space_hall_console()
	await _capture_space_alignment()
	print("LATEST INTERACTION CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT))
	_restore_save()
	quit(0)


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


func _capture_l1_field_guide() -> void:
	gm.new_game()
	gm.language_mode = "zh"
	gm.selected_object_id = "moon"
	gm.selected_object_level = 1
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.55)
	_save("01_l1_pixel_field_guide.png")
	view.queue_free()
	await process_frame


func _capture_l3_lunar_detail() -> void:
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(3, true)
	gm.selected_object_id = "moon"
	gm.selected_object_level = 3
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.38)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	await _settle(0.28)
	_save("02_l3_lunar_detail_fisheye.png")
	view.queue_free()
	await process_frame


func _capture_space_hall_console() -> void:
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(66, true)
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	await _settle(0.32)
	_save("03_space_console_in_glass.png")
	room.queue_free()
	await process_frame


func _capture_space_alignment() -> void:
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)
	var view := load("res://scenes/space_observation.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.20)
	view.set("stages", ["wavefront"])
	view.set("stage", 0)
	view.set("furthest_stage", 0)
	view.call("_rebuild")
	await _settle(0.18)
	view.call("_animate_wavefront_step", 0.18, "COARSE")
	await _settle(0.16)
	_save("04_space_coarse_alignment.png")
	await _settle(0.44)
	view.call("_animate_wavefront_step", 0.07, "FINE")
	await _settle(0.12)
	_save("05_space_fine_alignment.png")
	view.queue_free()
	await process_frame


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
