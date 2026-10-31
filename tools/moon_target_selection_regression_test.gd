extends SceneTree

var failures := 0
var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	_test_online_validation()
	_test_local_moon_position()
	await _test_sky_target_navigation()
	_test_free_observation_separation()
	_test_below_horizon_route()
	if failures == 0:
		print("MOON TARGET SELECTION REGRESSION PASS")
		quit(0)
	else:
		print("MOON TARGET SELECTION REGRESSION FAIL (%d)" % failures)
		quit(1)


func _test_online_validation() -> void:
	var service := SkyPositionService.new()
	var valid := _api_payload(23.5, 112.25)
	var parsed: Dictionary = service.call("_parse_astronomy_api_positions", valid, Rect2(0, 0, 630, 560))
	_check(parsed.has("moon"), "valid API Moon position is accepted")
	var missing := _api_payload(null, 112.25)
	_check((service.call("_parse_astronomy_api_positions", missing, Rect2(0, 0, 630, 560)) as Dictionary).is_empty(), "missing API altitude is rejected")
	var nan_payload := _api_payload(NAN, 112.25)
	_check((service.call("_parse_astronomy_api_positions", nan_payload, Rect2(0, 0, 630, 560)) as Dictionary).is_empty(), "NaN API altitude is rejected")
	var unreasonable := _api_payload(120.0, 112.25)
	_check((service.call("_parse_astronomy_api_positions", unreasonable, Rect2(0, 0, 630, 560)) as Dictionary).is_empty(), "out-of-range API altitude is rejected")


func _test_local_moon_position() -> void:
	var service := SkyPositionService.new()
	service.config["offline_mode"] = true
	var sky := service.get_sky_positions(Rect2(0, 0, 630, 560), {}, 34.0522, -118.2437)
	_check(sky.has("moon"), "offline/local sky always contains Moon")
	_check(service.is_valid_position_item(sky.get("moon", {})), "local Moon position is finite and physical")
	_check(not service.request_online_planet_data(root, Rect2(), Callable()), "offline mode does not start an API request")


func _test_sky_target_navigation() -> void:
	gm.new_game()
	gm.progress["current_level"] = 1
	gm.selected_object_id = ""
	gm.last_sky_aim = {"valid": true, "azimuth": 180.0, "altitude": 45.0, "view_mode": "naked_eye"}
	var sky_view: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky_view)
	# Replace only the time-dependent horizontal coordinates with a deterministic
	# above-horizon fixture before the deferred world-map gate runs.
	var sky: Dictionary = sky_view.get("sky_data")
	var moon: Dictionary = sky.get("moon", {}).duplicate(true)
	moon["azimuth"] = 250.0
	moon["altitude"] = 45.0
	moon["visible"] = true
	moon["below_horizon"] = false
	moon["source"] = "calculated"
	sky["moon"] = moon
	sky_view.set("sky_data", sky)
	gm.publish_sky_positions(sky)
	sky_view.call("_rebuild_view")
	await process_frame
	_check(str(sky_view.get("selected_object_id")) == "moon", "L1 defaults to the mission Moon")
	_check((sky_view.get("sky_data") as Dictionary).has("moon"), "L1 sky_data contains Moon")
	var edge: Control = sky_view.get("edge_target_indicator")
	_check(edge != null and edge.visible, "off-screen Moon shows edge indicator")
	_check(str((sky_view.get("edge_target_name") as Label).text).contains("Moon"), "edge indicator names the Moon")
	_check(str((sky_view.get("edge_target_delta") as Label).text).contains("\n"), "edge indicator shows separate A/D and W/S instructions")
	_check(edge.position.x >= 10.0 and edge.position.y >= 10.0 and edge.position.x + edge.size.x <= 620.0 and edge.position.y + edge.size.y <= 442.0, "edge indicator stays fully inside the safe observation area")
	var trail: Control = sky_view.get("edge_navigation_trail")
	_check(trail != null and trail.visible, "off-screen target shows a directional trail from the optical center")

	sky_view.set("telescope_azimuth", 250.0)
	sky_view.set("telescope_altitude", 45.0)
	sky_view.call("_rebuild_view")
	await create_timer(0.25).timeout
	_check((sky_view.get("in_view_targets") as Dictionary).has("moon"), "turning the view brings Moon into the FOV")
	_check(str(sky_view.get("target_lock_state")) == "locked", "centered Moon enters gold lock state")

	# L12 is the existing Moon lesson where Finder and Telescope are legal.
	gm.debug_jump_to_level(12, true)
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	var az_before := float(((sky_view.get("sky_data") as Dictionary)["moon"] as Dictionary)["azimuth"])
	var alt_before := float(((sky_view.get("sky_data") as Dictionary)["moon"] as Dictionary)["altitude"])
	for mode in ["naked_eye", "finder", "telescope"]:
		if bool(sky_view.call("_mode_available", mode).get("ok", false)):
			sky_view.call("_set_view_mode", mode)
			sky_view.call("_rebuild_view")
			_check((sky_view.get("sky_data") as Dictionary).has("moon"), "Moon remains after switching to %s" % mode)
			_check(is_equal_approx(float(((sky_view.get("sky_data") as Dictionary)["moon"] as Dictionary)["azimuth"]), az_before), "mode %s does not change Moon azimuth" % mode)
			_check(is_equal_approx(float(((sky_view.get("sky_data") as Dictionary)["moon"] as Dictionary)["altitude"]), alt_before), "mode %s does not change Moon altitude" % mode)
	sky_view.queue_free()
	await process_frame


func _test_free_observation_separation() -> void:
	gm.new_game()
	gm.progress["current_level"] = 5
	gm.selected_object_id = "moon"
	_check(gm.current_target_object_id() != "moon" and gm.is_free_observation(), "non-mission Moon selection enters free observation")
	var before_level := int(gm.progress.get("current_level", 0))
	var before_completed := (gm.progress.get("completed_levels", []) as Array).duplicate()
	gm.record_free_observation("moon", {"quality": "Good", "observation_mode": "free"})
	_check(int(gm.progress.get("current_level", 0)) == before_level, "free observation does not advance current level")
	_check((gm.progress.get("completed_levels", []) as Array) == before_completed, "free observation does not complete a mission")


func _test_below_horizon_route() -> void:
	gm.new_game()
	gm.progress["current_level"] = 1
	gm.publish_sky_positions({"moon": {"altitude": -4.0, "azimuth": 80.0, "visible": false, "below_horizon": true, "source": "calculated"}})
	_check(gm.target_requires_relocation(), "below-horizon Moon requests the world map")


func _api_payload(altitude: Variant, azimuth: Variant) -> Dictionary:
	var altitude_dict := {} if altitude == null else {"degrees": altitude}
	return {"data": {"table": {"rows": [{
		"body": {"id": "moon", "name": "Moon"},
		"positions": [{"position": {"horizontal": {
			"altitude": altitude_dict,
			"azimuth": {"degrees": azimuth}
		}}}]
	}]}}}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
