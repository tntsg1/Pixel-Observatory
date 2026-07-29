extends SceneTree
## Graphical proof for the first-save menu locale ordering.
## Run with an isolated --user-data-dir and a graphical renderer.

const OUTPUT_PATH := "res://artifacts/main_menu_new_game_language/01_new_game_intro_zh.png"


func _initialize() -> void:
	await process_frame
	var game_manager := root.get_node_or_null("/root/GameManager")
	var story_manager := root.get_node_or_null("/root/StoryManager")
	if game_manager == null or story_manager == null:
		push_error("Chinese new-game capture requires GameManager and StoryManager")
		quit(1)
		return

	var save_path := ProjectSettings.globalize_path("user://savegame.json")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	game_manager.progress = game_manager.default_progress()
	game_manager.language_mode = "en"
	story_manager.reset_flow()
	game_manager.cycle_language()
	if game_manager.language_mode != "zh":
		push_error("The fresh-menu language selection did not switch to Chinese")
		quit(1)
		return
	game_manager.new_game()
	if not game_manager.try_story_event("intro", "observatory"):
		push_error("The new Chinese game did not open its intro story")
		quit(1)
		return
	for _frame in 8:
		await process_frame
	var output_directory := ProjectSettings.globalize_path("res://artifacts/main_menu_new_game_language")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save Chinese new-game intro capture: %s" % OUTPUT_PATH)
		quit(1)
		return
	print("MAIN MENU NEW GAME CHINESE CAPTURE PASS: ", ProjectSettings.globalize_path(OUTPUT_PATH))
	quit()
