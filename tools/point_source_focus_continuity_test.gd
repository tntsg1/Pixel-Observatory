extends SceneTree

const OUTPUT_DIR := "res://artifacts/point_source_focus_continuity"
const LOG_PATH := OUTPUT_DIR + "/continuity_test.stdout.txt"

var failures := 0
var log_lines: PackedStringArray = []


func _initialize() -> void:
	var watchdog := create_timer(45.0)
	watchdog.timeout.connect(func() -> void:
		_log("POINT SOURCE FOCUS CONTINUITY TEST TIMEOUT")
		_finish(124)
	)
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var game_manager := root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager is available")
	if game_manager == null:
		_finish(1)
		return

	await _check_target("sirius", 22)
	await _check_target("vega", 23)
	await _check_target("arcturus", 17)
	_finish(0 if failures == 0 else 1)


func _check_target(object_id: String, level_number: int) -> void:
	var game_manager := root.get_node("/root/GameManager")
	game_manager.new_game()
	game_manager.debug_jump_to_level(level_number, true)
	game_manager.selected_object_id = object_id
	_suppress_tutorials()

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	view.set("drift_enabled", false)
	view.set("drift_offset", Vector2.ZERO)
	var lens_center: Vector2 = view.get("lens_center")
	view.set("target_center", lens_center)
	view.set("visual_target_center", lens_center)
	var guide := view.get("focus_guide_panel") as Control
	if guide != null:
		guide.visible = false
	var grain := view.get("grain_layer") as Control
	if grain != null:
		grain.visible = false
	var star_layer := view.get("star_layer_container") as Control
	if star_layer != null:
		star_layer.visible = false
	var ghost_a := view.get("ghost_a") as Control
	var ghost_b := view.get("ghost_b") as Control
	if ghost_a != null:
		ghost_a.visible = false
	if ghost_b != null:
		ghost_b.visible = false
	var main_sprite := view.get("main_sprite") as Control
	var isolation := Control.new()
	isolation.set_anchors_preset(Control.PRESET_FULL_RECT)
	isolation.z_index = 4096
	root.add_child(isolation)
	var black := ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	isolation.add_child(black)
	main_sprite.reparent(isolation)
	view.visible = false

	var target_focus := float(view.get("target_focus_value"))
	var values: Array[float] = []
	# Seven evenly spaced samples still cover both extremes and intermediate
	# continuity without forcing the headless renderer through 28 full captures.
	for index in range(7):
		values.append(float(index) / 6.0)
	if not values.has(target_focus):
		values.append(target_focus)
	values.sort()

	if DisplayServer.get_name() == "headless":
		await _check_headless_material_response(view, object_id, values, target_focus)
		view.queue_free()
		await process_frame
		return

	var sharp_peak := 0.0
	var sharp_area := 0
	var farthest_peak := 0.0
	var farthest_area := 0
	var farthest_error := -1.0
	for focus in values:
		view.call("_set_focus_value", focus)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var metric := _measure_target(image, lens_center)
		var peak := float(metric["peak"])
		var area := int(metric["area"])
		var error := absf(focus - target_focus)
		if error <= 0.0001:
			sharp_peak = peak
			sharp_area = area
		if error > farthest_error:
			farthest_error = error
			farthest_peak = peak
			farthest_area = area
		_log("%s focus %.3f error %.3f peak %.4f area %d" % [
			object_id,
			focus,
			error,
			peak,
			area
		])
		_check(peak >= 0.018, "%s remains visible at focus %.3f" % [object_id, focus])

	_check(sharp_peak >= farthest_peak * 1.18, "%s sharp peak is brighter than severe defocus" % object_id)
	_check(farthest_area >= maxi(sharp_area * 2, sharp_area + 18), "%s defocus expands the stellar footprint" % object_id)
	isolation.queue_free()
	view.queue_free()
	await process_frame


func _check_headless_material_response(
	view: Control,
	object_id: String,
	values: Array[float],
	target_focus: float
) -> void:
	var material := view.get("target_star_psf_material") as ShaderMaterial
	_check(material != null, "%s uses the shared point-source PSF material" % object_id)
	if material == null:
		return
	if object_id == "arcturus":
		var tint: Color = material.get_shader_parameter("source_tint")
		_check(tint.r > tint.g and tint.g > tint.b, "Arcturus keeps a warm orange catalog hue")
		var source := FileAccess.get_file_as_string("res://scripts/ui/telescope_view.gd")
		_check(
			not source.contains("max(source_tint.rgb")
			and source.contains("source_core = smoothstep"),
			"point-source shader removes baked halo edges without forcing a pink channel floor"
		)
	var sharp_defocus := 1.0
	var farthest_defocus := 0.0
	var previous_value := -1.0
	for focus in values:
		view.call("_set_focus_value", focus)
		await process_frame
		var actual := float(material.get_shader_parameter("defocus"))
		var expected := float(view.call("_optical_defocus_amount"))
		_log("%s focus %.3f expected defocus %.4f material %.4f" % [
			object_id,
			focus,
			expected,
			actual
		])
		_check(absf(actual - expected) <= 0.001, "%s material follows shared focus at %.3f" % [object_id, focus])
		_check(actual >= 0.0 and actual <= 1.0, "%s defocus remains normalized" % object_id)
		if absf(focus - target_focus) <= 0.0001:
			sharp_defocus = actual
		if absf(focus - target_focus) > previous_value:
			previous_value = absf(focus - target_focus)
			farthest_defocus = actual
	_check(sharp_defocus <= 0.001, "%s exact focus keeps the point source sharp" % object_id)
	_check(farthest_defocus >= 0.85, "%s severe focus error expands the point-source PSF" % object_id)
	_log("  note: pixel continuity is captured by the non-headless visual acceptance script")


func _measure_target(image: Image, center: Vector2) -> Dictionary:
	if image == null or image.is_empty():
		return {"peak": 0.0, "area": 0}
	var peak := 0.0
	var samples: PackedFloat32Array = []
	var center_i := Vector2i(roundi(center.x), roundi(center.y))
	for y in range(center_i.y - 58, center_i.y + 59):
		for x in range(center_i.x - 58, center_i.x + 59):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var color := image.get_pixel(x, y)
			var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			peak = maxf(peak, luminance)
			samples.append(luminance)
	var area := 0
	var footprint_threshold := maxf(0.0035, peak * 0.22)
	for luminance in samples:
		if luminance >= footprint_threshold:
			area += 1
	return {"peak": peak, "area": area}


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in [
		"first_focus_control",
		"focus_novice_guide",
		"first_earth_drift",
		"manual_earth_drift_correction_v2"
	]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _check(condition: bool, label: String) -> void:
	if condition:
		_log("  ok: " + label)
	else:
		failures += 1
		_log("  FAIL: " + label)


func _log(message: String) -> void:
	print(message)
	log_lines.append(message)


func _finish(exit_code: int) -> void:
	_log("POINT SOURCE FOCUS CONTINUITY TEST %s" % ("PASS" if failures == 0 and exit_code == 0 else "FAIL"))
	var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(log_lines) + "\n")
		file.close()
	quit(exit_code)
