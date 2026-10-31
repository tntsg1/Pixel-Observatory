extends SceneTree

const OUTPUT_DIR := "res://artifacts/focus_state_summary_acceptance"

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		_fail("required autoload is missing")
		quit(1)
		return

	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.debug_jump_to_level(4, true)
	var observation := _observation()
	gm.last_learning_card = teaching.make_mission_complete_payload(
		gm.current_level(),
		gm.get_object("jupiter"),
		observation,
		{"light_score": 78.0, "clarity_score": 78.0, "stability_score": 70.0, "magnification": 40.0}
	)
	teaching.active_card_mode = "complete"
	await _open_card()
	var all_text := _collect_label_text(view)
	_check(all_text.contains("失焦"), "Chinese summary labels the out-of-focus state")
	_check(all_text.contains("接近焦点"), "Chinese summary labels the near-focus state")
	_check(all_text.contains("准焦"), "Chinese summary labels the in-focus state")
	_check(_focus_area_texture_count(view) >= 4, "focus comparison uses layered real target textures")
	await _capture("jupiter_focus_states_zh.png")

	view.queue_free()
	await process_frame
	gm.debug_jump_to_level(3, true)
	gm.last_learning_card = teaching.make_mission_complete_payload(
		gm.current_level(),
		gm.get_object("moon"),
		_observation(),
		{"light_score": 70.0, "clarity_score": 70.0, "stability_score": 65.0, "magnification": 35.0}
	)
	teaching.active_card_mode = "complete"
	await _open_card()
	all_text = _collect_label_text(view)
	_check(not all_text.contains("接近焦点"), "no-focus mission keeps the original single-image layout")

	if failures == 0:
		print("FOCUS STATE SUMMARY TEST PASS")
		quit(0)
	else:
		print("FOCUS STATE SUMMARY TEST FAIL: ", failures)
		quit(1)


func _open_card() -> void:
	view = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	for frame in range(6):
		await process_frame


func _observation() -> Dictionary:
	return {
		"quality": "Good",
		"success": true,
		"observation_mode": "telescope",
		"focus_error": 0.0,
		"focus_tolerance": 0.06,
		"effective_clarity": 78.0,
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 0.9}
	}


func _focus_area_texture_count(node: Node) -> int:
	var count := 0
	if node is TextureRect:
		var rect := node as TextureRect
		if rect.position.x >= 228.0 and rect.position.x <= 540.0 and rect.position.y >= 184.0 and rect.position.y <= 290.0:
			count += 1
	for child in node.get_children():
		count += _focus_area_texture_count(child)
	return count


func _collect_label_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	for child in node.get_children():
		result += _collect_label_text(child)
	return result


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	_check(root.get_texture().get_image().save_png(output_path) == OK, "saved " + file_name)
	print("CAPTURE ", output_path)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
