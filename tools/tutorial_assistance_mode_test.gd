extends SceneTree

# Tutorial assistance policy regression test.
# Run:
# godot --headless --path . --script res://tools/tutorial_assistance_mode_test.gd

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	var tfm := root.get_node_or_null("/root/TeachingFlowManager")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	var save_manager := root.get_node_or_null("/root/SaveManager")
	if gm == null or tfm == null or feedback == null or save_manager == null:
		print("FAIL: required autoloads missing")
		quit(1)
		return

	var original_progress: Dictionary = gm.progress.duplicate(true)
	gm.new_game()
	_check(gm.tutorial_assistance_mode() == "full", "new save defaults to Full Guidance")
	_check(gm.uses_full_tutorials(), "full mode enables blocking tutorials")
	_check(gm.allows_tutorial_hints(), "full mode enables hints")
	_check(not tfm.get_pending_step(gm.current_level(), "before_observation", gm.progress).is_empty(), "L1 lesson is pending")

	gm.set_tutorial_assistance_mode("light")
	var seen_before: Array = gm.progress.get("seen_teaching_steps", []).duplicate()
	_check(not gm.try_teaching_intercept("before_observation", "sky"), "light mode skips blocking teaching card")
	_check(not gm.try_story_for_trigger("before_observation", "sky"), "light mode skips forced Maya prelude")
	_check(gm.progress.get("seen_teaching_steps", []) == seen_before, "skipped lesson is not marked seen")
	_check(gm.allows_tutorial_hints(), "light mode keeps compact hints")
	_check(feedback.guidance_highlights_enabled(), "light mode can keep guidance highlights")

	gm.progress["space_intro_seen"] = false
	var space_source := FileAccess.get_file_as_string("res://scripts/ui/space_observation.gd")
	_check(
		space_source.contains("GameManager.uses_full_tutorials()") and space_source.contains("out.append(\"intro\")"),
		"Space first-use briefing is connected to the central policy"
	)
	var sky_source := FileAccess.get_file_as_string("res://scripts/ui/sky_observation.gd")
	_check(
		sky_source.contains("func _update_workflow_discipline_timer") and sky_source.contains("if not GameManager.uses_full_tutorials():"),
		"stuck-player Maya overlay is connected to the central policy"
	)

	gm.set_tutorial_assistance_mode("free")
	_check(not gm.uses_full_tutorials(), "free mode disables blocking tutorials")
	_check(not gm.allows_tutorial_hints(), "free mode disables unsolicited hints")
	_check(not feedback.guidance_highlights_enabled(), "free mode suppresses highlight masks")
	_check(not gm.try_teaching_intercept("before_observation", "sky"), "free mode does not intercept navigation")

	# Tutorial assistance is not a cheat: the same missing-equipment gate must
	# remain closed after switching modes.
	gm.debug_jump_to_level(3, false)
	gm.reset_assembly()
	var free_gate: Dictionary = gm.can_enter_observation()
	_check(not bool(free_gate.get("ok", true)), "free mode keeps assembly requirements")
	var level_before := int(gm.progress.get("current_level", 0))
	var credits_before := int(gm.progress.get("credits", 0))
	gm.set_tutorial_assistance_mode("light")
	_check(int(gm.progress.get("current_level", 0)) == level_before, "changing mode does not advance level")
	_check(int(gm.progress.get("credits", 0)) == credits_before, "changing mode grants no credits")

	# Returning to Full Guidance must expose lessons skipped earlier because
	# light/free mode deliberately did not consume them.
	gm.debug_jump_to_level(1, false)
	gm.set_tutorial_assistance_mode("full")
	_check(gm.try_teaching_intercept("before_observation", "sky"), "restored full mode can trigger unseen lesson")
	tfm.reset_flow()

	# Pause menu provides an in-game, 1024x768-safe control and help entry.
	var pause: Node = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	root.add_child(pause)
	await process_frame
	var panel := pause.get_node("Panel") as Control
	_check(panel.get_rect().size.x <= 360.0 and panel.get_rect().size.y <= 388.0, "pause settings fit 1024x768")
	_check(panel.get_node_or_null("TutorialMode") is OptionButton, "pause menu exposes tutorial mode selector")
	var help_found := false
	for child in panel.get_children():
		if child is Button and (child as Button).text.contains("Mission"):
			help_found = true
	_check(help_found, "pause menu keeps an expandable Mission / Help entry")
	pause.queue_free()

	# This test exercises new-game and level-jump paths, so restore the player's
	# exact pre-test progress before the process exits.
	gm.progress = original_progress.duplicate(true)
	save_manager.save_progress(original_progress)
	if failures == 0:
		print("TUTORIAL ASSISTANCE MODE TEST PASS")
		quit(0)
	else:
		print("TUTORIAL ASSISTANCE MODE TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
