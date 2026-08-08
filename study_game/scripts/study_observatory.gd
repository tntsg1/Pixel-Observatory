extends Control

const SAVE_PATH := "user://study_observation_v1.json"
const GOLD := Color("e9bd58")
const CYAN := Color("81dcff")
const GREEN := Color("79e2a9")
const PANEL := Color("081423")
const PANEL_SOFT := Color("0d1d2e")
const TEXT := Color("edf6ff")
const MUTED := Color("91a7bd")

var language := "en"
var stage := 0
var mode := 0
var locks := [false, false, false]
var target_offset := Vector2(0.48, -0.32)
var eyepiece_mm := 10
var focus_value := 35.0
var tracking := false
var optical_ready_seconds := 0.0
var infrared_channels := ["dust", "near", "mid"]
var infrared_done := false
var dispersion_measure := 8.0
var radio_done := false
var completed := false
var active_seconds := 0.0
var heartbeat_seconds := 0.0

var page: VBoxContainer
var content_host: PanelContainer
var display: StudyDisplay
var status_label: Label
var primary_action: Button
var timer_label: Label
var stage_labels: Array[Label] = []
var focus_slider: HSlider
var dm_slider: HSlider
var integrate_button: Button
var quality_label: Label
var dragging := false
var last_pointer := Vector2.ZERO


func _ready() -> void:
	language = _website_language()
	_load_state()
	_build_shell()
	_show_stage(false)
	set_process(true)
	_emit_bridge("heartbeat")


func _process(delta: float) -> void:
	if not _window_active():
		return
	active_seconds += delta
	heartbeat_seconds += delta
	if timer_label:
		timer_label.text = _format_time(int(active_seconds))
	if stage == 1 and _optical_configuration_ready():
		optical_ready_seconds = minf(optical_ready_seconds + delta, 4.0)
		if integrate_button:
			integrate_button.text = tr_text("Integrating %.1f / 4.0 s", "积分曝光 %.1f / 4.0 秒") % optical_ready_seconds
			integrate_button.disabled = optical_ready_seconds < 4.0
	else:
		optical_ready_seconds = 0.0
		if integrate_button:
			integrate_button.text = tr_text("Stabilise the observation first", "请先稳定观测条件")
			integrate_button.disabled = true
	if heartbeat_seconds >= 15.0:
		heartbeat_seconds = 0.0
		_save_state()
		_emit_bridge("heartbeat")
	if completed:
		return
	if display:
		display.target_offset = target_offset
		display.view_mode = mode
		display.focus_value = focus_value
		display.tracking = tracking
		display.eyepiece_mm = eyepiece_mm
		display.infrared_channels = infrared_channels
		display.dispersion_measure = dispersion_measure


func _unhandled_input(event: InputEvent) -> void:
	if stage != 0 or completed:
		return
	var direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if direction.length_squared() > 0.0:
		_slew(direction.normalized() * 0.018)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed and display != null and display.get_global_rect().has_point(event.position)
		last_pointer = event.position
	elif event is InputEventMouseMotion and dragging:
		var pointer_delta: Vector2 = event.position - last_pointer
		last_pointer = event.position
		_slew(pointer_delta / maxf(display.size.x, 1.0) * 0.7)


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color("020711")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	page = VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)

	var header := HBoxContainer.new()
	page.add_child(header)
	var brand := Label.new()
	brand.text = "PIXEL OBSERVATORY  /  STUDY INSTRUMENT"
	brand.add_theme_color_override("font_color", GOLD)
	brand.add_theme_font_size_override("font_size", 14)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	timer_label = Label.new()
	timer_label.text = _format_time(int(active_seconds))
	timer_label.add_theme_color_override("font_color", CYAN)
	timer_label.add_theme_font_size_override("font_size", 14)
	header.add_child(timer_label)
	var language_button := _button("中文" if language == "en" else "EN", _toggle_language, "quiet")
	language_button.custom_minimum_size.x = 58
	header.add_child(language_button)

	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 8)
	page.add_child(progress)
	for index in range(3):
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.y = 32
		stage_labels.append(label)
		progress.add_child(label)

	content_host = PanelContainer.new()
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_host.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.39, 0.66, 0.81, 0.33), 8, 1))
	page.add_child(content_host)


