extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var game_manager: Node = root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		quit(1)
		return

	game_manager.new_game()
	game_manager.debug_jump_to_level(26, false)
	var config: Dictionary = game_manager.tube_subassembly_config()
	var complete := {}
	for part_type_value in config.get("order", []):
		complete[str(part_type_value)] = true
	_check(game_manager.save_tube_assembly(complete, 92.0, 94.0, false), "Newtonian tube subassembly saves")

	game_manager.reset_assembly()
	for part_type in ["tripod", "mount", "optical_tube_assembly", "finder_scope"]:
		var score: int = game_manager.install_part(part_type, 0)
		_check(score >= 0, "%s implicitly resolves to an unlocked Newtonian-compatible part" % part_type)
		var installed: Dictionary = game_manager.progress.get("assembly_state", {}).get(part_type, {})
		var installed_id := str(installed.get("installed_part_id", ""))
		if part_type != "optical_tube_assembly":
			var installed_part: Dictionary = game_manager.get_part(installed_id)
			var family := str(installed_part.get("telescope_family", ""))
			_check(family == "" or family == "newtonian", "%s does not auto-select another telescope family" % part_type)

	_check(game_manager.telescope_is_ready(), "implicit Newtonian assembly reaches ready state")
	if failures == 0:
		print("ASSEMBLY FAMILY AUTORESOLVE TEST PASS")
		quit(0)
	else:
		print("ASSEMBLY FAMILY AUTORESOLVE TEST FAIL")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
