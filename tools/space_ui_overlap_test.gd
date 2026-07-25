extends SceneTree

# Geometry acceptance for every page in the space-observatory terminal. The
# test intentionally checks real global button rectangles, including the stage
# bar, telemetry strip and Back button.

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(66, true)

	gm.progress["space_intro_seen"] = false
	gm.progress["space_deployed"] = false
	var first: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(first)
	for _i in range(5):
		await process_frame
	for page in range(6):
		first.set("intro_page", page)
		first.call("_build_stage")
		await process_frame
		_check_page(first, "intro_%d" % page)
	var deploy_index := (first.get("stages") as Array).find("deploy")
	first.set("stage", deploy_index)
	first.call("_build_stage")
	await process_frame
	_check_page(first, "deploy")
	first.queue_free()
	await process_frame

	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	var scene: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	for _i in range(5):
		await process_frame
	var model: SpaceObservationModel = scene.get("model")
	model.instrument = "nircam"
	model.filter = "near_infrared"
	model.dither = "three_point"
	model.exposure_time = 400.0
	model.integrations = 5
	model.rotate_to(model.thermal_target_deg)
	for _i in range(600):
		model.step_thermal(1.0 / 60.0)
		if model.thermal_locked:
			break
	model.choose_guide_star(1)
	for _i in range(240):
		model.step_guiding(1.0 / 60.0)
	model.set_segment_alignment(1.0)
	model.acquire()
	for frame_index in range(model.frames.size()):
		var frame: Dictionary = model.frames[frame_index]
		model.toggle_keep(frame_index, model.frame_should_keep(frame))
	model.align_frames()
	model.remove_cosmic_rays()
	model.subtract_background()
	model.stack()
	model.set_channel("R", "miri_dust")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "nir_short")
	model.choose_science(model.true_science)

	var stages: Array = scene.get("stages")
	for index in range(stages.size()):
		scene.set("stage", index)
		scene.call("_build_stage")
		await process_frame
		_check_page(scene, str(stages[index]))
	gm.language_mode = "zh"
	scene.set("stage", stages.find("thermal"))
	scene.call("_build_stage")
	await process_frame
	_check_page(scene, "thermal_zh")
	scene.set("stage", stages.find("filter"))
	scene.call("_build_stage")
	await process_frame
	_check_page(scene, "filter_zh")
	gm.language_mode = "en"
	scene.queue_free()
	await process_frame

	print("SPACE UI OVERLAP TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check_page(scene: Node, page_name: String) -> void:
	var buttons: Array[Button] = []
	_collect_buttons(scene, buttons)
	var overlaps: Array[String] = []
	for i in range(buttons.size()):
		var a := buttons[i]
		if not a.is_visible_in_tree():
			continue
		var ar := a.get_global_rect()
		if ar.position.x < -0.5 or ar.position.y < -0.5 or ar.end.x > 1024.5 or ar.end.y > 768.5:
			overlaps.append("%s outside viewport %s" % [a.text, str(ar)])
		for j in range(i + 1, buttons.size()):
			var b := buttons[j]
			if not b.is_visible_in_tree():
				continue
			var intersection := ar.intersection(b.get_global_rect())
			if intersection.size.x > 0.5 and intersection.size.y > 0.5:
				overlaps.append("%s <> %s (%s)" % [a.text, b.text, str(intersection.size)])
	var telemetry := Rect2(36, 620, 952, 56)
	for button in buttons:
		if button.is_visible_in_tree():
			var intersection := button.get_global_rect().intersection(telemetry)
			if intersection.size.x > 0.5 and intersection.size.y > 0.5:
				overlaps.append("%s <> telemetry (%s)" % [button.text, str(intersection.size)])
	_check(overlaps.is_empty(), "page '%s' has no button/terminal overlap %s" % [page_name, str(overlaps)])
	if page_name.begins_with("thermal"):
		_check_thermal_regions(scene, page_name)


func _check_thermal_regions(scene: Node, page_name: String) -> void:
	var status := scene.find_child("ThermalStatusRegion", true, false) as Control
	var canvas := scene.find_child("ThermalAttitudeCanvas", true, false) as Control
	var controls := scene.find_child("ThermalControlRegion", true, false) as Control
	var gimbal := scene.find_child("AttitudeGimbal", true, false) as Control
	_check(status != null and canvas != null and controls != null and gimbal != null,
		"page '%s' exposes all three thermal layout regions" % page_name)
	if status == null or canvas == null or controls == null or gimbal == null:
		return
	var status_rect := status.get_global_rect()
	var canvas_rect := canvas.get_global_rect()
	var control_rect := controls.get_global_rect()
	_check(not status_rect.intersects(canvas_rect),
		"page '%s' status and attitude canvas rects do not intersect" % page_name)
	_check(not canvas_rect.intersects(control_rect),
		"page '%s' attitude canvas and controls rects do not intersect" % page_name)
	_check(canvas_rect.encloses(gimbal.get_global_rect()),
		"page '%s' gimbal remains inside its clipped canvas" % page_name)


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	for child in node.get_children():
		if child is Button:
			out.append(child as Button)
		_collect_buttons(child, out)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
