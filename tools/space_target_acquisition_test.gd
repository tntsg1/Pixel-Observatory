extends SceneTree

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager is available")
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["completed_levels"] = range(66, 86)
	gm.progress["current_level"] = 85
	gm.progress["space_deployed"] = true
	gm.progress["tutorial_assistance"] = "free"
	_check(gm.begin_remote_free_observation("space", "andromeda_infrared"),
		"free infrared session can be seeded without selecting the final target")

	var scene := load("res://scenes/space_observation.tscn").instantiate() as Control
	root.add_child(scene)
	await _settle(0.12)
	_check(str(scene.call("_key")) == "acquire",
		"free infrared observation opens inside TARGET ACQUISITION")
	var entries: Array = scene.get("acquisition_entries")
	_check(entries.size() >= 8, "instrument sky contains the deep-sky program beacons")
	var acquisition_display := scene.find_child(
		"SpaceTargetAcquisitionDisplay", true, false) as Control
	_check(acquisition_display != null,
		"instrument acquisition uses a live attitude-sky display")
	_check(scene.find_child("RemoteFreeObservationCatalog", true, false) == null,
		"no ordinary target-list modal is present inside the instrument")
	if acquisition_display != null:
		var center_x := acquisition_display.size.x * 0.5
		acquisition_display.set("attitude", Vector2(179.0, 0.0))
		var east_of_seam: Vector2 = acquisition_display.call(
			"_entry_position", {"yaw": -179.0, "pitch": 0.0})
		acquisition_display.set("attitude", Vector2(-179.0, 0.0))
		var west_of_seam: Vector2 = acquisition_display.call(
			"_entry_position", {"yaw": 179.0, "pitch": 0.0})
		_check(
			absf(east_of_seam.x - center_x) < 16.0
			and absf(west_of_seam.x - center_x) < 16.0,
			"beacons remain adjacent to the boresight across the 359-to-0 degree seam")
		scene.set("acquisition_attitude", Vector2(179.5, 0.0))
		scene.call("_drag_acquisition_attitude", Vector2(2.0, 0.0))
		var wrapped_once: Vector2 = scene.get("acquisition_attitude")
		scene.call("_drag_acquisition_attitude", Vector2(1080.0, 0.0))
		var wrapped_after_turns: Vector2 = scene.get("acquisition_attitude")
		_check(
			is_equal_approx(wrapped_once.x, wrapped_after_turns.x)
			and wrapped_once.x < -170.0,
			"the attitude sky supports seamless multi-turn horizontal rotation")
		scene.set("acquisition_velocity", Vector2.ZERO)
		scene.set("acquisition_candidate_id", "")

	var safe_entry: Dictionary = {}
	var unsafe_entry: Dictionary = {}
	for value in entries:
		var entry := value as Dictionary
		var solar_angle := float(entry.get("solar_angle", -1.0))
		_check(
			bool(entry.get("thermal_safe", false)) == (solar_angle >= 85.0 and solar_angle <= 135.0),
			"%s thermal status follows the 85-135 degree sunshield corridor" % str(entry.get("name", "target")))
		if bool(entry.get("thermal_safe", false)):
			safe_entry = entry
		elif unsafe_entry.is_empty():
			unsafe_entry = entry
	_check(not safe_entry.is_empty(), "at least one deep-sky beacon is in the sunshield-safe corridor")
	if not unsafe_entry.is_empty():
		scene.set("acquisition_attitude", Vector2(
			float(unsafe_entry.get("yaw", 0.0)) + 1.2,
			float(unsafe_entry.get("pitch", 0.0))))
		scene.call("_process_acquisition", 0.0)
		await process_frame
		var blocked_lock_button := scene.find_child("SpaceFineLockButton", true, false) as Button
		_check(blocked_lock_button != null and not blocked_lock_button.disabled,
			"an aligned sun-blocked beacon offers a schedulable safe-window lock")
		_check("SCHEDULE" in blocked_lock_button.text,
			"the lock button explains that it will schedule a safe window")
		scene.call("_begin_acquisition_lock")
		var scheduled_entry: Dictionary = scene.call(
			"_acquisition_entry", str(unsafe_entry.get("id", "")))
		_check(bool(scheduled_entry.get("safe_window_scheduled", false)),
			"starting lock schedules the selected beacon into its safe observing window")
		_check(bool(scheduled_entry.get("thermal_safe", false)),
			"the scheduled window satisfies the thermal corridor")
		_check(bool(scene.get("acquisition_locking")),
			"fine lock starts immediately after safe-window scheduling")
		scene.set("acquisition_locking", false)
		scene.set("acquisition_lock_progress", 0.0)
	if not safe_entry.is_empty():
		scene.set("acquisition_attitude", Vector2(
			float(safe_entry.get("yaw", 0.0)),
			float(safe_entry.get("pitch", 0.0))))
		scene.call("_process_acquisition", 0.0)
		await process_frame
		var lock_button := scene.find_child("SpaceFineLockButton", true, false) as Button
		_check(lock_button != null and not lock_button.disabled,
			"fine lock becomes available only after the beacon reaches the capture box")

		var before_drive: Vector2 = scene.get("acquisition_attitude")
		Input.action_press("move_right")
		for _i in range(12):
			scene.call("_process_acquisition", 1.0 / 60.0)
		Input.action_release("move_right")
		var after_drive: Vector2 = scene.get("acquisition_attitude")
		_check(after_drive.x > before_drive.x,
			"continuous keyboard/Web input drives the spacecraft boresight")

		scene.set("acquisition_attitude", Vector2(
			float(safe_entry.get("yaw", 0.0)),
			float(safe_entry.get("pitch", 0.0))))
		scene.call("_refresh_acquisition")
		scene.call("_begin_acquisition_lock")
		for _i in range(130):
			scene.call("_process_acquisition", 1.0 / 60.0)
			await process_frame
			if str(scene.call("_key")) != "acquire":
				break
		# The locked result deliberately remains visible for 0.62 seconds.
		# Headless frames are uncapped, so wait real timer time rather than
		# assuming a frame count represents wall-clock seconds.
		if str(scene.call("_key")) == "acquire":
			await create_timer(0.75).timeout
		var final_stage := str(scene.call("_key"))
		_check(final_stage == "plan",
			"fine-lock completion advances seamlessly to the existing Plan stage (actual: %s)" % final_stage)
		_check(str(gm.active_remote_free_entry("space").get("id", "")) == str(safe_entry.get("id", "")),
			"the selected target context is committed only after fine lock")
		_check(int(gm.progress.get("current_level", 0)) == 85,
			"free target acquisition never advances the campaign")

	scene.queue_free()
	await process_frame
	_finish()


func _settle(seconds: float) -> void:
	var frames := maxi(2, ceili(seconds * 60.0))
	for _i in range(frames):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: " + message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	push_error("  FAIL: " + message)


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _finish() -> void:
	Input.action_release("move_right")
	_restore_save()
	print("SPACE TARGET ACQUISITION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
