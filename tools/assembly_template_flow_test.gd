extends SceneTree

var failures := 0
var finished := false
const TEST_TIMEOUT_SECONDS := 20.0


func _initialize() -> void:
	_start_watchdog()
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(26, false)

	var main: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.call("_select_newtonian_main_part", "mount")
	main.call("_install_main_part", "mount")
	if not _installed(gm, "mount"):
		print("  diagnostic: mount blocked: ", gm.install_part_block_reason("mount"))
		print("  diagnostic: family=", gm.assembly_family(), " equipped=", gm.equipped_part_id("mount"), " unlocked=", gm.progress.get("unlocked_parts", []))
	_check(_installed(gm, "mount"), "advanced main assembly accepts the mount before the tripod")
	main.call("_select_newtonian_main_part", "tripod")
	main.call("_install_main_part", "tripod")
	_check(_installed(gm, "tripod") and _installed(gm, "mount"), "main support components install in either order")

	main.queue_free()
	await process_frame
	var tube: Node = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(tube)
	current_scene = tube
	await process_frame
	var tube_order: Array = gm.tube_subassembly_config().get("order", []).duplicate()
	tube_order.reverse()
	for subpart_value in tube_order:
		var subpart := str(subpart_value)
		tube.call("_select_newtonian_tube_part", subpart)
		tube.call("_install_subpart", subpart)
	_check(str(tube.call("_next_required_subpart")) == "", "all tube parts install in reverse order")
	tube.call("_save_assembly")
	await process_frame
	await process_frame
	_check(gm.advanced_tube_completed(), "Save Tube Assembly completes the nested component")
	_check(_installed(gm, "optical_tube_assembly"), "saved Newtonian tube is marked installed on the main bench")
	_check(_installed(gm, "tripod") and _installed(gm, "mount"), "return from tube assembly preserves external components")
	_check(current_scene != null and current_scene.scene_file_path.ends_with("advanced_assembly.tscn"), "tube save returns to Newtonian main assembly")

	if failures == 0:
		print("ASSEMBLY TEMPLATE FLOW TEST PASS")
		_finish(0)
	else:
		print("ASSEMBLY TEMPLATE FLOW TEST FAIL")
		_finish(1)


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if finished:
			return
		push_error("ASSEMBLY TEMPLATE FLOW TEST TIMEOUT after %.1f seconds" % TEST_TIMEOUT_SECONDS)
		_finish(1)
	)


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	quit(exit_code)


func _installed(gm: Node, part_type: String) -> bool:
	var state: Dictionary = gm.progress.get("assembly_state", {})
	var entry: Dictionary = state.get(part_type, {})
	return bool(entry.get("installed", false))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
