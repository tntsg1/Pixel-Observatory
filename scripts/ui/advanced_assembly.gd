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
const NEWTONIAN_MAIN_BLUEPRINT := "res://assets/assembly/newtonian_main_blueprint.png"
const NEWTONIAN_MAIN_SOURCE_SIZE := Vector2(563.0, 612.0)
const NEWTONIAN_MAIN_SOURCE_CROP := Rect2(Vector2.ZERO, NEWTONIAN_MAIN_SOURCE_SIZE)
const NEWTONIAN_MAIN_SOURCE_SLOTS := {
	"optical_tube_assembly": Rect2(35.0, 227.0, 91.0, 105.0),
	"finder_scope": Rect2(350.0, 109.0, 82.0, 71.0),
	"mount": Rect2(444.0, 289.0, 83.0, 90.0),
	"tripod": Rect2(256.0, 479.0, 118.0, 83.0),
}
const DOBSONIAN_MAIN_BLUEPRINT := "res://assets/assembly/dobsonian_main_blueprint.png"
const DOBSONIAN_MAIN_SOURCE_SIZE := Vector2(746.0, 879.0)
# Source-pixel rects of the dashed boxes printed on the cropped board art,
# measured by cyan-pixel detection + overlay verification (never guessed).
const DOBSONIAN_MAIN_SOURCE_SLOTS := {
	"optical_tube_assembly": Rect2(340.0, 212.0, 112.0, 125.0),
	"finder_scope": Rect2(363.0, 52.0, 72.0, 66.0),
	"mount": Rect2(292.0, 560.0, 121.0, 132.0),
}
# Cassegrain main bench: the user's full-UI blueprint cropped to just the
# center board; slot rects measured on the crop + overlay-verified.
const CASSEGRAIN_MAIN_BLUEPRINT := "res://assets/assembly/cassegrain_main_blueprint_cropped.png"
const CASSEGRAIN_MAIN_SOURCE_SIZE := Vector2(694.0, 783.0)
const CASSEGRAIN_MAIN_SOURCE_SLOTS := {
	"finder_scope": Rect2(203.0, 14.0, 120.0, 86.0),
	"optical_tube_assembly": Rect2(283.0, 106.0, 252.0, 128.0),
	"mount": Rect2(195.0, 322.0, 108.0, 120.0),
	"tripod": Rect2(389.0, 624.0, 162.0, 150.0),
}
const SPACE_SEGMENTED_BLUEPRINT := "res://assets/assembly/space_segmented_blueprint_cropped.png"
const SPACE_SEGMENTED_SOURCE_SIZE := Vector2(758.0, 944.0)
const SPACE_SEGMENTED_SOURCE_SLOTS := {
	"secondary_mirror": Rect2(224.0, 74.0, 111.0, 104.0),
	"primary_mirror": Rect2(453.0, 215.0, 118.0, 111.0),
	"detector": Rect2(281.0, 462.0, 141.0, 113.0),
	"sunshield": Rect2(332.0, 611.0, 118.0, 106.0),
}
const SPACE_SEGMENTED_LABEL_RECTS := {
	"secondary_mirror": Rect2(8.0, 48.0, 124.0, 32.0),
	"primary_mirror": Rect2(306.0, 112.0, 116.0, 32.0),
	"detector": Rect2(292.0, 234.0, 126.0, 32.0),
	"sunshield": Rect2(8.0, 310.0, 124.0, 32.0),
}
const SPACE_CORE_TYPES := ["primary_mirror", "secondary_mirror", "detector", "sunshield"]
const SPACE_DEPLOYMENT_TYPES := [
	"spacecraft_bus",
	"deployable_tower",
	"deployment_hinges",
	"solar_array",
	"antenna",
	"radiator",
]
const SPACE_INSTRUMENT_TYPES := [
	"steering_mirror",
	"tertiary_mirror",
	"instrument_bay",
	"detector_module",
	"nircam",
	"nirspec",
	"miri",
	"fgs_niriss",
]
const FAST_BLUEPRINT_REFERENCE := "res://assets/assembly/fast_blueprint_reference.png"
const FAST_BLUEPRINT_CROPPED := "res://assets/assembly/fast_blueprint_center_cropped.png"
const FAST_BLUEPRINT_CONFIG := {
	"dish": {
		"path": FAST_BLUEPRINT_CROPPED,
		"source_size": Vector2(765.0, 956.0),
		"parts": ["radio_dish", "panel_segment", "panel_actuator"],
		"slots": {
			"radio_dish": Rect2(108.0, 132.0, 212.0, 98.0),
			"panel_segment": Rect2(28.0, 270.0, 168.0, 90.0),
			"panel_actuator": Rect2(224.0, 270.0, 168.0, 90.0),
		},
		"title_en": "Dish Surface",
		"title_zh": "反射面系统",
	},
	"feed": {
		"path": FAST_BLUEPRINT_CROPPED,
		"source_size": Vector2(765.0, 956.0),
		"parts": ["cable_system", "tension_controller", "receiver", "feed_receiver"],
		"slots": {
			"cable_system": Rect2(24.0, 58.0, 176.0, 90.0),
			"tension_controller": Rect2(220.0, 58.0, 176.0, 90.0),
			"receiver": Rect2(24.0, 180.0, 176.0, 90.0),
			"feed_receiver": Rect2(220.0, 180.0, 176.0, 90.0),
		},
		"title_en": "Suspended Feed",
		"title_zh": "悬吊馈源系统",
	},
	"signal": {
		"path": FAST_BLUEPRINT_CROPPED,
		"source_size": Vector2(765.0, 956.0),
		"parts": ["rf_receiver", "signal_processor", "spectrum_monitor", "timing_console", "data_recorder", "rfi_monitor", "control_terminal"],
		"slots": {
			"rf_receiver": Rect2(12.0, 46.0, 126.0, 88.0),
			"signal_processor": Rect2(148.0, 46.0, 126.0, 88.0),
			"spectrum_monitor": Rect2(284.0, 46.0, 126.0, 88.0),
			"timing_console": Rect2(12.0, 158.0, 126.0, 88.0),
			"data_recorder": Rect2(148.0, 158.0, 126.0, 88.0),
			"rfi_monitor": Rect2(284.0, 158.0, 126.0, 88.0),
			"control_terminal": Rect2(148.0, 270.0, 126.0, 88.0),
		},
		"title_en": "Signal Chain",
		"title_zh": "射电信号链",
	},
}
const FAST_SYSTEM_SOURCE_SLOTS := {
	"dish": Rect2(176.0, 374.0, 400.0, 194.0),
	"feed": Rect2(322.0, 99.0, 106.0, 108.0),
	"signal": Rect2(321.0, 722.0, 106.0, 104.0),
}

var selected_type := ""
var order: Array[String] = []
var status_label: Label
var flat_inspector_detail: Label
var blueprint: Control
var flat_parts_scroll: ScrollContainer
var template_parts_scroll: ScrollContainer
var template_parts_list: Control
var template_blueprint_layer: Control
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
var space_blueprint_page := "core"
var fast_blueprint_page := "overview"
var remembered_parts_scroll_y := 0


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)
	call_deferred("_show_assembly_tutorial")
	if GameManager.postgraduate_free_build() and bool(GameManager.get_meta(AUTO_CHAIN_TO_MAIN_META, false)):
		GameManager.remove_meta(AUTO_CHAIN_TO_MAIN_META)
		call_deferred("_run_auto_assemble")


func _show_assembly_tutorial() -> void:
	var target: Control = template_blueprint_layer if template_blueprint_layer != null else blueprint
	if _family() == "space_segmented":
		InteractionFeedback.tutorial_highlight_once(
			target,
			"first_space_system_assembly",
			GameManager.text(
				"Maya: This observatory has three systems. Install the light path, deployment hardware, and science instruments on their blueprint pages. Install Equipped Set completes the unlocked loadout for you.",
				"玛雅：这座天文台分成三套系统。请在“光路核心、展开与供电、科学仪器”三页蓝图中安装组件；“安装已装备组件”可以完成当前已解锁的整套配置。"
			),
			self
		)
		return
	InteractionFeedback.tutorial_highlight_once(target, "first_advanced_assembly", GameManager.text(
		"Select a real part card, then click its matching blueprint slot.",
		"先选择真实零件卡片，再点击蓝图中的对应槽位。"
	), self)


