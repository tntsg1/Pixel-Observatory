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
	gm.debug_jump_to_level(5, true) # Jupiter mission
	gm.selected_object_id = "moon"
	gm.selected_object_level = int(gm.progress.get("current_level", 1))
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": 102.75,
		"altitude": 37.35,
		"view_mode": "naked_eye"
	}

	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	for _frame in range(8):
		await process_frame

	var button := view.find_child("ReturnToMissionTargetButton", true, false) as Button
	var panel := view.get("selected_panel_border") as Panel
	var detail := view.get("selected_detail") as Label
	var aim := view.get("aim_label") as Label
	var guidance := view.get("guidance_label") as Label
	_check(str(view.call("_active_observation_object_id")) == "moon", "free target remains selected on return")
	_check(bool(view.call("_is_free_selection")), "view identifies the free-observation state")
	_check(button != null and button.visible, "free state exposes the mission-target switch")
	_check(panel != null, "selected panel exists")
	if button != null and panel != null:
		_check(_contains(panel.get_global_rect(), button.get_global_rect()), "mission switch stays inside the selected panel")
		_check(not button.get_global_rect().intersects(aim.get_global_rect()), "mission switch does not overlap the live aim readout")
		_check(not button.get_global_rect().intersects(guidance.get_global_rect()), "mission switch does not overlap guidance")
	if detail != null and aim != null:
		_check(not detail.get_global_rect().intersects(aim.get_global_rect()), "target details do not overlap the live aim readout")
	if panel != null:
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and style.bg_color.a >= 0.9, "panel interior masks the old baked divider")

	var azimuth_before := float(view.get("telescope_azimuth"))
	var altitude_before := float(view.get("telescope_altitude"))
	if button != null:
		button.pressed.emit()
	await process_frame
	_check(str(view.call("_active_observation_object_id")) == "jupiter", "mission target becomes active")
	_check(str(gm.selected_object_id) == "jupiter", "mission target persists in GameManager")
	_check(not bool(view.call("_is_free_selection")), "free-observation state clears")
	_check(button != null and not button.visible, "mission switch hides after restoring the mission")
	_check(is_equal_approx(float(view.get("telescope_azimuth")), azimuth_before), "switch does not teleport azimuth")
	_check(is_equal_approx(float(view.get("telescope_altitude")), altitude_before), "switch does not teleport altitude")

	view.queue_free()
	await process_frame
	_restore_save()
	if failures == 0:
		print("SKY FREE OBSERVATION MISSION SWITCH TEST PASS")
		quit(0)
	else:
		print("SKY FREE OBSERVATION MISSION SWITCH TEST FAIL (%d)" % failures)
		quit(1)


func _contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end - Vector2.ONE * 0.01)


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
