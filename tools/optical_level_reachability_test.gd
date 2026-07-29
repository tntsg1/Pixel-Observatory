extends SceneTree

const EXPECTED_ACTIVE_LEVEL_COUNT := 75

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	var active_levels: Array[int] = gm.available_level_numbers()
	_check(active_levels.size() == EXPECTED_ACTIVE_LEVEL_COUNT, "campaign exposes exactly 75 active levels")
	for level_number in active_levels:
		gm.new_game()
		gm.debug_jump_to_level(level_number, true)
		var actual_level_number := int(gm.current_level().get("level_number", 0))
		_check(actual_level_number == level_number, "L%d routes to the requested active level" % level_number)
		if actual_level_number == level_number and _is_ground_optical_level(gm.current_level()):
			_test_current_level(level_number)
	_finish()


func _is_ground_optical_level(level: Dictionary) -> bool:
	if str(level.get("observation_mode", "")) != "telescope":
		return false
	var family := str(level.get("telescope_family", "refractor"))
	return family not in ["space_segmented", "fast_radio"]


func _test_current_level(level_number: int) -> void:
	var level: Dictionary = gm.current_level()
	gm.selected_object_id = gm.current_target_object_id()
	gm.set_collimation_score(100.0)
	var stats: Dictionary = gm.calculate_stats()
	var requirements: Dictionary = level.get("observation_requirements", {})
	var context := {
		"observation_mode": "telescope",
		"minimum_success_quality": str(level.get("minimum_success_quality", "Good")),
		"requires_focus": bool(level.get("requires_focus", false)),
		"focus_error": 0.0,
		"focus_tolerance": 0.06,
		"environment": gm.current_environment(),
		"altitude": maxf(float(requirements.get("altitude_min", 45.0)), 60.0),
		"magnification": float(stats.get("magnification", 0.0)),
		"observation_requirements": requirements,
		"filter": str(requirements.get("filter", "none")),
		"dark_adaptation": 1.0,
		"averted_vision": true,
		"tracking_rate": gm.tracking_rate(),
		"observation_elapsed": 120.0,
		"cloud_attenuation": 0.0,
		"target_off_center": false,
	}
	var result: Dictionary = gm.evaluate_selected_object(context)
	var technique: Dictionary = result.get("technique_failure", {})
	var mount_id: String = str(gm.equipped_part_id("mount"))
	var eyepiece_id: String = str(gm.equipped_part_id("eyepiece"))
	var environment: Dictionary = gm.current_environment()
	print("  L%d target=%s mount=%s eyepiece=%s mag=%.1fx env=%s minimum=%s quality=%s success=%s ratios=%s failure=%s" % [
		level_number,
		gm.selected_object_id,
		mount_id,
		eyepiece_id,
		float(stats.get("magnification", 0.0)),
		str(environment),
		str(level.get("minimum_success_quality", "Good")),
		str(result.get("quality", "")),
		bool(result.get("success", false)),
		str(result.get("ratios", {})),
		str(technique.get("code", "")),
	])
	_check(bool(result.get("success", false)), "L%d is completable with its currently unlocked prepared equipment" % level_number)
	_check(not mount_id.is_empty(), "L%d has a compatible prepared mount" % level_number)


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("OPTICAL LEVEL REACHABILITY %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
