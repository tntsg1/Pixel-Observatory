extends Control
## Main Menu: full image background + transparent interaction layer.

const BG_TEXTURE := "res://assets/main_menu/main_menu_bg_1024.png"
const SCREEN_SIZE := Vector2(1024, 768)

# Button rects are transparent hotspots over the baked full-screen menu art.
const BUTTON_RECTS := {
	"new": Rect2(337, 336, 350, 54),
	"continue": Rect2(337, 403, 350, 54),
	"settings": Rect2(337, 470, 350, 54),
	"language": Rect2(337, 537, 350, 54),
	"quit": Rect2(337, 601, 350, 54)
}

var feedback_label: Label
var button_visuals: Dictionary = {}
var settings_panel: Panel


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	_build()
	InteractionFeedback.page_enter(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	button_visuals.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = SCREEN_SIZE

	_draw_background()
	_build_hotspots()
	_build_feedback()


func _draw_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.position = Vector2.ZERO
	bg.size = SCREEN_SIZE
	bg.ignore_texture_size = true
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_hotspots() -> void:
	_add_button_feedback("new", BUTTON_RECTS["new"])
	var new_button := _transparent_button("new", BUTTON_RECTS["new"])
	new_button.pressed.connect(_on_new_game)
	add_child(new_button)

	_add_button_feedback("continue", BUTTON_RECTS["continue"])
	var continue_button := _transparent_button("continue", BUTTON_RECTS["continue"])
	continue_button.pressed.connect(_on_continue)
	add_child(continue_button)

	_add_button_feedback("settings", BUTTON_RECTS["settings"])
	var settings_button := _transparent_button("settings", BUTTON_RECTS["settings"])
	settings_button.pressed.connect(_on_settings)
	add_child(settings_button)

	_add_button_feedback("language", BUTTON_RECTS["language"])
	var language_button := _transparent_button("language", BUTTON_RECTS["language"])
	language_button.pressed.connect(_on_language)
	add_child(language_button)

	_add_button_feedback("quit", BUTTON_RECTS["quit"])
	var quit_button := _transparent_button("quit", BUTTON_RECTS["quit"])
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	add_child(quit_button)


func _build_feedback() -> void:
	feedback_label = Label.new()
	feedback_label.position = Vector2(300, 694)
	feedback_label.size = Vector2(424, 28)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.clip_text = true
	feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.48))
	feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback_label)
	
	# Language indicator
	var lang_indicator := Label.new()
	lang_indicator.position = Vector2(440, 660)
	lang_indicator.size = Vector2(144, 20)
	lang_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lang_indicator.add_theme_font_size_override("font_size", 11)
	var mode := GameManager.language_mode
	var mode_text := "English" if mode == "en" else "中文"
	lang_indicator.text = "🌐 " + mode_text
	lang_indicator.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75))
	lang_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lang_indicator)


func _on_new_game() -> void:
	GameManager.new_game()
	if GameManager.try_story_event("intro", "observatory"):
		return
	GameManager.go("observatory")


func _on_continue() -> void:
	if not _has_meaningful_save():
		_show_feedback(GameManager.text("No save found yet.", "还没有存档。"))
		return
	GameManager.go("observatory")


