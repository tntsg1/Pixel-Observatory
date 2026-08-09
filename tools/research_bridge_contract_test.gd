extends SceneTree

const TEST_TIMEOUT_SECONDS := 10.0

var failures := 0
var _finished := false


func _initialize() -> void:
	var timeout := create_timer(TEST_TIMEOUT_SECONDS)
	timeout.timeout.connect(_on_timeout)
	await process_frame
	var bridge_script: GDScript = load("res://scripts/systems/research_bridge.gd") as GDScript
	_check(bridge_script != null, "research bridge loads")
	if bridge_script == null:
		_finish(1)
		return
	var bridge: Node = root.get_node_or_null("/root/ResearchBridge")
	_check(bridge != null, "research bridge instantiates")
	if bridge == null:
		_finish(1)
		return
	_check(bridge.has_method("node_for_level"), "bridge exposes checkpoint lookup")
	_check(bridge.has_method("offer_after_level"), "bridge exposes checkpoint offer")
	_check(bridge.has_signal("checkpoint_resolved"), "bridge exposes resolution signal")
	if bridge.has_method("node_for_level"):
		_check(str(bridge.call("node_for_level", 1)) == "baseline", "bridge maps L1 to baseline")
		_check(str(bridge.call("node_for_level", 6)) == "A", "bridge maps L6 to node A")
		_check(str(bridge.call("node_for_level", 11)) == "B", "bridge maps L11 to node B")
		_check(str(bridge.call("node_for_level", 16)) == "C", "bridge maps L16 to node C")
		_check(str(bridge.call("node_for_level", 21)) == "D", "bridge maps L21 to node D")
		_check(str(bridge.call("node_for_level", 24)) == "E", "bridge maps L24 to node E")
		_check(str(bridge.call("node_for_level", 5)).is_empty(), "bridge ignores non-checkpoint levels")
	if bridge.has_method("offer_after_level"):
		_check(not bool(bridge.call("offer_after_level", 1, "observatory")), "native gameplay falls through")
		_check(not bool(bridge.call("offer_after_level", 5, "observatory")), "non-checkpoint gameplay falls through")
	await _check_browser_permission_gate(bridge)
	await _check_original_continuation(bridge)
	await _check_level_24_single_consumption(bridge)
	_finish(0 if failures == 0 else 1)


func _check_browser_permission_gate(bridge: Node) -> void:
	_check(bridge.has_method("_can_offer_checkpoint"), "bridge exposes a testable browser permission gate")
	if not bridge.has_method("_can_offer_checkpoint"):
		return
	_check(
		bool(bridge.call("_can_offer_checkpoint", 1, {"canOfferBaseline": true})),
		"L1 baseline hook can offer without a participant or token"
	)
	_check(
		not bool(bridge.call("_can_offer_checkpoint", 1, {})),
		"ordinary page without the baseline hook falls through"
	)
	_check(
		not bool(bridge.call("_can_offer_checkpoint", 6, {
			"participantId": "participant-1",
			"token": "forged-token",
			"routeArm": "field_gameplay",
			"query": {"token": "forged-token", "research_arm": "field_gameplay"},
		})),
		"forged query context cannot unlock a later checkpoint"
	)
	_check(
		bool(bridge.call("_can_offer_checkpoint", 6, {"hasVerifiedGameplaySession": true})),
		"later checkpoint requires and accepts the verified-session hook"
	)
	_check(
		not bool(bridge.call("_can_offer_checkpoint", 6, {"canOfferBaseline": true})),
		"baseline permission cannot unlock a later checkpoint"
	)
	var baseline_detail: Dictionary = bridge.call("_prepare_checkpoint", 1, "observatory", {"canOfferBaseline": true})
	_check(str(baseline_detail.get("nodeId", "")) == "baseline", "L1 baseline is actually prepared through the permission gate")
	bridge.call("_on_browser_continue", [JSON.stringify({"nodeId": "baseline"})])


