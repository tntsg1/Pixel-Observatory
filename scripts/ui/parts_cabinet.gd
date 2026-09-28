extends Control

const SCREEN_SIZE := Vector2(1024, 768)
const PANEL := Color(0.045, 0.065, 0.115, 0.96)
const PANEL_DARK := Color(0.020, 0.030, 0.055, 0.98)
const CARD_BG := Color(0.040, 0.058, 0.100, 0.96)
const CARD_EQUIPPED := Color(0.050, 0.075, 0.070, 0.98)
const CARD_LOCKED := Color(0.035, 0.040, 0.052, 0.92)
const BRASS := Color(0.78, 0.56, 0.28)
const GOLD := Color(0.96, 0.76, 0.38)
const BLUE_EDGE := Color(0.18, 0.28, 0.44)
const WARM_TEXT := Color(0.95, 0.93, 0.86)
const MUTED := Color(0.68, 0.76, 0.80)
const GREEN := Color(0.45, 0.95, 0.56)
const WARNING := Color(1.0, 0.70, 0.34)

const HEADER_RECT := Rect2(18, 14, 988, 56)
const SUMMARY_RECT := Rect2(36, 86, 952, 86)
const LIST_RECT := Rect2(36, 188, 952, 510)
const CARD_SIZE := Vector2(916, 170)
const PART_ICON_TEXTURES := {
	"basic_tripod": "res://assets/telescope_parts/basic_tripod.png",
	"basic_mount": "res://assets/telescope_parts/basic_mount.png",
	"starter_tube": "res://assets/telescope_parts/starter_tube.png",
	"objective_60mm": "res://assets/telescope_parts/objective_60mm.png",
	"eyepiece_20mm": "res://assets/telescope_parts/eyepiece_20mm.png",
	"basic_finder_scope": "res://assets/telescope_parts/basic_finder_scope.png",
	"eyepiece_10mm": "res://assets/telescope_parts/eyepiece_10mm.png",
	"objective_100mm": "res://assets/telescope_parts/objective_100mm.png",
	"stable_mount": "res://assets/telescope_parts/stable_mount.png",
	"tracking_mount": "res://assets/telescope_parts/tracking_mount.png",
	"basic_focus_knob": "res://assets/telescope_parts/basic_focus_knob.png",
	"gregorian_equatorial_mount": "res://assets/telescope_parts/gregorian_equatorial_mount.png",
	"gregorian_18mm_eyepiece": "res://assets/telescope_parts/gregorian_18mm_eyepiece.png"
}

const CATEGORY_ORDER := ["Support", "Optics", "Aiming", "Control"]
func _category_label(cat: String) -> String:
	var labels := {"Support": ["Support", "支撑"], "Optics": ["Optics", "光学"], "Aiming": ["Aiming", "瞄准"], "Control": ["Control", "控制"]}
	var pair: Array = labels.get(cat, [cat, cat])
	return GameManager.text(str(pair[0]), str(pair[1]))

# TYPE_LABELS helper — returns localized label per field
func _type_label(part_type: String, field: String) -> String:
	var labels := {
		"tripod": {"en": "Tripod", "zh": "三脚架", "role_en": "Support", "role_zh": "支撑", "category": "Support"},
		"mount": {"en": "Mount", "zh": "支架", "role_en": "Turns and steadies the telescope", "role_zh": "转动与稳定", "category": "Support"},
		"tube": {"en": "Tube", "zh": "镜筒", "role_en": "Keeps optics aligned", "role_zh": "保持光路对齐", "category": "Support"},
		"objective": {"en": "Objective Lens", "zh": "物镜", "role_en": "Collects light", "role_zh": "集光", "category": "Optics"},
		"eyepiece": {"en": "Eyepiece", "zh": "目镜", "role_en": "Magnifies the image", "role_zh": "放大", "category": "Optics"},
		"finder_scope": {"en": "Finder Scope", "zh": "寻星镜", "role_en": "Aims before high power", "role_zh": "寻星", "category": "Aiming"},
		"focus_knob": {"en": "Focus Knob", "zh": "调焦旋钮", "role_en": "Sharpens the image", "role_zh": "调清图像", "category": "Control"},
		"primary_mirror": {"en": "Primary Mirror", "zh": "主镜", "role_en": "Collects infrared light", "role_zh": "收集红外光", "category": "Optics"},
		"secondary_mirror": {"en": "Secondary Mirror", "zh": "副镜", "role_en": "Returns the beam to the instruments", "role_zh": "把光束送回仪器", "category": "Optics"},
		"steering_mirror": {"en": "Steering Mirror", "zh": "精细转向镜", "role_en": "Removes fine pointing error", "role_zh": "消除精细指向误差", "category": "Aiming"},
		"tertiary_mirror": {"en": "Tertiary Mirror", "zh": "第三反射镜", "role_en": "Feeds the instrument bay", "role_zh": "把光束送入仪器舱", "category": "Optics"},
		"detector": {"en": "Detector Package", "zh": "探测器总成", "role_en": "Converts infrared photons to data", "role_zh": "把红外光子转换为数据", "category": "Control"},
		"sunshield": {"en": "Sunshield", "zh": "遮阳罩", "role_en": "Keeps the cold side in shadow", "role_zh": "让低温侧保持阴影", "category": "Support"},
		"spacecraft_bus": {"en": "Spacecraft Bus", "zh": "航天器平台", "role_en": "Power, control and station keeping", "role_zh": "供电、控制与轨道维持", "category": "Support"},
		"deployable_tower": {"en": "Deployable Tower", "zh": "可展开塔架", "role_en": "Separates cold optics from the warm bus", "role_zh": "分隔低温光学与温热平台", "category": "Support"},
		"deployment_hinges": {"en": "Deployment Hinges", "zh": "展开铰链", "role_en": "Unfolds mirror wings and sunshield", "role_zh": "展开镜翼与遮阳罩", "category": "Support"},
		"solar_array": {"en": "Solar Array", "zh": "太阳能电池阵", "role_en": "Powers the observatory", "role_zh": "为天文台供电", "category": "Support"},
		"antenna": {"en": "Communication Antenna", "zh": "通信天线", "role_en": "Downlinks science data", "role_zh": "向地面回传科学数据", "category": "Control"},
		"radiator": {"en": "Thermal Radiator", "zh": "热辐射散热器", "role_en": "Rejects instrument heat", "role_zh": "排出仪器热量", "category": "Support"},
		"instrument_bay": {"en": "Instrument Bay", "zh": "仪器舱", "role_en": "Holds the cold science instruments", "role_zh": "承载低温科学仪器", "category": "Control"},
		"detector_module": {"en": "Detector Module", "zh": "探测器模块", "role_en": "Reads the instrument focal planes", "role_zh": "读取仪器焦平面", "category": "Control"},
		"nircam": {"en": "NIRCam", "zh": "NIRCam 近红外相机", "role_en": "Near-infrared imaging", "role_zh": "近红外成像", "category": "Control"},
		"nirspec": {"en": "NIRSpec", "zh": "NIRSpec 近红外光谱仪", "role_en": "Infrared spectroscopy", "role_zh": "红外光谱分析", "category": "Control"},
		"miri": {"en": "MIRI", "zh": "MIRI 中红外仪器", "role_en": "Cold dust and molecular imaging", "role_zh": "冷尘埃与分子成像", "category": "Control"},
		"fgs_niriss": {"en": "FGS/NIRISS", "zh": "FGS/NIRISS 导星仪", "role_en": "Fine guidance and niche imaging", "role_zh": "精细导星与专用成像", "category": "Aiming"}
	}
	var entry: Dictionary = labels.get(part_type, {"en": part_type, "zh": part_type, "role_en": "", "role_zh": "", "category": "Control"})
	if field == "category":
		return str(entry.get("category", "Control"))
	return GameManager.text(str(entry.get(field + "_en", entry.get(field, ""))), str(entry.get(field + "_zh", "")))

