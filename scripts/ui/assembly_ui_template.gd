extends RefCounted

const LEFT_PANEL_RECT := Rect2(20, 74, 300, 636)
const BLUEPRINT_PANEL_RECT := Rect2(332, 74, 436, 636)
const INSPECTOR_PANEL_RECT := Rect2(776, 74, 232, 636)
const PARTS_SCROLL_RECT := Rect2(36, 128, 268, 560)
const PARTS_LIST_SIZE := Vector2(252, 560)
const PART_CARD_SIZE := Vector2(252, 78)
const PART_CARD_STEP := 90.0
const FINISH_RECT := Rect2(792, 584, 200, 54)
const REASSEMBLE_RECT := Rect2(792, 648, 98, 34)
const BACK_RECT := Rect2(894, 648, 98, 34)


# Persistent "Assembly Hints ON/OFF" toggle, bottom-left, shared by every
# bench. on_change is called after the setting is saved so the bench can
# rebuild its hint chrome.
static func add_hints_toggle(parent: Control, game_manager: Node, on_change: Callable) -> Button:
	var enabled: bool = game_manager.assembly_hints_enabled()
	var toggle := Button.new()
	toggle.text = game_manager.text("Assembly Hints: ON", "装配提示：开启") if enabled else game_manager.text("Assembly Hints: OFF", "装配提示：关闭")
	toggle.position = Vector2(24, 722)
	toggle.size = Vector2(212, 32)
	toggle.add_theme_font_size_override("font_size", 12)
	toggle.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.10) if enabled else Color(0.10, 0.10, 0.12)
	style.border_color = Color(0.46, 0.90, 0.58) if enabled else Color(0.45, 0.50, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	toggle.add_theme_stylebox_override("normal", style)
	toggle.add_theme_stylebox_override("hover", style)
	toggle.add_theme_stylebox_override("pressed", style)
	toggle.pressed.connect(func() -> void:
		game_manager.set_assembly_hints(not game_manager.assembly_hints_enabled())
		on_change.call()
	)
	parent.add_child(toggle)
	return toggle


static func add_title_bar(parent: Control, title: String, subtitle: String = "") -> void:
	_add_rect(parent, Rect2(0, 0, 1024, 58), Color(0.030, 0.045, 0.085, 0.96))
	_add_rect(parent, Rect2(18, 12, 988, 3), Color(0.78, 0.56, 0.28))
	_add_rect(parent, Rect2(18, 52, 988, 3), Color(0.17, 0.25, 0.40))
	var title_label := _add_label(parent, title, Vector2(216, 13), Vector2(592, 30), 24, Color(0.96, 0.95, 0.90))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if subtitle != "":
		var subtitle_label := _add_label(parent, subtitle, Vector2(708, 16), Vector2(286, 30), 11, Color(0.76, 0.84, 0.88))
		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


static func add_titled_panel(parent: Control, rect: Rect2, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(Color(0.040, 0.060, 0.105, 0.98), Color(0.78, 0.56, 0.28), 2, 4))
	parent.add_child(panel)
	_add_rect(parent, Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 34)), Color(0.30, 0.20, 0.10, 0.92))
	var heading := _add_label(parent, title, rect.position + Vector2(16, 8), Vector2(rect.size.x - 32, 26), 16, Color(0.96, 0.93, 0.84))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


static func add_blueprint_panel(parent: Control, title: String) -> Panel:
	var rect := BLUEPRINT_PANEL_RECT
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(Color(0.020, 0.045, 0.095, 0.98), Color(0.78, 0.56, 0.28), 2, 4))
	parent.add_child(panel)
	var nameplate := Panel.new()
	nameplate.position = Vector2(452, 80)
	nameplate.size = Vector2(196, 34)
	nameplate.add_theme_stylebox_override("panel", _style(Color(0.10, 0.13, 0.075, 0.96), Color(0.82, 0.62, 0.30), 2, 4))
	parent.add_child(nameplate)
	var heading := _add_label(parent, title, Vector2(452, 88), Vector2(196, 24), 16, Color(0.96, 0.82, 0.42))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


static func add_inspector_shell(
	parent: Control,
	heading_text: String,
	finish_text: String,
	reassemble_text: String,
	back_text: String,
	on_finish: Callable,
	on_reassemble: Callable,
	on_back: Callable
) -> Dictionary:
	add_titled_panel(parent, INSPECTOR_PANEL_RECT, heading_text)
	var status_box := Panel.new()
	status_box.position = Vector2(792, 128)
	status_box.size = Vector2(200, 56)
	status_box.add_theme_stylebox_override("panel", _style(Color(0.020, 0.045, 0.030, 0.96), Color(0.30, 0.55, 0.34), 2, 4))
	parent.add_child(status_box)
	var status := _add_label(parent, GameManager.text("ASSEMBLING", "组装中"), Vector2(812, 142), Vector2(128, 28), 18, Color(0.95, 0.78, 0.35))
	var dot := Panel.new()
	dot.position = Vector2(946, 146)
	dot.size = Vector2(24, 24)
	dot.add_theme_stylebox_override("panel", _style(Color(0.95, 0.78, 0.35, 0.14), Color(0.95, 0.78, 0.35), 3, 12))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(dot)
	var feedback := _add_label(parent, "", Vector2(792, 192), Vector2(200, 76), 11, Color(0.82, 0.88, 0.82))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var stats := Control.new()
	stats.position = Vector2(792, 282)
	stats.size = Vector2(200, 274)
	parent.add_child(stats)
	var finish := _add_button(parent, finish_text, FINISH_RECT, on_finish)
	finish.add_theme_font_size_override("font_size", 17)
	var reassemble := _add_button(parent, reassemble_text, REASSEMBLE_RECT, on_reassemble)
	var back := _add_button(parent, back_text, BACK_RECT, on_back)
	return {
		"status": status,
		"ready_dot": dot,
		"feedback": feedback,
		"stats": stats,
		"finish": finish,
		"reassemble": reassemble,
		"back": back,
	}


