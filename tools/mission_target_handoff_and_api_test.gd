extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("MISSION TARGET HANDOFF / API TEST FAIL (GameManager missing)")
		quit(1)
		return

	gm.new_game()
	gm.debug_jump_to_level(31, true)
	gm.selected_object_id = "mars"
	gm.selected_object_level = 31
	var completed: bool = bool(gm.complete_current_mission(
		gm.current_target_object_id(),
		{"success": true, "quality": "Good", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}}
	))
	_check(completed, "L31 can complete with its mission target")
	_check(int(gm.progress.get("current_level", 0)) == 32, "campaign advances to the Uranus lesson")
	_check(str(gm.current_target_object_id()) == "uranus", "L32 mission target is Uranus")
	_check(str(gm.selected_object_id) == "uranus", "old free-observation Mars is replaced by Uranus")
	_check(int(gm.selected_object_level) == 32, "selection ownership follows the new level")
	gm.selected_object_id = "mars"
	gm.selected_object_level = 32
	gm.go_to_observation("telescope")
	_check(str(gm.selected_object_id) == "uranus", "entering from the observatory repairs an already-stale save selection")

	var service := SkyPositionService.new()
	var parsed: Dictionary = service._parse_astronomy_api_row({
		"body": {"id": "uranus", "name": "Uranus"},
		"positions": [{
			"position": {
				"horizontal": {
					"altitude": {"degrees": 31.25},
					"azimuth": {"degrees": 96.5}
				}
			}
		}]
	}, Rect2(Vector2.ZERO, Vector2(640, 480)))
	_check(not parsed.is_empty(), "valid AstronomyAPI Uranus rows are accepted")
	_check(str(parsed.get("source", "")) == "online", "accepted Uranus data is labelled online")
	_check(str(gm.position_source_label("online")).contains("AstronomyAPI"), "online provenance names AstronomyAPI")

	var detail: Dictionary = gm.object_detail("uranus")
	_check(str(detail.get("weather_source_en", "")) == "Mission scenario data", "weather provenance does not claim a live API")

	print("MISSION TARGET HANDOFF / API TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
