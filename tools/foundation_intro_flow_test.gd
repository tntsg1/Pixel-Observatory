extends SceneTree

# Foundation chapter regression. L1-L10 use supervised club training times and
# cannot enter the site-map workflow before Maya teaches it.

const SAVE_PATH := "user://savegame.json"

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var story: Node = root.get_node_or_null("/root/StoryManager")
	if gm == null or story == null:
		print("FOUNDATION INTRO FLOW TEST FAIL (autoloads missing)")
		_restore_save()
		quit(1)
		return

	gm.new_game()
	for level_number in range(1, 11):
		gm.debug_jump_to_level(level_number, false)
		_check(bool(gm.uses_foundation_training_schedule()), "L%d uses the supervised club schedule" % level_number)
		var lesson_time: Dictionary = gm.observation_utc_datetime()
		_check(bool(lesson_time.get("foundation_training", false)), "L%d receives a scheduled observing time" % level_number)
		var visibility: Dictionary = gm.target_visibility()
		if bool(visibility.get("has_coords", false)):
			_check(float(visibility.get("altitude", -90.0)) >= 0.0, "L%d target is above the club horizon" % level_number)
		_check(not bool(gm.target_requires_relocation()), "L%d cannot require world-map relocation" % level_number)

	gm.debug_jump_to_level(1, false)
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _frame in range(5):
		await process_frame
	_check(sky.get_node_or_null("ChangeSiteButton") == null, "L1 does not expose Change Site before its tutorial")
	var target_id := str(sky.get("target_id"))
	_force_altitude(sky, target_id, -8.0)
	sky.call("_redirect_to_world_map_if_needed")
	_check(not bool(sky.get("horizon_explanation_active")), "L1 ignores stale below-horizon redirects")
	_check(sky.get_node_or_null("BelowHorizonExplanation") == null, "L1 does not create the relocation overlay")
	var item: Dictionary = (sky.get("sky_data") as Dictionary).get(target_id, {})
	_check(str(item.get("source", "")) == "scheduled_calculation", "L1 sky publishes the training-time source")
	sky.queue_free()
	await process_frame

	gm.debug_jump_to_level(11, false)
	_check(not bool(gm.uses_foundation_training_schedule()), "L11 returns to the live sky")
	gm.suppress_next_world_map_redirect = true
	var later_sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(later_sky)
	for _frame in range(4):
		await process_frame
	_check(later_sky.get_node_or_null("ChangeSiteButton") != null, "L11 exposes Change Site after the foundation chapter")
	later_sky.queue_free()
	await process_frame

	var intro: Array = story.get_dialogue("intro")
	var intro_en := ""
	var intro_zh := ""
	for line_value in intro:
		var line: Dictionary = line_value
		intro_en += " " + str(line.get("text_en", ""))
		intro_zh += " " + str(line.get("text_zh", ""))
	_check(intro.size() >= 7, "the club introduction has a complete first-night sequence")
	_check(intro_en.contains("first ten lessons") and intro_zh.contains("前十节基础课"), "Maya explains why L1-L10 stay at the club")
	_check(intro_en.contains("Parts Cabinet") and intro_en.contains("Assembly Table") and intro_en.contains("Club Logbook"), "Maya names the room's working areas")
	_check(intro_zh.contains("零件柜") and intro_zh.contains("组装台") and intro_zh.contains("观测日志"), "the room tour is complete in Chinese")
	_check(intro_en.contains("crater rims") and intro_zh.contains("环形山"), "the second Moon observation has a stated comparison purpose")
	_check(intro_en.contains("WASD") and intro_en.contains("press E") and intro_zh.contains("按 E"), "the first actionable controls are taught")

	_restore_save()
	if failures == 0:
		print("FOUNDATION INTRO FLOW TEST PASS")
		quit(0)
	else:
		print("FOUNDATION INTRO FLOW TEST FAIL (%d)" % failures)
		quit(1)


func _force_altitude(sky: Node, object_id: String, altitude: float) -> void:
	var data: Dictionary = sky.get("sky_data")
	var item: Dictionary = data.get(object_id, {"id": object_id, "azimuth": 120.0})
	item["altitude"] = altitude
	item["below_horizon"] = altitude < 0.0
	item["visible"] = altitude >= 0.0
	data[object_id] = item
	sky.set("sky_data", data)


func _backup_save() -> void:
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
