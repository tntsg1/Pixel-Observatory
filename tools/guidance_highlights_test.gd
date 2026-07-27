extends SceneTree

# Accessibility regression for the opt-out guidance layer. Disabling guidance
# must remove tutorial spotlights and persistent lobby routes without removing
# normal interaction feedback or marking unseen tutorials as completed.

const SAVE_PATH := "user://savegame.json"
const ACCESSIBILITY_PATH := "user://accessibility.cfg"

var failures := 0
var file_backups: Dictionary = {}


func _initialize() -> void:
	_backup_file(SAVE_PATH)
	_backup_file(ACCESSIBILITY_PATH)
	await process_frame
	var feedback: Node = root.get_node_or_null("/root/InteractionFeedback")
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if feedback == null or gm == null:
		print("GUIDANCE HIGHLIGHTS TEST FAIL (autoloads missing)")
		_restore_files()
		quit(1)
		return

	await _test_disabled_tutorial_spotlights(feedback)
	await _test_lobby_guidance_visibility(feedback, gm)
	await _test_settings_control(feedback)
	_test_persistence(feedback)

	_restore_files()
	if failures == 0:
		print("GUIDANCE HIGHLIGHTS TEST PASS")
		quit(0)
	else:
		print("GUIDANCE HIGHLIGHTS TEST FAIL (%d)" % failures)
		quit(1)


func _test_disabled_tutorial_spotlights(feedback: Node) -> void:
	feedback.set_guidance_highlights_enabled(false)
	_check(not bool(feedback.guidance_highlights_enabled()), "guidance highlights can be disabled")

	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var target := Control.new()
	target.position = Vector2(120, 100)
	target.size = Vector2(160, 80)
	host.add_child(target)
	var key := "guidance_toggle_disabled_probe"
	var overlay: Variant = feedback.tutorial_highlight_once(target, key, "Hidden", host)
	_check(overlay == null, "disabled setting suppresses tutorial spotlight creation")
	_check(not bool(feedback.was_tutorial_seen(key)), "suppressed tutorial is not marked as seen")
	host.queue_free()
	await process_frame


func _test_lobby_guidance_visibility(feedback: Node, gm: Node) -> void:
	gm.new_game()
	gm.update_room_guidance_for_level()
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	var panel: Control = room.get("guidance_panel")
	var overlay: Control = room.get("guidance_overlay")
	var route_indicator: Control = room.get("route_edge_indicator")
	var toggle: Button = room.get("guidance_toggle_button")
	room.call("_update_room_guidance_panel")
	_check(panel != null and not panel.visible, "disabled setting hides the persistent lobby guidance panel")
	_check(overlay != null and not overlay.visible, "disabled setting hides lobby dimming and gold frame")
	_check(route_indicator != null and not route_indicator.visible, "disabled setting hides route arrows")
	_check(toggle != null and toggle.visible and toggle.text == "Show highlights", "lobby exposes a persistent restore-highlight button")

	room.call("_toggle_guidance_highlights")
	await process_frame
	_check(feedback.guidance_highlights_enabled() and panel.visible, "lobby button restores the current route without reloading")
	room.call("_update_room_guidance_panel")
	await process_frame
	var corner_frames := overlay.find_children("GuidanceCornerFrame*", "", true, false)
	_check(corner_frames.size() == 2, "route target uses two restrained corner-bracket layers")
	for frame_value in corner_frames:
		var frame := frame_value as Control
		_check(frame.get_child_count() == 8, "each route layer is made from eight short corner arms")
		for arm_value in frame.get_children():
			var arm := arm_value as ColorRect
			_check(arm.size.x < frame.size.x and arm.size.y < frame.size.y, "route highlight contains no full hard-frame edge")
	room.call("_toggle_guidance_highlights")
	await process_frame
	_check(not panel.visible and not overlay.visible and not route_indicator.visible, "disabling guidance updates an open lobby immediately")
	_check(toggle.visible and toggle.text == "Show highlights", "highlight control remains available after guidance is hidden")
	room.queue_free()
	await process_frame


func _test_settings_control(feedback: Node) -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("_on_settings")
	await process_frame
	var toggle := menu.find_child("GuidanceHighlightsToggle", true, false)
	_check(toggle is CheckButton, "Accessibility settings expose a Guidance Highlights toggle")
	if toggle is CheckButton:
		_check(not (toggle as CheckButton).button_pressed, "settings toggle reflects the disabled state")
	menu.queue_free()
	await process_frame

	feedback.set_guidance_highlights_enabled(true)
	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var target := Control.new()
	target.position = Vector2(80, 80)
	target.size = Vector2(120, 70)
	host.add_child(target)
	var enabled_overlay: Variant = feedback.tutorial_highlight_once(target, "guidance_toggle_enabled_probe", "Visible", host)
	_check(enabled_overlay is Control, "re-enabled setting allows tutorial spotlights")
	host.queue_free()
	await process_frame


func _test_persistence(feedback: Node) -> void:
	feedback.set_guidance_highlights_enabled(false)
	var config := ConfigFile.new()
	var loaded := config.load(ACCESSIBILITY_PATH) == OK
	_check(loaded, "guidance preference is written to accessibility.cfg")
	_check(not bool(config.get_value("accessibility", "guidance_highlights", true)), "disabled preference persists on disk")


func _backup_file(path: String) -> void:
	file_backups[path] = {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	}


func _restore_files() -> void:
	for path_value in file_backups.keys():
		var path := str(path_value)
		var backup: Dictionary = file_backups[path]
		if bool(backup.get("exists", false)):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(backup.get("bytes", PackedByteArray()))
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
