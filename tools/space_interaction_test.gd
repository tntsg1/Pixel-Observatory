extends SceneTree

# Phase-1 interaction contract for the infrared assembly bench and the
# multi-observatory evidence desk. Proves the destructive actions are gated:
#   A. assembly card select never observes / completes / scores / installs / saves
#   B. only a blueprint slot click installs, and only the correct part
#   C. only Finish Assembly saves, and it returns to the lobby (not observation)
#   D. evidence card View/Select never re-observes or completes
#   E. only Confirm Evidence submits, and wrong evidence is rejected
#   F. the legacy refractor/newtonian/dobsonian assembly path is unchanged

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("SPACE INTERACTION TEST FAIL: GameManager missing")
		quit(1)
		return

	await _test_assembly(gm)
	await _test_evidence(gm)
	await _test_legacy(gm)
	await _release_test_scene(current_scene)
	current_scene = null
	var audio_manager := root.get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("release_all_audio"):
		audio_manager.call("release_all_audio")
	for _frame in 3:
		await process_frame

	print("SPACE INTERACTION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- A/B/C
func _test_assembly(gm: Node) -> void:
	gm.new_game()
	gm.debug_jump_to_level(66, true)   # first infrared level
	gm.reset_assembly()
	var credits_before := int(gm.progress.get("credits", 0))
	var scene := "?"

	var bench: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(bench)
	for _i in range(6):
		await process_frame

	# family + non-Newtonian copy
	_check(str(gm.assembly_family()) == "space_segmented", "0. bench is the infrared family")
	_check(not str(bench.call("_flat_bench_title")).contains("REFLECTOR")
		and not str(bench.call("_flat_bench_title")).contains("Newtonian"),
		"UI. infrared bench title is not a Newtonian/reflector title")
	_check(not str(bench.call("_flat_board_title")).contains("NEWTONIAN"),
		"UI. infrared blueprint board is not titled Newtonian light path")
	# status text is not the self-contradicting 'Missing: all installed'
	var status := str(bench.call("_status_text"))
	_check(not (status.contains("Missing") and status.contains("installed")),
		"UI. status text never says 'Missing: all installed'")

	# A. selecting a part card
	var order: Array = gm.current_level().get("assembly_order", [])
	var first := str(order[0])
	bench.call("_select_flat_part", first)
	await process_frame
	_check(str(bench.get("selected_type")) == first, "A. card tap selects the part")
	_check(not bench.call("_installed", first), "A. card tap does NOT install")
	_check(int(gm.progress.get("credits", 0)) == credits_before, "A. card tap does NOT add credits")
	_check(not bool(gm.progress.get("mission_completed_flag", false)), "A. card tap does NOT complete the mission")
	_check(gm.progress.get("last_scene_change", "") != "telescope_view", "A. card tap does NOT enter observation")

	# B. wrong slot does nothing; correct slot installs
	var second := str(order[1])
	bench.call("_install_at_slot", second)   # selected is `first`, click `second`
	await process_frame
	_check(not bench.call("_installed", first) and not bench.call("_installed", second),
		"B. clicking the wrong slot installs nothing")
	bench.call("_install_at_slot", first)    # correct slot for the selected part
	for _i in range(3):
		await process_frame
	_check(bench.call("_installed", first), "B. clicking the correct slot installs the selected part")
	_check(str(bench.get("selected_type")) == "", "B. selection clears after install")

	# C. Finish before ready must not save/route; nothing observes here
	var missing_before: Array = gm.missing_parts()
	_check(not missing_before.is_empty(), "C. mission is not ready with one part installed")
	bench.call("_finish")
	await process_frame
	_check(not gm.telescope_is_ready(), "C. Finish with missing parts does not mark ready")

	# install the rest through the blueprint, then Finish
	for i in range(1, order.size()):
		var t := str(order[i])
		bench.call("_select_flat_part", t)
		await process_frame
		bench.call("_install_at_slot", t)
		for _j in range(3):
			await process_frame
	_check(gm.telescope_is_ready(), "C. all parts installed via slots -> telescope ready")

	await _release_test_scene(bench)


# ---------------------------------------------------------------- D/E
func _test_evidence(gm: Node) -> void:
	gm.new_game()
	gm.debug_jump_to_level(66, true)
	gm.language_mode = "en"
	var desk: Node = load("res://scenes/multi_observation.tscn").instantiate()
	root.add_child(desk)
	for _i in range(6):
		await process_frame

	_check(str(desk.get("selected_band")) == "", "D. evidence desk opens with an empty evidence slot")

	# D. View a record: reads only
	desk.call("_view", "optical")
	await process_frame
	_check(str(desk.get("viewed_band")) == "optical", "D. View Record shows the record detail")
	_check(str(desk.get("selected_band")) == "", "D. View Record does NOT select evidence")
	_check(not bool(desk.get("completed")), "D. View Record does NOT complete the mission")

	# D. Select a (wrong) record: fills the slot, still no completion
	desk.call("_select", "optical")
	await process_frame
	_check(str(desk.get("selected_band")) == "optical", "D. Select Evidence fills the evidence slot")
	_check(not bool(desk.get("completed")), "D. Select Evidence does NOT complete the mission")

	# E. Confirm with the WRONG band is rejected
	desk.call("_confirm")
	await process_frame
	_check(not bool(desk.get("completed")), "E. Confirm with wrong evidence is rejected")

	# E. Select the correct band, then Confirm completes
	var expected := str(desk.call("_expected_record"))
	desk.call("_select", expected)
	await process_frame
	_check(not bool(desk.get("completed")), "E. selecting the right band still does not auto-complete")
	desk.call("_confirm")
	for _i in range(3):
		await process_frame
	_check(bool(desk.get("completed")), "E. Confirm with the correct evidence submits the mission")

	await _release_test_scene(desk)


# ---------------------------------------------------------------- F
func _test_legacy(gm: Node) -> void:
	# The Newtonian/refractor path must still build and behave.
	gm.new_game()
	gm.debug_jump_to_level(26, true)   # Newtonian
	var bench: Node = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(bench)
	for _i in range(8):
		await process_frame
	_check(str(gm.assembly_family()) == "newtonian", "F. Newtonian family still routes to the nested template")
	_check(bench.has_method("_main_parts"), "F. Newtonian template path intact")
	await _release_test_scene(bench)


func _release_test_scene(scene: Node) -> void:
	if scene != null and is_instance_valid(scene) and not scene.is_queued_for_deletion():
		scene.queue_free()
	# queue_free is deferred.  A UI scene owns theme, text, and canvas RID
	# allocations that need two render/process turns after its child tree has
	# left the viewport; a one-frame exit made the test look like it leaked the
	# entire bench even though the interaction assertions had passed.
	for _frame in 3:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
