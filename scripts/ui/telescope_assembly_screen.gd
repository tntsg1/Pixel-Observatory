extends Control

const AssemblyManagerScript = preload("res://scripts/systems/assembly_manager.gd")
const AssemblyUITemplate = preload("res://scripts/ui/assembly_ui_template.gd")

const SCREEN_SIZE := Vector2(1024, 768)
const PART_ORDER: Array[String] = ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]
const OPTIONAL_PARTS: Array[String] = ["focus_knob", "finder_scope"]
const CORE_PARTS: Array[String] = ["tripod", "mount", "tube", "objective", "eyepiece"]
const PART_TEXTURES := {
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
	"basic_focus_knob": "res://assets/telescope_parts/basic_focus_knob.png"
}
const DEFAULT_PART_IDS := {
	"tripod": "basic_tripod",
	"mount": "basic_mount",
	"tube": "starter_tube",
	"objective": "objective_60mm",
	"eyepiece": "eyepiece_20mm",
	"focus_knob": "basic_focus_knob",
	"finder_scope": "basic_finder_scope"
}

func _part_label(part_type: String, field: String) -> String:
	var labels := {
		"tripod": {"short_en": "Tripod", "short_zh": "三脚架", "role_en": "Base support", "role_zh": "底部支撑"},
		"mount": {"short_en": "Mount", "short_zh": "支架", "role_en": "Holds and turns the tube", "role_zh": "支撑并转动镜筒"},
		"tube": {"short_en": "Tube", "short_zh": "镜筒", "role_en": "Keeps optics aligned", "role_zh": "保持光路对齐"},
		"objective": {"short_en": "Lens", "short_zh": "物镜", "role_en": "Collects light", "role_zh": "收集光线"},
		"eyepiece": {"short_en": "Eye", "short_zh": "目镜", "role_en": "Magnifies the image", "role_zh": "放大图像"},
		"focus_knob": {"short_en": "Focus", "short_zh": "调焦", "role_en": "Moves eyepiece for sharp focus", "role_zh": "移动目镜以清晰成像"},
		"finder_scope": {"short_en": "Finder", "short_zh": "寻星镜", "role_en": "Helps aim the telescope", "role_zh": "帮助瞄准"}
	}
	var entry: Dictionary = labels.get(part_type, {"short_en": part_type, "short_zh": part_type, "role_en": "", "role_zh": ""})
	return GameManager.text(str(entry.get(field + "_en", "")), str(entry.get(field + "_zh", "")))

const SLOT_RECTS := {
	"finder_scope": Rect2(132, 86, 154, 48),
	"eyepiece": Rect2(42, 154, 88, 46),
	"focus_knob": Rect2(54, 196, 98, 62),
	"tube": Rect2(88, 132, 238, 78),
	"objective": Rect2(300, 126, 78, 86),
	"mount": Rect2(142, 198, 132, 116),
	"tripod": Rect2(132, 272, 150, 92)
}

# Blueprint background art (the user's mockup) + where each slot sits on it,
# in normalized 0-1 coords {u,v = center, w,h = size}. Drawn over the image
# so installed parts / highlights land on the printed dashed slots.
const BLUEPRINT_BG := "res://assets/assembly/blueprint_bg.png"
const BP_ORIGIN := Vector2(326, 116)
const BP_SIZE := Vector2(432, 432)
const SLOT_NORM := {
	"finder_scope": Rect2(0.335, 0.112, 0.205, 0.120),
	"objective": Rect2(0.857, 0.216, 0.145, 0.125),
	"tube": Rect2(0.470, 0.310, 0.280, 0.150),
	"eyepiece": Rect2(0.108, 0.348, 0.135, 0.115),
	"focus_knob": Rect2(0.385, 0.560, 0.090, 0.090),
	"mount": Rect2(0.459, 0.490, 0.145, 0.135),
	"tripod": Rect2(0.463, 0.795, 0.190, 0.230)
}
# tube (solid diagonal barrel) and focus_knob (drawn knob by the mount) have
# no printed dashed box on the blueprint, so we draw one for them in code.
const PARTS_WITHOUT_PRINTED_BOX: Array[String] = ["tube", "focus_knob"]


func _slot_display_rect(part_type: String) -> Rect2:
	var norm: Rect2 = SLOT_NORM[part_type]
	var size := Vector2(norm.size.x * BP_SIZE.x, norm.size.y * BP_SIZE.y)
	var center := Vector2(norm.position.x * BP_SIZE.x, norm.position.y * BP_SIZE.y)
	return Rect2(center - size * 0.5, size)


const PART_COLORS := {
	"tripod": Color(0.55, 0.61, 0.68),
	"mount": Color(0.62, 0.68, 0.74),
	"tube": Color(0.31, 0.57, 0.84),
	"objective": Color(0.63, 0.85, 0.92),
	"eyepiece": Color(0.45, 0.53, 0.62),
	"focus_knob": Color(0.88, 0.68, 0.32),
	"finder_scope": Color(0.38, 0.68, 0.92)
}

var selected_part_type := ""
var selected_part_id := ""
var wrong_attempts: Dictionary = {}

var parts_scroll: ScrollContainer
var parts_list: Control
var blueprint_layer: Control
var inspector_title: Label
var inspector_body: Label
var feedback_label: Label
var stats_list: Control
var ready_dot: Panel
var finish_button: Button
var part_card_controls: Dictionary = {}
var slot_controls: Dictionary = {}
var install_animation_active := false


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_load_wrong_attempts()
	_build()
	InteractionFeedback.page_enter(self)
	call_deferred("_show_assembly_tutorial")


func _show_assembly_tutorial() -> void:
	# On the first level that adds the finder scope, point straight at its slot
	# so the finder lesson (started by the story) continues into the bench.
	var finder_required: bool = GameManager.current_level().get("required_parts", []).has("finder_scope")
	if finder_required and not _is_installed("finder_scope") and not InteractionFeedback.was_tutorial_seen("first_finder_slot"):
		var finder_slot: Control = slot_controls.get("finder_scope") as Control
		if finder_slot != null:
			InteractionFeedback.tutorial_highlight_once(finder_slot, "first_finder_slot", GameManager.text(
				"New part tonight: install the Finder Scope in this top slot after the core parts.",
				"今晚的新零件：装完核心零件后，把寻星镜装到这个顶部槽位。"
			), self)
			return
	InteractionFeedback.tutorial_highlight_once(blueprint_layer, "first_refractor_assembly", GameManager.text(
		"Choose a part card, then install it in the matching blueprint slot.",
		"选择零件卡片，再安装到蓝图中的对应槽位。"
	), self)


func _load_wrong_attempts() -> void:
	var assembly_state: Dictionary = _assembly_state()
	for part_type in PART_ORDER:
		var entry: Dictionary = _dict_value(assembly_state.get(part_type, {}))
		wrong_attempts[part_type] = int(entry.get("wrong_attempts", 0))


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = SCREEN_SIZE

	_rect(Vector2.ZERO, SCREEN_SIZE, Color(0.006, 0.009, 0.018))
	_draw_grid()
	_draw_title_bar()
	_build_parts_panel()
	_build_blueprint_panel()
	_build_inspector_panel()
	_refresh_all()


