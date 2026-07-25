extends Control

# FAST remains a five-stage radio pipeline. The pure RadioSignalModel owns all
# scientific state; this screen turns that state into a physical control-room
# experience without introducing optical-telescope concepts.

const BG := Color("07101a")
const PANEL := Color("101b29")
const PANEL_DEEP := Color("09141f")
const GOLD := Color("d7a64a")
const BRASS := Color("8e682e")
const CYAN := Color("69cee8")
const CRT := Color("94c8c4")
const GREEN := Color("70d68b")
const AMBER := Color("e0a447")
const RED := Color("dc6a50")
const TEXT := Color("e8e2d4")
const MUTED := Color("91a3b4")
const STAGE_KEYS := ["aim", "tune", "rfi", "fold", "report"]
const SIMULATED_INTEGRATION_RATE := 42.0
const WATERFALL_ROWS := 24

static var _array_takeover_seen_this_session := false


class RadioPlot:
	extends Control
	var renderer: Callable

	func _draw() -> void:
		if renderer.is_valid():
			renderer.call(self)


var model: RadioSignalModel
var profile: Dictionary = {}
var stage := 0
var running := false
var discovery_running := false
var intro_running := false
var intro_progress := 0.0
var intro_overlay: Panel
var intro_plot: RadioPlot
var objective_label: Label

var status_label: Label
var readout: Label
var scope: RadioPlot
var stage_bar_holder: Control
var content: Control

var drive_vector := Vector2.ZERO
var drive_braking := false
var aim_trail: Array[Vector2] = []
var aim_lamp: Panel
var lock_button: Button

var tune_drag_mode := ""
var tune_log_label: Label
var tune_waterfall: Array = []
var waterfall_clock := 0.0
var waterfall_phase := 0.0

var selected_peak := -1
var rfi_evidence_label: Label
var rfi_waterfall: Array = []

var fold_step := 0
var fold_slider: HSlider
var fold_action_button: Button
var integration_held := false
var fold_step_label: Label
var fold_controls_panel: Panel

var report_choice := ""
var report_choice_buttons: Dictionary = {}
var submit_button: Button
var aim_capture_progress := 0.0
var aim_capture_state := ""
var discovery_phase := 0.0
var discovery_plot: RadioPlot


func _ready() -> void:
	profile = _profile()
	model = RadioSignalModel.new()
	model.configure(profile)
	GameManager.language_changed.connect(_rebuild)
	set_process(true)
	_rebuild()
	InteractionFeedback.page_enter(self)
	call_deferred("_maybe_play_array_takeover")


func _profile() -> Dictionary:
	var level := GameManager.current_level()
	var value: Variant = level.get("radio_profile", {})
	if value is Dictionary and not (value as Dictionary).is_empty():
		return (value as Dictionary).duplicate(true)
	return {
		"target_id": GameManager.current_target_object_id(),
		"kind": "pulsar",
		"challenge": "balanced",
	}


func _process(delta: float) -> void:
	if model == null:
		return
	if intro_running:
		intro_progress = clampf(intro_progress + delta / 2.8, 0.0, 1.0)
		if intro_plot != null and is_instance_valid(intro_plot):
			intro_plot.queue_redraw()
		return
	if stage == 0 and not running:
		var keyboard_drive := _keyboard_drive()
		var active_drive := keyboard_drive if keyboard_drive != Vector2.ZERO else drive_vector
		if active_drive != Vector2.ZERO:
			model.nudge(active_drive.x, -active_drive.y, delta * 6.2)
		if drive_braking or Input.is_key_pressed(KEY_SPACE):
			model.brake(delta * 7.0)
		model.step(delta)
		_record_aim_trail()
		_refresh_aim()
	elif stage == 3 and fold_step == 2 and integration_held and not discovery_running:
		model.set_integration(model.integration_s + delta * SIMULATED_INTEGRATION_RATE)
		_refresh_fold()
	elif stage in [1, 2] and not running:
		waterfall_clock += delta
		if waterfall_clock >= 0.14:
			waterfall_clock = 0.0
			waterfall_phase += 1.0
			_capture_waterfall_row(tune_waterfall if stage == 1 else rfi_waterfall, stage == 2)
			if scope != null and is_instance_valid(scope):
				scope.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if running or discovery_running or intro_running:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE and stage == 3 and fold_step == 2:
			integration_held = key.pressed
			get_viewport().set_input_as_handled()
			return
		if not key.pressed or key.echo:
			return
		match stage:
			0:
				if key.keycode == KEY_ENTER:
					_try_lock()
			1:
				_tune_keyboard(key.keycode)
			2:
				_rfi_keyboard(key.keycode)
			3:
				_fold_keyboard(key.keycode)


func _keyboard_drive() -> Vector2:
	if stage != 0:
		return Vector2.ZERO
	var value := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		value.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		value.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		value.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		value.y += 1.0
	return value.normalized()


