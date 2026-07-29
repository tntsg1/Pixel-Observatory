extends SceneTree

const OUTPUT_DIR := "res://artifacts/remote_desk_layering"
const STATES := [
	["01_desk_front.png", Vector2(850, 635), "up"],
	["02_desk_behind.png", Vector2(850, 575), "down"],
	["03_desk_left_pass.png", Vector2(720, 605), "right"],
]

var room: Control


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.debug_jump_to_level(66, true)
	room = (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	for _i in range(8):
		await process_frame

	for state_value in STATES:
		var state: Array = state_value
		room.call("_set_player_position", state[1])
		room.set("player_facing", str(state[2]))
		room.call("_set_player_animation_frame", str(state[2]), 0)
		room.call("_update_nearby")
		for _i in range(4):
			await process_frame
		_save(str(state[0]))

	room.call("_set_player_position", Vector2(721, 610))
	room.set("player_facing", "right")
	room.call("_update_nearby")
	room.call("_toggle_remote_instrument_console")
	for _i in range(8):
		await process_frame
	_save("04_remote_console_open.png")
	quit(0)


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var image := root.get_texture().get_image()
	var error := image.save_png(output) if image != null and not image.is_empty() else FAILED
	print("REMOTE DESK CAPTURE %s: %s" % ["PASS" if error == OK else "FAIL", output])
