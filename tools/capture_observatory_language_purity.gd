extends SceneTree

const OUTPUT := "res://artifacts/localization/observatory_fast_zh_fixed.png"

var had_save := false
var saved_bytes := PackedByteArray()
var previous_guidance_highlights := true


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://artifacts/localization"))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1, "GameManager autoload is missing")
		return
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		previous_guidance_highlights = bool(feedback.get("guidance_highlights"))
		feedback.set("guidance_highlights", true)
	gm.new_game()
	gm.debug_jump_to_level(76, true)

	# Reproduce the original failure before opening the Chinese room: the route
	# was cached in English while the rest of the interface used Chinese.
	gm.language_mode = "en"
	gm.update_room_guidance_for_level()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"

	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	current_scene = room
	for _frame in range(8):
		await process_frame
	await create_timer(0.25).timeout
	var error := root.get_texture().get_image().save_png(
		ProjectSettings.globalize_path(OUTPUT))
	room.queue_free()
	await process_frame
	_finish(0 if error == OK else 1,
		"OBSERVATORY LANGUAGE CAPTURE %s: %s" % [
			"PASS" if error == OK else "FAIL", OUTPUT])


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


func _finish(exit_code: int, message: String) -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		feedback.set("guidance_highlights", previous_guidance_highlights)
	_restore_save()
	print(message)
	quit(exit_code)
