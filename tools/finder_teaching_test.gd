extends SceneTree

# Round 20: first finder-scope teaching. The story panel introduces the finder
# before assembly, covers the four teaching points, stays on the level's real
# target, does not replay, and the calibration step guide drives the sky scene.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	var story: Node = root.get_node("/root/StoryManager")

	# --- 1. A finder story exists for L6 and plays before assembly/observation ---
	gm.new_game()
	gm.debug_jump_to_level(6, false)
	var event_id := str(story.event_for_trigger("before_observation", 6))
	_check(event_id == "level_6_before", "1. L6 has a before-observation story event")
	var lines: Array = story.get_dialogue(event_id)
	_check(lines.size() >= 4, "1. finder story is a full panel, not a one-liner (%d lines)" % lines.size())

	# --- 2. The story covers the four finder teaching points ---
	var joined_en := ""
	var joined_zh := ""
	for line in lines:
		joined_en += " " + str((line as Dictionary).get("text_en", "")).to_lower()
		joined_zh += " " + str((line as Dictionary).get("text_zh", ""))
	_check(joined_en.contains("wider") or joined_en.contains("wide"), "2. teaches the finder is WIDER")
	_check(joined_en.contains("center") or joined_en.contains("find"), "2. teaches finding/centering")
	_check(joined_en.contains("no planet detail") or joined_en.contains("not a magnifier") or joined_en.contains("no ") , "2. teaches it gives no detail")
	_check(joined_en.contains("switch to the main") or joined_en.contains("main telescope"), "2. teaches switching to the main scope")

	# --- 3. Story stays on the level's real target (Sirius), no target mismatch ---
	var target_name := str(gm.dict_text(gm.current_target(), "name")).to_lower()
	_check(target_name.contains("sirius"), "3. L6 target is Sirius")
	_check(joined_en.contains("sirius"), "3. finder story talks about Sirius, not a different body")

	# --- 4. The story does not replay once seen ---
	var played: bool = story.begin_event(event_id, "sky", "before_observation")
	_check(played, "4. story plays the first time")
	story.finish_active_event()
	var replay: bool = story.begin_event(event_id, "sky", "before_observation")
	_check(not replay, "4. story does NOT replay after being seen")

	# --- 5. Sky scene shows the calibration step guide, gated to finder-calib levels ---
	gm.new_game()
	gm.debug_jump_to_level(6, true)
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _i in range(8):
		await process_frame
	_check(bool(sky.call("_is_finder_calibration_level")), "5. L6 is a finder-calibration level")
	_check(sky.get("calibration_steps_banner") != null, "5. calibration step guide banner exists")
	_check((sky.get("calibration_step_labels") as Array).size() == 4, "5. guide shows all four steps")
	_check(str(sky.get("view_mode")) == "finder", "5. calibration opens directly in Finder mode")
	_check(int(sky.call("_active_calibration_step")) >= 1, "5. finder adjustment step is active immediately")
	var calibration_panel := sky.get("calibration_panel") as Control
	var calibration_banner := sky.get("calibration_steps_banner") as Control
	_check(calibration_panel != null and calibration_panel.visible, "5. calibration controls are visible")
	_check(calibration_banner != null and calibration_banner.get_parent() == calibration_panel, "5. step guide is contained by the calibration utility strip")
	var view_rect := Rect2(88, 103, 630, 560)
	_check(not calibration_panel.get_global_rect().intersects(view_rect), "5. calibration strip never covers the finder sky")
	var guidance := sky.get("guidance_banner") as Control
	var controls := sky.get("controls_help") as Control
	_check(guidance != null and not guidance.visible and controls != null and not controls.visible, "5. generic sky/debug guidance is hidden during calibration")
	sky.queue_free()
	await process_frame

	# --- 6. Language purity: no mojibake / no mixed EN+ZH in the finder story ---
	var mojibake := ["锛", "鈥", "鐨", "鏄", "瑙傛祴", "璇嗗埆", "�"]
	var clean := true
	for line in lines:
		var d: Dictionary = line
		for bad in mojibake:
			if str(d.get("text_en", "")).contains(bad) or str(d.get("text_zh", "")).contains(bad):
				clean = false
	_check(clean, "6. finder story has no mojibake markers")
	# EN mode: current-language text() never leaks the other language.
	gm.language_mode = "en"
	var en_text := str(gm.text("Finder", "寻星镜"))
	_check(en_text == "Finder", "6. EN mode returns only English")
	gm.language_mode = "zh"
	var zh_text := str(gm.text("Finder", "寻星镜"))
	_check(zh_text == "寻星镜", "6. ZH mode returns only Chinese")
	gm.language_mode = "en"

	if failures == 0:
		print("FINDER TEACHING TEST PASS")
		quit(0)
	else:
		print("FINDER TEACHING TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
