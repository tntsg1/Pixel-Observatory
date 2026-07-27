extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST RFI GUIDANCE TEST: GameManager missing")
		quit(1)
		return
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	var tutorial_seen_before: Dictionary = feedback.get("_tutorial_seen").duplicate(true) if feedback != null else {}
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["tutorial_assistance"] = "full"
	gm.debug_jump_to_level(83, true)
	var scene: Control = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.set("stage", 2)
	scene.call("_rebuild")
	await process_frame

	var keep_button := scene.get("rfi_keep_button") as Button
	var reject_button := scene.get("rfi_reject_button") as Button
	var verify_button := scene.get("rfi_verify_button") as Button
	_check(keep_button != null and reject_button != null and verify_button != null, "RFI controls exist")
	var actions := keep_button.get_parent_control()
	scene.call("_show_rfi_tutorial", actions)
	await process_frame
	var tutorial := scene.get("rfi_tutorial_panel") as Panel
	_check(tutorial != null and is_instance_valid(tutorial), "full guidance opens the compact Maya tutorial")
	_check(tutorial.get_node_or_null("MayaPortrait") != null, "tutorial uses Maya's official portrait")
	_check(not Rect2(tutorial.position, tutorial.size).intersects(Rect2(keep_button.position, keep_button.size)), "tutorial does not cover the Keep button")

	scene.call("_advance_rfi_tutorial")
	scene.call("_advance_rfi_tutorial")
	scene.call("_advance_rfi_tutorial")
	await process_frame
	_check(scene.get("rfi_tutorial_panel") == null, "tutorial closes after the three guided steps")

	var model: RadioSignalModel = scene.get("model")
	model.classifications.clear()
	scene.set("selected_peak", 0)
	scene.call("_refresh_rfi")
	_check(verify_button.disabled, "Verify remains disabled while peaks are unreviewed")
	scene.call("_classify_selected", bool(model.rfi_peaks[0].get("is_rfi", false)))
	scene.set("selected_peak", 0)
	scene.call("_refresh_rfi")
	var readout := scene.get("readout") as Label
	_check(readout.text.contains("Decision:"), "selected peak readout exposes the player's decision")
	for i in range(model.rfi_peaks.size()):
		model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))
	scene.call("_refresh_rfi")
	_check(not verify_button.disabled, "Verify enables only after every peak has been reviewed")

	var shader_text := FileAccess.get_file_as_string("res://shaders/fast_crt_monitor.gdshader")
	_check(
		not shader_text.contains("hint_screen_texture")
		and not shader_text.contains("SCREEN_UV"),
		"RFI state colors remain on the clear UI layer instead of being resampled by CRT glass"
	)
	if feedback != null:
		feedback.set("_tutorial_seen", tutorial_seen_before)
		feedback.call("_save_settings")
	scene.queue_free()
	await process_frame
	print("FAST RFI GUIDANCE TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
		return
	failures += 1
	push_error("  FAIL: " + message)
