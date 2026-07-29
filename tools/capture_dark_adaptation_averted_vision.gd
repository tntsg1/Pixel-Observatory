extends SceneTree

const OUTPUT := "res://artifacts/dark_adaptation_averted_vision"

var gm: Node
var view: Control
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	var watchdog := create_timer(45.0)
	watchdog.timeout.connect(func() -> void:
		push_error("DARK ADAPTATION CAPTURE TIMEOUT")
		_finish(124)
	)
	if DisplayServer.get_name() == "headless":
		push_error("DARK ADAPTATION CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		_finish(2)
		return
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(18, true)
	gm.selected_object_id = "orion_nebula"
	_suppress_tutorials()

	view = load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	current_scene = view
	await _settle(0.25)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await _settle(0.12)
		var quiz_overlay := view.get("quiz_brief_overlay") as Control
		if quiz_overlay != null and is_instance_valid(quiz_overlay):
			quiz_overlay.queue_free()
			view.set("quiz_brief_overlay", null)
			await process_frame
	for child in view.find_children("TutorialHighlight_*", "", true, false):
		child.queue_free()
	await process_frame
	var focus_panel := view.get("focus_guide_panel") as Control
	if focus_panel != null:
		focus_panel.visible = false
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	view.set_process(false)

	view.set("dark_adaptation", 0.0)
	view.set("averted_vision_active", false)
	view.set("averted_vision_confirmed", false)
	_refresh()
	await _save("01_before_adaptation.png")

	view.set("dark_adaptation", 1.0)
	view.call("_refresh_dark_adaptation_label")
	_refresh()
	await _save("02_dark_adaptation_100_effective.png")

	view.set("averted_vision_active", true)
	view.call("_update_averted_vision_guide", 1.26)
	_refresh()
	await _save("03_shift_averted_vision_confirmed.png")

	print("DARK ADAPTATION CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT))
	_finish(0)


func _refresh() -> void:
	view.set("observation", view.call("_evaluate"))
	view.call("_refresh_target_sprite")
	view.call("_refresh_focus_ui")
	view.call("_refresh_technique_status")


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var output_path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(error)])
	else:
		print(
			"CAPTURE ", output_path,
			" quality=", view.get("observation").get("quality", ""),
			" ratios=", view.get("observation").get("ratios", {}),
			" gains=", view.get("observation").get("technique_gains", {})
		)


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in ["first_focus_control", "focus_novice_guide", "first_averted_vision"]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _finish(code: int) -> void:
	Input.action_release("dodge")
	if view != null and is_instance_valid(view):
		view.queue_free()
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	quit(code)
