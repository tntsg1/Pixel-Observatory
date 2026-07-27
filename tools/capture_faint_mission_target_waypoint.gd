extends SceneTree

const OUTPUT_DIR := "res://artifacts/faint_mission_target_waypoint"
const TARGET_LEVELS := {
	"crab_nebula": 30,
	"sombrero_galaxy": 31,
	"uranus": 32,
	"dumbbell_nebula": 33,
	"ring_nebula": 35
}
const AIM := Vector2(180.0, 45.0)
const IN_VIEW_POSITION := Vector2(198.0, 51.0)
const OUT_OF_VIEW_POSITION := Vector2(292.0, 51.0)

var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var capture_index := 1
	for target_id_value in TARGET_LEVELS.keys():
		var target_id := str(target_id_value)
		var view := await _spawn_view(target_id)
		await _save("%02d_%s_in_fov_waypoint.png" % [capture_index, target_id])
		capture_index += 1
		if target_id == "sombrero_galaxy" or target_id == "uranus":
			_set_target_fixture(view, target_id, AIM)
			await _settle()
			await _save("%02d_%s_locked_waypoint.png" % [capture_index, target_id])
			capture_index += 1
		if target_id == "ring_nebula":
			_set_target_fixture(view, target_id, OUT_OF_VIEW_POSITION)
			await _settle()
			await _save("%02d_%s_outside_fov_direction_card.png" % [capture_index, target_id])
			capture_index += 1
		view.queue_free()
		await process_frame
	print("FAINT TARGET CAPTURES: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _spawn_view(target_id: String) -> Control:
	gm.new_game()
	gm.debug_jump_to_level(int(TARGET_LEVELS[target_id]), false)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.selected_object_id = target_id
	gm.selected_object_level = int(TARGET_LEVELS[target_id])
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": AIM.x,
		"altitude": AIM.y,
		"view_mode": "naked_eye"
	}
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	view.set("target_id", target_id)
	view.set("selected_object_id", target_id)
	_set_target_fixture(view, target_id, IN_VIEW_POSITION)
	await process_frame
	await process_frame
	await _settle()
	_clear_tutorial_overlays()
	await process_frame
	return view


func _set_target_fixture(view: Control, target_id: String, position: Vector2) -> void:
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get(target_id, {}).duplicate(true)
	item["azimuth"] = position.x
	item["altitude"] = position.y
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "capture_fixture"
	sky[target_id] = item
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