func _check_level_24_single_consumption(bridge: Node) -> void:
	_check(bridge.has_method("_prepare_checkpoint"), "bridge exposes checkpoint preparation state")
	if not bridge.has_method("_prepare_checkpoint"):
		return
	var graduation_scene: PackedScene = load("res://scenes/study_graduation.tscn") as PackedScene
	_check(graduation_scene != null, "study graduation scene loads for one-time consumption")
	if graduation_scene == null:
		return
	var first_detail: Dictionary = bridge.call("_prepare_checkpoint", 24, "study_graduation", _verified_context())
	_check(str(first_detail.get("nodeId", "")) == "E", "L24 checkpoint is prepared once")
	bridge.call("_on_browser_continue", [JSON.stringify({"nodeId": "E"})])
	var resume_node_ids: Dictionary = bridge.get("_resume_node_ids") as Dictionary
	_check(resume_node_ids.has("E"), "bridge marks resolved E for graduation consumption")
	var graduation: Control = graduation_scene.instantiate() as Control
	_check(graduation != null, "study graduation instantiates")
	if graduation == null:
		return
	root.add_child(graduation)
	await process_frame
	_check(not bool(bridge.call("consume_resolved_checkpoint", "E")), "study graduation consumes the resolved E checkpoint")
	var second_detail: Dictionary = bridge.call("_prepare_checkpoint", 24, "study_graduation", _verified_context())
	_check(second_detail.is_empty(), "resolved L24 checkpoint cannot be offered again")
	graduation.queue_free()
	await process_frame


func _check_original_continuation(bridge: Node) -> void:
	if not bridge.has_method("_prepare_checkpoint"):
		return
	var learning_card_script: GDScript = load("res://scripts/ui/learning_card.gd") as GDScript
	_check(learning_card_script != null, "learning card loads for continuation regression")
	if learning_card_script == null:
		return
	var learning_card: Node = learning_card_script.new() as Node
	_check(learning_card.has_method("_continue_after_completion"), "learning card keeps original continuation as a callable path")
	if not learning_card.has_method("_continue_after_completion"):
		learning_card.free()
		return
	var gm: Node = root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager autoload exists for continuation regression")
	if gm == null:
		learning_card.free()
		return
	gm.new_game()
	gm.debug_jump_to_level(5, true)
	_check(gm.complete_current_mission("jupiter", {
		"success": true,
		"quality": "Good",
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0},
	}), "continuation fixture completes L5")
	_check(str(gm.pending_mission_setup_scene()) == "assembly", "continuation fixture requires L6 assembly")
	var continuation_state := {"called": false}
	var continuation := func() -> void:
		continuation_state["called"] = true
		learning_card.call("_continue_after_completion", 5, false)
	var detail: Dictionary = bridge.call("_prepare_checkpoint", 6, "observatory", _verified_context(), continuation)
	_check(str(detail.get("nodeId", "")) == "A", "continuation checkpoint is prepared")
	bridge.call("_on_browser_continue", [JSON.stringify({"nodeId": "A"})])
	await process_frame
	_check(bool(continuation_state["called"]), "bridge callback invokes the saved original continuation")
	_check(str(gm.current_learning_card_mode()) == "brief", "pending assembly teaching intercept is preserved")
	gm.complete_current_brief()
	await process_frame
	var current_scene_path := current_scene.scene_file_path if current_scene != null else ""
	_check(current_scene_path.ends_with("telescope_assembly.tscn"), "checkpoint continuation enters pending mission setup")
	learning_card.free()


func _verified_context() -> Dictionary:
	return {
		"hasVerifiedGameplaySession": true,
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
		return
	failures += 1
	push_error("  FAIL: " + label)


func _on_timeout() -> void:
	if _finished:
		return
	push_error("RESEARCH BRIDGE CONTRACT TEST TIMEOUT")
	_finish(1)


func _finish(exit_code: int) -> void:
	if _finished:
		return
	_finished = true
	quit(exit_code)
