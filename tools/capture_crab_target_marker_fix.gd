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
	# This fixture validates target feedback, not the low-altitude/site-change
	# teaching route. Suppress that blocking layer before rebuilding the sky.
	var horizon_tween := view.get("horizon_explanation_tween") as Tween
	if horizon_tween != null:
		horizon_tween.kill()
	var horizon_layer := view.get("horizon_explanation_layer") as Control
	if horizon_layer != null and is_instance_valid(horizon_layer):
		horizon_layer.queue_free()
		view.set("horizon_explanation_layer", null)
	view.set("location_transition_active", true)
	view.set("horizon_explanation_active", false)
	view.set("target_id", "crab_nebula")
	view.set("selected_object_id", "crab_nebula")
	await _set_fixture(view, "naked_eye", Vector2(155.0, 45.0))
	await _save("01_crab_naked_eye_approach_42px.png")
	await _set_fixture(view, "naked_eye", Vector2(180.0, 45.0), 1.20)
	await _save("02_crab_naked_eye_locked_42px.png")
	await _set_fixture(view, "finder", Vector2(180.0, 45.0), 1.20)
	await _save("03_crab_finder_locked_54px.png")
	print("CRAB TARGET MARKER CAPTURES: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _set_fixture(view: Control, mode: String, aim_position: Vector2, settle_seconds := 0.30) -> void:
	view.set("view_mode", mode)
	view.call("_apply_view_mode")
	view.call("_update_mode_buttons")
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get("crab_nebula", {}).duplicate(true)
	var target_azimuth := AIM.x
	var target_altitude := 45.0
	item["azimuth"] = target_azimuth
	item["altitude"] = target_altitude
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "capture_fixture"
	sky["crab_nebula"] = item
	view.set("sky_data", sky)
	view.set("telescope_azimuth", aim_position.x)
	view.set("telescope_altitude", aim_position.y)
	view.set("display_azimuth", aim_position.x)
	view.set("display_altitude", aim_position.y)
	view.set("display_fov_x", view.get("fov_x"))
	view.set("display_fov_y", view.get("fov_y"))
	view.call("_rebuild_view")
	await process_frame
	# The capture is a deterministic visual fixture. Stop live input/camera
	# interpolation only after the real scene has rebuilt at the catalog target.
	view.set_process(false)
	view.set("telescope_azimuth", aim_position.x)
	view.set("telescope_altitude", aim_position.y)
	view.set("display_azimuth", aim_position.x)
	view.set("display_altitude", aim_position.y)
	view.set("display_fov_x", view.get("fov_x"))
	view.set("display_fov_y", view.get("fov_y"))
	view.call("_rebuild_view")
	await process_frame
	await create_timer(settle_seconds).timeout


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	await process_frame
