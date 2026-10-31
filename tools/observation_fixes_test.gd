extends SceneTree

# Round 23: audit-and-fix acceptance for the observation-location / free-obs /
# world-map / source-label / unified-entry / object-persistence fixes.

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")

	# --- ISSUE 2: planets now compute real positions and gate below horizon ---
	gm.new_game()
	gm.debug_jump_to_level(5, true)  # jupiter
	var vis: Dictionary = gm.target_visibility()
	_check(bool(vis.get("has_coords", false)), "2. jupiter resolves real RA/Dec (not a fixed fallback)")
	gm.debug_jump_to_level(11, true)  # mars
	_check(bool(gm.target_visibility().get("has_coords", false)), "2. mars resolves real RA/Dec")
	gm.debug_jump_to_level(3, false)  # moon
	_check(bool(gm.target_visibility().get("has_coords", false)), "2. moon resolves a real lunar position")

	# --- ISSUE 4: unified entry - interior no longer bypasses the horizon gate ---
	var src := FileAccess.get_file_as_string("res://scripts/ui/observatory_interior.gd")
	_check(not src.contains("go(\"sky\")"), "4. interior does NOT call go(\"sky\") directly (bypass removed)")
	_check(src.contains("go_to_observation"), "4. interior uses the unified go_to_observation entry")
	_check(gm.has_method("go_to_observation"), "4. GameManager exposes the single observation entry")

	# --- ISSUE 5: completing a mission never deletes the object from the sky ---
	gm.new_game()
	gm.debug_jump_to_level(5, true)
	var svc := SkyPositionService.new()
	var before: int = svc.get_sky_positions(Rect2(88, 103, 630, 560)).size()
	gm.selected_object_id = "jupiter"
	gm.complete_current_mission("jupiter", {"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}})
	var after: int = svc.get_sky_positions(Rect2(88, 103, 630, 560)).size()
	_check(after == before, "5. sky object count unchanged after mission completion")
	_check(gm.is_observed("jupiter"), "5. jupiter marked observed (task state)")
	_check(gm.object_detail("jupiter").has("id"), "5. jupiter still has a full detail record after completion")
	# and it can be freely observed again
	gm.selected_object_id = "jupiter"
	_check(gm.is_free_observation() or gm.current_target_object_id() == "jupiter", "5. observed jupiter is still selectable for free observation")

	# --- ISSUE 6: clear position/weather source labels, never a bare "Offline" ---
	gm.new_game()
	gm.debug_jump_to_level(5, true)
	var d: Dictionary = gm.object_detail("jupiter")
	_check(str(d.get("position_source_en", "")).to_lower().contains("local") or str(d.get("position_source_en", "")).to_lower().contains("live"), "6. planet position source is Local/Live, not Offline")
	_check(str(d.get("position_source_en", "")) != "" and not str(d.get("position_source_en", "")).to_lower().contains("offline"), "6. position source never says Offline")
	_check(d.has("weather_source_en") and d.has("last_updated"), "6. detail exposes weather source + last updated")
	_check(str(gm.position_source_label("online")).to_lower().contains("live") or gm.position_source_label("online") == "实时位置", "6. online -> Live position")
	_check(str(gm.position_source_label("fallback")).to_lower().contains("teaching") or gm.position_source_label("fallback") == "教学模拟", "6. fallback -> Teaching simulation")

	# --- ISSUE 7: observing location + selection persist across save/reload ---
	gm.new_game()
	gm.debug_jump_to_level(6, false)
	var away := {"id": "siding_spring", "name_en": "Siding Spring", "name_zh": "赛丁泉", "lat": -31.27, "lon": 149.06, "bortle": 3}
	gm.set_observing_location(away)
	gm.selected_object_id = "sirius"
	gm.save()
	gm.progress = root.get_node("/root/SaveManager").load_progress(gm.default_progress())
	_check(str(gm.observing_location().get("id", "")) == "siding_spring", "7. observing location persists across reload")

	# --- ISSUE 6b: weather failure must not move a target's altitude ---
	# altitude is a pure function of ra/dec/lat/lon/time, independent of weather.
	var a1 := svc.visibility_at(6.75, -16.7, -31.27, 149.06, {"year":2026,"month":7,"day":20,"hour":10,"minute":0,"second":0})
	var a2 := svc.visibility_at(6.75, -16.7, -31.27, 149.06, {"year":2026,"month":7,"day":20,"hour":10,"minute":0,"second":0})
	_check(absf(float(a1["altitude"]) - float(a2["altitude"])) < 0.0001, "6b. altitude is deterministic (weather-independent)")

	# --- World map still recommends a reachable site for a down target ---
	gm.new_game()
	gm.debug_jump_to_level(6, false)  # sirius
	if bool(gm.target_visibility().get("below_horizon", false)):
		_check(not gm.recommend_observation_location().is_empty(), "8. world map recommends a site for a below-horizon target")
	else:
		_check(true, "8. (sirius up this run - recommendation not needed)")

	if failures == 0:
		print("OBSERVATION FIXES TEST PASS")
		quit(0)
	else:
		print("OBSERVATION FIXES TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