func _show_stage(animated := true) -> void:
	for child in content_host.get_children():
		child.queue_free()
	display = null
	status_label = null
	primary_action = null
	focus_slider = null
	dm_slider = null
	integrate_button = null
	quality_label = null
	_update_progress()
	if completed:
		_build_complete()
	elif stage == 0:
		_build_acquire()
	elif stage == 1:
		_build_optical()
	else:
		_build_decode()
	if animated:
		content_host.modulate.a = 0.0
		content_host.position.x = 18.0
		var tween := create_tween().set_parallel(true)
		tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(content_host, "modulate:a", 1.0, 0.32)
		tween.tween_property(content_host, "position:x", 0.0, 0.32)


func _update_progress() -> void:
	var titles := [tr_text("1  ACQUIRE", "1  寻星"), tr_text("2  RESOLVE", "2  成像"), tr_text("3  DECODE", "3  解码")]
	for index in range(stage_labels.size()):
		var label := stage_labels[index]
		label.text = titles[index]
		label.add_theme_color_override("font_color", TEXT if index == stage else (GREEN if index < stage else MUTED))
		label.add_theme_stylebox_override("normal", _panel_style(Color("10253a") if index == stage else Color("07111e"), CYAN if index == stage else Color(0.2, 0.34, 0.47, 0.7), 6, 1))


func _stage_layout(title: String, subtitle: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.add_theme_constant_override("margin_left", 0)
	content_host.add_child(root)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 2)
	heading.add_theme_constant_override("margin_left", 18)
	root.add_child(heading)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", TEXT)
	title_label.add_theme_font_size_override("font_size", 25)
	heading.add_child(title_label)
	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_color_override("font_color", MUTED)
	subtitle_label.add_theme_font_size_override("font_size", 13)
	heading.add_child(subtitle_label)
	var columns := HSplitContainer.new()
	columns.split_offset = 660
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var visual_panel := PanelContainer.new()
	visual_panel.add_theme_stylebox_override("panel", _panel_style(Color("030a13"), Color(0.28, 0.53, 0.68, 0.52), 6, 1))
	columns.add_child(visual_panel)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 292
	controls.add_theme_constant_override("separation", 12)
	columns.add_child(controls)
	return {"root": root, "visual": visual_panel, "controls": controls}


func _build_acquire() -> void:
	var layout := _stage_layout(
		tr_text("Find M42 without losing the sky", "在天空中逐级找到 M42"),
		tr_text("Use a wide field first. Narrower instruments only help after the target is centred.", "先使用宽视场定位；目标居中后，再进入更窄的仪器视场。")
	)
	display = StudyDisplay.new()
	display.view_kind = StudyDisplay.ViewKind.ACQUIRE
	display.target_offset = target_offset
	display.view_mode = mode
	display.custom_minimum_size = Vector2(600, 500)
	layout.visual.add_child(display)
	var controls: VBoxContainer = layout.controls
	controls.add_child(_section_label(tr_text("TARGET ACQUISITION", "目标捕获")))
	status_label = _body_label("")
	controls.add_child(status_label)
	var modes := HBoxContainer.new()
	for index in range(3):
		var names := [tr_text("Eye", "肉眼"), tr_text("Finder", "寻星镜"), tr_text("Scope", "主镜")]
		var button := _button(names[index], func(): _set_mode(index), "selected" if index == mode else "quiet")
		button.disabled = index > mode
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(button)
	controls.add_child(modes)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_child(Control.new())
	pad.add_child(_button("↑", func(): _slew(Vector2(0, -0.045)), "quiet"))
	pad.add_child(Control.new())
	pad.add_child(_button("←", func(): _slew(Vector2(-0.045, 0)), "quiet"))
	pad.add_child(_button("↓", func(): _slew(Vector2(0, 0.045)), "quiet"))
	pad.add_child(_button("→", func(): _slew(Vector2(0.045, 0)), "quiet"))
	controls.add_child(pad)
	controls.add_child(_hint(tr_text("Drag the sky or use WASD. Lock the target once it enters the gold reticle.", "拖动星空或使用 WASD。目标进入金色准星后进行锁定。")))
	primary_action = _button(tr_text("Lock current view", "锁定当前视场"), _lock_current_view, "primary")
	controls.add_child(primary_action)
	_refresh_acquire_status()


