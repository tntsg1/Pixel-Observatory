extends SceneTree

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
		4:
			gm.language_mode = "en"
			sm.active_event_id = "intro"
			sm.active_event_ids = ["intro"]
			sm.active_lines = sm.get_dialogue("intro")
			sm.active_context = sm.context_for_event("intro")
			story = load("res://scenes/story_dialogue.tscn").instantiate()
			root.add_child(story)
			current_scene = story
		28:
			story.set("line_index", 1)
			story.call("_show_line")
		46:
			root.get_texture().get_image().save_png("res://artifacts/maya_dialogue_layout.png")
			print("MAYA_DIALOGUE_CAPTURED")
			quit(0)
