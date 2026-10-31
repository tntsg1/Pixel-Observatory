extends SceneTree

# Auto-equip rework acceptance (user checklist 1-10): scored best-part
# selection, teaching pins with reasons, family compatibility, no optics on
# IR/FAST, preview==apply, cancel==no-op, bilingual reasons.

var failures := 0


func _plan_entry(plan: Array, part_type: String) -> Dictionary:
	for entry_value in plan:
		if str(entry_value.get("part_type", "")) == part_type:
			return entry_value
	return {}


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("AUTO EQUIP TEST FAIL (no GameManager)")
		quit(1)
		return

	# (1)(2) L13 (Jupiter, free slots, upgrades unlocked): never basic parts.
	gm.new_game()
	gm.debug_jump_to_level(13, false)
	for part_id in ["eyepiece_10mm", "objective_100mm", "stable_mount", "tracking_mount"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
	var plan: Array = gm.auto_equip_plan()
	_check(str(_plan_entry(plan, "eyepiece").get("part_id", "")) == "eyepiece_10mm",
		"1. planet task picks the 10mm over the basic 20mm eyepiece")
	_check(str(_plan_entry(plan, "mount").get("part_id", "")) == "tracking_mount",
		"2. free task picks the best mount, not Basic Mount")
	_check(str(_plan_entry(plan, "objective").get("part_id", "")) == "objective_100mm",
		"2b. free task picks the 100mm objective")

	# (3) L25 pins Basic Mount for the chromatic experiment: kept + reasoned.
	gm.debug_jump_to_level(25, false)
	for part_id in ["stable_mount", "tracking_mount", "eyepiece_10mm"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
	plan = gm.auto_equip_plan()
	var mount_entry := _plan_entry(plan, "mount")
	_check(str(mount_entry.get("part_id", "")) == "basic_mount", "3. lesson-pinned Basic Mount is kept on L25")
	_check(bool(mount_entry.get("pinned", false)), "3. pinned flag set")
	_check(str(mount_entry.get("reason_zh", "")).contains("指定"), "3. teaching reason shown (zh)")
	var eyepiece_entry := _plan_entry(plan, "eyepiece")
	_check(str(eyepiece_entry.get("part_id", "")) == "eyepiece_20mm", "3b. pinned 20mm eyepiece kept for the experiment")

	# (4) Newtonian level: no refractor objective, families all compatible.
	gm.debug_jump_to_level(27, true)
	plan = gm.auto_equip_plan()
	_check(_plan_entry(plan, "objective").is_empty(), "4. Newtonian plan has no refractor objective slot")
	for entry_value in plan:
		var fam := str(gm.get_part(str(entry_value.get("part_id", ""))).get("telescope_family", ""))
		_check(fam in ["", "newtonian"], "4. '%s' is Newtonian-compatible" % str(entry_value.get("part_id", "")))

	# (5) Dobsonian level never picks the Cassegrain mount (even if unlocked).
	gm.debug_jump_to_level(37, true)
	if not gm.progress["unlocked_parts"].has("cassegrain_fork_mount"):
		gm.progress["unlocked_parts"].append("cassegrain_fork_mount")
	plan = gm.auto_equip_plan()
	_check(str(_plan_entry(plan, "mount").get("part_id", "")) == "dobsonian_rocker_mount",
		"5. Dobsonian keeps its rocker mount, not the Cassegrain fork")

	# (6) Infrared level: no eyepiece in the plan.
	gm.debug_jump_to_level(66, true)
	plan = gm.auto_equip_plan()
	_check(_plan_entry(plan, "eyepiece").is_empty(), "6. infrared plan equips no eyepiece")
	_check(not _plan_entry(plan, "detector").is_empty(), "6b. infrared plan includes the detector")

	# (7) FAST level: no objective, radio chain present.
	gm.debug_jump_to_level(76, true)
	plan = gm.auto_equip_plan()
	_check(_plan_entry(plan, "objective").is_empty(), "7. FAST plan equips no objective")
	_check(_plan_entry(plan, "eyepiece").is_empty(), "7b. FAST plan equips no eyepiece")
	_check(not _plan_entry(plan, "radio_dish").is_empty(), "7c. FAST plan includes the dish")

	# (8) Preview == applied result.
	gm.debug_jump_to_level(13, false)
	for part_id in ["eyepiece_10mm", "objective_100mm", "tracking_mount"]:
		if not gm.progress["unlocked_parts"].has(part_id):
			gm.progress["unlocked_parts"].append(part_id)
	plan = gm.auto_equip_plan()
	gm.apply_auto_equip(plan)
	for entry_value in plan:
		_check(gm.equipped_part_id(str(entry_value.get("part_type", ""))) == str(entry_value.get("part_id", "")),
			"8. applied '%s' matches preview" % str(entry_value.get("part_type", "")))

	# (9) Computing a plan without applying changes nothing.
	gm.equip_part("eyepiece_20mm")
	var before := str(gm.equipped_part_id("eyepiece"))
	var _unused_plan: Array = gm.auto_equip_plan()
	_check(str(gm.equipped_part_id("eyepiece")) == before, "9. preview/cancel does not modify equipment")

	# (10) Reasons exist in BOTH languages for every entry.
	plan = gm.auto_equip_plan()
	for entry_value in plan:
		_check(str(entry_value.get("reason_en", "")) != "" and str(entry_value.get("reason_zh", "")) != "",
			"10. bilingual reason for '%s'" % str(entry_value.get("part_type", "")))

	if failures == 0:
		print("AUTO EQUIP TEST PASS")
		quit(0)
	else:
		print("AUTO EQUIP TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
