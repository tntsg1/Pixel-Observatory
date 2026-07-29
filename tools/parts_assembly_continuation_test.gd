extends SceneTree

# Regression: choosing a newly unlocked part must make the next explicit action
# the correct Assembly Table, never the Observation Pad.

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

	var initial_route := _route_button(cabinet, "observatory")
	_check(initial_route != null, "initial cabinet route button exists")
	if initial_route != null:
		_check(str(initial_route.get_meta("destination_scene", "")) == "observatory", "before a change, Back returns to the room")

	var equip_button := _compatible_equip_button(cabinet, gm)
	_check(equip_button != null, "found an unlocked compatible replacement part")
	if equip_button != null:
		equip_button.pressed.emit()
		for _i in range(8):
			await process_frame

	_check(bool(cabinet.get("reassembly_route_ready")), "equipping a part arms assembly continuation")
	var route_button := _route_button(cabinet, str(gm.assembly_scene_key()))
	_check(route_button != null, "assembly continuation button exists after equip")
	if route_button != null:
		_check(route_button.text == "前往组装台", "button clearly says 前往组装台")
		_check(str(route_button.get_meta("destination_scene", "")) == str(gm.assembly_scene_key()), "route targets the current family's assembly scene")
		_check(str(route_button.get_meta("destination_scene", "")) not in ["sky", "telescope", "observatory"], "route cannot fall through to observation")

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
