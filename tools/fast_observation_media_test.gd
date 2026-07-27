extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	_test_fast_media_registry()
	_test_fast_level_assignments()
	_test_heritage_media()
	print("FAST OBSERVATION MEDIA TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _test_fast_media_registry() -> void:
	var registry_value: Variant = _read_json("res://data/fast_observation_media.json")
	_check(registry_value is Dictionary, "FAST observation-media registry parses")
	if not registry_value is Dictionary:
		return
	var registry := registry_value as Dictionary
	for media_id in ["fast_aerial", "fast_feed_cabin", "fast_active_reflector", "pulsar_science"]:
		var entry_value: Variant = registry.get(media_id, {})
		_check(entry_value is Dictionary, "%s has a registry entry" % media_id)
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var path := str(entry.get("image_path", ""))
		_check(str(entry.get("status", "")) == "packaged", "%s is explicitly approved for packaging" % media_id)
		_check(path != "" and ResourceLoader.exists(path), "%s has a loadable local asset" % media_id)
		if path != "":
			var texture: Texture2D = load(path)
			_check(texture != null and texture.get_width() >= 1024 and texture.get_height() >= 576,
				"%s loads as a high-resolution Texture2D" % media_id)
	var control_room: Dictionary = registry.get("fast_control_room", {})
	_check(str(control_room.get("status", "")) == "reference_only", "uncleared FAST control-room media remains reference-only")
	_check(str(control_room.get("image_path", "")) == "", "reference-only control-room media is not packaged")


func _test_fast_level_assignments() -> void:
	var levels_value: Variant = _read_json("res://data/advanced_levels.json")
	_check(levels_value is Array, "advanced level data parses")
	if not levels_value is Array:
		return
	var found := 0
	var media_ids := {}
	for level_value in levels_value as Array:
		if not level_value is Dictionary:
			continue
		var level := level_value as Dictionary
		var number := int(level.get("level_number", 0))
		if number < 76 or number > 85:
			continue
		found += 1
		var media: Dictionary = level.get("observation_media", {})
		var media_id := str(media.get("id", ""))
		_check(media_id != "", "L%d declares observation_media" % number)
		media_ids[media_id] = true
	_check(found == 10, "all ten FAST levels are covered")
	_check(media_ids.size() >= 4, "FAST learning cards use distinct engineering/science media")
	_check(not media_ids.has("pulsar_timing_console"), "no FAST level requests the legacy universal console fallback")


func _test_heritage_media() -> void:
	var heritage_value: Variant = _read_json("res://data/telescope_heritage.json")
	_check(heritage_value is Dictionary, "telescope heritage data parses")
	if not heritage_value is Dictionary:
		return
	var heritage := heritage_value as Dictionary
	_check(heritage.size() == 9, "all nine telescope-history nodes remain present")
	var archive_count := 0
	for entry_value in heritage.values():
		if not entry_value is Dictionary:
			continue
		var path := str((entry_value as Dictionary).get("diagram", ""))
		_check(path != "" and ResourceLoader.exists(path), "heritage media path remains loadable")
		if path.begins_with("res://assets/learning_media/heritage/"):
			archive_count += 1
	_check(archive_count == 7, "seven heritage nodes now use cleared archival media")


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  OK  ", message)
	else:
		failures += 1
		print("  FAIL ", message)
