extends SceneTree

const OUTPUT := "res://artifacts/optical_environment_acceptance"
const TELESCOPE_VIEW_PATH := "res://scenes/telescope_view.tscn"

var gm: Node
var had_save := false
var saved_bytes := PackedByteArray()
var metrics: Array[String] = []


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	root.size = Vector2i(1024, 768)
	if DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(12, 12))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	gm = root.get_node("/root/GameManager")

	await _capture_drift_sequence()
	await _capture_tracking_sequence()
	await _capture_pollution_comparison()
	await _capture_seeing_comparisons()
	await _capture_cloud_sequence()
	_write_metrics()
	_restore_save()
	print("OPTICAL ENVIRONMENT CAPTURES PASS: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _capture_drift_sequence() -> void:
	var setup := await _spawn_view(35, "whirlpool_galaxy", _environment("good", 0.0, "dark"))
	var view: Control = setup["view"]
	for spec in [
		["01_m51_drift_center.png", Vector2.ZERO],
		["02_m51_drift_mid.png", Vector2(110, -38)],
		["03_m51_drift_near_edge.png", Vector2(196, -72)],
	]:
		view.set("drift_offset", spec[1])
		view.call("_apply_drift_offset")
		view.set("visual_target_center", (view.get("lens_center") as Vector2) + spec[1])
		view.call("_update_target_visuals")
		await _save(str(spec[0]))
		metrics.append("DRIFT %s offset=%s lens_mask=fixed" % [spec[0], spec[1]])
	await _dispose(setup)


func _capture_tracking_sequence() -> void:
	for spec in [
		["04_tracking_0x_forward.png", 0.0],
		["05_tracking_1x_still.png", 1.0],
		["06_tracking_1_35x_reverse.png", 1.35],
	]:
		var setup := await _spawn_view(23, "jupiter", _environment("good", 0.0, "dark"))
		var view: Control = setup["view"]
		gm.set_tracking_rate(float(spec[1]))
		view.set("drift_direction", Vector2.RIGHT)
		view.set("drift_offset", Vector2.ZERO)
		view.call("_advance_drift", 2.0)
		await _save(str(spec[0]))
		metrics.append("TRACKING %.2fx drift=%s" % [float(spec[1]), str(view.get("drift_offset"))])
		await _dispose(setup)


func _capture_pollution_comparison() -> void:
	var images: Array[Image] = []
	for sky in ["dark", "suburban", "city"]:
		var setup := await _spawn_view(41, "lagoon_nebula", _environment("good", 0.0, sky))
		var view: Control = setup["view"]
		await _render_frame()
		var image := root.get_texture().get_image()
		images.append(image.duplicate())
		image.save_png(ProjectSettings.globalize_path(OUTPUT + "/07_m8_%s.png" % sky))
		var observation: Dictionary = view.call("_evaluate")
		metrics.append("POLLUTION %s sky_lift=%.2f light_ratio=%.3f quality=%s" % [
			sky,
			float(view.get("cond_sky_lift")),
			float(observation["ratios"]["light"]),
			str(observation["quality"]),
		])
		await _dispose(setup)
	_save_contact_sheet(images, OUTPUT + "/08_m8_dark_suburban_city.png")


func _capture_seeing_comparisons() -> void:
	var targets := [
		["sirius", 48, "star"],
		["saturn", 48, "planet"],
		["lagoon_nebula", 48, "nebula"],
		["m13", 48, "cluster"],
	]
	var sequence := 9
	for target in targets:
		var images: Array[Image] = []
		for seeing in ["good", "average", "poor"]:
			var seeing_environment := _environment(seeing, 0.0, "dark")
			seeing_environment["_test_altitude"] = 20.0
			var setup := await _spawn_view(int(target[1]), str(target[0]), seeing_environment)
			var view: Control = setup["view"]
			await _settle(0.34)
			await _render_frame()
			var image := root.get_texture().get_image()
			images.append(image.duplicate())
			metrics.append("SEEING %s %s turbulence=%.3f quality=%s" % [
				target[2],
				seeing,
				float(view.get("cond_turbulence")),
				str((view.get("observation") as Dictionary).get("quality", "")),
			])
			await _dispose(setup)
		_save_contact_sheet(images, OUTPUT + "/%02d_seeing_%s_good_average_poor.png" % [sequence, target[2]])
		sequence += 1


func _capture_cloud_sequence() -> void:
	var setup := await _spawn_view(41, "lagoon_nebula", _environment("average", 0.66, "suburban"))
	var view: Control = setup["view"]
	for i in range(4):
		await _settle(0.65)
		var file_name := "%02d_cloud_m8_frame_%d.png" % [13 + i, i + 1]
		await _save(file_name)
		var observation: Dictionary = view.call("_evaluate")
		metrics.append("CLOUD frame=%d visual_coverage=%.3f attenuation=%.3f light_ratio=%.3f quality=%s" % [
			i + 1,
			float(view.get("cloud_visual_coverage")),
			float(view.get("cond_cloud_atten")),
			float(observation["ratios"]["light"]),
			str(observation["quality"]),
		])
	await _dispose(setup)


func _spawn_view(level_number: int, object_id: String, environment: Dictionary) -> Dictionary:
	gm.new_game()
	gm.debug_jump_to_level(level_number, true)
	gm.selected_object_id = object_id
	var level: Dictionary = gm.current_level()
	var original_environment: Dictionary = (level.get("environment", {}) as Dictionary).duplicate(true)
	var runtime_environment := environment.duplicate(true)
	var test_altitude := float(runtime_environment.get("_test_altitude", 45.0))
	runtime_environment.erase("_test_altitude")
	level["environment"] = runtime_environment
	var aim: Dictionary = gm.last_sky_aim.duplicate(true)
	aim["valid"] = true
	aim["altitude"] = test_altitude
	gm.last_sky_aim = aim
	_suppress_tutorials()
	var view := (load(TELESCOPE_VIEW_PATH) as PackedScene).instantiate() as Control
	root.add_child(view)
	await _settle(0.20)
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
	var target_focus := float(view.get("target_focus_value"))
	view.call("_set_focus_value", target_focus)
	view.set("dark_adaptation", 0.999)
	view.call("_advance_dark_adaptation", 1.0)
	view.set("focus_guide_active", false)
	var guide_panel := view.get("focus_guide_panel") as Control
	if guide_panel != null:
		guide_panel.visible = false
	view.call("_update_target_visuals")
	await _render_frame()
	return {"view": view, "level": level, "environment": original_environment}


func _dispose(setup: Dictionary) -> void:
	var level: Dictionary = setup["level"]
	level["environment"] = setup["environment"]
	var view := setup["view"] as Control
	view.queue_free()
	await process_frame


func _environment(seeing: String, cloud_cover: float, sky: String) -> Dictionary:
	return {
		"seeing": seeing,
		"cloud_cover": cloud_cover,
		"sky_brightness": sky,
	}


func _suppress_tutorials() -> void:
	gm.progress["tutorial_assistance_mode"] = "free"
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null:
		return
	var seen: Dictionary = feedback.get("_tutorial_seen")
	for key in [
		"first_focus_control",
		"first_averted_vision",
		"first_earth_drift",
		"first_clouds",
		"focus_novice_guide",
	]:
		seen[key] = true
	feedback.set("_tutorial_seen", seen)


func _settle(seconds: float) -> void:
	await process_frame
	await create_timer(seconds).timeout
	await process_frame


func _render_frame() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await process_frame


func _save(file_name: String) -> void:
	await _render_frame()
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT + "/" + file_name)
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)


func _save_contact_sheet(images: Array[Image], path: String) -> void:
	if images.is_empty():
		return
	var width := images[0].get_width()
	var height := images[0].get_height()
	var contact := Image.create(width * images.size(), height, false, Image.FORMAT_RGBA8)
	contact.fill(Color.BLACK)
	for i in range(images.size()):
		var source := images[i].duplicate()
		if source.get_format() != Image.FORMAT_RGBA8:
			source.convert(Image.FORMAT_RGBA8)
		contact.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i(width * i, 0))
	var global_path := ProjectSettings.globalize_path(path)
	if contact.save_png(global_path) != OK:
		push_error("Could not save " + global_path)
	else:
		print("CONTACT ", global_path)


func _write_metrics() -> void:
	var file := FileAccess.open(OUTPUT + "/metrics.txt", FileAccess.WRITE)
	if file == null:
		push_error("Could not write metrics")
		return
	file.store_line("OPTICAL ENVIRONMENT ACCEPTANCE PASS")
	for line in metrics:
		file.store_line(line)
	file.store_line("EXIT_CODE=0")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))
