extends Control

# Multi-observatory evidence desk (also the space_segmented "observation").
#
# Interaction model (three explicit steps - a card click NEVER completes the
# mission, and nothing here ever re-runs an observation):
#   1. View Record   - reveal that record's detail (target, instrument, band,
#                       quality, SNR, scientific finding) in the detail strip.
#   2. Select Evidence - drop that record into the single evidence slot; the
#                       card gains a gold border and its button reads Selected.
#   3. Confirm Evidence - only this checks the slot against the mission and, if
#                       the band matches, shows the conclusion and submits.
# Reads-only until Confirm: no complete_current_mission, no record_free_observation.

const BG := Color("07101c")
const PANEL := Color("101d30")
const PANEL_SEL := Color("14263c")
const GOLD := Color("d8a94d")
const CYAN := Color("61d8ff")
const GREEN := Color("67d78b")
const WARN := Color("f0b24a")
const TEXT := Color("e9e5d8")
const MUTED := Color("9fb0c4")

const BANDS := ["optical", "infrared", "radio"]
const BAND_ACCENT := {"optical": Color("e8c65a"), "infrared": Color("ec9668"), "radio": Color("61d8ff")}

var selected_band := ""
var viewed_band := ""
var status_label: Label
var detail_title: Label
var detail_body: Label
var confirm_button: Button
var completed := false
var card_panels := {}
var select_buttons := {}


