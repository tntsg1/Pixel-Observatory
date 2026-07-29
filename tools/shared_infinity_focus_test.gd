extends SceneTree

var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		push_error("SHARED INFINITY FOCUS TEST TIMEOUT")
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
	game_manager.debug_jump_to_level(5, true)
	game_manager.selected_object_id = "jupiter"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	var target_focus := float(view.get("target_focus_value"))
	view.call("_set_focus_value", target_focus)
	var sharp_amount := float(view.call("_optical_defocus_amount"))
	var star_materials: Array = view.get("star_field_psf_materials")
	var main := view.get("main_sprite") as TextureRect
	var material := main.material as ShaderMaterial if main != null else null
	_check(main != null and material != null, "Jupiter uses the solid-body optical material")
	_check(not star_materials.is_empty(), "catalog stars have a PSF material")
	if material == null or star_materials.is_empty():
		view.queue_free()
		await process_frame
		_finish()
		return
	var sharp_star_amount := float((star_materials[0] as ShaderMaterial).get_shader_parameter("defocus"))
	var sharp_body_amount := float(material.get_shader_parameter("defocus_amount"))

	var far_value := clampf(target_focus + 0.32, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.24:
		far_value = clampf(target_focus - 0.32, 0.0, 1.0)
	view.call("_set_focus_value", far_value)
	var far_amount := float(view.call("_optical_defocus_amount"))
	var far_star_amount := float((star_materials[0] as ShaderMaterial).get_shader_parameter("defocus"))
	var far_body_amount := float(material.get_shader_parameter("defocus_amount"))
	var far_screen_radius := float(material.get_shader_parameter("blur_radius_px")) * float(view.get("display_scale"))

	_check(sharp_amount <= 0.001, "exact focus produces no shared defocus")
	_check(sharp_star_amount <= 0.001 and sharp_body_amount <= 0.001, "planet and stars are sharp on the same focal plane")
	_check(far_amount >= 0.90, "large focus error reaches severe shared defocus")
	_check(absf(far_star_amount - far_body_amount) <= 0.001, "planet and stars receive the same normalized focus error")
	_check(far_screen_radius >= 70.0, "severely defocused Jupiter receives a broad screen-space PSF")

	# Guard the regression where optional target media determined whether the
	# entire star field reacted to focus.
	view.set("blur_overlay", null)
	_check(float(view.call("_optical_defocus_amount")) >= 0.90, "shared focus survives without a target blur overlay")

	view.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("SHARED INFINITY FOCUS TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
