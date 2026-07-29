extends SceneTree
## Regression coverage for the menu-language/new-save ordering.
## Run with --user-data-dir pointing at an isolated test directory.

var failed := false
var gm: Node
var story_manager: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	story_manager = root.get_node_or_null("/root/StoryManager")
	if gm == null or story_manager == null:
		push_error("main menu new-game language test requires GameManager and StoryManager")
		quit(1)
		return

	# 1. A fresh menu choice must become the language of the new save and intro.
	await _reset_isolated_progress()
	_check(not FileAccess.file_exists(ProjectSettings.globalize_path("user://savegame.json")), "isolated test begins without a save")
	gm.cycle_language()
	_check(gm.language_mode == "zh", "menu language toggle selects Chinese before a game exists")
	gm.new_game()
	_check(gm.language_mode == "zh", "new game preserves the menu's Chinese selection")
	_check(str(gm.progress.get("language_mode", "")) == "zh", "new save stores Chinese language mode")
	_check(_saved_language() == "zh", "persisted new save stores Chinese language mode")
	_check(gm.text("New Game", "新游戏") == "新游戏", "new-game button copy resolves in Chinese")
	await _check_intro_screen("zh")

	# 2. An untouched fresh menu must still initialize in English.
	await _reset_isolated_progress()
	gm.new_game()
	_check(gm.language_mode == "en", "untouched fresh menu starts a new game in English")
	_check(str(gm.progress.get("language_mode", "")) == "en", "English new save stores English language mode")
	await _check_intro_screen("en")

	# 3. Returning from a Chinese save and continuing cannot change its locale.
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["current_level"] = 2
	gm.save()
	gm.go("menu")
	await process_frame
	var menu := current_scene
	_check(menu != null and menu.has_method("_on_continue"), "Chinese save returns to the main menu")
	if menu != null and menu.has_method("_on_continue"):
		menu.call("_on_continue")
	await process_frame
	_check(gm.language_mode == "zh", "continuing an existing Chinese save keeps Chinese")

	# 4. A later explicit menu choice wins when restarting, not the old save.
	gm.go("menu")
	await process_frame
	menu = current_scene
	_check(menu != null and menu.has_method("_on_language") and menu.has_method("_on_new_game"), "main menu exposes restart language actions")
	if menu != null and menu.has_method("_on_language"):
		menu.call("_on_language")
	_check(gm.language_mode == "en", "existing Chinese save can be explicitly switched to English on the menu")
	if menu != null and menu.has_method("_on_new_game"):
		menu.call("_on_new_game")
	await process_frame
	_check(gm.language_mode == "en", "restart uses the player's last explicit menu language")
	_check(str(gm.progress.get("language_mode", "")) == "en", "restart does not inherit the old Chinese save language")

	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
		await process_frame
	var audio_manager := root.get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("release_all_audio"):
		audio_manager.call("release_all_audio")
		await process_frame
		await create_timer(0.12).timeout
	print("MAIN MENU NEW GAME LANGUAGE TEST ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reset_isolated_progress() -> void:
	# This only targets the --user-data-dir supplied to this test command.
	var path := ProjectSettings.globalize_path("user://savegame.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	gm.progress = gm.default_progress()
	gm.language_mode = "en"
	story_manager.reset_flow()
	await process_frame


func _saved_language() -> String:
	var file := FileAccess.open(ProjectSettings.globalize_path("user://savegame.json"), FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return str(parsed.get("language_mode", "")) if parsed is Dictionary else ""


func _check_intro_screen(language: String) -> void:
	var started: bool = gm.try_story_event("intro", "observatory")
	await process_frame
	# A second transition in the same test run frees the previous story scene at
	# the end of the first frame; wait for the replacement's _ready() as well.
	await process_frame
	var story := current_scene
	_check(started and story != null, "%s new game enters the intro story" % language)
	if story == null:
		return
	var text_label := story.get_node_or_null("StoryDialogueText") as Label
	var speaker_label := story.get_node_or_null("StorySpeaker") as Label
	var next_button := story.get_node_or_null("StoryContinueButton") as Button
	var dialogue_is_localized := text_label != null and not text_label.text.is_empty()
	if language == "zh" and text_label != null:
		dialogue_is_localized = _contains_cjk(text_label.text)
	_check(dialogue_is_localized, "%s intro dialogue uses the selected language" % language)
	if language == "zh":
		_check(speaker_label != null and speaker_label.text == "玛雅", "Chinese intro Maya label uses the selected language")
	else:
		_check(speaker_label != null and not speaker_label.text.is_empty(), "English intro renders a speaker label")
	var button_is_localized := next_button != null and not next_button.text.is_empty()
	if language == "zh" and next_button != null:
		button_is_localized = _contains_cjk(next_button.text)
	_check(button_is_localized, "%s intro button uses the selected language" % language)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failed = true
		push_error("FAIL: " + message)


func _contains_cjk(value: String) -> bool:
	for index in value.length():
		var codepoint := value.unicode_at(index)
		if codepoint >= 0x4e00 and codepoint <= 0x9fff:
			return true
	return false
