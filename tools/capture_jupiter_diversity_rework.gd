extends SceneTree

# Acceptance captures for the Jupiter repeat-observation diversity rework.
#
# Run WITHOUT --headless (needs a real framebuffer) and with an isolated
# --user-data-dir. The player's save and accessibility config are snapshotted
# and restored on every exit path anyway.
#
#   Godot_v4.7-stable_win64_console.exe --path E:\godot\ai-game-0628 \
#     --user-data-dir <scratch> --script res://tools/capture_jupiter_diversity_rework.gd

const OUTPUT_DIR := "res://artifacts/jupiter_diversity_rework"
const SAVE_PATH := "user://savegame.json"
const ACCESSIBILITY_PATH := "user://accessibility.cfg"

var gm: Node
var file_backups: Dictionary = {}
var shots := 0
var failures := 0


func _initialize() -> void:
	_backup_file(SAVE_PATH)
	_backup_file(ACCESSIBILITY_PATH)
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("JUPITER DIVERSITY CAPTURE REQUIRES A GRAPHICAL DISPLAY")
		_finish(2)
		return
	root.size = Vector2i(1024, 768)
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("GameManager autoload missing")
		_finish(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm.new_game()

	await _capture_l4()
	await _capture_l10()
	await _capture_l13()
	await _capture_l16()
	await _capture_l50()
	await _capture_l53()
	await _capture_l55()
	await _capture_l60()
	await _capture_mission_boards()
	await _capture_learning_card()
	await _capture_logbook()

	print("JUPITER DIVERSITY CAPTURE %s: %d shots, %d failures" % [
		"PASS" if failures == 0 else "FAIL", shots, failures
	])
	_finish(0 if failures == 0 else 1)


# ------------------------------------------------------------------ captures


func _capture_l4() -> void:
	# A star is a point source: out of focus it swells, in focus it collapses.
	var view := await _telescope_view(4, "betelgeuse", "", 0.17)
	await _shot("01_l4_betelgeuse_defocused.png")
	_free(view)
	view = await _telescope_view(4, "betelgeuse", "", 0.0)
	await _shot("02_l4_betelgeuse_focused.png")
	_free(view)


func _capture_l10() -> void:
	var view := await _telescope_view(10, "saturn", "eyepiece_20mm", 0.0)
	await _shot("03_l10_saturn_medium_power.png")
	_free(view)
	view = await _telescope_view(10, "saturn", "eyepiece_10mm", 0.0)
	await _shot("04_l10_saturn_excessive_power.png")
	_free(view)


func _capture_l13() -> void:
	# The mission board is where the assessment hands the decision over.
	gm.debug_jump_to_level(13, true)
	_clear_target_choice()
	var room := await _mission_board()
	await _shot("05_l13_target_choice.png")
	_free(room)


func _capture_l16() -> void:
	# The cluster fits the finder but not the main scope: that is the lesson.
	var sky := await _sky_view(16, "pleiades", "finder")
	await _shot("06_l16_pleiades_finder.png")
	_free(sky)
	sky = await _sky_view(16, "pleiades", "telescope")
	await _shot("07_l16_pleiades_narrow_scope.png")
	_free(sky)


func _capture_l50() -> void:
	var view := await _telescope_view(50, "venus", "cassegrain_40mm_eyepiece", 0.0)
	if view != null:
		# Inside the valid low-exposure band: the crescent edge is retained, but
		# its illuminated limb remains bright enough to read in a still image.
		view.set("exposure_value", 0.40)
		view.call("_update_target_visuals")
		await process_frame
	await _shot("08_l50_venus_twilight.png")
	_free(view)


func _capture_l53() -> void:
	var view := await _telescope_view(53, "uranus", "cassegrain_12mm_eyepiece", 0.0)
	await _shot("09_l53_uranus_comparison.png")
	_free(view)


func _capture_l55() -> void:
	var view := await _telescope_view(55, "neptune", "cassegrain_12mm_eyepiece", 0.0)
	if view != null:
		# Reveal and confirm Triton so the shot shows the secondary target.
		view.call("_update_secondary_visuals")
		await process_frame
		view.call("_confirm_secondary_target")
		await process_frame
		await process_frame
	await _shot("10_l55_neptune_triton.png")
	_free(view)


func _capture_l60() -> void:
	var view := await _telescope_view(60, "mars", "", 0.0)
	await _shot("11_l60_mars_contrast.png")
	_free(view)


func _capture_mission_boards() -> void:
	gm.debug_jump_to_level(50, true)
	_set_language("en")
	var room := await _mission_board()
	await _shot("12_mission_board_english.png")
	_free(room)
	_set_language("zh")
	room = await _mission_board()
	await _shot("13_mission_board_chinese.png")
	_free(room)
	_set_language("en")


func _capture_learning_card() -> void:
	# The concept brief for the new point-source card.
	gm.debug_jump_to_level(4, true)
	var tfm: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if tfm == null:
		failures += 1
		return
	tfm.set("active_card_id", "stellar_point_source")
	tfm.set("active_card_mode", "brief")
	var card: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	current_scene = card
	for _frame in range(8):
		await process_frame
	await _shot("14_learning_card_example.png")
	_free(card)
	tfm.set("active_card_id", "")
	tfm.set("active_card_mode", "")


func _capture_logbook() -> void:
	# Real entries written by the real completion path, one per new target.
	_seed_journal()
	var journal: Node = load("res://scenes/learning_journal.tscn").instantiate()
	root.add_child(journal)
	current_scene = journal
	for _frame in range(10):
		await process_frame
	await _shot("15_logbook_multiple_targets.png")
	_free(journal)


# ------------------------------------------------------------------- helpers


func _telescope_view(level_number: int, object_id: String, eyepiece_id: String, focus: float) -> Node:
	gm.debug_jump_to_level(level_number, true)
	if gm.level_requires_target_choice():
		gm.set_level_target_choice(object_id)
	if eyepiece_id != "":
		if not gm.progress["unlocked_parts"].has(eyepiece_id):
			gm.progress["unlocked_parts"].append(eyepiece_id)
		if gm.equip_part(eyepiece_id):
			gm.install_part("eyepiece", 0)
	gm.selected_object_id = object_id
	gm.selected_object_level = level_number
	# A valid aim keeps altitude-dependent seeing consistent between runs.
	var sky: Dictionary = gm.current_sky_positions.get(object_id, {})
	gm.last_sky_aim = {
		"valid": true,
		"altitude": float(sky.get("altitude", 42.0)),
		"azimuth": float(sky.get("azimuth", 180.0)),
	}
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	# _build() reads this during _ready(), so it must be set before the node
	# enters the tree or the pre-quiz field guide covers the whole capture.
	view.set("quiz_brief_dismissed", true)
	root.add_child(view)
	current_scene = view
	for _frame in range(8):
		await process_frame
	# Drive focus through the real setter so the observation is re-evaluated and
	# the quality panel matches what the eyepiece is actually showing.
	var target_focus: float = float(view.get("target_focus_value"))
	view.call("_set_focus_value", clampf(target_focus + focus, 0.0, 1.0))
	view.set("focus_locked", focus <= 0.01)
	_strip_overlays()
	for _frame in range(6):
		await process_frame
	return view


func _sky_view(level_number: int, object_id: String, mode: String) -> Node:
	gm.debug_jump_to_level(level_number, true)
	gm.selected_object_id = object_id
	gm.last_sky_aim = {}
	var sky: Node = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(sky)
	current_scene = sky
	for _frame in range(10):
		await process_frame
	sky.call("_set_view_mode", mode)
	# Point the instrument at the target so the framing shot is meaningful.
	var data: Dictionary = sky.get("sky_data")
	var entry: Dictionary = data.get(object_id, {})
	if not entry.is_empty():
		sky.set("telescope_azimuth", float(entry.get("azimuth", 180.0)))
		sky.set("telescope_altitude", float(entry.get("altitude", 45.0)))
	sky.call("_rebuild_view")
	_strip_overlays()
	for _frame in range(8):
		await process_frame
	return sky


func _mission_board() -> Node:
	var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	for _frame in range(8):
		await process_frame
	room.call("_open_mission_board")
	for _frame in range(6):
		await process_frame
	return room


func _clear_target_choice() -> void:
	var level_id := str(gm.current_level().get("id", ""))
	var overrides: Dictionary = gm.progress.get("level_target_overrides", {})
	overrides.erase(level_id)
	gm.progress["level_target_overrides"] = overrides


func _set_language(mode: String) -> void:
	gm.language_mode = mode
	gm.progress["language_mode"] = mode


func _seed_journal() -> void:
	# Complete one mission per reworked target through the real pipeline so the
	# logbook shows genuine, differently-targeted entries. Equip the eyepiece
	# that demonstrates each lesson, rather than inheriting one arbitrary setup
	# across all five records.
	gm.progress["journal_entries"] = []
	for entry_value in [
		[4, "betelgeuse", "eyepiece_20mm"],
		[10, "saturn", "eyepiece_20mm"],
		[16, "pleiades", "eyepiece_32mm"],
		[50, "venus", "cassegrain_40mm_eyepiece"],
		[55, "neptune", "cassegrain_12mm_eyepiece"],
	]:
		var entry: Array = entry_value
		var level_number := int(entry[0])
		var object_id := str(entry[1])
		var eyepiece_id := str(entry[2])
		gm.debug_jump_to_level(level_number, true)
		gm.progress["completed_levels"] = []
		if not gm.progress["unlocked_parts"].has(eyepiece_id):
			gm.progress["unlocked_parts"].append(eyepiece_id)
		if gm.equip_part(eyepiece_id):
			gm.install_part("eyepiece", 0)
		for step_value in gm.mission_steps():
			gm.mark_mission_step_done(str((step_value as Dictionary).get("id", "")))
		if not gm.current_secondary_target().is_empty():
			gm.mark_secondary_target_found()
		gm.selected_object_id = object_id
		gm.complete_current_mission(object_id, {
			"success": true,
			"quality": "Good",
			"visual_effect": "clear",
			"observation_mode": "telescope",
			"ratios": {"light": 1.2, "clarity": 1.2, "stability": 1.2},
		})


func _strip_overlays() -> void:
	# Tutorial highlights and coach marks are not part of these acceptance
	# shots; they are covered by their own capture tools.
	for node in root.get_tree().get_nodes_in_group("guidance_highlight"):
		if is_instance_valid(node):
			node.queue_free()


func _shot(file_name: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error == OK:
		shots += 1
		print("  shot: %s" % file_name)
	else:
		failures += 1
		push_error("failed to save %s" % file_name)


func _free(node: Node) -> void:
	if node != null and is_instance_valid(node):
		if current_scene == node:
			current_scene = null
		node.queue_free()


func _backup_file(path: String) -> void:
	file_backups[path] = {
		"exists": FileAccess.file_exists(path),
		"bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray(),
	}


func _restore_files() -> void:
	for path_value in file_backups.keys():
		var path := str(path_value)
		var backup: Dictionary = file_backups[path]
		if bool(backup.get("exists", false)):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(backup.get("bytes", PackedByteArray()))
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _finish(code: int) -> void:
	_restore_files()
	quit(code)
