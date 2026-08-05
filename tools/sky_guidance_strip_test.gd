extends SceneTree

const SAVE_PATH := "user://savegame.json"

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
	await process_frame

	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(5, true)

	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	for _frame in range(8):
		await process_frame

	var strip := view.find_child("SkyGuidanceUtilityStrip", true, false) as Control
	var toggle := view.find_child("SkyGuidanceStripToggle", true, false) as Button
	var banner := view.get("guidance_banner") as Label
	var controls := view.get("controls_help") as Label
	var caption := view.get("view_mode_caption") as Label
	_check(strip != null, "guidance strip exists")
	_check(toggle != null, "collapse handle exists")
	_check(strip != null and is_equal_approx(strip.position.y, 664.0), "strip starts expanded")
	_check(strip != null and is_equal_approx(strip.size.y, 74.0), "expanded strip keeps full guidance height")
	_check(toggle != null and Rect2(88, 664, 630, 74).encloses(toggle.get_global_rect()), "handle stays inside the frame-safe strip")

	if toggle != null:
		toggle.pressed.emit()
	view.call("_apply_guidance_strip_state", false)
	await process_frame
	_check(bool(view.get("guidance_strip_collapsed")), "click collapses the strip")
	_check(strip != null and is_equal_approx(strip.position.y, 716.0), "collapsed strip moves to the frame edge")
	_check(strip != null and is_equal_approx(strip.size.y, 22.0), "collapsed strip leaves only a narrow handle rail")
	_check(banner != null and banner.modulate.a <= 0.01, "guidance text hides when collapsed")
	_check(controls != null and controls.modulate.a <= 0.01, "keyboard help hides when collapsed")
	_check(caption != null and caption.visible, "current view caption remains visible")
	_check(toggle != null and toggle.text == "▲", "handle communicates expand action")

	if toggle != null:
		toggle.pressed.emit()
	view.call("_apply_guidance_strip_state", false)
	await process_frame
	_check(not bool(view.get("guidance_strip_collapsed")), "second click expands the strip")
	_check(strip != null and is_equal_approx(strip.position.y, 664.0), "expanded strip returns to its original position")
	_check(banner != null and banner.modulate.a >= 0.99, "guidance text returns after expansion")

	view.queue_free()
	await process_frame
	_restore_save()
	if failures == 0:
		print("SKY GUIDANCE STRIP TEST PASS")
		quit(0)
	else:
		print("SKY GUIDANCE STRIP TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
