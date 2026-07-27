extends SceneTree

const OUTPUT_DIR := "res://artifacts/space_target_acquisition"

var gm: Node
var scene: Control
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["completed_levels"] = range(66, 86)
	gm.progress["current_level"] = 85
	gm.progress["space_deployed"] = true
	gm.progress["tutorial_assistance"] = "free"
	if not gm.begin_remote_free_observation("space", "andromeda_infrared"):
		_finish(1)
		return
	scene = load("res://scenes/space_observation.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	# The CRT warm-up is wall-clock driven. Uncapped capture frames can run far
	# faster than 60 fps, so wait for the real boot animation to finish.
	await create_timer(1.15).timeout
	_save("01_initial_search.png")

	var entry := _safe_entry()
	if entry.is_empty():
		_finish(1)
		return
	scene.set("acquisition_attitude", Vector2(
		float(entry.get("yaw", 0.0)) - 3.6,
		float(entry.get("pitch", 0.0)) - 1.3))
	scene.call("_refresh_acquisition")
	await _settle(0.18)
	_save("02_coarse_slew_near_target.png")

	scene.set("acquisition_attitude", Vector2(
		float(entry.get("yaw", 0.0)),
		float(entry.get("pitch", 0.0))))
	scene.call("_refresh_acquisition")
	scene.call("_begin_acquisition_lock")
	await create_timer(1.22).timeout
	_save("03_fine_lock_complete.png")
	await create_timer(0.72).timeout
	_save("04_plan_after_lock.png")
	scene.queue_free()
	await process_frame
	_finish(0)


func _safe_entry() -> Dictionary:
	for value in scene.get("acquisition_entries"):
		var entry := value as Dictionary
		if bool(entry.get("thermal_safe", false)):
			return entry
	return {}


func _settle(seconds: float) -> void:
	for _i in range(maxi(2, ceili(seconds * 60.0))):
		await process_frame


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name)))


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _finish(code: int) -> void:
	_restore_save()
	print("SPACE TARGET ACQUISITION CAPTURE %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)