func _build() -> void:
	_remember_parts_scroll_position()
	for child in get_children():
		child.queue_free()
	flat_parts_scroll = null
	template_parts_scroll = null
	part_card_controls.clear()
	slot_controls.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if _family() in ["newtonian", "dobsonian", "cassegrain"]:
		_build_newtonian_template_main()
		_queue_parts_scroll_restore()
		return
	if _is_nested_ground_family():
		_build_nested_main()
		_queue_parts_scroll_restore()
		return
	order.clear()
	var install_order: Array = (
		GameManager.space_segmented_install_types()
		if _family() == "space_segmented"
		else _assembly_level().get("assembly_order", [])
	)
	for type_value in install_order:
		order.append(str(type_value))
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_label(_flat_bench_title(), Vector2(20, 14), Vector2(984, 32), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_add_type_selector()
	_label(_flat_bench_subtitle(), Vector2(20, 50), Vector2(984, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var tray := _panel(Vector2(20, 88), Vector2(278, 614), _flat_tray_title())
	var scroll := ScrollContainer.new()
	flat_parts_scroll = scroll
	scroll.position = Vector2(12, 42)
	scroll.size = Vector2(254, 558)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(236, 0)
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	for part_type in order:
		list.add_child(_part_card(part_type))

	var board_panel := _panel(Vector2(316, 88), Vector2(448, 614), _flat_board_title())
	blueprint = Control.new()
	blueprint.position = Vector2(10, 38)
	blueprint.size = Vector2(428, 500)
	blueprint.clip_contents = true
	board_panel.add_child(blueprint)
	_draw_specialized_blueprint()

	var inspector := _panel(Vector2(782, 88), Vector2(222, 614), GameManager.text("ASSEMBLY CHECK", "组装检查"))
	var level := _assembly_level()
	var mission_title := _label(
		GameManager.dict_text(level, "title"),
		Vector2(12, 38),
		Vector2(198, 42),
		13,
		TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	mission_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(mission_title)
	# Inspector detail: name + purpose + status of the SELECTED part.
	var detail_box := Panel.new()
	detail_box.position = Vector2(12, 84)
	detail_box.size = Vector2(198, 150)
	detail_box.add_theme_stylebox_override("panel", _style(Color(0.03, 0.05, 0.085, 0.9), Color(0.22, 0.34, 0.5), 1))
	inspector.add_child(detail_box)
	flat_inspector_detail = _label("", Vector2(10, 8), Vector2(178, 134), 12, TEXT)
	flat_inspector_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flat_inspector_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_box.add_child(flat_inspector_detail)
	status_label = Label.new()
	status_label.position = Vector2(14, 244)
	status_label.size = Vector2(194, 120)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	status_label.clip_text = false
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", TEXT)
	status_label.text = _status_text()
	inspector.add_child(status_label)
	_add_flat_auto_assemble_button(inspector)
	var finish := _button(GameManager.text("Finish Assembly", "完成组装"), Vector2(14, 500), Vector2(194, 42), Color(0.10, 0.30, 0.20))
	finish.pressed.connect(_finish)
	inspector.add_child(finish)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 550), Vector2(194, 34), Color(0.10, 0.14, 0.22))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	)
	inspector.add_child(back)
	_update_flat_inspector(selected_type)
	_queue_parts_scroll_restore()


func _active_parts_scroll() -> ScrollContainer:
	if is_instance_valid(template_parts_scroll):
		return template_parts_scroll
	if is_instance_valid(flat_parts_scroll):
		return flat_parts_scroll
	return null


func _remember_parts_scroll_position() -> void:
	var scroll := _active_parts_scroll()
	if scroll != null:
		remembered_parts_scroll_y = scroll.scroll_vertical


func _queue_parts_scroll_restore() -> void:
	call_deferred("_restore_parts_scroll_position")


func _restore_parts_scroll_position() -> void:
	# ScrollContainer calculates its range during layout. Waiting one frame
	# prevents a rebuilt list from clamping the remembered value back to zero.
	await get_tree().process_frame
	var scroll := _active_parts_scroll()
	if scroll == null:
		return
	var bar := scroll.get_v_scroll_bar()
	var maximum := maxi(0, floori(bar.max_value - bar.page))
	scroll.scroll_vertical = clampi(remembered_parts_scroll_y, 0, maximum)


func _is_nested_ground_family() -> bool:
	return _family() in ["newtonian", "dobsonian", "cassegrain", "gregorian"]


func _build_nested_main() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_label(GameManager.text("ADVANCED TELESCOPE MAIN ASSEMBLY", "高级望远镜主组装台"), Vector2(20, 14), Vector2(984, 32), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_add_type_selector()
	_label(GameManager.text("Build the support system here. Assemble every mirror and optical part inside the Optical Tube Assembly.", "此处组装支撑系统。所有镜面和光学零件请在光学镜筒组件中完成。"), Vector2(30, 50), Vector2(964, 22), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	var tray := _panel(Vector2(20, 88), Vector2(278, 614), GameManager.text("MAIN COMPONENTS", "主组件"))
	var list := VBoxContainer.new()
	list.position = Vector2(16, 48)
	list.size = Vector2(246, 310)
	list.add_theme_constant_override("separation", 8)
	tray.add_child(list)
	var tray_order: Array[String] = ["tripod", "mount"]
	for subpart_value in GameManager.tube_subassembly_config().get("order", []):
		tray_order.append(str(subpart_value))
	for part_type in tray_order:
		list.add_child(_main_part_card(part_type))

	var board := _panel(Vector2(316, 88), Vector2(448, 614), GameManager.text("MAIN BLUEPRINT", "主装配蓝图"))
	blueprint = Control.new()
	blueprint.position = Vector2(10, 38)
	blueprint.size = Vector2(428, 500)
	board.add_child(blueprint)
	_draw_main_blueprint()

	var inspector := _panel(Vector2(782, 88), Vector2(222, 614), GameManager.text("ASSEMBLY CHECK", "组装检查"))
	status_label = _label(_main_status_text(), Vector2(14, 50), Vector2(194, 196), 12, TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector.add_child(status_label)
	var finish := _button(GameManager.text("Finish Main Assembly", "完成主组装"), Vector2(14, 500), Vector2(194, 42), Color(0.10, 0.30, 0.20))
	finish.pressed.connect(_finish)
	inspector.add_child(finish)
	_add_flat_auto_assemble_button(inspector)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 550), Vector2(194, 34), Color(0.10, 0.14, 0.22))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("assembly"); GameManager.go("observatory"))
	inspector.add_child(back)


func _build_newtonian_template_main() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.006, 0.009, 0.018))
	AssemblyUITemplate.add_title_bar(
		self,
		GameManager.text("Telescope Assembly", "望远镜组装台"),
		GameManager.text("Pick a part, then click its blueprint slot.", "选择零件，再点击蓝图安装位。")
	)
	_add_type_selector()
	AssemblyUITemplate.add_titled_panel(self, AssemblyUITemplate.LEFT_PANEL_RECT, GameManager.text("Parts Tray", "零件托盘"))
	AssemblyUITemplate.add_blueprint_panel(self, GameManager.text("Blueprint", "蓝图"))

	template_parts_scroll = ScrollContainer.new()
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
	for part_type in _main_parts():
		_add_newtonian_main_card(part_type, Vector2(0, y))
		y += AssemblyUITemplate.PART_CARD_STEP
	template_parts_list.custom_minimum_size.y = maxf(560.0, y)
	template_parts_list.size = template_parts_list.custom_minimum_size

	template_blueprint_layer = Control.new()
	template_blueprint_layer.position = Vector2(334, 112)
	template_blueprint_layer.size = Vector2(424, 512)
	add_child(template_blueprint_layer)
	var config := _main_blueprint_config()
	var source_size: Vector2 = config["size"]
	var slots: Dictionary = config["slots"]
	var layout := _calculate_blueprint_layout(source_size, Rect2(Vector2.ZERO, source_size), Rect2(Vector2.ZERO, template_blueprint_layer.size))
	var blueprint_image := TextureRect.new()
	blueprint_image.custom_minimum_size = Vector2.ZERO
	blueprint_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blueprint_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	blueprint_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blueprint_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint_image.texture = load(str(config["path"])) as Texture2D
	blueprint_image.position = layout["display_rect"].position
	blueprint_image.size = layout["display_rect"].size
	template_blueprint_layer.add_child(blueprint_image)
	for part_type in slots.keys():
		var slot_rect := _source_rect_to_blueprint(slots[part_type], layout)
		_newtonian_reference_slot(template_blueprint_layer, str(part_type), slot_rect)

	var helper := _label(GameManager.text("Select a card, then click the matching slot.", "选择零件卡，再点击对应安装位。"), Vector2(346, 632), Vector2(408, 28), 12, Color(0.72, 0.82, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(helper)
	var order_hint := GameManager.text("Tripod -> Mount -> Tube Assembly -> Finder", "三脚架 -> 支架 -> 镜筒组件 -> 寻星镜")
	if _family() == "dobsonian":
		order_hint = GameManager.text("Rocker Mount -> Tube Assembly -> Finder", "摇箱底座 -> 镜筒组件 -> 寻星镜")
	var order_text := _label(order_hint, Vector2(346, 664), Vector2(408, 22), 11, Color(0.56, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	add_child(order_text)

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
		_reset_newtonian_main,
		back_callback
	)
	template_inspector_title = shell["status"]
	template_feedback = shell["feedback"]
	template_stats = shell["stats"]
	template_ready_dot = shell["ready_dot"]
	template_finish = shell["finish"]
	status_label = template_feedback
	_add_template_auto_assemble_button()
	AssemblyUITemplate.add_hints_toggle(self, GameManager, _build)
	_refresh_newtonian_main_inspector()


func _add_type_selector() -> void:
	var button := _button(GameManager.text("Type: ", "类型：") + _family_display_name(), Vector2(24, 18), Vector2(180, 30), Color(0.08, 0.12, 0.20))
	button.name = "TelescopeTypeButton"
	button.add_theme_font_size_override("font_size", 11)
	button.tooltip_text = GameManager.text("Choose another unlocked telescope family", "选择其他已解锁的望远镜类型")
	button.pressed.connect(func() -> void:
		GameManager.set_meta("telescope_types_browse", false)
		GameManager.set_meta("telescope_types_return_scene", "advanced_assembly")
		GameManager.go("telescope_types")
	)
	add_child(button)


func _family_display_name() -> String:
	match _family():
		"newtonian": return GameManager.text("Newtonian", "牛顿反射式")
		"dobsonian": return GameManager.text("Dobsonian", "多布森")
		"cassegrain": return GameManager.text("Cassegrain", "卡塞格林")
		"gregorian": return GameManager.text("Gregorian", "格里高利")
		"space_segmented": return GameManager.text("Infrared", "红外")
		"fast_radio": return GameManager.text("FAST Radio", "FAST 射电")
	return GameManager.text("Refractor", "折射式")


func _add_newtonian_main_card(part_type: String, position: Vector2) -> void:
	var part := _main_template_part(part_type)
	var installed := _installed(part_type)
	var status_text := GameManager.text("Installed", "已安装") if installed else GameManager.text("Not Installed", "未安装")
	if part_type == "optical_tube_assembly":
		# Three card states: internals not built yet / built but not mounted /
		# mounted. The tube stays reopenable in every state (never one-shot).
		var built := GameManager.advanced_tube_completed()
		if installed:
			status_text = GameManager.text("Installed · click to edit", "已安装 · 点击可编辑")
		elif built:
			status_text = GameManager.text("Built · install on mount", "已组装 · 待装上支架")
		else:
			status_text = GameManager.text("%d/%d subparts · click to open", "%d/%d 子零件 · 点击打开") % [_tube_installed_count(), _tube_total_count()]
	var selected := selected_type == part_type
	var texture_path := str(part.get("icon_path", ""))
	var texture := load(texture_path) as Texture2D if texture_path != "" and ResourceLoader.exists(texture_path) else null
	var card := AssemblyUITemplate.add_part_card(
		template_parts_list,
		position,
		GameManager.dict_text(part, "name"),
		_main_part_role(part_type),
		status_text,
		texture,
		installed,
		selected,
		_select_newtonian_main_part.bind(part_type)
	)
	part_card_controls[part_type] = card


func _tube_installed_count() -> int:
	var state: Dictionary = GameManager.tube_assembly()
	var subparts: Dictionary = state.get("installed_subparts", state.get("tube_assembly_state", {}))
	var count := 0
	for key in subparts.keys():
		if bool(subparts[key]):
			count += 1
	return count


func _tube_total_count() -> int:
	return GameManager.tube_subassembly_config().get("order", []).size()


func _can_open_tube() -> bool:
	# Advanced benches expose the tube workspace immediately; completeness is
	# checked only when the player saves the assembled telescope.
	return true

func _open_tube_or_hint() -> void:
	if not _can_open_tube():
		if _family() == "dobsonian":
			status_label.text = GameManager.text(
				"Install the Rocker Mount first.",
				"请先安装摇箱底座。"
			)
		else:
			status_label.text = GameManager.text(
				"Install the external components first: Tripod, then Mount.",
				"请先安装外部组件：先三脚架，再支架。"
			)
		return
	if GameManager.try_story_mechanic("tube_subassembly", "optical_tube_assembly"):
		return
	GameManager.go("optical_tube_assembly")


func _main_blueprint_config() -> Dictionary:
	if _family() == "dobsonian":
		return {"path": DOBSONIAN_MAIN_BLUEPRINT, "size": DOBSONIAN_MAIN_SOURCE_SIZE, "slots": DOBSONIAN_MAIN_SOURCE_SLOTS}
	if _family() == "cassegrain":
		return {"path": CASSEGRAIN_MAIN_BLUEPRINT, "size": CASSEGRAIN_MAIN_SOURCE_SIZE, "slots": CASSEGRAIN_MAIN_SOURCE_SLOTS}
	return {"path": NEWTONIAN_MAIN_BLUEPRINT, "size": NEWTONIAN_MAIN_SOURCE_SIZE, "slots": NEWTONIAN_MAIN_SOURCE_SLOTS}


func _main_template_part(part_type: String) -> Dictionary:
	# The main bench reuses formal part sprites. Its optical tube is the
	# completed subassembly.
	match part_type:
		"tripod":
			return GameManager.get_part("basic_tripod")
		"mount":
			if _family() == "cassegrain":
				return GameManager.get_part("cassegrain_fork_mount")
			if _family() == "dobsonian":
				return GameManager.get_part("dobsonian_rocker_mount")
			# Newtonian mounts are a free slot now (upgrades like the
			# Tracking Mount are legal): show whatever is equipped.
			var equipped_mount := GameManager.get_part(GameManager.equipped_part_id("mount"))
			if not equipped_mount.is_empty() and str(equipped_mount.get("telescope_family", "")) in ["", _family()]:
				return equipped_mount
			return _part_for_type(part_type)
		"finder_scope":
			return GameManager.get_part("basic_finder_scope")
	if part_type == "optical_tube_assembly":
		if _family() == "cassegrain":
			return {
				"id": "cassegrain_optical_tube_assembly",
				"name_en": "Cassegrain Optical Tube Assembly",
				"name_zh": "卡塞格林光学镜筒组件",
				"description_en": "The completed folded-path tube: primary, convex secondary, baffle, rear focuser and eyepiece.",
				"description_zh": "完成的折叠光路镜筒：主镜、凸面副镜、挡板、后端调焦座和目镜。",
				"icon_path": "res://assets/telescope_parts/cassegrain/cassegrain_compact_tube.png",
			}
		if _family() == "dobsonian":
			return {
				"id": "dobsonian_optical_tube_assembly",
				"name_en": "Dobsonian Optical Tube Assembly",
				"name_zh": "多布森光学镜筒组件",
				"description_en": "A completed mirror, focuser, and eyepiece subassembly.",
				"description_zh": "由反射镜、调焦器和目镜组成的完整镜筒组件。",
				"icon_path": "res://assets/telescope_parts/dobsonian/dobsonian_reflector_tube.png",
			}
		return {
			"id": "newtonian_optical_tube_assembly",
			"name_en": "Newtonian Optical Tube Assembly",
			"name_zh": "牛顿光学镜筒组件",
			"description_en": "A completed mirror, focuser, and eyepiece subassembly.",
			"description_zh": "由反射镜、调焦器和目镜组成的完整镜筒组件。",
			"icon_path": "res://assets/telescope_parts/newtonian/newtonian_tube_complete.png",
		}
	return _part_for_type(part_type)


func _main_part_role(part_type: String) -> String:
	match part_type:
		"tripod": return GameManager.text("Base support", "底部支撑")
		"mount":
			if _family() == "dobsonian":
				return GameManager.text("Rocker box support", "摇箱支撑")
			return GameManager.text("Equatorial support", "赤道仪支撑")
		"optical_tube_assembly": return GameManager.text("Completed optical path", "完整光学组件")
		"finder_scope": return GameManager.text("Wide-field aiming", "宽视场寻星")
	return ""


func _select_newtonian_main_part(part_type: String) -> void:
	selected_type = part_type
	_build()


func _reset_newtonian_main() -> void:
	GameManager.reset_assembly()
	selected_type = ""
	_build()


func _refresh_newtonian_main_inspector() -> void:
	# Three honest states (never a hardcoded READY): missing parts ->
	# ASSEMBLING; everything mounted but collimation pending -> NEEDS
	# COLLIMATION; all conditions met -> READY.
	var parts_ready := GameManager.telescope_is_ready()
	var needs_collimation := bool(_assembly_level().get("requires_collimation", false)) \
		and not GameManager.collimation_is_acceptable()
	if not parts_ready:
		template_inspector_title.text = GameManager.text("ASSEMBLING", "组装中")
		template_inspector_title.add_theme_color_override("font_color", GOLD)
		_set_template_ready_dot(GOLD)
		template_finish.text = GameManager.text("Finish Assembly", "完成组装")
		template_finish.disabled = true
	elif needs_collimation:
		template_inspector_title.text = GameManager.text("COLLIMATE", "需要准直")
		template_inspector_title.add_theme_color_override("font_color", Color(0.95, 0.62, 0.30))
		_set_template_ready_dot(Color(0.95, 0.62, 0.30))
		template_finish.text = GameManager.text("Collimate Mirrors", "准直镜面")
		template_finish.disabled = false
	else:
		template_inspector_title.text = GameManager.text("READY", "已就绪")
		template_inspector_title.add_theme_color_override("font_color", GREEN)
		_set_template_ready_dot(GREEN)
		template_finish.text = GameManager.text("Finish Assembly", "完成组装")
		template_finish.disabled = false
	if selected_type != "":
		var part := _main_template_part(selected_type)
		var extra := GameManager.text("Click the matching blueprint slot.", "请点击对应蓝图安装位。")
		if selected_type == "optical_tube_assembly":
			extra = GameManager.text("Use the button below to open it.", "用下方按钮打开镜筒内部。")
		template_feedback.text = GameManager.dict_text(part, "name") + "\n" + extra
	else:
		template_feedback.text = _main_status_text()
	_clear_control(template_stats)
	var stats := GameManager.calculate_stats()
	var tube_state := GameManager.tube_assembly()
	var rows := [
		[GameManager.text("STABILITY", "稳定性"), float(stats.get("stability_score", 0.0)) / 100.0],
		[GameManager.text("OPTICS", "光学"), float(tube_state.get("subassembly_score", 0.0)) / 100.0],
		[GameManager.text("ALIGNMENT", "对齐"), GameManager.collimation_score() / 100.0],
		[GameManager.text("ASSEMBLY", "组装"), float(stats.get("assembly_score", 0.0)) / 100.0],
	]
	for index in range(rows.size()):
		_add_template_stat(template_stats, str(rows[index][0]), float(rows[index][1]), float(index) * 50.0)
	# Prominent, always-available tube entrance (item: the player must never
	# have to guess how to get back inside the optical tube).
	var tube_button := Button.new()
	var built := GameManager.advanced_tube_completed()
	tube_button.text = GameManager.text("Edit Optical Tube", "编辑光学镜筒") if built else GameManager.text("Open Optical Tube", "打开光学镜筒")
	tube_button.position = Vector2(0, 206)
	tube_button.size = Vector2(200, 42)
	tube_button.add_theme_font_size_override("font_size", 13)
	tube_button.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	var tube_style := StyleBoxFlat.new()
	tube_style.bg_color = Color(0.05, 0.14, 0.22)
	tube_style.border_color = CYAN
	tube_style.set_border_width_all(2)
	tube_style.set_corner_radius_all(5)
	var tube_hover := tube_style.duplicate()
	tube_hover.bg_color = Color(0.09, 0.20, 0.30)
	tube_button.add_theme_stylebox_override("normal", tube_style)
	tube_button.add_theme_stylebox_override("hover", tube_hover)
	tube_button.add_theme_stylebox_override("pressed", tube_style)
	tube_button.pressed.connect(_open_tube_or_hint)
	template_stats.add_child(tube_button)


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


func _build_newtonian_reference_main() -> void:
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	add_child(_label(GameManager.text("NEWTONIAN REFLECTOR MAIN ASSEMBLY", "牛顿反射式望远镜主组装"), Vector2(20, 14), Vector2(984, 30), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_label(GameManager.text("Install the external support here. Open the Optical Tube Assembly to build the internal reflector path.", "此处安装外部支撑。打开光学镜筒组件，完成内部反射光路。"), Vector2(24, 46), Vector2(976, 26), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	var tray := _panel(Vector2(20, 88), Vector2(278, 614), GameManager.text("PARTS TRAY", "零件托盘"))
	var scroll := ScrollContainer.new()
	flat_parts_scroll = scroll
	scroll.position = Vector2(12, 42)
	scroll.size = Vector2(254, 558)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tray.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(236, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	# Only external components belong on the main bench. Internal optical
	# components exist exclusively in the Optical Tube sub-blueprint.
	var tray_order: Array[String] = ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	for part_type in tray_order:
		list.add_child(_main_part_card(part_type))
	var center := _panel(Vector2(316, 88), Vector2(448, 614), GameManager.text("BLUEPRINT", "蓝图"))
	var blueprint_visual := Control.new()
	blueprint_visual.position = Vector2(10, 72)
	blueprint_visual.size = Vector2(428, 466)
	center.add_child(blueprint_visual)
	var layout := _calculate_blueprint_layout(NEWTONIAN_MAIN_SOURCE_SIZE, NEWTONIAN_MAIN_SOURCE_CROP, Rect2(Vector2.ZERO, blueprint_visual.size))
	var reference := TextureRect.new()
	reference.custom_minimum_size = Vector2.ZERO
	reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reference.texture = load(NEWTONIAN_MAIN_BLUEPRINT) as Texture2D
	reference.position = layout["display_rect"].position
	reference.size = layout["display_rect"].size
	blueprint_visual.add_child(reference)
	for part_type in NEWTONIAN_MAIN_SOURCE_SLOTS.keys():
		var local_rect := _source_rect_to_blueprint(NEWTONIAN_MAIN_SOURCE_SLOTS[part_type], layout)
		_newtonian_reference_slot(blueprint_visual, str(part_type), local_rect)
	var inspector := Panel.new()
	inspector.position = Vector2(770, 209)
	inspector.size = Vector2(216, 390)
	inspector.add_theme_stylebox_override("panel", _style(Color(0.025, 0.05, 0.08, 0.93), GOLD, 2))
	add_child(inspector)
	var hardware_ready := GameManager.telescope_is_ready()
	var needs_collimation := hardware_ready and bool(_assembly_level().get("requires_collimation", false)) and not GameManager.collimation_is_acceptable()
	var ready := hardware_ready and not needs_collimation
	var status := GameManager.text("READY", "已就绪") if ready else (GameManager.text("NEEDS COLLIMATION", "需要准直") if needs_collimation else GameManager.text("NOT READY", "未就绪"))
	inspector.add_child(_label(status, Vector2(10, 18), Vector2(196, 34), 20, GREEN if ready else (GOLD if needs_collimation else RED), HORIZONTAL_ALIGNMENT_CENTER))
	var tube_state := GameManager.tube_assembly()
	var sub_score := float(tube_state.get("subassembly_score", 0.0))
	inspector.add_child(_label(GameManager.text("Stability: %d" % roundi(GameManager.calculate_stats().get("stability_score", 0.0)), "稳定性：%d" % roundi(GameManager.calculate_stats().get("stability_score", 0.0))), Vector2(14, 76), Vector2(188, 22), 12, CYAN))
	inspector.add_child(_label(GameManager.text("Optics: %d" % roundi(sub_score), "光学：%d" % roundi(sub_score)), Vector2(14, 108), Vector2(188, 22), 12, CYAN))
	inspector.add_child(_label(GameManager.text("Collimation: %d%%" % roundi(GameManager.collimation_score()), "准直：%d%%" % roundi(GameManager.collimation_score())), Vector2(14, 140), Vector2(188, 22), 12, CYAN))
	var primary := _part_for_type("primary_mirror")
	var aperture := float(primary.get("aperture_mm", 0.0))
	var focal_length := float(primary.get("focal_length_mm", 0.0))
	var focal_ratio := focal_length / aperture if aperture > 0.0 else 0.0
	inspector.add_child(_label(GameManager.text("Aperture: %d mm" % roundi(aperture), "口径：%d mm" % roundi(aperture)), Vector2(14, 166), Vector2(188, 20), 11, CYAN))
	inspector.add_child(_label(GameManager.text("Focal: %d mm" % roundi(focal_length), "焦距：%d mm" % roundi(focal_length)), Vector2(14, 186), Vector2(188, 20), 11, CYAN))
	inspector.add_child(_label(GameManager.text("F-ratio: f/%.1f" % focal_ratio, "焦比：f/%.1f" % focal_ratio), Vector2(14, 206), Vector2(188, 20), 11, CYAN))
	# Built by hand (not the shared _label() helper) because property ORDER
	# matters here: Control.size always clamps up to the current minimum
	# size, and a Label's minimum size is computed from its shaped text
	# under whatever autowrap_mode was active AT SHAPING TIME. _label()
	# sets .text before autowrap is ever touched, so the first shape pass
	# happens unwrapped at natural (huge) width, permanently baking that
	# width in as the minimum - later setting autowrap_mode or reassigning
	# .size can't shrink it back down. Setting autowrap BEFORE .text avoids
	# that trap entirely.
	status_label = Label.new()
	status_label.position = Vector2(14, 234)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = _main_status_text()
	status_label.size = Vector2(188, 62)
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", TEXT)
	inspector.add_child(status_label)
	var finish_text := GameManager.text("Collimate Mirrors", "准直镜面") if needs_collimation else GameManager.text("Finish Assembly", "完成组装")
	var finish := _button(finish_text, Vector2(14, 306), Vector2(188, 42), Color(0.28, 0.20, 0.06) if needs_collimation else Color(0.10, 0.30, 0.20))
	# Hardware completion unlocks this button. When collimation is pending,
	# _finish() routes into the collimation lesson instead of deadlocking behind
	# a disabled control.
	finish.disabled = not hardware_ready
	finish.pressed.connect(_finish)
	inspector.add_child(finish)
	var back := _button(GameManager.text("Back", "返回"), Vector2(14, 352), Vector2(188, 28), Color(0.10, 0.14, 0.22))
	back.pressed.connect(func() -> void: GameManager.set_observatory_spawn("assembly"); GameManager.go("observatory"))
	inspector.add_child(back)


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


func debug_newtonian_main_slot_geometry() -> Dictionary:
	var result := {}
	if template_blueprint_layer == null:
		return result
	var config := _main_blueprint_config()
	var source_size: Vector2 = config["size"]
	var slots: Dictionary = config["slots"]
	var layout := _calculate_blueprint_layout(
		source_size,
		Rect2(Vector2.ZERO, source_size),
		Rect2(Vector2.ZERO, template_blueprint_layer.size)
	)
	for part_type_value in slots.keys():
		var part_type := str(part_type_value)
		var source_rect: Rect2 = slots[part_type]
		var local_rect := _source_rect_to_blueprint(source_rect, layout)
		var slot := template_blueprint_layer.find_child("MainSlot_%s" % part_type, true, false) as Control
		var texture := template_blueprint_layer.find_child("MainTexture_%s" % part_type, true, false) as TextureRect
		result[part_type] = {
			"source_rect": source_rect,
			"blueprint_local_rect": local_rect,
			"screen_rect": _blueprint_rect_to_screen(template_blueprint_layer, local_rect),
			"installed_texture_rect": Rect2(slot.position + texture.position, texture.size) if slot != null and texture != null else Rect2(),
		}
	return result


func _newtonian_reference_slot(parent: Control, part_type: String, rect: Rect2) -> void:
	# The printed blueprint already carries this slot's dashed box AND its
	# label (e.g. "SECONDARY SPIDER") baked into the 730x730 art - drawing a
	# second text label or a permanent colored rectangle here would both
	# duplicate it and read as a debug overlay. So idle slots get NO visual
	# chrome at all (just an invisible click target); the only state chrome
	# is a gold border on the currently selected slot, and a small green
	# check badge once installed.
	var installed := _installed(part_type)
	if part_type == "optical_tube_assembly":
		installed = bool(GameManager.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false))
	var selected := selected_type == part_type
	var slot := Control.new()
	slot.name = "MainSlot_%s" % part_type
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(slot)
	slot_controls[part_type] = slot

	# Layer order: installed PNG, state frame, OK badge, click target.
	if installed:
		var part := _main_template_part(part_type)
		var icon_path := str(part.get("icon_path", ""))
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var loaded_texture := load(icon_path) as Texture2D
			if loaded_texture != null:
				var installed_texture := TextureRect.new()
				installed_texture.name = "MainTexture_%s" % part_type
				installed_texture.custom_minimum_size = Vector2.ZERO
				installed_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				installed_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				installed_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				installed_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
				installed_texture.texture = _trim_transparent_texture(loaded_texture)
				installed_texture.position = Vector2.ZERO
				installed_texture.size = rect.size
				installed_texture.modulate = Color.WHITE
				slot.add_child(installed_texture)

	if selected and not installed:
		var border := Panel.new()
		border.position = Vector2.ZERO
		border.size = rect.size
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = GOLD
		style.set_border_width_all(2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		border.add_theme_stylebox_override("panel", style)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(border)
	elif installed:
		var completion_frame := Panel.new()
		completion_frame.name = "MainFrame_%s" % part_type
		completion_frame.position = Vector2.ZERO
		completion_frame.size = rect.size
		var completion_style := StyleBoxFlat.new()
		completion_style.bg_color = Color(0, 0, 0, 0)
		completion_style.border_color = GREEN
		completion_style.set_border_width_all(2)
		completion_style.set_corner_radius_all(4)
		completion_frame.add_theme_stylebox_override("panel", completion_style)
		completion_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(completion_frame)

		var badge_size := 20.0
		var badge_pos := Vector2(maxf(0.0, rect.size.x - badge_size), 0.0)
		var backdrop := Panel.new()
		backdrop.position = badge_pos
		backdrop.size = Vector2(badge_size, badge_size)
		var backdrop_style := StyleBoxFlat.new()
		backdrop_style.bg_color = Color(0.04, 0.10, 0.06, 0.92)
		backdrop_style.border_color = GREEN
		backdrop_style.set_border_width_all(2)
		backdrop_style.corner_radius_top_left = 10
		backdrop_style.corner_radius_top_right = 10
		backdrop_style.corner_radius_bottom_left = 10
		backdrop_style.corner_radius_bottom_right = 10
		backdrop.add_theme_stylebox_override("panel", backdrop_style)
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(backdrop)
		var badge := _label("✓", badge_pos, Vector2(badge_size, badge_size), 14, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)

	AssemblyUITemplate.add_slot_hit_target(slot, Rect2(Vector2.ZERO, rect.size), func() -> void:
		if part_type == "optical_tube_assembly":
			# The tube slot doubles as the sub-bench entrance and it NEVER
			# locks: not built -> open to build; built + selected -> install
			# on the mount; installed -> open again to view/edit.
			var built := GameManager.advanced_tube_completed()
			if installed:
				_open_tube_or_hint()
				return
			if not built:
				_open_tube_or_hint()
				return
			if selected_type == part_type:
				_install_main_part(part_type)
			else:
				status_label.text = GameManager.text(
					"Tube is built. Select its card, then click here to mount it - or click again to edit it.",
					"镜筒已组装。选中它的卡片后点此安装到支架；再次点击可继续编辑内部。"
				)
			return
		if selected_type == "":
			status_label.text = GameManager.text("Select a part card from the left first.", "请先从左侧选择零件卡。")
			return
		if selected_type != part_type:
			status_label.text = GameManager.text("Wrong slot. Select the matching blueprint position.", "安装位不正确，请点击与所选零件对应的蓝图位置。")
			return
		_install_main_part(part_type)
	)


func _trim_transparent_texture(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null or image.is_empty():
		return texture
	var used_rect := image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return texture
	if used_rect.position == Vector2i.ZERO and used_rect.size == image.get_size():
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(used_rect)
	return atlas


func _main_parts() -> Array[String]:
	if _family() == "newtonian":
		return ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	if _family() == "cassegrain":
		# Four EXTERNAL components only; the 8 internal parts live in the tube.
		return ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	if _family() == "dobsonian":
		return ["mount", "optical_tube_assembly", "finder_scope"]
	return ["tripod", "mount", "optical_tube_assembly"]


func _main_part_card(part_type: String) -> Control:
	var is_tube_subpart := _is_newtonian_tube_subpart(part_type)
	var completed := GameManager.advanced_tube_completed() if part_type == "optical_tube_assembly" else (_subpart_installed(part_type) if is_tube_subpart else _installed(part_type))
	var card := Panel.new()
	card.custom_minimum_size = Vector2(246, 62)
	card.add_theme_stylebox_override("panel", _style(Color(0.075, 0.10, 0.15), GREEN if completed else Color(0.25, 0.43, 0.66), 2))
	var title_text := GameManager.text("Optical Tube Assembly", "光学镜筒组件") if part_type == "optical_tube_assembly" else GameManager.dict_text(_part_for_type(part_type), "name")
	var title := _label(title_text, Vector2(9, 5), Vector2(172, 22), 12, TEXT)
	title.clip_text = true
	card.add_child(title)
	var status := GameManager.text("Installed", "已安装") if completed else (GameManager.text("Open tube blueprint", "进入镜筒子蓝图") if part_type == "optical_tube_assembly" or is_tube_subpart else GameManager.text("Select", "选择"))
	card.add_child(_label(status, Vector2(9, 32), Vector2(132, 18), 10, GREEN if completed else CYAN))
	var use := Button.new()
	use.text = GameManager.text("Open", "打开") if (part_type == "optical_tube_assembly" or is_tube_subpart) and not completed else GameManager.text("Use", "使用")
	use.position = Vector2(186, 13)
	use.size = Vector2(50, 34)
	use.add_theme_font_size_override("font_size", 10)
	use.pressed.connect(func() -> void:
		if (part_type == "optical_tube_assembly" or is_tube_subpart) and not GameManager.advanced_tube_completed():
			GameManager.go("optical_tube_assembly")
			return
		selected_type = part_type
		status_label.text = GameManager.text("Selected " + title_text + ". Click its marked main slot.", "已选择" + title_text + "。请点击对应主装配槽位。")
		if _family() == "newtonian":
			_build()
		else:
			_draw_main_blueprint()
	)
	card.add_child(use)
	return card


func _is_newtonian_tube_subpart(part_type: String) -> bool:
	return _family() == "newtonian" and part_type in ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"]


func _subpart_installed(part_type: String) -> bool:
	var state := GameManager.tube_assembly()
	var subparts: Dictionary = state.get("installed_subparts", state.get("tube_assembly_state", {}))
	return bool(subparts.get(part_type, false))


func _draw_main_blueprint() -> void:
	for child in blueprint.get_children():
		child.queue_free()
	var art := TextureRect.new()
	art.texture = _main_family_art_texture()
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.position = Vector2(32, 38)
	art.size = Vector2(364, 300)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint.add_child(art)
	var placements := {"tripod": Rect2(166, 378, 100, 60), "mount": Rect2(148, 308, 140, 54), "optical_tube_assembly": Rect2(78, 154, 272, 82)}
	for part_type in _main_parts():
		_draw_main_slot(part_type, placements.get(part_type, Rect2(150, 300, 120, 48)))


func _draw_main_slot(part_type: String, rect: Rect2) -> void:
	var tube_completed := GameManager.advanced_tube_completed()
	var installed_main := _installed(part_type)
	if part_type == "optical_tube_assembly":
		installed_main = bool(GameManager.progress.get("assembly_state", {}).get(part_type, {}).get("installed", false))
	var active := selected_type == part_type
	var color := GREEN if installed_main else (GOLD if active or (part_type == "optical_tube_assembly" and not tube_completed) else Color(0.35, 0.66, 0.90))
	var slot := Panel.new()
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	slot.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.13, 0.78), color, 2))
	blueprint.add_child(slot)
	var label_text := ""
	var main_part := _part_for_type(part_type) if part_type != "optical_tube_assembly" else {}
	if not main_part.is_empty():
		var main_icon := _part_texture_control(main_part, Rect2(5, 4, rect.size.x - 10, rect.size.y - 8))
		if main_icon != null:
			slot.add_child(main_icon)
	if part_type == "optical_tube_assembly":
		label_text = GameManager.text("Optical Tube Assembly complete" if tube_completed else "Optical Tube Assembly\nClick to open sub-blueprint", "光学镜筒组件已完成" if tube_completed else "光学镜筒组件\n点击进入子蓝图")
	else:
		label_text = GameManager.dict_text(_part_for_type(part_type), "name") if installed_main else _short_type(part_type)
	var label := _label(label_text, Vector2(4, 4), rect.size - Vector2(8, 8), 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot.add_child(label)
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.pressed.connect(func() -> void:
		if part_type == "optical_tube_assembly" and not tube_completed:
			GameManager.go("optical_tube_assembly")
			return
		_install_main_part(part_type)
	)
	slot.add_child(hit)


func _install_main_part(part_type: String) -> void:
	if install_animation_active:
		return
	if _installed(part_type):
		status_label.text = GameManager.text("This main component is already installed.", "该主组件已经安装。")
		return
	if selected_type != part_type:
		status_label.text = GameManager.text("Select this main component from the left first.", "请先从左侧选择该主组件。")
		return
	if part_type == "optical_tube_assembly" and not GameManager.advanced_tube_completed():
		status_label.text = GameManager.text("Complete the Optical Tube Assembly first.", "请先完成光学镜筒组件。")
		return
	install_animation_active = true
	var animation := _capture_part_animation(part_type)
	var selected_part := _main_template_part(part_type)
	var selected_part_id := str(selected_part.get("id", ""))
	if GameManager.install_part(part_type, 0, selected_part_id) < 0:
		install_animation_active = false
		status_label.text = GameManager.install_part_block_reason(part_type)
		return
	GameManager.sync_newtonian_installed_equipment()
	selected_type = ""
	install_animation_active = false
	_build()
	_play_part_animation(animation)
	call_deferred("_finish_advanced_install_feedback", part_type, true)


func _main_status_text() -> String:
	if not GameManager.advanced_tube_completed():
		return GameManager.text("The mirror system is not assembled yet. Open Optical Tube Assembly and build the internal light path first.", "镜面系统尚未组装。请打开光学镜筒组件，先完成内部光路。")
	var missing: Array = GameManager.missing_parts()
	if not missing.is_empty():
		return GameManager.text("Install the remaining main components: " + ", ".join(missing) + ".", "请安装剩余主组件：" + ", ".join(missing) + "。")
	if bool(_assembly_level().get("requires_collimation", false)) and not GameManager.collimation_is_acceptable():
		var threshold := int(_assembly_level().get("collimation_threshold", 80))
		return GameManager.text(
			"Hardware complete. Click Collimate Mirrors and align the optical axis to at least %d%%." % threshold,
			"硬件已装齐。点击“准直镜面”，将光轴校准到至少 %d%%。" % threshold
		)
	return GameManager.text("Support system and completed tube are installed. Finish main assembly to continue.", "支撑系统和完整镜筒已安装。完成主组装后即可继续。")


func _main_family_art_texture() -> Texture2D:
	return _family_art_texture(_family())


func _part_texture_control(part: Dictionary, bounds: Rect2) -> TextureRect:
	var path := str(part.get("icon_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2.ZERO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = texture
	icon.position = bounds.position
	icon.size = bounds.size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _part_card(part_type: String) -> Control:
	var part := _part_for_type(part_type)
	var installed := _installed(part_type)
	var is_selected := selected_type == part_type and not installed
	var card := Panel.new()
	card.name = "PartCard_%s" % part_type
	card.custom_minimum_size = Vector2(236, 54)
	var border := GREEN if installed else (GOLD if is_selected else Color(0.25, 0.43, 0.66))
	card.add_theme_stylebox_override("panel", _style(Color(0.075, 0.10, 0.15), border, 3 if is_selected else 2))
	var text_x := 10.0
	var icon := _part_texture_control(part, Rect2(6, 6, 42, 42))
	if icon != null:
		icon.name = "PartCardIcon_%s" % part_type
		card.add_child(icon)
		text_x = 56.0
	var title := _label(GameManager.dict_text(part, "name"), Vector2(text_x, 5), Vector2(188.0 - text_x, 18), 12, TEXT)
	title.clip_text = true
	card.add_child(title)
	var state_text := GameManager.text("Installed", "已安装") if installed else (GameManager.text("Selected", "已选择") if is_selected else GameManager.text("Tap to select", "点击选择"))
	card.add_child(_label(state_text, Vector2(text_x, 27), Vector2(132.0, 16), 11, GREEN if installed else (GOLD if is_selected else CYAN)))
	# The whole card is the select control (a tap selects; it never observes,
	# never installs, never completes the mission). A green check marks installed.
	if installed:
		var check := _label("✓", Vector2(196, 12), Vector2(30, 30), 22, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		card.add_child(check)
	else:
		var hit := Button.new()
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.position = Vector2.ZERO
		hit.size = Vector2(236, 54)
		hit.pressed.connect(func() -> void: _select_flat_part(part_type))
		card.add_child(hit)
	part_card_controls[part_type] = card
	return card


func _select_flat_part(part_type: String) -> void:
	# Selection only: highlight, update the inspector, and mark the blueprint
	# slot. Explicitly does NOT install, observe, log, score or save.
	selected_type = part_type
	if _family() == "space_segmented":
		space_blueprint_page = _space_page_for_part(part_type)
	elif _family() == "fast_radio":
		fast_blueprint_page = _fast_page_for_part(part_type)
	_build()  # rebuild recreates the cards/labels and re-applies the gold border
	var part := _part_for_type(part_type)
	status_label.text = GameManager.text(
		"Selected " + GameManager.dict_text(part, "name") + ". Now click its highlighted slot.",
		"已选择" + GameManager.dict_text(part, "name") + "。现在点击高亮的安装位。")
	status_label.add_theme_color_override("font_color", TEXT)
	_update_flat_inspector(part_type)


func _family() -> String:
	return GameManager.assembly_family()


func _assembly_level() -> Dictionary:
	return GameManager.assembly_level_context() if GameManager.postgraduate_free_build() else GameManager.current_level()


func _draw_specialized_blueprint() -> void:
	var family := _family()
	if family == "space_segmented":
		_draw_space_blueprint_page()
		return
	if family == "fast_radio":
		_draw_fast_blueprint_page()
		return
	var art := TextureRect.new()
	art.texture = _family_art_texture(family)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if family == "space_segmented":
		var layout := _space_segmented_blueprint_layout()
		art.position = layout["display_rect"].position
		art.size = layout["display_rect"].size
	else:
		art.position = Vector2(40, 30)
		art.size = Vector2(348, 300)
	blueprint.add_child(art)
	var placements := _specialized_slot_positions(family)
	if family == "space_segmented":
		for part_type in order:
			_draw_space_blueprint_slot(
				part_type,
				placements.get(part_type, Rect2(156, 388, 116, 42)),
				SPACE_SEGMENTED_LABEL_RECTS.get(part_type, Rect2(8, 360, 124, 32))
			)
	else:
		for part_type in order:
			_draw_slot(part_type, placements.get(part_type, Rect2(156, 388, 116, 42)))
	# Caption sits in its own strip BELOW the slots, on a solid backing, so it can
	# never overlap the green install frames or the art.
	var caption_bg := Panel.new()
	caption_bg.position = Vector2(14, 452)
	caption_bg.size = Vector2(400, 40)
	caption_bg.add_theme_stylebox_override("panel", _style(Color(0.03, 0.05, 0.085, 0.94), Color(0.20, 0.34, 0.5), 1))
	caption_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blueprint.add_child(caption_bg)
	var caption := _label_to(blueprint, _family_caption(family), Vector2(22, 458), Vector2(384, 28), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _draw_fast_blueprint_page() -> void:
	var page_id := fast_blueprint_page
	if page_id != "overview" and not FAST_BLUEPRINT_CONFIG.has(page_id):
		page_id = "overview"
		fast_blueprint_page = page_id
	if page_id == "overview":
		_draw_fast_blueprint_overview()
	else:
		var config: Dictionary = FAST_BLUEPRINT_CONFIG[page_id]
		_draw_fast_module_page(
			GameManager.text(str(config["title_en"]), str(config["title_zh"])),
			_fast_page_explanation(page_id),
			config["parts"]
		)
	_draw_fast_blueprint_tabs()


func _draw_fast_blueprint_overview() -> void:
	var canvas := Control.new()
	canvas.name = "FastBlueprintCanvas"
	canvas.position = Vector2(4, 6)
	canvas.size = Vector2(420, 438)
	canvas.clip_contents = true
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	blueprint.add_child(canvas)

	var source_size := Vector2(765.0, 956.0)
	var layout := _calculate_blueprint_layout(
		source_size,
		Rect2(Vector2.ZERO, source_size),
		Rect2(Vector2.ZERO, canvas.size)
	)
	var art := TextureRect.new()
	art.name = "FastBlueprintArt"
	art.custom_minimum_size = Vector2.ZERO
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = load(FAST_BLUEPRINT_CROPPED) as Texture2D
	art.position = layout["display_rect"].position
	art.size = layout["display_rect"].size
	art.set_meta("fast_blueprint_page", "overview")
	canvas.add_child(art)

	for system_id_value in ["dish", "feed", "signal"]:
		var system_id := str(system_id_value)
		var target_rect := _source_rect_to_blueprint(FAST_SYSTEM_SOURCE_SLOTS[system_id], layout)
		_draw_fast_system_target(canvas, system_id, target_rect)


func _draw_fast_system_target(parent: Control, page_id: String, rect: Rect2) -> void:
	var config: Dictionary = FAST_BLUEPRINT_CONFIG[page_id]
	var visible_parts: Array[String] = []
	for part_type_value in config["parts"]:
		var part_type := str(part_type_value)
		if order.has(part_type):
			visible_parts.append(part_type)
	var installed_count := 0
	for part_type in visible_parts:
		if _installed(part_type):
			installed_count += 1
	var complete := not visible_parts.is_empty() and installed_count == visible_parts.size()
	var color := GREEN if complete else CYAN
	var target := Panel.new()
	target.name = "FastSystemTarget_%s" % page_id
	target.position = rect.position
	target.size = rect.size
	target.clip_contents = true
	target.add_theme_stylebox_override("panel", _style(Color(0.015, 0.08, 0.12, 0.12), color, 2))
	parent.add_child(target)
	var title := GameManager.text(str(config["title_en"]), str(config["title_zh"]))
	var compact_target := rect.size.x < 90.0
	var target_text := "%d/%d" % [installed_count, visible_parts.size()] if compact_target else "%s\n%d/%d" % [title, installed_count, visible_parts.size()]
	var label := _label(
		target_text,
		Vector2(4, maxf(2.0, rect.size.y * 0.5 - 20.0)),
		Vector2(rect.size.x - 8, 40),
		8 if compact_target else 9,
		color,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(label)
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.tooltip_text = GameManager.text("Open this engineering system", "打开这套工程系统")
	hit.pressed.connect(_set_fast_blueprint_page.bind(page_id))
	target.add_child(hit)


func _draw_fast_module_page(title_text: String, explanation: String, part_types: Array) -> void:
	var header := _label(title_text, Vector2(14, 10), Vector2(400, 24), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	blueprint.add_child(header)
	var help := _label(explanation, Vector2(20, 36), Vector2(388, 34), 10, Color(0.66, 0.78, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blueprint.add_child(help)
	var visible_types: Array[String] = []
	for part_type_value in part_types:
		var part_type := str(part_type_value)
		if order.has(part_type):
			visible_types.append(part_type)
	for index in range(visible_types.size()):
		var column := index % 2
		var row := index / 2
		_draw_fast_blueprint_slot(
			visible_types[index],
			Rect2(12.0 + column * 204.0, 78.0 + row * 78.0, 196.0, 68.0)
		)
	if visible_types.is_empty():
		var locked_note := _label(
			GameManager.text("No components in this system have been unlocked yet.", "这套系统的组件尚未解锁。"),
			Vector2(32, 208), Vector2(364, 48), 13, Color(0.58, 0.66, 0.72), HORIZONTAL_ALIGNMENT_CENTER
		)
		locked_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blueprint.add_child(locked_note)


func _fast_page_explanation(page_id: String) -> String:
	match page_id:
		"dish":
			return GameManager.text("Active panels shape the collecting surface.", "主动面板共同塑造接收反射面。")
		"feed":
			return GameManager.text("Cables position and steady the feed cabin.", "缆索负责定位并稳定馈源舱。")
		"signal":
			return GameManager.text("Electronics clean, time and record the signal.", "电子系统净化、计时并记录信号。")
	return ""


func _draw_fast_blueprint_slot(part_type: String, rect: Rect2) -> void:
	var installed := _installed(part_type)
	var active := selected_type == part_type and not installed
	var color := GREEN if installed else (GOLD if active else CYAN)
	var slot := Control.new()
	slot.name = "FastBlueprintSlot_%s" % part_type
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	blueprint.add_child(slot)
	slot_controls[part_type] = slot

	var frame := Panel.new()
	frame.name = "FastBlueprintFrame_%s" % part_type
	frame.position = Vector2.ZERO
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override(
		"panel",
		_style(Color(0.015, 0.055, 0.085, 0.82 if installed else 0.68), color, 3 if active else 2)
	)
	slot.add_child(frame)

	var part := _part_for_type(part_type)
	var icon := _part_texture_control(part, Rect2(6, 6, 50, 50))
	if icon != null:
		icon.name = "FastBlueprintPartTexture_%s" % part_type
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if installed else 0.48)
		slot.add_child(icon)
	var caption := _label(
		_short_type(part_type),
		Vector2(64, 7),
		Vector2(rect.size.x - 72, 34),
		10,
		GREEN if installed else (GOLD if active else CYAN),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(caption)
	if installed:
		var ok := _label("OK", Vector2(rect.size.x - 30, 2), Vector2(26, 15), 9, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ok)
	var state := _label(
		GameManager.text("INSTALLED", "已安装") if installed else GameManager.text("CLICK TO INSTALL", "点击安装"),
		Vector2(64, 47), Vector2(rect.size.x - 72, 15), 8, GREEN if installed else CYAN
	)
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(state)

	var hit := Button.new()
	hit.name = "FastBlueprintHit_%s" % part_type
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.pressed.connect(func() -> void: _install_at_slot(part_type))
	slot.add_child(hit)


func _draw_fast_blueprint_tabs() -> void:
	var tabs := [
		["overview", GameManager.text("Overview", "总览")],
		["dish", GameManager.text("Dish", "反射面")],
		["feed", GameManager.text("Feed", "馈源")],
		["signal", GameManager.text("Signal", "信号")],
	]
	var x := 4.0
	for tab_value in tabs:
		var page_id := str(tab_value[0])
		var visible_parts: Array[String] = []
		var config: Dictionary = FAST_BLUEPRINT_CONFIG.get(page_id, {})
		for part_type_value in config.get("parts", []):
			var part_type := str(part_type_value)
			if order.has(part_type):
				visible_parts.append(part_type)
		var installed_count := 0
		for part_type in visible_parts:
			if _installed(part_type):
				installed_count += 1
		var suffix := "" if page_id == "overview" else " %d/%d" % [installed_count, visible_parts.size()]
		var tab := _button(str(tab_value[1]) + suffix, Vector2(x, 458), Vector2(100, 34), Color(0.055, 0.10, 0.17))
		tab.name = "FastBlueprintTab_%s" % page_id
		tab.tooltip_text = GameManager.text("Complete FAST engineering overview", "FAST 完整工程总览") if page_id == "overview" else GameManager.text(str(config["title_en"]), str(config["title_zh"]))
		if page_id == fast_blueprint_page:
			tab.add_theme_stylebox_override("normal", _style(Color(0.08, 0.18, 0.23), GOLD, 2))
			tab.add_theme_color_override("font_color", GOLD)
		elif not visible_parts.is_empty() and installed_count == visible_parts.size():
			tab.add_theme_color_override("font_color", GREEN)
		tab.pressed.connect(_set_fast_blueprint_page.bind(page_id))
		blueprint.add_child(tab)
		x += 106.0


func _set_fast_blueprint_page(page_id: String) -> void:
	if page_id != "overview" and not FAST_BLUEPRINT_CONFIG.has(page_id):
		return
	fast_blueprint_page = page_id
	_build()


func _fast_page_for_part(part_type: String) -> String:
	for page_id in FAST_BLUEPRINT_CONFIG:
		var config: Dictionary = FAST_BLUEPRINT_CONFIG[page_id]
		if config["parts"].has(part_type):
			return str(page_id)
	return "dish"


func _draw_space_blueprint_page() -> void:
	if space_blueprint_page == "core":
		var art := TextureRect.new()
		art.name = "SpaceCoreBlueprintArt"
		art.texture = _family_art_texture("space_segmented")
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var layout := _space_segmented_blueprint_layout()
		art.position = layout["display_rect"].position
		art.size = layout["display_rect"].size
		blueprint.add_child(art)
		var placements := _specialized_slot_positions("space_segmented")
		for part_type in SPACE_CORE_TYPES:
			if not order.has(part_type):
				continue
			_draw_space_blueprint_slot(
				part_type,
				placements.get(part_type, Rect2(156, 388, 116, 42)),
				SPACE_SEGMENTED_LABEL_RECTS.get(part_type, Rect2(8, 360, 124, 32))
			)
	elif space_blueprint_page == "deployment":
		_draw_space_module_page(
			GameManager.text("DEPLOYMENT, POWER & THERMAL", "展开、供电与热控"),
			GameManager.text(
				"Unfolds and powers the observatory.\nCommunicates with Earth and removes heat.",
				"这些系统负责展开天文台、供电、与地球通信，并把仪器热量排向深空。"
			),
			SPACE_DEPLOYMENT_TYPES
		)
	else:
		_draw_space_module_page(
			GameManager.text("COLD SCIENCE INSTRUMENT BAY", "低温科学仪器舱"),
			GameManager.text(
				"Mirrors steer light into the cold instrument bay.\nOnly installed instruments appear at the console.",
				"反射镜把光束送入低温仪器舱；只有已经安装的仪器才会在空间控制台中可用。"
			),
			SPACE_INSTRUMENT_TYPES
		)
	_draw_space_blueprint_tabs()


func _draw_space_blueprint_tabs() -> void:
	var tabs := [
		["core", GameManager.text("Light Path", "光路核心")],
		["deployment", GameManager.text("Deploy & Power", "展开与供电")],
		["instruments", GameManager.text("Instruments", "科学仪器")],
	]
	var x := 4.0
	for tab_value in tabs:
		var tab_id := str(tab_value[0])
		var tab := _button(str(tab_value[1]), Vector2(x, 458), Vector2(136, 34), Color(0.07, 0.12, 0.20))
		tab.name = "SpaceBlueprintTab_%s" % tab_id
		if tab_id == space_blueprint_page:
			tab.add_theme_stylebox_override("normal", _style(Color(0.12, 0.20, 0.23), GOLD, 2))
			tab.add_theme_color_override("font_color", GOLD)
		tab.pressed.connect(_set_space_blueprint_page.bind(tab_id))
		blueprint.add_child(tab)
		x += 142.0


func _set_space_blueprint_page(page_id: String) -> void:
	space_blueprint_page = page_id
	_build()


func _space_page_for_part(part_type: String) -> String:
	if SPACE_CORE_TYPES.has(part_type):
		return "core"
	if SPACE_DEPLOYMENT_TYPES.has(part_type):
		return "deployment"
	return "instruments"


func _draw_space_module_page(title_text: String, explanation: String, part_types: Array) -> void:
	var header := _label(title_text, Vector2(14, 10), Vector2(400, 24), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	blueprint.add_child(header)
	var help := _label(explanation, Vector2(20, 38), Vector2(388, 42), 10, Color(0.66, 0.78, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blueprint.add_child(help)
	var visible_types: Array[String] = []
	for part_type_value in part_types:
		var part_type := str(part_type_value)
		if order.has(part_type):
			visible_types.append(part_type)
	for index in range(visible_types.size()):
		var column := index % 2
		var row := index / 2
		_draw_space_module_slot(
			visible_types[index],
			Rect2(12.0 + column * 204.0, 88.0 + row * 86.0, 196.0, 76.0)
		)
	if visible_types.is_empty():
		var locked_note := _label(
			GameManager.text(
				"No components in this system have been unlocked yet.",
				"这套系统的组件尚未解锁。"
			),
			Vector2(32, 208),
			Vector2(364, 48),
			13,
			Color(0.58, 0.66, 0.72),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		locked_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blueprint.add_child(locked_note)


func _draw_space_module_slot(part_type: String, rect: Rect2) -> void:
	var installed := _installed(part_type)
	var active := selected_type == part_type and not installed
	var color := GREEN if installed else (GOLD if active else Color(0.35, 0.84, 1.0))
	var slot := Panel.new()
	slot.name = "SpaceModuleSlot_%s" % part_type
	slot.position = rect.position
	slot.size = rect.size
	slot.clip_contents = true
	slot.add_theme_stylebox_override(
		"panel",
		_style(Color(0.025, 0.06, 0.10, 0.96), color, 3 if active else 2)
	)
	blueprint.add_child(slot)
	slot_controls[part_type] = slot
	var part := _part_for_type(part_type)
	var icon := _part_texture_control(part, Rect2(6, 8, 56, 56))
	if icon != null:
		icon.name = "SpaceModuleTexture_%s" % part_type
		slot.add_child(icon)
	var name_label := _label(
		_short_type(part_type),
		Vector2(68, 8),
		Vector2(120, 34),
		11,
		color
	)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(name_label)
	slot.add_child(_label(
		GameManager.text("INSTALLED", "已安装") if installed else GameManager.text("CLICK TO INSTALL", "点击安装"),
		Vector2(68, 49),
		Vector2(120, 16),
		9,
		GREEN if installed else CYAN
	))
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.pressed.connect(func() -> void: _install_at_slot(part_type))
	slot.add_child(hit)


func _space_segmented_blueprint_layout() -> Dictionary:
	return _calculate_blueprint_layout(
		SPACE_SEGMENTED_SOURCE_SIZE,
		Rect2(Vector2.ZERO, SPACE_SEGMENTED_SOURCE_SIZE),
		Rect2(0, 0, blueprint.size.x, 452)
	)


func _draw_space_blueprint_slot(part_type: String, target_rect: Rect2, label_rect: Rect2) -> void:
	var installed := _installed(part_type)
	var active := selected_type == part_type and not installed
	var color := GREEN if installed else (GOLD if active else Color(0.35, 0.84, 1.0, 0.92))

	var label_anchor := label_rect.get_center()
	var target_anchor := target_rect.get_center()
	if label_anchor.x < target_anchor.x:
		label_anchor.x = label_rect.end.x
	else:
		label_anchor.x = label_rect.position.x
	var connector := Line2D.new()
	connector.name = "SpaceSlotConnector_%s" % part_type
	connector.points = PackedVector2Array([label_anchor, target_anchor])
	connector.width = 1.0
	connector.default_color = Color(color.r, color.g, color.b, 0.72)
	connector.antialiased = false
	blueprint.add_child(connector)

	var target := Control.new()
	target.name = "SpaceSlot_%s" % part_type
	target.position = target_rect.position
	target.size = target_rect.size
	target.clip_contents = true
	blueprint.add_child(target)
	slot_controls[part_type] = target

	# Installed art lives in the slot's local coordinate space and is clipped by
	# the printed cyan box. This prevents large source PNGs from escaping into
	# the inspector or covering the telescope.
	if installed:
		var installed_icon := _part_texture_control(
			_part_for_type(part_type),
			Rect2(Vector2(3, 3), target_rect.size - Vector2(6, 6))
		)
		if installed_icon != null:
			installed_icon.name = "SpaceInstalledTexture_%s" % part_type
			target.add_child(installed_icon)

	var target_frame := Panel.new()
	target_frame.position = Vector2.ZERO
	target_frame.size = target_rect.size
	target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.add_theme_stylebox_override(
		"panel",
		_style(Color(0.02, 0.10, 0.15, 0.08 if not active else 0.20), color, 3 if active else 2)
	)
	target.add_child(target_frame)
	if installed:
		var ok := _label("OK", Vector2(target_rect.size.x - 28, 2), Vector2(24, 16), 10, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		ok.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(ok)
	var target_hit := Button.new()
	target_hit.flat = true
	target_hit.position = Vector2.ZERO
	target_hit.size = target_rect.size
	target_hit.pressed.connect(func() -> void: _install_at_slot(part_type))
	target.add_child(target_hit)

	var label_panel := Panel.new()
	label_panel.name = "SpaceSlotLabel_%s" % part_type
	label_panel.position = label_rect.position
	label_panel.size = label_rect.size
	label_panel.add_theme_stylebox_override("panel", _style(Color(0.025, 0.055, 0.09, 0.94), color, 1))
	blueprint.add_child(label_panel)
	var label_text := _short_type(part_type)
	if installed:
		label_text += "  OK"
	var label := _label(label_text, Vector2(4, 2), label_rect.size - Vector2(8, 4), 10, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_panel.add_child(label)
	var label_hit := Button.new()
	label_hit.flat = true
	label_hit.position = Vector2.ZERO
	label_hit.size = label_rect.size
	label_hit.pressed.connect(func() -> void: _install_at_slot(part_type))
	label_panel.add_child(label_hit)


func _family_caption(family: String) -> String:
	match family:
		"dobsonian": return GameManager.text("Dobsonian: direct hand-guided wide-field reflector", "多布森：直接手动引导的宽视场反射镜")
		"cassegrain": return GameManager.text("Cassegrain: compact tube, long folded focal length", "卡塞格林：紧凑镜筒，长焦距折叠光路")
		"gregorian": return GameManager.text("Gregorian: a different two-concave-mirror light path", "格里高利：不同的双凹面镜光路")
		"space_segmented": return GameManager.text("Segmented infrared mirror and thermal protection", "分段红外主镜与热控保护")
		"fast_radio": return GameManager.text("Radio dish, feed cabin, then signal data", "无线电反射面、馈源舱，再到信号数据")
	return ""


func _specialized_slot_positions(family: String) -> Dictionary:
	match family:
		"dobsonian":
			return {"mount": Rect2(126, 286, 160, 48), "reflector_tube": Rect2(54, 132, 180, 48), "primary_mirror": Rect2(242, 132, 132, 48), "secondary_mirror": Rect2(104, 92, 120, 36), "focuser": Rect2(232, 82, 118, 36), "eyepiece": Rect2(254, 48, 92, 30)}
		"cassegrain", "gregorian":
			return {"mount": Rect2(140, 290, 140, 48), "reflector_tube": Rect2(88, 138, 176, 48), "primary_mirror": Rect2(272, 138, 122, 48), "secondary_mirror": Rect2(108, 102, 126, 34), "focuser": Rect2(280, 90, 110, 34), "eyepiece": Rect2(288, 54, 94, 30)}
		"space_segmented":
			var layout := _space_segmented_blueprint_layout()
			var converted := {}
			for part_type in SPACE_SEGMENTED_SOURCE_SLOTS:
				converted[part_type] = _source_rect_to_blueprint(SPACE_SEGMENTED_SOURCE_SLOTS[part_type], layout)
			return converted
		"fast_radio":
			return {"radio_dish": Rect2(94, 136, 220, 54), "receiver": Rect2(144, 82, 128, 38), "signal_processor": Rect2(120, 276, 172, 46)}
	return {}


func _family_art_texture(family: String) -> Texture2D:
	if family == "space_segmented":
		return load(SPACE_SEGMENTED_BLUEPRINT) as Texture2D
	if family == "fast_radio":
		return load(FAST_BLUEPRINT_CROPPED) as Texture2D
	var source_texture := load(ADVANCED_FAMILY_ATLAS) as Texture2D
	if source_texture == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	match family:
		"dobsonian": atlas.region = Rect2(0, 0, 626, 630)
		"cassegrain": atlas.region = Rect2(628, 0, 626, 630)
		"gregorian": atlas.region = Rect2(0, 632, 370, 622)
		"space_segmented": atlas.region = Rect2(372, 632, 380, 622)
		_: atlas.region = Rect2(0, 0, 626, 630)
	return atlas


func _draw_slot(part_type: String, rect: Rect2) -> void:
	var installed := _installed(part_type)
	var active := selected_type == part_type
	var color := GREEN if installed else (GOLD if active else Color(0.35, 0.66, 0.90))
	var slot := Panel.new()
	slot.position = rect.position
	slot.size = rect.size
	slot.add_theme_stylebox_override("panel", _style(Color(0.06, 0.09, 0.13, 0.92), color, 2))
	blueprint.add_child(slot)
	slot_controls[part_type] = slot
	var part := _part_for_type(part_type)
	var label := _label(GameManager.dict_text(part, "name") if installed else _short_type(part_type), Vector2(3, 3), rect.size - Vector2(6, 6), 12, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	slot.add_child(label)
	var hit := Button.new()
	hit.flat = true
	hit.position = Vector2.ZERO
	hit.size = rect.size
	hit.pressed.connect(func() -> void: _install_at_slot(part_type))
	slot.add_child(hit)


func _install_at_slot(slot_type: String) -> void:
	if install_animation_active:
		return
	if selected_type == "":
		status_label.text = GameManager.text("Select a reflector part first.", "请先选择一个反射镜零件。")
		return
	if selected_type != slot_type:
		status_label.text = GameManager.text("That part does not belong there. Newtonian optics must follow the reflected light path.", "该零件不属于这里。牛顿镜光学部件必须遵循反射光路。")
		return
	if _family() == "fast_radio":
		var missing_dependencies: Array[String] = []
		for dependency_value in AssemblyDependencyGraph.prerequisites_for("fast_radio", "main", slot_type):
			var dependency := str(dependency_value)
			if order.has(dependency) and not _installed(dependency):
				missing_dependencies.append(dependency)
		if not missing_dependencies.is_empty():
			var dependency_names: Array[String] = []
			for dependency in missing_dependencies:
				dependency_names.append(_short_type(dependency))
			status_label.text = GameManager.text(
				"Install %s first; this component depends on that physical system." % ", ".join(dependency_names),
				"请先安装%s；该组件依赖这些物理系统。" % "、".join(dependency_names)
			)
			for dependency in missing_dependencies:
				var dependency_card := part_card_controls.get(dependency) as Control
				if dependency_card != null:
					InteractionFeedback.pulse(dependency_card, GOLD, 0.44)
			return
	install_animation_active = true
	var animation := _capture_part_animation(slot_type)
	var selected_part := _part_for_type(slot_type)
	var selected_part_id := str(selected_part.get("id", ""))
	if GameManager.install_part(slot_type, 0, selected_part_id) < 0:
		install_animation_active = false
		status_label.text = GameManager.install_part_block_reason(slot_type)
		return
	selected_type = ""
	if _family() == "fast_radio":
		fast_blueprint_page = _fast_page_for_part(slot_type)
	install_animation_active = false
	status_label.text = GameManager.text(
		"Installed. The FAST engineering chain is taking shape." if _family() == "fast_radio" else "Installed. The reflected light path is taking shape.",
		"已安装，FAST 工程链正在成形。" if _family() == "fast_radio" else "已安装，反射光路正在成形。"
	)
	_build()
	_play_part_animation(animation)
	call_deferred("_finish_advanced_install_feedback", slot_type, false)


func _finish_advanced_install_feedback(part_type: String, main_mode: bool) -> void:
	var card := part_card_controls.get(part_type) as Control
	var slot := slot_controls.get(part_type) as Control
	InteractionFeedback.mechanical_snap(card, slot)
	var reason := _advanced_part_operation_effect(part_type)
	if flat_inspector_detail != null:
		flat_inspector_detail.text = "%s\n%s" % [_short_type(part_type), reason]
	status_label.text = reason
	var remaining := _remaining_advanced_install_parts(_main_parts() if main_mode else order)
	if GameManager.assembly_hints_enabled():
		for remaining_type_value in remaining:
			var remaining_type := str(remaining_type_value)
			var remaining_card := part_card_controls.get(remaining_type) as Control
			var remaining_slot := slot_controls.get(remaining_type) as Control
			if remaining_card != null:
				InteractionFeedback.pulse(remaining_card, Color(0.32, 0.86, 1.0), 0.42)
			if remaining_slot != null:
				InteractionFeedback.pulse(remaining_slot, Color(0.32, 0.86, 1.0), 0.42)
	var ready := remaining.is_empty()
	InteractionFeedback.operation_chain(
		self,
		GameManager.text("Installed %s" % _short_type(part_type), "已安装%s" % _short_type(part_type)),
		reason,
		GameManager.text(
			"Assembly check is ready" if ready else "%d components remain; choose any" % remaining.size(),
			"装配检查已就绪" if ready else "还剩 %d 个组件，可任选一个继续" % remaining.size()
		),
		null,
		Color(0.42, 0.96, 0.58) if ready else Color(0.32, 0.86, 1.0)
	)


func _remaining_advanced_install_parts(part_types: Array) -> Array[String]:
	var remaining: Array[String] = []
	for part_type_value in part_types:
		var part_type := str(part_type_value)
		if not _installed(part_type):
			remaining.append(part_type)
	return remaining


func _next_advanced_install_part(part_types: Array) -> String:
	var remaining := _remaining_advanced_install_parts(part_types)
	return "" if remaining.is_empty() else remaining[0]

func _advanced_part_operation_effect(part_type: String) -> String:
	match part_type:
		"primary_mirror":
			return GameManager.text("The collecting area now gathers faint incoming light.", "主镜集光面积现在可以收集微弱入射光。")
		"secondary_mirror":
			return GameManager.text("The reflected beam now reaches the instrument path.", "反射光束现在可以进入仪器光路。")
		"detector", "detector_module", "nircam", "nirspec", "miri":
			return GameManager.text("The focused infrared signal can now become science data.", "聚焦后的红外信号现在可以转化为科学数据。")
		"sunshield", "radiator":
			return GameManager.text("Thermal radiation is now kept away from the cold optics.", "热辐射现在会被隔离在低温光学系统之外。")
		"spacecraft_bus":
			return GameManager.text("Power, control and telemetry now have a stable platform.", "供电、控制与遥测现在有了稳定平台。")
		"deployable_tower", "deployment_hinges":
			return GameManager.text("The observatory can now unfold into its observing geometry.", "天文台现在可以展开到观测构型。")
		"radio_dish":
			return GameManager.text("The collecting surface now concentrates radio waves.", "反射面现在可以汇聚射电波。")
		"panel_segment":
			return GameManager.text("This active panel can now reshape the illuminated paraboloid.", "这块主动面板现在可以参与形成被照亮的抛物面。")
		"panel_actuator":
			return GameManager.text("The reflector surface can now follow commanded curvature changes.", "反射面现在可以执行曲率调整指令。")
		"cable_system":
			return GameManager.text("The suspended cabin now has its six-cable support geometry.", "悬吊馈源舱现在具备六索支撑结构。")
		"tension_controller":
			return GameManager.text("Cable load can now be balanced while the cabin moves.", "馈源舱移动时，缆索载荷现在可以保持平衡。")
		"receiver":
			return GameManager.text("The focused radio signal can now be converted electrically.", "聚焦后的射电信号现在可以转换为电信号。")
		"feed_receiver", "rf_receiver":
			return GameManager.text("The selected radio band can now enter the low-noise receiver chain.", "选定的射电频段现在可以进入低噪声接收链。")
		"signal_processor":
			return GameManager.text("Noise rejection and pulse analysis are now available.", "噪声抑制与脉冲分析现在可以工作。")
		"spectrum_monitor":
			return GameManager.text("Frequency structure and interference are now visible on the spectrum display.", "频率结构与干扰现在会显示在频谱监视器上。")
		"timing_console":
			return GameManager.text("Repeating arrivals can now be folded into a measurable pulse period.", "重复到达的信号现在可以折叠成可测量的脉冲周期。")
		"data_recorder":
			return GameManager.text("The calibrated observation can now be preserved as a science record.", "完成校准的观测现在可以保存为科学记录。")
		"rfi_monitor":
			return GameManager.text("Human-made radio contamination can now be identified and rejected.", "人造射频污染现在可以被识别并剔除。")
		"control_terminal":
			return GameManager.text("Dish, cabin and receiver commands now meet at one control station.", "反射面、馈源舱与接收机指令现在汇入同一控制终端。")
		"mount", "tripod":
			return GameManager.text("The optical assembly now has stable mechanical support.", "光学组件现在有了稳定机械支撑。")
		"optical_tube_assembly":
			return GameManager.text("The completed internal light path is now seated on the mount.", "完整的内部光路现在已经固定到支架上。")
		"finder_scope":
			return GameManager.text("Wide-field aiming can now guide the main telescope.", "宽视场瞄准现在可以引导主望远镜。")
	return GameManager.text("This component completes the next physical stage.", "该组件完成了下一个物理工作环节。")


func _space_part_prerequisite(part_type: String) -> String:
	var prerequisites := {
		"secondary_mirror": "primary_mirror",
		"detector": "secondary_mirror",
		"sunshield": "detector",
		"deployable_tower": "spacecraft_bus",
		"deployment_hinges": "deployable_tower",
		"solar_array": "spacecraft_bus",
		"antenna": "spacecraft_bus",
		"radiator": "sunshield",
		"steering_mirror": "primary_mirror",
		"tertiary_mirror": "secondary_mirror",
		"instrument_bay": "detector",
		"detector_module": "instrument_bay",
		"nircam": "instrument_bay",
		"nirspec": "instrument_bay",
		"miri": "radiator",
		"fgs_niriss": "steering_mirror",
	}
	return str(prerequisites.get(part_type, ""))


func _install_all_space_parts() -> void:
	# Compatibility entry point for older tests and scene bindings. The real
	# implementation is the graduation-only animated dependency queue.
	_on_auto_assemble_pressed()


func _add_flat_auto_assemble_button(inspector: Control) -> void:
	if not GameManager.postgraduate_free_build():
		auto_assemble_button = null
		return
	auto_assemble_button = _button(
		GameManager.text("Skip Animation", "跳过演出") if auto_assemble_running else GameManager.text("Auto Assemble", "自动装配"),
		Vector2(14, 448),
		Vector2(194, 42),
		Color(0.08, 0.20, 0.31)
	)
	auto_assemble_button.name = "AutoAssembleButton"
	auto_assemble_button.tooltip_text = GameManager.text(
		"Install only the missing components in a valid structural sequence.",
		"只安装缺失组件，并遵循有效的结构依赖顺序。"
	)
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
	auto_assemble_button.tooltip_text = GameManager.text(
		"Install only the missing components in a valid structural sequence.",
		"只安装缺失组件，并遵循有效的结构依赖顺序。"
	)
	auto_assemble_button.pressed.connect(_on_auto_assemble_pressed)
	add_child(auto_assemble_button)


func _on_auto_assemble_pressed() -> void:
	if auto_assemble_running:
		auto_assemble_skip_requested = true
		if auto_assemble_button != null:
			auto_assemble_button.text = GameManager.text("Finishing...", "正在完成…")
		return
	if not GameManager.postgraduate_free_build():
		return
	if _is_nested_ground_family() and not GameManager.advanced_tube_completed():
		GameManager.set_meta(AUTO_CHAIN_TO_TUBE_META, true)
		GameManager.go("optical_tube_assembly")
		return
	_run_auto_assemble()


func _run_auto_assemble() -> void:
	if not GameManager.postgraduate_free_build() or auto_assemble_running:
		return
	var available: Array[String] = _main_parts() if _is_nested_ground_family() else order.duplicate()
	var installed_parts: Array[String] = []
	for part_type in available:
		if _installed(part_type):
			installed_parts.append(part_type)
	var result := AssemblyDependencyGraph.topological_order(_family(), "main", available, installed_parts)
	if not bool(result.get("ok", false)):
		status_label.text = GameManager.text(
			"Auto assembly stopped: this telescope dependency graph is invalid.",
			"自动装配已停止：该望远镜的依赖图无效。"
		)
		push_error("%s auto-assembly dependency error: %s" % [_family(), result])
		return
	var queue: Array = result.get("order", [])
	if queue.is_empty():
		status_label.text = GameManager.text("Every available component is already installed.", "当前可用组件已全部安装。")
		return

	auto_assemble_running = true
	auto_assemble_skip_requested = false
	install_animation_active = true
	var failed := false
	if auto_assemble_button != null:
		auto_assemble_button.text = GameManager.text("Skip Animation", "跳过演出")
	for part_type_value in queue:
		if not is_inside_tree():
			return
		var part_type := str(part_type_value)
		if _installed(part_type):
			continue
		_prepare_auto_assemble_page(part_type)
		_build()
		await get_tree().process_frame
		var animation := _capture_part_animation(part_type)
		var part := _main_template_part(part_type) if _is_nested_ground_family() else _part_for_type(part_type)
		var part_id := "" if part_type == "optical_tube_assembly" else str(part.get("id", ""))
		if GameManager.install_part(part_type, 0, part_id) < 0:
			status_label.text = GameManager.install_part_block_reason(part_type, part_id)
			failed = true
			break
		_play_part_animation(animation)
		if not auto_assemble_skip_requested:
			await get_tree().create_timer(0.40 if not InteractionFeedback.is_reduced_motion() else 0.10).timeout
		_build()
		await get_tree().process_frame
		_finish_advanced_install_feedback(part_type, _is_nested_ground_family())
		if not auto_assemble_skip_requested:
			await get_tree().create_timer(0.11).timeout

	install_animation_active = false
	auto_assemble_running = false
	auto_assemble_skip_requested = false
	selected_type = ""
	_build()
	await get_tree().process_frame
	if failed:
		return
	InteractionFeedback.operation_chain(
		self,
		GameManager.text("Auto assembly complete", "自动装配完成"),
		GameManager.text("Every missing component followed this instrument's structural dependency graph.", "所有缺失组件均按该仪器的结构依赖完成安装。"),
		GameManager.text("Assembly check is ready", "装配检查已就绪"),
		template_finish,
		Color(0.42, 0.96, 0.58)
	)


func _prepare_auto_assemble_page(part_type: String) -> void:
	if _family() == "space_segmented":
		space_blueprint_page = _space_page_for_part(part_type)
	elif _family() == "fast_radio":
		fast_blueprint_page = _fast_page_for_part(part_type)


func _capture_part_animation(part_type: String) -> Dictionary:
	var part := _main_template_part(part_type) if _family() in ["newtonian", "dobsonian"] else _part_for_type(part_type)
	var path := str(part.get("icon_path", ""))
	var source := part_card_controls.get(part_type) as Control
	var target := slot_controls.get(part_type) as Control
	if source == null or target == null or path == "" or not ResourceLoader.exists(path):
		return {}
	var texture := load(path) as Texture2D
	if texture == null:
		return {}
	var source_rect := source.get_global_rect()
	source_rect.position += Vector2(8, 8)
	source_rect.size = Vector2(minf(54.0, source_rect.size.x), minf(54.0, source_rect.size.y))
	return {"texture": texture, "source": source_rect, "target": target.get_global_rect()}


func _play_part_animation(animation: Dictionary) -> void:
	if animation.is_empty():
		return
	InteractionFeedback.fly_texture(animation["texture"], animation["source"], animation["target"], self)


func _animate_install_error_if_idle(part_type: String) -> void:
	if install_animation_active or not is_inside_tree():
		return
	var source := part_card_controls.get(part_type) as Control
	InteractionFeedback.error(source if source != null else status_label)


func _finish() -> void:
	if not GameManager.telescope_is_ready():
		if _family() == "space_segmented":
			status_label.text = _status_text()
			InteractionFeedback.error(status_label)
			return
		status_label.text = GameManager.text("Install every marked reflector component first.", "请先安装全部标记的反射镜组件。")
		return
	if bool(_assembly_level().get("requires_collimation", false)) and not GameManager.collimation_is_acceptable():
		if GameManager.try_story_mechanic("collimation", "collimation", "before_collimation"):
			return
		if GameManager.try_teaching_intercept("before_collimation", "collimation"):
			return
		GameManager.go("collimation")
		return
	InteractionFeedback.feedback_sfx_requested.emit("assembly_completed")
	GameManager.equip_completed_optical_telescope(_family())
	GameManager.update_room_guidance_for_level()
	GameManager.set_observatory_spawn("assembly")
	GameManager.go("observatory")


func _part_for_type(part_type: String) -> Dictionary:
	# Advanced lessons prescribe exact components. Prefer that exact ID over a
	# previously equipped refractor part with the same broad type (eyepiece,
	# mount, and so on).
	for required_id_value in ([] if GameManager.postgraduate_free_build() else GameManager.current_level().get("required_part_ids", [])):
		var required := GameManager.get_part(str(required_id_value))
		if str(required.get("type", "")) == part_type:
			if GameManager.equipped_part_id(part_type) != str(required.get("id", "")):
				GameManager.equip_part(str(required.get("id", "")))
			return required
	var equipped := GameManager.get_part(GameManager.equipped_part_id(part_type))
	if not equipped.is_empty() and GameManager.is_part_compatible_with_current_level(equipped):
		return equipped
	var options: Array = GameManager.unlocked_parts_by_type(part_type)
	# Prefer a component built for this telescope family. Generic parts remain
	# a fallback, but an incompatible part left equipped by the previous bench
	# must never block an otherwise legal advanced assembly.
	for option_index in range(options.size() - 1, -1, -1):
		var option: Dictionary = options[option_index]
		if str(option.get("telescope_family", "")) != _family():
			continue
		GameManager.equip_part(str(option.get("id", "")))
		return option
	for option_index in range(options.size() - 1, -1, -1):
		var option: Dictionary = options[option_index]
		if not GameManager.is_part_compatible_with_current_level(option):
			continue
		GameManager.equip_part(str(option.get("id", "")))
		return option
	return {"id": part_type, "name_en": part_type, "name_zh": part_type}


func _placeholder_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _installed(part_type: String) -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var entry: Dictionary = state.get(part_type, {})
	return bool(entry.get("installed", false))


func _status_text() -> String:
	var missing: Array = GameManager.missing_parts()
	if _family() == "space_segmented":
		if missing.is_empty():
			return GameManager.text(
				"All observatory systems installed. Press Finish Assembly.",
				"天文台全部系统均已安装。请点击“完成组装”。"
			)
		var core_total := _space_group_available_count(SPACE_CORE_TYPES)
		var deployment_total := _space_group_available_count(SPACE_DEPLOYMENT_TYPES)
		var instrument_total := _space_group_available_count(SPACE_INSTRUMENT_TYPES)
		return GameManager.text(
			"Assembly progress\nLight path: %d/%d\nDeploy & power: %d/%d\nScience instruments: %d/%d\n\nSelect a card or install the equipped set." % [
				_space_group_installed_count(SPACE_CORE_TYPES), core_total,
				_space_group_installed_count(SPACE_DEPLOYMENT_TYPES), deployment_total,
				_space_group_installed_count(SPACE_INSTRUMENT_TYPES), instrument_total,
			],
			"组装进度\n光路核心：%d/%d\n展开与供电：%d/%d\n科学仪器：%d/%d\n\n请选择零件，或安装已装备组件。" % [
				_space_group_installed_count(SPACE_CORE_TYPES), core_total,
				_space_group_installed_count(SPACE_DEPLOYMENT_TYPES), deployment_total,
				_space_group_installed_count(SPACE_INSTRUMENT_TYPES), instrument_total,
			]
		)
	if _family() == "fast_radio":
		if missing.is_empty():
			return GameManager.text(
				"All FAST systems installed. Press Finish Assembly.",
				"FAST 全部系统均已安装。请点击“完成组装”。"
			)
		var available_now: Array[String] = []
		for part_type_value in missing:
			var part_type := str(part_type_value)
			var blocked := false
			for dependency_value in AssemblyDependencyGraph.prerequisites_for("fast_radio", "main", part_type):
				var dependency := str(dependency_value)
				if order.has(dependency) and not _installed(dependency):
					blocked = true
					break
			if not blocked:
				available_now.append(_short_type(part_type))
			if available_now.size() == 3:
				break
		var available_text := "\n- ".join(available_now)
		return GameManager.text(
			"Engineering progress: %d/%d\nAvailable now:\n- %s\n\nUse the three blueprint tabs to inspect each system." % [order.size() - missing.size(), order.size(), available_text],
			"工程进度：%d/%d\n当前可安装：\n- %s\n\n请切换三张蓝图，逐套检查系统。" % [order.size() - missing.size(), order.size(), available_text]
		)
	if missing.is_empty():
		return GameManager.text("All parts installed. Press Finish Assembly.", "全部零件已安装。点击“完成组装”。")
	var missing_lines: Array[String] = []
	for part_type_value in missing:
		missing_lines.append("- " + _short_type(str(part_type_value)))
	return GameManager.text("Still missing:\n", "尚缺零件：\n") + "\n".join(missing_lines)


func _space_group_available_count(group: Array) -> int:
	var count := 0
	for part_type_value in group:
		if order.has(str(part_type_value)):
			count += 1
	return count


func _space_group_installed_count(group: Array) -> int:
	var count := 0
	for part_type_value in group:
		var part_type := str(part_type_value)
		if order.has(part_type) and _installed(part_type):
			count += 1
	return count


# --- family-aware bench copy (the flat bench serves space_segmented + fast_radio,
# so it must never call itself a Newtonian reflector) --------------------------
func _flat_bench_title() -> String:
	match _family():
		"space_segmented": return GameManager.text("INFRARED OBSERVATORY ASSEMBLY", "红外天文台组装台")
		"fast_radio": return GameManager.text("RADIO TELESCOPE ASSEMBLY", "射电望远镜组装台")
	return GameManager.text("REFLECTOR ASSEMBLY BENCH", "反射镜组装台")


func _flat_bench_subtitle() -> String:
	match _family():
		"space_segmented": return GameManager.text("Select a part, then click its slot on the blueprint. Finishing does NOT start an observation.", "选择零件，再点击蓝图上的安装位。完成组装不会开始观测。")
		"fast_radio": return GameManager.text("Assemble the dish, feed cabin and signal chain. Observing happens later, from the control room.", "组装反射面、馈源舱与信号链。观测将在控制室中进行。")
	return GameManager.text("Select a part, then click its marked slot on the blueprint.", "选择零件，再点击蓝图上标记的安装位。")


func _flat_tray_title() -> String:
	match _family():
		"space_segmented": return GameManager.text("OBSERVATORY PARTS", "天文台零件")
		"fast_radio": return GameManager.text("RADIO PARTS", "射电零件")
	return GameManager.text("REFLECTOR PARTS", "反射镜零件")


func _flat_board_title() -> String:
	match _family():
		"space_segmented": return GameManager.text("INFRARED LIGHT PATH", "红外光路")
		"fast_radio": return GameManager.text("FAST ENGINEERING BLUEPRINTS", "FAST 工程蓝图")
	return GameManager.text("REFLECTOR LIGHT PATH", "反射光路")


func _update_flat_inspector(part_type: String) -> void:
	if flat_inspector_detail == null:
		return
	if part_type == "":
		flat_inspector_detail.text = GameManager.text(
			"Click a part card to select it. Its name, job and status show here.",
			"点击零件卡片进行选择。这里会显示它的名称、用途和状态。")
		flat_inspector_detail.add_theme_color_override("font_color", Color(0.62, 0.72, 0.82))
		return
	var part := _part_for_type(part_type)
	var state := GameManager.text("Installed", "已安装") if _installed(part_type) else GameManager.text("Selected - click its slot", "已选择——请点击安装位")
	flat_inspector_detail.text = "%s\n\n%s\n\n%s: %s" % [
		GameManager.dict_text(part, "name"),
		GameManager.dict_text(part, "description"),
		GameManager.text("Status", "状态"), state]
	flat_inspector_detail.add_theme_color_override("font_color", Color(0.92, 0.93, 0.86))


func _short_type(part_type: String) -> String:
	# Localised slot captions - never leak English into Chinese mode.
	match part_type:
		"primary_mirror": return GameManager.text("Primary Mirror", "主镜")
		"secondary_mirror": return GameManager.text("Secondary Mirror", "副镜")
		"detector": return GameManager.text("Detector", "探测器")
		"sunshield": return GameManager.text("Sunshield", "遮阳罩")
		"spacecraft_bus": return GameManager.text("Spacecraft Bus", "航天器平台")
		"deployable_tower": return GameManager.text("Deployable Tower", "可展开塔架")
		"deployment_hinges": return GameManager.text("Deployment Hinges", "展开铰链")
		"solar_array": return GameManager.text("Solar Array", "太阳能电池阵")
		"antenna": return GameManager.text("Antenna", "通信天线")
		"radiator": return GameManager.text("Thermal Radiator", "热辐射散热器")
		"steering_mirror": return GameManager.text("Steering Mirror", "精细转向镜")
		"tertiary_mirror": return GameManager.text("Tertiary Mirror", "第三反射镜")
		"instrument_bay": return GameManager.text("Instrument Bay", "仪器舱")
		"detector_module": return GameManager.text("Detector Module", "探测器模块")
		"nircam": return GameManager.text("NIRCam", "NIRCam 近红外相机")
		"nirspec": return GameManager.text("NIRSpec", "NIRSpec 近红外光谱仪")
		"miri": return GameManager.text("MIRI", "MIRI 中红外仪器")
		"fgs_niriss": return GameManager.text("FGS/NIRISS", "FGS/NIRISS 导星仪")
		"reflector_tube": return GameManager.text("Reflector Tube", "镜筒")
		"focuser": return GameManager.text("Focuser", "调焦座")
		"eyepiece": return GameManager.text("Eyepiece", "目镜")
		"mount": return GameManager.text("Mount", "支架")
		"tripod": return GameManager.text("Tripod", "三脚架")
		"radio_dish": return GameManager.text("Radio Dish", "反射面")
		"panel_segment": return GameManager.text("Panel Segment", "反射面板单元")
		"panel_actuator": return GameManager.text("Panel Actuator", "面板促动器")
		"cable_system": return GameManager.text("Cable System", "馈源舱缆索")
		"tension_controller": return GameManager.text("Tension Control", "缆索张力控制")
		"receiver": return GameManager.text("Receiver", "接收机")
		"feed_receiver": return GameManager.text("Feed Receiver", "馈源舱接收机")
		"rf_receiver": return GameManager.text("RF Receiver", "射频接收机")
		"signal_processor": return GameManager.text("Signal Processor", "信号处理")
		"spectrum_monitor": return GameManager.text("Spectrum Monitor", "频谱监视器")
		"timing_console": return GameManager.text("Timing Console", "脉冲计时台")
		"data_recorder": return GameManager.text("Data Recorder", "数据记录器")
		"rfi_monitor": return GameManager.text("RFI Monitor", "射频干扰监视器")
		"control_terminal": return GameManager.text("Control Terminal", "观测控制终端")
	return part_type.replace("_", " ").capitalize()


func _panel(pos: Vector2, size_value: Vector2, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 2))
	add_child(panel)
	panel.add_child(_label(title, Vector2(12, 8), Vector2(size_value.x - 24, 22), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	return panel


func _button(text_value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _style(color, GOLD, 2))
	button.add_theme_color_override("font_color", TEXT)
	return button


func _label(text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _label_to(parent: Control, text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label(text_value, pos, size_value, font_size, color, align)
	parent.add_child(label)
	return label


func _rect(pos: Vector2, size_value: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size_value
	rect.color = color
	add_child(rect)


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
