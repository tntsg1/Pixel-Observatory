extends SceneTree

var failures := 0
var frames := 0
var case_index := -1
var cases: Array = []
var story: Control


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm := root.get_node_or_null("/root/GameManager")
	var sm := root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		quit(1)
		return
	if frames == 2:
		gm.new_game()
		_build_cases(sm)
		_show_next_case(gm, sm)
		story = load("res://scenes/story_dialogue.tscn").instantiate()
		root.add_child(story)
		current_scene = story
		return
	if frames < 4:
		return
	_verify_current_case()
	if failures > 0:
		print("STORY DIALOGUE CATALOG LAYOUT TEST FAIL (%d)" % failures)
		quit(1)
		return
	if case_index >= cases.size() - 1:
		print("STORY DIALOGUE CATALOG LAYOUT TEST PASS (%d bilingual cases)" % cases.size())
		quit(0)
		return
	_show_next_case(gm, sm)


func _build_cases(sm: Node) -> void:
	var event_ids: Array = sm.dialogues.keys()
	event_ids.sort()
	for event_value in event_ids:
		var event_id := str(event_value)
		var lines_value: Variant = sm.dialogues.get(event_id, [])
		if not lines_value is Array:
			continue
		var lines: Array = lines_value
		for line_index in range(lines.size()):
			if not lines[line_index] is Dictionary:
				continue
			for language in ["en", "zh"]:
				cases.append({
					"event_id": event_id,
					"line_index": line_index,
					"language": language
				})


func _show_next_case(gm: Node, sm: Node) -> void:
	case_index += 1
	var test_case: Dictionary = cases[case_index]
	var event_id := str(test_case["event_id"])
	gm.language_mode = str(test_case["language"])
	sm.active_event_id = event_id
	sm.active_event_ids = [event_id]
	sm.active_lines = sm.get_dialogue(event_id)
	sm.active_context = sm.context_for_event(event_id)
	if story != null:
		story.set("line_index", int(test_case["line_index"]))
		story.call("_show_line")


func _verify_current_case() -> void:
	var test_case: Dictionary = cases[case_index]
	var identity := "%s line %d %s" % [
		str(test_case["event_id"]),
		int(test_case["line_index"]) + 1,
		str(test_case["language"])
	]
	for property_name in [
		"visual_title_label",
		"visual_caption_label",
		"chapter_label",
		"reason_label",
		"route_label",
		"text_label",
		"context_line_label"
	]:
		var label := story.get(property_name) as Label
		_check(label != null and _label_content_fits(label), "%s fits %s" % [identity, property_name])
	var speaker := story.get("speaker_label") as Label
	var beat := story.get("beat_label") as Label
	var counter := story.get("counter_label") as Label
	var button := story.get("next_button") as Button
	_check(speaker != null and _single_line_fits(speaker), identity + " fits speaker")
	_check(beat != null and _single_line_fits(beat), identity + " fits beat")
	_check(counter != null and _single_line_fits(counter), identity + " fits counter")
	_check(button != null and _button_text_fits(button), identity + " fits continue button")


func _label_content_fits(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return float(label.get_line_count() * font.get_height(font_size)) <= label.size.y + 1.0


func _single_line_fits(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= label.size.x + 1.0


func _button_text_fits(button: Button) -> bool:
	var font := button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	return font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= button.size.x - 16.0


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	print("  FAIL: " + label)
