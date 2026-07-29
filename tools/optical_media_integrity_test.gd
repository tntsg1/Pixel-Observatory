extends SceneTree

const OFFICIAL_IDS := [
	"mercury",
	"venus",
	"saturn",
	"uranus",
	"neptune",
	"moon_crater_copernicus",
	"moon_mare_tranquillitatis",
	"moon_terminator",
	"albireo",
	"pleiades",
	"m13",
	"ring_nebula",
	"lagoon_nebula",
	"sombrero_galaxy",
	"crab_nebula",
	"dumbbell_nebula",
	"double_cluster",
	"whirlpool_galaxy",
	"needle_galaxy"
]

const ALL_OPTICAL_IDS := [
	"moon",
	"polaris",
	"sirius",
	"vega",
	"mars",
	"jupiter",
	"betelgeuse",
	"orion_nebula",
	"andromeda",
	"arcturus",
	"canopus",
	"alpha_centauri",
	"proxima",
	"mercury",
	"venus",
	"saturn",
	"uranus",
	"neptune",
	"moon_crater_copernicus",
	"moon_mare_tranquillitatis",
	"moon_terminator",
	"albireo",
	"pleiades",
	"m13",
	"ring_nebula",
	"lagoon_nebula",
	"sombrero_galaxy",
	"crab_nebula",
	"dumbbell_nebula",
	"double_cluster",
	"whirlpool_galaxy",
	"needle_galaxy"
]

const ISOLATED_PLANET_IDS := [
	"mercury",
	"venus",
	"saturn",
	"uranus",
	"neptune"
]

const EXTENDED_FIELD_IDS := [
	"moon_crater_copernicus",
	"moon_mare_tranquillitatis",
	"moon_terminator",
	"albireo",
	"dumbbell_nebula",
	"ring_nebula",
	"lagoon_nebula",
	"crab_nebula",
	"sombrero_galaxy",
	"whirlpool_galaxy",
	"needle_galaxy",
	"m13",
	"pleiades",
	"double_cluster"
]

const EXTENDED_SURFACE_IDS := [
	"moon_crater_copernicus",
	"moon_mare_tranquillitatis",
	"moon_terminator"
]

const DEEP_SKY_SUBJECT_IDS := [
	"albireo",
	"dumbbell_nebula",
	"ring_nebula",
	"lagoon_nebula",
	"crab_nebula",
	"sombrero_galaxy",
	"whirlpool_galaxy",
	"needle_galaxy",
	"m13",
	"pleiades",
	"double_cluster"
]

var failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	_test_registry_coverage()
	_test_official_runtime_images()
	_test_pipeline_metadata()
	_test_isolated_planet_alpha()
	_test_extended_field_masters()
	_test_circular_field_alpha()
	_test_shared_rendering_pipeline()
	if failures.is_empty():
		print("OPTICAL MEDIA INTEGRITY PASS: %d optical targets, %d licensed masters" % [
			ALL_OPTICAL_IDS.size(),
			OFFICIAL_IDS.size()
		])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_registry_coverage() -> void:
	var registry := OpticalMediaRegistry.all()
	for object_id in ALL_OPTICAL_IDS:
		_expect(registry.has(object_id), "Registry is missing %s" % object_id)
		var path := OpticalMediaRegistry.master_path(object_id)
		_expect(path != "", "No loadable master for %s" % object_id)
		_expect(not path.contains("/temporary/"), "%s still uses temporary media" % object_id)
		_expect(not path.ends_with(".svg"), "%s still uses an SVG placeholder" % object_id)
		if path != "":
			var texture := load(path) as Texture2D
			_expect(texture != null, "%s master does not load as Texture2D" % object_id)


func _test_official_runtime_images() -> void:
	for object_id in OFFICIAL_IDS:
		var path := OpticalMediaRegistry.master_path(object_id)
		_expect(path.contains("/official/"), "%s is not routed to official media" % object_id)
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		_expect(
			texture.get_width() == 1024 and texture.get_height() == 1024,
			"%s must be a 1024x1024 crop, got %s" % [object_id, texture.get_size()]
		)


