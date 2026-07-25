extends SceneTree

# End-to-end reward regression from a completed observation through Credits,
# badge presentation, free-observation logging, and duplicate protection.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return

	_test_first_mission_reward(gm)
	_test_final_mission_badges(gm)
	_test_free_observation_reward(gm)
	_test_badge_localization(gm)

	if failures == 0:
		print("OBSERVATION REWARD PIPELINE TEST PASS")
		quit(0)
	else:
		print("OBSERVATION REWARD PIPELINE TEST FAIL (%d)" % failures)
		quit(1)


func _test_first_mission_reward(gm: Node) -> void:
	gm.new_game()
	var level: Dictionary = gm.current_level()
	var expected_credits := int(level.get("reward_credits", 0))
	var completed: bool = bool(gm.complete_current_mission(
		gm.current_target_object_id(),
		{"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}}
	))
	var summary: Dictionary = gm.last_learning_card.get("reward_summary", {})
	_check(completed, "mission observation completes")
	_check(int(gm.progress.get("credits", 0)) == expected_credits, "Credits are deposited exactly once")
	_check(int(summary.get("credits_awarded", -1)) == expected_credits, "result card receives the deposited Credit amount")
	_check(int(summary.get("credits_total", -1)) == expected_credits, "result card receives the new Credit total")
	_check((summary.get("badges_awarded", []) as Array).has("First Look"), "result card receives the newly earned badge")

	var before_repeat := int(gm.progress.get("credits", 0))
	gm.debug_jump_to_level(1, true)
	gm.complete_current_mission(
		gm.current_target_object_id(),
		{"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}}
	)
	_check(int(gm.progress.get("credits", 0)) == before_repeat, "replaying a completed mission cannot duplicate Credits")


func _test_final_mission_badges(gm: Node) -> void:
	gm.new_game()
	gm.debug_jump_to_level(85, true)
	for step_value in gm.mission_steps():
		var step: Dictionary = step_value
		gm.mark_mission_step_done(str(step.get("id", "")))
	var completed: bool = bool(gm.complete_current_mission(
		gm.current_target_object_id(),
		{"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}}
	))
	var summary: Dictionary = gm.last_learning_card.get("reward_summary", {})
	var awarded: Array = summary.get("badges_awarded", [])
	_check(completed, "final observation completes")
	_check(awarded.has("Radio Graduate"), "final result includes the instrument graduation badge")
	_check(awarded.has("Young Observer"), "final result includes the program-completion badge")
	var card: Node = current_scene
	var card_text := _collect_text(card)
	_check(card_text.contains("CLUB PROGRAM COMPLETE"), "final result shows program completion instead of a fake next level")
	_check(not card_text.contains("NEXT: Level 85"), "final result does not route back to Level 85")
	var result_image := str(card.call("_mission_object_image", gm.get_object(gm.current_target_object_id()))) if card != null and card.has_method("_mission_object_image") else ""
	_check(result_image != "" and ResourceLoader.exists(result_image), "final radio target has a visible result image")


func _test_free_observation_reward(gm: Node) -> void:
	gm.new_game()
	gm.debug_jump_to_level(26, true)
	var before := int(gm.progress.get("credits", 0))
	var result: Dictionary = gm.record_free_observation("jupiter", {"quality": "Good"})
	_check(bool(result.get("new_record", false)), "first free observation creates a log entry")
	_check(int(result.get("credits_awarded", -1)) == gm.FREE_OBSERVATION_CREDITS, "free result reports the actual Credit award")
	_check(int(result.get("credits_total", -1)) == before + gm.FREE_OBSERVATION_CREDITS, "free result reports the resulting Credit total")
	_check((gm.progress.get("observed_objects", []) as Array).has("jupiter"), "free log marks the object as observed")
	var entry: Dictionary = (gm.progress.get("journal_entries", []) as Array).back()
	_check(str(entry.get("telescope_family", "")) == gm.assembly_family(), "free log records the telescope actually selected at the bench")

	var repeat_before := int(gm.progress.get("credits", 0))
	var repeat: Dictionary = gm.record_free_observation("jupiter", {"quality": "Good"})
	_check(bool(repeat.get("repeat", false)), "identical free observation is recognized as a repeat")
	_check(int(repeat.get("credits_awarded", -1)) == 0, "repeat free observation awards no Credits")
	_check(int(gm.progress.get("credits", 0)) == repeat_before, "repeat free observation cannot duplicate Credits")


func _test_badge_localization(gm: Node) -> void:
	gm.language_mode = "zh"
	var badge_ids: Array[String] = ["Young Observer"]
	for level_value in gm.levels_data:
		var level: Dictionary = level_value
		var level_badge := str(level.get("badge", ""))
		if level_badge != "" and not badge_ids.has(level_badge):
			badge_ids.append(level_badge)
	for badge in badge_ids:
		_check(gm.badge_display_name(badge) != badge, "Chinese badge name exists: " + badge)
	gm.language_mode = "en"
	_check(gm.badge_display_name("Young Observer") == "Young Observer", "English badge name remains stable")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


func _collect_text(node: Node) -> String:
	if node == null:
		return ""
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child in node.get_children():
		result += _collect_text(child)
	return result