var feedback_text := ""
var feedback_color := GOLD
var parts_box: VBoxContainer
var parts_scroll: ScrollContainer
var next_step_part_type := ""
var selected_family := ""
var auto_equip_popup: Control
var reassembly_route_ready := false

# --- Mobile touch scrolling -------------------------------------------------
# Driven from _input (which runs BEFORE gui propagation) so a swipe scrolls the
# list whether the finger lands on a card, on the Equip button, or in the gap
# between cards - child controls can no longer swallow the gesture. A press only
# becomes a scroll after DRAG_THRESHOLD pixels of vertical travel; below that it
# stays a tap, so selection and Equip behave exactly as they do with a mouse.
const DRAG_THRESHOLD := 10.0
const SELECTION := Color(0.42, 0.82, 1.0)

var selected_part_id := ""
var _touch_active := false
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _touch_start_scroll := 0
var _touch_dragged := false
# Touch emulation raises a mouse click right after the finger lifts; a gesture
# that turned into a scroll must not let that click reach an Equip button.
var _suppress_emulated_click := false

# Family tabs shown above the parts list. "" = All.
const FAMILY_TABS := [
	["all", "All", "全部"],
	["refractor", "Refractor", "折射式"],
	["newtonian", "Newtonian", "牛顿式"],
	["dobsonian", "Dobsonian", "多布森"],
	["cassegrain", "Cassegrain", "卡塞格林"],
	["space_segmented", "Infrared Space", "红外空间"],
	["fast_radio", "FAST Radio", "FAST 射电"],
]
# Universal ("" family) parts are compatible with these ground optical tabs.
const UNIVERSAL_COMPAT := ["refractor", "newtonian", "dobsonian"]


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)
	call_deferred("_scroll_to_next_step")


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = SCREEN_SIZE
	next_step_part_type = _next_step_part_type()
	if selected_family == "":
		var current_family := GameManager.assembly_context_family()
		selected_family = current_family if current_family != "" else "refractor"

	_rect(Vector2.ZERO, SCREEN_SIZE, Color(0.010, 0.016, 0.032))
	_draw_star_grid()
	_draw_title_bar()
	if not GameManager.postgraduate_free_build() and GameManager.current_equipment_stage() == "eye":
		_draw_empty_eye_stage()
		return
	_draw_summary_panel()
	_draw_parts_list()
	_draw_family_tabs()


