extends SceneTree

const OUTPUT_DIR := "res://artifacts/venus_arcturus_regression"

var game_manager: Node
var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(45.0)
	watchdog.timeout.connect(func() -> void:
		push_error("VENUS / ARCTURUS CAPTURE TIMEOUT")
		quit(124)
	)
	if DisplayServer.get_name() == "headless":
		push_error("VENUS / ARCTURUS CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		quit(2)
		return
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_manager = root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.language_mode = "en"
	game_manager.debug_jump_to_level(28, true)
	_suppress_tutorials()
	await _capture("venus", "venus.png")
	await _capture("arcturus", "arcturus.png")
	print("VENUS / ARCTURUS CAPTURE %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT_DIR)
	])
	quit(0 if failures == 0 else 1)


func _capture(object_id: String, file_name: String) -> void:
	game_manager.selected_object_id = object_id
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	current_scene = view
	await _settle()
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	view.set("drift_enabled", false)
	view.set("drift_offset", Vector2.ZERO)
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	var grain := view.get("grain_layer") as Control
	if grain != null:
		grain.visible = false
	await _settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null or image.is_empty() or image.save_png(path) != OK:
		failures += 1
		push_error("Could not save " + path)
	current_scene = null
	view.queue_free()
	await process_frame


func _settle() -> void:
	await process_frame
	await create_timer(0.28).timeout
	await process_frame


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in ["first_focus_control", "focus_novice_guide", "first_earth_drift"]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)
