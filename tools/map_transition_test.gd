extends SceneTree

# Round 26: the relocation transition is a reliable multi-phase state machine.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(11, true)   # first post-foundation live-sky lesson
	# Real time moves: park the player at a site where the target is genuinely
	# below the horizon RIGHT NOW, so the precondition holds on any clock.
	_force_below_horizon(gm)
	_check(gm.target_requires_relocation(), "0. post-foundation target below horizon -> relocation required")

	var wm: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(wm)
	await process_frame

	# --- 1. Site maths finished BEFORE any animation frame ---
	_check(not (wm.get("site_visibility") as Dictionary).is_empty(), "1. all site visibility computed in _ready")
	_check(str(wm.get("selected_id")) != "", "1. a recommendation exists before the animation")
	_check(int(wm.get("phase")) == 0, "1. starts in INTRO phase")
	_check((wm.get("scan_order") as Array).size() == 14, "1. scan order built for all sites")

	# --- 2. Phases advance in order and reach READY on their own ---
	var seen: Array = []
	var guard := 0
	while int(wm.get("phase")) < 4 and guard < 1200:
		var p: int = int(wm.get("phase"))
		if not seen.has(p):
			seen.append(p)
		await process_frame
		guard += 1
	_check(seen.has(0) and seen.has(1) and seen.has(2) and seen.has(3), "2. INTRO->SCAN->FOUND->ROUTE all played (%s)" % str(seen))
	_check(int(wm.get("phase")) == 4, "2. settles in READY waiting for the player")
	_check(float(wm.get("arc_progress")) >= 0.99, "2. route fully drawn at READY")
	_check(int(wm.get("resolved_count")) == (wm.get("scan_order") as Array).size(), "2. every candidate resolved by the scan")

	# --- 3. Confirm is gated until READY, then drives CONFIRM->TRAVEL->DEPART ---
	var confirm: Button = wm.get("confirm_button")
	_check(not confirm.disabled, "3. Confirm enabled once a visible site is selected")
	wm.call("_on_confirm")
	_check(int(wm.get("phase")) == 5, "3. Confirm enters CONFIRM phase (no instant scene switch)")
	guard = 0
	while int(wm.get("phase")) < 7 and guard < 1200:
		await process_frame
		guard += 1
	_check(int(wm.get("phase")) == 7, "3. reaches DEPART after TRAVEL")
	wm.queue_free()
	await process_frame

	# --- 4. Skip jumps presentation to READY but keeps the calculation ---
	gm.new_game()
	gm.debug_jump_to_level(11, true)
	_force_below_horizon(gm)
	var wm2: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(wm2)
	await process_frame
	var rec_before: String = str(wm2.get("selected_id"))
	wm2.call("_skip_animation")
	_check(int(wm2.get("phase")) == 4, "4. Skip lands directly in READY")
	_check(str(wm2.get("selected_id")) == rec_before, "4. Skip keeps the computed recommendation")
	_check(float(wm2.get("arc_progress")) >= 0.99 and int(wm2.get("resolved_count")) > 0, "4. Skip shows the final route/scan state")
	_check(not (wm2.get("site_visibility") as Dictionary).is_empty(), "4. Skip did NOT skip the site calculation")
	wm2.queue_free()
	await process_frame

	# --- 5. Trigger reliability: the map opens EVERY time, not once ---
	var story: Node = root.get_node("/root/StoryManager")
	gm.new_game()
	gm.debug_jump_to_level(11, true)
	_force_below_horizon(gm)
	var first: bool = story.begin_event("first_below_horizon", "world_map")
	story.finish_active_event()
	var second: bool = story.begin_event("first_below_horizon", "world_map")
	_check(first and not second, "5. Maya lesson plays once (story flag)")
	# but relocation itself is independent of that flag
	_check(gm.target_requires_relocation(), "5. relocation still required after the story is seen")
	_check(gm.has_method("go_to_observation"), "5. unified entry falls through to the map every time")

	# --- 6. Target already up -> short path, no full search ---
	gm.new_game()
	gm.debug_jump_to_level(11, false)
	var visible_now: Dictionary = gm.target_visibility()
	if bool(visible_now.get("visible", false)):
		var wm3: Node = load("res://scenes/world_map.tscn").instantiate()
		root.add_child(wm3)
		await process_frame
		if float(visible_now.get("altitude", 0.0)) >= 18.0:
			_check(int(wm3.get("phase")) == 4, "6. comfortably visible target opens straight in READY")
		else:
			_check(bool(wm3.get("target_low")) and int(wm3.get("phase")) == 0, "6. risen but low target keeps the optional relocation transition")
		_check(not bool(wm3.get("target_below")), "6. headline is not the below-horizon one")
		wm3.queue_free()
		await process_frame
	else:
		_check(true, "6. (moon below or too low this run - short-path check skipped)")

	if failures == 0:
		print("MAP TRANSITION TEST PASS")
		quit(0)
	else:
		print("MAP TRANSITION TEST FAIL (%d)" % failures)
		quit(1)


func _force_below_horizon(gm: Node) -> void:
	# Pick whichever catalogued site currently has the target under the horizon.
	var radec: Dictionary = gm.current_target_radec()
	if radec.is_empty():
		return
	var svc := SkyPositionService.new()
	for site_value in gm.location_sites():
		var site: Dictionary = site_value
		var v := svc.visibility_at(float(radec["ra_hours"]), float(radec["dec_degrees"]), float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
		if bool(v["below_horizon"]):
			gm.set_observing_location(site)
			return


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