func _draw_title_bar() -> void:
	_panel(HEADER_RECT.position, HEADER_RECT.size, Color(0.030, 0.045, 0.085, 0.98), BLUE_EDGE)
	var title := _label_to(self, GameManager.text("Parts Cabinet", "零件柜"), Vector2(252, 24), Vector2(520, 32), 24, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF

	var back_text := GameManager.text("Continue to Assembly", "前往组装台") if reassembly_route_ready else GameManager.text("Back to Base", "返回基地")
	var back := _button(back_text, Vector2(842, 22), Vector2(144, 40))
	back.name = "CabinetPrimaryRouteButton"
	back.set_meta("destination_scene", GameManager.assembly_scene_key() if reassembly_route_ready else "observatory")
	back.pressed.connect(func() -> void:
		if reassembly_route_ready:
			_go_to_assembly_after_equipping()
		else:
			GameManager.set_observatory_spawn("cabinet")
			GameManager.go("observatory")
	)
	add_child(back)

	if GameManager.current_equipment_stage() != "eye":
		var auto_button := _button(GameManager.text("Auto Equip Best", "一键装备最佳组合"), Vector2(652, 22), Vector2(182, 40))
		auto_button.add_theme_font_size_override("font_size", 13)
		auto_button.pressed.connect(_show_auto_equip_preview)
		add_child(auto_button)


func _show_auto_equip_preview() -> void:
	# Preview first; nothing is written until the player confirms.
	var plan: Array = GameManager.auto_equip_plan()
	if plan.is_empty():
		_show_feedback(GameManager.text("No compatible parts to equip.", "没有可装备的兼容零件。"), WARNING)
		return
	if auto_equip_popup != null:
		auto_equip_popup.queue_free()
	auto_equip_popup = Control.new()
	auto_equip_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	auto_equip_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(auto_equip_popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	auto_equip_popup.add_child(dim)
	var height := minf(150.0 + float(plan.size()) * 48.0, 700.0)
	var panel := Panel.new()
	panel.position = Vector2(232, (768.0 - height) * 0.5)
	panel.size = Vector2(560, height)
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.055, 0.10, 0.98), GOLD, 2, 6))
	auto_equip_popup.add_child(panel)
	_label_to(panel, GameManager.text("Auto Equip Preview", "一键装备预览"), Vector2(20, 14), Vector2(520, 26), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(panel, GameManager.text("Chosen for the current target. Confirm to equip.", "已按当前目标选择。确认后才会装备。"), Vector2(20, 44), Vector2(520, 18), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var preview_scroll := ScrollContainer.new()
	preview_scroll.position = Vector2(20, 72)
	preview_scroll.size = Vector2(520, height - 140)
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(preview_scroll)
	var preview_rows := VBoxContainer.new()
	preview_rows.custom_minimum_size = Vector2(496, 0)
	preview_rows.add_theme_constant_override("separation", 4)
	preview_scroll.add_child(preview_rows)
	for entry_value in plan:
		var entry: Dictionary = entry_value
		var changed := bool(entry.get("changed", false))
		var pinned := bool(entry.get("pinned", false))
		var row := Control.new()
		row.custom_minimum_size = Vector2(496, 44)
		preview_rows.add_child(row)
		var row_text := GameManager.text(str(entry.get("name_en", "")), str(entry.get("name_zh", "")))
		if pinned:
			row_text += GameManager.text("  [lesson-required]", "【本关指定】")
		else:
			row_text += GameManager.text("  (change)", "（更换）") if changed else GameManager.text("  (kept)", "（保持）")
		_label_to(row, row_text, Vector2(8, 0), Vector2(480, 20), 12, WARNING if pinned else (GOLD if changed else Color(0.72, 0.80, 0.86)))
		var reason := GameManager.text(str(entry.get("reason_en", "")), str(entry.get("reason_zh", "")))
		if reason != "":
			var reason_label := _label_to(row, GameManager.text("Why: ", "原因：") + reason, Vector2(24, 21), Vector2(464, 18), 10, Color(0.62, 0.72, 0.80))
			reason_label.clip_text = true
	var confirm := _button(GameManager.text("Confirm", "确认装备"), Vector2(120, height - 56), Vector2(140, 38))
	confirm.pressed.connect(func() -> void:
		var applied: int = GameManager.apply_auto_equip(plan)
		auto_equip_popup.queue_free()
		auto_equip_popup = null
		reassembly_route_ready = applied > 0
		if reassembly_route_ready:
			GameManager.set_room_guidance_for_scene("assembly")
		_show_feedback(GameManager.text("Equipped %d parts. Reassemble at the Assembly Table.", "已更换 %d 件零件。请回组装台重新安装。") % applied, GREEN)
	)
	panel.add_child(confirm)
	var cancel := _button(GameManager.text("Cancel", "取消"), Vector2(300, height - 56), Vector2(140, 38))
	cancel.pressed.connect(func() -> void:
		auto_equip_popup.queue_free()
		auto_equip_popup = null
	)
	panel.add_child(cancel)


func _show_feedback(message: String, color: Color) -> void:
	feedback_text = message
	feedback_color = color
	_build()


func _draw_family_tabs() -> void:
	var x := LIST_RECT.position.x + 10.0
	var y := LIST_RECT.position.y + 8.0
	for tab_value in FAMILY_TABS:
		var tab_id := str(tab_value[0])
		var tab_text := GameManager.text(str(tab_value[1]), str(tab_value[2]))
		var locked := not _family_unlocked(tab_id)
		if locked:
			tab_text += " 🔒"
		var tab := Button.new()
		tab.text = tab_text
		tab.position = Vector2(x, y)
		tab.size = Vector2(114, 30)
		tab.add_theme_font_size_override("font_size", 11)
		tab.focus_mode = Control.FOCUS_NONE
		var active := selected_family == tab_id
		var style := _style(Color(0.10, 0.16, 0.26) if active else Color(0.045, 0.062, 0.10), GOLD if active else (Color(0.24, 0.28, 0.34) if locked else BLUE_EDGE), 2, 4)
		tab.add_theme_stylebox_override("normal", style)
		tab.add_theme_stylebox_override("hover", style)
		tab.add_theme_stylebox_override("pressed", style)
		tab.add_theme_color_override("font_color", GOLD if active else (Color(0.52, 0.56, 0.62) if locked else Color(0.80, 0.86, 0.92)))
		tab.pressed.connect(func() -> void:
			selected_family = tab_id
			_build()
		)
		add_child(tab)
		x += 118.0


func _part_visible_in_tab(part_family: String) -> bool:
	if selected_family == "all":
		return true
	if part_family == selected_family:
		return true
	if part_family == "":
		return selected_family in UNIVERSAL_COMPAT
	return false


func _family_unlocked(family: String) -> bool:
	if family in ["all", "refractor", ""]:
		return true
	for part in GameManager.parts_data:
		if str(part.get("telescope_family", "")) == family and _is_unlocked(str(part.get("id", ""))):
			return true
	return false


func _draw_empty_eye_stage() -> void:
	_panel(Vector2(202, 282), Vector2(620, 194), PANEL, BRASS)
	_label_to(
		self,
		GameManager.text("No telescope parts yet. Finish the naked-eye observations first.", "还没有望远镜零件。先完成肉眼观测，玛雅很快会解锁第一套折射镜组件。"),
		Vector2(244, 312),
		Vector2(536, 122),
		16,
		WARM_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _draw_summary_panel() -> void:
	_panel(SUMMARY_RECT.position, SUMMARY_RECT.size, Color(0.040, 0.060, 0.105, 0.96), BRASS)
	var mission := GameManager.current_level()
	var mission_title := GameManager.dict_text(mission, "title")
	var stage := _stage_label(GameManager.current_equipment_stage())
	var summary := GameManager.text("Mission: ", "任务: ") + mission_title + "\n" + GameManager.text("Equipment: ", "设备: ") + stage
	_label_to(self, summary, Vector2(58, 102), Vector2(558, 44), 13, Color(0.84, 0.90, 0.90))
	_label_to(self, GameManager.text("Recommended parts marked in gold. Reassemble at Assembly Table after swapping.", "当前任务零件建议会以金色标记。更换零件后需要回组装台重新安装。"), Vector2(58, 145), Vector2(560, 18), 12, Color(0.72, 0.82, 0.86))

	var ready_text := GameManager.text("READY", "已就绪") if GameManager.telescope_is_ready() else GameManager.text("NEEDS ASSEMBLY", "需要组装")
	var ready_color := GREEN if GameManager.telescope_is_ready() else WARNING
	_label_to(self, ready_text, Vector2(738, 100), Vector2(224, 20), 14, ready_color, HORIZONTAL_ALIGNMENT_RIGHT)
	_label_to(self, GameManager.text("Club Credits: %d", "社团积分: %d") % int(GameManager.progress.get("credits", 0)) + "\n" + GameManager.text("Unlocked: %d / %d", "已解锁: %d / %d") % [_unlocked_count(), GameManager.parts_data.size()], Vector2(748, 124), Vector2(214, 42), 12, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)

	if feedback_text != "":
		var chip := _badge_to(self, feedback_text, Vector2(624, 164), Vector2(342, 20), feedback_color, HORIZONTAL_ALIGNMENT_RIGHT)
		chip.add_theme_font_size_override("font_size", 10)


func _draw_parts_list() -> void:
	_panel(LIST_RECT.position, LIST_RECT.size, PANEL_DARK, BLUE_EDGE)
	parts_scroll = ScrollContainer.new()
	parts_scroll.position = LIST_RECT.position + Vector2(14, 48)
	parts_scroll.size = LIST_RECT.size - Vector2(28, 62)
	parts_scroll.clip_contents = true
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(parts_scroll)

	parts_box = VBoxContainer.new()
	parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parts_box.add_theme_constant_override("separation", 10)
	parts_scroll.add_child(parts_box)

	if not _family_unlocked(selected_family):
		var notice := Control.new()
		notice.custom_minimum_size = Vector2(CARD_SIZE.x, 26)
		_label_to(notice, GameManager.text("This family is not unlocked yet - later missions will open it. Parts below are preview only.", "该望远镜家族尚未解锁——完成后续任务后开放。以下零件仅供预览。"), Vector2(8, 2), Vector2(880, 22), 12, WARNING)
		parts_box.add_child(notice)

	var grouped := _grouped_parts()
	for category in CATEGORY_ORDER:
		var group: Array = grouped.get(category, [])
		if group.is_empty():
			continue
		parts_box.add_child(_category_header(str(_category_label(category))))
		for part_value in group:
			var part: Dictionary = part_value
			parts_box.add_child(_part_card(part))


func _category_header(text: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(CARD_SIZE.x, 28)
	var line := _rect_to(root, Vector2(0, 20), Vector2(CARD_SIZE.x, 1), Color(BRASS.r, BRASS.g, BRASS.b, 0.45))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_to(root, text, Vector2(8, 1), Vector2(280, 22), 15, GOLD)
	return root


func _part_card(part: Dictionary) -> Control:
	var part_type := str(part.get("type", ""))
	var part_id := str(part.get("id", ""))
	var type_info: Dictionary = {"en": _type_label(part_type, "en"), "zh": _type_label(part_type, "zh"), "role": _type_label(part_type, "role")}
	var unlocked := _is_unlocked(part_id)
	var equipped := GameManager.equipped_part_id(part_type) == part_id
	var exact_required_id := _required_id_for_type(part_type)
	var exact_required := exact_required_id == part_id
	var pending_step_part_id := GameManager.pending_mission_step_part_id(part_type)
	var pending_step_required := pending_step_part_id == part_id
	var required_for_mission := pending_step_part_id == "" and (
		GameManager.required_part_types_for_current_level().has(part_type)
		or (
			GameManager.assembly_context_family() == "space_segmented"
			and GameManager.space_segmented_install_types().has(part_type)
		)
	)
	var incompatible_equipped := equipped and exact_required_id != "" and not exact_required
	var recommended := _is_recommended(part)
	var is_next_step := (
		part_type == next_step_part_type
		and (pending_step_part_id == "" or pending_step_required)
	)

	var root := Control.new()
	root.custom_minimum_size = CARD_SIZE
	root.name = "part_card_%s" % part_type

	var bg := CARD_BG
	var border := BLUE_EDGE
	if incompatible_equipped:
		bg = Color(0.18, 0.075, 0.045)
		border = WARNING
	elif equipped:
		bg = CARD_EQUIPPED
		border = GREEN
	elif exact_required or pending_step_required or required_for_mission or recommended or is_next_step:
		border = GOLD
	elif not unlocked:
		bg = CARD_LOCKED
		border = Color(0.18, 0.20, 0.24)

	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", _style(bg, border, 3 if incompatible_equipped or exact_required or recommended else 2, 5))
	root.add_child(panel)
	_panel_corners_to(root, Vector2.ZERO, CARD_SIZE, border)

	if incompatible_equipped:
		_badge_to(root, GameManager.text("Equipped, but not accepted by this mission", "已装备，但不符合本关指定"), Vector2(122, 10), Vector2(322, 22), WARNING)
	elif exact_required:
		_badge_to(root, GameManager.text("Lesson-required: this level teaches this device", "本关指定零件——本关正在学习/要求该设备"), Vector2(122, 10), Vector2(380, 22), GOLD)
	elif pending_step_required:
		_badge_to(root, GameManager.text("Required for the current experiment", "当前实验指定目镜"), Vector2(122, 10), Vector2(286, 22), GOLD)
	elif required_for_mission:
		_badge_to(root, GameManager.text("Required for current mission", "本关必需"), Vector2(122, 10), Vector2(250, 22), GOLD)
	elif recommended:
		_badge_to(root, GameManager.text("Recommended for current mission", "当前任务推荐"), Vector2(122, 10), Vector2(322, 22), GOLD)
	elif pending_step_part_id == "" and unlocked and GameManager.pinned_part_id(part_type) == "" and str(GameManager.best_part_for_type(part_type).get("id", "")) == part_id:
		_badge_to(root, GameManager.text("Best available for this mission", "本关可用的最佳零件"), Vector2(122, 10), Vector2(300, 22), GOLD)
	elif is_next_step:
		_badge_to(root, GameManager.text("Next assembly step", "下一步安装"), Vector2(122, 10), Vector2(220, 22), WARNING)
	# Free-slot upgrade warning: equipped part beaten by an unlocked one.
	if equipped and pending_step_part_id == "" and GameManager.pinned_part_id(part_type) == "":
		var best_part: Dictionary = GameManager.best_part_for_type(part_type)
		if not best_part.is_empty() and str(best_part.get("id", "")) != part_id:
			_badge_to(root, GameManager.text("Better available: ", "可用更佳设备：") + GameManager.dict_text(best_part, "name"), Vector2(446, 10), Vector2(286, 22), Color(1.0, 0.55, 0.40))

	var icon_box := _rect_to(root, Vector2(18, 34), Vector2(70, 70), Color(0.070, 0.090, 0.120))
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_icon(root, part, Vector2(18, 34), Vector2(70, 70), unlocked)

	var text_x := 106.0
	var title_y := 36.0 if not incompatible_equipped and not exact_required and not recommended and not is_next_step else 34.0
	var name_color := WARM_TEXT if unlocked else Color(0.52, 0.58, 0.62)
	_label_to(root, GameManager.dict_text(part, "name"), Vector2(text_x, title_y), Vector2(370, 20), 15, name_color)
	_label_to(root, _type_label(str(part.get("type", "")), "role"), Vector2(text_x, title_y + 22), Vector2(370, 18), 13, Color(0.78, 0.88, 0.88) if unlocked else Color(0.46, 0.52, 0.54))
	_badge_to(root, str(type_info.get("role", GameManager.text("Equipment", "设备"))), Vector2(text_x, title_y + 45), Vector2(250, 20), Color(0.46, 0.66, 0.86))

	var desc := _short_description(part)
	var desc_label := _label_to(root, desc, Vector2(text_x, title_y + 72), Vector2(500, 34), 12, Color(0.78, 0.84, 0.84) if unlocked else Color(0.46, 0.50, 0.54))
	desc_label.max_lines_visible = 2

	_draw_stat_chips(root, part, Vector2(18, 132), unlocked)
	_draw_action_column(root, part, unlocked, equipped, incompatible_equipped)

	# Tap-selection marker: an inner outline, so the equipped / locked / required
	# border colours above stay exactly as they are.
	root.set_meta("part_id", part_id)
	var selection := Panel.new()
	selection.name = "SelectionOutline"
	selection.position = Vector2(3, 3)
	selection.size = CARD_SIZE - Vector2(6, 6)
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), SELECTION, 2, 4))
	selection.visible = part_id == selected_part_id
	root.add_child(selection)
	return root


func _draw_action_column(root: Control, part: Dictionary, unlocked: bool, equipped: bool, incompatible_equipped: bool) -> void:
	var part_id := str(part.get("id", ""))
	var part_type := str(part.get("type", ""))
	var column_x := CARD_SIZE.x - 174.0
	var badge_text := GameManager.text("Locked", "未解锁")
	var badge_color := Color(0.42, 0.46, 0.50)
	if incompatible_equipped:
		badge_text = GameManager.text("Wrong for mission", "不符合本关")
		badge_color = WARNING
	elif equipped:
		badge_text = GameManager.text("Equipped", "已装备")
		badge_color = GREEN
	elif unlocked:
		badge_text = GameManager.text("Available", "可装备")
		badge_color = GOLD
	_badge_to(root, badge_text, Vector2(column_x, 24), Vector2(146, 24), badge_color, HORIZONTAL_ALIGNMENT_CENTER)

	var button := Button.new()
	button.name = "EquipButton"
	button.position = Vector2(column_x + 18, 62)
	button.size = Vector2(110, 38)
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	if equipped:
		button.text = GameManager.text("Replace required", "请换指定件") if incompatible_equipped else GameManager.text("Equipped", "已装备")
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _style(Color(0.18, 0.075, 0.045), WARNING, 2, 3) if incompatible_equipped else _style(Color(0.07, 0.14, 0.10), GREEN, 2, 3))
		button.add_theme_color_override("font_disabled_color", Color(1.0, 0.78, 0.48) if incompatible_equipped else Color(0.72, 1.0, 0.76))
	elif not unlocked:
		button.text = GameManager.text("Locked", "未解锁")
		button.disabled = true
		button.add_theme_stylebox_override("disabled", _style(Color(0.05, 0.055, 0.065), Color(0.16, 0.17, 0.19), 2, 3))
		button.add_theme_color_override("font_disabled_color", Color(0.42, 0.44, 0.48))
	else:
		button.text = GameManager.text("Equip", "装备")
		button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.13, 0.22), BLUE_EDGE, 2, 3))
		button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.22, 0.34), BRASS, 2, 3))
		button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.14, 0.08), BRASS, 2, 3))
		button.pressed.connect(func() -> void:
			if GameManager.equip_part(part_id):
				feedback_color = GREEN
				feedback_text = GameManager.text("Equipped %s. Reassembly required." % str(part.get("name_en", part_id)), "已装备%s。请回组装台重新安装。" % _safe_zh_name(part, str(part_type)))
				reassembly_route_ready = true
				GameManager.set_room_guidance_for_scene("assembly")
				_build()
				call_deferred("_scroll_to_part_type", part_type)
		)
	root.add_child(button)

	var lock_note := _unlock_note(part, unlocked)
	_label_to(root, lock_note, Vector2(column_x - 2, 110), Vector2(154, 28), 10, MUTED if unlocked else Color(0.45, 0.47, 0.50), HORIZONTAL_ALIGNMENT_CENTER)


