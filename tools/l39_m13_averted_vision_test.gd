extends SceneTree

var failures := 0
var gm: Node
var view: Control


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(39, true)
	gm.selected_object_id = "m13"
	view = load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	_check(bool(view.call("_is_cluster_target")), "M13 remains classified as a star cluster")
	_check(
		bool(view.call("_visual_detection_techniques_available")),
		"M13's required side-view technique is enabled despite its cluster catalog type"
	)
	_check(view.get("averted_vision_guide") != null, "M13 receives the same visible side-view guide as galaxies")
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	Input.action_press("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.62)
	_check(float(view.get("averted_hold_visual")) > 0.45, "M13 side-view gives continuous hold progress")
	view.call("_update_averted_vision_guide", 0.64)
	_check(bool(view.get("averted_vision_confirmed")), "M13 confirms after the shared 1.25-second Shift hold")
	var evaluated: Dictionary = view.call("_evaluate")
	var failure: Dictionary = evaluated.get("technique_failure", {})
	_check(str(failure.get("code", "")) != "averted_vision", "confirmed M13 side-view clears the mission requirement")
	_check(
		float(evaluated.get("technique_gains", {}).get("averted_vision", 1.0)) > 1.0,
		"confirmed M13 side-view applies the same measurable detection gain"
	)
	Input.action_release("dodge")
	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	Input.action_release("dodge")
	print("L39 M13 AVERTED VISION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