# ---------------------------------------------------------------- layout
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_panel(Vector2(14, 10), Vector2(996, 724), Color("09131f"), BRASS)
	_label(GameManager.text("FAST RADIO OBSERVATION", "FAST 射电观测"), Vector2(24, 18), Vector2(976, 30), 23, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var target := GameManager.current_target()
	_label(
		GameManager.text("Target: ", "目标：") + GameManager.dict_text(target, "name")
			+ "   ·   " + _challenge_title(),
		Vector2(24, 48), Vector2(976, 22), 13, CRT, HORIZONTAL_ALIGNMENT_CENTER
	)
	_build_stage_bar()
	objective_label = _label(
		_stage_objective(),
		Vector2(42, 108), Vector2(940, 24), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER
	)
	objective_label.add_theme_stylebox_override("normal", _flat(Color("081723"), Color("28465a"), 1))

	content = Control.new()
	content.position = Vector2(0, 128)
	content.size = Vector2(1024, 546)
	add_child(content)

	status_label = _label("", Vector2(40, 680), Vector2(750, 42), 13, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(GameManager.text("Back", "返回"), Vector2(812, 684), Vector2(178, 38), Color("172235"))
	back.pressed.connect(_back)
	add_child(back)
	_build_stage()


func _stage_objective() -> String:
	match STAGE_KEYS[stage]:
		"aim":
			return GameManager.text(
				"OBJECTIVE: DRIVE, BRAKE, AND SETTLE THE FEED CABIN INSIDE THE STABILITY RING",
				"当前目标：驱动并提前制动，让馈源舱稳定停在锁定环内"
			)
		"tune":
			return GameManager.text(
				"OBJECTIVE: PRESERVE THE BROAD CANDIDATE BAND WHILE REDUCING RFI LOAD",
				"当前目标：保留宽缓候选频段，同时降低射频干扰负载"
			)
		"rfi":
			return GameManager.text(
				"OBJECTIVE: REMOVE PATTERNED HUMAN RFI; PRESERVE THE REPEATING SKY CANDIDATE",
				"当前目标：剔除规律性人造干扰，保留重复出现的天体候选"
			)
		"fold":
			return GameManager.text(
				"OBJECTIVE: ALIGN PERIOD AND SUB-BANDS, THEN HOLD INTEGRATION UNTIL SNR IS CREDIBLE",
				"当前目标：对齐周期与子频段，再持续积分，直到信噪比可信"
			)
		_:
			return GameManager.text(
				"OBJECTIVE: SELECT THE CONCLUSION SUPPORTED BY THE RECORDED RADIO EVIDENCE",
				"当前目标：依据已记录的射电证据选择科学结论"
			)


func _challenge_title() -> String:
	match str(profile.get("challenge", "balanced")):
		"cabin_drift": return GameManager.text("Precision feed-cabin control", "馈源舱精密控制")
		"rfi_heavy": return GameManager.text("Severe interference night", "强干扰观测夜")
		"long_integration": return GameManager.text("Long-integration search", "长积分搜索")
		"dm_alignment": return GameManager.text("Dispersion alignment", "色散对齐")
		"weak_window": return GameManager.text("Weak-source frequency search", "微弱源频窗搜索")
		"discovery": return GameManager.text("Independent discovery session", "独立发现观测")
		"period_search": return GameManager.text("Pulse-period measurement", "脉冲周期测量")
		_: return GameManager.text("Commissioning the giant", "巨型设备联调")


func _maybe_play_array_takeover() -> void:
	if _array_takeover_seen_this_session:
		return
	_array_takeover_seen_this_session = true
	await _play_array_takeover()


func _play_array_takeover() -> void:
	if intro_running:
		return
	intro_running = true
	intro_progress = 0.0
	intro_overlay = Panel.new()
	intro_overlay.name = "FastArrayTakeover"
	intro_overlay.position = Vector2(14, 10)
	intro_overlay.size = Vector2(996, 724)
	intro_overlay.z_index = 980
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_overlay.add_theme_stylebox_override("panel", _flat(Color("030910"), BRASS, 2))
	add_child(intro_overlay)

	intro_plot = RadioPlot.new()
	intro_plot.position = Vector2(18, 18)
	intro_plot.size = Vector2(960, 688)
	intro_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_plot.renderer = _draw_array_takeover
	intro_overlay.add_child(intro_plot)

	var skip := _button(GameManager.text("SKIP", "跳过"), Vector2(864, 654), Vector2(84, 28), Color("111d29"))
	skip.z_index = 4
	skip.pressed.connect(_finish_array_takeover)
	intro_overlay.add_child(skip)

	var duration := 2.8 if not InteractionFeedback.is_reduced_motion() else 0.72
	for _step in range(4):
		await get_tree().create_timer(duration / 5.0).timeout
		if not intro_running:
			return
		InteractionFeedback.feedback_sfx_requested.emit("fast_array_relay")
	await get_tree().create_timer(duration / 5.0).timeout
	_finish_array_takeover()


func _finish_array_takeover() -> void:
	if not intro_running:
		return
	intro_running = false
	if intro_overlay != null and is_instance_valid(intro_overlay):
		var overlay := intro_overlay
		intro_overlay = null
		intro_plot = null
		if InteractionFeedback.is_reduced_motion():
			overlay.queue_free()
		else:
			var exit := create_tween().bind_node(overlay)
			exit.tween_property(overlay, "modulate:a", 0.0, 0.18)
			exit.tween_callback(overlay.queue_free)
	InteractionFeedback.feedback_sfx_requested.emit("fast_array_online")


func _draw_array_takeover(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("02070d"), true)
	for i in range(90):
		var x := fposmod(float(i * 83 + 17), plot.size.x)
		var y := fposmod(float(i * 47 + 29), 300.0)
		var alpha := 0.16 + 0.28 * absf(sin(float(i) * 1.71))
		plot.draw_circle(Vector2(x, y), 0.8 + float(i % 3) * 0.35, Color(0.66, 0.78, 0.82, alpha))

	var horizon_y := 344.0
	var mountain_back := PackedVector2Array([
		Vector2(0, horizon_y + 14), Vector2(84, 282), Vector2(174, 320),
		Vector2(286, 252), Vector2(378, 310), Vector2(488, 238),
		Vector2(602, 310), Vector2(710, 266), Vector2(826, 314),
		Vector2(960, 270), Vector2(960, 442), Vector2(0, 442),
	])
	plot.draw_colored_polygon(mountain_back, Color("091620"))
	var mountain_front := PackedVector2Array([
		Vector2(0, 388), Vector2(116, 318), Vector2(230, 362),
		Vector2(348, 300), Vector2(466, 354), Vector2(590, 296),
		Vector2(718, 350), Vector2(846, 304), Vector2(960, 366),
		Vector2(960, 474), Vector2(0, 474),
	])
	plot.draw_colored_polygon(mountain_front, Color("0d1d28"))

	var dish_center := Vector2(480, 386)
	var dish_radius := 300.0
	var reveal := clampf((intro_progress - 0.05) / 0.58, 0.0, 1.0)
	var start_angle := PI * 0.10
	var end_angle := PI * 0.90
	var revealed_end := lerpf(start_angle, end_angle, reveal)
	for ring in range(7):
		var radius := dish_radius - float(ring) * 22.0
		plot.draw_arc(dish_center, radius, start_angle, revealed_end, 96, Color(CRT, 0.18 + ring * 0.025), 1.2, true)
	for spoke in range(19):
		var angle := lerpf(start_angle, end_angle, float(spoke) / 18.0)
		if angle > revealed_end:
			continue
		var outer := dish_center + Vector2(cos(angle), sin(angle)) * dish_radius
		var inner := dish_center + Vector2(cos(angle), sin(angle)) * 152.0
		plot.draw_line(inner, outer, Color(CRT, 0.17), 1.0)

	var cabin_alpha := clampf((intro_progress - 0.25) / 0.30, 0.0, 1.0)
	var cabin := Vector2(480, 268)
	var towers := [Vector2(192, 186), Vector2(768, 186), Vector2(132, 368), Vector2(828, 368)]
	for tower in towers:
		plot.draw_line(tower, cabin, Color(GOLD, cabin_alpha * 0.58), 1.4)
		plot.draw_circle(tower, 5.0, Color(BRASS, cabin_alpha))
	var cabin_shape := PackedVector2Array([
		cabin + Vector2(-20, -8), cabin + Vector2(18, -8),
		cabin + Vector2(24, 5), cabin + Vector2(12, 16),
		cabin + Vector2(-14, 16), cabin + Vector2(-24, 4),
	])
	plot.draw_colored_polygon(cabin_shape, Color(0.12, 0.23, 0.29, cabin_alpha))
	plot.draw_polyline(PackedVector2Array(Array(cabin_shape) + [cabin_shape[0]]), Color(CYAN, cabin_alpha), 2.0, true)

	_draw_plot_text(plot, GameManager.text("FAST ARRAY TAKEOVER", "FAST 阵列接管"), Vector2(34, 42), 24, GOLD)
	_draw_plot_text(plot, GameManager.text("500 m ACTIVE REFLECTOR · GUIZHOU", "500 米主动反射面 · 贵州"), Vector2(36, 68), 12, CRT)
	var status_lines := [
		GameManager.text("ARRAY SURFACE ........ ONLINE", "主动反射面 ........ 在线"),
		GameManager.text("FEED CABIN ........... LINKED", "悬吊馈源舱 ........ 已连接"),
		GameManager.text("RECEIVER CHAIN ....... READY", "接收机链路 ........ 就绪"),
		GameManager.text("TIME STANDARD ........ LOCKED", "时间基准 .......... 已锁定"),
	]
	var terminal_rect := Rect2(Vector2(94, 492), Vector2(772, 130))
	plot.draw_rect(terminal_rect, Color("06131b"), true)
	plot.draw_rect(terminal_rect, Color(BRASS, 0.72), false, 2.0)
	for i in range(status_lines.size()):
		var threshold := 0.36 + float(i) * 0.14
		var color := GREEN if intro_progress >= threshold else Color(MUTED, 0.28)
		_draw_plot_text(plot, str(status_lines[i]), Vector2(126, 524 + i * 24), 13, color)
		if intro_progress >= threshold:
			plot.draw_circle(Vector2(822, 519 + i * 24), 4.0, GREEN)
	var scan_y := lerpf(terminal_rect.position.y, terminal_rect.end.y, fposmod(intro_progress * 4.0, 1.0))
	plot.draw_line(Vector2(terminal_rect.position.x, scan_y), Vector2(terminal_rect.end.x, scan_y), Color(CYAN, 0.12), 1.0)


func _build_stage_bar() -> void:
	stage_bar_holder = Control.new()
	stage_bar_holder.position = Vector2(28, 78)
	stage_bar_holder.size = Vector2(968, 28)
	add_child(stage_bar_holder)
	var labels := [
		GameManager.text("1 AIM", "1 对准"),
		GameManager.text("2 TUNE", "2 调谐"),
		GameManager.text("3 RFI", "3 净化"),
		GameManager.text("4 FOLD", "4 折叠"),
		GameManager.text("5 REPORT", "5 报告"),
	]
	for i in range(labels.size()):
		var done := i < stage
		var active := i == stage
		var chip := Panel.new()
		chip.position = Vector2(i * 194.0, 0)
		chip.size = Vector2(184, 28)
		chip.add_theme_stylebox_override("panel", _flat(
			Color("14253a") if active else Color("0c1825"),
			GREEN if done else (GOLD if active else Color("314154")),
			2
		))
		stage_bar_holder.add_child(chip)
		_label_to(chip, str(labels[i]), Vector2.ZERO, chip.size, 12, GREEN if done else (GOLD if active else MUTED), HORIZONTAL_ALIGNMENT_CENTER)


func _clear_content() -> void:
	if content == null:
		return
	for child in content.get_children():
		child.queue_free()


func _build_stage() -> void:
	_clear_content()
	match STAGE_KEYS[stage]:
		"aim": _build_aim()
		"tune": _build_tune()
		"rfi": _build_rfi()
		"fold": _build_fold()
		"report": _build_report()


func _advance(next_stage: int = stage + 1) -> void:
	stage = clampi(next_stage, 0, STAGE_KEYS.size() - 1)
	_rebuild()


func _back() -> void:
	if stage > 0 and stage < 4:
		stage -= 1
		fold_step = 0
		_rebuild()
		return
	GameManager.set_observatory_spawn("telescope")
	GameManager.go("observatory")


# ---------------------------------------------------------------- 1. AIM
func _build_aim() -> void:
	var display := _panel_to(content, Vector2(32, 6), Vector2(626, 478), PANEL_DEEP, GOLD, GameManager.text("SUSPENDED FEED CABIN", "悬吊馈源舱"))
	scope = RadioPlot.new()
	scope.position = Vector2(18, 42)
	scope.size = Vector2(590, 414)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.renderer = _draw_aim_plot
	display.add_child(scope)

	var drive := _panel_to(content, Vector2(674, 6), Vector2(318, 478), PANEL, GOLD, GameManager.text("CABIN DRIVE", "馈源舱驱动"))
	aim_lamp = Panel.new()
	aim_lamp.position = Vector2(274, 14)
	aim_lamp.size = Vector2(20, 20)
	aim_lamp.add_theme_stylebox_override("panel", _flat(AMBER, Color("302817"), 2))
	drive.add_child(aim_lamp)
	readout = _label_to(drive, "", Vector2(16, 44), Vector2(286, 130), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_meter(drive, GameManager.text("Cable tension", "缆索张力"), Vector2(16, 178), Vector2(286, 12), model.cable_tension, RED if model.tension_warning() else AMBER)
	_meter(drive, GameManager.text("Stability", "稳定度"), Vector2(16, 214), Vector2(286, 12), model.stability(), GREEN)

	var pad_center := Vector2(159, 318)
	_drive_button(drive, "▲", Vector2(pad_center.x - 32, pad_center.y - 74), Vector2(64, 44), Vector2(0, -1))
	_drive_button(drive, "▼", Vector2(pad_center.x - 32, pad_center.y + 30), Vector2(64, 44), Vector2(0, 1))
	_drive_button(drive, "◀", Vector2(pad_center.x - 102, pad_center.y - 22), Vector2(64, 44), Vector2(-1, 0))
	_drive_button(drive, "▶", Vector2(pad_center.x + 38, pad_center.y - 22), Vector2(64, 44), Vector2(1, 0))
	var brake := _button(GameManager.text("BRAKE", "制动"), Vector2(pad_center.x - 42, pad_center.y - 22), Vector2(84, 44), Color("3a2a1d"))
	brake.button_down.connect(func() -> void: drive_braking = true)
	brake.button_up.connect(func() -> void: drive_braking = false)
	drive.add_child(brake)

	lock_button = _button(GameManager.text("ENGAGE CABIN LOCK", "锁定馈源舱"), Vector2(28, 404), Vector2(262, 42), Color("18452f"))
	lock_button.pressed.connect(_try_lock)
	drive.add_child(lock_button)
	_label_to(drive, GameManager.text("WASD / arrows: drive   Space: brake", "WASD / 方向键：驱动   空格：制动"), Vector2(16, 374), Vector2(286, 22), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_refresh_aim()
	if not InteractionFeedback.was_tutorial_seen("first_fast_cabin"):
		InteractionFeedback.tutorial_highlight_once(
			scope,
			"first_fast_cabin",
			GameManager.text(
				"Follow the motion vector. Brake before crossing the stable ring.",
				"跟随运动矢量，在越过稳定环前提前制动。"
			),
			self
		)


func _drive_button(parent: Control, text_value: String, pos: Vector2, size_value: Vector2, vector: Vector2) -> void:
	var button := _button(text_value, pos, size_value, Color("153249"))
	button.add_theme_font_size_override("font_size", 19)
	button.button_down.connect(func() -> void:
		drive_vector = vector
		InteractionFeedback.feedback_sfx_requested.emit("fast_cabin_drive")
	)
	button.button_up.connect(func() -> void:
		if drive_vector == vector:
			drive_vector = Vector2.ZERO
	)
	parent.add_child(button)


func _record_aim_trail() -> void:
	var err := Vector2(
		wrapf(model.azimuth - model.true_azimuth, -180.0, 180.0),
		model.altitude - model.true_altitude
	)
	if aim_trail.is_empty() or aim_trail[-1].distance_to(err) > 0.05:
		aim_trail.append(err)
	while aim_trail.size() > 42:
		aim_trail.pop_front()


func _refresh_aim() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Cabin  AZ %06.2f°  ALT %05.2f°\nTarget AZ %06.2f°  ALT %05.2f°\nError %.2f°   Speed %.2f°/s" % [
			model.azimuth, model.altitude, model.true_azimuth, model.true_altitude,
			model.pointing_error(), model.pointing_speed(),
		],
		"馈源舱  方位 %06.2f°  高度 %05.2f°\n目标    方位 %06.2f°  高度 %05.2f°\n误差 %.2f°   速度 %.2f°/秒" % [
			model.azimuth, model.altitude, model.true_azimuth, model.true_altitude,
			model.pointing_error(), model.pointing_speed(),
		]
	)
	var color := GREEN if model.is_locked() else (AMBER if model.is_on_target() else TEXT)
	readout.add_theme_color_override("font_color", RED if model.tension_warning() else color)
	if aim_lamp != null and is_instance_valid(aim_lamp):
		aim_lamp.add_theme_stylebox_override("panel", _flat(GREEN if model.is_locked() else (AMBER if model.is_on_target() else RED), Color("2d322c"), 2))
	if lock_button != null and is_instance_valid(lock_button):
		lock_button.disabled = running
	scope.queue_redraw()


func _draw_aim_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("06111a"), true)
	_draw_crt_grid(plot, Rect2(Vector2(12, 10), plot.size - Vector2(24, 38)), 42.0, Color(0.20, 0.36, 0.42, 0.20))
	var center := Vector2(plot.size.x * 0.5, plot.size.y * 0.48)
	var scale_factor := 7.0
	var err_az := wrapf(model.azimuth - model.true_azimuth, -180.0, 180.0)
	var err_alt := model.altitude - model.true_altitude
	var marker := center + Vector2(err_az, -err_alt) * scale_factor
	marker.x = clampf(marker.x, 34.0, plot.size.x - 34.0)
	marker.y = clampf(marker.y, 30.0, plot.size.y - 54.0)

	var stability_radius := lerpf(27.0, 15.0, model.stability())
	plot.draw_arc(center, 34.0, 0.0, TAU, 72, Color(CYAN, 0.45), 1.0, true)
	plot.draw_arc(center, stability_radius, 0.0, TAU * clampf(model.stability() + 0.08, 0.08, 1.0), 72, GREEN if model.is_locked() else AMBER, 3.0, true)
	plot.draw_line(center - Vector2(48, 0), center + Vector2(48, 0), Color(CRT, 0.45), 1.0)
	plot.draw_line(center - Vector2(0, 48), center + Vector2(0, 48), Color(CRT, 0.45), 1.0)

	var corners := [
		Vector2(38, 26),
		Vector2(plot.size.x - 38, 26),
		Vector2(38, plot.size.y - 48),
		Vector2(plot.size.x - 38, plot.size.y - 48),
	]
	var tension_color := RED if model.tension_warning() else Color(GOLD, 0.64)
	for corner in corners:
		plot.draw_line(corner, marker, tension_color, 1.2)
		plot.draw_circle(corner, 4.0, BRASS)

	if aim_trail.size() > 1:
		var trail := PackedVector2Array()
		for trail_error in aim_trail:
			var point := center + Vector2(trail_error.x, -trail_error.y) * scale_factor
			point.x = clampf(point.x, 34.0, plot.size.x - 34.0)
			point.y = clampf(point.y, 30.0, plot.size.y - 54.0)
			trail.append(point)
		plot.draw_polyline(trail, Color(CYAN, 0.34), 1.5, true)

	var cabin_shape := PackedVector2Array([
		marker + Vector2(0, -12),
		marker + Vector2(14, -3),
		marker + Vector2(10, 10),
		marker + Vector2(-10, 10),
		marker + Vector2(-14, -3),
	])
	plot.draw_colored_polygon(cabin_shape, Color("203849"))
	plot.draw_polyline(PackedVector2Array(Array(cabin_shape) + [cabin_shape[0]]), GREEN if model.is_locked() else GOLD, 2.0, true)

	var velocity := model.motion_vector() * 12.0
	if velocity.length() > 2.0:
		_draw_arrow(plot, marker, marker + velocity, RED if model.tension_warning() else CYAN)
	var predicted_error := model.predicted_error_vector()
	var predicted := center + Vector2(predicted_error.x, -predicted_error.y) * scale_factor
	predicted.x = clampf(predicted.x, 24.0, plot.size.x - 24.0)
	predicted.y = clampf(predicted.y, 24.0, plot.size.y - 48.0)
	plot.draw_dashed_line(marker, predicted, Color(AMBER, 0.72), 6.0, 1.0)
	plot.draw_arc(predicted, 6.0, 0.0, TAU, 20, AMBER, 1.0)

	var state_text := GameManager.text("LOCKED · CABLE LOAD STABLE", "已锁定 · 缆索载荷稳定") if model.is_locked() else (
		GameManager.text("ON TARGET · BRAKE TO SETTLE", "已对准 · 制动并等待稳定") if model.is_on_target()
		else GameManager.text("DRIVE CABIN INTO THE STABILITY RING", "将馈源舱驶入稳定环")
	)
	if aim_capture_progress > 0.0:
		var capture_radius := lerpf(62.0, 18.0, aim_capture_progress)
		plot.draw_arc(center, capture_radius, -PI * 0.5, -PI * 0.5 + TAU * aim_capture_progress, 64, CYAN, 3.0, true)
		plot.draw_line(
			Vector2(center.x, plot.size.y - 48.0),
			center + Vector2(0, 14),
			Color(GREEN, 0.28 + aim_capture_progress * 0.62),
			2.0 + aim_capture_progress * 3.0
		)
		_draw_plot_text(plot, aim_capture_state, Vector2(18, 22), 11, GREEN)
		state_text = GameManager.text("RECEIVER CAPTURE SEQUENCE", "接收机捕获序列")
	_draw_plot_text(plot, state_text, Vector2(18, plot.size.y - 18), 12, GREEN if model.is_locked() else AMBER)


func _try_lock() -> void:
	if running:
		return
	if model.is_locked():
		running = true
		await _play_cabin_capture_sequence()
		running = false
		_advance(1)
		_radio_operation_chain(
			GameManager.text("Locked the suspended feed cabin", "锁定悬吊馈源舱"),
			GameManager.text("Velocity collapsed and cable tension settled", "运动速度收束，缆索张力稳定"),
			GameManager.text("The receiver can now search the radio band", "接收机现在可以搜索射电频段")
		)
	elif model.is_on_target():
		status_label.text = GameManager.text("The cabin is crossing the target too fast. Brake and let the stable ring close.", "馈源舱掠过目标的速度过快。请制动并等待稳定环闭合。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(lock_button)
	else:
		status_label.text = GameManager.text("Position error remains visible in the cabin plot. Follow the vector toward the central ring.", "馈源舱位置图仍显示明显误差。请沿矢量驶向中央稳定环。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(lock_button)


func _play_cabin_capture_sequence() -> void:
	var states := [
		[
			GameManager.text("SLEW COMPLETE · BRAKE APPLIED", "转向完成 · 制动已施加"),
			GameManager.text("SLEW ................. COMPLETE\nBRAKE COMMAND ........ HOLD", "转向 ................ 完成\n制动指令 ............ 保持"),
		],
		[
			GameManager.text("CABLE LOAD SETTLING", "缆索载荷正在稳定"),
			GameManager.text("OVERSHOOT ............ ARRESTED\nCABLE LOAD ........... SETTLING", "过冲 ................ 已抑制\n缆索载荷 ............ 稳定中"),
		],
		[
			GameManager.text("RECEIVER CAPTURE", "接收机捕获"),
			GameManager.text("STABILITY RING ....... CLOSED\nRECEIVER CAPTURE ..... LOCKED", "稳定环 .............. 闭合\n接收机捕获 .......... 已锁定"),
		],
	]
	InteractionFeedback.feedback_sfx_requested.emit("fast_cabin_brake")
	for i in range(states.size()):
		aim_capture_state = str(states[i][0])
		status_label.text = str(states[i][1])
		status_label.add_theme_color_override("font_color", GREEN if i == states.size() - 1 else AMBER)
		var start := float(i) / float(states.size())
		var finish := float(i + 1) / float(states.size())
		var duration := 0.34 if not InteractionFeedback.is_reduced_motion() else 0.08
		var tween := create_tween().bind_node(self)
		tween.tween_method(func(value: float) -> void:
			aim_capture_progress = value
			if scope != null and is_instance_valid(scope):
				scope.queue_redraw()
		, start, finish, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		if i == 1:
			InteractionFeedback.feedback_sfx_requested.emit("fast_cable_settle")
	aim_capture_progress = 1.0
	InteractionFeedback.feedback_sfx_requested.emit("fast_cabin_lock")
	InteractionFeedback.success(scope, "fast_cabin_lock")
	await get_tree().create_timer(0.34 if not InteractionFeedback.is_reduced_motion() else 0.08).timeout


# ---------------------------------------------------------------- 2. TUNE
func _build_tune() -> void:
	var spectrum_panel := _panel_to(content, Vector2(32, 6), Vector2(960, 352), PANEL_DEEP, GOLD, GameManager.text("LIVE RECEIVER SPECTRUM", "实时接收机频谱"))
	scope = RadioPlot.new()
	scope.position = Vector2(18, 42)
	scope.size = Vector2(924, 292)
	scope.mouse_filter = Control.MOUSE_FILTER_STOP
	scope.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	scope.renderer = _draw_tune_plot
	scope.gui_input.connect(_on_tune_scope_input)
	spectrum_panel.add_child(scope)

	var controls := _panel_to(content, Vector2(32, 374), Vector2(960, 110), PANEL, GOLD, GameManager.text("PASSBAND CONTROLS", "通带控制"))
	readout = _label_to(controls, "", Vector2(18, 38), Vector2(330, 58), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stepper(controls, GameManager.text("CENTER MHz", "中心 MHz"), Vector2(372, 40), 150.0, _adjust_tune_center.bind(-5.0), _adjust_tune_center.bind(5.0))
	_stepper(controls, GameManager.text("WIDTH MHz", "带宽 MHz"), Vector2(552, 40), 150.0, _adjust_tune_width.bind(-5.0), _adjust_tune_width.bind(5.0))
	tune_log_label = _label_to(controls, "", Vector2(718, 38), Vector2(224, 32), 10, CRT, HORIZONTAL_ALIGNMENT_CENTER)
	tune_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var confirm := _button(GameManager.text("STABILIZE WINDOW", "稳定频窗"), Vector2(728, 72), Vector2(204, 30), Color("18452f"))
	confirm.pressed.connect(_confirm_tune)
	controls.add_child(confirm)
	if tune_waterfall.is_empty():
		_capture_waterfall_row(tune_waterfall, false)
	_refresh_tune()


func _adjust_tune_center(delta: float) -> void:
	model.window_center_mhz = clampf(model.window_center_mhz + delta, model.BAND_MIN, model.BAND_MAX)
	InteractionFeedback.feedback_sfx_requested.emit("fast_tune_window")
	_refresh_tune()


func _adjust_tune_width(delta: float) -> void:
	model.window_bandwidth_mhz = clampf(model.window_bandwidth_mhz + delta, 20.0, 180.0)
	InteractionFeedback.feedback_sfx_requested.emit("fast_tune_window")
	_refresh_tune()


func _tune_keyboard(keycode: Key) -> void:
	match keycode:
		KEY_LEFT, KEY_A: _adjust_tune_center(-5.0)
		KEY_RIGHT, KEY_D: _adjust_tune_center(5.0)
		KEY_UP, KEY_W: _adjust_tune_width(5.0)
		KEY_DOWN, KEY_S: _adjust_tune_width(-5.0)
		KEY_ENTER: _confirm_tune()


func _on_tune_scope_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			var rect := _tune_window_rect(scope.size)
			if absf(mouse.position.x - rect.position.x) <= 12.0:
				tune_drag_mode = "left"
			elif absf(mouse.position.x - rect.end.x) <= 12.0:
				tune_drag_mode = "right"
			else:
				tune_drag_mode = "center"
				_set_tune_center_from_x(mouse.position.x)
		else:
			tune_drag_mode = ""
			InteractionFeedback.feedback_sfx_requested.emit("fast_tune_window")
		_refresh_tune()
	elif event is InputEventMouseMotion and tune_drag_mode != "":
		var motion := event as InputEventMouseMotion
		var mhz := _x_to_mhz(motion.position.x, scope.size.x)
		if tune_drag_mode == "center":
			model.window_center_mhz = mhz
		else:
			var other := model.window_center_mhz + model.window_bandwidth_mhz * (0.5 if tune_drag_mode == "left" else -0.5)
			model.window_center_mhz = (mhz + other) * 0.5
			model.window_bandwidth_mhz = clampf(absf(mhz - other), 20.0, 180.0)
		_refresh_tune()


func _set_tune_center_from_x(x: float) -> void:
	model.window_center_mhz = _x_to_mhz(x, scope.size.x)
	_refresh_tune()


func _x_to_mhz(x: float, width: float) -> float:
	return lerpf(model.BAND_MIN, model.BAND_MAX, clampf((x - 30.0) / maxf(width - 60.0, 1.0), 0.0, 1.0))


func _mhz_to_x(mhz: float, width: float) -> float:
	return 30.0 + (width - 60.0) * (mhz - model.BAND_MIN) / (model.BAND_MAX - model.BAND_MIN)


func _tune_window_rect(plot_size: Vector2) -> Rect2:
	var lo := model.window_center_mhz - model.window_bandwidth_mhz * 0.5
	var hi := model.window_center_mhz + model.window_bandwidth_mhz * 0.5
	return Rect2(
		Vector2(_mhz_to_x(lo, plot_size.x), 26),
		Vector2(_mhz_to_x(hi, plot_size.x) - _mhz_to_x(lo, plot_size.x), plot_size.y - 58)
	)


func _refresh_tune() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var quality := model.tuning_quality()
	readout.text = GameManager.text(
		"Window %4.0f ± %2.0f MHz\nSource %3d%%   RFI load %3d%%   Quality %3d%%" % [
			model.window_center_mhz, model.window_bandwidth_mhz * 0.5,
			int(model.window_covers_source() * 100.0), int(model.window_rfi_load() * 100.0), int(quality * 100.0),
		],
		"频窗 %4.0f ± %2.0f MHz\n信号 %3d%%   干扰负载 %3d%%   质量 %3d%%" % [
			model.window_center_mhz, model.window_bandwidth_mhz * 0.5,
			int(model.window_covers_source() * 100.0), int(model.window_rfi_load() * 100.0), int(quality * 100.0),
		]
	)
	readout.add_theme_color_override("font_color", GREEN if quality >= 0.55 else (AMBER if quality >= 0.28 else RED))
	if tune_log_label != null and is_instance_valid(tune_log_label):
		tune_log_label.text = GameManager.text(
			"RECEIVER WINDOW ....... MOVING" if tune_drag_mode != "" else (
				"CANDIDATE BAND ........ PRESERVED" if quality >= 0.55 else "RFI LOAD .............. HIGH"
			),
			"接收频窗 .......... 移动中" if tune_drag_mode != "" else (
				"候选频段 .......... 已保留" if quality >= 0.55 else "干扰负载 .......... 偏高"
			)
		)
	_capture_waterfall_row(tune_waterfall, false)
	scope.queue_redraw()


func _draw_tune_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var spectrum_rect := Rect2(Vector2(30, 18), Vector2(plot.size.x - 60, 142))
	var waterfall_rect := Rect2(Vector2(30, 174), Vector2(plot.size.x - 60, 82))
	_draw_crt_grid(plot, spectrum_rect, 44.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_crt_grid(plot, waterfall_rect, 44.0, Color(0.18, 0.34, 0.38, 0.12))
	var samples := model.spectrum_samples(220)
	var points := PackedVector2Array()
	var rfi_load := model.window_rfi_load()
	var plot_h := spectrum_rect.size.y - 20.0
	for i in range(samples.size()):
		var x := spectrum_rect.position.x + spectrum_rect.size.x * float(i) / float(samples.size() - 1)
		var jitter := sin(float(i) * 1.73) * rfi_load * 2.4
		var y := spectrum_rect.position.y + spectrum_rect.size.y - 6.0 - clampf(float(samples[i]) / 1.4, 0.0, 1.0) * plot_h + jitter
		points.append(Vector2(x, y))
	var trace_color := Color(RED, 0.90) if rfi_load > 0.72 else (Color(AMBER, 0.95) if rfi_load > 0.35 else CRT)
	plot.draw_polyline(points, Color(trace_color, 0.22), 5.0, true)
	plot.draw_polyline(points, trace_color, 1.7, true)

	var window := _tune_window_rect(Vector2(plot.size.x, spectrum_rect.end.y + 32.0))
	window.position.y = spectrum_rect.position.y
	window.size.y = spectrum_rect.size.y
	var quality := model.tuning_quality()
	var window_color := GREEN if quality >= 0.55 else (AMBER if quality >= 0.28 else RED)
	plot.draw_rect(window, Color(window_color, 0.10), true)
	plot.draw_rect(window, window_color, false, 2.0)
	plot.draw_rect(Rect2(window.position - Vector2(3, 0), Vector2(6, window.size.y)), window_color, true)
	plot.draw_rect(Rect2(Vector2(window.end.x - 3, window.position.y), Vector2(6, window.size.y)), window_color, true)
	for mhz in [1000.0, 1100.0, 1200.0, 1300.0, 1400.0, 1500.0]:
		var x := _mhz_to_x(mhz, plot.size.x)
		_draw_plot_text(plot, "%.0f" % mhz, Vector2(x - 16, plot.size.y - 8), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("MHz · live receiver power", "MHz · 实时接收功率"), Vector2(34, 14), 10, MUTED)
	_draw_waterfall(plot, waterfall_rect, tune_waterfall, false)
	_draw_plot_text(plot, GameManager.text("RECEIVER HISTORY", "接收历史"), waterfall_rect.position + Vector2(4, -4), 9, MUTED)
	if rfi_load > 0.55:
		_draw_plot_text(plot, GameManager.text("RFI RAISING NOISE FLOOR", "干扰正在抬高噪声底"), Vector2(plot.size.x - 226, 14), 11, RED)
	elif model.window_covers_source() > 0.75:
		_draw_plot_text(plot, GameManager.text("STABLE CANDIDATE FEATURE", "稳定候选特征"), Vector2(plot.size.x - 220, 14), 11, GREEN)


func _confirm_tune() -> void:
	var quality := model.tuning_quality()
	if quality >= 0.55:
		status_label.text = GameManager.text("Passband stable. The candidate remains while the receiver noise drops.", "通带已经稳定。候选信号保留，接收机噪声下降。")
		status_label.add_theme_color_override("font_color", GREEN)
		InteractionFeedback.feedback_sfx_requested.emit("fast_tune_locked")
		_advance(2)
		_radio_operation_chain(
			GameManager.text("Stabilized the receiver window", "稳定接收机频窗"),
			GameManager.text("The source band stayed inside while strong RFI stayed outside", "信号频段被保留，强干扰留在通带之外"),
			GameManager.text("Individual peaks can now be inspected and cleaned", "现在可以逐个检查并净化频谱峰")
		)
	else:
		status_label.text = GameManager.text(
			"The visual evidence is not stable: recenter the broad source feature or narrow away from the tall RFI peaks.",
			"视觉证据尚不稳定：重新框住宽缓的信号特征，或缩窄频窗避开高耸干扰峰。"
		)
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)


# ---------------------------------------------------------------- 3. RFI
func _build_rfi() -> void:
	var spectrum_panel := _panel_to(content, Vector2(32, 6), Vector2(676, 478), PANEL_DEEP, GOLD, GameManager.text("SPECTRUM CLEANING", "频谱净化"))
	scope = RadioPlot.new()
	scope.position = Vector2(18, 42)
	scope.size = Vector2(640, 414)
	scope.mouse_filter = Control.MOUSE_FILTER_STOP
	scope.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	scope.renderer = _draw_rfi_plot
	scope.gui_input.connect(_on_rfi_scope_input)
	spectrum_panel.add_child(scope)

	var actions := _panel_to(content, Vector2(724, 6), Vector2(268, 478), PANEL, GOLD, GameManager.text("PEAK REVIEW", "频峰审查"))
	readout = _label_to(actions, GameManager.text("Select a peak in the spectrum.", "请在频谱中选择一个峰。"), Vector2(14, 44), Vector2(240, 116), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var keep := _button(GameManager.text("KEEP CANDIDATE  [K]", "保留候选  [K]"), Vector2(18, 176), Vector2(232, 42), Color("153e34"))
	keep.pressed.connect(_classify_selected.bind(false))
	actions.add_child(keep)
	var reject := _button(GameManager.text("MARK INTERFERENCE [X]", "标记干扰  [X]"), Vector2(18, 230), Vector2(232, 42), Color("42271e"))
	reject.pressed.connect(_classify_selected.bind(true))
	actions.add_child(reject)
	rfi_evidence_label = _label_to(actions, "", Vector2(18, 288), Vector2(232, 74), 11, AMBER)
	rfi_evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var confirm := _button(GameManager.text("VERIFY CLEAN SPECTRUM", "验证净化频谱"), Vector2(18, 402), Vector2(232, 44), Color("18452f"))
	confirm.pressed.connect(_confirm_rfi)
	actions.add_child(confirm)
	_label_to(actions, GameManager.text("←/→ select · K keep · X reject", "←/→ 选择 · K 保留 · X 剔除"), Vector2(12, 372), Vector2(244, 20), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if rfi_waterfall.is_empty():
		_capture_waterfall_row(rfi_waterfall, true)
	_refresh_rfi()


func _rfi_keyboard(keycode: Key) -> void:
	match keycode:
		KEY_LEFT, KEY_A:
			selected_peak = wrapi(selected_peak - 1, 0, model.rfi_peaks.size())
			_refresh_rfi()
		KEY_RIGHT, KEY_D:
			selected_peak = wrapi(selected_peak + 1, 0, model.rfi_peaks.size())
			_refresh_rfi()
		KEY_K: _classify_selected(false)
		KEY_X: _classify_selected(true)
		KEY_ENTER: _confirm_rfi()


func _on_rfi_scope_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var nearest := -1
	var distance := 9999.0
	for i in range(model.rfi_peaks.size()):
		var x := _mhz_to_x(float(model.rfi_peaks[i]["mhz"]), scope.size.x)
		var current := absf(mouse.position.x - x)
		if current < distance:
			distance = current
			nearest = i
	if nearest >= 0 and distance <= 34.0:
		selected_peak = nearest
		InteractionFeedback.selection(scope, true, CYAN, false, "fast_peak_selected")
		_refresh_rfi()


func _classify_selected(as_rfi: bool) -> void:
	if selected_peak < 0 or selected_peak >= model.rfi_peaks.size():
		status_label.text = GameManager.text("Select a visible peak before issuing a keep or reject command.", "请先选择可见频谱峰，再执行保留或剔除。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(scope)
		return
	model.classify(selected_peak, as_rfi)
	InteractionFeedback.feedback_sfx_requested.emit("fast_rfi_mark")
	_refresh_rfi()
	var evidence := model.classification_evidence()
	if evidence == "source_deleted":
		status_label.text = GameManager.text("The broad repeating candidate collapsed: you rejected the celestial source.", "宽缓的重复候选信号消失了：你误删了天体源。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
	elif evidence == "residual_rfi":
		status_label.text = GameManager.text("A tall or patterned contaminant still survives in the cleaned trace.", "净化轨迹中仍有高耸或带规律的污染峰。")
		status_label.add_theme_color_override("font_color", AMBER)
	else:
		status_label.text = GameManager.text("The cleaned trace is becoming quieter. Continue reviewing the remaining peaks.", "净化后的轨迹正在安静下来。继续检查其余频谱峰。")
		status_label.add_theme_color_override("font_color", GREEN)


func _refresh_rfi() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	if selected_peak >= 0 and selected_peak < model.rfi_peaks.size():
		var peak: Dictionary = model.rfi_peaks[selected_peak]
		var pattern := _pattern_text(str(peak.get("pattern", "fixed_narrow")))
		readout.text = GameManager.text(
			"Peak %d / %d\n%.1f MHz   Strength %.2f\nShape: %s\nCommand: keep the sky candidate or reject interference." % [
				selected_peak + 1, model.rfi_peaks.size(), float(peak["mhz"]), float(peak["strength"]), pattern,
			],
			"频峰 %d / %d\n%.1f MHz   强度 %.2f\n形态：%s\n操作：保留天体候选，或剔除人造干扰。" % [
				selected_peak + 1, model.rfi_peaks.size(), float(peak["mhz"]), float(peak["strength"]), pattern,
			]
		)
	else:
		readout.text = GameManager.text("Select a peak. Its shape and persistence are evidence.", "选择一个频谱峰。它的形态和持续性就是证据。")
	var evidence := model.classification_evidence()
	if rfi_evidence_label != null and is_instance_valid(rfi_evidence_label):
		match evidence:
			"source_deleted":
				rfi_evidence_label.text = GameManager.text("EVIDENCE: candidate band missing. Restore the celestial peak.", "证据：候选频段已消失。请恢复天体频峰。")
				rfi_evidence_label.add_theme_color_override("font_color", RED)
			"residual_rfi":
				rfi_evidence_label.text = GameManager.text("EVIDENCE: residual patterned peaks remain in the cleaned trace.", "证据：净化轨迹中仍残留规律性干扰峰。")
				rfi_evidence_label.add_theme_color_override("font_color", AMBER)
			"clean":
				rfi_evidence_label.text = GameManager.text("EVIDENCE: noise floor is quiet and the broad pulse candidate remains.", "证据：噪声底已安静，宽缓脉冲候选仍然存在。")
				rfi_evidence_label.add_theme_color_override("font_color", GREEN)
			_:
				rfi_evidence_label.text = GameManager.text("Review every visible feature before verification.", "验证前请检查每个可见特征。")
				rfi_evidence_label.add_theme_color_override("font_color", MUTED)
	_capture_waterfall_row(rfi_waterfall, true)
	scope.queue_redraw()


func _pattern_text(pattern: String) -> String:
	match pattern:
		"pulse_train": return GameManager.text("broad, repeating candidate", "宽缓、重复的候选信号")
		"periodic": return GameManager.text("regular mechanical cadence", "规则机械周期")
		"burst": return GameManager.text("short impulsive bursts", "短促突发")
		"comb": return GameManager.text("equally spaced comb", "等间距梳状谱")
		"swept": return GameManager.text("frequency-swept trace", "扫频轨迹")
		_: return GameManager.text("narrow fixed carrier", "窄带固定载波")


func _draw_rfi_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var spectrum_rect := Rect2(Vector2(30, 16), Vector2(plot.size.x - 60, 220))
	var waterfall_rect := Rect2(Vector2(30, 252), Vector2(plot.size.x - 60, 112))
	_draw_crt_grid(plot, spectrum_rect, 40.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_crt_grid(plot, waterfall_rect, 40.0, Color(0.18, 0.34, 0.38, 0.12))
	var samples := model.spectrum_samples(180, true)
	var points := PackedVector2Array()
	var plot_h := spectrum_rect.size.y - 26.0
	for i in range(samples.size()):
		var x := spectrum_rect.position.x + spectrum_rect.size.x * float(i) / float(samples.size() - 1)
		var y := spectrum_rect.position.y + spectrum_rect.size.y - 6.0 - clampf(float(samples[i]) / 1.4, 0.0, 1.0) * plot_h
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(CRT, 0.22), 5.0, true)
	plot.draw_polyline(points, CRT, 1.7, true)

	for i in range(model.rfi_peaks.size()):
		var peak: Dictionary = model.rfi_peaks[i]
		var x := _mhz_to_x(float(peak["mhz"]), plot.size.x)
		var y := spectrum_rect.position.y + 24.0 + plot_h * (1.0 - clampf(float(peak["strength"]) / 1.2, 0.0, 1.0))
		var mark := str(model.classifications.get(i, ""))
		var color := CYAN if i == selected_peak else GOLD
		if mark == "rfi":
			color = RED
			plot.draw_line(Vector2(x - 10, y - 10), Vector2(x + 10, y + 10), Color(RED, 0.78), 2.0)
			plot.draw_line(Vector2(x + 10, y - 10), Vector2(x - 10, y + 10), Color(RED, 0.78), 2.0)
		elif mark == "source":
			color = GREEN
			plot.draw_arc(Vector2(x, y), 12.0, 0.0, TAU, 24, GREEN, 2.0)
		_draw_peak_signature(plot, Vector2(x, y), str(peak.get("pattern", "fixed_narrow")), color)
		if i == selected_peak:
			plot.draw_rect(Rect2(Vector2(x - 21, y - 26), Vector2(42, 48)), CYAN, false, 2.0)
			_draw_plot_text(plot, "%.0f MHz" % float(peak["mhz"]), Vector2(x - 28, y - 31), 10, CYAN)

	_draw_waterfall(plot, waterfall_rect, rfi_waterfall, true)
	var clean_ratio := float(model.correctly_rejected_rfi_count()) / float(maxi(1, model.rfi_peaks.size() - 1))
	_meter_draw(plot, Rect2(Vector2(34, plot.size.y - 22), Vector2(plot.size.x - 68, 8)), clean_ratio, GREEN)
	_draw_plot_text(plot, GameManager.text("CLEANING HISTORY", "净化历史"), waterfall_rect.position + Vector2(4, -4), 9, MUTED)


func _draw_peak_signature(plot: RadioPlot, pos: Vector2, pattern: String, color: Color) -> void:
	match pattern:
		"pulse_train":
			plot.draw_arc(pos, 8.0, 0.0, TAU, 24, color, 2.0)
			for offset in [-16.0, 16.0]:
				plot.draw_arc(pos + Vector2(offset, 0), 4.0, 0.0, TAU, 16, Color(color, 0.65), 1.0)
		"periodic":
			for offset in [-9.0, 0.0, 9.0]:
				plot.draw_line(pos + Vector2(offset, 8), pos + Vector2(offset, -8), color, 1.5)
		"burst":
			plot.draw_polyline(PackedVector2Array([
				pos + Vector2(-12, 5), pos + Vector2(-5, 4), pos + Vector2(-2, -10),
				pos + Vector2(2, 8), pos + Vector2(5, -4), pos + Vector2(12, 4),
			]), color, 2.0, true)
		"comb":
			for offset in [-12.0, -6.0, 0.0, 6.0, 12.0]:
				plot.draw_line(pos + Vector2(offset, 7), pos + Vector2(offset, -7 + absf(offset) * 0.25), color, 1.2)
		"swept":
			plot.draw_line(pos + Vector2(-13, 8), pos + Vector2(13, -8), color, 2.0)
		_:
			plot.draw_line(pos + Vector2(0, 10), pos + Vector2(0, -12), color, 2.0)


func _confirm_rfi() -> void:
	if not model.all_classified():
		status_label.text = GameManager.text("Unreviewed peaks remain. Select each visible feature before verification.", "仍有频谱峰尚未审查。验证前请逐个选择可见特征。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(scope)
		return
	if model.source_deleted():
		status_label.text = GameManager.text("Verification failed: the celestial candidate was removed. Restore it and review the shape.", "验证失败：天体候选被误删。请根据形态恢复它。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		return
	if model.residual_rfi_count() > 0 or model.classification_score() < model.rfi_threshold:
		status_label.text = GameManager.text("Verification found residual interference. The surviving patterned peak is the evidence.", "验证发现残余干扰。仍然存在的规律性频峰就是证据。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		return
	status_label.text = GameManager.text("Spectrum verified clean. The preserved candidate can now be folded in time.", "频谱净化验证通过。保留的候选信号现在可以进行时间折叠。")
	status_label.add_theme_color_override("font_color", GREEN)
	InteractionFeedback.feedback_sfx_requested.emit("fast_rfi_clean")
	_advance(3)
	_radio_operation_chain(
		GameManager.text("Removed man-made radio interference", "剔除人造射频干扰"),
		GameManager.text("Patterned contaminants vanished while the celestial band remained", "规律污染峰消失，天体频段被保留"),
		GameManager.text("The remaining time series can reveal a repeating period", "剩余时间序列可以寻找重复周期")
	)


# ---------------------------------------------------------------- 4. FOLD
func _build_fold() -> void:
	var signal_panel := _panel_to(content, Vector2(32, 6), Vector2(646, 478), PANEL_DEEP, GOLD, GameManager.text("PULSE RECOVERY", "脉冲恢复"))
	scope = RadioPlot.new()
	scope.position = Vector2(16, 42)
	scope.size = Vector2(614, 414)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.renderer = _draw_fold_plot
	signal_panel.add_child(scope)
	_build_fold_controls_panel()


func _build_fold_controls_panel() -> void:
	if fold_controls_panel != null and is_instance_valid(fold_controls_panel):
		fold_controls_panel.queue_free()
	fold_controls_panel = _panel_to(content, Vector2(694, 6), Vector2(298, 478), PANEL, GOLD, GameManager.text("FOLDING CONSOLE", "折叠控制台"))
	fold_step_label = _label_to(fold_controls_panel, "", Vector2(14, 42), Vector2(270, 28), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	readout = _label_to(fold_controls_panel, "", Vector2(14, 76), Vector2(270, 112), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_fold_control(fold_controls_panel)
	_refresh_fold()


func _build_fold_control(parent: Control) -> void:
	if fold_step <= 1:
		fold_slider = HSlider.new()
		fold_slider.position = Vector2(18, 218)
		fold_slider.size = Vector2(262, 28)
		if fold_step == 0:
			fold_slider.min_value = model.true_period_ms - 80.0
			fold_slider.max_value = model.true_period_ms + 80.0
			fold_slider.step = 0.25
			fold_slider.value = model.trial_period_ms
			fold_slider.value_changed.connect(func(value: float) -> void:
				model.trial_period_ms = value
				_refresh_fold()
			)
		else:
			fold_slider.min_value = 0.0
			fold_slider.max_value = maxf(model.true_dm + 28.0, 40.0)
			fold_slider.step = 0.2
			fold_slider.value = model.trial_dm
			fold_slider.value_changed.connect(func(value: float) -> void:
				model.trial_dm = value
				_refresh_fold()
			)
		parent.add_child(fold_slider)
		fold_action_button = _button(
			GameManager.text("LOCK TRIAL PERIOD", "锁定试验周期") if fold_step == 0 else GameManager.text("APPLY DM CORRECTION", "应用 DM 校正"),
			Vector2(18, 278), Vector2(262, 44), Color("18452f")
		)
		fold_action_button.pressed.connect(_confirm_fold_step)
		parent.add_child(fold_action_button)
	else:
		fold_action_button = _button(GameManager.text("HOLD TO INTEGRATE [SPACE]", "按住积分 [空格]"), Vector2(18, 218), Vector2(262, 54), Color("153249"))
		fold_action_button.button_down.connect(func() -> void: integration_held = true)
		fold_action_button.button_up.connect(func() -> void: integration_held = false)
		parent.add_child(fold_action_button)
		var confirm := _button(GameManager.text("CONFIRM DISCOVERY", "确认发现"), Vector2(18, 292), Vector2(262, 48), Color("18452f"))
		confirm.pressed.connect(_confirm_fold)
		parent.add_child(confirm)
	_label_to(parent, GameManager.text("←/→ fine adjust · Enter: apply", "←/→ 微调 · 回车：应用"), Vector2(12, 356), Vector2(274, 20), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(parent, _challenge_hint(), Vector2(18, 382), Vector2(262, 58), 11, CRT, HORIZONTAL_ALIGNMENT_CENTER).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _challenge_hint() -> String:
	match str(profile.get("challenge", "balanced")):
		"long_integration":
			return GameManager.text("Weak source: hold integration.\nSNR rises with the square root of time.", "微弱源：持续积分。\n信噪比随时间平方根增长。")
		"dm_alignment":
			return GameManager.text("Watch the sub-bands.\nCorrect DM aligns every arrival.", "观察子频段。\n正确 DM 会对齐所有脉冲。")
		"period_search":
			return GameManager.text("A wrong period splits the peak.\nConverge the two profiles.", "错误周期会分裂峰形。\n让两个轮廓逐渐重合。")
		_:
			return GameManager.text("Search period, align dispersion,\nthen integrate for certainty.", "搜索周期并校正色散，\n再通过积分确认信号。")


func _fold_keyboard(keycode: Key) -> void:
	var direction := -1.0 if keycode in [KEY_LEFT, KEY_A] else (1.0 if keycode in [KEY_RIGHT, KEY_D] else 0.0)
	if direction != 0.0 and fold_step <= 1:
		if fold_step == 0:
			model.trial_period_ms = clampf(model.trial_period_ms + direction * 0.5, model.true_period_ms - 80.0, model.true_period_ms + 80.0)
		else:
			model.trial_dm = clampf(model.trial_dm + direction * 0.25, 0.0, maxf(model.true_dm + 28.0, 40.0))
		if fold_slider != null:
			fold_slider.value = model.trial_period_ms if fold_step == 0 else model.trial_dm
		_refresh_fold()
	elif keycode == KEY_ENTER:
		if fold_step <= 1:
			_confirm_fold_step()
		else:
			_confirm_fold()


func _confirm_fold_step() -> void:
	if fold_step == 0:
		if model.period_match() < 0.45:
			status_label.text = GameManager.text("The folded profile is still split. Move the trial period until the two peaks converge.", "折叠轮廓仍然分裂。继续调整试验周期，直到两个峰汇合。")
			status_label.add_theme_color_override("font_color", RED)
			InteractionFeedback.error(fold_slider)
			return
		fold_step = 1
		status_label.text = GameManager.text("Coarse period found. Now align arrival time across the receiver sub-bands.", "已找到粗略周期。现在校正各接收子频段的到达时间。")
	else:
		if model.dm_match() < 0.48:
			status_label.text = GameManager.text("Sub-band pulses are still staggered. Adjust DM until the rows align vertically.", "子频段脉冲仍然错开。继续调整 DM，直到各行垂直对齐。")
			status_label.add_theme_color_override("font_color", RED)
			InteractionFeedback.error(fold_slider)
			return
		fold_step = 2
		status_label.text = GameManager.text("Dispersion aligned. Hold integration until the pulse rises above the noise.", "色散已经对齐。按住积分，直到脉冲高出噪声。")
	InteractionFeedback.feedback_sfx_requested.emit("fast_fold_step")
	_build_fold_controls_panel()
	if scope != null and is_instance_valid(scope):
		scope.queue_redraw()


func _refresh_fold() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	if fold_step_label != null and is_instance_valid(fold_step_label):
		fold_step_label.text = [
			GameManager.text("A · SEARCH PERIOD", "A · 搜索周期"),
			GameManager.text("B · CORRECT DISPERSION", "B · 校正色散"),
			GameManager.text("C · INTEGRATE SIGNAL", "C · 积分信号"),
		][fold_step]
	var snr := model.fold_snr()
	if fold_step == 0:
		readout.text = GameManager.text(
			"Trial %.2f ms\nPeriod coherence %d%%\nSplit peaks mean the period is wrong." % [model.trial_period_ms, int(model.period_match() * 100.0)],
			"试验周期 %.2f ms\n周期相干度 %d%%\n双峰分裂表示周期仍然错误。" % [model.trial_period_ms, int(model.period_match() * 100.0)]
		)
	elif fold_step == 1:
		readout.text = GameManager.text(
			"Trial DM %.1f pc/cm³\nSub-band alignment %d%%\nTilted rows reveal dispersion error." % [model.trial_dm, int(model.dm_match() * 100.0)],
			"试验 DM %.1f pc/cm³\n子频段对齐 %d%%\n倾斜行列显示色散误差。" % [model.trial_dm, int(model.dm_match() * 100.0)]
		)
	else:
		readout.text = GameManager.text(
			"Integration %.0f / %.0f s\nSNR %.1f / %.1f\nNoise falls slowly; the pulse repeats." % [model.integration_s, model.required_integration_s, snr, model.report_snr_threshold],
			"积分 %.0f / %.0f 秒\n信噪比 %.1f / %.1f\n噪声缓慢退去，脉冲持续重复。" % [model.integration_s, model.required_integration_s, snr, model.report_snr_threshold]
		)
	readout.add_theme_color_override("font_color", GREEN if snr >= model.report_snr_threshold else (AMBER if maxf(model.period_match(), model.dm_match()) > 0.55 else RED))
	if scope != null and is_instance_valid(scope):
		scope.queue_redraw()


func _draw_fold_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var waterfall_rect := Rect2(Vector2(28, 22), Vector2(plot.size.x - 56, 210))
	var profile_rect := Rect2(Vector2(28, 270), Vector2(plot.size.x - 56, 112))
	_draw_crt_grid(plot, waterfall_rect, 38.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_crt_grid(plot, profile_rect, 38.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_plot_text(plot, GameManager.text("SUB-BAND ARRIVAL / DISPERSION", "子频段到达时间 / 色散"), Vector2(28, 16), 10, MUTED)
	_draw_plot_text(plot, GameManager.text("FOLDED PULSE PROFILE", "折叠脉冲轮廓"), Vector2(28, 264), 10, MUTED)

	var offsets := model.subband_offsets(7)
	var period_split := (1.0 - model.period_match()) * 0.18
	for row in range(offsets.size()):
		var y := waterfall_rect.position.y + 20.0 + row * 26.0
		plot.draw_line(Vector2(waterfall_rect.position.x, y), Vector2(waterfall_rect.end.x, y), Color(CRT, 0.12), 1.0)
		var center_x := waterfall_rect.position.x + waterfall_rect.size.x * (0.5 + float(offsets[row]))
		var row_color := Color(CYAN, lerpf(0.32, 0.92, model.dm_match()))
		_draw_gaussian_trace(plot, Vector2(center_x - period_split * waterfall_rect.size.x, y), 14.0 + (1.0 - model.dm_match()) * 24.0, row_color)
		if period_split > 0.02:
			_draw_gaussian_trace(plot, Vector2(center_x + period_split * waterfall_rect.size.x, y), 13.0, Color(AMBER, 0.68))
		_draw_plot_text(plot, "B%d" % (row + 1), Vector2(waterfall_rect.position.x - 24, y + 4), 9, MUTED)

	var profile := model.folded_profile(120)
	var points := PackedVector2Array()
	var max_amp := 1.25
	for i in range(profile.size()):
		var x := profile_rect.position.x + profile_rect.size.x * float(i) / float(profile.size() - 1)
		var deterministic_noise := sin(float(i) * 2.17 + model.integration_s * 0.02) * (1.0 - clampf(model.integration_s / maxf(model.required_integration_s, 1.0), 0.0, 1.0)) * 0.06
		var y := profile_rect.end.y - clampf((float(profile[i]) + deterministic_noise) / max_amp, 0.0, 1.0) * (profile_rect.size.y - 10.0)
		points.append(Vector2(x, y))
	var line_color := GREEN if bool(model.report().get("success", false)) else (CYAN if model.period_match() > 0.45 else AMBER)
	plot.draw_polyline(points, Color(line_color, 0.22), 5.0, true)
	plot.draw_polyline(points, line_color, 1.8, true)
	_meter_draw(plot, Rect2(Vector2(profile_rect.position.x, plot.size.y - 14), Vector2(profile_rect.size.x, 8)), clampf(model.fold_snr() / maxf(model.report_snr_threshold, 0.1), 0.0, 1.0), GREEN)
	_draw_plot_text(plot, "SNR %.1f" % model.fold_snr(), Vector2(profile_rect.end.x - 70, plot.size.y - 20), 10, GREEN if model.fold_snr() >= model.report_snr_threshold else AMBER)


func _draw_gaussian_trace(plot: RadioPlot, center: Vector2, width: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var x := center.x - width * 1.8 + width * 3.6 * float(i) / 24.0
		var d := (x - center.x) / maxf(width, 1.0)
		var y := center.y - exp(-d * d) * 13.0
		points.append(Vector2(x, y))
	plot.draw_polyline(points, color, 1.6, true)


func _confirm_fold() -> void:
	if discovery_running:
		return
	var rep := model.report()
	if not bool(rep.get("success", false)):
		var reason := model.conclusion_state()
		match reason:
			"residual_rfi":
				status_label.text = GameManager.text("Residual RFI still contaminates the fold. Return to the cleaning stage.", "残余干扰仍在污染折叠结果。请返回净化阶段。")
			"insufficient_signal":
				status_label.text = GameManager.text("The pulse shape is aligned but not yet significant. Continue integrating.", "脉冲形态已经对齐，但显著性仍不足。请继续积分。")
			_:
				status_label.text = GameManager.text("The pulse is still split or dispersed. Recheck period and DM.", "脉冲仍然分裂或色散。请重新检查周期与 DM。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		return
	await _play_discovery_moment()
	_advance(4)
	_radio_operation_chain(
		GameManager.text("Matched period, DM, and integration", "匹配周期、DM 与积分"),
		GameManager.text("Sub-band arrivals aligned and random noise averaged down", "子频段到达时间对齐，随机噪声被平均压低"),
		GameManager.text("A repeating cosmic radio pulse emerged from the noise", "重复宇宙射电脉冲从噪声中显现")
	)


func _play_discovery_moment() -> void:
	discovery_running = true
	integration_held = false
	discovery_phase = 0.0
	var overlay := Panel.new()
	overlay.name = "FastDiscoveryMoment"
	overlay.position = Vector2(70, 112)
	overlay.size = Vector2(884, 492)
	overlay.z_index = 950
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_theme_stylebox_override("panel", _flat(Color("061119"), GOLD, 3))
	add_child(overlay)
	var title := _label_to(overlay, GameManager.text("FIRST PULSE", "首次脉冲确认"), Vector2(24, 18), Vector2(836, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	discovery_plot = RadioPlot.new()
	discovery_plot.position = Vector2(28, 62)
	discovery_plot.size = Vector2(828, 292)
	discovery_plot.renderer = _draw_discovery_plot
	overlay.add_child(discovery_plot)
	var printout := _label_to(overlay, "", Vector2(48, 370), Vector2(788, 96), 13, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	printout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	InteractionFeedback.feedback_sfx_requested.emit("fast_discovery")
	if not InteractionFeedback.is_reduced_motion():
		overlay.modulate.a = 0.0
		overlay.scale = Vector2(1.02, 0.98)
		overlay.pivot_offset = overlay.size * 0.5
		var enter := create_tween().bind_node(overlay).set_parallel(true)
		enter.tween_property(overlay, "modulate:a", 1.0, 0.18)
		enter.tween_property(overlay, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var pulse := create_tween().bind_node(title)
		pulse.tween_property(title, "modulate", GREEN, 0.28)
		pulse.tween_property(title, "modulate", GOLD, 0.38)
	var sequence := [
		GameManager.text("PERIODICITY DETECTED", "检测到稳定周期"),
		GameManager.text("DISPERSION SOLUTION STABLE", "色散解稳定"),
		GameManager.text("PULSE PROFILE ........ CONFIRMED", "脉冲轮廓 ............ 已确认"),
		GameManager.text("CANDIDATE ............ PSR %s", "候选体 .............. PSR %s") % str(model.target_id).to_upper(),
	]
	for i in range(sequence.size()):
		if not is_instance_valid(printout) or not is_inside_tree():
			discovery_running = false
			discovery_plot = null
			return
		printout.text += ("" if printout.text == "" else "\n") + str(sequence[i])
		var target_phase := float(i + 1) / float(sequence.size())
		var tween := create_tween().bind_node(self)
		tween.tween_method(func(value: float) -> void:
			discovery_phase = value
			if discovery_plot != null and is_instance_valid(discovery_plot):
				discovery_plot.queue_redraw()
		, discovery_phase, target_phase, 0.40 if not InteractionFeedback.is_reduced_motion() else 0.10)
		await tween.finished
	await get_tree().create_timer(0.55 if not InteractionFeedback.is_reduced_motion() else 0.16).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()
	discovery_plot = null
	discovery_running = false


func _draw_discovery_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("041018"), true)
	var subband_rect := Rect2(Vector2(12, 14), Vector2(258, 248))
	var waterfall_rect := Rect2(Vector2(285, 14), Vector2(246, 248))
	var profile_rect := Rect2(Vector2(546, 14), Vector2(270, 248))
	for rect in [subband_rect, waterfall_rect, profile_rect]:
		_draw_crt_grid(plot, rect, 28.0, Color(0.20, 0.40, 0.42, 0.16))
		plot.draw_rect(rect, Color(BRASS, 0.55), false, 1.0)

	_draw_plot_text(plot, GameManager.text("SUB-BANDS", "子频段"), subband_rect.position + Vector2(8, 14), 10, MUTED)
	var offsets := model.subband_offsets(7)
	for row in range(offsets.size()):
		var y := subband_rect.position.y + 42.0 + row * 27.0
		var correction := lerpf(float(offsets[row]), 0.0, discovery_phase)
		var x := subband_rect.position.x + subband_rect.size.x * (0.50 + correction)
		plot.draw_line(Vector2(subband_rect.position.x + 12, y), Vector2(subband_rect.end.x - 12, y), Color(CRT, 0.10), 1.0)
		_draw_gaussian_trace(plot, Vector2(x, y), lerpf(19.0, 9.0, discovery_phase), Color(CYAN, 0.38 + discovery_phase * 0.56))

	_draw_plot_text(plot, GameManager.text("CLEAN WATERFALL", "净化瀑布图"), waterfall_rect.position + Vector2(8, 14), 10, MUTED)
	for row in range(26):
		var y := waterfall_rect.position.y + 34.0 + row * 7.6
		var phase_x := waterfall_rect.position.x + waterfall_rect.size.x * (0.50 + sin(float(row) * 0.77) * (1.0 - discovery_phase) * 0.16)
		var alpha := 0.12 + discovery_phase * 0.48
		plot.draw_line(Vector2(waterfall_rect.position.x + 8, y), Vector2(waterfall_rect.end.x - 8, y), Color(CRT, 0.04), 1.0)
		plot.draw_rect(Rect2(Vector2(phase_x - 3, y - 2), Vector2(6, 4)), Color(CYAN, alpha), true)
		if row % 5 == 0:
			plot.draw_rect(Rect2(Vector2(phase_x - 10, y - 1), Vector2(20, 2)), Color(GREEN, alpha * 0.62), true)

	_draw_plot_text(plot, GameManager.text("FOLDED PROFILE", "折叠轮廓"), profile_rect.position + Vector2(8, 14), 10, MUTED)
	var values := model.folded_profile(120)
	var points := PackedVector2Array()
	for i in range(values.size()):
		var x := profile_rect.position.x + 10.0 + (profile_rect.size.x - 20.0) * float(i) / float(values.size() - 1)
		var noise := sin(float(i) * 2.91) * (1.0 - discovery_phase) * 0.12
		var y := profile_rect.end.y - 18.0 - clampf(float(values[i]) + noise, 0.0, 1.2) * 148.0
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(GREEN, 0.14 + discovery_phase * 0.18), 7.0, true)
	plot.draw_polyline(points, Color(GREEN, 0.42 + discovery_phase * 0.58), 2.2, true)
	_draw_plot_text(
		plot,
		"%.3f ms · DM %.2f · SNR %.1f" % [model.trial_period_ms, model.trial_dm, model.fold_snr()],
		profile_rect.position + Vector2(12, 32),
		10,
		GREEN
	)


# ---------------------------------------------------------------- 5. REPORT
func _build_report() -> void:
	var rep := model.report()
	var report_panel := _panel_to(content, Vector2(32, 6), Vector2(960, 478), PANEL, GOLD, GameManager.text("RADIO OBSERVATION REPORT", "射电观测报告"))
	_label_to(report_panel, GameManager.text("FAST DATA PRODUCT", "FAST 观测成果"), Vector2(26, 42), Vector2(410, 26), 14, GOLD)
	var product_plot := RadioPlot.new()
	product_plot.position = Vector2(26, 72)
	product_plot.size = Vector2(410, 238)
	product_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	product_plot.renderer = _draw_report_product
	report_panel.add_child(product_plot)
	var rows := [
		[GameManager.text("Period", "周期"), "%.3f ms" % float(rep["trial_period_ms"])],
		["DM", "%.2f pc/cm³" % float(rep["trial_dm"])],
		["SNR", "%.1f" % float(rep["snr"])],
		[GameManager.text("Integration", "积分"), "%.0f s" % float(rep["integration_s"])],
		[GameManager.text("RFI removed", "剔除干扰"), "%d" % int(rep["rfi_cleared"])],
		[GameManager.text("Residual", "残余"), "%d" % int(rep["rfi_residual"])],
	]
	for i in range(rows.size()):
		var col := i % 3
		var row_index := i / 3
		var x := 28.0 + float(col) * 136.0
		var y := 318.0 + float(row_index) * 38.0
		_label_to(report_panel, str(rows[i][0]), Vector2(x, y), Vector2(128, 16), 9, MUTED)
		_label_to(report_panel, str(rows[i][1]), Vector2(x, y + 14), Vector2(128, 20), 12, TEXT)
	var science_text := GameManager.text(
		_wrap_words(str(rep.get("result_en", "")), 60),
		_wrap_characters(str(rep.get("result_zh", "")), 30)
	)
	var science := _label_to(report_panel, science_text, Vector2(28, 398), Vector2(408, 56), 11, CRT)
	science.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	science.clip_text = true

	var divider := ColorRect.new()
	divider.position = Vector2(454, 50)
	divider.size = Vector2(1, 376)
	divider.color = Color(BRASS, 0.65)
	report_panel.add_child(divider)
	_label_to(report_panel, GameManager.text("CONCLUSION FROM THE EVIDENCE", "根据证据得出结论"), Vector2(480, 44), Vector2(446, 28), 14, GOLD)
	var choices := [
		["stable_pulsar", GameManager.text("Stable pulsar candidate", "稳定脉冲星候选"), GameManager.text("Period repeats, DM aligns, SNR is significant.", "周期重复、DM 对齐且信噪比显著。")],
		["residual_rfi", GameManager.text("Residual interference dominates", "残余干扰占主导"), GameManager.text("Patterned contamination remains in the spectrum.", "频谱中仍存在规律性污染。")],
		["insufficient_signal", GameManager.text("Signal remains insufficient", "信号仍然不足"), GameManager.text("The profile has not risen reliably above noise.", "轮廓尚未可靠高出噪声。")],
	]
	report_choice_buttons.clear()
	for i in range(choices.size()):
		var key := str(choices[i][0])
		var button := _button(str(choices[i][1]) + "\n" + str(choices[i][2]), Vector2(482, 88 + i * 88), Vector2(438, 70), Color("14253a"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_select_report_choice.bind(key))
		report_panel.add_child(button)
		report_choice_buttons[key] = button
	submit_button = _button(GameManager.text("SUBMIT SCIENCE REPORT", "提交科学报告"), Vector2(590, 374), Vector2(330, 44), Color("18452f"))
	submit_button.disabled = report_choice == ""
	submit_button.pressed.connect(_submit)
	report_panel.add_child(submit_button)
	_refresh_report_choice()


func _draw_report_product(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var before_rect := Rect2(Vector2(10, 22), Vector2(188, 82))
	var after_rect := Rect2(Vector2(212, 22), Vector2(188, 82))
	var pulse_rect := Rect2(Vector2(10, 132), Vector2(390, 92))
	for rect in [before_rect, after_rect, pulse_rect]:
		_draw_crt_grid(plot, rect, 24.0, Color(0.18, 0.34, 0.38, 0.14))
		plot.draw_rect(rect, Color(BRASS, 0.48), false, 1.0)
	_draw_plot_text(plot, GameManager.text("RAW BAND", "原始频段"), before_rect.position + Vector2(4, -5), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("CLEAN BAND", "净化频段"), after_rect.position + Vector2(4, -5), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("CONFIRMED FOLDED PULSE", "已确认折叠脉冲"), pulse_rect.position + Vector2(4, -5), 9, MUTED)
	_draw_spectrum_trace_in_rect(plot, before_rect, model.spectrum_samples(96, false), AMBER)
	_draw_spectrum_trace_in_rect(plot, after_rect, model.spectrum_samples(96, true), CRT)
	var profile := model.folded_profile(128)
	var points := PackedVector2Array()
	for i in range(profile.size()):
		var x := pulse_rect.position.x + 6.0 + (pulse_rect.size.x - 12.0) * float(i) / float(profile.size() - 1)
		var y := pulse_rect.end.y - 8.0 - clampf(float(profile[i]), 0.0, 1.2) * (pulse_rect.size.y - 18.0)
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(GREEN, 0.18), 6.0, true)
	plot.draw_polyline(points, GREEN, 1.8, true)
	_draw_plot_text(plot, "OBS %s · %s" % [str(GameManager.current_level().get("level_number", "--")), str(model.target_id).to_upper()], Vector2(12, 12), 10, GOLD)


func _draw_spectrum_trace_in_rect(plot: RadioPlot, rect: Rect2, samples: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(samples.size()):
		var x := rect.position.x + 4.0 + (rect.size.x - 8.0) * float(i) / float(maxi(1, samples.size() - 1))
		var y := rect.end.y - 5.0 - clampf(float(samples[i]) / 1.4, 0.0, 1.0) * (rect.size.y - 10.0)
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(color, 0.18), 4.0, true)
	plot.draw_polyline(points, color, 1.2, true)


func _select_report_choice(choice: String) -> void:
	report_choice = choice
	_refresh_report_choice()
	InteractionFeedback.feedback_sfx_requested.emit("ui_select")


func _refresh_report_choice() -> void:
	for key in report_choice_buttons:
		var button := report_choice_buttons[key] as Button
		InteractionFeedback.selection(button, str(key) == report_choice, CYAN, true, "fast_report_choice")
	if submit_button != null and is_instance_valid(submit_button):
		submit_button.disabled = report_choice == ""


func _submit() -> void:
	if running:
		return
	if report_choice == "":
		status_label.text = GameManager.text("Select the conclusion supported by the measured evidence.", "请选择实测证据支持的结论。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(submit_button)
		return
	var rep := model.report()
	if not model.evaluate_conclusion(report_choice):
		status_label.text = GameManager.text(
			"That conclusion conflicts with the report. Compare SNR, residual RFI, and the aligned pulse profile.",
			"该结论与报告证据冲突。请比较信噪比、残余干扰和对齐后的脉冲轮廓。"
		)
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(report_choice_buttons.get(report_choice, submit_button) as Control)
		return
	running = true
	InteractionFeedback.success(submit_button, "fast_report_confirmed")
	var observation := {
		"success": bool(rep.get("success", false)),
		"quality": _quality(float(rep["snr"])),
		"clarity": clampf(float(rep["snr"]) * 3.0, 0.0, 100.0),
		"contrast": clampf(float(rep["rfi_score"]) * 100.0, 0.0, 100.0),
		"detail": clampf(float(rep["timing_stability"]) * 100.0, 0.0, 100.0),
		"snr": float(rep["snr"]),
		"observation_mode": "radio",
		"pulse_period_ms": float(rep["trial_period_ms"]),
		"dispersion_measure": float(rep["trial_dm"]),
		"rfi_cleared": int(rep["rfi_cleared"]),
		"report_conclusion": report_choice,
		"feedback_en": str(rep.get("result_en", "A repeating radio pulse confirmed the source.")),
		"feedback_zh": str(rep.get("result_zh", "重复射电脉冲确认了目标。")),
	}
	await get_tree().create_timer(0.34 if not InteractionFeedback.is_reduced_motion() else 0.08).timeout
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _quality(snr: float) -> String:
	if snr >= 20.0:
		return "Excellent"
	if snr >= 13.0:
		return "Good"
	if snr >= model.report_snr_threshold:
		return "Fair"
	return "Poor"


func _wrap_words(value: String, line_length: int) -> String:
	var lines: Array[String] = []
	var current := ""
	for word in value.split(" ", false):
		var candidate := word if current == "" else current + " " + word
		if current != "" and candidate.length() > line_length:
			lines.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return "\n".join(lines)


func _wrap_characters(value: String, line_length: int) -> String:
	var lines: Array[String] = []
	var offset := 0
	while offset < value.length():
		lines.append(value.substr(offset, line_length))
		offset += line_length
	return "\n".join(lines)


# ---------------------------------------------------------------- shared drawing / controls
func _radio_operation_chain(action_text: String, effect_text: String, reveal_text: String) -> void:
	var chain := InteractionFeedback.operation_chain(self, action_text, effect_text, reveal_text, null, CYAN, 3.0)
	if chain != null:
		chain.position.y = 602.0


func _capture_waterfall_row(history: Array, apply_classification: bool) -> void:
	if model == null:
		return
	var source: Array = model.spectrum_samples(96, apply_classification)
	var row := PackedFloat32Array()
	for i in range(source.size()):
		var receiver_noise := sin(float(i) * 1.71 + waterfall_phase * 0.67) * 0.018
		row.append(clampf(float(source[i]) / 1.4 + receiver_noise, 0.0, 1.0))
	history.append(row)
	while history.size() > WATERFALL_ROWS:
		history.pop_front()


func _draw_waterfall(plot: Control, rect: Rect2, history: Array, cleaned: bool) -> void:
	if history.is_empty():
		return
	var row_height := rect.size.y / float(WATERFALL_ROWS)
	for row_index in range(history.size()):
		var row: PackedFloat32Array = history[row_index]
		if row.is_empty():
			continue
		var y := rect.end.y - float(history.size() - row_index) * row_height
		var cell_width := rect.size.x / float(row.size())
		for i in range(row.size()):
			var strength := clampf(float(row[i]), 0.0, 1.0)
			var color := Color(
				lerpf(0.03, 0.40 if cleaned else 0.56, strength),
				lerpf(0.08, 0.78 if cleaned else 0.58, strength),
				lerpf(0.10, 0.72 if cleaned else 0.30, strength),
				0.18 + strength * 0.70
			)
			plot.draw_rect(
				Rect2(Vector2(rect.position.x + float(i) * cell_width, y), Vector2(maxf(1.0, cell_width + 0.2), row_height + 0.2)),
				color,
				true
			)


func _draw_crt_grid(plot: Control, rect: Rect2, spacing: float, color: Color) -> void:
	plot.draw_rect(rect, Color("061019"), true)
	var x := rect.position.x
	while x <= rect.end.x:
		plot.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), color, 1.0)
		x += spacing
	var y := rect.position.y
	while y <= rect.end.y:
		plot.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0)
		y += spacing
	var scan_y := rect.position.y + 3.0
	while scan_y <= rect.end.y:
		plot.draw_line(Vector2(rect.position.x, scan_y), Vector2(rect.end.x, scan_y), Color(0.0, 0.0, 0.0, 0.10), 1.0)
		scan_y += 5.0


func _draw_arrow(plot: Control, from: Vector2, to: Vector2, color: Color) -> void:
	plot.draw_line(from, to, color, 2.0)
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x)
	plot.draw_colored_polygon(PackedVector2Array([to, to - direction * 10.0 + side * 5.0, to - direction * 10.0 - side * 5.0]), color)


func _draw_plot_text(plot: Control, value: String, pos: Vector2, font_size: int, color: Color) -> void:
	plot.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _meter(parent: Control, label_text: String, pos: Vector2, size_value: Vector2, value: float, color: Color) -> void:
	_label_to(parent, label_text, pos - Vector2(0, 16), Vector2(size_value.x, 16), 10, MUTED)
	var holder := Panel.new()
	holder.position = pos
	holder.size = size_value
	holder.add_theme_stylebox_override("panel", _flat(Color("07111b"), Color("26384b"), 1))
	parent.add_child(holder)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = Vector2((size_value.x - 4.0) * clampf(value, 0.0, 1.0), maxf(1.0, size_value.y - 4.0))
	fill.color = color
	holder.add_child(fill)


func _meter_draw(plot: Control, rect: Rect2, value: float, color: Color) -> void:
	plot.draw_rect(rect, Color("142333"), true)
	plot.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0.0, 1.0), rect.size.y)), color, true)
	plot.draw_rect(rect, Color("34495e"), false, 1.0)


func _stepper(parent: Control, label_text: String, pos: Vector2, width: float, minus_action: Callable, plus_action: Callable) -> void:
	_label_to(parent, label_text, pos - Vector2(0, 20), Vector2(150, 18), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var minus := _button("−", pos, Vector2(width * 0.5 - 2.0, 30), Color("153249"))
	minus.pressed.connect(minus_action)
	parent.add_child(minus)
	var plus := _button("+", pos + Vector2(width * 0.5 + 2.0, 0), Vector2(width * 0.5 - 2.0, 30), Color("153249"))
	plus.pressed.connect(plus_action)
	parent.add_child(plus)


func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	return _panel_to(self, pos, size_value, fill, border, "")


func _panel_to(parent: Control, pos: Vector2, size_value: Vector2, fill: Color, border: Color, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _flat(fill, border, 2))
	parent.add_child(panel)
	if title != "":
		_label_to(panel, title, Vector2(0, 8), Vector2(size_value.x, 26), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	return panel


func _flat(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style


func _label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label_to(self, value, pos, size_value, font_size, color, alignment)


func _label_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = size_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _flat(color, GOLD, 2))
	button.add_theme_stylebox_override("hover", _flat(color.lightened(0.10), CYAN, 2))
	button.add_theme_stylebox_override("pressed", _flat(color.darkened(0.12), GREEN, 2))
	button.add_theme_stylebox_override("disabled", _flat(color.darkened(0.35), Color("344255"), 1))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	return button
