extends SceneTree

const CASES := {
	23: {"mount": "tracking_mount", "tracking": true, "rate": 1.0},
	35: {"mount": "reflector_mount", "tracking": false, "rate": 0.0},
	36: {"mount": "dobsonian_rocker_mount", "tracking": false, "rate": 0.0},
	41: {"mount": "dobsonian_rocker_mount", "tracking": false, "rate": 0.0}
}

var failures := 0
var game_manager: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	game_manager = root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager is available")
	if game_manager == null:
		_finish()
		return

	for level_number_value in CASES.keys():
		var level_number := int(level_number_value)
		var expected: Dictionary = CASES[level_number]
		var snapshots: Array[Dictionary] = []
		for repeat_index in range(3):
			game_manager.new_game()
			game_manager.debug_jump_to_level(level_number, true)
			var report: Dictionary = game_manager.prepared_readiness_report()
			snapshots.append({
				"mount_id": str(report.get("mount_id", "")),
				"tracking_capable": bool(report.get("tracking_capable", false)),
				"tracking_rate": float(report.get("tracking_rate", -1.0)),
				"observation_open": bool(report.get("observation_open", false))
			})
		var first: Dictionary = snapshots[0]
		print("  L%d mount=%s tracking=%s rate=%.2f" % [
			level_number,
			first.get("mount_id", ""),
			first.get("tracking_capable", false),
			float(first.get("tracking_rate", -1.0))
		])
		_check(snapshots[1] == first and snapshots[2] == first, "L%d quick prepare is deterministic" % level_number)
		_check(str(first.get("mount_id", "")) == str(expected.get("mount", "")), "L%d selects %s" % [level_number, expected.get("mount", "")])
		_check(bool(first.get("tracking_capable", false)) == bool(expected.get("tracking", false)), "L%d reports tracking capability correctly" % level_number)
		_check(is_equal_approx(float(first.get("tracking_rate", -1.0)), float(expected.get("rate", -1.0))), "L%d reports the expected tracking rate" % level_number)
		_check(bool(first.get("observation_open", false)), "L%d prepared rig opens observation" % level_number)

	_finish()


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("DEVELOPER QUICK PREPARE TRACKING %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
