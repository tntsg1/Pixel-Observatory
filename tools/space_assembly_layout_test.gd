extends SceneTree

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(66, true)
	gm.reset_assembly()

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(5):
		await process_frame

	_check(str(gm.assembly_family()) == "space_segmented", "L66 opens the infrared assembly family")
	var blueprint := bench.get("blueprint") as Control
	_check(blueprint != null, "center blueprint exists")
	if blueprint != null:
		var art := _find_blueprint_art(blueprint)
		_check(art != null, "cropped space-observatory blueprint is the center artwork")
		if art != null:
			_check(art.texture != null and art.texture.resource_path.ends_with("space_segmented_blueprint_cropped.png"),
				"center artwork loads the user-provided blueprint crop")
			_check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
				"blueprint keeps its original aspect ratio")
		_check(bench.find_child("SpaceBlueprintBoard", true, false) == null, "no replacement composite is injected")

	var expected: Dictionary = bench.call("_specialized_slot_positions", "space_segmented")
	var slots: Dictionary = bench.get("slot_controls")
	var subject_core := Rect2(134, 92, 162, 230)
	for part_type in expected:
		var slot := slots.get(part_type) as Control
		_check(slot != null, "%s slot exists" % part_type)
		if slot != null:
			var rect := Rect2(slot.position, slot.size)
			_check(rect.is_equal_approx(expected[part_type]), "%s click rect matches the printed cyan box" % part_type)
			_check(Rect2(Vector2.ZERO, blueprint.size).encloses(rect), "%s click rect stays inside the blueprint" % part_type)
		var label_panel := bench.find_child("SpaceSlotLabel_%s" % part_type, true, false) as Control
		_check(label_panel != null, "%s has a separate readable label" % part_type)
		if label_panel != null:
			_check(not subject_core.has_point(label_panel.position + label_panel.size * 0.5),
				"%s label center stays off the telescope core" % part_type)
		_check(bench.find_child("SpaceSlotConnector_%s" % part_type, true, false) != null,
			"%s has a visual connector" % part_type)

	var status := str(bench.call("_status_text"))
	_check(status.contains("Light path:") and status.contains("Deploy & power:") and status.contains("Science instruments:"),
		"space status summarizes all three assembly systems")
	_check(not status.contains("_mirror") and not status.contains("_shield"), "space status hides internal part IDs")
	var status_label := bench.get("status_label") as Label
	_check(status_label != null and status_label.position.x + status_label.size.x <= 208.0,
		"missing list stays inside the 222px inspector")
	_check(status_label != null and status_label.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"missing list keeps wrapping enabled")

	var order: Array = gm.current_level().get("assembly_order", [])
	if not order.is_empty():
		var first := str(order[0])
		bench.call("_select_flat_part", first)
		await process_frame
		_check(not bool(bench.call("_installed", first)), "selecting a card still does not install it")
		bench.call("_install_at_slot", first)
		for _i in range(3):
			await process_frame
		_check(bool(bench.call("_installed", first)), "clicking the matching slot still installs it")
		var installed_texture := bench.find_child("SpaceInstalledTexture_%s" % first, true, false) as TextureRect
		_check(installed_texture != null, "installed part appears inside its printed blueprint slot")
		var installed_slot := (bench.get("slot_controls") as Dictionary).get(first) as Control
		_check(
			installed_texture != null
			and installed_slot != null
			and installed_texture.get_parent() == installed_slot
			and Rect2(Vector2.ZERO, installed_slot.size).encloses(Rect2(installed_texture.position, installed_texture.size)),
			"installed texture is clipped to the slot and cannot cover the inspector"
		)

	bench.queue_free()
	await process_frame
	_finish()


func _find_blueprint_art(parent: Control) -> TextureRect:
	for child in parent.get_children():
		if child is TextureRect:
			var texture := (child as TextureRect).texture
			if texture != null and texture.resource_path.ends_with("space_segmented_blueprint_cropped.png"):
				return child as TextureRect
	return null


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish() -> void:
	_restore_save()
	print("SPACE ASSEMBLY LAYOUT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
