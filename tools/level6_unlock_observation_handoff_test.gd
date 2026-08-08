extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(6, true)
	gm.progress["pending_unlock_notice"] = ["eyepiece_10mm"]

	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	current_scene = room
	for _i in range(6):
		await process_frame

	var action := _find_button(room, "打开观星台")
	_check(action != null, "L6 unlock action opens the Observation Pad")
	_check(_labels_contain(room, "返回观星台继续"), "L6 unlock copy matches the observation handoff")
	_check(not _labels_contain(room, "到零件柜装备"), "L6 unlock copy no longer sends the player to the Parts Cabinet")
	if action != null:
		action.pressed.emit()
		await process_frame
		_check(str(gm.observatory_spawn_id) == "telescope", "unlock handoff targets the central telescope pad")
		_check(current_scene != room, "unlock action leaves the lobby for the observation flow")

	_finish()


func _find_button(parent: Node, expected_text: String) -> Button:
	for child in parent.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.text == expected_text:
			return button
	return null


func _labels_contain(parent: Node, fragment: String) -> bool:
	for child in parent.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null and label.text.contains(fragment):
			return true
	return false


func _finish() -> void:
	print("LEVEL 6 UNLOCK OBSERVATION HANDOFF TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
