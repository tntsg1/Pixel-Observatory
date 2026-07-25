extends SceneTree

const OUTPUT_DIR := "res://artifacts/space_thermal_interaction"

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
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(68, true)
	for part_type in gm.space_segmented_install_types():
		gm.install_part(part_type, 0)

	var scene := load("res://scenes/space_observation.tscn").instantiate() as Control
	root.add_child(scene)
	for _i in range(8):
		await process_frame
	var stage_list: Array = scene.get("stages")
	scene.set("stage", stage_list.find("thermal"))
	scene.call("_rebuild")
	for _i in range(4):
		await process_frame
	_hide_guidance()
	await process_frame
	_capture("01_new_target_requires_slew.png")

	var model: SpaceObservationModel = scene.get("model")
	model.rotate_to(model.thermal_target_deg)
	for _i in range(90):
		model.step_thermal(1.0 / 60.0)
	scene.call("_refresh_thermal")
	await process_frame
	_capture("02_cooling_and_holding.png")

	for _i in range(600):
		model.step_thermal(1.0 / 60.0)
		if model.thermal_locked:
			break
	scene.call("_refresh_thermal")
	await process_frame
	_capture("03_target_specific_lock.png")

	scene.queue_free()
	for _i in range(3):
		await process_frame
	_finish()


func _capture(filename: String) -> void:
	var texture := root.get_texture()
	var image := texture.get_image() if texture != null else null
	if image == null or image.is_empty():
		failures += 1
		return
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename)
	if image.save_png(output) != OK:
		failures += 1
	else:
		print("SPACE THERMAL CAPTURE PASS: " + output)


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
	print("SPACE THERMAL CAPTURE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
