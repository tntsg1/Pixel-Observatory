extends SceneTree

const OUTPUT_DIR := "res://artifacts/l10_eyepiece_guidance"

var gm: Node
var active_scene: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_prepare_high_power_complete()
	await _capture_room_route()
	await _capture_cabinet()
	await _capture_telescope()
	print("L10 EYEPIECE GUIDANCE CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT_DIR))
	_finish(0)


func _prepare_high_power_complete() -> void:
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
	gm.update_room_guidance_for_level()


func _capture_room_route() -> void:
	active_scene = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(active_scene)
	await _settle(0.55)
	await _save("01_after_high_power_routes_to_cabinet.png")
	await _clear_scene()


func _capture_cabinet() -> void:
	gm.equip_part("eyepiece_20mm")
	active_scene = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(active_scene)
	await _settle(0.45)
	active_scene.call("_scroll_to_part_type", "eyepiece")
	await _settle(0.35)
	await _save("02_20mm_is_current_experiment.png")
	await _clear_scene()


func _capture_telescope() -> void:
	gm.install_part("eyepiece", 0, "eyepiece_20mm")
	gm.selected_object_id = "jupiter"
	gm.selected_object_level = 10
	active_scene = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(active_scene)
	await _settle(0.45)
	if active_scene.get("quiz_brief_overlay") != null:
		active_scene.call("_dismiss_pre_quiz_guide")
		await _settle(0.45)
		var overlay: Node = active_scene.get("quiz_brief_overlay")
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
			await process_frame
	for child in active_scene.find_children("TutorialHighlight_*", "", true, false):
		child.queue_free()
	await process_frame
	await _save("03_readable_20mm_observation_step.png")
	await _clear_scene()


func _settle(seconds: float) -> void:
	await process_frame
	await process_frame
	await create_timer(seconds).timeout


func _save(file_name: String) -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print("CAPTURE ", output_path)
	await process_frame


func _clear_scene() -> void:
	if active_scene != null:
		active_scene.queue_free()
		active_scene = null
	await process_frame
	await process_frame


func _finish(code: int) -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	quit(code)
