extends Control

# FAST radio observation - a staged radio pipeline, not a light-bucket viewer.
# The player finds a real radio signal in noise and interference and confirms
# the source through data processing. It deliberately avoids every ground-optic
# concept and works purely in frequency, gain, noise and timing.
#
# Stages (a step bar at the top tracks progress):
#   1 AIM   - fly the suspended feed cabin onto the target (inertia + tension)
#   2 TUNE  - slide a frequency window onto the source, off the RFI
#   3 RFI   - tag each spectral peak as interference or a real source
#   4 FOLD  - set trial period + dispersion measure, integrate to raise SNR
#   5 REPORT- read the radio report and submit
#
# Reads GameManager.current_level().radio_profile when present so different
# levels/targets play differently with no code change.

const BG := Color("06101c")
const PANEL := Color("0f1c2e")
const GOLD := Color("d8a94d")
const CYAN := Color("61d8ff")
const GREEN := Color("67d78b")
const RED := Color("e0664a")
const TEXT := Color("e9e5d8")
const MUTED := Color("9fb0c4")

var model: RadioSignalModel
var stage := 0
const STAGE_KEYS := ["aim", "tune", "rfi", "fold", "report"]

var running := false
var status_label: Label
var readout: Label
var scope: Control
var stage_bar_holder: Control
var content: Control


func _ready() -> void:
	model = RadioSignalModel.new()
	model.configure(_profile())
	GameManager.language_changed.connect(_rebuild)
	set_process(true)
	_rebuild()
	InteractionFeedback.page_enter(self)


func _profile() -> Dictionary:
	var level := GameManager.current_level()
	var prof: Dictionary = level.get("radio_profile", {})
	if prof.is_empty():
		# default pulsar profile keyed off the level's target
		prof = {"target_id": GameManager.current_target_object_id(), "kind": "pulsar"}
	return prof


func _process(delta: float) -> void:
	if model == null:
		return
	# The cabin keeps coasting every frame so aiming has real inertia.
	model.step(delta)
	if stage == 0 and scope != null:
		_refresh_aim()


