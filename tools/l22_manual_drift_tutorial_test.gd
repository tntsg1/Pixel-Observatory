extends SceneTree

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	var watchdog := create_timer(45.0)
	watchdog.timeout.connect(func() -> void:
		push_error("L22 MANUAL DRIFT TUTORIAL TEST TIMEOUT")
		_finish(124)
	)
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish(1)
		return

	await _test_full_tutorial_requires_real_correction()
	await _test_free_mode_is_non_blocking()
	_finish(0 if failures == 0 else 1)


func _test_full_tutorial_requires_real_correction() -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.set_tutorial_assistance_mode("full")
	gm.debug_jump_to_level(22, true)
	gm.selected_object_id = "sirius"
	var level: Dictionary = gm.current_level()
	_check(bool(level.get("teach_manual_drift_correction", false)), "L22 explicitly owns the first manual-drift lesson")

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame

	_check(bool(view.get("manual_drift_tutorial_active")), "full guidance starts the manual drift lesson")
	var instruction := view.get("drift_instruction_label") as Label
	_check(instruction != null, "manual mount exposes a readable drift instruction row")
	if instruction != null:
		_check(instruction.text.contains("watch Sirius drift"), "lesson first asks the player to observe the physical drift")

	view.set("drift_direction", Vector2.RIGHT)
	view.set("drift_offset", Vector2.ZERO)
	view.call("_advance_drift", 1.0)
	_check(bool(view.get("manual_drift_tutorial_observed")), "natural Earth drift must become visible before correction is credited")
	if instruction != null:
		_check(instruction.text.contains("tap D"), "rightward drift names D as the live correction")

	Input.action_press("move_left")
	view.call("_advance_drift", 0.08)
	Input.action_release("move_left")
	_check(bool(view.get("manual_drift_tutorial_active")), "wrong-direction input does not complete the lesson")

	view.set("drift_direction", Vector2.ZERO)
	Input.action_press("move_right")
	view.call("_advance_drift", 0.12)
	Input.action_release("move_right")
	_check(bool(view.get("manual_drift_tutorial_corrected")), "a real D correction toward center completes the lesson")
	_check(not bool(view.get("manual_drift_tutorial_active")), "completed lesson stops prompting")
	_check(
		(gm.progress.get("seen_teaching_steps", []) as Array).has("manual_earth_drift_correction_v2"),
		"successful correction is persisted in the teaching archive"
	)
	if instruction != null:
		_check(instruction.text.contains("learned"), "the instruction row confirms the acquired skill")

	view.queue_free()
	await process_frame


func _test_free_mode_is_non_blocking() -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.set_tutorial_assistance_mode("free")
	gm.debug_jump_to_level(22, true)
	gm.selected_object_id = "sirius"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame

	_check(not bool(view.get("manual_drift_tutorial_active")), "free exploration does not start a blocking drift lesson")
	var instruction := view.get("drift_instruction_label") as Label
	_check(instruction != null and instruction.text.contains("A/D"), "free mode keeps only the compact A/D control reference")
	var overlay := view.find_child("TutorialHighlight_manual_earth_drift_correction_v2", true, false)
	_check(overlay == null, "free exploration creates no tutorial overlay")

	view.queue_free()
	await process_frame

func _finish(code: int) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("L22 MANUAL DRIFT TUTORIAL TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(code)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
