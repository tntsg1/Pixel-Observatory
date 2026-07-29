extends SceneTree

const ObservationSystemScript = preload("res://scripts/systems/observation_system.gd")

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	_test_science_quality_gains()
	await _test_level_18_shift_flow()
	_finish()


func _test_science_quality_gains() -> void:
	var stats := {
		"light_score": 83.3,
		"clarity_score": 70.2,
		"stability_score": 61.3,
		"useful_magnification_limit": 200.0,
		"magnification": 80.0,
		"aperture_mm": 100.0
	}
	var orion := {
		"id": "orion_nebula",
		"type_en": "Diffuse nebula",
		"required_light_score": 65.0,
		"required_clarity": 50.0,
		"required_stability": 35.0
	}
	var context := {
		"observation_mode": "telescope",
		"requires_focus": true,
		"focus_error": 0.0,
		"focus_tolerance": 0.06,
		"minimum_success_quality": "Fair",
		"environment": {"seeing": "average", "cloud_cover": 0.15},
		"altitude": 45.0,
		"magnification": 80.0,
		"visual_detection_techniques_enabled": true,
		"dark_adaptation": 0.0,
		"averted_vision": false
	}
	var baseline: Dictionary = ObservationSystemScript.evaluate(stats, orion, context)
	context["visual_detection_techniques_enabled"] = false
	context["dark_adaptation"] = 1.0
	context["averted_vision"] = true
	var before_lesson: Dictionary = ObservationSystemScript.evaluate(stats, orion, context)
	_check(
		is_equal_approx(
			float(before_lesson.get("ratios", {}).get("light", 0.0)),
			float(baseline.get("ratios", {}).get("light", 0.0))
		),
		"observer-technique gains stay locked before their lesson"
	)
	context["visual_detection_techniques_enabled"] = true
	context["averted_vision"] = false
	context["dark_adaptation"] = 1.0
	var adapted: Dictionary = ObservationSystemScript.evaluate(stats, orion, context)
	context["averted_vision"] = true
	var averted: Dictionary = ObservationSystemScript.evaluate(stats, orion, context)

	_check(str(baseline.get("quality", "")) == "Good", "screenshot-like L18 equipment begins at Good")
	_check(str(adapted.get("quality", "")) == "Excellent", "100% dark adaptation raises the faint-nebula result to Excellent")
	_check(
		float(adapted.get("ratios", {}).get("light", 0.0))
		> float(baseline.get("ratios", {}).get("light", 0.0)),
		"dark adaptation increases low-surface-brightness detectability"
	)
	_check(
		float(averted.get("ratios", {}).get("light", 0.0))
		> float(adapted.get("ratios", {}).get("light", 0.0)),
		"confirmed averted vision adds a further measurable gain"
	)
	_check(
		is_equal_approx(
			float(averted.get("ratios", {}).get("stability", 0.0)),
			float(baseline.get("ratios", {}).get("stability", 0.0))
		),
		"observer techniques do not fabricate mount stability"
	)

	var moon := {
		"id": "moon",
		"type_en": "Moon",
		"required_light_score": 65.0,
		"required_clarity": 50.0,
		"required_stability": 35.0
	}
	context["dark_adaptation"] = 0.0
	context["averted_vision"] = false
	var moon_baseline: Dictionary = ObservationSystemScript.evaluate(stats, moon, context)
	context["dark_adaptation"] = 1.0
	context["averted_vision"] = true
	var moon_with_techniques: Dictionary = ObservationSystemScript.evaluate(stats, moon, context)
	_check(
		is_equal_approx(
			float(moon_baseline.get("ratios", {}).get("light", 0.0)),
			float(moon_with_techniques.get("ratios", {}).get("light", 0.0))
		),
		"dark adaptation and averted vision do not boost solid bright targets"
	)


func _test_level_18_shift_flow() -> void:
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(18, true)
	gm.selected_object_id = "orion_nebula"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	_check(
		bool(view.call("_visual_detection_techniques_available")),
		"L18 enables the observer techniques without making them hard gates"
	)
	_check(view.get("averted_vision_guide") != null, "L18 creates the visible side-view guide")

	view.set("dark_adaptation", 1.0)
	view.call("_advance_dark_adaptation", 0.01)
	var dark_label := view.get("dark_adaptation_label") as Label
	_check(dark_label != null and dark_label.text.contains("生效"), "100% dark adaptation reports that its gain is active")

	Input.action_press("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.60)
	_check(float(view.get("averted_hold_visual")) > 0.40, "Shift provides immediate visible hold progress")
	view.call("_update_averted_vision_guide", 0.66)
	_check(bool(view.get("averted_vision_confirmed")), "holding Shift for 1.25 seconds confirms averted vision")
	var averted_label := view.get("averted_vision_label") as Label
	_check(averted_label != null and averted_label.text.contains("已确认"), "confirmed averted vision reports that its gain is active")
	var evaluated: Dictionary = view.call("_evaluate")
	_check(
		float(evaluated.get("technique_gains", {}).get("averted_vision", 1.0)) > 1.0,
		"L18 evaluation receives the confirmed Shift technique"
	)

	Input.action_release("dodge")
	view.queue_free()
	await process_frame


func _finish() -> void:
	Input.action_release("dodge")
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("DARK ADAPTATION AVERTED VISION QUALITY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