# ---------------------------------------------------------------- layout
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_label(GameManager.text("FAST RADIO OBSERVATION", "FAST 射电观测"), Vector2(24, 16), Vector2(976, 30), 23, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var target := GameManager.current_target()
	_label(GameManager.text("Target: ", "目标：") + GameManager.dict_text(target, "name")
		+ "   ·   " + GameManager.text("Find the real signal in the noise.", "在噪声中找到真实信号。"),
		Vector2(24, 48), Vector2(976, 22), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_build_stage_bar()

	content = Control.new()
	content.position = Vector2(0, 118)
	content.size = Vector2(1024, 560)
	add_child(content)

	status_label = _label(GameManager.text("", ""), Vector2(40, 690), Vector2(760, 40), 13, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(GameManager.text("Back", "返回"), Vector2(820, 690), Vector2(170, 40), Color("15233a"))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("telescope"); GameManager.go("observatory"))
	add_child(back)

	_build_stage()


func _build_stage_bar() -> void:
	stage_bar_holder = Control.new()
	stage_bar_holder.position = Vector2(24, 78)
	stage_bar_holder.size = Vector2(976, 30)
	add_child(stage_bar_holder)
	var labels := [
		GameManager.text("1 Aim", "1 定位"), GameManager.text("2 Tune", "2 调谐"),
		GameManager.text("3 RFI", "3 干扰"), GameManager.text("4 Fold", "4 折叠"),
		GameManager.text("5 Report", "5 报告")]
	var x := 0.0
	for i in range(labels.size()):
		var done := i < stage
		var active := i == stage
		var chip := Panel.new()
		chip.position = Vector2(x, 0)
		chip.size = Vector2(184, 28)
		chip.add_theme_stylebox_override("panel", _flat(
			Color("13233a") if not active else Color("1c3350"),
			GREEN if done else (GOLD if active else Color("2a3f5a")), 2))
		stage_bar_holder.add_child(chip)
		_label_to(chip, str(labels[i]), Vector2(0, 0), Vector2(184, 28), 13,
			GREEN if done else (GOLD if active else MUTED), HORIZONTAL_ALIGNMENT_CENTER)
		x += 198.0


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


func _advance() -> void:
	stage = mini(stage + 1, STAGE_KEYS.size() - 1)
	_rebuild()


# ---------------------------------------------------------------- 1. AIM
func _build_aim() -> void:
	_panel_to(content, Vector2(40, 10), Vector2(600, 470), PANEL, GOLD, GameManager.text("FEED CABIN SKY", "馈源舱天区"))
	scope = Control.new()
	scope.position = Vector2(40, 10)
	scope.size = Vector2(600, 470)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)

	var pad := _panel_to(content, Vector2(670, 10), Vector2(314, 470), PANEL, GOLD, GameManager.text("CABIN DRIVE", "馈源舱驱动"))
	readout = _label_to(pad, "", Vector2(16, 46), Vector2(282, 150), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# eight-direction nudge pad (az/alt), with inertia so a tap coasts
	var cx := 158.0
	var cy := 300.0
	_nudge(pad, GameManager.text("Alt +", "高度 +"), Vector2(cx - 40, cy - 88), Vector2(80, 38), 0.0, 1.0)
	_nudge(pad, GameManager.text("Alt -", "高度 -"), Vector2(cx - 40, cy + 50), Vector2(80, 38), 0.0, -1.0)
	_nudge(pad, GameManager.text("Az -", "方位 -"), Vector2(cx - 130, cy - 19), Vector2(80, 38), -1.0, 0.0)
	_nudge(pad, GameManager.text("Az +", "方位 +"), Vector2(cx + 50, cy - 19), Vector2(80, 38), 1.0, 0.0)
	var lock := _button(GameManager.text("Lock On Target", "锁定目标"), Vector2(cx - 90, cy + 108), Vector2(180, 42), Color("175238"))
	lock.pressed.connect(_try_lock)
	pad.add_child(lock)
	_refresh_aim()


func _nudge(parent: Control, label: String, pos: Vector2, size: Vector2, d_az: float, d_alt: float) -> void:
	var b := _button(label, pos, size, Color("143247"))
	b.pressed.connect(func() -> void: model.nudge(d_az, d_alt))
	parent.add_child(b)


func _refresh_aim() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Azimuth   %.1f  (target %.1f)\nAltitude  %.1f  (target %.1f)\nError     %.2f deg\nSpeed     %.2f deg/s\nCable tension %d%%" % [
			model.azimuth, model.true_azimuth, model.altitude, model.true_altitude,
			model.pointing_error(), model.pointing_speed(), int(model.cable_tension * 100.0)],
		"方位   %.1f  (目标 %.1f)\n高度   %.1f  (目标 %.1f)\n误差   %.2f 度\n速度   %.2f 度/秒\n缆索张力 %d%%" % [
			model.azimuth, model.true_azimuth, model.altitude, model.true_altitude,
			model.pointing_error(), model.pointing_speed(), int(model.cable_tension * 100.0)])
	readout.add_theme_color_override("font_color", RED if model.tension_warning() else TEXT)
	_draw_aim_scope()


