extends SceneTree

# A suggested eyepiece must respect the observation window for the target
# actually chosen by the player. L10's comparison step is deliberately exempt.
var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_check(false, "GameManager exists")
		_finish()
		return
	var cabinet: Control = load("res://scripts/ui/parts_cabinet.gd").new()

	for case in [
		{"target": "moon", "eyepiece": "eyepiece_10mm", "recommend_10mm": true},
		{"target": "saturn", "eyepiece": "eyepiece_20mm", "recommend_10mm": false},
		{"target": "pleiades", "eyepiece": "eyepiece_32mm", "recommend_10mm": false},
	]:
		gm.new_game()
		gm.debug_jump_to_level(13, true)
		var target: String = case["target"]
		_check(gm.set_level_target_choice(target), "L13 selects %s" % target)
		var best_id := str(gm.best_part_for_type("eyepiece").get("id", ""))
		_check(best_id == str(case["eyepiece"]), "L13 %s best eyepiece is %s" % [target, case["eyepiece"]])
		_check(_plan_eyepiece(gm) == best_id, "L13 %s auto-equip follows the chosen target" % target)
		_check(_best_eyepiece_succeeds(gm, best_id), "L13 %s best eyepiece can complete the observation" % target)
		var recommends_10mm: bool = cabinet.call("_is_recommended", gm.get_part("eyepiece_10mm"))
		_check(recommends_10mm == bool(case["recommend_10mm"]), "L13 %s cabinet badge matches the target" % target)

	gm.new_game()
	gm.debug_jump_to_level(16, true)
	_check(str(gm.best_part_for_type("eyepiece").get("id", "")) == "eyepiece_32mm", "L16 wide-field cluster selects 32mm")
	_check(_plan_eyepiece(gm) == "eyepiece_32mm", "L16 auto-equip selects 32mm")
	_check(_best_eyepiece_succeeds(gm, "eyepiece_32mm"), "L16 auto-equipped eyepiece can complete the observation")
	_check(not cabinet.call("_is_recommended", gm.get_part("eyepiece_10mm")), "L16 does not recommend overpowered 10mm")

	gm.new_game()
	gm.debug_jump_to_level(10, true)
	_check(_plan_eyepiece(gm) == "eyepiece_32mm", "L10 preserves its required first comparison step")
	for step in gm.mission_steps():
		gm.mark_mission_step_done(str(step.get("id", "")))
	_check(_plan_eyepiece(gm) == "eyepiece_20mm", "L10 recommends 20mm after the comparison")

	cabinet.free()
	_finish()


func _plan_eyepiece(gm: Node) -> String:
	for entry in gm.auto_equip_plan():
		if str(entry.get("part_type", "")) == "eyepiece":
			return str(entry.get("part_id", ""))
	return ""


func _best_eyepiece_succeeds(gm: Node, eyepiece_id: String) -> bool:
	if not gm.equip_part(eyepiece_id):
		return false
	gm.install_part("eyepiece", 0)
	gm.selected_object_id = gm.current_target_object_id()
	gm.set_collimation_score(100.0)
	var requirements: Dictionary = gm.active_observation_requirements()
	var result: Dictionary = gm.evaluate_selected_object({
		"requires_focus": false,
		"focus_error": 0.0,
		"observation_requirements": requirements,
		"altitude": maxf(float(requirements.get("altitude_min", 45.0)), 60.0),
		"observation_elapsed": 120.0,
		"exposure": 0.5,
		"dark_adaptation": 1.0,
		"averted_vision": true,
	})
	return bool(result.get("success", false))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("RECOMMENDED EQUIPMENT REACHABILITY %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
