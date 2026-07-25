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
		_fail("GameManager autoload is missing")
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(68, true)
	gm.reset_assembly()

	var install_types: Array[String] = gm.space_segmented_install_types()
	for expected in [
		"primary_mirror", "sunshield", "spacecraft_bus", "deployable_tower",
		"deployment_hinges", "solar_array", "antenna", "radiator",
		"instrument_bay", "detector_module", "nircam", "nirspec", "miri",
	]:
		_check(install_types.has(expected), "L68 assembly includes " + expected)

	var plan: Array = gm.auto_equip_plan()
	var planned_types: Array[String] = []
	for entry_value in plan:
		planned_types.append(str((entry_value as Dictionary).get("part_type", "")))
	for part_type in install_types:
		_check(planned_types.has(part_type), "auto-equip includes " + part_type)
	gm.apply_auto_equip(plan)
	for part_type in install_types:
		_check(gm.equipped_part_id(part_type) != "", "auto-equip selects " + part_type)

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(4):
		await process_frame
	_check((bench.get("order") as Array).size() == install_types.size(), "bench exposes every unlocked space component")
	for tab_id in ["core", "deployment", "instruments"]:
		_check(bench.find_child("SpaceBlueprintTab_%s" % tab_id, true, false) != null, "blueprint has %s page" % tab_id)

	bench.call("_select_flat_part", "solar_array")
	await process_frame
	_check(str(bench.get("space_blueprint_page")) == "deployment", "selecting Solar Array opens deployment blueprint")
	_check(bench.find_child("SpaceModuleSlot_solar_array", true, false) != null, "Solar Array has an installable blueprint slot")

	bench.call("_select_flat_part", "miri")
	await process_frame
	_check(str(bench.get("space_blueprint_page")) == "instruments", "selecting MIRI opens instruments blueprint")
	_check(bench.find_child("SpaceModuleSlot_miri", true, false) != null, "MIRI has an installable blueprint slot")
	_check(bench.find_child("InstallEquippedSpaceSet", true, false) != null, "bench offers one-click installation of equipped components")

	bench.call("_install_all_space_parts")
	await process_frame
	for part_type in install_types:
		_check(bool((gm.progress.get("assembly_state", {}).get(part_type, {}) as Dictionary).get("installed", false)),
			"one-click assembly installs " + part_type)
	_check(gm.telescope_is_ready(), "full unlocked space loadout makes the observatory ready")
	for instrument in ["nircam", "nirspec", "miri"]:
		_check(gm.space_instrument_is_installed(instrument), instrument.to_upper() + " is available at the science console")
	_check(not gm.space_instrument_is_installed("fgs_niriss"), "future FGS/NIRISS remains unavailable before its unlock")

	bench.queue_free()
	await process_frame
	_finish()


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


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	_restore_save()
	print("SPACE PARTS INTEGRATION TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
