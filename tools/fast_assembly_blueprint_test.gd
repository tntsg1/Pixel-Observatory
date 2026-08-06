extends SceneTree

const APPROVED_BLUEPRINT := "res://assets/assembly/fast_blueprint_center_cropped.png"
const EXPECTED_LEVEL_COUNTS := {
	76: 7,
	77: 10,
	78: 12,
	79: 13,
	80: 13,
	81: 13,
	82: 13,
	83: 14,
	84: 14,
	85: 14,
}
const EXPECTED := {
	"dish": {
		"path": APPROVED_BLUEPRINT,
		"parts": ["radio_dish", "panel_segment", "panel_actuator"],
	},
	"feed": {
		"path": APPROVED_BLUEPRINT,
		"parts": ["cable_system", "tension_controller", "receiver", "feed_receiver"],
	},
	"signal": {
		"path": APPROVED_BLUEPRINT,
		"parts": ["rf_receiver", "signal_processor", "spectrum_monitor", "timing_console", "data_recorder", "rfi_monitor", "control_terminal"],
	},
}

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish()
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	var previous_parts: Array = []
	for level_number in EXPECTED_LEVEL_COUNTS:
		gm.debug_jump_to_level(level_number, true)
		var level: Dictionary = gm.current_level()
		var required_parts: Array = level.get("required_parts", [])
		var required_ids: Array = level.get("required_part_ids", [])
		var assembly_order: Array = level.get("assembly_order", [])
		var expected_count: int = EXPECTED_LEVEL_COUNTS[level_number]
		_check(required_parts.size() == expected_count,
			"L%d introduces the expected cumulative FAST engineering set" % level_number)
		_check(required_ids.size() == expected_count and assembly_order.size() == expected_count,
			"L%d keeps requirements, exact parts and assembly order aligned" % level_number)
		for previous_part in previous_parts:
			_check(required_parts.has(previous_part),
				"L%d retains previously introduced FAST component %s" % [level_number, previous_part])
		previous_parts = required_parts.duplicate()
	gm.debug_jump_to_level(83, true)
	gm.reset_assembly()
	_check(ResourceLoader.exists("res://assets/assembly/fast_blueprint_reference.png"),
		"the complete user reference is preserved in project assets")
	_check(ResourceLoader.exists("res://assets/assembly/fast_blueprint_center_cropped.png"),
		"the runtime center crop is imported")
	var concept: Dictionary = gm.get_learning_card("radio_signal_observing")
	_check(str(concept.get("image", "")) == APPROVED_BLUEPRINT,
		"FAST concept brief uses the approved user blueprint crop")

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(5):
		await process_frame

	_check(str(gm.assembly_family()) == "fast_radio", "L83 opens the complete FAST assembly")
	_check(gm.current_level().get("required_parts", []).size() == 14,
		"L83 requires the complete fourteen-component FAST system")
	var inspector_status := bench.get("status_label") as Label
	_check(inspector_status != null and inspector_status.text.contains("0/14"),
		"FAST inspector summarizes cumulative engineering progress")
	_check(inspector_status != null and inspector_status.text.count("\n- ") <= 3,
		"FAST inspector never overflows with the full missing-parts list")
	var blueprint := bench.get("blueprint") as Control
	_check(blueprint != null, "FAST center blueprint exists")
	_check(blueprint != null and blueprint.clip_contents,
		"FAST center blueprint hard-clips every child to the center panel")
	bench.call("_set_fast_blueprint_page", "overview")
	await process_frame
	await process_frame
	var overview_canvas := bench.find_child("FastBlueprintCanvas", true, false) as Control
	var overview_art := bench.find_child("FastBlueprintArt", true, false) as TextureRect
	_check(overview_canvas != null and overview_canvas.clip_contents,
		"FAST overview uses the same clipped blueprint canvas pattern as the space observatory")
	_check(overview_art != null and overview_art.texture != null
			and overview_art.texture.resource_path == APPROVED_BLUEPRINT,
		"FAST overview displays the approved full engineering blueprint")
	if overview_art != null:
		_check(overview_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			"FAST overview preserves blueprint aspect ratio")
		_check(overview_art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"FAST overview uses nearest filtering")
	for system_id in ["dish", "feed", "signal"]:
		var system_target := bench.find_child("FastSystemTarget_%s" % system_id, true, false) as Control
		_check(system_target != null, "%s system has a printed-blueprint target" % system_id)
		if system_target != null and overview_canvas != null:
			_check(Rect2(Vector2.ZERO, overview_canvas.size).encloses(Rect2(system_target.position, system_target.size)),
				"%s system target stays inside the blueprint image canvas" % system_id)
	for page_id in EXPECTED:
		bench.call("_set_fast_blueprint_page", page_id)
		await process_frame
		await process_frame
		for part_type_value in EXPECTED[page_id]["parts"]:
			var part_type := str(part_type_value)
			var slot := bench.find_child("FastBlueprintSlot_%s" % part_type, true, false) as Control
			_check(slot != null, "%s page exposes the %s slot" % [page_id, part_type])
			if slot != null and blueprint != null:
				_check(Rect2(Vector2.ZERO, blueprint.size).encloses(Rect2(slot.position, slot.size)),
					"%s slot stays inside the center board" % part_type)
			var center_icon := bench.find_child("FastBlueprintPartTexture_%s" % part_type, true, false) as TextureRect
			_check(center_icon != null, "%s slot shows the real component artwork" % part_type)
			if center_icon != null and center_icon.texture != null:
				_check(center_icon.texture.resource_path.contains("telescope_parts/fast_radio"),
					"%s center artwork uses the FAST component asset" % part_type)

	bench.call("_set_fast_blueprint_page", "overview")
	await process_frame
	await process_frame
	if blueprint != null:
		for node in blueprint.find_children("*", "TextureRect", true, false):
			var texture_rect := node as TextureRect
			if texture_rect == null or texture_rect.texture == null:
				continue
			var path := texture_rect.texture.resource_path
			_check(not path.contains("advanced_family_atlas_placeholder"),
				"FAST center never loads the legacy family atlas")
			_check(not path.contains("fast_main_blueprint")
					and not path.contains("fast_feed_blueprint")
					and not path.contains("fast_signal_blueprint"),
				"FAST center never loads the simplified line-art boards")

	_check(bench.find_child("FastBlueprintTab_overview", true, false) != null, "FAST overview tab exists")
	_check(bench.find_child("FastBlueprintTab_dish", true, false) != null, "dish blueprint tab exists")
	_check(bench.find_child("FastBlueprintTab_feed", true, false) != null, "feed blueprint tab exists")
	_check(bench.find_child("FastBlueprintTab_signal", true, false) != null, "signal blueprint tab exists")
	for tab_id in ["overview", "dish", "feed", "signal"]:
		var tab := bench.find_child("FastBlueprintTab_%s" % tab_id, true, false) as Control
		if tab != null and blueprint != null:
			_check(Rect2(Vector2.ZERO, blueprint.size).encloses(Rect2(tab.position, tab.size)),
				"%s tab stays inside the center panel" % tab_id)
	for part_type_value in gm.current_level().get("required_parts", []):
		var part_type := str(part_type_value)
		var icon := bench.find_child("PartCardIcon_%s" % part_type, true, false) as TextureRect
		_check(icon != null, "%s part card displays its thumbnail" % part_type)
		if icon != null:
			_check(icon.texture != null, "%s part card thumbnail is loaded" % part_type)
			if icon.texture != null:
				_check(icon.texture.resource_path.contains("telescope_parts/fast_radio"),
					"%s thumbnail uses the FAST part artwork" % part_type)

	bench.call("_select_flat_part", "control_terminal")
	await process_frame
	await process_frame
	bench.call("_install_at_slot", "control_terminal")
	_check(not bool(gm.progress.get("assembly_state", {}).get("control_terminal", {}).get("installed", false)),
		"the control terminal cannot bypass its physical prerequisites")

	for part_type_value in gm.current_level().get("assembly_order", []):
		var part_type := str(part_type_value)
		bench.call("_select_flat_part", part_type)
		await process_frame
		await process_frame
		bench.call("_install_at_slot", part_type)
		await process_frame
		await process_frame
		_check(bool(gm.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false)),
			"%s installs in the documented engineering sequence" % part_type)
	_check(gm.missing_parts().is_empty(), "the complete FAST requirement set is achievable")
	_check(gm.telescope_is_ready(), "finishing all fourteen FAST components makes the observatory ready")
	bench.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST ASSEMBLY BLUEPRINT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
