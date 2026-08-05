extends SceneTree

const OUTPUT_PATH := "res://artifacts/telescope_guidance_layout/01_zh_diagnostic_contained.png"

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(31, true)
	gm.selected_object_id = "sombrero_galaxy"
	view = (load("res://scenes/telescope_view.tscn") as PackedScene).instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await create_timer(0.30).timeout

	view.call("_set_focus_value", float(view.get("target_focus_value")))
	var forced_observation: Dictionary = (view.get("observation") as Dictionary).duplicate(true)
	forced_observation["quality"] = "Fair"
	forced_observation["success"] = false
	forced_observation["seeing_label"] = "Poor"
	view.set("observation", forced_observation)
	view.set("hold_timer", float(view.get("hold_seconds_required")))
	view.set("averted_vision_confirmed", true)
	view.call("_refresh_focus_ui")
	await process_frame

	var diagnosis := view.get("focus_state_label") as Label
	var identify := view.get("identify_title_label") as Label
	var method_status := view.get("technique_status_label") as Label
	_check(diagnosis != null and identify != null, "diagnosis and identification regions exist")
	if diagnosis != null and identify != null:
		_check(diagnosis.position.y + diagnosis.size.y <= identify.position.y, "Chinese diagnosis stays above the Identify heading")
		_check(diagnosis.clip_text, "diagnosis has a hard drawing boundary")
		_check(diagnosis.max_lines_visible == 3, "diagnosis reserves up to three contained lines")
		_check(diagnosis.text.contains("大气仍不稳定"), "long poor-seeing Maya guidance is exercised")
	if method_status != null:
		_check(method_status.clip_text, "bottom observing-method status cannot draw through its frame")
		_check(method_status.position.x + method_status.size.x <= 726.0, "method status stays inside the gold panel")

	if DisplayServer.get_name() != "headless":
		await _capture()
	view.queue_free()
	await process_frame
	_finish()


func _capture() -> void:
	await create_timer(0.25).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/telescope_guidance_layout"))
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	_check(error == OK, "saved contained Chinese guidance screenshot")
	if error == OK:
		print("CAPTURE ", ProjectSettings.globalize_path(OUTPUT_PATH))


func _finish() -> void:
	print("TELESCOPE GUIDANCE LAYOUT TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