func _set_mode(index: int) -> void:
	if index <= mode:
		mode = index
		_show_stage(false)


func _slew(delta: Vector2) -> void:
	target_offset -= delta / [0.55, 1.15, 2.15][mode]
	target_offset.x = clampf(target_offset.x, -0.72, 0.72)
	target_offset.y = clampf(target_offset.y, -0.58, 0.58)
	_refresh_acquire_status()


func _refresh_acquire_status() -> void:
	if not status_label or not primary_action:
		return
	var distance := target_offset.length()
	var threshold: float = [0.12, 0.075, 0.045][mode]
	status_label.text = tr_text("M42 / Orion Nebula\nOffset %.2f°\nMode %d of 3", "M42 / 猎户座大星云\n偏差 %.2f°\n模式 %d / 3") % [distance * 10.0, mode + 1]
	primary_action.disabled = distance >= threshold
	primary_action.text = tr_text("Target inside lock ring", "目标已进入锁定环") if distance < threshold else tr_text("Slew closer to M42", "继续转向 M42")


func _lock_current_view() -> void:
	locks[mode] = true
	if mode < 2:
		mode += 1
		target_offset *= 0.36
		_save_state()
		_show_stage(true)
	else:
		stage = 1
		_save_state()
		_show_stage(true)


func _build_optical() -> void:
	var layout := _stage_layout(
		tr_text("Produce a stable optical image", "获得稳定的光学图像"),
		tr_text("Poor seeing caps useful magnification near 55×. More magnification is not always more detail.", "差视宁度把有效倍率限制在约 55×；更高倍率并不总能带来更多细节。")
	)
	display = StudyDisplay.new()
	display.view_kind = StudyDisplay.ViewKind.OPTICAL
	display.focus_value = focus_value
	display.eyepiece_mm = eyepiece_mm
	display.tracking = tracking
	display.custom_minimum_size = Vector2(600, 500)
	layout.visual.add_child(display)
	var controls: VBoxContainer = layout.controls
	controls.add_child(_section_label(tr_text("OPTICAL BENCH", "光学控制")))
	quality_label = _body_label("")
	controls.add_child(quality_label)
	var eyepieces := HBoxContainer.new()
	for value in [25, 10]:
		var magnification := int(round(1200.0 / value))
		var button := _button("%d mm  /  %d×" % [value, magnification], func(): _set_eyepiece(value), "selected" if value == eyepiece_mm else "quiet")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eyepieces.add_child(button)
	controls.add_child(eyepieces)
	controls.add_child(_section_label(tr_text("Focus", "调焦")))
	focus_slider = HSlider.new()
	focus_slider.min_value = 0
	focus_slider.max_value = 100
	focus_slider.value = focus_value
	focus_slider.value_changed.connect(func(value): focus_value = value; _refresh_optical_status(); _save_state())
	controls.add_child(focus_slider)
	var tracking_button := _button(tr_text("Tracking: ON", "追踪：开启") if tracking else tr_text("Tracking: OFF", "追踪：关闭"), _toggle_tracking, "selected" if tracking else "quiet")
	controls.add_child(tracking_button)
	controls.add_child(_hint(tr_text("Choose 25 mm (48×), focus near the sharp point, then enable sidereal tracking.", "选择 25 mm（48×），把焦点调到清晰位置，再开启恒星时追踪。")))
	integrate_button = _button(tr_text("Stabilise the observation first", "请先稳定观测条件"), _finish_optical, "primary")
	integrate_button.disabled = true
	controls.add_child(integrate_button)
	_refresh_optical_status()


