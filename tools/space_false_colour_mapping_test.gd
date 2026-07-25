extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var model := SpaceObservationModel.new()
	model.configure({
		"target_id": "carina_cosmic_cliffs",
		"kind": "nebula",
		"science": "star_forming",
		"observation_seed": 67,
	})

	_check(model.band_signature("nir_short") != model.band_signature("nir_long"),
		"short- and long-wave near infrared expose different structures")
	_check(model.band_signature("nir_long") != model.band_signature("miri_dust"),
		"long-wave near infrared and mid-infrared dust expose different structures")

	model.set_channel("R", "nir_short")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "miri_dust")
	var reversed_signature := model.composite_signature()
	model.choose_science("star_forming")
	_check(model.mapping_complete(), "a unique three-band mapping is complete")
	_check(not model.mapping_is_scientific(), "reversed wavelength order is visibly ambiguous")
	_check(not model.science_correct(), "the correct label cannot rescue an invalid mapping")

	model.set_channel("R", "miri_dust")
	model.set_channel("G", "nir_long")
	model.set_channel("B", "nir_short")
	var canonical_signature := model.composite_signature()
	_check(canonical_signature != reversed_signature, "changing RGB order changes the structural composite")
	_check(model.mapping_is_scientific(), "longest-to-red wavelength order is scientifically readable")

	model.choose_science("dust_rich")
	_check(not model.science_correct(), "wrong scientific interpretation cannot complete the stage")
	model.choose_science("star_forming")
	_check(model.science_correct(), "correct mapping and visible evidence complete the stage")

	var display := SpaceFalseColourDisplay.new()
	display.size = Vector2(480, 300)
	display.configure(
		load("res://assets/telescope_view/space_infrared/carina_cosmic_cliffs.png") as Texture2D
			if ResourceLoader.exists("res://assets/telescope_view/space_infrared/carina_cosmic_cliffs.png")
			else null,
		model.channel_map,
		model.band_signatures,
		"nebula",
		67,
		1.0
	)
	root.add_child(display)
	await process_frame
	_check(display.get_child_count() == 3, "RGB composite uses three independent rendered band layers")
	var layer_names: Array[String] = []
	for child in display.get_children():
		layer_names.append(child.name)
	_check(layer_names.any(func(value: String) -> bool: return "nir_short" in value),
		"short-wave NIR layer is present")
	_check(layer_names.any(func(value: String) -> bool: return "nir_long" in value),
		"long-wave NIR layer is present")
	_check(layer_names.any(func(value: String) -> bool: return "miri_dust" in value),
		"mid-infrared dust layer is present")
	display.queue_free()
	await process_frame

	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["space_intro_seen"] = true
	gm.progress["space_deployed"] = true
	gm.debug_jump_to_level(67, true)
	var screen: Control = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var stages: Array = screen.get("stages")
	screen.set("stage", stages.find("filter"))
	screen.call("_rebuild")
	await process_frame
	screen.call("_set_filter_channel", "R", "miri_dust")
	_check(bool(screen.get("filter_animating")), "mapping starts a channel-specific reveal scan")
	await create_timer(0.70).timeout
	_check(not bool(screen.get("filter_animating")), "reveal scan settles without a stale-node callback")
	screen.queue_free()
	await process_frame

	print("SPACE FALSE COLOUR MAPPING TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		print("  FAIL: ", message)
