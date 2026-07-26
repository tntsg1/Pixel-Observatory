extends SceneTree

var frame := 0
var view: Node
var captures := [
	{"level": 76, "name": "fast_learning_card_aerial.png"},
	{"level": 79, "name": "fast_learning_card_feed_cabin.png"},
	{"level": 78, "name": "fast_learning_card_pulsar.png"},
]
var capture_index := 0


func _initialize() -> void:
	process_frame.connect(_tick)


func _tick() -> void:
	frame += 1
	if frame == 3:
		_show_capture(capture_index)
	elif frame == 48:
		_save_capture(captures[capture_index]["name"])
		capture_index += 1
		if capture_index >= captures.size():
			quit(0)
			return
		frame = 2


func _show_capture(index: int) -> void:
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var teaching: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		print("CAPTURE FAIL: required autoload missing")
		quit(1)
		return
	if view != null:
		view.queue_free()
		await process_frame
	gm.call("new_game")
	gm.call("debug_jump_to_level", int(captures[index]["level"]), true)
	var level: Dictionary = gm.call("current_level")
	var observation := {
		"quality": "Good",
		"success": true,
		"observation_mode": "radio",
		"pulse_period_ms": 714.5,
		"dispersion_measure": 26.8,
		"snr": 12.4,
	}
	gm.last_learning_card = teaching.call(
		"make_mission_complete_payload",
		level,
		gm.call("get_object", str(level.get("target_object_id", "pulsar_b0329"))),
		observation,
		gm.call("calculate_stats")
	)
	var packed: PackedScene = load("res://scenes/learning_card.tscn")
	view = packed.instantiate()
	root.add_child(view)


func _save_capture(file_name: String) -> void:
	var directory := ProjectSettings.globalize_path("res://artifacts/fast_media")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(file_name)
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s: %s" % [file_name, error_string(error)])
