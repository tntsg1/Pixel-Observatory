extends SceneTree

const OUTPUT := "res://artifacts/space_false_colour_mapping"

var scene: Control


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(67, true)

	scene = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	await _settle(0.28)
	var model: SpaceObservationModel = scene.get("model")
	model.acquired = true
	model.frames = [
		{"signal": 0.9, "cosmic_ray": false, "saturated": false, "kept": true},
		{"signal": 0.8, "cosmic_ray": true, "saturated": false, "kept": true},
		{"signal": 0.9, "cosmic_ray": false, "saturated": false, "kept": true},
		{"signal": 0.85, "cosmic_ray": false, "saturated": false, "kept": true},
	]
	model.frames_aligned = true
	model.cosmic_rays_removed = true
	model.stacked = true
	model.background_subtracted = true
	model.guide_locked = true
	model.pointing_error = 0.18
	model.drift_rate = 0.01
	model.thermal_locked = true
	model.cold_side_temp = 38.0
	model.segment_alignment = 1.0
	model.wavefront_error_nm = 90.0

	model.set_channel("R", "miri_dust")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "nir_short")
	_show_filter()
	await _settle(0.16)
	_save("01_scientific_mapping.png")

	model.set_channel("R", "nir_short")
	model.set_channel("B", "miri_dust")
	_show_filter()
	await _settle(0.16)
	_save("02_ambiguous_mapping.png")

	model.set_channel("R", "miri_dust")
	model.set_channel("B", "nir_short")
	scene.set("filter_preview_band", "nir_long")
	scene.call("_draw_filter")
	await _settle(0.12)
	_save("03_long_nir_grayscale.png")

	print("SPACE FALSE COLOUR CAPTURE PASS: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _show_filter() -> void:
	var stages: Array = scene.get("stages")
	scene.set("stage", stages.find("filter"))
	scene.call("_rebuild")


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _save(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	if image.save_png(path) != OK:
		push_error("Unable to save " + path)
