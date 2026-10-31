extends SceneTree

# Phase 1 acceptance: the player always knows what to do next.
#   A. finishing L66 leaves a concrete next step + a highlighted lobby device
#   B. a SPACE telescope is never told to "travel to a visible site" (the ground
#      horizon rule must not apply to an observatory at Sun-Earth L2)
#   C. the exposure stage states its numbers and its buttons have real states
#   D. the science image is the actual target (galaxy/nebula/star), never a Moon
#      stand-in and never a field of random dots
#   E. processing and filter stages explain themselves step by step

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("SPACE GUIDANCE TEST FAIL: GameManager missing")
		quit(1)
		return

	_test_next_step(gm)
	await _test_exposure(gm)
	_test_target_image(gm)

	print("SPACE GUIDANCE TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- A / B
func _test_next_step(gm: Node) -> void:
	gm.new_game()
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)

	# B. space levels must not inherit the ground horizon rule
	var route: Dictionary = gm.current_room_route()
	_check(not bool(route.get("needs_site_change", false)),
		"B. a space level never demands a site change for the local horizon")
	_check(bool(route.get("space_constraints", false)),
		"B. the space route is flagged as using space constraints")
	var hint_before := str(route.get("hint", ""))
	_check(not hint_before.contains("below the horizon") and not hint_before.contains("地平线以下"),
		"B. the space route hint does not mention the local horizon")

	# A. complete L66 -> there is a concrete next step
	gm.complete_current_mission(gm.current_target_object_id(),
		{"success": true, "quality": "Good", "clarity": 80.0, "contrast": 80.0, "detail": 80.0})
	_check(int(gm.progress.get("current_level", 0)) == 67, "A. finishing L66 advances to L67")
	gm.update_room_guidance_for_level()
	var next: Dictionary = gm.current_room_route()
	_check(str(next.get("target", "")) != "", "A. the next step names a lobby device (%s)" % str(next.get("target", "")))
	_check(str(next.get("action", "")) != "", "A. the next step states an action (%s)" % str(next.get("action", "")))
	_check(str(next.get("hint", "")) != "", "A. the next step explains what to do")
	_check(str(gm.room_guidance_target) != "", "A. the lobby device is flagged for highlighting")
	_check(str(gm.room_guidance_target) == str(next.get("target", "")), "A. the highlight matches the route target")
	# the next mission's own target is what the guidance talks about
	_check(str(next.get("action", "")).contains(gm.dict_text(gm.current_target(), "name"))
		or str(next.get("hint", "")).contains(gm.dict_text(gm.current_target(), "name")),
		"A. the next step names the next mission's target")


