extends SceneTree

const OUTPUT_DIR := "res://artifacts/space_assembly_layout"

var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("GameManager autoload is missing")
		_restore_save()
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(66, true)
	gm.reset_assembly()
	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(8):
		await process_frame
	for overlay in get_nodes_in_group("guidance_highlight"):
		if overlay != null:
			overlay.visible = false
	await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Viewport texture unavailable; run this capture with a graphical display driver.")
		bench.queue_free()
		await process_frame
		_restore_save()
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image is empty.")
		bench.queue_free()
		await process_frame
		_restore_save()
		quit(1)
		return
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/after_space_slot_layout.png")
	var error := image.save_png(output)
	print("SPACE ASSEMBLY CAPTURE %s: %s" % ["PASS" if error == OK else "FAIL", output])
	for part_type_value in gm.current_level().get("assembly_order", []):
		gm.install_part(str(part_type_value), 0)
	bench.call("_build")
	for _i in range(5):
		await process_frame
	var installed_image := root.get_texture().get_image()
	var installed_output := ProjectSettings.globalize_path(OUTPUT_DIR + "/after_space_all_installed.png")
	var installed_error := installed_image.save_png(installed_output) if installed_image != null and not installed_image.is_empty() else FAILED
	print("SPACE INSTALLED CAPTURE %s: %s" % ["PASS" if installed_error == OK else "FAIL", installed_output])
	if installed_error != OK:
		error = installed_error
	bench.queue_free()
	await process_frame
	_restore_save()
	quit(0 if error == OK else 1)


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
