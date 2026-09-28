extends SceneTree

# The low and high power observations are evidence for L10's comparison,
# while only the medium power observation may identify Saturn.
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

	gm.new_game()
	gm.set_tutorial_assistance_mode("free")
	gm.debug_jump_to_level(10, true)
	gm.selected_object_id = "saturn"
	for part_id in ["eyepiece_32mm", "eyepiece_20mm", "eyepiece_10mm"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)

	var eyepieces := ["eyepiece_32mm", "eyepiece_20mm", "eyepiece_10mm", "eyepiece_20mm"]
	var step_ids := ["low_power", "medium_power", "high_power"]
	for index in range(eyepieces.size()):
		var eyepiece_id: String = eyepieces[index]
		_check(gm.equip_part(eyepiece_id), "%s equips" % eyepiece_id)
		var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
		root.add_child(view)
		await process_frame
		if index == 0:
			_check(not gm.completed_mission_steps().has("low_power"), "unfocused 32mm view does not count")
		view.call("_set_focus_value", float(view.get("target_focus_value")))
		await process_frame
		var observation: Dictionary = view.get("observation")
		var failure: Dictionary = observation.get("technique_failure", {})
		if index < 3:
			_check(gm.completed_mission_steps().has(step_ids[index]), "%s comparison step counts" % eyepiece_id)
		_check(bool(observation.get("success", false)) == (index == 1 or index == 3), "%s final quality gate" % eyepiece_id)
		if index == 0 or index == 2:
			_check(not view.call("can_identify_object"), "%s cannot identify Saturn yet" % eyepiece_id)
		if index == 0:
			_check(str(failure.get("code", "")) == "magnification_low", "32mm is below the identification range")
		elif index == 2:
			_check(str(failure.get("code", "")) == "magnification_high", "10mm is above the identification range")
		if index == 2:
			_check(gm.completed_mission_steps().size() == 3, "all three observations recorded")
		if index == 3:
			_check(view.call("can_identify_object"), "20mm allows identification after comparison")
			_check(gm.complete_current_mission("saturn", observation), "level 10 can complete")
		view.queue_free()
		await process_frame
		gm.selected_object_id = "saturn"

	_finish()


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
	print("LEVEL 10 MAGNIFICATION COMPARISON %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
