extends SceneTree

const OUTPUT_DIR := "res://artifacts/learning_card_refresh"


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_card(gm, teaching, "dobsonian_manual_altaz", "01_dobsonian_tutorial.png")
	await _capture_card(gm, teaching, "constellation_orion_constellation", "02_orion_constellation_tutorial.png")
	quit(0)


func _capture_card(gm: Node, teaching: Node, card_id: String, file_name: String) -> void:
	teaching.active_card_mode = "brief"
	teaching.active_card_id = card_id
	var node: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(node)
	current_scene = node
	for frame in range(12):
		await process_frame
	var path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path)
	node.queue_free()
	current_scene = null
	await process_frame
