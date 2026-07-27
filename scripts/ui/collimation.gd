extends Control

const BG := Color(0.012, 0.020, 0.042)
const GOLD := Color(0.94, 0.72, 0.30)
const CYAN := Color(0.44, 0.84, 1.0)
const GREEN := Color(0.48, 0.92, 0.58)
const TEXT := Color(0.92, 0.91, 0.84)
const COLLIMATION_SOUND_IDLE_SECONDS := 0.09
const COLLIMATION_SOUND_FADE_SECONDS := 0.025


class CollimationStarPreview extends Control:
	var alignment_error := Vector2.ZERO

	func set_alignment_error(value: Vector2) -> void:
		alignment_error = value
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var field_radius := minf(size.x, size.y) * 0.43
		draw_circle(center, field_radius, Color(0.002, 0.005, 0.012, 0.98))
		draw_arc(center, field_radius, 0.0, TAU, 96, Color(0.35, 0.72, 0.82, 0.72), 2.0)
		draw_line(center - Vector2(12, 0), center + Vector2(12, 0), Color(0.32, 0.58, 0.65, 0.22), 1.0)
		draw_line(center - Vector2(0, 12), center + Vector2(0, 12), Color(0.32, 0.58, 0.65, 0.22), 1.0)

		var severity := clampf(alignment_error.length() / 0.30, 0.0, 1.0)
		var direction := alignment_error.normalized() if alignment_error.length() > 0.001 else Vector2.RIGHT
		if severity > 0.015:
			# Misaligned reflector optics turn a point source into an asymmetric
			# coma flare. Wider, fainter lobes form the visible tail.
			var perpendicular := Vector2(-direction.y, direction.x)
			for step in range(6, 0, -1):
				var distance := float(step) * (3.0 + severity * 3.8)
				var radius := 2.0 + float(step) * severity * 1.15
				var alpha := (0.05 + (7.0 - float(step)) * 0.035) * severity
				var tail_center := center + direction * distance
				draw_circle(tail_center, radius, Color(0.55, 0.82, 1.0, alpha))
				draw_circle(tail_center + perpendicular * radius * 0.55, maxf(1.0, radius * 0.36), Color(0.95, 0.76, 0.34, alpha * 0.65))
			draw_arc(center + direction * severity * 4.0, 10.0 + severity * 8.0, -1.8, 1.8, 36, Color(0.65, 0.88, 1.0, 0.42 + severity * 0.25), 1.0)
		else:
			# Correct collimation produces a compact Airy core and symmetric rings.
			draw_arc(center, 10.0, 0.0, TAU, 40, Color(0.56, 0.92, 0.68, 0.62), 1.0)
			draw_arc(center, 17.0, 0.0, TAU, 52, Color(0.56, 0.92, 0.68, 0.24), 1.0)
		draw_circle(center, 4.5 + severity * 1.5, Color(0.98, 0.96, 0.84, 0.98))
		draw_circle(center - direction * severity * 1.5, 1.8, Color(1.0, 1.0, 1.0, 1.0))

var secondary_x := 0.18
var secondary_y := -0.14
var primary_x := -0.12
var primary_y := 0.16
var result_label: Label
var score_label: Label
var reticle: Control
var optical_axis: Line2D
var alignment_spot: Panel
var alignment_cross: Label
var reticle_rings: Array[Panel] = []
var collimation_success_played := false
var confirm_button: Button
var star_preview: CollimationStarPreview
var star_preview_label: Label
var collimation_sound_deadline := -1.0
var collimation_sound_active := false


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	set_process(false)
	_build()
	InteractionFeedback.page_enter(self)


func _process(_delta: float) -> void:
	if collimation_sound_active and Time.get_ticks_msec() / 1000.0 >= collimation_sound_deadline:
		_stop_collimation_adjust_loop()


func _exit_tree() -> void:
	_stop_collimation_adjust_loop(0.0)


