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
var stage_root: Control
var stage_indicator: Label
var back_button: Button
var next_button: Button
var stage_index := 0
var stage_transition: Tween

const STAGE_COUNT := 4


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
	ceremony_panel.position = Vector2(70, 40)
	ceremony_panel.size = Vector2(884, 688)
	ceremony_panel.pivot_offset = ceremony_panel.size * 0.5
	ceremony_panel.add_theme_stylebox_override("panel", _style(NAVY, GOLD, 3, 6))
	add_child(ceremony_panel)
	_add_corner_pins(ceremony_panel)

	_label(ceremony_panel, GameManager.text("ASTRONOMY CLUB GRADUATION", "天文俱乐部毕业典礼"), Vector2(28, 14), Vector2(828, 38), 27, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(ceremony_panel, GameManager.text("The last lesson ends. Your own observing begins.", "最后一课结束了。属于你的观测，从现在开始。"), Vector2(28, 51), Vector2(828, 22), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	stage_indicator = _label(ceremony_panel, "", Vector2(42, 76), Vector2(800, 22), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_line(ceremony_panel, Vector2(34, 103), Vector2(816, 1), Color(0.78, 0.56, 0.24, 0.78))

	stage_root = Control.new()
	stage_root.name = "GraduationStageRoot"
	stage_root.position = Vector2(34, 112)
	stage_root.size = Vector2(816, 500)
	stage_root.clip_contents = true
	ceremony_panel.add_child(stage_root)

	back_button = _button(ceremony_panel, GameManager.text("Back", "上一步"), Vector2(124, 628), Vector2(180, 42), Color(0.10, 0.14, 0.22), Color(0.48, 0.58, 0.70))
	back_button.name = "GraduationBackButton"
	back_button.pressed.connect(_previous_stage)
	next_button = _button(ceremony_panel, GameManager.text("Continue", "继续"), Vector2(580, 628), Vector2(180, 42), Color(0.08, 0.34, 0.20), Color(0.52, 0.90, 0.54))
	next_button.name = "GraduationNextButton"
	next_button.pressed.connect(_next_stage)
	var journal_button := _button(ceremony_panel, GameManager.text("Open Logbook", "打开观测档案"), Vector2(324, 628), Vector2(236, 42), Color(0.06, 0.18, 0.36), Color(0.42, 0.74, 1.0))
	journal_button.name = "OpenGraduationLogbookButton"
	journal_button.pressed.connect(_open_logbook)
	_show_stage(0, false)
	_build_confetti()


func _show_stage(next_stage: int, animate := true) -> void:
	stage_index = clampi(next_stage, 0, STAGE_COUNT - 1)
	if stage_transition != null and stage_transition.is_valid():
		stage_transition.kill()
	for child in stage_root.get_children():
		stage_root.remove_child(child)
		child.queue_free()
	stage_indicator.text = _stage_indicator_text()
	back_button.visible = stage_index > 0
	next_button.text = GameManager.text("Begin Independent Night", "开始独立观测") if stage_index == STAGE_COUNT - 1 \
		else GameManager.text("Continue", "继续")
	next_button.name = "BeginIndependentNightButton" if stage_index == STAGE_COUNT - 1 else "GraduationNextButton"
	match stage_index:
		0:
			_build_recap_stage()
		1:
			_build_archive_stage()
		2:
			_build_access_stage()
		_:
			_build_independent_night_stage()
	if animate:
		stage_root.position.x = 50.0
		stage_root.modulate.a = 0.0
		var duration := 0.12 if InteractionFeedback.is_reduced_motion() else 0.28
		stage_transition = create_tween().bind_node(stage_root).set_parallel(true)
		stage_transition.tween_property(stage_root, "position:x", 34.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		stage_transition.tween_property(stage_root, "modulate:a", 1.0, duration)


func _stage_indicator_text() -> String:
	var names := [
		GameManager.text("LOOK BACK", "回望"),
		GameManager.text("YOUR ARCHIVE", "你的档案"),
		GameManager.text("ACCESS OPEN", "权限开放"),
		GameManager.text("FIRST NIGHT", "独立第一夜"),
	]
	var pieces: Array[String] = []
	for index in range(names.size()):
		var marker := "● " if index == stage_index else "○ "
		pieces.append(marker + names[index])
	return "   ·   ".join(pieces)


func _build_recap_stage() -> void:
	portrait = MayaPortrait.create(stage_root, "MayaGraduationPortrait", MayaPortrait.DISCOVER, Vector2(18, 26), Vector2(166, 300))
	badge = _texture(stage_root, BADGE_TEXTURE, Vector2(44, 350), Vector2(112, 112))
	badge.name = "YoungObserverBadge"
	badge.pivot_offset = badge.size * 0.5
	_label(stage_root, GameManager.text("YOUNG OBSERVER", "青年观测员"), Vector2(18, 462), Vector2(166, 22), 12, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var title := _label(stage_root, GameManager.text("LOOK HOW FAR YOU CAME", "看看你一路走了多远"), Vector2(204, 18), Vector2(582, 34), 23, PALE_GOLD)
	title.name = "GraduationRecapTitle"
	var maya_copy := _label(stage_root, GameManager.text(
		"You began by trying to hold the Moon inside a guide. Tonight you chose instruments, aligned mirrors, judged the sky, and recovered a pulsar from noise. Those were not button presses. They were observing decisions.",
		"你最初只是努力把月球留在准星里。今晚，你已经能选择仪器、校准镜面、判断天空，并从噪声中找回一颗脉冲星。那不是一串按键，而是一次次真正的观测判断。"
	), Vector2(204, 58), Vector2(582, 82), 15, WARM_TEXT)
	maya_copy.name = "GraduationRecapCopy"
	maya_copy.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	maya_copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	maya_copy.clip_text = true
	maya_copy.custom_minimum_size = Vector2.ZERO
	maya_copy.position = Vector2(204, 58)
	maya_copy.size = Vector2(582, 82)

	var milestones := [
		[GameManager.text("FIRST LIGHT", "第一次看见"), GameManager.text("Found and centered the Moon with your own eyes.", "用自己的眼睛找到月球，并把它移入视野中心。")],
		[GameManager.text("BUILT THE INSTRUMENT", "亲手组装仪器"), GameManager.text("Learned why focus, collimation, stability, and tracking matter.", "理解了调焦、准直、稳定与追踪为什么重要。")],
		[GameManager.text("READ INVISIBLE LIGHT", "读懂不可见光"), GameManager.text("Turned infrared frames into evidence about dust and hidden structure.", "把红外帧转化成尘埃与隐藏结构的证据。")],
		[GameManager.text("FOUND THE RHYTHM", "从噪声中找到节拍"), GameManager.text("Rejected interference and proved a repeating radio signal.", "剔除干扰，并证明一个射电信号正在稳定重复。")],
	]
	for index in range(milestones.size()):
		var y := 152.0 + float(index) * 76.0
		var row := Panel.new()
		row.position = Vector2(204, y)
		row.size = Vector2(582, 62)
		row.add_theme_stylebox_override("panel", _style(Color(0.025, 0.055, 0.088, 0.96), Color(0.20, 0.46, 0.62, 0.88), 1, 4))
		stage_root.add_child(row)
		_label(row, "%02d" % (index + 1), Vector2(14, 12), Vector2(42, 36), 19, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_label(row, str(milestones[index][0]), Vector2(68, 8), Vector2(490, 20), 13, CYAN)
		var detail := _label(row, str(milestones[index][1]), Vector2(68, 28), Vector2(490, 28), 13, WARM_TEXT)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.clip_text = true


func _build_archive_stage() -> void:
	var title := _label(stage_root, GameManager.text("YOUR OBSERVING RECORD", "这是你的观测档案"), Vector2(18, 14), Vector2(780, 34), 23, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "GraduationArchiveTitle"
	_label(stage_root, _stats_text(), Vector2(48, 54), Vector2(720, 26), 15, Color(0.72, 0.92, 0.76), HORIZONTAL_ALIGNMENT_CENTER)
	var archive_copy := _label(stage_root, GameManager.text(
		"The archive is not a checklist. It is the trail of questions you learned to answer.",
		"档案不是通关清单，而是你学会回答过的那些问题留下的轨迹。"
	), Vector2(64, 84), Vector2(688, 44), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	archive_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var highlights := _archive_highlights()
	for index in range(3):
		var card := Panel.new()
		card.name = "GraduationArchiveCard%d" % index
		card.position = Vector2(18 + index * 266, 142)
		card.size = Vector2(250, 270)
		card.add_theme_stylebox_override("panel", _style(Color(0.028, 0.046, 0.080, 0.98), Color(0.26, 0.56, 0.70, 0.86), 2, 4))
		stage_root.add_child(card)
		var entry: Dictionary = highlights[index]
		_label(card, GameManager.text("ARCHIVE %02d" % (index + 1), "档案 %02d" % (index + 1)), Vector2(14, 12), Vector2(222, 20), 11, CYAN)
		var entry_name := _archive_entry_name(entry)
		var name_label := _label(card, entry_name, Vector2(14, 42), Vector2(222, 54), 18, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		_line(card, Vector2(22, 105), Vector2(206, 1), Color(0.34, 0.58, 0.68, 0.55))
		_label(card, _archive_entry_kind(entry), Vector2(14, 118), Vector2(222, 24), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		var record_copy := _label(card, _archive_entry_summary(entry), Vector2(18, 150), Vector2(214, 88), 13, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		record_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		record_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		record_copy.clip_text = true
		_label(card, _archive_entry_quality(entry), Vector2(18, 240), Vector2(214, 18), 12, Color(0.64, 0.92, 0.70), HORIZONTAL_ALIGNMENT_CENTER)

	var preserve := _label(stage_root, GameManager.text(
		"Every lesson, badge, image, and signal record remains available in the Club Logbook.",
		"每一课、每枚徽章、每张图像与每份信号记录，都会继续保存在俱乐部观测档案中。"
	), Vector2(56, 430), Vector2(704, 46), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	preserve.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_access_stage() -> void:
	var title := _label(stage_root, GameManager.text("EQUIPMENT & ACCESS HANDOVER", "器材与权限交接"), Vector2(18, 14), Vector2(780, 34), 23, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "GraduationAccessTitle"
	var intro := _label(stage_root, GameManager.text(
		"Unlocked optical telescopes are now yours. Space and FAST remain remote research facilities.",
		"你解锁的俱乐部光学望远镜现已交给你；国家级科研设施仍通过远程权限使用。"
	), Vector2(64, 54), Vector2(688, 52), 14, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if GameManager.language_mode == "en" else TextServer.AUTOWRAP_ARBITRARY
	intro.custom_minimum_size = Vector2.ZERO
	intro.size = Vector2(688, 52)
	intro.clip_text = true
	var owned_names := _owned_optical_names()
	var access_rows := [
		{
			"title": GameManager.text("PERSONAL OPTICAL EQUIPMENT", "个人光学设备"),
			"status": GameManager.text("OWNERSHIP TRANSFERRED", "所有权已移交"),
			"open": not owned_names.is_empty(),
			"copy": GameManager.text(
				"%s\nFREE REBUILD\nMODIFY\nOBSERVE" % "\n".join(owned_names),
				"%s\n自由拆装 · 改装 · 观测" % "\n".join(owned_names)),
		},
		{
			"title": GameManager.text("SPACE INFRARED", "空间红外观测"),
			"status": GameManager.text("REMOTE ACCESS GRANTED", "远程权限已开放"),
			"open": GameManager.remote_free_unlocked("space"),
			"copy": GameManager.text("REQUEST OBSERVING TIME\nOPERATE REMOTELY\nINSTITUTIONAL FACILITY", "申请观测时间\n远程操作深空计划\n设施仍属科研机构"),
		},
		{
			"title": GameManager.text("FAST RADIO", "FAST 射电观测"),
			"status": GameManager.text("REMOTE ACCESS GRANTED", "远程权限已开放"),
			"open": GameManager.remote_free_unlocked("radio"),
			"copy": GameManager.text("REQUEST ARRAY TIME\nBUILD RADIO EVIDENCE\nFAST IS NOT PERSONAL GEAR", "申请阵列时间\n建立射电观测证据\nFAST 不属于个人设备"),
		},
	]
	for index in range(access_rows.size()):
		var row: Dictionary = access_rows[index]
		var card := Panel.new()
		card.name = "GraduationAccessCard%d" % index
		card.position = Vector2(18 + index * 266, 128)
		card.size = Vector2(250, 258)
		var is_open := bool(row.get("open", false))
		card.add_theme_stylebox_override("panel", _style(
			Color(0.025, 0.065, 0.070, 0.98) if is_open else Color(0.055, 0.055, 0.070, 0.98),
			Color(0.35, 0.86, 0.62) if is_open else Color(0.52, 0.52, 0.56), 2, 4))
		stage_root.add_child(card)
		var card_title := _label(card, str(row.get("title", "")), Vector2(14, 14), Vector2(222, 42), 15, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		card_title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		card_title.custom_minimum_size = Vector2.ZERO
		card_title.size = Vector2(222, 42)
		card_title.clip_text = true
		_label(card, str(row.get("status", "")) if is_open else GameManager.text("LOCKED", "未开放"), Vector2(14, 62), Vector2(222, 28), 12, Color(0.48, 0.96, 0.66) if is_open else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_line(card, Vector2(28, 101), Vector2(194, 1), Color(0.32, 0.62, 0.66, 0.52))
		var copy := _label(card, str(row.get("copy", "")), Vector2(22, 110), Vector2(206, 132), 14, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		copy.name = "GraduationAccessCopy%d" % index
		copy.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		copy.custom_minimum_size = Vector2.ZERO
		copy.size = Vector2(206, 132)
		copy.clip_text = true
		copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var maya := _label(stage_root, GameManager.text(
		"Maya: These telescopes were club gear you borrowed for class. Now the optical ones you unlocked are yours. Rebuild them, modify them, and point them where you choose. Space and FAST stay public facilities: you have access, not ownership.",
		"玛雅：这些镜子以前是借给你上课的。现在课程结束了，你解锁的光学望远镜归你了。以后想拆、想换、想拿去哪片天空试，都由你决定。空间望远镜和 FAST 不一样——交给你的是操作权限，不是那两座设施。"
	), Vector2(48, 400), Vector2(720, 76), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	maya.name = "GraduationAccessDialogue"
	maya.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if GameManager.language_mode == "en" else TextServer.AUTOWRAP_ARBITRARY
	maya.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	maya.custom_minimum_size = Vector2.ZERO
	maya.size = Vector2(720, 76)
	maya.clip_text = true


func _owned_optical_names() -> Array[String]:
	var names: Array[String] = []
	for family in GameManager.owned_optical_telescope_families():
		names.append(GameManager.optical_telescope_family_name(family))
	return names


func _build_independent_night_stage() -> void:
	var title := _label(stage_root, GameManager.text("INDEPENDENT NIGHT 01", "独立观测第一夜"), Vector2(18, 12), Vector2(780, 34), 24, PALE_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.name = "GraduationIndependentNightTitle"
	var prompt := _label(stage_root, GameManager.text(
		"There is no answer key tonight. Choose one question, choose the instrument that can answer it, and leave behind a record another observer could trust.",
		"今晚没有标准答案。先选一个问题，再选能回答它的仪器，最后留下让另一位观测者也能相信的记录。"
	), Vector2(72, 54), Vector2(672, 66), 15, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var route_rows := [
		[GameManager.text("OPTICAL", "光学"), GameManager.text("Revisit a familiar target with a telescope you chose and assembled.", "用你亲自选择并组装的望远镜，重新观察一个熟悉目标。")],
		[GameManager.text("INFRARED", "红外"), GameManager.text("Compare one deep-sky target through two different filter mappings.", "用两组不同滤镜映射，对比同一个深空目标。")],
		[GameManager.text("RADIO", "射电"), GameManager.text("Recover a timing, spectral-line, or transient signal and archive the evidence.", "恢复一份计时、谱线或暂现信号，并把证据归档。")],
	]
	for index in range(route_rows.size()):
		var row := Panel.new()
		row.position = Vector2(80, 138 + index * 86)
		row.size = Vector2(656, 70)
		row.add_theme_stylebox_override("panel", _style(Color(0.026, 0.052, 0.082, 0.98), Color(0.26, 0.58, 0.70, 0.82), 2, 4))
		stage_root.add_child(row)
		_label(row, str(route_rows[index][0]), Vector2(18, 14), Vector2(130, 42), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		var detail := _label(row, str(route_rows[index][1]), Vector2(164, 10), Vector2(470, 50), 14, WARM_TEXT)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var close_copy := _label(stage_root, GameManager.text(
		"You arrived as a beginner. You leave this room as the observer on duty.",
		"你以新手的身份来到这里。现在，你将以当值观测员的身份走出这个房间。"
	), Vector2(72, 416), Vector2(672, 46), 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	close_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _next_stage() -> void:
	if stage_index >= STAGE_COUNT - 1:
		_return_to_observatory()
		return
	_show_stage(stage_index + 1)


func _previous_stage() -> void:
	if stage_index <= 0:
		return
	_show_stage(stage_index - 1)


func _archive_highlights() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for value in GameManager.progress.get("journal_entries", []):
		var entry := value as Dictionary
		if str(entry.get("object_id", "")) != "":
			records.append(entry)
	for value in GameManager.progress.get("remote_observation_archive", []):
		records.append(value as Dictionary)
	var result: Array[Dictionary] = []
	if records.is_empty():
		result.assign([{}, {}, {}])
		return result
	if records.size() == 1:
		result.assign([records[0], records[0], records[0]])
		return result
	if records.size() == 2:
		result.assign([records[0], records[1], records[1]])
		return result
	result.assign([records[0], records[records.size() / 2], records[-1]])
	return result


func _archive_entry_name(entry: Dictionary) -> String:
	if entry.is_empty():
		return GameManager.text("First observation", "第一次观测")
	var en := str(entry.get("object_name_en", entry.get("target_name_en", entry.get("object_id", ""))))
	var zh := str(entry.get("object_name_zh", entry.get("target_name_zh", entry.get("object_id", ""))))
	return GameManager.text(en, zh)


func _archive_entry_kind(entry: Dictionary) -> String:
	if entry.is_empty():
		return GameManager.text("OBSERVING RECORD", "观测记录")
	if str(entry.get("entry_kind", "")) == "remote_free_observation":
		return GameManager.text("INDEPENDENT REMOTE SESSION", "独立远程观测")
	var level := int(entry.get("level_completed", 0))
	return GameManager.text("LESSON %02d" % level, "第 %02d 课" % level)


func _archive_entry_summary(entry: Dictionary) -> String:
	if entry.is_empty():
		return GameManager.text("Your first recorded question began the archive.", "你记录下的第一个问题，开启了这份档案。")
	var en := str(entry.get("knowledge_en", entry.get("science_en", entry.get("learning_text_en", ""))))
	var zh := str(entry.get("knowledge_zh", entry.get("science_zh", entry.get("learning_text_zh", ""))))
	if en == "":
		en = "A completed observation became evidence you can revisit."
	if zh == "":
		zh = "一次完成的观测，变成了可以重新检视的证据。"
	return GameManager.text(en, zh)


func _archive_entry_quality(entry: Dictionary) -> String:
	var quality := str(entry.get("observation_quality", entry.get("quality", "Recorded")))
	return GameManager.text("RESULT: " + quality.to_upper(), "结果：" + quality)


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