func _test_pipeline_metadata() -> void:
	for object_id in ISOLATED_PLANET_IDS:
		_expect(
			OpticalMediaRegistry.media_class(object_id) == "isolated_planet",
			"%s must declare isolated_planet media_class" % object_id
		)
		_expect(
			OpticalMediaRegistry.render_mode(object_id) == "transparent_subject",
			"%s must declare transparent_subject render_mode" % object_id
		)
		var crop := OpticalMediaRegistry.crop_metadata(object_id)
		_expect(str(crop.get("fit", "")) == "contain", "%s crop must use contain" % object_id)
		_expect(int(crop.get("safe_margin_px", 0)) >= 96, "%s needs a safe margin" % object_id)
	for object_id in EXTENDED_FIELD_IDS:
		_expect(
			OpticalMediaRegistry.media_class(object_id) == "extended_field",
			"%s must declare extended_field media_class" % object_id
		)
		_expect(
			OpticalMediaRegistry.render_mode(object_id) == "circular_field",
			"%s must declare circular_field render_mode" % object_id
		)
		var crop := OpticalMediaRegistry.crop_metadata(object_id)
		_expect(str(crop.get("fit", "")) == "cover", "%s crop must use cover" % object_id)
		_expect(not crop.has("feather_px"), "%s must not bake a rectangular feather" % object_id)
		_expect(
			is_equal_approx(float(crop.get("radial_fade_fraction", 0.0)), 0.10),
			"%s must reserve only the outer 10%% for the runtime radial fade" % object_id
		)


func _test_isolated_planet_alpha() -> void:
	for object_id in ISOLATED_PLANET_IDS:
		var image := _load_runtime_image(object_id)
		if image == null:
			continue
		_expect(_corners_are_transparent(image), "%s PNG corners must be transparent" % object_id)
		var bounds := _alpha_bounds(image, 0.05)
		_expect(bounds.size.x > 96 and bounds.size.y > 96, "%s has no usable alpha subject" % object_id)
		if bounds.size.x <= 0 or bounds.size.y <= 0:
			continue
		var margin := mini(
			mini(bounds.position.x, bounds.position.y),
			mini(image.get_width() - bounds.end.x, image.get_height() - bounds.end.y)
		)
		_expect(margin >= 96, "%s subject touches the safe edge (margin %d px)" % [object_id, margin])
		_expect(_partial_alpha_samples(image) > 24, "%s lacks antialiased alpha edges" % object_id)
		if object_id == "uranus":
			var aspect := float(bounds.size.x) / float(bounds.size.y)
			_expect(aspect >= 0.94 and aspect <= 1.06, "Uranus crop is not circular (%.3f)" % aspect)


func _test_extended_field_masters() -> void:
	for object_id in EXTENDED_SURFACE_IDS:
		var image := _load_runtime_image(object_id)
		if image == null:
			continue
		# Continuous lunar surfaces are sharp, opaque overscan masters. The
		# single circular eyepiece stop is applied in fixed lens space.
		_expect(_corners_are_opaque(image), "%s surface master contains an unexpected alpha edge" % object_id)
		_expect(image.get_pixel(int(image.get_width() / 2), int(image.get_height() / 2)).a > 0.90, "%s subject center is missing" % object_id)
		_expect(_partial_alpha_samples(image) == 0, "%s master contains a second alpha feather" % object_id)
	for object_id in DEEP_SKY_SUBJECT_IDS:
		var image := _load_runtime_image(object_id)
		if image == null:
			continue
		# Alpha follows real astronomical structure, not x/y edge distance:
		# the rectangular photo itself must not exist in the live star field.
		_expect(
			_edge_alpha_mean(image) < 0.34,
			"%s keeps too much opaque photo background at its edges" % object_id
		)
		var bounds := _alpha_bounds(image, 0.02)
		_expect(bounds.size.x > 64 and bounds.size.y > 64, "%s lost its science structure" % object_id)
		_expect(_partial_alpha_samples(image) > 24, "%s lacks structure-derived alpha" % object_id)


func _test_circular_field_alpha() -> void:
	# Match the shader's radius exactly. Equal radii must have equal alpha in
	# every direction; a rectangular x_alpha*y_alpha mask fails this test.
	for radius_value in [0.90, 0.94, 0.97, 0.995]:
		var radius := float(radius_value)
		var samples: Array[float] = []
		for angle_index in range(32):
			var angle := TAU * float(angle_index) / 32.0
			var uv: Vector2 = Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * radius * 0.5
			samples.append(_runtime_circular_alpha(uv))
		var minimum: float = samples.min()
		var maximum: float = samples.max()
		_expect(
			maximum - minimum <= 0.0001,
			"Runtime circular alpha varies by angle at radius %.3f (%.5f)" % [radius, maximum - minimum]
		)
	_expect(_runtime_circular_alpha(Vector2(0.5, 0.5)) >= 0.999, "Field center must remain fully opaque")
	_expect(_runtime_circular_alpha(Vector2(1.0, 0.5)) <= 0.001, "Field edge must fade to transparent")


