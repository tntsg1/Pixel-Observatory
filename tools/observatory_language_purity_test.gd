extends SceneTree

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(76, true)
	gm.language_mode = "en"
	gm.update_room_guidance_for_level()
	_check(gm.room_guidance_title.contains("FAST Radio Telescope Console"),
		"English FAST route uses its English title")
	_check(gm.room_guidance_hint.contains("bottom-right console"),
		"English FAST route uses its English instruction")

	# Simulate the exact regression: an English route is cached before a Chinese
	# observatory scene is entered. The room must localize the cached route.
	gm.language_mode = "zh"
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	for _i in range(4):
		await process_frame
	_check(gm.room_guidance_title == "玛雅：FAST 射电望远镜控制台",
		"Chinese room entry refreshes the cached FAST title")
	_check(gm.room_guidance_hint.contains("使用右下角控制台"),
		"Chinese room entry refreshes the cached FAST instruction")
	_check(not gm.room_guidance_title.contains("Maya"),
		"Chinese FAST title contains no English character name")
	_check(not gm.room_guidance_hint.contains("bottom-right")
			and not gm.room_guidance_hint.contains("radio command link"),
		"Chinese FAST instruction contains no cached English sentence")
	var chinese_room_text := _collect_control_text(room)
	for forbidden in [
		"Maya", "Radio Telescope Console", "is ready for", "bottom-right",
		"Use the", "Move right", "Complete this mission", "INTERACT",
		"MISSIONS", "CLUB CREDITS", "MODE:"
	]:
		_check(not chinese_room_text.contains(forbidden),
			"Chinese observatory UI excludes English phrase: " + forbidden)

	gm.set_room_guidance_for_scene("assembly")
	_check(gm.room_guidance_title == "玛雅：组装台",
		"scene-specific assembly guidance is localized")
	_check(gm.room_guidance_hint == "前往组装台，按 E 键互动。",
		"scene-specific assembly instruction is localized")
	gm.set_room_guidance_for_scene("assembly", "before_focus")
	_check(gm.room_guidance_title == "玛雅：安装调焦旋钮",
		"focus prerequisite title is localized")
	_check(gm.room_guidance_hint.contains("安装调焦旋钮"),
		"focus prerequisite instruction is localized")

	gm.update_room_guidance_for_level()
	gm.language_mode = "en"
	gm.language_changed.emit()
	for _i in range(2):
		await process_frame
	_check(gm.room_guidance_title.contains("FAST Radio Telescope Console"),
		"switching back to English regenerates the current route")
	_check(not _contains_cjk(gm.room_guidance_title)
			and not _contains_cjk(gm.room_guidance_hint),
		"English FAST route contains no Chinese glyphs")
	_check(not _contains_cjk(_collect_control_text(room)),
		"English observatory controls contain no Chinese glyphs")

	room.queue_free()
	await process_frame
	_finish()


func _contains_cjk(value: String) -> bool:
	for codepoint in value.to_utf32_buffer():
		if (codepoint >= 0x3400 and codepoint <= 0x9FFF) \
				or (codepoint >= 0xF900 and codepoint <= 0xFAFF):
			return true
	return false


func _collect_control_text(node: Node) -> String:
	var values: Array[String] = []
	if node is Label:
		values.append((node as Label).text)
	elif node is Button:
		values.append((node as Button).text)
	for child in node.get_children():
		values.append(_collect_control_text(child))
	return "\n".join(values)


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	_restore_save()
	print("OBSERVATORY LANGUAGE PURITY TEST %s" % (
		"PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
