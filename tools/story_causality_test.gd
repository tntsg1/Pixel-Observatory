extends SceneTree

# Narrative causality regression.
# Verifies that every active campaign level belongs to an authored chapter,
# every story handoff has a bilingual reason and physical route, and the
# chapter-spine dialogue follows the campaign that is actually playable.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	if gm == null or sm == null or mm == null:
		print("STORY CAUSALITY TEST FAIL (autoloads missing)")
		quit(1)
		return
	gm.new_game()

	var locations: Dictionary = sm.narrative.get("locations", {})
	for location_id in locations:
		var location: Dictionary = locations[location_id]
		_check(str(location.get("name_en", "")) != "", "%s has English name" % location_id)
		_check(str(location.get("name_zh", "")) != "", "%s has Chinese name" % location_id)
		_check(str(location.get("role_en", "")) != "", "%s has narrative responsibility" % location_id)
		_check(str(location.get("role_zh", "")) != "", "%s has Chinese responsibility" % location_id)

	for level_value in mm.campaign_order:
		var level_number := int(level_value)
		gm.debug_jump_to_level(level_number, false)
		var authored_event := ""
		for trigger_value in sm.TRIGGER_SUFFIXES.keys():
			var candidate: String = sm.event_for_trigger(str(trigger_value), level_number)
			if candidate != "":
				authored_event = candidate
				break
		if authored_event == "":
			authored_event = "level_%d_after" % level_number
		var context: Dictionary = sm.context_for_event(authored_event)
		_check(not context.is_empty(), "L%d has narrative context" % level_number)
		_check(str(context.get("chapter_en", "")) != "", "L%d belongs to an English chapter" % level_number)
		_check(str(context.get("chapter_zh", "")) != "", "L%d belongs to a Chinese chapter" % level_number)
		_check(str(context.get("reason_en", "")) != "", "L%d explains why now" % level_number)
		_check(str(context.get("reason_zh", "")) != "", "L%d explains why now in Chinese" % level_number)
		_check(locations.has(str(context.get("from_id", ""))), "L%d route starts at a real location" % level_number)
		_check(locations.has(str(context.get("to_id", ""))), "L%d route ends at a real location" % level_number)
		_check(str(context.get("action_en", "")) != "", "L%d route has an action" % level_number)
		_check(str(context.get("action_zh", "")) != "", "L%d route has a Chinese action" % level_number)

	var intro_context: Dictionary = sm.context_for_event("intro")
	_check(str(intro_context.get("from_id", "")) == "observatory_room", "intro begins in observatory room")
	_check(str(intro_context.get("to_id", "")) == "observation_pad", "intro leads to observation pad")
	var tube_context: Dictionary = sm.context_for_event("first_tube_subassembly")
	_check(str(tube_context.get("from_id", "")) == "assembly_table", "tube story begins at main assembly")
	_check(str(tube_context.get("to_id", "")) == "tube_blueprint", "tube story leads to tube blueprint")
	var collimation_context: Dictionary = sm.context_for_event("first_collimation")
	_check(str(collimation_context.get("to_id", "")) == "collimation_bench", "collimation story leads to collimation bench")
	var horizon_context: Dictionary = sm.context_for_event("first_below_horizon")
	_check(str(horizon_context.get("from_id", "")) == "observation_pad", "horizon story begins at observation")
	_check(str(horizon_context.get("to_id", "")) == "site_map", "horizon story leads to site map")

	_check(_event_contains(sm, "level_2_after", "Assembly Table", "组装台"), "L2 creates the reason to assemble")
	_check(_event_contains(sm, "level_25_after", "Newtonian", "牛顿"), "L25 failure causes Newtonian switch")
	_check(_event_contains(sm, "level_35_after", "larger mirror", "更大的主镜"), "Newtonian result causes Dobsonian aperture")
	_check(_event_contains(sm, "level_45_after", "long focal length", "长焦距"), "Dobsonian result causes Cassegrain precision")
	_check(_event_contains(sm, "level_55_after", "Space Telescope Console", "空间望远镜控制台"), "Cassegrain result leads to active space chapter")
	_check(not _event_contains_any(sm, "level_55_after", ["Gregorian", "格里高利"]), "L55 no longer points to retired Gregorian chapter")
	_check(_event_contains(sm, "level_75_after", "FAST", "FAST"), "infrared result causes radio chapter")
	_check(_event_contains(sm, "level_85_after", "ask, predict, measure, compare, record", "提问、预测、测量、比较"), "L85 closes the method arc")
	_check(not _event_contains_any(sm, "level_85_after", ["what happens when", "会发生什么"]), "L85 has no dangling sequel hook")
	_check(str(sm.context_for_event("level_55_after").get("from_id", "")) == "observation_pad", "L55 epilogue still begins at the ground observation pad")
	_check(str(sm.context_for_event("level_75_after").get("from_id", "")) == "space_console", "L75 epilogue begins at the space console")
	_check(str(sm.context_for_event("level_85_after").get("from_id", "")) == "radio_console", "L85 epilogue begins at the radio console")

	if failures == 0:
		print("STORY CAUSALITY TEST PASS")
		quit(0)
	else:
		print("STORY CAUSALITY TEST FAIL (%d)" % failures)
		quit(1)


func _event_contains(sm: Node, event_id: String, english: String, chinese: String) -> bool:
	var found_en := false
	var found_zh := false
	for line_value in sm.get_dialogue(event_id):
		if not line_value is Dictionary:
			continue
		var line: Dictionary = line_value
		found_en = found_en or str(line.get("text_en", "")).contains(english)
		found_zh = found_zh or str(line.get("text_zh", "")).contains(chinese)
	return found_en and found_zh


func _event_contains_any(sm: Node, event_id: String, needles: Array) -> bool:
	for line_value in sm.get_dialogue(event_id):
		if not line_value is Dictionary:
			continue
		var combined := str(line_value.get("text_en", "")) + str(line_value.get("text_zh", ""))
		for needle_value in needles:
			if combined.contains(str(needle_value)):
				return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
