extends SceneTree

# FAST regression: mission completion and cabinet equipment changes must return
# to the observatory's physical route. Neither Continue nor the cabinet may
# teleport the player into a work screen.

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAST GUIDED SETUP HANDOFF TEST FAIL: GameManager missing")
		quit(1)
		return

	# L76 hands three new receiver/control parts to L77. Continue should put the
	# player back beside the console and highlight the cabinet across the room.
	gm.new_game()
	gm.debug_jump_to_level(76, true)
	_check(gm.complete_current_mission("pulsar_b0329", {
		"success": true,
		"quality": "Excellent",
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0},
	}), "L76 FAST completion succeeds")
	_check(int(gm.progress.get("current_level", 0)) == 77, "FAST advances to L77")
	_check(str(gm.current_room_route().get("target", "")) == "cabinet", "L77 route identifies the Parts Cabinet")
	_check(gm.go_to_pending_mission_setup(), "Continue accepts the pending guided setup")
	for _i in range(4):
		await process_frame
	var scene_path := current_scene.scene_file_path if current_scene != null else ""
	_check(scene_path.ends_with("observatory_room.tscn"), "FAST Continue returns to the observatory, not the cabinet")
	_check(str(gm.room_guidance_target) == "cabinet", "FAST cabinet remains highlighted in the room")
	var unlock_popup := current_scene.find_child("EquipmentUnlockPopup", true, false) if current_scene != null else null
	_check(unlock_popup != null, "new FAST parts are announced before route guidance resumes")
	var unlock_route_button := current_scene.find_child("UnlockRouteButton", true, false) as Button if current_scene != null else null
	_check(unlock_route_button != null, "unlock announcement offers a room route instead of opening the cabinet")
	if unlock_route_button != null:
		unlock_route_button.pressed.emit()
		for _i in range(4):
			await process_frame
		scene_path = current_scene.scene_file_path if current_scene != null else ""
		_check(scene_path.ends_with("observatory_room.tscn"), "unlock route action keeps the player in the observatory")
	_check_visible_room_highlight(current_scene, "cabinet", "FAST Continue visibly highlights the Parts Cabinet")

	# Build a realistic L77 handoff: L76 hardware is installed, while three new
	# receiver/control parts are unlocked but not selected or installed yet.
	gm.new_game()
	gm.debug_jump_to_level(76, true)
	var l76_assembly: Dictionary = gm.progress.get("assembly_state", {}).duplicate(true)
	var l76_selection: Dictionary = gm.progress.get("selected_parts", {}).duplicate(true)
	gm.debug_jump_to_level(77, false)
	gm.progress["assembly_state"] = l76_assembly
	gm.progress["selected_parts"] = l76_selection
	gm.progress["telescope_ready"] = false
	gm.update_room_guidance_for_level()
	_check(str(gm.current_room_route().get("required_part_id", "")) == "fast_tension_controller", "L77 asks for the first newly unlocked FAST part")

	var cabinet: Control = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	for _i in range(8):
		await process_frame
	var ordered_new_parts := [
		["fast_tension_controller", "tension_controller"],
		["fast_feed_receiver", "feed_receiver"],
		["fast_rf_receiver", "rf_receiver"],
	]
	for index in range(ordered_new_parts.size()):
		var part_id := str(ordered_new_parts[index][0])
		var part_type := str(ordered_new_parts[index][1])
		var equip_button := _equip_button_for(cabinet, part_id)
		_check(equip_button != null, "%s has an enabled Equip button" % part_id)
		if equip_button != null:
			equip_button.pressed.emit()
			for _i in range(8):
				await process_frame
		_check(str(gm.equipped_part_id(part_type)) == part_id, "cabinet selects %s" % part_id)
		var slot: Dictionary = gm.progress.get("assembly_state", {}).get(part_type, {})
		_check(not bool(slot.get("installed", false)), "equipping %s does not install it" % part_id)
		if index < ordered_new_parts.size() - 1:
			_check(str(gm.room_guidance_target) == "cabinet", "cabinet remains highlighted while another FAST part is missing")
		else:
			_check(str(gm.room_guidance_target) == "assembly", "after the last equipment choice, Assembly Table is highlighted")

	_check(not gm.telescope_is_ready(), "FAST remains unavailable until bench installation")

	var route_button := _route_button(cabinet, "observatory")
	_check(route_button != null, "FAST cabinet exits through the observatory")
	if route_button != null:
		route_button.pressed.emit()
		for _i in range(4):
			await process_frame
		scene_path = current_scene.scene_file_path if current_scene != null else ""
		_check(scene_path.ends_with("observatory_room.tscn"), "FAST cabinet does not teleport to the assembly screen")
		_check(str(gm.room_guidance_target) == "assembly", "Assembly highlight survives the room return")
		_check_visible_room_highlight(current_scene, "assembly", "returning from the FAST cabinet visibly highlights the Assembly Table")

	if failures == 0:
		print("FAST GUIDED SETUP HANDOFF TEST PASS")
		quit(0)
	else:
		print("FAST GUIDED SETUP HANDOFF TEST FAIL (%d)" % failures)
		quit(1)


func _equip_button_for(cabinet: Control, part_id: String) -> Button:
	for node_value in cabinet.find_children("*", "Control", true, false):
		var card := node_value as Control
		if card == null or str(card.get_meta("part_id", "")) != part_id:
			continue
		var button := card.get_node_or_null("EquipButton") as Button
		if button != null and not button.disabled:
			return button
	return null


func _route_button(cabinet: Control, destination: String) -> Button:
	for node_value in cabinet.find_children("*", "Button", true, false):
		var button := node_value as Button
		if button != null and str(button.get_meta("destination_scene", "")) == destination:
			return button
	return null


func _check_visible_room_highlight(room: Node, target_id: String, label: String) -> void:
	if room == null:
		_check(false, label)
		return
	room.call("_update_room_guidance_panel")
	var item: Dictionary = room.call("_get_interactable", target_id)
	var target_center: Vector2 = item.get("rect", Rect2()).get_center()
	var aligned := false
	for node_value in room.find_children("GuidanceCornerFrameOuter", "Control", true, false):
		var frame := node_value as Control
		if frame != null and frame.is_visible_in_tree() and frame.get_rect().get_center().distance_to(target_center) <= 2.0:
			aligned = true
			break
	if not aligned:
		var feedback := root.get_node_or_null("/root/InteractionFeedback")
		print("  diagnostic highlight target=", target_id,
			" suspended=", room.get("room_guidance_suspended"),
			" full_tutorials=", root.get_node("/root/GameManager").uses_full_tutorials(),
			" highlights_enabled=", feedback.guidance_highlights_enabled() if feedback != null else null,
			" frames=", room.find_children("GuidanceCornerFrameOuter", "Control", true, false).size())
	_check(aligned, label)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
