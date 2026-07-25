extends SceneTree

const OUTPUT := "res://artifacts/mode_transition_feedback"

var gm: Node
var view: Control
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(14, true)
	view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	await create_timer(0.45).timeout
	view.call("_set_view_mode", "naked_eye")
	await create_timer(0.55).timeout
	view.call("_set_view_mode", "finder")
	await create_timer(0.16).timeout
	_save("01_eye_to_finder_midpoint.png")
	await create_timer(0.42).timeout
	view.call("_set_view_mode", "telescope")
	await create_timer(0.18).timeout
	_save("02_finder_to_scope_midpoint.png")
	await create_timer(0.40).timeout
	_save("03_scope_settled.png")
	_restore_save()
	print("MODE TRANSITION FEEDBACK CAPTURE PASS")
	quit(0)


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
