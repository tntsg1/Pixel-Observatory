extends SceneTree

const OUTPUT_DIR := "res://artifacts/space_parts_workflow"

var had_save := false
var saved_bytes := PackedByteArray()
var failures := 0


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("GameManager autoload is missing")
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(68, true)
	gm.reset_assembly()

	var cabinet := load("res://scenes/parts_cabinet.tscn").instantiate() as Control
	root.add_child(cabinet)
	for _i in range(5):
		await process_frame
	cabinet.call("_show_auto_equip_preview")
	for _i in range(3):
		await process_frame
	_capture("00_auto_equip_full_loadout.png")
	cabinet.queue_free()
	for _i in range(3):
		await process_frame

	gm.apply_auto_equip(gm.auto_equip_plan())

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(8):
		await process_frame
	_hide_guidance()
	await process_frame

	bench.call("_set_space_blueprint_page", "deployment")
	for _i in range(3):
		await process_frame
	_capture("01_deploy_and_power.png")

	bench.call("_set_space_blueprint_page", "instruments")
	for _i in range(3):
		await process_frame
	_capture("02_science_instruments.png")

	bench.call("_install_all_space_parts")
	bench.call("_set_space_blueprint_page", "instruments")
	for _i in range(5):
		await process_frame
	_capture("03_all_unlocked_installed.png")

	bench.queue_free()
	for _i in range(3):
		await process_frame
	_finish()


func _capture(filename: String) -> void:
	var viewport_texture := root.get_texture()
	var image := viewport_texture.get_image() if viewport_texture != null else null
	if image == null or image.is_empty():
		failures += 1
		push_error("Viewport image is empty for " + filename)
		return
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)
	var error := image.save_png(output)
	if error != OK:
		failures += 1
		push_error("Unable to save " + output)
	else:
		print("SPACE PARTS CAPTURE PASS: " + output)


func _hide_guidance() -> void:
	for overlay in get_nodes_in_group("guidance_highlight"):
		if overlay != null:
			overlay.visible = false


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


func _finish() -> void:
	_restore_save()
	print("SPACE PARTS WORKFLOW CAPTURE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
