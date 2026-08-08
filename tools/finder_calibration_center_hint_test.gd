extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager autoload is available")
	if gm == null:
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(6, true)
	gm.language_mode = "zh"
	gm.last_sky_aim = {}
	var sky := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(sky)
	for _frame in range(8):
		await process_frame

	var entry_hint := sky.get("finder_calibration_center_hint") as Control
	_check(entry_hint != null and entry_hint.visible, "entering Finder shows a central calibration hint")
	_check(entry_hint != null and entry_hint.name == "FinderCalibrationEntryHint", "entry hint has a stable UI identity")
	_check(_descendant_text(entry_hint).contains("I / J / K / L"), "entry hint names the adjustment keys")
	_check(_descendant_text(entry_hint).contains("平行线重合"), "entry hint explains the alignment goal")
	_check(_descendant_text(entry_hint).contains("屏幕底部"), "entry hint points to the bottom calibration bar")
	if entry_hint != null:
		_check(entry_hint.get_global_rect().intersects(Rect2(88, 103, 630, 560)), "entry hint appears over the observing field")

	gm.progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	sky.call("_update_calibration_panel")
	await process_frame
	var complete_hint := sky.get("finder_calibration_center_hint") as Control
	_check(complete_hint != null and complete_hint.name == "FinderCalibrationCompleteHint", "completion replaces the entry hint once")
	_check(_descendant_text(complete_hint).contains("可以继续观测"), "completion tells the player to continue observing")
	_check(_descendant_text(complete_hint).contains("底部校准条"), "completion reminds the player about the bottom bar")
	var footer := sky.get("calibration_panel") as Control
	_check(footer != null and footer.visible, "bottom calibration bar stays visible with the completion hint")

	sky.queue_free()
	await process_frame
	_finish()


func _descendant_text(node: Node) -> String:
	if node == null:
		return ""
	var combined := ""
	if node is Label:
		combined += (node as Label).text + "\n"
	for child in node.get_children():
		combined += _descendant_text(child)
	return combined


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	print("FINDER CALIBRATION CENTER HINT TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