func _draw_title_bar() -> void:
	AssemblyUITemplate.add_title_bar(self, GameManager.text("Telescope Assembly", "望远镜组装台"), GameManager.text("Pick a part, then click its blueprint slot.", "选择零件，再点击蓝图安装位。"))
	_add_type_selector()
	AssemblyUITemplate.add_hints_toggle(self, GameManager, _build)


func _add_type_selector() -> void:
	var button := _button(GameManager.text("Type: Refractor", "类型：折射式"), Vector2(24, 18), Vector2(180, 30))
	button.name = "TelescopeTypeButton"
	button.add_theme_font_size_override("font_size", 11)
	button.tooltip_text = GameManager.text("Choose another unlocked telescope family", "选择其他已解锁的望远镜类型")
	button.pressed.connect(func() -> void:
		GameManager.set_meta("telescope_types_browse", false)
		GameManager.set_meta("telescope_types_return_scene", "assembly")
		GameManager.go("telescope_types")
	)
	add_child(button)


func _build_parts_panel() -> void:
	_panel(AssemblyUITemplate.LEFT_PANEL_RECT.position, AssemblyUITemplate.LEFT_PANEL_RECT.size, Color(0.050, 0.070, 0.120, 0.96), Color(0.78, 0.56, 0.28))
	_rect(Vector2(24, 78), Vector2(292, 34), Color(0.30, 0.20, 0.10, 0.92))
	var heading := _label(GameManager.text("Parts Tray", "零件托盘"), 17, Color(0.96, 0.93, 0.84))
	heading.position = Vector2(40, 91)
	heading.size = Vector2(250, 26)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(heading)

	parts_scroll = ScrollContainer.new()
	parts_scroll.position = AssemblyUITemplate.PARTS_SCROLL_RECT.position
	parts_scroll.size = AssemblyUITemplate.PARTS_SCROLL_RECT.size
	parts_scroll.clip_contents = true
	parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(parts_scroll)

	parts_list = Control.new()
	parts_list.size = Vector2(252, 560)
	parts_list.custom_minimum_size = Vector2(252, 560)
	parts_scroll.add_child(parts_list)


func _build_blueprint_panel() -> void:
	_panel(AssemblyUITemplate.BLUEPRINT_PANEL_RECT.position, AssemblyUITemplate.BLUEPRINT_PANEL_RECT.size, Color(0.020, 0.045, 0.095, 0.98), Color(0.78, 0.56, 0.28))
	# Gold nameplate header (mockup style).
	_dark_panel_add(Vector2(452, 80), Vector2(196, 34), Color(0.10, 0.13, 0.075, 0.96), Color(0.82, 0.62, 0.30))
	var heading := _label(GameManager.text("BLUEPRINT", "蓝图"), 16, Color(0.96, 0.82, 0.42))
	heading.position = Vector2(452, 88)
	heading.size = Vector2(196, 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(heading)

	# The mockup blueprint art fills the panel; slot interaction/highlight
	# and installed parts are layered on top by blueprint_layer.
	_mission_bg_texture(BLUEPRINT_BG, BP_ORIGIN, BP_SIZE)

	blueprint_layer = Control.new()
	blueprint_layer.position = BP_ORIGIN
	blueprint_layer.size = BP_SIZE
	add_child(blueprint_layer)

	var helper := _label(GameManager.text("Pick a part card, then click its slot on the blueprint.", "选左侧零件卡，再点击蓝图上对应安装位。"), 12, Color(0.72, 0.82, 0.90))
	helper.position = Vector2(346, 560)
	helper.size = Vector2(408, 40)
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(helper)

	var order := _label(GameManager.text("Tripod → Mount → Tube → Lens → Eye → Focus", "三脚架 → 支架 → 镜筒 → 物镜 → 目镜 → 调焦"), 11, Color(0.56, 0.68, 0.78))
	order.position = Vector2(346, 606)
	order.size = Vector2(408, 20)
	order.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(order)


func _dark_panel_add(pos: Vector2, size: Vector2, color: Color, border: Color) -> Panel:
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


func _mission_bg_texture(path: String, pos: Vector2, size: Vector2) -> void:
	var rect := TextureRect.new()
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.position = pos
	rect.size = size
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _build_inspector_panel() -> void:
	var back_callback := func() -> void:
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	var shell := AssemblyUITemplate.add_inspector_shell(
		self,
		GameManager.text("Inspector", "检查器"),
		GameManager.text("Finish Assembly", "完成组装"),
		GameManager.text("Reassemble", "重装"),
		GameManager.text("Back", "返回"),
		_finish,
		_reset,
		back_callback
	)
	inspector_title = shell["status"]
	feedback_label = shell["feedback"]
	stats_list = shell["stats"]
	ready_dot = shell["ready_dot"]
	finish_button = shell["finish"]
	return
	_panel(Vector2(776, 74), Vector2(232, 636), Color(0.045, 0.065, 0.115, 0.98), Color(0.78, 0.56, 0.28))
	_dark_panel_add(Vector2(812, 80), Vector2(160, 34), Color(0.10, 0.13, 0.075, 0.96), Color(0.82, 0.62, 0.30))
	var heading := _label("INSPECTOR · 检查器", 14, Color(0.96, 0.82, 0.42))
	heading.position = Vector2(812, 88)
	heading.size = Vector2(160, 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(heading)

	# READY status box (green when the scope is complete).
	_dark_panel_add(Vector2(792, 128), Vector2(200, 56), Color(0.020, 0.045, 0.030, 0.96), Color(0.30, 0.55, 0.34))
	inspector_title = _label("READY", 20, Color(0.42, 0.92, 0.50))
	inspector_title.position = Vector2(812, 142)
	inspector_title.size = Vector2(120, 28)
	inspector_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inspector_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(inspector_title)
	ready_dot = Panel.new()
	ready_dot.position = Vector2(946, 146)
	ready_dot.size = Vector2(24, 24)
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(0, 0, 0, 0)
	dot_style.border_color = Color(0.42, 0.92, 0.50)
	dot_style.set_border_width_all(3)
	dot_style.set_corner_radius_all(12)
	ready_dot.add_theme_stylebox_override("panel", dot_style)
	ready_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ready_dot)

	# Assembly hint line (step-by-step guidance).
	inspector_body = _label("", 11, Color(0.70, 0.80, 0.88))
	inspector_body.position = Vector2(792, 190)
	inspector_body.size = Vector2(200, 20)
	inspector_body.visible = false
	add_child(inspector_body)
	feedback_label = _label("", 11, Color(0.82, 0.88, 0.82))
	feedback_label.position = Vector2(792, 192)
	feedback_label.size = Vector2(200, 44)
	add_child(feedback_label)

	_dashed_divider(Vector2(792, 248), 200)

	stats_list = Control.new()
	stats_list.position = Vector2(792, 268)
	stats_list.size = Vector2(200, 220)
	add_child(stats_list)

	_dashed_divider(Vector2(792, 566), 200)

	var finish := _button(GameManager.text("✦  FINISH", "✦  完成"), Vector2(792, 584), Vector2(200, 54))
	finish.add_theme_font_size_override("font_size", 18)
	var fnormal := StyleBoxFlat.new()
	fnormal.bg_color = Color(0.10, 0.14, 0.085)
	fnormal.border_color = Color(0.85, 0.65, 0.32)
	fnormal.set_border_width_all(3)
	fnormal.set_corner_radius_all(5)
	var fhover := fnormal.duplicate()
	fhover.bg_color = Color(0.16, 0.20, 0.11)
	finish.add_theme_stylebox_override("normal", fnormal)
	finish.add_theme_stylebox_override("hover", fhover)
	finish.add_theme_stylebox_override("pressed", fnormal)
	finish.add_theme_color_override("font_color", Color(0.96, 0.82, 0.42))
	finish.pressed.connect(_finish)
	add_child(finish)

	var reset := _button(GameManager.text("Reassemble", "重装"), Vector2(792, 648), Vector2(98, 34))
	reset.pressed.connect(_reset)
	add_child(reset)

	var back := _button(GameManager.text("Back", "返回"), Vector2(894, 648), Vector2(98, 34))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	)
	add_child(back)


