extends SceneTree

const OUTPUT_DIR := "res://artifacts/sky_deep_sky_lod"
const AIM := Vector2(180.0, 45.0)
const CASES := [
	["pleiades", "naked_eye"],
	["pleiades", "finder"],
	["pleiades", "telescope"],
	["orion_nebula", "finder"],
	["orion_nebula", "telescope"],
]


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(29, false)
	gm.language_mode = "en"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	view.set("location_transition_active", true)
	view.set("horizon_explanation_active", false)
	for case_value in CASES:
		var case: Array = case_value
		await _capture(view, str(case[0]), str(case[1]))
	print("SKY DEEP-SKY LOD CAPTURES: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture(view: Control, object_id: String, mode: String) -> void:
	view.set("target_id", object_id)
	view.set("selected_object_id", object_id)
	var sky: Dictionary = view.get("sky_data")
	for id_value in sky.keys():
		var hidden: Dictionary = sky[id_value].duplicate(true)
		hidden["altitude"] = -90.0
		hidden["visible"] = false
		sky[id_value] = hidden
	var item: Dictionary = sky.get(object_id, {}).duplicate(true)
	item["azimuth"] = AIM.x
	item["altitude"] = AIM.y
	item["visible"] = true
	item["below_horizon"] = false
	sky[object_id] = item
	view.set("sky_data", sky)
	view.set("view_mode", mode)
	view.call("_apply_view_mode")
	view.call("_update_mode_buttons")
	view.set("display_fov_x", view.get("fov_x"))
	view.set("display_fov_y", view.get("fov_y"))
	view.set("telescope_azimuth", AIM.x - (8.0 if mode == "naked_eye" else (2.8 if mode == "finder" else 0.82)))
	view.set("telescope_altitude", AIM.y + (4.0 if mode == "naked_eye" else (1.4 if mode == "finder" else 0.34)))
	view.set("display_azimuth", view.get("telescope_azimuth"))
	view.set("display_altitude", view.get("telescope_altitude"))
	view.call("_rebuild_view")
	await process_frame
	await process_frame
	var ring := view.get("target_state_ring") as Control
	if ring != null and is_instance_valid(ring):
		ring.visible = false
	var waypoint := view.get("faint_mission_target_waypoint") as Control
	if waypoint != null:
		waypoint.visible = false
	await process_frame
	var output := ProjectSettings.globalize_path("%s/%s_%s.png" % [OUTPUT_DIR, object_id, mode])
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
