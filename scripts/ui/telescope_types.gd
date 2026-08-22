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
const PREVIEW_PANEL_POS := Vector2(362, 116)
const PREVIEW_PANEL_SIZE := Vector2(634, 306)
const DETAIL_GRID_POS := Vector2(370, 438)

const FAMILY_BLUEPRINTS := {
	"refractor": "res://assets/learning_diagrams/refractor_light_path.png",
	"newtonian": "res://assets/assembly/newtonian_main_blueprint.png",
	"dobsonian": "res://assets/assembly/dobsonian_main_blueprint.png",
	"cassegrain": "res://assets/assembly/cassegrain_main_blueprint_cropped.png",
	"space_segmented": "res://assets/assembly/space_segmented_blueprint_cropped.png",
	"fast_radio": "res://assets/assembly/fast_blueprint_center_cropped.png",
}

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
var detail_container: GridContainer
var proceed_button: Button
var title_label: Label
var preview_panel: Panel
var preview_texture: TextureRect
var preview_title: Label
var preview_status: Label
var preview_reason: Label
var preview_meta: Label
var detail_tween: Tween


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
	cards.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_label(GameManager.text("INSTRUMENT CATALOG  /  06 DESIGNS", "仪器目录  /  06 种设计"), Vector2(28, 14), Vector2(968, 20), 10, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	title_label = _label(GameManager.text("SELECT A TELESCOPE TYPE", "选择望远镜类型"), Vector2(28, 31), Vector2(968, 38), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var subtitle := GameManager.text(
		"Choose the instrument whose physics match the target. Mission recommendations are guidance, not a restriction.",
		"按目标所需的物理特性选择仪器。任务推荐只是提示，不会限制你的选择。")
	if postgraduate_free_build:
		subtitle = GameManager.text(
			"Your unlocked optical telescopes are personal equipment. Space and FAST remain remote research facilities.",
			"已解锁的光学望远镜现为个人设备；空间红外与 FAST 仍是远程科研设施。")
	if browse_only:
		subtitle = GameManager.text("Reference catalog of every telescope family you can unlock.",
			"你可以解锁的所有望远镜家族参考手册。")
	_label(subtitle, Vector2(40, 70), Vector2(944, 22), 13, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	var divider := ColorRect.new()
	divider.position = Vector2(28, 101)
	divider.size = Vector2(968, 1)
	divider.color = Color(GOLD_DIM, 0.65)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	# ---- left: family list ----
	var list := VBoxContainer.new()
	list.name = "FamilyRail"
	list.position = Vector2(28, 116)
	list.size = Vector2(314, 548)
	list.add_theme_constant_override("separation", 8)
	add_child(list)
	for entry_value in FAMILIES:
		var entry: Dictionary = entry_value
		var id := str(entry["id"])
		var card := _family_card(entry)
		list.add_child(card)
		cards[id] = card

	# ---- right: blueprint preview ----
	preview_panel = Panel.new()
	preview_panel.name = "BlueprintPreview"
	preview_panel.position = PREVIEW_PANEL_POS
	preview_panel.size = PREVIEW_PANEL_SIZE
	preview_panel.clip_contents = true
	preview_panel.add_theme_stylebox_override("panel", _style(Color("071224"), GOLD, 2))
	add_child(preview_panel)

	preview_texture = TextureRect.new()
	preview_texture.name = "BlueprintTexture"
	preview_texture.position = Vector2(8, 8)
	preview_texture.size = PREVIEW_PANEL_SIZE - Vector2(16, 16)
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	preview_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_texture)

	var preview_scrim := ColorRect.new()
	preview_scrim.position = Vector2(0, 214)
	preview_scrim.size = Vector2(PREVIEW_PANEL_SIZE.x, 92)
	preview_scrim.color = Color(0.015, 0.027, 0.055, 0.94)
	preview_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_scrim)

	preview_meta = _panel_label(preview_panel, "", Vector2(18, 222), Vector2(380, 18), 10, CYAN)
	preview_title = _panel_label(preview_panel, "", Vector2(18, 239), Vector2(420, 30), 22, TEXT)
	preview_reason = _panel_label(preview_panel, "", Vector2(18, 270), Vector2(596, 28), 12, DIM)
	preview_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_status = _panel_label(preview_panel, "", Vector2(456, 232), Vector2(158, 32), 11, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	preview_status.add_theme_stylebox_override("normal", _style(Color(0.03, 0.10, 0.11, 0.94), GREEN, 1))

	# ---- right: compact facts ----
	detail_container = GridContainer.new()
	detail_container.name = "InstrumentFacts"
	detail_container.position = DETAIL_GRID_POS
	detail_container.size = Vector2(626, 222)
	detail_container.columns = 2
	detail_container.add_theme_constant_override("h_separation", 18)
	detail_container.add_theme_constant_override("v_separation", 8)
	add_child(detail_container)

	# ---- bottom buttons ----
	proceed_button = _button("", Vector2(614, 686), Vector2(382, 48), GOLD)
	proceed_button.name = "ProceedButton"
	proceed_button.pressed.connect(_proceed)
	add_child(proceed_button)
	var back := _button(GameManager.text("Back", "返回"), Vector2(362, 686), Vector2(232, 48), Color(0.16, 0.20, 0.30))
	back.name = "BackButton"
	back.pressed.connect(_go_back)
	add_child(back)

	_select(selected_family)


func _family_card(entry: Dictionary) -> Button:
	var id := str(entry["id"])
	var unlocked := _is_unlocked(entry)
	var button := Button.new()
	button.name = "Family_" + id
	button.custom_minimum_size = Vector2(314, 84)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = false
	var name := GameManager.dict_text(entry, "name")
	var state := GameManager.text("READY TO BUILD", "可装配")
	if not unlocked:
		state = GameManager.text("LOCKED · LEVEL %d" % int(entry.get("unlock", 0)), "未解锁 · 第 %d 关" % int(entry.get("unlock", 0)))
	elif id == _recommended_family() and not browse_only:
		state = GameManager.text("MISSION MATCH", "符合本关任务")
	elif postgraduate_free_build and GameManager.is_player_optical_family(id):
		state = GameManager.text("OWNED · FREE BUILD", "已拥有 · 自由组装")
	button.text = ""
	button.tooltip_text = name + " — " + state
	button.clip_contents = true
	var blueprint_path := str(FAMILY_BLUEPRINTS.get(id, ""))
	var thumbnail := TextureRect.new()
	thumbnail.position = Vector2(10, 10)
	thumbnail.size = Vector2(64, 64)
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if blueprint_path != "" and ResourceLoader.exists(blueprint_path):
		thumbnail.texture = load(blueprint_path) as Texture2D
	thumbnail.modulate = Color.WHITE if unlocked else Color(0.38, 0.42, 0.48)
	button.add_child(thumbnail)
	var name_label := _panel_label(button, name, Vector2(88, 17), Vector2(210, 27), 15, TEXT if unlocked else LOCK)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var state_label := _panel_label(button, state, Vector2(88, 45), Vector2(210, 20), 10, GOLD if unlocked else LOCK)
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_stylebox_override("normal", _style(PANEL, GOLD_DIM if unlocked else Color(0.20, 0.24, 0.30), 1, 12))
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
	if detail_tween != null and detail_tween.is_valid():
		detail_tween.kill()
	for child in detail_container.get_children():
		detail_container.remove_child(child)
		child.queue_free()
	var unlocked := _is_unlocked(entry)
	var status_text := GameManager.text("READY TO BUILD", "可装配")
	var status_color := GREEN
	var reason_text := GameManager.text(
		"Unlocked and ready for the assembly bench.",
		"已经解锁，可以进入装配台。")
	if not unlocked:
		status_text = GameManager.text("LOCKED · LEVEL %d" % int(entry.get("unlock", 0)),
			"未解锁 · 第 %d 关" % int(entry.get("unlock", 0)))
		status_color = LOCK
		reason_text = GameManager.text(
			"Continue the campaign to unlock this instrument and its assembly bench.",
			"继续推进课程，即可解锁这台仪器及其装配台。")
	elif postgraduate_free_build:
		if GameManager.is_player_optical_family(id):
			status_text = GameManager.text("OWNED · FREE BUILD", "已拥有 · 自由组装")
			status_color = GREEN
			reason_text = GameManager.text(
				"Your personal telescope. Its configuration is saved separately for free observation.",
				"这是你的个人望远镜；自由观测配置会单独保存。")
		else:
			status_text = GameManager.text("REMOTE FACILITY", "远程科研设施")
			status_color = CYAN
			reason_text = GameManager.text(
				"Build its training model, then request remote observing time. The facility is not personal equipment.",
				"先组装教学模型，再申请远程观测时间；该设施不属于个人设备。")
	elif not browse_only and id == _recommended_family():
		status_text = GameManager.text("MISSION MATCH", "符合本关任务")
		status_color = GOLD
		reason_text = _recommendation_reason(id)

	var blueprint_path := str(FAMILY_BLUEPRINTS.get(id, ""))
	preview_texture.texture = load(blueprint_path) as Texture2D if ResourceLoader.exists(blueprint_path) else null
	preview_meta.text = GameManager.text(
		"INSTRUMENT %02d  /  UNLOCK LEVEL %02d" % [_family_index(id), int(entry.get("unlock", 0))],
		"仪器 %02d  /  第 %02d 关解锁" % [_family_index(id), int(entry.get("unlock", 0))])
	preview_title.text = GameManager.dict_text(entry, "name")
	preview_status.text = status_text
	preview_status.add_theme_color_override("font_color", status_color)
	preview_status.add_theme_stylebox_override("normal", _style(Color(0.03, 0.07, 0.10, 0.94), status_color, 1))
	preview_reason.text = reason_text

	detail_container.add_child(_fact_block(GameManager.text("HOW IT WORKS", "工作原理"), GameManager.dict_text(entry, "principle")))
	detail_container.add_child(_fact_block(GameManager.text("STRENGTHS", "优点"), GameManager.dict_text(entry, "pros")))
	detail_container.add_child(_fact_block(GameManager.text("TRADE-OFFS", "局限"), GameManager.dict_text(entry, "cons")))
	detail_container.add_child(_fact_block(GameManager.text("BEST TARGETS", "适合目标"), GameManager.dict_text(entry, "targets")))

	preview_panel.position = PREVIEW_PANEL_POS + Vector2(8, 0)
	preview_panel.modulate.a = 0.45
	detail_container.position = DETAIL_GRID_POS + Vector2(8, 0)
	detail_container.modulate.a = 0.45
	detail_tween = create_tween().set_parallel(true)
	detail_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	detail_tween.tween_property(preview_panel, "position", PREVIEW_PANEL_POS, 0.18)
	detail_tween.tween_property(preview_panel, "modulate:a", 1.0, 0.14)
	detail_tween.tween_property(detail_container, "position", DETAIL_GRID_POS, 0.18)
	detail_tween.tween_property(detail_container, "modulate:a", 1.0, 0.14)

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
		card.add_theme_stylebox_override("normal", _style(Color(0.10, 0.16, 0.26) if active else PANEL, border, 2 if active else 1, 12))


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


func _family_index(id: String) -> int:
	for index in range(FAMILIES.size()):
		if str(FAMILIES[index]["id"]) == id:
			return index + 1
	return 1


func _fact_block(heading: String, body: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(304, 104)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("091426"), Color(0.22, 0.34, 0.49), 1, 12))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	panel.add_child(content)
	var heading_label := Label.new()
	heading_label.text = heading
	heading_label.add_theme_font_size_override("font_size", 11)
	heading_label.add_theme_color_override("font_color", GOLD)
	heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(heading_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.custom_minimum_size = Vector2(280, 68)
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("font_size", 11)
	body_label.add_theme_color_override("font_color", TEXT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(body_label)
	return panel


func _panel_label(parent: Control, value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
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


func _style(fill: Color, border: Color, width: int, horizontal_margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(6)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
