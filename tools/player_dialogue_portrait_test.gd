extends SceneTree

# Prevents the dialogue UI from drifting back to the retired blocky avatar.

var failures := 0
var story: Control


func _initialize() -> void:
	await process_frame
	var game_manager := root.get_node_or_null("/root/GameManager")
	var story_manager := root.get_node_or_null("/root/StoryManager")
	if game_manager == null or story_manager == null:
		print("PLAYER DIALOGUE PORTRAIT TEST FAIL (autoloads missing)")
		quit(1)
		return

	var intro: Array = story_manager.call("get_dialogue", "intro")
	var player_line_index := -1
	for index in range(intro.size()):
		var line: Dictionary = intro[index]
		if str(line.get("portrait", "")).to_lower() in ["player", "you"]:
			player_line_index = index
			break
	_check(player_line_index >= 0, "intro contains a player dialogue line")
	if player_line_index < 0:
		_finish()
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

	var portrait := story.find_child("CharacterPortrait", true, false) as TextureRect
	var frame := story.find_child("DialoguePortraitFrame", true, false) as Panel
	_check(portrait != null, "dialogue creates the player portrait")
	_check(frame != null and frame.clip_contents, "player portrait remains clipped to its framed well")
	if portrait != null:
		var atlas := portrait.texture as AtlasTexture
		_check(atlas != null, "player portrait is an atlas crop, not the retired standalone avatar")
		if atlas != null:
			_check(atlas.atlas.resource_path.ends_with("player_observer_smooth_8dir.png"), "portrait shares the current high-detail protagonist atlas")
			_check(atlas.region == Rect2(0, 0, 64, 96), "portrait uses the authored front-facing rest frame")
		_check(portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "portrait keeps crisp pixel sampling")
		_check(portrait.visible, "player portrait is visible on the player line")
		_check(str(portrait.get_meta("player_source_path", "")).ends_with("player_observer_smooth_8dir.png"), "portrait records the shared source for diagnostics")
	_finish()


func _finish() -> void:
	if is_instance_valid(story):
		story.queue_free()
	if failures == 0:
		print("PLAYER DIALOGUE PORTRAIT TEST PASS")
		quit(0)
	else:
		print("PLAYER DIALOGUE PORTRAIT TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		failures += 1
		print("  FAIL: " + message)
