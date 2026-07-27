extends SceneTree

const TransitionScript := preload("res://scripts/ui/stage_handoff_transition.gd")

var failures := 0
var finished := false


func _initialize() -> void:
	var watchdog := create_timer(24.0)
	watchdog.timeout.connect(func() -> void:
		if finished:
			return
		push_error("STAGE HANDOFF TRANSITION TEST TIMEOUT")
		quit(2)
	)
	await process_frame
	root.size = Vector2i(1024, 768)
	await _test_controller()
	await _test_fast_handoff()
	await _test_space_handoff()
	finished = true
	if failures == 0:
		print("STAGE HANDOFF TRANSITION TEST PASS")
		quit(0)
	else:
		print("STAGE HANDOFF TRANSITION TEST FAIL (%d)" % failures)
		quit(1)


func _test_controller() -> void:
	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var old_workspace := Control.new()
	old_workspace.position = Vector2(0, 128)
	old_workspace.size = Vector2(1024, 546)
	host.add_child(old_workspace)
	var next_workspace := Control.new()
	next_workspace.position = Vector2(0, 128)
	next_workspace.size = Vector2(1024, 546)
	host.add_child(next_workspace)
	var callback_state := {"midpoint": 0, "completed": 0}
	var transition = TransitionScript.new()
	transition.begin(
		host,
		old_workspace,
		next_workspace,
		Vector2(120, 92),
		Vector2(314, 92),
		false,
		func() -> void: callback_state["midpoint"] = int(callback_state["midpoint"]) + 1,
		func() -> void: callback_state["completed"] = int(callback_state["completed"]) + 1
	)
	_check(transition.active, "controller locks while a handoff is running")
	_check(host.find_child("StageTransitionInputGuard", false, false) != null, "controller installs one input guard")
	_check(host.find_child("StageHandoffPacket", false, false) != null, "controller draws the data packet on the stage rail")
	await create_timer(0.58).timeout
	_check(int(callback_state["midpoint"]) == 1, "controller resolves the data packet once at midpoint")
	await create_timer(0.52).timeout
	await process_frame
	_check(not transition.active and int(callback_state["completed"]) == 1, "controller completes once at the configured duration")
	_check(not is_instance_valid(old_workspace), "outgoing workspace is removed only after the handoff")
	_check(host.find_child("StageTransitionInputGuard", false, false) == null, "input guard is removed after completion")

	var reduced_old := Control.new()
	reduced_old.position = Vector2(0, 128)
	reduced_old.size = Vector2(1024, 546)
	host.add_child(reduced_old)
	var reduced_next := Control.new()
	reduced_next.position = Vector2(0, 128)
	reduced_next.size = Vector2(1024, 546)
	host.add_child(reduced_next)
	transition.begin(
		host,
		reduced_old,
		reduced_next,
		Vector2(314, 92),
		Vector2(508, 92),
		true,
		func() -> void: pass,
		func() -> void: pass
	)
	_check(transition.duration <= 0.18, "reduced motion keeps a short data-bearing crossfade")
	transition.finish_immediately()
	await process_frame
	_check(not transition.active, "finish-immediately leaves no transition lock")

	var abort_old := Control.new()
	abort_old.position = Vector2(0, 128)
	abort_old.size = Vector2(1024, 546)
	host.add_child(abort_old)
	var abort_next := Control.new()
	abort_next.position = Vector2(0, 128)
	abort_next.size = Vector2(1024, 546)
	host.add_child(abort_next)
	transition.begin(
		host,
		abort_old,
		abort_next,
		Vector2(508, 103),
		Vector2(702, 103),
		false,
		func() -> void: pass,
		func() -> void: pass
	)
	await create_timer(0.22).timeout
	transition.abort()
	await process_frame
	_check(not transition.active, "Back/exit can cancel a running handoff")
	_check(is_instance_valid(abort_old) and abort_old.position == Vector2(0, 128), "abort restores the outgoing workspace")
	_check(not is_instance_valid(abort_next), "abort removes the staged incoming workspace")
	_check(host.find_child("StageTransitionInputGuard", false, false) == null, "abort clears the transition input guard")
	host.queue_free()
	await process_frame


