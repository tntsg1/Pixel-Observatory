extends SceneTree

# PHASE 1 ACCEPTANCE - drives the real L66 flow, captures every checkpoint and
# runs automated UI audits. Prints a PROBLEM LIST, not just pass/fail.

const OUT := "res://artifacts/phase1_acceptance"
var gm: Node
var tf: Node
var scene: Node
var problems: Array = []
var checks := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	gm = root.get_node("/root/GameManager")
	tf = root.get_node("/root/TeachingFlowManager")

	await _run_real_l66()
	await _audit_lobby()
	_audit_space_rules()

	print("\n================ PHASE 1 PROBLEM LIST ================")
	if problems.is_empty():
		print("  (none found in %d automated checks)" % checks)
	else:
		for p in problems:
			print("  * " + str(p))
	print("checks run: %d,  problems: %d" % [checks, problems.size()])
	print("PHASE1 ACCEPTANCE %s" % ("PASS" if problems.is_empty() else "ISSUES (%d)" % problems.size()))
	quit(0)


func _problem(s: String) -> void:
	problems.append(s)


func _expect(cond: bool, ok_msg: String, bad_msg: String) -> void:
	checks += 1
	if cond:
		print("  ok: " + ok_msg)
	else:
		print("  ISSUE: " + bad_msg)
		_problem(bad_msg)