func _set_eyepiece(value: int) -> void:
	eyepiece_mm = value
	optical_ready_seconds = 0.0
	_save_state()
	_show_stage(false)


func _toggle_tracking() -> void:
	tracking = not tracking
	optical_ready_seconds = 0.0
	_save_state()
	_show_stage(false)


func _optical_configuration_ready() -> bool:
	return eyepiece_mm == 25 and absf(focus_value - 72.0) <= 5.0 and tracking


func _refresh_optical_status() -> void:
	if not quality_label:
		return
	var magnification := int(round(1200.0 / eyepiece_mm))
	var focus_error := absf(focus_value - 72.0)
	var condition := tr_text("stable", "稳定") if tracking else tr_text("drifting", "漂移")
	quality_label.text = tr_text("Seeing: poor / cap 55×\nCurrent: %d×\nFocus error: %.0f\nField: %s", "视宁度：差 / 上限 55×\n当前倍率：%d×\n焦点误差：%.0f\n视场：%s") % [magnification, focus_error, condition]


func _finish_optical() -> void:
	stage = 2
	_save_state()
	_show_stage(true)


func _build_decode() -> void:
	var layout := _stage_layout(
		tr_text("Decode light the eye cannot see", "解码肉眼看不见的证据"),
		tr_text("Assign infrared bands to display colours, then correct the radio pulse dispersion.", "把红外波段映射为显示色，再校正射电脉冲的色散。")
	)
	var visual_tabs := VBoxContainer.new()
	visual_tabs.add_theme_constant_override("separation", 9)
	layout.visual.add_child(visual_tabs)
	display = StudyDisplay.new()
	display.view_kind = StudyDisplay.ViewKind.INFRARED if not infrared_done else StudyDisplay.ViewKind.RADIO
	display.infrared_channels = infrared_channels
	display.dispersion_measure = dispersion_measure
	display.custom_minimum_size = Vector2(600, 445)
	display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	visual_tabs.add_child(display)
	var evidence_switch := HBoxContainer.new()
	evidence_switch.add_child(_button(tr_text("Infrared composite", "红外合成"), func(): display.view_kind = StudyDisplay.ViewKind.INFRARED, "selected" if display.view_kind == StudyDisplay.ViewKind.INFRARED else "quiet"))
	evidence_switch.add_child(_button(tr_text("Radio dispersion", "射电色散"), func(): display.view_kind = StudyDisplay.ViewKind.RADIO, "selected" if display.view_kind == StudyDisplay.ViewKind.RADIO else "quiet"))
	visual_tabs.add_child(evidence_switch)
	var controls: VBoxContainer = layout.controls
	controls.add_child(_section_label(tr_text("INVISIBLE EVIDENCE", "不可见光证据")))
	status_label = _body_label("")
	controls.add_child(status_label)
	for index in range(3):
		var names := ["R", "G", "B"]
		var button := _button("%s  ←  %s" % [names[index], _band_name(infrared_channels[index])], func(): _cycle_band(index), "selected" if infrared_done else "quiet")
		controls.add_child(button)
	var confirm_ir := _button(tr_text("Confirm false-colour mapping", "确认假彩色映射"), _confirm_infrared, "primary")
	confirm_ir.disabled = infrared_done
	controls.add_child(confirm_ir)
	controls.add_child(_section_label(tr_text("Dispersion measure", "色散量")))
	dm_slider = HSlider.new()
	dm_slider.min_value = 0.0
	dm_slider.max_value = 30.0
	dm_slider.step = 0.2
	dm_slider.value = dispersion_measure
	dm_slider.value_changed.connect(func(value): dispersion_measure = value; display.dispersion_measure = value; _refresh_decode_status(); _save_state())
	controls.add_child(dm_slider)
	var confirm_radio := _button(tr_text("Lock corrected pulse", "锁定校正后的脉冲"), _confirm_radio, "primary")
	confirm_radio.disabled = radio_done
	controls.add_child(confirm_radio)
	primary_action = _button(tr_text("Complete observation", "完成观测"), _finish_study_game, "primary")
	primary_action.disabled = not (infrared_done and radio_done)
	controls.add_child(primary_action)
	_refresh_decode_status()


