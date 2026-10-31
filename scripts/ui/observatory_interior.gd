extends Control

const W: float = 1024.0
const H: float = 768.0

var status_label: Label
var start_button: Button


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_rect(Vector2.ZERO, Vector2(W, H), Color(0.035, 0.045, 0.065))
	_rect(Vector2(0, 0), Vector2(W, 62), Color(0.08, 0.11, 0.17))
	_label(GameManager.text("Observatory Interior", "天文台内部"), Vector2(28, 16), Vector2(520, 30), 24)

	var back := Button.new()
	back.text = GameManager.text("Back to Base", "返回基地")
	back.position = Vector2(842, 14)
	back.size = Vector2(150, 42)
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("door")
		GameManager.go("observatory")
	)
	add_child(back)

	_draw_dome_room()
	_draw_console()
	_draw_scope_station()

	status_label = _label("", Vector2(120, 640), Vector2(784, 42), 16)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_state()


func _draw_dome_room() -> void:
	_rect(Vector2(96, 96), Vector2(832, 520), Color(0.11, 0.12, 0.15))
	_rect(Vector2(128, 128), Vector2(768, 456), Color(0.16, 0.17, 0.20))
	_rect(Vector2(164, 164), Vector2(696, 82), Color(0.045, 0.055, 0.10))
	for i in range(38):
		var star := ColorRect.new()
		star.color = Color(0.78, 0.88, 1.0, 0.9)
		star.position = Vector2(190 + fmod(float(i * 79), 630.0), 178 + fmod(float(i * 31), 52.0))
		star.size = Vector2(2, 2)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)

	_rect(Vector2(128, 552), Vector2(768, 32), Color(0.08, 0.08, 0.09))
	for x in range(160, 850, 46):
		_rect(Vector2(x, 552), Vector2(20, 32), Color(0.13, 0.13, 0.15))


func _draw_console() -> void:
	_rect(Vector2(366, 286), Vector2(292, 154), Color(0.09, 0.10, 0.12))
	_rect(Vector2(390, 304), Vector2(244, 68), Color(0.02, 0.04, 0.07))
	_rect(Vector2(412, 322), Vector2(90, 6), Color(0.52, 0.90, 0.78))
	_rect(Vector2(412, 340), Vector2(142, 6), Color(0.52, 0.70, 1.0))
	_rect(Vector2(574, 324), Vector2(26, 26), Color(0.90, 0.72, 0.30))

	start_button = Button.new()
	start_button.text = GameManager.text("Start Observation", "开始观测")
	start_button.position = Vector2(386, 382)
	start_button.size = Vector2(252, 52)
	start_button.add_theme_font_size_override("font_size", 15)
	start_button.add_theme_stylebox_override("normal", _button_style(Color(0.11, 0.18, 0.28), Color(0.84, 0.62, 0.30)))
	start_button.add_theme_stylebox_override("hover", _button_style(Color(0.16, 0.27, 0.40), Color(1.00, 0.80, 0.40)))
	start_button.add_theme_stylebox_override("pressed", _button_style(Color(0.24, 0.16, 0.08), Color(1.00, 0.80, 0.40)))
	start_button.add_theme_stylebox_override("disabled", _button_style(Color(0.08, 0.09, 0.11), Color(0.28, 0.30, 0.34)))
	start_button.pressed.connect(_start_observation)
	add_child(start_button)


func _draw_scope_station() -> void:
	_rect(Vector2(260, 448), Vector2(504, 44), Color(0.20, 0.18, 0.15))
	var scope := TextureRect.new()
	scope.texture = load("res://assets/pixel_observatory/assembled_telescope_base.png")
	scope.position = Vector2(374, 430)
	scope.size = Vector2(276, 154)
	scope.ignore_texture_size = true
	scope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scope.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scope)


func _update_state() -> void:
	if GameManager.telescope_is_ready():
		status_label.text = GameManager.text(
			"Telescope ready. Use the console to begin sky observation.",
			"望远镜已就绪。使用控制台开始观测。"
		)
		start_button.disabled = false
	else:
		status_label.text = GameManager.text(
			"The telescope is not ready yet. Assemble the core parts before entering observation mode.",
			"望远镜还没有准备好。请先组装核心部件。"
		)
		start_button.disabled = true


func _start_observation() -> void:
	if not GameManager.telescope_is_ready():
		status_label.text = GameManager.text(
			"The telescope is not ready yet. Assemble the core parts first.",
			"望远镜还没有准备好。请先组装核心部件。"
		)
		return
	# Unified observation entry: the dome console now routes through the same
	# horizon-aware gate as the open pad, instead of jumping straight to sky.
	GameManager.go_to_observation("door")


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label(text: String, pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.88))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(3)
	return style

func _on_language_changed() -> void:
	_build()
