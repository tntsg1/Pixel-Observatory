extends Control

const AssemblyUITemplate = preload("res://scripts/ui/assembly_ui_template.gd")
const AssemblyDependencyGraph = preload("res://scripts/systems/assembly_dependency_graph.gd")
const AUTO_CHAIN_TO_TUBE_META := "postgraduate_auto_assemble_tube"
const AUTO_CHAIN_TO_MAIN_META := "postgraduate_auto_assemble_main"

const BG := Color(0.018, 0.028, 0.055)
const PANEL := Color(0.040, 0.065, 0.110)
const GOLD := Color(0.92, 0.67, 0.30)
const CYAN := Color(0.42, 0.82, 1.0)
const GREEN := Color(0.46, 0.90, 0.58)
const RED := Color(0.92, 0.38, 0.32)
const TEXT := Color(0.92, 0.91, 0.84)
const ADVANCED_FAMILY_ATLAS := "res://assets/telescope_parts/placeholders/advanced_family_atlas_placeholder.png"
const NEWTONIAN_TUBE_BLUEPRINT := "res://assets/assembly/newtonian_tube_blueprint.png"
const NEWTONIAN_TUBE_SOURCE_SIZE := Vector2(482.0, 643.0)
const NEWTONIAN_TUBE_SOURCE_CROP := Rect2(Vector2.ZERO, NEWTONIAN_TUBE_SOURCE_SIZE)
const NEWTONIAN_TUBE_SOURCE_SLOTS := {
	# Source-image coordinates measured from the cyan dashed borders in the
	# formal 482x643 blueprint. They are transformed with the image display
	# rect below; none of these are final UI/screen coordinates.
	"reflector_tube": Rect2(54.0, 122.0, 57.0, 55.0),
	"secondary_spider": Rect2(185.0, 141.0, 56.0, 55.0),
	"mirror_cell": Rect2(310.0, 119.0, 57.0, 57.0),
	"primary_mirror": Rect2(393.0, 146.0, 57.0, 56.0),
	"secondary_mirror": Rect2(74.0, 490.0, 58.0, 58.0),
	"focuser": Rect2(220.0, 440.0, 43.0, 40.0),
	"eyepiece": Rect2(293.0, 472.0, 57.0, 57.0),
	"collimation_tool": Rect2(393.0, 458.0, 55.0, 53.0)
}
const DOBSONIAN_TUBE_BLUEPRINT := "res://assets/assembly/dobsonian_tube_blueprint.png"
const DOBSONIAN_TUBE_SOURCE_SIZE := Vector2(726.0, 788.0)
# Cyan-dashed slot boxes measured on the cropped 726x788 board art with
# pixel detection + overlay verification.
const DOBSONIAN_TUBE_SOURCE_SLOTS := {
	"reflector_tube": Rect2(168.0, 535.0, 110.0, 66.0),
	"mirror_cell": Rect2(617.0, 468.0, 51.0, 110.0),
	"primary_mirror": Rect2(552.0, 300.0, 88.0, 238.0),
	"secondary_spider": Rect2(103.0, 248.0, 58.0, 90.0),
	"secondary_mirror": Rect2(190.0, 238.0, 62.0, 96.0),
	"focuser": Rect2(345.0, 153.0, 74.0, 70.0),
	"eyepiece": Rect2(437.0, 152.0, 62.0, 66.0),
	"collimation_tool": Rect2(362.0, 584.0, 67.0, 72.0)
}
# Cassegrain tube: user's full-UI tube blueprint cropped to the board; 8 slots
# measured on the crop + overlay-verified against the printed dashed boxes.
const CASSEGRAIN_TUBE_BLUEPRINT := "res://assets/assembly/cassegrain_tube_blueprint_cropped.png"
const CASSEGRAIN_TUBE_SOURCE_SIZE := Vector2(854.0, 658.0)
const CASSEGRAIN_TUBE_SOURCE_SLOTS := {
	"reflector_tube": Rect2(219.0, 72.0, 78.0, 76.0),
	"mirror_cell": Rect2(713.0, 120.0, 80.0, 82.0),
	"primary_mirror": Rect2(545.0, 72.0, 80.0, 80.0),
	"secondary_mirror": Rect2(67.0, 140.0, 78.0, 80.0),
	"central_baffle": Rect2(387.0, 130.0, 78.0, 80.0),
	"focuser": Rect2(661.0, 240.0, 76.0, 78.0),
	"eyepiece": Rect2(773.0, 296.0, 80.0, 100.0),
	"collimation_tool": Rect2(607.0, 560.0, 80.0, 82.0)
}

var config: Dictionary = {}
var installed: Dictionary = {}
var selected_subpart := ""
var status_label: Label
var blueprint: Control
var template_parts_scroll: ScrollContainer
var template_parts_list: Control
var parts_scroll: ScrollContainer
var template_inspector_title: Label
var template_feedback: Label
var template_stats: Control
var template_ready_dot: Panel
var template_finish: Button
var part_card_controls: Dictionary = {}
var slot_controls: Dictionary = {}
var install_animation_active := false
var auto_assemble_button: Button
var auto_assemble_running := false
var auto_assemble_skip_requested := false
var remembered_parts_scroll_y := 0
var parts_scroll_restore_serial := 0


func _ready() -> void:
	GameManager.language_changed.connect(_build)
	config = GameManager.tube_subassembly_config()
	var saved: Dictionary = GameManager.tube_assembly()
	installed = saved.get("installed_subparts", saved.get("tube_assembly_state", {})).duplicate()
	_build()
	InteractionFeedback.page_enter(self)
	call_deferred("_show_tube_tutorial")
	if GameManager.postgraduate_free_build() and bool(GameManager.get_meta(AUTO_CHAIN_TO_TUBE_META, false)):
		call_deferred("_run_auto_assemble")