func _go_to_assembly_after_equipping() -> void:
	GameManager.set_room_guidance_for_scene("assembly")
	GameManager.set_observatory_spawn("assembly")
	GameManager.go(GameManager.assembly_scene_key())


func _draw_stat_chips(parent: Control, part: Dictionary, pos: Vector2, unlocked: bool) -> void:
	var chips := _part_stat_chips(part)
	if chips.is_empty():
		chips.append(GameManager.text("No special stats", "暂无特殊属性"))
	var x := pos.x
	var y := pos.y
	for chip in chips:
		var width := clampf(46.0 + float(str(chip).length()) * 5.6, 72.0, 150.0)
		if x + width > CARD_SIZE.x - 190.0:
			x = pos.x
			y += 24.0
			if y > pos.y + 25.0:
				break
		_badge_to(parent, str(chip), Vector2(x, y), Vector2(width, 19), Color(0.38, 0.58, 0.72) if unlocked else Color(0.28, 0.32, 0.38), HORIZONTAL_ALIGNMENT_CENTER)
		x += width + 8.0


func _draw_icon(parent: Control, part: Dictionary, box_pos: Vector2, box_size: Vector2, unlocked: bool = true) -> void:
	var part_id := str(part.get("id", ""))
	# Advanced parts (Newtonian etc.) carry their icon in the data file.
	var texture_path := str(PART_ICON_TEXTURES.get(part_id, str(part.get("icon_path", ""))))
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var texture: Texture2D = load(texture_path)
		var native_size := texture.get_size()
		var scale := minf((box_size.x - 8.0) / native_size.x, (box_size.y - 8.0) / native_size.y)
		var draw_size := native_size * scale
		var icon := TextureRect.new()
		icon.texture = texture
		icon.position = box_pos + (box_size - draw_size) * 0.5
		icon.size = native_size
		icon.scale = Vector2.ONE * scale
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color(1, 1, 1, 1.0 if unlocked else 0.28)
		parent.add_child(icon)
		return

	var part_type := str(part.get("type", ""))
	var alpha := 1.0 if unlocked else 0.35
	var color := Color(0.52, 0.70, 0.86, alpha)
	match part_type:
		"tripod":
			color = Color(0.56, 0.62, 0.68, alpha)
			_rect_to(parent, box_pos + Vector2(32, 12), Vector2(8, 34), color)
			_rect_to(parent, box_pos + Vector2(18, 46), Vector2(36, 6), color.lightened(0.08))
			_rect_to(parent, box_pos + Vector2(16, 52), Vector2(6, 12), color.darkened(0.10))
			_rect_to(parent, box_pos + Vector2(50, 52), Vector2(6, 12), color.darkened(0.10))
		"mount":
			color = Color(0.62, 0.68, 0.74, alpha)
			_rect_to(parent, box_pos + Vector2(22, 20), Vector2(28, 28), color)
			_rect_to(parent, box_pos + Vector2(31, 10), Vector2(10, 48), color.lightened(0.08))
			_rect_to(parent, box_pos + Vector2(17, 52), Vector2(42, 5), color.darkened(0.14))
		"tube":
			color = Color(0.30, 0.58, 0.86, alpha)
			_rect_to(parent, box_pos + Vector2(12, 31), Vector2(42, 14), color)
			_rect_to(parent, box_pos + Vector2(52, 24), Vector2(12, 28), color.lightened(0.12))
			_rect_to(parent, box_pos + Vector2(9, 28), Vector2(6, 20), color.darkened(0.12))
		"objective":
			color = Color(0.66, 0.88, 0.94, alpha)
			_rect_to(parent, box_pos + Vector2(24, 14), Vector2(24, 42), color)
			_rect_to(parent, box_pos + Vector2(20, 25), Vector2(32, 8), color.darkened(0.12))
			_rect_to(parent, box_pos + Vector2(30, 18), Vector2(8, 34), Color(0.90, 1.0, 1.0, alpha * 0.45))
		"eyepiece":
			color = Color(0.46, 0.54, 0.62, alpha)
			_rect_to(parent, box_pos + Vector2(22, 24), Vector2(30, 26), color)
			_rect_to(parent, box_pos + Vector2(12, 30), Vector2(14, 14), color.darkened(0.10))
			_rect_to(parent, box_pos + Vector2(50, 28), Vector2(8, 18), color.lightened(0.10))
		"focus_knob":
			color = Color(0.88, 0.68, 0.32, alpha)
			_rect_to(parent, box_pos + Vector2(20, 18), Vector2(30, 30), color)
			_rect_to(parent, box_pos + Vector2(26, 24), Vector2(18, 18), color.darkened(0.18))
			_rect_to(parent, box_pos + Vector2(34, 10), Vector2(4, 10), color.lightened(0.12))
			_rect_to(parent, box_pos + Vector2(34, 48), Vector2(4, 10), color.darkened(0.12))
			_rect_to(parent, box_pos + Vector2(12, 31), Vector2(10, 4), color.darkened(0.12))
			_rect_to(parent, box_pos + Vector2(48, 31), Vector2(10, 4), color.lightened(0.12))
		_:
			color = Color(0.38, 0.68, 0.92, alpha)
			_rect_to(parent, box_pos + Vector2(12, 30), Vector2(42, 12), color)
			_rect_to(parent, box_pos + Vector2(52, 24), Vector2(10, 24), color.lightened(0.12))
			_rect_to(parent, box_pos + Vector2(16, 22), Vector2(30, 4), color.darkened(0.10))


