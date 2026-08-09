extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	gm.new_game()
	gm.debug_jump_to_level(43, true)
	gm.selected_object_id = "neptune"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	_check(bool(view.call("_visual_detection_techniques_available")), "L43 explicit side-view requirement enables the technique for Neptune")
	_check(view.get("averted_vision_guide") != null, "L43 shows the side-view marker and progress guide")
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	Input.action_press("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.62)
	_check(float(view.get("averted_hold_visual")) > 0.45, "holding Shift produces visible side-view progress")
	view.call("_update_averted_vision_guide", 0.64)
	_check(bool(view.get("averted_vision_confirmed")), "L43 confirms the authored 1.25-second Shift hold")
	var evaluated: Dictionary = view.call("_evaluate")
	_check(str(evaluated.get("technique_failure", {}).get("code", "")) != "averted_vision", "confirmed L43 side-view clears the mission gate")
	Input.action_release("dodge")
	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	Input.action_release("dodge")
	print("L43 NEPTUNE AVERTED VISION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  FAIL: " + label)
