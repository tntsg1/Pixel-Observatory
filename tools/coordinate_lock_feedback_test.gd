extends SceneTree

const OUTPUT_DIR := "res://artifacts/coordinate_lock_feedback"

var failures := 0


func _initialize() -> void:
	await process_frame
	TranslationServer.set_locale("zh")
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("COORDINATE LOCK FEEDBACK TEST FAIL: GameManager missing")
		quit(1)
		return
	gm.debug_jump_to_level(14, true)
	# Real-sky positions move with the clock: if Mars is below the horizon right
	# now, travel to a site where it has risen so the approach/lock ring can
	# actually render (the feedback under test needs the target IN the sky).
	if gm.target_requires_relocation():
		var rec: Dictionary = gm.recommend_observation_location()
		if not rec.is_empty():
			gm.set_observing_location(rec["site"])
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.last_sky_aim = {"valid": false}

	var view: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	var target_id := str(view.get("target_id"))
	var target: Dictionary = (view.get("sky_data") as Dictionary).get(target_id, {})
	_check(target_id == "mars", "level 14 targets Mars")
	var mission_hint := str(view.call("_mission_hint", gm.get_object(target_id)))
	_check(
		mission_hint.contains("方位角") and mission_hint.contains("俯仰角"),
		"mission panel preserves the coordinate-navigation instruction"
	)

	# Fourteen degrees projects outside the Eye mode's visible 64 px center ring.
	view.set("telescope_azimuth", wrapf(float(target.get("azimuth", 0.0)) + 14.0, 0.0, 360.0))
	view.set("telescope_altitude", float(target.get("altitude", 45.0)))
	view.call("_set_view_mode", "naked_eye")
	view.call("_rebuild_view")
	await process_frame
	var approach_ring := view.get("target_state_ring") as TextureRect
	_check(approach_ring != null and str(view.get("target_lock_state")) == "approach", "coordinate lesson restores the cyan approach ring after target acquisition")
	_check(approach_ring != null and approach_ring.modulate.a > 0.0, "approach ring is visibly rendered")
	_check(str(view.get("guidance_label").text).contains("青色环"), "approach state explains how to center the target")
	await _capture("mars_target_acquired.png")

	view.set("telescope_azimuth", float(target.get("azimuth", 0.0)))
	view.set("telescope_altitude", float(target.get("altitude", 45.0)))
	view.call("_rebuild_view")
	await process_frame
	var lock_ring := view.get("target_state_ring") as TextureRect
	_check(lock_ring != null and str(view.get("target_lock_state")) == "locked", "centered Mars restores the gold lock state")
	_check(str(view.get("guidance_label").text).contains("金色锁定"), "lock state gives the next Finder action")
	await _capture("mars_target_locked.png")

	view.queue_free()
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("release_transient_sfx"):
		audio.call("release_transient_sfx")
		await process_frame
	await create_timer(0.12).timeout
	print("COORDINATE LOCK FEEDBACK TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR + "/" + file_name)
	_check(error == OK, "captured %s" % file_name)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
