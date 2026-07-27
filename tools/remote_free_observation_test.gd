extends SceneTree

# Run:
# Godot --headless --path <project> --script res://tools/remote_free_observation_test.gd

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager autoload exists")
	if gm == null:
		_finish()
		return

	gm.new_game()
	_check(gm.remote_free_catalog("space").size() == 8, "space free catalog contains eight deep-sky programs")
	_check(gm.remote_free_catalog("radio").size() == 3, "FAST free catalog contains three radio programs")
	for value in gm.remote_free_catalog("space"):
		var entry := value as Dictionary
		_check(str(entry.get("category_en", "")).to_lower() != "planet",
			"space catalog excludes planets: %s" % str(entry.get("id", "")))
		var profile := entry.get("profile", {}) as Dictionary
		var image_path := str(profile.get("science_image_path", ""))
		_check(image_path == "" or ResourceLoader.exists(image_path),
			"space science asset exists: %s" % str(entry.get("id", "")))
	var radio_kinds: Array[String] = []
	for value in gm.remote_free_catalog("radio"):
		var entry := value as Dictionary
		radio_kinds.append(str((entry.get("profile", {}) as Dictionary).get("kind", "")))
	_check(radio_kinds.has("pulsar") and radio_kinds.has("hi_line") and radio_kinds.has("repeating_frb"),
		"FAST catalog exposes pulsar, HI and repeating-FRB programs")

	_check(not gm.remote_free_unlocked("space"), "new save does not unlock Space free observation early")
	_check(not gm.remote_free_unlocked("radio"), "new save does not unlock FAST free observation early")
	_check(not gm.begin_remote_free_observation("space", "andromeda_infrared"),
		"locked free program cannot be entered")

	gm.progress["completed_levels"] = [66]
	gm.progress["current_level"] = 67
	_check(gm.remote_free_unlocked("space"), "first Space campaign observation permanently unlocks free time")
	_check(not gm.remote_free_unlocked("radio"), "Space completion does not unlock FAST")
	_check(gm.begin_remote_free_observation("space", "andromeda_infrared"),
		"unlocked Space catalog entry starts")
	_check(gm.is_remote_free_observation("space"), "Space free context is separate from campaign")
	var level_before := int(gm.progress.get("current_level", 0))
	var completed_before := (gm.progress.get("completed_levels", []) as Array).duplicate()
	var space_record: Dictionary = gm.record_remote_free_observation("space", {
		"quality": "Good",
		"instrument": "NIRCam",
		"filter": "R=MIR G=NIR-L B=NIR-S",
		"exposure": 360.0,
		"snr": 14.2,
	})
	_check(bool(space_record.get("recorded", false)), "Space free result is archived")
	_check(int(gm.progress.get("current_level", 0)) == level_before, "Space free result does not advance current level")
	_check((gm.progress.get("completed_levels", []) as Array) == completed_before,
		"Space free result does not alter completed missions")

	gm.remote_observation_context.clear()
	gm.progress["completed_levels"].append(76)
	gm.progress["current_level"] = 77
	_check(gm.remote_free_unlocked("radio"), "first FAST campaign observation permanently unlocks free time")
	for entry_id in ["pulsar_clock", "galactic_hi", "repeating_frb"]:
		_check(gm.begin_remote_free_observation("radio", entry_id), "FAST program starts: " + entry_id)
		var entry: Dictionary = gm.active_remote_free_entry("radio")
		var expected_kind := str(entry.get("result_kind", ""))
		var result: Dictionary = gm.record_remote_free_observation("radio", {
			"quality": "Good",
			"instrument": "FAST",
			"integration_s": 180.0,
			"snr": 12.5,
		})
		_check(bool(result.get("recorded", false)), "FAST result archives: " + entry_id)
		_check(str((result.get("record", {}) as Dictionary).get("result_kind", "")) == expected_kind,
			"FAST archive preserves evidence type: " + expected_kind)
		gm.remote_observation_context.clear()

	# Simulate an old save made after the chapter began but before these arrays
	# existed. Normalization must add them without relocking legal progress.
	gm.progress.erase("remote_observation_archive")
	gm.progress.erase("remote_free_intro_seen")
	gm.progress["completed_levels"] = [70, 80]
	gm.progress["current_level"] = 81
	gm.call("_normalize_progress")
	_check(gm.progress.get("remote_observation_archive", null) is Array,
		"old save migration adds the archive")
	_check(gm.progress.get("remote_free_intro_seen", null) is Array,
		"old save migration adds intro history")
	_check(gm.remote_free_unlocked("space") and gm.remote_free_unlocked("radio"),
		"old legal chapter progress remains unlocked")

	await _test_console_ui(gm)
	var space_source := FileAccess.get_file_as_string("res://scripts/ui/space_observation.gd")
	var radio_source := FileAccess.get_file_as_string("res://scripts/ui/radio_observation.gd")
	_check(space_source.contains("record_remote_free_observation(\"space\""),
		"Space submit path records free observations")
	_check(radio_source.contains("record_remote_free_observation(\"radio\""),
		"FAST submit path records free observations")
	_check(space_source.contains("is_remote_free_observation(\"space\")"),
		"Space tutorials distinguish free observation")
	_check(radio_source.contains("is_remote_free_observation(\"radio\")"),
		"FAST tutorials distinguish free observation")
	_finish()


func _test_console_ui(gm: Node) -> void:
	gm.language_mode = "en"
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(5):
		await process_frame
	room.call("_toggle_remote_instrument_console")
	await process_frame
	var popup := room.get("stats_terminal_popup") as Control
	_check(popup != null, "Remote Instrument Console opens")
	_check(_tree_has_text(popup, "SPACE INFRARED OBSERVATORY"), "console lists Space")
	_check(_tree_has_text(popup, "FAST RADIO ARRAY"), "console lists FAST")
	_check(_tree_has_text(popup, "FREE OBSERVATION"), "console exposes permanent free-observation actions")
	if popup != null:
		popup.queue_free()
		room.set("stats_terminal_popup", null)
		room.set("stats_terminal_animating", false)
	var room_source := FileAccess.get_file_as_string("res://scripts/ui/observatory_room.gd")
	_check(
		room_source.contains("_enter_space_console(kind, \"free\")"),
		"free action routes into the instrument instead of making a target-list choice")
	_check(
		FileAccess.file_exists("res://tools/space_target_acquisition_test.gd")
		and FileAccess.file_exists("res://tools/fast_target_acquisition_test.gd"),
		"instrument-internal acquisition has dedicated interaction regression tests")
	room.queue_free()
	for _i in range(3):
		await process_frame


func _tree_has_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and str(node.get("text")).contains(needle):
		return true
	for child in node.get_children():
		if _tree_has_text(child, needle):
			return true
	return false


func _count_buttons(node: Node) -> int:
	var count := 1 if node is Button else 0
	for child in node.get_children():
		count += _count_buttons(child)
	return count


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  FAIL: " + label)


func _finish() -> void:
	_restore_save()
	print("REMOTE FREE OBSERVATION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
