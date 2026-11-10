extends Control

# Astronomy Club dialogue scene. Plays StoryManager.active_lines one line
# at a time; Space / Enter / click advances. Pure presentation - all flow
# decisions live in StoryManager.

const PANEL_BG := Color(0.030, 0.045, 0.085, 0.97)
const BORDER := Color(0.78, 0.56, 0.28)
const NAME_COLOR := Color(0.98, 0.82, 0.50)
const TEXT_COLOR := Color(0.94, 0.94, 0.90)
const MUTED := Color(0.66, 0.74, 0.84)
const CYAN := Color(0.36, 0.82, 0.94)
const STORY_VISUAL_RESOLVER = preload("res://scripts/ui/story_visual_resolver.gd")
const OBSERVATORY_BACKGROUND: Texture2D = preload("res://assets/reference/observatory_room_hall_1024.png")

const PLAYER_PORTRAIT_ATLAS: Texture2D = preload("res://assets/characters/player_observer_smooth_8dir.png")
const PLAYER_PORTRAIT_REGION := Rect2(0, 0, 64, 96)
const MAYA_PORTRAIT_POSITION := Vector2(-24, -2)
const PLAYER_PORTRAIT_POSITION := Vector2(-24, -18)

var line_index := 0
var speaker_label: Label
var text_label: Label
var counter_label: Label
var portrait_frame: Panel
var portrait_rect: TextureRect
var next_button: Button
var diagram_rect: TextureRect
var diagram_tween: Tween
var line_tween: Tween
var visual_frame: Panel
var visual_title_label: Label
var visual_caption_label: Label
var dialogue_panel: Panel
var context_line_label: Label
var chapter_label: Label
var beat_label: Label
var reason_label: Label
var route_label: Label
var club_label: Label
var continue_hint_label: Label


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	if StoryManager.active_lines.is_empty():
		GameManager.call_deferred("go", "observatory")
		return
	_build()
	_show_line()
	InteractionFeedback.page_enter(self)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_SPACE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_advance()
	elif event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			# The button emits `pressed` on release. Let it own clicks inside its
			# bounds so one physical click cannot advance two dialogue lines.
			if next_button != null and next_button.get_global_rect().has_point(mouse.position):
				return
			_advance()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := TextureRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1024, 768)
	background.texture = OBSERVATORY_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.modulate = Color(0.55, 0.62, 0.74, 0.54)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_rect(Vector2.ZERO, Vector2(1024, 768), Color(0.008, 0.015, 0.032, 0.76))

	var plaque := Panel.new()
	plaque.name = "StoryHeader"
	plaque.position = Vector2(54, 24)
	plaque.size = Vector2(916, 70)
	plaque.add_theme_stylebox_override("panel", _style(Color(0.025, 0.040, 0.075, 0.98), BORDER, 2, 5))
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plaque)
	club_label = _label(
		GameManager.text("ASTRONOMY CLUB", "天文俱乐部"),
		Vector2(80, 40),
		Vector2(480, 36),
		24,
		NAME_COLOR,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	club_label.name = "StoryClubName"
	counter_label = _label("", Vector2(820, 44), Vector2(122, 28), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

	visual_frame = Panel.new()
	visual_frame.name = "StoryVisualFrame"
	visual_frame.position = Vector2(54, 110)
	visual_frame.size = Vector2(916, 360)
	visual_frame.add_theme_stylebox_override("panel", _style(Color(0.018, 0.031, 0.060, 0.98), Color(0.27, 0.60, 0.75), 2, 5))
	visual_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual_frame)

	var image_well := Panel.new()
	image_well.position = Vector2(66, 122)
	image_well.size = Vector2(634, 336)
	image_well.add_theme_stylebox_override("panel", _style(Color(0.005, 0.010, 0.022, 1.0), Color(0.16, 0.31, 0.46), 1, 3))
	image_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image_well)

	diagram_rect = TextureRect.new()
	diagram_rect.name = "StoryVisualImage"
	diagram_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diagram_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diagram_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diagram_rect.position = Vector2(72, 128)
	diagram_rect.size = Vector2(622, 324)
	diagram_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram_rect.modulate = Color(1, 1, 1, 0)
	add_child(diagram_rect)

	_rect(Vector2(714, 126), Vector2(1, 318), Color(0.25, 0.53, 0.68, 0.55))
	visual_title_label = _label("", Vector2(736, 136), Vector2(210, 56), 20, NAME_COLOR)
	visual_title_label.name = "StoryVisualTitle"
	visual_title_label.max_lines_visible = 2
	visual_caption_label = _label("", Vector2(736, 198), Vector2(210, 80), 13, TEXT_COLOR)
	visual_caption_label.name = "StoryVisualCaption"
	visual_caption_label.max_lines_visible = 4
	chapter_label = _label("", Vector2(736, 282), Vector2(210, 38), 10, CYAN)
	chapter_label.name = "StoryChapter"
	chapter_label.max_lines_visible = 2
	reason_label = _label("", Vector2(736, 324), Vector2(210, 72), 9, MUTED)
	reason_label.name = "StoryReason"
	reason_label.max_lines_visible = 6
	route_label = _label("", Vector2(736, 400), Vector2(210, 44), 9, Color(0.58, 0.91, 0.96))
	route_label.name = "StoryRoute"
	route_label.max_lines_visible = 3

	dialogue_panel = Panel.new()
	dialogue_panel.name = "StoryDialoguePanel"
	dialogue_panel.position = Vector2(54, 486)
	dialogue_panel.size = Vector2(916, 252)
	dialogue_panel.add_theme_stylebox_override("panel", _style(PANEL_BG, BORDER, 3, 5))
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_panel)

	portrait_frame = Panel.new()
	portrait_frame.name = "DialoguePortraitFrame"
	portrait_frame.position = Vector2(74, 506)
	portrait_frame.size = Vector2(144, 208)
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override(
		"panel",
		_style(Color(0.018, 0.030, 0.060, 0.98), Color(0.34, 0.70, 0.86), 2, 3)
	)
	add_child(portrait_frame)

	portrait_rect = TextureRect.new()
	portrait_rect.name = "CharacterPortrait"
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_rect.position = Vector2(-24, -18)
	portrait_rect.size = Vector2(192, 288)
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_rect)

	speaker_label = _label("", Vector2(240, 505), Vector2(400, 32), 20, NAME_COLOR)
	speaker_label.name = "StorySpeaker"
	beat_label = _label("", Vector2(650, 508), Vector2(290, 26), 12, CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	text_label = _label("", Vector2(240, 546), Vector2(700, 98), 16, TEXT_COLOR)
	text_label.name = "StoryDialogueText"
	text_label.max_lines_visible = 5
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	context_line_label = _label("", Vector2(240, 652), Vector2(530, 52), 11, MUTED)
	context_line_label.name = "StoryContextLine"
	context_line_label.max_lines_visible = 3

	next_button = Button.new()
	next_button.name = "StoryContinueButton"
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.position = Vector2(790, 670)
	next_button.size = Vector2(156, 48)
	next_button.add_theme_font_size_override("font_size", 14)
	next_button.add_theme_stylebox_override("normal", _style(Color(0.09, 0.16, 0.27, 1.0), Color(0.42, 0.76, 0.88), 2, 4))
	next_button.add_theme_stylebox_override("hover", _style(Color(0.13, 0.26, 0.37, 1.0), Color(0.62, 0.91, 0.98), 2, 4))
	next_button.add_theme_stylebox_override("pressed", _style(Color(0.19, 0.14, 0.07, 1.0), NAME_COLOR, 2, 4))
	next_button.pressed.connect(_advance)
	add_child(next_button)

	continue_hint_label = _label(GameManager.text("Space / Enter / Click", "空格 / 回车 / 点击"), Vector2(356, 708), Vector2(330, 18), 9, MUTED)
	continue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _show_line() -> void:
	var line: Dictionary = StoryManager.active_lines[line_index]
	var event_id := str(line.get("_story_event_id", StoryManager.active_event_id))
	var event_line_index := int(line.get("_story_line_index", line_index))
	var event_context: Dictionary = StoryManager.context_for_event(event_id)
	if event_context.is_empty():
		event_context = StoryManager.active_context
	var speaker := str(line.get("speaker", "Maya"))
	if speaker == "You":
		speaker_label.text = GameManager.text("You", "你")
	elif speaker.to_lower() == "maya":
		speaker_label.text = GameManager.text("Maya", "玛雅")
	else:
		speaker_label.text = speaker
	text_label.text = GameManager.text(str(line.get("text_en", "")), str(line.get("text_zh", "")))
	var beat_en := str(line.get("beat_en", ""))
	var beat_zh := str(line.get("beat_zh", ""))
	beat_label.text = GameManager.text(beat_en, beat_zh)
	counter_label.text = "%d / %d" % [line_index + 1, StoryManager.active_lines.size()]
	var portrait_id := str(line.get("portrait", "maya")).to_lower()
	if portrait_id == "maya" or speaker.to_lower() == "maya":
		portrait_rect.position = MAYA_PORTRAIT_POSITION
		portrait_rect.set_meta("player_source_path", "")
		var event_line_count := StoryManager.get_dialogue(event_id).size()
		if event_line_count <= 0:
			event_line_count = StoryManager.active_lines.size()
		var pose := MayaPortrait.story_pose(
			line,
			event_id,
			event_line_index,
			event_line_count
		)
		MayaPortrait.apply_to(portrait_rect, pose)
	elif portrait_id in ["player", "you"]:
		portrait_rect.position = PLAYER_PORTRAIT_POSITION
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_rect.texture = _player_portrait_texture()
		portrait_rect.visible = true
		portrait_rect.set_meta("maya_pose", "")
		portrait_rect.set_meta("maya_source_path", "")
		portrait_rect.set_meta("player_source_path", PLAYER_PORTRAIT_ATLAS.resource_path)
	else:
		portrait_rect.visible = false
	if line_index >= StoryManager.active_lines.size() - 1:
		next_button.text = GameManager.text("Let's go!", "出发！").replace("\n", " · ")
	else:
		next_button.text = GameManager.text("Next", "继续").replace("\n", " · ")
	_update_line_image(line, event_id, event_context, event_line_index)
	_update_context_panel(event_context)
	_animate_dialogue_line()


func _player_portrait_texture() -> AtlasTexture:
	# The dialogue portrait and lobby character deliberately share one source.
	# The first cell is the authored front-facing rest pose; AtlasTexture keeps
	# the crop lossless and avoids maintaining a second, easily stale avatar PNG.
	var texture := AtlasTexture.new()
	texture.atlas = PLAYER_PORTRAIT_ATLAS
	texture.region = PLAYER_PORTRAIT_REGION
	return texture


func _update_context_panel(context: Dictionary) -> void:
	if context.is_empty():
		chapter_label.text = ""
		reason_label.text = ""
		route_label.text = ""
		context_line_label.text = ""
		return
	chapter_label.text = GameManager.text(
		str(context.get("chapter_en", "Astronomy Club")),
		str(context.get("chapter_zh", "天文俱乐部"))
	)
	reason_label.text = GameManager.text(
		"WHY THIS MATTERS\n" + str(context.get("reason_en", "")),
		"为什么要做这一步\n" + str(context.get("reason_zh", ""))
	)
	route_label.text = GameManager.text(
		"ROUTE\n%s  >  %s" % [
			str(context.get("from_en", "")),
			str(context.get("to_en", ""))
		],
		"路线\n%s  >  %s" % [
			str(context.get("from_zh", "")),
			str(context.get("to_zh", ""))
		]
	)
	var current_beat_en := beat_label.text if GameManager.language_mode == "en" else ""
	var current_beat_zh := beat_label.text if GameManager.language_mode == "zh" else ""
	context_line_label.text = GameManager.text(
		"CURRENT  %s\nNEXT  %s" % [current_beat_en if current_beat_en != "" else visual_title_label.text, str(context.get("action_en", ""))],
		"当前  %s\n下一步  %s" % [current_beat_zh if current_beat_zh != "" else visual_title_label.text, str(context.get("action_zh", ""))]
	)


func _update_line_image(line: Dictionary, event_id: String, context: Dictionary, event_line_index: int) -> void:
	var target := _target_for_context(context)
	var family := _family_for_context(context)
	var visual: Dictionary = STORY_VISUAL_RESOLVER.resolve(event_id, line, context, target, family, event_line_index)
	var image_path := str(visual.get("path", ""))
	visual_title_label.text = GameManager.text(str(visual.get("title_en", "")), str(visual.get("title_zh", "")))
	_fit_wrapped_label(visual_title_label, 20, 13)
	visual_caption_label.text = GameManager.text(str(visual.get("caption_en", "")), str(visual.get("caption_zh", "")))
	if diagram_tween:
		diagram_tween.kill()
	if image_path == "" or not ResourceLoader.exists(image_path):
		diagram_rect.texture = null
		diagram_rect.modulate.a = 0.0
		return
	diagram_rect.modulate.a = 0.0
	diagram_rect.position.x = 78.0
	diagram_rect.texture = load(image_path)
	diagram_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if str(visual.get("fit", "contain")) == "cover" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diagram_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	diagram_tween.tween_property(diagram_rect, "position:x", 72.0, 0.18)
	diagram_tween.parallel().tween_property(diagram_rect, "modulate:a", 1.0, 0.18)


func _target_for_context(context: Dictionary) -> Dictionary:
	var level := _level_for_context(context)
	var target_id := str(level.get("target_object_id", GameManager.current_target_object_id()))
	if int(level.get("level_number", 0)) == int(GameManager.current_level().get("level_number", 0)):
		target_id = GameManager.current_target_object_id()
	return GameManager.get_object(target_id)


func _family_for_context(context: Dictionary) -> String:
	return str(_level_for_context(context).get("telescope_family", GameManager.current_level().get("telescope_family", "refractor")))


func _level_for_context(context: Dictionary) -> Dictionary:
	var current: Dictionary = GameManager.current_level()
	var level_number := int(context.get("level_number", current.get("level_number", 0)))
	if level_number == int(current.get("level_number", 0)):
		return current
	var mission_manager := get_node_or_null("/root/MissionManager")
	if mission_manager != null and mission_manager.has_method("get_level"):
		var resolved: Dictionary = mission_manager.get_level(level_number)
		if not resolved.is_empty():
			return resolved
	return current


func _animate_dialogue_line() -> void:
	if line_tween:
		line_tween.kill()
	text_label.modulate.a = 0.0
	text_label.position.y = 550.0
	context_line_label.modulate.a = 0.0
	line_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	line_tween.tween_property(text_label, "position:y", 546.0, 0.16)
	line_tween.parallel().tween_property(text_label, "modulate:a", 1.0, 0.16)
	line_tween.parallel().tween_property(context_line_label, "modulate:a", 1.0, 0.2)


func _advance() -> void:
	if StoryManager.active_lines.is_empty():
		return
	if line_index < StoryManager.active_lines.size() - 1:
		line_index += 1
		_show_line()
	else:
		StoryManager.finish_active_event()


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _fit_wrapped_label(label: Label, preferred_size: int, minimum_size: int) -> void:
	var font_size := preferred_size
	label.add_theme_font_size_override("font_size", font_size)
	while label.get_line_count() > label.max_lines_visible and font_size > minimum_size:
		font_size -= 1
		label.add_theme_font_size_override("font_size", font_size)

func _on_language_changed() -> void:
	if club_label != null:
		club_label.text = GameManager.text("ASTRONOMY CLUB", "天文俱乐部")
	if continue_hint_label != null:
		continue_hint_label.text = GameManager.text("Space / Enter / Click to continue", "空格 / 回车 / 点击继续")
	if not StoryManager.active_lines.is_empty():
		_show_line()
