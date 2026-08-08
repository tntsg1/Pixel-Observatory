extends Control

# Mode-driven learning card scene.
# - brief: concept preview before the player starts a key action.
# - complete: mission result recap after the player succeeds.

const GOLD := Color(0.96, 0.90, 0.58)
const TEXT := Color(0.92, 0.93, 0.90)
const MUTED := Color(0.72, 0.80, 0.88)
const GREEN := Color(0.72, 0.94, 0.68)
const BG := Color(0.050, 0.060, 0.090)
const PANEL_BG := Color(0.035, 0.050, 0.085, 0.96)
const BORDER := Color(0.78, 0.56, 0.28)
const PAPER_INK := Color(0.11, 0.075, 0.04)
const PAPER_MUTED := Color(0.28, 0.20, 0.11)
const PAPER_LINE := Color(0.55, 0.39, 0.20, 0.55)
const PAPER_BOX := Color(0.93, 0.82, 0.58, 0.54)
const DEEP_BLUE := Color(0.02, 0.04, 0.075, 0.92)

const MISSION_BG := "res://assets/mission_complete/bg_room.png"
const MISSION_PARCHMENT := "res://assets/mission_complete/parchment_card.png"
const MISSION_JOURNAL := "res://assets/mission_complete/journal_book_64_clean.png"
const MISSION_BADGE := "res://assets/mission_complete/badge_shield_64_clean.png"
const MISSION_CREDIT := "res://assets/mission_complete/credit_coin_64_clean.png"
const FAST_OBSERVATION_MEDIA_PATH := "res://data/fast_observation_media.json"

var _fast_observation_media_cache: Dictionary = {}
var _current_share_payload: Dictionary = {}


class FastCompletionPlot extends Control:
	var product: Dictionary = {}
	var target_kind := "pulsar"

	func configure(value: Dictionary, kind: String) -> void:
		product = value
		target_kind = kind
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("061119"), true)
		for x in range(0, int(size.x) + 1, 24):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.30, 0.55, 0.58, 0.10), 1.0)
		for y in range(0, int(size.y) + 1, 24):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.30, 0.55, 0.58, 0.10), 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color("7b9498"), false, 1.0)
		if target_kind in ["hi_line", "hydrogen"]:
			_draw_hi()
		elif target_kind in ["repeating_frb", "frb"]:
			_draw_frb()
		else:
			_draw_pulsar()

	func _draw_pulsar() -> void:
		var waterfall: Array = product.get("clean_spectrum", [])
		var waterfall_rect := Rect2(8, 20, size.x - 16, 62)
		_draw_waterfall(waterfall, waterfall_rect)
		_text("CLEAN TIME-FREQUENCY DATA", Vector2(10, 14), 9, Color("9fc7ca"))
		var profile: Array = product.get("folded_two_cycles", [])
		var profile_rect := Rect2(8, 104, size.x - 16, size.y - 112)
		_text("TWO-PERIOD FOLDED PROFILE", Vector2(10, 98), 9, Color("9fd9c1"))
		_draw_profile(profile, profile_rect, Color("9fe8c9"))
		draw_line(Vector2(profile_rect.get_center().x, profile_rect.position.y), Vector2(profile_rect.get_center().x, profile_rect.end.y), Color(0.85, 0.68, 0.34, 0.32), 1.0)

	func _draw_hi() -> void:
		_text("21 CM VELOCITY PROFILE", Vector2(10, 18), 10, Color("9fc7ca"))
		var values: Array = product.get("clean_spectrum_1d", product.get("folded_two_cycles", []))
		if values.is_empty():
			for index in range(96):
				var t := float(index) / 95.0
				values.append(0.08 + exp(-pow((t - 0.55) / 0.12, 2.0)) * 0.82)
		_draw_profile(values, Rect2(10, 34, size.x - 20, size.y - 48), Color("9fe8c9"))
		draw_line(Vector2(size.x * 0.55, 34), Vector2(size.x * 0.55, size.y - 14), Color(0.85, 0.68, 0.34, 0.38), 1.0)

	func _draw_frb() -> void:
		_text("DEDISPERSED BURST · TIME × FREQUENCY", Vector2(10, 18), 10, Color("9fc7ca"))
		var rect := Rect2(10, 30, size.x - 20, size.y - 42)
		var dm_quality := float(product.get("dm_quality", 0.82))
		for row in range(14):
			var f := float(row) / 13.0
			var arrival := 0.53 + (1.0 - f) * (1.0 - dm_quality) * 0.32
			var y := rect.position.y + f * rect.size.y
			var x := rect.position.x + arrival * rect.size.x
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.25, 0.46, 0.50, 0.12), 1.0)
			draw_line(Vector2(x - 8, y), Vector2(x + 8, y), Color(0.62, 0.90, 0.80, 0.78), 2.0)

	func _draw_waterfall(data: Array, rect: Rect2) -> void:
		if data.is_empty():
			return
		var rows := data.size()
		var columns := (data[0] as Array).size()
		for row in range(rows):
			for column in range(columns):
				var value := clampf(float((data[row] as Array)[column]), 0.0, 1.0)
				var cell := Rect2(
					rect.position + Vector2(float(column) * rect.size.x / columns, float(row) * rect.size.y / rows),
					Vector2(rect.size.x / columns + 0.4, rect.size.y / rows + 0.4)
				)
				draw_rect(cell, Color(0.04 + value * 0.28, 0.09 + value * 0.66, 0.11 + value * 0.52, 0.94), true)

	func _draw_profile(values: Array, rect: Rect2, color: Color) -> void:
		if values.size() < 2:
			return
		var points := PackedVector2Array()
		for index in range(values.size()):
			var x := rect.position.x + rect.size.x * float(index) / float(values.size() - 1)
			var y := rect.end.y - clampf(float(values[index]), 0.0, 1.2) * rect.size.y * 0.86
			points.append(Vector2(x, y))
		draw_polyline(points, Color(color, 0.20), 5.0, true)
		draw_polyline(points, color, 1.6, true)

	func _text(value: String, pos: Vector2, font_size: int, color: Color) -> void:
		draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


class RadioSourceSkyMap extends Control:
	var ra_hours := 0.0
	var dec_degrees := 0.0

	func configure(identity: Dictionary) -> void:
		ra_hours = clampf(float(identity.get("ra_hours", 0.0)), 0.0, 24.0)
		dec_degrees = clampf(float(identity.get("dec_degrees", 0.0)), -90.0, 90.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("061119"), true)
		for hour in [0, 6, 12, 18, 24]:
			var x := size.x * float(hour) / 24.0
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.38, 0.61, 0.64, 0.20), 1.0)
		for dec in [-60, -30, 0, 30, 60]:
			var y := size.y * (90.0 - float(dec)) / 180.0
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.38, 0.61, 0.64, 0.16), 1.0)
		var point := Vector2(
			size.x * ra_hours / 24.0,
			size.y * (90.0 - dec_degrees) / 180.0
		)
		draw_line(point - Vector2(7, 0), point + Vector2(7, 0), Color("8fe0c8"), 1.0)
		draw_line(point - Vector2(0, 7), point + Vector2(0, 7), Color("8fe0c8"), 1.0)
		draw_circle(point, 4.0, Color("d9fff3"), false, 1.5)
		draw_rect(Rect2(Vector2.ZERO, size), Color("6f8d91"), false, 1.0)


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)

	var mode: String = GameManager.current_learning_card_mode()
	if mode == "brief":
		_build_concept_brief(GameManager.current_brief_card())
	elif mode == "complete" or not GameManager.last_learning_card.is_empty():
		TeachingFlowManager.acknowledge_card_shown()
		_build_mission_complete(GameManager.last_learning_card)
	else:
		GameManager.call_deferred("go", "observatory")


