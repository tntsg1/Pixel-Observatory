extends Control

# Telescope Type Selection screen.
#
# Two jobs:
#   1. A browsable catalog of every telescope family - principle, pros, cons,
#      suitable targets, unlock state - reachable any time from the observatory.
#   2. The confirm step in front of an advanced-assembly lesson: it names the
#      family the mission recommends AND why, but every UNLOCKED family stays
#      selectable, so the player is never silently forced onto one bench.
#
# It never changes level data. "Proceed" simply routes to the correct assembly
# scene for the family the player is looking at; the recommended family is only
# highlighted, not enforced.

const GOLD := Color("e0aa46")
const GOLD_DIM := Color("8a6a2c")
const CYAN := Color("55c7df")
const GREEN := Color("6fdf8a")
const TEXT := Color("ece8dc")
const DIM := Color("8391a6")
const BG := Color("05070f")
const PANEL := Color("0b1424")
const LOCK := Color("4a5568")

# Family unlock levels come from the campaign's first level of each family
# block (advanced_levels.json). refractor is the L1 starter tuning bench.
const FAMILIES := [
	{
		"id": "refractor", "unlock": 1, "scene": "assembly",
		"name_en": "Refractor", "name_zh": "折射式",
		"principle_en": "Light passes through a lens (objective) that bends it to a focus at the far end of a sealed tube.",
		"principle_zh": "光线穿过物镜（透镜），被折射后在密闭镜筒的另一端汇聚成像。",
		"pros_en": "Sharp, high-contrast views; sealed tube needs no alignment; great for the Moon and planets.",
		"pros_zh": "成像锐利、对比度高；密闭镜筒无需准直；非常适合月亮和行星。",
		"cons_en": "Large lenses are heavy and costly; shows color fringing (chromatic aberration) on bright stars.",
		"cons_zh": "大口径透镜又重又贵；观测亮星时会出现色差（红蓝边）。",
		"targets_en": "Moon, planets, double stars, bright targets.",
		"targets_zh": "月亮、行星、双星、明亮目标。"
	},
	{
		"id": "newtonian", "unlock": 26, "scene": "advanced_assembly",
		"name_en": "Newtonian Reflector", "name_zh": "牛顿反射式",
		"principle_en": "A curved primary mirror gathers light; a flat secondary on a spider redirects it out the side to the eyepiece.",
		"principle_zh": "凹面主镜收集光线，蜘蛛支架上的平面副镜把光引向侧面的目镜。",
		"pros_en": "Mirrors have NO chromatic aberration; large aperture is affordable; excellent for deep sky.",
		"pros_zh": "镜面完全没有色差；大口径成本低；非常适合深空观测。",
		"cons_en": "Mirrors drift out of alignment - needs collimation; open tube collects dust and air currents.",
		"cons_zh": "镜面会偏离对准——需要准直；开放镜筒易进灰尘、受气流影响。",
		"targets_en": "Nebulae, galaxies, star clusters, faint deep-sky light.",
		"targets_zh": "星云、星系、星团、暗弱深空目标。"
	},
	{
		"id": "dobsonian", "unlock": 36, "scene": "advanced_assembly",
		"name_en": "Dobsonian", "name_zh": "多布森",
		"principle_en": "A Newtonian optical tube on a simple, sturdy altitude-azimuth rocker box you push by hand.",
		"principle_zh": "把牛顿镜筒装在简单坚固的地平式摇箱上，用手推动指向。",
		"pros_en": "The most aperture per dollar; stable and intuitive; sweeps the sky quickly.",
		"pros_zh": "每一分钱换来最大口径；稳定直观；扫视天空很快。",
		"cons_en": "No motor - you track by hand; tall tubes are bulky; still a mirror to collimate.",
		"cons_zh": "没有马达——追踪靠手推；长镜筒体积大；镜面仍需准直。",
		"targets_en": "Large, bright deep-sky objects; sweeping the Milky Way.",
		"targets_zh": "大而亮的深空天体；巡视银河。"
	},
	{
		"id": "cassegrain", "unlock": 46, "scene": "advanced_assembly",
		"name_en": "Cassegrain", "name_zh": "卡塞格林",
		"principle_en": "Two mirrors fold a long focal length into a short tube: the primary reflects to a convex secondary, then back through a hole in the primary.",
		"principle_zh": "两面镜子把长焦距折叠进短镜筒：主镜反射到凸面副镜，再穿过主镜中央的孔成像。",
		"pros_en": "Long focal length in a compact, portable tube; high magnification for small targets.",
		"pros_zh": "短镜筒里塞进长焦距，紧凑便携；对小目标可用高倍率。",
		"cons_en": "Narrow field of view; two mirrors to align; slower to cool down.",
		"cons_zh": "视场狭窄；两面镜子都要对准；降温较慢。",
		"targets_en": "Planets, small planetary nebulae, tight double stars.",
		"targets_zh": "行星、小型行星状星云、紧密双星。"
	},
	{
		"id": "space_segmented", "unlock": 66, "scene": "advanced_assembly",
		"name_en": "Infrared / Space", "name_zh": "红外 / 空间",
		"principle_en": "A large segmented mirror above the atmosphere feeds cold infrared instruments that read heat, not visible light.",
		"principle_zh": "大气层之上的大型分段主镜，把光送入低温红外仪器——读的是热辐射而非可见光。",
		"pros_en": "Sees through dust; detects the coldest, most distant objects; no atmospheric blur.",
		"pros_zh": "能穿透尘埃；探测最冷、最遥远的天体；没有大气扰动。",
		"cons_en": "Must stay extremely cold; no eyepiece - you read data; enormous and complex.",
		"cons_zh": "必须保持极低温；没有目镜——靠读数据；体量巨大、结构复杂。",
		"targets_en": "Dust-shrouded nurseries, deep-field galaxies, cold gas.",
		"targets_zh": "尘埃笼罩的恒星摇篮、深场星系、冷气体。"
	},
	{
		"id": "fast_radio", "unlock": 76, "scene": "advanced_assembly",
		"name_en": "FAST Radio", "name_zh": "FAST 射电",
		"principle_en": "A giant dish focuses radio waves onto a receiver; there is no image, only a signal trace you tune and interpret.",
		"principle_zh": "巨大的天线把射电波聚到接收机上；没有图像，只有一条需要你调谐和解读的信号轨迹。",
		"pros_en": "Detects invisible radio sources - pulsars, hydrogen clouds; works day or night, through clouds.",
		"pros_zh": "探测看不见的射电源——脉冲星、氢云；昼夜、阴天都能工作。",
		"cons_en": "No visual image at all; needs a huge fixed dish; vulnerable to radio interference.",
		"cons_zh": "完全没有可见图像；需要巨大的固定天线；易受无线电干扰。",
		"targets_en": "Pulsars, neutral hydrogen, radio galaxies, transient bursts.",
		"targets_zh": "脉冲星、中性氢、射电星系、瞬变暴。"
	}
]