func _dashed_divider(pos: Vector2, width: float) -> void:
	var x := 0.0
	while x < width:
		_rect(pos + Vector2(x, 0), Vector2(6, 1), Color(0.40, 0.50, 0.56, 0.6))
		x += 12.0


func _refresh_all() -> void:
	_refresh_parts()
	_refresh_blueprint()
	_refresh_inspector()
	_refresh_stats()


func _refresh_parts() -> void:
	_clear(parts_list)
	part_card_controls.clear()
	var y := 0.0
	var selected_y := -1.0
	var next_part := _next_installable_part() if GameManager.assembly_hints_enabled() else ""
	for part_type in PART_ORDER:
		var unlocked: Array = GameManager.unlocked_parts_by_type(part_type)
		if unlocked.is_empty():
			continue
		var part: Dictionary = _part_for_type(part_type)
		var installed := _is_installed(part_type)
		var selected := selected_part_type == part_type or (selected_part_type == "" and next_part == part_type)
		if selected:
			selected_y = y
		_draw_part_card(part_type, part, installed, selected, Vector2(0, y))
		y += 90.0
	parts_list.custom_minimum_size = Vector2(252, maxf(560.0, y))
	parts_list.size = parts_list.custom_minimum_size
	if parts_scroll != null and selected_y >= 0.0:
		call_deferred("_scroll_parts_to", int(maxf(0.0, selected_y - 24.0)))


func _scroll_parts_to(value: int) -> void:
	if parts_scroll == null:
		return
	var bar := parts_scroll.get_v_scroll_bar()
	if bar != null:
		bar.value = value


func _draw_part_card(part_type: String, part: Dictionary, installed: bool, selected: bool, pos: Vector2) -> void:
	var shared_texture_path := _part_texture_path(part)
	var shared_texture := load(shared_texture_path) as Texture2D if shared_texture_path != "" and ResourceLoader.exists(shared_texture_path) else null
	var state := GameManager.part_slot_state(part_type, str(part.get("id", "")))
	var template_card := AssemblyUITemplate.add_part_card(
		parts_list,
		pos,
		GameManager.dict_text(part, "name"),
		str(_part_label(part_type, "role")),
		_state_status_text(state),
		shared_texture,
		installed,
		selected,
		_select_part.bind(part_type)
	)
	part_card_controls[part_type] = template_card
	return
	var bg_color := Color(0.155, 0.172, 0.180)
	if installed:
		bg_color = Color(0.112, 0.128, 0.132)
	if selected:
		bg_color = Color(0.185, 0.245, 0.285)
	var border_color := Color(0.30, 0.38, 0.42)
	if installed:
		border_color = Color(0.34, 0.56, 0.42)
	if selected:
		border_color = Color(0.82, 0.72, 0.34)
	var card := _panel_local(parts_list, pos, Vector2(252, 78), bg_color, border_color)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_box := _panel_local(parts_list, pos + Vector2(10, 11), Vector2(56, 56), Color(0.070, 0.085, 0.095), Color(0.22, 0.30, 0.34))
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.clip_contents = true
	_draw_part_icon(parts_list, part, pos + Vector2(10, 11), installed, Vector2(56, 56))

	var name_en := _label(GameManager.dict_text(part, "name"), 12, Color(0.94, 0.95, 0.92))
	name_en.position = pos + Vector2(76, 10)
	name_en.size = Vector2(160, 18)
	name_en.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_en.clip_text = true
	parts_list.add_child(name_en)

	var name_zh := _label(str(_part_label(part_type, "short")), 12, Color(0.82, 0.88, 0.88))
	name_zh.position = pos + Vector2(76, 30)
	name_zh.size = Vector2(160, 18)
	name_zh.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_zh.clip_text = true
	parts_list.add_child(name_zh)

	var status_text := GameManager.text("Installed", "已安装") if installed else GameManager.text("Not Installed", "未安装")
	var status_color := Color(0.58, 0.86, 0.62) if installed else Color(0.86, 0.78, 0.48)
	var status := _label(status_text, 11, status_color)
	status.position = pos + Vector2(76, 52)
	status.size = Vector2(160, 16)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.clip_text = true
	parts_list.add_child(status)

	if installed:
		var check := _label("OK", 11, Color(0.66, 0.94, 0.70))
		check.position = pos + Vector2(219, 52)
		check.size = Vector2(24, 16)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		check.autowrap_mode = TextServer.AUTOWRAP_OFF
		parts_list.add_child(check)

	var click := Button.new()
	click.position = pos
	click.size = Vector2(252, 78)
	click.text = ""
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.pressed.connect(_select_part.bind(part_type))
	parts_list.add_child(click)


func _state_status_text(state: String) -> String:
	match state:
		"installed": return GameManager.text("Installed  OK", "已安装  OK")
		"equipped": return GameManager.text("Equipped - not installed", "已装备 · 未安装")
		"unlocked": return GameManager.text("Unlocked - not installed", "已解锁 · 未安装")
		"incompatible": return GameManager.text("Wrong telescope family", "望远镜类型不兼容")
		_: return GameManager.text("Locked", "未解锁")


