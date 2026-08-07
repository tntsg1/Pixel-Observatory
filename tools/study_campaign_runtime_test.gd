extends SceneTree

const EXPECTED_ORDER: Array[int] = [16, 4, 10, 11, 20, 22, 25, 74, 84]
var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	var mm := root.get_node_or_null("/root/MissionManager")
	_check(gm != null and mm != null, "main-game autoloads are available")
	if gm == null or mm == null:
		quit(1)
		return
	_check(gm.study_mode_active(), "study mode is active")
	_check(mm.campaign_order == EXPECTED_ORDER, "original levels use the extracted research order")
	_check(mm.campaign_order_issues().is_empty(), "research subset is a valid campaign order")
	for index in range(EXPECTED_ORDER.size() - 1):
		_check(mm.next_level_number(EXPECTED_ORDER[index]) == EXPECTED_ORDER[index + 1],
			"L%d jumps directly to L%d" % [EXPECTED_ORDER[index], EXPECTED_ORDER[index + 1]])

	gm.progress = gm.default_progress()
	gm.progress["save_initialized"] = true
	gm.progress["completed_levels"] = [16]
	gm.progress["current_level"] = 4
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 4, "non-contiguous L16 to L4 survives save repair")
	gm._prepare_study_inventory()
	var allowed_exceptions: Array = gm.current_level().get("required_part_ids", []).duplicate()
	allowed_exceptions.append_array(gm.current_level().get("recommended_part_ids", []))
	var leaked: Array[String] = []
	for part_id_value in gm.progress.get("unlocked_parts", []):
		var part: Dictionary = gm.get_part(str(part_id_value))
		if not part.is_empty() and int(part.get("unlock_level", 999)) > 4 and not allowed_exceptions.has(str(part_id_value)):
			leaked.append(str(part_id_value))
	_check(leaked.is_empty(), "L4 inventory contains no later-campaign optics: %s" % ", ".join(leaked))

	gm.progress["completed_levels"] = EXPECTED_ORDER.slice(0, EXPECTED_ORDER.size() - 1)
	gm.progress["current_level"] = 84
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 84, "final FAST lesson survives save repair")
	_check(not gm.study_campaign_complete(), "research route remains open before L84 completion")
	gm.progress["completed_levels"].append(84)
	_check(gm.study_campaign_complete(), "research route completes after the original L84 mission")

	if failures == 0:
		print("STUDY CAMPAIGN RUNTIME TEST PASS")
		quit(0)
	else:
		print("STUDY CAMPAIGN RUNTIME TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		failures += 1
		push_error("  FAIL: " + label)
