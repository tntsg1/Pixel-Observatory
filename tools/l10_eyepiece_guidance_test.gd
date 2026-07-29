extends SceneTree

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_check(false, "GameManager autoload exists")
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(10, false)
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	for part_id in ["eyepiece_20mm", "eyepiece_10mm", "basic_finder_scope", "basic_focus_knob"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)

	gm.equip_part("eyepiece_10mm")
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.mark_mission_step_done("high_power")
	var auto_plan: Array = gm.auto_equip_plan()
	var planned_eyepiece := ""
	for entry_value in auto_plan:
		var entry: Dictionary = entry_value
		if str(entry.get("part_type", "")) == "eyepiece":
			planned_eyepiece = str(entry.get("part_id", ""))
			break
	_check(planned_eyepiece == "eyepiece_20mm", "one-click mission loadout selects the pending 20mm experiment eyepiece")

	var route: Dictionary = gm.current_room_route()
	_check(str(route.get("target", "")) == "cabinet", "after the 10mm pass, room guidance points to the Parts Cabinet")
	_check(str(route.get("required_part_id", "")) == "eyepiece_20mm", "route names the pending 20mm eyepiece")

	gm.equip_part("eyepiece_20mm")
	route = gm.current_room_route()
	_check(str(route.get("target", "")) == "assembly", "after equipping 20mm, guidance points to the Assembly Table")

	gm.install_part("eyepiece", 0, "eyepiece_20mm")
	route = gm.current_room_route()
	_check(str(route.get("target", "")) == "telescope", "after reinstalling 20mm, the Observation Pad reopens")

	await _check_cabinet(gm)
	await _check_telescope_panel(gm)
	_finish()


func _check_cabinet(gm: Node) -> void:
	var cabinet: Node = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	await process_frame
	await process_frame
	var all_text := _node_text(cabinet)
	var eyepiece_text := ""
	var high_power_text := ""
	for node in cabinet.find_children("*", "Control", true, false):
		if node.has_meta("part_id") and str(node.get_meta("part_id", "")) == "eyepiece_20mm":
			eyepiece_text = _node_text(node)
		elif node.has_meta("part_id") and str(node.get_meta("part_id", "")) == "eyepiece_10mm":
			high_power_text = _node_text(node)
	_check(all_text.contains("当前实验指定目镜"), "20mm card is identified as the current experiment part")
	_check(not eyepiece_text.contains("可用更佳设备") and not eyepiece_text.contains("10mm"), "task-required 20mm does not advertise 10mm as a better replacement")
	_check(not eyepiece_text.contains("Better available"), "English generic eyepiece upgrade warning is also suppressed")
	_check(not high_power_text.contains("本关必需") and not high_power_text.contains("当前任务推荐") and not high_power_text.contains("下一步安装"), "completed 10mm experiment is not still marked as required, recommended, or next")
	_check(not high_power_text.contains("Required for current mission") and not high_power_text.contains("Recommended for current mission") and not high_power_text.contains("Next assembly step"), "completed 10mm experiment has no English mission badge")
	cabinet.queue_free()
	await process_frame


func _check_telescope_panel(gm: Node) -> void:
	gm.selected_object_id = "jupiter"
	gm.selected_object_level = 10
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	var label := view.find_child("MissionStepLabel", true, false) as Label
	_check(label != null, "telescope view exposes a dedicated mission-step label")
	if label != null:
		_check(label.text.contains("20mm"), "mission-step label names the pending 20mm eyepiece")
		_check(label.text.contains("已完成 1/2") and label.text.contains("当前"), "mission-step label describes flexible completion progress")
		_check(not label.text.contains("Step") and not label.text.contains("Completed"), "Chinese mode does not leak the English progress prefix")
		_check(label.get_theme_font_size("font_size") >= 14, "mission-step text uses a readable font size")
		_check(label.size.y >= 34.0 and label.max_lines_visible >= 2, "mission-step label has room to wrap")
		_check(not label.clip_text, "mission-step text is not clipped")
	view.queue_free()
	await process_frame


func _node_text(node: Node) -> String:
	var lines: Array[String] = []
	if node is Label:
		lines.append((node as Label).text)
	elif node is Button:
		lines.append((node as Button).text)
	for child in node.get_children():
		lines.append(_node_text(child))
	return "\n".join(lines)


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("L10 EYEPIECE GUIDANCE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)
