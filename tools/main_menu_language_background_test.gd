extends SceneTree

const SCREEN_RECT := Rect2(Vector2.ZERO, Vector2(1024, 768))
const ACTION_IDS := ["new", "settings", "language", "quit"]

var failed := false
var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("main menu localization test requires GameManager")
		quit(1)
		return

	gm.language_mode = "en"
	var menu := load("res://scenes/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	await process_frame
	_check_menu(menu, "main_menu_bg_1024.png", "English")

	gm.language_mode = "zh"
	menu.call("_on_language_changed")
	await process_frame
	await process_frame
	_check_menu(menu, "main_menu_bg_zh_1024.png", "Chinese")

	var background := menu.get_node_or_null("MainMenuBackground") as TextureRect
	_check(background != null and background.texture.get_width() == 1024, "Chinese runtime background matches the design width")
	_check(background != null and background.texture.get_height() == 768, "Chinese runtime background matches the design height")
	_check(
		background != null and background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"both languages use proportional centered scaling"
	)

	menu.queue_free()
	await process_frame
	print("MAIN MENU LANGUAGE BACKGROUND TEST ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check_menu(menu: Control, expected_file: String, label: String) -> void:
	var background := menu.get_node_or_null("MainMenuBackground") as TextureRect
	var language_indicator := menu.get_node_or_null("MainMenuLanguageIndicator") as Label
	_check(background != null, "%s menu has a named background" % label)
	_check(
		background != null and background.texture.resource_path.ends_with(expected_file),
		"%s menu loads %s" % [label, expected_file]
	)
	_check(language_indicator != null, "%s menu keeps the language action indicator node" % label)
	_check(
		language_indicator != null and language_indicator.visible == (label == "English"),
		"%s menu does not duplicate the baked language footer" % label
	)
	for action_id in ACTION_IDS:
		var button := menu.get_node_or_null("MainMenuAction_" + action_id) as Button
		_check(button != null, "%s %s action remains available" % [label, action_id])
		if button != null:
			_check(
				SCREEN_RECT.encloses(button.get_rect()),
				"%s %s action stays inside 1024x768" % [label, action_id]
			)
			_check(button.size.x >= 340.0 and button.size.y >= 50.0, "%s %s has a usable hit target" % [label, action_id])
	var continue_button := menu.get_node_or_null("MainMenuAction_continue") as Button
	_check(continue_button == null or SCREEN_RECT.encloses(continue_button.get_rect()), "%s Continue is either absent for a blank archive or remains on-screen" % label)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)
