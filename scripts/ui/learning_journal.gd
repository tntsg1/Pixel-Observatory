extends Control

const QUALITY_COLORS := {
	"Excellent": Color(0.30, 0.95, 0.50),
	"Good": Color(0.50, 0.85, 0.30),
	"Fair": Color(0.95, 0.80, 0.20),
	"Poor": Color(1.0, 0.50, 0.20),
	"Failed": Color(1.0, 0.25, 0.25)
}

const QUALITY_ZH := {"Excellent": "优秀", "Good": "良好", "Fair": "尚可", "Poor": "较差", "Failed": "失败"}

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
	if entries.is_empty():
		var empty := _label(GameManager.text("No observations recorded yet.\nComplete a mission to create your first observing report.", "还没有观测记录。\n完成任务后，这里会保存你的第一份观测报告。"), Vector2(0, 180), Vector2(938, 70), 18, Color(0.82, 0.86, 0.94), HORIZONTAL_ALIGNMENT_CENTER)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_entry_list.add_child(empty)
		return
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if str(entry.get("object_id", "")) == "":
			continue
		_entry_list.add_child(_build_entry_card(i + 1, entry))


func _build_entry_card(index: int, entry: Dictionary) -> Control:
	if str(entry.get("entry_kind", "")) == "telescope_heritage":
		return _build_heritage_card(index, entry)
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
