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
			_verify_single_advance()
			if failures == 0:
				print("STORY DIALOGUE INPUT TEST PASS")
				quit(0)
			else:
				print("STORY DIALOGUE INPUT TEST FAIL (%d)" % failures)
				quit(1)


func _verify_single_advance() -> void:
	var next_button := story.get_node_or_null("StoryContinueButton") as Button
	_check(next_button != null, "continue button exists")
	if next_button == null:
		return
	_check(next_button.focus_mode == Control.FOCUS_NONE, "global keyboard shortcut cannot also activate the button")

	var button_press := InputEventMouseButton.new()
	button_press.button_index = MOUSE_BUTTON_LEFT
	button_press.pressed = true
	button_press.position = next_button.get_global_rect().get_center()
	story.call("_input", button_press)
	_check(int(story.get("line_index")) == 0, "button press is not also treated as a background click")

	next_button.pressed.emit()
	_check(int(story.get("line_index")) == 1, "button click advances exactly one line")

	var background_press := InputEventMouseButton.new()
	background_press.button_index = MOUSE_BUTTON_LEFT
	background_press.pressed = true
	background_press.position = Vector2(20, 20)
	story.call("_input", background_press)
	_check(int(story.get("line_index")) == 2, "background click advances exactly one line")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