func _grouped_parts() -> Dictionary:
	var grouped := {}
	for category in CATEGORY_ORDER:
		grouped[category] = []
	var parts := GameManager.parts_data.duplicate()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac := _category_index(_category_for_part(a))
		var bc := _category_index(_category_for_part(b))
		if ac != bc:
			return ac < bc
		var at := _type_rank(str(a.get("type", "")))
		var bt := _type_rank(str(b.get("type", "")))
		if at != bt:
			return at < bt
		return int(a.get("unlock_level", 999)) < int(b.get("unlock_level", 999))
	)
	for part_value in parts:
		var part: Dictionary = part_value
		if not _part_visible_in_tab(str(part.get("telescope_family", ""))):
			continue
		var category := _category_for_part(part)
		if not grouped.has(category):
			grouped[category] = []
		grouped[category].append(part)
	return grouped


func _category_for_part(part: Dictionary) -> String:
	var part_type := str(part.get("type", ""))
	var info: Dictionary = {"en": _type_label(part_type, "en"), "zh": _type_label(part_type, "zh"), "role": _type_label(part_type, "role")}
	return str(info.get("category", "Control"))


func _category_index(category: String) -> int:
	var index := CATEGORY_ORDER.find(category)
	return index if index >= 0 else 99


func _type_rank(part_type: String) -> int:
	var order := [
		"tripod", "mount", "tube", "objective", "eyepiece", "finder_scope", "focus_knob",
		"primary_mirror", "secondary_mirror", "steering_mirror", "tertiary_mirror",
		"detector", "sunshield", "spacecraft_bus", "deployable_tower", "deployment_hinges",
		"solar_array", "antenna", "radiator", "instrument_bay", "detector_module",
		"nircam", "nirspec", "miri", "fgs_niriss",
	]
	var index := order.find(part_type)
	return index if index >= 0 else 99