# ---------------------------------------------------------------- C
func _test_exposure(gm: Node) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)
	var scene: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(scene)
	for _i in range(6):
		await process_frame
	var m: SpaceObservationModel = scene.get("model")
	# jump to the exposure stage
	m.instrument = "nircam"; m.filter = "near_infrared"; m.exposure_time = 400.0; m.integrations = 4
	scene.call("_confirm_plan"); await process_frame
	m.rotate_to(m.thermal_target_deg)
	for _i in range(600):
		m.step_thermal(1.0 / 60.0)
		if m.thermal_locked:
			break
	scene.call("_confirm_thermal"); await process_frame
	var usable_guide := _first_usable_guide(m.guide_stars)
	_check(usable_guide >= 0, "C. this mission has a usable guide candidate")
	m.choose_guide_star(usable_guide)
	for _i in range(240):
		m.step_guiding(1.0 / 60.0)
	scene.call("_confirm_guide"); await process_frame
	for _i in range(12):
		m.align_step(0.09)
	scene.call("_confirm_wavefront"); await process_frame
	_check(str(scene.call("_key")) == "expose", "C. reached the exposure stage")

	# before: Start enabled, Process disabled
	var start := _find_button(scene, "StartExposure")
	var proc := _find_button(scene, "ProcessData")
	_check(start != null and not start.disabled, "C. before exposure, Start Exposure is enabled")
	_check(proc != null and proc.disabled, "C. before exposure, Process Data is disabled")
	# cannot skip ahead without frames
	scene.call("_confirm_expose"); await process_frame
	_check(str(scene.call("_key")) == "expose", "C. cannot process before any frames exist")

	# during: Start disabled (no double-start)
	scene.call("_start_expose")
	await process_frame
	start = _find_button(scene, "StartExposure")
	_check(start != null and start.disabled, "C. during exposure, Start is disabled (no repeat clicks)")
	_check(bool(scene.get("acquiring")), "C. the scene is integrating")

	# after: frames captured, Start shows complete, Process becomes primary
	# push the integration clock past the animation window deterministically
	for _i in range(20):
		scene.set("elapsed", float(scene.get("elapsed")) + 0.5)
		scene.call("_refresh_expose")
		await process_frame
		if not bool(scene.get("acquiring")):
			break
	for _i in range(4):
		await process_frame
	_check(not bool(scene.get("acquiring")), "C. integration finishes on its own")
	_check(m.acquired and m.frames.size() == m.integrations,
		"C. exactly %d frames were captured" % m.integrations)
	start = _find_button(scene, "StartExposure")
	proc = _find_button(scene, "ProcessData")
	_check(start != null and start.disabled, "C. after exposure, Start no longer restarts endlessly")
	_check(proc != null and not proc.disabled, "C. after exposure, Process Data becomes available")

	# the readout states the mission facts, not just a bar
	var text := _all_text(scene)
	for needle in ["Target", "Instrument", "Filter", "Frame", "Integration", "Detector"]:
		_check(text.contains(needle), "C. exposure readout states '%s'" % needle)
	_check(text.contains("Andromeda"), "C. exposure names the actual target")
	_check(text.to_lower().contains("photon"), "C. exposure explains what exposure IS (photons)")

	# E. processing stage explains each step
	scene.call("_confirm_expose"); await process_frame
	_check(str(scene.call("_key")) == "process", "E. reached processing")
	var raw := _all_text(scene)
	_check(raw.contains("cosmic") or raw.contains("Cosmic"), "E. processing explains the cosmic-ray state")
	_review_frames(m)
	m.align_frames(); scene.call("_build_stage"); await process_frame
	_check(_all_text(scene).contains("Remove") or _all_text(scene).contains("cosmic"),
		"E. after frame review and alignment it tells the player to remove events")
	scene.queue_free()
	await process_frame


func _first_usable_guide(stars: Array) -> int:
	for index in range(stars.size()):
		if bool((stars[index] as Dictionary).get("usable", false)):
			return index
	return -1


func _review_frames(model: SpaceObservationModel) -> void:
	for index in range(model.frames.size()):
		var frame: Dictionary = model.frames[index]
		model.toggle_keep(index, model.frame_should_keep(frame))


# ---------------------------------------------------------------- D
func _test_target_image(gm: Node) -> void:
	# The space screen must render the target by kind, and must never fall back
	# to a Moon image for a galaxy.
	var f := FileAccess.open("res://scripts/ui/space_observation.gd", FileAccess.READ)
	_check(f != null, "D. space screen source readable")
	if f == null:
		return
	var src := f.get_as_text()
	_check(src.contains("_draw_target_image"), "D. a dedicated target renderer exists")
	_check(src.contains("target_kind"), "D. the render branches on the target kind")
	# "moon_angle" is a legitimate pointing constraint; what must never appear is
	# a Moon ASSET path being used as the science image.
	var moon_asset := false
	for line in src.split("\n"):
		var low := str(line).to_lower()
		if low.contains("res://") and low.contains("moon"):
			moon_asset = true
	_check(not moon_asset, "D. the space screen never loads a Moon image asset")
	# the mission-complete image for Andromeda resolves to Andromeda art
	gm.new_game()
	var andromeda: Dictionary = gm.get_object("andromeda")
	_check(not andromeda.is_empty(), "D. andromeda exists in the catalog")
	var card: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	var path := str(card.call("_mission_object_image", andromeda))
	_check(path.contains("andromeda"), "D. mission-complete art for Andromeda is Andromeda (%s)" % path.get_file())
	_check(not path.contains("moon"), "D. mission-complete art for Andromeda is NOT the Moon")
	card.queue_free()


# ---------------------------------------------------------------- helpers
func _find_button(node: Node, name: String) -> Button:
	for child in node.get_children():
		if child is Button and str(child.name) == name:
			return child
		var found := _find_button(child, name)
		if found != null:
			return found
	return null


func _all_text(node: Node) -> String:
	var out := ""
	for child in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		elif child is Button:
			out += (child as Button).text + "\n"
		out += _all_text(child)
	return out


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
