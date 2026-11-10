extends SceneTree

const StoryVisualResolver = preload("res://scripts/ui/story_visual_resolver.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	var sm := root.get_node_or_null("/root/StoryManager")
	var mm := root.get_node_or_null("/root/MissionManager")
	if gm == null or sm == null or mm == null:
		print("STORY VISUAL SEMANTICS TEST FAIL (autoloads missing)")
		quit(1)
		return
	gm.new_game()

	var explicit := StoryVisualResolver.resolve(
		"level_3_before_assembly",
		{"image": "res://assets/learning_diagrams/refractor_light_path.png", "text_en": "Light path", "text_zh": "光路"},
		{"phase": "before", "to_id": "assembly_table"},
		{"id": "moon", "name_en": "Moon", "name_zh": "月球"},
		"refractor",
		1
	)
	_check(str(explicit.get("path", "")) == "res://assets/learning_diagrams/refractor_light_path.png", "explicit authored image wins")

	var assembly := StoryVisualResolver.resolve(
		"level_26_before_assembly",
		{"text_en": "Build the reflector", "text_zh": "组装反射镜"},
		{"phase": "before", "to_id": "assembly_table"},
		{"id": "vega", "name_en": "Vega", "name_zh": "织女星"},
		"newtonian",
		2
	)
	_check(str(assembly.get("role", "")) == "assembly", "assembly dialogue resolves to a blueprint, not Vega")
	_check(not str(assembly.get("path", "")).contains("star_"), "assembly dialogue never falls back to the current target")

	var focus := StoryVisualResolver.resolve(
		"level_12_before_focus",
		{"text_en": "Adjust focus", "text_zh": "调整焦点"},
		{"phase": "before", "to_id": "observation_pad"},
		{"id": "jupiter", "name_en": "Jupiter", "name_zh": "木星"},
		"refractor",
		0
	)
	_check(str(focus.get("role", "")) == "focus", "focus dialogue resolves to the focal-plane diagram")

	var target := StoryVisualResolver.resolve(
		"level_30_before",
		{"visual_role": "target", "text_en": "Find the Crab Nebula", "text_zh": "寻找蟹状星云"},
		{"phase": "before", "to_id": "observation_pad"},
		{
			"id": "crab_nebula",
			"name_en": "Crab Nebula",
			"name_zh": "蟹状星云 M1",
			"sky_icon_source_path": "res://assets/telescope_view/official/crab_nebula.png"
		},
		"newtonian",
		0
	)
	_check(str(target.get("role", "")) == "target", "target-science line resolves to target evidence")
	_check(str(target.get("path", "")) == "res://assets/telescope_view/official/crab_nebula.png", "target resolver prefers the authored observation image")

	var workflow := StoryVisualResolver.resolve(
		"intro",
		{"visual_role": "workflow", "text_en": "Board, parts, assembly, observation, logbook", "text_zh": "任务板、零件、组装、观测、日志"},
		{"phase": "intro", "to_id": "observation_pad"},
		{"id": "moon", "name_en": "Moon", "name_zh": "月球"},
		"refractor",
		2
	)
	_check(str(workflow.get("role", "")) == "workflow", "workflow line keeps a workflow visual role")
	_check(not str(workflow.get("path", "")).contains("moon"), "workflow line never displays the Moon by default")

	var transition_expectations := {
		"level_2_after": {"line": 1, "role": "assembly", "path": "refractor_light_path.png"},
		"level_25_after": {"line": 1, "role": "assembly", "path": "newtonian_main_blueprint.png"},
		"level_35_after": {"line": 1, "role": "assembly", "path": "dobsonian_main_blueprint.png"},
		"level_45_after": {"line": 1, "role": "assembly", "path": "cassegrain_main_blueprint_cropped.png"},
		"level_55_after": {"line": 1, "role": "space_console", "path": "jwst_instruments_diagram.png"},
		"level_75_after": {"line": 1, "role": "radio_console", "path": "pulsar_timing_console.png"}
	}
	for event_value in transition_expectations:
		var event_id := str(event_value)
		var expected: Dictionary = transition_expectations[event_id]
		var transition_lines: Array = sm.get_dialogue(event_id)
		var transition_line_index := int(expected["line"])
		var transition_context: Dictionary = sm.context_for_event(event_id)
		var transition_level: Dictionary = mm.get_level(int(transition_context.get("level_number", 1)))
		var transition_target: Dictionary = gm.get_object(str(transition_level.get("target_object_id", "moon")))
		var transition := StoryVisualResolver.resolve(
			event_id,
			transition_lines[transition_line_index],
			transition_context,
			transition_target,
			str(transition_level.get("telescope_family", "refractor")),
			transition_line_index
		)
		_check(str(transition.get("role", "")) == str(expected["role"]), "%s points at the next instrument" % event_id)
		_check(str(transition.get("path", "")).ends_with(str(expected["path"])), "%s uses the matching authored visual" % event_id)
	var route_expectations := {
		"level_2_after": ["observation_pad", "assembly_table"],
		"level_25_after": ["observation_pad", "assembly_table"],
		"level_35_after": ["observation_pad", "assembly_table"],
		"level_45_after": ["observation_pad", "assembly_table"],
		"level_55_after": ["observation_pad", "space_console"],
		"level_75_after": ["space_console", "radio_console"]
	}
	for event_value in route_expectations:
		var event_id := str(event_value)
		var expected_route: Array = route_expectations[event_id]
		var handoff: Dictionary = sm.context_for_event(event_id)
		_check(str(handoff.get("from_id", "")) == str(expected_route[0]), "%s starts at the correct instrument" % event_id)
		_check(str(handoff.get("to_id", "")) == str(expected_route[1]), "%s route matches its visual and dialogue" % event_id)
	_check(str(sm.context_for_event("level_75_after").get("to_en", "")) == "FAST Control Console", "radio handoff shows the authored FAST destination")

	var checked_lines := 0
	for event_value in sm.dialogues.keys():
		var event_id := str(event_value)
		var lines_value: Variant = sm.dialogues.get(event_id, [])
		if not lines_value is Array:
			continue
		var context: Dictionary = sm.context_for_event(event_id)
		var level_number := int(context.get("level_number", 1))
		var level: Dictionary = mm.get_level(level_number)
		var family := str(level.get("telescope_family", "refractor"))
		var target_id := str(level.get("target_object_id", "moon"))
		var target_data: Dictionary = gm.get_object(target_id)
		if target_data.is_empty():
			target_data = {"id": target_id, "name_en": target_id.capitalize(), "name_zh": target_id}
		var lines: Array = lines_value
		for line_index in range(lines.size()):
			if not lines[line_index] is Dictionary:
				continue
			var resolved := StoryVisualResolver.resolve(event_id, lines[line_index], context, target_data, family, line_index)
			var path := str(resolved.get("path", ""))
			_check(path != "", "%s line %d resolves a visual" % [event_id, line_index + 1])
			_check(path == "" or ResourceLoader.exists(path), "%s line %d visual exists" % [event_id, line_index + 1])
			_check(str(resolved.get("title_en", "")).strip_edges() != "", "%s line %d has an English visual title" % [event_id, line_index + 1])
			_check(str(resolved.get("title_zh", "")).strip_edges() != "", "%s line %d has a Chinese visual title" % [event_id, line_index + 1])
			_check(str(resolved.get("caption_en", "")).strip_edges() != "", "%s line %d has an English visual caption" % [event_id, line_index + 1])
			_check(str(resolved.get("caption_zh", "")).strip_edges() != "", "%s line %d has a Chinese visual caption" % [event_id, line_index + 1])
			checked_lines += 1

	_check(checked_lines >= 300, "the merged campaign dialogue catalogue is fully audited")
	if failures == 0:
		print("STORY VISUAL SEMANTICS TEST PASS (%d lines)" % checked_lines)
		quit(0)
	else:
		print("STORY VISUAL SEMANTICS TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
