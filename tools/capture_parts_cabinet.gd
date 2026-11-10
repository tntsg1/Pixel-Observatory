extends SceneTree

const OUT_DIR := "user://"


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.progress["current_level"] = 8
	gm.progress["unlocked_parts"] = [
		"basic_tripod",
		"basic_mount",
		"starter_tube",
		"objective_60mm",
		"eyepiece_20mm",
		"basic_focus_knob",
		"basic_finder_scope",
		"eyepiece_10mm",
		"objective_100mm",
		"stable_mount"
	]
	gm.progress["selected_parts"]["objective"] = "objective_60mm"
	gm.progress["selected_parts"]["mount"] = "basic_mount"
	gm.save()

	var scene: Control = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.4).timeout
	_save("parts_top.png")

	var scroll: ScrollContainer = _find_scroll(scene)
	if scroll != null:
		scroll.scroll_vertical = 99999
	await create_timer(0.4).timeout
	_save("parts_bottom.png")

	gm.equip_part("objective_100mm")
	scene.queue_free()
	await process_frame
	scene = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await create_timer(0.4).timeout
	_save("parts_after_equip.png")
	print("saved parts_top.png, parts_bottom.png, parts_after_equip.png")
	quit(0)


func _find_scroll(node: Node) -> ScrollContainer:
	if node is ScrollContainer:
		return node
	for child in node.get_children():
		var result := _find_scroll(child)
		if result != null:
			return result
	return null


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + name)
