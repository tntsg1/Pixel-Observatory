extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_check(false, "GameManager exists")
		_finish()
		return

	gm.new_game()
	gm.debug_jump_to_level(26)
	var selected: Dictionary = gm.progress["selected_parts"]
	selected["tube"] = "starter_tube"
	selected["objective"] = "objective_60mm"
	selected["reflector_tube"] = "newtonian_reflector_tube"
	gm.progress.erase("selected_assembly_level")
	gm.progress["selected_telescope_family"] = "refractor"
	gm.assembly_family_id = "refractor"
	gm.call("_sync_assembly_family_for_level")
	_check(gm.assembly_family() == "newtonian", "old level 26 save selects Newtonian")
	_check(gm.assembly_scene_key() == "advanced_assembly", "level 26 opens advanced assembly")
	_check(str(selected.get("tube", "")) == "", "starter tube is no longer equipped")
	_check(str(selected.get("objective", "")) == "", "refractor objective is no longer equipped")
	_check(str(selected.get("reflector_tube", "")) == "newtonian_reflector_tube", "Newtonian tube remains selected")
	_check(not gm.equip_part("starter_tube"), "starter tube cannot be equipped on Newtonian bench")
	_check(gm.equip_part("newtonian_reflector_tube"), "Newtonian tube is equippable")

	var bench: Control = load("res://scenes/advanced_assembly.tscn").instantiate()
	root.add_child(bench)
	await process_frame
	_check(str(bench.call("_family")) == "newtonian", "rendered bench uses Newtonian family")
	_check(bench.call("_main_parts").has("optical_tube_assembly"), "bench exposes optical tube subassembly")
	bench.queue_free()
	await process_frame
	var cabinet: Control = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	await process_frame
	cabinet.selected_family = "newtonian"
	var grouped: Dictionary = cabinet.call("_grouped_parts")
	var starter_in_newtonian_tab := false
	for category_parts in grouped.values():
		for part in category_parts:
			if str(part.get("id", "")) == "starter_tube":
				starter_in_newtonian_tab = true
	_check(not starter_in_newtonian_tab, "cabinet omits starter tube from Newtonian tab")
	var starter_card: Control = cabinet.call("_part_card", gm.get_part("starter_tube"))
	_check((starter_card.get_node("EquipButton") as Button).disabled, "cabinet cannot equip starter tube on Newtonian bench")
	starter_card.queue_free()
	cabinet.queue_free()
	await process_frame

	gm.select_assembly_family("refractor")
	gm.call("_sync_assembly_family_for_level")
	_check(gm.assembly_family() == "refractor", "manual same-level family choice is preserved")
	_check(str(selected.get("reflector_tube", "")) == "", "manual family change clears incompatible tube")
	gm.progress["current_level"] = 27
	gm.call("_sync_assembly_family_for_level")
	_check(gm.assembly_family() == "newtonian", "next lesson restores its recommended family")
	_check(gm.equip_part("newtonian_reflector_tube"), "Newtonian tube can be selected again")
	gm.progress["current_level"] = 36
	gm.call("_sync_assembly_family_for_level")
	_check(gm.assembly_family() == "dobsonian", "later family transition selects Dobsonian")
	_check(str(selected.get("reflector_tube", "")) == "", "previous family reflector tube is unequipped")
	gm.new_game()
	gm.progress["current_level"] = 25
	gm.progress["completed_levels"] = range(1, 26)
	gm.progress["selected_assembly_level"] = 25
	_check(gm.call("_advance_past_completed_current_level"), "completed level advances")
	_check(int(gm.progress["current_level"]) == 26, "campaign advances to level 26")
	_check(gm.assembly_family() == "newtonian", "campaign advance selects Newtonian bench")
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _finish() -> void:
	if failures == 0:
		print("LEVEL 26 ASSEMBLY FAMILY PASS")
	quit(0 if failures == 0 else 1)
