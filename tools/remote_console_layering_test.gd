extends SceneTree

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish()
		return

	await _test_remote_console(gm, 66, "space", "space_observation", "Space Telescope")
	await _test_remote_console(gm, 76, "radio", "radio_observation", "FAST Radio Telescope")
	await _test_stats_terminal_layer(gm)
	await _test_unlock_popup_layer(gm)
	_finish()


func _test_remote_console(gm: Node, level_number: int, kind: String, destination: String, name_fragment: String) -> void:
	_prepare_remote_level(gm, level_number)
	var route: Dictionary = gm.current_room_route()
	_check(str(route.get("target", "")) == "computer", "L%d route points to the lower-right computer" % level_number)
	_check(not bool(route.get("needs_site_change", false)), "L%d remote instrument ignores ground-site relocation" % level_number)

	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(5):
		await process_frame
	_check(str(room.call("_remote_console_kind")) == kind, "L%d resolves the %s console" % [level_number, kind])
	_check(str(room.call("_remote_console_destination")) == destination, "L%d routes to %s" % [level_number, destination])
	var computer: Dictionary = room.call("_get_interactable", "computer")
	_check(str(computer.get("name", "")).contains(name_fragment), "L%d computer has the correct instrument name" % level_number)
	if kind == "radio":
		_check(_tree_has_label(room, "FAST LINK"), "FAST chapter paints the FAST link on the physical computer")
	else:
		_check(_tree_has_label(room, "L2 LINK"), "space chapter paints the L2 link on the physical computer")

	var fake_maya := Control.new()
	fake_maya.name = "FakeMayaTutorialLayer"
	fake_maya.add_to_group("guidance_highlight")
	fake_maya.z_index = 900
	room.add_child(fake_maya)
	room.call("_enter_space_console")
	await process_frame
	var transition := room.find_child("SpaceConsoleTransition", true, false) as Control
	_check(transition != null, "L%d opens a guarded computer transition" % level_number)
	_check(transition != null and transition.z_index == 1100, "L%d computer transition is above Maya's tutorial layer" % level_number)
	_check(not is_instance_valid(fake_maya), "L%d dismisses the lobby Maya bubble before opening" % level_number)
	_check(bool(room.get("room_guidance_suspended")), "L%d suspends lobby guidance while the console owns the screen" % level_number)
	_check(str(room.get("pending_remote_console_scene")) == destination, "L%d preserves the correct remote destination" % level_number)
	var guidance_panel := room.get("guidance_panel") as Control
	_check(guidance_panel == null or not guidance_panel.visible, "L%d hides the persistent Maya panel during transition" % level_number)
	room.queue_free()
	for _i in range(3):
		await process_frame


func _test_stats_terminal_layer(gm: Node) -> void:
	gm.new_game()
	gm.language_mode = "en"
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(5):
		await process_frame
	var fake_maya := Control.new()
	fake_maya.add_to_group("guidance_highlight")
	fake_maya.z_index = 900
	room.add_child(fake_maya)
	room.call("_toggle_stats_terminal")
	await process_frame
	var popup := room.get("stats_terminal_popup") as Control
	_check(popup != null and popup.z_index == 1100, "stats terminal also owns the computer modal layer")
	_check(not is_instance_valid(fake_maya), "stats terminal dismisses the lobby Maya bubble")
	_check(bool(room.get("room_guidance_suspended")), "stats terminal suspends room guidance")
	room.call("_toggle_stats_terminal")
	for _i in range(2):
		await process_frame
	_check(not bool(room.get("room_guidance_suspended")), "closing stats terminal restores room guidance")
	room.queue_free()
	for _i in range(3):
		await process_frame


func _test_unlock_popup_layer(gm: Node) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(67, true)
	gm.update_room_guidance_for_level()
	gm.progress["pending_unlock_notice"] = [
		"space_nircam",
		"space_radiator",
		"space_instrument_bay",
	]
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(6):
		await process_frame
	var popup := room.get("unlock_popup") as Control
	_check(popup != null and popup.z_index == 1100,
		"equipment unlock notice owns the modal layer")
	_check(bool(room.get("room_guidance_suspended")),
		"equipment unlock notice suspends the route guidance")
	var guidance := room.get("guidance_panel") as Control
	_check(guidance == null or not guidance.visible,
		"equipment unlock notice hides the large route card behind it")
	_check(room.find_child("MayaTutorialBubble", true, false) == null,
		"equipment unlock notice does not stack a second Maya tutorial bubble")
	var portrait := room.find_child("MayaEquipmentUnlockPortrait", true, false) as TextureRect
	_check(portrait != null and str(portrait.get_meta("maya_source_path", "")).ends_with("点子.png"),
		"equipment unlock notice uses the supplied Maya artwork")
	var source := FileAccess.get_file_as_string("res://scripts/ui/observatory_room.gd")
	_check(not source.contains("assets/characters/maya_portrait.png"),
		"the lobby no longer references the legacy pixel Maya portrait")
	room.call("_close_unlock_popup", true)
	for _i in range(3):
		await process_frame
	_check(not bool(room.get("room_guidance_suspended")),
		"closing the equipment notice restores route guidance")
	var room_portrait := room.get("guidance_maya_portrait") as TextureRect
	_check(room_portrait != null and room_portrait.size.x <= 64.0 and room_portrait.size.y <= 104.0,
		"the persistent Maya portrait stays inside its compact portrait area")
	room.queue_free()
	for _i in range(3):
		await process_frame


func _prepare_remote_level(gm: Node, level_number: int) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(level_number, true)
	gm.progress["seen_story_events"] = ["level_%d_before" % level_number]
	var seen_steps: Array = []
	var completed_cards: Array = []
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	var level_steps: Array = teaching.get_steps_for_level(gm.current_level()) if teaching != null else []
	for step_value in level_steps:
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
	gm.reset_assembly()
	for part_type_value in gm.current_level().get("assembly_order", []):
		gm.install_part(str(part_type_value), 0)
	if level_number == 66:
		gm.progress["space_intro_seen"] = true
		gm.progress["space_deployed"] = true


func _tree_has_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _tree_has_label(child, needle):
			return true
	return false


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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	_restore_save()
	print("REMOTE CONSOLE LAYERING TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
