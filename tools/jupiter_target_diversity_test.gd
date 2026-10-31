extends SceneTree

# Regression coverage for the "Jupiter repeat-observation diversity" rework.
#
# Jupiter used to be the fixed target of ten separate missions. It is now kept
# for exactly two teaching beats - L5 (the first magnification trade-off) and
# L47 (high-power planetary work with the Cassegrain) - and the other eight
# levels were rebuilt around different targets AND different primary actions.
#
# This test locks all of that down, plus the things most likely to regress
# silently: the frozen pulsar/FAST chapter, bilingual copy, leftover Jupiter
# wording, save compatibility, and 1024x768 layout safety.
#
# Run:
#   Godot_v4.7-stable_win64_console.exe --headless \
#     --path E:\godot\ai-game-0628 --user-data-dir <scratch> \
#     --script res://tools/jupiter_target_diversity_test.gd

const SAVE_PATH := "user://savegame.json"
const ACCESSIBILITY_PATH := "user://accessibility.cfg"

# Levels that may still target Jupiter.
const JUPITER_ALLOWED := [5, 47]

# level_number -> required target_object_id after the rework.
const EXPECTED_TARGETS := {
	4: "betelgeuse",
	10: "saturn",
	16: "pleiades",
	50: "venus",
	53: "uranus",
	55: "neptune",
	60: "mars",
}

# The reworked levels must each pose a DIFFERENT primary observing problem.
# Keyed by level; each entry lists level fields that must be present.
const EXPECTED_MECHANICS := {
	4: ["requires_focus"],
	10: ["mission_steps", "observation_requirements"],
	13: ["target_choices", "requires_target_choice"],
	16: ["observation_requirements"],
	50: ["observation_requirements", "environment", "safety_notice_en"],
	53: ["observation_requirements", "comparison_baseline_en"],
	55: ["secondary_target", "observation_requirements"],
	60: ["observation_requirements"],
}

const FROZEN_FIRST := 76
const FROZEN_LAST := 85

var failures := 0
var file_backups: Dictionary = {}


func _initialize() -> void:
	_backup_file(SAVE_PATH)
	_backup_file(ACCESSIBILITY_PATH)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager autoload missing")
		_restore_files()
		quit(1)
		return
	root.size = Vector2i(1024, 768)
	gm.new_game()

	_test_jupiter_confined(gm)
	_test_expected_targets(gm)
	_test_distinct_mechanics(gm)
	_test_level_13_free_choice(gm)
	_test_level_55_triton(gm)
	_test_frozen_pulsar_chapter(gm)
	_test_assets_and_data_load(gm)
	_test_bilingual_text(gm)
	_test_no_residual_jupiter_copy(gm)
	await _test_layout_safety(gm)
	_test_save_migration(gm)

	_restore_files()
	print("JUPITER TARGET DIVERSITY TEST %s%s" % [
		"PASS" if failures == 0 else "FAIL",
		"" if failures == 0 else " (%d failures)" % failures,
	])
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- 1. Jupiter
func _test_jupiter_confined(gm: Node) -> void:
	var offenders: Array[String] = []
	for level_value in gm.levels_data:
		if not level_value is Dictionary:
			continue
		var level: Dictionary = level_value
		var number := int(level.get("level_number", 0))
		if str(level.get("target_object_id", "")) != "jupiter":
			continue
		if not JUPITER_ALLOWED.has(number):
			offenders.append("L%d" % number)
	_check(
		offenders.is_empty(),
		"Jupiter is only a fixed target on L5 and L47 (stray: %s)" % ", ".join(offenders)
	)
	for allowed in JUPITER_ALLOWED:
		var level := _level(gm, allowed)
		_check(
			str(level.get("target_object_id", "")) == "jupiter",
			"L%d still targets Jupiter" % allowed
		)
	# The player-facing choice pool on L13 must not smuggle Jupiter back in.
	# L17 is deliberately left alone: its five-target pool is a randomised
	# navigation review, so Jupiter there is occasional variety rather than the
	# fixed, predictable repetition this rework removed.
	var l13_pool: Variant = _level(gm, 13).get("target_pool", [])
	if l13_pool is Array:
		_check(
			not (l13_pool as Array).has("jupiter"),
			"L13's choice pool excludes Jupiter"
		)


