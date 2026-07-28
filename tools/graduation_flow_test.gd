extends SceneTree

# End-to-end regression for the campaign conclusion. The final lesson must
# award once, route through Maya's epilogue into graduation, and leave the
# mission board in a permanent completed state instead of replaying L85.

var failures := 0
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_backup_save()
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var sm: Node = root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		print("GRADUATION FLOW TEST FAIL (autoloads missing)")
		_restore_save()
		quit(1)
		return

	await _test_final_completion_and_ceremony(gm, sm)
	await _test_postgraduate_board_and_duplicate_protection(gm)
	_test_old_save_graduation_migration(gm)

	if failures == 0:
		print("GRADUATION FLOW TEST PASS")
		_restore_save()
		quit(0)
	else:
		print("GRADUATION FLOW TEST FAIL (%d)" % failures)
		_restore_save()
		quit(1)


func _test_final_completion_and_ceremony(gm: Node, sm: Node) -> void:
	gm.new_game()
	gm.debug_jump_to_level(85, true)
	var mission_manager: Node = root.get_node_or_null("/root/MissionManager")
	if mission_manager != null:
		var completed_before_final: Array = []
		for number_value in mission_manager.get("campaign_order") as Array:
			var number := int(number_value)
			if number < 85:
				completed_before_final.append(number)
		gm.progress["completed_levels"] = completed_before_final
	for step_value in gm.mission_steps():
		var step: Dictionary = step_value
		gm.mark_mission_step_done(str(step.get("id", "")))
	var credits_before := int(gm.progress.get("credits", 0))
	var completed := bool(gm.complete_current_mission(
		gm.current_target_object_id(),
		{"success": true, "quality": "Excellent", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}}
	))
	await process_frame

	_check(completed, "L85 completes successfully")
	_check(bool(gm.progress.get("program_completed", false)), "program completion is persisted")
	_check(bool(gm.progress.get("graduation_pending", false)), "graduation is queued after L85")
	_check(not bool(gm.progress.get("graduation_seen", false)), "ceremony is not marked seen before presentation")
	_check((gm.progress.get("badges", []) as Array).has("Radio Graduate"), "FAST graduation badge is awarded")
	_check((gm.progress.get("badges", []) as Array).has("Young Observer"), "program graduation badge is awarded")
	_check(int(gm.progress.get("credits", 0)) > credits_before, "final mission Credits are awarded")
	_check((gm.progress.get("completed_levels", []) as Array).count(85) == 1, "L85 is archived exactly once")

	var result_card := current_scene
	var graduation_button := result_card.find_child("GraduationButton", true, false) if result_card != null else null
	_check(graduation_button is Button, "final result offers a Graduation Ceremony button")
	_check(not _collect_text(result_card).contains("NEXT: Level 85"), "result card never advertises L85 as the next lesson")
	if graduation_button is Button:
		(graduation_button as Button).pressed.emit()
		await process_frame
		await process_frame

	# L85 has a Maya epilogue. Finish it in the test to verify its return target.
	if current_scene != null and current_scene.name != "GraduationCeremony":
		sm.finish_active_event()
		await process_frame
		await process_frame

	_check(current_scene != null and current_scene.name == "GraduationCeremony", "Maya's final epilogue routes into the graduation ceremony")
	_check(bool(gm.progress.get("graduation_seen", false)), "presenting the ceremony is remembered")
	_check(not bool(gm.progress.get("graduation_pending", true)), "ceremony queue clears after presentation")
	_check(_collect_text(current_scene).contains("YOUNG OBSERVER"), "ceremony presents the Young Observer award")
	_check(_collect_text(current_scene).contains("LOOK HOW FAR YOU CAME"), "graduation begins with a concise journey recap")
	var recap_copy := current_scene.find_child("GraduationRecapCopy", true, false)
	if recap_copy is Label:
		var original_text := (recap_copy as Label).text
		(recap_copy as Label).text = original_text + " " + "VeryLongCatalogIdentifierWithoutSpaces".repeat(8)
		await process_frame
		var copy_rect := (recap_copy as Label).get_global_rect()
		var parent_rect := (recap_copy as Label).get_parent_control().get_global_rect()
		_check(copy_rect.end.x <= parent_rect.end.x + 0.5, "long graduation dialogue stays inside its content rect")
		_check((recap_copy as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, "graduation dialogue keeps automatic wrapping enabled")
		(recap_copy as Label).text = original_text
	else:
		_check(false, "graduation recap dialogue exists")

	var next_button := current_scene.find_child("GraduationNextButton", true, false)
	_check(next_button is Button, "graduation recap can continue into the archive")
	if next_button is Button:
		(next_button as Button).pressed.emit()
		await process_frame
	_check(_collect_text(current_scene).contains("YOUR OBSERVING RECORD"), "graduation unfolds the player's real observing archive")
	_check(_collect_text(current_scene).contains("PSR B0329+54"), "archive recap includes the final recorded target")

	next_button = current_scene.find_child("GraduationNextButton", true, false)
	if next_button is Button:
		(next_button as Button).pressed.emit()
		await process_frame
	_check(_collect_text(current_scene).contains("EQUIPMENT & ACCESS HANDOVER"), "graduation explicitly separates equipment ownership from facility access")
	_check(_collect_text(current_scene).contains("OWNERSHIP TRANSFERRED"), "graduation transfers unlocked optical equipment")
	_check(_collect_text(current_scene).contains("SPACE INFRARED"), "graduation names Space Infrared free observation")
	_check(_collect_text(current_scene).contains("FAST RADIO"), "graduation names FAST free observation")
	_check(_collect_text(current_scene).contains("REMOTE ACCESS GRANTED"), "graduation keeps national facilities as remote access")
	var owned_optical: Array[String] = gm.owned_optical_telescope_families()
	_check(not owned_optical.is_empty(), "graduation persists ownership of unlocked optical families")
	_check(not owned_optical.has("space_segmented") and not owned_optical.has("fast_radio"), "remote facilities are never transferred as personal equipment")
	_check(gm.is_player_optical_family(gm.active_optical_telescope_family()), "graduation active equipment is always an optical family")
	for index in range(3):
		var access_card := current_scene.find_child("GraduationAccessCard%d" % index, true, false)
		var access_copy := current_scene.find_child("GraduationAccessCopy%d" % index, true, false)
		if access_card is Control and access_copy is Control:
			_check((access_copy as Control).get_global_rect().end.x <= (access_card as Control).get_global_rect().end.x + 0.5, "graduation access card %d text stays inside its content rect" % (index + 1))
		else:
			_check(false, "graduation access card %d exposes a bounded copy control" % (index + 1))
	var access_dialogue := current_scene.find_child("GraduationAccessDialogue", true, false)
	_check(access_dialogue is Label and (access_dialogue as Label).autowrap_mode != TextServer.AUTOWRAP_OFF, "graduation ownership dialogue remains wrapped")

	next_button = current_scene.find_child("GraduationNextButton", true, false)
	if next_button is Button:
		(next_button as Button).pressed.emit()
		await process_frame
	_check(_collect_text(current_scene).contains("INDEPENDENT NIGHT 01"), "graduation ends with a concrete first independent observing prompt")
	_check(current_scene.find_child("BeginIndependentNightButton", true, false) is Button, "graduation offers a clear start-independent-night action")


func _test_postgraduate_board_and_duplicate_protection(gm: Node) -> void:
	var credits_before_repeat := int(gm.progress.get("credits", 0))
	var journal_before_repeat := (gm.progress.get("journal_entries", []) as Array).size()
	var completed_before_repeat := (gm.progress.get("completed_levels", []) as Array).size()

	var return_button := current_scene.find_child("BeginIndependentNightButton", true, false) if current_scene != null else null
	_check(return_button is Button, "ceremony has a begin-independent-night action")
	if return_button is Button:
		(return_button as Button).pressed.emit()
		await process_frame
		await process_frame
	_check(current_scene != null and current_scene.name == "ObservatoryRoom", "ceremony returns to the observatory")

	var route: Dictionary = gm.current_room_route()
	_check(bool(route.get("completed", false)), "post-graduation lobby uses a completed route")
	_check(str(route.get("title", "")).contains("Program Complete"), "post-graduation guidance says the program is complete")
	_check(not str(route.get("hint", "")).contains("next unfinished lesson"), "post-graduation guidance does not promise another lesson")
	_check(str(route.get("target", "")) == "", "post-graduation lobby has no mandatory furniture route")
	_check(gm.room_guidance_target == "", "post-graduation room guidance remains cleared")
	_check(get_nodes_in_group("guidance_highlight").is_empty(), "post-graduation lobby creates no guidance highlight")

	if current_scene != null and current_scene.has_method("_enter_learning_journal"):
		current_scene.call("_enter_learning_journal")
		await process_frame
		await process_frame
	_check(current_scene != null and current_scene.name == "LearningJournal", "graduate can open the journal voluntarily")
	if current_scene != null and current_scene.has_method("_go_back"):
		current_scene.call("_go_back")
		await process_frame
		await process_frame
	_check(current_scene != null and current_scene.name == "ObservatoryRoom", "journal returns to the observatory")
	_check(gm.room_guidance_target == "", "journal return does not recreate postgraduate guidance")
	_check(get_nodes_in_group("guidance_highlight").is_empty(), "journal return does not recreate a highlight")


	if current_scene != null and current_scene.has_method("_open_mission_board"):
		current_scene.call("_open_mission_board")
		await process_frame
	var graduated_panel := current_scene.find_child("GraduatedMissionBoardPanel", true, false) if current_scene != null else null
	var board_text := _collect_text(graduated_panel)
	_check(board_text.contains("PROGRAM COMPLETE"), "mission board becomes a permanent graduation record")
	_check(not board_text.contains("LEVEL 85"), "graduated mission board does not present L85 as active")
	_check(not board_text.contains("Show Route"), "graduated mission board has no mission restart route")

	# A stale result or explicit repeat cannot duplicate the final payout and
	# never creates a second completion record.
	gm.complete_current_mission(
		gm.current_target_object_id(),
		{"success": true, "quality": "Excellent", "ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}}
	)
	await process_frame
	_check(int(gm.progress.get("credits", 0)) == credits_before_repeat, "re-entering final completion cannot duplicate Credits")
	_check((gm.progress.get("journal_entries", []) as Array).size() == journal_before_repeat, "re-entering final completion cannot duplicate the log")
	_check((gm.progress.get("completed_levels", []) as Array).size() == completed_before_repeat, "re-entering final completion cannot duplicate L85")


func _test_old_save_graduation_migration(gm: Node) -> void:
	gm.new_game()
	gm.progress["current_level"] = 85
	gm.progress["completed_levels"] = [85]
	gm.progress.erase("program_completed")
	gm.progress.erase("graduation_pending")
	gm.progress.erase("graduation_seen")
	gm._normalize_progress()
	_check(bool(gm.progress.get("program_completed", false)), "old completed save recovers program-complete state")
	_check(bool(gm.progress.get("graduation_pending", false)), "old completed save receives the missing ceremony once")
	_check(not bool(gm.progress.get("graduation_seen", true)), "old completed save does not falsely mark ceremony seen")
	_check((gm.progress.get("badges", []) as Array).has("Young Observer"), "old completed save recovers the graduation badge")

	gm.progress["graduation_seen"] = true
	gm.progress["graduation_pending"] = false
	gm.progress.erase("owned_optical_telescope_families")
	gm.progress.erase("active_optical_telescope_id")
	gm.progress.erase("optical_ownership_transfer_version")
	gm._normalize_progress()
	var migrated_owned: Array[String] = gm.owned_optical_telescope_families()
	_check(not migrated_owned.is_empty(), "old graduated save receives optical ownership without replaying the ceremony")
	_check(not migrated_owned.has("space_segmented") and not migrated_owned.has("fast_radio"), "old graduated save migration excludes remote facilities")
	_check(gm.is_player_optical_family(gm.active_optical_telescope_family()), "old graduated save infers an optical active family instead of a remote facility")


func _collect_text(node: Node) -> String:
	if node == null:
		return ""
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child in node.get_children():
		result += _collect_text(child)
	return result


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
		failures += 1
		print("  FAIL: " + label)
