extends Control

const BG := Color(0.025, 0.040, 0.075, 0.98)
const PANEL := Color(0.045, 0.070, 0.120, 0.99)
const GOLD := Color(0.95, 0.72, 0.30)
const CYAN := Color(0.48, 0.86, 1.0)
const TEXT := Color(0.94, 0.91, 0.80)

var selected_level := 1
var status_label: Label
var selected_label: Label
# Keep this lookup local to avoid a parse-time autoload cycle with
# GameManager, which dynamically loads this guarded panel.
var GameManager: Node
var InteractionFeedback: Node


func _ready() -> void:
	GameManager = get_node_or_null("/root/GameManager")
	InteractionFeedback = get_node_or_null("/root/InteractionFeedback")
	# A direct scene/script instantiation is not an authorization path. The
	# manager has already checked the server role, and the panel checks again.
	if GameManager == null or not GameManager.can_open_developer_console():
		if GameManager != null and GameManager.developer_console == self:
			GameManager.developer_console = null
		queue_free()
		return
	selected_level = int(GameManager.progress.get("current_level", 1))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if InteractionFeedback != null:
		InteractionFeedback.page_enter(self, Vector2(0, 6))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.keycode == KEY_EQUAL):
			_close()
			accept_event()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(106, 62)
	panel.size = Vector2(812, 644)
	panel.add_theme_stylebox_override("panel", _style(PANEL, GOLD, 3))
	add_child(panel)

	panel.add_child(_label(GameManager.text("DEVELOPER CONSOLE", "开发者调试台"), Vector2(24, 18), Vector2(540, 32), 25, GOLD))
	panel.add_child(_label(GameManager.text("[=] or [Esc] closes this panel", "按 [=] 或 [Esc] 关闭调试台"), Vector2(484, 24), Vector2(300, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_RIGHT))
	panel.add_child(_label(GameManager.text("Select a lesson, then choose a test entry point.", "选择关卡，再选择要进入的测试入口。"), Vector2(24, 54), Vector2(760, 22), 14, TEXT))

	selected_label = _label("", Vector2(24, 88), Vector2(760, 42), 18, Color(1.0, 0.88, 0.54), HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(selected_label)
	_refresh_selected_label()

	panel.add_child(_label(GameManager.text("LEVEL SELECT (scroll)", "关卡选择（可滚轮滚动）"), Vector2(30, 138), Vector2(300, 20), 13, CYAN))
	# The active campaign lives in a mouse-wheel scrollable grid so removed or
	# deprecated lessons never leak into developer navigation.
	var level_scroll := ScrollContainer.new()
	level_scroll.position = Vector2(24, 162)
	level_scroll.size = Vector2(770, 180)
	level_scroll.clip_contents = true
	level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	level_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(level_scroll)
	var level_grid := Control.new()
	var level_numbers: Array = GameManager.available_level_numbers()
	var columns := 9
	var rows := int(ceil(float(level_numbers.size()) / float(columns)))
	level_grid.custom_minimum_size = Vector2(750, float(rows) * 36.0)
	level_scroll.add_child(level_grid)
	for index in range(level_numbers.size()):
		var level_number: int = level_numbers[index]
		var button := _button("L%02d" % level_number, Vector2(6 + (index % columns) * 83, float(index / columns) * 36.0), Vector2(74, 30), level_number == selected_level)
		button.pressed.connect(func() -> void:
			selected_level = level_number
			GameManager.debug_jump_to_level(selected_level, false)
			_refresh_selected_label()
			_build()
		)
		level_grid.add_child(button)
	# Auto-scroll so the selected level's row is visible.
	var selected_index: int = level_numbers.find(selected_level)
	if selected_index >= 0:
		level_scroll.set_deferred("scroll_vertical", maxi(0, int(selected_index / columns) * 36 - 72))

	panel.add_child(_label(GameManager.text("TEST ENTRY", "测试入口"), Vector2(30, 350), Vector2(220, 20), 13, CYAN))
	var hall := _action_button(GameManager.text("Hall Route", "大厅路线"), Vector2(30, 376), Vector2(232, 42), Color(0.08, 0.24, 0.22))
	hall.pressed.connect(func() -> void:
		GameManager.debug_jump_to_level(selected_level, false)
		GameManager.debug_launch("observatory")
	)
	panel.add_child(hall)
	var assembly := _action_button(GameManager.text("Assembly Test", "组装台测试"), Vector2(280, 376), Vector2(232, 42), Color(0.15, 0.18, 0.28))
	assembly.pressed.connect(func() -> void:
		GameManager.debug_jump_to_level(selected_level, false)
		GameManager.debug_launch("assembly")
	)
	panel.add_child(assembly)
	var sky := _action_button(GameManager.text("Prepared Sky Test", "观星快速测试"), Vector2(530, 376), Vector2(252, 42), Color(0.06, 0.18, 0.34))
	sky.pressed.connect(func() -> void:
		GameManager.debug_jump_to_level(selected_level, true)
		GameManager.debug_launch("sky")
	)
	panel.add_child(sky)
	var telescope := _action_button(GameManager.text("Prepared Telescope View", "望远镜视野快速测试"), Vector2(30, 428), Vector2(350, 42), Color(0.16, 0.12, 0.25))
	telescope.pressed.connect(func() -> void:
		GameManager.debug_jump_to_level(selected_level, true)
		GameManager.debug_launch("telescope")
	)
	panel.add_child(telescope)
	var prep := _action_button(GameManager.text("Prepare Equipment", "准备本关设备"), Vector2(398, 428), Vector2(250, 42), Color(0.16, 0.24, 0.12))
	prep.pressed.connect(func() -> void:
		GameManager.debug_jump_to_level(selected_level, true)
		status_label.text = _readiness_text()
		_refresh_selected_label()
	)
	panel.add_child(prep)

	var note_panel := Panel.new()
	note_panel.position = Vector2(30, 478)
	note_panel.size = Vector2(752, 96)
	note_panel.add_theme_stylebox_override("panel", _style(BG, Color(0.30, 0.48, 0.72), 1))
	panel.add_child(note_panel)
	note_panel.add_child(_label(GameManager.text("Current lesson requirements", "当前关卡要求"), Vector2(16, 10), Vector2(300, 18), 13, GOLD))
	status_label = _label(_status_text(), Vector2(16, 34), Vector2(720, 50), 13, TEXT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_panel.add_child(status_label)

	var close := _action_button(GameManager.text("Close", "关闭"), Vector2(632, 590), Vector2(150, 32), Color(0.12, 0.14, 0.20))
	close.pressed.connect(_close)
	panel.add_child(close)


func _readiness_text() -> String:
	var report: Dictionary = GameManager.prepared_readiness_report()
	if not bool(report.get("needs_telescope", true)):
		return GameManager.text(
			"Test setup ready. Naked-eye night - no rig required. Observation entry: OPEN.",
			"测试设备已就绪。肉眼观测之夜，无需装配。观测入口：已开放。")
	var main_ok: bool = bool(report.get("main_assembly", false))
	var tube_ok: bool = bool(report.get("tube_interior", false))
	var collimation: float = float(report.get("collimation", -1.0))
	var open_ok: bool = bool(report.get("observation_open", false))
	var main_line: String = GameManager.text("Main assembly: done." if main_ok else "Main assembly: MISSING %s." % ", ".join(report.get("main_missing", [])),
		"主装配：完成。" if main_ok else "主装配：缺少 %s。" % ", ".join(report.get("main_missing", [])))
	var tube_line: String = GameManager.text("Tube interior: done." if tube_ok else "Tube interior: incomplete.",
		"镜筒内部：完成。" if tube_ok else "镜筒内部：未完成。")
	var collimation_line := ""
	if collimation >= 0.0:
		collimation_line = GameManager.text("Collimation: %d%%. " % int(round(collimation)), "准直：%d%%。" % int(round(collimation)))
	var open_line: String = GameManager.text("Observation entry: OPEN." if open_ok else "Observation entry: BLOCKED.",
		"观测入口：已开放。" if open_ok else "观测入口：未开放。")
	var mount_id := str(report.get("mount_id", ""))
	var mount_line := ""
	if mount_id != "":
		var mount: Dictionary = GameManager.get_part(mount_id)
		if bool(report.get("tracking_capable", false)):
			mount_line = GameManager.text(
				" Mount: %s · motor tracking %.2fx." % [GameManager.dict_text(mount, "name"), float(report.get("tracking_rate", 0.0))],
				" 支架：%s · 电动追踪 %.2f 倍速。" % [GameManager.dict_text(mount, "name"), float(report.get("tracking_rate", 0.0))]
			)
		else:
			mount_line = GameManager.text(
				" Mount: %s · manual, hand-guided tracking only." % GameManager.dict_text(mount, "name"),
				" 支架：%s · 手动支架，只能手动跟随。" % GameManager.dict_text(mount, "name")
			)
	return GameManager.text("Test rig fully prepared. ", "当前测试设备已完整准备。") + main_line + " " + tube_line + " " + collimation_line + open_line + mount_line


func _refresh_selected_label() -> void:
	var level: Dictionary = GameManager.current_level()
	var title: String = GameManager.dict_text(level, "title")
	if selected_label != null:
		selected_label.text = GameManager.text("Selected: L%02d  %s" % [selected_level, title], "当前选择：第 %02d 关  %s" % [selected_level, title])


func _status_text() -> String:
	var level: Dictionary = GameManager.current_level()
	var target: String = GameManager.dict_text(GameManager.current_target(), "name")
	var mode: String = GameManager.current_observation_mode()
	var required: Array[String] = []
	for type_value in level.get("required_parts", []):
		required.append(str(type_value).capitalize())
	var parts: String = ", ".join(required) if not required.is_empty() else GameManager.text("No telescope parts required", "不需要望远镜零件")
	return GameManager.text("Target: %s | Mode: %s | Required: %s" % [target, mode, parts], "目标：%s | 模式：%s | 所需部件：%s" % [target, mode, parts])


func _button(text_value: String, pos: Vector2, size_value: Vector2, active: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(Color(0.12, 0.16, 0.25) if not active else Color(0.20, 0.16, 0.06), GOLD if active else Color(0.25, 0.40, 0.66), 2))
	button.add_theme_stylebox_override("hover", _style(Color(0.18, 0.26, 0.38), Color(1.0, 0.88, 0.48), 2))
	button.add_theme_color_override("font_color", TEXT)
	return button


func _action_button(text_value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = pos
	button.size = size_value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _style(color, GOLD, 2))
	button.add_theme_stylebox_override("hover", _style(color.lightened(0.12), Color(1.0, 0.90, 0.56), 2))
	button.add_theme_color_override("font_color", TEXT)
	return button


func _label(text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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


func _close() -> void:
	if GameManager.developer_console == self:
		GameManager.developer_console = null
	queue_free()
