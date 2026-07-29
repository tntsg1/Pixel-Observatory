extends SceneTree

const OUTPUT_DIR := "res://artifacts/sky_guidance_acceptance"

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.debug_jump_to_level(25, false)
	gm.last_sky_aim = {
		"valid": true,
		"azimuth": 142.0,
		"altitude": 27.0,
		"view_mode": "naked_eye"
	}

	view = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	# Guidance is tested against a stable above-horizon offset; real seasonal
	# visibility is covered separately by the horizon tests.
	var sky: Dictionary = view.get("sky_data")
	var vega: Dictionary = sky.get("vega", {}).duplicate(true)
	vega["azimuth"] = 130.0
	vega["altitude"] = 40.0
	vega["visible"] = true
	vega["below_horizon"] = false
	vega["source"] = "calculated"
	sky["vega"] = vega
	view.set("sky_data", sky)
	gm.publish_sky_positions(sky)
	view.call("_rebuild_view")
	for index in range(5):
		await process_frame

	var banner: Label = view.get("guidance_banner")
	var banner_bg: ColorRect = view.get("guidance_banner_bg")
	var help: Label = view.get("controls_help")
	print("GUIDANCE_TEXT=", banner.text if banner != null else "<missing>")
	_check(banner != null and (banner.text.contains("Hold A") or banner.text.contains("Hold D")), "live guidance names the horizontal movement key")
	_check(banner != null and (banner.text.contains("Hold W") or banner.text.contains("Hold S")), "live guidance names the vertical movement key")
	_check(banner != null and banner.z_index > 0 and banner_bg != null and banner.z_index > banner_bg.z_index, "guidance renders above its opaque backing and moving sky")
	_check(
		help != null
		and help.text.contains("A/D")
		and help.text.contains("W/S")
		and help.text.contains("1/2/3")
		and help.get_theme_font_size("font_size") >= 12,
		"persistent movement legend is readable"
	)
	_check(_visible_han_labels(view).is_empty(), "English sky UI contains no visible Chinese text: %s" % str(_visible_han_labels(view)))

	var mission_hint := _find_label_with_text(view, "Bring Vega into focus")
	_check(mission_hint != null and mission_hint.autowrap_mode != TextServer.AUTOWRAP_OFF, "Vega mission hint wraps")
	_check(mission_hint != null and mission_hint.size.y >= 70.0, "Vega mission hint has enough vertical room")
	_check(mission_hint != null and mission_hint.text.contains("\n"), "long Vega mission hint is split into visible lines")

	var target_item: Dictionary = view.get("sky_data").get("vega", {})
	_check(not target_item.is_empty(), "Vega exists in the sky-position catalog")
	var aim_before: float = absf(view.call("shortest_angle_degrees", view.get("telescope_azimuth"), float(target_item.get("azimuth", 0.0))))
	Input.action_press("move_left")
	view.call("_handle_aim_input", 0.25)
	Input.action_release("move_left")
	var aim_after: float = absf(view.call("shortest_angle_degrees", view.get("telescope_azimuth"), float(target_item.get("azimuth", 0.0))))
	_check(aim_after < aim_before, "pressing A reduces Vega's westward azimuth error")
	view.set("telescope_azimuth", 142.0)
	view.call("_rebuild_view")

	var child_count_before := view.get_child_count()
	gm.language_mode = "zh"
	view.call("_on_language_changed")
	await process_frame
	gm.language_mode = "en"
	view.call("_on_language_changed")
	await process_frame
	_check(view.get_child_count() <= child_count_before, "language switching does not duplicate the UI tree")
	_check(_visible_han_labels(view).is_empty(), "English remains clean after language round trip: %s" % str(_visible_han_labels(view)))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if DisplayServer.get_name() != "headless":
		var viewport_image := root.get_texture().get_image()
		var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/l25_vega_movement_guidance.png")
		var save_error := viewport_image.save_png(output_path)
		_check(save_error == OK, "acceptance screenshot saved")
		print("CAPTURE ", output_path)
	else:
		print("CAPTURE SKIPPED: dummy headless renderer has no viewport texture")

	if failures == 0:
		print("SKY OBSERVATION GUIDANCE TEST PASS")
		quit(0)
	else:
		print("SKY OBSERVATION GUIDANCE TEST FAIL: ", failures)
		quit(1)


func _visible_han_labels(node: Node) -> Array[String]:
	var results: Array[String] = []
	var regex := RegEx.new()
	regex.compile("[一-龥]")
	_collect_han_labels(node, regex, results)
	return results


func _collect_han_labels(node: Node, regex: RegEx, results: Array[String]) -> void:
	if node is Label and node.is_visible_in_tree():
		var label := node as Label
		if regex.search(label.text) != null:
			results.append(label.text)
	for child in node.get_children():
		_collect_han_labels(child, regex, results)


func _find_label_with_text(node: Node, needle: String) -> Label:
	if node is Label and (node as Label).text.contains(needle):
		return node as Label
	for child in node.get_children():
		var found := _find_label_with_text(child, needle)
		if found != null:
			return found
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