func _is_unlocked(part_id: String) -> bool:
	return GameManager.progress.get("unlocked_parts", []).has(part_id)


func _unlocked_count() -> int:
	var total := 0
	for part in GameManager.parts_data:
		if _is_unlocked(str(part.get("id", ""))):
			total += 1
	return total


func _is_recommended(part: Dictionary) -> bool:
	if GameManager.postgraduate_free_build():
		return false
	var part_id := str(part.get("id", ""))
	var part_type := str(part.get("type", ""))
	var level := GameManager.current_level()
	if (
		str(level.get("telescope_family", "")) == "space_segmented"
		and GameManager.space_segmented_install_types().has(part_type)
	):
		return _is_unlocked(part_id)
	var exact_required_id := _required_id_for_type(part_type)
	# A prescribed experiment takes priority over generic target advice. Do
	# not mark a higher-stat mount as recommended when this level explicitly
	# asks the player to compare using a different mount.
	if exact_required_id != "":
		return part_id == exact_required_id
	var pending_step_part_id := GameManager.pending_mission_step_part_id(part_type)
	if pending_step_part_id != "":
		return part_id == pending_step_part_id
	if part_type == "eyepiece" and not GameManager.eyepiece_meets_active_magnification(part):
		return false
	if _array_has_string(level.get("recommended_part_ids", []), part_id):
		return true
	var target_id := GameManager.current_target_object_id()
	if target_id in ["orion_nebula", "andromeda"] and part_id in ["objective_100mm", "stable_mount", "eyepiece_20mm", "tracking_mount"]:
		return _is_unlocked(part_id)
	if target_id in ["mars", "jupiter"] and part_id in ["stable_mount", "eyepiece_10mm"]:
		return _is_unlocked(part_id)
	if target_id == "moon" and part_id == "eyepiece_10mm":
		return _is_unlocked(part_id)
	return false


