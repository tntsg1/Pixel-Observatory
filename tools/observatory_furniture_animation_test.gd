extends SceneTree

# Verifies that every observatory station except the central telescope has a
# reusable open/close rig and that repeated input cannot duplicate transitions.

const FURNITURE_IDS := [
	"cabinet",
	"door",
	"mission",
	"assembly",
	"journal",
	"computer",
]

var failures := 0
var room: Control
var animator: ObservatoryFurnitureAnimator
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	await process_frame
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	room = scene.instantiate()
	root.add_child(room)
	await process_frame

	animator = room.get_node_or_null("FurnitureAnimator") as ObservatoryFurnitureAnimator
	_check(animator != null, "furniture animator is present")
	if animator == null:
		_finish()
		return

	for id in FURNITURE_IDS:
		_check(animator.has_rig(id), "%s has an animation rig" % id)
	_check(not animator.has_rig("telescope"), "central telescope is intentionally untouched")
	_check(animator.rigs.size() == FURNITURE_IDS.size(), "only the six non-telescope stations are animated")
	var assembly_rig: Dictionary = animator.rigs.get("assembly", {})
	_check(str(assembly_rig.get("mode", "")) == "workbench", "assembly uses a dedicated workbench activation instead of a drawer")
	_check(assembly_rig.get("focus_frame") is Control, "assembly activation includes a blueprint focus frame")

	await _check_open_close_cycle()
	await _check_repeated_input_guard()
	await _check_reduced_motion()
	await _check_return_close_cycle()
	_finish()


func _check_open_close_cycle() -> void:
	for id in FURNITURE_IDS:
		var callback_state := {"count": 0}
		animator.play_open(id, func() -> void: callback_state["count"] = int(callback_state["count"]) + 1)
		_check(animator.is_animating(id), "%s enters opening state" % id)
		await create_timer(0.86).timeout
		_check(animator.is_open(id), "%s reaches open state" % id)
		_check(int(callback_state["count"]) == 1, "%s open callback runs once" % id)

		animator.play_close(id, func() -> void: callback_state["count"] = int(callback_state["count"]) + 1)
		_check(animator.is_animating(id), "%s enters closing state" % id)
		await create_timer(0.72).timeout
		_check(not animator.is_open(id) and not animator.is_animating(id), "%s reaches closed state" % id)
		_check(int(callback_state["count"]) == 2, "%s close callback runs once" % id)


func _check_repeated_input_guard() -> void:
	var action_state := {"count": 0}
	room.call("_play_furniture_action", "cabinet", func() -> void: action_state["count"] = int(action_state["count"]) + 1)
	room.call("_play_furniture_action", "cabinet", func() -> void: action_state["count"] = int(action_state["count"]) + 1)
	_check(bool(room.get("furniture_interaction_active")), "room locks interaction during furniture motion")
	await create_timer(0.72).timeout
	_check(int(action_state["count"]) == 1, "repeated interaction starts only one action")
	_check(not bool(room.get("furniture_interaction_active")), "interaction unlocks after animation")
	animator.play_close("cabinet")
	await create_timer(0.60).timeout


func _check_reduced_motion() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	_check(feedback != null, "interaction feedback autoload is available")
	if feedback == null:
		return
	var previous := bool(feedback.get("reduced_motion"))
	feedback.set("reduced_motion", true)
	animator.play_open("door")
	await create_timer(0.14).timeout
	_check(animator.is_animating("door"), "reduced motion preserves a readable open cadence")
	await create_timer(0.38).timeout
	_check(animator.is_open("door"), "reduced motion completes the open feedback")
	animator.play_close("door")
	await create_timer(0.12).timeout
	_check(animator.is_animating("door"), "reduced motion preserves a readable close cadence")
	await create_timer(0.32).timeout
	_check(not animator.is_open("door"), "reduced motion completes the close feedback")
	feedback.set("reduced_motion", previous)


func _check_return_close_cycle() -> void:
	var game_manager := root.get_node_or_null("/root/GameManager")
	_check(game_manager != null, "game manager is available for return-state test")
	if game_manager == null:
		return
	game_manager.call("set_observatory_spawn", "assembly")
	room.queue_free()
	await process_frame
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	room = scene.instantiate()
	root.add_child(room)
	await process_frame
	animator = room.get_node("FurnitureAnimator") as ObservatoryFurnitureAnimator
	var rig: Dictionary = animator.rigs.get("assembly", {})
	var workbench := (rig.get("doors", []) as Array)[0] as Control
	var closed_position := workbench.position
	await create_timer(0.12).timeout
	_check(animator.is_animating("assembly"), "returning from assembly visibly powers down its work surface")
	_check(workbench.position.is_equal_approx(closed_position), "workbench feedback never pulls the furniture outward")
	await create_timer(0.48).timeout
	_check(not animator.is_open("assembly") and not animator.is_animating("assembly"), "return close cycle finishes cleanly")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1


func _finish() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
	if failures == 0:
		print("OBSERVATORY FURNITURE ANIMATION TEST PASS")
		quit(0)
	else:
		print("OBSERVATORY FURNITURE ANIMATION TEST FAIL (%d failures)" % failures)
		quit(1)
