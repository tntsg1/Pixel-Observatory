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
		# Like the filter and dark-adaptation values above, this models a player
		# who actually performs the technique the level asks for - L50 requires
		# trimming exposure until Venus stops being an overexposed blob.
		"exposure": (float(requirements.get("exposure_min", 0.0)) + float(requirements.get("exposure_max", 1.0))) * 0.5 if (requirements.has("exposure_min") or requirements.has("exposure_max")) else 0.5,
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
	var reachable: bool = bool(result.get("success", false))
	var reached_with := eyepiece_id
	if not reachable:
		# Levels that teach eyepiece choice (L10's low/medium/high comparison)
		# deliberately fail with the highest-power eyepiece - that IS the
		# lesson. What must hold is that SOME unlocked eyepiece completes them.
		var retry := _retry_across_eyepieces(level, context)
		reachable = bool(retry.get("success", false))
		reached_with = str(retry.get("eyepiece_id", ""))
		if reachable:
			print("    (reachable instead with %s)" % reached_with)
		# Restore the prepared loadout so later assertions see the real state.
		if eyepiece_id != "":
			gm.equip_part(eyepiece_id)
			gm.install_part("eyepiece", 0)
	_check(reachable, "L%d is completable with its currently unlocked equipment" % level_number)
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


# Tries every unlocked eyepiece for the current level and returns the first
# that completes it.
func _retry_across_eyepieces(level: Dictionary, context: Dictionary) -> Dictionary:
	for option_value in gm.unlocked_parts_by_type("eyepiece"):
		if not option_value is Dictionary:
			continue
		var option: Dictionary = option_value
		var option_id := str(option.get("id", ""))
		if option_id == "" or not gm.equip_part(option_id):
			continue
		gm.install_part("eyepiece", 0)
		var retry_stats: Dictionary = gm.calculate_stats()
		var retry_context: Dictionary = context.duplicate(true)
		retry_context["magnification"] = float(retry_stats.get("magnification", 0.0))
		var retry_result: Dictionary = gm.evaluate_selected_object(retry_context)
		if bool(retry_result.get("success", false)):
			return {"success": true, "eyepiece_id": option_id}
	return {"success": false, "eyepiece_id": ""}
