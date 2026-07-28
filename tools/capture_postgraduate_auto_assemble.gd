extends SceneTree

const OUTPUT_DIR := "res://artifacts/postgraduate_auto_assemble"
const TEST_TIMEOUT_SECONDS := 20.0

var failures := 0
var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_start_watchdog()
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return

	_prepare_graduate(gm)
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.select_assembly_family("refractor")
	gm.reset_assembly()
	gm.install_part("tripod", 0, "basic_tripod")

	var bench := load("res://scenes/telescope_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	await _settle(0.2)
	_capture("01_partial_ready.png")

	bench.call("_on_auto_assemble_pressed")
	await _settle(0.16)
	_capture("02_part_flying.png")
	await _settle(0.42)
	_capture("03_first_snap.png")
	await _settle(3.8)
	_capture("04_complete_light_path.png")

	bench.queue_free()
	await process_frame
	print("POSTGRADUATE AUTO ASSEMBLE CAPTURE %s" % ("PASS" if failures == 0 else "FAIL"))
	_finish(0 if failures == 0 else 1)


func _prepare_graduate(gm: Node) -> void:
	gm.new_game()
	var mission_manager := root.get_node_or_null("/root/MissionManager")
	gm.progress["current_level"] = 85
	gm.progress["completed_levels"] = (mission_manager.get("campaign_order") as Array).duplicate() if mission_manager != null else [85]
	gm.progress["program_completed"] = true
	gm.progress["graduation_seen"] = true
	gm.progress["graduation_pending"] = false
	var all_parts: Array = []
	for part_value in gm.parts_data:
		if part_value is Dictionary:
			var part_id := str((part_value as Dictionary).get("id", ""))
			if part_id != "":
				all_parts.append(part_id)
	gm._normalize_progress()
	gm.progress["current_level"] = 85
	gm.progress["unlocked_parts"] = all_parts


func _settle(seconds: float) -> void:
	await process_frame
	await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout


func _capture(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		failures += 1
		push_error("Viewport texture unavailable for " + file_name)
		return
	var image := texture.get_image()
	var output := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var error := image.save_png(output)
	if error != OK:
		failures += 1
		push_error("Could not save " + output)
	else:
		print("CAPTURE ", output)


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not finished:
			push_error("POSTGRADUATE AUTO ASSEMBLE CAPTURE TIMEOUT")
			_finish(1)
	)


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	_restore_save()
	quit(exit_code)
