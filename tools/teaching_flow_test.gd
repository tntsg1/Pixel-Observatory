extends SceneTree

# Teaching Flow State Machine test.
# Run: godot --headless --script res://tools/teaching_flow_test.gd
# NOTE: resets the save - back it up before running.

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var tfm: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or tfm == null:
		print("FAIL: autoloads missing")
		quit(1)
		return
	gm.new_game()

	# --- 1. fresh state ------------------------------------------------------
	_check(gm.progress.get("seen_teaching_steps", []).is_empty(), "new game: seen_teaching_steps empty")
	_check(gm.progress.get("completed_concept_cards", []).is_empty(), "new game: completed_concept_cards empty")

	# --- 2. Level 1 brief before observation ---------------------------------
	var level1: Dictionary = gm.current_level()
	var pending: Dictionary = tfm.get_pending_step(level1, "before_observation", gm.progress)
	_check(str(pending.get("id", "")) == "eye_imaging_intro", "L1 pending step is eye_imaging_intro")

	gm.selected_object_id = "moon"
	_check(gm.try_teaching_intercept("before_observation", "sky"), "L1 before_observation intercepts")
	_check(str(tfm.active_card_mode) == "brief", "active_card_mode is brief")
	_check(str(tfm.active_card_id) == "eye_imaging", "active_card_id is eye_imaging")
	_check(gm.selected_object_id == "moon", "intercept preserves selected_object_id")
	_check(_scene_is("learning_card"), "brief routed to learning card scene")

	gm.complete_current_brief()
	await process_frame
	_check(gm.progress.get("seen_teaching_steps", []).has("eye_imaging_intro"), "seen_teaching_steps records step id")
	_check(gm.progress.get("seen_concept_briefs", []).has("eye_imaging"), "seen_concept_briefs records card id")
	_check(not gm.progress.get("completed_concept_cards", []).has("eye_imaging"), "brief seen does NOT unlock journal card")
	_check(_scene_is("sky_observation"), "device-triggered brief continues straight to sky observation")
	_check(not gm.try_teaching_intercept("before_observation", "sky"), "L1 brief does not repeat")

	# --- 3. completing L1 unlocks the concept card ---------------------------
	gm.selected_object_id = "moon"
	var naked_moon: Dictionary = gm.evaluate_selected_object()
	_check(gm.complete_current_mission("moon", naked_moon), "L1 mission completes")
	_check(gm.progress.get("completed_concept_cards", []).has("eye_imaging"), "mission completion unlocks concept card")
	var entry: Dictionary = gm.progress.get("journal_entries", [])[0]
	_check(str(entry.get("concept_card_id", "")) == "eye_imaging", "journal entry records concept card")
	# go("card") instantiates the scene synchronously, and the card scene
	# acknowledges "complete" mode as soon as it renders - so by the time we
	# check, the mode has been consumed and the payload is on screen.
	_check(_scene_is("learning_card"), "mission complete routed to learning card")
	_check(not gm.last_learning_card.is_empty(), "mission complete payload set")
	_check(str(tfm.active_card_mode) == "", "complete mode consumed after the card is shown")

	# --- finish L2 quickly (auto fallback step exists but is optional) -------
	gm.selected_object_id = "polaris"
	gm.complete_current_mission("polaris", gm.evaluate_selected_object())
	await process_frame

	# --- 4. Level 3 brief before assembly ------------------------------------
	gm.debug_jump_to_level(3, false)
	_check(int(gm.progress.get("current_level", 0)) == 3, "at level 3")
	_check(gm.try_teaching_intercept("before_assembly", "assembly"), "L3 before_assembly intercepts")
	_check(str(tfm.active_card_id) == "refractor_light_path", "L3 brief is refractor_light_path")
	gm.complete_current_brief()
	await process_frame
	_check(_scene_is("telescope_assembly"), "device-triggered L3 brief continues straight to assembly")
	_check(not gm.try_teaching_intercept("before_assembly", "assembly"), "L3 brief does not repeat")

	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "moon"
	gm.complete_current_mission("moon", gm.evaluate_selected_object())
	await process_frame

	# --- 5. Level 4 brief before focus ----------------------------------------
	gm.debug_jump_to_level(4, false)
	_check(int(gm.progress.get("current_level", 0)) == 4, "at level 4")
	gm.selected_object_id = "betelgeuse"
	_check(gm.try_teaching_intercept("before_focus", "telescope"), "L4 before_focus intercepts")
	_check(str(tfm.active_card_id) == "focus_focal_plane", "L4 brief is focus_focal_plane")
	_check(gm.selected_object_id == "betelgeuse", "L4 intercept preserves betelgeuse selection")
	gm.complete_current_brief()
	await process_frame
	_check(_scene_is("telescope_view"), "L4 focus brief continues straight to telescope view")
	_check(gm.selected_object_id == "betelgeuse", "selection survives the whole brief round trip")
	_check(not gm.try_teaching_intercept("before_focus", "telescope"), "L4 brief does not repeat")

	# --- 6. multi-step level: triggers are independent ------------------------
	var multi_level: Dictionary = {
		"teaching_steps": [
			{"id": "step_a", "card_id": "newtonian_light_path", "trigger": "before_assembly", "mode": "brief", "required_once": true},
			{"id": "step_b", "card_id": "collimation_alignment", "trigger": "before_collimation", "mode": "brief", "required_once": true}
		]
	}
	var fake_progress: Dictionary = {"seen_teaching_steps": []}
	var step_a: Dictionary = tfm.get_pending_step(multi_level, "before_assembly", fake_progress)
	var step_b: Dictionary = tfm.get_pending_step(multi_level, "before_collimation", fake_progress)
	_check(str(step_a.get("id", "")) == "step_a", "multi-step: before_assembly finds step_a")
	_check(str(step_b.get("id", "")) == "step_b", "multi-step: before_collimation finds step_b")
	fake_progress["seen_teaching_steps"].append("step_a")
	_check(tfm.get_pending_step(multi_level, "before_assembly", fake_progress).is_empty(), "multi-step: step_a consumed")
	_check(not tfm.get_pending_step(multi_level, "before_collimation", fake_progress).is_empty(), "multi-step: step_b still pending")

	# --- fallback auto-step for legacy levels ---------------------------------
	var legacy_level: Dictionary = {"required_concept_card": "aperture_light_gathering", "requires_focus": true}
	var auto_step: Dictionary = tfm.get_pending_step(legacy_level, "before_focus", {"seen_teaching_steps": []})
	_check(str(auto_step.get("id", "")) == "auto_aperture_light_gathering", "legacy level auto-generates fallback step")
	var completed_progress: Dictionary = {
		"seen_teaching_steps": [],
		"seen_concept_briefs": [],
		"completed_concept_cards": ["aperture_light_gathering"]
	}
	_check(tfm.get_pending_step(legacy_level, "before_focus", completed_progress).is_empty(), "completed concept card does not repeat as a brief")

	if failures == 0:
		print("TEACHING FLOW TEST PASS")
		quit(0)
	else:
		print("TEACHING FLOW TEST FAIL (%d failures)" % failures)
		quit(1)


func _scene_is(name_part: String) -> bool:
	var scene: Node = current_scene
	if scene == null:
		return false
	return str(scene.scene_file_path).contains(name_part)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
