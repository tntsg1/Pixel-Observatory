extends SceneTree

const MISSION_LEVELS := [7, 8, 18, 19]
const SUPPORTED_NEBULAE := ["orion_nebula", "ring_nebula", "lagoon_nebula", "dumbbell_nebula"]

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	for level_number in MISSION_LEVELS:
		gm.new_game()
		gm.debug_jump_to_level(level_number, true)
		var mission_target := str(gm.current_level().get("target_object_id", ""))
		_check(mission_target in SUPPORTED_NEBULAE, "L%d uses one of the supported nebula targets" % level_number)
		gm.selected_object_id = mission_target
		var mission_view := await _make_view()
		_check(mission_view.get("technique_filter_button") != null, "L%d exposes the nebula filter control" % level_number)
		mission_view.queue_free()
		await process_frame

	gm.new_game()
	gm.debug_jump_to_level(22, true)
	for object_id in SUPPORTED_NEBULAE:
		gm.selected_object_id = object_id
		var free_view := await _make_view()
		_check(free_view.call("_is_emission_nebula_target"), "%s remains filter-eligible in free observation" % object_id)
		_check(free_view.get("technique_filter_button") != null, "%s exposes its optional nebula filter in free observation" % object_id)
		free_view.queue_free()
		await process_frame
	gm.selected_object_id = "andromeda"
	var galaxy_view := await _make_view()
	_check(galaxy_view.get("technique_filter_button") == null, "a galaxy never receives the nebula-only filter control")
	galaxy_view.queue_free()
	await process_frame
	_finish()


func _make_view() -> Control:
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame
	return view


func _finish() -> void:
	print("NEBULA FILTER AVAILABILITY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  FAIL: " + label)
