extends SceneTree

const OUTPUT_DIR := "res://artifacts/observatory_ambient_motion"

var room: Control
var frames := 0
var loop_frame := 0


func _initialize() -> void:
	call_deferred("_boot")


func _boot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manager := root.get_node_or_null("GameManager")
	if manager != null:
		manager.call("new_game")
		manager.set("room_guidance_target", "")
	room = (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate() as Control
	root.add_child(room)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 18:
		_save("01_quiet_hall.png")
	if frames >= 18 and frames <= 138 and (frames - 18) % 10 == 0:
		_save("loop_%02d.png" % loop_frame)
		loop_frame += 1
	if frames == 42:
		var manager := root.get_node_or_null("GameManager")
		if manager != null:
			manager.set("room_guidance_target", "assembly")
	if frames == 150:
		_save("02_assembly_guided.png")
		print("OBSERVATORY AMBIENT MOTION CAPTURE PASS")
		quit(0)


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
