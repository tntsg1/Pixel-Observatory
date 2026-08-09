extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(36, false)
	var selector: Node = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(selector)
	await process_frame
	var ids: Array[String] = []
	var constants: Dictionary = (selector.get_script() as Script).get_script_constant_map()
	for entry_value in constants.get("FAMILIES", []):
		ids.append(str((entry_value as Dictionary).get("id", "")))
	for expected in ["refractor", "newtonian", "dobsonian", "cassegrain", "space_segmented", "fast_radio"]:
		_check(ids.has(expected), "selector includes " + expected)
	_check(str(selector.get("selected_family")) == "dobsonian", "L36 opens on its required Dobsonian family")
	selector.call("_select", "cassegrain")
	_check(str(selector.get("selected_family")) == "dobsonian", "ordinary L36 mission cannot switch to an unrelated bench")
	var cassegrain_card := selector.get("cards").get("cassegrain") as Button
	_check(cassegrain_card != null and cassegrain_card.disabled, "ordinary L36 disables unrelated telescope families")
	selector.queue_free()
	await process_frame
	gm.debug_jump_to_level(46, false)
	selector = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(selector)
	await process_frame
	_check(str(selector.get("selected_family")) == "cassegrain", "L46 opens on Cassegrain instead of Dobsonian")
	selector.call("_select", "dobsonian")
	_check(str(selector.get("selected_family")) == "cassegrain", "ordinary L46 cannot enter the Dobsonian bench")
	selector.queue_free()
	await process_frame
	gm.new_game()
	_check(gm.assembly_family() == "refractor", "new game starts with the refractor blueprint")
	_check(gm.assembly_scene_key() == "assembly", "refractor choice routes directly to the basic blueprint")
	print("TELESCOPE TYPE SELECTION TEST PASS" if failures == 0 else "TELESCOPE TYPE SELECTION TEST FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
