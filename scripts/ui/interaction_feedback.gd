extends Node

signal reduced_motion_changed(enabled: bool)
signal guidance_highlights_changed(enabled: bool)
signal feedback_sfx_requested(event_name: String)

const CONFIG_PATH := "user://accessibility.cfg"
const GOLD := Color(1.0, 0.78, 0.32, 1.0)
const CYAN := Color(0.38, 0.84, 1.0, 1.0)
const GREEN := Color(0.42, 0.96, 0.58, 1.0)
const ERROR := Color(1.0, 0.42, 0.32, 1.0)

var reduced_motion := false
var guidance_highlights := true
var _tutorial_seen: Dictionary = {}
var _bound_buttons: Array[BaseButton] = []
var _bound_sliders: Array[Slider] = []
var _disabled_refresh_elapsed := 0.0


func _ready() -> void:
	_load_settings()
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_signal("tutorial_assistance_changed"):
		gm.tutorial_assistance_changed.connect(_on_tutorial_assistance_changed)
	get_tree().node_added.connect(_on_node_added)
	_bind_existing_buttons(get_tree().root)


func _process(delta: float) -> void:
	_disabled_refresh_elapsed += delta
	if _disabled_refresh_elapsed < 0.2:
		return
	_disabled_refresh_elapsed = 0.0
	var live_buttons: Array[BaseButton] = []
	for button in _bound_buttons:
		if button != null and is_instance_valid(button):
			_apply_disabled_visual(button)
			live_buttons.append(button)
	_bound_buttons = live_buttons
	var live_sliders: Array[Slider] = []
	for slider in _bound_sliders:
		if slider != null and is_instance_valid(slider):
			live_sliders.append(slider)
	_bound_sliders = live_sliders


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))
	guidance_highlights = bool(config.get_value("accessibility", "guidance_highlights", true))
	var seen_value: Variant = config.get_value("tutorials", "seen", {})
	if seen_value is Dictionary:
		_tutorial_seen = seen_value


func set_reduced_motion(enabled: bool) -> void:
	if reduced_motion == enabled:
		return
	reduced_motion = enabled
	_save_settings()
	reduced_motion_changed.emit(enabled)


func is_reduced_motion() -> bool:
	return reduced_motion


func set_guidance_highlights_enabled(enabled: bool) -> void:
	if guidance_highlights == enabled:
		return
	guidance_highlights = enabled
	_save_settings()
	if not enabled and is_inside_tree():
		for overlay in get_tree().get_nodes_in_group("guidance_highlight"):
			if overlay != null and is_instance_valid(overlay):
				overlay.queue_free()
	guidance_highlights_changed.emit(enabled)


func guidance_highlights_enabled() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm != null and gm.has_method("tutorial_assistance_mode") and str(gm.tutorial_assistance_mode()) == "free":
		return false
	return guidance_highlights


func _on_tutorial_assistance_changed(mode: String) -> void:
	if mode != "free" or not is_inside_tree():
		return
	for overlay in get_tree().get_nodes_in_group("guidance_highlight"):
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	config.set_value("accessibility", "guidance_highlights", guidance_highlights)
	config.set_value("tutorials", "seen", _tutorial_seen)
	config.save(CONFIG_PATH)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		# Deferred by INSTANCE ID: rebuilt screens free buttons within the
		# same frame, and a typed deferred bind_button(freed Button) throws
		# "Cannot convert argument" every time. instance_from_id() simply
		# returns null for freed nodes.
		call_deferred("_bind_button_deferred", node.get_instance_id())
	elif node is Slider:
		call_deferred("_bind_slider_deferred", node.get_instance_id())


func _bind_button_deferred(button_id: int) -> void:
	var node: Object = instance_from_id(button_id)
	if node is BaseButton and is_instance_valid(node):
		bind_button(node as BaseButton)


func _bind_slider_deferred(slider_id: int) -> void:
	var node: Object = instance_from_id(slider_id)
	if node is Slider and is_instance_valid(node):
		bind_slider(node as Slider)


