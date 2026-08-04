extends SceneTree

const OUTPUT_PATH := "res://artifacts/player_dialogue_portrait/01_player_portrait.png"

var story: Control
var settle_frames := 0


func _initialize() -> void:
	await process_frame
	var story_manager := root.get_node_or_null("/root/StoryManager")
	if story_manager == null:
		push_error("StoryManager is unavailable")
		quit(1)
		return
	var intro: Array = story_manager.call("get_dialogue", "intro")
	var player_line_index := -1
	for index in range(intro.size()):
		var line: Dictionary = intro[index]
		if str(line.get("portrait", "")).to_lower() in ["player", "you"]:
			player_line_index = index
			break
	if player_line_index < 0:
		push_error("Intro has no player portrait line")
		quit(1)
		return
	story_manager.set("active_event_id", "intro")
	story_manager.set("active_event_ids", ["intro"])
	story_manager.set("active_lines", intro)
	story_manager.set("active_context", story_manager.call("context_for_event", "intro"))
	story = load("res://scenes/story_dialogue.tscn").instantiate() as Control
	root.add_child(story)
	await process_frame
	story.set("line_index", player_line_index)
	story.call("_show_line")
	var output_dir := ProjectSettings.globalize_path("res://artifacts/player_dialogue_portrait")
	DirAccess.make_dir_recursive_absolute(output_dir)
	process_frame.connect(_capture_tick)


func _capture_tick() -> void:
	settle_frames += 1
	if settle_frames < 6:
		return
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Could not save player dialogue portrait capture")
		quit(1)
		return
	print("saved ", ProjectSettings.globalize_path(OUTPUT_PATH))
	quit(0)
