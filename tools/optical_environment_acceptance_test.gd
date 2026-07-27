extends SceneTree

const TELESCOPE_VIEW_PATH := "res://scenes/telescope_view.tscn"
const ObservationSystem := preload("res://scripts/systems/observation_system.gd")

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	await _test_fixed_lens_space_and_drift()
	await _test_tracking_direction()
	await _test_light_pollution_response()
	await _test_seeing_classes()
	await _test_cloud_area_sampling()
	_finish()


func _test_fixed_lens_space_and_drift() -> void:
	var setup := await _spawn_view(35, "whirlpool_galaxy", {
		"seeing": "good",
		"cloud_cover": 0.0,
		"sky_brightness": "dark",
	})
	var view: Control = setup["view"]
	view.process_mode = Node.PROCESS_MODE_DISABLED
	var target_parent := (view.get("main_sprite") as Control).get_parent() as Control
	var lens_center: Vector2 = view.get("lens_center")
	var lens_global := target_parent.global_position + lens_center
	var mask := _find_lens_mask(view)
	_check(mask != null, "scope owns one fixed lens-space field stop")
	var mask_rect_before := mask.get_global_rect() if mask != null else Rect2()
	view.set("drift_offset", Vector2.ZERO)
	view.call("_apply_drift_offset")
	var star_layer := view.get("star_layer_container") as Control
	var star_before := star_layer.position if star_layer != null else Vector2.ZERO
	var target_before: Vector2 = view.get("target_center")
	var cloud_positions_before: Array[Vector2] = []
	for cloud_value in view.get("cloud_nodes"):
		cloud_positions_before.append((cloud_value as Control).position)

	var drift := Vector2(196, -72)
	view.set("drift_offset", drift)
	view.call("_apply_drift_offset")
	view.set("visual_target_center", lens_center + drift)
	view.call("_update_target_visuals")
	await _render_frame()

	_check(star_layer != null and (star_layer.position - star_before).distance_to(drift) < 0.1, "realtime star field follows the same sky drift")
	var target_center: Vector2 = view.get("target_center")
	_check((target_center - target_before).distance_to(drift) < 0.1, "science target follows the same sky drift")
	if mask != null:
		_check(mask.get_global_rect() == mask_rect_before, "lens-space field stop stays fixed while the sky drifts")
	var clouds_fixed := true
	var clouds: Array = view.get("cloud_nodes")
	for i in range(mini(clouds.size(), cloud_positions_before.size())):
		if not (clouds[i] as Control).position.is_equal_approx(cloud_positions_before[i]):
			clouds_fixed = false
	_check(clouds_fixed, "atmospheric cloud layer stays in lens space")

	var image: Image
	if DisplayServer.get_name() != "headless" and root.get_texture() != null:
		image = root.get_texture().get_image()
	if image != null:
		var outside_samples := _radial_luminance_samples(image, lens_global, 224.0, 32)
		var outside_max := 0.0
		for value in outside_samples:
			outside_max = maxf(outside_max, float(value))
		_check(outside_max < 0.08, "final viewport keeps a fixed dark circular field stop near the rim")
	else:
		print("  info: final framebuffer pixel check deferred to non-headless renderer")
	await _dispose(setup)


func _test_tracking_direction() -> void:
	var displacements := {}
	for rate in [0.0, 1.0, 1.35]:
		var setup := await _spawn_view(23, "jupiter", {
			"seeing": "good",
			"cloud_cover": 0.0,
			"sky_brightness": "dark",
		})
		var view: Control = setup["view"]
		gm.set_tracking_rate(rate)
		view.set("drift_direction", Vector2.RIGHT)
		view.set("drift_offset", Vector2.ZERO)
		view.call("_advance_drift", 1.0)
		displacements[rate] = float((view.get("drift_offset") as Vector2).x)
		print("  tracking %.2fx -> drift %.3f px/s" % [rate, displacements[rate]])
		await _dispose(setup)
	_check(float(displacements[0.0]) > 0.5, "0x tracking drifts with Earth's rotation")
	_check(absf(float(displacements[1.0])) < 0.05, "1x tracking holds the target nearly still")
	_check(float(displacements[1.35]) < -0.1, "tracking above 1x reverses the apparent drift")


