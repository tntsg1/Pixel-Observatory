extends SceneTree

var failures := 0


func _initialize() -> void:
	var watchdog := create_timer(30.0)
	watchdog.timeout.connect(func() -> void:
		push_error("SIRIUS POINT SOURCE FOCUS TEST TIMEOUT")
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
	game_manager.debug_jump_to_level(22, true)
	game_manager.selected_object_id = "sirius"
	_suppress_tutorials()

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	var main := view.get("main_sprite") as TextureRect
	var ghost_a := view.get("ghost_a") as TextureRect
	var ghost_b := view.get("ghost_b") as TextureRect
	var blur_overlay := view.get("blur_overlay") as TextureRect
	var point_material := view.get("target_star_psf_material") as ShaderMaterial
	var ghost_materials: Array = view.get("target_star_psf_ghost_materials")
	var field_materials: Array = view.get("star_field_psf_materials")

	_check(main != null, "Sirius target sprite exists")
	_check(point_material != null, "Sirius uses the energy-preserving point-source PSF")
	var shader_code := point_material.shader.code if point_material != null else ""
	_check(shader_code.contains("sharp_core_sigma"), "Sirius PSF exposes a dedicated compact sharp core")
	_check(shader_code.contains("halo_strength"), "Sirius PSF keeps its halo independently restrained")
	_check(shader_code.contains("source_art_mix"), "Sirius PSF can preserve supplied diffraction artwork")
	if point_material != null:
		_check(float(point_material.get_shader_parameter("sharp_core_sigma")) <= 0.007, "best-focus Sirius core stays point-like")
		_check(float(point_material.get_shader_parameter("halo_strength")) <= 0.12, "best-focus Sirius halo stays subordinate to the core")
		if shader_code.contains("source_art_mix"):
			_check(float(point_material.get_shader_parameter("source_art_mix")) >= 0.99, "best-focus Sirius preserves the supplied diffraction artwork")
	_check(float(view.get("display_scale")) >= 1.45, "Sirius artwork is large enough to read in the eyepiece")
	_check(ghost_materials.size() == 2, "chromatic images have two independent point-source materials")
	_check(not field_materials.is_empty(), "catalog field stars use the shared focus PSF")
	if main == null or point_material == null or ghost_materials.size() != 2 or field_materials.is_empty():
		view.queue_free()
		await process_frame
		_finish()
		return

	var target_focus := float(view.get("target_focus_value"))
	view.call("_set_focus_value", target_focus)
	var sharp_target_defocus := float(point_material.get_shader_parameter("defocus"))
	var sharp_field_defocus := float((field_materials[0] as ShaderMaterial).get_shader_parameter("defocus"))

	var far_value := clampf(target_focus + 0.32, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.24:
		far_value = clampf(target_focus - 0.32, 0.0, 1.0)
	view.call("_set_focus_value", far_value)
	var far_target_defocus := float(point_material.get_shader_parameter("defocus"))
	var far_field_defocus := float((field_materials[0] as ShaderMaterial).get_shader_parameter("defocus"))

	_check(sharp_target_defocus <= 0.001, "Sirius is sharp at the true focal plane")
	_check(sharp_field_defocus <= 0.001, "field stars are sharp at the same focal plane")
	_check(far_target_defocus >= 0.90, "Sirius reaches a visibly broad PSF at severe defocus")
	_check(absf(far_target_defocus - far_field_defocus) <= 0.001, "Sirius and field stars share the same focus error")
	_check(main.modulate.a >= 0.45, "Sirius remains visible instead of fading out during focus adjustment")
	_check(blur_overlay == null or not blur_overlay.visible, "point sources do not cross-fade through the sparse blur overlay")
	var ghost_a_material := ghost_materials[0] as ShaderMaterial
	var ghost_b_material := ghost_materials[1] as ShaderMaterial
	_check(ghost_a_material != point_material, "first chromatic image keeps an independent tint material")
	_check(ghost_b_material != point_material, "second chromatic image keeps an independent tint material")
	_check(absf(float(ghost_a_material.get_shader_parameter("defocus")) - far_target_defocus) <= 0.001, "first chromatic image broadens at the same focus")
	_check(absf(float(ghost_b_material.get_shader_parameter("defocus")) - far_target_defocus) <= 0.001, "second chromatic image broadens at the same focus")
	var ghost_a_tint := ghost_a_material.get_shader_parameter("psf_tint") as Color
	var ghost_b_tint := ghost_b_material.get_shader_parameter("psf_tint") as Color
	_check(ghost_a == null or ghost_a_tint.r > ghost_a_tint.b, "first chromatic PSF preserves its red tint")
	_check(ghost_b == null or ghost_b_tint.b > ghost_b_tint.r, "second chromatic PSF preserves its blue tint")

	view.queue_free()
	await process_frame
	_finish()


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in ["first_focus_control", "focus_novice_guide"]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _finish() -> void:
	print("SIRIUS POINT SOURCE FOCUS TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
