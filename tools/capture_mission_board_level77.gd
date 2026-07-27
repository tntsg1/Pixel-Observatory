extends SceneTree

const OUTPUT := "res://artifacts/mission_board_layering/level77_1024x768.png"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Mission board capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/mission_board_layering"))
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(77, true)
	var room := load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(room)
	current_scene = room
	for _i in range(5):
		await process_frame
	room.call("_open_mission_board")
	for _i in range(5):
		await process_frame
	# Wait for InteractionFeedback.page_enter to finish so this records the
	# settled modal hierarchy rather than a partially transparent transition.
	await create_timer(0.72).timeout
	var texture := root.get_texture()
	if texture == null:
		push_error("Viewport texture unavailable.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image unavailable.")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not save mission board capture.")
		quit(1)
		return
	print("MISSION BOARD LAYERING CAPTURE PASS")
	quit(0)
