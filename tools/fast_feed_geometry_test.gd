extends SceneTree

var failures := 0


func _initialize() -> void:
	_test_disturbance_cadence()
	_test_target_projection()
	_test_panel_tilt_field()
	print("FAST FEED GEOMETRY TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _test_disturbance_cadence() -> void:
	var model := RadioSignalModel.new()
	model.configure({
		"target_id": "cadence_test",
		"azimuth": 145.0,
		"altitude": 52.0,
		"start_offset_az": 0.0,
		"start_offset_alt": 0.0,
		"aim_drift_deg_s": 1.8,
		"aim_disturbance_interval_s": 10.0,
	})
	var start := Vector2(model.azimuth, model.altitude)
	for _frame in range(90):
		model.step(0.1)
	_check(model.aim_disturbance_serial == 0, "no continuous drift pulse during the first nine seconds")
	_check(Vector2(model.azimuth, model.altitude).distance_to(start) < 0.001, "cabin remains still between load pulses")

	for _frame in range(11):
		model.step(0.1)
	_check(model.aim_disturbance_serial == 1, "one cable-load pulse occurs at about ten seconds")
	_check(model.pointing_speed() > 0.0, "the pulse creates a short physical velocity consequence")

	for _frame in range(80):
		model.step(0.1)
	_check(model.aim_disturbance_serial == 1, "the pulse does not repeat continuously")
	_check(model.pointing_speed() < 0.05, "cabin damping returns the system to a controllable stable state")


func _test_target_projection() -> void:
	var east := RadioSignalModel.new()
	east.configure({"azimuth": 90.0, "altitude": 60.0})
	var west := RadioSignalModel.new()
	west.configure({"azimuth": 270.0, "altitude": 60.0})
	var high := RadioSignalModel.new()
	high.configure({"azimuth": 90.0, "altitude": 82.0})

	_check(east.target_feed_offset_normalized().x > 0.2, "east target moves the projected feed point to the east side")
	_check(west.target_feed_offset_normalized().x < -0.2, "west target moves the projected feed point to the west side")
	_check(
		high.target_feed_offset_normalized().length() < east.target_feed_offset_normalized().length(),
		"higher targets project nearer the dish vertex"
	)
	_check(
		east.active_reflector_center_normalized().distance_to(west.active_reflector_center_normalized()) > 0.2,
		"different sky targets activate different reflector regions"
	)


func _test_panel_tilt_field() -> void:
	var model := RadioSignalModel.new()
	model.configure({"azimuth": 145.0, "altitude": 52.0})
	var left := model.panel_tilt_vector(Vector2(-0.65, 0.0))
	var right := model.panel_tilt_vector(Vector2(0.65, 0.0))
	var upper := model.panel_tilt_vector(Vector2(0.0, -0.55))
	var lower := model.panel_tilt_vector(Vector2(0.0, 0.55))
	_check(left.distance_to(right) > 0.5, "left and right reflector panels receive different tilt vectors")
	_check(upper.distance_to(lower) > 0.5, "upper and lower reflector panels receive different tilt vectors")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
		return
	failures += 1
	print("  FAIL: %s" % message)
