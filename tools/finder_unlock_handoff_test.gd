extends SceneTree

# Regression: completing L5 unlocks the finder scope, but L6 must not skip
# installation and enter its story/observation flow with the old telescope.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return

	gm.new_game()
	gm.debug_jump_to_level(5, true)
	var finder_before: Dictionary = gm.progress.get("assembly_state", {}).get("finder_scope", {})
	_check(not bool(finder_before.get("installed", false)), "L5 telescope does not already contain the finder")
	_check(gm.complete_current_mission("jupiter", {
		"success": true,
		"quality": "Good",
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0},
	}), "L5 completion succeeds")
	_check(int(gm.progress.get("current_level", 0)) == 6, "completion advances to L6")
	_check(gm.progress.get("unlocked_parts", []).has("basic_finder_scope"), "L5 reward unlocks the finder scope")

	var route: Dictionary = gm.current_room_route()
	_check(str(route.get("target", "")) == "assembly", "L6 route points to the Assembly Table")
	_check(not bool(route.get("ready", true)), "L6 route is blocked until installation")
	_check((route.get("missing", []) as Array).has("finder_scope"), "route names finder scope as missing")
	_check(str(gm.pending_mission_setup_scene()) == "assembly", "mission Continue resolves to the install screen")

	var gate: Dictionary = gm.can_enter_observation()
	_check(not bool(gate.get("ok", true)), "observation is blocked before finder installation")
	_check(str(gate.get("reason_en", "")).contains("Finder Scope"), "observation gate explains the missing finder")
	_check(gm.go_to_pending_mission_setup(), "mission Continue consumes the mandatory setup route")
	await process_frame
	_check(str(gm.current_learning_card_mode()) == "brief", "first-time finder explanation appears before installation")
	gm.complete_current_brief()
	await process_frame
	var current_scene_path := current_scene.scene_file_path if current_scene != null else ""
	_check(current_scene_path.ends_with("telescope_assembly.tscn"), "finder explanation continues directly to the install screen")

	var finder_score: int = gm.install_part("finder_scope", 0, "basic_finder_scope")
	_check(finder_score >= 0, "finder installs from the unlocked reward")
	_check(bool(gm.can_enter_observation().get("ok", false)), "observation opens only after finder installation")

	if failures == 0:
		print("FINDER UNLOCK HANDOFF TEST PASS")
		quit(0)
	else:
		print("FINDER UNLOCK HANDOFF TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