func _show_tube_tutorial() -> void:
	InteractionFeedback.tutorial_highlight_once(blueprint, "first_tube_subassembly", GameManager.text(
		"Choose any uninstalled tube part, then place it in the matching blueprint slot. The optical-path diagram explains its function, not a forced order.",
		"任选一个尚未安装的镜筒零件，再放入对应的蓝图槽位。光路图用于解释功能，不代表强制安装顺序。"
	), self)

func _build() -> void:
	_remember_parts_scroll_position()
	for child in get_children():
		child.queue_free()
	parts_scroll = null
	template_parts_scroll = null
	part_card_controls.clear()
	slot_controls.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if str(config.get("family", "")) in ["newtonian", "dobsonian", "cassegrain"]:
		_build_newtonian_template()
		_queue_parts_scroll_restore()
		return
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	var is_newtonian := str(config.get("family", "")) == "newtonian"
	var page_title := GameManager.text("NEWTONIAN OPTICAL TUBE SUB-ASSEMBLY", "牛顿光学镜筒子组装") if is_newtonian else GameManager.text("OPTICAL TUBE ASSEMBLY", "光学镜筒组件")
	var page_subtitle := GameManager.text("Install every internal optical component in any order, then save the completed tube.", "以任意顺序安装全部内部光学组件，再保存完成的镜筒。") if is_newtonian else _subtitle()
	add_child(_label(page_title, Vector2(20, 14), Vector2(984, 30), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_label(page_subtitle, Vector2(26, 46), Vector2(972, 24), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var tray := _panel(Vector2(20, 88), Vector2(276, 614), GameManager.text("TUBE SUBPARTS", "镜筒子零件"))
	var scroll := ScrollContainer.new()
	parts_scroll = scroll
	scroll.position = Vector2(12, 42)
	scroll.size = Vector2(252, 550)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(232, 0)
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for subpart_value in config.get("order", []):
		list.add_child(_part_card(str(subpart_value)))

	var board := _panel(Vector2(314, 88), Vector2(452, 614), GameManager.text("EXPLODED BLUEPRINT", "拆解蓝图"))
	blueprint = Control.new()
	blueprint.position = Vector2(10, 38)
	blueprint.size = Vector2(432, 500)
	board.add_child(blueprint)
	_draw_blueprint()

	var inspector := _panel(Vector2(784, 88), Vector2(220, 614), GameManager.text("TUBE CHECK", "镜筒检查"))
	status_label = _label(_status_text(), Vector2(14, 48), Vector2(192, 178), 12, TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(status_label)
	if str(config.get("family", "")) == "newtonian":
		var complete_ratio := _completion_ratio()
		var readiness := GameManager.text("READY" if complete_ratio >= 1.0 and GameManager.collimation_is_acceptable() else "NOT READY", "已就绪" if complete_ratio >= 1.0 and GameManager.collimation_is_acceptable() else "未就绪")
		var readiness_color := GREEN if complete_ratio >= 1.0 and GameManager.collimation_is_acceptable() else RED
		inspector.add_child(_label(readiness, Vector2(14, 238), Vector2(192, 28), 18, readiness_color, HORIZONTAL_ALIGNMENT_CENTER))
		inspector.add_child(_label(GameManager.text("Optics: %d%%" % roundi(complete_ratio * 100.0), "光学：%d%%" % roundi(complete_ratio * 100.0)), Vector2(18, 280), Vector2(186, 22), 12, CYAN))
		inspector.add_child(_label(GameManager.text("Alignment: %d%%" % roundi(GameManager.collimation_score()), "准直：%d%%" % roundi(GameManager.collimation_score())), Vector2(18, 310), Vector2(186, 22), 12, CYAN))
	var save_button := _button(GameManager.text("Save Tube Assembly", "保存镜筒组装"), Vector2(14, 500), Vector2(192, 42), Color(0.10, 0.30, 0.20))
	save_button.pressed.connect(_save_assembly)
	inspector.add_child(save_button)
	_add_flat_auto_assemble_button(inspector)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 550), Vector2(192, 34), Color(0.10, 0.14, 0.22))
	back.pressed.connect(_back)
	inspector.add_child(back)
	_queue_parts_scroll_restore()


func _build_newtonian_template() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.006, 0.009, 0.018))
	AssemblyUITemplate.add_title_bar(
		self,
		GameManager.text("Telescope Assembly", "望远镜组装台"),
		GameManager.text("Pick a tube part, then click its blueprint slot.", "选择镜筒零件，再点击蓝图安装位。")
	)
	AssemblyUITemplate.add_titled_panel(self, AssemblyUITemplate.LEFT_PANEL_RECT, GameManager.text("Tube Parts Tray", "镜筒零件托盘"))
	AssemblyUITemplate.add_blueprint_panel(self, GameManager.text("Tube Blueprint", "镜筒蓝图"))

	template_parts_scroll = ScrollContainer.new()
	parts_scroll = template_parts_scroll
	template_parts_scroll.position = AssemblyUITemplate.PARTS_SCROLL_RECT.position
	template_parts_scroll.size = AssemblyUITemplate.PARTS_SCROLL_RECT.size
	template_parts_scroll.clip_contents = true
	template_parts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(template_parts_scroll)
	template_parts_list = Control.new()
	template_parts_list.custom_minimum_size = AssemblyUITemplate.PARTS_LIST_SIZE
	template_parts_list.size = AssemblyUITemplate.PARTS_LIST_SIZE
	template_parts_scroll.add_child(template_parts_list)
	var y := 0.0
	for subpart_value in config.get("order", []):
		_add_newtonian_tube_card(str(subpart_value), Vector2(0, y))
		y += AssemblyUITemplate.PART_CARD_STEP
	template_parts_list.custom_minimum_size.y = maxf(560.0, y)
	template_parts_list.size = template_parts_list.custom_minimum_size

	blueprint = Control.new()
	blueprint.position = Vector2(334, 116)
	blueprint.size = Vector2(424, 452)
	add_child(blueprint)
	var tube_config := _tube_blueprint_config()
	var layout := _calculate_blueprint_layout(tube_config["size"], Rect2(Vector2.ZERO, tube_config["size"]), Rect2(Vector2.ZERO, blueprint.size))
	var blueprint_image := TextureRect.new()
	blueprint_image.custom_minimum_size = Vector2.ZERO
	blueprint_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blueprint_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blueprint_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blueprint_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_image.texture = load(str(tube_config["path"])) as Texture2D
	blueprint_image.position = layout["display_rect"].position
	blueprint_image.size = layout["display_rect"].size
	blueprint.add_child(blueprint_image)
	var slots := _newtonian_slot_positions()
	for subpart_value in config.get("order", []):
		var subpart := str(subpart_value)
		_draw_slot(subpart, slots[subpart])

	var helper := _label(GameManager.text("Select a card, then click the matching slot.", "选择零件卡，再点击对应安装位。"), Vector2(346, 580), Vector2(408, 28), 12, Color(0.72, 0.82, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(helper)
	# Cassegrain's folded path has no diagonal spider; use its own order line.
	var order_hint_en := "Tube -> Cell -> Primary -> Spider\nSecondary -> Focus -> Eye -> Collimation"
	var order_hint_zh := "镜筒 -> 镜座 -> 主镜 -> 蜘蛛架\n副镜 -> 调焦 -> 目镜 -> 准直"
	if str(config.get("family", "")) == "cassegrain":
		order_hint_en = "Tube -> Cell -> Primary -> Secondary\nBaffle -> Rear Focuser -> Eye -> Collimation"
		order_hint_zh = "镜筒 -> 镜座 -> 主镜 -> 副镜\n挡板 -> 后端调焦 -> 目镜 -> 准直"
	var order_text := _label(GameManager.text(order_hint_en, order_hint_zh), Vector2(340, 606), Vector2(420, 38), 9, Color(0.56, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	order_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(order_text)

	var shell := AssemblyUITemplate.add_inspector_shell(
		self,
		GameManager.text("Tube Inspector", "镜筒检查器"),
		GameManager.text("Save Tube Assembly", "保存镜筒组装"),
		GameManager.text("Reassemble", "重装"),
		GameManager.text("Back", "返回"),
		_save_assembly,
		_reset_newtonian_tube,
		_back
	)
	template_inspector_title = shell["status"]
	template_feedback = shell["feedback"]
	template_stats = shell["stats"]
	template_ready_dot = shell["ready_dot"]
	template_finish = shell["finish"]
	status_label = template_feedback
	_add_template_auto_assemble_button()
	AssemblyUITemplate.add_hints_toggle(self, GameManager, _build)
	_refresh_newtonian_tube_inspector()


func _remember_parts_scroll_position() -> void:
	if is_instance_valid(parts_scroll):
		remembered_parts_scroll_y = parts_scroll.scroll_vertical


func _queue_parts_scroll_restore() -> void:
	parts_scroll_restore_serial += 1
	call_deferred("_restore_parts_scroll_position", parts_scroll_restore_serial)


func _restore_parts_scroll_position(serial: int) -> void:
	# Rebuilding the selected card replaces the ScrollContainer.  Wait until its
	# new content has calculated a range before restoring the exact viewport.
	await get_tree().process_frame
	if serial != parts_scroll_restore_serial or not is_instance_valid(parts_scroll):
		return
	var bar := parts_scroll.get_v_scroll_bar()
	var maximum := maxi(0, floori(bar.max_value - bar.page))
	parts_scroll.scroll_vertical = clampi(remembered_parts_scroll_y, 0, maximum)


func _add_newtonian_tube_card(subpart: String, position: Vector2) -> void:
	var part := _part_for_subpart(subpart)
	var installed_now := bool(installed.get(subpart, false))
	var selected := selected_subpart == subpart
	var texture_path := str(part.get("icon_path", ""))
	var texture := load(texture_path) as Texture2D if texture_path != "" and ResourceLoader.exists(texture_path) else null
	var card := AssemblyUITemplate.add_part_card(
		template_parts_list,
		position,
		GameManager.dict_text(part, "name"),
		_newtonian_tube_part_role(subpart),
		GameManager.text("Installed", "已安装") if installed_now else GameManager.text("Not Installed", "未安装"),
		texture,
		installed_now,
		selected,
		_select_newtonian_tube_part.bind(subpart)
	)
	part_card_controls[subpart] = card


func _newtonian_tube_part_role(subpart: String) -> String:
	match subpart:
		"reflector_tube": return GameManager.text("Holds the reflected light path", "保持反射光路")
		"mirror_cell": return GameManager.text("Supports the primary mirror", "支撑主反射镜")
		"primary_mirror": return GameManager.text("Collects and reflects light", "收集并反射光线")
		"secondary_spider": return GameManager.text("Holds the diagonal mirror", "固定斜置副镜")
		"secondary_mirror":
			if str(config.get("family", "")) == "cassegrain":
				return GameManager.text("Convex mirror folds light back", "凸面副镜把光折返")
			return GameManager.text("Turns light to the side", "把光线转向侧面")
		"central_baffle": return GameManager.text("Blocks stray light down the axis", "沿光轴遮挡杂散光")
		"focuser":
			if str(config.get("family", "")) == "cassegrain":
				return GameManager.text("Rear-cell focus at the tube back", "位于镜筒后端的调焦座")
			return GameManager.text("Moves the eyepiece for focus", "移动目镜进行调焦")
		"eyepiece": return GameManager.text("Magnifies the formed image", "放大形成的图像")
		"collimation_tool": return GameManager.text("Aligns the optical axis", "校准光学轴线")
	return ""


func _select_newtonian_tube_part(subpart: String) -> void:
	selected_subpart = subpart
	_build()


func _reset_newtonian_tube() -> void:
	installed.clear()
	selected_subpart = ""
	GameManager.update_tube_subassembly_progress(installed)
	_build()


func _refresh_newtonian_tube_inspector() -> void:
	var complete := _next_required_subpart() == ""
	template_inspector_title.text = GameManager.text("READY", "已就绪") if complete else GameManager.text("ASSEMBLING", "组装中")
	template_inspector_title.add_theme_color_override("font_color", GREEN if complete else GOLD)
	_set_template_ready_dot(GREEN if complete else GOLD)
	template_finish.disabled = not complete
	if selected_subpart != "":
		var part := _part_for_subpart(selected_subpart)
		template_feedback.text = GameManager.dict_text(part, "name") + "\n" + GameManager.dict_text(part, "description") + "\n" + GameManager.text("Click the matching blueprint slot.", "请点击对应蓝图安装位。")
	else:
		template_feedback.text = _status_text()
	_clear_control(template_stats)
	var completion := _completion_ratio()
	var state := GameManager.tube_assembly()
	var rows := [
		[GameManager.text("OPTICS", "光学"), completion],
		[GameManager.text("ALIGNMENT", "对齐"), float(state.get("optical_alignment", 0.0)) / 100.0],
		[GameManager.text("COLLIMATION", "准直"), GameManager.collimation_score() / 100.0],
		[GameManager.text("ASSEMBLY", "组装"), completion],
	]
	for index in range(rows.size()):
		_add_template_stat(template_stats, str(rows[index][0]), float(rows[index][1]), float(index) * 54.0)


func _set_template_ready_dot(color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.14)
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	template_ready_dot.add_theme_stylebox_override("panel", style)


func _add_template_stat(parent: Control, stat_name: String, ratio: float, y: float) -> void:
	var label := _label(stat_name, Vector2(0, y), Vector2(200, 18), 11, Color(0.86, 0.90, 0.94))
	parent.add_child(label)
	var clamped := clampf(ratio, 0.0, 1.0)
	for index in range(8):
		var cell := ColorRect.new()
		cell.position = Vector2(float(index) * 24.0, y + 24.0)
		cell.size = Vector2(20, 14)
		cell.color = GREEN if index < roundi(clamped * 8.0) else Color(0.10, 0.16, 0.14)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(cell)


func _clear_control(parent: Control) -> void:
	for child in parent.get_children():
		child.queue_free()


func _subtitle() -> String:
	var family := str(config.get("family", ""))
	match family:
		"newtonian": return GameManager.text("Optical path: primary mirror -> diagonal secondary -> side focuser. Install matching parts in any order.", "光路：主镜 -> 斜副镜 -> 侧置调焦座。零件可按任意顺序装入对应槽位。")
		"dobsonian": return GameManager.text("The large optical tube is separate from the Dobsonian rocker base.", "大口径光学镜筒与多布森摇臂底座分开组装。")
		"cassegrain": return GameManager.text("Folded path: primary -> convex secondary -> central baffle -> rear focuser.", "折叠光路：主镜 -> 凸面副镜 -> 中央挡板 -> 后端调焦座。")
		"gregorian": return GameManager.text("Optical path: primary focus -> concave secondary -> final focus. Install matching parts in any order.", "光路：主焦点 -> 凹面副镜 -> 最终焦点。零件可按任意顺序安装。")
	return ""


func _part_card(subpart: String) -> Control:
	var installed_now := bool(installed.get(subpart, false))
	var part := _part_for_subpart(subpart)
	var card := Panel.new()
	card.custom_minimum_size = Vector2(232, 58)
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _style(Color(0.075, 0.10, 0.15), GREEN if installed_now else Color(0.25, 0.43, 0.66), 2))
	var title := _label(GameManager.dict_text(part, "name"), Vector2(58, 4), Vector2(115, 22), 11, TEXT)
	title.clip_text = true
	card.add_child(title)
	var card_icon := _part_texture_control(part, Rect2(7, 7, 44, 44))
	if card_icon != null:
		card.add_child(card_icon)
	card.add_child(_label(GameManager.text("Installed", "已安装") if installed_now else GameManager.text("Select", "选择"), Vector2(9, 31), Vector2(98, 17), 10, GREEN if installed_now else CYAN))
	var use_button := Button.new()
	use_button.text = GameManager.text("Done", "完成") if installed_now else GameManager.text("Use", "使用")
	use_button.disabled = installed_now
	use_button.position = Vector2(174, 11)
	use_button.size = Vector2(46, 32)
	use_button.add_theme_font_size_override("font_size", 10)
	use_button.pressed.connect(func() -> void:
		selected_subpart = subpart
		status_label.text = GameManager.text("Selected " + GameManager.dict_text(part, "name") + ". Click its gold slot.", "已选择" + GameManager.dict_text(part, "name") + "。请点击金色槽位。")
		_draw_blueprint()
	)
	card.add_child(use_button)
	part_card_controls[subpart] = card
	return card


func _draw_blueprint() -> void:
	for child in blueprint.get_children():
		child.queue_free()
	if str(config.get("family", "")) == "newtonian":
		# Static image only: live slots, part state and all interactions are
		# still created by Godot immediately below.
		var layout := _calculate_blueprint_layout(NEWTONIAN_TUBE_SOURCE_SIZE, NEWTONIAN_TUBE_SOURCE_CROP, Rect2(Vector2.ZERO, blueprint.size))
		var reference := TextureRect.new()
		reference.custom_minimum_size = Vector2.ZERO
		reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reference.texture = load(NEWTONIAN_TUBE_BLUEPRINT) as Texture2D
		reference.position = layout["display_rect"].position
		reference.size = layout["display_rect"].size
		blueprint.add_child(reference)
	else:
		var art := TextureRect.new()
		art.texture = _art_texture()
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.position = Vector2(34, 38)
		art.size = Vector2(364, 304)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blueprint.add_child(art)
	var arrow := _label_to(blueprint, _light_path_text(), Vector2(76, 458), Vector2(280, 26), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slots := _slot_positions()
	for subpart_value in config.get("order", []):
		var subpart := str(subpart_value)
		_draw_slot(subpart, slots.get(subpart, Rect2(160, 410, 118, 40)))
	if str(config.get("family", "")) == "gregorian":
		_draw_gregorian_mount_reference()


func _draw_slot(subpart: String, rect: Rect2) -> void:
	var installed_now := bool(installed.get(subpart, false))
	var next := not installed_now and GameManager.assembly_hints_enabled()
	var selected := selected_subpart == subpart
	# Cassegrain shares the printed-blueprint style: the art already carries every
	# dashed box and label, so it uses the clean state-only slot (no duplicate
	# frame or label overlapping the baked text) exactly like Newtonian/Dobsonian.
	var uses_printed_blueprint := str(config.get("family", "")) in ["newtonian", "dobsonian", "cassegrain"]
	if uses_printed_blueprint:
		_draw_newtonian_slot(subpart, rect, installed_now, next, selected)
		return
	# Reached only by families whose blueprint does NOT bake dashed boxes/labels
	# (gregorian and the mount-based devices); those draw their own slot chrome.
	var slot := Panel.new()
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	var color := GREEN if installed_now else (GOLD if selected or next else Color(0.35, 0.66, 0.90, 0.75))
	slot.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.13, 0.05), color, 2))
	blueprint.add_child(slot)
	slot_controls[subpart] = slot
	if installed_now:
		var installed_icon := _part_texture_control(_part_for_subpart(subpart), Rect2(4, 3, rect.size.x - 8, rect.size.y - 6))
		if installed_icon != null:
			slot.add_child(installed_icon)
	var label := _label(GameManager.dict_text(_part_for_subpart(subpart), "name") if installed_now else _short_name(subpart), Vector2(3, 2), rect.size - Vector2(6, 4), 9, GREEN if installed_now else Color(0.35, 0.66, 0.90, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	AssemblyUITemplate.add_slot_hit_target(slot, Rect2(Vector2.ZERO, rect.size), _install_subpart.bind(subpart))


func _draw_newtonian_slot(subpart: String, rect: Rect2, installed_now: bool, next: bool, selected: bool) -> void:
	# The formal blueprint supplies idle dashed borders and labels. Installed
	# artwork and live state chrome share this exact transformed rectangle.
	if installed_now:
		var installed_icon := _newtonian_installed_texture(subpart, rect)
		if installed_icon != null:
			blueprint.add_child(installed_icon)

	var state_frame := Panel.new()
	state_frame.name = "TubeSlot_%s" % subpart
	state_frame.position = rect.position
	state_frame.size = rect.size
	state_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if installed_now:
		state_frame.add_theme_stylebox_override("panel", _style(Color(0.04, 0.10, 0.06, 0.12), GREEN, 2))
	elif selected or (next and selected_subpart == ""):
		state_frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), GOLD, 2))
	else:
		state_frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	blueprint.add_child(state_frame)
	slot_controls[subpart] = state_frame

	if installed_now:
		var ok_badge := Label.new()
		ok_badge.name = "TubeOK_%s" % subpart
		ok_badge.text = "OK"
		ok_badge.position = rect.position + Vector2(maxf(0.0, rect.size.x - 24.0), maxf(0.0, rect.size.y - 15.0))
		ok_badge.size = Vector2(24, 15)
		ok_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ok_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ok_badge.add_theme_font_size_override("font_size", 8)
		ok_badge.add_theme_color_override("font_color", Color(0.86, 1.0, 0.88))
		ok_badge.add_theme_stylebox_override("normal", _style(Color(0.02, 0.12, 0.06, 0.92), GREEN, 1))
		ok_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blueprint.add_child(ok_badge)

	var hit_target := AssemblyUITemplate.add_slot_hit_target(
		blueprint,
		rect,
		_install_subpart.bind(subpart)
	)
	hit_target.name = "TubeHit_%s" % subpart