var browse_only := false
var postgraduate_free_build := false
var selected_family := ""
var cards: Dictionary = {}
var detail_container: VBoxContainer
var proceed_button: Button
var title_label: Label


func _ready() -> void:
	# browse_only when opened from the observatory info entry; otherwise this is
	# the confirm step for the current lesson's advanced assembly.
	browse_only = bool(GameManager.get_meta("telescope_types_browse", false))
	postgraduate_free_build = GameManager.postgraduate_free_build()
	selected_family = GameManager.assembly_family()
	if _entry(selected_family).is_empty() or not _is_unlocked(_entry(selected_family)):
		selected_family = _recommended_family()
	_build()
	InteractionFeedback.page_enter(self)


func _recommended_family() -> String:
	if postgraduate_free_build:
		return GameManager.assembly_family()
	if browse_only:
		return "refractor"
	var family := str(GameManager.current_level().get("telescope_family", "refractor"))
	for entry in FAMILIES:
		if str(entry["id"]) == family:
			return family
	return "refractor"


func _highest_level_reached() -> int:
	var current := int(GameManager.progress.get("current_level", 1))
	var completed: Array = GameManager.progress.get("completed_levels", [])
	var best := current
	for value in completed:
		best = maxi(best, int(value))
	return best


func _is_unlocked(entry: Dictionary) -> bool:
	return _highest_level_reached() >= int(entry.get("unlock", 999))


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	title_label = _label(GameManager.text("SELECT A TELESCOPE TYPE", "选择望远镜类型"), Vector2(40, 22), Vector2(944, 40), 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle := GameManager.text(
		"Browse every design. Unlocked types can be built now; the mission's recommendation is marked.",
		"浏览每一种设计。已解锁的类型现在就能装配；任务推荐的类型已标出。")
	if postgraduate_free_build:
		subtitle = GameManager.text(
			"Your unlocked optical telescopes are personal equipment. Space and FAST remain remote research facilities.",
			"已解锁的光学望远镜现为个人设备；空间红外与 FAST 仍是远程科研设施。")
	if browse_only:
		subtitle = GameManager.text("Reference catalog of every telescope family you can unlock.",
			"你可以解锁的所有望远镜家族参考手册。")
	_label(subtitle, Vector2(40, 62), Vector2(944, 26), 14, DIM, HORIZONTAL_ALIGNMENT_CENTER)

	# ---- left: family list ----
	var list := VBoxContainer.new()
	list.position = Vector2(40, 104)
	list.size = Vector2(320, 620)
	list.add_theme_constant_override("separation", 8)
	add_child(list)
	for entry_value in FAMILIES:
		var entry: Dictionary = entry_value
		var id := str(entry["id"])
		var card := _family_card(entry)
		list.add_child(card)
		cards[id] = card

	# ---- right: detail panel ----
	var detail_panel := Panel.new()
	detail_panel.position = Vector2(384, 104)
	detail_panel.size = Vector2(600, 560)
	detail_panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 2))
	add_child(detail_panel)
	detail_container = VBoxContainer.new()
	detail_container.position = Vector2(404, 122)
	detail_container.size = Vector2(564, 524)
	detail_container.add_theme_constant_override("separation", 10)
	add_child(detail_container)

	# ---- bottom buttons ----
	proceed_button = _button("", Vector2(624, 684), Vector2(360, 48), GOLD)
	proceed_button.pressed.connect(_proceed)
	add_child(proceed_button)
	var back := _button(GameManager.text("Back", "返回"), Vector2(384, 684), Vector2(220, 48), Color(0.16, 0.20, 0.30))
	back.pressed.connect(_go_back)
	add_child(back)

	_select(selected_family)