func _part_texture_path(part: Dictionary) -> String:
	var part_id := str(part.get("id", ""))
	var legacy_path := str(PART_TEXTURES.get(part_id, ""))
	if legacy_path != "" and ResourceLoader.exists(legacy_path):
		return legacy_path
	var icon_path := str(part.get("icon_path", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		return icon_path
	return ""


func _draw_part_texture(parent: Control, part: Dictionary, pos: Vector2, texture_size: Vector2, alpha: float = 1.0) -> bool:
	var texture_path := _part_texture_path(part)
	if texture_path == "":
		return false
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return false
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = texture
	icon.position = pos
	icon.size = texture_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, alpha)
	parent.add_child(icon)
	return true


func _draw_part_icon(parent: Control, part: Dictionary, box_pos: Vector2, installed: bool, box_size: Vector2 = Vector2(56, 56)) -> void:
	if _draw_part_texture(parent, part, box_pos + Vector2(3, 3), box_size - Vector2(6, 6), 0.72 if installed else 1.0):
		return

	var part_type := str(part.get("type", ""))
	var color: Color = PART_COLORS[part_type]
	if installed:
		color = color.darkened(0.22)
	var p := box_pos + Vector2(4, 4)
	match part_type:
		"tripod":
			_rect_local(parent, p + Vector2(21, 8), Vector2(8, 24), color)
			_rect_local(parent, p + Vector2(12, 33), Vector2(28, 6), color.lightened(0.08))
			_rect_local(parent, p + Vector2(8, 39), Vector2(6, 8), color.darkened(0.08))
			_rect_local(parent, p + Vector2(37, 39), Vector2(6, 8), color.darkened(0.08))
		"mount":
			_rect_local(parent, p + Vector2(16, 13), Vector2(24, 23), color)
			_rect_local(parent, p + Vector2(22, 7), Vector2(12, 37), color.lightened(0.08))
			_rect_local(parent, p + Vector2(11, 20), Vector2(8, 9), color.darkened(0.10))
			_rect_local(parent, p + Vector2(37, 20), Vector2(8, 9), color.darkened(0.10))
		"tube":
			_rect_local(parent, p + Vector2(7, 22), Vector2(35, 12), color)
			_rect_local(parent, p + Vector2(37, 17), Vector2(10, 22), color.lightened(0.12))
			_rect_local(parent, p + Vector2(4, 19), Vector2(7, 18), color.darkened(0.10))
		"objective":
			_rect_local(parent, p + Vector2(16, 9), Vector2(22, 34), color)
			_rect_local(parent, p + Vector2(22, 5), Vector2(10, 42), color.lightened(0.14))
			_rect_local(parent, p + Vector2(13, 16), Vector2(28, 5), color.darkened(0.12))
		"eyepiece":
			_rect_local(parent, p + Vector2(17, 16), Vector2(23, 22), color)
			_rect_local(parent, p + Vector2(8, 21), Vector2(13, 12), color.darkened(0.10))
			_rect_local(parent, p + Vector2(35, 20), Vector2(8, 14), color.lightened(0.10))
		"focus_knob":
			# knurled knob with an axle
			_rect_local(parent, p + Vector2(14, 14), Vector2(24, 24), color)
			_rect_local(parent, p + Vector2(18, 18), Vector2(16, 16), color.darkened(0.18))
			_rect_local(parent, p + Vector2(23, 23), Vector2(6, 6), color.lightened(0.22))
			_rect_local(parent, p + Vector2(38, 22), Vector2(9, 8), color.darkened(0.10))
			_rect_local(parent, p + Vector2(11, 10), Vector2(4, 4), color.lightened(0.10))
			_rect_local(parent, p + Vector2(37, 10), Vector2(4, 4), color.lightened(0.10))
			_rect_local(parent, p + Vector2(11, 38), Vector2(4, 4), color.lightened(0.10))
			_rect_local(parent, p + Vector2(37, 38), Vector2(4, 4), color.lightened(0.10))
		_:
			_rect_local(parent, p + Vector2(8, 20), Vector2(34, 10), color)
			_rect_local(parent, p + Vector2(36, 15), Vector2(10, 20), color.lightened(0.12))
			_rect_local(parent, p + Vector2(11, 16), Vector2(8, 18), color.darkened(0.10))


func _refresh_blueprint() -> void:
	# Transparent overlay ON TOP of the blueprint art: highlights the active
	# slot, shows installed parts, and carries the click hotspots. The dashed
	# slot outlines and telescope drawing come from the background image.
	_clear(blueprint_layer)
	slot_controls.clear()
	var next_part := _next_installable_part() if GameManager.assembly_hints_enabled() else ""
	for part_type in PART_ORDER:
		if OPTIONAL_PARTS.has(part_type) and GameManager.unlocked_parts_by_type(part_type).is_empty():
			continue
		_draw_slot(part_type, next_part)


func _draw_blueprint_grid() -> void:
	for x in range(24, 382, 48):
		_rect_local(blueprint_layer, Vector2(x, 12), Vector2(1, 334), Color(0.16, 0.25, 0.31, 0.34))
	for y in range(24, 350, 48):
		_rect_local(blueprint_layer, Vector2(18, y), Vector2(344, 1), Color(0.16, 0.25, 0.31, 0.34))
	var label := _label(GameManager.text("blueprint view", "蓝图视图"), 11, Color(0.34, 0.50, 0.58))
	label.position = Vector2(246, 8)
	label.size = Vector2(112, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	blueprint_layer.add_child(label)


func _draw_scope_guide() -> void:
	var ghost := Color(0.58, 0.70, 0.76, 0.12)
	var brass := Color(0.86, 0.63, 0.28, 0.16)
	_rect_local(blueprint_layer, Vector2(83, 158), Vector2(252, 30), Color(0.26, 0.52, 0.72, 0.16))
	_rect_local(blueprint_layer, Vector2(310, 143), Vector2(42, 60), Color(0.62, 0.83, 0.91, 0.13))
	_rect_local(blueprint_layer, Vector2(56, 162), Vector2(66, 22), Color(0.58, 0.66, 0.74, 0.13))
	_rect_local(blueprint_layer, Vector2(146, 119), Vector2(126, 9), Color(0.38, 0.68, 0.92, 0.12))
	_rect_local(blueprint_layer, Vector2(190, 202), Vector2(28, 88), ghost)
	_rect_local(blueprint_layer, Vector2(156, 324), Vector2(116, 9), ghost)
	_draw_line(Vector2(204, 284), Vector2(144, 350), ghost)
	_draw_line(Vector2(204, 284), Vector2(266, 350), ghost)
	_rect_local(blueprint_layer, Vector2(122, 147), Vector2(8, 54), brass)
	_rect_local(blueprint_layer, Vector2(268, 147), Vector2(8, 54), brass)


func _draw_connection_hardware() -> void:
	var metal := Color(0.42, 0.50, 0.54, 0.82)
	var dark := Color(0.08, 0.10, 0.11, 0.88)
	var brass := Color(0.86, 0.62, 0.30, 0.82)

	# Finder rail and two little feet that clamp it to the main tube.
	_rect_local(blueprint_layer, Vector2(151, 128), Vector2(128, 5), dark)
	_rect_local(blueprint_layer, Vector2(169, 126), Vector2(8, 21), metal)
	_rect_local(blueprint_layer, Vector2(247, 126), Vector2(8, 21), metal)
	_rect_local(blueprint_layer, Vector2(164, 143), Vector2(18, 5), brass)
	_rect_local(blueprint_layer, Vector2(242, 143), Vector2(18, 5), brass)

	# Eyepiece/focuser drawtube and the focus housing connection.
	_rect_local(blueprint_layer, Vector2(92, 165), Vector2(46, 18), dark)
	_rect_local(blueprint_layer, Vector2(86, 185), Vector2(42, 8), metal)
	_rect_local(blueprint_layer, Vector2(104, 190), Vector2(10, 18), metal)

	# Tube rings, objective collar, and saddle into the mount.
	_rect_local(blueprint_layer, Vector2(122, 145), Vector2(7, 58), brass)
	_rect_local(blueprint_layer, Vector2(267, 145), Vector2(7, 58), brass)
	_rect_local(blueprint_layer, Vector2(304, 149), Vector2(12, 48), brass)
	_rect_local(blueprint_layer, Vector2(176, 204), Vector2(58, 9), metal)
	_rect_local(blueprint_layer, Vector2(192, 208), Vector2(24, 48), dark)

	# Mount-to-tripod neck and top plate.
	_rect_local(blueprint_layer, Vector2(190, 292), Vector2(30, 18), metal)
	_rect_local(blueprint_layer, Vector2(160, 310), Vector2(90, 8), brass)


func _draw_slot(part_type: String, next_part: String) -> void:
	var rect := _slot_display_rect(part_type)
	var installed := _is_installed(part_type)
	var selected := selected_part_type == part_type
	var next := next_part == part_type
	var can_show_selected := selected_part_type != "" and selected

	var needs_drawn_box := PARTS_WITHOUT_PRINTED_BOX.has(part_type)
	if installed:
		# Cover the printed dashed slot with the real part sprite + a soft
		# green "locked in" glow so progress is obvious over the blueprint.
		_draw_glow_frame(rect.grow(2.0), Color(0.40, 0.90, 0.55, 0.55))
		var part := _part_for_type(part_type)
		var pad := rect.size * 0.08
		var inner := Rect2(rect.position + pad, rect.size - pad * 2.0)
		if not _draw_part_texture(blueprint_layer, part, inner.position, inner.size, 0.98):
			_rect_local(blueprint_layer, inner.position, inner.size, PART_COLORS.get(part_type, Color(0.5, 0.6, 0.7)))
	else:
		# tube / focus_knob have no printed box - draw a cyan dashed one so
		# they read as real slots like the others.
		if needs_drawn_box:
			_draw_dashed_box(rect, Color(0.55, 0.82, 0.98, 0.85), part_type)
		if can_show_selected:
			_draw_glow_frame(rect.grow(3.0), Color(0.98, 0.80, 0.30, 0.95))
		elif selected_part_type == "" and next:
			_draw_glow_frame(rect.grow(2.0), Color(0.55, 0.82, 0.98, 0.85))

	var hit := AssemblyUITemplate.add_slot_hit_target(blueprint_layer, rect, _try_install.bind(part_type))
	slot_controls[part_type] = hit


func _draw_glow_frame(rect: Rect2, color: Color) -> void:
	# Layered rounded borders (outer faint, inner bright) = cheap glow.
	for i in range(3):
		var g := rect.grow(float(i) * 2.0)
		var c := Color(color.r, color.g, color.b, color.a * (0.30 - float(i) * 0.08))
		var panel := Panel.new()
		panel.position = g.position
		panel.size = g.size
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = c
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blueprint_layer.add_child(panel)


func _draw_dashed_box(rect: Rect2, color: Color, part_type: String) -> void:
	# Cyan dashed rectangle matching the blueprint's printed slots, drawn in
	# blueprint_layer-local coords, for slots the art doesn't already show.
	var dash := 7.0
	var gap := 5.0
	var p := rect.position
	var s := rect.size
	var x := 0.0
	while x < s.x:
		var w: float = minf(dash, s.x - x)
		_rect_local(blueprint_layer, p + Vector2(x, 0), Vector2(w, 2), color)
		_rect_local(blueprint_layer, p + Vector2(x, s.y - 2), Vector2(w, 2), color)
		x += dash + gap
	var y := 0.0
	while y < s.y:
		var h: float = minf(dash, s.y - y)
		_rect_local(blueprint_layer, p + Vector2(0, y), Vector2(2, h), color)
		_rect_local(blueprint_layer, p + Vector2(s.x - 2, y), Vector2(2, h), color)
		y += dash + gap
	var label := _label(str(_part_label(part_type, "short")), 10, Color(0.72, 0.86, 0.96))
	label.position = p + Vector2(2, -14)
	label.size = Vector2(s.x + 20, 14)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	blueprint_layer.add_child(label)


func _draw_installed_part(part_type: String, rect: Rect2) -> void:
	var color: Color = PART_COLORS[part_type]
	var part := _part_for_type(part_type)
	var inner := _installed_part_rect(part_type, part, rect)
	if _draw_part_texture(blueprint_layer, part, inner.position, inner.size, 0.92):
		return

	if part_type == "tripod":
		_rect_local(blueprint_layer, inner.position + Vector2(26, 0), Vector2(10, 34), color)
		_rect_local(blueprint_layer, inner.position + Vector2(8, 38), Vector2(72, 8), color.darkened(0.08))
		_draw_line(inner.position + Vector2(31, 32), inner.position + Vector2(6, 58), color)
		_draw_line(inner.position + Vector2(36, 32), inner.position + Vector2(82, 58), color)
	elif part_type == "mount":
		_rect_local(blueprint_layer, inner.position + Vector2(13, 10), Vector2(40, 28), color)
		_rect_local(blueprint_layer, inner.position + Vector2(23, 0), Vector2(20, 48), color.lightened(0.08))
	elif part_type == "tube":
		_rect_local(blueprint_layer, inner.position + Vector2(6, 20), Vector2(126, 22), color)
		_rect_local(blueprint_layer, inner.position + Vector2(116, 13), Vector2(24, 36), color.lightened(0.12))
	elif part_type == "objective":
		_rect_local(blueprint_layer, inner.position + Vector2(8, 7), Vector2(37, 38), color)
		_rect_local(blueprint_layer, inner.position + Vector2(18, 0), Vector2(17, 52), color.lightened(0.14))
	elif part_type == "eyepiece":
		_rect_local(blueprint_layer, inner.position + Vector2(13, 12), Vector2(34, 30), color)
		_rect_local(blueprint_layer, inner.position + Vector2(2, 19), Vector2(17, 16), color.darkened(0.10))
	elif part_type == "focus_knob":
		_rect_local(blueprint_layer, inner.position + Vector2(14, 4), Vector2(20, 20), color)
		_rect_local(blueprint_layer, inner.position + Vector2(19, 9), Vector2(10, 10), color.darkened(0.20))
		_rect_local(blueprint_layer, inner.position + Vector2(34, 10), Vector2(10, 7), color.darkened(0.10))
	else:
		_rect_local(blueprint_layer, inner.position + Vector2(10, 15), Vector2(72, 15), color)
		_rect_local(blueprint_layer, inner.position + Vector2(64, 9), Vector2(20, 28), color.lightened(0.12))


func _installed_part_rect(part_type: String, part: Dictionary, slot_rect: Rect2) -> Rect2:
	var part_id := str(part.get("id", ""))
	match part_type:
		"tube":
			return Rect2(88, 136, 238, 82)
		"finder_scope":
			# Finder should read as a small scope mounted directly on top
			# of the main tube, not as a separate object floating above it.
			return Rect2(146, 92, 132, 42)
		"objective":
			if part_id == "objective_60mm":
				return Rect2(312, 136, 58, 64)
			return Rect2(300, 128, 76, 84)
		"eyepiece":
			return Rect2(45, 160, 84, 30)
		"focus_knob":
			return Rect2(52, 194, 96, 68)
		"mount":
			match part_id:
				"basic_mount":
					return Rect2(176, 190, 70, 92)
				"stable_mount":
					return Rect2(154, 190, 98, 108)
				"tracking_mount":
					return Rect2(156, 190, 96, 108)
			return Rect2(166, 206, 86, 96)
		"tripod":
			return Rect2(128, 246, 168, 120)
	return slot_rect.grow(-9.0)


func _draw_corner_ticks(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var s := rect.size
	var tick := 10.0
	_rect_local(blueprint_layer, p, Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p, Vector2(2, tick), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - tick, 0), Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - 2, 0), Vector2(2, tick), color)
	_rect_local(blueprint_layer, p + Vector2(0, s.y - 2), Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p + Vector2(0, s.y - tick), Vector2(2, tick), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - tick, s.y - 2), Vector2(tick, 2), color)
	_rect_local(blueprint_layer, p + Vector2(s.x - 2, s.y - tick), Vector2(2, tick), color)