func _build() -> void:
	_stop_collimation_adjust_loop()
	for child in get_children():
		child.queue_free()
	reticle_rings.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_label_to(self, GameManager.text("NEWTONIAN COLLIMATION", "牛顿镜准直"), Vector2(0, 22), Vector2(1024, 34), 27, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(self, GameManager.text("Align the optical axis. Focus cannot fix a tilted mirror.", "校正光轴。调焦不能修复倾斜的镜面。"), Vector2(0, 58), Vector2(1024, 22), 14, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var field := Panel.new()
	field.position = Vector2(78, 112)
	field.size = Vector2(560, 560)
	field.add_theme_stylebox_override("panel", _style(Color(0.02, 0.035, 0.065), GOLD, 2))
	add_child(field)
	reticle = Control.new()
	reticle.position = Vector2(30, 30)
	reticle.size = Vector2(500, 500)
	reticle.pivot_offset = reticle.size * 0.5
	field.add_child(reticle)
	_build_reticle()

	var panel := Panel.new()
	panel.position = Vector2(666, 112)
	panel.size = Vector2(292, 560)
	panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.065, 0.11), GOLD, 2))
	add_child(panel)
	_label_to(panel, GameManager.text("ALIGNMENT CONTROLS", "准直控制"), Vector2(16, 16), Vector2(260, 22), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_add_slider(panel, GameManager.text("Secondary horizontal", "副镜水平"), 60, secondary_x, func(value: float) -> void: secondary_x = value; _refresh())
	_add_slider(panel, GameManager.text("Secondary vertical", "副镜垂直"), 126, secondary_y, func(value: float) -> void: secondary_y = value; _refresh())
	_add_slider(panel, GameManager.text("Primary horizontal", "主镜水平"), 192, primary_x, func(value: float) -> void: primary_x = value; _refresh())
	_add_slider(panel, GameManager.text("Primary vertical", "主镜垂直"), 258, primary_y, func(value: float) -> void: primary_y = value; _refresh())
	score_label = _label_to(panel, "", Vector2(20, 340), Vector2(252, 28), 18, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	result_label = _label_to(panel, "", Vector2(20, 376), Vector2(252, 76), 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_button = Button.new()
	confirm_button.text = GameManager.text("Confirm Collimation", "确认准直")
	confirm_button.position = Vector2(28, 474)
	confirm_button.size = Vector2(236, 42)
	confirm_button.add_theme_font_size_override("font_size", 15)
	confirm_button.pressed.connect(_confirm)
	panel.add_child(confirm_button)
	_refresh(true)
	call_deferred("_show_collimation_tutorial")


func _show_collimation_tutorial() -> void:
	InteractionFeedback.tutorial_highlight_once(reticle, "first_collimation", GameManager.text(
		"Adjust both mirrors until the reflected light path is centered.",
		"调整两面镜子，使反射光轴逐步居中。"
	), self)


func _add_slider(parent: Control, title: String, y: float, value: float, changed: Callable) -> void:
	_label_to(parent, title, Vector2(20, y), Vector2(250, 18), 12, CYAN)
	var slider := HSlider.new()
	slider.min_value = -0.25
	slider.max_value = 0.25
	slider.step = 0.01
	slider.value = value
	slider.position = Vector2(20, y + 24)
	slider.size = Vector2(252, 18)
	# This mechanism owns a continuous ratchet loop. Suppress the generic
	# release click so stopping a drag never adds a second, late sound.
	slider.set_meta("feedback_sfx_suppressed", true)
	slider.value_changed.connect(changed)
	slider.value_changed.connect(_on_collimation_slider_value_changed)
	slider.drag_ended.connect(func(_value_changed: bool) -> void: _stop_collimation_adjust_loop())
	parent.add_child(slider)


func _on_collimation_slider_value_changed(_value: float) -> void:
	collimation_sound_deadline = Time.get_ticks_msec() / 1000.0 + COLLIMATION_SOUND_IDLE_SECONDS
	if not collimation_sound_active:
		collimation_sound_active = true
		AudioManager.start_event_loop("collimation_adjust_loop", -2.0)
	set_process(true)


func _stop_collimation_adjust_loop(fade_seconds := COLLIMATION_SOUND_FADE_SECONDS) -> void:
	if collimation_sound_active:
		AudioManager.stop_event_loop("collimation_adjust_loop", fade_seconds)
	collimation_sound_active = false
	collimation_sound_deadline = -1.0
	set_process(false)


func _score() -> float:
	var error := Vector2(secondary_x + primary_x * 0.7, secondary_y + primary_y * 0.7).length()
	return clampf(100.0 - error * 250.0, 0.0, 100.0)


func _refresh(immediate := false) -> void:
	var score := _score()
	var threshold := float(GameManager.current_level().get("collimation_threshold", 86.0))
	var aligned := score >= threshold
	var alignment_error := Vector2(secondary_x + primary_x * 0.7, secondary_y + primary_y * 0.7)
	if star_preview != null:
		star_preview.set_alignment_error(alignment_error)
	if star_preview_label != null:
		star_preview_label.text = GameManager.text(
			"SYMMETRIC AIRY DISC" if aligned else "COMA: MIRROR AXIS OFFSET",
			"对称艾里斑" if aligned else "彗差：镜面光轴偏移"
		)
		star_preview_label.add_theme_color_override("font_color", GREEN if aligned else Color(1.0, 0.72, 0.34))
	score_label.text = GameManager.text("Collimation: %.0f%%" % score, "准直：%.0f%%" % score)
	if aligned:
		result_label.text = GameManager.text("Collimation complete. The reflected light path is centered.", "准直完成。反射光轴已经居中。")
		result_label.add_theme_color_override("font_color", GREEN)
		score_label.add_theme_color_override("font_color", GREEN)
		if not collimation_success_played:
			collimation_success_played = true
			InteractionFeedback.success(reticle, "collimation_aligned")
			InteractionFeedback.success(confirm_button, "collimation_ready")
	else:
		var remaining := maxf(0.0, threshold - score)
		result_label.text = GameManager.text(
			"The optical axis needs %.0f%% more. Adjust the mirrors, not focus." % remaining,
			"光轴还差 %.0f%%。请调整镜面，而不是调焦。" % remaining
		)
		result_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.34))
		score_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32) if remaining <= 12.0 else GOLD)
	_update_reticle(aligned, immediate)


