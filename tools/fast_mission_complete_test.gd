extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var game_manager := root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		_check(false, "GameManager autoload is available")
		_finish()
		return
	game_manager.new_game()
	game_manager.debug_jump_to_level(85, true)
	var model := RadioSignalModel.new()
	model.configure({
		"target_id": "pulsar_b0329",
		"kind": "pulsar",
		"period_ms": 714.5,
		"dm": 26.8,
		"center_mhz": 1250.0,
		"bandwidth_mhz": 90.0,
	})
	model.azimuth = model.true_azimuth
	model.altitude = model.true_altitude
	model.window_center_mhz = model.true_center_mhz
	model.window_bandwidth_mhz = model.true_bandwidth_mhz
	for index in range(model.rfi_peaks.size()):
		model.classify(index, bool(model.rfi_peaks[index].get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.trial_phase = model.true_phase
	model.set_integration(240.0)
	var product := model.science_product(48, 12)
	var observation := {
		"success": true,
		"quality": "Excellent",
		"observation_mode": "radio",
		"radio_target_kind": "pulsar",
		"pulse_period_ms": 714.5,
		"dispersion_measure": 26.8,
		"snr": model.fold_snr(),
		"integration_s": 240.0,
		"rfi_cleared": int(product.get("removed_rfi_count", 0)),
		"raw_rfi_count": int(product.get("raw_rfi_count", 0)),
		"pulse_width_ms": float(product.get("pulse_width_ms", 0.0)),
		"duty_cycle_percent": float(product.get("duty_cycle_percent", 0.0)),
		"confidence": float(product.get("confidence", 0.0)),
		"pointing_quality": float(product.get("pointing_quality", 0.0)),
		"tuning_quality": float(product.get("tuning_quality", 0.0)),
		"report_conclusion": "stable_pulsar",
		"radio_data_product": product,
	}
	game_manager.last_learning_card = {
		"object": game_manager.get_object(game_manager.current_target_object_id()),
		"level": game_manager.current_level(),
		"observation": observation,
		"stats": {},
		"concept_card": {},
		"reward_summary": {"credits_awarded": 190},
	}
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	if teaching != null:
		teaching.active_card_mode = "complete"
	var packed_scene := load("res://scenes/learning_card.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	for _frame in range(5):
		await process_frame
	_check(_find_named(scene, "FastRadioCompletionPlot") != null, "FAST completion uses a radio data-product plot")
	var text_dump := _collect_text(scene)
	_check(text_dump.contains("714.500 ms"), "completion period comes from this observation")
	_check(text_dump.contains("26.80 pc/cm³"), "completion DM comes from this observation")
	_check(text_dump.contains("射电脉冲星") or text_dump.contains("Radio Pulsar"), "completion names the radio object type")
	_check(text_dump.contains("PSR J0332+5434"), "completion shows the J2000 catalogue alias")
	_check(text_dump.contains("03h 32m 59.37s"), "completion shows catalogue right ascension")
	_check(text_dump.contains("+54° 34′ 43.6″"), "completion shows catalogue declination")
	_check(text_dump.contains("J2000"), "completion names the coordinate epoch")
	_check(text_dump.contains("鹿豹座") or text_dump.contains("Camelopardalis"), "completion shows the source constellation")
	_check(_find_named(scene, "FastSourceIdentity") != null, "completion separates catalogue identity from measured values")
	_check(_find_named(scene, "FastSourceSkyMap") != null, "completion includes a coordinate-driven source locator")
	var expected_duty := float(product.get("pulse_width_ms", 0.0)) / 714.5 * 100.0
	_check(text_dump.contains("%.1f%%" % expected_duty), "completion duty cycle is derived from width divided by period")
	_check(not text_dump.contains("Clarity") and not text_dump.contains("清晰度"), "FAST completion removes optical clarity scoring")
	_check(not text_dump.contains("Contrast") and not text_dump.contains("对比度"), "FAST completion removes optical contrast scoring")
	_check(not text_dump.contains("Detail") and not text_dump.contains("细节"), "FAST completion removes optical detail scoring")
	var forbidden_texture := false
	for texture_rect in _collect_texture_rects(scene):
		var texture := (texture_rect as TextureRect).texture
		if texture == null:
			continue
		var path := str(texture.resource_path).to_lower()
		if path.contains("fast_aerial") or path.contains("fast_site") or path.contains("fast_500m"):
			forbidden_texture = true
	_check(not forbidden_texture, "FAST engineering/site photography is absent from the result card")
	scene.queue_free()
	await process_frame
	_finish()


func _collect_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child in node.get_children():
		result += _collect_text(child)
	return result


func _collect_texture_rects(node: Node) -> Array:
	var result: Array = []
	if node is TextureRect:
		result.append(node)
	for child in node.get_children():
		result.append_array(_collect_texture_rects(child))
	return result


func _find_named(node: Node, wanted: String) -> Node:
	if node.name == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		failures += 1
		push_error("  FAIL: %s" % label)


func _finish() -> void:
	print("FAST MISSION COMPLETE TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
