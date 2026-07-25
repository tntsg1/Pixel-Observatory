extends SceneTree

# Selected-object horizon routing: the explanation belongs to Sky Observation,
# while the map follows the exact mission/free target that opened it.

var failures := 0
var save_path := ""
var saved_bytes := PackedByteArray()
var had_save := false


func _initialize() -> void:
	await process_frame
	_snapshot_save()
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	# Site relocation is introduced only after the ten local foundation lessons.
	gm.debug_jump_to_level(11, false)
	gm.suppress_next_world_map_redirect = true

	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _frame in range(4):
		await process_frame
	var mission_id := str(sky.get("target_id"))

	_set_altitude(sky, mission_id, 36.0)
	sky.call("_redirect_to_world_map_if_needed")
	_check(not bool(sky.get("horizon_explanation_active")), "1. an above-horizon target does not open the relocation explanation")

	_set_altitude(sky, mission_id, 9.0)
	sky.call("_redirect_to_world_map_if_needed")
	_check(not bool(sky.get("horizon_explanation_active")), "2. a low but risen target is not forcibly relocated")
	_check(bool(sky.get("low_altitude_notice_active")), "2. a target below 18 degrees shows the optional site-change state")
	var location_button := sky.get_node_or_null("ChangeSiteButton") as Button
	_check(location_button != null and location_button.text.contains("Change Site"), "2. the existing Location button carries the low-altitude choice")

	_set_altitude(sky, mission_id, -8.0)
	sky.call("_redirect_to_world_map_if_needed")
	_check(bool(sky.get("horizon_explanation_active")), "3. a below-horizon mission target starts the visual explanation")
	_check(sky.get_node_or_null("WorldMapArrivalFeedback") == null, "3. arrival feedback is not confused with departure")
	var explanation: Control = sky.get("horizon_explanation_layer")
	_check(explanation != null and explanation.get_node_or_null("BelowHorizonGhostTarget") != null, "3. explanation contains the occluded ghost target")
	_check(str(gm.world_map_target_id) == mission_id, "3. mission target context is handed to the map")
	_cancel_explanation(sky)

	var free_id := "jupiter" if mission_id != "jupiter" else "mars"
	sky.set("selected_object_id", free_id)
	gm.selected_object_id = free_id
	_set_altitude(sky, free_id, -5.0)
	sky.call("_redirect_to_world_map_if_needed")
	_check(bool(sky.get("horizon_explanation_active")), "4. a below-horizon free target uses the same explanation flow")
	_check(str(gm.world_map_target_id) == free_id, "4. free target is not replaced by the mission target")
	_check(bool(gm.world_map_observation_context.get("free_observation", false)), "4. map context records FREE OBSERVATION")
	_cancel_explanation(sky)
	sky.queue_free()
	await process_frame

	gm.world_map_target_id = free_id
	gm.selected_object_id = free_id
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1"]
	var map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	_check(str(map.get("map_target_id")) == free_id, "5. World Map computes the selected free target")
	_check(not (map.get("radec") as Dictionary).is_empty(), "5. map resolves the selected object's real RA/Dec")
	var recommendation: Dictionary = map.get("recommended")
	_check(not recommendation.is_empty(), "5. map automatically recommends a legal observing station")
	if not recommendation.is_empty():
		_check(float(recommendation.get("altitude", -90.0)) >= 18.0, "5. recommendation prefers a target altitude of at least 18 degrees")
		_check(str(map.get("selected_id")) == str(recommendation.get("site", {}).get("id", "")), "5. recommended station is selected automatically")
	_check(str(gm.selected_object_id) == free_id and gm.is_free_observation(), "6. opening the map does not convert free observation into a mission")
	map.queue_free()
	await process_frame
	gm.suppress_next_world_map_redirect = true
	var returned_sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(returned_sky)
	for _frame in range(3):
		await process_frame
	_check(str(returned_sky.get("selected_object_id")) == free_id, "6. returning from the map restores the same free target")
	_check(bool(gm.is_free_observation()), "6. restored target remains FREE OBSERVATION")
	returned_sky.queue_free()

	_restore_save()
	if failures == 0:
		print("HORIZON AUTO SITE FLOW TEST PASS")
		quit(0)
	else:
		print("HORIZON AUTO SITE FLOW TEST FAIL (%d)" % failures)
		quit(1)


func _set_altitude(sky: Node, object_id: String, altitude: float) -> void:
	var data: Dictionary = sky.get("sky_data")
	var item: Dictionary = data.get(object_id, {"id": object_id, "azimuth": 120.0})
	item["altitude"] = altitude
	item["azimuth"] = float(item.get("azimuth", 120.0))
	item["below_horizon"] = altitude < 0.0
	item["visible"] = altitude >= 10.0
	item["source"] = "calculated"
	data[object_id] = item
	sky.set("sky_data", data)


func _cancel_explanation(sky: Node) -> void:
	var tween: Tween = sky.get("horizon_explanation_tween")
	if tween != null:
		tween.kill()
	var layer: Control = sky.get("horizon_explanation_layer")
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	sky.set("horizon_explanation_active", false)
	sky.set("horizon_explanation_layer", null)
	sky.set("location_transition_active", false)


func _snapshot_save() -> void:
	save_path = ProjectSettings.globalize_path("user://savegame.json")
	had_save = FileAccess.file_exists(save_path)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(save_path)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(save_path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
