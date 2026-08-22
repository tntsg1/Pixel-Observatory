extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.language_mode = "en"
	_check(gm.position_source_label("online") == "AstronomyAPI live", "online ephemeris names its live provider")
	_check(gm.position_source_label("calculated") == "Local calculation", "local astronomy is not labelled offline")
	_check(gm.position_source_label("planet_ephemeris") == "Local calculation", "local planet ephemeris is labelled Local calculation")
	_check(gm.position_source_label("fallback") == "Teaching simulation", "catalog teaching coordinates are labelled Teaching simulation")
	_check(gm.position_source_label("missing") == "Offline fallback", "only missing position data uses Offline fallback")
	gm.language_mode = "zh"
	_check(gm.position_source_label("calculated") == "本地计算", "Chinese local-calculation label is valid UTF-8")
	gm.language_mode = "en"
	print("LOCAL CALCULATION STATUS TEST PASS" if failures == 0 else "LOCAL CALCULATION STATUS TEST FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