func _test_fast_handoff() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager is available for FAST handoff")
		return
	gm.new_game()
	gm.debug_jump_to_level(76, true)
	gm.set_tutorial_assistance_mode(gm.TUTORIAL_ASSIST_FREE)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	for _frame in range(8):
		await process_frame
	if bool(scene.get("intro_running")):
		scene.call("_finish_array_takeover")
		await process_frame
	var old_workspace: Control = scene.get("content")
	scene.call("_advance", 1)
	_check(int(scene.get("stage")) == 1, "FAST stages the next workspace immediately")
	_check(bool(scene.get("stage_transition_active")), "FAST blocks repeated confirmation during handoff")
	var snapshot: Dictionary = scene.get("stage_handoff_snapshot")
	_check(snapshot.has("stability") and snapshot.has("cable_load"), "AIM passes cabin stability and cable load into TUNE")
	scene.call("_advance", 2)
	_check(int(scene.get("stage")) == 1, "FAST ignores a second advance while the packet is moving")
	_check(is_instance_valid(old_workspace), "FAST keeps the outgoing plot alive during resolve")
	await create_timer(1.10).timeout
	await process_frame
	_check(not bool(scene.get("stage_transition_active")), "FAST releases input after the handoff")
	_check(not is_instance_valid(old_workspace), "FAST removes the old stage after acquire")
	_check(scene.find_child("FastHandoffInputSummary", true, false) != null, "FAST shows the previous stage input summary")
	var fast_focus := root.gui_get_focus_owner()
	var fast_content: Control = scene.get("content")
	_check(fast_focus != null and fast_content.is_ancestor_of(fast_focus), "FAST restores keyboard focus inside the acquired stage")
	root.gui_release_focus()
	scene.queue_free()
	for _frame in range(3):
		await process_frame


func _test_space_handoff() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager is available for space handoff")
		return
	gm.new_game()
	gm.debug_jump_to_level(66, true)
	gm.set_tutorial_assistance_mode(gm.TUTORIAL_ASSIST_FREE)
	var scene: Control = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	for _frame in range(8):
		await process_frame
	scene.set("stages", ["plan", "thermal", "guide", "wavefront", "expose", "process", "filter", "report"])
	scene.set("stage", 3)
	scene.set("furthest_stage", 3)
	scene.call("_rebuild")
	await process_frame
	var space_model: SpaceObservationModel = scene.get("model")
	space_model.wavefront_error_nm = 132.0
	space_model.segment_alignment = 0.94
	var old_workspace: Control = scene.get("content")
	scene.call("_advance")
	_check(int(scene.get("stage")) == 4, "space observatory stages Expose without rebuilding the shell")
	_check(bool(scene.get("stage_transition_active")), "space handoff blocks repeated stage commands")
	var snapshot: Dictionary = scene.get("stage_handoff_snapshot")
	_check(snapshot.has("wfe_nm") and snapshot.has("psf"), "Align passes WFE and PSF into Expose")
	_check(is_equal_approx(float(snapshot.get("wfe_nm", 0.0)), 132.0), "space handoff carries the real WFE value")
	_check(is_instance_valid(old_workspace), "space outgoing wavefront view remains during telemetry handoff")
	await create_timer(1.10).timeout
	await process_frame
	_check(not bool(scene.get("stage_transition_active")), "space handoff restores input")
	_check(not is_instance_valid(old_workspace), "space removes the old panel after Expose acquires")
	_check(scene.find_child("SpaceHandoffInputSummary", false, false) != null, "space Expose displays the incoming telemetry summary")
	var space_focus := root.gui_get_focus_owner()
	var space_content: Control = scene.get("content")
	_check(space_focus != null and space_content.is_ancestor_of(space_focus), "space observatory restores focus inside the acquired panel")
	root.gui_release_focus()
	scene.queue_free()
	for _frame in range(3):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: " + message)
