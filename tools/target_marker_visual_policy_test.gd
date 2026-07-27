extends SceneTree

const TEST_TIMEOUT_SECONDS := 35.0
const TARGET_LEVELS := {
	"crab_nebula": 30,
	"ring_nebula": 35,
	"dumbbell_nebula": 33,
	"sombrero_galaxy": 31,
	"moon": 1,
	"jupiter": 4,
	"pleiades": 36,
}
const MODE_MAXIMUM := {
	"naked_eye": 42.0,
	"finder": 64.0,
	"telescope": 88.0,
}
const AIM := Vector2(180.0, 45.0)

var failures := 0
var finished := false
var gm: Node


func _initialize() -> void:
	_start_watchdog()
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	for target_id_value in TARGET_LEVELS.keys():
		var target_id := str(target_id_value)
		var view := await _spawn_view(target_id, int(TARGET_LEVELS[target_id]))
		for mode_value in MODE_MAXIMUM.keys():
			await _verify_mode(view, target_id, str(mode_value))
		view.queue_free()
		await process_frame
	print("TARGET MARKER VISUAL POLICY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	_finish(0 if failures == 0 else 1)


func _spawn_view(target_id: String, level_number: int) -> Control:
	gm.new_game()
	gm.debug_jump_to_level(level_number, false)
	gm.selected_object_id = target_id
	gm.selected_object_level = level_number
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": AIM.x,
		"altitude": AIM.y,
		"view_mode": "naked_eye",
	}
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	view.set("target_id", target_id)
	view.set("selected_object_id", target_id)
	return view


func _verify_mode(view: Control, target_id: String, mode: String) -> void:
	view.set("view_mode", mode)
	view.call("_apply_view_mode")
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get(target_id, {}).duplicate(true)
	item["azimuth"] = AIM.x
	item["altitude"] = AIM.y
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "marker_policy_fixture"
	sky[target_id] = item
	view.set("sky_data", sky)
	view.set("telescope_azimuth", AIM.x)
	view.set("telescope_altitude", AIM.y)
	view.call("_rebuild_view")
	await process_frame
	await process_frame

	var waypoint := view.get("faint_mission_target_waypoint") as Control
	var ring := view.get("target_state_ring") as Control
	var waypoint_visible := waypoint != null and waypoint.visible
	var ring_visible := ring != null and is_instance_valid(ring) and ring.visible
	_check(int(waypoint_visible) + int(ring_visible) == 1, "%s %s has exactly one moving target marker" % [target_id, mode])
	var marker := waypoint if waypoint_visible else ring
	_check(marker != null, "%s %s exposes an asset-backed marker" % [target_id, mode])
	if marker != null:
		_check(marker is TextureRect and (marker as TextureRect).texture != null, "%s %s marker uses a texture asset" % [target_id, mode])
		_check(maxf(marker.size.x, marker.size.y) <= float(MODE_MAXIMUM[mode]) + 0.1, "%s %s marker remains inside the visual size limit" % [target_id, mode])

	var centered_before := bool(view.call("_is_target_centered", target_id))
	if view.get("in_view_targets") is Dictionary and (view.get("in_view_targets") as Dictionary).has(target_id):
		var targets: Dictionary = view.get("in_view_targets")
		var info: Dictionary = targets[target_id]
		info["marker_diameter"] = 400.0
		targets[target_id] = info
		view.set("in_view_targets", targets)
	var centered_after := bool(view.call("_is_target_centered", target_id))
	_check(centered_before == centered_after, "%s %s visual marker size does not change angular lock" % [target_id, mode])


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not finished:
			push_error("TARGET MARKER VISUAL POLICY TEST TIMEOUT")
			_finish(1)
	)


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	quit(exit_code)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
