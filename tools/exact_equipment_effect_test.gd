extends SceneTree

# Regression for the two refractor lessons that pin an exact component ID.
# Equipping and installing are separate physical actions, and the installed
# component must change the actual optical result rather than only the UI.

var failures := 0
var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	_check_high_power_eyepiece_lesson()
	_check_large_aperture_lesson()
	_finish()


func _check_high_power_eyepiece_lesson() -> void:
	gm.new_game()
	gm.debug_jump_to_level(12, false)
	_check(gm.equipped_part_id("eyepiece") == "eyepiece_20mm", "L12 starts with the previously installed 20mm eyepiece")
	var low_power_stats: Dictionary = gm.calculate_stats()
	_check(float(low_power_stats.get("magnification", 0.0)) == 35.0, "20mm eyepiece produces 35x before the upgrade")
	_check(str(gm.current_room_route().get("target", "")) == "cabinet", "L12 first routes to the cabinet for the exact 10mm eyepiece")

	_check(gm.equip_part("eyepiece_10mm"), "L12 can equip the unlocked 10mm eyepiece")
	_check(str(gm.current_room_route().get("target", "")) == "assembly", "equipping 10mm does not skip the Assembly Table")
	_install_current_level()
	var high_power_stats: Dictionary = gm.calculate_stats()
	_check(gm.equipped_part_id("eyepiece") == "eyepiece_10mm", "L12 keeps the exact required eyepiece installed")
	_check(float(high_power_stats.get("magnification", 0.0)) == 70.0, "10mm eyepiece doubles the optical magnification to 70x")
	_check(float(high_power_stats.get("field_of_view", 0.0)) < float(low_power_stats.get("field_of_view", 0.0)), "10mm eyepiece narrows the field of view")
	_check(str(gm.current_room_route().get("target", "")) == "telescope", "L12 opens the Observation Pad only after installation")


func _check_large_aperture_lesson() -> void:
	gm.new_game()
	gm.debug_jump_to_level(19, false)
	_check(gm.equipped_part_id("objective") == "objective_60mm", "L19 starts with the previous 60mm objective")
	var small_aperture_stats: Dictionary = gm.calculate_stats()
	_check(float(small_aperture_stats.get("aperture_mm", 0.0)) == 60.0, "starter objective exposes its real 60mm aperture")
	_check(str(gm.current_room_route().get("target", "")) == "cabinet", "L19 first routes to the cabinet for the exact 100mm objective")

	_check(gm.equip_part("objective_100mm"), "L19 can equip the unlocked 100mm objective")
	_check(str(gm.current_room_route().get("target", "")) == "assembly", "equipping 100mm does not skip the Assembly Table")
	_install_current_level()
	var large_aperture_stats: Dictionary = gm.calculate_stats()
	_check(gm.equipped_part_id("objective") == "objective_100mm", "L19 keeps the exact required objective installed")
	_check(float(large_aperture_stats.get("aperture_mm", 0.0)) == 100.0, "100mm objective exposes its real aperture")
	_check(float(large_aperture_stats.get("light_score", 0.0)) > float(small_aperture_stats.get("light_score", 0.0)), "100mm objective increases actual light gathering")
	_check(str(gm.current_room_route().get("target", "")) == "telescope", "L19 opens the Observation Pad only after installation")


func _install_current_level() -> void:
	for part_type_value in gm.current_level().get("required_parts", []):
		var part_type := str(part_type_value)
		var score := int(gm.install_part(part_type, 0))
		_check(score >= 0, "%s installs at the Assembly Table" % part_type)


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	print("EXACT EQUIPMENT EFFECT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
