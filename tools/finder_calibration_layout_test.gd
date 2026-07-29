extends SceneTree

const SKY_RECT := Rect2(88, 103, 630, 560)

var failures := 0


func _initialize() -> void:
	await process_frame
	var game_manager := root.get_node_or_null("GameManager")
	if game_manager == null:
		_fail("GameManager autoload is available")
		_finish()
		return

	game_manager.new_game()
	game_manager.debug_jump_to_level(6, true)
	game_manager.language_mode = "zh"
	game_manager.last_sky_aim = {}

	var sky: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	for _frame in range(10):
		await process_frame

	_check(str(sky.get("view_mode")) == "finder", "finder calibration opens in finder mode")

	var panel := sky.get("calibration_panel") as Control
	var steps := sky.get("calibration_steps_banner") as Control
	var guidance_bg := sky.get("guidance_banner_bg") as Control
	var guidance := sky.get("guidance_banner") as Control
	var controls := sky.get("controls_help") as Control
	_check(panel != null and panel.visible, "calibration utility footer is visible")
	_check(steps != null and steps.get_parent() == panel, "calibration steps live inside the footer")
	if panel != null:
		_check(not panel.get_global_rect().intersects(SKY_RECT), "calibration footer does not cover the sky")
	_check(guidance_bg == null or not guidance_bg.visible, "generic guidance background is hidden during calibration")
	_check(guidance == null or not guidance.visible, "generic guidance text is hidden during calibration")
	_check(controls == null or not controls.visible, "generic key strip is hidden during calibration")

	sky.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	push_error("FAIL: %s" % message)


func _finish() -> void:
	if failures == 0:
		print("FINDER CALIBRATION LAYOUT TEST PASS")
		quit(0)
	else:
		print("FINDER CALIBRATION LAYOUT TEST FAIL (%d)" % failures)
		quit(1)
