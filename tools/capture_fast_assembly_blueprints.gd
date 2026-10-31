extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_blueprint_reference"

var gm: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("FAST assembly capture requires GameManager.")
		quit(1)
		return
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		feedback.set("guidance_highlights", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(76, true)
	gm.reset_assembly()

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	current_scene = bench
	await _settle()
	_save("03_runtime_uninstalled_1024x768.png")

	await _install(bench, "radio_dish")
	_save("04_runtime_partial_1024x768.png")

	await _install(bench, "receiver")
	await _install(bench, "signal_processor")
	bench.call("_set_fast_blueprint_page", "signal")
	await _settle()
	_save("05_runtime_complete_1024x768.png")

	root.size = Vector2i(1280, 720)
	await _settle()
	_save("06_runtime_complete_1280x720.png")
	print("FAST ASSEMBLY BLUEPRINT CAPTURE PASS")
	quit(0)


func _install(bench: Control, part_type: String) -> void:
	bench.call("_select_flat_part", part_type)
	await _settle()
	bench.call("_install_at_slot", part_type)
	await create_timer(0.72).timeout
	await _settle()


func _settle() -> void:
	for _i in range(4):
		await process_frame
	await create_timer(0.08).timeout


func _save(file_name: String) -> void:
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Viewport texture unavailable while capturing %s." % file_name)
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Viewport image unavailable while capturing %s." % file_name)
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name]))
	if error != OK:
		push_error("Failed to save %s (error %d)." % [file_name, error])
		quit(1)
