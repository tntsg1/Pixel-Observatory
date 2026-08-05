extends SceneTree

const TEST_LEVEL := 35

var failures := 0
var game_manager: Node
var save_manager: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	game_manager = root.get_node_or_null("/root/GameManager")
	save_manager = root.get_node_or_null("/root/SaveManager")
	_check(game_manager != null, "GameManager is available")
	_check(save_manager != null, "SaveManager is available")
	if game_manager == null or save_manager == null:
		_finish()
		return

	game_manager.new_game()
	var persisted_before: Dictionary = save_manager.load_raw_progress()
	_check(int(persisted_before.get("current_level", 0)) == 1, "fixture begins with persisted level 1")

	game_manager.debug_jump_to_level(TEST_LEVEL, false)
	_check(game_manager.developer_sandbox_active(), "developer jump enters a runtime sandbox")
	_check(int(game_manager.progress.get("current_level", 0)) == TEST_LEVEL, "selected lesson becomes active")

	game_manager.debug_jump_to_level(TEST_LEVEL, true)
	_check(int(game_manager.progress.get("current_level", 0)) == TEST_LEVEL, "equipment preparation keeps the selected lesson")
	_check(bool(game_manager.prepared_readiness_report().get("observation_open", false)), "prepared lesson is ready to observe")

	game_manager.save()
	game_manager.call("_normalize_progress")
	_check(int(game_manager.progress.get("current_level", 0)) == TEST_LEVEL, "save and normalization do not rewind the sandbox")
	var persisted_during: Dictionary = save_manager.load_raw_progress()
	_check(int(persisted_during.get("current_level", 0)) == 1, "sandbox never overwrites the campaign save")

	game_manager.resume_saved_campaign()
	_check(not game_manager.developer_sandbox_active(), "Continue exits the developer sandbox")
	_check(int(game_manager.progress.get("current_level", 0)) == 1, "Continue restores the persisted campaign")
	_finish()


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("DEVELOPER SANDBOX REGRESSION %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