# --------------------------------------------------------------- 2-9. targets
func _test_expected_targets(gm: Node) -> void:
	for level_number_value in EXPECTED_TARGETS.keys():
		var level_number := int(level_number_value)
		var expected := str(EXPECTED_TARGETS[level_number_value])
		var level := _level(gm, level_number)
		_check(
			str(level.get("target_object_id", "")) == expected,
			"L%d targets %s" % [level_number, expected]
		)
		_check(
			not gm.get_object(expected).is_empty(),
			"target object '%s' is registered" % expected
		)


func _test_distinct_mechanics(gm: Node) -> void:
	# Each reworked level must carry its own mechanic fields, so none of them
	# can quietly decay back into "aim, lock, click, read".
	for level_number_value in EXPECTED_MECHANICS.keys():
		var level_number := int(level_number_value)
		var level := _level(gm, level_number)
		for field_value in EXPECTED_MECHANICS[level_number_value]:
			var field := str(field_value)
			_check(
				level.has(field) and level.get(field) != null,
				"L%d defines '%s'" % [level_number, field]
			)
	# L10's three-eyepiece comparison needs three distinct required parts.
	var l10 := _level(gm, 10)
	var steps: Array = l10.get("mission_steps", [])
	var part_ids: Array[String] = []
	for step_value in steps:
		if step_value is Dictionary:
			var part_id := str((step_value as Dictionary).get("require_part_id", ""))
			if part_id != "" and not part_ids.has(part_id):
				part_ids.append(part_id)
	_check(part_ids.size() == 3, "L10 compares three different eyepieces (got %d)" % part_ids.size())
	for part_id in part_ids:
		_check(not gm.get_part(part_id).is_empty(), "L10 eyepiece '%s' exists" % part_id)


# ------------------------------------------------------- 4. L13 free choice
func _test_level_13_free_choice(gm: Node) -> void:
	var level := _level(gm, 13)
	_check(bool(level.get("requires_target_choice", false)), "L13 requires an explicit target choice")
	var choices: Array = level.get("target_choices", [])
	_check(choices.size() == 3, "L13 offers three targets (got %d)" % choices.size())

	var expected_ids := ["moon", "saturn", "pleiades"]
	var seen_ids: Array[String] = []
	for choice_value in choices:
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		var object_id := str(choice.get("object_id", ""))
		seen_ids.append(object_id)
		_check(not gm.get_object(object_id).is_empty(), "L13 choice '%s' is a real object" % object_id)
		for key in ["label_en", "label_zh", "blurb_en", "blurb_zh"]:
			_check(str(choice.get(key, "")) != "", "L13 choice '%s' has %s" % [object_id, key])
	for expected_id in expected_ids:
		_check(seen_ids.has(expected_id), "L13 offers '%s'" % expected_id)

	# Every one of the three must be completable - the level must not have a
	# single "correct" target hiding behind the free-choice framing.
	for object_id in expected_ids:
		gm.debug_jump_to_level(13, true)
		var chosen: bool = gm.set_level_target_choice(object_id)
		_check(chosen, "L13 accepts '%s' as a choice" % object_id)
		_check(
			str(gm.current_target_object_id()) == object_id,
			"L13 resolves the chosen target '%s'" % object_id
		)
		var best := _best_quality_for_choice(gm, object_id)
		_check(
			bool(best.get("success", false)),
			"L13 '%s' is completable with a suitable eyepiece (best=%s)" % [object_id, str(best.get("quality", "?"))]
		)
	# Without a choice the level must not silently roll one for the player.
	gm.new_game()
	gm.debug_jump_to_level(13, true)
	_check(not gm.has_chosen_level_target(), "L13 starts with no target chosen")
	_check(
		str(gm.current_target_object_id()) == str(_level(gm, 13).get("target_object_id", "")),
		"L13 falls back to its declared placeholder instead of rolling a random target"
	)
	var pending_route: Dictionary = gm.current_room_route()
	_check(bool(pending_route.get("choice_pending", false)), "L13 room route waits for the target choice")
	_check(str(pending_route.get("target", "")) == "mission", "L13 points the player back to the Mission Board")
	_check(
		not str(pending_route.get("action", "")).to_lower().contains("moon"),
		"L13 pending route does not leak the placeholder Moon as a chosen target"
	)


