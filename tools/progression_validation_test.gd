extends SceneTree

var failures := 0
var had_save := false
var original_save := ""


func _initialize() -> void:
	await process_frame
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.READ)
		if save_file != null:
			original_save = save_file.get_as_text()
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	_check(gm != null and mm != null, "autoloads available")
	if gm == null or mm == null:
		quit(1)
		return
	main_progression_test(gm, mm)
	unlock_consistency_test(gm)
	old_save_migration_test(gm)
	campaign_order_integrity_test(mm)
	assembly_gate_test(gm)
	finder_scope_progression_test(gm, mm)
	space_unlock_installation_test(gm, mm)
	early_moon_comparison_test(mm)
	_restore_save()
	if failures == 0:
		print("PROGRESSION VALIDATION TEST PASS")
		quit(0)
	else:
		print("PROGRESSION VALIDATION TEST FAIL (%d)" % failures)
		quit(1)


func main_progression_test(gm: Node, mm: Node) -> void:
	gm.new_game()
	_check(int(gm.progress.get("current_level", 0)) == 1, "main_progression_test: new game starts at L1")
	for level_number in range(1, 11):
		_check(mm.next_level_number(level_number) == level_number + 1, "main_progression_test: L%d -> L%d" % [level_number, level_number + 1])
	var first_ten: Array = mm.campaign_order.slice(0, 10)
	_check(first_ten == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], "main_progression_test: first ten lessons are contiguous")
	_check((mm.campaign_order.slice(0, 10) as Array).all(func(value): return int(value) <= 24), "main_progression_test: first ten never jump above L24")
	_check((mm.campaign_order.slice(0, 24) as Array).all(func(value): return int(value) < 92), "main_progression_test: first 24 never jump into expansion")


func unlock_consistency_test(gm: Node) -> void:
	var issues: Dictionary = gm.all_level_data_issues()
	for level_number in issues.keys():
		print("  data issues L%d: %s" % [int(level_number), "; ".join(issues[level_number])])
	_check(issues.is_empty(), "unlock_consistency_test: every level has legal parts, target, cards, and feedback")


func old_save_migration_test(gm: Node) -> void:
	gm.progress = gm.default_progress()
	gm.progress["campaign_version"] = 91
	gm.progress["current_level"] = 115
	gm.progress["completed_levels"] = [1, 2, 114]
	gm.progress["credits"] = 321
	gm.progress["completed_concept_cards"] = ["eye_imaging"]
	gm.progress["unlocked_parts"].append("newtonian_primary_mirror")
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 3, "old_save_migration_test: old L114 jump resumes at L3")
	_check(int(gm.progress.get("credits", 0)) == 321, "old_save_migration_test: credits are retained")
	_check(not (gm.progress.get("completed_levels", []) as Array).has(114), "old_save_migration_test: retired completion ids are discarded")
	_check(not (gm.progress.get("unlocked_parts", []) as Array).has("newtonian_primary_mirror"), "old_save_migration_test: leaked advanced equipment is removed")
	gm.progress["current_level"] = 999
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 3, "old_save_migration_test: invalid current level safely returns to the next legal lesson")
	gm.progress = gm.default_progress()
	gm.progress["campaign_version"] = int(gm.CAMPAIGN_VERSION)
	gm.progress["current_level"] = 1
	gm.progress["completed_levels"] = [1]
	gm.progress["credits"] = 77
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 2, "old_save_migration_test: completed L1 cursor resumes at L2")
	_check(int(gm.progress.get("credits", 0)) == 77, "old_save_migration_test: interrupted completion repair grants no duplicate credits")


func campaign_order_integrity_test(mm: Node) -> void:
	_check(mm.campaign_order_issues().is_empty(), "campaign_order_integrity_test: no duplicates, missing levels, or invalid ids")
	_check(mm.campaign_order.size() == 75, "campaign_order_integrity_test: 75 active lessons remain after deprecated and post-FAST removal")
	_check(mm.campaign_order[0] == 1 and mm.campaign_order[-1] == 85, "campaign_order_integrity_test: campaign runs from L1 through FAST graduation L85")
	_check((mm.campaign_order as Array).all(func(value): return int(value) <= 85), "campaign_order_integrity_test: no post-FAST lesson remains")


