extends SceneTree

const OUTPUT_DIR := "res://artifacts/current"
const TARGET_ID := "andromeda"
const LEVEL_ID := 20
const AIM := Vector2(180.0, 45.0)
const APPROACH_POSITION := Vector2(198.0, 51.0)

var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.debug_jump_to_level(LEVEL_ID, false)
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.selected_object_id = TARGET_ID
	gm.selected_object_level = LEVEL_ID
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": AIM.x,
		"altitude": AIM.y,
		"view_mode": "naked_eye"
	}

	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	view.set("target_id", TARGET_ID)
	view.set("selected_object_id", TARGET_ID)
	_clear_tutorial_overlays()

	_set_target_fixture(view, APPROACH_POSITION)
	await _settle()
	await _save("andromeda_approach_ring_zh.png")

	_set_target_fixture(view, AIM)
	await _settle()
	await _save("andromeda_lock_ring_zh.png")

	view.queue_free()
	await process_frame
	quit(0)


func _set_target_fixture(view: Control, position: Vector2) -> void:
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get(TARGET_ID, {}).duplicate(true)
	item["azimuth"] = position.x
	item["altitude"] = position.y
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "capture_fixture"
	sky[TARGET_ID] = item
	view.set("sky_data", sky)
	view.set("telescope_azimuth", AIM.x)
	view.set("telescope_altitude", AIM.y)
	gm.publish_sky_positions(sky)
	view.call("_rebuild_view")


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.30).timeout


func _clear_tutorial_overlays() -> void:
	for child in root.find_children("TutorialHighlight_*", "", true, false):
		child.queue_free()


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	else:
		print("CAPTURE ", output)
	await process_frame
