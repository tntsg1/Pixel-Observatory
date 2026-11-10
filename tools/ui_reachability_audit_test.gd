extends SceneTree

const EXPECTED_LIVE_KEYS := [
	"menu", "observatory", "interior", "parts", "assembly", "advanced_assembly",
	"telescope_types", "world_map", "optical_tube_assembly", "collimation",
	"radio_observation", "multi_observation", "space_observation", "constellation",
	"sky", "telescope", "journal", "card", "story", "graduation", "study_graduation",
]

const LEGACY_PROTOTYPE_SCENES := [
	"res://scenes/main.tscn",
	"res://scenes/levels/level1.tscn",
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/pause_menu.tscn",
]

var failures := 0


func _initialize() -> void:
	await process_frame
	var game_manager := root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload is available")
	var routes: Dictionary = {}
	if game_manager != null:
		var constants: Dictionary = game_manager.get_script().get_script_constant_map()
		routes = constants.get("SCENES", {})
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_check(project_source.contains('run/main_scene="res://scenes/main_menu.tscn"'), "project starts from the astronomy main menu")
	for key in EXPECTED_LIVE_KEYS:
		_check(routes.has(key), "live route '%s' is registered" % key)
		if routes.has(key):
			_check(ResourceLoader.exists(str(routes[key])), "live route '%s' resolves" % key)
	for key in routes.keys():
		_check(EXPECTED_LIVE_KEYS.has(str(key)), "registered route '%s' is documented as live" % str(key))
	for scene_path in LEGACY_PROTOTYPE_SCENES:
		_check(ResourceLoader.exists(scene_path), "legacy prototype remains available for isolated regression coverage: %s" % scene_path)
		_check(not routes.values().has(scene_path), "legacy prototype is unreachable from the astronomy route table: %s" % scene_path)
	if failures == 0:
		print("UI REACHABILITY AUDIT TEST PASS")
		quit(0)
	else:
		push_error("UI REACHABILITY AUDIT TEST FAIL: %d issue(s)" % failures)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
		return
	failures += 1
	push_error("FAIL: " + message)
