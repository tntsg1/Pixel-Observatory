extends SceneTree

const AssemblyDependencyGraph = preload("res://scripts/systems/assembly_dependency_graph.gd")
const TEST_TIMEOUT_SECONDS := 30.0

var failures := 0
var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_start_watchdog()
	_backup_save()
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return

	gm.new_game()
	var training_bench: Node = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(training_bench)
	await process_frame
	_check(training_bench.find_child("AutoAssembleButton", true, false) == null, "auto assembly is hidden before graduation")
	training_bench.queue_free()
	await process_frame

	_prepare_graduate(gm)
	_test_dependency_graphs()

	gm.select_assembly_family("refractor")
	gm.reset_assembly()
	_check(gm.install_part("tripod", 0, "basic_tripod") >= 0, "partial refractor state starts with the existing tripod")
	var refractor_bench: Node = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(refractor_bench)
	await process_frame
	_check(refractor_bench.find_child("AutoAssembleButton", true, false) != null, "graduation exposes Auto Assemble on the refractor bench")
	refractor_bench.call("_on_auto_assemble_pressed")
	await create_timer(4.5).timeout
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		_check(bool(gm.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false)), "refractor auto assembly installs %s" % part_type)
	_check(not bool(refractor_bench.get("auto_assemble_running")), "refractor auto assembly releases its input lock")
	refractor_bench.queue_free()
	await process_frame

	gm.select_assembly_family("dobsonian")
	gm.reset_assembly()
	var tube_bench: Node = load("res://scenes/optical_tube_assembly.tscn").instantiate()
	root.add_child(tube_bench)
	await process_frame
	_check(tube_bench.find_child("AutoAssembleButton", true, false) != null, "graduation exposes Auto Assemble inside the optical tube bench")
	tube_bench.call("_on_auto_assemble_pressed")
	await create_timer(0.18).timeout
	tube_bench.call("_on_auto_assemble_pressed")
	await create_timer(0.9).timeout
	var tube_config: Dictionary = gm.tube_subassembly_config()
	var tube_state: Dictionary = gm.tube_assembly().get("installed_subparts", {})
	for subpart_value in tube_config.get("order", []):
		var subpart := str(subpart_value)
		_check(bool(tube_state.get(subpart, false)), "skip animation safely completes Dobsonian tube part %s" % subpart)
	_check(not bool(tube_bench.get("auto_assemble_running")), "tube auto assembly releases its input lock after skip")
	tube_bench.queue_free()
	await process_frame

	for family in ["newtonian", "dobsonian", "cassegrain", "gregorian", "space_segmented"]:
		await _test_advanced_family_auto(gm, family)

	gm.select_assembly_family("fast_radio")
	gm.reset_assembly()
	var fast_bench: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(fast_bench)
	await process_frame
	_check(fast_bench.find_child("AutoAssembleButton", true, false) != null, "graduation exposes Auto Assemble on the FAST bench")
	fast_bench.call("_on_auto_assemble_pressed")
	await create_timer(2.5).timeout
	for part_type in ["radio_dish", "receiver", "signal_processor"]:
		_check(bool(gm.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false)), "FAST auto assembly installs %s" % part_type)
	_check(not bool(fast_bench.get("auto_assemble_running")), "FAST auto assembly releases its input lock")
	fast_bench.queue_free()
	await process_frame

	print("POSTGRADUATE AUTO ASSEMBLE TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	_finish(0 if failures == 0 else 1)


func _test_advanced_family_auto(gm: Node, family: String) -> void:
	gm.select_assembly_family(family)
	gm.reset_assembly()
	var tube_config: Dictionary = gm.tube_subassembly_config()
	if not tube_config.is_empty():
		var completed_tube: Dictionary = {}
		for subpart_value in tube_config.get("order", []):
			completed_tube[str(subpart_value)] = true
		_check(
			gm.save_tube_assembly(completed_tube, 100.0, 100.0, false),
			"%s completed tube can seed the main-bench dependency test" % family
		)
	var bench: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	_check(bench.find_child("AutoAssembleButton", true, false) != null, "%s exposes Auto Assemble after graduation" % family)
	bench.call("_on_auto_assemble_pressed")
	await create_timer(0.12).timeout
	bench.call("_on_auto_assemble_pressed")
	await _wait_for_auto_complete(bench, 3.0)
	for part_type_value in gm.call("_effective_required_parts"):
		var part_type := str(part_type_value)
		_check(
			bool(gm.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false)),
			"%s auto assembly installs %s" % [family, part_type]
		)
	_check(not bool(bench.get("auto_assemble_running")), "%s auto assembly releases its input lock" % family)
	bench.queue_free()
	await process_frame


