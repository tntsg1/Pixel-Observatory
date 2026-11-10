extends SceneTree

const OUTPUT_DIR := "res://artifacts/story_dialogue_redesign"
const CAPTURES := [
	{"name": "intro_workflow", "event": "intro", "line": 2},
	{"name": "refractor_transition", "event": "level_2_after", "line": 1},
	{"name": "newtonian_transition", "event": "level_25_after", "line": 1},
	{"name": "dobsonian_transition", "event": "level_35_after", "line": 1},
	{"name": "m13_long_title", "event": "level_39_after", "line": 0},
	{"name": "cassegrain_transition", "event": "level_45_after", "line": 1},
	{"name": "space_transition", "event": "level_55_after", "line": 1},
	{"name": "radio_transition", "event": "level_75_after", "line": 1},
	{"name": "site_map", "event": "first_below_horizon", "line": 0}
]

var language_index := 0
var capture_index := 0
var wait_frames := 0
var active_view: Control


func _initialize() -> void:
	Engine.max_fps = 60
	var directory := DirAccess.open("res://")
	if directory != null:
		directory.make_dir_recursive("artifacts/story_dialogue_redesign")
	process_frame.connect(_tick)


func _tick() -> void:
	wait_frames += 1
	if wait_frames == 4:
		_show_current()
	elif wait_frames == 40:
		_capture_current()
		_advance()


func _show_current() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	var sm := root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		push_error("Missing story autoloads")
		quit(1)
		return
	gm.language_mode = ["en", "zh"][language_index]
	var capture: Dictionary = CAPTURES[capture_index]
	var event_id := str(capture["event"])
	var lines: Array = sm.get_dialogue(event_id)
	var requested_line := int(capture["line"])
	if lines.is_empty() or requested_line < 0 or requested_line >= lines.size():
		push_error("Invalid capture case: %s" % capture)
		quit(1)
		return
	sm.active_event_id = event_id
	sm.active_event_ids = [event_id]
	sm.active_lines = lines
	sm.active_context = sm.context_for_event(event_id)
	if active_view != null and is_instance_valid(active_view):
		active_view.queue_free()
	active_view = load("res://scenes/story_dialogue.tscn").instantiate()
	root.add_child(active_view)
	current_scene = active_view
	active_view.set("line_index", requested_line)
	active_view.call("_show_line")


func _capture_current() -> void:
	var capture: Dictionary = CAPTURES[capture_index]
	var language: String = ["en", "zh"][language_index]
	var file_name := "%s_%s.png" % [language, str(capture["name"])]
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Story capture requires a rendering display driver")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Story capture produced an empty image")
		quit(1)
		return
	image.save_png(OUTPUT_DIR + "/" + file_name)
	print("saved ", file_name)


func _advance() -> void:
	capture_index += 1
	if capture_index >= CAPTURES.size():
		capture_index = 0
		language_index += 1
	if language_index >= 2:
		print("STORY DIALOGUE REDESIGN CAPTURES COMPLETE")
		quit(0)
		return
	wait_frames = 0