func _family_card(entry: Dictionary) -> Button:
	var id := str(entry["id"])
	var unlocked := _is_unlocked(entry)
	var button := Button.new()
	button.custom_minimum_size = Vector2(320, 68)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = false
	var name := GameManager.dict_text(entry, "name")
	var lock_tag := "" if unlocked else GameManager.text("  [LOCKED]", "  [未解锁]")
	button.text = name + lock_tag
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT if unlocked else LOCK)
	button.add_theme_color_override("font_color_hover", GOLD)
	button.add_theme_stylebox_override("normal", _style(PANEL, GOLD_DIM if unlocked else Color(0.20, 0.24, 0.30), 1))
	button.add_theme_stylebox_override("hover", _style(Color(0.10, 0.16, 0.26), GOLD, 1))
	button.add_theme_stylebox_override("pressed", _style(Color(0.10, 0.16, 0.26), GOLD, 2))
	button.pressed.connect(_select.bind(id))
	InteractionFeedback.bind_button(button)
	return button


func _select(id: String) -> void:
	selected_family = id
	for family_id in cards.keys():
		var family_card := cards.get(family_id) as Control
		if family_card != null:
			InteractionFeedback.selection(family_card, str(family_id) == id, GOLD, true, "telescope_family_selected")
	var entry := _entry(id)
	if entry.is_empty():
		return
	for child in detail_container.get_children():
		child.queue_free()
	var unlocked := _is_unlocked(entry)

	var header := _free_label(GameManager.dict_text(entry, "name"), 22, GOLD)
	detail_container.add_child(header)

	var status_text := ""
	var status_color := GREEN
	if not unlocked:
		status_text = GameManager.text("Locked - reach campaign level %d to unlock." % int(entry.get("unlock", 0)),
			"未解锁——推进到第 %d 关即可解锁。" % int(entry.get("unlock", 0)))
		status_color = LOCK
	elif postgraduate_free_build:
		if GameManager.is_player_optical_family(id):
			status_text = GameManager.optical_equipment_ownership_label(id) + "\n" + GameManager.text(
				"Free rebuild enabled. This family's configuration is saved separately.",
				"已开放自由改装，这一家族的配置会单独保存。")
			status_color = GREEN
		else:
			status_text = GameManager.optical_equipment_ownership_label(id) + "\n" + GameManager.text(
				"You may assemble its training model and request remote observing time; the facility is not personal equipment.",
				"你可以组装教学模型并申请远程观测时间；该设施不属于个人设备。")
			status_color = CYAN
	elif not browse_only and id == _recommended_family():
		status_text = GameManager.text("Recommended for tonight's mission.", "今晚任务推荐使用。")
		status_color = GOLD
	else:
		status_text = GameManager.optical_equipment_ownership_label(id) if GameManager.is_player_optical_family(id) else GameManager.text("Unlocked - ready to build.", "已解锁——可以装配。")
	detail_container.add_child(_free_label(status_text, 14, status_color))

	if not postgraduate_free_build and not browse_only and id == _recommended_family():
		var why := _recommendation_reason(id)
		if why != "":
			detail_container.add_child(_wrapped(why, 13, CYAN))

	detail_container.add_child(_section(GameManager.text("How it works", "工作原理"), GameManager.dict_text(entry, "principle")))
	detail_container.add_child(_section(GameManager.text("Strengths", "优点"), GameManager.dict_text(entry, "pros")))
	detail_container.add_child(_section(GameManager.text("Trade-offs", "缺点"), GameManager.dict_text(entry, "cons")))
	detail_container.add_child(_section(GameManager.text("Best targets", "适合目标"), GameManager.dict_text(entry, "targets")))

	# proceed button reflects selection state
	if not _is_unlocked(entry):
		proceed_button.disabled = true
		proceed_button.text = GameManager.text("Locked", "未解锁")
	elif browse_only or postgraduate_free_build:
		proceed_button.disabled = false
		proceed_button.text = GameManager.text(
			("Open %s free-build bench" if postgraduate_free_build else "Open %s bench") % GameManager.dict_text(entry, "name"),
			("打开 %s 自由组装台" if postgraduate_free_build else "打开 %s 装配台") % GameManager.dict_text(entry, "name"))
	else:
		proceed_button.disabled = false
		if id == _recommended_family():
			proceed_button.text = GameManager.text("Build recommended: %s" % GameManager.dict_text(entry, "name"), "装配推荐：%s" % GameManager.dict_text(entry, "name"))
		else:
			proceed_button.text = GameManager.text("Build %s instead" % GameManager.dict_text(entry, "name"), "改为装配：%s" % GameManager.dict_text(entry, "name"))

	# highlight the active card
	for card_id in cards:
		var card: Button = cards[card_id]
		var e := _entry(card_id)
		var active: bool = card_id == id
		var border := GOLD if active else (GOLD_DIM if _is_unlocked(e) else Color(0.20, 0.24, 0.30))
		card.add_theme_stylebox_override("normal", _style(Color(0.10, 0.16, 0.26) if active else PANEL, border, 2 if active else 1))


