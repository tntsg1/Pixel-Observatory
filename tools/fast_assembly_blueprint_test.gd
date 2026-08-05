extends SceneTree

const APPROVED_BLUEPRINT := "res://assets/assembly/fast_blueprint_center_cropped.png"
const EXPECTED := {
	"dish": {
		"path": APPROVED_BLUEPRINT,
		"part_type": "radio_dish",
	},
	"feed": {
		"path": APPROVED_BLUEPRINT,
		"part_type": "receiver",
	},
	"signal": {
		"path": APPROVED_BLUEPRINT,
		"part_type": "signal_processor",
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
	gm.debug_jump_to_level(76, true)
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

	_check(str(gm.assembly_family()) == "fast_radio", "L76 opens FAST assembly")
	var blueprint := bench.get("blueprint") as Control
	_check(blueprint != null, "FAST center blueprint exists")
	for page_id in EXPECTED:
		bench.call("_set_fast_blueprint_page", page_id)
		await process_frame
		await process_frame
		var art := bench.find_child("FastBlueprintArt", true, false) as TextureRect
		_check(art != null, "%s page has blueprint art" % page_id)
		if art != null:
			_check(art.texture != null and art.texture.resource_path == EXPECTED[page_id]["path"],
				"%s page loads its approved FAST blueprint" % page_id)
			_check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
				"%s page preserves blueprint aspect ratio" % page_id)
			_check(art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				"%s page uses nearest filtering" % page_id)
		var part_type := str(EXPECTED[page_id]["part_type"])
		var slot := bench.find_child("FastBlueprintSlot_%s" % part_type, true, false) as Control
		_check(slot != null, "%s page exposes the matching printed slot" % page_id)
		if slot != null and blueprint != null:
			_check(Rect2(Vector2.ZERO, blueprint.size).encloses(Rect2(slot.position, slot.size)),
				"%s slot stays inside the center board" % page_id)

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
			# Part sprites are intentionally absent before selection/installation;
			# the checks below verify that they then appear in their exact slots.

	_check(bench.find_child("FastBlueprintTab_dish", true, false) != null, "dish blueprint tab exists")
	_check(bench.find_child("FastBlueprintTab_feed", true, false) != null, "feed blueprint tab exists")
	_check(bench.find_child("FastBlueprintTab_signal", true, false) != null, "signal blueprint tab exists")
	for part_type in ["radio_dish", "receiver", "signal_processor"]:
		var icon := bench.find_child("PartCardIcon_%s" % part_type, true, false) as TextureRect
		_check(icon != null, "%s part card displays its thumbnail" % part_type)
		if icon != null:
			_check(icon.texture != null, "%s part card thumbnail is loaded" % part_type)
			if icon.texture != null:
				_check(_source_texture_path(icon.texture).contains("telescope_parts/fast_radio"),
					"%s thumbnail uses the FAST part artwork" % part_type)
			_check(icon.texture is AtlasTexture,
				"%s thumbnail trims transparent canvas padding" % part_type)
			if part_type == "receiver" and icon.texture is AtlasTexture:
				var cabin_atlas := icon.texture as AtlasTexture
				_check(cabin_atlas.atlas != null and cabin_atlas.region.size.x <= cabin_atlas.atlas.get_width() * 0.5,
					"feed cabin thumbnail focuses the cabin instead of scaling all six cables")

	# Selecting previews the same tray art in the printed window; installing it
	# keeps the art there instead of collapsing to a frame and an OK badge.
	for part_type in ["radio_dish", "receiver", "signal_processor"]:
		bench.call("_select_flat_part", part_type)
		await process_frame
		await process_frame
		var preview := bench.find_child("FastBlueprintPart_%s" % part_type, true, false) as TextureRect
		_check(preview != null and preview.texture != null,
			"%s selection previews its real part art in the blueprint slot" % part_type)
		bench.call("_install_at_slot", part_type)
		await process_frame
		await process_frame
		var installed_art := bench.find_child("FastBlueprintPart_%s" % part_type, true, false) as TextureRect
		_check(installed_art != null and installed_art.texture != null,
			"%s installed part art remains visible in the blueprint slot" % part_type)
		if installed_art != null and installed_art.texture != null:
			_check(_source_texture_path(installed_art.texture).contains("telescope_parts/fast_radio"),
				"%s blueprint slot uses the same FAST artwork as its tray card" % part_type)
	bench.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _source_texture_path(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas != null:
			return atlas_texture.atlas.resource_path
	return texture.resource_path


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST ASSEMBLY BLUEPRINT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
