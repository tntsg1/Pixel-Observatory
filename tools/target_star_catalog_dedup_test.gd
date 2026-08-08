extends SceneTree

# The real-sky HYG layer and the analytical target layer must not draw the
# selected star twice. A neutral catalog PSF stacked over Sirius used to wash
# its blue target core to white while the result thumbnail stayed blue.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var view := load("res://scenes/telescope_view.tscn").instantiate() as Control
	_check(gm != null and view != null, "test fixtures load")
	if gm == null or view == null:
		_finish()
		return

	view.set("selected_object", gm.get_object("sirius"))
	var sirius_radec: Dictionary = gm.object_radec("sirius")
	_check(
		view.call(
			"_catalog_star_matches_selected_target",
			[6.7525, -16.716, -1.44],
			sirius_radec
		),
		"Sirius HYG entry is excluded from the background layer"
	)
	_check(
		not view.call(
			"_catalog_star_matches_selected_target",
			[6.7540, -16.716, 5.0],
			sirius_radec
		),
		"nearby field stars remain visible"
	)
	view.set("selected_object", gm.get_object("moon"))
	_check(
		not view.call(
			"_catalog_star_matches_selected_target",
			[6.7525, -16.716, -1.44],
			{}
		),
		"non-stellar targets do not remove catalog stars"
	)

	view.queue_free()
	_finish()


func _finish() -> void:
	print("TARGET STAR CATALOG DEDUP TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