func _recommendation_reason(id: String) -> String:
	var target := GameManager.dict_text(GameManager.current_target(), "name")
	match id:
		"newtonian":
			return GameManager.text(
				"Mirrors remove the chromatic aberration a refractor showed on %s, and gather more light for deep sky." % target,
				"镜面能消除折射镜观测 %s 时出现的色差，并为深空收集更多光线。" % target)
		"dobsonian":
			return GameManager.text(
				"Its large aperture and wide sweep suit the bright, extended target %s." % target,
				"它的大口径和宽视场适合明亮而延展的目标 %s。" % target)
		"cassegrain":
			return GameManager.text(
				"Its long folded focal length gives the high magnification %s needs in a portable tube." % target,
				"它折叠的长焦距能为 %s 提供所需的高倍率，而镜筒依然便携。" % target)
		"gregorian":
			return GameManager.text(
				"Trace where the concave secondary refocuses the light - compare its path deliberately for %s." % target,
				"追踪凹面副镜在哪里重新聚焦光线——为 %s 有目的地比较光路。" % target)
		"space_segmented":
			return GameManager.text(
				"Only cold infrared optics above the atmosphere can reveal %s." % target,
				"只有大气层之上的低温红外光学才能揭示 %s。" % target)
		"fast_radio":
			return GameManager.text(
				"%s emits radio, not visible light - a dish and receiver are the only way to detect it." % target,
				"%s 发出的是射电而非可见光——只有天线和接收机才能探测到它。" % target)
		_:
			return GameManager.text(
				"A sealed refractor gives the sharp, high-contrast view %s rewards." % target,
				"密闭折射镜能给出 %s 所需的锐利、高对比度视野。" % target)