func _band_name(value: String) -> String:
	match value:
		"dust": return tr_text("MIR dust", "中红外尘埃")
		"mid": return tr_text("NIR long", "近红外长波")
		_: return tr_text("NIR short", "近红外短波")


func _cycle_band(index: int) -> void:
	if infrared_done:
		return
	var values := ["dust", "mid", "near"]
	var current := values.find(infrared_channels[index])
	infrared_channels[index] = values[(current + 1) % values.size()]
	_save_state()
	_show_stage(false)


func _confirm_infrared() -> void:
	if infrared_channels == ["dust", "mid", "near"]:
		infrared_done = true
		display.view_kind = StudyDisplay.ViewKind.RADIO
		_save_state()
		_show_stage(true)
	else:
		status_label.text = tr_text("The channels still duplicate or reverse the wavelength order. Build a long-to-short display sequence.", "通道仍然重复或颠倒了波长顺序。请建立由长波到短波的显示顺序。")


func _confirm_radio() -> void:
	if absf(dispersion_measure - 14.4) <= 0.8:
		radio_done = true
		_save_state()
		_show_stage(true)
	else:
		status_label.text = tr_text("The pulse is still slanted across the band. Move DM until the traces arrive together.", "脉冲在频段中仍然倾斜。调整色散量，直到各频段同时到达。")


func _refresh_decode_status() -> void:
	if not status_label:
		return
	var coherence := clampf(1.0 - absf(dispersion_measure - 14.4) / 12.0, 0.0, 1.0)
	status_label.text = tr_text("Infrared mapping: %s\nTrial DM: %.1f pc/cm³\nPulse coherence: %d%%", "红外映射：%s\n试验 DM：%.1f pc/cm³\n脉冲相干度：%d%%") % [tr_text("confirmed", "已确认") if infrared_done else tr_text("pending", "待确认"), dispersion_measure, int(round(coherence * 100.0))]


func _finish_study_game() -> void:
	completed = true
	_save_state()
	_emit_bridge("complete")
	_show_stage(true)


