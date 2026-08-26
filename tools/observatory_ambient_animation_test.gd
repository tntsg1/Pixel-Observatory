extends SceneTree

# Verifies the observatory's continuous ambient layer without replacing the
# supplied painted hall or interfering with the existing furniture rigs.

var failures := 0
var room: Control
var ambient: ObservatoryAmbientAnimator


func _initialize() -> void:
	await process_frame
	await process_frame
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	room = scene.instantiate()
	root.add_child(room)
	await process_frame

	ambient = room.get_node_or_null("AmbientAnimator") as ObservatoryAmbientAnimator
	_check(ambient != null, "ambient animator is present")
	if ambient == null:
		_finish()
		return

	_check(ambient.light_rigs.size() == 8, "eight local lamp sources are registered")
	_check(ambient.screen_rigs.size() == 2, "two screen refresh regions are registered")
	_check(ambient.dust_rigs.size() == 5, "dust layer stays intentionally sparse")
	_check(ambient.activity != null, "workbench micro-activity layer is present")
	var workbench_screen: Dictionary = ambient.screen_rigs[0]
	var screen_root := workbench_screen["root"] as Control
	_check(screen_root.z_index == 5, "screen refresh sits above the baked screen raster only")

	var scanline := workbench_screen["scanline"] as ColorRect
	var initial_y := scanline.position.y
	await create_timer(0.28).timeout
	_check(not is_equal_approx(scanline.position.y, initial_y), "screen scanline advances while idle")
	var first_flame := ambient.light_rigs[0]["flame"] as ObservatoryAmbientAnimator.AmbientFlame
	_check(absf(first_flame.sway) > 0.01, "lamp flame receives a small asymmetric sway")

	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	_check(feedback != null, "interaction feedback autoload is available")
	if feedback != null:
		var previous := bool(feedback.get("reduced_motion"))
		feedback.set("reduced_motion", true)
		await process_frame
		await process_frame
		_check(is_equal_approx(scanline.position.y, 3.0), "reduced motion pins the scanline to a quiet position")
		_check(bool(ambient.activity.get("reduced_motion")), "reduced motion suppresses workbench glints")
		feedback.set("reduced_motion", previous)
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1


func _finish() -> void:
	if failures == 0:
		print("OBSERVATORY AMBIENT ANIMATION TEST PASS")
		quit(0)
	else:
		print("OBSERVATORY AMBIENT ANIMATION TEST FAIL (%d failures)" % failures)
		quit(1)
