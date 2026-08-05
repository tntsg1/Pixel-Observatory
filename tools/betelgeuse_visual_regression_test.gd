extends SceneTree

const OUTPUT_PATH := "res://artifacts/betelgeuse_visual/01_betelgeuse_focused_master.png"
const CLEAR_MASTER := "res://assets/telescope_view/star_red_clear.png"
const OBSOLETE_PIXEL_STAR := "star_red_large.png"

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(34, true)
	gm.selected_object_id = "betelgeuse"
	view = (load("res://scenes/telescope_view.tscn") as PackedScene).instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await create_timer(0.30).timeout

	view.set("drift_enabled", false)
	view.set("drift_offset", Vector2.ZERO)
	view.call("_set_focus_value", float(view.get("target_focus_value")))
	view.set("hold_timer", float(view.get("hold_seconds_required")))
	view.set("observation", view.call("_evaluate"))
	view.call("_refresh_target_sprite")
	view.call("_update_target_visuals")
	await process_frame

	_check(str(view.get("current_sprite_path")) == CLEAR_MASTER, "Betelgeuse uses the registered clear observation master")
	var sprite := view.get("main_sprite") as TextureRect
	_check(sprite != null and sprite.texture != null, "focused Betelgeuse has a runtime texture")
	if sprite != null and sprite.texture != null:
		_check(sprite.texture.get_width() == 160 and sprite.texture.get_height() == 160, "runtime master is the 160x160 optical asset, not the 32px icon")
	var star_material := view.get("target_star_psf_material") as ShaderMaterial
	_check(star_material != null, "stellar point-spread material remains active")
	if star_material != null and star_material.shader != null:
		var code := star_material.shader.code
		_check(code.contains("vec4(sharp.rgb * brightness, sharp.a)"), "correct focus preserves the master's hot core and warm halo")
		_check(code.contains("mix(sharp_response, spread, spread_mix)"), "defocus still transitions continuously into the analytical PSF")

	var telescope_source := FileAccess.get_file_as_string("res://scripts/ui/telescope_view.gd")
	var story_source := FileAccess.get_file_as_string("res://scripts/ui/story_dialogue.gd")
	_check(not telescope_source.contains("\"betelgeuse\": \"res://assets/telescope_view/%s\"" % OBSOLETE_PIXEL_STAR), "telescope fallback no longer references the obsolete pixel star")
	_check(not story_source.contains("\"betelgeuse\": \"res://assets/telescope_view/%s\"" % OBSOLETE_PIXEL_STAR), "story visual no longer references the obsolete pixel star")

	if DisplayServer.get_name() != "headless":
		await _capture()
	view.queue_free()
	await process_frame
	_finish()


func _capture() -> void:
	await create_timer(0.30).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/betelgeuse_visual"))
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	_check(error == OK, "saved focused Betelgeuse visual evidence")
	if error == OK:
		print("CAPTURE ", ProjectSettings.globalize_path(OUTPUT_PATH))


func _finish() -> void:
	print("BETELGEUSE VISUAL REGRESSION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
