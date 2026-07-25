extends SceneTree

# Verifies the first-use Maya teaching contract:
# authored reason -> controls -> success signal -> recovery, followed by the
# existing concept brief. New mechanics cannot enter the active campaign
# without a registered bilingual tutorial.

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	var tfm: Node = root.get_node_or_null("/root/TeachingFlowManager")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	if gm == null or sm == null or tfm == null or mm == null:
		print("MAYA SKILL TUTORIAL COVERAGE TEST FAIL (autoloads missing)")
		quit(1)
		return

	gm.new_game()
	_check(sm.skill_tutorials.size() >= 30, "registry contains the complete active skill set")

	var first_concept_level: Dictionary = {}
	var tutorial_level_by_card: Dictionary = {}
	var tutorial_levels: Dictionary = {}
	for skill_id_value in sm.skill_tutorials:
		var skill_id := str(skill_id_value)
		var skill: Dictionary = sm.skill_tutorial(skill_id)
		var event_id: String = str(sm.skill_event_id(skill_id))
		var level_number := int(skill.get("level", 0))
		var trigger := str(skill.get("trigger", ""))
		var card_id := str(skill.get("concept_card", ""))
		tutorial_levels[level_number] = true

		_check(level_number > 0, "%s has a valid first-use level" % skill_id)
		_check(trigger in tfm.KNOWN_TRIGGERS, "%s uses a real gameplay trigger" % skill_id)
		_check(not gm.get_learning_card(card_id).is_empty(), "%s links to an existing visual concept card" % skill_id)
		for field in [
			"title_en", "title_zh",
			"why_en", "why_zh",
			"action_en", "action_zh",
			"success_en", "success_zh",
			"recovery_en", "recovery_zh"
		]:
			_check(str(skill.get(field, "")).strip_edges() != "", "%s has %s" % [skill_id, field])
		var lines: Array = sm.get_dialogue(event_id)
		_check(lines.size() == 4, "%s becomes four concise Maya teaching beats" % skill_id)
		for line_value in lines:
			_check(
				line_value is Dictionary
					and str((line_value as Dictionary).get("speaker", "")) == "Maya",
				"%s is spoken by Maya" % skill_id
			)

		if not tutorial_level_by_card.has(card_id):
			tutorial_level_by_card[card_id] = level_number
		else:
			tutorial_level_by_card[card_id] = mini(int(tutorial_level_by_card[card_id]), level_number)

	for level_value in mm.campaign_order:
		var level_number := int(level_value)
		var level: Dictionary = mm.get_level(level_number)
		var card_id := str(level.get("required_concept_card", ""))
		if card_id != "" and not first_concept_level.has(card_id):
			first_concept_level[card_id] = level_number
		if str(level.get("new_mechanic_en", "")).strip_edges() != "":
			_check(tutorial_levels.has(level_number), "L%d new mechanic has a Maya tutorial before use" % level_number)
			_check(str(level.get("new_mechanic_zh", "")).strip_edges() != "", "L%d new mechanic is bilingual" % level_number)
		for step_value in level.get("teaching_steps", []):
			if not step_value is Dictionary:
				continue
			var step: Dictionary = step_value
			var step_card := str(step.get("card_id", ""))
			var has_matching_skill := false
			for skill_value in sm.skill_tutorials.values():
				if skill_value is Dictionary \
						and int((skill_value as Dictionary).get("level", 0)) == level_number \
						and str((skill_value as Dictionary).get("concept_card", "")) == step_card:
					has_matching_skill = true
					break
			_check(has_matching_skill, "L%d explicit teaching card %s has Maya context" % [level_number, step_card])

	for card_id_value in first_concept_level:
		var card_id := str(card_id_value)
		var first_level := int(first_concept_level[card_id])
		_check(tutorial_level_by_card.has(card_id), "%s is introduced by Maya" % card_id)
		if tutorial_level_by_card.has(card_id):
			_check(
				int(tutorial_level_by_card[card_id]) <= first_level,
				"%s is taught no later than first required use (L%d)" % [card_id, first_level]
			)

	# The first campaign handoff combines authored plot and first-use teaching.
	gm.new_game()
	_check(sm.begin_event_for_trigger("before_observation", "sky"), "L1 first observation is intercepted")
	_check(sm.active_event_ids.has("level_1_before"), "L1 keeps its authored plot dialogue")
	_check(sm.active_event_ids.has("maya_skill_eye_observation"), "L1 also includes the Maya skill tutorial")
	_check(sm.active_lines.size() >= 4, "combined dialogue contains the four teaching beats")
	sm.finish_active_event()
	await process_frame
	_check(gm.progress.get("seen_story_events", []).has("maya_skill_eye_observation"), "skill tutorial completion is persisted")
	_check(not sm.begin_event_for_trigger("before_observation", "sky"), "completed Maya tutorial does not replay")

	# Identification was previously a concept-card-only gap.
	gm.new_game()
	gm.debug_jump_to_level(23, false)
	_check(sm.begin_event_for_trigger("before_identify", "telescope"), "L23 identification now has a Maya intercept")
	_check(sm.active_event_ids.has("maya_skill_chromatic_aberration"), "chromatic-aberration identification is taught by Maya")
	sm.reset_flow()

	# The collimation mechanic combines its existing story with operational
	# success and recovery instructions.
	gm.new_game()
	gm.debug_jump_to_level(26, false)
	_check(sm.begin_mechanic_event("collimation", "collimation", "before_collimation"), "first collimation is intercepted")
	_check(sm.active_event_ids.has("first_collimation"), "existing collimation story remains")
	_check(sm.active_event_ids.has("maya_skill_collimation_alignment"), "collimation operation is taught in the same sequence")
	sm.reset_flow()

	# Space-console mechanics use their dedicated entrance rather than relying
	# on the ground telescope path.
	gm.new_game()
	gm.debug_jump_to_level(72, false)
	_check(sm.begin_event_for_trigger("before_observation", "space_observation"), "L72 deep exposure is intercepted")
	_check(sm.active_event_ids.has("maya_skill_space_deep_exposure"), "deep exposure has its own Maya tutorial")
	sm.reset_flow()

	if failures == 0:
		print("MAYA SKILL TUTORIAL COVERAGE TEST PASS")
		quit(0)
	else:
		print("MAYA SKILL TUTORIAL COVERAGE TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