func _bind_existing_buttons(node: Node) -> void:
	if node is BaseButton:
		bind_button(node as BaseButton)
	elif node is Slider:
		bind_slider(node as Slider)
	for child in node.get_children():
		_bind_existing_buttons(child)


func bind_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button) or bool(button.get_meta("feedback_bound", false)):
		return
	button.set_meta("feedback_bound", true)
	button.set_meta("feedback_pending", false)
	button.set_meta("feedback_disabled_state", not button.disabled)
	button.set_meta("feedback_selected", button.toggle_mode and button.button_pressed)
	var base_modulate := button.modulate
	# Invisible hit targets still need visible child feedback; their own style
	# remains empty, so normalizing alpha here reveals only the feedback layers.
	if base_modulate.a < 0.05:
		base_modulate = Color.WHITE
	button.set_meta("feedback_base_modulate", base_modulate)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pivot_offset = button.size * 0.5
	var shadow := Panel.new()
	shadow.name = "InteractionFeedbackShadow"
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.position += Vector2(0, 3)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.modulate.a = 0.0
	shadow.z_index = -1
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0.01, 0.02, 0.04, 0.72)
	shadow_style.border_color = Color(0.92, 0.61, 0.19, 0.24)
	shadow_style.set_border_width_all(1)
	shadow_style.set_corner_radius_all(4)
	shadow.add_theme_stylebox_override("panel", shadow_style)
	button.add_child(shadow)
	var border := Panel.new()
	border.name = "InteractionFeedbackBorder"
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.modulate.a = 0.0
	border.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", style)
	button.add_child(border)
	var shine := ColorRect.new()
	shine.name = "InteractionFeedbackShine"
	shine.anchor_right = 1.0
	shine.offset_left = 5.0
	shine.offset_right = -5.0
	shine.offset_top = 2.0
	shine.offset_bottom = 4.0
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.color = Color(1.0, 0.86, 0.48, 0.0)
	shine.z_index = 21
	button.add_child(shine)
	_bound_buttons.append(button)
	button.mouse_entered.connect(_button_hover.bind(button, border, true))
	button.mouse_exited.connect(_button_hover.bind(button, border, false))
	button.focus_entered.connect(_button_focus.bind(button, border, true))
	button.focus_exited.connect(_button_focus.bind(button, border, false))
	button.button_down.connect(_button_down.bind(button, border))
	button.button_up.connect(_button_up.bind(button, border))
	button.pressed.connect(_button_complete.bind(button, border))
	button.gui_input.connect(_button_gui_input.bind(button))
	if button.toggle_mode:
		button.toggled.connect(_button_toggled.bind(button))
	_apply_disabled_visual(button)


func bind_slider(slider: Slider) -> void:
	if slider == null or not is_instance_valid(slider) or bool(slider.get_meta("feedback_bound", false)):
		return
	slider.set_meta("feedback_bound", true)
	slider.pivot_offset = slider.size * 0.5
	var border := _feedback_border(slider, CYAN)
	border.modulate.a = 0.0
	slider.value_changed.connect(_slider_value_changed.bind(slider, border))
	slider.drag_started.connect(_slider_drag_started.bind(slider, border))
	slider.drag_ended.connect(_slider_drag_ended.bind(slider, border))
	slider.focus_entered.connect(func() -> void:
		_tween_property(border, "modulate:a", 0.58, 0.12, "feedback_slider_border")
	)
	slider.focus_exited.connect(func() -> void:
		_tween_property(border, "modulate:a", 0.0, 0.16, "feedback_slider_border")
	)
	_bound_sliders.append(slider)