func _test_light_pollution_response() -> void:
	var metrics := {}
	var has_framebuffer := true
	for sky in ["dark", "suburban", "city"]:
		var setup := await _spawn_view(41, "lagoon_nebula", {
			"seeing": "good",
			"cloud_cover": 0.0,
			"sky_brightness": sky,
		})
		var view: Control = setup["view"]
		var profile: Dictionary = view.call("_light_pollution_profile")
		var material_list: Array = view.get("extended_field_materials")
		_check(not material_list.is_empty(), "%s extended target owns a persistent environment material" % sky)
		if not material_list.is_empty():
			var material := material_list[0] as ShaderMaterial
			_check(
				is_equal_approx(float(material.get_shader_parameter("faint_suppression")), float(profile["faint_suppression"])),
				"%s refresh keeps faint-structure suppression active" % sky
			)
		await _render_frame()
		var target_parent := (view.get("main_sprite") as Control).get_parent() as Control
		var center := target_parent.global_position + (view.get("lens_center") as Vector2)
		var image: Image
		if DisplayServer.get_name() != "headless" and root.get_texture() != null:
			image = root.get_texture().get_image()
		if image == null:
			has_framebuffer = false
		metrics[sky] = {
			"sky": _annulus_mean(image, center, 150.0, 195.0) if image != null else 0.0,
			"contrast": _region_luminance_stddev(image, center, 92) if image != null else 0.0,
			"faint": float(profile["faint_suppression"]),
		}
		print("  %s sky=%.4f contrast=%.4f faint_suppression=%.2f" % [
			sky,
			float(metrics[sky]["sky"]),
			float(metrics[sky]["contrast"]),
			float(metrics[sky]["faint"]),
		])
		await _dispose(setup)
	_check(float(metrics["dark"]["faint"]) < float(metrics["suburban"]["faint"]), "Suburban suppresses more faint structure than Dark")
	_check(float(metrics["suburban"]["faint"]) < float(metrics["city"]["faint"]), "City suppresses more faint structure than Suburban")
	if has_framebuffer:
		_check(float(metrics["dark"]["contrast"]) > float(metrics["city"]["contrast"]), "final viewport retains less local deep-sky contrast in City")
		_check(float(metrics["city"]["sky"]) > float(metrics["dark"]["sky"]), "final viewport city sky black level is visibly lifted")
	else:
		print("  info: pollution framebuffer comparisons deferred to non-headless renderer")
	_check(ObservationSystem._nebula_filter_eligible({"id": "lagoon_nebula"}), "emission nebula is eligible for the nebula filter")
	_check(not ObservationSystem._nebula_filter_eligible({"id": "whirlpool_galaxy"}), "galaxy does not receive a generic nebula-filter bonus")
	_check(not ObservationSystem._nebula_filter_eligible({"id": "crab_nebula"}), "Crab does not receive a blanket broadband brightness bonus")


func _test_seeing_classes() -> void:
	for object_id in ["pleiades", "m13", "double_cluster"]:
		var setup := await _spawn_view(41, object_id, {
			"seeing": "poor",
			"cloud_cover": 0.0,
			"sky_brightness": "dark",
		})
		var view: Control = setup["view"]
		_check(bool(view.call("_is_cluster_target")), "%s uses cluster-specific seeing" % object_id)
		_check(float(view.get("cond_turbulence")) > 0.2, "%s receives visible poor-seeing PSF degradation" % object_id)
		var materials: Array = view.get("extended_field_materials")
		if not materials.is_empty():
			var material := materials[0] as ShaderMaterial
			_check(float(material.get_shader_parameter("cluster_mode")) > 0.5, "%s resolves individual stellar members instead of wobbling as one object" % object_id)
		await _dispose(setup)

	var stats := {
		"light_score": 90.0,
		"clarity_score": 90.0,
		"stability_score": 90.0,
		"useful_magnification_limit": 220.0,
	}
	var obj := {
		"id": "m13",
		"type_en": "Globular Cluster",
		"required_light_score": 70.0,
		"required_clarity": 65.0,
		"required_stability": 65.0,
	}
	var high_mag := ObservationSystem.evaluate(stats, obj, {
		"observation_mode": "telescope",
		"environment": {"seeing": "poor", "sky_brightness": "dark", "cloud_cover": 0.0},
		"altitude": 20.0,
		"magnification": 165.0,
		"minimum_success_quality": "Fair",
	})
	var low_mag := ObservationSystem.evaluate(stats, obj, {
		"observation_mode": "telescope",
		"environment": {"seeing": "poor", "sky_brightness": "dark", "cloud_cover": 0.0},
		"altitude": 20.0,
		"magnification": 45.0,
		"minimum_success_quality": "Fair",
	})
	_check(
		float(low_mag["ratios"]["clarity"]) > float(high_mag["ratios"]["clarity"]),
		"lower magnification improves cluster clarity under poor low-altitude seeing"
	)
	_check(
		float(low_mag["ratios"]["stability"]) > float(high_mag["ratios"]["stability"]),
		"lower magnification improves cluster stability under poor low-altitude seeing"
	)