func _draw_aim_scope() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var center := Vector2(300, 235)
	# target reticle (fixed) and cabin marker (moves with error)
	var ring := _ring(Vector2(300, 235), 26, GREEN if model.is_on_target() else CYAN)
	scope.add_child(ring)
	var err_az := wrapf(model.azimuth - model.true_azimuth, -180.0, 180.0)
	var err_alt := model.altitude - model.true_altitude
	var marker_pos := center + Vector2(err_az, -err_alt) * 6.0
	marker_pos.x = clampf(marker_pos.x, 20, 580)
	marker_pos.y = clampf(marker_pos.y, 20, 450)
	var marker := _ring(marker_pos, 14, GOLD)
	scope.add_child(marker)
	_label_to(scope, GameManager.text("cabin", "馈源舱"), marker_pos + Vector2(-30, 16), Vector2(60, 16), 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(scope, GameManager.text("target", "目标"), Vector2(270, 264), Vector2(60, 16), 10, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	var state := GameManager.text("LOCKED", "已锁定") if model.is_locked() else (
		GameManager.text("On target - slow down to settle", "已对准——减速稳定") if model.is_on_target()
		else GameManager.text("Drive the cabin onto the green reticle", "把馈源舱驱动到绿色标线上"))
	_label_to(scope, state, Vector2(40, 430), Vector2(520, 26), 14, GREEN if model.is_locked() else CYAN, HORIZONTAL_ALIGNMENT_CENTER)


func _try_lock() -> void:
	if model.is_locked():
		status_label.text = GameManager.text("Cabin locked. Tune the receiver next.", "馈源舱已锁定。下一步调谐接收机。")
		status_label.add_theme_color_override("font_color", GREEN)
		InteractionFeedback.success(self)
		_advance()
		_radio_operation_chain(
			GameManager.text("Locked the feed cabin", "锁定馈源舱"),
			GameManager.text("The radio beam settled on the source without cable drift", "射电波束稳定落在信号源上，缆索不再漂移"),
			GameManager.text("Receiver tuning is now available", "接收机调谐现已可用")
		)
	elif model.is_on_target():
		status_label.text = GameManager.text("On target but still drifting - wait for it to settle.", "已对准但仍在漂移——等它稳定下来。")
		status_label.add_theme_color_override("font_color", GOLD)
	else:
		status_label.text = GameManager.text("Not on target yet. Reduce the pointing error first.", "尚未对准。请先减小指向误差。")
		status_label.add_theme_color_override("font_color", RED)


# ---------------------------------------------------------------- 2. TUNE
func _build_tune() -> void:
	_panel_to(content, Vector2(40, 10), Vector2(944, 300), PANEL, GOLD, GameManager.text("LIVE SPECTRUM", "实时频谱"))
	scope = Control.new()
	scope.position = Vector2(40, 10)
	scope.size = Vector2(944, 300)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	_draw_spectrum()

	var ctl := _panel_to(content, Vector2(40, 326), Vector2(944, 150), PANEL, GOLD, GameManager.text("RECEIVER", "接收机"))
	readout = _label_to(ctl, "", Vector2(20, 44), Vector2(520, 60), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slider(ctl, GameManager.text("Centre frequency (MHz)", "中心频率 (MHz)"), Vector2(20, 104), model.BAND_MIN, model.BAND_MAX, model.window_center_mhz,
		func(v: float) -> void: model.window_center_mhz = v; _draw_spectrum(); _refresh_tune())
	_slider(ctl, GameManager.text("Bandwidth (MHz)", "带宽 (MHz)"), Vector2(500, 104), 20.0, 160.0, model.window_bandwidth_mhz,
		func(v: float) -> void: model.window_bandwidth_mhz = v; _draw_spectrum(); _refresh_tune())
	var confirm := _button(GameManager.text("Confirm Tuning", "确认调谐"), Vector2(760, 40), Vector2(164, 44), Color("175238"))
	confirm.pressed.connect(_confirm_tune)
	ctl.add_child(confirm)
	_refresh_tune()


func _refresh_tune() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Source coverage %d%%   RFI in window %d%%\nQuality %d%%.  Cover the source bump, avoid the tall spikes." % [
			int(model.window_covers_source() * 100), int(model.window_rfi_load() * 100), int(model.tuning_quality() * 100)],
		"信号覆盖 %d%%   窗口内干扰 %d%%\n质量 %d%%。覆盖信号鼓包，避开高尖峰。" % [
			int(model.window_covers_source() * 100), int(model.window_rfi_load() * 100), int(model.tuning_quality() * 100)])
	readout.add_theme_color_override("font_color", GREEN if model.tuning_quality() > 0.6 else (GOLD if model.tuning_quality() > 0.3 else RED))


func _draw_spectrum() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var w := 904.0
	var h := 236.0
	var ox := 20.0
	var oy := 44.0
	var samples: Array = model.spectrum_samples(180)
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = CYAN
	for i in range(samples.size()):
		var x := ox + w * float(i) / float(samples.size() - 1)
		var y := oy + h - float(samples[i]) / 1.4 * h
		line.add_point(Vector2(x, y))
	scope.add_child(line)
	# tuned window overlay
	var lo := (model.window_center_mhz - model.window_bandwidth_mhz * 0.5 - model.BAND_MIN) / (model.BAND_MAX - model.BAND_MIN)
	var hi := (model.window_center_mhz + model.window_bandwidth_mhz * 0.5 - model.BAND_MIN) / (model.BAND_MAX - model.BAND_MIN)
	var win := Panel.new()
	win.position = Vector2(ox + w * clampf(lo, 0, 1), oy)
	win.size = Vector2(w * clampf(hi - lo, 0.01, 1), h)
	win.add_theme_stylebox_override("panel", _flat(Color(0.85, 0.66, 0.30, 0.14), GOLD, 2))
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.add_child(win)
	_label_to(scope, GameManager.text("noise + RFI + source", "噪声 + 干扰 + 信号"), Vector2(ox, oy - 26), Vector2(300, 20), 11, MUTED)


func _confirm_tune() -> void:
	if model.tuning_quality() >= 0.55:
		status_label.text = GameManager.text("Good tuning. Now identify the interference.", "调谐良好。接下来识别干扰。")
		status_label.add_theme_color_override("font_color", GREEN)
		_advance()
		_radio_operation_chain(
			GameManager.text("Tuned the receiver window", "调谐接收机频率窗口"),
			GameManager.text("The source band entered the passband while excess noise fell", "信号频段进入通带，多余噪声下降"),
			GameManager.text("RFI peaks can now be classified", "射频干扰峰现已可分类")
		)
	else:
		status_label.text = GameManager.text("The window is off the source or full of RFI. Adjust it.", "窗口偏离信号或落在干扰上。请调整。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(self)


# ---------------------------------------------------------------- 3. RFI
func _build_rfi() -> void:
	_panel_to(content, Vector2(40, 10), Vector2(944, 466), PANEL, GOLD, GameManager.text("INTERFERENCE ID", "干扰识别"))
	_label_to(content, GameManager.text("Tag each peak: a real celestial source, or man-made interference (radar, satellite, phone, power line).",
		"给每个峰分类：真实天体信号，还是人造干扰（雷达、卫星、手机、电网）。"),
		Vector2(60, 52), Vector2(900, 40), 13, MUTED)
	var y := 100.0
	for i in range(model.rfi_peaks.size()):
		_rfi_row(i, model.rfi_peaks[i], Vector2(60, y))
		y += 62.0
	var confirm := _button(GameManager.text("Confirm Classification", "确认分类"), Vector2(700, 410), Vector2(240, 46), Color("175238"))
	confirm.pressed.connect(_confirm_rfi)
	content.add_child(confirm)


func _rfi_row(index: int, peak: Dictionary, pos: Vector2) -> void:
	var row := _panel_to(content, pos, Vector2(880, 52), Color("102037"), Color("2a3f5a"), "")
	_label_to(row, "%.0f MHz" % float(peak["mhz"]), Vector2(16, 0), Vector2(120, 52), 15, CYAN)
	var bar := Panel.new()
	bar.position = Vector2(150, 16)
	bar.size = Vector2(float(peak["strength"]) * 260.0, 20)
	bar.add_theme_stylebox_override("panel", _flat(GOLD, GOLD, 0))
	row.add_child(bar)
	var src := _button(GameManager.text("Real source", "真实信号"), Vector2(470, 8), Vector2(180, 36), Color("143a30"))
	src.pressed.connect(func() -> void: model.classify(index, false); _mark_rfi_row(row, false))
	row.add_child(src)
	var rfi := _button(GameManager.text("Interference", "人造干扰"), Vector2(662, 8), Vector2(180, 36), Color("3a2418"))
	rfi.pressed.connect(func() -> void: model.classify(index, true); _mark_rfi_row(row, true))
	row.add_child(rfi)
	row.set_meta("index", index)
	_apply_rfi_mark(row, index)


func _mark_rfi_row(row: Panel, as_rfi: bool) -> void:
	row.add_theme_stylebox_override("panel", _flat(Color("102037"), RED if as_rfi else GREEN, 3))
	InteractionFeedback.pulse(row, RED if as_rfi else GREEN)


func _apply_rfi_mark(row: Panel, index: int) -> void:
	var c := str(model.classifications.get(index, ""))
	if c == "rfi":
		row.add_theme_stylebox_override("panel", _flat(Color("102037"), RED, 3))
	elif c == "source":
		row.add_theme_stylebox_override("panel", _flat(Color("102037"), GREEN, 3))


func _confirm_rfi() -> void:
	if not model.all_classified():
		status_label.text = GameManager.text("Classify every peak first.", "请先给每个峰分类。")
		status_label.add_theme_color_override("font_color", GOLD)
		return
	if model.classification_score() >= 0.75:
		status_label.text = GameManager.text("Interference rejected. Fold the pulse next.", "干扰已剔除。下一步折叠脉冲。")
		status_label.add_theme_color_override("font_color", GREEN)
		_advance()
		_radio_operation_chain(
			GameManager.text("Classified and rejected RFI", "分类并剔除射频干扰"),
			GameManager.text("Man-made peaks no longer contaminate the time series", "人造信号峰不再污染时间序列"),
			GameManager.text("The celestial pulse is ready for period folding", "天体脉冲现已可进行周期折叠")
		)
	else:
		status_label.text = GameManager.text("Some peaks are misidentified - a false peak would give a wrong period.", "部分峰识别错误——假峰会给出错误周期。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(self)


# ---------------------------------------------------------------- 4. FOLD
func _build_fold() -> void:
	_panel_to(content, Vector2(40, 10), Vector2(560, 300), PANEL, GOLD, GameManager.text("FOLDED PULSE PROFILE", "脉冲折叠轮廓"))
	scope = Control.new()
	scope.position = Vector2(40, 10)
	scope.size = Vector2(560, 300)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	_draw_fold()

	var ctl := _panel_to(content, Vector2(620, 10), Vector2(364, 466), PANEL, GOLD, GameManager.text("SIGNAL PROCESSING", "信号处理"))
	readout = _label_to(ctl, "", Vector2(16, 44), Vector2(332, 96), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slider(ctl, GameManager.text("Trial period (ms)", "试验周期 (ms)"), Vector2(16, 146), model.true_period_ms - 60.0, model.true_period_ms + 60.0, model.trial_period_ms,
		func(v: float) -> void: model.trial_period_ms = v; _draw_fold(); _refresh_fold())
	_slider(ctl, GameManager.text("Dispersion measure", "色散量 DM"), Vector2(16, 214), 0.0, model.true_dm + 20.0, model.trial_dm,
		func(v: float) -> void: model.trial_dm = v; _draw_fold(); _refresh_fold())
	_slider(ctl, GameManager.text("Integration time (s)", "积分时间 (s)"), Vector2(16, 282), 0.0, model.MAX_INTEGRATION, model.integration_s,
		func(v: float) -> void: model.set_integration(v); _draw_fold(); _refresh_fold())
	var confirm := _button(GameManager.text("Save Observation", "保存观测"), Vector2(16, 402), Vector2(332, 46), Color("175238"))
	confirm.pressed.connect(_confirm_fold)
	ctl.add_child(confirm)
	_refresh_fold()


func _refresh_fold() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"SNR %.1f   Period match %d%%   DM match %d%%\nLonger integration raises SNR as sqrt(time)." % [
			model.fold_snr(), int(model.period_match() * 100), int(model.dm_match() * 100)],
		"信噪比 %.1f   周期匹配 %d%%   DM 匹配 %d%%\n延长积分时间，信噪比按 sqrt(时间) 提升。" % [
			model.fold_snr(), int(model.period_match() * 100), int(model.dm_match() * 100)])
	readout.add_theme_color_override("font_color", GREEN if model.fold_snr() >= 8.0 else GOLD)
	_draw_fold()


func _draw_fold() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var w := 520.0
	var h := 210.0
	var ox := 20.0
	var oy := 60.0
	# two folded cycles so a clean single pulse per period is obvious
	var profile: Array = model.folded_profile(120)
	var line := Line2D.new()
	line.width = 2.0
	line.default_color = GREEN if model.fold_snr() >= 8.0 else CYAN
	for rep in range(2):
		for i in range(profile.size()):
			var x := ox + w * (float(rep) + float(i) / float(profile.size())) / 2.0
			var y := oy + h - float(profile[i]) / 1.2 * h
			line.add_point(Vector2(x, y))
	scope.add_child(line)
	_label_to(scope, GameManager.text("phase (2 periods)", "相位（两个周期）"), Vector2(ox, oy + h + 6), Vector2(300, 20), 11, MUTED)


func _confirm_fold() -> void:
	var snr := model.fold_snr()
	if snr < 8.0 or model.period_match() <= 0.6 or model.dm_match() <= 0.6:
		status_label.text = GameManager.text(
			"Signal not confirmed. Match the period and DM, then integrate longer to raise SNR above 8.",
			"信号未确认。请匹配周期与 DM，再延长积分把信噪比提到 8 以上。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(self)
		return
	status_label.text = GameManager.text("Pulse confirmed. Reading the report.", "脉冲已确认。正在读取报告。")
	status_label.add_theme_color_override("font_color", GREEN)
	InteractionFeedback.success(self)
	_advance()
	_radio_operation_chain(
		GameManager.text("Matched period and dispersion measure", "匹配脉冲周期与色散量"),
		GameManager.text("Dispersed samples aligned and folded integrations raised SNR", "色散样本对齐，折叠积分提高了信噪比"),
		GameManager.text("A repeating radio pulse emerged from the noise", "重复射电脉冲从噪声中显现")
	)


func _radio_operation_chain(action_text: String, effect_text: String, reveal_text: String) -> void:
	var chain := InteractionFeedback.operation_chain(
		self,
		action_text,
		effect_text,
		reveal_text,
		null,
		CYAN,
		2.7
	)
	if chain != null:
		chain.position.y = 538.0


# ---------------------------------------------------------------- 5. REPORT
func _build_report() -> void:
	var rep := model.report()
	_panel_to(content, Vector2(212, 10), Vector2(600, 440), PANEL, GOLD, GameManager.text("RADIO OBSERVATION REPORT", "射电观测报告"))
	var rows := [
		[GameManager.text("Pulse period", "脉冲周期"), "%.1f ms" % float(rep["pulse_period_ms"])],
		[GameManager.text("Dispersion measure", "色散量"), "%.1f pc/cm3" % float(rep["dispersion_measure"])],
		[GameManager.text("Signal-to-noise", "信噪比"), "%.1f" % float(rep["snr"])],
		[GameManager.text("Pulse width", "脉冲宽度"), "%.1f ms" % float(rep["pulse_width_ms"])],
		[GameManager.text("Timing stability", "计时稳定度"), "%d%%" % int(float(rep["timing_stability"]) * 100)],
		[GameManager.text("Radio band", "射电频段"), "%.0f MHz" % float(rep["band_mhz"])],
		[GameManager.text("Integration", "积分时间"), "%.0f s" % float(rep["integration_s"])],
		[GameManager.text("RFI rejection", "干扰剔除"), "%d%%" % int(float(rep["rfi_score"]) * 100)],
	]
	var y := 56.0
	for row in rows:
		_label_to(content, str(row[0]), Vector2(252, y), Vector2(280, 24), 14, MUTED)
		_label_to(content, str(row[1]), Vector2(540, y), Vector2(240, 24), 14, TEXT)
		y += 40.0
	var finding := _label_to(content, GameManager.text(
		"Conclusion: a repeating radio pulse confirms the source. No camera image exists - the evidence is the signal itself.",
		"结论：稳定重复的射电脉冲确认了目标。没有相机图像——证据就是信号本身。"),
		Vector2(252, y + 4), Vector2(520, 60), 13, CYAN)
	finding.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var submit := _button(GameManager.text("Submit Report", "提交报告"), Vector2(392, 400), Vector2(240, 46), Color("175238"))
	submit.pressed.connect(_submit)
	content.add_child(submit)


func _submit() -> void:
	if running:
		return
	running = true
	var rep := model.report()
	var observation := {
		"success": true, "quality": _quality(float(rep["snr"])),
		"clarity": clampf(float(rep["snr"]) * 3.0, 0.0, 100.0),
		"contrast": clampf(float(rep["rfi_score"]) * 100.0, 0.0, 100.0),
		"detail": clampf(float(rep["timing_stability"]) * 100.0, 0.0, 100.0),
		"snr": float(rep["snr"]), "observation_mode": "radio",
		"pulse_period_ms": float(rep["pulse_period_ms"]),
		"dispersion_measure": float(rep["dispersion_measure"]),
		"feedback_en": "A repeating radio pulse confirmed the source.",
		"feedback_zh": "重复的射电脉冲确认了目标。",
	}
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _quality(snr: float) -> String:
	if snr >= 20.0:
		return "Excellent"
	if snr >= 13.0:
		return "Good"
	if snr >= 8.0:
		return "Fair"
	return "Poor"


# ---------------------------------------------------------------- helpers
func _slider(parent: Control, label: String, pos: Vector2, lo: float, hi: float, value: float, changed: Callable) -> void:
	_label_to(parent, label, pos, Vector2(300, 18), 12, MUTED)
	var slider := HSlider.new()
	slider.position = pos + Vector2(0, 24)
	slider.size = Vector2(300, 20)
	slider.min_value = lo
	slider.max_value = hi
	slider.step = (hi - lo) / 200.0
	slider.value = value
	slider.value_changed.connect(changed)
	parent.add_child(slider)


func _ring(center: Vector2, radius: float, color: Color) -> Node2D:
	var node := Line2D.new()
	node.width = 3.0
	node.default_color = color
	for i in range(33):
		var a := TAU * float(i) / 32.0
		node.add_point(center + Vector2(cos(a), sin(a)) * radius)
	return node


func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	return _panel_to(self, pos, size_value, fill, border, "")


func _panel_to(parent: Control, pos: Vector2, size_value: Vector2, fill: Color, border: Color, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _flat(fill, border, 2))
	parent.add_child(panel)
	if title != "":
		_label_to(panel, title, Vector2(0, 8), Vector2(size_value.x, 26), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	return panel


func _flat(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
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
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _flat(color, GOLD, 2))
	button.add_theme_stylebox_override("hover", _flat(color.lightened(0.12), GOLD, 2))
	button.add_theme_stylebox_override("pressed", _flat(color.darkened(0.15), CYAN, 2))
	button.add_theme_color_override("font_color", TEXT)
	return button
