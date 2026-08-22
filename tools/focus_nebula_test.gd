extends SceneTree

# Deep-sky focus regression test: Orion Nebula must be focusable.
# Run: godot --headless --script res://tools/focus_nebula_test.gd
# NOTE: resets the save - back it up before running.

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
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = 7
	gm.call("_unlock_parts_for_current_level")
	gm.call("reset_assembly")
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "orion_nebula"

	# --- L7 basic parts: Fair is acceptable for the first nebula mission --------
	var scene: PackedScene = load("res://scenes/telescope_view.tscn")
	var probe: Node = scene.instantiate()
	root.add_child(probe)

	var target: float = float(probe.get("target_focus_value"))
	var tolerance: float = float(probe.get("focus_tolerance"))
	print("--- L7 orion_nebula focus diagnostics (basic parts) ---")
	print("  focus_value=%.4f target_focus_value=%.4f focus_error=%.4f tolerance=%.4f" % [
		float(probe.get("focus_value")), target, float(probe.get("focus_error")), tolerance
	])
	print("  is_focus_acceptable=%s is_quality_acceptable=%s" % [
		probe.call("is_focus_acceptable"), probe.call("is_quality_acceptable")
	])
	_check(target >= 0.0 and target <= 1.0, "target_focus_value within 0..1 (%.3f)" % target)
	_check(tolerance >= 0.06, "deep-sky tolerance is not too narrow (%.3f >= 0.06)" % tolerance)

	# exact focus -> acceptable + sharp, never "adjust focus"
	probe.call("_set_focus_value", target)
	var error_at_target: float = float(probe.get("focus_error"))
	print("  after set to target: focus_error=%.5f state=%s acceptable=%s quality=%s" % [
		error_at_target, probe.call("_focus_state"), probe.call("is_focus_acceptable"),
		probe.get("observation").get("quality")
	])
	_check(error_at_target < 0.0001, "focus_error ~0 at exact target")
	_check(bool(probe.call("is_focus_acceptable")), "is_focus_acceptable true at exact target")
	_check(str(probe.call("_focus_state")) == "sharp", "_focus_state sharp at exact target")
	_check(is_zero_approx(float(probe.call("_target_blur_weight"))), "exact focus uses the sharp nebula texture state")
	var slider: HSlider = probe.get("focus_slider")
	_check(slider != null and absf(slider.value - float(probe.get("focus_value"))) <= float(slider.step) + 0.0001, "slider value matches focus_value (within one step)")

	var feedback: String = str(probe.call("_current_feedback"))
	_check(str(probe.get("observation").get("quality")) == "Fair", "L7 basic Orion remains Fair, not secretly Good")
	_check(bool(probe.call("is_quality_acceptable")), "L7 Fair quality is acceptable")
	_check(bool(probe.call("can_identify_object")), "L7 focused Fair nebula can be identified")
	_check(feedback.contains("Ready to identify"), "L7 Fair feedback says ready, not equipment blocked")

	# far off focus -> not acceptable, asks to adjust
	probe.call("_set_focus_value", clampf(target + 0.2, 0.0, 1.0))
	print("  after +0.2 offset: focus_error=%.4f state=%s acceptable=%s" % [
		float(probe.get("focus_error")), probe.call("_focus_state"), probe.call("is_focus_acceptable")
	])
	_check(not bool(probe.call("is_focus_acceptable")), "is_focus_acceptable false at +0.2 offset")
	_check(float(probe.call("_target_blur_weight")) > 0.95, "off-focus nebula keeps the blurry texture state")
	_check(str(probe.call("_current_feedback")).contains("Adjust focus"), "off-focus feedback asks to adjust")
	probe.queue_free()
	await process_frame

	# Mission completion should accept the L7 Fair observation.
	var fair_obs: Dictionary = {
		"quality": "Fair",
		"success": true,
		"observation_mode": "telescope",
		"focus_error": 0.0
	}
	_check(gm.complete_current_mission("orion_nebula", fair_obs), "L7 Fair Orion mission completes")
	await process_frame
	_check(int(gm.progress.get("current_level", 0)) == 8, "L7 completion advances to L8")

	# --- L8 basic parts: focus is sharp, but equipment is now the blocker -------
	gm.call("reset_assembly")
	gm.equip_part("objective_60mm")
	gm.equip_part("basic_mount")
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "orion_nebula"
	var probe_l8_basic: Node = scene.instantiate()
	root.add_child(probe_l8_basic)
	probe_l8_basic.call("_set_focus_value", probe_l8_basic.get("target_focus_value"))
	var l8_feedback: String = str(probe_l8_basic.call("_current_feedback"))
	print("--- L8 basic parts: quality=%s can_identify=%s feedback=%s" % [
		probe_l8_basic.get("observation").get("quality"),
		probe_l8_basic.call("can_identify_object"),
		l8_feedback
	])
	_check(bool(probe_l8_basic.call("is_focus_acceptable")), "L8 basic focus is acceptable at exact target")
	_check(str(probe_l8_basic.get("observation").get("quality")) == "Fair", "L8 basic Orion is Fair")
	_check(not bool(probe_l8_basic.call("is_quality_acceptable")), "L8 Fair quality is not acceptable")
	_check(not bool(probe_l8_basic.call("can_identify_object")), "L8 focused Fair nebula cannot be identified")
	var l8_feedback_lower := l8_feedback.to_lower()
	_check(l8_feedback_lower.contains("aperture") or l8_feedback_lower.contains("stable") or l8_feedback_lower.contains("equipment") or l8_feedback_lower.contains("equip"), "L8 feedback names equipment/aperture/stability")
	_check(not l8_feedback.contains("Adjust focus"), "L8 in-focus equipment blocker never says adjust focus")
	probe_l8_basic.queue_free()
	await process_frame

	# --- L8 upgraded parts: quality passes and identify becomes possible --------
	gm.equip_part("objective_100mm")
	gm.equip_part("stable_mount")
	gm.call("reset_assembly")
	for part_type in gm.current_level().get("required_parts", []):
		gm.install_part(str(part_type), 0)
	gm.selected_object_id = "orion_nebula"
	var probe2: Node = scene.instantiate()
	root.add_child(probe2)
	probe2.call("_set_focus_value", probe2.get("target_focus_value"))
	print("--- upgraded parts: quality=%s can_identify=%s" % [
		probe2.get("observation").get("quality"), probe2.call("can_identify_object")
	])
	_check(bool(probe2.call("is_quality_acceptable")), "upgraded telescope reaches acceptable quality on the nebula")
	_check(bool(probe2.call("can_identify_object")), "upgraded + focused nebula can be identified")
	_check(str(probe2.call("_current_feedback")).contains("Ready to identify"), "upgraded feedback says ready")
	probe2.queue_free()

	if failures == 0:
		print("FOCUS NEBULA TEST PASS")
		quit(0)
	else:
		print("FOCUS NEBULA TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
