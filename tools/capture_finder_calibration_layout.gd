extends SceneTree

const OUTPUT := "res://artifacts/current/finder_calibration_bottom_strip_zh.png"

var frames := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(6, true)
	gm.language_mode = "zh"
	gm.last_sky_aim = {}
	var sky: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames < 30:
		return
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT)
	print("FINDER CALIBRATION CAPTURE %s: %s" % ["PASS" if error == OK else "FAIL", ProjectSettings.globalize_path(OUTPUT)])
	quit(0 if error == OK else 1)