func _build_concept_brief(card: Dictionary) -> void:
	_label(GameManager.text("Concept Brief", "概念预习"), Vector2(0, 10), Vector2(1024, 36), 27, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(
		GameManager.text("See the mechanism, learn the controls, then try it yourself.", "先看清原理，再学会操作，然后亲手完成。"),
		Vector2(0, 48), Vector2(1024, 20), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER
	)

	_panel(Vector2(56, 74), Vector2(912, 612))
	_label(GameManager.dict_text(card, "title"), Vector2(100, 80), Vector2(824, 28), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_dark_panel(Vector2(74, 120), Vector2(556, 548), Color(0.012, 0.028, 0.052, 0.98), Color(0.18, 0.42, 0.60))
	_diagram(str(card.get("image", "")), Vector2(82, 128), Vector2(540, 532))
	_build_concept_notes(card, Vector2(646, 120), Vector2(304, 548))

	var start: Button = _button(GameManager.text("Start", "开始"), Vector2(382, 696), Vector2(260, 48))
	start.pressed.connect(func() -> void:
		GameManager.complete_current_brief()
	)


func _build_concept_notes(card: Dictionary, pos: Vector2, size: Vector2) -> void:
	var panel := _dark_panel(pos, size, Color(0.025, 0.045, 0.075, 0.98), BORDER)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	MayaPortrait.create(
		self,
		"MayaBriefPortrait",
		MayaPortrait.brief_pose(str(card.get("id", ""))),
		pos + Vector2(82, 8),
		Vector2(140, 178),
		2
	)
	var scroll := ScrollContainer.new()
	scroll.name = "ConceptTutorialScroll"
	scroll.position = pos + Vector2(12, 194)
	scroll.size = Vector2(size.x - 24, size.y - 206)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)

	var notes := RichTextLabel.new()
	notes.name = "ConceptTutorialText"
	notes.bbcode_enabled = true
	notes.fit_content = true
	notes.scroll_active = false
	notes.custom_minimum_size = Vector2(size.x - 46, 0)
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes.add_theme_font_size_override("normal_font_size", 13)
	notes.add_theme_font_size_override("bold_font_size", 14)
	notes.text = _concept_notes_bbcode(card)
	scroll.add_child(notes)


func _concept_notes_bbcode(card: Dictionary) -> String:
	var principle := GameManager.dict_text(card, "text")
	var action := _concept_action_text(str(card.get("id", "")))
	var watch := _concept_watch_text(str(card.get("id", "")))
	return (
		"[color=#f1c66f][b]%s[/b][/color]\n%s\n\n"
		+ "[color=#66d9ef][b]%s[/b][/color]\n%s\n\n"
		+ "[color=#ffb45c][b]%s[/b][/color]\n%s"
	) % [
		GameManager.text("WHY IT WORKS", "为什么有效"),
		principle,
		GameManager.text("WHAT YOU DO", "你要怎么做"),
		action,
		GameManager.text("WATCH FOR", "注意这些问题"),
		watch
	]


func _concept_action_text(card_id: String) -> String:
	if card_id.begins_with("constellation_"):
		return GameManager.text(
			"1. Begin with the brightest anchor star.\n2. Trace the shown line in order without zooming too far in.\n3. Check season, Az and Alt before confirming the pattern.",
			"1. 先找到最亮的锚点星。\n2. 按图示顺序连线，不要把倍率放得过高。\n3. 核对季节、方位角和俯仰角，再确认整体形状。"
		)
	match card_id:
		"dobsonian_manual_altaz":
			return GameManager.text(
				"1. Use a low-power eyepiece to acquire the target.\n2. Swivel the rocker box for Az; tilt the tube for Alt.\n3. Nudge, release, observe, then nudge again as the sky drifts.",
				"1. 先用低倍率目镜找到目标。\n2. 左右转动摇箱调整方位，上下推镜筒调整高度。\n3. 轻推、松手、观察；目标漂移后再轻推。"
			)
		"cassegrain_folded_path":
			return GameManager.text(
				"1. Center with Eye and Finder first.\n2. Switch to the main scope only after alignment.\n3. Focus in small steps because the long focal length magnifies every error.",
				"1. 先用肉眼和寻星镜完成居中。\n2. 对准后再切换主望远镜。\n3. 长焦距会放大误差，调焦时必须小幅微调。"
			)
		"gregorian_concave_secondary":
			return GameManager.text(
				"1. Align the primary axis to the real intermediate focus.\n2. Bring the concave secondary onto that axis.\n3. Verify the final focus at the rear eyepiece.",
				"1. 先让主镜光轴穿过中间的真实焦点。\n2. 再把凹面副镜调到同一光轴上。\n3. 最后在后置目镜处检查最终焦点。"
			)
		"infrared_space_observing":
			return GameManager.text(
				"1. Deploy the sunshield and cool the detector.\n2. Select the wavelength band that can pass through the target dust.\n3. Integrate several exposures before interpreting the result.",
				"1. 展开遮阳板并冷却探测器。\n2. 选择能够穿透目标尘埃的波段。\n3. 累积多次曝光后再解释结果。"
			)
		"radio_signal_observing":
			return GameManager.text(
				"1. Point the dish and tune the requested band.\n2. Separate the repeating peak from background noise.\n3. Measure its period; the graph, not an eyepiece image, is the observation.",
				"1. 指向目标并调到指定频段。\n2. 从背景噪声中找出重复峰值。\n3. 测量周期；这里的观测结果是曲线，不是目镜照片。"
			)
		"multi_wavelength_evidence":
			return GameManager.text(
				"1. Record the visible-light structure.\n2. Compare infrared dust and radio gas at the same coordinates.\n3. Keep only conclusions supported by all relevant bands.",
				"1. 先记录可见光结构。\n2. 在相同坐标比较红外尘埃和射电气体。\n3. 只保留能被相关波段共同支持的结论。"
			)
		"mercury_twilight":
			return GameManager.text(
				"Observe during the short twilight window. Keep magnification moderate, aim just above the horizon, and wait for brief steady moments.",
				"抓住短暂暮光窗口，使用适中倍率，在地平线上方低空寻找，并等待大气短暂稳定。"
			)
		"venus_phase_exposure":
			return GameManager.text(
				"Lower exposure until the bright disk regains a clean crescent edge. Compare phase before increasing magnification.",
				"先降低曝光，直到明亮圆面重新出现清楚的弯月边缘；确认月相后再考虑提高倍率。"
			)
		"saturn_rings_seeing":
			return GameManager.text(
				"Hold Saturn centered and wait through the boiling image. Judge the ring gap only during the stable instants.",
				"保持土星居中，耐心等过画面翻滚；只在短暂稳定时判断环缝与环面结构。"
			)
		"ice_giant_disks":
			return GameManager.text(
				"Use Finder first, then high power and very small focus steps. Confirm a tiny colored disk instead of a sharp star point.",
				"先用寻星镜定位，再使用高倍率和极小调焦步长；确认它是微小有颜色的圆面，而不是尖锐星点。"
			)
		"lunar_feature_scale":
			return GameManager.text(
				"Locate the feature at low power, switch eyepieces without losing it, then compare crater walls and terminator shadows at high power.",
				"低倍率先定位地貌，换目镜时不要丢失目标，再用高倍率比较环形山壁和终结线阴影。"
			)
		"double_cluster_framing":
			return GameManager.text(
				"Choose low power for the whole cluster pair; use higher power only when the task asks you to resolve a close pair.",
				"观测整个双星团时选低倍率宽视场；只有任务要求分开近距离双星时才提高倍率。"
			)
		"faint_object_techniques":
			return GameManager.text(
				"Dark-adapt first. Enable the nebula filter only for a suitable nebula, then hold SHIFT and look at the side marker for averted vision.",
				"先完成暗适应。只在合适的星云上开启星云滤镜，再按住 SHIFT 看侧视标记来使用侧视法。"
			)
		"focus_focal_plane":
			return GameManager.text("Turn the focus control in small steps; stop when the image enters the green clear zone.", "小幅调整调焦旋钮；图像进入绿色清晰区时立即停止。")
		"finder_scope_alignment":
			return GameManager.text("Center the same bright star in Eye, Finder and Telescope, using I/J/K/L for Finder calibration.", "让同一颗亮星依次在肉眼、寻星镜和主镜中居中；用 I/J/K/L 校准寻星镜。")
		"collimation_alignment":
			return GameManager.text("Adjust the mirror screws until the optical axis and all reflection rings share one center.", "调整镜面旋钮，直到光轴与所有反射圆环共享同一个中心。")
	return GameManager.text(
		"Study the diagram, then apply this relationship in the next task. Use the live visual and numerical feedback to verify the result.",
		"先看图理解关系，再在下一步任务中实际操作；同时用画面变化和数值反馈验证结果。"
	)


func _concept_watch_text(card_id: String) -> String:
	if card_id.begins_with("constellation_"):
		return GameManager.text(
			"A constellation is a wide pattern, not one selectable star. High power can hide the shape outside the field.",
			"星座是宽广的整体图形，不是某一颗可点击的星。倍率过高会把其余形状裁出视场。"
		)
	match card_id:
		"dobsonian_manual_altaz":
			return GameManager.text("The mount does not track automatically. Large corrections create overshoot; use repeated gentle nudges.", "支架不会自动追踪。大幅推动很容易冲过目标，应连续使用轻柔小幅修正。")
		"cassegrain_folded_path":
			return GameManager.text("A short tube does not mean a wide field. The folded path is long, so vibration and poor seeing are magnified.", "短镜筒不等于宽视场。折叠后的光路仍很长，抖动和糟糕视宁度都会被放大。")
		"gregorian_concave_secondary":
			return GameManager.text("Passing one ring is not enough: primary, intermediate focus and secondary must agree.", "只对准一个圆环还不够：主镜、中间焦点和副镜必须同时一致。")
		"infrared_space_observing":
			return GameManager.text("The telescope's own heat can look like signal. Cooling and shielding are part of the observation.", "望远镜自身热量也会像信号；冷却与遮阳本身就是观测步骤。")
		"radio_signal_observing":
			return GameManager.text("A tall random spike is not a detection. Look for repeatable timing above the noise floor.", "单个随机高峰不算探测；必须寻找高于噪声底且能够重复的周期。")
		"multi_wavelength_evidence":
			return GameManager.text("Different bands do not need to look alike. Compare location and structure, not color alone.", "不同波段不必长得一样；应比较位置与结构，不能只比较颜色。")
		"mercury_twilight":
			return GameManager.text("Never point near the Sun while it is above the horizon. Low altitude also makes extra power counterproductive.", "太阳仍在地平线上时绝不能靠近它指向；低空扰动下，过高倍率也会适得其反。")
		"venus_phase_exposure":
			return GameManager.text("A white featureless blob is usually overexposure, not bad focus.", "一团没有细节的白斑通常是过曝，不一定是失焦。")
		"saturn_rings_seeing":
			return GameManager.text("Do not chase every atmospheric wobble with the focus control.", "不要把每一次大气晃动都误认为失焦而反复调焦。")
		"ice_giant_disks":
			return GameManager.text("Uranus and Neptune remain small even at high power. Size alone is not proof of focus.", "天王星和海王星即使在高倍率下仍然很小；目标变大不代表已经对焦。")
		"lunar_feature_scale":
			return GameManager.text("High power reveals detail but loses context and stability. Record both views.", "高倍率增加细节，却会损失整体位置和稳定性；两种视图都要记录。")
		"double_cluster_framing":
			return GameManager.text("If only one cluster remains visible, the field is too narrow for the framing task.", "如果视场里只剩一个星团，说明当前视场过窄，不符合取景任务。")
		"faint_object_techniques":
			return GameManager.text("Filters do not improve every object, and averted vision requires looking beside the target rather than at it.", "滤镜不会增强所有天体；侧视法要求看向目标旁边，而不是继续直盯目标。")
	return GameManager.text(
		"Do not rely on the final label alone. The image, control state and quality result must tell the same story.",
		"不要只看最终标签；画面、控件状态和质量结果必须彼此一致。"
	)


func _build_mission_complete(data: Dictionary) -> void:
	var obj: Dictionary = data.get("object", {})
	var level: Dictionary = data.get("level", {})
	var observation: Dictionary = data.get("observation", {})
	var concept: Dictionary = data.get("concept_card", {})
	_current_share_payload = _observation_share_payload(data)
	if _is_fast_completion(level, observation):
		_build_fast_mission_complete(data)
		return

	_mission_bg()
	_title_banner()
	_mission_texture(MISSION_PARCHMENT, Vector2(180, 78), Vector2(664, 528), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

	var object_name := _dict_inline(obj, "name")
	_paper_label(object_name, Vector2(250, 94), Vector2(524, 42), 28, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle := _target_subtitle(obj)
	if subtitle != "":
		var subtitle_label := _paper_label(subtitle, Vector2(250, 134), Vector2(524, 26), 15, PAPER_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		subtitle_label.max_lines_visible = 2

	_mission_section_line(Vector2(228, 162), 568)
	_observation_image(obj, level, observation)
	_quality_panel(observation, data.get("stats", {}))
	_learned_panel(obj, level, observation, data, concept)
	_rewards_panel(level, concept, data)
	_dark_panel(Vector2(168, 594), Vector2(688, 66), Color(0.02, 0.05, 0.035, 0.95), GOLD)
	var completed_level_number := int(level.get("level_number", 0))
	if bool(GameManager.progress.get("program_completed", false)) and completed_level_number == GameManager.FINAL_CAMPAIGN_LEVEL:
		_build_program_complete_route()
	else:
		_build_next_mission_route()

	_build_completion_navigation(level)
	_build_share_result_button()
	_emit_share_payload("observatory:observation-complete")


func _is_fast_completion(level: Dictionary, observation: Dictionary) -> bool:
	return (
		str(level.get("telescope_family", "")) == "fast_radio"
		or str(level.get("observation_mode", "")) == "radio"
		or str(observation.get("observation_mode", "")) == "radio"
	)


func _build_fast_mission_complete(data: Dictionary) -> void:
	var obj: Dictionary = data.get("object", {})
	var level: Dictionary = data.get("level", {})
	var observation: Dictionary = data.get("observation", {})
	var product := _fast_completion_product(observation)
	var kind := str(observation.get("radio_target_kind", product.get("target_kind", "pulsar")))
	var target_name := _dict_inline(obj, "name")
	var type_label := _fast_type_label(kind)
	var conclusion := _fast_conclusion_label(kind, str(observation.get("report_conclusion", "")))
	var confidence := clampf(float(observation.get("confidence", product.get("confidence", 0.0))), 0.0, 1.0)
	var identity := _fast_source_identity(obj, kind)

	_mission_bg()
	_title_banner()
	_dark_panel(Vector2(166, 78), Vector2(692, 508), Color(0.018, 0.035, 0.045, 0.97), Color("7c999c"))
	_label(target_name, Vector2(190, 92), Vector2(452, 32), 25, Color("e4f4ee"))
	_label(type_label, Vector2(190, 123), Vector2(452, 22), 13, Color("8fc6c7"))
	var result_chip := _dark_panel(Vector2(646, 94), Vector2(188, 50), Color("102b27"), Color("68d5b5"))
	result_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(conclusion, Vector2(654, 98), Vector2(172, 22), 12, Color("d5fff2"), HORIZONTAL_ALIGNMENT_CENTER)
	_label(
		GameManager.text("Confidence %.0f%%" % (confidence * 100.0), "置信度 %.0f%%" % (confidence * 100.0)),
		Vector2(654, 120), Vector2(172, 18), 10, Color("9ed7c6"), HORIZONTAL_ALIGNMENT_CENTER
	)

	var identity_panel := _dark_panel(Vector2(190, 154), Vector2(246, 210), Color("041018"), Color("759296"))
	identity_panel.name = "FastSourceIdentity"
	_label(GameManager.text("SOURCE IDENTITY", "目标身份"), Vector2(202, 162), Vector2(222, 20), 12, GOLD)
	_label(str(identity.get("catalog_alias", target_name)), Vector2(202, 184), Vector2(222, 22), 13, Color("d9f1ea"))
	var identity_class := _label(
		GameManager.text(str(identity.get("class_en", type_label)), str(identity.get("class_zh", type_label))),
		Vector2(202, 207), Vector2(222, 34), 10, Color("9ed7c6")
	)
	identity_class.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_class.max_lines_visible = 2
	var sky_map := RadioSourceSkyMap.new()
	sky_map.name = "FastSourceSkyMap"
	sky_map.position = Vector2(202, 247)
	sky_map.size = Vector2(104, 82)
	sky_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_map.configure(identity)
	add_child(sky_map)
	_label("RA", Vector2(314, 247), Vector2(22, 18), 9, MUTED)
	_label(str(identity.get("ra_j2000", "—")), Vector2(336, 247), Vector2(88, 18), 9, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("Dec", Vector2(314, 266), Vector2(30, 18), 9, MUTED)
	_label(str(identity.get("dec_j2000", "—")), Vector2(340, 266), Vector2(84, 18), 9, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(
		GameManager.text(
			"%s · %s" % [str(identity.get("epoch", "J2000")), str(identity.get("constellation_en", "—"))],
			"%s · %s" % [str(identity.get("epoch", "J2000")), str(identity.get("constellation_zh", "—"))]
		),
		Vector2(314, 285), Vector2(110, 18), 9, Color("8fc6c7"), HORIZONTAL_ALIGNMENT_RIGHT
	)
	_label(
		GameManager.text(
			"Distance ~%.2f kpc" % float(identity.get("distance_kpc", 0.0)),
			"距离估计约 %.2f kpc" % float(identity.get("distance_kpc", 0.0))
		),
		Vector2(314, 304), Vector2(110, 18), 9, Color("8fc6c7"), HORIZONTAL_ALIGNMENT_RIGHT
	)
	var significance := _label(
		GameManager.text(str(identity.get("significance_en", "")), str(identity.get("significance_zh", ""))),
		Vector2(202, 335), Vector2(222, 24), 9, MUTED
	)
	significance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	significance.max_lines_visible = 2

	var plot_panel := _dark_panel(Vector2(446, 154), Vector2(242, 210), Color("041018"), Color("759296"))
	plot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plot := FastCompletionPlot.new()
	plot.name = "FastRadioCompletionPlot"
	plot.position = Vector2(6, 6)
	plot.size = Vector2(230, 198)
	plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plot.configure(product, kind)
	plot_panel.add_child(plot)

	_label(GameManager.text("THIS OBSERVATION", "本轮测量"), Vector2(698, 158), Vector2(136, 22), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var metrics := _fast_metric_rows(observation, product, kind)
	for index in range(metrics.size()):
		var row: Array = metrics[index]
		var y := 184.0 + float(index) * 24.0
		_label(str(row[0]), Vector2(698, y), Vector2(60, 20), 9, MUTED)
		var value_label := _label(str(row[1]), Vector2(758, y), Vector2(76, 20), 10, Color("d9f1ea"), HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.name = "FastMetric_%d" % index
		if not InteractionFeedback.is_reduced_motion():
			value_label.modulate.a = 0.0
			var value_tween := value_label.create_tween()
			value_tween.tween_interval(0.08 + float(index) * 0.055)
			value_tween.tween_property(value_label, "modulate:a", 1.0, 0.14)

	_label(GameManager.text("EVIDENCE CHAIN", "证据链"), Vector2(190, 372), Vector2(644, 24), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var chain := _fast_operation_chain(observation, product, kind)
	for index in range(3):
		var x := 190.0 + float(index) * 214.0
		var headers := [
			GameManager.text("PLAYER ACTION", "玩家操作"),
			GameManager.text("SYSTEM EFFECT", "系统变化"),
			GameManager.text("MEASURED RESULT", "测量结果"),
		]
		_label(str(headers[index]), Vector2(x, 398), Vector2(198, 18), 10, Color("8fc6c7"), HORIZONTAL_ALIGNMENT_CENTER)
		var body := _label(str(chain[index]), Vector2(x, 417), Vector2(198, 60), 11, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.max_lines_visible = 4
		if index < 2:
			_label(">", Vector2(x + 198, 432), Vector2(16, 24), 14, Color("68d5b5"), HORIZONTAL_ALIGNMENT_CENTER)

	var quality := str(observation.get("quality", "Good"))
	_label(
		GameManager.text("DATA QUALITY  %s" % quality.to_upper(), "数据质量  %s" % quality),
		Vector2(190, 492), Vector2(214, 22), 12, _paper_quality_color(quality)
	)
	var archive_note := _label(
		GameManager.text(
			"This is a measured timing product, not an optical photograph.",
			"这是由射电计时数据得到的成果，不是光学照片。"
		),
		Vector2(404, 492), Vector2(430, 38), 11, MUTED, HORIZONTAL_ALIGNMENT_RIGHT
	)
	archive_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	archive_note.max_lines_visible = 2

	_label(GameManager.text("REWARDS ARCHIVED", "奖励已归档"), Vector2(190, 535), Vector2(644, 20), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var reward: Dictionary = data.get("reward_summary", {})
	_label(
		GameManager.text(
			"+%d Club Credits · FAST signal record saved" % int(reward.get("credits_awarded", 0)),
			"+%d 社团积分 · FAST 信号记录已保存" % int(reward.get("credits_awarded", 0))
		),
		Vector2(190, 557), Vector2(644, 20), 12, Color("9ed7c6"), HORIZONTAL_ALIGNMENT_CENTER
	)

	if not InteractionFeedback.is_reduced_motion():
		plot_panel.scale = Vector2(0.97, 0.97)
		plot_panel.pivot_offset = plot_panel.size * 0.5
		plot_panel.modulate.a = 0.0
		var reveal := plot_panel.create_tween().set_parallel(true)
		reveal.tween_property(plot_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal.tween_property(plot_panel, "modulate:a", 1.0, 0.18)

	_dark_panel(Vector2(168, 594), Vector2(688, 66), Color(0.02, 0.05, 0.035, 0.95), GOLD)
	var completed_level_number := int(level.get("level_number", 0))
	if bool(GameManager.progress.get("program_completed", false)) and completed_level_number == GameManager.FINAL_CAMPAIGN_LEVEL:
		_build_program_complete_route()
	else:
		_build_next_mission_route()
	_build_completion_navigation(level)
	_build_share_result_button()
	_emit_share_payload("observatory:observation-complete")


func _build_share_result_button() -> void:
	if not OS.has_feature("web"):
		return
	var share_button := _mission_button(
		GameManager.text("Share Result", "分享成果"),
		Vector2(842, 22), Vector2(154, 40), Color(0.06, 0.26, 0.28)
	)
	share_button.name = "ShareObservationResultButton"
	share_button.pressed.connect(func() -> void:
		InteractionFeedback.success(share_button, "")
		_emit_share_payload("observatory:open-observation-share")
	)


func _emit_share_payload(event_name: String) -> void:
	if _current_share_payload.is_empty() or not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return
	JavaScriptBridge.eval(
		"window.dispatchEvent(new CustomEvent('%s',{detail:%s}));" % [event_name, JSON.stringify(_current_share_payload)],
		true
	)


func _observation_share_payload(data: Dictionary) -> Dictionary:
	var obj: Dictionary = data.get("object", {})
	var level: Dictionary = data.get("level", {})
	var observation: Dictionary = data.get("observation", {})
	var stats: Dictionary = data.get("stats", {})
	var family := str(level.get("telescope_family", GameManager.progress.get("selected_telescope_family", "refractor")))
	var mode := str(observation.get("observation_mode", level.get("observation_mode", "telescope")))
	var telescope_name := _share_telescope_name(family, mode)
	var equipment := _share_equipment(family, mode, observation)
	var parameters := _share_parameters(family, mode, observation, stats)
	var discovery := _operation_chain_summary(obj, level, observation, data)[2]
	if family == "space_segmented":
		discovery = str(observation.get("science_finding", discovery))
	var clarity := _share_score(observation.get("effective_clarity", observation.get("clarity", stats.get("clarity_score", 0.0))))
	var contrast := _share_score(observation.get("effective_contrast", observation.get("contrast", stats.get("contrast_score", 0.0))))
	var detail := _share_score(observation.get("effective_detail", observation.get("detail", stats.get("stability_score", 0.0))))
	return {
		"locale": GameManager.language_mode,
		"object": {
			"id": str(obj.get("id", "unknown")),
			"name": _dict_inline(obj, "name"),
			"type": _target_subtitle(obj),
		},
		"telescopeFamily": family if family != "" else mode,
		"telescopeName": telescope_name,
		"equipment": equipment,
		"parameters": parameters,
		"quality": {
			"grade": str(observation.get("quality", "Good")),
			"metrics": {"clarity": clarity, "contrast": contrast, "detail": detail},
		},
		"discovery": discovery,
		"missionLevel": int(level.get("level_number", 0)),
	}


func _share_score(value: Variant) -> float:
	var score := float(value)
	if score > 0.0 and score <= 1.0:
		score *= 100.0
	return clampf(score, 0.0, 100.0)


func _share_telescope_name(family: String, mode: String) -> String:
	if family == "space_segmented" or mode == "space_infrared":
		return GameManager.text("Space Infrared Observatory", "太空红外天文台")
	if family == "fast_radio" or mode == "radio":
		return GameManager.text("FAST 500 m Radio Telescope", "FAST 500 米射电望远镜")
	var names := {
		"refractor": ["Refracting Telescope", "折射式望远镜"],
		"newtonian": ["Newtonian Reflector", "牛顿反射式望远镜"],
		"dobsonian": ["Dobsonian Telescope", "多布森望远镜"],
		"cassegrain": ["Cassegrain Telescope", "卡塞格林望远镜"],
	}
	var pair: Array = names.get(family, ["Optical Telescope", "光学望远镜"])
	return GameManager.text(str(pair[0]), str(pair[1]))


func _share_equipment(family: String, mode: String, observation: Dictionary) -> Dictionary:
	if family == "space_segmented" or mode == "space_infrared":
		return {
			"primary": str(observation.get("instrument", "NIRCam")),
			"secondary": GameManager.text("Filter: %s" % str(observation.get("filter", "infrared")), "滤镜：%s" % str(observation.get("filter", "infrared"))),
			"detail": GameManager.text("Segmented infrared optics", "分段式红外光学系统"),
		}
	if family == "fast_radio" or mode == "radio":
		return {
			"primary": GameManager.text("Suspended feed cabin", "悬吊馈源舱"),
			"secondary": GameManager.text("Cryogenic radio receiver", "低温射电接收机"),
			"detail": GameManager.text("500 m aperture synthesis", "500 米口径合成"),
		}
	var objective := GameManager.get_part(GameManager.equipped_part_id("objective"))
	var eyepiece := GameManager.get_part(GameManager.equipped_part_id("eyepiece"))
	var mount := GameManager.get_part(GameManager.equipped_part_id("mount"))
	return {
		"primary": GameManager.dict_text(objective, "name") if not objective.is_empty() else GameManager.text("Optical tube", "光学镜筒"),
		"secondary": GameManager.dict_text(eyepiece, "name") if not eyepiece.is_empty() else GameManager.text("Eyepiece", "目镜"),
		"detail": GameManager.dict_text(mount, "name") if not mount.is_empty() else GameManager.text("Manual mount", "手动支架"),
	}


func _share_parameters(family: String, mode: String, observation: Dictionary, stats: Dictionary) -> Array:
	var rows: Array = []
	if family == "space_segmented" or mode == "space_infrared":
		rows.append({"label": GameManager.text("Exposure", "曝光"), "value": "%.0f s" % float(observation.get("exposure", 0.0))})
		rows.append({"label": GameManager.text("Signal / noise", "信噪比"), "value": "%.1f" % float(observation.get("snr", 0.0))})
		rows.append({"label": GameManager.text("Instrument", "仪器"), "value": str(observation.get("instrument", "NIRCam"))})
		rows.append({"label": GameManager.text("Filter", "滤镜"), "value": str(observation.get("filter", "infrared"))})
		return rows
	if family == "fast_radio" or mode == "radio":
		rows.append({"label": GameManager.text("Period", "周期"), "value": "%.3f ms" % float(observation.get("pulse_period_ms", 0.0))})
		rows.append({"label": "DM", "value": "%.2f pc/cm³" % float(observation.get("dispersion_measure", 0.0))})
		rows.append({"label": GameManager.text("Signal / noise", "信噪比"), "value": "%.1f" % float(observation.get("snr", 0.0))})
		rows.append({"label": GameManager.text("Integration", "积分时长"), "value": "%.0f s" % float(observation.get("integration_s", 0.0))})
		return rows
	var objective := GameManager.get_part(GameManager.equipped_part_id("objective"))
	var eyepiece := GameManager.get_part(GameManager.equipped_part_id("eyepiece"))
	rows.append({"label": GameManager.text("Magnification", "放大倍率"), "value": "%.1f×" % float(stats.get("magnification", 0.0))})
	rows.append({"label": GameManager.text("Aperture", "口径"), "value": "%d mm" % int(objective.get("aperture_mm", 0))})
	rows.append({"label": GameManager.text("Focal length", "物镜焦距"), "value": "%d mm" % int(objective.get("focal_length_mm", 0))})
	rows.append({"label": GameManager.text("Eyepiece", "目镜焦距"), "value": "%d mm" % int(eyepiece.get("focal_length_mm", 0))})
	return rows


func _fast_source_identity(obj: Dictionary, kind: String) -> Dictionary:
	var identity_value: Variant = obj.get("radio_identity", {})
	if identity_value is Dictionary and not (identity_value as Dictionary).is_empty():
		return (identity_value as Dictionary).duplicate(true)
	return {
		"catalog_alias": _dict_inline(obj, "name"),
		"class_en": "Radio source" if kind != "pulsar" else "Radio pulsar",
		"class_zh": "射电源" if kind != "pulsar" else "射电脉冲星",
		"ra_j2000": "—",
		"dec_j2000": "—",
		"ra_hours": 0.0,
		"dec_degrees": 0.0,
		"epoch": "J2000",
		"constellation_en": "Catalogue position unavailable",
		"constellation_zh": "暂无目录位置",
		"distance_kpc": 0.0,
		"significance_en": "Identity information is kept separate from the measurements made in this observation.",
		"significance_zh": "目标目录身份与本轮实际测量值分开记录。",
	}


func _fast_completion_product(observation: Dictionary) -> Dictionary:
	var product: Dictionary = observation.get("radio_data_product", {}).duplicate(true)
	if not product.is_empty():
		return product
	var values: Array = []
	var confidence := clampf(float(observation.get("confidence", 0.78)), 0.25, 1.0)
	for index in range(128):
		var phase := fmod(float(index) / 64.0, 1.0)
		var distance := minf(absf(phase - 0.50), 1.0 - absf(phase - 0.50))
		var pulse := exp(-pow(distance / lerpf(0.095, 0.045, confidence), 2.0))
		var noise := sin(float(index) * 1.73) * (1.0 - confidence) * 0.10
		values.append(clampf(0.05 + pulse * 0.88 + noise, 0.0, 1.1))
	product["folded_two_cycles"] = values
	product["confidence"] = confidence
	product["target_kind"] = str(observation.get("radio_target_kind", "pulsar"))
	product["pulse_width_ms"] = float(observation.get("pulse_width_ms", 0.0))
	product["duty_cycle_percent"] = float(observation.get("duty_cycle_percent", 0.0))
	return product


func _fast_type_label(kind: String) -> String:
	if kind in ["hi_line", "hydrogen"]:
		return GameManager.text("Neutral Hydrogen · 21 cm Spectral Measurement", "中性氢 · 21 厘米谱线测量")
	if kind in ["repeating_frb", "frb"]:
		return GameManager.text("Fast Radio Burst · Dispersed Transient", "快速射电爆发 · 色散暂现源")
	return GameManager.text("Radio Pulsar · Precision Timing", "射电脉冲星 · 精密计时")


func _fast_conclusion_label(kind: String, choice: String) -> String:
	if choice == "residual_rfi":
		return GameManager.text("RFI REMAINS", "仍有干扰")
	if choice == "insufficient_signal":
		return GameManager.text("SIGNAL INSUFFICIENT", "信号不足")
	if kind in ["hi_line", "hydrogen"]:
		return GameManager.text("21 CM LINE CONFIRMED", "21 厘米谱线已确认")
	if kind in ["repeating_frb", "frb"]:
		return GameManager.text("BURST CONFIRMED", "射电爆发已确认")
	return GameManager.text("PERIODICITY CONFIRMED", "周期信号已确认")


func _fast_metric_rows(observation: Dictionary, product: Dictionary, kind: String) -> Array:
	var common := [
		[GameManager.text("S/N", "信噪比"), "%.1f" % float(observation.get("snr", 0.0))],
		[GameManager.text("Integration", "积分时长"), "%.0f s" % float(observation.get("integration_s", 0.0))],
		[GameManager.text("RFI removed", "剔除干扰"), "%d" % int(observation.get("rfi_cleared", 0))],
	]
	if kind in ["hi_line", "hydrogen"]:
		return [
			[GameManager.text("Rest line", "静止谱线"), "1420.406 MHz"],
			[GameManager.text("Velocity", "径向速度"), "%.1f km/s" % float(product.get("velocity_kms", 0.0))],
		] + common
	if kind in ["repeating_frb", "frb"]:
		return [
			["DM", "%.2f pc/cm³" % float(observation.get("dispersion_measure", 0.0))],
			[GameManager.text("Burst width", "爆发宽度"), "%.2f ms" % float(observation.get("pulse_width_ms", 0.0))],
		] + common
	return [
		[GameManager.text("Period", "周期"), "%.3f ms" % float(observation.get("pulse_period_ms", 0.0))],
		["DM", "%.2f pc/cm³" % float(observation.get("dispersion_measure", 0.0))],
		[GameManager.text("Pulse width", "脉冲宽度"), "%.2f ms" % float(observation.get("pulse_width_ms", product.get("pulse_width_ms", 0.0)))],
		[GameManager.text("Duty cycle", "占空比"), "%.1f%%" % float(observation.get("duty_cycle_percent", product.get("duty_cycle_percent", 0.0)))],
	] + common


func _fast_operation_chain(observation: Dictionary, product: Dictionary, kind: String) -> Array[String]:
	var action := GameManager.text(
		"Locked the feed cabin, tuned the passband, removed RFI, and solved the timing model.",
		"锁定馈源舱、调谐通带、剔除干扰并求解计时模型。"
	)
	var effect := GameManager.text(
		"Pointing %.0f%% · tuning %.0f%% · RFI %d/%d removed." % [
			float(observation.get("pointing_quality", product.get("pointing_quality", 0.0))) * 100.0,
			float(observation.get("tuning_quality", product.get("tuning_quality", 0.0))) * 100.0,
			int(observation.get("rfi_cleared", product.get("removed_rfi_count", 0))),
			int(observation.get("raw_rfi_count", product.get("raw_rfi_count", 0))),
		],
		"指向 %.0f%% · 调谐 %.0f%% · 已剔除干扰 %d/%d。" % [
			float(observation.get("pointing_quality", product.get("pointing_quality", 0.0))) * 100.0,
			float(observation.get("tuning_quality", product.get("tuning_quality", 0.0))) * 100.0,
			int(observation.get("rfi_cleared", product.get("removed_rfi_count", 0))),
			int(observation.get("raw_rfi_count", product.get("raw_rfi_count", 0))),
		]
	)
	var result := GameManager.text(
		"The cleaned data support a repeatable radio measurement.",
		"净化后的数据支持可重复的射电测量结果。"
	)
	if kind not in ["hi_line", "hydrogen", "repeating_frb", "frb"]:
		result = GameManager.text(
			"Period %.3f ms · DM %.2f · S/N %.1f formed a stable folded pulse." % [
				float(observation.get("pulse_period_ms", 0.0)),
				float(observation.get("dispersion_measure", 0.0)),
				float(observation.get("snr", 0.0)),
			],
			"周期 %.3f ms · DM %.2f · 信噪比 %.1f 形成稳定折叠脉冲。" % [
				float(observation.get("pulse_period_ms", 0.0)),
				float(observation.get("dispersion_measure", 0.0)),
				float(observation.get("snr", 0.0)),
			]
		)
	return [action, effect, result]


func _build_completion_navigation(level: Dictionary) -> void:
	var completed_level_number := int(level.get("level_number", 0))
	var program_complete := GameManager.study_campaign_complete() if GameManager.study_mode_active() else ( \
		bool(GameManager.progress.get("program_completed", false)) \
		and completed_level_number == GameManager.FINAL_CAMPAIGN_LEVEL)
	var continue_text := GameManager.text("Complete Research Route", "完成研究路线") if GameManager.study_mode_active() and program_complete \
		else (GameManager.text("Graduation Ceremony", "参加毕业典礼") if program_complete else GameManager.text("Continue", "继续"))
	var continue_position := Vector2(357, 668) if GameManager.study_mode_active() else Vector2(298, 668)
	var continue_size := Vector2(310, 48) if GameManager.study_mode_active() else Vector2(210, 48)
	var continue_button: Button = _mission_button(continue_text, continue_position, continue_size, Color(0.08, 0.38, 0.20))
	continue_button.name = "GraduationButton" if program_complete else "ContinueButton"
	continue_button.pressed.connect(func() -> void:
		if GameManager.study_mode_active():
			if program_complete:
				if GameManager.try_story_epilogue(completed_level_number, "study_graduation"):
					return
				GameManager.go("study_graduation")
				return
			GameManager.update_room_guidance_for_level()
			if GameManager.go_to_pending_mission_setup():
				return
			if GameManager.try_story_epilogue(completed_level_number, "observatory"):
				return
			GameManager.go("observatory")
			return
		if program_complete:
			if GameManager.try_story_epilogue(completed_level_number, "graduation"):
				return
			GameManager.go("graduation")
			return
		GameManager.update_room_guidance_for_level()
		if GameManager.go_to_pending_mission_setup():
			return
		if GameManager.try_story_epilogue(completed_level_number, "observatory"):
			return
		GameManager.go("observatory")
	)
	if GameManager.study_mode_active():
		return
	var journal_button: Button = _mission_button(GameManager.text("Open Journal", "打开观测日志"), Vector2(536, 668), Vector2(230, 48), Color(0.06, 0.20, 0.42))
	journal_button.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("journal")
		GameManager.go("journal")
	)


func _build_next_mission_route() -> void:
	# Tell the player exactly where the newly advanced campaign continues.
	var next_route := GameManager.current_room_route()
	var next_level := int(GameManager.progress.get("current_level", 0))
	var next_title := GameManager.dict_text(GameManager.current_level(), "title")
	var next_heading := GameManager.text("NEXT RESEARCH STEP: %s" % next_title, "下一研究步骤：%s" % next_title) if GameManager.study_mode_active() \
		else GameManager.text("NEXT: Level %d - %s" % [next_level, next_title], "下一关：第 %d 关 - %s" % [next_level, next_title])
	var head := _label(
		next_heading,
		Vector2(180, 598), Vector2(664, 22), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.clip_text = true
	var where := _label(
		GameManager.text("Go to: ", "前往：") + str(next_route.get("action", "")),
		Vector2(180, 619), Vector2(664, 20), 14, Color(0.72, 0.94, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	where.clip_text = true
	var what := _label(str(next_route.get("hint", "")), Vector2(180, 637), Vector2(664, 20), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	what.clip_text = true


func _build_program_complete_route() -> void:
	var head := _label(
		GameManager.text("CLUB PROGRAM COMPLETE", "社团观测课程完成"),
		Vector2(180, 598), Vector2(664, 22), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.clip_text = true
	var where := _label(
		GameManager.text("Your full observing record is now preserved.", "你的完整观测记录已经归档。"),
		Vector2(180, 619), Vector2(664, 20), 14, Color(0.72, 0.94, 0.68), HORIZONTAL_ALIGNMENT_CENTER)
	where.clip_text = true
	var what := _label(
		GameManager.text("Return to the observatory or open the Club Logbook.", "返回天文台，或打开俱乐部观测日志。"),
		Vector2(180, 637), Vector2(664, 20), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	what.clip_text = true


func _mission_bg() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.01, 0.015, 0.03))
	_mission_texture(MISSION_BG, Vector2.ZERO, Vector2(1024, 768), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var shade := _rect(Vector2.ZERO, Vector2(1024, 768), Color(0.0, 0.0, 0.0, 0.16))
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _title_banner() -> void:
	_dark_panel(Vector2(362, 14), Vector2(300, 54), Color(0.025, 0.045, 0.080, 0.96), GOLD)
	_label(GameManager.text("MISSION COMPLETE", "观测完成"), Vector2(362, 20), Vector2(300, 36), 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


func _observation_image(obj: Dictionary, level: Dictionary, observation: Dictionary) -> void:
	_dark_panel(Vector2(220, 176), Vector2(330, 158), Color(0.025, 0.025, 0.030, 0.88), Color(0.50, 0.34, 0.16))
	if bool(level.get("requires_focus", false)):
		_focus_comparison_image(obj, observation)
		return
	var path := _mission_object_image(obj, level)
	if path != "":
		var observation_image := _mission_texture(path, Vector2(232, 186), Vector2(306, 138), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		observation_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var check := _dark_panel(Vector2(204, 158), Vector2(40, 40), Color(0.12, 0.08, 0.03, 0.95), GOLD)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label("✓", Vector2(204, 158), Vector2(40, 36), 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER)


func _focus_comparison_image(obj: Dictionary, observation: Dictionary) -> void:
	var clear_path := _mission_object_state_image(obj, "clear")
	if clear_path == "":
		var fallback_path := _mission_object_image(obj)
		if fallback_path != "":
			_mission_texture(fallback_path, Vector2(232, 186), Vector2(306, 138), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		return

	var states := [
		{
			"label": _inline_text("Out of Focus", "失焦"),
			"border": Color(0.72, 0.24, 0.12),
			"blur_radius": 5.6,
			"brightness": 0.72
		},
		{
			"label": _inline_text("Near Focus", "接近焦点"),
			"border": Color(0.82, 0.56, 0.12),
			"blur_radius": 2.2,
			"brightness": 0.90
		},
		{
			"label": _inline_text("In Focus", "准焦"),
			"border": Color(0.20, 0.56, 0.24),
			"blur_radius": 0.0,
			"brightness": 1.0
		}
	]
	var start_x := 228.0
	var cell_size := Vector2(100, 140)
	for index in range(states.size()):
		var state: Dictionary = states[index]
		var cell_pos := Vector2(start_x + float(index) * 106.0, 184)
		_dark_panel(cell_pos, cell_size, Color(0.018, 0.022, 0.030, 0.96), state["border"])
		var image_pos := cell_pos + Vector2(5, 5)
		var image_size := Vector2(90, 103)
		var state_path := clear_path
		var uses_authored_state := false
		if index == 0:
			var authored_blur := _mission_object_state_image(obj, "blurry")
			if authored_blur != "" and authored_blur != clear_path:
				state_path = authored_blur
				uses_authored_state = true
		var image := _mission_texture(state_path, image_pos, image_size, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		# Astronomy masters are photographic/antialiased media. Nearest-neighbour
		# downsampling made star spikes jagged and erased thin planetary detail.
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if float(state["blur_radius"]) > 0.0 and not uses_authored_state:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/optical_target_state.gdshader") if _mission_object_is_solid_body(obj) else preload("res://shaders/optical_focus_preview.gdshader")
			material.set_shader_parameter("blur_radius_px", float(state["blur_radius"]))
			material.set_shader_parameter("defocus_amount", clampf(float(state["blur_radius"]) / 5.6, 0.0, 1.0))
			material.set_shader_parameter("brightness", float(state["brightness"]))
			image.material = material
		var label := _label(str(state["label"]), cell_pos + Vector2(3, 111), Vector2(94, 24), 10, state["border"], HORIZONTAL_ALIGNMENT_CENTER)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.max_lines_visible = 2

	# A completed focus mission records the successful state. Mark that state
	# without covering the clear target image.
	var focus_error := float(observation.get("focus_error", 0.0))
	var focus_tolerance := maxf(float(observation.get("focus_tolerance", 0.06)), 0.001)
	if focus_error <= focus_tolerance:
		var badge := _dark_panel(Vector2(510, 180), Vector2(34, 22), Color(0.08, 0.30, 0.12, 0.96), Color(0.34, 0.76, 0.34))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label("OK", Vector2(510, 180), Vector2(34, 20), 10, Color(0.72, 1.0, 0.70), HORIZONTAL_ALIGNMENT_CENTER)


func _mission_object_is_solid_body(obj: Dictionary) -> bool:
	var object_id := str(obj.get("id", ""))
	if OpticalMediaRegistry.is_isolated_planet(object_id):
		return true
	var type_lower := str(obj.get("type_en", "")).strip_edges().to_lower()
	return type_lower in ["planet", "natural satellite", "moon"]


func _quality_panel(observation: Dictionary, stats: Dictionary) -> void:
	_paper_label(_inline_text("Observation Quality", "观测质量"), Vector2(584, 182), Vector2(220, 24), 17, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	_mission_section_line(Vector2(596, 210), 194)
	var scores := _quality_scores(observation, stats)
	var rows := [
		{"name": _inline_text("Clarity", "清晰度"), "score": int(scores.get("clarity", 3))},
		{"name": _inline_text("Contrast", "对比度"), "score": int(scores.get("contrast", 3))},
		{"name": _inline_text("Detail", "细节"), "score": int(scores.get("detail", 3))}
	]
	var y := 222.0
	for row in rows:
		_paper_label(str(row["name"]), Vector2(594, y), Vector2(92, 20), 15, PAPER_INK)
		_paper_label(_star_string(int(row["score"])), Vector2(688, y - 4.0), Vector2(112, 24), 20, Color(0.80, 0.48, 0.08))
		y += 32.0
	var quality := str(observation.get("quality", "Good"))
	_paper_label(quality, Vector2(592, 306), Vector2(198, 22), 15, _paper_quality_color(quality), HORIZONTAL_ALIGNMENT_CENTER)


func _learned_panel(obj: Dictionary, level: Dictionary, observation: Dictionary, data: Dictionary, concept: Dictionary) -> void:
	_mission_section_line(Vector2(228, 354), 568)
	_paper_label(_inline_text("Operation Chain", "操作回顾"), Vector2(312, 340), Vector2(400, 26), 18, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var summary := _operation_chain_summary(obj, level, observation, data)
	var headings := [
		_inline_text("ACTION", "操作结果"),
		_inline_text("PHYSICAL EFFECT", "系统状态"),
		_inline_text("WHAT BECAME VISIBLE", "观测发现"),
	]
	for index in range(3):
		var x := 240.0 + float(index) * 184.0
		_paper_label(str(headings[index]), Vector2(x, 368), Vector2(168, 22), 13, Color(0.50, 0.29, 0.05), HORIZONTAL_ALIGNMENT_CENTER)
		var body := _paper_label(str(summary[index]), Vector2(x, 390), Vector2(168, 65), 13, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		body.max_lines_visible = 4
		if index < 2:
			_paper_label(">", Vector2(x + 168, 408), Vector2(16, 24), 16, Color(0.76, 0.48, 0.10), HORIZONTAL_ALIGNMENT_CENTER)


func _operation_chain_summary(obj: Dictionary, level: Dictionary, observation: Dictionary, data: Dictionary) -> Array[String]:
	var family := str(level.get("telescope_family", GameManager.progress.get("selected_telescope_family", "refractor")))
	if family == "space_segmented":
		return [
			_inline_text("Protected the cold side, locked the guide star, and phased the mirror.", "保护低温面、锁定导星并完成镜面相位校准。"),
			_inline_text("Thermal noise fell, pointing stabilized, and photons accumulated coherently.", "热噪声降低、指向稳定，光子得以相干积累。"),
			_space_result_reveal(obj),
		]
	if family == "fast_radio" or str(level.get("observation_mode", "")) == "radio":
		return [
			_inline_text("Locked the feed cabin, tuned the band, rejected RFI, and matched DM.", "锁定馈源舱、调谐频段、抑制射频干扰并匹配色散量。"),
			_inline_text("Dispersed pulses aligned while folded integrations raised SNR.", "色散脉冲完成对齐，折叠积分提高了信噪比。"),
			_inline_text("A repeating radio pulse emerged from the noise.", "重复射电脉冲从噪声中显现。"),
		]
	var action := _inline_text("Centered and held the target in the main field.", "将目标居中并稳定保持在主镜视场中。")
	var effect := _inline_text("Stable light remained on the same focal-plane detail.", "稳定光线持续落在同一焦平面细节上。")
	if bool(level.get("finder_calibration", false)) or bool(level.get("requires_finder_calibration", false)):
		action = _inline_text("Aligned the finder scope, then centered the target.", "校准寻星镜后将目标移到视场中央。")
		effect = _inline_text("The wide finder field transferred the target into the narrow main field.", "宽视场寻星镜把目标送入狭窄主镜视场。")
	elif bool(level.get("requires_focus", false)):
		action = _inline_text("Adjusted the focuser into the sharp-focus tolerance.", "将调焦器微调到清晰焦点容差内。")
		effect = _inline_text("The focal plane met the eyepiece and blur stopped spreading detail.", "焦平面与目镜重合，失焦模糊不再扩散细节。")
	elif bool(level.get("requires_collimation", false)):
		action = _inline_text("Collimated the primary and secondary optical axes.", "校准主镜与副镜的光轴。")
		effect = _inline_text("Light converged symmetrically instead of forming an offset flare.", "光线对称会聚，不再形成偏移光斑。")
	elif bool(level.get("drift_enabled", false)):
		action = _inline_text("Matched the tracking rate and held the target.", "匹配追踪速率并稳定保持目标。")
		effect = _inline_text("Earth-rotation drift was cancelled at the focal plane.", "地球自转造成的焦平面漂移被抵消。")
	return [action, effect, _optical_result_reveal(obj)]


func _space_result_reveal(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	if id == "horsehead_nebula_infrared":
		return _inline_text("Background stars appeared through thinner lanes of dust.", "背景恒星穿过较薄尘埃带显现出来。")
	if id == "carina_cosmic_cliffs":
		return _inline_text("Embedded newborn stars and cooler dust structure separated.", "内嵌的新生恒星与较冷尘埃结构被区分开。")
	return _inline_text("Faint infrared structure emerged from the processed photon stack.", "微弱红外结构从处理后的光子堆栈中显现。")


func _optical_result_reveal(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	match id:
		"jupiter":
			return _inline_text("Jupiter's cloud bands became separable.", "木星云带变得可以分辨。")
		"moon":
			return _inline_text("Crater rims, maria, and the terminator gained definition.", "陨石坑边缘、月海和终结线变得清晰。")
		"saturn":
			return _inline_text("Saturn's ring separated cleanly from the planetary disk.", "土星环与行星圆盘清楚分离。")
		"mars":
			return _inline_text("Mars's disk edge and broad surface shading became stable.", "火星圆盘边缘与大尺度表面明暗变得稳定。")
	var type_text := str(obj.get("type_en", "")).to_lower()
	if type_text.find("nebula") >= 0 or type_text.find("galaxy") >= 0:
		return _inline_text("The faint core and outer glow separated from the sky background.", "微弱核心和外围辉光从天空背景中分离。")
	return _inline_text("The target's defining shape, brightness, and color became readable.", "目标的关键形状、亮度和颜色变得可辨认。")


func _rewards_panel(level: Dictionary, concept: Dictionary, data: Dictionary) -> void:
	_mission_section_line(Vector2(228, 486), 568)
	_paper_label(_inline_text("Rewards Unlocked", "奖励解锁"), Vector2(312, 474), Vector2(400, 24), 18, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	var rewards := _reward_items(level, concept, data)
	var count: int = max(1, rewards.size())
	var slot_w := 144.0
	var total_w := slot_w * float(count)
	var start_x := 512.0 - total_w * 0.5
	for i in range(rewards.size()):
		var reward: Dictionary = rewards[i]
		var x := start_x + float(i) * slot_w
		_reward_slot(reward, Vector2(x, 510))


func _reward_slot(reward: Dictionary, pos: Vector2) -> void:
	var icon_path := str(reward.get("icon", ""))
	if icon_path != "":
		_mission_texture(icon_path, pos + Vector2(43, 0), Vector2(44, 44), TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var title := str(reward.get("title", ""))
	var detail := str(reward.get("detail", ""))
	var title_label := _paper_label(title, pos + Vector2(2, 42), Vector2(126, 20), 13, PAPER_INK, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.max_lines_visible = 1
	var detail_label := _paper_label(detail, pos + Vector2(2, 60), Vector2(126, 20), 12, PAPER_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	detail_label.max_lines_visible = 1


func _reward_items(level: Dictionary, concept: Dictionary, data: Dictionary) -> Array:
	var items: Array = []
	var summary: Dictionary = data.get("reward_summary", {})
	var credits := int(summary.get("credits_awarded", level.get("reward_credits", 0)))
	var credits_total := int(summary.get("credits_total", GameManager.progress.get("credits", 0)))
	if credits > 0:
		items.append({
			"icon": MISSION_CREDIT,
			"title": "+%d" % credits,
			"detail": _inline_text("Total %d Credits" % credits_total, "积分共 %d" % credits_total)
		})
	var badges: Array = summary.get("badges_awarded", [])
	if badges.is_empty():
		var fallback_badge := str(level.get("badge", ""))
		if fallback_badge != "":
			badges = [fallback_badge]
	for badge_value in badges:
		var badge := str(badge_value)
		items.append({
			"icon": MISSION_BADGE,
			"title": GameManager.badge_display_name(badge),
			"detail": _inline_text("Observer Badge", "观测徽章")
		})
	if not concept.is_empty():
		items.append({
			"icon": MISSION_JOURNAL,
			"title": _inline_text("Journal Entry", "日志条目"),
			"detail": _inline_text("Unlocked", "已解锁")
		})
	var unlock_names := _unlock_names(level)
	if not unlock_names.is_empty():
		items.append({
			"icon": MISSION_BADGE,
			"title": _inline_text("New Gear", "新装备"),
			"detail": ", ".join(unlock_names)
		})
	return items


func _unlock_names(level: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for part_id in level.get("unlock_parts", []):
		var part := GameManager.get_part(str(part_id))
		if part.is_empty():
			continue
		names.append(_dict_inline(part, "name"))
	return names


func _quality_scores(observation: Dictionary, stats: Dictionary) -> Dictionary:
	var quality := str(observation.get("quality", "Good"))
	var base := _quality_to_stars(quality)
	var ratios: Dictionary = observation.get("ratios", {})
	var clarity_value := float(observation.get("effective_clarity", stats.get("clarity_score", 60.0)))
	var clarity := int(clampf(round(clarity_value / 20.0), 0.0, 5.0))
	if clarity == 0 and base > 0:
		clarity = base
	var contrast_ratio := float(ratios.get("light", base / 5.0))
	var contrast := int(clampf(round(contrast_ratio * 4.0), 0.0, 5.0))
	if contrast == 0 and base > 0:
		contrast = max(1, base - 1)
	var stability_ratio := float(ratios.get("stability", base / 5.0))
	var detail := int(clampf(round((float(base) + stability_ratio * 4.0) * 0.5), 0.0, 5.0))
	return {
		"clarity": clampi(clarity, 0, 5),
		"contrast": clampi(contrast, 0, 5),
		"detail": clampi(detail, 0, 5)
	}


func _quality_to_stars(quality: String) -> int:
	match quality:
		"Excellent":
			return 5
		"Good":
			return 4
		"Fair":
			return 3
		"Poor":
			return 2
		"Failed":
			return 1
	return 3


func _star_string(score: int) -> String:
	var full := clampi(score, 0, 5)
	var text := ""
	for i in range(5):
		text += "★" if i < full else "☆"
	return text


func _paper_quality_color(quality: String) -> Color:
	match quality:
		"Excellent":
			return Color(0.20, 0.44, 0.15)
		"Good":
			return Color(0.18, 0.38, 0.16)
		"Fair":
			return Color(0.56, 0.38, 0.10)
		"Poor":
			return Color(0.65, 0.22, 0.12)
		"Failed":
			return Color(0.55, 0.12, 0.10)
	return PAPER_MUTED


func _target_subtitle(obj: Dictionary) -> String:
	var parts: Array[String] = []
	for key in ["messier", "constellation", "type", "distance"]:
		var value := ""
		if key == "messier":
			value = str(obj.get(key, ""))
		else:
			value = GameManager.dict_text(obj, key)
		if value != "":
			parts.append(value)
	if not parts.is_empty():
		return " · ".join(parts)
	# Backward compatibility for older object rows that only have English
	# subtitle metadata.
	for key in ["constellation_en", "type_en", "distance_en"]:
		var value := str(obj.get(key, ""))
		if value != "":
			parts.append(value)
	if parts.is_empty():
		return ""
	return " · ".join(parts)


func _learned_lines(obj: Dictionary, level: Dictionary, observation: Dictionary, data: Dictionary, concept: Dictionary) -> Array[String]:
	var id := str(obj.get("id", ""))
	var type_text := str(obj.get("type_en", "")).to_lower()
	var lines: Array[String] = []
	var success := _dict_inline(level, "success_text")
	if success != "":
		lines.append(success.replace("\n", " / "))
	var variation := str(level.get("variation", ""))
	var concept_title := _dict_inline(concept, "title")
	if concept_title != "":
		lines.append(_inline_text("Concept logged:", "知识点记录：") + " " + concept_title.replace("\n", " / "))

	if id == "moon":
		lines.append(_inline_text(
			"The Moon is bright enough to show craters and maria when the optics are steady.",
			"月球足够明亮，光学稳定时可以看到陨石坑和月海。"
		))
		if bool(level.get("requires_telescope", false)):
			lines.append(_inline_text(
				"A telescope reveals detail your naked eye cannot separate.",
				"望远镜能分辨肉眼无法分开的细节。"
			))
	elif id == "jupiter" or id == "mars" or type_text.find("planet") >= 0:
		lines.append(_inline_text(
			"Planet detail depends on focus, magnification, and a steady mount.",
			"行星细节取决于调焦、倍率和支架稳定性。"
		))
		if variation != "":
			lines.append(_inline_text(
				"Tonight's variable: " + variation.replace("_", " ") + ".",
				"今晚变化的条件：" + variation.replace("_", " ") + "。"
			))
	elif id == "carina_cosmic_cliffs":
		lines.append(_inline_text(
			"Near-infrared reveals embedded newborn stars; mid-infrared maps the cooler dust around them.",
			"近红外显现内嵌的新生恒星；中红外描绘它们周围温度更低的尘埃。"
		))
	elif id == "horsehead_nebula_infrared":
		lines.append(_inline_text(
			"Visible light outlines the Horsehead as an opaque silhouette; infrared reveals stars shining through thinner dust.",
			"可见光把马头星云勾勒成不透明剪影；红外则显现穿过较薄尘埃的背景恒星。"
		))
	elif type_text.find("star") >= 0:
		lines.append(_inline_text(
			"Even through a telescope, stars stay point-like; brightness and color carry the clue.",
			"即使用望远镜，恒星也多半仍是点状；亮度和颜色才是线索。"
		))
		lines.append(_inline_text(
			"The finder scope helps place a tiny target into the narrow telescope view.",
			"寻星镜帮助把小目标送进狭窄的主镜视野。"
		))
	elif type_text.find("nebula") >= 0 or type_text.find("galaxy") >= 0 or id == "orion_nebula" or id == "andromeda":
		lines.append(_inline_text(
			"Faint deep-sky objects often look like soft smudges, not sharp planets.",
			"暗弱深空天体常像柔和的淡斑，而不是清晰的行星。"
		))
		lines.append(_inline_text(
			"Aperture, dark skies, and patient viewing matter more than raw magnification.",
			"口径、暗空和耐心观测比单纯高倍率更重要。"
		))
	else:
		var object_learning := _dict_inline(obj, "learning_text")
		if object_learning != "":
			lines.append(object_learning.replace("\n", " / "))

	var maya_recap := str(data.get("maya_recap_zh", "")) if GameManager.language_mode == "zh" else str(data.get("maya_recap_en", ""))
	if maya_recap != "":
		lines.append(GameManager.text("Maya: ", "玛雅：") + maya_recap)
	while lines.size() > 3:
		lines.pop_back()
	return lines


func _mission_object_image(obj: Dictionary, level: Dictionary = {}) -> String:
	var observation_media_path := _level_observation_media_path(level)
	if observation_media_path != "":
		return observation_media_path
	var id := str(obj.get("id", ""))
	var optical_master := OpticalMediaRegistry.master_path(id)
	if optical_master != "":
		return optical_master
	var path := ""
	match id:
		"moon":
			path = "res://assets/telescope_view/moon_clear.png"
		"mars":
			path = "res://assets/telescope_view/mars_clear.png"
		"jupiter":
			path = "res://assets/telescope_view/jupiter_clear.png"
		"vega":
			path = "res://assets/telescope_view/vega_user_clear.png"
		"orion_nebula":
			path = "res://assets/telescope_view/orion_nebula_clear.png"
		"carina_cosmic_cliffs":
			path = "res://assets/telescope_view/space_infrared/carina_cosmic_cliffs.png"
		"horsehead_nebula_infrared":
			path = "res://assets/telescope_view/space_infrared/horsehead_infrared.png"
		"andromeda":
			path = "res://assets/telescope_view/andromeda_clear.png"
		"betelgeuse":
			path = "res://assets/telescope_view/star_red_clear.png"
		"sirius":
			path = "res://assets/telescope_view/star_blue_clear.png"
		"polaris":
			path = "res://assets/telescope_view/star_white_clear.png"
		"arcturus":
			path = "res://assets/telescope_view/arcturus_clear.png"
		"canopus":
			path = "res://assets/telescope_view/canopus_clear.png"
		"alpha_centauri":
			path = "res://assets/telescope_view/alpha_cen_clear.png"
		"proxima":
			path = "res://assets/telescope_view/proxima_clear.png"
	if path != "" and ResourceLoader.exists(path):
		return path
	for key in ["result_sprite_path", "sprite_path", "icon_path"]:
		var candidate := str(obj.get(key, ""))
		if candidate != "" and ResourceLoader.exists(candidate):
			return candidate
	if bool(obj.get("radio_visible", false)):
		var radio_result := "res://assets/telescope_parts/fast_radio/pulsar_timing_console.png"
		if ResourceLoader.exists(radio_result):
			return radio_result
	return ""


func _level_observation_media_path(level: Dictionary) -> String:
	var media_value: Variant = level.get("observation_media", {})
	var media_id := ""
	if media_value is Dictionary:
		media_id = str((media_value as Dictionary).get("id", ""))
	else:
		media_id = str(media_value)
	if media_id == "":
		return ""
	var registry := _fast_observation_media()
	var entry_value: Variant = registry.get(media_id, {})
	if not entry_value is Dictionary:
		return ""
	var entry := entry_value as Dictionary
	if str(entry.get("status", "")) != "packaged":
		return ""
	var path := str(entry.get("image_path", ""))
	if path != "" and ResourceLoader.exists(path):
		return path
	return ""


func _fast_observation_media() -> Dictionary:
	if not _fast_observation_media_cache.is_empty():
		return _fast_observation_media_cache
	if not FileAccess.file_exists(FAST_OBSERVATION_MEDIA_PATH):
		return {}
	var file := FileAccess.open(FAST_OBSERVATION_MEDIA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_fast_observation_media_cache = parsed as Dictionary
	return _fast_observation_media_cache


func _mission_object_state_image(obj: Dictionary, state: String) -> String:
	var clear_path := _mission_object_image(obj)
	if clear_path == "" or state == "clear":
		return clear_path
	var state_path := clear_path.replace("_clear.png", "_%s.png" % state)
	if ResourceLoader.exists(state_path):
		return state_path
	return clear_path


func _mission_section_line(pos: Vector2, width: float) -> void:
	_rect(pos, Vector2(width, 1), PAPER_LINE)


func _paper_box(pos: Vector2, size: Vector2) -> void:
	var box := _rect(pos, size, PAPER_BOX)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect(pos, Vector2(size.x, 1), PAPER_LINE)
	_rect(pos + Vector2(0, size.y - 1), Vector2(size.x, 1), PAPER_LINE)
	_rect(pos, Vector2(1, size.y), PAPER_LINE)
	_rect(pos + Vector2(size.x - 1, 0), Vector2(1, size.y), PAPER_LINE)


func _paper_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(text, pos, size, font_size, color, align)
	label.remove_theme_color_override("font_shadow_color")
	label.remove_theme_constant_override("shadow_offset_x")
	label.remove_theme_constant_override("shadow_offset_y")
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _dark_panel(pos: Vector2, size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _mission_texture(path: String, pos: Vector2, size: Vector2, stretch: TextureRect.StretchMode) -> TextureRect:
	var rect := TextureRect.new()
	var texture: Texture2D = _load_texture(path)
	if texture != null:
		rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = stretch
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.position = pos
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)


func _mission_button(text: String, pos: Vector2, size: Vector2, color: Color) -> Button:
	var button := _button(text, pos, size)
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = GOLD
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = color.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	return button


func _inline_text(en: String, zh: String) -> String:
	if GameManager.language_mode == "zh":
		return zh
	return en


func _dict_inline(data: Dictionary, base: String) -> String:
	var en := str(data.get(base + "_en", data.get(base, "")))
	var zh := str(data.get(base + "_zh", en))
	return _inline_text(en, zh)


func _diagram(image_path: String, pos: Vector2, size: Vector2) -> void:
	if image_path == "" or not ResourceLoader.exists(image_path):
		return
	var diagram := TextureRect.new()
	# Property ORDER matters: expand_mode/custom_minimum_size must be set BEFORE
	# .texture. Assigning the texture first caches a minimum size equal to the
	# raw pixel size, and the later .size assignment is silently clamped back up
	# to it (Godot clamps Control.size to the cached minimum, and the expand_mode
	# recompute is deferred). With a 1672x941 source that would push the diagram
	# over the title, body and Start button.
	diagram.custom_minimum_size = Vector2.ZERO
	diagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# KEEP_ASPECT_CENTERED never stretches or crops; NEAREST keeps the pixel art crisp.
	diagram.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diagram.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diagram.texture = load(image_path)
	diagram.position = pos
	diagram.size = size
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram.name = "ConceptDiagram"
	add_child(diagram)


# Rect the diagram art actually covers on screen (KEEP_ASPECT_CENTERED letterboxes
# inside the control), for layout regression tests.
func debug_diagram_draw_rect() -> Rect2:
	var diagram := get_node_or_null("ConceptDiagram") as TextureRect
	if diagram == null or diagram.texture == null:
		return Rect2()
	var source: Vector2 = diagram.texture.get_size()
	if source.x <= 0.0 or source.y <= 0.0:
		return Rect2()
	var scale := minf(diagram.size.x / source.x, diagram.size.y / source.y)
	var drawn := source * scale
	return Rect2(diagram.position + (diagram.size - drawn) * 0.5, drawn)


func _panel(pos: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	return panel


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if color != PAPER_INK and color != PAPER_MUTED:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, pos: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 16)
	add_child(button)
	return button

func _on_language_changed() -> void:
	_build()
