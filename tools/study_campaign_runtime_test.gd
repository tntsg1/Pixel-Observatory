extends SceneTree

const EXPECTED_ORDER: Array[int] = [
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
	13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
]
var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	var mm := root.get_node_or_null("/root/MissionManager")
	var sm := root.get_node_or_null("/root/SaveManager")
	_check(gm != null and mm != null and sm != null, "main-game autoloads are available")
	if gm == null or mm == null or sm == null:
		quit(1)
		return
	_check(gm.study_mode_active(), "study mode is active")
	_check(mm.campaign_order == EXPECTED_ORDER, "research route uses every foundation level from L1 through L24")
	_check(mm.campaign_order_issues().is_empty(), "foundation research route is a valid campaign order")
	for index in range(EXPECTED_ORDER.size() - 1):
		_check(mm.next_level_number(EXPECTED_ORDER[index]) == EXPECTED_ORDER[index + 1],
			"L%d advances sequentially to L%d" % [EXPECTED_ORDER[index], EXPECTED_ORDER[index + 1]])

	gm.progress = gm.default_progress()
	gm.progress["save_initialized"] = true
	gm.progress["completed_levels"] = [1, 2, 3]
	gm.progress["current_level"] = 4
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 4, "sequential L1-L3 completion resumes at L4")
	_check(not bool(gm.progress.get("telescope_ready", false)), "research mode does not auto-assemble the telescope")
	_check(gm.progress.get("unlocked_equipment_stages", []) == ["eye"], "research mode preserves authored equipment unlock progression")

	gm.progress["completed_levels"] = EXPECTED_ORDER.slice(0, EXPECTED_ORDER.size() - 1)
	gm.progress["current_level"] = 24
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 24, "final foundation lesson survives save repair")
	_check(not gm.study_campaign_complete(), "research route remains open before L24 completion")
	gm.progress["completed_levels"].append(24)
	_check(gm.study_campaign_complete(), "research route completes after L24")
	_check(bool(sm.clear_study_progress()), "research save can be cleared independently")
	var restarted: Dictionary = sm.load_progress(gm.default_progress())
	_check(int(restarted.get("current_level", 0)) == 1, "cleared research route restarts at L1")

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
