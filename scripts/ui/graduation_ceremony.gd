extends Control

const GOLD := Color(0.98, 0.76, 0.28)
const PALE_GOLD := Color(1.0, 0.91, 0.62)
const CYAN := Color(0.42, 0.86, 1.0)
const WARM_TEXT := Color(0.96, 0.92, 0.82)
const MUTED := Color(0.68, 0.76, 0.84)
const NAVY := Color(0.018, 0.032, 0.064, 0.98)
const ROOM_BG := "res://assets/reference/observatory_room_clean_bg_1024.png"
const BADGE_TEXTURE := "res://assets/mission_complete/badge_shield_96.png"
const CREDIT_TEXTURE := "res://assets/mission_complete/credit_coin_64_clean.png"

var ceremony_panel: Panel
var portrait: TextureRect
var badge: TextureRect
var confetti: Array[ColorRect] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	GameManager.mark_graduation_presented()
	_build()
	_play_entrance()


func _build() -> void:
	var background := TextureRect.new()
	background.texture = load(ROOM_BG)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.32, 0.42, 0.56, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var night := ColorRect.new()
	night.color = Color(0.0, 0.01, 0.035, 0.73)
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)
	_build_stars()

	ceremony_panel = Panel.new()
	ceremony_panel.position = Vector2(94, 58)
	ceremony_panel.size = Vector2(836, 650)
	ceremony_panel.pivot_offset = ceremony_panel.size * 0.5
	ceremony_panel.add_theme_stylebox_override("panel", _style(NAVY, GOLD, 3, 6))
	add_child(ceremony_panel)
	_add_corner_pins(ceremony_panel)

	_label(ceremony_panel, GameManager.text("ASTRONOMY CLUB GRADUATION", "天文俱乐部毕业典礼"), Vector2(28, 18), Vector2(780, 42), 29, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(ceremony_panel, GameManager.text("The final observation is complete", "最后一次观测已经完成"), Vector2(28, 62), Vector2(780, 24), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_line(ceremony_panel, Vector2(36, 96), Vector2(764, 1), Color(0.78, 0.56, 0.24, 0.78))

	portrait = MayaPortrait.create(
		ceremony_panel,
		"MayaGraduationPortrait",
		MayaPortrait.DISCOVER,
		Vector2(44, 112),
		Vector2(150, 182)
	)
	var maya_panel := Panel.new()
	maya_panel.position = Vector2(212, 116)
	maya_panel.size = Vector2(574, 174)
	maya_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.060, 0.095, 0.96), Color(0.27, 0.58, 0.72), 2, 4))
	ceremony_panel.add_child(maya_panel)
	_label(maya_panel, GameManager.text("MAYA", "玛雅"), Vector2(20, 13), Vector2(530, 22), 13, CYAN)
	var maya_label := _label(maya_panel, GameManager.text(
		"You began by finding the Moon. Now you can choose an instrument, read the atmosphere, align its optics, track a moving sky, and explain what the signal means. I am proud of the observer you became.",
		"你从寻找月球开始。现在，你已经能选择仪器、读懂大气、校准光路、追踪转动的天空，并解释信号意味着什么。我为你成长为真正的观测者而骄傲。"
	), Vector2(20, 42), Vector2(530, 112), 16, WARM_TEXT)
	maya_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	maya_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var certificate := Panel.new()
	certificate.position = Vector2(44, 314)
	certificate.size = Vector2(742, 214)
	certificate.add_theme_stylebox_override("panel", _style(Color(0.12, 0.095, 0.045, 0.98), Color(0.95, 0.73, 0.26), 2, 4))
	ceremony_panel.add_child(certificate)
	badge = _texture(certificate, BADGE_TEXTURE, Vector2(28, 46), Vector2(112, 112))
	badge.pivot_offset = badge.size * 0.5
	_label(certificate, GameManager.text("YOUNG OBSERVER", "青年观测员"), Vector2(162, 26), Vector2(540, 34), 25, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var certificate_body := _label(certificate, GameManager.text(
		"This certifies completion of the Pixel Observatory observing program.",
		"兹证明你已完成《像素天文台》全部观测课程。"
	), Vector2(162, 67), Vector2(540, 44), 15, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	certificate_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(certificate, _stats_text(), Vector2(162, 118), Vector2(540, 27), 14, Color(0.72, 0.92, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	_label(certificate, GameManager.text("Badge awarded and saved permanently", "徽章已颁发并永久保存"), Vector2(162, 154), Vector2(540, 24), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var credit_icon := _texture(ceremony_panel, CREDIT_TEXTURE, Vector2(248, 550), Vector2(34, 34))
	credit_icon.modulate = Color(1.0, 0.90, 0.58)
	_label(ceremony_panel, GameManager.text(
		"All Credits, badges, lessons, and logbook entries are preserved.",
		"全部积分、徽章、课程与观测日志均已保存。"
	), Vector2(288, 555), Vector2(500, 24), 14, MUTED)

	var continue_button := _button(ceremony_panel, GameManager.text("Return to Observatory", "返回天文台"), Vector2(164, 594), Vector2(244, 42), Color(0.08, 0.34, 0.20), Color(0.52, 0.90, 0.54))
	continue_button.name = "ReturnToObservatoryButton"
	continue_button.pressed.connect(_return_to_observatory)
	var journal_button := _button(ceremony_panel, GameManager.text("Open Club Logbook", "打开俱乐部日志"), Vector2(428, 594), Vector2(244, 42), Color(0.06, 0.18, 0.36), Color(0.42, 0.74, 1.0))
	journal_button.name = "OpenGraduationLogbookButton"
	journal_button.pressed.connect(_open_logbook)
	_build_confetti()


func _stats_text() -> String:
	var completed := (GameManager.progress.get("completed_levels", []) as Array).size()
	var observed := (GameManager.progress.get("observed_objects", []) as Array).size()
	var entries := (GameManager.progress.get("journal_entries", []) as Array).size()
	var credits := int(GameManager.progress.get("credits", 0))
	return GameManager.text(
		"%d lessons  |  %d objects  |  %d logs  |  %d Credits" % [completed, observed, entries, credits],
		"%d 门课程  |  %d 个天体  |  %d 篇日志  |  %d 积分" % [completed, observed, entries, credits]
	)


func _build_stars() -> void:
	var positions := [
		Vector2(48, 80), Vector2(156, 42), Vector2(278, 86), Vector2(746, 44),
		Vector2(936, 104), Vector2(58, 304), Vector2(960, 352), Vector2(92, 620),
		Vector2(904, 688), Vector2(836, 126), Vector2(188, 714), Vector2(968, 548)
	]
	for index in range(positions.size()):
		var star := ColorRect.new()
		var star_size := 3.0 if index % 3 == 0 else 2.0
		star.position = positions[index]
		star.size = Vector2(star_size, star_size)
		star.color = PALE_GOLD if index % 2 == 0 else CYAN
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)


func _build_confetti() -> void:
	var colors := [GOLD, PALE_GOLD, CYAN, Color(0.58, 0.94, 0.72)]
	for index in range(24):
		var piece := ColorRect.new()
		var on_left := index % 2 == 0
		var x := 118.0 + float((index * 67) % 132) if on_left else 776.0 + float((index * 43) % 128)
		piece.position = Vector2(x, 92.0 + float((index * 29) % 120))
		piece.size = Vector2(3, 9) if index % 3 else Vector2(7, 3)
		piece.color = colors[index % colors.size()]
		piece.rotation = float(index % 5) * 0.24
		piece.modulate.a = 0.0
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(piece)
		confetti.append(piece)


func _play_entrance() -> void:
	modulate.a = 0.0
	ceremony_panel.scale = Vector2(0.965, 0.965)
	portrait.modulate.a = 0.0
	portrait.position.x -= 18.0
	badge.scale = Vector2(0.45, 0.45)
	badge.rotation = -0.10
	var reduced := InteractionFeedback.is_reduced_motion()
	var tween := create_tween().bind_node(self).set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.24)
	tween.tween_property(ceremony_panel, "scale", Vector2.ONE, 0.42 if not reduced else 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.30).set_delay(0.12)
	tween.tween_property(portrait, "position:x", portrait.position.x + 18.0, 0.42 if not reduced else 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "scale", Vector2.ONE, 0.52 if not reduced else 0.20).set_delay(0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge, "rotation", 0.0, 0.52 if not reduced else 0.20).set_delay(0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if reduced:
		return
	for index in range(confetti.size()):
		var piece := confetti[index]
		var fall := create_tween().bind_node(piece).set_parallel(true)
		var delay := 0.18 + float(index % 8) * 0.035
		fall.tween_property(piece, "modulate:a", 0.9, 0.14).set_delay(delay)
		fall.tween_property(piece, "position:y", piece.position.y + 210.0 + float(index % 5) * 18.0, 1.15).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(piece, "position:x", piece.position.x + (-20.0 + float(index % 7) * 7.0), 1.15).set_delay(delay)
		fall.tween_property(piece, "rotation", piece.rotation + 2.0 + float(index % 4), 1.15).set_delay(delay)
		fall.tween_property(piece, "modulate:a", 0.0, 0.28).set_delay(delay + 0.87)


func _return_to_observatory() -> void:
	GameManager.mark_graduation_presented()
	GameManager.set_observatory_spawn("journal")
	GameManager.update_room_guidance_for_level()
	GameManager.go("observatory")


func _open_logbook() -> void:
	GameManager.mark_graduation_presented()
	GameManager.set_observatory_spawn("journal")
	GameManager.go("journal")


func _texture(parent: Control, path: String, pos: Vector2, size_value: Vector2) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.texture = load(path)
	texture_rect.position = pos
	texture_rect.size = size_value
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture_rect)
	return texture_rect


func _label(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Control, value: String, pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", WARM_TEXT)
	button.add_theme_stylebox_override("normal", _style(fill, border, 2, 4))
	button.add_theme_stylebox_override("hover", _style(fill.lightened(0.12), border.lightened(0.12), 2, 4))
	button.add_theme_stylebox_override("pressed", _style(fill.darkened(0.12), border, 2, 4))
	parent.add_child(button)
	InteractionFeedback.bind_button(button)
	return button


func _line(parent: Control, pos: Vector2, size_value: Vector2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.position = pos
	line.size = size_value
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	return line


func _add_corner_pins(parent: Control) -> void:
	var positions := [
		Vector2(9, 9), Vector2(parent.size.x - 17, 9),
		Vector2(9, parent.size.y - 17), Vector2(parent.size.x - 17, parent.size.y - 17)
	]
	for pos in positions:
		var pin := ColorRect.new()
		pin.position = pos
		pin.size = Vector2(8, 8)
		pin.color = PALE_GOLD
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(pin)


func _style(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
