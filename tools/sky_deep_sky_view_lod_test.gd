extends SceneTree

const AIM := Vector2(180.0, 45.0)
const EXPECTED_SIZE := {"naked_eye": 3.0, "finder": 15.0, "telescope": 36.0}
const EXPECTED_REVEAL_MAX := {"naked_eye": 0.20, "finder": 0.58, "telescope": 0.90}
const DEEP_SKY_IDS := [
	"andromeda",
	"carina_cosmic_cliffs",
	"crab_nebula",
	"double_cluster",
	"dumbbell_nebula",
	"horsehead_nebula_infrared",
	"lagoon_nebula",
	"m13",
	"needle_galaxy",
	"orion_nebula",
	"pleiades",
	"ring_nebula",
	"sombrero_galaxy",
	"whirlpool_galaxy",
]

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(31, false)
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var target_id := "andromeda"
	view.set("target_id", target_id)
	view.set("selected_object_id", target_id)
	var sky: Dictionary = view.get("sky_data")
	var item: Dictionary = sky.get(target_id, {}).duplicate(true)
	item["azimuth"] = AIM.x
	item["altitude"] = AIM.y
	item["visible"] = true
	item["below_horizon"] = false
	sky[target_id] = item
	view.set("sky_data", sky)
	view.set("telescope_azimuth", AIM.x)
	view.set("telescope_altitude", AIM.y)

	var sizes: Array[float] = []
	var reveals: Array[float] = []
	for mode in ["naked_eye", "finder", "telescope"]:
		view.set("view_mode", mode)
		view.call("_apply_view_mode")
		view.set("display_fov_x", view.get("fov_x"))
		view.set("display_fov_y", view.get("fov_y"))
		view.call("_rebuild_view")
		await process_frame
		var icon := (view.get("object_icons") as Dictionary).get(target_id) as TextureRect
		_check(icon != null, "%s creates a distinct deep-sky icon" % mode)
		if icon == null:
			continue
		_check(bool(icon.get_meta("deep_sky_lod", false)), "%s uses the progressive low-light material" % mode)
		var material := icon.material as ShaderMaterial
		_check(material != null, "%s has a shader material" % mode)
		if material == null:
			continue
		var rendered_size := maxf(icon.texture.get_size().x, icon.texture.get_size().y) * icon.scale.x
		var reveal := float(material.get_shader_parameter("morphology_reveal"))
		sizes.append(rendered_size)
		reveals.append(reveal)
		_check(absf(rendered_size - float(EXPECTED_SIZE[mode])) < 0.2, "%s renders at the authored acquisition scale" % mode)
		_check(reveal <= float(EXPECTED_REVEAL_MAX[mode]) + 0.001, "%s never reveals more morphology than its optics resolve" % mode)
		if mode == "naked_eye":
			_check(float(material.get_shader_parameter("saturation")) == 0.0, "naked eye removes photographic colour")
		if mode == "finder":
			_check(float(material.get_shader_parameter("pixel_grid")) == 12.0, "finder galaxy uses a coarse pixel signature")
		if mode == "telescope":
			_check(float(material.get_shader_parameter("saturation")) <= 0.12, "acquisition telescope remains low-saturation")

	_check(sizes.size() == 3 and sizes[0] < sizes[1] and sizes[1] < sizes[2], "apparent size grows through the optical chain")
	_check(reveals.size() == 3 and reveals[0] < reveals[1] and reveals[1] < reveals[2], "morphology is progressively revealed")
	var deep_sky_textures := {}
	for deep_sky_id in DEEP_SKY_IDS:
		var deep_sky_icon := (view.get("object_icons") as Dictionary).get(deep_sky_id) as TextureRect
		_check(deep_sky_icon != null, "%s has its own acquisition icon" % deep_sky_id)
		if deep_sky_icon == null:
			continue
		_check(bool(deep_sky_icon.get_meta("deep_sky_lod", false)), "%s uses view-dependent low-light rendering" % deep_sky_id)
		deep_sky_textures[deep_sky_icon.texture.resource_path] = true
	_check(deep_sky_textures.size() == DEEP_SKY_IDS.size(), "all deep-sky targets keep distinct source artwork")
	var moon_icon := (view.get("object_icons") as Dictionary).get("moon") as TextureRect
	_check(moon_icon != null and not bool(moon_icon.get_meta("deep_sky_lod", false)), "solar-system targets keep their own rendering")
	print("SKY DEEP-SKY VIEW LOD TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
