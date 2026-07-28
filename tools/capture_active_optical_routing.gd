extends SceneTree

const OUTPUT_PATH := "res://artifacts/graduation_last_ten/06_dobsonian_central_pad_after_fast_1024x768.png"
const TIMEOUT_SECONDS := 25.0

var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(func() -> void:
		if not finished:
			push_error("ACTIVE OPTICAL ROUTING CAPTURE TIMEOUT")
			_finish(1)
	)
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var mission_manager: Node = root.get_node_or_null("/root/MissionManager")
	if gm == null:
		_finish(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = 85
	gm.progress["completed_levels"] = (mission_manager.get("campaign_order") as Array).duplicate() if mission_manager != null else [85]
	gm.progress["program_completed"] = true
	gm.progress["graduation_seen"] = true
	gm.progress["graduation_pending"] = false
	gm._normalize_progress()
	gm.progress["current_level"] = 85
	gm.select_assembly_family("dobsonian")
	gm.progress["assembly_state"] = {
		"mount": {"installed": true, "alignment_score": 94, "wrong_attempts": 0},
		"optical_tube_assembly": {"installed": true, "alignment_score": 94, "wrong_attempts": 0},
		"finder_scope": {"installed": true, "alignment_score": 94, "wrong_attempts": 0},
	}
	gm.progress["tube_assemblies"]["dobsonian"] = {
		"completed": true,
		"subassembly_score": 94.0,
		"optical_alignment": 94.0,
	}
	gm.progress["telescope_ready"] = true
	if not gm.equip_completed_optical_telescope("dobsonian"):
		push_error("Could not equip Dobsonian fixture.")
		_finish(1)
		return
	gm.begin_remote_campaign("radio")
	if gm.active_optical_telescope_family() != "dobsonian":
		push_error("FAST context overwrote the active optical telescope.")
		_finish(1)
		return
	gm.progress["pending_unlock_notice"] = []

	var room := (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	current_scene = room
	for _frame in range(8):
		await process_frame
	var guidance := room.get("guidance_panel") as Control
	if guidance != null:
		guidance.visible = false
	room.call("_set_player_position", Vector2(520, 575))
	room.set("player_facing", "up")
	room.call("_set_player_animation_frame", "up", 0)
	room.call("_update_nearby")
	room.call("_update_hud")
	for _frame in range(5):
		await process_frame
	await create_timer(0.12).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save active optical routing capture.")
		_finish(1)
		return
	print("ACTIVE OPTICAL ROUTING CAPTURE PASS")
	_finish(0)


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	_restore_save()
	quit(exit_code)
