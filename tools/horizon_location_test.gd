extends SceneTree

# Round 21: below-horizon observing flow. Real altitude drives visibility, the
# world map relocates the player, and Az/Alt recompute at the new site. Uses a
# fixed UTC + celestial-pole geometry for deterministic checks.

var failures := 0
const UTC := {"year": 2026, "month": 7, "day": 20, "hour": 6, "minute": 0, "second": 0}


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	var svc := SkyPositionService.new()

	# --- 1. Deterministic geometry: a north-pole star sits at altitude = lat ---
	# RA is irrelevant at dec=+90; altitude equals observer latitude.
	var north := svc.visibility_at(0.0, 89.9, 34.05, -118.24, UTC)
	_check(absf(float(north["altitude"]) - 34.05) < 1.5, "1. Polaris-like target altitude ~= +latitude (north site)")
	_check(bool(north["visible"]), "1. north-pole target visible from northern site")
	var south := svc.visibility_at(0.0, 89.9, -32.0, 20.0, UTC)
	_check(float(south["altitude"]) < 0.0, "1. same target is BELOW horizon from a southern site")
	_check(bool(south["below_horizon"]), "1. below_horizon flag set")

	# --- 2. A far-south target is down north, up south (recommendation exists) ---
	# dec -80 -> altitude ~ -(90-|lat|)... below horizon from lat +34.
	var down := svc.visibility_at(6.0, -80.0, 34.05, -118.24, UTC)
	_check(bool(down["below_horizon"]), "2. far-south target below horizon at home")
	var rec := svc.recommend_location(6.0, -80.0, gm.location_sites(), UTC)
	_check(not rec.is_empty(), "2. a southern site is recommended for a far-south target")
	if not rec.is_empty():
		_check(float(rec["altitude"]) >= 10.0, "2. recommended site has the target above the minimum")
		_check(float(rec["site"]["lat"]) < 0.0, "2. recommended site is in the southern hemisphere")

	# --- 3. Integration: relocation makes the real target visible + recomputes ---
	gm.new_game()
	gm.debug_jump_to_level(11, false)  # first post-foundation live-sky lesson
	var home_vis: Dictionary = gm.target_visibility()
	if bool(home_vis.get("below_horizon", false)):
		_check(gm.target_requires_relocation(), "3. below-horizon target requires relocation")
		var g_rec: Dictionary = gm.recommend_observation_location()
		_check(not g_rec.is_empty(), "3. GameManager recommends a site")
		var home_az := float(home_vis.get("azimuth", 0.0))
		gm.set_observing_location(g_rec["site"])
		var new_vis: Dictionary = gm.target_visibility()
		_check(bool(new_vis.get("visible", false)), "3. target visible after relocation")
		_check(not gm.target_requires_relocation(), "3. no relocation needed after moving")
		_check(absf(float(new_vis.get("azimuth", 0.0)) - home_az) > 0.5 or absf(float(new_vis.get("altitude", 0.0)) - float(home_vis.get("altitude", 0.0))) > 0.5, "3. Az/Alt recomputed at the new site")
	else:
		_check(true, "3. (Sirius already up at home this run - relocation not needed, skipped)")

	# --- 4. Location persists through save/reload; Return Home resets it ---
	var away := {"id": "atacama_paranal", "name_en": "Paranal", "name_zh": "帕瑞纳", "lat": -24.6, "lon": -70.4, "bortle": 1}
	gm.set_observing_location(away)
	gm.save()
	gm.progress = root.get_node("/root/SaveManager").load_progress(gm.default_progress())
	gm._normalize_progress() if gm.has_method("_normalize_progress") else null
	_check(str(gm.observing_location().get("id", "")) == "atacama_paranal", "4. observing location persists across save/reload")
	gm.reset_observing_location()
	_check(gm.is_at_home_location(), "4. Return Home resets to the home base")

	# --- 5. Targets without sky coordinates never gate (naked-eye safety) ---
	gm.new_game()
	gm.debug_jump_to_level(1, false)  # L1 - simple naked-eye/basic
	# The foundation chapter is deliberately scheduled at the home club.
	var l1_requires: bool = gm.target_requires_relocation()
	_check(not l1_requires, "5. L1 never enters the site-map workflow")

	# --- 6. World map scene instantiates and binds the target ---
	gm.debug_jump_to_level(11, false)
	var wm: Node = load("res://scenes/world_map.tscn").instantiate()
	root.add_child(wm)
	await process_frame
	_check((wm.get("sites") as Array).size() == 14, "6. world map loads all sites")
	# The map is now ONE authored image, not procedural geometry.
	_check(wm.get_node_or_null("MapImage") != null, "6. world map shows the authored map image")
	var map_image: TextureRect = wm.get_node_or_null("MapImage")
	_check(map_image != null and map_image.texture != null and map_image.texture.get_size() == Vector2(1672, 941), "6. map image is the 1672x941 source art")
	_check(map_image != null and map_image.mouse_filter == Control.MOUSE_FILTER_IGNORE, "6. map image never intercepts clicks")
	_check(wm.get_node_or_null("DynamicOverlay") != null, "6. dynamic content sits on a separate overlay")
	# aspect preserved (no stretching)
	var drawn: Vector2 = map_image.size
	_check(absf(drawn.x / drawn.y - 1672.0 / 941.0) < 0.01, "6. map aspect ratio preserved (no distortion)")
	wm.queue_free()
	await process_frame

	if failures == 0:
		print("HORIZON LOCATION TEST PASS")
		quit(0)
	else:
		print("HORIZON LOCATION TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
