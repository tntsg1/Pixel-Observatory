extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	var story_manager := root.get_node_or_null("/root/StoryManager")
	if story_manager == null:
		quit(1)
		return
	gm.new_game()
	var pre_newtonian_targets := {
		22: "sirius",
		23: "vega",
		24: "andromeda",
		25: "vega",
	}
	for level_number in pre_newtonian_targets:
		gm.debug_jump_to_level(level_number, true)
		var bridge_level: Dictionary = gm.current_level()
		_check(gm.current_target_object_id() == pre_newtonian_targets[level_number], "L%d keeps its intended comparison target" % level_number)
		_check(bool(bridge_level.get("chromatic_aberration", false)), "L%d shows refractor chromatic aberration" % level_number)

	gm.debug_jump_to_level(25, true)
	var level: Dictionary = gm.current_level()
	_check(str(level.get("telescope_family", "")) == "refractor", "L25 begins with the refractor")
	_check(gm.current_target_object_id() == "vega", "L25 observes Vega")
	_check(bool(level.get("chromatic_aberration", false)), "L25 enables visible chromatic aberration")
	for state in ["clear", "blurry", "dim"]:
		var vega_path := "res://assets/telescope_view/vega_user_%s.png" % state
		_check(ResourceLoader.exists(vega_path) and load(vega_path) is Texture2D, "official Vega %s texture loads" % state)
	_check(bool(level.get("requires_focus", false)), "L25 keeps focus interaction")

	gm.debug_jump_to_level(26, true)

	# Reproduce the pre-fix save: main mount installed, but the previous
	# reflector mount remains selected instead of the card's Basic Mount.
	gm.progress["selected_parts"]["mount"] = "reflector_mount"
	gm.progress["assembly_state"]["mount"] = {"installed": true, "alignment_score": 100, "wrong_attempts": 0}
	var requires_basic_mount := Array(gm.current_level().get("required_part_ids", [])).has("basic_mount")
	if requires_basic_mount:
		_check(gm.missing_required_parts().has("basic_mount"), "legacy save reproduces the Basic Mount gate")
		_check(gm.sync_newtonian_installed_equipment(), "legacy Newtonian equipment is migrated")
		_check(gm.equipped_part_id("mount") == "basic_mount", "installed main mount synchronizes to basic_mount")
	else:
		_check(not gm.missing_required_parts().has("basic_mount"), "current L26 data has no stale Basic Mount gate")
		_check(not gm.sync_newtonian_installed_equipment(), "migration is a no-op when the level has no support-part hard gate")
	_check(not gm.missing_required_parts().has("basic_mount"), "Basic Mount no longer locks Identify")

	level = gm.current_level()
	_check(gm.current_target_object_id() == "moon", "L26 gives the Newtonian a first-light target")
	_check(str(level.get("telescope_family", "")) == "newtonian", "L26 introduces the Newtonian family")
	_check(bool(level.get("requires_focus", false)), "L26 enables focus")
	var environment: Dictionary = level.get("environment", {})
	_check(environment.has("seeing"), "L26 defines seeing")
	_check(gm.focus_control_installed(), "Newtonian tube focuser enables focus input")
	gm.selected_object_id = gm.current_target_object_id()
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await process_frame
	await process_frame
	_check(view.call("_missing_required_parts").is_empty(), "Telescope View no longer reports Basic Mount missing")
	_check(bool(view.get("allow_focus_input")), "Telescope View exposes Newtonian focus control")
	_check(float(view.call("_focus_control_score")) > 0.0, "Newtonian focuser contributes a nonzero control score")
	view.queue_free()
	await process_frame

	var dialogue: Array = story_manager.get_dialogue("level_26_before_assembly")
	_check(dialogue.size() >= 3, "L26 explanation precedes Newtonian assembly")
	var dialogue_en := ""
	for line_value in dialogue:
		dialogue_en += " " + str(line_value.get("text_en", ""))
	_check(
		dialogue_en.contains("chromatic aberration") or dialogue_en.contains("colored fringes"),
		"dialogue explains refractor chromatic aberration"
	)
	_check(
		dialogue_en.contains("Newtonian") and dialogue_en.contains("mirror"),
		"dialogue introduces the Newtonian solution"
	)
	_check(
		dialogue_en.contains("primary mirror") and dialogue_en.contains("secondary"),
		"dialogue explains the Newtonian light path"
	)

	gm.debug_jump_to_level(27, true)
	level = gm.current_level()
	_check(gm.current_target_object_id() == "vega", "L27 repeats Vega with the Newtonian")
	_check(not bool(level.get("chromatic_aberration", false)), "L27 removes the refractor color fringe")
	_check(bool(level.get("requires_focus", false)), "L27 keeps focus interaction")

	for level_number in [32, 35]:
		gm.debug_jump_to_level(level_number, true)
		level = gm.current_level()
		_check(bool(level.get("requires_focus", false)), "L%d enables focus" % level_number)
		_check(bool(level.get("drift_enabled", false)), "L%d enables Earth-rotation drift" % level_number)
		_check(float(level.get("hold_seconds", 0.0)) > 0.0, "L%d requires center hold" % level_number)
		environment = level.get("environment", {})
		_check(environment.has("seeing") and environment.has("cloud_cover"), "L%d defines seeing and clouds" % level_number)

	print("NEWTONIAN OBSERVATION PARITY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
