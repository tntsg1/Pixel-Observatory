extends Control

const QUALITY_COLORS := {
	"Excellent": Color(0.30, 0.95, 0.50),
	"Good": Color(0.50, 0.85, 0.30),
	"Fair": Color(0.95, 0.80, 0.20),
	"Poor": Color(1.0, 0.50, 0.20),
	"Failed": Color(1.0, 0.25, 0.25)
}

const QUALITY_ZH := {"Excellent": "优秀", "Good": "良好", "Fair": "尚可", "Poor": "较差", "Failed": "失败"}


class RadioArchiveThumbnail extends Control:
	var spectrum: Array = []
	var folded_profile: Array = []

	func configure(product: Dictionary) -> void:
		spectrum = (product.get("corrected_spectrum", product.get("clean_spectrum", [])) as Array).duplicate(true)
		folded_profile = (product.get("folded_two_cycles", []) as Array).duplicate(true)
		queue_redraw()

	func _draw() -> void:
		var bounds := Rect2(Vector2.ZERO, size)
		draw_rect(bounds, Color("07111a"), true)
		draw_rect(bounds, Color(0.30, 0.72, 0.78, 0.62), false, 1.0)
		var waterfall := Rect2(Vector2(8, 20), Vector2(size.x - 16.0, maxf(24.0, size.y * 0.52)))
		var profile_rect := Rect2(Vector2(8, waterfall.end.y + 14.0), Vector2(size.x - 16.0, maxf(20.0, size.y - waterfall.end.y - 22.0)))
		draw_string(get_theme_default_font(), Vector2(8, 13), GameManager.text("DEDISPERSED SPECTRUM", "去色散动态谱"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color(0.56, 0.88, 0.92))
		var row_count := spectrum.size()
		if row_count > 0:
			for row_index in range(row_count):
				var row := spectrum[row_index] as Array
				if row.is_empty():
					continue
				for column_index in range(row.size()):
					var strength := clampf(float(row[column_index]), 0.0, 1.0)
					var cell := Rect2(
						waterfall.position + Vector2(float(column_index) / float(row.size()) * waterfall.size.x, float(row_index) / float(row_count) * waterfall.size.y),
						Vector2(waterfall.size.x / float(row.size()) + 0.7, waterfall.size.y / float(row_count) + 0.7)
					)
					draw_rect(cell, Color(0.13 + strength * 0.64, 0.22 + strength * 0.68, 0.27 + strength * 0.62, 0.32 + strength * 0.68), true)
		else:
			draw_string(get_theme_default_font(), waterfall.get_center() + Vector2(-30, 3), "NO DATA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color(0.55, 0.62, 0.70))
		draw_rect(profile_rect, Color(0.08, 0.16, 0.20, 0.78), true)
		draw_line(Vector2(profile_rect.position.x, profile_rect.get_center().y), Vector2(profile_rect.end.x, profile_rect.get_center().y), Color(0.56, 0.72, 0.76, 0.30), 1.0)
		draw_string(get_theme_default_font(), Vector2(profile_rect.position.x, profile_rect.position.y - 4), GameManager.text("FOLDED DOUBLE PEAK", "折叠双峰轮廓"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color(0.90, 0.76, 0.42))
		if folded_profile.size() >= 2:
			var points := PackedVector2Array()
			for index in range(folded_profile.size()):
				var value := clampf(float(folded_profile[index]), 0.0, 1.0)
				points.append(Vector2(
					profile_rect.position.x + float(index) / float(folded_profile.size() - 1) * profile_rect.size.x,
					profile_rect.end.y - value * profile_rect.size.y * 0.86 - 2.0
				))
			draw_polyline(points, Color(0.76, 1.0, 0.72), 1.4, true)


var _scroll: ScrollContainer
var _entry_list: VBoxContainer


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.035, 0.070)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in range(72):
		var dot := ColorRect.new()
		dot.color = Color(0.70, 0.78, 0.95, 0.16)
		dot.position = Vector2(fmod(float(i * 151), 1000.0) + 12.0, fmod(float(i * 89), 700.0) + 54.0)
		dot.size = Vector2(2, 2)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)

	var top := Panel.new()
	top.position = Vector2(22, 12)
	top.size = Vector2(980, 52)
	top.add_theme_stylebox_override("panel", _style(Color(0.045, 0.070, 0.120, 0.96), Color(0.86, 0.62, 0.28), 2))
	add_child(top)
	var title := _label(GameManager.text("CLUB LOGBOOK", "俱乐部观测日志"), Vector2(24, 9), Vector2(620, 30), 24, Color(0.96, 0.91, 0.76))
	top.add_child(title)
	var summary := _label(_summary_text(), Vector2(540, 15), Vector2(260, 20), 12, Color(0.58, 0.84, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	top.add_child(summary)
	var back := Button.new()
	back.text = GameManager.text("Back", "返回")
	back.position = Vector2(834, 9)
	back.size = Vector2(124, 32)
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(_go_back)
	top.add_child(back)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(28, 78)
	_scroll.size = Vector2(968, 662)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.clip_contents = true
	add_child(_scroll)
	_entry_list = VBoxContainer.new()
	_entry_list.custom_minimum_size = Vector2(938, 0)
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.add_theme_constant_override("separation", 12)
	_scroll.add_child(_entry_list)
	_populate()


func _populate() -> void:
	var entries: Array = GameManager.progress.get("journal_entries", [])
	var remote_entries: Array = GameManager.progress.get("remote_observation_archive", [])
	if entries.is_empty() and remote_entries.is_empty():
		var empty := _label(GameManager.text("No observations recorded yet.\nComplete a mission to create your first observing report.", "还没有观测记录。\n完成任务后，这里会保存你的第一份观测报告。"), Vector2(0, 180), Vector2(938, 70), 18, Color(0.82, 0.86, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entry_list.add_child(empty)
		return
	var display_index := 1
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if str(entry.get("object_id", "")) == "":
			continue
		_entry_list.add_child(_build_entry_card(display_index, entry))
		display_index += 1
	for value in remote_entries:
		var entry := value as Dictionary
		_entry_list.add_child(_build_remote_observation_card(display_index, entry))
		display_index += 1


func _build_entry_card(index: int, entry: Dictionary) -> Control:
	if str(entry.get("entry_kind", "")) == "telescope_heritage":
		return _build_heritage_card(index, entry)
	if str(entry.get("observation_mode", "")) == "radio" and not (entry.get("radio_observation", {}) as Dictionary).is_empty():
		return _build_radio_archive_card(index, entry, entry.get("radio_observation", {}) as Dictionary)
	var quality := str(entry.get("observation_quality", "Good"))
	var accent: Color = QUALITY_COLORS.get(quality, Color(0.56, 0.66, 0.76))
	var maya := _entry_text(entry, "maya", "")
	var kind := _entry_text(entry, "entry_kind", "")
	var process := _entry_text(entry, "process", "")
	var extra_rows := (1 if maya != "" else 0) + (1 if process != "" else 0)
	var card := Panel.new()
	card.custom_minimum_size = Vector2(938, 194 + 24 * extra_rows)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color(0.045, 0.060, 0.105, 0.96), Color(accent.r, accent.g, accent.b, 0.78), 2))

	var name := GameManager.text(str(entry.get("object_name_en", entry.get("object_id", ""))), str(entry.get("object_name_zh", entry.get("object_id", ""))))
	var level := int(entry.get("level_completed", 0))
	card.add_child(_label("#%02d   %s" % [index, name], Vector2(18, 12), Vector2(560, 26), 20, Color(0.98, 0.92, 0.76)))
	card.add_child(_label(GameManager.text("Level %02d", "第 %02d 关") % level, Vector2(592, 16), Vector2(112, 18), 12, Color(0.56, 0.82, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
	if kind != "":
		card.add_child(_label(kind, Vector2(430, 16), Vector2(150, 18), 11, Color(0.85, 0.72, 0.98), HORIZONTAL_ALIGNMENT_RIGHT))
	var quality_display := quality if GameManager.language_mode == "en" else str(QUALITY_ZH.get(quality, quality))
	var badge := _label(quality_display, Vector2(726, 10), Vector2(182, 28), 14, accent, HORIZONTAL_ALIGNMENT_CENTER)
	badge.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04))
	badge.add_theme_constant_override("outline_size", 2)
	card.add_child(badge)

	var equipment := _entry_text(entry, "equipment", GameManager.text("Telescope setup not recorded", "未记录望远镜配置"))
	var magnification := float(entry.get("magnification", 0.0))
	var aperture := int(entry.get("objective_aperture_mm", 0))
	var focal := int(entry.get("objective_focal_length_mm", 0))
	var eyepiece := int(entry.get("eyepiece_focal_length_mm", 0))
	var optics := GameManager.text("Magnification: %.1fx | Objective: %dmm / %dmm | Eyepiece: %dmm", "倍率：%.1fx | 物镜：%dmm / %dmm | 目镜：%dmm") % [magnification, aperture, focal, eyepiece]
	var environment := _entry_text(entry, "environment", GameManager.text("Clear sky", "晴朗天空"))
	var actions := _entry_text(entry, "actions", GameManager.text("Centered and identified the target", "居中并识别目标"))
	var result := _entry_text(entry, "result", GameManager.text("Recorded " + quality + " quality.", "记录到" + quality + "质量。"))
	var knowledge := _entry_text(entry, "knowledge", _entry_text(entry, "concept_title", _entry_text(entry, "learning_text", "")))

	_add_record_line(card, GameManager.text("Equipment", "设备"), equipment, 46, Color(0.72, 0.84, 0.98))
	_add_record_line(card, GameManager.text("Optics", "光学"), optics, 70, Color(0.72, 0.84, 0.98))
	_add_record_line(card, GameManager.text("Environment", "环境"), environment, 94, Color(0.93, 0.75, 0.40))
	_add_record_line(card, GameManager.text("Operation", "操作记录"), actions, 118, Color(0.68, 0.92, 0.70))
	var y := 142.0
	if process != "":
		_add_record_line(card, GameManager.text("Process", "过程"), process, y, Color(0.80, 0.86, 0.98))
		y += 24.0
	_add_record_line(card, GameManager.text("Result", "结果"), result, y, accent)
	_add_record_line(card, GameManager.text("New knowledge", "本次新知识"), knowledge, y + 24.0, Color(0.98, 0.89, 0.55))
	if maya != "":
		_add_record_line(card, GameManager.text("Maya's summary", "玛雅总结"), "\"" + maya + "\"", y + 48.0, Color(0.72, 0.94, 0.86))
	return card


func _build_heritage_card(index: int, entry: Dictionary) -> Control:
	var card := Panel.new()
	card.custom_minimum_size = Vector2(938, 218)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_style(Color(0.040, 0.055, 0.090, 0.98), Color(0.78, 0.56, 0.28, 0.92), 2)
	)
	var title := GameManager.text(
		str(entry.get("object_name_en", "")),
		str(entry.get("object_name_zh", ""))
	)
	card.add_child(_label("#%02d   %s" % [index, title], Vector2(18, 12), Vector2(650, 28), 20, Color(0.98, 0.86, 0.56)))
	card.add_child(_label(
		GameManager.text("TELESCOPE HERITAGE", "望远镜传承"),
		Vector2(690, 14),
		Vector2(222, 24),
		12,
		Color(0.54, 0.91, 0.96),
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var text_x := 34.0
	var text_width := 878.0
	var diagram_path := str(entry.get("diagram", ""))
	if diagram_path != "" and ResourceLoader.exists(diagram_path):
		var diagram := TextureRect.new()
		diagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		diagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		diagram.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		diagram.texture = load(diagram_path)
		diagram.position = Vector2(22, 52)
		diagram.size = Vector2(150, 142)
		diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(diagram)
		var diagram_caption := GameManager.text(
			str(entry.get("diagram_caption_en", "")),
			str(entry.get("diagram_caption_zh", ""))
		)
		if diagram_caption != "":
			var caption_back := ColorRect.new()
			caption_back.position = Vector2(22, 170)
			caption_back.size = Vector2(150, 24)
			caption_back.color = Color(0.015, 0.025, 0.050, 0.88)
			caption_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(caption_back)
			var caption := _label(
				diagram_caption,
				Vector2(28, 171),
				Vector2(138, 22),
				10,
				Color(0.84, 0.91, 0.96),
				HORIZONTAL_ALIGNMENT_CENTER
			)
			caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			caption.max_lines_visible = 2
			card.add_child(caption)
		text_x = 188.0
		text_width = 724.0

	_add_heritage_line(
		card,
		GameManager.text("BEFORE", "此前"),
		GameManager.text(str(entry.get("before_en", "")), str(entry.get("before_zh", ""))),
		text_x,
		52.0,
		text_width,
		Color(0.72, 0.82, 0.94)
	)
	_add_heritage_line(
		card,
		GameManager.text("BREAKTHROUGH", "突破"),
		GameManager.text(str(entry.get("breakthrough_en", "")), str(entry.get("breakthrough_zh", ""))),
		text_x,
		100.0,
		text_width,
		Color(0.98, 0.78, 0.38)
	)
	_add_heritage_line(
		card,
		GameManager.text("LEARNED BY DOING", "亲手学到"),
		GameManager.text(str(entry.get("learned_en", "")), str(entry.get("learned_zh", ""))),
		text_x,
		156.0,
		text_width,
		Color(0.58, 0.94, 0.76)
	)
	return card


func _build_radio_archive_card(index: int, entry: Dictionary, observation: Dictionary) -> Control:
	var product: Dictionary = observation.get("radio_data_product", entry.get("radio_data_product", {})) as Dictionary
	var report: Dictionary = product.get("report", {}) as Dictionary
	var sky: Dictionary = observation.get("sky_position", report.get("sky_position", entry.get("sky_position", {}))) as Dictionary
	var target_en := str(entry.get("target_name_en", entry.get("object_name_en", observation.get("radio_target_name", report.get("target_name", entry.get("target_id", "FAST target"))))))
	var target_zh := str(entry.get("target_name_zh", entry.get("object_name_zh", observation.get("radio_target_name", report.get("target_name", entry.get("target_id", "FAST 目标"))))))
	var period := float(observation.get("pulse_period_ms", report.get("trial_period_ms", entry.get("pulse_period_ms", 0.0))))
	var dm := float(observation.get("dispersion_measure", report.get("trial_dm", entry.get("dispersion_measure", 0.0))))
	var width := float(observation.get("pulse_width_ms", product.get("pulse_width_ms", entry.get("pulse_width_ms", 0.0))))
	var snr := float(observation.get("snr", product.get("snr", entry.get("snr", 0.0))))
	var confidence := float(observation.get("confidence", product.get("confidence", entry.get("confidence", 0.0))))
	var candidate := str(observation.get("candidate_model", report.get("candidate_model", entry.get("candidate_model", "PULSAR"))))
	var utc := str(entry.get("observation_utc", ""))
	if utc == "":
		var observed_at := float(observation.get("observed_at_unix", entry.get("observed_at_unix", 0.0)))
		utc = Time.get_datetime_string_from_unix_time(observed_at, true) + "Z" if observed_at > 0.0 else "UTC recorded with report"
	var card := Panel.new()
	card.custom_minimum_size = Vector2(938, 236)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color(0.030, 0.058, 0.074, 0.98), Color(0.34, 0.82, 0.78, 0.88), 2))
	card.add_child(_label("#%02d   %s" % [index, GameManager.text(target_en, target_zh)], Vector2(18, 12), Vector2(510, 28), 20, Color(0.88, 0.96, 0.84)))
	card.add_child(_label(GameManager.text("FAST SIGNAL ARCHIVE", "FAST 信号档案"), Vector2(570, 15), Vector2(338, 20), 13, Color(0.46, 0.88, 0.86), HORIZONTAL_ALIGNMENT_RIGHT))
	card.add_child(_label("%s · %s" % [candidate, str(sky.get("label", ""))], Vector2(20, 44), Vector2(548, 20), 12, Color(0.94, 0.78, 0.46)))
	_add_record_line(card, GameManager.text("Timing", "计时"), GameManager.text("P %.3f ms | DM %.2f pc/cm³ | Width %.2f ms", "周期 %.3f ms | DM %.2f pc/cm³ | 脉宽 %.2f ms") % [period, dm, width], 70, Color(0.60, 0.88, 0.94))
	_add_record_line(card, GameManager.text("Recovered pulse", "恢复脉冲"), GameManager.text("SNR %.1f | Confidence %.0f%% | seven bands aligned", "信噪比 %.1f | 置信度 %.0f%% | 七条频段已对齐") % [snr, confidence * 100.0], 96, Color(0.70, 0.96, 0.72))
	_add_record_line(card, GameManager.text("Sky position", "天区位置"), str(sky.get("label", GameManager.text("recorded with the timing packet", "已写入计时数据包"))), 122, Color(0.94, 0.78, 0.48))
	_add_record_line(card, "UTC", utc, 148, Color(0.66, 0.76, 0.86))
	var thumbnail := RadioArchiveThumbnail.new()
	thumbnail.name = "RadioArchiveThumbnail"
	thumbnail.position = Vector2(590, 46)
	thumbnail.size = Vector2(318, 164)
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.configure(product)
	card.add_child(thumbnail)
	return card


func _build_remote_observation_card(index: int, entry: Dictionary) -> Control:
	var instrument_kind := str(entry.get("instrument_kind", "space"))
	if instrument_kind == "radio" and not (entry.get("radio_data_product", {}) as Dictionary).is_empty():
		return _build_radio_archive_card(index, entry, entry.get("radio_observation", entry) as Dictionary)
	var quality := str(entry.get("quality", "Good"))
	var accent := Color(0.30, 0.82, 0.76) if instrument_kind == "space" else Color(0.56, 0.78, 0.92)
	var card := Panel.new()
	card.custom_minimum_size = Vector2(938, 190)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color(0.034, 0.052, 0.074, 0.98), accent, 2))
	var target_name := GameManager.text(
		str(entry.get("target_name_en", entry.get("target_id", ""))),
		str(entry.get("target_name_zh", entry.get("target_id", ""))))
	var record_title := GameManager.text("Infrared Composite Archive", "红外合成图档案") \
		if instrument_kind == "space" else GameManager.text("FAST Signal Archive", "FAST 信号档案")
	card.add_child(_label("#%02d   %s" % [index, target_name], Vector2(18, 12), Vector2(560, 26), 20, Color(0.98, 0.92, 0.76)))
	card.add_child(_label(record_title, Vector2(590, 14), Vector2(320, 22), 13, accent, HORIZONTAL_ALIGNMENT_RIGHT))
	var category := GameManager.text(str(entry.get("category_en", "")), str(entry.get("category_zh", "")))
	var evidence := str(entry.get("result_kind", "infrared_composite")).replace("_", " ").capitalize()
	var setup := ""
	if instrument_kind == "space":
		setup = GameManager.text(
			"Instrument: %s | Filter: %s | Exposure: %.0f s",
			"仪器：%s | 滤镜：%s | 曝光：%.0f 秒") % [
				str(entry.get("instrument", "space")),
				str(entry.get("filter", "")),
				float(entry.get("exposure", 0.0))]
	else:
		setup = GameManager.text(
			"Evidence: %s | Integration: %.0f s | SNR: %.1f",
			"证据：%s | 积分：%.0f 秒 | 信噪比：%.1f") % [
				evidence,
				float(entry.get("exposure", 0.0)),
				float(entry.get("snr", 0.0))]
	_add_record_line(card, GameManager.text("Program", "计划"), category, 48, accent)
	_add_record_line(card, GameManager.text("Observation", "观测参数"), setup, 76, Color(0.76, 0.86, 0.96))
	_add_record_line(card, GameManager.text("Quality", "质量"), quality, 104, Color(0.76, 0.92, 0.72))
	_add_record_line(card, GameManager.text("Science note", "科学说明"),
		GameManager.text(str(entry.get("science_en", "")), str(entry.get("science_zh", ""))), 132, Color(0.96, 0.86, 0.58))
	_add_record_line(card, "UTC", str(entry.get("observation_utc", "")), 160, Color(0.62, 0.74, 0.82))
	return card


func _add_heritage_line(parent: Control, heading: String, value: String, x: float, y: float, width: float, color: Color) -> void:
	var heading_label := _label(heading, Vector2(x, y), Vector2(width, 18), 11, color)
	parent.add_child(heading_label)
	var content := _label(value, Vector2(x, y + 18.0), Vector2(width, 34), 11, Color(0.86, 0.88, 0.91))
	content.max_lines_visible = 2
	parent.add_child(content)


func _add_record_line(parent: Control, heading: String, value: String, y: float, color: Color) -> void:
	var key := _label(heading + ":", Vector2(18, y), Vector2(120, 18), 11, color)
	parent.add_child(key)
	var content := _label(value, Vector2(142, y), Vector2(760, 18), 11, Color(0.84, 0.86, 0.90))
	content.clip_text = true
	content.max_lines_visible = 1
	parent.add_child(content)


func _entry_text(entry: Dictionary, prefix: String, fallback: String) -> String:
	var language_key := prefix + "_en" if GameManager.language_mode == "en" else prefix + "_zh"
	return str(entry.get(language_key, fallback))


func _summary_text() -> String :
	var entries: Array = GameManager.progress.get("journal_entries", [])
	var objects: Array = GameManager.progress.get("observed_objects", [])
	return GameManager.text("%d sessions | %d objects" % [entries.size(), objects.size()], "%d 次记录 | %d 个天体" % [entries.size(), objects.size()])


func _go_back() -> void:
	GameManager.set_observatory_spawn("journal")
	GameManager.go("observatory")


func _label(text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func _on_language_changed() -> void:
	_build()
