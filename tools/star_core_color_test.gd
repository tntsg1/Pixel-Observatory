extends SceneTree

# Star-identification targets must retain distinct intrinsic core colours.
# Chromatic aberration may add red/blue fringes, but it must not turn every
# stellar source into the same white center.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	_check(gm != null and view != null, "test fixtures load")
	if gm == null or view == null:
		_finish()
		return

	var tints: Dictionary = {}
	for object_id in ["sirius", "polaris", "betelgeuse", "canopus"]:
		view.set("selected_object", gm.get_object(object_id))
		tints[object_id] = view.call("_target_star_source_tint") as Color

	var sirius: Color = tints["sirius"]
	var polaris: Color = tints["polaris"]
	var betelgeuse: Color = tints["betelgeuse"]
	var canopus: Color = tints["canopus"]
	_check(sirius.b - sirius.r >= 0.55, "Sirius core is visibly blue-white")
	_check(betelgeuse.r - betelgeuse.b >= 0.80, "Betelgeuse core is visibly orange-red")
	_check(canopus.r - canopus.b >= 0.65 and canopus.g >= 0.65, "Canopus core is visibly yellow-white")
	_check(polaris.r - polaris.b <= 0.20 and polaris.b >= 0.70, "Polaris remains a neutral warm white")
	for pair in [
		["sirius", "polaris"],
		["sirius", "betelgeuse"],
		["sirius", "canopus"],
		["polaris", "betelgeuse"],
		["polaris", "canopus"],
		["betelgeuse", "canopus"],
	]:
		var left: Color = tints[str(pair[0])]
		var right: Color = tints[str(pair[1])]
		var distance := Vector3(left.r, left.g, left.b).distance_to(Vector3(right.r, right.g, right.b))
		_check(distance >= 0.20, "%s and %s cores remain distinguishable" % [pair[0], pair[1]])

	view.queue_free()
	_finish()


func _finish() -> void:
	print("STAR CORE COLOR TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
