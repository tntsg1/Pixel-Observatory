extends SceneTree

var room: Control
var frames := 0


func _initialize() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var gm := root.get_node_or_null("GameManager")
	if gm != null:
		gm.progress["current_level"] = 1
		gm.room_guidance_target = "telescope"
		gm.language_mode = "zh"
	room = (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 18:
		_save("res://artifacts/maya_npc_hall_greeting.png")
	if frames == 260:
		_save("res://artifacts/maya_npc_hall_at_station.png")
		quit()


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
