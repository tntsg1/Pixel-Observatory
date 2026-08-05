extends SceneTree

const SAVE_PATH := "user://savegame.json"
const OUTPUT_DIR := "res://artifacts/sky_guidance_strip"

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

	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	for _frame in range(8):
		await process_frame
	_save("01_guidance_expanded.png")

	var toggle := view.find_child("SkyGuidanceStripToggle", true, false) as Button
	if toggle == null:
		push_error("Guidance strip toggle is missing")
		_restore_save()
		quit(1)
		return
	toggle.pressed.emit()
	view.call("_apply_guidance_strip_state", false)
	await process_frame
	_save("02_guidance_collapsed.png")

	view.queue_free()
	await process_frame
	_restore_save()
	print("SKY GUIDANCE STRIP CAPTURE PASS: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("No viewport texture available for %s" % output)
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("No rendered frame available for %s" % output)
		quit(1)
		return
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