func _build_complete() -> void:
	var center := CenterContainer.new()
	content_host.add_child(center)
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(600, 430)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 16)
	center.add_child(card)
	var mark := Label.new()
	mark.text = "✓"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_color_override("font_color", GREEN)
	mark.add_theme_font_size_override("font_size", 64)
	card.add_child(mark)
	var title := Label.new()
	title.text = tr_text("Observation record complete", "观测记录已完成")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TEXT)
	title.add_theme_font_size_override("font_size", 30)
	card.add_child(title)
	var summary := Label.new()
	summary.text = tr_text(
		"You acquired M42 through three fields of view, respected the atmosphere's 55× limit, produced a tracked focus, mapped invisible infrared bands, and recovered a dispersed radio pulse.",
		"你通过三种视场捕获了 M42，遵守了大气的 55× 倍率上限，获得了稳定追踪的清晰图像，并完成了红外波段映射与射电脉冲色散校正。"
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", MUTED)
	summary.add_theme_font_size_override("font_size", 15)
	card.add_child(summary)
	var result := Label.new()
	result.text = tr_text("Study-only record  •  %s active", "研究专用记录  •  有效时长 %s") % _format_time(int(active_seconds))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_color_override("font_color", CYAN)
	card.add_child(result)
	card.add_child(_hint(tr_text("Return to the questionnaire tab to complete the final reflection.", "返回问卷页面，完成最后的反思测试。")))


func _toggle_language() -> void:
	language = "zh" if language == "en" else "en"
	_save_state()
	_build_language_refresh()
	_emit_bridge("language")


func _build_language_refresh() -> void:
	for child in get_children():
		child.queue_free()
	stage_labels.clear()
	page = null
	content_host = null
	call_deferred("_rebuild_after_language")


func _rebuild_after_language() -> void:
	_build_shell()
	_show_stage(false)


func _website_language() -> String:
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("new URLSearchParams(location.search).get('lang') || localStorage.getItem('so-lang') || 'en'", true)
		if str(value).to_lower().begins_with("zh"):
			return "zh"
	return "en"


func _window_active() -> bool:
	if not OS.has_feature("web"):
		return true
	return bool(JavaScriptBridge.eval("!document.hidden && document.hasFocus()", true))


func _emit_bridge(event_name: String) -> void:
	if not OS.has_feature("web"):
		return
	var payload := JSON.stringify({
		"source": "pixel-observatory-study-godot",
		"event": event_name,
		"activeSeconds": int(active_seconds),
		"complete": completed,
		"language": language
	})
	JavaScriptBridge.eval("window.parent.postMessage(%s, location.origin)" % payload, true)


func _load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != 1:
		return
	stage = clampi(int(parsed.get("stage", 0)), 0, 2)
	mode = clampi(int(parsed.get("mode", 0)), 0, 2)
	var saved_locks = parsed.get("locks", locks)
	if typeof(saved_locks) == TYPE_ARRAY and saved_locks.size() == 3:
		locks = saved_locks
	var offset = parsed.get("target_offset", [target_offset.x, target_offset.y])
	if typeof(offset) == TYPE_ARRAY and offset.size() == 2:
		target_offset = Vector2(float(offset[0]), float(offset[1]))
	eyepiece_mm = int(parsed.get("eyepiece_mm", 10))
	focus_value = float(parsed.get("focus_value", 35.0))
	tracking = bool(parsed.get("tracking", false))
	var channels = parsed.get("infrared_channels", infrared_channels)
	if typeof(channels) == TYPE_ARRAY and channels.size() == 3:
		infrared_channels = channels
	infrared_done = bool(parsed.get("infrared_done", false))
	dispersion_measure = float(parsed.get("dispersion_measure", 8.0))
	radio_done = bool(parsed.get("radio_done", false))
	completed = bool(parsed.get("completed", false))
	active_seconds = float(parsed.get("active_seconds", 0.0))
	language = str(parsed.get("language", language))


func _save_state() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"version": 1,
		"stage": stage,
		"mode": mode,
		"locks": locks,
		"target_offset": [target_offset.x, target_offset.y],
		"eyepiece_mm": eyepiece_mm,
		"focus_value": focus_value,
		"tracking": tracking,
		"infrared_channels": infrared_channels,
		"infrared_done": infrared_done,
		"dispersion_measure": dispersion_measure,
		"radio_done": radio_done,
		"completed": completed,
		"active_seconds": active_seconds,
		"language": language
	}))


func tr_text(en: String, zh: String) -> String:
	return zh if language == "zh" else en


func _format_time(total_seconds: int) -> String:
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 14)
	return label


func _hint(text: String) -> Label:
	var label := _body_label(text)
	label.add_theme_color_override("font_color", MUTED)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_stylebox_override("normal", _panel_style(Color("0a1828"), Color(0.22, 0.41, 0.55, 0.62), 5, 1))
	return label


func _button(text: String, callback: Callable, kind := "quiet") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_font_size_override("font_size", 13)
	var fill := GOLD if kind == "primary" else (Color("bdeeff") if kind == "selected" else PANEL_SOFT)
	var colour := Color("11100c") if kind == "primary" else (Color("06111a") if kind == "selected" else TEXT)
	button.add_theme_color_override("font_color", colour)
	button.add_theme_color_override("font_hover_color", colour)
	button.add_theme_stylebox_override("normal", _panel_style(fill, fill.lightened(0.18), 5, 1))
	button.add_theme_stylebox_override("hover", _panel_style(fill.lightened(0.08), CYAN if kind != "primary" else GOLD.lightened(0.2), 5, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(fill.darkened(0.09), CYAN, 5, 1))
	button.pressed.connect(callback)
	return button


func _panel_style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
