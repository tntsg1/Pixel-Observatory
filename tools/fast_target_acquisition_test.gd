extends SceneTree

var failures := 0
var finished := false


func _initialize() -> void:
	var watchdog := create_timer(20.0)
	watchdog.timeout.connect(func() -> void:
		if finished:
			return
		push_error("FAST TARGET ACQUISITION TEST TIMEOUT")
		quit(2)
	)
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is available")
		_finish()
		return
	gm.new_game()
	gm.progress["completed_levels"] = [76]
	gm.progress["current_level"] = 85
	gm.set_tutorial_assistance_mode(gm.TUTORIAL_ASSIST_FREE)
	_check(gm.begin_remote_free_observation("radio", "pulsar_clock"), "free FAST target can set navigation coordinates")
	var completed_before: Array = (gm.progress.get("completed_levels", []) as Array).duplicate()

	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(5):
		await process_frame
	if scene.get("intro_running") == true:
		scene.call("_finish_array_takeover")
		await process_frame

	_check(scene.get("acquisition_active") == true, "free observation opens inside FAST target acquisition")
	_check(scene.get("acquisition_completed") != true, "catalogue selection does not directly lock the target")
	var acquisition_entries: Array = scene.get("acquisition_entries")
	_check(acquisition_entries.size() >= 3, "FAST acquisition sky contains the radio target catalogue")
	_check(int(scene.get("stage")) == 0, "target acquisition does not skip the existing AIM stage")
	_check(
		scene.call("acquisition_direction_reachable", 50.0)
		and not scene.call("acquisition_direction_reachable", 49.9),
		"40 degree zenith-angle boundary is exact"
	)
	_check(scene.find_child("FastTargetAcquisitionPlot", true, false) != null, "instrument sky plot is visible")
	_check(scene.find_child("FastAcquisitionGuide", true, false) == null, "free tutorial mode does not force a guide overlay")

	var start_azimuth := float(scene.get("acquisition_azimuth"))
	Input.action_press("move_right")
	for _frame in range(18):
		await process_frame
	Input.action_release("move_right")
	await process_frame
	_check(float(scene.get("acquisition_azimuth")) > start_azimuth, "continuous Web/action input drives the feed cabin")

	scene.set("acquisition_velocity", Vector2.ZERO)
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_LEFT
	mouse_down.pressed = true
	scene.call("_on_acquisition_scope_input", mouse_down)
	var mouse_drag := InputEventMouseMotion.new()
	mouse_drag.relative = Vector2(14.0, -3.0)
	scene.call("_on_acquisition_scope_input", mouse_drag)
	var mouse_up := InputEventMouseButton.new()
	mouse_up.button_index = MOUSE_BUTTON_LEFT
	mouse_up.pressed = false
	scene.call("_on_acquisition_scope_input", mouse_up)
	_check(
		(scene.get("acquisition_velocity") as Vector2).length() > 0.1,
		"mouse drag applies a continuous feed-cabin steering impulse"
	)

	scene.set("acquisition_altitude", 50.1)
	scene.set("acquisition_velocity", Vector2.ZERO)
	for _frame in range(90):
		scene.call("_step_target_acquisition", Vector2.DOWN, false, 1.0 / 60.0)
	_check(float(scene.get("acquisition_altitude")) >= 50.0, "drive input cannot cross the 40 degree reachable-sky boundary")

	var selected_entry: Dictionary = {}
	for value in acquisition_entries:
		var entry := value as Dictionary
		if str(entry.get("id", "")) == "galactic_hi":
			selected_entry = entry
			break
	_check(not selected_entry.is_empty(), "a second radio programme can be selected inside the instrument")
	var model: RadioSignalModel = scene.get("model")
	scene.set("acquisition_state", "search")
	scene.set("acquisition_candidate_id", str(selected_entry.get("id", "")))
	scene.set("acquisition_azimuth", float(selected_entry.get("azimuth", 0.0)) + 2.0)
	scene.set("acquisition_altitude", float(selected_entry.get("altitude", 50.0)))
	scene.set("acquisition_velocity", Vector2.ZERO)
	scene.call("_attempt_acquisition_lock")
	await process_frame
	_check(str(scene.get("acquisition_state")) == "coarse", "broad beam capture produces coarse track only")
	_check(scene.get("acquisition_completed") != true, "coarse track is not treated as selected target")

	scene.set("acquisition_azimuth", float(selected_entry.get("azimuth", 0.0)))
	scene.set("acquisition_altitude", float(selected_entry.get("altitude", 50.0)))
	scene.set("acquisition_velocity", Vector2.ZERO)
	scene.call("_attempt_acquisition_lock")
	await process_frame
	_check(str(scene.get("acquisition_state")) == "locked", "fine threshold produces a real target lock")
	_check(scene.get("acquisition_completed") == true, "fine lock completes target acquisition")
	_check(
		str(gm.active_remote_free_entry("radio").get("id", "")) == "galactic_hi",
		"fine lock commits the radio programme selected by beam pointing"
	)
	_check(
		str((scene.get("model") as RadioSignalModel).target_id) == "galactic_hi_cloud",
		"receiver model is reconfigured only after the selected beacon is locked"
	)
	_check(int(scene.get("stage")) == 0, "fine lock hands off to AIM instead of skipping the radio pipeline")
	_check(
		(gm.progress.get("completed_levels", []) as Array) == completed_before,
		"free target acquisition never advances campaign progress"
	)

	await create_timer(1.05).timeout
	_check(scene.get("acquisition_active") != true, "locked target hands off to the existing AIM stage")
	_check(scene.find_child("FastTargetAcquisitionPlot", true, false) == null, "acquisition plot leaves after the handoff")
	_check(scene.find_child("FastAimPlot", true, false) != null or scene.get("scope") != null, "existing AIM controls remain available")

	current_scene = null
	scene.queue_free()
	await process_frame
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	finished = true
	print("FAST TARGET ACQUISITION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
