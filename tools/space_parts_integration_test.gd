extends SceneTree
## Confirms campaign-only space requirements and the graduation free-build path.

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
		_check(install_types.has(expected), "L68 assembly exposes unlocked " + expected)

	var campaign_required: Array = gm.current_level().get("required_parts", [])
	_check(campaign_required == ["primary_mirror", "secondary_mirror", "detector", "sunshield"], "L68 keeps the documented four-part campaign gate")
	var campaign_plan: Array = gm.auto_equip_plan()
	var campaign_types: Array[String] = _plan_types(campaign_plan)
	for part_type_value in campaign_required:
		var part_type := str(part_type_value)
		_check(campaign_types.has(part_type), "campaign auto-equip includes required " + part_type)
	for part_type in install_types:
		if not campaign_required.has(part_type) and part_type != gm.recommended_space_instrument_type():
			_check(not campaign_types.has(part_type), "campaign auto-equip leaves optional " + part_type + " free")
	gm.apply_auto_equip(campaign_plan)
	for part_type_value in campaign_required:
		var part_type := str(part_type_value)
		_check(gm.equipped_part_id(part_type) != "", "campaign auto-equip selects required " + part_type)

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(4):
		await process_frame
	_check((bench.get("order") as Array).size() == install_types.size(), "campaign bench still exposes every unlocked space component")
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
	_check(bench.find_child("AutoAssembleButton", true, false) == null, "campaign bench does not expose graduation auto-assembly")

	for part_type_value in campaign_required:
		var part_type := str(part_type_value)
		var result: int = gm.install_part(part_type, 0, gm.equipped_part_id(part_type))
		_check(result >= 0, "campaign installs required " + part_type + " at its printed slot")
	_check(gm.telescope_is_ready(), "four required campaign parts make the L68 observatory ready")
	for instrument in ["nircam", "nirspec", "miri"]:
		_check(not gm.space_instrument_is_installed(instrument), instrument.to_upper() + " stays optional during the L68 campaign")

	bench.queue_free()
	await _settle_fixture_ui(0.0)
	gm.reset_assembly()
	gm.progress["program_completed"] = true
	gm.progress["graduation_seen"] = true
	gm.progress["selected_telescope_family"] = "space_segmented"
	gm.assembly_family_id = "space_segmented"
	_check(gm.postgraduate_free_build(), "graduation unlocks free infrared assembly")
	var graduation_plan: Array = gm.auto_equip_plan()
	var graduation_types: Array[String] = _plan_types(graduation_plan)
	for part_type in install_types:
		_check(graduation_types.has(part_type), "graduation auto-equip includes unlocked " + part_type)
	gm.apply_auto_equip(graduation_plan)
	for part_type in install_types:
		_check(gm.equipped_part_id(part_type) != "", "graduation auto-equip selects unlocked " + part_type)

	bench = load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(4):
		await process_frame
	_check(bench.find_child("AutoAssembleButton", true, false) != null, "graduation bench exposes one-click assembly")
	bench.call("_install_all_space_parts")
	# Let the first visibly flying component enter its readable beat before the
	# test presses Skip Animation. Frame-only waits do not advance SceneTree
	# timers in a headless tight loop.
	await create_timer(0.55).timeout
	# The second press converts the visual sequence into its documented skip
	# completion path. Players still see individual parts fly in on first press.
	bench.call("_on_auto_assemble_pressed")
	var auto_finished := false
	# Skipping removes the audience-facing dwell between parts, but the bench
	# still deliberately yields a frame for each flight/build handoff. Wait for
	# that real completion signal rather than assuming a fixed wall-clock delay.
	for _i in range(300): # 15 s watchdog for a broken dependency queue.
		if not bool(bench.get("auto_assemble_running")):
			auto_finished = true
			break
		await create_timer(0.05).timeout
	_check(auto_finished, "graduation one-click assembly completes its dependency queue")
	for part_type in install_types:
		_check(bool((gm.progress.get("assembly_state", {}).get(part_type, {}) as Dictionary).get("installed", false)),
			"graduation one-click assembly installs " + part_type)
	_check(gm.telescope_is_ready(), "full unlocked graduation loadout makes the observatory ready")
	for instrument in ["nircam", "nirspec", "miri"]:
		_check(gm.space_instrument_is_installed(instrument), instrument.to_upper() + " is available in graduation free observation")
	_check(not gm.space_instrument_is_installed("fgs_niriss"), "future FGS/NIRISS remains unavailable before its unlock")

	bench.queue_free()
	# The completion feedback owns a short Timer/Tween chain. Let it retire
	# before the headless SceneTree exits so teardown diagnostics remain useful.
	await _settle_fixture_ui(2.5)
	_finish()


func _plan_types(plan: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value in plan:
		result.append(str((entry_value as Dictionary).get("part_type", "")))
	return result


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


func _settle_fixture_ui(seconds: float) -> void:
	for _i in range(4):
		await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	for _i in range(4):
		await process_frame
	var audio_manager := root.get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("release_all_audio"):
		audio_manager.call("release_all_audio")
		await process_frame


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
