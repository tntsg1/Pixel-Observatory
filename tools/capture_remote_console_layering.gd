extends SceneTree

const OUTPUT_DIR := "res://artifacts/remote_console_layering"

var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	var result := OK
	if await _capture_console(gm, 66, "l2_console_transition.png") != OK:
		result = FAILED
	if await _capture_console(gm, 76, "fast_console_transition.png") != OK:
		result = FAILED
	_finish(0 if result == OK else 1)


func _capture_console(gm: Node, level_number: int, file_name: String) -> Error:
	_prepare_level(gm, level_number)
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(8):
		await process_frame
	if level_number == 66:
		var idle_image := root.get_texture().get_image()
		var idle_output := ProjectSettings.globalize_path(OUTPUT_DIR + "/l2_console_idle.png")
		var idle_error := idle_image.save_png(idle_output) if idle_image != null and not idle_image.is_empty() else FAILED
		print("REMOTE CONSOLE IDLE CAPTURE %s: %s" % ["PASS" if idle_error == OK else "FAIL", idle_output])
	room.call("_enter_space_console")
	for _i in range(8):
		await process_frame
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := image.save_png(output) if image != null and not image.is_empty() else FAILED
	print("REMOTE CONSOLE CAPTURE %s: %s" % ["PASS" if error == OK else "FAIL", output])
	room.queue_free()
	for _i in range(3):
		await process_frame
	return error


func _prepare_level(gm: Node, level_number: int) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(level_number, true)
	var story := root.get_node_or_null("/root/StoryManager")
	if story != null:
		var seen_story_events: Array = gm.progress.get("seen_story_events", [])
		var event_id := str(story.event_for_trigger("before_observation", level_number))
		if event_id != "" and not seen_story_events.has(event_id):
			seen_story_events.append(event_id)
		for skill_event_value in story.pending_skill_events("before_observation", level_number, gm.progress):
			var skill_event_id := str(skill_event_value)
			if skill_event_id != "" and not seen_story_events.has(skill_event_id):
				seen_story_events.append(skill_event_id)
		gm.progress["seen_story_events"] = seen_story_events
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	var seen_steps: Array = []
	var completed_cards: Array = []
	if teaching != null:
		for step_value in teaching.get_steps_for_level(gm.current_level()):
			if not step_value is Dictionary:
				continue
			var step: Dictionary = step_value
			var step_id := str(step.get("id", ""))
			var card_id := str(step.get("card_id", ""))
			if step_id != "":
				seen_steps.append(step_id)
			if card_id != "":
				completed_cards.append(card_id)
	gm.progress["seen_teaching_steps"] = seen_steps
	gm.progress["seen_concept_briefs"] = completed_cards.duplicate()
	gm.progress["completed_concept_cards"] = completed_cards.duplicate()
	gm.reset_assembly()
	for part_type_value in gm.current_level().get("assembly_order", []):
		gm.install_part(str(part_type_value), 0)
	if level_number == 66:
		gm.progress["space_intro_seen"] = true
		gm.progress["space_deployed"] = true


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


func _finish(exit_code: int) -> void:
	_restore_save()
	quit(exit_code)
