extends SceneTree

# Debug quick-assembly acceptance: "Prepare Equipment" must yield a FULLY
# ready rig for every family - main assembly, tube subassembly, collimation,
# and an open observation gate - and never leave ghost-uninstalled slots.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	gm.new_game()
	var cases := [
		[4, ""],
		[27, "newtonian"],
		[37, "dobsonian"],
		[47, "cassegrain"],
		[67, "space_segmented"],
		[77, "fast_radio"]
	]
	for case_value in cases:
		var level_number: int = int(case_value[0])
		var family := str(case_value[1])
		gm.debug_jump_to_level(level_number, true)
		_check(str(gm.current_level().get("telescope_family", "")) == family, "L%d family is %s" % [level_number, family if family != "" else "basic"])
		var state: Dictionary = gm.progress.get("assembly_state", {})
		for type_value in gm._effective_required_parts():
			_check(bool((state.get(str(type_value), {}) as Dictionary).get("installed", false)),
				"L%d slot '%s' installed after prepare" % [level_number, str(type_value)])
		if bool(gm._uses_tube_subassembly()):
			var tube: Dictionary = gm.tube_assembly()
			_check(bool(tube.get("completed", false)), "L%d tube subassembly completed" % level_number)
			var subparts: Dictionary = tube.get("installed_subparts", {})
			for subpart_value in gm.tube_subassembly_config().get("order", []):
				_check(bool(subparts.get(str(subpart_value), false)), "L%d tube part '%s' installed" % [level_number, str(subpart_value)])
		if bool(gm.current_level().get("requires_collimation", false)):
			_check(gm.collimation_is_acceptable(), "L%d collimation prepared" % level_number)
		_check(gm.telescope_is_ready(), "L%d telescope READY" % level_number)
		var gate: Dictionary = gm.can_enter_observation()
		_check(bool(gate.get("ok", false)), "L%d observation gate open" % level_number)
	if failures == 0:
		print("DEBUG PREPARE TEST PASS")
		quit(0)
	else:
		print("DEBUG PREPARE TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
