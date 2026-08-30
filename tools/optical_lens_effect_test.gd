extends SceneTree

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_restore_save()
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	if not gm.progress["unlocked_parts"].has("basic_finder_scope"):
		gm.progress["unlocked_parts"].append("basic_finder_scope")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		gm.install_part(part_type, 0)

	_test_shader()
	await _test_sky_observation()
	await _test_telescope_view()
	await _test_averted_vision_ui()
	_test_newtonian_part_compatibility()
	print("OPTICAL LENS EFFECT TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	_restore_save()
	quit(0 if failures == 0 else 1)


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _test_shader() -> void:
	var path := "res://shaders/optical_lens.gdshader"
	_check(ResourceLoader.exists(path), "full-colour optical lens shader exists")
	var shader := load(path) as Shader
	_check(shader != null, "optical lens shader loads")
	if shader != null:
		_check(not shader.code.contains("uniform float monochrome"), "ordinary lens does not expose a monochrome conversion")
		_check(shader.code.contains("vec3(red, green, blue)"), "ordinary lens samples and preserves RGB channels")


func _test_sky_observation() -> void:
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var overlay := view.get("optical_lens_overlay") as ColorRect
	var reticle := view.get("scope_reticle_layer") as Control
	_check(overlay != null, "Sky Observation owns one optical glass overlay")
	_check(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "optical glass never blocks mouse or touch input")
	var star_pool: Array = view.get("star_pool")
	var object_icons: Dictionary = view.get("object_icons")
	_check(not star_pool.is_empty() and overlay != null and (star_pool[0] as Control).z_index < overlay.z_index, "background stars are curved below the optical glass")
	if not object_icons.is_empty():
		var icon := object_icons.values()[0] as Control
		_check(overlay != null and overlay.z_index < icon.z_index, "clickable celestial objects stay aligned above curved glass")
	_check(overlay != null and reticle != null and overlay.z_index < reticle.z_index, "reticle remains straight and readable above curved glass")
	var curvatures: Array[float] = []
	for mode in ["naked_eye", "finder", "telescope"]:
		view.call("_set_view_mode", mode)
		await create_timer(0.32).timeout
		var material := view.get("optical_lens_material") as ShaderMaterial
		curvatures.append(float(material.get_shader_parameter("curvature")))
		_check(float(material.get_shader_parameter("circular_lens")) == 0.0, "%s search view uses the rectangular observation-window lens" % mode)
	_check(curvatures[0] < curvatures[1] and curvatures[1] < curvatures[2], "Eye < Finder < Scope optical curvature")
	_check(is_equal_approx(float(view.get("fov_x")), 6.0), "mode switching keeps the existing Scope FOV target")
	view.queue_free()
	await process_frame


func _test_telescope_view() -> void:
	gm.selected_object_id = str(gm.current_target_object_id())
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var overlay := view.find_child("OpticalLensOverlay", true, false) as ColorRect
	_check(overlay != null, "detailed Telescope View owns a curved optical glass layer")
	if overlay != null:
		var material := overlay.material as ShaderMaterial
		print("  info: telescope mode=", view.get("observation_mode"),
			" path=", overlay.get_path(),
			" circular=", material.get_shader_parameter("circular_lens") if material != null else "no material",
			" curvature=", material.get_shader_parameter("curvature") if material != null else "no material")
		_check(material != null and float(material.get_shader_parameter("circular_lens")) == 1.0, "detailed Telescope View uses a circular lens")
		_check(material != null and float(material.get_shader_parameter("curvature")) >= 0.05, "detailed telescope curvature is visible but restrained")
		_check(material != null and float(material.get_shader_parameter("lens_rim_strength")) >= 0.15, "detailed telescope has a visible full-colour fisheye rim")
		_check(material != null and float(material.get_shader_parameter("lens_caustic_strength")) >= 0.10, "detailed telescope has subtle moving lens caustics")
		_check(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "detailed lens does not block controls")
	view.queue_free()
	await process_frame


func _test_averted_vision_ui() -> void:
	gm.debug_jump_to_level(31, false)
	gm.selected_object_id = "sombrero_galaxy"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var guide := view.find_child("AvertedVisionGuide", true, false) as Control
	_check(guide != null and bool(guide.get("enabled")), "averted-vision lesson draws a visible side-gaze marker")
	var guide_parent := guide.get_parent() if guide != null else null
	var occluder_clipper := view.find_child("LensRingOccluderClipper", true, false)
	_check(
		guide_parent != null and occluder_clipper != null and guide.get_index() > occluder_clipper.get_index(),
		"side-gaze marker renders above the barrel occluder instead of being covered by it"
	)
	_check(int(guide.get("z_index")) > 0, "side-gaze marker has an explicit foreground render layer")
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)
	Input.action_press("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.70)
	_check(guide != null and bool(guide.get("active")) and float(guide.get("hold_visual")) > 0.0, "holding averted vision drives the visual progress ring")
	_check(not bool(view.get("averted_vision_confirmed")), "a short Shift press does not satisfy averted vision")
	view.call("_update_averted_vision_guide", 0.56)
	_check(bool(view.get("averted_vision_confirmed")), "1.25 seconds of continuous side-gaze confirms the technique")
	_check(float(guide.get("cursor_progress")) > 0.8, "gaze cursor travels from the target toward the side marker")
	Input.action_release("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.60)
	_check(not bool(view.get("averted_vision_confirmed")), "releasing Shift decays and resets averted vision")
	_check(
		str(view.call("_guide_thumbnail_path", "sombrero_galaxy")) == OpticalMediaRegistry.master_path("sombrero_galaxy"),
		"Field Guide prioritizes the registry clean master"
	)
	_check(str(view.call("_target_render_mode", "sombrero_galaxy")) == "extended_subject", "deep-sky registry art uses a true-alpha science subject behind the fixed lens mask")
	_check(str(view.call("_target_render_mode", "jupiter")) == "transparent_sprite", "planet sprites keep transparent-sprite rendering")
	# "Change Equipment" used to teleport straight into the Parts Cabinet from
	# mid-observation; that shortcut was removed - swapping gear now always
	# means walking back to the cabinet like any other destination.
	var equipment_button: Button
	for node in view.find_children("*", "Button", true, false):
		if str((node as Button).text).contains("Change Equipment"):
			equipment_button = node as Button
			break
	_check(equipment_button == null, "detailed telescope view no longer offers a direct Change Equipment shortcut")
	view.queue_free()
	await process_frame


func _test_newtonian_part_compatibility() -> void:
	var objective: Dictionary = gm.get_part("objective_100mm")
	_check(str(objective.get("telescope_family", "")) == "refractor", "100mm objective is correctly restricted to refractors")
	gm.debug_jump_to_level(31, false)
	_check(not gm.is_part_compatible_with_current_level(objective), "Newtonian missions reject the refractor objective lens")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
