extends SceneTree

const CAPTURE_PATH := "user://sky_observation_typography_zh.png"

var failures: Array[String] = []
var frames := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Sky-observation typography test requires GameManager.")
		quit(1)
		return
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["current_level"] = 1
	var scene: PackedScene = load("res://scenes/sky_observation.tscn")
	root.add_child(scene.instantiate())
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames == 30:
		var view := _view()
		var target_id: String = str(view.get("target_id"))
		var sky_data: Dictionary = view.get("sky_data")
		var item: Dictionary = sky_data.get(target_id, {})
		view.set("telescope_azimuth", float(item.get("azimuth", 180.0)) - 4.0)
		view.set("telescope_altitude", float(item.get("altitude", 45.0)) + 3.0)
		view.call("_rebuild_view")
		view.call("_select_object", target_id)
	if frames == 90:
		_check_label("selected_badge", 12)
		_check_label("selected_title", 14)
		_check_label("selected_detail", 11)
		_check_label("aim_label", 11)
		_check_label("guidance_label", 11)
		var detail := _view().get("selected_detail") as Label
		_expect(detail.text.count("\n") <= 3, "selected details stay within four rows")
		_expect(not detail.has_theme_color_override("font_shadow_color"), "selected details have no text shadow")
		var error := root.get_texture().get_image().save_png(CAPTURE_PATH)
		_expect(error == OK, "saved Chinese sky-observation reference image")
		if failures.is_empty():
			print("SKY OBSERVATION TYPOGRAPHY TEST PASS")
		else:
			for failure in failures:
				push_error(failure)
			print("SKY OBSERVATION TYPOGRAPHY TEST FAIL: %d issue(s)" % failures.size())
		quit(0 if failures.is_empty() else 1)


func _view() -> Node:
	return root.get_child(root.get_child_count() - 1)


func _check_label(property_name: String, minimum_size: int) -> void:
	var label := _view().get(property_name) as Label
	_expect(label != null, "%s exists" % property_name)
	if label == null:
		return
	_expect(label.get_theme_font_size("font_size") >= minimum_size, "%s is at least %d px" % [property_name, minimum_size])


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures.append(message)
