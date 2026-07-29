extends SceneTree

var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		push_error("URANUS FOCUS BLUR TEST TIMEOUT")
		quit(124)
	)
	await process_frame
	root.size = Vector2i(1024, 768)
	var game_manager := root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager is available")
	if game_manager == null:
		_finish()
		return

	game_manager.new_game()
	game_manager.debug_jump_to_level(32, true)
	game_manager.selected_object_id = "uranus"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	_check(bool(view.call("_is_solid_body_target", "uranus")), "Uranus uses the opaque solid-body pipeline")
	var main := view.get("main_sprite") as TextureRect
	_check(main != null, "Uranus creates a target sprite")
	if main == null:
		view.queue_free()
		_finish()
		return
	var material := main.material as ShaderMaterial
	_check(material != null, "Uranus uses the optical target-state shader")
	if material == null:
		view.queue_free()
		_finish()
		return

	var target_focus := float(view.get("target_focus_value"))
	var tolerance := maxf(float(view.get("focus_tolerance")), 0.02)
	view.call("_set_focus_value", target_focus)
	view.call("_advance_visual_smoothing", 1.0)
	var sharp_texture_radius := float(material.get_shader_parameter("blur_radius_px"))
	var sharp_screen_radius := sharp_texture_radius * float(view.get("display_scale"))

	var near_value := clampf(target_focus + tolerance * 1.45, 0.0, 1.0)
	if absf(near_value - target_focus) < tolerance:
		near_value = clampf(target_focus - tolerance * 1.45, 0.0, 1.0)
	view.call("_set_focus_value", near_value)
	view.call("_advance_visual_smoothing", 1.0)
	var near_texture_radius := float(material.get_shader_parameter("blur_radius_px"))
	var near_screen_radius := near_texture_radius * float(view.get("display_scale"))

	var far_value := clampf(target_focus + 0.32, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.24:
		far_value = clampf(target_focus - 0.32, 0.0, 1.0)
	view.call("_set_focus_value", far_value)
	view.call("_advance_visual_smoothing", 1.0)
	var far_texture_radius := float(material.get_shader_parameter("blur_radius_px"))
	var far_screen_radius := far_texture_radius * float(view.get("display_scale"))
	var star_materials: Array = view.get("star_field_psf_materials")

	print(
		"URANUS FOCUS RADII screen=", [sharp_screen_radius, near_screen_radius, far_screen_radius],
		" texture=", [sharp_texture_radius, near_texture_radius, far_texture_radius],
		" scale=", view.get("display_scale")
	)
	_check(sharp_screen_radius <= 2.5, "exact focus retains only the small real seeing/collimation residual")
	_check(near_screen_radius > sharp_screen_radius + 1.0, "near focus visibly starts broadening the disk")
	_check(near_screen_radius < far_screen_radius, "defocus grows continuously with focus error")
	_check(far_screen_radius >= 26.0, "severe defocus spreads Uranus by at least 26 eyepiece pixels")
	_check(far_screen_radius >= sharp_screen_radius * 6.0, "severe defocus is unmistakably broader than best focus")
	_check(far_texture_radius >= 100.0, "small-planet source scale is compensated in texture space")
	_check(float(material.get_shader_parameter("defocus_amount")) >= 0.90, "solid-body convolution receives the shared severe focus error")
	_check(main.modulate.a >= 0.98, "defocus does not turn Uranus into a translucent sticker")
	_check(not star_materials.is_empty(), "background stars share the optical focus state")
	if not star_materials.is_empty():
		_check(
			float((star_materials[0] as ShaderMaterial).get_shader_parameter("defocus")) >= 0.90,
			"background stars become defocused with Uranus"
		)
	var shader_source := FileAccess.get_file_as_string("res://shaders/optical_target_state.gdshader")
	_check(
		shader_source.contains("PSF_SAMPLE_COUNT = 24")
		and shader_source.contains("GOLDEN_ANGLE"),
		"solid-body shader uses the Web-safe circular PSF kernel"
	)
	_check(shader_source.contains("source_uv_scale"), "solid-body shader has transparent optical overscan for outward blur")
	_check(shader_source.contains("convolution_mix"), "solid-body shader removes the clear core as defocus grows")

	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("URANUS FOCUS BLUR TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
