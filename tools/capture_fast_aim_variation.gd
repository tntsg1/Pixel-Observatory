extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_aim_variation"
const CASES := [
	{"level": 76, "file": "L76_northeast_high_start.png"},
	{"level": 79, "file": "L79_southeast_low_start.png"},
	{"level": 82, "file": "L82_western_cable_path.png"},
	{"level": 85, "file": "L85_graduation_opposite_approach.png"},
]

var gm: Node
var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST AIM variation capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for entry in CASES:
		await _capture_case(int(entry["level"]), str(entry["file"]))
	print("FAST AIM VARIATION CAPTURE %s" % (
		"PASS" if failures == 0 else "FAIL (%d)" % failures
	))
	quit(0 if failures == 0 else 1)


func _capture_case(level_number: int, file_name: String) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(level_number, true)
	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	# The takeover begins only after the 0.92 s console boot. Wait for that
	# deferred handoff before dismissing it; calling finish immediately would
	# be a no-op on the first capture of a session.
	await create_timer(1.08).timeout
	scene.call("_finish_array_takeover")
	scene.call("_refresh_aim")
	await process_frame
	await create_timer(0.34).timeout
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		failures += 1
		push_error("Viewport texture unavailable for " + path)
		scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		failures += 1
		push_error("Viewport image unavailable for " + path)
		scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
		return
	var error := image.save_png(path)
	if error != OK:
		failures += 1
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
	scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
