extends RefCounted

const ROOM_BACKGROUND: Texture2D = preload("res://assets/reference/observatory_room_hall_1024.png")

const NAVY := Color(0.025, 0.040, 0.075, 0.94)
const NAVY_SOFT := Color(0.050, 0.075, 0.120, 0.90)
const NAVY_DEEP := Color(0.012, 0.022, 0.044, 0.96)
const NAVY_RAISED := Color(0.075, 0.110, 0.170, 0.96)
const BRASS := Color(0.90, 0.63, 0.28)
const BRASS_DIM := Color(0.60, 0.43, 0.22)
const CYAN := Color(0.52, 0.86, 1.00)
const GREEN := Color(0.45, 0.95, 0.56)
const WARM_TEXT := Color(0.96, 0.91, 0.78)
const BODY_TEXT := Color(0.84, 0.88, 0.92)
const MUTED_TEXT := Color(0.64, 0.72, 0.80)
const STEEL_EDGE := Color(0.18, 0.28, 0.44)


static func add_observatory_backdrop(parent: Control, scrim_alpha: float = 0.82) -> TextureRect:
	var backdrop := TextureRect.new()
	backdrop.name = "ObservatoryBackdrop"
	backdrop.texture = ROOM_BACKGROUND
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(backdrop)

	var scrim := ColorRect.new()
	scrim.name = "ObservatoryScrim"
	scrim.color = Color(0.004, 0.010, 0.023, clampf(scrim_alpha, 0.0, 1.0))
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scrim)
	return backdrop


static func panel(fill: Color, border: Color, border_width: int = 1, radius: int = 6, horizontal_margin: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	if horizontal_margin > 0:
		style.content_margin_left = horizontal_margin
		style.content_margin_right = horizontal_margin
		style.content_margin_top = 6
		style.content_margin_bottom = 6
	return style


static func apply_button(button: Button, accent: Color = BRASS, primary: bool = false, font_size: int = 14) -> void:
	var normal_fill := accent.darkened(0.58) if primary else NAVY_RAISED.darkened(0.22)
	var hover_fill := accent.darkened(0.38) if primary else NAVY_RAISED.lightened(0.08)
	var pressed_fill := accent.darkened(0.66) if primary else NAVY_DEEP
	var edge := accent if primary else STEEL_EDGE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", WARM_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.53, 0.60))
	button.add_theme_stylebox_override("normal", panel(normal_fill, edge, 1, 5, 10))
	button.add_theme_stylebox_override("hover", panel(hover_fill, accent.lightened(0.16), 2, 5, 10))
	button.add_theme_stylebox_override("pressed", panel(pressed_fill, accent, 2, 5, 10))
	button.add_theme_stylebox_override("focus", panel(hover_fill, CYAN, 2, 5, 10))
	button.add_theme_stylebox_override("disabled", panel(Color(0.035, 0.045, 0.060, 0.86), Color(0.22, 0.26, 0.32), 1, 5, 10))


static func add_frame_corners(parent: Control, pos: Vector2, frame_size: Vector2, color: Color, length: float = 12.0, thickness: float = 2.0) -> void:
	var inset := 5.0
	var points := [
		Rect2(pos + Vector2(inset, inset), Vector2(length, thickness)),
		Rect2(pos + Vector2(inset, inset), Vector2(thickness, length)),
		Rect2(pos + Vector2(frame_size.x - inset - length, inset), Vector2(length, thickness)),
		Rect2(pos + Vector2(frame_size.x - inset - thickness, inset), Vector2(thickness, length)),
		Rect2(pos + Vector2(inset, frame_size.y - inset - thickness), Vector2(length, thickness)),
		Rect2(pos + Vector2(inset, frame_size.y - inset - length), Vector2(thickness, length)),
		Rect2(pos + Vector2(frame_size.x - inset - length, frame_size.y - inset - thickness), Vector2(length, thickness)),
		Rect2(pos + Vector2(frame_size.x - inset - thickness, frame_size.y - inset - length), Vector2(thickness, length)),
	]
	for rect_value in points:
		var mark := ColorRect.new()
		mark.position = (rect_value as Rect2).position
		mark.size = (rect_value as Rect2).size
		mark.color = color
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(mark)
