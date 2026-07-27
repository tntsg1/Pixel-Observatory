extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is available")
		_finish()
		return
	gm.new_game()

	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	await process_frame
	scene.call("_finish_array_takeover")

	var source_choices := [
		["stable_pulsar", "positive", "positive evidence"],
		["residual_rfi", "rfi", "rfi evidence"],
		["insufficient_signal", "weak", "weak evidence"],
	]
	var observed_orders: Array[String] = []
	for level_number in [84, 85]:
		gm.debug_jump_to_level(level_number, true)
		var first := scene.call("_ordered_report_choices", source_choices) as Array
		var second := scene.call("_ordered_report_choices", source_choices) as Array
		var first_ids := _choice_ids(first)
		var second_ids := _choice_ids(second)
		_check(first_ids == second_ids,
			"level %d keeps a stable order when the report is rebuilt" % level_number)
		_check(first_ids[0] != "stable_pulsar",
			"level %d does not place the successful conclusion first" % level_number)
		_check(_same_choice_set(first_ids),
			"level %d preserves every conclusion ID exactly once" % level_number)
		observed_orders.append("|".join(first_ids))

	_check(observed_orders[0] != observed_orders[1],
		"adjacent FAST levels rotate the evidence choices")

	scene.queue_free()
	await process_frame
	_finish()


func _choice_ids(choices: Array) -> Array[String]:
	var ids: Array[String] = []
	for choice in choices:
		ids.append(str(choice[0]))
	return ids


func _same_choice_set(ids: Array[String]) -> bool:
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	return sorted_ids == ["insufficient_signal", "residual_rfi", "stable_pulsar"]


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST REPORT CHOICE ORDER TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
