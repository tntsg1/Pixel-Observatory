extends SceneTree

const OUTPUT_DIR := "res://artifacts/l22_manual_drift_tutorial"
const TUTORIAL_ID := "manual_earth_drift_correction_v2"

var had_save := false
var saved_save := PackedByteArray()
var had_accessibility := false
var saved_accessibility := PackedByteArray()
var gm: Node
var feedback: Node


func _initialize() -> void:
	var watchdog := create_timer(45.0)
	watchdog.timeout.connect(func() -> void:
		push_error("L22 MANUAL DRIFT CAPTURE TIMEOUT")
		_finish(124)
	)
	_backup_user_files()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm = root.get_node_or_null("/root/GameManager")
	feedback = root.get_node_or_null("/root/InteractionFeedback")
	if gm == null or feedback == null:
		push_error("Required autoloads are unavailable")
		_finish(1)
		return

	gm.new_game()
	gm.language_mode = "zh"
	gm.set_tutorial_assistance_mode("full")
	gm.debug_jump_to_level(22, true)
	gm.selected_object_id = "sirius"
	feedback.set("guidance_highlights", true)
	var seen: Dictionary = feedback.get("_tutorial_seen")
	seen.erase(TUTORIAL_ID)
	feedback.set("_tutorial_seen", seen)

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	# This capture is about the hands-on drift lesson, not the identification
	# guide that normally follows it.
	view.set("quiz_brief_dismissed", true)
	root.add_child(view)
	for _frame in range(8):
		await process_frame
	await create_timer(0.12).timeout
	await _capture("01_maya_explains_manual_tracking.png")

	for overlay in get_nodes_in_group("guidance_highlight"):
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	await process_frame
	view.set_process(false)
	view.set("drift_direction", Vector2.RIGHT)
	view.set("drift_offset", Vector2.ZERO)
	view.call("_advance_drift", 1.0)
	view.call("_refresh_drift_ui")
	await process_frame
	await _capture("02_sirius_drifts_press_d.png")

	view.set("drift_direction", Vector2.ZERO)
	Input.action_press("move_right")
	view.call("_advance_drift", 0.12)
	Input.action_release("move_right")
	view.call("_refresh_drift_ui")
	await process_frame
	await _capture("03_manual_correction_learned.png")

	view.queue_free()
	await process_frame
	_finish(0)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var output := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := image.save_png(output) if image != null and not image.is_empty() else FAILED
	print("L22 MANUAL DRIFT CAPTURE %s: %s" % ["PASS" if error == OK else "FAIL", output])


func _backup_user_files() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_save = FileAccess.get_file_as_bytes("user://savegame.json")
	had_accessibility = FileAccess.file_exists("user://accessibility.cfg")
	if had_accessibility:
		saved_accessibility = FileAccess.get_file_as_bytes("user://accessibility.cfg")


func _restore_file(path: String, existed: bool, bytes: PackedByteArray) -> void:
	if existed:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(code: int) -> void:
	Input.action_release("move_right")
	_restore_file("user://savegame.json", had_save, saved_save)
	_restore_file("user://accessibility.cfg", had_accessibility, saved_accessibility)
	quit(code)
