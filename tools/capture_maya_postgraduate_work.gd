extends SceneTree

const OUTPUT_DIR := "res://artifacts/maya_postgraduate_work"
const PLAYER_SAVE_PATH := "user://savegame.json"
const ISOLATED_USER_MARKER := "maya_capture_user"

var _preserved_manager_state: Dictionary = {}
var _preserved_save_text := ""
var _player_save_existed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var active_user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not active_user_dir.contains(ISOLATED_USER_MARKER):
		push_error(
			"Maya capture refused to run against the player profile. "
			+ "Launch it with APPDATA pointing at an isolated maya_capture_user directory."
		)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manager := root.get_node_or_null("GameManager")
	_snapshot_player_state(manager)
	# Capture scenes deliberately exercise normal save-producing NPC paths. Keep
	# the entire run inside GameManager's existing developer sandbox so deferred
	# saves cannot touch the player's archive between snapshot and restoration.
	manager.set("_developer_sandbox_active", true)
	manager.progress["program_completed"] = true
	manager.progress["graduation_seen"] = true
	manager.progress.erase("maya_postgraduate_work")
	manager.progress["maya_postgraduate_relationship"] = {
		"conversations": 12,
		"assembly_assists": 8,
		"observations_joined": 5,
		"observations_completed": 4,
		"rest_conversations": 5,
		"tea_breaks_shared": 3,
	}
	manager.room_guidance_target = ""
	manager.language_mode = "zh"
	var room := (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	var maya := room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	if maya == null:
		_restore_player_state(manager)
		quit(1)
		return
	maya.set_process(false)
	maya.set("_postgraduate_target_id", "jupiter")
	maya.set("_postgraduate_instrument_id", "refractor_80")
	maya.set("_postgraduate_night_id", "cold_clear")
	maya.set("_postgraduate_event_id", "dew_control")
	maya.set("_postgraduate_cycle", 1)
	maya.set("_postgraduate_phase", "assembling")
	maya.set("_postgraduate_assembly_progress", 1)
	maya.position = room.call("_maya_destination_for", "assembly")
	maya.set("_destination_id", "assembly")
	maya.set("_arrived", true)
	maya.set("_moving", false)
	maya.call("_show_state", "postgraduate_assembling", false)
	room.call("_open_maya_workbench")
	for _settle in range(4):
		await process_frame
	root.get_texture().get_image().save_png("%s/00_collaborative_workbench.png" % OUTPUT_DIR)
	room.call("_close_maya_workbench")
	for _walkaway_settle in range(3):
		await process_frame
	root.get_texture().get_image().save_png("%s/00b_workbench_walkaway.png" % OUTPUT_DIR)
	maya.set("_postgraduate_event_id", "finder_recalibration")
	room.call("_open_maya_workbench")
	for _finder_settle in range(3):
		await process_frame
	root.get_texture().get_image().save_png("%s/00c_finder_recalibration_workbench.png" % OUTPUT_DIR)
	room.call("_close_maya_workbench")
	maya.set("_postgraduate_event_id", "dew_control")
	var phases := [
		["assembling", "assembly", "01_assembling.png"],
		["observing", "telescope", "02_observing_jupiter.png"],
		["recording", "journal", "03_recording_jupiter.png"],
		["reviewing", "computer", "04_reviewing_jupiter.png"],
		["resting", "journal", "05_resting_with_tea.png"],
	]
	for phase_spec in phases:
		var phase := str(phase_spec[0])
		var destination := str(phase_spec[1])
		maya.set("_postgraduate_phase", phase)
		maya.set("_postgraduate_event_id", "old_logbook" if phase == "resting" else "dew_control")
		maya.position = room.call("_maya_destination_for", destination)
		maya.set("_destination_id", destination)
		maya.set("_arrived", true)
		maya.set("_moving", false)
		maya.call("_face_toward", room.call("_maya_focus_for", destination))
		maya.call("_show_state", "postgraduate_%s" % phase, false)
		for _settle in range(3):
			await process_frame
		await process_frame
		root.get_texture().get_image().save_png(
			"%s/%s" % [OUTPUT_DIR, str(phase_spec[2])]
		)
		if phase == "observing":
			manager.progress["maya_postgraduate_presence"] = {
				"departed_unix": int(Time.get_unix_time_from_system()) - 20,
				"phase": "assembling",
				"cycle": 1,
				"target_id": "jupiter",
			}
			var return_reaction: Dictionary = maya.call("_postgraduate_return_reaction")
			maya.call("_show_postgraduate_override", return_reaction)
			for _return_settle in range(3):
				await process_frame
			root.get_texture().get_image().save_png("%s/02b_returned_to_observation.png" % OUTPUT_DIR)
		if phase == "reviewing":
			maya.respond_to_player()
			maya.respond_to_player()
			for _interrupt_settle in range(3):
				await process_frame
			root.get_texture().get_image().save_png("%s/04b_reviewing_interruption.png" % OUTPUT_DIR)
		if phase == "resting":
			room.call("_open_maya_rest_chat")
			await process_frame
			room.call("_choose_maya_rest_topic", "old_logbook")
			for _chat_settle in range(3):
				await process_frame
			root.get_texture().get_image().save_png("%s/05b_rest_conversation.png" % OUTPUT_DIR)
			room.call("_choose_maya_rest_topic", "first_solo_night")
			for _memory_settle in range(3):
				await process_frame
			root.get_texture().get_image().save_png("%s/05c_private_memory.png" % OUTPUT_DIR)
			room.call("_close_maya_rest_chat")
			await process_frame
	room.queue_free()
	await process_frame
	manager.local_optical_observation_context = {
		"active": true,
		"companion": "maya",
		"companion_target_id": "jupiter",
		"companion_instrument_id": "refractor_80",
		"companion_instrument_name_en": "80 mm refractor",
		"companion_instrument_name_zh": "80 毫米折射镜",
	}
	manager.selected_object_id = "jupiter"
	manager.selected_object_level = int(manager.progress.get("current_level", 1))
	manager.last_sky_aim = {}
	var sky := (load("res://scenes/sky_observation.tscn") as PackedScene).instantiate()
	root.add_child(sky)
	for _settle in range(6):
		await process_frame
	root.get_texture().get_image().save_png("%s/06_observing_with_maya.png" % OUTPUT_DIR)
	var selected_detail := sky.get("selected_detail") as Label
	if selected_detail == null or not selected_detail.text.contains("80 毫米折射镜"):
		push_error("Maya companion observation does not show her assembled instrument")
		_restore_player_state(manager)
		quit(1)
		return
	sky.queue_free()
	await process_frame
	manager.progress["maya_postgraduate_work"] = {
		"phase": "observing",
		"target_id": "jupiter",
		"instrument_id": "refractor_80",
		"night_id": "clear_stable",
		"assembly_progress": 3,
		"cycle": 3,
	}
	manager.progress["maya_postgraduate_relationship"] = {
		"conversations": 5,
		"assembly_assists": 6,
		"observations_joined": 3,
		"observations_completed": 2,
	}
	manager.observation_result_serial = 12
	manager.last_observation = {
		"result_serial": 12,
		"object_id": "jupiter",
		"object_name_en": "Jupiter",
		"object_name_zh": "木星",
		"quality": "Good",
	}
	manager.local_optical_observation_context = {
		"active": true,
		"companion": "maya",
		"companion_target_id": "jupiter",
		"started_observation_serial": 11,
		"companion_instrument_id": "refractor_80",
		"companion_instrument_name_en": "80 mm refractor",
		"companion_instrument_name_zh": "80 毫米折射镜",
	}
	manager.room_guidance_target = ""
	manager.clear_maya_observatory_return_pose()
	manager.set_observatory_spawn("telescope")
	var return_room := (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(return_room)
	for _settle in range(5):
		await process_frame
	root.get_texture().get_image().save_png("%s/07_companion_result_return.png" % OUTPUT_DIR)
	var return_maya := return_room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	if return_maya == null or return_maya.current_state_id() != "postgraduate_observation_return":
		push_error("Maya does not acknowledge a completed companion observation")
		_restore_player_state(manager)
		quit(1)
		return
	return_room.queue_free()
	await process_frame
	_restore_player_state(manager)
	print("MAYA POSTGRADUATE WORK CAPTURE: PASS")
	quit(0)


func _snapshot_player_state(manager: Node) -> void:
	_player_save_existed = FileAccess.file_exists(PLAYER_SAVE_PATH)
	if _player_save_existed:
		_preserved_save_text = FileAccess.get_file_as_string(PLAYER_SAVE_PATH)
	_preserved_manager_state = {
		"progress": manager.get("progress").duplicate(true),
		"language_mode": manager.get("language_mode"),
		"room_guidance_target": manager.get("room_guidance_target"),
		"selected_object_id": manager.get("selected_object_id"),
		"selected_object_level": manager.get("selected_object_level"),
		"last_observation": manager.get("last_observation").duplicate(true),
		"last_sky_aim": manager.get("last_sky_aim").duplicate(true),
		"local_optical_observation_context": manager.get("local_optical_observation_context").duplicate(true),
		"observation_result_serial": manager.get("observation_result_serial"),
		"developer_sandbox_active": manager.get("_developer_sandbox_active"),
		"developer_sandbox_level": manager.get("_developer_sandbox_level"),
	}


func _restore_player_state(manager: Node) -> void:
	if manager != null and not _preserved_manager_state.is_empty():
		manager.set("progress", (_preserved_manager_state.get("progress", {}) as Dictionary).duplicate(true))
		manager.set("language_mode", _preserved_manager_state.get("language_mode", "en"))
		manager.set("room_guidance_target", _preserved_manager_state.get("room_guidance_target", ""))
		manager.set("selected_object_id", _preserved_manager_state.get("selected_object_id", ""))
		manager.set("selected_object_level", _preserved_manager_state.get("selected_object_level", 0))
		manager.set("last_observation", (_preserved_manager_state.get("last_observation", {}) as Dictionary).duplicate(true))
		manager.set("last_sky_aim", (_preserved_manager_state.get("last_sky_aim", {}) as Dictionary).duplicate(true))
		manager.set(
			"local_optical_observation_context",
			(_preserved_manager_state.get("local_optical_observation_context", {}) as Dictionary).duplicate(true)
		)
		manager.set("observation_result_serial", _preserved_manager_state.get("observation_result_serial", 0))
	if _player_save_existed:
		var save_file := FileAccess.open(PLAYER_SAVE_PATH, FileAccess.WRITE)
		if save_file != null:
			save_file.store_string(_preserved_save_text)
			save_file.close()
	elif FileAccess.file_exists(PLAYER_SAVE_PATH):
		var save_absolute := ProjectSettings.globalize_path(PLAYER_SAVE_PATH)
		DirAccess.remove_absolute(save_absolute)
	# Keep the sandbox guard active until this capture-only process exits. Turning
	# it off here would let already queued deferred saves run after restoration.