func _apply_disabled_visual(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	var previous := bool(button.get_meta("feedback_disabled_state", not button.disabled))
	if previous == button.disabled:
		return
	button.set_meta("feedback_disabled_state", button.disabled)
	button.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if button.disabled else Control.CURSOR_POINTING_HAND
	var base: Color = button.get_meta("feedback_base_modulate", Color.WHITE)
	var target := base * Color(0.58, 0.60, 0.64, 0.62) if button.disabled else base
	_tween_property(button, "modulate", target, 0.14 if not reduced_motion else 0.05, "feedback_disabled")
	if button.disabled:
		button.scale = Vector2.ONE
		var border := button.get_node_or_null("InteractionFeedbackBorder") as Panel
		if border != null:
			_tween_property(border, "modulate:a", 0.0, 0.08, "feedback_border")


func _button_hover(button: BaseButton, border: Panel, entering: bool) -> void:
	button.set_meta("feedback_pointer_hover", entering)
	if button.disabled:
		_apply_disabled_visual(button)
		return
	_set_button_hover_visual(button, border, entering or button.has_focus())


func _button_focus(button: BaseButton, border: Panel, focused: bool) -> void:
	if button.disabled:
		return
	_set_button_hover_visual(button, border, focused or bool(button.get_meta("feedback_pointer_hover", false)))


func _set_button_hover_visual(button: BaseButton, border: Panel, active: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var duration := 0.14 if not reduced_motion else 0.06
	var selected := bool(button.get_meta("feedback_selected", false))
	var base: Color = button.get_meta("feedback_base_modulate", Color.WHITE)
	var hover_tint := Color(1.08, 1.06, 1.0, 1.0)
	_tween_property(button, "modulate", base * hover_tint if active else base, duration, "feedback_hover")
	if not reduced_motion:
		_tween_property(button, "scale", Vector2.ONE * (1.018 if active else 1.0), duration, "feedback_hover_scale", Tween.TRANS_BACK, Tween.EASE_OUT)
	_tween_property(border, "modulate:a", 0.62 if active else (0.72 if selected else 0.0), duration, "feedback_border")
	var shadow := button.get_node_or_null("InteractionFeedbackShadow") as Panel
	if shadow != null:
		_tween_property(shadow, "modulate:a", 0.72 if active else 0.0, duration, "feedback_shadow")
	var shine := button.get_node_or_null("InteractionFeedbackShine") as ColorRect
	if shine != null:
		_tween_property(shine, "color:a", 0.52 if active else 0.0, duration, "feedback_shine")


func _button_down(button: BaseButton, border: Panel) -> void:
	if button.disabled:
		return
	button.pivot_offset = button.size * 0.5
	_tween_property(border, "modulate:a", 1.0, 0.06, "feedback_border")
	if reduced_motion:
		return
	# A real key has travel. Four percent is still restrained, but reads
	# immediately even on a busy pixel-art screen.
	_tween_property(button, "scale", Vector2.ONE * 0.955, 0.065, "feedback_press", Tween.TRANS_QUAD, Tween.EASE_OUT)
	var shadow := button.get_node_or_null("InteractionFeedbackShadow") as Panel
	if shadow != null:
		_tween_property(shadow, "position:y", 0.0, 0.065, "feedback_shadow_press", Tween.TRANS_QUAD, Tween.EASE_OUT)
	var shine := button.get_node_or_null("InteractionFeedbackShine") as ColorRect
	if shine != null:
		_tween_property(shine, "color:a", 0.86, 0.055, "feedback_shine")


func _button_up(button: BaseButton, border: Panel) -> void:
	if button.disabled:
		return
	var active := button.is_hovered() or button.has_focus()
	var selected := bool(button.get_meta("feedback_selected", false))
	var target_scale := Vector2.ONE * (1.018 if active and not reduced_motion else 1.0)
	_tween_property(button, "scale", target_scale, 0.13 if not reduced_motion else 0.04, "feedback_press", Tween.TRANS_BACK, Tween.EASE_OUT)
	_tween_property(border, "modulate:a", 0.62 if active else (0.72 if selected else 0.0), 0.12, "feedback_border")
	var shadow := button.get_node_or_null("InteractionFeedbackShadow") as Panel
	if shadow != null:
		_tween_property(shadow, "position:y", 3.0, 0.11, "feedback_shadow_press", Tween.TRANS_BACK, Tween.EASE_OUT)


func _button_complete(button: BaseButton, border: Panel) -> void:
	if button.disabled:
		return
	_spawn_click_echo(button)
	_spawn_click_sweep(button)
	flash_border(button, GOLD, 0.48, border)
	feedback_sfx_requested.emit("ui_confirm")


func _button_toggled(pressed: bool, button: BaseButton) -> void:
	selection(button, pressed, GOLD)


func _button_gui_input(event: InputEvent, button: BaseButton) -> void:
	if not button.disabled:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			error(button)


func _slider_value_changed(_value: float, slider: Slider, border: Panel) -> void:
	if reduced_motion:
		border.modulate.a = maxf(border.modulate.a, 0.36)
		return
	slider.pivot_offset = slider.size * 0.5
	var tween := _replace_tween(slider, "feedback_slider_value")
	tween.tween_property(slider, "scale", Vector2(1.0, 1.045), 0.055).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slider, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_property(border, "modulate:a", 0.52, 0.08, "feedback_slider_border")


func _slider_drag_started(slider: Slider, border: Panel) -> void:
	_tween_property(border, "modulate:a", 0.82, 0.10, "feedback_slider_border")
	if not reduced_motion:
		_tween_property(slider, "scale", Vector2(1.012, 1.06), 0.10, "feedback_slider_drag", Tween.TRANS_BACK, Tween.EASE_OUT)


func _slider_drag_ended(value_changed: bool, slider: Slider, border: Panel) -> void:
	_tween_property(slider, "scale", Vector2.ONE, 0.14 if not reduced_motion else 0.04, "feedback_slider_drag", Tween.TRANS_BACK, Tween.EASE_OUT)
	if value_changed:
		flash_border(slider, CYAN, 0.28, border)
		feedback_sfx_requested.emit("ui_adjust")
	else:
		_tween_property(border, "modulate:a", 0.0, 0.12, "feedback_slider_border")


func selection(control: Control, selected: bool, color: Color = GOLD, show_border := true, event_name := "ui_select") -> void:
	if control == null or not is_instance_valid(control):
		return
	var initialized := bool(control.get_meta("feedback_selection_initialized", false))
	var previous := bool(control.get_meta("feedback_selected", false))
	if initialized and previous == selected:
		return
	control.set_meta("feedback_selection_initialized", true)
	control.set_meta("feedback_selected", selected)
	control.set_meta("feedback_selected_color", color)
	var border: Panel
	if show_border:
		border = control.get_node_or_null("InteractionFeedbackBorder") as Panel
		if border == null:
			border = _feedback_border(control, color)
		var style := border.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.border_color = color
		border.modulate.a = 0.72 if selected else 0.0
	if selected:
		control.pivot_offset = control.size * 0.5
		if not reduced_motion:
			var tween := _replace_tween(control, "feedback_selection")
			tween.tween_property(control, "scale", Vector2.ONE * 1.028, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(control, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if show_border and border != null:
			flash_border(control, color, 0.34, border)
		if initialized:
			feedback_sfx_requested.emit(event_name)
	elif initialized and not selected:
		_tween_property(control, "scale", Vector2.ONE, 0.12 if not reduced_motion else 0.04, "feedback_selection", Tween.TRANS_QUAD, Tween.EASE_OUT)


func _spawn_click_echo(button: BaseButton) -> void:
	var echo := Panel.new()
	echo.name = "InteractionFeedbackClickEcho"
	echo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	echo.pivot_offset = button.size * 0.5
	echo.scale = Vector2.ONE * 0.92
	echo.modulate.a = 0.88
	echo.z_index = 24
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	echo.add_theme_stylebox_override("panel", style)
	button.add_child(echo)
	var tween := create_tween().bind_node(echo).set_parallel(true)
	tween.tween_property(echo, "scale", Vector2.ONE * 1.055, 0.22 if not reduced_motion else 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(echo, "modulate:a", 0.0, 0.22 if not reduced_motion else 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(echo.queue_free)


func _spawn_click_sweep(button: BaseButton) -> void:
	# A short warm scan across the control confirms the command without a
	# large flash or modal interruption. It is clipped by the button bounds.
	var clip := Control.new()
	clip.name = "InteractionFeedbackClickSweepClip"
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.z_index = 23
	button.add_child(clip)
	var sweep := ColorRect.new()
	sweep.name = "InteractionFeedbackClickSweep"
	sweep.position = Vector2(-button.size.x * 0.34, 2.0)
	sweep.size = Vector2(maxf(18.0, button.size.x * 0.22), maxf(1.0, button.size.y - 4.0))
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.color = Color(1.0, 0.88, 0.46, 0.34)
	clip.add_child(sweep)
	if reduced_motion:
		sweep.modulate.a = 0.0
		clip.queue_free()
		return
	var tween := create_tween().bind_node(sweep).set_parallel(true)
	tween.tween_property(sweep, "position:x", button.size.x * 1.08, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sweep, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(clip.queue_free)


func flash_border(control: Control, color: Color = GOLD, duration := 0.42, existing_border: Panel = null) -> void:
	if control == null or not is_instance_valid(control):
		return
	var border := existing_border
	if border == null:
		border = _feedback_border(control, color)
	var style := border.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = color
	border.modulate.a = 1.0
	var tween := _replace_tween(border, "feedback_flash")
	var rest_alpha := 0.72 if bool(control.get_meta("feedback_selected", false)) else 0.12
	tween.tween_property(border, "modulate:a", rest_alpha, duration if not reduced_motion else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_restore_selected_border.bind(control, border))


func _restore_selected_border(control: Control, border: Panel) -> void:
	if control == null or border == null or not is_instance_valid(control) or not is_instance_valid(border):
		return
	if not bool(control.get_meta("feedback_selected", false)):
		return
	var color: Color = control.get_meta("feedback_selected_color", GOLD)
	var style := border.get_theme_stylebox("panel") as StyleBoxFlat
	if style != null:
		style.border_color = color
	border.modulate.a = 0.72


func success(control: Control, event_name := "success") -> void:
	if control == null or not is_instance_valid(control):
		return
	flash_border(control, GREEN, 0.48)
	if not reduced_motion:
		control.pivot_offset = control.size * 0.5
		var tween := _replace_tween(control, "feedback_success")
		tween.tween_property(control, "scale", Vector2.ONE * 1.035, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	feedback_sfx_requested.emit(event_name)


func error(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	flash_border(control, ERROR, 0.28)
	feedback_sfx_requested.emit("ui_error")
	if reduced_motion:
		return
	control.pivot_offset = control.size * 0.5
	var origin := control.rotation
	var tween := _replace_tween(control, "feedback_error")
	for offset in [-0.018, 0.018, -0.012, 0.012, 0.0]:
		tween.tween_property(control, "rotation", origin + offset, 0.045)


func pulse(control: Control, color := CYAN, duration := 0.5) -> void:
	if control == null or not is_instance_valid(control):
		return
	if reduced_motion:
		flash_border(control, color, 0.14)
		return
	var tween := _replace_tween(control, "feedback_pulse")
	var start := control.modulate
	tween.tween_property(control, "modulate", color, duration * 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "modulate", start, duration * 0.55).set_trans(Tween.TRANS_SINE)


# Text swap with a soft fade-in of the NEW text. Safe to call every frame:
# identical text is a no-op, so only real changes animate.
func crossfade_text(label: Label, new_text: String) -> void:
	if label == null or not is_instance_valid(label) or label.text == new_text:
		return
	label.text = new_text
	if reduced_motion:
		return
	label.modulate.a = 0.18
	var tween := _replace_tween(label, "feedback_textswap")
	tween.tween_property(label, "modulate:a", 1.0, 0.18)


func page_enter(control: Control, from_offset := Vector2(0, 10)) -> void:
	if control == null or not is_instance_valid(control):
		return
	var final_position := control.position
	control.modulate.a = 0.0
	if not reduced_motion:
		control.position = final_position + from_offset
	var tween := _replace_tween(control, "feedback_page")
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.20 if not reduced_motion else 0.08)
	if not reduced_motion:
		tween.tween_property(control, "position", final_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func fade_then(control: Control, callback: Callable) -> void:
	if control == null or not is_instance_valid(control):
		callback.call()
		return
	var tween := _replace_tween(control, "feedback_page_exit")
	tween.tween_property(control, "modulate:a", 0.0, 0.16 if not reduced_motion else 0.06)
	tween.tween_callback(callback)


func tween_rotation(control: Control, target: float, duration := 0.12) -> void:
	if control == null or not is_instance_valid(control):
		return
	_tween_property(control, "rotation", target, 0.04 if reduced_motion else duration, "feedback_rotation", Tween.TRANS_QUAD, Tween.EASE_OUT)


func tween_size(control: Control, target: Vector2, duration := 0.16) -> void:
	if control == null or not is_instance_valid(control):
		return
	_tween_property(control, "size", target, 0.05 if reduced_motion else duration, "feedback_size", Tween.TRANS_QUAD, Tween.EASE_OUT)


func fly_texture(texture: Texture2D, from_global: Rect2, to_global: Rect2, parent: Control) -> Tween:
	var icon := TextureRect.new()
	icon.name = "InstallingPartFeedback"
	icon.custom_minimum_size = Vector2.ZERO
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = texture
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = 850
	parent.add_child(icon)
	var parent_origin := parent.get_global_rect().position
	icon.position = from_global.position - parent_origin
	icon.size = from_global.size
	icon.pivot_offset = icon.size * 0.5
	icon.modulate = Color(1.08, 1.04, 0.92, 0.94)
	var target_position := to_global.position - parent_origin
	var tween := create_tween().bind_node(icon)
	if reduced_motion:
		tween.set_parallel(true)
		tween.tween_property(icon, "position", target_position, 0.08)
		tween.tween_property(icon, "size", to_global.size, 0.08)
	else:
		tween.set_parallel(true)
		tween.tween_property(icon, "position", target_position, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "size", to_global.size, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(icon, "rotation", 0.025, 0.12).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_property(icon, "scale", Vector2.ONE * 1.04, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.08)
	tween.tween_property(icon, "modulate:a", 0.0, 0.06)
	tween.finished.connect(icon.queue_free)
	return tween


func mechanical_snap(card: Control, slot: Control, event_name := "assembly_part_installed") -> void:
	if card != null and is_instance_valid(card):
		flash_border(card, GOLD, 0.34)
		if not reduced_motion:
			card.pivot_offset = card.size * 0.5
			var card_tween := _replace_tween(card, "feedback_part_lock")
			card_tween.tween_property(card, "scale", Vector2.ONE * 0.985, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			card_tween.tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if slot == null or not is_instance_valid(slot):
		return
	flash_border(slot, CYAN, 0.46)
	slot.pivot_offset = slot.size * 0.5
	if not reduced_motion:
		var snap_tween := _replace_tween(slot, "feedback_mechanical_snap")
		slot.scale = Vector2.ONE * 0.94
		snap_tween.tween_property(slot, "scale", Vector2.ONE * 1.025, 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		snap_tween.tween_property(slot, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_alignment_pulse(slot)
	feedback_sfx_requested.emit(event_name)


func _alignment_pulse(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var pulse_frame := Panel.new()
	pulse_frame.name = "OperationChainAlignmentPulse"
	pulse_frame.position = -Vector2(6, 6)
	pulse_frame.size = control.size + Vector2(12, 12)
	pulse_frame.pivot_offset = pulse_frame.size * 0.5
	pulse_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse_frame.z_index = 86
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = CYAN
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	pulse_frame.add_theme_stylebox_override("panel", style)
	control.add_child(pulse_frame)
	if reduced_motion:
		pulse_frame.modulate.a = 0.0
		pulse_frame.queue_free()
		return
	pulse_frame.scale = Vector2.ONE * 0.82
	var tween := create_tween().bind_node(pulse_frame).set_parallel(true)
	tween.tween_property(pulse_frame, "scale", Vector2.ONE * 1.18, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(pulse_frame, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(pulse_frame.queue_free)


func operation_chain(
	parent: Control,
	action_text: String,
	effect_text: String,
	reveal_text: String,
	next_control: Control = null,
	accent: Color = CYAN,
	duration := 2.8
) -> Control:
	if parent == null or not is_instance_valid(parent):
		return null
	var existing := parent.get_node_or_null("OperationChainFeedback")
	if existing != null:
		parent.remove_child(existing)
		existing.queue_free()
	var panel := Panel.new()
	panel.name = "OperationChainFeedback"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 840
	var parent_size := parent.size
	if parent_size.x < 1.0 or parent_size.y < 1.0:
		parent_size = parent.get_viewport_rect().size
	var compact := parent_size.x < 560.0
	var panel_width := clampf(parent_size.x - 32.0, 320.0, 820.0)
	var panel_height := 112.0 if compact else 66.0
	panel.position = Vector2((parent_size.x - panel_width) * 0.5, maxf(8.0, parent_size.y - panel_height - 12.0))
	panel.size = Vector2(panel_width, panel_height)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.060, 0.97)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var steps := [
		[GameManager.text("ACTION", "操作结果"), action_text],
		[GameManager.text("PHYSICAL EFFECT", "系统状态"), effect_text],
		[GameManager.text("NOW VISIBLE", "已解锁"), reveal_text],
	]
	for index in range(steps.size()):
		var cell := Label.new()
		var heading: String = str(steps[index][0])
		var body: String = str(steps[index][1])
		cell.text = heading + "\n" + body
		cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_font_size_override("font_size", 11 if not compact else 10)
		cell.add_theme_color_override("font_color", Color(0.92, 0.94, 0.90))
		cell.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		cell.add_theme_constant_override("shadow_offset_x", 1)
		cell.add_theme_constant_override("shadow_offset_y", 1)
		if compact:
			cell.position = Vector2(12, 6 + index * 34)
			cell.size = Vector2(panel_width - 24, 31)
		else:
			var cell_width := (panel_width - 48.0) / 3.0
			cell.position = Vector2(12 + index * (cell_width + 12.0), 6)
			cell.size = Vector2(cell_width, panel_height - 12)
		panel.add_child(cell)
		if not compact and index < steps.size() - 1:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.position = Vector2(cell.position.x + cell.size.x, 20)
			arrow.size = Vector2(12, 24)
			arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			arrow.add_theme_font_size_override("font_size", 14)
			arrow.add_theme_color_override("font_color", accent)
			panel.add_child(arrow)
	if next_control != null and is_instance_valid(next_control):
		pulse(next_control, accent, 0.52)
	if reduced_motion:
		panel.modulate.a = 1.0
	else:
		panel.modulate.a = 0.0
		panel.position.y += 8.0
		var rest_y := panel.position.y - 8.0
		var enter := create_tween().bind_node(panel).set_parallel(true)
		enter.tween_property(panel, "position:y", rest_y, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		enter.tween_property(panel, "modulate:a", 1.0, 0.16)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(duration, 0.8)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(panel):
			return
		if reduced_motion:
			panel.queue_free()
			return
		var exit := create_tween().bind_node(panel)
		exit.tween_property(panel, "modulate:a", 0.0, 0.18)
		exit.tween_callback(panel.queue_free)
	)
	panel.add_child(timer)
	timer.start()
	return panel


func tutorial_highlight_once(target: Control, key: String, text: String, parent: Control) -> Control:
	var gm := get_node_or_null("/root/GameManager")
	var tutorial_mode := "full"
	if gm != null and gm.has_method("tutorial_assistance_mode"):
		tutorial_mode = str(gm.tutorial_assistance_mode())
	if tutorial_mode == "free" or not guidance_highlights or target == null or parent == null or bool(_tutorial_seen.get(key, false)):
		return null
	var light_hint := tutorial_mode == "light"
	_tutorial_seen[key] = true
	_save_settings()
	var overlay := Control.new()
	overlay.name = "TutorialHighlight_%s" % key
	overlay.add_to_group("guidance_highlight")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 900
	parent.add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.0 if light_hint else 0.34)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var target_rect := target.get_global_rect()
	var local_origin := parent.get_global_rect().position
	var frame := Panel.new()
	frame.position = target_rect.position - local_origin - Vector2(8, 8)
	frame.size = target_rect.size + Vector2(16, 16)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	frame.add_theme_stylebox_override("panel", style)
	overlay.add_child(frame)
	var parent_size := parent.size
	var bubble_size := Vector2(
		clampf(parent_size.x - 40.0, 280.0, 380.0 if light_hint else 430.0),
		72.0 if light_hint else 116.0
	)
	var bubble_x := frame.position.x + frame.size.x * 0.5 - bubble_size.x * 0.5
	if frame.position.x > parent_size.x * 0.58:
		bubble_x = frame.position.x - bubble_size.x - 18.0
	elif frame.position.x + frame.size.x < parent_size.x * 0.42:
		bubble_x = frame.position.x + frame.size.x + 18.0
	bubble_x = clampf(bubble_x, 20.0, maxf(20.0, parent_size.x - bubble_size.x - 20.0))
	var bubble_y := frame.position.y - bubble_size.y - 10.0
	if bubble_y < 20.0:
		bubble_y = frame.position.y + frame.size.y + 10.0
	bubble_y = clampf(bubble_y, 20.0, maxf(20.0, parent_size.y - bubble_size.y - 20.0))
	var bubble := Panel.new()
	bubble.name = "MayaTutorialBubble"
	bubble.position = Vector2(bubble_x, bubble_y)
	bubble.size = bubble_size
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.025, 0.045, 0.080, 0.98)
	bubble_style.border_color = GOLD
	bubble_style.set_border_width_all(2)
	bubble_style.set_corner_radius_all(5)
	bubble.add_theme_stylebox_override("panel", bubble_style)
	overlay.add_child(bubble)
	if not light_hint:
		MayaPortrait.create(
			bubble,
			"MayaTutorialPortrait",
			MayaPortrait.tutorial_pose(key, text),
			Vector2(6, 6),
			Vector2(76, 104),
			1
		)
	var label := Label.new()
	label.text = text
	label.position = Vector2(12, 8) if light_hint else Vector2(88, 10)
	label.size = Vector2(bubble_size.x - 24.0, bubble_size.y - 16.0) if light_hint else Vector2(bubble_size.x - 98.0, bubble_size.y - 20.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	bubble.add_child(label)
	if not reduced_motion:
		var tween := _replace_tween(frame, "feedback_tutorial")
		tween.set_loops(3)
		tween.tween_property(frame, "modulate:a", 0.50, 0.38).set_trans(Tween.TRANS_SINE)
		tween.tween_property(frame, "modulate:a", 1.0, 0.38).set_trans(Tween.TRANS_SINE)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = (1.8 if light_hint else 2.4) if not reduced_motion else 1.2
	timer.timeout.connect(overlay.queue_free)
	overlay.add_child(timer)
	timer.start()
	return overlay


func was_tutorial_seen(key: String) -> bool:
	return bool(_tutorial_seen.get(key, false))


func _feedback_border(control: Control, color: Color) -> Panel:
	var existing := control.get_node_or_null("InteractionFeedbackEffectBorder") as Panel
	if existing != null:
		return existing
	var border := Panel.new()
	border.name = "InteractionFeedbackEffectBorder"
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.z_index = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	border.add_theme_stylebox_override("panel", style)
	control.add_child(border)
	return border


func _tween_property(control: Object, property: NodePath, value: Variant, duration: float, key: String, trans := Tween.TRANS_SINE, ease := Tween.EASE_IN_OUT) -> Tween:
	var tween := _replace_tween(control, key)
	tween.tween_property(control, property, value, duration).set_trans(trans).set_ease(ease)
	return tween


func _replace_tween(control: Object, key: String) -> Tween:
	var old: Variant = control.get_meta(key) if control.has_meta(key) else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := create_tween()
	if control is Node:
		tween.bind_node(control as Node)
	control.set_meta(key, tween)
	return tween