func _newtonian_installed_texture(subpart: String, final_rect: Rect2) -> TextureRect:
	var part := _part_for_subpart(subpart)
	var path := str(part.get("icon_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var loaded_texture := load(path) as Texture2D
	if loaded_texture == null:
		return null
	var texture_rect := TextureRect.new()
	texture_rect.name = "TubeTexture_%s" % subpart
	texture_rect.custom_minimum_size = Vector2.ZERO
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = loaded_texture
	texture_rect.position = final_rect.position
	texture_rect.size = final_rect.size
	return texture_rect


func _install_subpart(slot_subpart: String) -> void:
	if install_animation_active:
		return
	if bool(installed.get(slot_subpart, false)):
		status_label.text = GameManager.text("This subpart is already installed.", "该子零件已经安装。")
		_animate_install_error_if_idle(slot_subpart)
		return
	if selected_subpart == "":
		status_label.text = GameManager.text("Select a tube subpart from the left first.", "请先从左侧选择镜筒子零件。")
		_animate_install_error_if_idle(slot_subpart)
		return
	if selected_subpart != slot_subpart:
		status_label.text = _mismatch_reason(selected_subpart, slot_subpart)
		_animate_install_error_if_idle(slot_subpart)
		return
	install_animation_active = true
	var animation := _capture_part_animation(slot_subpart)
	installed[slot_subpart] = true
	selected_subpart = ""
	GameManager.update_tube_subassembly_progress(installed)
	status_label.text = GameManager.text("Installed. The tube optical path is taking shape.", "安装完成。镜筒光路正在成形。")
	install_animation_active = false
	_build()
	_play_part_animation(animation)
	call_deferred("_finish_install_feedback", slot_subpart)


func _add_flat_auto_assemble_button(inspector: Control) -> void:
	if not GameManager.postgraduate_free_build():
		auto_assemble_button = null
		return
	auto_assemble_button = _button(
		GameManager.text("Skip Animation", "跳过演出") if auto_assemble_running else GameManager.text("Auto Assemble", "自动装配"),
		Vector2(14, 448),
		Vector2(192, 42),
		Color(0.08, 0.20, 0.31)
	)
	auto_assemble_button.name = "AutoAssembleButton"
	auto_assemble_button.pressed.connect(_on_auto_assemble_pressed)
	inspector.add_child(auto_assemble_button)


func _add_template_auto_assemble_button() -> void:
	if not GameManager.postgraduate_free_build():
		auto_assemble_button = null
		return
	auto_assemble_button = _button(
		GameManager.text("Skip Animation", "跳过演出") if auto_assemble_running else GameManager.text("Auto Assemble", "自动装配"),
		Vector2(792, 546),
		Vector2(200, 32),
		Color(0.08, 0.20, 0.31)
	)
	auto_assemble_button.name = "AutoAssembleButton"
	auto_assemble_button.pressed.connect(_on_auto_assemble_pressed)
	add_child(auto_assemble_button)


func _on_auto_assemble_pressed() -> void:
	if auto_assemble_running:
		auto_assemble_skip_requested = true
		if auto_assemble_button != null:
			auto_assemble_button.text = GameManager.text("Finishing...", "正在完成…")
		return
	_run_auto_assemble()


func _run_auto_assemble() -> void:
	if not GameManager.postgraduate_free_build() or auto_assemble_running:
		return
	var family := str(config.get("family", GameManager.assembly_context_family()))
	var available: Array[String] = []
	for value in config.get("order", []):
		available.append(str(value))
	var installed_parts: Array[String] = []
	for part_type in available:
		if bool(installed.get(part_type, false)):
			installed_parts.append(part_type)
	var result := AssemblyDependencyGraph.topological_order(family, "tube", available, installed_parts)
	if not bool(result.get("ok", false)):
		status_label.text = GameManager.text(
			"Auto assembly stopped: the tube dependency graph is invalid.",
			"自动装配已停止：镜筒依赖图无效。"
		)
		push_error("%s tube auto-assembly dependency error: %s" % [family, result])
		return
	var queue: Array = result.get("order", [])
	if queue.is_empty():
		_finish_auto_assemble_chain_if_needed()
		return

	auto_assemble_running = true
	auto_assemble_skip_requested = false
	install_animation_active = true
	if auto_assemble_button != null:
		auto_assemble_button.text = GameManager.text("Skip Animation", "跳过演出")
	for value in queue:
		if not is_inside_tree():
			return
		var subpart := str(value)
		if bool(installed.get(subpart, false)):
			continue
		var animation := _capture_part_animation(subpart)
		installed[subpart] = true
		GameManager.update_tube_subassembly_progress(installed)
		_play_part_animation(animation)
		if not auto_assemble_skip_requested:
			await get_tree().create_timer(0.40 if not InteractionFeedback.is_reduced_motion() else 0.10).timeout
		_build()
		await get_tree().process_frame
		_finish_install_feedback(subpart)
		if not auto_assemble_skip_requested:
			await get_tree().create_timer(0.11).timeout
	install_animation_active = false
	auto_assemble_running = false
	auto_assemble_skip_requested = false
	selected_subpart = ""
	_build()
	await get_tree().process_frame
	InteractionFeedback.operation_chain(
		self,
		GameManager.text("Tube auto assembly complete", "镜筒自动装配完成"),
		GameManager.text("Supports were seated before their optical components.", "承载结构先就位，光学组件随后完成安装。"),
		GameManager.text("Tube check is ready", "镜筒检查已就绪"),
		template_finish,
		Color(0.42, 0.96, 0.58)
	)
	_finish_auto_assemble_chain_if_needed()


func _finish_auto_assemble_chain_if_needed() -> void:
	if not bool(GameManager.get_meta(AUTO_CHAIN_TO_TUBE_META, false)):
		return
	GameManager.remove_meta(AUTO_CHAIN_TO_TUBE_META)
	GameManager.set_meta(AUTO_CHAIN_TO_MAIN_META, true)
	_save_assembly()


func _capture_part_animation(subpart: String) -> Dictionary:
	var part := _part_for_subpart(subpart)
	var path := str(part.get("icon_path", ""))
	var source := part_card_controls.get(subpart) as Control
	var target := slot_controls.get(subpart) as Control
	if source == null or target == null or path == "" or not ResourceLoader.exists(path):
		return {}
	var texture := load(path) as Texture2D
	if texture == null:
		return {}
	var source_rect := source.get_global_rect()
	source_rect.position += Vector2(7, 7)
	source_rect.size = Vector2(minf(48.0, source_rect.size.x), minf(48.0, source_rect.size.y))
	return {"texture": texture, "source": source_rect, "target": target.get_global_rect()}


func _play_part_animation(animation: Dictionary) -> void:
	if animation.is_empty():
		return
	InteractionFeedback.fly_texture(animation["texture"], animation["source"], animation["target"], self)


func _finish_install_feedback(subpart: String) -> void:
	var target := slot_controls.get(subpart) as Control
	if target != null:
		InteractionFeedback.success(target, "tube_part_installed")


func _animate_install_error_if_idle(subpart: String) -> void:
	if install_animation_active or not is_inside_tree():
		return
	var source := part_card_controls.get(subpart) as Control
	InteractionFeedback.error(source if source != null else status_label)


func _mismatch_reason(selected: String, slot: String) -> String:
	# Teach WHY the placement is wrong (spec: every wrong install names the
	# real optical reason), not just "wrong slot".
	if selected == "secondary_mirror":
		return GameManager.text(
			"The diagonal secondary must sit in the spider at the tube's front - it turns light to the side focuser.",
			"斜副镜必须装在镜筒前端的蜘蛛支架中心——它负责把光转向侧置调焦座。"
		)
	if selected == "primary_mirror":
		return GameManager.text(
			"The primary mirror belongs in the mirror cell at the REAR of the tube, where it collects incoming light.",
			"主镜必须装在镜筒后端的主镜座里——它在那里收集入射光。"
		)
	if selected == "eyepiece":
		return GameManager.text(
			"The eyepiece mounts on the side focuser - a Newtonian's image exits the side of the tube.",
			"目镜必须装在侧置调焦座上——牛顿镜的图像从镜筒侧面出来。"
		)
	if selected == "collimation_tool":
		return GameManager.text(
			"The collimation cap is an alignment tool, not an eyepiece - it goes on its own marked position.",
			"准直盖是校准工具,不能代替目镜——请装到它自己的标记位置。"
		)
	if selected == "secondary_spider":
		return GameManager.text(
			"The spider vanes stretch across the front opening of the tube to hold the secondary.",
			"蜘蛛支架要横跨镜筒前端开口,用来悬挂副镜。"
		)
	if selected == "mirror_cell":
		return GameManager.text(
			"The mirror cell bolts to the rear of the tube - it holds and collimates the primary.",
			"主镜座要固定在镜筒后端——它负责承托并准直主镜。"
		)
	return GameManager.text("That part belongs to another position in this telescope.", "该零件属于这台望远镜的其他安装位置。")


func _missing_subparts() -> Array[String]:
	var missing: Array[String] = []
	for item in config.get("order", []):
		var subpart := str(item)
		if not bool(installed.get(subpart, false)):
			missing.append(subpart)
	return missing

func _next_required_subpart() -> String:
	for item in config.get("order", []):
		var subpart := str(item)
		if not bool(installed.get(subpart, false)):
			return subpart
	return ""


func _completion_ratio() -> float:
	var order: Array = config.get("order", [])
	if order.is_empty():
		return 0.0
	var count := 0
	for subpart_value in order:
		if bool(installed.get(str(subpart_value), false)):
			count += 1
	return float(count) / float(order.size())


func _save_assembly() -> void:
	var missing := _missing_subparts()
	if not missing.is_empty():
		var missing_names: Array[String] = []
		for subpart in missing:
			missing_names.append(_short_name(subpart))
		status_label.text = GameManager.text(
			"Tube assembly is incomplete. Missing: %s." % ", ".join(missing_names),
			"镜筒组装尚未完成。缺少：%s。" % "、".join(missing_names)
		)
		InteractionFeedback.error(template_finish if template_finish != null else status_label)
		return
	var score := 100.0
	var alignment := 100.0
	var uses_placeholder_assets := not str(config.get("family", "")) in ["newtonian", "dobsonian"]
	if not GameManager.save_tube_assembly(installed, score, alignment, uses_placeholder_assets):
		status_label.text = GameManager.text("Tube assembly could not be saved.", "镜筒组件无法保存。")
		InteractionFeedback.error(template_finish if template_finish != null else status_label)
		return
	for slot_value in slot_controls.values():
		var slot := slot_value as Control
		if slot != null:
			InteractionFeedback.pulse(slot, Color(0.58, 1.0, 0.68, 1.0), 0.34)
	InteractionFeedback.success(blueprint, "tube_assembly_saved")
	if str(config.get("family", "")) in ["newtonian", "dobsonian"]:
		GameManager.install_part("optical_tube_assembly", 0)
	GameManager.go("advanced_assembly")


func _back() -> void:
	GameManager.update_tube_subassembly_progress(installed)
	GameManager.go("advanced_assembly")


func _part_for_subpart(subpart: String) -> Dictionary:
	var order: Array = config.get("order", [])
	var ids: Array = config.get("ids", [])
	var index := order.find(subpart)
	if index >= 0 and index < ids.size():
		var part := GameManager.get_part(str(ids[index]))
		if not part.is_empty():
			if GameManager.equipped_part_id(str(part.get("type", ""))) != str(part.get("id", "")):
				GameManager.equip_part(str(part.get("id", "")))
			return part
	return {"id": subpart, "name_en": _short_name(subpart), "name_zh": _short_name(subpart)}


func _draw_gregorian_mount_reference() -> void:
	var mount := GameManager.get_part("gregorian_equatorial_mount")
	var mount_slot := Panel.new()
	mount_slot.position = Vector2(152, 384)
	mount_slot.size = Vector2(128, 102)
	mount_slot.clip_contents = true
	mount_slot.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.13, 0.78), CYAN, 2))
	blueprint.add_child(mount_slot)
	var mount_icon := _part_texture_control(mount, Rect2(18, 4, 92, 74))
	if mount_icon != null:
		mount_slot.add_child(mount_icon)
	var caption := _label(GameManager.text("Main Equatorial Mount", "主赤道仪支架"), Vector2(4, 78), Vector2(120, 20), 9, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	mount_slot.add_child(caption)


func _part_texture_control(part: Dictionary, bounds: Rect2) -> TextureRect:
	var path := str(part.get("icon_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.texture = texture
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = bounds.position
	icon.size = bounds.size
	icon.custom_minimum_size = Vector2.ZERO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _calculate_blueprint_layout(source_size: Vector2, source_crop: Rect2, bounds: Rect2) -> Dictionary:
	var crop := source_crop.intersection(Rect2(Vector2.ZERO, source_size))
	if crop.size.x <= 0.0 or crop.size.y <= 0.0:
		crop = Rect2(Vector2.ZERO, source_size)
	var scale_factor := minf(bounds.size.x / crop.size.x, bounds.size.y / crop.size.y)
	var display_size := crop.size * scale_factor
	var centered_offset := (bounds.size - display_size) * 0.5
	return {
		"source_size": source_size,
		"source_crop": crop,
		"display_rect": Rect2(bounds.position + centered_offset, display_size),
		"scale": scale_factor,
	}


func _source_rect_to_blueprint(source_rect: Rect2, layout: Dictionary) -> Rect2:
	var crop: Rect2 = layout["source_crop"]
	var display_rect: Rect2 = layout["display_rect"]
	var scale_factor := float(layout["scale"])
	var cropped_position := source_rect.position - crop.position
	return Rect2(display_rect.position + cropped_position * scale_factor, source_rect.size * scale_factor)


func _blueprint_rect_to_screen(parent: Control, local_rect: Rect2) -> Rect2:
	var transform := parent.get_global_transform_with_canvas()
	return Rect2(transform * local_rect.position, transform.basis_xform(local_rect.size))


func debug_newtonian_tube_slot_geometry() -> Dictionary:
	var result := {}
	if blueprint == null:
		return result
	var tube_config := _tube_blueprint_config()
	var source_size: Vector2 = tube_config.get("size", NEWTONIAN_TUBE_SOURCE_SIZE)
	var slots: Dictionary = tube_config.get("slots", NEWTONIAN_TUBE_SOURCE_SLOTS)
	var layout := _calculate_blueprint_layout(
		source_size,
		Rect2(Vector2.ZERO, source_size),
		Rect2(Vector2.ZERO, blueprint.size)
	)
	for part_type_value in slots.keys():
		var part_type := str(part_type_value)
		var source_rect: Rect2 = slots[part_type]
		var local_rect := _source_rect_to_blueprint(source_rect, layout)
		var texture := blueprint.find_child("TubeTexture_%s" % part_type, true, false) as TextureRect
		result[part_type] = {
			"source_rect": source_rect,
			"blueprint_local_rect": local_rect,
			"screen_rect": _blueprint_rect_to_screen(blueprint, local_rect),
			"installed_texture_rect": Rect2(texture.position, texture.size) if texture != null else Rect2(),
		}
	return result


func _tube_blueprint_config() -> Dictionary:
	if str(config.get("family", "")) == "dobsonian":
		return {"path": DOBSONIAN_TUBE_BLUEPRINT, "size": DOBSONIAN_TUBE_SOURCE_SIZE, "slots": DOBSONIAN_TUBE_SOURCE_SLOTS}
	if str(config.get("family", "")) == "cassegrain":
		return {"path": CASSEGRAIN_TUBE_BLUEPRINT, "size": CASSEGRAIN_TUBE_SOURCE_SIZE, "slots": CASSEGRAIN_TUBE_SOURCE_SLOTS}
	return {"path": NEWTONIAN_TUBE_BLUEPRINT, "size": NEWTONIAN_TUBE_SOURCE_SIZE, "slots": NEWTONIAN_TUBE_SOURCE_SLOTS}


func _newtonian_slot_positions() -> Dictionary:
	# Shared transform: every slot rect derives from the SAME displayed
	# blueprint layout, so panel resizes keep art and slots aligned.
	var tube_config := _tube_blueprint_config()
	var slots: Dictionary = tube_config["slots"]
	var layout := _calculate_blueprint_layout(tube_config["size"], Rect2(Vector2.ZERO, tube_config["size"]), Rect2(Vector2.ZERO, blueprint.size))
	var result := {}
	for part_type in slots.keys():
		result[part_type] = _source_rect_to_blueprint(slots[part_type], layout)
	return result


func _slot_positions() -> Dictionary:
	match str(config.get("family", "")):
		"newtonian", "dobsonian": return _newtonian_slot_positions()
		"cassegrain": return {"reflector_tube": Rect2(80, 164, 172, 42), "primary_mirror": Rect2(280, 212, 96, 36), "secondary_mirror": Rect2(94, 120, 118, 32), "central_baffle": Rect2(186, 220, 90, 32), "focuser": Rect2(274, 84, 110, 32), "eyepiece": Rect2(282, 46, 94, 30)}
		"gregorian": return {"reflector_tube": Rect2(80, 164, 172, 42), "primary_mirror": Rect2(280, 212, 96, 36), "optical_support": Rect2(94, 120, 118, 32), "secondary_mirror": Rect2(112, 210, 88, 34), "focuser": Rect2(274, 84, 110, 32), "eyepiece": Rect2(282, 46, 94, 30)}
	return {}


func _art_texture() -> Texture2D:
	var image := Image.load_from_file(ADVANCED_FAMILY_ATLAS)
	if image == null or image.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	match str(config.get("family", "")):
		"dobsonian": atlas.region = Rect2(0, 0, 626, 630)
		"cassegrain": atlas.region = Rect2(628, 0, 626, 630)
		"gregorian": atlas.region = Rect2(0, 632, 370, 622)
	return atlas


func _light_path_text() -> String:
	match str(config.get("family", "")):
		"cassegrain": return "-> PRIMARY -> SECONDARY -> BAFFLE ->"
		"gregorian": return "-> PRIMARY -> FIRST FOCUS -> SECONDARY ->"
		_: return "-> PRIMARY -> SECONDARY -> FOCUSER ->"


func _status_text() -> String:
	var missing := _missing_subparts()
	if missing.is_empty():
		return GameManager.text("All tube subparts are installed. Save this completed optical tube assembly.", "所有镜筒子零件均已安装。请保存这个完整的光学镜筒组件。")
	if not GameManager.assembly_hints_enabled():
		return GameManager.text("Hints off. Choose any uninstalled part and place it in its matching slot.", "提示已关闭。任选未安装零件，放入对应槽位即可。")
	return GameManager.text(
		"%d tube parts remain. Any matching part can be installed next." % missing.size(),
		"还剩 %d 个镜筒零件，可任选一个安装到对应槽位。" % missing.size()
	)

func _short_name(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _panel(pos: Vector2, size_value: Vector2, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 2))
	add_child(panel)
	panel.add_child(_label(title, Vector2(12, 8), Vector2(size_value.x - 24, 22), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	return panel


func _button(value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(color, GOLD, 2))
	button.add_theme_color_override("font_color", TEXT)
	return button


func _label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _label_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(value, pos, size_value, font_size, color, align)
	parent.add_child(label)
	return label


func _rect(pos: Vector2, size_value: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size_value
	rect.color = color
	add_child(rect)


func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
