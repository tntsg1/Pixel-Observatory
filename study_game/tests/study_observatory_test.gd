extends SceneTree

var failures := 0
var scene


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "independent study scene loads")
	if packed == null:
		quit(1)
		return
	scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	_check(ProjectSettings.get_setting("application/config/name") == "Pixel Observatory Study", "study project has a distinct application identity")
	_check(ProjectSettings.get_setting("application/config/use_custom_user_dir", false), "study project uses a custom user-data directory")
	_check(scene.SAVE_PATH == "user://study_observation_v1.json", "study save path cannot collide with savegame.json")
	_check(scene.stage == 0 and scene.mode == 0, "fresh study starts at target acquisition")

	for index in range(3):
		scene.mode = index
		scene.target_offset = Vector2.ZERO
		scene._lock_current_view()
		await process_frame
	_check(scene.stage == 1, "three field locks advance to optical imaging")

	scene.eyepiece_mm = 10
	scene.focus_value = 72.0
	scene.tracking = true
	_check(not scene._optical_configuration_ready(), "120x remains unusable under the 55x seeing cap")
	scene.eyepiece_mm = 25
	_check(scene._optical_configuration_ready(), "48x plus focus and tracking is a valid optical solution")
	scene._finish_optical()
	await process_frame
	_check(scene.stage == 2, "optical integration advances to invisible evidence")

	scene.infrared_channels = ["dust", "mid", "near"]
	scene._confirm_infrared()
	scene.dispersion_measure = 14.4
	scene._confirm_radio()
	_check(scene.infrared_done and scene.radio_done, "infrared mapping and radio dispersion both require correct evidence")
	scene._finish_study_game()
	await process_frame
	_check(scene.completed, "successful decoding completes the study-only observation")

	var save_path := ProjectSettings.globalize_path(scene.SAVE_PATH)
	_check(save_path.find("PixelObservatoryStudy") >= 0, "resolved save lives under the isolated study profile")
	if FileAccess.file_exists(scene.SAVE_PATH):
		DirAccess.remove_absolute(save_path)
	print("STUDY_OBSERVATORY_TEST failures=", failures)
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
