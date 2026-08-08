extends SceneTree

const ObservationSystemScript = preload("res://scripts/systems/observation_system.gd")
const OUTPUT_PATH := "res://artifacts/l30_crab_averted_vision/01_crab_side_view_confirmed.png"

var failures := 0
var gm: Node
var view: Control


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(30, true)
	gm.selected_object_id = "crab_nebula"
	view = load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	_check(bool(view.call("_is_diffuse_target")), "Crab supernova remnant is treated as an extended diffuse target")
	_check(bool(view.call("_visual_detection_techniques_available")), "L30 enables the same side-view mechanic as L31")
	_check(view.get("averted_vision_guide") != null, "L30 creates the visible side-view gaze guide")
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	Input.action_press("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.60)
	_check(float(view.get("averted_hold_visual")) > 0.40, "Crab side-view hold gives continuous visible progress")
	view.call("_update_averted_vision_guide", 0.66)
	_check(bool(view.get("averted_vision_confirmed")), "Crab confirms after the same 1.25-second hold as Sombrero")
	var evaluated: Dictionary = view.call("_evaluate")
	print("L30_EVALUATION ", JSON.stringify(evaluated))
	var failure: Dictionary = evaluated.get("technique_failure", {})
	_check(str(failure.get("code", "")) != "averted_vision", "confirmed Crab side-view clears the observation requirement")
	_check(float(evaluated.get("technique_gains", {}).get("averted_vision", 1.0)) > 1.0, "confirmed Crab side-view applies a real detectability gain")
	_check(str(evaluated.get("quality", "")) in ["Good", "Excellent"], "fully prepared L30 reaches mission quality instead of remaining Fair")
	_check(bool(evaluated.get("success", false)), "fully prepared L30 observation is scientifically completable")
	_test_same_science_path_as_galaxy()
	if DisplayServer.get_name() != "headless":
		await _capture()
	Input.action_release("dodge")
	view.queue_free()
	await process_frame
	_finish()


func _test_same_science_path_as_galaxy() -> void:
	var stats := {
		"light_score": 100.0,
		"clarity_score": 72.0,
		"stability_score": 66.0,
		"useful_magnification_limit": 300.0,
		"magnification": 30.0,
		"aperture_mm": 150.0,
	}
	var context := {
		"observation_mode": "telescope",
		"minimum_success_quality": "Good",
		"environment": {"seeing": "good", "cloud_cover": 0.0, "sky_brightness": "dark"},
		"visual_detection_techniques_enabled": true,
		"dark_adaptation": 1.0,
		"averted_vision": true,
	}
	var crab: Dictionary = gm.get_object("crab_nebula")
	var sombrero: Dictionary = gm.get_object("sombrero_galaxy")
	var crab_result: Dictionary = ObservationSystemScript.evaluate(stats, crab, context)
	var sombrero_result: Dictionary = ObservationSystemScript.evaluate(stats, sombrero, context)
	_check(
		is_equal_approx(
			float(crab_result.get("technique_gains", {}).get("averted_vision", 1.0)),
			float(sombrero_result.get("technique_gains", {}).get("averted_vision", 1.0))
		),
		"Crab and Sombrero use the same confirmed side-view gain"
	)


func _capture() -> void:
	# Let the identification guide's short fade finish so the evidence shows
	# the actual L30 side-view state rather than a transient modal overlay.
	await create_timer(0.35).timeout
	for _frame in range(4):
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/l30_crab_averted_vision"))
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	_check(error == OK, "saved L30 confirmed side-view screenshot")
	if error == OK:
		print("CAPTURE ", ProjectSettings.globalize_path(OUTPUT_PATH))


func _finish() -> void:
	Input.action_release("dodge")
	print("L30 CRAB AVERTED VISION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
