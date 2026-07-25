extends SceneTree

# Repeatable visual capture for the telescope-history story layer.
# Run without --headless at 1024x768.

const OUTPUT_DIR := "res://artifacts/telescope_heritage"

var frames := 0
var active_view: Node


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		quit(1)
		return
	match frames:
		4:
			gm.language_mode = "en"
			_show_story(sm, "level_3_before_assembly", 1)
		34:
			_capture("01_refractor_breakthrough.png")
		44:
			_show_story(sm, "level_26_before_assembly", 0)
		74:
			_capture("02_newtonian_before.png")
		84:
			_show_story(sm, "level_76_before_assembly", 1)
		114:
			_capture("03_fast_breakthrough.png")
		124:
			gm.progress["journal_entries"] = []
			for event_id in ["level_3_before_assembly", "level_26_before_assembly", "level_76_before_assembly"]:
				sm.record_telescope_heritage(event_id)
			_replace_view(load("res://scenes/learning_journal.tscn").instantiate())
		160:
			_capture("04_heritage_logbook.png")
			print("TELESCOPE_HERITAGE_CAPTURES_COMPLETE")
			quit(0)


func _show_story(sm: Node, event_id: String, line_index: int) -> void:
	sm.active_event_id = event_id
	sm.active_event_ids = [event_id]
	sm.active_lines = sm.get_dialogue(event_id)
	sm.active_context = sm.context_for_event(event_id)
	var story: Control = load("res://scenes/story_dialogue.tscn").instantiate()
	_replace_view(story)
	story.set("line_index", line_index)
	story.call("_show_line")


func _replace_view(view: Node) -> void:
	if active_view != null and is_instance_valid(active_view):
		active_view.queue_free()
	active_view = view
	root.add_child(active_view)
	current_scene = active_view


func _capture(file_name: String) -> void:
	var directory := DirAccess.open("res://")
	if directory != null:
		directory.make_dir_recursive("artifacts/telescope_heritage")
	root.get_texture().get_image().save_png(OUTPUT_DIR + "/" + file_name)
	print("saved ", file_name)
