extends SceneTree

var failures := 0
var gm: Node
var feedback: Node
var saved_mode := "full"
var saved_seen: Dictionary = {}
var saved_reduced := false


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	feedback = root.get_node_or_null("/root/InteractionFeedback")
	if gm == null or feedback == null:
		push_error("FAST GUIDANCE POLISH TEST: required autoload missing")
		quit(1)
		return
	saved_mode = str(gm.tutorial_assistance_mode())
	saved_seen = feedback.get("_tutorial_seen").duplicate(true)
	saved_reduced = bool(feedback.get("reduced_motion"))

	await _test_guidance_modes_and_persistence()
	await _test_idle_hints_and_terminal_throttle()
	await _test_rfi_recovery()
	await _test_first_pulse_order()
	await _test_chinese_layout()

	feedback.set("_tutorial_seen", saved_seen)
	feedback.call("_save_settings")
	feedback.call("set_reduced_motion", saved_reduced)
	gm.set_tutorial_assistance_mode(saved_mode)
	print("FAST GUIDANCE POLISH TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _new_fast_scene(level_number: int = 76) -> Control:
	var requested_mode := str(gm.progress.get("tutorial_assistance", "full"))
	gm.new_game()
	gm.progress["tutorial_assistance"] = requested_mode
	gm.debug_jump_to_level(level_number, true)
	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.call("_finish_array_takeover")
	await process_frame
	return scene


func _test_guidance_modes_and_persistence() -> void:
	feedback.set("_tutorial_seen", {})
	gm.progress["tutorial_assistance"] = "full"
	var scene := await _new_fast_scene()
	scene.call("_configure_stage_guidance")
	await process_frame
	_check(bool(scene.get("tutorial_active")), "full guidance starts the staged AIM tutorial")
	_check(str(scene.get("tutorial_waiting_action")) == "aim_drive", "AIM tutorial opens on the first physical action instead of an ambiguous Start prompt")
	var status := scene.get("status_label") as Label
	_check(status != null and status.text.contains("MAYA 1/3"), "full guidance identifies Maya and shows concise step progress")
	var next := scene.get("tutorial_next_button") as Button
	_check(next != null and next.text == "I KNOW THIS", "the optional bypass is explicit instead of a vague Start button")
	var frame := scene.get("tutorial_frame") as Control
	var drive_panel := scene.get("aim_drive_panel") as Control
	_check(frame != null and drive_panel != null and frame.size.x < drive_panel.size.x, "AIM guidance highlights the direction controls instead of the whole console")
	scene.call("_tutorial_action", "aim_drive")
	_check(bool(scene.get("tutorial_action_complete")), "the requested player action completes the current tutorial step")
	_check(status.text.contains("inertia"), "the completed drive action explains the visible coasting consequence")
	scene.call("_advance_fast_tutorial")
	_check(str(scene.get("tutorial_waiting_action")) == "aim_brake", "the next revealed action teaches braking")
	scene.call("_finish_stage_tutorial")
	_check(feedback.call("was_tutorial_seen", "fast_guided_stage_v2_aim"), "completed versioned stage tutorial is persisted")
	scene.call("_rebuild")
	await process_frame
	_check(not bool(scene.get("tutorial_active")), "persisted tutorial does not replay automatically")
	scene.queue_free()
	await process_frame

	feedback.set("_tutorial_seen", {})
	gm.progress["tutorial_assistance"] = "light"
	scene = await _new_fast_scene()
	scene.call("_configure_stage_guidance")
	await process_frame
	_check(not bool(scene.get("tutorial_active")), "light guidance does not open the staged tutorial")
	status = scene.get("status_label") as Label
	_check(status != null and status.text != "", "light guidance provides one compact stage hint")
	scene.queue_free()
	await process_frame

	await _test_every_stage_starts_with_an_action()

	feedback.set("_tutorial_seen", {})
	gm.progress["tutorial_assistance"] = "free"
	scene = await _new_fast_scene()
	scene.call("_configure_stage_guidance")
	await process_frame
	_check(not bool(scene.get("tutorial_active")), "free exploration opens no proactive tutorial")
	_check(not (scene.get("tutorial_next_button") as Button).visible, "free exploration leaves tutorial controls hidden")
	scene.queue_free()
	await process_frame


func _test_idle_hints_and_terminal_throttle() -> void:
	feedback.set("_tutorial_seen", {})
	gm.progress["tutorial_assistance"] = "full"
	var scene := await _new_fast_scene()
	scene.call("_configure_stage_guidance")
	scene.set("tutorial_idle_tier", 0)
	scene.call("_show_progressive_idle_hint")
	_check(int(scene.get("tutorial_idle_tier")) == 1, "first idle hint points to the relevant data region")
	scene.call("_show_progressive_idle_hint")
	_check(int(scene.get("tutorial_idle_tier")) == 2, "second idle hint explains the visible phenomenon")
	scene.call("_show_progressive_idle_hint")
	_check(int(scene.get("tutorial_idle_tier")) == 3, "third idle hint gives a concrete operation")

	scene.set("terminal_log", [])
	scene.set("terminal_last_events", {})
	scene.call("_refresh_terminal")
	scene.set("terminal_clock", 10.0)
	var before_count := (scene.get("terminal_log") as Array).size()
	scene.call("_terminal_event", "TEST INPUT", "RUN", "A", "repeat", 1.0)
	var first_count := (scene.get("terminal_log") as Array).size()
	scene.call("_terminal_event", "TEST INPUT", "RUN", "A", "repeat", 1.0)
	var repeated_count := (scene.get("terminal_log") as Array).size()
	_check(first_count == before_count + 1 and repeated_count == first_count, "terminal throttles repeated held-input events")
	scene.set("terminal_clock", 11.1)
	scene.call("_terminal_event", "TEST INPUT", "RUN", "A", "repeat", 1.0)
	_check((scene.get("terminal_log") as Array).size() == repeated_count + 1, "terminal records a later meaningful state sample")
	for i in range(12):
		scene.set("terminal_clock", 12.0 + float(i))
		scene.call("_terminal_event", "EVENT %d" % i, "OK")
	_check((scene.get("terminal_log") as Array).size() == 6, "terminal keeps six readable lines of real event history")
	scene.queue_free()
	await process_frame


func _test_every_stage_starts_with_an_action() -> void:
	feedback.set("_tutorial_seen", {})
	gm.progress["tutorial_assistance"] = "full"
	var scene := await _new_fast_scene()
	var expected := ["aim_drive", "tune_center", "rfi_select", "fold_period_adjust", "report_choose"]
	for stage_index in range(expected.size()):
		scene.set("stage", stage_index)
		scene.call("_rebuild")
		await process_frame
		scene.call("_configure_stage_guidance")
		await process_frame
		_check(
			str(scene.get("tutorial_waiting_action")) == expected[stage_index],
			"FAST stage %d begins with one concrete player action" % (stage_index + 1)
		)
	scene.set("stage", 3)
	scene.set("fold_step", 0)
	var hint := str(scene.call("_idle_hint_for_state", 3))
	_check(not hint.to_lower().contains("drag"), "Fold idle guidance matches the button-driven capture controls")
	scene.queue_free()
	await process_frame


func _test_rfi_recovery() -> void:
	gm.progress["tutorial_assistance"] = "free"
	var scene := await _new_fast_scene(83)
	scene.set("stage", 2)
	scene.call("_rebuild")
	await process_frame
	var model := scene.get("model") as RadioSignalModel
	model.classify(0, true)
	model.classify(1, true)
	_check(model.source_deleted(), "rejecting the source creates visible candidate-loss evidence")
	scene.call("_restore_raw_spectrum")
	_check(model.classifications.is_empty(), "Restore Raw Spectrum clears every reversible classification mask")
	_check(not model.source_deleted(), "restoring the spectrum brings the celestial candidate back")
	var restore := scene.get("rfi_restore_button") as Button
	_check(restore != null and restore.disabled, "restore control disables when the raw spectrum is already restored")
	scene.queue_free()
	await process_frame


func _test_first_pulse_order() -> void:
	gm.progress["tutorial_assistance"] = "free"
	feedback.call("set_reduced_motion", true)
	var scene := await _new_fast_scene()
	scene.set("stage", 3)
	var model := scene.get("model") as RadioSignalModel
	for i in range(model.rfi_peaks.size()):
		model.classify(i, bool(model.rfi_peaks[i].get("is_rfi", false)))
	model.trial_period_ms = model.true_period_ms
	model.trial_dm = model.true_dm
	model.set_integration(maxf(model.required_integration_s, 300.0))
	await scene.call("_play_discovery_moment")
	var trace: Array = scene.get("discovery_event_trace")
	var expected := [
		"SUB-BANDS ALIGNED",
		"WATERFALL PERIODIC",
		"PROFILE EMERGED",
		"REPEATING SOURCE CONFIRMED",
	]
	_check(trace == expected, "FIRST PULSE follows the physical sub-band -> waterfall -> profile -> confirmation order")
	_check(float(scene.get("discovery_phase")) >= 0.99, "reduced motion preserves the complete discovery state change")
	scene.queue_free()
	await process_frame


func _test_chinese_layout() -> void:
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["tutorial_assistance"] = "free"
	var scene := await _new_fast_scene()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	scene.call("_rebuild")
	await create_timer(0.20).timeout
	var terminal := scene.get("terminal_panel") as Control
	var status := scene.get("status_label") as Control
	var help := scene.get("tutorial_help_button") as Control
	_check(
		terminal != null and status != null
		and not Rect2(terminal.position, terminal.size).intersects(Rect2(status.position, status.size)),
		"Chinese terminal remains separate from the footer at 1024x768"
	)
	_check(status != null and help != null and not status.get_global_rect().intersects(help.get_global_rect()), "Chinese status text does not overlap the Help control")

	scene.set("stage", 1)
	scene.call("_rebuild")
	await process_frame
	var tune_controls := scene.find_child("TuneControlsPanel", true, false) as Control
	var tune_title := scene.find_child("TuneControlsTitle", true, false) as Control
	var center_caption := scene.find_child("TuneCenterLabel", true, false) as Control
	var width_caption := scene.find_child("TuneWidthLabel", true, false) as Control
	terminal = scene.get("terminal_panel") as Control
	_check(tune_controls != null and terminal != null and tune_controls.get_global_rect().end.y <= terminal.get_global_rect().position.y - 3.0, "Tune controls end above the terminal band")
	_check(tune_title != null and center_caption != null and not tune_title.get_global_rect().intersects(center_caption.get_global_rect()), "Chinese center-frequency caption stays below the Tune title")
	_check(tune_title != null and width_caption != null and not tune_title.get_global_rect().intersects(width_caption.get_global_rect()), "Chinese bandwidth caption stays below the Tune title")

	scene.call("_radio_operation_chain", "锁定馈源舱", "运动速度收束，缆索张力稳定", "接收机现在可以搜索射电频段")
	await process_frame
	var chain := scene.get_node_or_null("OperationChainFeedback") as Control
	var back := scene.find_child("FastBackButton", true, false) as Control
	terminal = scene.get("terminal_panel") as Control
	help = scene.get("tutorial_help_button") as Control
	_check(
		chain != null and terminal != null
		and terminal.get_global_rect().encloses(chain.get_global_rect()),
		"FAST operation feedback temporarily occupies and remains clipped to the event terminal bay"
	)
	_check(chain != null and back != null and not chain.get_global_rect().intersects(back.get_global_rect()), "FAST operation feedback never covers Back")
	_check(chain != null and help != null and not chain.get_global_rect().intersects(help.get_global_rect()), "FAST operation feedback never covers Help")
	if chain != null:
		for value_index in range(3):
			var chain_value := chain.get_node_or_null("OperationChainValue%d" % value_index) as Control
			_check(
				chain_value != null and chain.get_global_rect().encloses(chain_value.get_global_rect()),
				"FAST operation feedback column %d remains inside its clipped terminal bay" % (value_index + 1)
			)

	for stage_index in range(5):
		scene.set("stage", stage_index)
		scene.call("_rebuild")
		await process_frame
		terminal = scene.get("terminal_panel") as Control
		var stage_content := scene.get("content") as Control
		var stage_clear := true
		for child in stage_content.get_children():
			if child is Control and (child as Control).visible:
				stage_clear = stage_clear and (child as Control).get_global_rect().end.y <= terminal.get_global_rect().position.y - 2.0
		_check(stage_clear, "Chinese FAST stage %d content remains above the terminal band" % (stage_index + 1))

	var shader_text := FileAccess.get_file_as_string("res://shaders/fast_crt_monitor.gdshader")
	_check(not shader_text.contains("SCREEN_UV"), "CRT glass never resamples the full-screen UI")
	_check(not shader_text.contains("hint_screen_texture"), "CRT glass uses no mipmapped screen texture")
	_check(not shader_text.contains("curvature"), "CRT glass cannot warp text or control geometry")
	_check(shader_text.contains("smoothstep(0.80, 1.0"), "CRT darkening is restricted to the outer glass")
	_check(shader_text.contains("scanline_strength") and shader_text.contains("0.022"), "CRT scanlines are reduced for text readability")
	scene.set("stage", 0)
	scene.call("_rebuild")
	await process_frame
	var glass := scene.get("crt_glass") as Control
	var lock := scene.get("lock_button") as Control
	var rect_before := lock.get_global_rect() if lock != null else Rect2()
	scene.call("_update_fast_crt")
	var rect_after := lock.get_global_rect() if lock != null else Rect2()
	_check(glass != null and glass.material is ShaderMaterial, "transparent CRT effect is isolated on its own glass overlay")
	_check(lock != null and lock.material == null, "interactive controls stay on an unshaded clear layer")
	_check(rect_before == rect_after, "CRT state updates never move or resize controls")
	scene.queue_free()
	await process_frame
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: ", message)
		return
	failures += 1
	push_error("  FAIL: " + message)