# ============================================================ real L66 run
func _run_real_l66() -> void:
	print("\n--- REAL L66 PLAYTHROUGH ---")
	gm.new_game()
	_lang("zh")
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(66, true)

	# (3) space telescope must NOT use the ground horizon rule
	var route: Dictionary = gm.current_room_route()
	_expect(not bool(route.get("needs_site_change", false)),
		"3. space level does not demand a ground site change",
		"3. space level still demands a ground site change")
	_expect(not str(route.get("hint", "")).contains("地平线以下"),
		"3. space route hint has no horizon wording",
		"3. space route hint still mentions the local horizon")

	await _open("res://scenes/space_observation.tscn")
	var m: SpaceObservationModel = scene.get("model")

	# (4) the target is Andromeda, and the renderer branches on target kind
	_expect(str(gm.current_target_object_id()) == "andromeda",
		"4. L66 target is Andromeda (%s)" % gm.current_target_object_id(),
		"4. L66 target is NOT Andromeda (%s)" % gm.current_target_object_id())
	_expect(str(m.target_kind) == "galaxy",
		"4. model renders it as a galaxy",
		"4. model target_kind is '%s', not galaxy" % m.target_kind)

	# walk plan -> thermal -> guide -> wavefront
	m.instrument = "nircam"; m.filter = "near_infrared"; m.exposure_time = 400.0; m.integrations = 4
	scene.call("_confirm_plan"); await _f(4)
	m.rotate_to(m.thermal_target_deg)
	for _i in range(600):
		m.step_thermal(1.0 / 60.0)
		if m.thermal_locked:
			break
	scene.call("_confirm_thermal"); await _f(4)
	m.choose_guide_star(1)
	for _i in range(240):
		m.step_guiding(1.0 / 60.0)
	scene.call("_confirm_guide"); await _f(4)
	for _i in range(12):
		m.align_step(0.09)
	scene.call("_confirm_wavefront"); await _f(6)

	# ---- (5) exposure button ordering
	print("\n--- (5) EXPOSURE BUTTON ORDER ---")
	await _shot("03_exposure_before.png")
	var start := _find_btn(scene, "StartExposure")
	var proc := _find_btn(scene, "ProcessData")
	_expect(start != null and not start.disabled, "5. Start Exposure enabled before exposing", "5. Start Exposure not usable before exposing")
	_expect(proc != null and proc.disabled, "5. Process Data locked before frames exist", "5. Process Data clickable before any frames")
	scene.call("_confirm_expose"); await _f(3)
	_expect(str(scene.call("_key")) == "expose", "5. cannot skip to processing without frames", "5. skipped past exposure with no frames")

	scene.call("_start_expose"); await _f(3)
	start = _find_btn(scene, "StartExposure")
	_expect(start != null and start.disabled, "5. Start disabled while exposing (no double start)", "5. Start still clickable while exposing")
	scene.set("elapsed", 1.0); scene.call("_refresh_expose"); await _f(3)
	await _shot("04_exposure_frame1.png")
	for _i in range(24):
		scene.set("elapsed", float(scene.get("elapsed")) + 0.5)
		scene.call("_refresh_expose"); await _f(2)
		if not bool(scene.get("acquiring")):
			break
	await _f(4)
	await _shot("05_exposure_complete.png")
	start = _find_btn(scene, "StartExposure"); proc = _find_btn(scene, "ProcessData")
	_expect(start != null and start.disabled, "5. Start stays locked after 4/4 (no endless restart)", "5. Start can restart after frames complete")
	_expect(proc != null and not proc.disabled, "5. Process Data unlocks only after exposure", "5. Process Data did not unlock after exposure")
	_audit_ui("exposure")

	# ---- (6) each processing step changes the picture AND explains itself
	print("\n--- (6) PROCESSING STEPS ---")
	scene.call("_confirm_expose"); await _f(6)
	var t_raw := _all_text(scene)
	await _shot("06a_process_raw.png")
	var sig_raw := _image_signature()
	_expect(t_raw.contains("宇宙线"), "6. raw stage explains the cosmic-ray state", "6. raw stage does not explain cosmic rays")

	_review_frames(m)
	m.align_frames(); scene.call("_build_stage"); await _f(4)
	await _shot("06b_process_aligned.png")
	var sig_al := _image_signature()
	_expect(sig_al != sig_raw, "6. aligning frames changed the image (ghost gone)", "6. aligning did not change the image")

	m.remove_cosmic_rays(); scene.call("_build_stage"); await _f(4)
	await _shot("06c_process_events_removed.png")
	var sig_cr := _image_signature()
	var t_cr := _all_text(scene)
	_expect(sig_cr != sig_al, "6. removing multiple detector events changed the image", "6. event removal did not change the image")
	_expect(t_cr.contains("背景"), "6. next step (background) is explained", "6. after event removal the next step is not explained")

	m.subtract_background(); m.stack(); scene.call("_build_stage"); await _f(4)
	await _shot("06d_process_stacked.png")
	var sig_st := _image_signature()
	_expect(sig_st != sig_al, "6. background+stack changed the image", "6. stacking did not change the image")
	_expect(_all_text(scene).contains("显现"), "6. stacked stage says faint structure is now visible", "6. stacked stage gives no explanation")
	_audit_ui("processing")
	# ---- (7) RGB mapping drives the final image
	print("\n--- (7) FALSE-COLOUR MAPPING ---")
	scene.call("_confirm_process"); await _f(6)
	m.set_channel("R", "miri_dust"); m.set_channel("G", "nir_long"); m.set_channel("B", "nir_short")
	m.choose_science("dust_rich"); scene.call("_build_stage"); await _f(4)
	await _shot("07a_filter_mapA.png")
	var sig_a := _image_signature()
	var txt_a := _all_text(scene)
	_expect(txt_a.contains("R=中红外尘埃") and txt_a.contains("G=近红外长波") and txt_a.contains("B=近红外短波"),
		"7. the on-screen mapping matches the chosen channels", "7. the displayed mapping does not match the chosen channels")
	# swap the mapping -> the image must change with it
	m.set_channel("R", "nir_short"); m.set_channel("B", "miri_dust")
	scene.call("_build_stage"); await _f(4)
	await _shot("07b_filter_mapB.png")
	var sig_b := _image_signature()
	var txt_b := _all_text(scene)
	_expect(sig_b != sig_a, "7. changing the mapping changed the rendered image", "7. the image ignores the channel mapping")
	_expect(txt_b.contains("R=近红外短波"), "7. the label follows the new mapping", "7. the label did not follow the new mapping")
	_audit_ui("filter")
	# restore a correct mapping and finish
	m.set_channel("R", "miri_dust"); m.set_channel("B", "nir_short")
	m.choose_science("dust_rich"); scene.call("_build_stage"); await _f(3)
	scene.call("_confirm_filter"); await _f(6)
	await _shot("08_report.png")
	_audit_ui("report")

	# ---- (1) REAL submit -> Mission Complete must name the next step
	print("\n--- (1) MISSION COMPLETE NEXT STEP (real submit) ---")
	scene.call("_submit")
	await _f(6)
	_expect(int(gm.progress.get("current_level", 0)) == 67,
		"1. submitting L66 really advanced the campaign to L67",
		"1. submitting L66 did not advance the campaign (level=%d)" % int(gm.progress.get("current_level", 0)))
	scene.queue_free(); await _f(2)
	await _open("res://scenes/learning_card.tscn")
	await _shot("01_mission_complete.png")
	var card_text := _all_text(scene)
	_expect(card_text.contains("下一关"), "1. Mission Complete states the NEXT level", "1. Mission Complete never states the next level")
	_expect(card_text.contains("前往"), "1. Mission Complete states WHERE to go", "1. Mission Complete does not say where to go")
	_expect(card_text.contains("第 67 关"), "1. it names the real next level (67)", "1. the next level shown is wrong")
	_audit_ui("mission_complete")
	scene.queue_free(); await _f(2)


func _review_frames(model: SpaceObservationModel) -> void:
	for index in range(model.frames.size()):
		var frame: Dictionary = model.frames[index]
		model.toggle_keep(index, model.frame_should_keep(frame))