func _required_id_for_type(part_type: String) -> String:
	if GameManager.postgraduate_free_build():
		return String()
	for required_id_value in GameManager.current_level().get("required_part_ids", []):
		var required_id := str(required_id_value)
		var required_part := GameManager.get_part(required_id)
		if str(required_part.get("type", "")) == part_type:
			return required_id
	return ""


func _array_has_string(values: Variant, needle: String) -> bool:
	if not values is Array:
		return false
	for value in values:
		if str(value) == needle:
			return true
	return false


func _next_step_part_type() -> String:
	var required: Array[String] = GameManager.required_part_types_for_current_level()
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	for value in required:
		var part_type := str(value)
		var entry: Dictionary = state.get(part_type, {})
		if not bool(entry.get("installed", false)):
			return part_type
	return ""


# --- touch scrolling / tap selection ---------------------------------------


func _input(event: InputEvent) -> void:
	if parts_scroll == null or not is_inside_tree():
		return
	if event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func _handle_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_suppress_emulated_click = false
		if not list_viewport_rect().has_point(touch.position):
			return
		_touch_active = true
		_touch_index = touch.index
		_touch_start = touch.position
		_touch_start_scroll = parts_scroll.scroll_vertical
		_touch_dragged = false
		return
	if not _touch_active or touch.index != _touch_index:
		return
	var was_drag := _touch_dragged
	_touch_active = false
	_touch_index = -1
	_touch_dragged = false
	if was_drag:
		# A scroll must never equip anything or open another screen: swallow the
		# release, and the emulated click that follows it.
		_suppress_emulated_click = true
		get_viewport().set_input_as_handled()
		return
	_tap_select(touch.position)


func _handle_drag(drag: InputEventScreenDrag) -> void:
	if not _touch_active or drag.index != _touch_index:
		return
	if not _touch_dragged and absf(drag.position.y - _touch_start.y) < DRAG_THRESHOLD:
		return
	_touch_dragged = true
	scroll_by_drag(drag.position)
	# Consumed so the ScrollContainer's own touch handling cannot double-apply.
	get_viewport().set_input_as_handled()


func _handle_mouse_button(mouse: InputEventMouseButton) -> void:
	# Wheel events are deliberately untouched - the ScrollContainer keeps them.
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _suppress_emulated_click:
		if not mouse.pressed:
			_suppress_emulated_click = false
		get_viewport().set_input_as_handled()
		return
	if not mouse.pressed and list_viewport_rect().has_point(mouse.position):
		_tap_select(mouse.position)


func scroll_by_drag(position_now: Vector2) -> void:
	# Finger moving up yields a negative delta, which must scroll the list DOWN.
	var delta_y := position_now.y - _touch_start.y
	parts_scroll.scroll_vertical = int(clampf(float(_touch_start_scroll) - delta_y, 0.0, float(max_scroll_offset())))


func max_scroll_offset() -> int:
	if parts_scroll == null:
		return 0
	var bar := parts_scroll.get_v_scroll_bar()
	if bar != null and bar.max_value > 0.0:
		return int(maxf(0.0, bar.max_value - bar.page))
	if parts_box == null:
		return 0
	return int(maxf(0.0, parts_box.size.y - parts_scroll.size.y))


func list_viewport_rect() -> Rect2:
	if parts_scroll == null:
		return Rect2()
	return parts_scroll.get_global_rect()


func _tap_select(pos: Vector2) -> void:
	var card := card_at(pos)
	if card == null:
		return
	# A tap on the Equip button belongs to the button: let its own pressed signal
	# run so equip / compatibility rules stay exactly as they are.
	var equip := card.get_node_or_null("EquipButton") as Button
	if equip != null and equip.get_global_rect().has_point(pos):
		return
	select_part(str(card.get_meta("part_id", "")))


func card_at(pos: Vector2) -> Control:
	if parts_box == null:
		return null
	for child in parts_box.get_children():
		var control := child as Control
		if control == null or not control.has_meta("part_id"):
			continue
		if control.get_global_rect().has_point(pos):
			return control
	return null


# Selection only toggles an outline - never a rebuild - so selecting a card can
# never move the list under the player's finger.
func select_part(part_id: String) -> void:
	if part_id == "":
		return
	selected_part_id = part_id
	_refresh_selection_outlines()


func _refresh_selection_outlines() -> void:
	if parts_box == null:
		return
	for child in parts_box.get_children():
		if not child.has_meta("part_id"):
			continue
		var outline := child.get_node_or_null("SelectionOutline") as Control
		var is_selected := str(child.get_meta("part_id", "")) == selected_part_id
		if outline != null:
			outline.visible = is_selected
		if child is Control:
			InteractionFeedback.selection(child as Control, is_selected, SELECTION, false, "part_selected")


func _scroll_to_next_step() -> void:
	if next_step_part_type != "":
		_scroll_to_part_type(next_step_part_type)


func _scroll_to_part_type(part_type: String) -> void:
	if parts_scroll == null or parts_box == null:
		return
	await get_tree().process_frame
	for child in parts_box.get_children():
		if child.name == "part_card_%s" % part_type:
			parts_scroll.scroll_vertical = max(0, int(child.position.y) - 36)
			# First finder night: spotlight the Basic Finder Scope card so the
			# finder lesson flows Cabinet -> Assembly -> Sky.
			if part_type == "finder_scope" and child is Control and not InteractionFeedback.was_tutorial_seen("first_finder_cabinet"):
				InteractionFeedback.tutorial_highlight_once(child as Control, "first_finder_cabinet", GameManager.text(
					"This is your Basic Finder Scope - equip it, then install it at the Assembly Table.",
					"这是你的基础寻星镜——先装备它，再到组装台安装。"
				), self)
			return


