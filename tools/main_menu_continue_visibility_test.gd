extends SceneTree
## Main-menu resume availability regression.
## Run with --user-data-dir set to an isolated directory.

var failed := false
var gm: Node
var active_menu: Control
var save_manager: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	save_manager = root.get_node_or_null("/root/SaveManager")
	if gm == null or save_manager == null:
		_fail("GameManager and SaveManager are available")
		_finish()
		return

	await _test_no_save()
	await _test_valid_save()
	await _test_corrupt_and_incomplete_save()
	await _test_new_game_return_to_menu()
	await _cleanup()
	_finish()


func _test_no_save() -> void:
	_remove_save()
	gm.progress = gm.default_progress()
	gm.language_mode = "en"
	await _show_menu()
	_check(not gm.has_save(), "isolated bootstrap archive is not resumable")
	_check(_continue_button() == null, "no-save menu does not create a Continue button")
	_check(not active_menu.get("button_visuals").has("continue"), "no-save Continue has no hover or focus visual")
	_check(active_menu.get_node_or_null("MainMenuNoSaveReflowMask") != null, "no-save menu repacks the baked button rows")
	_check(active_menu.get_node_or_null("MainMenuPrinted_new") != null, "no-save menu keeps a visible New Game row")
	_check(_continue_button() == null or _continue_button().focus_mode == Control.FOCUS_NONE, "hidden Continue cannot receive focus")
	active_menu.call("_on_continue")
	await process_frame
	_check(current_scene == active_menu, "hidden Continue handler cannot navigate when invoked")


func _test_valid_save() -> void:
	var valid: Dictionary = gm.default_progress()
	valid["save_initialized"] = true
	valid["language_mode"] = "en"
	save_manager.save_progress(valid, false)
	gm.progress = valid.duplicate(true)
	await _show_menu()
	_check(gm.has_save(), "well-formed initialized campaign is resumable")
	_check(_continue_button() != null, "valid save displays Continue")
	_check(active_menu.get_node_or_null("MainMenuNoSaveReflowMask") == null, "valid save keeps the normal two-action layout")
	_check(active_menu.get("button_visuals").has("continue"), "valid Continue owns its usual hover feedback")


func _test_corrupt_and_incomplete_save() -> void:
	_remove_save()
	var corrupt := FileAccess.open(ProjectSettings.globalize_path("user://savegame.json"), FileAccess.WRITE)
	corrupt.store_string("{not valid json")
	corrupt.close()
	gm.progress = gm.default_progress()
	await _show_menu()
	_check(not save_manager.has_resumable_save(), "corrupted JSON is not resumable")
	_check(_continue_button() == null, "corrupted JSON safely falls back to New Game only")

	var incomplete := {"campaign_version": 1, "current_level": 1, "completed_levels": []}
	save_manager.save_progress(incomplete, false)
	await _show_menu()
	_check(not save_manager.has_resumable_save(), "incomplete progress payload is not resumable")
	_check(_continue_button() == null, "incomplete archive creates no clickable Continue")


func _test_new_game_return_to_menu() -> void:
	_remove_save()
	gm.progress = gm.default_progress()
	gm.language_mode = "zh"
	gm.new_game()
	_check(str(gm.progress.get("language_mode", "")) == "zh", "Chinese menu choice remains the new save language")
	_check(bool(gm.progress.get("save_initialized", false)), "new game marks its L1 campaign resumable")
	gm.go("menu")
	await process_frame
	await process_frame
	active_menu = current_scene as Control
	_check(active_menu != null, "new game can return to main menu")
	_check(_continue_button() != null, "newly created save shows Continue on return")
	_check(active_menu.get_node_or_null("MainMenuPrinted_new") == null, "resumable Chinese menu restores the standard row layout")


func _show_menu() -> void:
	if active_menu != null and is_instance_valid(active_menu):
		active_menu.queue_free()
		await process_frame
	var menu_scene := load("res://scenes/main_menu.tscn") as PackedScene
	active_menu = menu_scene.instantiate() as Control
	root.add_child(active_menu)
	current_scene = active_menu
	await process_frame
	await process_frame


func _continue_button() -> Button:
	return active_menu.get_node_or_null("MainMenuAction_continue") as Button if active_menu != null else null


func _remove_save() -> void:
	var path := ProjectSettings.globalize_path("user://savegame.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _cleanup() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	active_menu = null
	await process_frame
	await process_frame
	var audio_manager := root.get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("release_all_audio"):
		audio_manager.call("release_all_audio")
		await process_frame
		await create_timer(0.12).timeout


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("FAIL: " + message)


func _finish() -> void:
	print("MAIN MENU CONTINUE VISIBILITY TEST ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
