extends SceneTree

# Telescope-history narrative regression.
# Verifies the first-introduction beats, historical anchors, one-time story
# behavior, and Club Logbook heritage records without changing campaign data.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		print("TELESCOPE HERITAGE STORY TEST FAIL (autoloads missing)")
		quit(1)
		return
	gm.new_game()

	var introductions := [
		{"event": "intro", "level": 1, "anchor": "long chain", "anchor_zh": "观测传承"},
		{"event": "level_3_before_assembly", "level": 3, "anchor": "Galileo", "anchor_zh": "伽利略"},
		{"event": "level_6_before", "level": 6, "anchor": "experienced observers", "anchor_zh": "有经验的观测者"},
		{"event": "level_18_before", "level": 18, "anchor": "older notebooks", "anchor_zh": "旧观测本"},
		{"event": "level_26_before_assembly", "level": 26, "anchor": "Isaac Newton", "anchor_zh": "艾萨克·牛顿"},
		{"event": "level_36_before_assembly", "level": 36, "anchor": "John Dobson", "anchor_zh": "约翰·多布森"},
		{"event": "level_46_before_assembly", "level": 46, "anchor": "Laurent Cassegrain", "anchor_zh": "洛朗·卡塞格林"},
		{"event": "level_66_before_assembly", "level": 66, "anchor": "Sun-Earth L2", "anchor_zh": "日地 L2"},
		{"event": "level_76_before_assembly", "level": 76, "anchor": "Guizhou", "anchor_zh": "贵州"}
	]

	for intro_value in introductions:
		var intro: Dictionary = intro_value
		var event_id := str(intro.get("event", ""))
		var level_number := int(intro.get("level", 1))
		var lines: Array = sm.get_dialogue(event_id)
		_check(lines.size() >= 3 and lines.size() <= 6, "%s has 3-6 concise beats" % event_id)
		_check(_has_beat(lines, "BEFORE", "此前"), "%s has BEFORE beat" % event_id)
		_check(_has_beat(lines, "BREAKTHROUGH", "突破"), "%s has BREAKTHROUGH beat" % event_id)
		_check(_has_beat(lines, "HANDOFF", "交给你"), "%s has HANDOFF beat" % event_id)
		_check(_contains_bilingual(lines, str(intro.get("anchor", "")), str(intro.get("anchor_zh", ""))), "%s has accurate bilingual anchor" % event_id)
		for line_value in lines:
			if not line_value is Dictionary:
				continue
			var line: Dictionary = line_value
			_check(str(line.get("text_en", "")) != "", "%s English line is complete" % event_id)
			_check(str(line.get("text_zh", "")) != "", "%s Chinese line is complete" % event_id)

		gm.debug_jump_to_level(level_number, false)
		_check(sm.begin_event(event_id, "observatory"), "%s plays on first introduction" % event_id)
		sm.finish_active_event()
		await process_frame
		_check(sm.has_seen(event_id, gm.progress), "%s is recorded as seen" % event_id)
		_check(not sm.begin_event(event_id, "observatory"), "%s does not replay" % event_id)
		_check(not sm.record_telescope_heritage(event_id), "%s heritage entry does not duplicate" % event_id)

	var heritage_entries := 0
	for entry_value in gm.progress.get("journal_entries", []):
		if entry_value is Dictionary and str(entry_value.get("entry_kind", "")) == "telescope_heritage":
			heritage_entries += 1
			var entry: Dictionary = entry_value
			_check(str(entry.get("before_en", "")) != "" and str(entry.get("before_zh", "")) != "", "heritage BEFORE is bilingual")
			_check(str(entry.get("breakthrough_en", "")) != "" and str(entry.get("breakthrough_zh", "")) != "", "heritage BREAKTHROUGH is bilingual")
			_check(str(entry.get("learned_en", "")) != "" and str(entry.get("learned_zh", "")) != "", "heritage hands-on line is bilingual")
	_check(heritage_entries == introductions.size(), "one heritage entry recorded for each introduction")

	var refractor_text := _combined_text(sm.get_dialogue("level_3_before_assembly"))
	_check(not refractor_text.to_lower().contains("galileo invented"), "refractor story does not claim Galileo invented the telescope")
	var newtonian_text := _combined_text(sm.get_dialogue("level_26_before_assembly"))
	_check(newtonian_text.contains("not your mistake"), "Newtonian transition relieves player blame")
	_check(newtonian_text.contains("collimat"), "Newtonian handoff introduces collimation responsibility")
	var fast_text := _combined_text(sm.get_dialogue("level_76_before_assembly"))
	_check(fast_text.contains("RFI") and fast_text.contains("dispersion") and fast_text.contains("SNR"), "FAST handoff uses radio-specific operations")

	if failures == 0:
		print("TELESCOPE HERITAGE STORY TEST PASS")
		quit(0)
	else:
		print("TELESCOPE HERITAGE STORY TEST FAIL (%d)" % failures)
		quit(1)


func _has_beat(lines: Array, english: String, chinese: String) -> bool:
	for line_value in lines:
		if not line_value is Dictionary:
			continue
		var line: Dictionary = line_value
		if str(line.get("beat_en", "")) == english and str(line.get("beat_zh", "")) == chinese:
			return true
	return false


func _contains_bilingual(lines: Array, english: String, chinese: String) -> bool:
	var found_en := false
	var found_zh := false
	for line_value in lines:
		if not line_value is Dictionary:
			continue
		var line: Dictionary = line_value
		found_en = found_en or str(line.get("text_en", "")).to_lower().contains(english.to_lower())
		found_zh = found_zh or str(line.get("text_zh", "")).contains(chinese)
	return found_en and found_zh


func _combined_text(lines: Array) -> String:
	var text := ""
	for line_value in lines:
		if line_value is Dictionary:
			text += str(line_value.get("text_en", "")) + "\n"
	return text


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
