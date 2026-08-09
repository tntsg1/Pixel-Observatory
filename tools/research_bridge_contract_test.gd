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
	bridge.free()
	_finish(0 if failures == 0 else 1)


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
