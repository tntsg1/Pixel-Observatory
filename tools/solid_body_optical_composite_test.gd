extends SceneTree

const PLANETS := ["mercury", "venus", "saturn", "uranus", "neptune"]

var failures := 0
var game_manager: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	game_manager = root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager is available")
	if game_manager == null:
		_finish()
		return

	_test_planet_alpha_assets()
	_test_expanded_canvas_shader_contract()
	await _test_saturn_runtime_composite()
	_finish()


func _test_planet_alpha_assets() -> void:
	for object_id in PLANETS:
		var path := OpticalMediaRegistry.master_path(object_id)
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_check(image != null and not image.is_empty(), "%s master loads" % object_id)
		if image == null or image.is_empty():
			continue
		_check(image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH], "%s master has an alpha channel" % object_id)
		var width := image.get_width()
		var height := image.get_height()
		var corners := [
			image.get_pixel(0, 0).a,
			image.get_pixel(width - 1, 0).a,
			image.get_pixel(0, height - 1).a,
			image.get_pixel(width - 1, height - 1).a
		]
		_check(float(corners.max()) <= 0.01, "%s has transparent corners" % object_id)
		_check(image.get_pixel(width / 2, height / 2).a >= 0.98, "%s solid disk center is opaque" % object_id)


func _test_expanded_canvas_shader_contract() -> void:
	var shader_source := FileAccess.get_file_as_string("res://shaders/optical_target_state.gdshader")
	_check(
		shader_source.contains("COLOR = vec4(optical_sample.rgb * brightness, optical_sample.a);")
		and not shader_source.contains("optical_sample.a) * COLOR"),
		"expanded solid-body canvas does not mask transformed UVs with a second texture sample"
	)


func _test_saturn_runtime_composite() -> void:
	game_manager.new_game()
	game_manager.debug_jump_to_level(28, true)
	game_manager.selected_object_id = "saturn"
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame

	_check(bool(view.call("_is_solid_body_target", "saturn")), "Saturn uses the solid-body response")
	var target_focus := float(view.get("target_focus_value"))
	view.call("_set_focus_value", clampf(target_focus + 0.28, 0.0, 1.0))
	view.set("cond_cloud_atten", 0.82)
	var observation: Dictionary = view.get("observation")
	observation["quality"] = "Fair"
	observation["visual_effect"] = "dim"
	view.set("observation", observation)
	view.call("_refresh_target_sprite")
	view.call("_update_target_visuals")

	var main := view.get("main_sprite") as TextureRect
	var blur := view.get("blur_overlay") as TextureRect
	_check(main != null and main.modulate.a >= 0.98, "Saturn remains opaque at Fair quality under cloud")
	_check(blur == null or blur.modulate.a <= 0.001, "solid-body defocus does not cross-fade a translucent duplicate")
	if main != null:
		var material := main.material as ShaderMaterial
		_check(material != null, "Saturn uses the continuous optical-state shader")
		if material != null:
			_check(float(material.get_shader_parameter("blur_radius_px")) > 1.0, "defocus softens Saturn through the PSF shader")
		_check(main.modulate.r < 0.8, "cloud and Fair quality dim Saturn through RGB luminance")
		# With source center alpha and node alpha both opaque, a bright test
		# star behind the planet contributes zero to the final center pixel.
		var source := Image.load_from_file(
			ProjectSettings.globalize_path(OpticalMediaRegistry.master_path("saturn"))
		)
		var source_alpha := source.get_pixel(source.get_width() / 2, source.get_height() / 2).a
		var composed_alpha := source_alpha * main.modulate.a
		_check(composed_alpha >= 0.98, "a background star cannot bleed through Saturn's disk")

	view.queue_free()
	await process_frame


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("SOLID BODY OPTICAL COMPOSITE %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
