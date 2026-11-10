extends SceneTree

# Story-system audit regression: every active campaign level must have a trackable
# narrative/teaching entry, L25+ must have real (non-fallback) story
# content, mechanics with first-time stories must exist, nothing replays,
# and journal entries never duplicate identical knowledge cards.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	var tfm: Node = root.get_node_or_null("/root/TeachingFlowManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	if gm == null or sm == null or tfm == null or mm == null:
		print("STORY AUDIT TEST FAIL (autoloads missing)")
		quit(1)
		return
	gm.new_game()

	var wired_triggers := ["before_observation", "before_assembly", "before_focus", "before_identify", "before_collimation"]
	var family_intro := {
		"newtonian": 26, "dobsonian": 36, "cassegrain": 46,
		"gregorian": 56, "space_segmented": 66, "fast_radio": 76
	}

	for level_value in mm.campaign_order:
		var level_number := int(level_value)
		var level: Dictionary = mm.get_level(level_number)
		_check(not level.is_empty(), "L%d exists" % level_number)
		if level.is_empty():
			continue
		var chapter: Dictionary = sm.call("_chapter_for_level", level_number)
		_check(not chapter.is_empty(), "L%d belongs to an authored narrative chapter" % level_number)
		# 1. Trackable entry: a story event mapped for the level OR at least
		# one teaching step (explicit or fallback from required_concept_card).
		var has_story := false
		for trigger_value in sm.TRIGGER_SUFFIXES.keys():
			var event_id: String = sm.event_for_trigger(str(trigger_value), level_number)
			if event_id != "":
				has_story = true
		var steps: Array = tfm.get_steps_for_level(level)
		_check(has_story or not steps.is_empty(), "L%d has a story or teaching entry" % level_number)
		# 2. Teaching data integrity: cards exist, triggers are wired.
		var concept_id := str(level.get("required_concept_card", ""))
		if concept_id != "":
			_check(not gm.get_learning_card(concept_id).is_empty(), "L%d concept card '%s' exists" % [level_number, concept_id])
		for step_value in steps:
			if not step_value is Dictionary:
				continue
			var step: Dictionary = step_value
			_check(wired_triggers.has(str(step.get("trigger", ""))), "L%d teaching trigger '%s' is wired in UI" % [level_number, str(step.get("trigger", ""))])
			_check(not gm.get_learning_card(str(step.get("card_id", ""))).is_empty(), "L%d step card '%s' exists" % [level_number, str(step.get("card_id", ""))])
		# 3. L25-45: real story content, not the generic family fallback.
		if level_number >= 25:
			var found_real := false
			for trigger_value in sm.TRIGGER_SUFFIXES.keys():
				var event_id: String = sm.event_for_trigger(str(trigger_value), level_number)
				if event_id != "" and sm.dialogues.has(event_id):
					found_real = true
			var epilogue_id := "level_%d_after" % level_number
			_check(found_real or sm.dialogues.has(epilogue_id), "L%d has authored story content" % level_number)
			_check(sm.dialogues.has(epilogue_id), "L%d has completion epilogue lines" % level_number)
		# 4. Board note coverage.
		_check(not sm.board_note_for_level(level_number).is_empty(), "L%d has a mission board note" % level_number)

	# 5. Family first-introduction events resolve to authored dialogue.
	for family_value in family_intro.keys():
		var intro_level: int = int(family_intro[family_value])
		var found := ""
		for trigger_value in sm.TRIGGER_SUFFIXES.keys():
			var event_id: String = sm.event_for_trigger(str(trigger_value), intro_level)
			if event_id != "" and sm.dialogues.has(event_id):
				found = event_id
		_check(found != "", "family '%s' has an authored intro event at L%d" % [str(family_value), intro_level])

	# 6. First-time mechanic stories exist.
	for mechanic in ["tube_subassembly", "collimation"]:
		var mechanic_event := str(sm.MECHANIC_EVENTS.get(mechanic, ""))
		_check(mechanic_event != "" and sm.dialogues.has(mechanic_event), "mechanic '%s' has a first-time story" % mechanic)

	# 7. Stories never replay.
	gm.debug_jump_to_level(25, false)
	_check(sm.begin_event("level_25_before", "observatory"), "L25 before-story plays the first time")
	sm.finish_active_event()
	_check(not sm.begin_event("level_25_before", "observatory"), "L25 before-story refuses to replay")

	# 8. Epilogue plays once, then never again; L1-24 never epilogue.
	_check(sm.begin_epilogue(27, "observatory"), "L27 epilogue plays after completion")
	sm.finish_active_event()
	_check(not sm.begin_epilogue(27, "observatory"), "L27 epilogue refuses to replay")
	_check(not sm.begin_epilogue(12, "observatory"), "L12 keeps recap-only behavior (no epilogue)")

	# 9. Teaching briefs do not re-intercept once seen.
	gm.debug_jump_to_level(36, false)
	var level_36: Dictionary = mm.get_level(36)
	_check(tfm.should_intercept(level_36, "before_assembly", gm.progress), "L36 dobsonian brief intercepts on first assembly")
	_check(tfm.begin_step(level_36, "before_assembly", "assembly"), "L36 brief begins")
	tfm.complete_active_brief(gm.progress)
	tfm.consume_return_scene()
	_check(not tfm.should_intercept(level_36, "before_assembly", gm.progress), "L36 brief never re-intercepts")

	# 10. Journal dedup: same concept twice -> comparison entry, not a clone.
	gm.new_game()
	gm.debug_jump_to_level(36, true)
	gm.progress["journal_entries"] = []
	gm._add_journal_entry(str(gm.current_target_object_id()), {"success": true, "quality": "Good"})
	gm._add_journal_entry(str(gm.current_target_object_id()), {"success": true, "quality": "Excellent"})
	var entries: Array = gm.progress.get("journal_entries", [])
	_check(entries.size() == 2, "two journal entries recorded")
	if entries.size() == 2:
		var first: Dictionary = entries[0]
		var second: Dictionary = entries[1]
		_check(str(first.get("entry_kind_zh", "")) == "首次实验", "first entry marked as first experiment")
		_check(str(second.get("entry_kind_zh", "")) == "对比实验", "repeat entry marked as comparison")
		_check(str(first.get("knowledge_zh", "")) != str(second.get("knowledge_zh", "")), "repeat entry does not clone the knowledge card")

	# 11. Old-save robustness: queries tolerate empty progress dictionaries.
	_check(not sm.has_seen("level_1_before", {}), "has_seen tolerates empty progress")
	_check(tfm.get_pending_step(mm.get_level(1), "before_observation", {}) is Dictionary, "get_pending_step tolerates empty progress")

	if failures == 0:
		print("STORY AUDIT TEST PASS")
		quit(0)
	else:
		print("STORY AUDIT TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
