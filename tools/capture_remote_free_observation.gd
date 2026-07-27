extends SceneTree

const OUTPUT_DIR := "res://artifacts/remote_free_observation"

var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()
var failures := 0


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Remote free-observation capture requires GameManager.")
		_finish(1)
		return
	await _capture_remote_console_and_catalogs()
	await _capture_radio_products()
	print("REMOTE FREE OBSERVATION CAPTURE %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	_finish(0 if failures == 0 else 1)


func _prepare_unlocked_progress() -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	var completed: Array = []
	for level_number in range(66, 86):
		completed.append(level_number)
	gm.progress["completed_levels"] = completed
	gm.progress["current_level"] = 86
	gm.progress["space_deployed"] = true
	gm.progress["tutorial_assistance"] = "free"
	gm.progress["remote_free_intro_seen"] = {"space": true, "radio": true}


func _capture_remote_console_and_catalogs() -> void:
	_prepare_unlocked_progress()
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	current_scene = room
	await _settle(0.36)
	room.call("_toggle_remote_instrument_console")
	await _settle(0.70)
	_save("01_remote_instrument_console.png")
	room.call("_show_remote_free_catalog", "space")
	await _settle(0.70)
	_save("02_space_deep_sky_catalog.png")
	room.call("_show_remote_free_catalog", "radio")
	await _settle(0.70)
	_save("03_fast_radio_catalog.png")
	await _remove_scene(room)


func _capture_radio_products() -> void:
	var entries := [
		["pulsar_clock", "stable_pulsar", "04_fast_pulsar_product.png"],
		["galactic_hi", "confirmed_hi", "05_fast_hi_product.png"],
		["repeating_frb", "confirmed_frb", "06_fast_frb_product.png"],
	]
	for row in entries:
		_prepare_unlocked_progress()
		if not gm.begin_remote_free_observation("radio", str(row[0])):
			failures += 1
			push_error("Could not begin radio free observation: " + str(row[0]))
			continue
		var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
		root.add_child(scene)
		current_scene = scene
		await _settle(0.36)
		var model: RadioSignalModel = scene.get("model")
		_prepare_science_chain(model)
		model.trial_period_ms = model.true_period_ms
		model.trial_dm = model.true_dm
		model.trial_phase = model.true_phase
		model.set_integration(model.required_integration_s)
		scene.set("stage", 4)
		scene.set("prediction_confirmed", true)
		scene.set("report_choice", str(row[1]))
		scene.call("_rebuild")
		await _settle(0.55)
		_save(str(row[2]))
		await _remove_scene(scene)


func _prepare_science_chain(model: RadioSignalModel) -> void:
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for i in range(model.rfi_peaks.size()):
		model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))


func _settle(seconds: float) -> void:
	await process_frame
	await process_frame
	await create_timer(seconds).timeout


func _remove_scene(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := image.save_png(path) if image != null and not image.is_empty() else FAILED
	if error != OK:
		failures += 1
		push_error("Could not save capture: " + path)
	else:
		print("CAPTURE ", path)


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


func _finish(exit_code: int) -> void:
	_restore_save()
	quit(exit_code)
