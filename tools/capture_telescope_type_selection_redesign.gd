extends SceneTree

const OUTPUT_DIR := "res://artifacts/telescope_type_selection_redesign"

var gm: Node
var selector: Control


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Telescope type capture requires GameManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(80, false)
	await _open_selector("fast_radio")
	await _save("01_fast_recommended_en_1024x768.png")

	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	await _open_selector("dobsonian")
	await _save("02_dobsonian_owned_zh_1024x768.png")

	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	await _open_selector("fast_radio")
	await _save("03_fast_locked_catalog_en_1024x768.png")

	await _dispose_selector()
	print("TELESCOPE TYPE REDESIGN CAPTURE PASS")
	quit(0)


func _open_selector(family_id: String) -> void:
	await _dispose_selector()
	selector = load("res://scenes/telescope_types.tscn").instantiate() as Control
	root.add_child(selector)
	await process_frame
	selector.call("_select", family_id)
	for _frame in range(4):
		await process_frame
	await create_timer(0.24).timeout


func _dispose_selector() -> void:
	if selector == null or not is_instance_valid(selector):
		selector = null
		return
	selector.queue_free()
	selector = null
	await process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Viewport texture unavailable while capturing %s." % file_name)
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty() or not _has_visible_content(image):
		push_error("Capture %s is blank or visually empty." % file_name)
		quit(1)
		return
	var output := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := image.save_png(output)
	if error != OK:
		push_error("Failed to save %s (error %d)." % [file_name, error])
		quit(1)
		return
	print("CAPTURE ", output)


func _has_visible_content(image: Image) -> bool:
	var minimum := 1.0
	var maximum := 0.0
	var samples := 0
	var mean := 0.0
	var m2 := 0.0
	for y in range(0, image.get_height(), 24):
		for x in range(0, image.get_width(), 24):
			var color := image.get_pixel(x, y)
			var value := (color.r + color.g + color.b) / 3.0
			minimum = minf(minimum, value)
			maximum = maxf(maximum, value)
			samples += 1
			var delta := value - mean
			mean += delta / float(samples)
			m2 += delta * (value - mean)
	var variance := m2 / float(maxi(samples - 1, 1))
	return maximum - minimum > 0.08 and variance > 0.0002
