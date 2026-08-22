extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	_check(gm != null and mm != null, "campaign autoloads are available")
	if gm == null or mm == null:
		quit(1)
		return

	var active_levels: Array = mm.campaign_order
	_check(not active_levels.is_empty() and int(active_levels[-1]) == 85, "FAST Graduation L85 is the campaign endpoint")
	_check(active_levels.all(func(value): return int(value) <= 85), "campaign order contains no post-FAST level")
	_check(mm.get_level(85).get("title_en", "") == "FAST Graduation", "L85 is the FAST graduation lesson")
	_check(mm.get_level(86).is_empty() and mm.get_level(131).is_empty(), "retired L86-L131 data is absent")
	_check(gm.available_level_numbers() == active_levels, "developer level list exactly matches campaign order")

	gm.new_game()
	gm.debug_jump_to_level(131, false)
	_check(int(gm.progress.get("current_level", 0)) == 85, "direct debug jump beyond FAST clamps to L85")

	# The migration case must behave like a real loaded save, not like the
	# disposable developer sandbox exercised above.
	gm.new_game()
	gm.progress = gm.default_progress()
	gm.progress["campaign_version"] = 93
	gm.progress["current_level"] = 100
	gm.progress["completed_levels"] = active_levels.duplicate()
	gm.progress["credits"] = 987
	gm._normalize_progress()
	_check(int(gm.progress.get("current_level", 0)) == 85, "old post-FAST save settles on L85")
	_check(int(gm.progress.get("credits", 0)) == 987, "old-save credits are preserved")
	_check(bool(gm.progress.get("program_completed", false)), "completed FAST save is marked as program complete")
	_check((gm.progress.get("completed_levels", []) as Array).all(func(value): return int(value) <= 85), "retired completion ids do not remain active")

	if failures == 0:
		print("POST-FAST RETIREMENT TEST PASS")
		quit(0)
	else:
		print("POST-FAST RETIREMENT TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
