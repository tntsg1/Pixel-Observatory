extends SceneTree

# Graphical acceptance capture for the eyepiece magnification pass. Run without
# --headless so the viewport can be read back. The script leaves the editor
# untouched and restores the local save after it finishes.

const OUTPUT_DIR := "res://artifacts/magnification_acceptance"
const WATCHDOG_SECONDS := 75.0

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("MAGNIFICATION ACCEPTANCE CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		quit(2)
		return
	var watchdog := create_timer(WATCHDOG_SECONDS)
	watchdog.timeout.connect(func() -> void:
		push_error("MAGNIFICATION ACCEPTANCE CAPTURE TIMEOUT")
		_restore_save()
		quit(124)
	)
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("GameManager autoload is missing")
		_restore_save()
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	await _capture("01_refractor_20mm_jupiter.png", 10, "jupiter", "eyepiece_20mm")
	await _capture("02_refractor_10mm_jupiter.png", 10, "jupiter", "eyepiece_10mm")
	await _capture("03_cassegrain_40mm_jupiter.png", 51, "jupiter", "cassegrain_40mm_eyepiece")
	await _capture("04_cassegrain_12mm_jupiter.png", 51, "jupiter", "cassegrain_12mm_eyepiece")
	await _capture("05_extended_andromeda_10mm.png", 24, "andromeda", "eyepiece_10mm")

	print("MAGNIFICATION ACCEPTANCE CAPTURE %s: %s" % [
		"PASS" if failures == 0 else "FAIL",
		ProjectSettings.globalize_path(OUTPUT_DIR),
	])
	_restore_save()
	quit(0 if failures == 0 else 1)


func _capture(file_name: String, level_number: int, target_id: String, eyepiece_id: String) -> void:
	gm.new_game()
	gm.debug_jump_to_level(level_number, true)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	if not gm.progress["unlocked_parts"].has(eyepiece_id):
		gm.progress["unlocked_parts"].append(eyepiece_id)
	if not gm.equip_part(eyepiece_id):
		_fail("could not equip %s for %s" % [eyepiece_id, file_name])
		return
	gm.reset_assembly()
	for part_type_value in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type_value), 0)
	gm.set_collimation_score(100.0)
	gm.selected_object_id = target_id
	gm.selected_object_level = level_number

	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	root.add_child(view)
	await _settle(0.42)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await _settle(0.18)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	var guide_text := view.get("focus_guide_text") as Control
	if guide_text != null:
		guide_text.visible = false
	view.set("dark_adaptation", 1.0)
	view.set("drift_offset", Vector2.ZERO)
	view.set("drift_direction", Vector2.ZERO)
	if bool(view.get("requires_focus")):
		view.call("_set_focus_value", float(view.get("target_focus_value")))
	view.call("_advance_visual_smoothing", 1.0)
	await _settle(0.20)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("empty viewport for %s" % file_name)
	else:
		var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
		var error := image.save_png(path)
		if error != OK:
			_fail("could not save %s: %s" % [path, error_string(error)])
		else:
			print("CAPTURE ", path, " eyepiece=", eyepiece_id,
				" magnification=", gm.calculate_stats().get("magnification", 0.0))
	view.queue_free()
	await process_frame


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _fail(message: String) -> void:
	failures += 1
	push_error(message)