func _refresh_inspector() -> void:
	var is_ready := GameManager.telescope_is_ready()
	if is_ready:
		inspector_title.text = "READY"
		inspector_title.add_theme_color_override("font_color", Color(0.42, 0.92, 0.50))
		_set_ready_dot(Color(0.42, 0.92, 0.50))
	else:
		inspector_title.text = GameManager.text("ASSEMBLING", "组装中")
		inspector_title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
		_set_ready_dot(Color(0.95, 0.78, 0.35))

	if selected_part_type != "":
		var unlocked: Array = GameManager.unlocked_parts_by_type(selected_part_type)
		if not unlocked.is_empty():
			var part: Dictionary = _part_for_type(selected_part_type)
			var part_name := GameManager.dict_text(part, "name")
			var state := GameManager.part_slot_state(selected_part_type, str(part.get("id", "")))
			var guidance := ""
			match state:
				"installed":
					guidance = GameManager.text("Installed successfully. Pick another slot.", "已安装成功。请选择其它安装位。")
				"equipped":
					guidance = GameManager.text("Equipped - click the matching blueprint slot.", "已装备——请点击蓝图上的对应安装位。")
				"unlocked":
					guidance = GameManager.text("Unlocked - click the slot to equip and install it.", "已解锁——点击安装位即可装备并安装。")
				"incompatible":
					guidance = GameManager.text("Wrong telescope family for this mission.", "望远镜类型与本关不兼容。")
				_:
					guidance = GameManager.text("Requires its introduction lesson to unlock.", "需要先完成对应教学关卡解锁。")
			feedback_label.text = part_name + " · " + guidance
			return
	var next_part := _next_installable_part()
	if next_part == "":
		feedback_label.text = GameManager.text("All core parts installed. Press Finish.", "核心部件已装齐，点击完成。")
	elif GameManager.assembly_hints_enabled():
		feedback_label.text = GameManager.text("Next: ", "下一步：") + str(_part_label(next_part, "short")) + GameManager.text(" - pick it, click its slot. ", " —— 选它，点击安装位。") + _next_step_description(next_part)
	else:
		feedback_label.text = GameManager.text("Hints off. Pick parts and install them in a valid order.", "提示已关闭。自行选择零件并按有效顺序安装。")


