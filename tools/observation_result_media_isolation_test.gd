extends SceneTree

var failures := 0
var gm: Node
var teaching: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	teaching = root.get_node_or_null("/root/TeachingFlowManager")
	_check(gm != null and teaching != null, "result-card services are available")
	if gm == null or teaching == null:
		quit(1)
		return
	gm.new_game()
	await _check_case("canopus", 17, "canopus_blurry.png", "optical_focus_preview.gdshader")
	await _check_case("mars", 11, "mars_blurry.png", "optical_target_state.gdshader")
	await _check_case("m13", 17, "official/m13.png", "optical_focus_preview.gdshader")
	print("OBSERVATION RESULT MEDIA ISOLATION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check_case(object_id: String, level_number: int, expected_blurry_suffix: String, expected_near_shader: String) -> void:
	gm.debug_jump_to_level(level_number, true)
	gm.selected_object_id = object_id
	var observation := {
		"quality": "Excellent",
		"success": true,
		"observation_mode": "telescope",
		"focus_error": 0.0,
		"focus_tolerance": 0.06,
		"effective_clarity": 90.0,
		"ratios": {"light": 0.92, "clarity": 0.95, "stability": 0.90}
	}
	gm.last_learning_card = teaching.make_mission_complete_payload(
		gm.current_level(), gm.get_object(object_id), observation, gm.calculate_stats()
	)
	teaching.active_card_mode = "complete"
	var card := load("res://scenes/learning_card.tscn").instantiate() as Control
	root.add_child(card)
	await process_frame
	var previews: Array[TextureRect] = []
	_collect_previews(card, previews)
	previews.sort_custom(func(a: TextureRect, b: TextureRect) -> bool: return a.position.x < b.position.x)
	_check(previews.size() == 3, "%s result has exactly three focus previews" % object_id)
	if previews.size() == 3:
		var blurry_path := str(previews[0].texture.resource_path)
		_check(blurry_path.ends_with(expected_blurry_suffix), "%s uses the correct authored/master defocus image" % object_id)
		_check(previews[0].texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "%s defocus preview uses linear sampling" % object_id)
		_check(previews[1].texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "%s near-focus preview uses linear sampling" % object_id)
		_check(previews[2].texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "%s sharp preview uses linear sampling" % object_id)
		var near_material := previews[1].material as ShaderMaterial
		_check(near_material != null, "%s near-focus preview has an optical material" % object_id)
		if near_material != null:
			_check(str(near_material.shader.resource_path).ends_with(expected_near_shader), "%s uses its own media-class focus shader" % object_id)
		_check(previews[2].material == null, "%s sharp preview keeps the unmodified source image" % object_id)
	card.queue_free()
	await process_frame


func _collect_previews(node: Node, output: Array[TextureRect]) -> void:
	for child in node.get_children():
		if child is TextureRect:
			var rect := child as TextureRect
			if rect.position.y >= 188.0 and rect.position.y <= 190.0 and rect.size.x == 90.0:
				output.append(rect)
		_collect_previews(child, output)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
