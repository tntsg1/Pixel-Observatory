extends SceneTree

const OUTPUT_DIR := "res://artifacts/operation_chain"

var gm: Node
var teaching: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	teaching = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		push_error("Operation-chain capture requires GameManager and TeachingFlowManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_assembly_snap()
	await _capture_target_lock()
	await _capture_result_chain()
	print("OPERATION CHAIN VISUAL CAPTURE PASS")
	quit(0)


func _prepare_level(level_number: int) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = level_number
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		if not gm.unlocked_parts_by_type(part_type).is_empty():
			gm.install_part(part_type, 0)
	gm.selected_object_id = str(gm.current_target_object_id())


func _capture_assembly_snap() -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	var assembly: Control = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(assembly)
	current_scene = assembly
	await _settle()
	assembly.call("_select_part", "tripod")
	assembly.call("_try_install", "tripod")
	await create_timer(0.62).timeout
	_save("01_assembly_snap_response.png")
	await _remove_scene(assembly)


func _capture_target_lock() -> void:
	_prepare_level(4)
	var view: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await _settle()
	view.call("_set_view_mode", "telescope")
	var target_id := str(view.get("target_id"))
	var data: Dictionary = view.get("sky_data")
	var sky_item: Dictionary = data.get(target_id, {}).duplicate(true)
	if float(sky_item.get("altitude", -90.0)) < 5.0:
		sky_item["altitude"] = 45.0
		sky_item["above_horizon"] = true
		data[target_id] = sky_item
		view.set("sky_data", data)
	view.set("target_lock_state", "search")
	view.set("telescope_azimuth", float(sky_item.get("azimuth", 180.0)))
	view.set("telescope_altitude", float(sky_item.get("altitude", 45.0)))
	view.call("_rebuild_view")
	await create_timer(0.18).timeout
	_save("02_mission_target_lock.png")
	await _remove_scene(view)


func _capture_result_chain() -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = 66
	var level: Dictionary = gm.current_level().duplicate(true)
	var target_id := str(level.get("target_object_id", "andromeda"))
	var observation := {
		"quality": "Excellent",
		"success": true,
		"observation_mode": "telescope",
		"effective_clarity": 94.0,
		"ratios": {"light": 1.24, "clarity": 1.18, "stability": 1.14},
	}
	var stats := {
		"aperture": 6500.0,
		"focal_length": 131400.0,
		"magnification": 1.0,
		"light_score": 96.0,
		"clarity_score": 92.0,
		"stability_score": 94.0,
	}
	gm.last_learning_card = teaching.call(
		"make_mission_complete_payload",
		level,
		gm.get_object(target_id),
		observation,
		stats
	)
	# The card normally opens after progression has selected the next mission.
	# Mirror that display context without completing or saving a mission here.
	gm.progress["current_level"] = 67
	teaching.active_card_mode = "complete"
	var card: Control = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	current_scene = card
	await _settle()
	_save("03_observation_result_chain.png")
	await _remove_scene(card)


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.32).timeout


func _remove_scene(node: Node) -> void:
	node.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