func _set_ready_dot(color: Color) -> void:
	if ready_dot == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.14)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	ready_dot.add_theme_stylebox_override("panel", style)


func _refresh_stats() -> void:
	_clear(stats_list)
	var stats: Dictionary = GameManager.calculate_stats()
	var rows := [
		{"icon": "tripod", "name": GameManager.text("STABILITY", "稳定度"), "ratio": float(stats.get("stability_score", 0.0)) / 100.0},
		{"icon": "optics", "name": GameManager.text("OPTICS", "光学"), "ratio": (float(stats.get("light_score", 0.0)) + float(stats.get("clarity_score", 0.0))) / 200.0},
		{"icon": "align", "name": GameManager.text("ALIGNMENT", "对齐"), "ratio": float(stats.get("assembly_score", 0.0)) / 100.0}
	]
	var y := 6.0
	for row in rows:
		_draw_gauge(str(row["icon"]), str(row["name"]), clampf(float(row["ratio"]), 0.0, 1.0), y)
		y += 66.0


func _draw_gauge(icon: String, gname: String, ratio: float, y: float) -> void:
	_draw_gauge_icon(icon, Vector2(2, y + 2))
	var label := _label(gname, 12, Color(0.86, 0.90, 0.94))
	label.position = Vector2(36, y)
	label.size = Vector2(160, 18)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats_list.add_child(label)
	var cells := 8
	var cell_w := 18.0
	var gap := 2.0
	var filled := int(round(ratio * float(cells)))
	for i in range(cells):
		var cx := 36.0 + float(i) * (cell_w + gap)
		var col := Color(0.34, 0.78, 0.38) if i < filled else Color(0.10, 0.16, 0.14)
		_rect_local(stats_list, Vector2(cx, y + 24), Vector2(cell_w, 16), col)
		_rect_local(stats_list, Vector2(cx, y + 24), Vector2(cell_w, 1), Color(0.55, 0.92, 0.55, 0.30) if i < filled else Color(0.2, 0.3, 0.3, 0.2))


func _draw_gauge_icon(icon: String, pos: Vector2) -> void:
	var c := Color(0.78, 0.85, 0.90)
	match icon:
		"tripod":
			_rect_local(stats_list, pos + Vector2(10, 2), Vector2(6, 4), c)
			_rect_local(stats_list, pos + Vector2(12, 6), Vector2(2, 7), c)
			var leg := Color(c.r, c.g, c.b, 0.9)
			for step in range(6):
				var t := float(step)
				_rect_local(stats_list, pos + Vector2(13 - t, 13 + t * 1.8), Vector2(2, 2), leg)
				_rect_local(stats_list, pos + Vector2(13 + t, 13 + t * 1.8), Vector2(2, 2), leg)
		"optics":
			var ring := Panel.new()
			ring.position = pos + Vector2(4, 4)
			ring.size = Vector2(18, 18)
			var st := StyleBoxFlat.new()
			st.bg_color = Color(0.15, 0.30, 0.55, 0.7)
			st.border_color = c
			st.set_border_width_all(2)
			st.set_corner_radius_all(9)
			ring.add_theme_stylebox_override("panel", st)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_list.add_child(ring)
			_rect_local(stats_list, pos + Vector2(11, 11), Vector2(4, 4), Color(0.6, 0.8, 1.0))
		"align":
			var ring2 := Panel.new()
			ring2.position = pos + Vector2(5, 5)
			ring2.size = Vector2(16, 16)
			var st2 := StyleBoxFlat.new()
			st2.bg_color = Color(0, 0, 0, 0)
			st2.border_color = c
			st2.set_border_width_all(2)
			st2.set_corner_radius_all(8)
			ring2.add_theme_stylebox_override("panel", st2)
			ring2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_list.add_child(ring2)
			_rect_local(stats_list, pos + Vector2(12, 1), Vector2(2, 24), c)
			_rect_local(stats_list, pos + Vector2(1, 12), Vector2(24, 2), c)


