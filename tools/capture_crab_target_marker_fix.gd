extends SceneTree

const OUTPUT_DIR := "res://artifacts/crab_target_marker_fix"
const AIM := Vector2(180.0, 45.0)

var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.debug_jump_to_level(30, false)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.selected_object_id = "crab_nebula"
	gm.selected_object_level = 30
	gm.last_sky_aim = {"valid": true, "azimuth": AIM.x, "altitude": AIM.y, "view_mode": "naked_eye"}
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	view.set("target_id", "crab_nebula")
	view.set("selected_object_id", "crab_nebula")
	await _set_fixture(view, "naked_eye")
	await _save("01_crab_naked_eye_formal_42px_marker.png")
	await _set_fixture(view, "finder")
	await _save("02_crab_finder_formal_marker.png")
	await _set_fixture(view, "telescope")
	await _save("03_crab_telescope_formal_marker.png")
	print("CRAB TARGET MARKER CAPTURES: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _set_fixture(view: Control, mode: String) -> void:
	view.set("view_mode", mode)
	view.call("_apply_view_mode")
	view.call("_update_mode_buttons")
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get("crab_nebula", {}).duplicate(true)
	var target_azimuth := float(item.get("azimuth", AIM.x))
	var target_altitude := maxf(8.0, float(item.get("altitude", AIM.y)))
	item["azimuth"] = target_azimuth
	item["altitude"] = target_altitude
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "capture_fixture"
	sky["crab_nebula"] = item
	view.set("sky_data", sky)
	view.set("telescope_azimuth", target_azimuth)
	view.set("telescope_altitude", target_altitude)
	view.set("display_azimuth", target_azimuth)
	view.set("display_altitude", target_altitude)
	view.set("display_fov_x", view.get("fov_x"))
	view.set("display_fov_y", view.get("fov_y"))
	view.call("_rebuild_view")
	await process_frame
	# The capture is a deterministic visual fixture. Stop live input/camera
	# interpolation only after the real scene has rebuilt at the catalog target.
	view.set_process(false)
	view.set("telescope_azimuth", target_azimuth)
	view.set("telescope_altitude", target_altitude)
	view.set("display_azimuth", target_azimuth)
	view.set("display_altitude", target_altitude)
	view.set("display_fov_x", view.get("fov_x"))
	view.set("display_fov_y", view.get("fov_y"))
	view.call("_rebuild_view")
	await process_frame
	await create_timer(0.30).timeout


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	await process_frame