func _proceed() -> void:
	var entry := _entry(selected_family)
	if entry.is_empty() or not _is_unlocked(entry):
		return
	GameManager.set_meta("telescope_types_browse", false)
	GameManager.select_assembly_family(selected_family)
	GameManager.remove_meta("telescope_types_return_scene")
	# Route to the correct bench for the chosen family. Level data is untouched;
	# for a browse-only visit we still open the matching assembly scene so the
	# player can inspect the bench.
	var scene := str(entry.get("scene", "assembly"))
	GameManager.go(scene)


func _go_back() -> void:
	GameManager.set_meta("telescope_types_browse", false)
	var return_scene := str(GameManager.get_meta("telescope_types_return_scene", GameManager.assembly_scene_key()))
	GameManager.remove_meta("telescope_types_return_scene")
	GameManager.go(return_scene)


# ------------------------------------------------------------------ helpers


func _entry(id: String) -> Dictionary:
	for entry_value in FAMILIES:
		if str(entry_value["id"]) == id:
			return entry_value
	return {}


func _section(heading: String, body: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_free_label(heading, 14, GOLD))
	box.add_child(_wrapped(body, 13, TEXT))
	return box


func _free_label(value: String, font_size: int, color: Color) -> Label:
	# Unparented label for container content (the _label helper adds to self,
	# which would error on a second add_child into a container).
	var label := Label.new()
	label.text = value
	label.custom_minimum_size = Vector2(560, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _wrapped(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.custom_minimum_size = Vector2(560, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(value: String, pos: Vector2, button_size: Vector2, tint: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(tint.darkened(0.5), tint, 2))
	button.add_theme_stylebox_override("hover", _style(tint.darkened(0.3), tint.lightened(0.2), 2))
	button.add_theme_stylebox_override("pressed", _style(tint.darkened(0.6), tint, 2))
	button.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.10, 0.14), Color(0.30, 0.34, 0.40), 1))
	InteractionFeedback.bind_button(button)
	return button


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
