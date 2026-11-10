extends SceneTree

var failures := 0
var frames := 0
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
	match frames:
		2:
			gm.new_game()
			gm.language_mode = "en"
			sm.active_event_id = "intro"
			sm.active_event_ids = ["intro"]
			sm.active_lines = sm.get_dialogue("intro")
			sm.active_context = sm.context_for_event("intro")
			story = load("res://scenes/story_dialogue.tscn").instantiate()
			root.add_child(story)
			current_scene = story
		8:
			story.set("line_index", 6)
			story.call("_show_line")
		14:
			_verify_layout("English")
			gm.language_mode = "zh"
			story.call("_on_language_changed")
		20:
			_verify_layout("Chinese")
			_show_event(sm, gm, "level_75_after", 1, "en")
		26:
			_verify_layout("English FAST transition")
			gm.language_mode = "zh"
			story.call("_on_language_changed")
		32:
			_verify_layout("Chinese FAST transition")
			if failures == 0:
				print("STORY DIALOGUE LAYOUT TEST PASS")
				quit(0)
			else:
				print("STORY DIALOGUE LAYOUT TEST FAIL (%d)" % failures)
				quit(1)


func _verify_layout(language_label: String) -> void:
	var visual_frame := story.get_node_or_null("StoryVisualFrame") as Control
	var visual_caption := story.get_node_or_null("StoryVisualCaption") as Label
	var chapter := story.get("chapter_label") as Label
	var reason := story.get("reason_label") as Label
	var route := story.get("route_label") as Label
	var dialogue_panel := story.get_node_or_null("StoryDialoguePanel") as Control
	var portrait := story.get_node_or_null("DialoguePortraitFrame") as Control
	var text_label := story.get_node_or_null("StoryDialogueText") as Label
	var context_line := story.get_node_or_null("StoryContextLine") as Label
	var next_button := story.get_node_or_null("StoryContinueButton") as Button
	_check(visual_frame != null, language_label + " visual frame exists")
	_check(visual_caption != null and visual_caption.text.strip_edges() != "", language_label + " visual caption is visible")
	_check(chapter != null and reason != null and route != null, language_label + " visual metadata exists")
	_check(dialogue_panel != null, language_label + " dialogue panel exists")
	_check(portrait != null, language_label + " portrait frame exists")
	_check(text_label != null, language_label + " dialogue text exists")
	_check(context_line != null, language_label + " context line exists")
	_check(next_button != null, language_label + " continue button exists")
	if visual_frame == null or dialogue_panel == null or portrait == null or text_label == null or context_line == null or next_button == null:
		return
	_check(visual_frame.position.y + visual_frame.size.y <= dialogue_panel.position.y, language_label + " visual stage does not overlap dialogue")
	_check(text_label.get_line_count() <= text_label.max_lines_visible, language_label + " longest dialogue line is not clipped")
	_check(text_label.position.x >= portrait.position.x + portrait.size.x, language_label + " dialogue never covers the portrait")
	_check(context_line.position.y + context_line.size.y <= next_button.position.y + next_button.size.y, language_label + " context remains inside the dialogue safe area")
	if chapter != null and reason != null and route != null:
		_check(_label_content_fits(chapter), language_label + " chapter label is not clipped")
		_check(_label_content_fits(reason), language_label + " reason label is not clipped")
		_check(_label_content_fits(route), language_label + " route label is not clipped")
		_check(chapter.position.y + chapter.size.y <= reason.position.y, language_label + " chapter does not overlap reason")
		_check(reason.position.y + reason.size.y <= route.position.y, language_label + " reason does not overlap route")
	for node in [visual_frame, dialogue_panel, portrait, text_label, context_line, next_button]:
		var control := node as Control
		var rect: Rect2 = control.get_global_rect()
		_check(rect.position.x >= 0.0 and rect.position.y >= 0.0, language_label + " %s starts inside the viewport" % control.name)
		_check(rect.end.x <= 1024.0 and rect.end.y <= 768.0, language_label + " %s ends inside the viewport" % control.name)


func _show_event(sm: Node, gm: Node, event_id: String, requested_line: int, language: String) -> void:
	gm.language_mode = language
	sm.active_event_id = event_id
	sm.active_event_ids = [event_id]
	sm.active_lines = sm.get_dialogue(event_id)
	sm.active_context = sm.context_for_event(event_id)
	story.set("line_index", requested_line)
	story.call("_show_line")


func _label_content_fits(label: Label) -> bool:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	return float(label.get_line_count() * font.get_height(font_size)) <= label.size.y + 1.0


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
