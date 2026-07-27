extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(77, true)

	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(5):
		await process_frame
	room.call("_open_mission_board")
	for _i in range(4):
		await process_frame

	var popup := room.find_child("MissionBoardModal", true, false) as Control
	_check(popup != null, "Level 77 mission board opens")
	if popup != null:
		_check(popup.z_index >= 1100, "mission board is rendered on the modal layer")
	var panel := room.find_child("MissionBoardPanel", true, false) as Control
	_check(panel != null, "mission board content panel exists")
	var show_route := room.find_child("ShowRouteButton", true, false) as Button
	var close_button := _find_button(room, "Close")
	var log_button := _find_button(room, "Open Logbook")
	_check(show_route != null and close_button != null and log_button != null,
		"all mission-board actions remain reachable")

	var furniture_data: Array = room.get("furniture_occluders")
	for data_value in furniture_data:
		var data: Dictionary = data_value
		var occluder := data.get("node") as CanvasItem
		_check(occluder == null or not occluder.visible,
			"furniture cutout %s is hidden while the mission modal is open" % str(data.get("id", "")))

	if panel != null:
		var panel_rect := panel.get_global_rect()
		for button in [show_route, log_button, close_button]:
			if button != null:
				_check(panel_rect.encloses(button.get_global_rect()),
					"%s stays inside the mission board" % button.text)

	room.queue_free()
	await process_frame
	_finish()


func _find_button(parent: Node, text_value: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text_value:
			return button
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("MISSION BOARD LAYERING TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
