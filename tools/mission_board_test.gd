extends SceneTree

# Regression coverage for the Mission Board route resolver. The board must
# reflect the same equipment and task state that gates the real observatory.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return
	gm.new_game()

	var room_scene: PackedScene = load("res://scenes/observatory_room.tscn")
	var room: Node = room_scene.instantiate()
	root.add_child(room)
	await process_frame

	# L1 has no telescope requirement: the board must point to the pad.
	gm.progress["current_level"] = 1
	gm.reset_assembly()
	var route: Dictionary = room.call("_mission_board_route")
	_check(str(route.get("target", "")) == "telescope", "L1 routes to Observation Pad")
	_check(bool(route.get("ready", false)), "L1 is ready without telescope equipment")

	# L3 starts with parts selected but not installed: route to assembly.
	gm.progress["current_level"] = 3
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	route = room.call("_mission_board_route")
	_check(str(route.get("target", "")) == "assembly", "L3 routes to Assembly Table before telescope is built")
	_check(not bool(route.get("ready", false)), "L3 reports telescope not ready")

	# L4 must explicitly surface Focus Knob installation before the sky pad.
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	route = room.call("_mission_board_route")
	var missing: Array = room.call("_mission_missing_names")
	var l4_rows: Array = room.call("_mission_board_checklist", route)
	_check(str(route.get("target", "")) == "assembly", "L4 routes to Assembly Table while Focus Knob is uninstalled")
	_check(not missing.is_empty(), "L4 Mission Board lists missing equipment")
	_check(_rows_contain(l4_rows, "Focus Knob"), "L4 checklist makes Focus Knob installation explicit")

	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	route = room.call("_mission_board_route")
	_check(str(route.get("target", "")) == "telescope", "L4 routes to Observation Pad after required parts are installed")
	_check(bool(route.get("ready", false)), "L4 reports ready after assembly")

	# L10 puts both eyepiece passes in the visible, data-driven checklist.
	gm.progress["current_level"] = 10
	for part_value in gm.parts_data:
		if part_value is Dictionary:
			var part: Dictionary = part_value
			var part_id := str(part.get("id", ""))
			if part_id != "" and not gm.progress["unlocked_parts"].has(part_id):
				gm.progress["unlocked_parts"].append(part_id)
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	route = room.call("_mission_board_route")
	var l10_rows: Array = room.call("_mission_board_checklist", route)
	_check(
		_rows_contain(l10_rows, "32mm") and _rows_contain(l10_rows, "20mm") and _rows_contain(l10_rows, "10mm"),
		"L10 checklist names all three eyepiece passes"
	)

	# L10 now compares three eyepieces, so the board correctly routes to the
	# Parts Cabinet until the CURRENT pass's eyepiece is fitted. Fit the first
	# one (32mm) so the pad-guidance assertion below tests what it always did:
	# a mission whose equipment is ready points at the Observation Pad.
	gm.equip_part("eyepiece_32mm")
	gm.install_part("eyepiece", 0)
	route = room.call("_mission_board_route")
	_check(str(route.get("target", "")) == "telescope", "L10 routes to the pad once the current pass's eyepiece is fitted")

	room.call("_open_mission_board")
	_check(room.get("mission_board_popup") != null, "Mission Board opens as a modal task center")
	room.call("_close_mission_board", true)
	_check(str(gm.room_guidance_target) == "telescope", "closing board sets large Observation Pad guidance")
	room.queue_free()

	if failures == 0:
		print("MISSION BOARD TEST PASS")
		quit(0)
	else:
		print("MISSION BOARD TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1


func _rows_contain(rows: Array, fragment: String) -> bool:
	for row_value in rows:
		if row_value is Dictionary and str((row_value as Dictionary).get("label", "")).contains(fragment):
			return true
	return false
