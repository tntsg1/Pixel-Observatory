extends SceneTree

const OUTPUT_DIR := "res://artifacts/graduation_last_ten"
const TIMEOUT_SECONDS := 30.0

var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_start_watchdog()
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var mission_manager: Node = root.get_node_or_null("/root/MissionManager")
	if gm == null:
		_finish(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["current_level"] = 85
	gm.progress["completed_levels"] = (mission_manager.get("campaign_order") as Array).duplicate() if mission_manager != null else [1, 4, 31, 66, 85]
	gm.progress["program_completed"] = true
	gm.progress["graduation_pending"] = true
	gm.progress["graduation_seen"] = false
	gm.progress["observed_objects"] = ["moon", "jupiter", "sombrero_galaxy", "andromeda_galaxy", "pulsar_b0329"]
	gm.progress["credits"] = 2710
	gm.progress["journal_entries"] = [
		{
			"object_id": "moon",
			"object_name_en": "Moon",
			"object_name_zh": "月球",
			"level_completed": 1,
			"observation_quality": "Good",
			"knowledge_en": "Unaided sight established the first observing baseline.",
			"knowledge_zh": "肉眼观测建立了第一条观测基线。",
		},
		{
			"object_id": "sombrero_galaxy",
			"object_name_en": "Sombrero Galaxy",
			"object_name_zh": "草帽星系",
			"level_completed": 31,
			"observation_quality": "Excellent",
			"knowledge_en": "Dark adaptation and averted vision revealed a faint dust lane.",
			"knowledge_zh": "暗适应与偏视法显出了微弱尘埃带。",
		},
		{
			"object_id": "pulsar_b0329",
			"object_name_en": "PSR B0329+54",
			"object_name_zh": "脉冲星 PSR B0329+54",
			"level_completed": 85,
			"observation_quality": "Excellent",
			"knowledge_en": "Radio timing recovered a stable pulse from noise.",
			"knowledge_zh": "射电计时从噪声中恢复出稳定脉冲。",
		},
	]
	gm.mark_graduation_presented()
	var scene := (load("res://scenes/graduation_ceremony.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(8):
		await process_frame
	await _capture_stage(scene, 0, "01_recap_zh_1024x768.png")
	await _capture_stage(scene, 1, "02_archive_zh_1024x768.png")
	await _capture_stage(scene, 2, "03_equipment_access_zh_1024x768.png")
	await _capture_stage(scene, 3, "04_independent_night_zh_1024x768.png")
	scene.queue_free()
	await process_frame
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	scene = (load("res://scenes/graduation_ceremony.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(8):
		await process_frame
	await _capture_stage(scene, 2, "05_equipment_access_en_1024x768.png")
	print("GRADUATION LAST TEN CAPTURE PASS")
	_finish(0)


func _capture_stage(scene: Node, index: int, file_name: String) -> void:
	scene.call("_show_stage", index)
	for _frame in range(5):
		await process_frame
	await create_timer(0.12).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name))
	if error != OK:
		push_error("Could not save graduation capture: " + file_name)
		_finish(1)


func _start_watchdog() -> void:
	create_timer(TIMEOUT_SECONDS).timeout.connect(func() -> void:
		if not finished:
			push_error("GRADUATION LAST TEN CAPTURE TIMEOUT")
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


func _finish(code: int) -> void:
	if finished:
		return
	finished = true
	_restore_save()
	quit(code)
