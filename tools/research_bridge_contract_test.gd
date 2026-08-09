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
	var bridge: Node = bridge_script.new() as Node
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
	await _check_research_session_gate(bridge)
	await _check_level_24_single_consumption(bridge)
	await _check_original_continuation(bridge)
	bridge.free()
	_finish(0 if failures == 0 else 1)


func _check_research_session_gate(bridge: Node) -> void:
	_check(bridge.has_method("_is_active_research_context"), "bridge exposes a testable research-session gate")
	if not bridge.has_method("_is_active_research_context"):
		return
	_check(
		not bool(bridge.call("_is_active_research_context", {})),
		"ordinary Web context falls through"
	)
	_check(
		not bool(bridge.call("_is_active_research_context", {
			"participantId": "prestudy-local",
			"token": "",
			"routeArm": "",
			"verified": false,
		})),
		"local prestudy session falls through"
	)
	_check(
		not bool(bridge.call("_is_active_research_context", {
			"participantId": "participant-1",
			"token": "active-token",
			"routeArm": "field_gameplay",
			"verified": false,
		})),
		"unverified token and arm fall through"
	)
	_check(
		bool(bridge.call("_is_active_research_context", {
			"participantId": "participant-1",
			"token": "active-token",
			"routeArm": "field_gameplay",
			"verified": true,
		})),
		"verified active token and arm pass the gate"
	)


func _check_level_24_single_consumption(bridge: Node) -> void:
	_check(bridge.has_method("_prepare_checkpoint"), "bridge exposes checkpoint preparation state")
	if not bridge.has_method("_prepare_checkpoint"):
		return
	var context := _verified_context()
	var first_detail: Dictionary = bridge.call("_prepare_checkpoint", 24, "study_graduation", context)
	_check(str(first_detail.get("nodeId", "")) == "E", "L24 checkpoint is prepared once")
	bridge.call("_on_browser_continue", [JSON.stringify({"nodeId": "E"})])
	var second_detail: Dictionary = bridge.call("_prepare_checkpoint", 24, "study_graduation", context)
	_check(second_detail.is_empty(), "resolved L24 checkpoint cannot be offered again")


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
	bridge.checkpoint_resolved.connect(func(action: String, _node_id: String) -> void:
		if action != "continue":
			return
		continuation_state["called"] = true
		learning_card.call("_continue_after_completion", 5, false)
	, CONNECT_ONE_SHOT)
	var detail: Dictionary = bridge.call("_prepare_checkpoint", 6, "observatory", _verified_context())
	_check(str(detail.get("nodeId", "")) == "A", "continuation checkpoint is prepared")
	bridge.call("_on_browser_continue", [JSON.stringify({"nodeId": "A"})])
	await process_frame
	_check(bool(continuation_state["called"]), "checkpoint callback invokes the original caller continuation")
	_check(str(gm.current_learning_card_mode()) == "brief", "pending assembly teaching intercept is preserved")
	gm.complete_current_brief()
	await process_frame
	var current_scene_path := current_scene.scene_file_path if current_scene != null else ""
	_check(current_scene_path.ends_with("telescope_assembly.tscn"), "checkpoint continuation enters pending mission setup")
	learning_card.free()


func _verified_context() -> Dictionary:
	return {
		"participantId": "participant-1",
		"token": "active-token",
		"routeArm": "field_gameplay",
		"verified": true,
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
