extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager missing")
		quit(1)
		return
	gm.new_game()
	gm.go("observatory")
	await process_frame
	var cloud_sync: Node = root.get_node_or_null("/root/CloudSyncManager")
	gm.set_developer_console_test_permission_for_tests(true)
	if cloud_sync != null and cloud_sync.has_method("set_test_session_role_for_tests"):
		cloud_sync.set_test_session_role_for_tests("")
	gm.toggle_developer_console()
	_check(gm.developer_console == null, "visitor session cannot open developer console through direct call")
	_check(root.find_children("*", "DeveloperConsole", true, false).is_empty(), "visitor scene tree contains no developer console node")
	if cloud_sync != null and cloud_sync.has_method("set_test_session_role_for_tests"):
		cloud_sync.set_test_session_role_for_tests("user")
	gm.toggle_developer_console()
	_check(gm.developer_console == null, "ordinary role remains denied")
	var direct_panel := preload("res://scripts/ui/developer_console.gd").new()
	current_scene.add_child(direct_panel)
	await process_frame
	_check(not is_instance_valid(direct_panel) or direct_panel.get_parent() == null, "direct developer console instantiation fails closed for ordinary role")
	if cloud_sync != null and cloud_sync.has_method("set_test_session_role_for_tests"):
		cloud_sync.set_test_session_role_for_tests("admin")
	gm.toggle_developer_console()
	_check(gm.developer_console != null and is_instance_valid(gm.developer_console), "explicit admin test session opens developer console")
	var mm: Node = root.get_node_or_null("/root/MissionManager")
	_check(mm != null and gm.available_level_numbers() == mm.campaign_order, "developer console mirrors the active campaign order")
	_check(gm.available_level_numbers().has(45), "developer console includes L45")
	_check(gm.available_level_numbers().has(85), "developer console includes FAST graduation L85")
	_check(not gm.available_level_numbers().has(86), "developer console excludes retired post-FAST levels")
	var has_l45_button := false
	for node in gm.developer_console.find_children("*", "Button", true, false):
		if str(node.get("text")) == "L45":
			has_l45_button = true
			break
	_check(has_l45_button, "developer console renders an L45 button")
	var has_l86_button := false
	for node in gm.developer_console.find_children("*", "Button", true, false):
		if str(node.get("text")) == "L86":
			has_l86_button = true
			break
	_check(not has_l86_button, "developer console renders no retired L86 button")
	gm.debug_jump_to_level(18, true)
	_check(int(gm.progress.get("current_level", 0)) == 18, "developer console can select L18")
	_check(gm.selected_object_id == "orion_nebula", "selected target follows the chosen lesson")
	_check(gm.telescope_is_ready(), "prepared level installs required telescope parts")
	gm.debug_launch("telescope", true)
	await process_frame
	_check(current_scene != null and str(current_scene.scene_file_path).contains("telescope_view"), "developer launch opens Telescope View")
	if failures == 0:
		print("DEVELOPER CONSOLE TEST PASS")
		quit(0)
	else:
		print("DEVELOPER CONSOLE TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1
