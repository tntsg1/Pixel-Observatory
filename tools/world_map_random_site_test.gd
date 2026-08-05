extends SceneTree

var failures := 0


func _initialize() -> void:
	var map: Control = (load("res://scripts/ui/world_map.gd") as Script).new() as Control
	map.current_site = {"id": "current", "lat": 0.0, "lon": 0.0}
	map.minimum_altitude = 10.0
	map.comfortable_altitude = 18.0
	map.site_visibility = {
		"current": _candidate("current", 65.0, -118.0),
		"left_edge": _candidate("left_edge", 36.0, -155.0),
		"middle_west": _candidate("middle_west", 29.0, -70.0),
		"middle_east": _candidate("middle_east", 42.0, 20.0),
		"right_edge": _candidate("right_edge", 24.0, 149.0),
		"low": _candidate("low", 7.0, 80.0),
		"below": _candidate("below", -12.0, 15.0),
	}

	var available: Array = map.call("_available_site_candidates")
	var available_ids := _ids(available)
	_check(available_ids.size() == 4, "all four comfortable non-current sites are eligible")
	_check(available_ids.has("middle_west") and available_ids.has("middle_east"), "middle-map observatories are not discarded")
	_check(not available_ids.has("current") and not available_ids.has("below"), "current and below-horizon sites are excluded")

	map.recommendation_rng.seed = 20260804
	var selected_ids: Dictionary = {}
	for _sample in range(128):
		var selected: Dictionary = map.call("_recommend_site")
		selected_ids[str(selected.get("site", {}).get("id", ""))] = true
	_check(selected_ids.size() == available_ids.size(), "fixed random sequence reaches every available observatory")
	_check(selected_ids.has("left_edge") and selected_ids.has("right_edge"), "edge sites remain possible without monopolizing selection")
	_check(selected_ids.has("middle_west") and selected_ids.has("middle_east"), "random selection reaches both middle-map sites")

	map.site_visibility = {
		"current": _candidate("current", 65.0, 0.0),
		"minimum_ok": _candidate("minimum_ok", 12.0, 35.0),
		"too_low": _candidate("too_low", 5.0, 70.0),
		"below": _candidate("below", -1.0, 90.0),
	}
	available = map.call("_available_site_candidates")
	_check(_ids(available) == ["minimum_ok"], "minimum-altitude pool is used when no comfortable site exists")

	map.site_visibility = {
		"current": _candidate("current", 65.0, 0.0),
		"last_resort": _candidate("last_resort", 4.0, 35.0),
		"below": _candidate("below", -1.0, 90.0),
	}
	available = map.call("_available_site_candidates")
	_check(_ids(available) == ["last_resort"], "above-horizon fallback prevents a dead-end when no higher site exists")

	map.free()
	print("WORLD MAP RANDOM SITE TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _candidate(id: String, altitude: float, longitude: float) -> Dictionary:
	return {
		"site": {"id": id, "name_en": id, "name_zh": id, "lat": 0.0, "lon": longitude},
		"altitude": altitude,
		"visible": altitude >= 0.0,
		"comfortable": altitude >= 18.0,
		"cloud_cover": 0.2,
		"seeing": "good",
	}


func _ids(candidates: Array) -> Array:
	var ids: Array = []
	for candidate_value in candidates:
		var candidate: Dictionary = candidate_value
		ids.append(str(candidate.get("site", {}).get("id", "")))
	ids.sort()
	return ids


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
