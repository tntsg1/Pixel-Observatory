extends SceneTree

var failures := 0
var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		quit(1)
		return

	gm.new_game()
	gm.debug_jump_to_level(31, false)
	gm.selected_object_id = ""
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": 124.0,
		"altitude": 10.0,
		"view_mode": "naked_eye"
	}

	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame

	var sky: Dictionary = view.get("sky_data")
	var sombrero: Dictionary = sky.get("sombrero_galaxy", {}).duplicate(true)
	sombrero["azimuth"] = 109.0
	sombrero["altitude"] = 7.5
	sombrero["visible"] = true
	sombrero["below_horizon"] = false
	sombrero["source"] = "calculated"
	sky["sombrero_galaxy"] = sombrero
	view.set("sky_data", sky)
	view.set("telescope_azimuth", 124.0)
	view.set("telescope_altitude", 10.0)
	gm.publish_sky_positions(sky)
	view.call("_rebuild_view")
	await process_frame
	await create_timer(0.3).timeout

	var visual: Dictionary = view.call("_object_visual_for_mode", gm.get_object("sombrero_galaxy"))
	_check(not bool(visual.get("shown", true)), "Sombrero remains invisible to the naked eye")

	var targets: Dictionary = view.get("in_view_targets")
	_check(targets.has("sombrero_galaxy"), "faint mission target keeps an in-view coordinate waypoint")
	var target_info: Dictionary = targets.get("sombrero_galaxy", {})
	_check(not bool(target_info.get("object_visible", true)), "waypoint does not reveal the faint galaxy texture")

	var icons: Dictionary = view.get("object_icons")
	var icon := icons.get("sombrero_galaxy") as TextureRect
	_check(icon != null and not icon.visible, "faint galaxy sprite stays hidden")
	var buttons: Dictionary = view.get("object_buttons")
	var hit_target := buttons.get("sombrero_galaxy") as Button
	_check(hit_target != null and hit_target.visible, "catalog waypoint remains selectable")

	var ring := view.get("target_state_ring") as TextureRect
	_check(ring != null and ring.visible and ring.modulate.a > 0.0, "mission waypoint ring is visible at the catalog position")
	if ring != null and targets.has("sombrero_galaxy"):
		var target_rect: Rect2 = target_info.get("rect", Rect2())
		var expected_center: Vector2 = target_rect.get_center()
		var actual_center := ring.position + ring.size * 0.5
		_check(actual_center.distance_to(expected_center) < 1.0, "waypoint ring is centered on the real projected coordinates")

	var edge := view.get("edge_target_indicator") as Control
	_check(edge != null and (not edge.visible or edge.modulate.a <= 0.01), "edge direction card withdraws once the target enters the field")

	view.queue_free()
	await process_frame
	print("FAINT MISSION TARGET MARKER %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
