extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_target_acquisition"

var gm: Node
var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST target acquisition capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["completed_levels"] = [76]
	gm.progress["current_level"] = 85
	gm.set_tutorial_assistance_mode(gm.TUTORIAL_ASSIST_LIGHT)
	if not gm.begin_remote_free_observation("radio", "pulsar_clock"):
		push_error("Could not begin FAST free observation.")
		quit(1)
		return

	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	# Wait for the CRT boot before dismissing the one-time array takeover.
	# Otherwise the validation captures would contain the boot/takeover overlay
	# instead of the acquisition controls being tested.
	await create_timer(1.15).timeout
	if scene.get("intro_running") == true:
		scene.call("_finish_array_takeover")
		await _settle()

	scene.call("_refresh_target_acquisition")
	await _settle()
	_save("01_search_reachable_radio_sky.png")

	var model: RadioSignalModel = scene.get("model")
	scene.set("acquisition_state", "search")
	scene.set("acquisition_azimuth", model.true_azimuth + 4.2)
	scene.set("acquisition_altitude", model.true_altitude + 1.4)
	scene.set("acquisition_velocity", Vector2(0.62, -0.18))
	scene.call("_refresh_target_acquisition")
	scene.call("_terminal_event", "RADIO BEACON", "APPROACH", "ERROR 3.1 DEG")
	await _settle()
	_save("02_approach_coarse_capture.png")

	scene.set("acquisition_state", "locked")
	scene.set("acquisition_completed", true)
	scene.set("acquisition_transition_pending", true)
	scene.set("acquisition_azimuth", model.true_azimuth)
	scene.set("acquisition_altitude", model.true_altitude)
	scene.set("acquisition_velocity", Vector2.ZERO)
	scene.call("_refresh_target_acquisition")
	scene.call("_terminal_event", "RADIO BEACON", "FINE LOCK", str(model.target_id).to_upper())
	scene.call("_terminal_event", "BEAM CENTRE", "CAPTURED", "40 DEG ENVELOPE VERIFIED")
	await _settle()
	_save("03_fine_lock_complete.png")

	current_scene = null
	scene.queue_free()
	await process_frame
	await process_frame
	print("FAST TARGET ACQUISITION CAPTURE %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.28).timeout


func _save(file_name: String) -> void:
	var texture := root.get_texture()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	if texture == null:
		failures += 1
		push_error("Viewport texture unavailable: " + path)
		return
	var image := texture.get_image()
	if image == null or image.save_png(path) != OK:
		failures += 1
		push_error("Could not save: " + path)
	else:
		print("CAPTURE ", path)