func assembly_gate_test(gm: Node) -> void:
	gm.new_game()
	gm.progress["current_level"] = 6
	var locked: Dictionary = gm.locked_required_equipment()
	_check((locked.get("types", []) as Array).has("finder_scope"), "assembly_gate_test: finder requirement is locked before its teaching")
	_check(not bool(gm.can_enter_observation().get("ok", true)), "assembly_gate_test: locked equipment cannot enter observation")
	_check(str(gm.current_room_route().get("target", "")) == "cabinet", "assembly_gate_test: locked equipment routes to Parts Cabinet")
	_check(gm.install_part("finder_scope", 0) == -1, "assembly_gate_test: locked finder cannot be installed")


func finder_scope_progression_test(gm: Node, mm: Node) -> void:
	var first_required := -1
	for level_number in mm.campaign_order:
		var level: Dictionary = mm.get_level(int(level_number))
		if (level.get("required_parts", []) as Array).has("finder_scope"):
			first_required = int(level_number)
			break
	_check(first_required == 6, "finder_scope_progression_test: L6 is the first finder requirement")
	for level_number in range(1, first_required):
		var level: Dictionary = mm.get_level(level_number)
		_check(not (level.get("required_parts", []) as Array).has("finder_scope"), "finder_scope_progression_test: L%d does not require finder early" % level_number)
	var intro: Dictionary = mm.get_level(5)
	_check((intro.get("unlock_parts", []) as Array).has("basic_finder_scope"), "finder_scope_progression_test: L5 unlocks the finder")
	_check(str(intro.get("required_concept_card", "")) == "magnification_field_of_view", "finder_scope_progression_test: finder introduction has Maya teaching")
	var finder_lesson: Dictionary = mm.get_level(6)
	_check(str(finder_lesson.get("variation", "")) == "finder_calibration", "finder_scope_progression_test: L6 begins finder calibration")
	var finder_steps: Array = finder_lesson.get("teaching_steps", [])
	_check(not finder_steps.is_empty() and str((finder_steps[0] as Dictionary).get("trigger", "")) == "before_assembly", "finder_scope_progression_test: finder principle appears before installation")


func space_unlock_installation_test(gm: Node, mm: Node) -> void:
	gm.new_game()
	gm.progress["current_level"] = 66
	var intro_rewards: Array = mm.get_level(55).get("unlock_parts", [])
	for part_id_value in intro_rewards:
		var part_id := str(part_id_value)
		if not (gm.progress.get("unlocked_parts", []) as Array).has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
	gm.reset_assembly()
	_check(str(gm.current_room_route().get("target", "")) == "cabinet",
		"space_unlock_installation_test: newly unlocked space parts route to the cabinet")
	for part_id_value in gm.current_level().get("required_part_ids", []):
		_check(gm.equip_part(str(part_id_value)), "space_unlock_installation_test: required space part can be equipped")
	_check(str(gm.current_room_route().get("target", "")) == "assembly",
		"space_unlock_installation_test: equipped space parts must still be installed")
	for part_type_value in gm.current_level().get("required_parts", []):
		_check(gm.install_part(str(part_type_value), 0) >= 0,
			"space_unlock_installation_test: %s installs on the space blueprint" % str(part_type_value))
	_check(str(gm.current_room_route().get("target", "")) == "computer",
		"space_unlock_installation_test: console opens only after installation")


func early_moon_comparison_test(mm: Node) -> void:
	var first_view: Dictionary = mm.get_level(1)
	var refractor_view: Dictionary = mm.get_level(3)
	_check(str(first_view.get("target_object_id", "")) == "moon" and str(first_view.get("observation_mode", "")) == "naked_eye",
		"early_moon_comparison_test: L1 establishes the naked-eye Moon baseline")
	_check(str(refractor_view.get("target_object_id", "")) == "moon"
		and str(refractor_view.get("variation", "")) == "lunar_detail_comparison",
		"early_moon_comparison_test: L3 is an explicit lunar-detail comparison")
	_check(str(refractor_view.get("hint_text_en", "")).to_lower().contains("crater")
		and str(refractor_view.get("hint_text_zh", "")).contains("环形山"),
		"early_moon_comparison_test: L3 tells the player what new detail to inspect")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_string(original_save)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