func _test_cloud_area_sampling() -> void:
	var setup := await _spawn_view(41, "lagoon_nebula", {
		"seeing": "average",
		"cloud_cover": 0.66,
		"sky_brightness": "suburban",
	})
	var view: Control = setup["view"]
	await _render_frame()
	var attenuation := float(view.call("_cloud_target_atten"))
	var visual_coverage := float(view.get("cloud_visual_coverage"))
	_check(view.get("cloud_nodes").size() >= 2, "cloud challenge draws multiple moving dark cloud structures")
	_check(is_equal_approx(attenuation, visual_coverage), "extended-target visual cloud coverage is the score attenuation source")
	_check(attenuation >= 0.0 and attenuation <= 1.0, "area-sampled cloud attenuation stays normalized")
	var observation: Dictionary = view.call("_evaluate")
	var live_attenuation := float(view.get("cond_cloud_atten"))
	view.set("cond_cloud_atten", 0.0)
	var clear_gap_observation: Dictionary = view.call("_evaluate")
	view.set("cond_cloud_atten", live_attenuation)
	_check(
		float(observation["ratios"]["light"]) <= float(clear_gap_observation["ratios"]["light"]),
		"live area coverage lowers the same light ratio used for observation quality"
	)
	print("  cloud coverage=%.3f attenuation=%.3f light_ratio=%.3f quality=%s" % [
		visual_coverage,
		float(view.get("cond_cloud_atten")),
		float(observation["ratios"]["light"]),
		str(observation["quality"]),
	])
	await _dispose(setup)


func _spawn_view(level_number: int, object_id: String, environment: Dictionary) -> Dictionary:
	gm.new_game()
	gm.debug_jump_to_level(level_number, true)
	gm.selected_object_id = object_id
	var level: Dictionary = gm.current_level()
	var original_environment: Dictionary = (level.get("environment", {}) as Dictionary).duplicate(true)
	level["environment"] = environment.duplicate(true)
	_suppress_tutorials()
	var view := (load(TELESCOPE_VIEW_PATH) as PackedScene).instantiate() as Control
	root.add_child(view)
	await _settle(0.18)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	var target_focus := float(view.get("target_focus_value"))
	view.call("_set_focus_value", target_focus)
	view.set("focus_guide_active", false)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	await _render_frame()
	return {
		"view": view,
		"level": level,
		"environment": original_environment,
	}


func _dispose(setup: Dictionary) -> void:
	var level: Dictionary = setup["level"]
	level["environment"] = setup["environment"]
	var view := setup["view"] as Control
	view.queue_free()
	await process_frame


func _find_lens_mask(view: Control) -> Control:
	for node in view.find_children("*", "ColorRect", true, false):
		var color_rect := node as ColorRect
		if color_rect.material is ShaderMaterial:
			var material := color_rect.material as ShaderMaterial
			if material.shader != null and material.shader.resource_path.ends_with("lens_ring_occluder.gdshader"):
				return color_rect
	return null


func _radial_luminance_samples(image: Image, center: Vector2, radius: float, count: int) -> Array[float]:
	var values: Array[float] = []
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var point := Vector2i(center + Vector2(cos(angle), sin(angle)) * radius)
		if Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
			values.append(image.get_pixelv(point).get_luminance())
	return values


func _annulus_mean(image: Image, center: Vector2, inner_radius: float, outer_radius: float) -> float:
	var total := 0.0
	var count := 0
	for y in range(int(center.y - outer_radius), int(center.y + outer_radius) + 1, 4):
		for x in range(int(center.x - outer_radius), int(center.x + outer_radius) + 1, 4):
			var distance := Vector2(x, y).distance_to(center)
			if distance < inner_radius or distance > outer_radius:
				continue
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(float(count), 1.0)


func _region_luminance_stddev(image: Image, center: Vector2, radius: int) -> float:
	var values: Array[float] = []
	for y in range(int(center.y) - radius, int(center.y) + radius + 1, 4):
		for x in range(int(center.x) - radius, int(center.x) + radius + 1, 4):
			if Vector2(x, y).distance_to(center) > radius:
				continue
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			values.append(image.get_pixel(x, y).get_luminance())
	if values.is_empty():
		return 0.0
	var mean := 0.0
	for value in values:
		mean += value
	mean /= values.size()
	var variance := 0.0
	for value in values:
		variance += pow(value - mean, 2.0)
	return sqrt(variance / values.size())


func _suppress_tutorials() -> void:
	gm.progress["tutorial_assistance_mode"] = "free"
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in [
		"first_focus_control",
		"first_averted_vision",
		"first_earth_drift",
		"first_clouds",
		"focus_novice_guide",
	]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _render_frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await process_frame


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("OPTICAL ENVIRONMENT ACCEPTANCE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