func _runtime_circular_alpha(uv: Vector2) -> float:
	var radius := (uv * 2.0 - Vector2.ONE).length()
	return 1.0 - smoothstep(0.90, 1.0, radius)


func _load_runtime_image(object_id: String) -> Image:
	var resource_path := OpticalMediaRegistry.master_path(object_id)
	if resource_path == "":
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	_expect(image != null and not image.is_empty(), "%s PNG cannot be read as Image" % object_id)
	return image


func _corners_are_transparent(image: Image) -> bool:
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a <= 0.01
		and image.get_pixel(last_x, 0).a <= 0.01
		and image.get_pixel(0, last_y).a <= 0.01
		and image.get_pixel(last_x, last_y).a <= 0.01
	)


func _edge_alpha_mean(image: Image) -> float:
	var size := image.get_size()
	var total := 0.0
	var samples := 0
	for step in range(33):
		var t := float(step) / 32.0
		var x := mini(roundi(t * float(size.x - 1)), size.x - 1)
		var y := mini(roundi(t * float(size.y - 1)), size.y - 1)
		for point in [
			Vector2i(x, 0),
			Vector2i(x, size.y - 1),
			Vector2i(0, y),
			Vector2i(size.x - 1, y),
		]:
			total += image.get_pixelv(point).a
			samples += 1
	return total / maxf(float(samples), 1.0)


func _corners_are_opaque(image: Image) -> bool:
	var last_x := image.get_width() - 1
	var last_y := image.get_height() - 1
	return (
		image.get_pixel(0, 0).a >= 0.99
		and image.get_pixel(last_x, 0).a >= 0.99
		and image.get_pixel(0, last_y).a >= 0.99
		and image.get_pixel(last_x, last_y).a >= 0.99
	)


func _alpha_bounds(image: Image, threshold: float) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _partial_alpha_samples(image: Image) -> int:
	var count := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.01 and alpha < 0.99:
				count += 1
	return count


func _test_shared_rendering_pipeline() -> void:
	var telescope_source := FileAccess.get_file_as_string("res://scripts/ui/telescope_view.gd")
	var result_source := FileAccess.get_file_as_string("res://scripts/ui/learning_card.gd")
	var shader_source := FileAccess.get_file_as_string("res://shaders/optical_target_state.gdshader")
	var pipeline_source := FileAccess.get_file_as_string("res://tools/fetch_optical_observation_media.py")
	_expect(
		telescope_source.contains("OpticalMediaRegistry.master_path(id)"),
		"Telescope view does not resolve the shared optical registry"
	)
	_expect(
		result_source.contains("OpticalMediaRegistry.master_path(id)"),
		"Observation result does not resolve the shared optical registry"
	)
	_expect(
		result_source.contains("\"blur_radius\": 5.6")
		and result_source.contains("\"blur_radius\": 2.2")
		and result_source.contains("\"blur_radius\": 0.0"),
		"Result focus comparison is not derived from one master at three focus states"
	)
	_expect(
		shader_source.contains("blur_radius_px") and shader_source.contains("TEXTURE_PIXEL_SIZE"),
		"Optical state shader does not implement source-derived defocus"
	)
	_expect(
		not pipeline_source.contains("def feather_field_edges")
		and not pipeline_source.contains("def _contain_field"),
		"Media pipeline still bakes or contains an inner rectangular field"
	)
	_expect(
		telescope_source.contains("LENS_RING_OCCLUDER_SHADER")
		and telescope_source.contains("occluder_mat.shader = LENS_RING_OCCLUDER_SHADER"),
		"Telescope view does not use a single radial eyepiece mask"
	)
	_expect(
		telescope_source.contains("EXTENDED_FIELD_OVERSCAN_SIZE / largest_dim")
		and telescope_source.contains("436.0 * subject_scale * _magnification_scale() / largest_dim"),
		"Surface overscan and deep-sky subject composition are not separated"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