# Tries every unlocked eyepiece and returns the best evaluation.
func _best_quality_for_choice(gm: Node, object_id: String) -> Dictionary:
	var best: Dictionary = {"success": false, "quality": "Failed"}
	for eyepiece_id in ["eyepiece_32mm", "eyepiece_20mm", "eyepiece_10mm"]:
		if not gm.progress["unlocked_parts"].has(eyepiece_id):
			gm.progress["unlocked_parts"].append(eyepiece_id)
		gm.equip_part(eyepiece_id)
		gm.install_part("eyepiece", 0)
		gm.selected_object_id = object_id
		var result: Dictionary = gm.evaluate_selected_object({
			"requires_focus": false,
			"focus_error": 0.0,
			"observation_requirements": gm.active_observation_requirements(),
			"observation_elapsed": 30.0,
			"exposure": 0.35,
			"dark_adaptation": 1.0,
			"averted_vision": true,
		})
		if bool(result.get("success", false)):
			return result
		best = result
	return best


# ------------------------------------------------------ 8. L55 Neptune+Triton
func _test_level_55_triton(gm: Node) -> void:
	var level := _level(gm, 55)
	var secondary: Dictionary = level.get("secondary_target", {})
	_check(not secondary.is_empty(), "L55 declares a secondary target")
	var triton_id := str(secondary.get("object_id", ""))
	_check(triton_id == "triton", "L55 secondary target is Triton")

	var triton: Dictionary = gm.get_object(triton_id)
	_check(not triton.is_empty(), "Triton is registered as its own object")
	_check(str(triton.get("name_en", "")) != "", "Triton has an English name")
	_check(str(triton.get("name_zh", "")) != "", "Triton has a Chinese name")
	_check(
		str(triton.get("parent_object_id", "")) == "neptune",
		"Triton is linked to Neptune as its parent"
	)
	# Triton must be separately confirmable, and must actually gate completion.
	gm.debug_jump_to_level(55, true)
	_check(not gm.secondary_target_found(), "L55 starts with Triton unconfirmed")
	var observation: Dictionary = {"success": true, "quality": "Good"}
	_check(
		not gm.complete_current_mission("neptune", observation),
		"L55 does not complete on Neptune alone"
	)
	gm.mark_secondary_target_found()
	_check(gm.secondary_target_found(), "Triton can be confirmed independently")
	# Position feedback must be describable, not a pixel hunt.
	_check(
		float(secondary.get("separation_px", 0.0)) > 0.0,
		"Triton has a defined separation from Neptune"
	)
	_check(
		float(secondary.get("detect_radius_px", 0.0)) >= 18.0,
		"Triton's detection radius is forgiving enough to click"
	)
	for key in ["hint_en", "hint_zh", "found_en", "found_zh", "name_en", "name_zh"]:
		_check(str(secondary.get(key, "")) != "", "L55 secondary target has %s" % key)


# ----------------------------------------------------- 10. frozen FAST levels
func _test_frozen_pulsar_chapter(gm: Node) -> void:
	# The pulsar/FAST chapter is explicitly out of scope for this rework.
	for level_number in range(FROZEN_FIRST, FROZEN_LAST + 1):
		var level := _level(gm, level_number)
		_check(not level.is_empty(), "L%d still exists" % level_number)
		_check(
			str(level.get("target_object_id", "")) == "pulsar_b0329",
			"L%d still targets pulsar_b0329" % level_number
		)
		_check(
			str(level.get("observation_mode", "")) == "radio",
			"L%d is still a radio observation" % level_number
		)
		_check(
			not level.has("target_requirement_overrides"),
			"L%d was not touched by the rework" % level_number
		)
	# Campaign order must still run straight through the chapter.
	var mission_manager: Node = root.get_node_or_null("/root/MissionManager")
	if mission_manager != null:
		for level_number in range(FROZEN_FIRST, FROZEN_LAST + 1):
			_check(
				int(mission_manager.order_index(level_number)) >= 0,
				"L%d is still in the campaign order" % level_number
			)


