extends SceneTree

# Reproduces the normal new-save path through L5 with only period-correct
# starter equipment. The original save is restored before this script exits.

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_check(false, "GameManager autoload is available")
		_finish()
		return

	gm.new_game()
	_complete_naked_eye(gm, 1, "moon")
	_complete_naked_eye(gm, 2, "polaris")
	_complete_basic_refractor(gm)
	_complete_focus_training(gm)
	_verify_l5_jupiter(gm)
	_finish()


func _complete_naked_eye(gm: Node, expected_level: int, target_id: String) -> void:
	_check(int(gm.progress.get("current_level", 0)) == expected_level, "L%d is current" % expected_level)
	gm.selected_object_id = target_id
	var observation: Dictionary = gm.evaluate_selected_object()
	_check(bool(observation.get("success", false)), "L%d naked-eye observation succeeds" % expected_level)
	_check(gm.complete_current_mission(target_id, observation), "L%d completes normally" % expected_level)


func _complete_basic_refractor(gm: Node) -> void:
	_check(int(gm.progress.get("current_level", 0)) == 3, "L3 follows L2")
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	_check(bool(gm.can_enter_observation().get("ok", false)), "L3 basic refractor is ready")
	gm.selected_object_id = "moon"
	var observation: Dictionary = gm.evaluate_selected_object()
	_check(bool(observation.get("success", false)), "L3 Moon observation succeeds")
	_check(gm.complete_current_mission("moon", observation), "L3 completes normally")


func _complete_focus_training(gm: Node) -> void:
	_check(int(gm.progress.get("current_level", 0)) == 4, "L4 follows L3")
	_check(gm.install_part("focus_knob", 0, "basic_focus_knob") > 0, "L4 installs the unlocked focus knob")
	# L4's focus training now uses Betelgeuse (a point source). L5 is still the
	# Jupiter magnification lesson this test exists to protect.
	var l4_target := str(gm.current_target_object_id())
	_check(l4_target == "betelgeuse", "L4 trains focus on Betelgeuse")
	gm.selected_object_id = l4_target
	var observation := _focused_jupiter_observation(gm)
	_check(bool(observation.get("success", false)), "L4 focused star observation succeeds")
	_check(gm.complete_current_mission(l4_target, observation), "L4 completes normally")


func _verify_l5_jupiter(gm: Node) -> void:
	_check(int(gm.progress.get("current_level", 0)) == 5, "L5 follows L4")
	var level: Dictionary = gm.current_level()
	_check(str(level.get("minimum_success_quality", "")) == "Fair", "L5 explicitly accepts Fair starter-equipment quality")
	_check(not gm.progress.get("unlocked_parts", []).has("eyepiece_10mm"), "10mm eyepiece is still locked during L5")
	_check(not gm.progress.get("unlocked_parts", []).has("objective_100mm"), "100mm objective is still locked during L5")
	_check(not gm.progress.get("unlocked_parts", []).has("stable_mount"), "stable mount is still locked during L5")
	_check(str(gm.equipped_part_id("objective")) == "objective_60mm", "L5 uses the 60mm starter objective")
	_check(str(gm.equipped_part_id("eyepiece")) == "eyepiece_20mm", "L5 uses the 20mm starter eyepiece")
	_check(str(gm.equipped_part_id("mount")) == "basic_mount", "L5 uses the basic mount")

	# A 70-point assembly is explicitly accepted by L5's entry gate. Recreate
	# that legal lower-bound state instead of testing only a perfect build.
	var assembly_state: Dictionary = gm.progress.get("assembly_state", {}).duplicate(true)
	for part_type in assembly_state.keys():
		var entry: Dictionary = assembly_state.get(part_type, {})
		if bool(entry.get("installed", false)):
			entry["alignment_score"] = 70
			entry["wrong_attempts"] = 2
			assembly_state[part_type] = entry
	gm.progress["assembly_state"] = assembly_state
	var stats: Dictionary = gm.calculate_stats()
	_check(is_equal_approx(float(stats.get("assembly_score", 0.0)), 70.0), "L5 accepts a 70-point legal assembly")

	gm.selected_object_id = "jupiter"
	var old_default_context := _focused_jupiter_context()
	old_default_context["minimum_success_quality"] = "Good"
	var old_default_result: Dictionary = gm.evaluate_selected_object(old_default_context)
	_check(str(old_default_result.get("quality", "")) == "Fair", "L5 starter equipment produces a legitimate Fair observation")
	_check(not bool(old_default_result.get("success", true)), "the former implicit Good threshold reproduces the L5 soft lock")

	var observation := _focused_jupiter_observation(gm)
	var quality_order := ["Failed", "Poor", "Fair", "Good", "Excellent"]
	var quality := str(observation.get("quality", "Failed"))
	print("  L5 starter result: quality=%s ratios=%s success=%s" % [
		quality,
		str(observation.get("ratios", {})),
		bool(observation.get("success", false)),
	])
	_check(quality_order.find(quality) >= quality_order.find("Fair"), "L5 starter equipment reaches its teaching threshold")
	_check(bool(observation.get("success", false)), "L5 focused and centered Jupiter observation succeeds")
	_check(
		str(observation.get("feedback_zh", "")) == "图像已经可以辨认。现在比较倍率、亮度和视野，不必更换设备。",
		"L5 Chinese feedback does not misdirect the player toward locked upgrades"
	)
	_check(
		str(observation.get("feedback_en", "")).contains("clear enough to compare magnification"),
		"L5 English feedback explains the magnification lesson"
	)
	_check(gm.complete_current_mission("jupiter", observation), "L5 completes without visiting the Parts Cabinet")
	_check(int(gm.progress.get("current_level", 0)) == 6, "successful L5 advances to L6")


func _focused_jupiter_observation(gm: Node) -> Dictionary:
	return gm.evaluate_selected_object(_focused_jupiter_context())


func _focused_jupiter_context() -> Dictionary:
	return {
		"focus_error": 0.0,
		"requires_focus": true,
		"focus_tolerance": 0.06,
		"target_off_center": false,
	}


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("L5 JUPITER REACHABILITY %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
