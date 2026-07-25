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
		_fail("GameManager is missing")
		_finish()
		return
	var missions := root.get_node_or_null("/root/MissionManager")
	if missions == null:
		_fail("MissionManager is missing")
		_finish()
		return

	gm.new_game()
	for number in [67, 68]:
		var level: Dictionary = missions.get_level(number)
		_check(str(level.get("target_object_id", "")) == "carina_cosmic_cliffs",
			"L%d uses the infrared-only Cosmic Cliffs target" % number)
		var profile: Dictionary = level.get("space_profile", {})
		_check(str(profile.get("target_id", "")) == "carina_cosmic_cliffs",
			"L%d profile and mission target agree" % number)
		_check(str(profile.get("science_image_path", "")).ends_with("carina_cosmic_cliffs.png"),
			"L%d declares the dedicated infrared science image" % number)

	var compare_level: Dictionary = missions.get_level(72)
	_check(str(compare_level.get("target_object_id", "")) == "horsehead_nebula_infrared",
		"L72 uses a dedicated infrared Horsehead comparison instead of Orion again")
	_check(not [67, 68, 72].any(func(number: int) -> bool:
		return str(missions.get_level(number).get("target_object_id", "")) == "orion_nebula"),
		"the infrared target lessons no longer reuse the optical Orion Nebula mission")

	var target: Dictionary = gm.get_object("carina_cosmic_cliffs")
	_check(not target.is_empty(), "Cosmic Cliffs celestial data exists")
	_check(str(target.get("name_en", "")).contains("Cosmic Cliffs"), "English target name is specific")
	_check(str(target.get("name_zh", "")).contains("宇宙悬崖"), "Chinese target name is specific")
	var image_path := str(target.get("result_sprite_path", ""))
	_check(ResourceLoader.exists(image_path), "infrared science image exists")
	_check(load(image_path) is Texture2D, "infrared science image loads as Texture2D")
	var horsehead: Dictionary = gm.get_object("horsehead_nebula_infrared")
	var horsehead_path := str(horsehead.get("result_sprite_path", ""))
	_check(not horsehead.is_empty(), "infrared Horsehead celestial data exists")
	_check(ResourceLoader.exists(horsehead_path), "infrared Horsehead science image exists")
	_check(load(horsehead_path) is Texture2D, "infrared Horsehead science image loads as Texture2D")

	gm.debug_jump_to_level(67, true)
	var space_scene: Node = load("res://scenes/space_observation.tscn").instantiate()
	root.add_child(space_scene)
	for _i in range(4):
		await process_frame
	var host := Control.new()
	space_scene.add_child(host)
	space_scene.call("_draw_target_image", host, Rect2(20, 20, 480, 270), 1.0)
	var rendered := host.find_child("InfraredScienceTarget", true, false) as TextureRect
	_check(rendered != null and rendered.texture != null,
		"space console renders the dedicated science frame")
	if rendered != null:
		_check(rendered.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"science frame fills its viewport without distortion")
		_check(rendered.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"science frame keeps the project pixel filter")

	var card: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	await process_frame
	var card_path := str(card.call("_mission_object_image", target))
	_check(card_path == image_path, "mission result card uses the same infrared image")

	card.queue_free()
	space_scene.queue_free()
	await process_frame
	_finish()


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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	push_error("  FAIL: " + message)


func _finish() -> void:
	_restore_save()
	print("SPACE INFRARED TARGET DISTINCTION TEST %s" % (
		"PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
