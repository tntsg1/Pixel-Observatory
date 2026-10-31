extends SceneTree

const OUTPUT_DIR := "res://artifacts/l30_guidance_acceptance"

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.debug_jump_to_level(30, true)
	_check(gm.equip_part("reflector_mount"), "test can reproduce equipping the Newtonian Reflector Mount")
	gm.update_room_guidance_for_level()
	var wrong_route: Dictionary = gm.current_room_route()
	_check(str(wrong_route.get("target", "")) == "cabinet", "wrong prescribed mount routes to the Parts Cabinet")
	_check(str(wrong_route.get("required_part_id", "")) == "basic_mount", "route identifies Basic Mount as the exact requirement")
	_check(str(wrong_route.get("equipped_part_id", "")) == "reflector_mount", "route reports the currently equipped Newtonian mount")
	var wrong_hint := str(wrong_route.get("hint", ""))
	_check(wrong_hint.contains("牛顿反射镜支架") and wrong_hint.contains("基础支架"), "Chinese hint names both current and required mounts")
	_check(wrong_hint.contains("数值更高也不能替代"), "hint explains why the best-stat part is not accepted")

	var auto_plan: Array = gm.auto_equip_plan()
	_check(_planned_id_for_type(auto_plan, "mount") == "basic_mount", "one-click loadout chooses the prescribed Basic Mount")
	var cabinet: Control = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	await _settle()
	_check(bool(cabinet.call("_is_recommended", gm.get_part("basic_mount"))), "Basic Mount is highlighted as required")
	_check(not bool(cabinet.call("_is_recommended", gm.get_part("reflector_mount"))), "Newtonian mount is no longer generically recommended on L30")
	var cabinet_text := _collect_control_text(cabinet)
	_check(cabinet_text.contains("已装备，但不符合本关指定"), "cabinet marks the equipped incompatible part")
	cabinet.queue_free()
	await process_frame

	var room: Control = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await _settle()
	room.call("_update_room_guidance_panel")
	var hint_label: Label = room.get("guidance_hint_label")
	_check(hint_label != null and hint_label.text == gm.room_guidance_hint, "room panel keeps the detailed equipment diagnostic visible")
	await _capture("l30_wrong_mount_detailed_guidance.png")
	room.queue_free()
	await process_frame

	_check(gm.equip_part("basic_mount"), "player can equip the prescribed Basic Mount")
	gm.install_part("mount", 0)
	_check(gm.telescope_is_ready(), "hardware becomes ready after reinstalling the prescribed mount")
	gm.set_collimation_score(0.0)
	var collimation_route: Dictionary = gm.current_room_route()
	_check(str(collimation_route.get("target", "")) == "assembly", "unfinished collimation routes to the Assembly Table")
	_check(str(collimation_route.get("hint", "")).contains("0%") and str(collimation_route.get("hint", "")).contains("86%"), "collimation hint shows current and required percentages")

	var assembly: Control = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(assembly)
	current_scene = assembly
	await _settle()
	var collimate_button := _find_button(assembly, "准直镜面")
	_check(collimate_button != null and not collimate_button.disabled, "Collimate Mirrors button is enabled when hardware is complete")
	await _capture("l30_collimation_next_step.png")
	assembly.queue_free()
	await process_frame

	gm.set_collimation_score(86.0)
	var ready_route: Dictionary = gm.current_room_route()
	_check(str(ready_route.get("target", "")) == "telescope", "completed prescribed loadout proceeds to observation")
	_check(str(ready_route.get("target", "")) != "cabinet", "generic deep-sky upgrade advice cannot override L30's prescribed loadout")

	if failures == 0:
		print("L30 GUIDANCE REGRESSION TEST PASS")
		quit(0)
	else:
		print("L30 GUIDANCE REGRESSION TEST FAIL: ", failures)
		quit(1)


func _planned_id_for_type(plan: Array, part_type: String) -> String:
	for entry_value in plan:
		var entry: Dictionary = entry_value
		if str(entry.get("part_type", "")) == part_type:
			return str(entry.get("part_id", ""))
	return ""


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func _collect_control_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child in node.get_children():
		result += _collect_control_text(child)
	return result


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	_check(root.get_texture().get_image().save_png(output_path) == OK, "saved " + file_name)
	print("CAPTURE ", output_path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
