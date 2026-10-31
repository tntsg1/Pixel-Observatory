extends SceneTree

# Observation UI ownership regression. This intentionally checks scene
# responsibilities without changing campaign data or completing any mission.

var failures := 0
var gm: Node
var touch: Node


func _init() -> void:
	print("OBSERVATION UI RESPONSIBILITY TEST START")


func _initialize() -> void:
	await process_frame
	gm = root.get_node("/root/GameManager")
	touch = root.get_node("/root/TouchInput")
	gm.new_game()
	await _check_lobby_hud(false)
	await _check_lobby_hud(true)
	await _check_settings_mobile_toggle()
	await _check_assembly_family_selector()
	await _check_sky_selection_ownership()
	await _check_world_map_tutorial_and_home()
	touch.set_mobile_mode(false)
	if failures == 0:
		print("OBSERVATION UI RESPONSIBILITY TEST PASS")
		quit(0)
	else:
		print("OBSERVATION UI RESPONSIBILITY TEST FAIL (%d)" % failures)
		quit(1)


func _check_lobby_hud(mobile: bool) -> void:
	touch.set_mobile_mode(mobile)
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	var button_texts := _button_texts(room)
	_check(not button_texts.has("Site"), "lobby has no Site button")
	_check(not button_texts.has("Scopes"), "lobby has no Scopes button")
	_check(not button_texts.has("Touch"), "lobby has no top Touch button")
	_check(not button_texts.has("Return Home"), "lobby has no Return Home button")
	_check(button_texts.has("Menu"), "lobby keeps Menu")
	var overlay: Variant = room.get("mobile_overlay")
	_check((overlay != null) == mobile, "mobile controls follow actual/explicit mobile mode")
	room.queue_free()
	await process_frame


func _check_assembly_family_selector() -> void:
	var selector: Node = load("res://scenes/telescope_types.tscn").instantiate()
	root.add_child(selector)
	await process_frame
	var ids: Array[String] = []
	var constants: Dictionary = (selector.get_script() as Script).get_script_constant_map()
	for entry_value in constants.get("FAMILIES", []):
		ids.append(str((entry_value as Dictionary).get("id", "")))
	for expected in ["refractor", "newtonian", "dobsonian", "cassegrain", "gregorian", "space_segmented", "fast_radio"]:
		_check(ids.has(expected), "assembly selector includes " + expected)
	_check(str(selector.get("selected_family")) == "refractor", "mission recommendation starts selected")
	selector.queue_free()
	await process_frame


func _check_settings_mobile_toggle() -> void:
	var menu: Node = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.call("_on_settings")
	await process_frame
	var found := false
	for child in menu.find_children("*", "CheckButton", true, false):
		if str((child as CheckButton).text) == "Mobile controls":
			found = true
			break
	_check(found, "Settings provides the explicit Mobile Controls toggle")
	menu.queue_free()
	await process_frame


func _check_sky_selection_ownership() -> void:
	gm.debug_jump_to_level(1, false)
	gm.selected_object_id = "jupiter"
	gm.selected_object_level = 99
	gm.suppress_next_world_map_redirect = true
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	await process_frame
	_check(str(sky.get("selected_object_id")) == str(sky.get("target_id")), "new mission clears an old free selection")
	_check(sky.get_node_or_null("ChangeSiteButton") == null, "L1 hides Location until Maya teaches site selection")
	var level_number := int(gm.progress.get("current_level", 1))
	gm.selected_object_id = "jupiter"
	gm.selected_object_level = level_number
	sky.queue_free()
	await process_frame
	gm.suppress_next_world_map_redirect = true
	var returned_sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(returned_sky)
	await process_frame
	_check(str(returned_sky.get("selected_object_id")) == "jupiter", "same-mission map/telescope return preserves selection")
	returned_sky.queue_free()
	await process_frame
	gm.debug_jump_to_level(11, false)
	gm.suppress_next_world_map_redirect = true
	var later_sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(later_sky)
	await process_frame
	_check(later_sky.get_node_or_null("ChangeSiteButton") != null, "Location entry appears in Sky Observation after L10")
	later_sky.queue_free()
	await process_frame


func _check_world_map_tutorial_and_home() -> void:
	gm.progress["seen_teaching_steps"] = []
	var map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	_check(map.get_node_or_null("MayaMapTutorial") != null, "first map entry opens Maya tutorial")
	for _i in range(7):
		map.call("_advance_map_tutorial")
	await process_frame
	_check((gm.progress.get("seen_teaching_steps", []) as Array).has("world_map_controls_v1"), "map tutorial is recorded once")
	_check(map.get_node_or_null("MayaMapTutorial") == null, "tutorial returns to the map")
	map.queue_free()
	await process_frame

	var away: Dictionary = (gm.location_sites()[1] as Dictionary).duplicate(true)
	gm.set_observing_location(away)
	gm.progress["seen_teaching_steps"] = ["world_map_controls_v1"]
	var home_map: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(home_map)
	await process_frame
	var home_button := home_map.get_node_or_null("ReturnHomeButton") as Button
	_check(home_button != null and home_button.visible, "Return Home is available on the map when away")
	# Test the state change without following the scene transition.
	gm.reset_observing_location()
	_check(gm.is_at_home_location(), "Return Home changes only the observing location")
	home_map.queue_free()
	await process_frame


func _button_texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	for child in node.find_children("*", "Button", true, false):
		result.append(str((child as Button).text))
	return result


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
