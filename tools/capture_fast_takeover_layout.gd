extends SceneTree

const OUTPUT_PATH := "res://artifacts/fast_radio_upgrade/00_array_takeover_layout_fixed_1024x768.png"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST takeover capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/fast_radio_upgrade"))
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(76, true)

	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	current_scene = scene
	await create_timer(3.25).timeout
	for _i in range(4):
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("FAST takeover viewport image is unavailable.")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("FAST takeover capture failed with error %d." % error)
		quit(1)
		return
	print("FAST TAKEOVER LAYOUT CAPTURE PASS")
	quit(0)