func _short_description(part: Dictionary) -> String:
	var part_id := str(part.get("id", ""))
	match part_id:
		"objective_100mm":
			return GameManager.text("More light for faint targets.", "收集更多光，适合星云和星系。")
		"eyepiece_10mm":
			return GameManager.text("More magnification, narrower and dimmer view.", "倍率更高，但视野更窄更暗。")
		"stable_mount":
			return GameManager.text("Less shake at high magnification.", "高倍率下抖动更少。")
		"tracking_mount":
			return GameManager.text("Tracks sky drift for long observations.", "抵消星空漂移，适合长时间观测。")
		"basic_focus_knob":
			return GameManager.text("Moves the eyepiece to sharpen focus.", "移动目镜，让图像清晰。")
	return GameManager.dict_text(part, "description")


func _safe_zh_name(part: Dictionary, fallback: String) -> String:
	var part_id := str(part.get("id", ""))
	var names := {
		"basic_tripod": "基础三脚架",
		"basic_mount": "基础支架",
		"starter_tube": "入门镜筒",
		"objective_60mm": "60mm 入门物镜",
		"eyepiece_20mm": "20mm 低倍率目镜",
		"basic_finder_scope": "基础寻星镜",
		"eyepiece_10mm": "10mm 高倍率目镜",
		"objective_100mm": "100mm 大口径物镜",
		"stable_mount": "重型稳定支架",
		"tracking_mount": "追踪支架",
		"basic_focus_knob": "基础调焦旋钮"
	}
	return str(names.get(part_id, part.get("name_zh", fallback)))


func _part_stat_chips(part: Dictionary) -> Array[String]:
	var chips: Array[String] = []
	if part.has("aperture_mm"):
		chips.append(GameManager.text("Aperture: %smm", "口径: %smm") % part.get("aperture_mm"))
	if part.has("focal_length_mm"):
		chips.append(GameManager.text("Focal: %smm", "焦距: %smm") % part.get("focal_length_mm"))
	if part.has("quality"):
		chips.append(GameManager.text("Quality: %s", "质量: %s") % part.get("quality"))
	if part.has("field_of_view"):
		chips.append(GameManager.text("FOV: %s", "视野: %s") % part.get("field_of_view"))
	if part.has("stability"):
		chips.append(GameManager.text("Stability: %s", "稳定: %s") % part.get("stability"))
	if part.has("stability_bonus"):
		chips.append(GameManager.text("Stability: %s", "稳定: %s") % part.get("stability_bonus"))
	if part.has("tracking"):
		chips.append(GameManager.text("Tracking: %s", "追踪: %s") % part.get("tracking"))
	if part.has("aim_assist"):
		chips.append(GameManager.text("Aim: %s", "瞄准: %s") % part.get("aim_assist"))
	if part.has("focus_sensitivity"):
		chips.append(GameManager.text("Focus: %s", "调焦: %s") % part.get("focus_sensitivity"))
	return chips


func _unlock_note(part: Dictionary, unlocked: bool) -> String:
	if unlocked:
		return ""
	if str(part.get("type", "")) == "finder_scope" and GameManager.required_part_types_for_current_level().has("finder_scope"):
		return GameManager.text("Complete Finder Scope Introduction first", "请先完成寻星镜教学")
	var level := int(part.get("unlock_level", 999))
	if level < 999:
		return GameManager.text("Unlocks at L%d" % level, "第 %d 关解锁" % level)
	return GameManager.text("Locked", "未解锁")


func _stage_label(stage: String) -> String:
	match stage:
		"eye":
			return GameManager.text("Naked Eye", "肉眼")
		"refractor_basic":
			return GameManager.text("Simple Refractor", "基础折射镜")
		"refractor_with_finder":
			return GameManager.text("Refractor + Finder", "折射镜 + 寻星镜")
		"refractor_upgraded", "newtonian_basic":
			return GameManager.text("Upgraded Refractor", "大口径折射镜")
		"refractor_advanced":
			return GameManager.text("Advanced Refractor", "进阶折射镜")
		"newtonian_reflector":
			return GameManager.text("Newtonian Reflector", "牛顿反射镜")
		"dobsonian":
			return GameManager.text("Dobsonian", "多布森望远镜")
		"cassegrain":
			return GameManager.text("Cassegrain", "卡塞格林望远镜")
		"gregorian":
			return GameManager.text("Gregorian", "格里高利望远镜")
		"space_segmented":
			return GameManager.text("Infrared Space Telescope", "红外空间望远镜")
		"fast_radio":
			return GameManager.text("FAST Radio Telescope", "FAST 射电望远镜")
		"observatory_network":
			return GameManager.text("Observatory Network", "联合观测网络")
		"advanced":
			return GameManager.text("Advanced Kit", "高级设备")
	return stage


func _draw_star_grid() -> void:
	for index in range(90):
		var x := fmod(float(index * 89), SCREEN_SIZE.x)
		var y := fmod(float(index * 53), SCREEN_SIZE.y)
		var alpha := 0.08 + fmod(float(index), 5.0) * 0.025
		_rect(Vector2(x, y), Vector2(1, 1), Color(0.6, 0.75, 0.95, alpha))


func _panel(pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 3, 5))
	add_child(panel)
	_panel_corners_to(self, pos, panel_size, border)
	return panel


func _button(text: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.13, 0.22), BLUE_EDGE, 2, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.22, 0.34), BRASS, 2, 3))
	button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.14, 0.08), BRASS, 2, 3))
	return button


func _badge_to(parent: Control, text: String, pos: Vector2, badge_size: Vector2, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var bg := _rect_to(parent, pos, badge_size, Color(color.r, color.g, color.b, 0.16))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label_to(parent, text, pos + Vector2(5, 2), badge_size - Vector2(10, 3), 10, color, align)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	return label


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _panel_corners_to(parent: Control, pos: Vector2, panel_size: Vector2, color: Color) -> void:
	_rect_to(parent, pos + Vector2(4, 4), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(4, 4), Vector2(3, 12), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 16, 4), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 7, 4), Vector2(3, 12), color)
	_rect_to(parent, pos + Vector2(4, panel_size.y - 7), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(4, panel_size.y - 16), Vector2(3, 12), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 16, panel_size.y - 7), Vector2(12, 3), color)
	_rect_to(parent, pos + Vector2(panel_size.x - 7, panel_size.y - 16), Vector2(3, 12), color)


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	return _rect_to(self, pos, rect_size, color)


func _rect_to(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label_to(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _on_language_changed() -> void:
	_build()