func _select_part(part_type: String) -> void:
	selected_part_type = part_type
	# Remember the exact part id the card represents, so the install uses the
	# player's real choice rather than a stale equipped id.
	selected_part_id = str(_part_for_type(part_type).get("id", ""))
	if _is_installed(part_type):
		feedback_label.text = str(_part_label(part_type, "short")) + " " + GameManager.text("is already installed. Pick its slot to replace it.", "已安装。点击安装位可替换。")
	else:
		var state := GameManager.part_slot_state(part_type, selected_part_id)
		if state == "incompatible":
			feedback_label.text = GameManager.install_part_block_reason(part_type, selected_part_id)
		elif state == "unlocked":
			# Safe to auto-equip the moment the card is picked: the card only
			# exists for unlocked, compatible parts, so equip it now and show
			# "Equipped" straight away - no separate Equip button needed.
			GameManager.equip_part(selected_part_id)
			feedback_label.text = GameManager.dict_text(_part_for_type(part_type), "name") + " " + GameManager.text("equipped. Click its blueprint slot to install.", "已装备。点击蓝图安装位即可安装。")
		else:
			feedback_label.text = GameManager.text(
				"Click the " + str(_part_label(part_type, "short")) + " slot on the blueprint.",
				"点击蓝图上的 " + str(_part_label(part_type, "short")) + " 安装位。"
			)
	_refresh_all()


func _try_install(slot_type: String) -> void:
	if install_animation_active:
		return
	if selected_part_type == "":
		feedback_label.text = GameManager.text("Select a part card from the left first.", "请先从左侧选择零件卡。")
		InteractionFeedback.error(slot_controls.get(slot_type) as Control if slot_controls.has(slot_type) else feedback_label)
		return
	if _is_installed(slot_type):
		# Allow REPLACING with a different part: the same part is a no-op, a
		# new part re-installs (install_part overwrites the slot snapshot, so
		# the old part's alignment/id never carries over).
		var installed_id := str(_installed_part_id(slot_type))
		var picked_id := selected_part_id if selected_part_id != "" else str(_part_for_type(slot_type).get("id", ""))
		if selected_part_type != slot_type or picked_id == installed_id:
			feedback_label.text = str(_part_label(slot_type, "short")) + " " + GameManager.text("is already installed. Pick a different part to replace it.", "已安装。选择另一个零件可替换。")
			InteractionFeedback.error(slot_controls.get(slot_type) as Control if slot_controls.has(slot_type) else feedback_label)
			return
	if selected_part_type != slot_type:
		wrong_attempts[selected_part_type] = int(wrong_attempts.get(selected_part_type, 0)) + 1
		feedback_label.text = _wrong_feedback(selected_part_type, slot_type)
		var selected_card := part_card_controls.get(selected_part_type) as Control
		InteractionFeedback.error(selected_card if selected_card != null else feedback_label)
		var wrong_slot := slot_controls.get(slot_type) as Control
		if wrong_slot != null:
			InteractionFeedback.flash_border(wrong_slot, Color(1.0, 0.53, 0.23), 0.32)
		_refresh_all()
		return

	var order_check: Dictionary = AssemblyManagerScript.can_install(slot_type, _assembly_state())
	if not bool(order_check.get("ok", false)):
		wrong_attempts[selected_part_type] = int(wrong_attempts.get(selected_part_type, 0)) + 1
		feedback_label.text = _order_feedback(slot_type)
		InteractionFeedback.error(part_card_controls.get(selected_part_type) as Control if part_card_controls.has(selected_part_type) else feedback_label)
		_refresh_all()
		return

	install_animation_active = true
	var animation := _capture_part_animation(slot_type)
	var install_id := selected_part_id if selected_part_id != "" else str(_part_for_type(slot_type).get("id", ""))
	var score: int = GameManager.install_part(slot_type, int(wrong_attempts.get(slot_type, 0)), install_id)
	if score < 0:
		install_animation_active = false
		feedback_label.text = GameManager.install_part_block_reason(slot_type, install_id)
		InteractionFeedback.error(part_card_controls.get(slot_type) as Control if part_card_controls.has(slot_type) else feedback_label)
		return
	feedback_label.text = GameManager.text("Installed " + str(_part_label(slot_type, "short")) + ". Alignment " + str(score) + ".", "已安装 " + str(_part_label(slot_type, "short")) + "，对齐 " + str(score) + "。")
	selected_part_type = ""
	selected_part_id = ""
	install_animation_active = false
	_refresh_all()
	_play_part_animation(animation)
	call_deferred("_finish_install_feedback", slot_type)


func _capture_part_animation(part_type: String) -> Dictionary:
	var part := _part_for_type(part_type)
	var path := _part_texture_path(part)
	var source := part_card_controls.get(part_type) as Control
	var target := slot_controls.get(part_type) as Control
	if source == null or target == null or path == "" or not ResourceLoader.exists(path):
		return {}
	var texture := load(path) as Texture2D
	if texture == null:
		return {}
	var source_rect := source.get_global_rect()
	source_rect.position += Vector2(10, 10)
	source_rect.size = Vector2(minf(54.0, source_rect.size.x), minf(54.0, source_rect.size.y))
	return {"texture": texture, "source": source_rect, "target": target.get_global_rect()}


func _play_part_animation(animation: Dictionary) -> void:
	if animation.is_empty():
		return
	InteractionFeedback.fly_texture(animation["texture"], animation["source"], animation["target"], self)


func _finish_install_feedback(part_type: String) -> void:
	var target := slot_controls.get(part_type) as Control
	var card := part_card_controls.get(part_type) as Control
	InteractionFeedback.mechanical_snap(card, target)
	var reason := _part_operation_effect(part_type)
	feedback_label.text = reason
	var next_part := _next_installable_part()
	var next_card := part_card_controls.get(next_part) as Control
	var next_slot := slot_controls.get(next_part) as Control
	if next_card != null:
		InteractionFeedback.pulse(next_card, Color(0.96, 0.70, 0.24), 0.58)
	if next_part == "":
		InteractionFeedback.operation_chain(
			self,
			GameManager.text("Installed %s" % _part_label(part_type, "short"), "已安装%s" % _part_label(part_type, "short")),
			reason,
			GameManager.text("Assembly check is ready", "装配检查已就绪"),
			finish_button,
			Color(0.42, 0.96, 0.58)
		)
	else:
		InteractionFeedback.operation_chain(
			self,
			GameManager.text("Installed %s" % _part_label(part_type, "short"), "已安装%s" % _part_label(part_type, "short")),
			reason,
			GameManager.text("Next: %s" % _part_label(next_part, "short"), "下一步：%s" % _part_label(next_part, "short")),
			next_slot
		)


func _part_operation_effect(part_type: String) -> String:
	match part_type:
		"tripod":
			return GameManager.text("The load now has a stable base.", "载荷现在有了稳定基座。")
		"mount":
			return GameManager.text("The tube can now aim and hold position.", "镜筒现在可以转向并保持位置。")
		"tube":
			return GameManager.text("The optical path is enclosed and aligned.", "光路现在被封闭并保持对齐。")
		"objective":
			return GameManager.text("Incoming light is gathered into the focal plane.", "入射光现在会聚到焦平面。")
		"eyepiece":
			return GameManager.text("The focal image can now be magnified for the eye.", "焦平面图像现在可以放大供肉眼观察。")
		"focus_knob":
			return GameManager.text("The focal plane can now be moved into sharp focus.", "焦平面现在可以调到清晰位置。")
		"finder_scope":
			return GameManager.text("Wide-field aiming can now guide the narrow main view.", "宽视场瞄准现在可以引导狭窄的主镜视野。")
	return GameManager.text("The optical chain gained its next working stage.", "光学链路完成了下一个工作环节。")


