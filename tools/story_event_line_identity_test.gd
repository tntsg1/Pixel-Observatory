extends SceneTree

var failures := 0
var frames := 0


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames < 2:
		return
	var gm := root.get_node_or_null("/root/GameManager")
	var sm := root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		quit(1)
		return
	gm.new_game()
	gm.progress["seen_story_events"] = []
	var event_ids := ["intro", "first_collimation"]
	var expected_count := 0
	for event_id in event_ids:
		expected_count += sm.get_dialogue(event_id).size()
	var started: bool = sm.call("_begin_events", event_ids, "observatory")
	_check(started, "combined story starts")
	_check(sm.active_lines.size() == expected_count, "combined story keeps every authored line")
	var counts := {}
	for line_value in sm.active_lines:
		var line: Dictionary = line_value
		var event_id := str(line.get("_story_event_id", ""))
		var event_line_index := int(line.get("_story_line_index", -1))
		counts[event_id] = int(counts.get(event_id, 0)) + 1
		_check(event_id in event_ids, "line carries its source event")
		_check(event_line_index >= 0, "line carries its source index")
	for event_id in event_ids:
		_check(int(counts.get(event_id, 0)) == sm.get_dialogue(event_id).size(), "%s line identity is complete" % event_id)
	if failures == 0:
		print("STORY EVENT LINE IDENTITY TEST PASS")
		quit(0)
	else:
		print("STORY EVENT LINE IDENTITY TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
