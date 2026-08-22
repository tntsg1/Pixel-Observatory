extends SceneTree

# Headless end-to-end flow test: simulates completing all levels.
# Run: godot --headless --script res://tools/flow_test.gd

func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return
	gm.new_game()
	# This regression protects the original L1-L24 campaign. Advanced content
	# has its own focused tests and must not redefine this legacy contract.
	var max_level: int = min(24, root.get_node("/root/MissionManager").get_max_level())
	print("Legacy levels tested: ", max_level)
	var failures := 0
	for i in range(max_level):
		var level: Dictionary = gm.current_level()
		var level_number: int = int(level.get("level_number", -1))
		var target_id: String = gm.current_target_object_id()
		if target_id == "":
			print("FAIL L", level_number, ": no target")
			failures += 1
			break
		# Campaign order weaves expansion lessons (constellation nights and
		# technique-driven telescope targets) between legacy lessons. Their
		# mechanics have dedicated tests (observation_expansion_test); here
		# they complete synthetically so the ORDER itself stays under test.
		if level_number > 91:
			for step_value in gm.mission_steps():
				gm.mark_mission_step_done(str((step_value as Dictionary).get("id", "")))
			var expansion_observation := {
				"success": true, "quality": "Good", "visual_effect": "clear",
				"observation_mode": str(level.get("observation_mode", "telescope")),
				"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}
			}
			if not gm.complete_current_mission(target_id, expansion_observation):
				print("FAIL L", level_number, ": expansion mission not completed")
				failures += 1
				break
			print("L", level_number, " expansion ", target_id, " completed=true")
			continue
		var needs_telescope: bool = bool(level.get("requires_telescope", true))
		if needs_telescope:
			# Auto-equip best unlocked part per type (upgrade path)
			for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope"]:
				var options: Array = gm.unlocked_parts_by_type(part_type)
				if not options.is_empty():
					gm.equip_part(str(options[options.size() - 1].get("id", "")))
			# Perfect assembly of required parts
			gm.reset_assembly()
			for part_type in level.get("required_parts", []):
				gm.install_part(str(part_type), 0)
			if not gm.telescope_is_ready():
				print("FAIL L", level_number, ": telescope not ready, missing=", gm.missing_parts())
				failures += 1
				break
		# L15's finder calibration gate is a Sky Observation concern (blocks
		# entering telescope mode), not something evaluate/complete touch -
		# but the real flow requires it done, so simulate it here.
		if str(level.get("variation", "")) == "finder_calibration":
			gm.progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
		# L10-style checklist: simulate the player walking through every
		# step (equipping the required part first) before the final identify.
		for step_value in gm.mission_steps():
			var step: Dictionary = step_value
			var require_part_id := str(step.get("require_part_id", ""))
			if require_part_id != "":
				gm.equip_part(require_part_id)
				gm.reset_assembly()
				for part_type in level.get("required_parts", []):
					gm.install_part(str(part_type), 0)
			gm.selected_object_id = target_id
			gm.evaluate_selected_object()
			gm.mark_mission_step_done(str(step.get("id", "")))
		var stats: Dictionary = gm.calculate_stats()
		gm.selected_object_id = target_id
		var observation: Dictionary = gm.evaluate_selected_object()
		var ok: bool = gm.complete_current_mission(target_id, observation)
		print("L", level_number, " target=", target_id,
			" quality=", observation.get("quality"),
			" min=", level.get("minimum_success_quality", "Good"),
			" light=", stats.get("light_score"),
			" clarity=", stats.get("clarity_score"),
			" stability=", stats.get("stability_score"),
			" completed=", ok)
		if level_number == 7:
			if str(observation.get("quality", "")) != "Fair" or not ok:
				print("FAIL L7: first Orion Nebula should allow focused Fair quality")
				failures += 1
				break
		if level_number == 8:
			if not str(observation.get("quality", "")) in ["Good", "Excellent"] or not ok:
				print("FAIL L8: aperture lesson should require and reach Good+ quality")
				failures += 1
				break
		if not ok:
			print("FAIL L", level_number, ": mission not completed. feedback=", observation.get("feedback_en"))
			failures += 1
			break
	var completed: Array = gm.progress.get("completed_levels", [])
	var badges: Array = gm.progress.get("badges", [])
	var last_completed: int = int(completed[completed.size() - 1]) if not completed.is_empty() else max_level
	gm.progress["current_level"] = last_completed
	var final_level: Dictionary = gm.current_level()
	var final_target_id: String = gm.current_target_object_id()
	gm.selected_object_id = final_target_id
	var repeat_observation: Dictionary = gm.evaluate_selected_object()
	var journal_count_before: int = gm.progress.get("journal_entries", []).size()
	var repeated_ok: bool = gm.complete_current_mission(final_target_id, repeat_observation)
	await process_frame
	if not repeated_ok:
		print("FAIL repeat final: completed mission should be acknowledged")
		failures += 1
	var expected_next_route := str(gm.current_room_route().get("target", ""))
	if str(gm.room_guidance_target) != expected_next_route:
		print("FAIL repeat final: expected next unfinished lesson route ", expected_next_route, ", got ", gm.room_guidance_target)
		failures += 1
	if gm.progress.get("journal_entries", []).size() != journal_count_before:
		print("FAIL repeat final: duplicate journal entry added")
		failures += 1
	if current_scene == null or not str(current_scene.scene_file_path).contains("observatory_room"):
		print("FAIL repeat final: expected observatory room after already-completed observation")
		failures += 1
	print("Completed levels: ", completed)
	print("Badges: ", badges)
	print("Credits: ", gm.progress.get("credits"))
	print("Journal entries: ", gm.progress.get("journal_entries", []).size())
	if failures == 0 and completed.size() == max_level:
		print("FLOW TEST PASS")
		quit(0)
	else:
		print("FLOW TEST FAIL")
		quit(1)
