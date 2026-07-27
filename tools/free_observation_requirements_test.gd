extends SceneTree

const TEST_TIMEOUT_SECONDS := 20.0

var failures := 0
var finished := false


func _initialize() -> void:
	_start_watchdog()
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish(1)
		return

	gm.new_game()
	gm.debug_jump_to_level(33, true)
	_check(str(gm.current_level().get("observation_requirements", {}).get("filter", "")) == "nebula", "fixture mission requires a nebula filter")
	gm.selected_object_id = "moon"
	_check(gm.is_free_observation(), "Moon is a free target during the nebula mission")

	var free_view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(free_view)
	for _frame in range(8):
		await process_frame
	var free_requirements: Dictionary = free_view.call("_active_observation_requirements")
	_check(free_requirements.is_empty(), "free Moon inherits no mission observation requirements")
	_check(free_view.get("technique_filter_button") == null, "free Moon does not show the nebula-filter control")
	var free_result: Dictionary = free_view.call("_evaluate")
	_check(str(free_result.get("technique_failure", {}).get("code", "")) != "filter", "free Moon is never capped by the mission nebula-filter gate")
	_check(not str(free_result.get("feedback_en", "")).contains("nebula filter"), "free Moon feedback contains no nebula-filter instruction")
	free_view.queue_free()
	await process_frame

	gm.selected_object_id = gm.current_target_object_id()
	var mission_view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(mission_view)
	for _frame in range(8):
		await process_frame
	var mission_requirements: Dictionary = mission_view.call("_active_observation_requirements")
	_check(str(mission_requirements.get("filter", "")) == "nebula", "returning to the mission target restores its nebula-filter requirement")
	_check(mission_view.get("technique_filter_button") != null, "mission target still exposes the required filter control")
	mission_view.queue_free()
	await process_frame

	print("FREE OBSERVATION REQUIREMENTS TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	_finish(0 if failures == 0 else 1)


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if finished:
			return
		push_error("FREE OBSERVATION REQUIREMENTS TEST TIMEOUT")
		_finish(124)
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
		failures += 1
		print("  FAIL: " + label)
