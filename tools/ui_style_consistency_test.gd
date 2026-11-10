extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	_check(ResourceLoader.exists("res://scripts/ui/observatory_ui_style.gd"), "shared observatory UI style module exists")
	await _check_screen("res://scenes/learning_journal.tscn", "ObservatoryBackdrop", "ArchiveHeader")
	await _check_screen("res://scenes/parts_cabinet.tscn", "ObservatoryBackdrop", "CabinetHeader")
	await _check_screen("res://scenes/study_graduation.tscn", "ObservatoryBackdrop", "StudyGraduationHeader")
	await _check_world_map_panel()
	var telescope_types_source := FileAccess.get_file_as_string("res://scripts/ui/telescope_types.gd")
	_check(telescope_types_source.contains("observatory_ui_style.gd"), "telescope catalog uses the shared observatory palette")
	if failures == 0:
		print("UI STYLE CONSISTENCY TEST PASS")
		quit(0)
	else:
		push_error("UI STYLE CONSISTENCY TEST FAIL: %d issue(s)" % failures)
		quit(1)


func _check_screen(scene_path: String, backdrop_name: String, header_name: String) -> void:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path)
	if packed == null:
		return
	var screen := packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	await process_frame
	var backdrop := screen.find_child(backdrop_name, true, false)
	var header := screen.find_child(header_name, true, false)
	_check(backdrop is TextureRect and (backdrop as TextureRect).texture != null, "%s uses the observatory artwork" % scene_path)
	_check(header is Panel, "%s exposes a framed header" % scene_path)
	screen.queue_free()
	await process_frame


func _check_world_map_panel() -> void:
	var game_manager := root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager is available for the world map visual check")
	if game_manager == null:
		return
	game_manager.new_game()
	game_manager.progress["seen_teaching_steps"] = ["world_map_controls_v1", "below_horizon_flow_v1"]
	var packed := load("res://scenes/world_map.tscn") as PackedScene
	_check(packed != null, "world map scene loads")
	if packed == null:
		return
	var screen := packed.instantiate() as Control
	root.add_child(screen)
	await process_frame
	await process_frame
	var info := screen.find_child("SiteInfoPanel", true, false)
	_check(info is Panel, "world map site data uses a framed instrument panel")
	if info is Panel:
		_check((info as Panel).get_theme_stylebox("panel") is StyleBoxFlat, "world map site panel exposes an explicit surface style")
	screen.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
		return
	failures += 1
	push_error("FAIL: " + message)
