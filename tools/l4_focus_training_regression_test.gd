extends SceneTree

# Verifies the real early-game path with only parts available by L4.
# Run with an isolated user data directory:
# godot --headless --path . --script res://tools/l4_focus_training_regression_test.gd

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		quit(1)
		return

	gm.new_game()
	_complete_naked_eye(gm, 1, "moon")
	_complete_naked_eye(gm, 2, "polaris")
	_complete_basic_refractor(gm)
	_complete_focus_training(gm)

	if failures == 0:
		print("PASS: L1-L4 focus training is completable with period-correct basic equipment")
	quit(1 if failures > 0 else 0)


func _complete_naked_eye(gm: Node, expected_level: int, target_id: String) -> void:
	_check(int(gm.progress.get("current_level", 0)) == expected_level, "L%d is current" % expected_level)
	gm.selected_object_id = target_id
	var observation: Dictionary = gm.evaluate_selected_object()
	_check(bool(observation.get("success", false)), "L%d naked-eye observation succeeds" % expected_level)
	_check(gm.complete_current_mission(target_id, observation), "L%d completes normally" % expected_level)


func _complete_basic_refractor(gm: Node) -> void:
	_check(int(gm.progress.get("current_level", 0)) == 3, "L3 follows L2")
	gm.reset_assembly()
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	_check(bool(gm.can_enter_observation().get("ok", false)), "L3 basic refractor is ready")
	gm.selected_object_id = "moon"
	var observation: Dictionary = gm.evaluate_selected_object()
	_check(bool(observation.get("success", false)), "L3 Moon observation succeeds with basic refractor")
	_check(gm.complete_current_mission("moon", observation), "L3 completes normally")
	_check(gm.progress.get("unlocked_parts", []).has("basic_focus_knob"), "L3 unlocks Basic Focus Knob")


func _complete_focus_training(gm: Node) -> void:
	_check(int(gm.progress.get("current_level", 0)) == 4, "L4 follows L3")
	var level: Dictionary = gm.current_level()
	_check(str(level.get("minimum_success_quality", "")) == "Fair", "L4 explicitly accepts Fair quality")
	_check(not gm.progress.get("unlocked_parts", []).has("objective_100mm"), "100mm objective remains locked at L4")
	_check(not gm.progress.get("unlocked_parts", []).has("stable_mount"), "stable mount remains locked at L4")
	_check(not bool(gm.can_enter_observation().get("ok", true)), "L4 remains blocked until the Focus Knob is installed")

	# Installation goes directly through the Assembly Table path. No Parts
	# Cabinet equip action is needed for the newly unlocked zero-cost knob.
	var install_score: int = gm.install_part("focus_knob", 0, "basic_focus_knob")
	_check(install_score > 0, "Basic Focus Knob installs directly at the Assembly Table")
	_check(str(gm.equipped_part_id("objective")) == "objective_60mm", "L4 still uses the 60mm starter objective")
	_check(str(gm.equipped_part_id("mount")) == "basic_mount", "L4 still uses the basic mount")
	_check(bool(gm.can_enter_observation().get("ok", false)), "L4 observation gate opens after focus knob installation")

	gm.selected_object_id = "jupiter"
	var observation: Dictionary = gm.evaluate_selected_object({
		"focus_error": 0.0,
		"requires_focus": true,
		"focus_tolerance": 0.06,
		"target_off_center": false
	})
	var quality_order := ["Failed", "Poor", "Fair", "Good", "Excellent"]
	var quality := str(observation.get("quality", "Failed"))
	_check(quality_order.find(quality) >= quality_order.find("Fair"), "L4 basic equipment reaches the Fair teaching threshold")
	_check(not bool(observation.get("out_of_focus", true)), "L4 exact focus is inside tolerance")
	_check(bool(observation.get("success", false)), "L4 focused Fair observation passes")
	_check(str(observation.get("feedback_zh", "")) == "图像已清晰，可以识别。", "L4 focused Chinese feedback is instructional")
	var off_center: Dictionary = gm.evaluate_selected_object({
		"focus_error": 0.0,
		"requires_focus": true,
		"focus_tolerance": 0.06,
		"target_off_center": true
	})
	_check(not bool(off_center.get("success", true)), "L4 still requires Jupiter to be centered")

	# Passing Jupiter is the same final gate used by the correct Identify choice.
	_check(not gm.complete_current_mission("mars", observation), "an incorrect identification cannot complete L4")
	_check(gm.complete_current_mission("jupiter", observation), "correctly identified Jupiter completes L4")
	_check(int(gm.progress.get("current_level", 0)) == 5, "L4 advances to L5")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
