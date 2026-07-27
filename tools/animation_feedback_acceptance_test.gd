extends SceneTree

var failures := 0
var gm: Node
var feedback: Node
var sfx_events: Array[String] = []
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	feedback = root.get_node_or_null("/root/InteractionFeedback")
	_check(gm != null and feedback != null, "animation service autoloads without changing GameManager")
	if gm == null or feedback == null:
		_restore_save()
		quit(1)
		return
	feedback.feedback_sfx_requested.connect(func(event_name: String) -> void: sfx_events.append(event_name))
	await _test_common_feedback_and_accessibility()
	await _test_observation_motion()
	await _test_focus_feedback()
	await _test_assembly_snap()
	await _test_room_routing()
	await _test_result_chain()
	await _test_collimation_feedback()
	print("ANIMATION FEEDBACK ACCEPTANCE %s" % ("PASS" if failures == 0 else "FAIL"))
	_restore_save()
	quit(0 if failures == 0 else 1)


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _test_common_feedback_and_accessibility() -> void:
	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(160, 44)
	host.add_child(button)
	var slider := HSlider.new()
	slider.position = Vector2(100, 170)
	slider.size = Vector2(220, 32)
	slider.min_value = 0.0
	slider.max_value = 100.0
	host.add_child(slider)
	await process_frame
	_check(bool(button.get_meta("feedback_bound", false)), "important buttons receive the shared hover/click feedback")
	_check(button.has_node("InteractionFeedbackShadow") and button.has_node("InteractionFeedbackShine"), "buttons receive depth and highlight layers")
	button.mouse_entered.emit()
	await create_timer(0.18).timeout
	_check(button.scale.x > 1.0, "hover produces a restrained spring lift")
	button.button_down.emit()
	await create_timer(0.08).timeout
	_check(button.scale.x < 1.0, "press visibly depresses the button")
	button.button_up.emit()
	button.pressed.emit()
	await create_timer(0.03).timeout
	_check(button.has_node("InteractionFeedbackClickEcho"), "confirmed clicks create a short gold echo")
	feedback.selection(button, true, Color(1.0, 0.78, 0.32), true, "acceptance_selection")
	await create_timer(0.15).timeout
	_check(bool(button.get_meta("feedback_selected", false)), "selected controls keep a persistent state")
	_check(bool(slider.get_meta("feedback_bound", false)), "sliders receive the shared adjustment feedback")
	slider.value = 42.0
	await create_timer(0.08).timeout
	var slider_border := slider.get_node_or_null("InteractionFeedbackEffectBorder") as Panel
	_check(slider_border != null and slider_border.modulate.a > 0.2, "slider movement produces visible active feedback")
	feedback.set_reduced_motion(true)
	var start_position := host.position
	feedback.page_enter(host, Vector2(0, 20))
	_check(host.position == start_position, "reduced motion removes page travel while preserving feedback")
	feedback.set_reduced_motion(false)
	var tutorial_key := "animation_acceptance_once_%d" % Time.get_ticks_usec()
	var first: Variant = feedback.tutorial_highlight_once(button, tutorial_key, "Guide", host)
	var second: Variant = feedback.tutorial_highlight_once(button, tutorial_key, "Guide", host)
	_check(first != null and second == null, "tutorial highlights do not repeat")
	if first is Control:
		var tutorial := first as Control
		var frame := tutorial.get_child(1) as Panel
		var bubble := tutorial.get_node_or_null("MayaTutorialBubble") as Panel
		_check(bubble != null and not frame.get_rect().intersects(bubble.get_rect()) and bubble.position.x >= 0.0 and bubble.position.x + bubble.size.x <= host.size.x, "tutorial copy stays on-screen without covering its highlighted control")
	var chain: Variant = feedback.operation_chain(host, "Turned the knob", "Focus plane moved", "Detail became sharp", button)
	_check(chain != null and chain.get_child_count() >= 3, "operation chain presents action, physical effect, and visible result")
	host.size = Vector2(480, 270)
	var mobile_chain: Control = feedback.operation_chain(host, "Locked guide", "Pointing stabilized", "Wavefront control ready")
	await process_frame
	_check(
		mobile_chain != null
			and mobile_chain.position.x >= 0.0
			and mobile_chain.position.y >= 0.0
			and mobile_chain.position.x + mobile_chain.size.x <= host.size.x
			and mobile_chain.position.y + mobile_chain.size.y <= host.size.y,
		"compact operation chain stays inside a mobile landscape viewport"
	)
	host.queue_free()
	await process_frame


