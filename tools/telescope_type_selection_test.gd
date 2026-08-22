extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(80, false)
	var selector: Control = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(selector)
	await process_frame
	var ids: Array[String] = []
	var constants: Dictionary = (selector.get_script() as Script).get_script_constant_map()
	for entry_value in constants.get("FAMILIES", []):
		ids.append(str((entry_value as Dictionary).get("id", "")))
	var blueprints: Dictionary = constants.get("FAMILY_BLUEPRINTS", {})
	for expected in ["refractor", "newtonian", "dobsonian", "cassegrain", "space_segmented", "fast_radio"]:
		_check(ids.has(expected), "selector includes " + expected)
		var blueprint_path := str(blueprints.get(expected, ""))
		_check(blueprint_path != "" and ResourceLoader.exists(blueprint_path), "selector has a real blueprint for " + expected)
	var preview_texture := selector.get("preview_texture") as TextureRect
	_check(preview_texture != null and preview_texture.texture != null, "recommended family opens with a blueprint preview")
	for family_id in ids:
		selector.call("_select", family_id)
		_check(preview_texture.texture != null, family_id + " selection keeps the blueprint stage populated")
		_check(preview_texture.texture.resource_path == str(blueprints.get(family_id, "")), family_id + " preview uses its assigned blueprint")
	_check(_inside_1024(selector.get_node("FamilyRail") as Control), "family rail stays inside 1024x768")
	_check(_inside_1024(selector.get("preview_panel") as Control), "blueprint stage stays inside 1024x768")
	_check(_inside_1024(selector.get("detail_container") as Control), "instrument facts stay inside 1024x768")
	_check(_inside_1024(selector.get("proceed_button") as Control), "proceed action stays inside 1024x768")
	selector.call("_select", "newtonian")
	_check(str(selector.get("selected_family")) == "newtonian", "an unlocked non-recommended family can be selected")
	# _proceed stores the player's explicit bench choice before routing. Avoid a
	# scene switch in the test; the assignment itself is the navigation contract.
	gm.select_assembly_family(str(selector.get("selected_family")))
	_check(gm.assembly_family() == "newtonian", "assembly context preserves the player's choice")
	_check(str(gm.progress.get("selected_telescope_family", "")) == "newtonian", "bench choice is stored in save progress")
	_check(gm.assembly_scene_key() == "advanced_assembly", "non-refractor choice routes directly to the advanced blueprint")
	gm.assembly_family_id = ""
	_check(gm.assembly_family() == "newtonian", "saved bench choice survives transient navigation state")
	_check(str(gm.current_level().get("telescope_family", "")) == "fast_radio", "choosing a bench does not rewrite mission data")
	selector.queue_free()
	await process_frame
	gm.new_game()
	_check(gm.assembly_family() == "refractor", "new game starts with the refractor blueprint")
	_check(gm.assembly_scene_key() == "assembly", "refractor choice routes directly to the basic blueprint")
	var starter_selector: Control = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(starter_selector)
	await process_frame
	starter_selector.call("_select", "fast_radio")
	var starter_preview := starter_selector.get("preview_texture") as TextureRect
	var starter_proceed := starter_selector.get("proceed_button") as Button
	_check(starter_preview != null and starter_preview.texture != null, "locked instruments can still be studied in the catalog")
	_check(starter_proceed != null and starter_proceed.disabled, "locked instrument cannot enter its assembly bench")
	starter_selector.queue_free()
	await process_frame
	print("TELESCOPE TYPE SELECTION TEST PASS" if failures == 0 else "TELESCOPE TYPE SELECTION TEST FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _inside_1024(control: Control) -> bool:
	if control == null:
		return false
	var rect := Rect2(control.position, control.size)
	return Rect2(Vector2.ZERO, Vector2(1024, 768)).encloses(rect)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
