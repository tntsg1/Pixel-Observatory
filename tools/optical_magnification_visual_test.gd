extends SceneTree

var failures := 0


func _initialize() -> void:
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	var scale_20mm := float(view.call("_magnification_visual_scale", 40.0, false))
	var scale_10mm := float(view.call("_magnification_visual_scale", 80.0, false))
	_check(scale_10mm > scale_20mm * 1.45,
		"20mm -> 10mm produces an unmistakably larger resolved target")

	var cassegrain_40mm := float(view.call("_magnification_visual_scale", 50.0, false))
	var cassegrain_12mm := float(view.call("_magnification_visual_scale", 166.6667, false))
	_check(cassegrain_12mm > cassegrain_40mm * 1.70,
		"Cassegrain 40mm -> 12mm no longer collapses to one capped size")

	var point_low := float(view.call("_magnification_visual_scale", 40.0, true))
	var point_high := float(view.call("_magnification_visual_scale", 166.6667, true))
	_check(is_equal_approx(point_low, 1.0) and is_equal_approx(point_high, 1.0),
		"stellar point sources remain point-like at higher magnification")

	var source := FileAccess.get_file_as_string("res://scripts/ui/telescope_view.gd")
	_check(source.contains("magnification_zoom"), "extended-field shaders expose optical zoom")
	_check(source.contains("_is_solid_body_target(id)") and
			source.contains("sprite_scale = _magnification_scale() * _object_view_scale(id)"),
		"solid bodies are not forced back under the legacy 380px cap")
	_check(source.contains("436.0 * subject_scale * _magnification_scale()"),
		"true-alpha extended subjects scale inside the fixed field stop")

	_check(source.count("/ magnification_zoom") >= 2,
		"sharp and defocused extended fields retain the same optical magnification")

	view.free()
	print("OPTICAL MAGNIFICATION VISUAL TEST %s" % (
		"PASS" if failures == 0 else "FAIL (%d)" % failures
	))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
