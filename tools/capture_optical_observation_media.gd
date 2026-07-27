extends SceneTree

const OUTPUT := "res://artifacts/optical_observation_media"

const REPRESENTATIVES := [
	["saturn", "01_planet_saturn_sharp.png"],
	["moon_crater_copernicus", "02_lunar_copernicus_sharp.png"],
	["albireo", "03_double_star_albireo_sharp.png"],
	["m13", "04_globular_m13_sharp.png"],
	["ring_nebula", "05_planetary_nebula_m57_sharp.png"],
	["lagoon_nebula", "06_emission_nebula_m8_sharp.png"],
	["whirlpool_galaxy", "07_face_on_m51_sharp.png"],
	["needle_galaxy", "08_edge_on_ngc4565_sharp.png"]
]

var gm: Node
var capture_failures := 0


func _initialize() -> void:
	var watchdog := create_timer(90.0)
	watchdog.timeout.connect(func() -> void:
		push_error("OPTICAL MEDIA CAPTURES TIMEOUT")
		quit(124)
	)
	if DisplayServer.get_name() == "headless":
		push_error("OPTICAL MEDIA CAPTURES REQUIRE A GRAPHICAL DISPLAY DRIVER")
		quit(2)
		return
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(28, true)
	_suppress_tutorials()
	for spec in REPRESENTATIVES:
		await _capture_target(str(spec[0]), str(spec[1]), "sharp")
	for object_id in ["m13", "lagoon_nebula"]:
		await _capture_target(object_id, "09_%s_defocused.png" % object_id, "defocused")
		await _capture_target(object_id, "10_%s_near_focus.png" % object_id, "near")
		await _capture_target(object_id, "11_%s_in_focus.png" % object_id, "sharp")
	await _capture_focus_result("m13", "12_m13_focus_result.png")
	await _capture_target("uranus", "13_uranus_complete_disk.png", "sharp")
	await _capture_target("dumbbell_nebula", "14_dumbbell_defocused.png", "defocused")
	await _capture_target("dumbbell_nebula", "15_dumbbell_near_focus.png", "near")
	await _capture_target("dumbbell_nebula", "16_dumbbell_sharp.png", "sharp")
	await _capture_target("saturn", "17_saturn_sharp_opaque.png", "sharp")
	await _capture_target("saturn", "18_saturn_fair_opaque.png", "fair")
	await _capture_target("saturn", "19_saturn_defocused_opaque.png", "defocused")
	await _capture_field_backdrop("dumbbell_nebula", Color(0.20, 0.22, 0.25), "20_dumbbell_radial_mask_gray.png")
	await _capture_field_backdrop("dumbbell_nebula", Color(0.86, 0.86, 0.84), "21_dumbbell_radial_mask_light.png")
	if capture_failures > 0:
		push_error("OPTICAL MEDIA CAPTURES FAIL: %d capture(s) were not saved" % capture_failures)
		quit(1)
		return
	print("OPTICAL MEDIA CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _capture_target(object_id: String, file_name: String, state: String) -> void:
	gm.selected_object_id = object_id
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	current_scene = view
	await _settle(0.26)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	view.set("focus_guide_active", false)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	var guide_text := view.get("focus_guide_text") as Control
	if guide_text != null:
		guide_text.visible = false
	var target_focus := float(view.get("target_focus_value"))
	var tolerance := maxf(float(view.get("focus_tolerance")), 0.025)
	match state:
		"defocused":
			var offset := 0.30 if target_focus <= 0.65 else -0.30
			view.call("_set_focus_value", clampf(target_focus + offset, 0.0, 1.0))
		"near":
			var offset := tolerance * 1.45 if target_focus <= 0.75 else -tolerance * 1.45
			view.call("_set_focus_value", clampf(target_focus + offset, 0.0, 1.0))
		"fair":
			view.call("_set_focus_value", target_focus)
			var fair_observation: Dictionary = view.get("observation")
			fair_observation["quality"] = "Fair"
			fair_observation["visual_effect"] = "dim"
			view.set("observation", fair_observation)
			view.set("cond_cloud_atten", 0.42)
			view.call("_refresh_target_sprite")
			view.call("_update_target_visuals")
			view.process_mode = Node.PROCESS_MODE_DISABLED
		_:
			view.call("_set_focus_value", target_focus)
	await _settle(0.22)
	_save(file_name)
	current_scene = null
	view.queue_free()
	await process_frame


func _capture_focus_result(object_id: String, file_name: String) -> void:
	gm.debug_jump_to_level(4, true)
	var teaching := root.get_node("/root/TeachingFlowManager")
	var observation := {
		"quality": "Fair",
		"success": true,
		"observation_mode": "telescope",
		"focus_error": 0.0,
		"focus_tolerance": 0.06,
		"effective_clarity": 74.0,
		"ratios": {"light": 0.82, "clarity": 0.88, "stability": 0.78}
	}
	gm.last_learning_card = teaching.make_mission_complete_payload(
		gm.current_level(),
		gm.get_object(object_id),
		observation,
		gm.calculate_stats()
	)
	teaching.active_card_mode = "complete"
	var card := load("res://scenes/learning_card.tscn").instantiate() as Control
	root.add_child(card)
	current_scene = card
	await _settle(0.28)
	_save(file_name)
	current_scene = null
	card.queue_free()
	await process_frame


func _capture_field_backdrop(object_id: String, backdrop: Color, file_name: String) -> void:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	current_scene = stage
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = backdrop
	stage.add_child(background)

	var texture := load(OpticalMediaRegistry.master_path(object_id)) as Texture2D
	var field := TextureRect.new()
	field.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	field.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	field.texture = texture
	field.position = Vector2(294, 166)
	field.size = Vector2(436, 436)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float radius = length(UV * 2.0 - vec2(1.0));
	float alpha = 1.0 - smoothstep(0.90, 1.0, radius);
	COLOR = vec4(source.rgb, source.a * alpha) * COLOR;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	field.material = material
	stage.add_child(field)

	var title := Label.new()
	title.text = "%s · runtime circular field mask" % object_id
	title.position = Vector2(294, 126)
	title.size = Vector2(436, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override(
		"font_color",
		Color(0.06, 0.07, 0.09) if backdrop.get_luminance() > 0.6 else Color(0.94, 0.96, 1.0)
	)
	stage.add_child(title)
	await _settle(0.18)
	_save(file_name)
	current_scene = null
	stage.queue_free()
	await process_frame


func _suppress_tutorials() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in [
		"first_focus_control",
		"first_averted_vision",
		"first_earth_drift",
		"focus_novice_guide"
	]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _save(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		capture_failures += 1
		push_error("Cannot capture %s with the headless display driver" % file_name)
		return
	await RenderingServer.frame_post_draw
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		capture_failures += 1
		push_error("Viewport texture was null for " + file_name)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		capture_failures += 1
		push_error("Viewport image was empty for " + file_name)
		return
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		capture_failures += 1
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
