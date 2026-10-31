extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)
	var config: Dictionary = gm.tube_subassembly_config()
	_check(str(config.get("family", "")) == "newtonian", "L26 selects Newtonian tube sub-blueprint")
	var partial := {"reflector_tube": true}
	gm.update_tube_subassembly_progress(partial)
	_check(not gm.advanced_tube_completed(), "partial tube assembly is not complete")
	_check(bool(gm.tube_assembly().get("installed_subparts", {}).get("reflector_tube", false)), "partial subpart survives return state")
	var complete := {}
	for subpart_value in config.get("order", []):
		complete[str(subpart_value)] = true
	_check(gm.save_tube_assembly(complete, 92.0, 94.0, true), "completed Newtonian tube saves")
	_check(gm.advanced_tube_completed(), "completed tube state is recognized")
	_check(not gm.telescope_is_ready(), "completed tube still needs main-assembly installation")
	gm.reset_assembly()
	gm.install_part("tripod", 0)
	gm.install_part("mount", 0)
	gm.install_part("optical_tube_assembly", 0)
	_check(not gm.telescope_is_ready(), "main assembly still needs the finder scope")
	gm.install_part("finder_scope", 0)
	_check(gm.telescope_is_ready(), "main assembly becomes ready only after tube component installation")
	_check(float(gm.calculate_stats().get("subassembly_score", 0.0)) == 92.0, "subassembly score reaches telescope stats")
	gm.set_collimation_score(87.0)
	_check(float(gm.tube_assembly().get("collimation_score", 0.0)) == 87.0, "collimation score syncs back into tube assembly")
	for level_number in [36, 46, 56]:
		gm.debug_jump_to_level(level_number, false)
		var family_config: Dictionary = gm.tube_subassembly_config()
		_check(not family_config.is_empty(), "L%d has a tube sub-blueprint config" % level_number)
		_check((family_config.get("order", []) as Array).size() >= 6, "L%d sub-blueprint has ordered optical parts" % level_number)
	gm.debug_jump_to_level(56, true)
	var greg_mount: Dictionary = gm.get_part("gregorian_equatorial_mount")
	var greg_eye: Dictionary = gm.get_part("gregorian_18mm_eyepiece")
	_check(ResourceLoader.exists(str(greg_mount.get("icon_path", ""))), "Gregorian mount PNG is registered")
	_check(ResourceLoader.exists(str(greg_eye.get("icon_path", ""))), "Gregorian eyepiece PNG is registered")
	_check(gm.equip_part("gregorian_equatorial_mount"), "Gregorian mount equips in Gregorian lesson")
	gm.debug_jump_to_level(46, false)
	gm.progress["unlocked_parts"].append("gregorian_equatorial_mount")
	gm.progress["unlocked_parts"].append("gregorian_18mm_eyepiece")
	_check(not gm.equip_part("gregorian_equatorial_mount"), "Gregorian mount is rejected by Cassegrain")
	_check(not gm.equip_part("gregorian_18mm_eyepiece"), "Gregorian eyepiece is rejected by Cassegrain")
	if failures == 0:
		print("NESTED TUBE ASSEMBLY TEST PASS")
		quit(0)
	else:
		print("NESTED TUBE ASSEMBLY TEST FAIL")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
