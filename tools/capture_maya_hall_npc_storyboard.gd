extends SceneTree

const OUTPUT_DIR := "res://artifacts/maya_npc_hall_storyboard"

var room: Control
var maya: MayaHallNPC
var game_manager: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	game_manager = root.get_node_or_null("GameManager")
	if game_manager == null:
		push_error("GameManager unavailable")
		quit(1)
		return
	game_manager.progress["current_level"] = 1
	game_manager.progress["graduation_seen"] = false
	game_manager.room_guidance_target = ""
	game_manager.language_mode = "zh"
	room = (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	maya = room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	if maya == null:
		push_error("MayaHallNPC unavailable")
		quit(1)
		return
	# Storyboard frames are controlled explicitly below. Disable the delayed
	# tutorial route so it cannot replace a staged state halfway through capture.
	maya.set_process(false)
	maya.set("_route_target_provider", Callable())

	await _capture("01_greeting", Vector2(512, 292), Vector2(512, 620), "greeting", "telescope")
	await _capture("02_leading_to_assembly", Vector2(548, 390), Vector2(500, 620), "guide_assembly", "assembly")
	await _capture("03_wrong_way", Vector2(600, 430), Vector2(260, 540), "route_wrong_way", "assembly")
	await _capture("04_at_assembly", Vector2(701, 510), Vector2(620, 575), "arrive_assembly", "assembly")
	await _capture("05_result_saved", Vector2(322, 590), Vector2(410, 620), "journal_saved", "journal")
	game_manager.progress["graduation_seen"] = true
	await _capture("06_graduated_companion", Vector2(612, 496), Vector2(520, 620), "free_near", "")
	print("MAYA HALL STORYBOARD CAPTURE: PASS")
	quit(0)


func _capture(
	file_stem: String,
	maya_position: Vector2,
	player_position: Vector2,
	state_id: String,
	guidance_target: String
) -> void:
	game_manager.room_guidance_target = guidance_target
	room.set("player_pos", player_position)
	room.call("_set_player_position", player_position)
	room.call("_update_room_guidance_panel")
	maya.set("_route_enabled", false)
	maya.set("_path", PackedVector2Array())
	maya.set("_path_index", 0)
	maya.set("_destination_id", "")
	maya.set("_arrived", true)
	maya.set("_moving", false)
	maya.position = maya_position
	maya.call("_face_toward", player_position)
	maya.call("_show_state", state_id, true)
	await create_timer(0.30).timeout
	await process_frame
	var path := "%s/%s.png" % [OUTPUT_DIR, file_stem]
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))
