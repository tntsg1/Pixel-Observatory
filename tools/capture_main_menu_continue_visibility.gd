extends SceneTree
## Graphical 1024x768 evidence for the packed no-save and resumable menu.

const OUTPUT_DIR := "res://artifacts/main_menu_continue_visibility"

var gm: Node
var menu: Control


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Main-menu visibility capture requires GameManager")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_remove_save()
	gm.progress = gm.default_progress()
	gm.language_mode = "en"
	await _show_menu()
	await _capture("01_no_save_1024x768.png")

	gm.new_game()
	gm.go("menu")
	await process_frame
	await process_frame
	menu = current_scene as Control
	await _capture("02_valid_save_1024x768.png")
	print("MAIN MENU CONTINUE VISIBILITY CAPTURE PASS")
	quit(0)


func _show_menu() -> void:
	var scene := load("res://scenes/main_menu.tscn") as PackedScene
	menu = scene.instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame


func _capture(file_name: String) -> void:
	await create_timer(0.18).timeout
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Could not save " + path)
		quit(1)
		return
	print("CAPTURE ", path)


func _remove_save() -> void:
	var path := ProjectSettings.globalize_path("user://savegame.json")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
