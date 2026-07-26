extends SceneTree

var failures := 0
var gm: Node
var touch_input: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	touch_input = root.get_node_or_null("/root/TouchInput")
	_check(gm != null, "GameManager is available")
	_check(touch_input != null, "TouchInput is available")
	if gm == null:
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(31, false)
	gm.selected_object_id = "sombrero_galaxy"

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await process_frame
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)

	_test_registry_and_rendering(view)
	_test_continuous_hold(view)
	_test_touch_and_drift_isolation(view)
	_test_continuous_defocus(view)

	Input.action_release("dodge")
	Input.action_release("move_right")
	if touch_input != null:
		touch_input.set("boost_held", false)
	view.queue_free()
	await process_frame
	_finish()


func _test_registry_and_rendering(view: Control) -> void:
	var master := OpticalMediaRegistry.master_path("sombrero_galaxy")
	_check(master != "", "Sombrero has a registry clean master")
	_check(str(view.call("_guide_thumbnail_path", "sombrero_galaxy")) == master, "Field Guide uses the registry master before legacy state art")
	_check(str(view.call("_target_render_mode", "sombrero_galaxy")) == "extended_field", "Sombrero is treated as an extended field")
	_check(str(view.call("_target_render_mode", "jupiter")) == "transparent_sprite", "Jupiter remains a transparent sprite")
	var main_sprite := view.get("main_sprite") as TextureRect
	var main_material := main_sprite.material as ShaderMaterial if main_sprite != null else null
	_check(
		main_material != null and main_material.shader.code.contains("feather_inner"),
		"extended-field master receives circular feathering instead of a rectangular edge"
	)


func _test_continuous_hold(view: Control) -> void:
	var guide := view.get("averted_vision_guide") as Control
	_check(guide != null, "L31 has an averted-vision gaze guide")
	Input.action_press("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.62)
	_check(not bool(view.get("averted_vision_confirmed")), "0.62 seconds cannot confirm the technique")
	_check(float(view.get("averted_hold_visual")) > 0.45, "hold progress updates continuously")
	view.call("_update_averted_vision_guide", 0.62)
	_check(not bool(view.get("averted_vision_confirmed")), "1.24 seconds remains below the 1.25-second threshold")
	view.call("_update_averted_vision_guide", 0.02)
	_check(bool(view.get("averted_vision_confirmed")), "continuous 1.25-second hold confirms averted vision")
	_check(guide != null and float(guide.get("cursor_progress")) > 0.95, "gaze cursor reaches the side marker")
	var evaluated: Dictionary = view.call("_evaluate")
	var failure: Dictionary = evaluated.get("technique_failure", {})
	_check(str(failure.get("code", "")) != "averted_vision", "evaluation receives only the confirmed technique state")
	Input.action_release("dodge")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_update_averted_vision_guide", 0.20)
	_check(float(view.get("averted_hold_visual")) > 0.0, "release visibly decays progress before reset")
	view.call("_update_averted_vision_guide", 0.40)
	_check(not bool(view.get("averted_vision_confirmed")) and is_zero_approx(float(view.get("averted_hold_visual"))), "release fully resets the confirmation")


func _test_touch_and_drift_isolation(view: Control) -> void:
	touch_input.set("boost_held", true)
	view.call("_advance_dark_adaptation", 0.01)
	_check(bool(view.get("averted_vision_active")), "TouchInput boost holds averted vision")
	touch_input.set("boost_held", false)
	view.call("_advance_dark_adaptation", 0.01)

	view.set("drift_enabled", true)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2(1.0, 0.0))
	Input.action_press("dodge")
	Input.action_press("move_right")
	view.call("_advance_dark_adaptation", 0.01)
	view.call("_advance_drift", 0.50)
	_check((view.get("drift_offset") as Vector2).is_zero_approx(), "WASD and natural drift do not move a centered target during the side-gaze hold")
	Input.action_release("move_right")
	Input.action_release("dodge")
	view.call("_advance_dark_adaptation", 0.01)


func _test_continuous_defocus(view: Control) -> void:
	var blur_overlay := view.get("blur_overlay") as TextureRect
	var main_sprite := view.get("main_sprite") as TextureRect
	_check(blur_overlay != null, "registry master has a same-source optical defocus layer")
	if blur_overlay == null or main_sprite == null:
		return
	view.set("visual_focus_error", 0.85)
	view.set("blur_weight", 1.0)
	view.call("_update_target_visuals")
	var material := blur_overlay.material as ShaderMaterial
	_check(material != null, "defocus layer owns a low-cost optical state shader")
	if material != null:
		_check(float(material.get_shader_parameter("blur_radius_px")) >= 12.0, "strong defocus removes high-frequency detail")
		_check(float(material.get_shader_parameter("brightness")) < 0.70, "defocus also spreads and dims surface brightness")
	_check(blur_overlay.modulate.a > main_sprite.modulate.a, "defocused same-source layer dominates instead of a ghost-only effect")


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("L31 SOMBRERO AVERTED VISION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
