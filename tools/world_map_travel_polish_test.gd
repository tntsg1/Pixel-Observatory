extends SceneTree

# Relocation motion regression: the presentation may become richer, but the
# real site data must remain untouched until arrival.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(11, true)
	_force_below_horizon(gm)
	var original_site: Dictionary = gm.observing_location().duplicate(true)

	var map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	map.set_process(false)
	map.call("_skip_animation")

	var selected_id := str(map.get("selected_id"))
	var visibility: Dictionary = (map.get("site_visibility") as Dictionary).get(selected_id, {})
	var destination: Dictionary = visibility.get("site", {})
	_check(not destination.is_empty(), "destination is available")
	map.call("_on_confirm")
	_check(int(map.get("phase")) == 5, "confirm begins coordinate handoff")
	_check((map.get("travel_hud") as Control).visible, "coordinate HUD appears during handoff")
	_check(is_equal_approx(float(map.get("display_latitude")), float(original_site.get("lat", 0.0))), "latitude begins at current site")
	_check(is_equal_approx(float(map.get("display_longitude")), float(original_site.get("lon", 0.0))), "longitude begins at current site")
	_check(float(map.get("travel_distance_km")) > 1.0, "real travel distance is calculated")

	map.call("_process", float(map.call("_duration", 5)) + 0.01)
	_check(int(map.get("phase")) == 6, "handoff enters travel phase")
	var duration := float(map.call("_duration", 6))
	map.call("_process", duration * 0.48)
	var mid_progress := float(map.get("travel_marker_progress"))
	var mid_lat := float(map.get("display_latitude"))
	var mid_lon := float(map.get("display_longitude"))
	_check(mid_progress > 0.2 and mid_progress < 0.8, "travel marker advances smoothly at mid-flight")
	_check(not is_equal_approx(mid_lat, float(original_site.get("lat", 0.0))), "latitude rolls during travel")
	_check(not is_equal_approx(mid_lon, float(original_site.get("lon", 0.0))), "longitude rolls during travel")
	_check(not is_equal_approx(mid_lat, float(destination.get("lat", 0.0))), "latitude does not jump directly to destination")
	_check(str((map.get("travel_coords_label") as Label).text) != "", "coordinate HUD is populated")
	_check(float((map.get("travel_progress_bar") as ProgressBar).value) > 0.0, "travel progress is continuous")
	_check(str(gm.observing_location().get("id", "")) == str(original_site.get("id", "")), "real observing location is unchanged mid-animation")

	map.call("_process", duration * 0.53)
	_check(int(map.get("phase")) == 7, "travel settles into arrival phase")
	_check(is_equal_approx(float(map.get("display_latitude")), float(destination.get("lat", 0.0))), "arrival latitude matches destination")
	_check(is_equal_approx(float(map.get("display_longitude")), float(destination.get("lon", 0.0))), "arrival longitude matches destination")
	_check(float(map.get("arrival_flash")) > 0.9, "arrival synchronization pulse fires")
	_check(str(gm.observing_location().get("id", "")) == str(original_site.get("id", "")), "location commit still waits for completed transition")

	map.queue_free()
	await process_frame
	if failures == 0:
		print("WORLD MAP TRAVEL POLISH TEST PASS")
		quit(0)
	else:
		print("WORLD MAP TRAVEL POLISH TEST FAIL (%d)" % failures)
		quit(1)


func _force_below_horizon(gm: Node) -> void:
	var radec: Dictionary = gm.current_target_radec()
	var service := SkyPositionService.new()
	for site_value in gm.location_sites():
		var site: Dictionary = site_value
		var visibility := service.visibility_at(
			float(radec.get("ra_hours", 0.0)),
			float(radec.get("dec_degrees", 0.0)),
			float(site.get("lat", 0.0)),
			float(site.get("lon", 0.0))
		)
		if bool(visibility.get("below_horizon", false)):
			gm.set_observing_location(site)
			return


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
