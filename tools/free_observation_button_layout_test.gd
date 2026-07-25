extends SceneTree

# Regression for the compact free-observation action area at 1024x768.
# The mission return, two secondary actions, and equipment action must remain
# inside the existing right panel without overlapping at 1024x768.

const SAVE_PATH := "user://savegame.json"
const RIGHT_PANEL_RECT := Rect2(752.0, 106.0, 236.0, 594.0)

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists(SAVE_PATH)
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes(SAVE_PATH)
	await process_frame

	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is available")
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(5, true)
	gm.selected_object_id = "moon"
	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	for _frame in range(10):
		await process_frame

	var log_button := view.find_child("FreeObservationLogButton", true, false) as Button
	var back_button := view.find_child("FreeObservationBackButton", true, false) as Button
	var mission_button := view.find_child("FreeObservationMissionButton", true, false) as Button
	var equipment_button: Button = null
	for node in view.find_children("*", "Button", true, false):
		var candidate := node as Button
		if candidate != null and candidate.text.contains("Change Equipment"):
			equipment_button = candidate
			break

	_check(log_button != null, "logbook button exists")
	_check(back_button != null, "back-to-sky button exists")
	_check(mission_button != null, "return-to-mission button exists")
	if mission_button != null:
		_check(_inside_panel(mission_button.get_global_rect()), "return-to-mission button stays inside the right panel")
	if log_button != null and back_button != null:
		var log_rect := log_button.get_global_rect()
		var back_rect := back_button.get_global_rect()
		_check(_inside_panel(log_rect), "logbook button stays inside the right panel")
		_check(_inside_panel(back_rect), "back-to-sky button stays inside the right panel")
		_check(not log_rect.intersects(back_rect), "primary actions do not overlap")
		_check(back_rect.end.x <= 1024.0, "back-to-sky button stays on screen at 1024x768")
	if equipment_button != null and log_button != null and back_button != null:
		var equipment_rect := equipment_button.get_global_rect()
		_check(_inside_panel(equipment_rect), "equipment button stays inside the right panel")
		_check(not equipment_rect.intersects(log_button.get_global_rect())
			and not equipment_rect.intersects(back_button.get_global_rect()),
			"equipment action does not overlap the primary actions")
		if mission_button != null:
			_check(not mission_button.get_global_rect().intersects(log_button.get_global_rect())
				and not mission_button.get_global_rect().intersects(back_button.get_global_rect())
				and not mission_button.get_global_rect().intersects(equipment_rect),
				"return-to-mission action does not overlap other actions")

	view.queue_free()
	await process_frame
	_finish()


func _inside_panel(rect: Rect2) -> bool:
	return rect.position.x >= RIGHT_PANEL_RECT.position.x \
		and rect.position.y >= RIGHT_PANEL_RECT.position.y \
		and rect.end.x <= RIGHT_PANEL_RECT.end.x \
		and rect.end.y <= RIGHT_PANEL_RECT.end.y


func _finish() -> void:
	_restore_save()
	if failures == 0:
		print("FREE OBSERVATION BUTTON LAYOUT TEST PASS")
		quit(0)
	else:
		print("FREE OBSERVATION BUTTON LAYOUT TEST FAIL (%d)" % failures)
		quit(1)


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)
