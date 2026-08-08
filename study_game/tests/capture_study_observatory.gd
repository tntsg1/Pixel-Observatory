extends SceneTree

const OUTPUT_DIR := "E:/godot/ai-game-0628/artifacts/study_godot"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var packed := load("res://main.tscn") as PackedScene
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await _capture("01-acquire.png")

	scene.stage = 1
	scene.eyepiece_mm = 25
	scene.focus_value = 72.0
	scene.tracking = true
	scene._show_stage(false)
	await process_frame
	await _capture("02-optical.png")

	scene.stage = 2
	scene.infrared_done = false
	scene.radio_done = false
	scene._show_stage(false)
	await process_frame
	await _capture("03-infrared.png")

	scene.infrared_done = true
	scene.dispersion_measure = 14.4
	scene._show_stage(false)
	await process_frame
	await _capture("04-radio.png")
	quit()


func _capture(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_DIR.path_join(file_name))
	print("CAPTURED: ", OUTPUT_DIR.path_join(file_name))