func _build_reticle() -> void:
	var center := Vector2(250, 250)
	optical_axis = Line2D.new()
	optical_axis.width = 3.0
	optical_axis.antialiased = false
	reticle.add_child(optical_axis)
	for radius in [210.0, 150.0, 90.0, 38.0]:
		var ring := Panel.new()
		ring.position = center - Vector2.ONE * radius
		ring.size = Vector2.ONE * radius * 2.0
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", _ring_style(Color(0.30, 0.68, 0.90, 0.75), int(radius)))
		reticle.add_child(ring)
		reticle_rings.append(ring)
	alignment_spot = Panel.new()
	alignment_spot.size = Vector2(36, 36)
	alignment_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment_spot.add_theme_stylebox_override("panel", _ring_style(GOLD, 18))
	reticle.add_child(alignment_spot)
	alignment_cross = _label_to(reticle, "+", Vector2.ZERO, Vector2(36, 40), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	star_preview = CollimationStarPreview.new()
	star_preview.name = "FocusedStarPreview"
	star_preview.position = Vector2(12, 12)
	star_preview.size = Vector2(148, 148)
	star_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle.add_child(star_preview)
	var preview_title := _label_to(reticle, GameManager.text("FOCUSED STAR", "聚焦恒星像"), Vector2(10, 2), Vector2(152, 18), 10, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	preview_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_preview_label = _label_to(reticle, "", Vector2(4, 153), Vector2(164, 30), 9, Color(1.0, 0.72, 0.34), HORIZONTAL_ALIGNMENT_CENTER)
	star_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	star_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_reticle(aligned: bool, immediate: bool) -> void:
	var center := Vector2(250, 250)
	var offset := Vector2(secondary_x + primary_x * 0.7, secondary_y + primary_y * 0.7) * 360.0
	var target_spot := center + offset - Vector2(18, 18)
	var target_cross := center + offset - Vector2(18, 22)
	var axis_points := PackedVector2Array([Vector2(250, 468), center + offset, Vector2(468, 250)])
	var threshold := float(GameManager.current_level().get("collimation_threshold", 86.0))
	var color := GREEN if aligned else (Color(1.0, 0.80, 0.26) if _score() >= threshold - 12.0 else CYAN)
	optical_axis.default_color = color
	for ring in reticle_rings:
		var style := ring.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = Color(color, 0.78)
	if immediate or InteractionFeedback.is_reduced_motion():
		alignment_spot.position = target_spot
		alignment_cross.position = target_cross
		optical_axis.points = axis_points
		return
	_tween_property(alignment_spot, "position", target_spot, 0.14, "spot")
	_tween_property(alignment_cross, "position", target_cross, 0.14, "cross")
	_tween_property(optical_axis, "points", axis_points, 0.14, "axis")


func _tween_property(node: Object, property: NodePath, value: Variant, duration: float, key: String) -> void:
	var meta_key := "collimation_" + key
	var old: Variant = node.get_meta(meta_key) if node.has_meta(meta_key) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := create_tween()
	if node is Node:
		tween.bind_node(node as Node)
	tween.tween_property(node, property, value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	node.set_meta(meta_key, tween)


func _confirm() -> void:
	var score := _score()
	GameManager.set_collimation_score(score)
	if GameManager.collimation_is_acceptable():
		InteractionFeedback.success(confirm_button, "collimation_complete")
		await get_tree().create_timer(0.34 if not InteractionFeedback.is_reduced_motion() else 0.08).timeout
		GameManager.update_room_guidance_for_level()
		GameManager.set_observatory_spawn("assembly")
		GameManager.go("observatory")
	else:
		InteractionFeedback.error(confirm_button)
		_refresh()


func _label_to(parent: Control, text_value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
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
	style.set_corner_radius_all(4)
	return style


func _ring_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style


func _on_language_changed() -> void:
	_build()
