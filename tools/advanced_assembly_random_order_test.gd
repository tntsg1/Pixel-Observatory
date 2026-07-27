extends SceneTree

const TEST_TIMEOUT_SECONDS := 30.0

var failures := 0
var finished := false


func _initialize() -> void:
	_start_watchdog()
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	gm.new_game()
	await _test_dobsonian(gm)
	await _test_flat_family(gm, 66, "space_segmented")
	await _test_flat_family(gm, 76, "fast_radio")
	await _test_foundation_order(gm)
	print("ADVANCED ASSEMBLY RANDOM ORDER TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	_finish(0 if failures == 0 else 1)


func _test_dobsonian(gm: Node) -> void:
	gm.debug_jump_to_level(36, false)
	gm.reset_assembly()
	var tube: Node = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(tube)
	current_scene = tube
	await process_frame
	var reverse_order: Array = gm.tube_subassembly_config().get("order", []).duplicate()
	reverse_order.reverse()
	for part_value in reverse_order:
		var part_type := str(part_value)
		tube.call("_select_newtonian_tube_part", part_type)
		tube.call("_install_subpart", part_type)
	_check(str(tube.call("_next_required_subpart")) == "", "Dobsonian tube accepts reverse subpart order")
	_check(not gm.missing_parts().is_empty(), "Dobsonian cannot finish before its tube is saved and mounted")
	tube.call("_save_assembly")
	await process_frame
	await process_frame
	_check(gm.advanced_tube_completed(), "Dobsonian tube saves after random-order installation")
	var bench: Node = current_scene
	_check(bench != null and bench.scene_file_path.ends_with("advanced_assembly.tscn"), "Dobsonian returns to main bench")
	bench.call("_select_newtonian_main_part", "finder_scope")
	bench.call("_install_main_part", "finder_scope")
	bench.call("_select_newtonian_main_part", "mount")
	bench.call("_install_main_part", "mount")
	_check(gm.missing_parts().is_empty(), "Dobsonian completes after all main components, regardless of order")
	bench.queue_free()
	await process_frame


func _test_flat_family(gm: Node, level_number: int, expected_family: String) -> void:
	gm.debug_jump_to_level(level_number, true)
	gm.reset_assembly()
	var bench: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(bench)
	current_scene = bench
	await process_frame
	_check(str(gm.assembly_family()) == expected_family, "L%d opens %s assembly" % [level_number, expected_family])
	var reverse_order: Array = (bench.get("order") as Array).duplicate()
	reverse_order.reverse()
	_check(reverse_order.size() > 1, "%s exposes multiple installable components" % expected_family)
	var deferred_part := str(reverse_order.pop_back())
	for part_value in reverse_order:
		var part_type := str(part_value)
		bench.call("_select_flat_part", part_type)
		bench.call("_install_at_slot", part_type)
	_check(not gm.missing_parts().is_empty(), "%s cannot finish with one required component missing" % expected_family)
	bench.call("_select_flat_part", deferred_part)
	bench.call("_install_at_slot", deferred_part)
	_check(gm.missing_parts().is_empty(), "%s completes in reverse install order" % expected_family)
	bench.queue_free()
	await process_frame


func _test_foundation_order(gm: Node) -> void:
	gm.debug_jump_to_level(1, false)
	gm.reset_assembly()
	var bench: Node = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(bench)
	current_scene = bench
	await process_frame
	bench.call("_select_part", "mount")
	bench.call("_try_install", "mount")
	var mount_state: Dictionary = gm.progress.get("assembly_state", {}).get("mount", {})
	_check(not bool(mount_state.get("installed", false)), "foundation refractor still blocks mount before tripod")
	bench.queue_free()
	await process_frame


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if finished:
			return
		push_error("ADVANCED ASSEMBLY RANDOM ORDER TEST TIMEOUT after %.1f seconds" % TEST_TIMEOUT_SECONDS)
		_finish(1)
	)


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	quit(exit_code)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
