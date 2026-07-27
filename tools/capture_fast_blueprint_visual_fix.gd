extends SceneTree

const OUTPUT_DIR := "res://artifacts/fast_blueprint_reference"

var gm: Node
var teaching: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	teaching = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		push_error("FAST visual capture requires GameManager and TeachingFlowManager.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	teaching.active_card_mode = "brief"
	teaching.active_card_id = "radio_signal_observing"
	var card := load("res://scenes/learning_card.tscn").instantiate() as Control
	root.add_child(card)
	current_scene = card
	await _settle()
	_save("07_radio_concept_official_blueprint_1024x768.png")
	card.queue_free()
	await _settle()

	gm.debug_jump_to_level(76, true)
	gm.reset_assembly()
	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	current_scene = bench
	await _settle()
	await _install(bench, "radio_dish")
	await _install(bench, "receiver")
	bench.call("_select_flat_part", "signal_processor")
	await _settle()
	_save("08_fast_parts_and_official_blueprint_1024x768.png")

	bench.queue_free()
	await process_frame
	print("FAST BLUEPRINT VISUAL FIX CAPTURE PASS")
	quit(0)


func _install(bench: Control, part_type: String) -> void:
	bench.call("_select_flat_part", part_type)
	await _settle()
	bench.call("_install_at_slot", part_type)
	await create_timer(0.75).timeout
	await _settle()


func _settle() -> void:
	for _i in range(5):
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
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save %s (error %d)." % [file_name, error])
		quit(1)