func _prepare_level(level_number: int) -> void:
	gm.new_game()
	gm.progress["current_level"] = level_number
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		if not gm.unlocked_parts_by_type(part_type).is_empty():
			gm.install_part(part_type, 0)
	gm.selected_object_id = str(gm.current_target_object_id())


func _test_observation_motion() -> void:
	_prepare_level(15)
	var view: Control = load("res://scenes/sky_observation.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	view.call("_set_view_mode", "finder")
	var view_layer := view.get("view_layer") as Control
	var optical_transition := view.get("optical_mode_transition") as Control
	_check(view_layer != null and optical_transition != null and optical_transition.visible, "Eye/Finder/Scope switching starts a visible optical transition")
	_check(view.get("reticle_transition_ghost") != null, "old and new reticles crossfade instead of swapping instantly")
	await create_timer(0.52).timeout
	_check(not optical_transition.visible and is_equal_approx(float(view.get("mode_content_alpha")), 1.0), "mode transition settles without changing target coordinates")
	var real_before := float(view.get("telescope_azimuth"))
	var display_before := float(view.get("display_azimuth"))
	view.call("_apply_aim_delta", 12.0, 0.0)
	var real_after := float(view.get("telescope_azimuth"))
	var display_after := float(view.get("display_azimuth"))
	_check(real_after != real_before and display_after != display_before and display_after != real_after, "aim data is immediate while scale and pointer chase smoothly")
	await create_timer(0.35).timeout
	_check(absf(float(view.get("display_azimuth")) - real_after) < 0.5, "animated scale catches the real azimuth without desynchronizing")
	gm.progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	view.call("_update_calibration_panel")
	await process_frame
	var finder_events_before := sfx_events.count("finder_aligned") + sfx_events.count("finder_lock")
	view.call("_update_calibration_panel")
	await process_frame
	var finder_events_after := sfx_events.count("finder_aligned") + sfx_events.count("finder_lock")
	_check(bool(view.get("calibration_success_played")) and finder_events_after == finder_events_before, "finder alignment success feedback plays only once")
	var ring := view.get("target_state_ring") as TextureRect
	if ring != null and ring.texture != null:
		var center_alpha := ring.texture.get_image().get_pixel(ring.texture.get_width() / 2, ring.texture.get_height() / 2).a
		_check(center_alpha < 0.35, "target lock ring keeps its center transparent")
	var target_id := str(view.get("target_id"))
	var target_item: Dictionary = view.call("_sky_item", target_id)
	if float(target_item.get("altitude", -90.0)) < 0.0:
		target_item["altitude"] = 45.0
		target_item["azimuth"] = 180.0
		target_item["below_horizon"] = false
		target_item["visible"] = true
		var synthetic_sky: Dictionary = view.get("sky_data")
		synthetic_sky[target_id] = target_item
		view.set("sky_data", synthetic_sky)
	view.call("_set_view_mode", "naked_eye")
	view.set("telescope_azimuth", float(target_item.get("azimuth", 180.0)))
	view.set("telescope_altitude", float(target_item.get("altitude", 45.0)))
	view.set("display_azimuth", float(target_item.get("azimuth", 180.0)))
	view.set("display_altitude", float(target_item.get("altitude", 45.0)))
	view.call("_rebuild_view")
	await create_timer(0.12).timeout
	_check(str(view.get("target_lock_state")) == "locked", "mission target produces a precise centered lock")
	_check(view_layer.get_node_or_null("OperationChainFeedback") != null, "mission lock explains why Observe became ready")
	var free_id := ""
	for object_id_value in (view.get("sky_data") as Dictionary).keys():
		var object_id := str(object_id_value)
		if object_id != target_id and float((view.get("sky_data") as Dictionary)[object_id].get("altitude", -90.0)) >= 0.0:
			free_id = object_id
			break
	if free_id != "":
		view.call("_select_object", free_id)
		_check(str(view.get("selected_object_id")) == free_id and str(view.get("selected_object_id")) != target_id, "free selection remains separate from the mission target")
	view.queue_free()
	await process_frame


func _test_focus_feedback() -> void:
	_prepare_level(8)
	var view: Control = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	await process_frame
	await process_frame
	if bool(view.get("requires_focus")):
		var target := float(view.get("target_focus_value"))
		view.call("_set_focus_value", target)
		_check(bool(view.get("focus_lock_feedback_played")), "focus image and knob emit one sharp-focus lock")
		var count_before := sfx_events.count("focus_locked")
		view.call("_set_focus_value", target)
		_check(sfx_events.count("focus_locked") == count_before, "sharp-focus lock does not repeat")
		_check(float(view.get("focus_error")) <= float(view.get("focus_tolerance")), "focus animation leaves the original focus condition unchanged")
	view.queue_free()
	await process_frame


func _test_assembly_snap() -> void:
	gm.new_game()
	gm.progress["current_level"] = 4
	gm.call("_unlock_parts_for_current_level")
	gm.reset_assembly()
	var assembly: Control = load("res://scenes/telescope_assembly.tscn").instantiate()
	root.add_child(assembly)
	await process_frame
	await process_frame
	assembly.call("_select_part", "tripod")
	assembly.call("_try_install", "tripod")
	await create_timer(0.05).timeout
	_check(assembly.find_child("InstallingPartFeedback", true, false) != null, "part icon travels from its card to the blueprint slot")
	await create_timer(0.65).timeout
	_check(bool(gm.progress.get("assembly_state", {}).get("tripod", {}).get("installed", false)), "snap animation commits through the original installation logic")
	var chain := assembly.get_node_or_null("OperationChainFeedback")
	_check(chain != null, "successful installation reveals the next operation through a compact chain")
	assembly.queue_free()
	await process_frame


func _test_room_routing() -> void:
	_prepare_level(4)
	gm.update_room_guidance_for_level()
	gm.set_observatory_spawn("assembly")
	var room: Control = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	var player_position: Vector2 = room.get("player_pos")
	var assembly_spawn: Vector2 = room.call("_spawn_position", "assembly")
	_check(player_position.distance_to(assembly_spawn) < 4.0, "assembly completion returns beside the assembly table")
	_check(room.get_node_or_null("OperationChainFeedback") != null, "room arrival confirms Telescope Ready and reveals the routed destination")
	_check(str(gm.room_guidance_target) in ["telescope", "computer"], "existing route guidance points to the correct observing station")
	room.queue_free()
	await process_frame


func _test_result_chain() -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	gm.progress["current_level"] = 66
	var level: Dictionary = gm.current_level().duplicate(true)
	var target_id := str(level.get("target_object_id", "andromeda"))
	var observation := {
		"quality": "Excellent",
		"success": true,
		"observation_mode": "telescope",
		"effective_clarity": 94.0,
		"ratios": {"light": 1.2, "clarity": 1.2, "stability": 1.2},
	}
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	gm.last_learning_card = teaching.call(
		"make_mission_complete_payload",
		level,
		gm.get_object(target_id),
		observation,
		{"light_score": 95.0, "clarity_score": 94.0, "stability_score": 93.0}
	)
	gm.progress["current_level"] = 67
	teaching.active_card_mode = "complete"
	var card: Control = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	await process_frame
	await process_frame
	var text := _tree_text(card)
	_check(text.contains("Operation Chain") and text.contains("ACTION") and text.contains("PHYSICAL EFFECT") and text.contains("WHAT BECAME VISIBLE"),
		"successful observation explains action, physical effect, and visible evidence")
	_check(text.contains("Thermal noise") and text.contains("infrared"),
		"Space result uses thermal and infrared language rather than an optical-telescope summary")
	_check(text.contains("NEXT:") and text.contains("Go to:"),
		"completed observation reveals the existing next route")
	card.queue_free()
	await process_frame


func _test_collimation_feedback() -> void:
	_prepare_level(26)
	var collimation: Control = load("res://scenes/collimation.tscn").instantiate()
	root.add_child(collimation)
	await process_frame
	await process_frame
	collimation.set("secondary_x", 0.0)
	collimation.set("secondary_y", 0.0)
	collimation.set("primary_x", 0.0)
	collimation.set("primary_y", 0.0)
	collimation.call("_refresh")
	await create_timer(0.18).timeout
	var axis := collimation.get("optical_axis") as Line2D
	_check(bool(collimation.get("collimation_success_played")), "collimation threshold produces one clear completion feedback")
	_check(axis != null and axis.default_color.is_equal_approx(Color(0.48, 0.92, 0.58)), "collimation light path turns green when aligned")
	_check(axis != null and axis.points.size() == 3, "mirror adjustments drive the primary-secondary-eyepiece light path")
	collimation.queue_free()
	await process_frame


func _tree_text(node: Node) -> String:
	var text := ""
	if node is Label:
		text += (node as Label).text + "\n"
	elif node is Button:
		text += (node as Button).text + "\n"
	for child in node.get_children():
		text += _tree_text(child)
	return text


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		print("  FAIL: ", message)
