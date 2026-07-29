extends Control

# Astronomy Club dialogue scene. Plays StoryManager.active_lines one line
# at a time; Space / Enter / click advances. Pure presentation - all flow
# decisions live in StoryManager.

const BG := Color(0.012, 0.020, 0.045)
const PANEL_BG := Color(0.030, 0.045, 0.085, 0.97)
const BORDER := Color(0.78, 0.56, 0.28)
const NAME_COLOR := Color(0.98, 0.82, 0.50)
const TEXT_COLOR := Color(0.94, 0.94, 0.90)
const MUTED := Color(0.66, 0.74, 0.84)

const PLAYER_PORTRAIT := "res://assets/characters/player_portrait.png"
const MAYA_PORTRAIT_POSITION := Vector2(-24, -2)
const PLAYER_PORTRAIT_POSITION := Vector2(-24, -18)

const TARGET_VISUALS := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_large.png",
	"andromeda": "res://assets/telescope_view/andromeda_large.png"
}

var line_index := 0
var speaker_label: Label
var text_label: Label
var counter_label: Label
var portrait_frame: Panel
var portrait_rect: TextureRect
var next_button: Button
var diagram_rect: TextureRect
var diagram_tween: Tween
var default_visual_rect: TextureRect
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
			_advance()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(Vector2.ZERO, Vector2(1024, 768), BG)
	_draw_night_sky()

	# Astronomy Club plaque
	var plaque := Panel.new()
	plaque.position = Vector2(342, 60)
	plaque.size = Vector2(340, 64)
	plaque.add_theme_stylebox_override("panel", _style(Color(0.16, 0.11, 0.05, 0.96), BORDER, 3, 4))
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plaque)
	club_label = _label(
		GameManager.text("ASTRONOMY CLUB", "天文俱乐部"),
		Vector2(342, 76),
		Vector2(340, 36),
		22,
		NAME_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	club_label.name = "StoryClubName"

	# dialogue panel
	var panel := Panel.new()
	panel.position = Vector2(72, 520)
	panel.size = Vector2(880, 190)
	panel.add_theme_stylebox_override("panel", _style(PANEL_BG, BORDER, 3, 5))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	# A compact narrative compass connects Maya's explanation to the physical
	# observatory. It is deliberately separate from the spoken text: the player
	# can always see why this scene exists and where the next action happens.
	var context_panel := Panel.new()
	context_panel.position = Vector2(72, 430)
	context_panel.size = Vector2(880, 76)
	context_panel.add_theme_stylebox_override("panel", _style(Color(0.022, 0.038, 0.071, 0.96), Color(0.30, 0.57, 0.70), 2, 4))
	context_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(context_panel)
	chapter_label = _label("", Vector2(92, 438), Vector2(420, 20), 13, NAME_COLOR)
	reason_label = _label("", Vector2(92, 460), Vector2(420, 38), 10, MUTED)
	reason_label.max_lines_visible = 2
	route_label = _label("", Vector2(530, 440), Vector2(398, 60), 10, Color(0.55, 0.91, 0.96), HORIZONTAL_ALIGNMENT_RIGHT)
	route_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	route_label.max_lines_visible = 3

	# Maya belongs to the dialogue, not to the sky. The clipped portrait well
	# presents a readable head-and-torso crop while keeping the supplied PNG
	# untouched and preserving her face and both gesturing hands.
	portrait_frame = Panel.new()
	portrait_frame.name = "DialoguePortraitFrame"
	portrait_frame.position = Vector2(92, 538)
	portrait_frame.size = Vector2(132, 156)
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
	portrait_rect.size = Vector2(180, 270)
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait_rect)

	speaker_label = _label("", Vector2(244, 540), Vector2(420, 28), 19, NAME_COLOR)
	speaker_label.name = "StorySpeaker"
	beat_label = _label("", Vector2(676, 542), Vector2(236, 22), 11, Color(0.54, 0.91, 0.96), HORIZONTAL_ALIGNMENT_RIGHT)
	text_label = _label("", Vector2(244, 574), Vector2(668, 82), 16, TEXT_COLOR)
	text_label.name = "StoryDialogueText"
	text_label.max_lines_visible = 4

	counter_label = _label("", Vector2(244, 682), Vector2(120, 20), 11, MUTED)

	# Per-line learning diagram overlay. Sized to fit within the upper play
	# area without covering the dialogue panel (which starts at y=520) or
	# the plaque (which ends around y=124). Hidden (alpha 0) by default;
	# lines with an "image" field fade it in centered over the night sky.
	diagram_rect = TextureRect.new()
	diagram_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diagram_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	diagram_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	diagram_rect.position = Vector2(278, 136)
	diagram_rect.size = Vector2(594, 280)
	diagram_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram_rect.modulate = Color(1, 1, 1, 0)
	add_child(diagram_rect)

	next_button = Button.new()
	next_button.name = "StoryContinueButton"
	next_button.position = Vector2(812, 664)
	next_button.size = Vector2(120, 38)
	next_button.add_theme_font_size_override("font_size", 14)
	next_button.pressed.connect(_advance)
	add_child(next_button)

	continue_hint_label = _label(GameManager.text("Space / Enter / Click to continue", "空格 / 回车 / 点击继续"), Vector2(382, 682), Vector2(390, 24), 9, MUTED)
	continue_hint_label.max_lines_visible = 2


