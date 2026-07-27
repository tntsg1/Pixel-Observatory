extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var mission_manager := root.get_node_or_null("/root/MissionManager")
	if mission_manager == null:
		_fail("MissionManager autoload is available")
		_finish()
		return

	var target_points: Array[Vector2] = []
	var path_signatures := {}
	for level_number in range(76, 86):
		var level: Dictionary = mission_manager.get_level(level_number)
		var profile: Dictionary = level.get("radio_profile", {})
		_check(not profile.is_empty(), "L%d has a radio profile" % level_number)
		_check(profile.has("start_azimuth") and profile.has("start_altitude"),
			"L%d defines an explicit feed-cabin start point" % level_number)

		var model := RadioSignalModel.new()
		model.configure(profile)
		var zenith_angle := 90.0 - model.true_altitude
		_check(zenith_angle <= model.FAST_MAX_ZENITH_ANGLE_DEG + 0.001,
			"L%d target stays inside the 40-degree zenith envelope" % level_number)
		_check(model.altitude >= 50.0 and model.altitude <= 88.0,
			"L%d start altitude is physically reachable" % level_number)
		_check(model.pointing_error() >= 24.0,
			"L%d starts far enough away to require a real slew (%.1f deg)" % [
				level_number, model.pointing_error()
			])

		var delta_az := wrapf(model.azimuth - model.true_azimuth, -180.0, 180.0)
		var delta_alt := model.altitude - model.true_altitude
		path_signatures["%d:%d" % [signf(delta_az), signf(delta_alt)]] = true
		target_points.append(model.target_feed_offset_normalized())

	var distinct_targets := 0
	for i in range(target_points.size()):
		var unique := true
		for j in range(i):
			if target_points[i].distance_to(target_points[j]) < 0.12:
				unique = false
				break
		if unique:
			distinct_targets += 1
	_check(distinct_targets >= 8,
		"L76-L85 project to at least eight visibly distinct reflector positions (%d)" % distinct_targets)
	_check(path_signatures.size() >= 4,
		"campaign starts approach targets from all four signed path directions")

	var legacy := RadioSignalModel.new()
	legacy.configure({
		"azimuth": 145.0,
		"altitude": 39.0,
		"start_offset_az": 12.0,
		"start_offset_alt": 30.0,
	})
	_check(is_equal_approx(legacy.true_altitude, 50.0),
		"legacy target below the FAST envelope is clamped to 50 degrees altitude")
	_check(is_equal_approx(legacy.altitude, 50.0),
		"legacy start below the FAST envelope is clamped to a reachable altitude")

	var absolute_start := RadioSignalModel.new()
	absolute_start.configure({
		"azimuth": 350.0,
		"altitude": 62.0,
		"start_azimuth": 18.0,
		"start_altitude": 77.0,
		"start_offset_az": 99.0,
		"start_offset_alt": 99.0,
	})
	_check(is_equal_approx(absolute_start.azimuth, 18.0)
		and is_equal_approx(absolute_start.altitude, 77.0),
		"absolute campaign start point takes precedence over legacy offsets")

	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST AIM PROFILE VARIATION TEST %s" % (
		"PASS" if failures == 0 else "FAIL (%d)" % failures
	))
	quit(0 if failures == 0 else 1)