func _ready() -> void:
	GameManager.language_changed.connect(_build)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	card_panels.clear()
	select_buttons.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_label(GameManager.text("MULTI-OBSERVATORY EVIDENCE DESK", "多观测台证据工作台"), Vector2(32, 18), Vector2(960, 32), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var target := GameManager.current_target()
	_label(GameManager.text("Target: ", "目标：") + GameManager.dict_text(target, "name"), Vector2(50, 58), Vector2(924, 26), 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Three steps: View a record, Select it as evidence, then Confirm. Selecting never re-runs an observation.", "三步：查看记录、选择为证据、再确认提交。选择证据不会重新观测。"), Vector2(60, 88), Vector2(904, 34), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	var records := _records(target)
	var x := 70.0
	for band in BANDS:
		_add_record_card(band, records[band], Vector2(x, 138))
		x += 300.0

	# Detail strip (View Record output) - a slim strip, not a fullscreen panel.
	var strip := _panel(Vector2(70, 500), Vector2(884, 92), PANEL, Color("2a3f5a"))
	detail_title = _label(GameManager.text("View a record to read its science detail here.", "点击“查看记录”，这里会显示该记录的科学细节。"), Vector2(88, 512), Vector2(848, 24), 14, CYAN)
	detail_body = _label("", Vector2(88, 540), Vector2(848, 44), 12, TEXT)
	detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	status_label = _label(GameManager.text("No evidence selected yet.", "尚未选择证据。"), Vector2(70, 602), Vector2(884, 28), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	confirm_button = _button(GameManager.text("Confirm Evidence", "确认证据"), Vector2(560, 646), Vector2(200, 46), Color("175238"))
	confirm_button.pressed.connect(_confirm)
	add_child(confirm_button)
	var back := _button(GameManager.text("Back", "返回"), Vector2(264, 646), Vector2(200, 46), Color("15233a"))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	add_child(back)
	_refresh_cards()


func _add_record_card(band: String, rec: Dictionary, pos: Vector2) -> void:
	var accent: Color = BAND_ACCENT[band]
	var panel := _panel(pos, Vector2(266, 344), PANEL, accent)
	card_panels[band] = panel
	_label_to(panel, GameManager.text(rec["name_en"], rec["name_zh"]), Vector2(12, 12), Vector2(242, 30), 19, accent, HORIZONTAL_ALIGNMENT_CENTER)
	# band chip
	var chip := _label_to(panel, GameManager.text(rec["chip_en"], rec["chip_zh"]), Vector2(58, 46), Vector2(150, 20), 11, BG, HORIZONTAL_ALIGNMENT_CENTER)
	var chip_bg := Panel.new()
	chip_bg.position = Vector2(58, 46)
	chip_bg.size = Vector2(150, 20)
	chip_bg.add_theme_stylebox_override("panel", _flat(accent, accent, 0))
	panel.add_child(chip_bg)
	panel.move_child(chip_bg, chip.get_index())

	# always-visible measured values (fills the previously blank card)
	var rows := [
		[GameManager.text("Instrument", "仪器"), rec["instrument"]],
		[GameManager.text("Band", "波段"), GameManager.text(rec["band_en"], rec["band_zh"])],
		[GameManager.text("Quality", "质量"), rec["quality"]],
		[GameManager.text("SNR", "信噪比"), "%.1f" % float(rec["snr"])],
	]
	var y := 78.0
	for row in rows:
		_label_to(panel, str(row[0]), Vector2(16, y), Vector2(96, 18), 12, MUTED)
		_label_to(panel, str(row[1]), Vector2(112, y), Vector2(140, 18), 12, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 24.0

	var desc := _label_to(panel, GameManager.text(rec["desc_en"], rec["desc_zh"]), Vector2(16, y + 4), Vector2(236, 74), 12, TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var view := _button(GameManager.text("View Record", "查看记录"), Vector2(14, 258), Vector2(110, 38), Color("143247"))
	view.add_theme_font_size_override("font_size", 12)
	view.pressed.connect(func() -> void: _view(band))
	panel.add_child(view)

	var select := _button("", Vector2(142, 258), Vector2(110, 38), Color("164560"))
	select.add_theme_font_size_override("font_size", 12)
	select.pressed.connect(func() -> void: _select(band))
	panel.add_child(select)
	select_buttons[band] = select

	# hint line under the buttons so the two steps read as distinct
	_label_to(panel, GameManager.text("View = read  ·  Select = pick", "查看=阅读 · 选择=作为证据"), Vector2(14, 306), Vector2(238, 30), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _view(band: String) -> void:
	viewed_band = band
	var rec: Dictionary = _records(GameManager.current_target())[band]
	detail_title.text = GameManager.text(rec["name_en"], rec["name_zh"]) + "  —  " + GameManager.dict_text(GameManager.current_target(), "name")
	detail_title.add_theme_color_override("font_color", BAND_ACCENT[band])
	detail_body.text = GameManager.text(
		"Instrument %s · Band %s · Quality %s · SNR %.1f\nFinding: %s" % [rec["instrument"], rec["band_en"], rec["quality"], float(rec["snr"]), rec["finding_en"]],
		"仪器 %s · 波段 %s · 质量 %s · 信噪比 %.1f\n结论：%s" % [rec["instrument"], rec["band_zh"], rec["quality"], float(rec["snr"]), rec["finding_zh"]]
	)
	InteractionFeedback.pulse(card_panels[band], BAND_ACCENT[band])


func _select(band: String) -> void:
	if selected_band == band:
		selected_band = ""
	else:
		selected_band = band
	status_label.add_theme_color_override("font_color", CYAN if selected_band != "" else MUTED)
	if selected_band == "":
		status_label.text = GameManager.text("No evidence selected yet.", "尚未选择证据。")
	else:
		var rec: Dictionary = _records(GameManager.current_target())[selected_band]
		status_label.text = GameManager.text(
			"Evidence slot: %s. Press Confirm Evidence to submit." % rec["name_en"],
			"证据槽：%s。点击“确认证据”提交。" % rec["name_zh"])
	_refresh_cards()


func _refresh_cards() -> void:
	for band in BANDS:
		var accent: Color = BAND_ACCENT[band]
		var panel := card_panels.get(band) as Panel
		var is_sel: bool = band == selected_band
		if panel != null:
			panel.add_theme_stylebox_override("panel", _flat(PANEL_SEL if is_sel else PANEL, GOLD if is_sel else accent, 4 if is_sel else 2))
			InteractionFeedback.selection(panel, is_sel, GOLD, false, "evidence_selected")
		var button := select_buttons.get(band) as Button
		if button != null:
			button.text = GameManager.text("Selected", "已选择") if is_sel else GameManager.text("Select Evidence", "选择证据")
			button.add_theme_color_override("font_color", GREEN if is_sel else TEXT)


func _confirm() -> void:
	if completed:
		return
	if selected_band == "":
		status_label.text = GameManager.text("Select one record as evidence first.", "请先选择一份记录作为证据。")
		status_label.add_theme_color_override("font_color", WARN)
		InteractionFeedback.error(confirm_button)
		return
	var expected := _expected_record()
	if selected_band != expected:
		var need: Dictionary = _records(GameManager.current_target())[expected]
		status_label.text = GameManager.text(
			"That evidence does not answer this mission. It needs a %s record - the signal that shows %s." % [need["band_en"], need["need_hint_en"]],
			"这份证据无法回答本任务。本任务需要%s记录——能显示%s的信号。" % [need["band_zh"], need["need_hint_zh"]])
		status_label.add_theme_color_override("font_color", WARN)
		InteractionFeedback.error(select_buttons.get(selected_band, confirm_button))
		return
	completed = true
	var rec: Dictionary = _records(GameManager.current_target())[expected]
	status_label.text = GameManager.text(
		"Confirmed. %s Submitting the observation report." % rec["finding_en"],
		"确认正确。%s 正在提交观测报告。" % rec["finding_zh"])
	status_label.add_theme_color_override("font_color", GREEN)
	InteractionFeedback.success(confirm_button)
	var observation := {
		"success": true, "quality": "Good",
		"clarity": float(rec["snr"]) * 8.0, "contrast": 86.0, "detail": 84.0,
		"snr": float(rec["snr"]), "band": expected,
		"feedback_en": rec["finding_en"], "feedback_zh": rec["finding_zh"],
	}
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _expected_record() -> String:
	var level := int(GameManager.current_level().get("level_number", 43))
	var forced := str(GameManager.current_level().get("evidence_band", ""))
	if forced != "":
		return forced
	if level >= 37 and level <= 39:
		return "infrared"
	if level == 43:
		return "infrared"
	if level == 44:
		return "optical"
	return "radio"


func _records(target: Dictionary) -> Dictionary:
	var name_en := str(target.get("name_en", target.get("name", "the target")))
	var name_zh := GameManager.dict_text(target, "name")
	return {
		"optical": {
			"name_en": "Optical", "name_zh": "可见光",
			"chip_en": "VISIBLE LIGHT", "chip_zh": "可见光",
			"instrument": "Ground 8\"", "band_en": "0.4-0.7 um", "band_zh": "0.4-0.7 微米",
			"quality": GameManager.text("Fair", "一般"), "snr": 9.4,
			"desc_en": "Surface detail, star colours and the visible shape of %s." % name_en,
			"desc_zh": "%s 的表面细节、恒星颜色与可见形状。" % name_zh,
			"finding_en": "Visible light shows the bright cores but is blocked by dust lanes.",
			"finding_zh": "可见光能看到明亮的核心，但被尘埃带遮挡。",
			"need_hint_en": "visible shape and star colour", "need_hint_zh": "可见形状与恒星颜色",
		},
		"infrared": {
			"name_en": "Infrared", "name_zh": "红外",
			"chip_en": "INFRARED", "chip_zh": "红外",
			"instrument": "NIRCam/MIRI", "band_en": "1-25 um", "band_zh": "1-25 微米",
			"quality": GameManager.text("Excellent", "优秀"), "snr": 24.6,
			"desc_en": "Warm dust and structure hidden behind the visible-light dust of %s." % name_en,
			"desc_zh": "%s 中温暖的尘埃，以及可见光尘埃后隐藏的结构。" % name_zh,
			"finding_en": "Infrared sees straight through the dust to warm gas and young stars.",
			"finding_zh": "红外能穿透尘埃，看到温暖气体与年轻恒星。",
			"need_hint_en": "warm dust behind the dust lanes", "need_hint_zh": "尘埃带后的温暖尘埃",
		},
		"radio": {
			"name_en": "Radio", "name_zh": "无线电",
			"chip_en": "RADIO", "chip_zh": "无线电",
			"instrument": "FAST 500m", "band_en": "1.0-1.5 GHz", "band_zh": "1.0-1.5 吉赫",
			"quality": GameManager.text("Good", "良好"), "snr": 15.1,
			"desc_en": "Pulses, cold gas and signals from %s that never form a visible image." % name_en,
			"desc_zh": "%s 的脉冲、冷气体和永远不会形成可见图像的信号。" % name_zh,
			"finding_en": "Radio maps neutral hydrogen and pulses no camera could image.",
			"finding_zh": "无线电能绘制中性氢，并捕捉相机无法成像的脉冲。",
			"need_hint_en": "neutral hydrogen and pulses", "need_hint_zh": "中性氢与脉冲信号",
		},
	}


# ---------------------------------------------------------------- helpers
func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _flat(fill, border, 2))
	add_child(panel)
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
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _flat(color, GOLD, 2))
	button.add_theme_stylebox_override("hover", _flat(color.lightened(0.12), GOLD, 2))
	button.add_theme_stylebox_override("pressed", _flat(color.darkened(0.15), CYAN, 2))
	button.add_theme_color_override("font_color", TEXT)
	return button
