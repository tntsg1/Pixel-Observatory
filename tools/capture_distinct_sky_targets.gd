extends SceneTree

const OUTPUT_DIR := "res://artifacts/distinct_sky_targets"
const AIM := Vector2(180.0, 45.0)
const TARGETS := [
	"orion_nebula",
	"andromeda",
	"pleiades",
	"m13",
	"crab_nebula",
	"ring_nebula",
	"lagoon_nebula",
	"dumbbell_nebula",
	"double_cluster",
	"sombrero_galaxy",
	"whirlpool_galaxy",
	"needle_galaxy",
	"carina_cosmic_cliffs",
	"horsehead_nebula_infrared",
]


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	gm.new_game()
	gm.debug_jump_to_level(30, false)
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view := load("res://scenes/sky_observation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var horizon_tween := view.get("horizon_explanation_tween") as Tween
	if horizon_tween != null:
		horizon_tween.kill()
	var horizon_layer := view.get("horizon_explanation_layer") as Control
	if horizon_layer != null and is_instance_valid(horizon_layer):
		horizon_layer.queue_free()
		view.set("horizon_explanation_layer", null)
	view.set("location_transition_active", true)
	view.set("horizon_explanation_active", false)
	view.set("view_mode", "telescope")
	view.call("_apply_view_mode")
	for object_id_value in TARGETS:
		await _capture_target(view, str(object_id_value))
	print("DISTINCT SKY TARGET CAPTURES: " + ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture_target(view: Control, object_id: String) -> void:
	view.set("target_id", object_id)
	view.set("selected_object_id", object_id)
	var sky: Dictionary = view.get("sky_data")
	# Each fixture must contain exactly one catalog target at the test aim.
	# Otherwise earlier captures remain stacked at the same coordinates and
	# visually hide the target being verified.
	for id_value in sky.keys():
		var hidden_item: Dictionary = sky[id_value].duplicate(true)
		hidden_item["altitude"] = -90.0
		hidden_item["visible"] = false
		sky[id_value] = hidden_item
	var item: Dictionary = sky.get(object_id, {}).duplicate(true)
	item["azimuth"] = AIM.x
	item["altitude"] = AIM.y
	item["visible"] = true
	item["below_horizon"] = false
	item["source"] = "distinct_icon_capture"
	sky[object_id] = item
	view.set("sky_data", sky)
	# Keep the target just outside the lock threshold so the artwork remains
	# visible without the success ring covering its morphology.
	view.set("telescope_azimuth", AIM.x - 0.82)
	view.set("telescope_altitude", AIM.y + 0.34)
	view.set("display_azimuth", AIM.x - 0.82)
	view.set("display_altitude", AIM.y + 0.34)
	view.set("display_fov_x", view.get("fov_x"))
	view.set("display_fov_y", view.get("fov_y"))
	view.call("_rebuild_view")
	await process_frame
	await process_frame
	var object_data: Dictionary = root.get_node("/root/GameManager").get_object(object_id)
	var icon: TextureRect = (view.get("object_icons") as Dictionary).get(object_id)
	var material := icon.material as ShaderMaterial
	print("%s category=%s visual=%s zoom=%s focus=%s" % [
		object_id,
		view.call("_object_category", object_data),
		view.call("_object_visual_for_mode", object_data),
		material.get_shader_parameter("zoom") if material != null else "none",
		material.get_shader_parameter("focus") if material != null else "none"
	])
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + object_id + ".png")
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	await process_frame