# ============================================================ (2) lobby
func _audit_lobby() -> void:
	print("\n--- (2) LOBBY GUIDANCE ---")
	gm.update_room_guidance_for_level()
	_expect(str(gm.room_guidance_target) != "", "2. a lobby device is flagged for guidance (%s)" % gm.room_guidance_target,
		"2. no lobby device is flagged after finishing a level")
	await _open("res://scenes/observatory_room.tscn")
	await _f(30)
	await _shot("02_lobby_highlight.png")
	# does the overlay actually dim + frame the device?
	var overlay: Control = scene.get("guidance_overlay")
	_expect(overlay != null and overlay.visible, "2. the guidance overlay is visible", "2. the guidance overlay is not visible")
	var shades := 0
	var frames := 0
	if overlay != null:
		for c in overlay.get_children():
			if c is ColorRect:
				shades += 1
			else:
				frames += 1
	_expect(shades >= 3, "2. the room is dimmed around the target (%d shade rects)" % shades,
		"2. the room is NOT dimmed around the target")
	_expect(frames >= 1, "2. the target device has a highlight frame", "2. the target device has no highlight frame")
	var panel: Control = scene.get("guidance_panel")
	_expect(panel != null and panel.visible, "2. the guidance panel is shown", "2. the guidance panel is hidden")
	var edge: Control = scene.get("route_edge_indicator")
	_expect(edge != null, "2. a direction indicator exists", "2. no direction indicator exists")
	var lobby_text := _all_text(scene)
	# big target-name callout? (Phase-1 spec asks for a large target name)
	checks += 1
	if not lobby_text.contains("[E]"):
		print("  ISSUE: 2. lobby shows no [E] Interact prompt while away from the device")
		_problem("2. lobby shows no [E] Interact prompt until the player is adjacent (spec asks for it up-front)")
	else:
		print("  ok: 2. lobby shows an [E] interact prompt")
	_audit_ui("lobby")
	scene.queue_free(); await _f(2)


func _audit_space_rules() -> void:
	print("\n--- (3) SPACE vs GROUND RULES ---")
	# a GROUND level must still use the horizon rule (we must not have broken it)
	gm.debug_jump_to_level(4, true)
	var ground: Dictionary = gm.current_room_route()
	_expect(ground.has("needs_site_change"), "3. ground levels still evaluate the horizon rule",
		"3. the horizon rule was removed from ground levels too")
	_expect(not bool(ground.get("space_constraints", false)), "3. ground levels are not flagged as space",
		"3. a ground level got flagged with space constraints")


# ============================================================ UI audit
func _audit_ui(tag: String) -> void:
	var mojibake := ["锛", "鈥", "鏄", "瑁", "�"]
	var viewport := Rect2(0, 0, 1024, 768)
	var buttons: Array = []
	_walk(scene, func(n: Node) -> void:
		if n is Label:
			var l := n as Label
			var r := l.get_global_rect()
			if l.text.strip_edges() != "":
				if not viewport.grow(2).encloses(r):
					_problem("%s: label off-screen/clipped '%s' rect=%s" % [tag, l.text.substr(0, 24), str(r)])
				for g in mojibake:
					if l.text.contains(g):
						_problem("%s: mojibake in label '%s'" % [tag, l.text.substr(0, 24)])
		elif n is Button:
			var b := n as Button
			buttons.append(b)
			var br := b.get_global_rect()
			if not viewport.grow(2).encloses(br):
				_problem("%s: button off-screen '%s' rect=%s" % [tag, b.text.substr(0, 20), str(br)])
			if b.text.strip_edges() == "" and b.icon == null and not b.flat:
				_problem("%s: button with no label at %s" % [tag, str(br.position)])
	)
	# enabled buttons must not overlap each other (mis-click risk)
	for i in range(buttons.size()):
		for j in range(i + 1, buttons.size()):
			var a: Button = buttons[i]
			var b2: Button = buttons[j]
			if a.disabled or b2.disabled or a.flat or b2.flat:
				continue
			var ov := a.get_global_rect().intersection(b2.get_global_rect())
			if ov.size.x > 2.0 and ov.size.y > 2.0:
				_problem("%s: buttons overlap '%s' / '%s'" % [tag, a.text.substr(0, 14), b2.text.substr(0, 14)])
	checks += 1
	print("  ui-audit(%s): %d buttons checked" % [tag, buttons.size()])


func _walk(n: Node, fn: Callable) -> void:
	fn.call(n)
	for c in n.get_children():
		_walk(c, fn)


# ============================================================ helpers
func _image_signature() -> String:
	# cheap fingerprint of the rendered frame so we can prove the picture changed
	var img := root.get_texture().get_image()
	var s := ""
	for p in [Vector2i(300, 200), Vector2i(340, 210), Vector2i(240, 260), Vector2i(420, 180), Vector2i(180, 300)]:
		var c := img.get_pixelv(p)
		s += "%d-%d-%d|" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
	return s


func _find_btn(n: Node, nm: String) -> Button:
	for c in n.get_children():
		if c is Button and str(c.name) == nm:
			return c
		var f := _find_btn(c, nm)
		if f != null:
			return f
	return null


func _all_text(n: Node) -> String:
	var out := ""
	for c in n.get_children():
		if c is Label:
			out += (c as Label).text + "\n"
		elif c is Button:
			out += (c as Button).text + "\n"
		out += _all_text(c)
	return out


func _lang(l: String) -> void:
	gm.language_mode = l
	gm.progress["language_mode"] = l


func _open(p: String) -> void:
	scene = load(p).instantiate()
	root.add_child(scene)
	await _f(10)


func _f(n: int) -> void:
	for _i in range(n):
		await process_frame


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var e := root.get_texture().get_image().save_png(OUT + "/" + n)
	print("  CAP %s %s" % [n, "OK" if e == OK else str(e)])