func _on_settings() -> void:
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.queue_free()
		settings_panel = null
		return
	settings_panel = Panel.new()
	settings_panel.position = Vector2(322, 398)
	settings_panel.size = Vector2(380, 282)
	settings_panel.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.040, 0.070, 0.98)
	style.border_color = Color(0.96, 0.72, 0.30)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	settings_panel.add_theme_stylebox_override("panel", style)
	add_child(settings_panel)
	var title := Label.new()
	title.text = GameManager.text("ACCESSIBILITY", "辅助功能")
	title.position = Vector2(20, 14)
	title.size = Vector2(340, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.54))
	settings_panel.add_child(title)
	var reduced := CheckButton.new()
	reduced.text = GameManager.text("Reduce motion", "减少动画")
	reduced.position = Vector2(28, 58)
	reduced.size = Vector2(324, 38)
	reduced.button_pressed = InteractionFeedback.is_reduced_motion()
	reduced.toggled.connect(func(enabled: bool) -> void:
		InteractionFeedback.set_reduced_motion(enabled)
		_show_feedback(GameManager.text("Reduced motion updated.", "减少动画设置已更新。"))
	)
	settings_panel.add_child(reduced)
	var highlights := CheckButton.new()
	highlights.name = "GuidanceHighlightsToggle"
	highlights.text = GameManager.text("Guidance highlights", "高光引导")
	highlights.tooltip_text = GameManager.text(
		"Show tutorial spotlights, route arrows, and highlighted destinations.",
		"显示教学聚光、路线箭头和高亮目的地。"
	)
	highlights.position = Vector2(28, 100)
	highlights.size = Vector2(324, 38)
	highlights.button_pressed = InteractionFeedback.guidance_highlights_enabled()
	highlights.toggled.connect(func(enabled: bool) -> void:
		InteractionFeedback.set_guidance_highlights_enabled(enabled)
		_show_feedback(GameManager.text(
			"Guidance highlights enabled." if enabled else "Guidance highlights disabled. Explore freely.",
			"高光引导已开启。" if enabled else "高光引导已关闭，可以自由探索。"
		))
	)
	settings_panel.add_child(highlights)
	var mobile := CheckButton.new()
	mobile.text = GameManager.text("Mobile controls", "移动端控制")
	mobile.position = Vector2(28, 142)
	mobile.size = Vector2(324, 38)
	mobile.button_pressed = TouchInput.is_mobile()
	mobile.toggled.connect(func(enabled: bool) -> void:
		TouchInput.set_mobile_mode(enabled)
		_show_feedback(GameManager.text("Mobile controls updated.", "移动端控制设置已更新。"))
	)
	settings_panel.add_child(mobile)
	var close := Button.new()
	close.text = GameManager.text("Close", "关闭")
	close.position = Vector2(110, 226)
	close.size = Vector2(160, 36)
	close.pressed.connect(func() -> void:
		if settings_panel != null:
			settings_panel.queue_free()
			settings_panel = null
	)
	settings_panel.add_child(close)
	InteractionFeedback.page_enter(settings_panel, Vector2(0, 6))


func _on_language() -> void:
	GameManager.cycle_language()
	_build()


func _has_meaningful_save() -> bool:
	if not GameManager.has_save():
		return false
	var progress: Dictionary = GameManager.progress
	if int(progress.get("current_level", 1)) > 1:
		return true
	if bool(progress.get("telescope_ready", false)):
		return true
	for key in ["completed_levels", "journal_entries", "seen_story_events", "seen_concept_briefs", "observed_objects", "badges"]:
		var values: Array = progress.get(key, [])
		if not values.is_empty():
			return true
	return false


func _show_feedback(text: String) -> void:
	if feedback_label != null:
		feedback_label.text = text


func _transparent_button(id: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(func() -> void: _set_button_feedback(id, "hover"))
	button.mouse_exited.connect(func() -> void: _set_button_feedback(id, "normal"))
	button.button_down.connect(func() -> void: _set_button_feedback(id, "pressed"))
	button.button_up.connect(func() -> void: _set_button_feedback(id, "hover"))
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button


func _add_button_feedback(id: String, rect: Rect2) -> void:
	var overlay := ColorRect.new()
	overlay.position = rect.position
	overlay.size = rect.size
	overlay.color = Color.TRANSPARENT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var frame := Control.new()
	frame.position = rect.position - Vector2(2, 2)
	frame.size = rect.size + Vector2(4, 4)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_rect(frame, Vector2.ZERO, Vector2(frame.size.x, 2), Color.TRANSPARENT)
	_rect(frame, Vector2(0, frame.size.y - 2), Vector2(frame.size.x, 2), Color.TRANSPARENT)
	_rect(frame, Vector2.ZERO, Vector2(2, frame.size.y), Color.TRANSPARENT)
	_rect(frame, Vector2(frame.size.x - 2, 0), Vector2(2, frame.size.y), Color.TRANSPARENT)

	button_visuals[id] = {"overlay": overlay, "frame": frame}


func _set_button_feedback(id: String, state: String) -> void:
	if not button_visuals.has(id):
		return
	var parts: Dictionary = button_visuals[id]
	var overlay: ColorRect = parts.get("overlay")
	var frame: Control = parts.get("frame")
	var border_color := Color.TRANSPARENT
	match state:
		"hover":
			overlay.color = Color(1.0, 0.76, 0.28, 0.12)
			border_color = Color(1.0, 0.76, 0.28, 0.92)
		"pressed":
			overlay.color = Color(0.0, 0.0, 0.0, 0.24)
			border_color = Color(1.0, 0.88, 0.50, 1.0)
		_:
			overlay.color = Color.TRANSPARENT
	for child in frame.get_children():
		if child is ColorRect:
			child.color = border_color


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _on_language_changed() -> void:
	_build()