# ------------------------------------------------ 11. assets and data loading
func _test_assets_and_data_load(gm: Node) -> void:
	var ids := ["betelgeuse", "saturn", "pleiades", "venus", "uranus", "neptune", "triton", "mars"]
	for object_id in ids:
		var obj: Dictionary = gm.get_object(object_id)
		_check(not obj.is_empty(), "object '%s' loads" % object_id)
		if obj.is_empty():
			continue
		# Every target needs something renderable in the eyepiece.
		var master: String = OpticalMediaRegistry.master_path(object_id)
		var sprite := str(obj.get("sprite_path", ""))
		var has_art: bool = master != "" or (sprite != "" and ResourceLoader.exists(sprite))
		_check(has_art, "object '%s' has loadable telescope art" % object_id)
		if master != "":
			_check(load(master) != null, "master texture for '%s' loads" % object_id)
	# Sky markers for everything that appears in the star field.
	for object_id in ["betelgeuse", "saturn", "pleiades", "venus", "uranus", "neptune", "mars"]:
		var icon := "res://assets/celestial_icons/%s.png" % object_id
		_check(ResourceLoader.exists(icon), "sky icon exists for '%s'" % object_id)
	# The new low-power eyepiece needs its inventory icon.
	var eyepiece: Dictionary = gm.get_part("eyepiece_32mm")
	_check(not eyepiece.is_empty(), "eyepiece_32mm is registered")
	if not eyepiece.is_empty():
		var icon_path := str(eyepiece.get("icon_path", ""))
		_check(ResourceLoader.exists(icon_path), "eyepiece_32mm icon exists (%s)" % icon_path)
	# New learning cards must resolve.
	for card_id in ["stellar_point_source", "wide_field_framing", "surface_contrast_detail"]:
		var card: Dictionary = gm.get_learning_card(card_id)
		_check(not card.is_empty(), "learning card '%s' loads" % card_id)


# ---------------------------------------------------------- 12. bilingual copy
func _test_bilingual_text(gm: Node) -> void:
	var checked := EXPECTED_TARGETS.keys()
	checked.append(13)
	for level_number_value in checked:
		var level_number := int(level_number_value)
		var level := _level(gm, level_number)
		for field in ["title", "description", "hint_text", "success_text"]:
			var en := str(level.get("%s_en" % field, ""))
			var zh := str(level.get("%s_zh" % field, ""))
			_check(en.strip_edges() != "", "L%d has %s_en" % [level_number, field])
			_check(zh.strip_edges() != "", "L%d has %s_zh" % [level_number, field])
			_check(en != zh, "L%d %s is actually translated" % [level_number, field])
			# Catch untranslated Chinese fields (pure ASCII where CJK expected).
			_check(_has_cjk(zh), "L%d %s_zh contains Chinese text" % [level_number, field])
	# The new objects need bilingual names and learning text too.
	for object_id in ["triton", "saturn", "pleiades", "venus", "uranus", "neptune", "betelgeuse", "mars"]:
		var obj: Dictionary = gm.get_object(object_id)
		if obj.is_empty():
			continue
		for field in ["name", "learning_text"]:
			_check(str(obj.get("%s_en" % field, "")).strip_edges() != "", "%s has %s_en" % [object_id, field])
			var zh := str(obj.get("%s_zh" % field, ""))
			_check(zh.strip_edges() != "", "%s has %s_zh" % [object_id, field])
			_check(_has_cjk(zh), "%s %s_zh contains Chinese text" % [object_id, field])
	# New learning cards, both languages.
	for card_id in ["stellar_point_source", "wide_field_framing", "surface_contrast_detail"]:
		var card: Dictionary = gm.get_learning_card(card_id)
		if card.is_empty():
			continue
		for field in ["title", "text"]:
			_check(str(card.get("%s_en" % field, "")).strip_edges() != "", "card %s has %s_en" % [card_id, field])
			_check(_has_cjk(str(card.get("%s_zh" % field, ""))), "card %s has Chinese %s" % [card_id, field])


# --------------------------------------------- 13. no leftover Jupiter wording
func _test_no_residual_jupiter_copy(gm: Node) -> void:
	var reworked := [4, 10, 13, 16, 50, 53, 55, 60]
	for level_number in reworked:
		var level := _level(gm, level_number)
		var blob := JSON.stringify(level).to_lower()
		_check(not blob.contains("jupiter"), "L%d has no English Jupiter copy left" % level_number)
		_check(not blob.contains("\u6728\u661f"), "L%d has no Chinese Jupiter copy left" % level_number)
		# The learning card a level points at must not describe the old target.
		var card_id := str(level.get("required_concept_card", ""))
		if card_id == "":
			continue
		var card: Dictionary = gm.get_learning_card(card_id)
		if card.is_empty():
			continue
		var card_blob := JSON.stringify(card).to_lower()
		_check(
			not card_blob.contains("jupiter") and not card_blob.contains("\u6728\u661f"),
			"L%d's learning card '%s' does not still teach Jupiter" % [level_number, card_id]
		)
	# Maya's dialogue and board notes for the reworked levels.
	var story: Node = root.get_node_or_null("/root/StoryManager")
	if story == null:
		return
	for level_number in reworked:
		for suffix in ["before", "after", "before_focus", "mid"]:
			var key := "level_%d_%s" % [level_number, suffix]
			var lines: Array = story.get_dialogue(key)
			if lines.is_empty():
				continue
			var blob := JSON.stringify(lines).to_lower()
			_check(not blob.contains("jupiter"), "%s has no Jupiter copy" % key)
			_check(not blob.contains("\u6728\u661f"), "%s has no Chinese Jupiter copy" % key)