func _wait_for_auto_complete(bench: Node, max_seconds: float) -> void:
	var elapsed := 0.0
	while is_instance_valid(bench) and bool(bench.get("auto_assemble_running")) and elapsed < max_seconds:
		await create_timer(0.05).timeout
		elapsed += 0.05


func _prepare_graduate(gm: Node) -> void:
	gm.new_game()
	var mission_manager: Node = root.get_node_or_null("/root/MissionManager")
	gm.progress["current_level"] = 85
	gm.progress["completed_levels"] = (mission_manager.get("campaign_order") as Array).duplicate() if mission_manager != null else [85]
	gm.progress["program_completed"] = true
	gm.progress["graduation_seen"] = true
	gm.progress["graduation_pending"] = false
	var all_parts: Array = []
	for part_value in gm.parts_data:
		if part_value is Dictionary:
			var part_id := str((part_value as Dictionary).get("id", ""))
			if part_id != "":
				all_parts.append(part_id)
	gm._normalize_progress()
	gm.progress["current_level"] = 85
	gm.progress["unlocked_parts"] = all_parts


func _test_dependency_graphs() -> void:
	var refractor := AssemblyDependencyGraph.topological_order(
		"refractor",
		"main",
		["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]
	)
	_check(bool(refractor.get("ok", false)), "refractor dependency graph is acyclic")
	_check((refractor.get("order", []) as Array).find("tripod") < (refractor.get("order", []) as Array).find("mount"), "tripod precedes mount")
	_check((refractor.get("order", []) as Array).find("mount") < (refractor.get("order", []) as Array).find("tube"), "mount precedes refractor tube")

	var newtonian_tube := AssemblyDependencyGraph.topological_order(
		"newtonian",
		"tube",
		["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"]
	)
	_check(bool(newtonian_tube.get("ok", false)), "Newtonian tube dependency graph is acyclic")
	var tube_order: Array = newtonian_tube.get("order", [])
	_check(tube_order.find("mirror_cell") < tube_order.find("primary_mirror"), "mirror cell precedes primary mirror")
	_check(tube_order.find("secondary_spider") < tube_order.find("secondary_mirror"), "spider precedes secondary mirror")

	for family in ["dobsonian", "cassegrain", "gregorian", "space_segmented", "fast_radio"]:
		var scope := "tube" if family in ["dobsonian", "cassegrain", "gregorian"] else "main"
		var graph := AssemblyDependencyGraph.dependencies_for(family, scope)
		var parts: Array = graph.keys()
		var result := AssemblyDependencyGraph.topological_order(family, scope, parts)
		_check(bool(result.get("ok", false)), "%s %s dependency graph is acyclic" % [family, scope])

	var cycle_result := AssemblyDependencyGraph.topological_order_from_graph(
		{"a": ["b"], "b": ["a"]},
		["a", "b"]
	)
	_check(not bool(cycle_result.get("ok", true)), "cycle detection rejects an invalid dependency graph")


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not finished:
			push_error("POSTGRADUATE AUTO ASSEMBLE TEST TIMEOUT")
			_finish(1)
	)


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	_restore_save()
	quit(exit_code)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
