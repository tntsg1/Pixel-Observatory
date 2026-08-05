extends SceneTree

const OUTPUT_PATH := "res://artifacts/advanced_tracking_mount/01_l30_tracking_and_similar_choices.png"
const GROUND_CASES := [
	{"level": 26, "family": "newtonian", "mount": "reflector_mount"},
	{"level": 36, "family": "dobsonian", "mount": "dobsonian_rocker_mount"},
	{"level": 46, "family": "cassegrain", "mount": "cassegrain_fork_mount"},
]

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	for test_case in GROUND_CASES:
		gm.new_game()
		gm.debug_jump_to_level(int(test_case["level"]), true)
		var report: Dictionary = gm.prepared_readiness_report()
		_check(str(report.get("family", "")) == str(test_case["family"]), "%s family is active" % test_case["family"])
		_check(str(report.get("mount_id", "")) == str(test_case["mount"]), "%s equips its prescribed mount" % test_case["family"])
		_check(bool(report.get("tracking_capable", false)), "%s mount exposes sidereal tracking" % test_case["family"])
		_check(gm.has_tracking_mount_equipped(), "%s telescope enables the tracking controls" % test_case["family"])
		_check(is_equal_approx(gm.tracking_rate(), 1.0), "%s prepared rig starts at the correct 1x sidereal rate" % test_case["family"])

	# The retired Gregorian data still needs to remain scientifically coherent
	# for old saves, even though it is no longer in the active campaign order.
	var gregorian: Dictionary = gm.get_part("gregorian_equatorial_mount")
	_check(bool(gregorian.get("tracking_capable", false)), "legacy Gregorian equatorial mount remains tracking-capable")

	# Exercise the actual L30 telescope screen from the user's report, not only
	# GameManager data. A tracking-capable Newtonian must create the live rate
	# control instead of falling back to the manual-hand-guided instructions.
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(30, true)
	gm.selected_object_id = "crab_nebula"
	var view := (load("res://scenes/telescope_view.tscn") as PackedScene).instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await create_timer(0.30).timeout
	_check(view.get("tracking_slider") != null, "L30 Newtonian telescope screen renders the tracking-rate control")
	_check(str(view.call("_tracking_state_label").get("zh", "")) == "已匹配 1 倍速", "L30 tracking status starts matched instead of manual")
	var choice_ids: Array = view.get("identify_choice_ids")
	_check(choice_ids.size() == 4 and choice_ids.has("crab_nebula"), "L30 UI presents the Crab Nebula among four choices")
	for expected_id in ["lagoon_nebula", "ring_nebula", "dumbbell_nebula"]:
		_check(choice_ids.has(expected_id), "L30 UI uses similar nebula choice %s" % expected_id)
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/advanced_tracking_mount"))
		var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
		_check(error == OK, "saved L30 tracking and similar-choice screenshot")
		if error == OK:
			print("CAPTURE ", ProjectSettings.globalize_path(OUTPUT_PATH))
	view.queue_free()
	await process_frame

	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	if failures == 0:
		print("ADVANCED TRACKING MOUNT COMPATIBILITY: PASS")
		quit(0)
	else:
		print("ADVANCED TRACKING MOUNT COMPATIBILITY: FAIL (%d)" % failures)
		quit(1)