# ------------------------------------------------------- 15. layout at 1024x768
func _test_layout_safety(gm: Node) -> void:
	# The mission board gained a target-choice panel and a safety strip; both
	# must stay inside the shipping resolution.
	for level_number in [13, 50]:
		gm.debug_jump_to_level(level_number, true)
		var room: Node = load("res://scenes/observatory_room.tscn").instantiate()
		root.add_child(room)
		await process_frame
		room.call("_open_mission_board")
		await process_frame
		await process_frame
		var popup: Variant = room.get("mission_board_popup")
		_check(popup != null, "L%d mission board opens" % level_number)
		if popup != null:
			var overflow := _overflowing_controls(popup as Control)
			_check(
				overflow.is_empty(),
				"L%d mission board stays inside 1024x768 (overflow: %s)" % [level_number, ", ".join(overflow)]
			)
		room.queue_free()
		await process_frame


# Returns names of visible controls whose rect leaves the 1024x768 screen.
func _overflowing_controls(node: Control) -> Array[String]:
	var bad: Array[String] = []
	var screen := Rect2(Vector2.ZERO, Vector2(1024, 768))
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control.visible and control.size.x > 0.0 and control.size.y > 0.0:
				var rect := Rect2(control.global_position, control.size)
				# Full-rect dimmers legitimately match the screen exactly.
				if not screen.encloses(rect) and rect.size != screen.size:
					bad.append("%s@%s" % [control.name, str(rect)])
			bad.append_array(_overflowing_controls(control))
	return bad


# ------------------------------------------------------- 14. save compatibility
func _test_save_migration(gm: Node) -> void:
	# An old save that recorded completed levels, credits and badges - plus a
	# L13 pick that is no longer offered - must survive untouched apart from
	# the stale pick being dropped.
	gm.new_game()
	gm.progress["completed_levels"] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
	gm.progress["credits"] = 1234
	gm.progress["badges"] = ["Sharp Eye", "Power User"]
	gm.progress["current_level"] = 14
	gm.progress["level_target_overrides"] = {"level_13": "jupiter"}
	gm.progress["journal"] = [{"object_id": "jupiter", "quality": "Good"}]
	gm.save()
	gm.resume_saved_campaign()

	_check(gm.progress["completed_levels"].has(5), "old save keeps completed levels")
	_check(gm.progress["completed_levels"].has(13), "old save keeps later completed levels")
	_check(int(gm.progress.get("credits", 0)) == 1234, "old save keeps credits")
	_check(gm.progress["badges"].has("Power User"), "old save keeps badges")
	_check(int(gm.progress.get("current_level", 0)) == 14, "old save keeps current level")
	var overrides: Dictionary = gm.progress.get("level_target_overrides", {})
	_check(
		not overrides.has("level_13"),
		"a L13 pick that is no longer offered is dropped rather than stranding the player"
	)
	# Historic Jupiter journal entries must remain readable, not be rewritten.
	var journal: Array = gm.progress.get("journal", [])
	_check(journal.size() == 1, "old journal entries are preserved")
	if journal.size() == 1 and journal[0] is Dictionary:
		_check(
			str((journal[0] as Dictionary).get("object_id", "")) == "jupiter",
			"an old Jupiter journal entry is left intact"
		)
	# A save sitting on a reworked level must resolve to the new target.
	gm.progress["current_level"] = 4
	_check(
		str(gm.current_target_object_id()) == "betelgeuse",
		"a save parked on L4 picks up the new target instead of soft-locking"
	)
	_check(not gm.current_target().is_empty(), "the new L4 target resolves to a real object")


# ------------------------------------------------------------------- helpers
func _level(gm: Node, level_number: int) -> Dictionary:
	for level_value in gm.levels_data:
		if not level_value is Dictionary:
			continue
		if int((level_value as Dictionary).get("level_number", -1)) == level_number:
			return level_value as Dictionary
	return {}


func _has_cjk(text: String) -> bool:
	for index in text.length():
		var code := text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		print("  FAIL: " + label)
		failures += 1


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
