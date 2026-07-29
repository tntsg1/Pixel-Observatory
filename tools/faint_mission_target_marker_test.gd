extends SceneTree

const TARGET_LEVELS := {
	"andromeda": 9,
	"orion_nebula": 18,
	"crab_nebula": 30,
	"sombrero_galaxy": 31,
	"dumbbell_nebula": 33,
	"ring_nebula": 35
}
const AIM := Vector2(180.0, 45.0)
const IN_VIEW_POSITION := Vector2(198.0, 51.0)
const OUT_OF_VIEW_POSITION := Vector2(292.0, 51.0)
const EXPECTED_WAYPOINT_DIAMETER := 42.0

var failures := 0
var gm: Node
var feedback_events: Array[String] = []


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		quit(1)
		return
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		feedback.feedback_sfx_requested.connect(func(event_name: String) -> void:
			feedback_events.append(event_name)
		)

	for target_id_value in TARGET_LEVELS.keys():
		var target_id := str(target_id_value)
		var view := await _spawn_view(target_id)
		await _verify_in_view_waypoint(view, target_id)
		await _verify_centered_lock(view, target_id)
		await _verify_out_of_view_card(view, target_id)
		await _verify_stale_tween_cannot_hide_new_card(view, target_id)
		view.queue_free()
		await process_frame

	print("FAINT MISSION TARGET MARKER %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _spawn_view(target_id: String) -> Control:
	gm.new_game()
	gm.debug_jump_to_level(int(TARGET_LEVELS[target_id]), false)
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
	await process_frame
	await process_frame
	view.set("target_id", target_id)
	view.set("selected_object_id", target_id)
	_set_target_fixture(view, target_id, IN_VIEW_POSITION)
	await _settle()
	return view


func _verify_in_view_waypoint(view: Control, target_id: String) -> void:
	var targets: Dictionary = view.get("in_view_targets")
	_check(targets.has(target_id), "%s keeps a real projected in-view target entry" % target_id)
	var target_info: Dictionary = targets.get(target_id, {})
	_check(bool(target_info.get("faint_waypoint", false)), "%s is represented by the faint waypoint state" % target_id)
	_check(not bool(target_info.get("object_visible", true)), "%s does not reveal its sprite in the sky finder" % target_id)

	var icons: Dictionary = view.get("object_icons")
	var icon := icons.get(target_id) as TextureRect
	_check(icon != null and not icon.visible, "%s sprite stays hidden" % target_id)

	var buttons: Dictionary = view.get("object_buttons")
	var hit_target := buttons.get(target_id) as Button
	_check(hit_target != null and hit_target.visible, "%s waypoint remains selectable" % target_id)

	var waypoint := view.get("faint_mission_target_waypoint") as Control
	_check(waypoint != null and waypoint.visible, "%s formal asset waypoint is visible" % target_id)
	_check(str(view.get("faint_mission_target_waypoint_id")) == target_id, "%s owns the active waypoint state" % target_id)
	if waypoint != null:
		_check(waypoint is TextureRect, "%s faint waypoint uses the shared asset-backed ring control" % target_id)
		var waypoint_texture := (waypoint as TextureRect).texture if waypoint is TextureRect else null
		_check(waypoint_texture != null and waypoint_texture.resource_path.ends_with("target_approach_ring.png"), "%s in-view waypoint uses the formal cyan approach ring before centering" % target_id)
		_check((waypoint as TextureRect).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "%s downsamples the formal approach ring without reducing it to a geometric fallback" % target_id)
		_check(str(waypoint.get_meta("marker_state", "")) == "approach", "%s cannot inherit a stale locked appearance while still off center" % target_id)
		_check(waypoint.size.distance_to(Vector2.ONE * EXPECTED_WAYPOINT_DIAMETER) < 0.1, "%s waypoint keeps the authored arrowheads readable at naked-eye size" % target_id)
		var expected_center: Vector2 = (target_info.get("rect", Rect2()) as Rect2).get_center()
		var actual_center := waypoint.position + waypoint.size * 0.5
		_check(actual_center.distance_to(expected_center) < 0.5, "%s waypoint is centered on the real projection" % target_id)

	var normal_ring := view.get("target_state_ring") as Control
	_check(normal_ring == null or not is_instance_valid(normal_ring) or not normal_ring.visible, "%s does not stack the normal target ring over the waypoint" % target_id)
	var edge := view.get("edge_target_indicator") as Control
	_check(edge != null and (not edge.visible or edge.modulate.a <= 0.01), "%s retracts the edge direction card inside the FOV" % target_id)
	_check(str(view.get("edge_target_state")) == "hidden", "%s edge-card state settles to hidden" % target_id)


func _verify_centered_lock(view: Control, target_id: String) -> void:
	var lock_events_before := feedback_events.count("finder_lock")
	_set_target_fixture(view, target_id, AIM)
	await _settle()
	var targets: Dictionary = view.get("in_view_targets")
	var target_info: Dictionary = targets.get(target_id, {})
	_check(targets.has(target_id), "%s remains projected after centering" % target_id)
	_check(not bool(target_info.get("object_visible", true)), "%s remains scientifically hidden when centered in naked-eye mode" % target_id)

	var waypoint := view.get("faint_mission_target_waypoint") as TextureRect
	_check(waypoint != null and waypoint.visible, "%s keeps the shared waypoint visible at lock" % target_id)
	if waypoint != null:
		var waypoint_texture := waypoint.texture
		_check(waypoint_texture != null and waypoint_texture.resource_path.ends_with("target_lock_ring.png"), "%s switches to the formal brass lock ring only after centering" % target_id)
		_check(waypoint.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "%s preserves the authored lock-ring detail at naked-eye scale" % target_id)
		_check(str(waypoint.get_meta("marker_state", "")) == "locked", "%s exposes the locked state only after the angular threshold is met" % target_id)
		_check(waypoint.size.distance_to(Vector2.ONE * EXPECTED_WAYPOINT_DIAMETER) < 0.1, "%s lock ring keeps the authored brass nodes readable at naked-eye size" % target_id)
	_check(str(view.get("target_lock_state")) == "locked", "%s enters the real locked state at the angular center" % target_id)
	_check(feedback_events.count("finder_lock") == lock_events_before + 1, "%s emits one finder-lock confirmation when entering tolerance" % target_id)
	view.call("_update_marker_frames")
	await process_frame
	_check(feedback_events.count("finder_lock") == lock_events_before + 1, "%s does not repeat the lock sound while remaining centered" % target_id)

	var icons: Dictionary = view.get("object_icons")
	var icon := icons.get(target_id) as TextureRect
	_check(icon != null and not icon.visible, "%s locked waypoint does not reveal the hidden object sprite" % target_id)


func _verify_out_of_view_card(view: Control, target_id: String) -> void:
	_set_target_fixture(view, target_id, OUT_OF_VIEW_POSITION)
	await _settle()
	var targets: Dictionary = view.get("in_view_targets")
	_check(not targets.has(target_id), "%s leaves the in-view registry outside the FOV" % target_id)
	var waypoint := view.get("faint_mission_target_waypoint") as Control
	_check(waypoint != null and not waypoint.visible, "%s hides the waypoint outside the FOV" % target_id)
	var edge := view.get("edge_target_indicator") as Control
	_check(edge != null and edge.visible and edge.modulate.a > 0.95, "%s shows the edge direction card outside the FOV" % target_id)
	_check(str(view.get("edge_target_object_id")) == target_id, "%s edge card is bound to the correct target ID" % target_id)
	_check(str(view.get("edge_target_state")) == "visible", "%s edge-card state is visible outside the FOV" % target_id)


func _verify_stale_tween_cannot_hide_new_card(view: Control, target_id: String) -> void:
	_set_target_fixture(view, target_id, IN_VIEW_POSITION)
	await process_frame
	_set_target_fixture(view, target_id, OUT_OF_VIEW_POSITION)
	await create_timer(0.30).timeout
	var edge := view.get("edge_target_indicator") as Control
	_check(edge != null and edge.visible and edge.modulate.a > 0.95, "%s stale retract tween cannot hide a new out-of-view card" % target_id)
	_check(str(view.get("edge_target_object_id")) == target_id and str(view.get("edge_target_state")) == "visible", "%s keeps coherent edge ID and state after a rapid transition" % target_id)


func _set_target_fixture(view: Control, target_id: String, position: Vector2) -> void:
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get(target_id, {}).duplicate(true)
	item["azimuth"] = position.x
	item["altitude"] = position.y
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "test_fixture"
	sky[target_id] = item
	view.set("sky_data", sky)
	view.set("telescope_azimuth", AIM.x)
	view.set("telescope_altitude", AIM.y)
	gm.publish_sky_positions(sky)
	view.call("_rebuild_view")


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.26).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
