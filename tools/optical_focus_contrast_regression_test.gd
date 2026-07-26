extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return

	gm.new_game()
	gm.language_mode = "en"
	# Level 4 is the focus-only teaching harness: it avoids collimation blur,
	# so this test isolates the visual response of the focus control itself.
	gm.debug_jump_to_level(4, true)
	gm.selected_object_id = "ring_nebula"

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	for index in range(2):
		await process_frame
	print(
		"FOCUS TEST CONTEXT level=", gm.progress.get("current_level", -1),
		" selected=", gm.selected_object_id,
		" mode=", view.get("observation_mode"),
		" requires_focus=", view.get("requires_focus"),
		" object=", (view.get("selected_object") as Dictionary).get("id", "")
	)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	var blur_overlay := view.get("blur_overlay") as TextureRect
	var main_sprite := view.get("main_sprite") as TextureRect
	var star_materials: Array = view.get("star_field_psf_materials")
	var star_nodes: Array = view.get("star_layer_nodes")
	_check(blur_overlay != null, "extended target creates a same-source defocus layer")
	_check(main_sprite != null, "extended target creates a sharp source layer")
	_check(not star_materials.is_empty(), "real background stars use a shared optical PSF")
	_check(not star_nodes.is_empty(), "real catalog stars are present in the eyepiece")
	if blur_overlay == null or main_sprite == null or star_materials.is_empty():
		_finish()
		return

	var target := float(view.get("target_focus_value"))
	var tolerance := maxf(float(view.get("focus_tolerance")), 0.02)
	var blur_material := blur_overlay.material as ShaderMaterial
	_check(blur_material != null, "defocus layer has an optical PSF material")
	if blur_material == null:
		_finish()
		return

	view.call("_set_focus_value", target)
	view.call("_advance_visual_smoothing", 1.0)
	var sharp_radius := float(blur_material.get_shader_parameter("blur_radius_px"))
	var sharp_blur_alpha := blur_overlay.modulate.a
	var sharp_star_defocus := float((star_materials[0] as ShaderMaterial).get_shader_parameter("defocus"))

	view.call("_set_focus_value", clampf(target + tolerance * 1.45, 0.0, 1.0))
	view.call("_advance_visual_smoothing", 1.0)
	var near_radius := float(blur_material.get_shader_parameter("blur_radius_px"))
	var near_blur_alpha := blur_overlay.modulate.a

	var far_value := clampf(target + 0.30, 0.0, 1.0)
	if absf(far_value - target) < 0.20:
		far_value = clampf(target - 0.30, 0.0, 1.0)
	view.call("_set_focus_value", far_value)
	view.call("_advance_visual_smoothing", 1.0)
	var far_radius := float(blur_material.get_shader_parameter("blur_radius_px"))
	var far_brightness := float(blur_material.get_shader_parameter("brightness"))
	var far_blur_alpha := blur_overlay.modulate.a
	var far_sharp_alpha := main_sprite.modulate.a
	var far_star_defocus := float((star_materials[0] as ShaderMaterial).get_shader_parameter("defocus"))
	print(
		"FOCUS TEST VALUES target=", target,
		" tolerance=", tolerance,
		" radii=", [sharp_radius, near_radius, far_radius],
		" blur_alpha=", [sharp_blur_alpha, near_blur_alpha, far_blur_alpha],
		" sharp_alpha_far=", far_sharp_alpha,
		" brightness_far=", far_brightness,
		" focus_error=", view.get("focus_error"),
		" blur_weight=", view.get("blur_weight")
	)

	_check(sharp_blur_alpha <= 0.001, "exact focus exposes only the sharp master")
	_check(near_radius > sharp_radius and near_blur_alpha > sharp_blur_alpha, "near-focus response is continuous")
	_check(far_radius >= 30.0, "severe defocus uses a visibly broad PSF")
	_check(far_brightness <= 0.50, "severe defocus lowers diffuse surface brightness")
	_check(far_blur_alpha > far_sharp_alpha * 4.0, "severe defocus hides the high-frequency sharp layer")
	_check(sharp_star_defocus <= 0.01, "background stars share the target's sharp focal plane")
	_check(far_star_defocus >= 0.90, "background stars defocus together with the selected target")
	if not star_materials.is_empty() and not star_nodes.is_empty():
		_check(
			(star_materials[0] as ShaderMaterial) == (star_nodes[0] as ColorRect).material,
			"background PSF is applied to eyepiece star nodes"
		)
	for object_id in ["ring_nebula", "dumbbell_nebula", "lagoon_nebula", "m13", "sombrero_galaxy"]:
		_check(
			not bool(view.call("_is_solid_body_target", object_id)),
			"%s remains in the extended-target focus pipeline" % object_id
		)
	for object_id in ["saturn", "uranus", "neptune"]:
		_check(
			bool(view.call("_is_solid_body_target", object_id)),
			"%s remains in the opaque solid-body focus pipeline" % object_id
		)

	var source := FileAccess.get_file_as_string("res://scripts/ui/telescope_view.gd")
	_check(source.count("texture(TEXTURE, uv + step_px") >= 20, "extended-field PSF uses a dense kernel instead of sparse ghosts")
	_check(source.contains("energy_peak"), "point-source PSF spreads energy instead of scaling sharp squares")
	_finish()


func _finish() -> void:
	if failures == 0:
		print("OPTICAL FOCUS CONTRAST REGRESSION TEST PASS")
		quit(0)
	else:
		print("OPTICAL FOCUS CONTRAST REGRESSION TEST FAIL: ", failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
