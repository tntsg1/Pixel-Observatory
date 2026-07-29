extends SceneTree

const OUTPUT_DIR := "res://artifacts/main_menu_localization"

var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("main menu localization capture requires GameManager")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture("en", "01_main_menu_en.png")
	await _capture("zh", "02_main_menu_zh.png")
	print("MAIN MENU LOCALIZATION CAPTURE PASS")
	quit(0)


func _capture(language: String, file_name: String) -> void:
	gm.language_mode = language
	gm.progress["language_mode"] = language
	var menu := load("res://scenes/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var result := root.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Could not save " + path)
	menu.queue_free()
	current_scene = null
	await process_frame
	await process_frame
