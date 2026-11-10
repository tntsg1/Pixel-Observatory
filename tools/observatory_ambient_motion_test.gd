extends SceneTree

var failures := 0
var room: Control
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	var manager := root.get_node_or_null("/root/GameManager")
	_check(manager != null, "GameManager is available")
	if manager != null:
		manager.call("new_game")
		manager.set("room_guidance_target", "assembly")
	await _open_room()
	var director := room.get_node_or_null("ObservatoryAmbientDirector")
	_check(director != null, "hall owns a dedicated ambient director")
	if director != null:
		_check(director.has_method("ambient_snapshot"), "ambient director exposes a verification snapshot")
		var snapshot: Dictionary = director.call("ambient_snapshot")
		_check(snapshot.has("ambient_layer") and snapshot.has("task_layer"), "ambient and task-performance layers are separate")
		_check(int(snapshot.get("ambient_lamps", 0)) >= 4, "ambient lamps cover the room")
		_check(int(snapshot.get("ambient_motes", 0)) >= 4, "ambient layer includes sparse living details")
		_check(int(snapshot.get("pixel_lamps", 0)) >= 4, "lamp flicker reuses real hall pixels")
		_check(bool(snapshot.get("terminal_pixel_animation", false)), "terminal self-test uses the supplied CRT pixels")
		_check(bool(snapshot.get("journal_page_animation", false)), "journal page-turn uses the supplied book pixels")
		_check(bool(snapshot.get("focus_pixel_animation", false)), "telescope maintenance uses the supplied focus assembly pixels")
		_check(str(snapshot.get("task_target", "")) == "assembly", "task-performance layer follows room guidance")
		_check(float(snapshot.get("task_intensity", 0.0)) > float(snapshot.get("ambient_intensity", 1.0)), "guided station is more visible than background ambience")
		var feedback := root.get_node_or_null("/root/InteractionFeedback")
		if feedback != null:
			var previous := bool(feedback.get("reduced_motion"))
			feedback.set("reduced_motion", true)
			await create_timer(0.08).timeout
			snapshot = director.call("ambient_snapshot")
			_check(bool(snapshot.get("reduced_motion", false)), "ambient director honors reduced motion")
			_check(float(snapshot.get("mote_motion", 1.0)) <= 0.15, "reduced motion removes drifting motes")
			_check(float(snapshot.get("task_intensity", 0.0)) > 0.0, "reduced motion keeps the task station legible")
			feedback.set("reduced_motion", previous)
	_finish()


func _open_room() -> void:
	var packed := load("res://scenes/observatory_room.tscn") as PackedScene
	_check(packed != null, "observatory room scene loads")
	if packed == null:
		return
	room = packed.instantiate() as Control
	root.add_child(room)
	await process_frame
	await process_frame
	await create_timer(0.12).timeout


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
		return
	failures += 1
	push_error("  FAIL: " + label)


func _finish() -> void:
	if room != null:
		room.queue_free()
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	if failures == 0:
		print("OBSERVATORY AMBIENT MOTION TEST PASS")
		quit(0)
	else:
		push_error("OBSERVATORY AMBIENT MOTION TEST FAIL (%d failures)" % failures)
		quit(1)