func _draw_night_sky() -> void:
	# Generic starfield. A target visual is only shown for current-target
	# observation story events; equipment/assembly teaching stays generic.
	for i in range(90):
		var x := 14.0 + fmod(float(i * 89), 996.0)
		var y := 10.0 + fmod(float(i * 53), 480.0)
		var b := 0.45 + fmod(float(i), 5.0) * 0.10
		_rect(Vector2(x, y), Vector2(2, 2), Color(b, b, 0.95, 0.7))
	var visual_id := _story_visual_id()
	if visual_id == "":
		return
	var visual_path: String = TARGET_VISUALS.get(visual_id, "")
	if visual_path == "" or not ResourceLoader.exists(visual_path):
		return
	var moon := TextureRect.new()
	moon.texture = load(visual_path)
	moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moon.position = Vector2(790, 150)
	moon.size = Vector2(160, 160)
	moon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moon.modulate = Color(1, 1, 1, 0.9)
	add_child(moon)
	default_visual_rect = moon


func _story_visual_id() -> String:
	var event_id := StoryManager.active_event_id
	if event_id.contains("assembly") or event_id.contains("focus") or event_id == "intro":
		return ""
	return GameManager.current_target_object_id()


func _show_line() -> void:
	var line: Dictionary = StoryManager.active_lines[line_index]
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
		var pose := MayaPortrait.story_pose(
			line,
			StoryManager.active_event_id,
			line_index,
			StoryManager.active_lines.size()
		)
		MayaPortrait.apply_to(portrait_rect, pose)
	elif portrait_id in ["player", "you"] and ResourceLoader.exists(PLAYER_PORTRAIT):
		portrait_rect.position = PLAYER_PORTRAIT_POSITION
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_rect.texture = load(PLAYER_PORTRAIT)
		portrait_rect.visible = true
		portrait_rect.set_meta("maya_pose", "")
		portrait_rect.set_meta("maya_source_path", "")
	else:
		portrait_rect.visible = false
	if line_index >= StoryManager.active_lines.size() - 1:
		next_button.text = GameManager.text("Let's go!", "出发！").replace("\n", " · ")
	else:
		next_button.text = GameManager.text("Next", "继续").replace("\n", " · ")
	_update_line_image(line)
	_update_context_panel()


func _update_context_panel() -> void:
	var context: Dictionary = StoryManager.active_context
	if context.is_empty():
		chapter_label.text = ""
		reason_label.text = ""
		route_label.text = ""
		return
	chapter_label.text = GameManager.text(
		str(context.get("chapter_en", "Astronomy Club")),
		str(context.get("chapter_zh", "天文俱乐部"))
	)
	reason_label.text = GameManager.text(
		"WHY NOW  " + str(context.get("reason_en", "")),
		"为什么是现在  " + str(context.get("reason_zh", ""))
	)
	route_label.text = GameManager.text(
		"%s  >  %s\n%s" % [
			str(context.get("from_en", "")),
			str(context.get("to_en", "")),
			str(context.get("action_en", ""))
		],
		"%s  >  %s\n%s" % [
			str(context.get("from_zh", "")),
			str(context.get("to_zh", "")),
			str(context.get("action_zh", ""))
		]
	)


func _update_line_image(line: Dictionary) -> void:
	var image_path := str(line.get("image", ""))
	if diagram_tween:
		diagram_tween.kill()
	diagram_tween = create_tween()
	if image_path != "" and ResourceLoader.exists(image_path):
		# Swap texture while invisible, then fade in; covers the default
		# target visual so the two never show at once.
		diagram_rect.modulate.a = 0.0
		diagram_rect.texture = load(image_path)
		if default_visual_rect:
			diagram_tween.tween_property(default_visual_rect, "modulate:a", 0.0, 0.2)
		diagram_tween.parallel().tween_property(diagram_rect, "modulate:a", 1.0, 0.25)
	else:
		diagram_tween.tween_property(diagram_rect, "modulate:a", 0.0, 0.2)
		if default_visual_rect:
			diagram_tween.parallel().tween_property(default_visual_rect, "modulate:a", 0.9, 0.25)


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

func _on_language_changed() -> void:
	if club_label != null:
		club_label.text = GameManager.text("ASTRONOMY CLUB", "天文俱乐部")
	if continue_hint_label != null:
		continue_hint_label.text = GameManager.text("Space / Enter / Click to continue", "空格 / 回车 / 点击继续")
	if not StoryManager.active_lines.is_empty():
		_show_line()
