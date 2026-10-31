extends SceneTree

const TEST_TIMEOUT_SECONDS := 30.0

var failures := 0
var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_start_watchdog()
	_backup_save()
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_finish(1)
		return

	gm.new_game()
	var mission_manager: Node = root.get_node_or_null("/root/MissionManager")
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
	_check(gm.equip_completed_optical_telescope("dobsonian"), "finishing the Dobsonian equips it as the active optical telescope")

	_check(str(gm.current_level().get("telescope_family", "")) == "fast_radio", "fixture keeps the FAST campaign active")
	_check(gm.telescope_is_ready(), "assembled Dobsonian is ready in postgraduate free build")
	_check(gm.active_optical_telescope_family() == "dobsonian", "active optical identity is independent from the FAST mission family")
	_check(gm.go_to_local_optical_observation("telescope"), "central pad can begin a local optical session during a FAST mission")
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.name == "SkyObservation", "local optical context bypasses the FAST sky-route redirect")
	_check(gm.is_local_optical_free_observation(), "local optical session owns the central pad")
	_check(gm.is_free_observation(), "local optical session cannot advance the FAST campaign")
	_check(str(gm.local_optical_observation_context.get("family", "")) == "dobsonian", "selected ground family is preserved")
	_check(gm.selected_object_id != gm.current_target_object_id(), "local sky starts on a real optical catalog object, not the radio mission target")
	_check(gm.remote_observation_context.is_empty(), "central pad does not open a remote instrument context")

	gm.begin_remote_campaign("radio")
	_check(not gm.is_local_optical_free_observation(), "lower-right remote console cleanly takes ownership")
	_check(str(gm.remote_observation_context.get("kind", "")) == "radio", "FAST remains available only through the remote context")
	_check(gm.active_optical_telescope_family() == "dobsonian", "visiting FAST does not overwrite the active optical telescope")

	gm.select_assembly_family("cassegrain")
	gm.progress["assembly_state"] = {
		"tripod": {"installed": true, "alignment_score": 96, "wrong_attempts": 0},
		"mount": {"installed": true, "alignment_score": 96, "wrong_attempts": 0},
		"optical_tube_assembly": {"installed": true, "alignment_score": 96, "wrong_attempts": 0},
	}
	gm.progress["tube_assemblies"]["cassegrain"] = {
		"completed": true,
		"subassembly_score": 96.0,
		"optical_alignment": 96.0,
	}
	gm.progress["telescope_ready"] = true
	_check(gm.telescope_is_ready(), "assembled Cassegrain is ready in postgraduate free build")
	_check(gm.equip_completed_optical_telescope("cassegrain"), "finishing the Cassegrain makes it the active optical telescope")
	_check(gm.begin_local_optical_free_observation(), "central pad opens the assembled Cassegrain instead of FAST")
	_check(str(gm.local_optical_observation_context.get("family", "")) == "cassegrain", "Cassegrain remains the active local optical family")
	_check(gm.remote_observation_context.is_empty(), "Cassegrain central-pad entry clears the FAST remote context")

	gm.begin_remote_campaign("space")
	_check(gm.active_optical_telescope_family() == "cassegrain", "visiting Space Infrared does not overwrite the active optical telescope")
	_check(gm.begin_local_optical_free_observation(), "central pad can resume the active Cassegrain after Space Infrared")
	_check(str(gm.local_optical_observation_context.get("family", "")) == "cassegrain", "Space Infrared return preserves the Cassegrain build")

	gm.save()
	var save_manager: Node = root.get_node_or_null("/root/SaveManager")
	if save_manager != null:
		gm.progress = save_manager.load_progress(gm.default_progress())
		gm._normalize_progress()
		_check(gm.active_optical_telescope_family() == "cassegrain", "active optical telescope survives save reload")
	else:
		_check(false, "SaveManager is available for active optical persistence")

	gm.progress["active_optical_telescope_id"] = ""
	_check(not gm.begin_local_optical_free_observation(), "central pad refuses entry when no optical telescope is equipped")
	_check(str(gm.remote_observation_context.get("kind", "")) != "radio", "missing optical equipment never falls back to FAST")

	print("LOCAL OPTICAL OBSERVATION ROUTING TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	_finish(0 if failures == 0 else 1)


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not finished:
			push_error("LOCAL OPTICAL OBSERVATION ROUTING TEST TIMEOUT")
			_finish(1)
	)


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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
