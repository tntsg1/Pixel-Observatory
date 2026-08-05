extends SceneTree

# Headless verification for the rotatable finder-scope sky view.
# Run: godot --headless --script res://tools/sky_view_test.gd

const SkyPositionServiceScript := preload("res://scripts/systems/sky_position_service.gd")

const DEFAULT_AZIMUTH := 180.0
const DEFAULT_ALTITUDE := 45.0
const FOV_BASE := 28.0
const FOV_WITH_FINDER := 45.0


func _init() -> void:
	var failures := 0
	failures += _test_shortest_angle()
	failures += _test_dms_format()
	failures += _test_sky_positions()
	if failures == 0:
		print("SKY VIEW TEST: ALL PASSED")
	else:
		print("SKY VIEW TEST: %d FAILURES" % failures)
	quit(failures)


func shortest_angle_degrees(from_deg: float, to_deg: float) -> float:
	var diff := fmod((to_deg - from_deg + 540.0), 360.0) - 180.0
	return diff


func _test_shortest_angle() -> int:
	var failures := 0
	var cases: Array = [
		[350.0, 10.0, 20.0],
		[10.0, 350.0, -20.0],
		[180.0, 180.0, 0.0],
		[0.0, 359.0, -1.0],
		[359.0, 0.0, 1.0],
		[180.0, 200.0, 20.0],
		[180.0, 160.0, -20.0],
		[90.0, 270.0, 180.0]
	]
	for case_value in cases:
		var case_data: Array = case_value
		var got := shortest_angle_degrees(float(case_data[0]), float(case_data[1]))
		var expected := float(case_data[2])
		if absf(got - expected) > 0.001 and not (absf(expected) == 180.0 and absf(absf(got) - 180.0) < 0.001):
			print("FAIL shortest_angle(%s, %s) = %s, expected %s" % [case_data[0], case_data[1], got, expected])
			failures += 1
	print("shortest_angle_degrees: %s" % ("ok" if failures == 0 else "FAILED"))
	return failures


func _test_dms_format() -> int:
	var failures := 0
	var cases: Array = [
		[0.0, "0°00'00\""],
		[45.5, "45°30'00\""],
		[12.999722, "12°59'59\""],
		[359.9999, "360°00'00\""],
		[-4.25, "-4°15'00\"", true]
	]
	for case_value in cases:
		var case_data: Array = case_value
		var signed := false
		if case_data.size() > 2:
			signed = bool(case_data[2])
		var got: String = _format_dms_for_test(float(case_data[0]), signed)
		var expected: String = str(case_data[1])
		if got != expected:
			print("FAIL _format_dms(%s) = %s, expected %s" % [case_data[0], got, expected])
			failures += 1
	print("_format_dms: %s" % ("ok" if failures == 0 else "FAILED"))
	return failures


func _format_dms_for_test(value: float, signed: bool = false) -> String:
	var sign := ""
	var amount := value
	if signed and value < 0.0:
		sign = "-"
		amount = -value
	elif signed and value > 0.0:
		sign = "+"
	amount = absf(amount)
	var degrees := int(floor(amount))
	var minutes_float := (amount - float(degrees)) * 60.0
	var minutes := int(floor(minutes_float))
	var seconds := int(round((minutes_float - float(minutes)) * 60.0))
	if seconds >= 60:
		seconds -= 60
		minutes += 1
	if minutes >= 60:
		minutes -= 60
		degrees += 1
	return "%s%d°%02d'%02d\"" % [sign, degrees, minutes, seconds]


func _test_sky_positions() -> int:
	var failures := 0
	var service: RefCounted = SkyPositionServiceScript.new()
	var data: Dictionary = service.get_sky_positions(Rect2(40, 72, 650, 560))
	if data.size() != 34:
		print("FAIL: expected 34 catalog objects, got %d" % data.size())
		failures += 1

	print("--- tonight's positions (offline/calculated pass) ---")
	var ids: Array = data.keys()
	ids.sort()
	for id_value in ids:
		var object_id: String = str(id_value)
		var item: Dictionary = data[object_id]
		print("%-14s alt %7.2f  az %7.2f  %-10s %s" % [
			object_id,
			float(item.get("altitude", 0.0)),
			float(item.get("azimuth", 0.0)),
			str(item.get("source", "?")),
			str(item.get("visibility_text", "?"))
		])
		if not item.has("altitude") or not item.has("azimuth") or not item.has("source"):
			print("FAIL: %s missing required fields" % object_id)
			failures += 1

	print("--- default view az %.0f alt %.0f ---" % [DEFAULT_AZIMUTH, DEFAULT_ALTITUDE])
	for fov in [FOV_BASE, FOV_WITH_FINDER]:
		var visible_ids: Array[String] = []
		for id_value in ids:
			var object_id: String = str(id_value)
			var item: Dictionary = data[object_id]
			var altitude: float = float(item.get("altitude", 0.0))
			var delta_az := shortest_angle_degrees(DEFAULT_AZIMUTH, float(item.get("azimuth", 0.0)))
			var delta_alt := altitude - DEFAULT_ALTITUDE
			if altitude > 0.0 and absf(delta_az) <= float(fov) * 0.5 and absf(delta_alt) <= float(fov) * 0.5:
				visible_ids.append(object_id)
		print("FOV %2.0f deg -> in view: %s" % [float(fov), ", ".join(visible_ids) if not visible_ids.is_empty() else "(none)"])

	# Every non-constellation target needs a dedicated visual. Deep-sky targets
	# use their real science image as a low-light finder thumbnail; no two may
	# silently share the old generic purple-nebula fallback.
	var object_index := _load_object_index()
	var science_paths: Dictionary = {}
	var science_backed_count := 0
	for id_value in ids:
		var object_id := str(id_value)
		var object_data: Dictionary = object_index.get(object_id, {})
		var path := str(object_data.get("sky_icon_path", ""))
		if path == "":
			path = "res://assets/celestial_icons/%s.png" % object_id
		if not ResourceLoader.exists(path):
			print("FAIL: missing icon %s" % path)
			failures += 1
		if object_data.has("sky_icon_path"):
			science_backed_count += 1
			if science_paths.has(path):
				print("FAIL: %s and %s share science-backed icon %s" % [object_id, science_paths[path], path])
				failures += 1
			science_paths[path] = object_id
			if path.contains("/temporary/"):
				print("FAIL: %s still uses temporary art %s" % [object_id, path])
				failures += 1
	if science_backed_count != 14:
		print("FAIL: expected 14 science-backed deep-sky icons, got %d" % science_backed_count)
		failures += 1
	print("icon files: %s" % ("ok" if failures == 0 else "check output"))
	return failures


func _load_object_index() -> Dictionary:
	var result: Dictionary = {}
	for path in ["res://data/celestial_objects.json", "res://data/expansion/celestial_objects.json"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Array:
			continue
		for value in parsed:
			if value is Dictionary:
				var item: Dictionary = value
				result[str(item.get("id", ""))] = item
	return result
