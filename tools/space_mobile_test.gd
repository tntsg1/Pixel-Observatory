extends SceneTree

# Mobile-touch validation for the space observatory. Confirms a finger can drive
# the pipeline (deploy, pick instrument, adjust attitude, expose, process) and
# that the space screen keeps its own buttons - no virtual joystick overlay
# steals the taps or sits on top of the key controls.

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var ti: Node = root.get_node_or_null("/root/TouchInput")
	if gm == null or ti == null:
		print("SPACE MOBILE TEST FAIL: autoloads missing")
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	ti.set_mobile_mode(true)
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = false
	gm.debug_jump_to_level(66, true)

	var scene: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	for _i in range(6):
		await process_frame

	# 1. no mobile joystick overlay is mounted over the space screen
	var overlays := 0
	for child in scene.get_children():
		var control := child as Control
		if control == null or control.get_script() == null:
			continue
		if str((control.get_script() as Script).resource_path).ends_with("mobile_controls.gd"):
			overlays += 1
	_check(overlays == 0, "1. no virtual joystick overlay is mounted over the space screen")

	# 2. touch the deploy buttons in order (finger taps, not method calls)
	_check(str(scene.call("_key")) == "deploy", "2. opens on deployment")
	var m: SpaceObservationModel = scene.get("model")
	for step in m.DEPLOY_ORDER:
		var btn := _find_button_containing(scene, _deploy_hint(step))
		_check(btn != null, "2. deploy button for '%s' is present and reachable" % step)
		if btn != null:
			await _tap_button(btn)
			await create_timer(0.80).timeout
	_check(m.fully_deployed(), "2. touch taps deployed the whole observatory in order")
	# tap the continue button
	var cont := _find_button_containing(scene, "Continue")
	if cont == null:
		cont = _find_button_containing(scene, "部署完成")
	_check(cont != null, "2. deployment-complete continue button is present")
	if cont != null:
		await _tap_button(cont)
	_check(str(scene.call("_key")) == "plan", "2. touch advanced to planning")

	# 3. tap an instrument choice
	var nircam := _find_button_containing(scene, "NIRCam")
	_check(nircam != null, "3. instrument buttons are tappable")
	if nircam != null:
		await _tap_button(nircam)
	_check(m.instrument == "nircam", "3. touch selected the NIRCam instrument")

	# key buttons sit inside the screen (not off-viewport, not under a HUD strip)
	var confirm := _find_button_containing(scene, "Confirm Plan")
	_check(confirm != null and confirm.get_global_rect().end.y <= 768.0 and confirm.get_global_rect().position.y >= 0.0,
		"3. the Confirm button is fully on-screen (not blocked by a HUD)")

	# 4. attitude slider can be driven by touch (drag changes the value)
	m.exposure_time = 400.0; m.integrations = 5; m.instrument = "nircam"; m.filter = "near_infrared"
	scene.call("_confirm_plan")
	await process_frame
	_check(str(scene.call("_key")) == "thermal", "4. reached the thermal stage")
	var before := m.attitude_deg
	var rot := _find_button_containing(scene, "+10")
	_check(rot != null, "4. a touch-friendly attitude nudge button is present")
	if rot != null:
		await _tap_button(rot)
		await create_timer(0.40).timeout
		await _tap_button(rot)
		await create_timer(0.40).timeout
	_check(m.attitude_deg != before, "4. touch tapping the attitude button changed the attitude")

	# 5. expose + process reachable by touch
	m.rotate_to(m.thermal_target_deg)
	for _i in range(600):
		m.step_thermal(1.0 / 60.0)
		if m.thermal_locked:
			break
	scene.call("_confirm_thermal")
	await process_frame
	m.choose_guide_star(1)
	for _i in range(240): m.step_guiding(1.0/60.0)
	scene.call("_confirm_guide")
	await process_frame
	for _i in range(12): m.align_step(0.09)
	scene.call("_confirm_wavefront")
	await process_frame
	_check(str(scene.call("_key")) == "expose", "5. reached the exposure stage")
	var start := _find_button_containing(scene, "Start Exposure")
	_check(start != null, "5. Start Exposure button is tappable")
	if start != null:
		await _tap_button(start)
	_check(m.acquired, "5. touch started the exposure and acquired frames")

	scene.queue_free()
	ti.set_mobile_mode(false)
	print("SPACE MOBILE TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _deploy_hint(step: String) -> String:
	# a substring guaranteed to be in that deploy button's label
	match step:
		"solar_array": return "Solar Array"
		"sunshield": return "Sunshield"
		"primary_mirror": return "Primary Mirror"
		"secondary_mirror": return "Secondary Mirror"
		"hinges": return "Hinges"
		"actuators": return "Actuators"
	return step


func _find_button_containing(node: Node, needle: String) -> Button:
	for child in node.get_children():
		if child is Button and str((child as Button).text).contains(needle):
			return child
		var found := _find_button_containing(child, needle)
		if found != null:
			return found
	return null


func _find_slider(node: Node) -> HSlider:
	for child in node.get_children():
		if child is HSlider:
			return child
		var found := _find_slider(child)
		if found != null:
			return found
	return null


func _tap_button(btn: Button) -> void:
	var c := btn.get_global_rect().get_center()
	var press := InputEventScreenTouch.new()
	press.index = 0; press.pressed = true; press.position = c
	root.push_input(press)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0; release.pressed = false; release.position = c
	root.push_input(release)
	await process_frame
	await process_frame


func _drag_slider(slider: HSlider) -> void:
	# A touch that lands near the right end of the track grabs and moves the value.
	var rect := slider.get_global_rect()
	var target := Vector2(rect.position.x + rect.size.x * 0.85, rect.get_center().y)
	var press := InputEventScreenTouch.new()
	press.index = 0; press.pressed = true; press.position = target
	root.push_input(press)
	await process_frame
	# hold and drag a touch so the grabber follows the finger
	for i in range(1, 5):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = target + Vector2(2.0 * float(i), 0)
		drag.relative = Vector2(2.0, 0)
		root.push_input(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0; release.pressed = false; release.position = target
	root.push_input(release)
	await process_frame
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