func _animate_install_error_if_idle(part_type: String) -> void:
	if install_animation_active or not is_inside_tree():
		return
	var source := part_card_controls.get(part_type) as Control
	InteractionFeedback.error(source if source != null else feedback_label)


func _finish() -> void:
	if GameManager.telescope_is_ready():
		InteractionFeedback.feedback_sfx_requested.emit("assembly_completed")
		GameManager.equip_completed_optical_telescope("refractor")
		GameManager.update_room_guidance_for_level()
		GameManager.set_observatory_spawn("assembly")
		GameManager.save()
		GameManager.go("observatory")
		return
	var missing := GameManager.missing_parts()
	var names: Array[String] = []
	for part_type in missing:
		names.append(_part_label(str(part_type), "short"))
	feedback_label.text = GameManager.text("Missing core parts: " + ", ".join(names) + ".", "核心部件未齐：" + ", ".join(names) + "。")


func _reset() -> void:
	GameManager.reset_assembly()
	for part_type in PART_ORDER:
		wrong_attempts[part_type] = 0
	selected_part_type = ""
	feedback_label.text = GameManager.text("Assembly reset. Start with Tripod.", "已重新组装，请从三脚架开始。")
	_refresh_all()


func _wrong_feedback(part_type: String, slot_type: String) -> String:
	if part_type == "focus_knob":
		return "The focus knob belongs near the eyepiece. It moves the eyepiece to sharpen the image.\n调焦旋钮安装在目镜附近，用来移动目镜位置，让图像变清楚。"
	return "Wrong slot. " + str(_part_label(part_type, "short")) + " belongs in the " + str(_part_label(part_type, "short")) + " slot.\n" \
		+ "位置不对。" + str(_part_label(part_type, "short")) + " 应安装到对应安装位。\n" \
		+ str(_part_label(part_type, "role"))


func _order_feedback(part_type: String) -> String:
	var previous := _previous_required(part_type)
	if previous == "":
		return "Install the lower support parts first.\n请先安装底部支撑结构。"
	return "Install " + str(_part_label(previous, "short")) + " first.\n请先安装 " + str(_part_label(previous, "short")) + "。"


func _previous_required(part_type: String) -> String:
	var index := CORE_PARTS.find(part_type)
	if index <= 0:
		return ""
	for i in range(index):
		var required_type := CORE_PARTS[i]
		if not _is_installed(required_type):
			return required_type
	return ""


func _next_step_description(part_type: String) -> String:
	match part_type:
		"tripod":
			return GameManager.text("Start with the bottom support.", "先从底部支撑开始。")
		"mount":
			return GameManager.text("Add the mount above the tripod.", "把支架安装到三脚架上方。")
		"tube":
			return GameManager.text("Place the tube on the mount.", "把镜筒安装到支架上。")
		"objective":
			return GameManager.text("Install the front lens to collect light.", "安装前端物镜来收集光线。")
		"eyepiece":
			return GameManager.text("Install the eyepiece at the viewing end.", "把目镜安装到观察端。")
		"focus_knob":
			return GameManager.text("Attach the focus knob near the eyepiece.", "把调焦旋钮安装到目镜附近。")
		_:
			return GameManager.text("Add the finder scope for easier aiming.", "安装寻星镜帮助瞄准。")


func _next_installable_part() -> String:
	for part_type in CORE_PARTS:
		if not _is_installed(part_type):
			return part_type
	for optional_type in OPTIONAL_PARTS:
		if GameManager.unlocked_parts_by_type(optional_type).is_empty():
			continue
		if not _is_installed(optional_type):
			return optional_type
	return ""


func _is_installed(part_type: String) -> bool:
	return bool(_dict_value(_assembly_state().get(part_type, {})).get("installed", false))


func _installed_part_id(part_type: String) -> String:
	return str(_dict_value(_assembly_state().get(part_type, {})).get("installed_part_id", ""))


func _part_for_type(part_type: String) -> Dictionary:
	var unlocked: Array = GameManager.unlocked_parts_by_type(part_type)
	var fallback := {
		"id": str(DEFAULT_PART_IDS.get(part_type, "")),
		"type": part_type,
		"name_en": _part_label(str(part_type), "short")
	}
	if unlocked.is_empty():
		return fallback
	var part: Dictionary = _dict_value(unlocked[0])
	var equipped_id := GameManager.equipped_part_id(part_type)
	if equipped_id != "":
		for candidate in unlocked:
			var candidate_part := _dict_value(candidate)
			if str(candidate_part.get("id", "")) == equipped_id:
				return candidate_part
	return part


func _assembly_state() -> Dictionary:
	return _dict_value(GameManager.progress.get("assembly_state", {}))


func _dict_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _draw_grid() -> void:
	for x in range(0, 1024, 32):
		_rect(Vector2(x, 56), Vector2(1, 712), Color(0.13, 0.18, 0.20, 0.14))
	for y in range(56, 768, 32):
		_rect(Vector2(0, y), Vector2(1024, 1), Color(0.13, 0.18, 0.20, 0.14))


func _draw_line(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var points := [from_pos, to_pos]
	var line := Line2D.new()
	line.points = PackedVector2Array(points)
	line.width = 4.0
	line.default_color = color
	blueprint_layer.add_child(line)


func _panel(pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 3, 3))
	add_child(panel)
	_panel_corners(pos, panel_size, border)
	return panel


func _panel_local(parent: Control, pos: Vector2, panel_size: Vector2, color: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	panel.add_theme_stylebox_override("panel", _style(color, border, 2, 4))
	parent.add_child(panel)
	return panel


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _panel_corners(pos: Vector2, panel_size: Vector2, color: Color) -> void:
	_rect(pos + Vector2(4, 4), Vector2(12, 3), color)
	_rect(pos + Vector2(4, 4), Vector2(3, 12), color)
	_rect(pos + Vector2(panel_size.x - 16, 4), Vector2(12, 3), color)
	_rect(pos + Vector2(panel_size.x - 7, 4), Vector2(3, 12), color)
	_rect(pos + Vector2(4, panel_size.y - 7), Vector2(12, 3), color)
	_rect(pos + Vector2(4, panel_size.y - 16), Vector2(3, 12), color)
	_rect(pos + Vector2(panel_size.x - 16, panel_size.y - 7), Vector2(12, 3), color)
	_rect(pos + Vector2(panel_size.x - 7, panel_size.y - 16), Vector2(3, 12), color)


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _rect_local(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _texture(path: String, rect_size: Vector2) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.texture = load(path)
	texture_rect.size = rect_size
	texture_rect.custom_minimum_size = rect_size
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return texture_rect


func _button(text: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.13, 0.22), Color(0.17, 0.25, 0.40), 2, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.22, 0.34), Color(0.95, 0.76, 0.42), 2, 3))
	button.add_theme_stylebox_override("pressed", _style(Color(0.20, 0.14, 0.08), Color(0.95, 0.76, 0.42), 2, 3))
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _on_language_changed() -> void:
	_build()
