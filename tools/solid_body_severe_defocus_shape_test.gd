extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(11, true)
	gm.selected_object_id = "mars"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame

	var target_focus := float(view.get("target_focus_value"))
	var far_value := clampf(target_focus + 0.40, 0.0, 1.0)
	if absf(far_value - target_focus) < 0.30:
		far_value = clampf(target_focus - 0.40, 0.0, 1.0)
	view.call("_set_focus_value", far_value)
	view.call("_advance_visual_smoothing", 1.0)
	view.call("_update_target_visuals")

	var main := view.get("main_sprite") as TextureRect
	var material := main.material as ShaderMaterial if main != null else null
	_check(main != null and material != null, "Mars uses the solid-body optical material")
	if material != null:
		var screen_radius := float(material.get_shader_parameter("blur_radius_px")) * float(view.get("display_scale"))
		_check(float(material.get_shader_parameter("defocus_amount")) >= 0.90, "far focus reaches severe defocus")
		_check(screen_radius >= 120.0, "severe Mars defocus spreads beyond the sharp planet silhouette")
		_check(float(material.get_shader_parameter("brightness")) <= 0.42, "severe defocus lowers surface brightness")

	var shader_source := FileAccess.get_file_as_string("res://shaders/optical_target_state.gdshader")
	_check(shader_source.contains("severe_haze"), "severe defocus replaces the hard source limb with a soft haze")
	_check(shader_source.contains("flat_rgb"), "severe defocus removes identifiable surface detail")
	_check(shader_source.contains("severe_mix * 0.94"), "hard silhouette is almost entirely removed at the focus extreme")

	view.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


func _finish() -> void:
	print("SOLID BODY SEVERE DEFOCUS SHAPE TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
