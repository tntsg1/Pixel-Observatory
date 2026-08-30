extends SceneTree

# Regression: equipping a newly unlocked part must point the room's guidance
# highlight at the Assembly Table, but the Cabinet's own Back button must
# never teleport the player straight there - reaching it stays on foot, same
# as every other destination in the lobby. (Earlier this button relabeled
# itself "Continue to Assembly" and jumped scenes directly; that shortcut was
# removed.)

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("PARTS ASSEMBLY CONTINUATION TEST FAIL: GameManager missing")
		quit(1)
		return

	gm.new_game()
	# L7 unlocks a larger refractor objective while preserving the starter
	# objective as equipped, giving the cabinet a real replacement action.
	gm.debug_jump_to_level(7, false)
	gm.language_mode = "zh"
	var cabinet: Control = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	for _i in range(8):
		await process_frame

	var route_button := _route_button(cabinet, "observatory")
	_check(route_button != null, "cabinet route button exists")
	if route_button != null:
		_check(route_button.text == "返回基地", "before a change, Back returns to the room")

	var equip_button := _compatible_equip_button(cabinet, gm)
	_check(equip_button != null, "found an unlocked compatible replacement part")
	if equip_button != null:
		equip_button.pressed.emit()
		for _i in range(8):
			await process_frame

	_check(str(gm.room_guidance_target) == "assembly", "equipping a part points room guidance at the Assembly Table")
	route_button = _route_button(cabinet, "observatory")
	_check(route_button != null, "the Back button still exists after equipping")
	if route_button != null:
		_check(route_button.text == "返回基地", "Back still says 返回基地, not 前往组装台 (no scene-jump shortcut)")
	_check(_route_button(cabinet, str(gm.assembly_scene_key())) == null,
		"no button teleports straight into the assembly scene")

	if failures == 0:
		print("PARTS ASSEMBLY CONTINUATION TEST PASS")
		quit(0)
	else:
		print("PARTS ASSEMBLY CONTINUATION TEST FAIL (%d)" % failures)
		quit(1)


func _compatible_equip_button(cabinet: Control, gm: Node) -> Button:
	var current_family := str(gm.assembly_context_family())
	for node_value in cabinet.find_children("*", "Control", true, false):
		var card := node_value as Control
		if card == null or not card.has_meta("part_id"):
			continue
		var part_id := str(card.get_meta("part_id", ""))
		var part: Dictionary = gm.get_part(part_id)
		var part_family := str(part.get("telescope_family", ""))
		var part_type := str(part.get("type", ""))
		if part_type == "" or (part_family != "" and part_family != current_family):
			continue
		if str(gm.equipped_part_id(part_type)) == part_id:
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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