static func add_part_card(
	parent: Control,
	position: Vector2,
	name_text: String,
	role_text: String,
	status_text: String,
	texture: Texture2D,
	installed: bool,
	selected: bool,
	on_pressed: Callable
) -> Panel:
	var background := Color(0.155, 0.172, 0.180)
	var border := Color(0.30, 0.38, 0.42)
	if installed:
		background = Color(0.112, 0.128, 0.132)
		border = Color(0.34, 0.56, 0.42)
	if selected:
		background = Color(0.185, 0.245, 0.285)
		border = Color(0.82, 0.72, 0.34)

	var card := Panel.new()
	card.position = position
	card.size = PART_CARD_SIZE
	card.add_theme_stylebox_override("panel", _style(background, border, 2, 4))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)

	var icon_box := Panel.new()
	icon_box.position = position + Vector2(10, 11)
	icon_box.size = Vector2(56, 56)
	icon_box.add_theme_stylebox_override("panel", _style(Color(0.070, 0.085, 0.095), Color(0.22, 0.30, 0.34), 1, 3))
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.clip_contents = true
	parent.add_child(icon_box)
	if texture != null:
		var native_size := texture.get_size()
		var available := Vector2(50, 50)
		var scale_factor := minf(available.x / native_size.x, available.y / native_size.y)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2.ZERO
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = texture
		icon.position = position + Vector2(13, 14)
		icon.size = native_size * scale_factor
		icon.modulate = Color(1, 1, 1, 0.72 if installed else 1.0)
		parent.add_child(icon)

	_add_label(parent, name_text, position + Vector2(76, 8), Vector2(160, 20), 10 if name_text.length() > 28 else 12, Color(0.94, 0.95, 0.92))
	_add_label(parent, role_text, position + Vector2(76, 29), Vector2(160, 18), 10, Color(0.72, 0.82, 0.86))
	_add_label(parent, status_text, position + Vector2(76, 51), Vector2(138, 18), 11, Color(0.58, 0.86, 0.62) if installed else Color(0.86, 0.78, 0.48))
	if installed:
		var check := _add_label(parent, "OK", position + Vector2(216, 51), Vector2(27, 18), 11, Color(0.66, 0.94, 0.70))
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var hit := Button.new()
	hit.position = position
	hit.size = PART_CARD_SIZE
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(on_pressed)
	parent.add_child(hit)
	return card


static func add_slot_hit_target(parent: Control, rect: Rect2, on_pressed: Callable) -> Button:
	var hit := Button.new()
	hit.position = rect.position
	hit.size = rect.size
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.pressed.connect(on_pressed)
	parent.add_child(hit)
	# Soft gold hover glow: clickable blueprint slots answer the cursor with
	# a gentle fade instead of staying inert until clicked.
	var glow := Panel.new()
	glow.position = rect.position - Vector2(3, 3)
	glow.size = rect.size + Vector2(6, 6)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(1.0, 0.82, 0.36, 0.06)
	glow_style.border_color = Color(1.0, 0.82, 0.36, 0.85)
	glow_style.set_border_width_all(2)
	glow_style.set_corner_radius_all(4)
	glow.add_theme_stylebox_override("panel", glow_style)
	glow.modulate.a = 0.0
	parent.add_child(glow)
	hit.mouse_entered.connect(func() -> void:
		if is_instance_valid(glow):
			var feedback: Node = hit.get_node_or_null("/root/InteractionFeedback")
			var quick: bool = feedback != null and bool(feedback.call("is_reduced_motion"))
			var tween := glow.create_tween()
			tween.tween_property(glow, "modulate:a", 1.0, 0.05 if quick else 0.14)
	)
	hit.mouse_exited.connect(func() -> void:
		if is_instance_valid(glow):
			var tween := glow.create_tween()
			tween.tween_property(glow, "modulate:a", 0.0, 0.18)
	)
	return hit


static func _add_label(parent: Control, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func _add_button(parent: Control, text: String, rect: Rect2, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	button.add_theme_stylebox_override("normal", _style(Color(0.10, 0.14, 0.22), Color(0.78, 0.56, 0.28), 2, 4))
	var hover := button.get_theme_stylebox("normal").duplicate()
	hover.bg_color = Color(0.15, 0.20, 0.30)
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button


static func _add_rect(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
