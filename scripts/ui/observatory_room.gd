extends Control

const FurnitureAnimator = preload("res://scripts/ui/observatory_furniture_animator.gd")
const W := 1024.0
const H := 768.0
const ROOM_RECT := Rect2(36, 118, 952, 570)
const PLAYER_SIZE := Vector2(18, 20)
const PLAYER_SPEED := 220.0
const INTERACT_DISTANCE := 56.0
const BG_TEXTURE := "res://assets/reference/observatory_room_clean_bg_1024.png"
const PLAYER_TEXTURE := "res://assets/characters/player_observer_4dir_clean.png"
const PLAYER_FRAME_SIZE := Vector2(96, 128)
# Uniform scale only — the old 44x62 display size squashed the 96x128 frame.
const PLAYER_DISPLAY_HEIGHT := 72.0
const PLAYER_DISPLAY_SCALE := PLAYER_DISPLAY_HEIGHT / PLAYER_FRAME_SIZE.y
const PLAYER_DISPLAY_SIZE := PLAYER_FRAME_SIZE * PLAYER_DISPLAY_SCALE
# Feet row inside the 128px frame (content ends ~y120, below is padding).
const PLAYER_FOOT_Y := 120.0
const PLAYER_ANIM_FPS := 8.0

const NAVY := Color(0.025, 0.040, 0.075, 0.92)
const NAVY_SOFT := Color(0.050, 0.075, 0.120, 0.82)
const WARM_TEXT := Color(0.96, 0.91, 0.78)
const BRASS := Color(0.90, 0.63, 0.28)
const CYAN := Color(0.52, 0.86, 1.00)
const COMPUTER_MODAL_LAYER := 1100

var player: Sprite2D
var player_atlas: AtlasTexture
var player_shadow: ColorRect
var mission_board_popup: Control
var stats_terminal_popup: Control
var unlock_popup: Control
var level_value_label: Label
var credits_value_label: Label
var telescope_status_label: Label
var guidance_overlay: Control
var guidance_panel: Panel
var guidance_maya_portrait: TextureRect
var guidance_title_label: Label
var guidance_hint_label: Label
var guidance_action_label: Label
var guidance_outcome_label: Label
var mobile_overlay: Control
var route_edge_indicator: Control
var route_arrow_label: Label
var route_distance_label: Label
var focus_label: Label
var feedback_label: Label
var furniture_animator: ObservatoryFurnitureAnimator
var interactables: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var nearby_id := ""
var player_pos := Vector2(517, 630)
var active_guidance := ""
var feedback_override := ""
var feedback_override_until_msec := 0
var interact_key_was_down := false
var mission_key_was_down := false
var player_facing := "down"
var player_anim_frame := 0
var player_anim_time := 0.0
var player_is_moving := false
var room_transition_active := false
var room_guidance_suspended := false
var pending_remote_console_scene := ""
var furniture_interaction_active := false
var arrival_furniture_id := ""


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	InteractionFeedback.guidance_highlights_changed.connect(_on_guidance_highlights_changed)
	# A completed save that closed on the result card still receives its
	# one-time ceremony on the next lobby visit.
	if GameManager.graduation_pending():
		GameManager.call_deferred("go", "graduation")
		return
	# room_guidance_target is runtime-only state that used to be written ONLY by
	# the Mission Complete "Continue" button. Any other way of reaching the lobby
	# - quitting and relaunching, loading a save, backing out of a screen - left
	# it empty, which hid the whole highlight and left the player with no next
	# step. The lobby always recomputes it from the current level instead.
	if GameManager.room_guidance_target == "":
		GameManager.update_room_guidance_for_level()
	if GameManager.last_guidance == "ready_to_observe":
		active_guidance = GameManager.last_guidance
		GameManager.last_guidance = ""
	elif GameManager.room_guidance_target != "":
		active_guidance = "room_guidance"
	var arrival_id := GameManager.take_observatory_spawn()
	arrival_furniture_id = arrival_id
	player_pos = _spawn_position(arrival_id)
	_build()
	InteractionFeedback.page_enter(self)
	set_process(true)
	call_deferred("_animate_arrival_furniture_close")
	call_deferred("_maybe_show_unlock_popup")
	call_deferred("_show_room_tutorial")
	call_deferred("_show_assembly_return_chain", arrival_id)


func _show_room_tutorial() -> void:
	# The persistent Maya route card already explains the next action. Do not
	# stack a second tutorial bubble on top of it or on top of a modal.
	if guidance_panel == null or unlock_popup != null or mission_board_popup != null \
			or stats_terminal_popup != null or room_guidance_suspended:
		return
	InteractionFeedback.success(guidance_panel)


func _show_assembly_return_chain(arrival_id: String) -> void:
	if arrival_id != "assembly" or not GameManager.telescope_is_ready():
		return
	GameManager.update_room_guidance_for_level()
	_update_room_guidance_panel()
	var route := GameManager.current_room_route()
	var route_target := str(route.get("target", "telescope"))
	var destination := _get_interactable(route_target)
	var destination_glow := destination.get("glow") as Control
	var destination_name := str(destination.get("name", GameManager.text("Observation Pad", "观测台")))
	_show_feedback(
		GameManager.text(
			"Telescope Ready. Follow the highlighted route to %s." % destination_name,
			"望远镜已就绪。沿高亮路线前往%s。" % destination_name
		),
		3200
	)
	if destination_glow != null:
		InteractionFeedback.success(destination_glow, "assembly_route_ready")
	var chain := InteractionFeedback.operation_chain(
		self,
		GameManager.text("Assembly complete", "装配完成"),
		GameManager.text("The telescope passed its readiness check", "望远镜已通过就绪检查"),
		GameManager.text("%s is now active" % destination_name, "%s现已启用" % destination_name),
		destination_glow,
		Color(0.42, 0.96, 0.58),
		3.2
	)
	if chain != null:
		chain.position.y = 636.0


func _process(delta: float) -> void:
	if room_transition_active:
		_update_hud()
		return
	if unlock_popup != null:
		_update_hud()
		return
	if stats_terminal_popup != null:
		_update_hud()
		return
	_move_player(delta)
	_poll_action_keys()
	_update_nearby()
	_update_hud()


func _input(event: InputEvent) -> void:
	if room_transition_active:
		return
	if stats_terminal_popup != null:
		if event is InputEventKey:
			var terminal_key := event as InputEventKey
			if terminal_key.pressed and not terminal_key.echo and terminal_key.keycode == KEY_ESCAPE:
				_toggle_stats_terminal()
		return
	if furniture_interaction_active:
		return
	# The Mission Board is a modal task center. Do not let its hotkeys also
	# activate furniture behind it while the player is reading the route.
	if mission_board_popup != null:
		if event is InputEventKey:
			var board_key := event as InputEventKey
			if board_key.pressed and not board_key.echo and (board_key.keycode == KEY_TAB or board_key.keycode == KEY_ESCAPE):
				mission_key_was_down = board_key.keycode == KEY_TAB
				_close_mission_board(true)
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or _event_action_pressed(event, "interact")):
			_interact_with_nearby()
		if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_TAB or _event_action_pressed(event, "view_missions")):
			_handle_interaction("mission")
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			GameManager.go("menu")
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_interact_at(mouse_event.position)


func _poll_action_keys() -> void:
	if mission_board_popup != null:
		interact_key_was_down = Input.is_key_pressed(KEY_E) or _action_pressed("interact")
		mission_key_was_down = Input.is_key_pressed(KEY_TAB) or _action_pressed("view_missions")
		return
	var interact_down := Input.is_key_pressed(KEY_E) or _action_pressed("interact")
	if interact_down and not interact_key_was_down:
		_interact_with_nearby()
	interact_key_was_down = interact_down

	var mission_down := Input.is_key_pressed(KEY_TAB) or _action_pressed("view_missions")
	if mission_down and not mission_key_was_down:
		_handle_interaction("mission")
	mission_key_was_down = mission_down


func _action_pressed(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func _event_action_pressed(event: InputEvent, action_name: String) -> bool:
	return InputMap.has_action(action_name) and event.is_action_pressed(action_name)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	interactables.clear()
	obstacles.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_draw_full_background()
	_draw_furniture_animation_overlays()
	_register_hitboxes()
	_draw_player()
	_draw_hud()
	_set_player_position(player_pos)
	_update_nearby()
	_update_hud()


func _draw_full_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.position = Vector2.ZERO
	bg.size = Vector2(W, H)
	bg.ignore_texture_size = true
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if _space_console_active():
		_draw_space_console_overlay()


func _draw_furniture_animation_overlays() -> void:
	furniture_animator = FurnitureAnimator.new()
	furniture_animator.name = "FurnitureAnimator"
	add_child(furniture_animator)
	furniture_animator.setup()


func _animate_arrival_furniture_close() -> void:
	if furniture_animator == null or not furniture_animator.has_rig(arrival_furniture_id):
		return
	furniture_interaction_active = true
	furniture_animator.open_immediately(arrival_furniture_id)
	await get_tree().create_timer(0.08).timeout
	furniture_animator.play_close(arrival_furniture_id, func() -> void:
		furniture_interaction_active = false
	)


func _space_console_active() -> bool:
	return _remote_console_kind() != ""


func _remote_console_kind() -> String:
	var level := GameManager.current_level()
	var family := str(level.get("telescope_family", ""))
	var mode := str(level.get("observation_mode", ""))
	if family == "space_segmented" or mode == "space_infrared":
		return "space"
	if family == "fast_radio" or mode == "radio":
		return "radio"
	return ""


func _remote_console_destination() -> String:
	return "radio_observation" if _remote_console_kind() == "radio" else "space_observation"


func _draw_space_console_overlay() -> void:
	# The furniture art already contains a complete green monitor. Add only a
	# clipped status strip inside its glass; a second framed panel would cover
	# the original display and read as a broken foreground layer.
	var screen := Control.new()
	screen.name = "SpaceConsoleScreen"
	screen.position = Vector2(737, 489)
	screen.size = Vector2(112, 88)
	screen.clip_contents = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var radio_console := _remote_console_kind() == "radio"
	var status_strip := Panel.new()
	status_strip.position = Vector2(2, 68)
	status_strip.size = Vector2(108, 16)
	status_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_strip.add_theme_stylebox_override(
		"panel",
		_style(Color(0.002, 0.018, 0.018, 0.70), Color(0.22, 0.56, 0.50, 0.46), 1, 0)
	)
	screen.add_child(status_strip)
	_board_label(
		status_strip,
		("FAST LINK / ARRAY READY" if radio_console else "L2 LINK / BUS READY"),
		Vector2(2, 1),
		Vector2(104, 13),
		7,
		Color(0.56, 0.92, 0.82),
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _register_hitboxes() -> void:
	_register_interactable("cabinet", GameManager.text("Parts Cabinet", "零件柜"), GameManager.text("Review unlocked telescope parts.", "查看已解锁的望远镜零件。"), Rect2(82, 124, 214, 182))
	_register_interactable("door", GameManager.text("Observatory Dome", "圆顶观星站"), GameManager.text("The ridge dome: wind-shielded formal station with its own control room. Same sky as the pad - steadier housing.", "山脊圆顶：挡风的正式观测站，带控制室。和露天观测台看同一片天空，但圆顶更稳、更抗风。"), Rect2(468, 88, 88, 188))
	_register_interactable("mission", GameManager.text("Mission Board", "任务公告板"), GameManager.text("Read the current level goal here.", "在此查看当前关卡目标。"), Rect2(622, 108, 138, 124))
	_register_interactable("assembly", GameManager.text("Assembly Table", "组装台"), GameManager.text("Build and align the telescope.", "组装和校准望远镜。"), Rect2(782, 214, 170, 160))
	if GameManager.current_observation_mode() == "naked_eye":
		_register_interactable("telescope", GameManager.text("Naked Eye Observation", "肉眼观测"), GameManager.text("Observe the night sky with your own eyes.", "用肉眼观察夜空。"), Rect2(455, 398, 120, 124))
	elif GameManager.current_observation_mode() == "constellation":
		_register_interactable("telescope", GameManager.text("Constellation Search", "星座搜寻"), GameManager.text("Use the observation pad to locate the complete star pattern, then study it through the telescope.", "使用观测台定位完整星群，再通过望远镜观察它。"), Rect2(455, 398, 120, 124))
	else:
		_register_interactable("telescope", GameManager.text("Telescope Observation Pad", "望远镜观测台"), GameManager.text("Open-air quick setup: carry your telescope out and observe right away. Same sky as the dome.", "露天快速架设：把你组装的望远镜搬出来立刻观测。与圆顶观星站看同一片天空。"), Rect2(455, 398, 120, 124))
	# The logbook is opened from the chair-side/lower edge of the desk. Keeping
	# the interaction center there also makes the route cue say "lower-left"
	# from the room's central telescope instead of incorrectly pointing upward.
	_register_interactable("journal", GameManager.text("Learning Journal", "学习日志"), GameManager.text("Review completed observations and learning cards.", "查看已完成的观测和学习卡。"), Rect2(96, 506, 214, 132))
	var remote_console := _remote_console_kind()
	if remote_console == "space":
		_register_interactable("computer", GameManager.text("Space Telescope Console", "空间望远镜控制台"), GameManager.text("Open the segmented infrared observatory command link.", "打开分段式红外空间望远镜指挥链路。"), Rect2(730, 492, 146, 116))
	elif remote_console == "radio":
		_register_interactable("computer", GameManager.text("FAST Radio Telescope Console", "FAST 射电望远镜控制台"), GameManager.text("Open the FAST radio telescope command link.", "打开 FAST 射电望远镜指挥链路。"), Rect2(730, 492, 146, 116))
	else:
		_register_interactable("computer", GameManager.text("Stats Terminal", "统计终端"), GameManager.text("Check telescope performance and readiness.", "查看望远镜性能和就绪状态。"), Rect2(730, 492, 146, 116))

	# Foot blockers only: keep furniture edges walkable while preventing the player from standing inside bases.
	obstacles.append_array([
		Rect2(92, 302, 190, 22),
		Rect2(474, 260, 74, 18),
		Rect2(646, 232, 94, 16),
		Rect2(812, 366, 126, 26),
		Rect2(128, 618, 150, 22),
		Rect2(756, 610, 106, 22)
	])


func _register_interactable(id: String, display_name: String, hint: String, rect: Rect2) -> void:
	var frame_color := BRASS if _is_ready_observation_target(id) else CYAN
	var frame := _thin_highlight_frame(rect, frame_color)
	frame.modulate.a = 0.0
	var click_target := _transparent_click_target(rect, id)
	interactables.append({
		"id": id,
		"name": display_name,
		"hint": hint,
		"rect": rect,
		"glow": frame,
		"click_target": click_target
	})


func _draw_player() -> void:
	player_shadow = _rect(_player_shadow_position(), Vector2(26, 7), Color(0.0, 0.0, 0.0, 0.32))
	player = Sprite2D.new()
	player_atlas = AtlasTexture.new()
	player_atlas.atlas = load(PLAYER_TEXTURE)
	player.texture = player_atlas
	player.position = _player_visual_position()
	player.centered = true
	player.scale = Vector2.ONE * PLAYER_DISPLAY_SCALE
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(player)
	_set_player_animation_frame("down", 0)


func _draw_hud() -> void:
	var top := Panel.new()
	top.name = "BaseTopHUD"
	top.position = Vector2(58, 10)
	top.size = Vector2(834, 50)
	top.add_theme_stylebox_override("panel", _style(NAVY, BRASS, 2, 4))
	add_child(top)
	_corner_pins(top)

	level_value_label = _label_to(top, "", Vector2(28, 10), Vector2(190, 26), 18, HORIZONTAL_ALIGNMENT_LEFT)
	credits_value_label = _label_to(top, "", Vector2(280, 10), Vector2(230, 26), 18, HORIZONTAL_ALIGNMENT_LEFT)
	telescope_status_label = _label_to(top, "", Vector2(548, 11), Vector2(258, 24), 16, HORIZONTAL_ALIGNMENT_LEFT)

	var menu := Button.new()
	menu.name = "MenuButton"
	menu.text = GameManager.text("Menu", "菜单")
	menu.position = Vector2(900, 18)
	menu.size = Vector2(76, 32)
	menu.add_theme_font_size_override("font_size", 10)
	menu.add_theme_stylebox_override("normal", _style(Color(0.055, 0.075, 0.120, 0.94), BRASS, 1, 3))
	menu.add_theme_stylebox_override("hover", _style(Color(0.10, 0.15, 0.22, 0.98), Color(1.0, 0.82, 0.42), 1, 3))
	menu.add_theme_stylebox_override("pressed", _style(Color(0.03, 0.05, 0.09, 1.0), Color(1.0, 0.82, 0.42), 1, 3))
	menu.add_theme_color_override("font_color", WARM_TEXT)
	menu.pressed.connect(func() -> void: GameManager.go("menu"))
	add_child(menu)

	# Base HUD ends here. Site travel belongs to Sky Observation, telescope
	# families belong to Assembly, and touch setup belongs to Settings/mobile UI.
	_draw_hud_lower()


func _draw_hud_lower() -> void:
	var bottom := Panel.new()
	bottom.position = Vector2(172, 704)
	bottom.size = Vector2(680, 48)
	bottom.add_theme_stylebox_override("panel", _style(NAVY, BRASS, 2, 4))
	add_child(bottom)
	_corner_pins(bottom)
	_label_to(bottom, "[E]", Vector2(40, 13), Vector2(38, 20), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, GameManager.text("INTERACT", "互动"), Vector2(84, 14), Vector2(96, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(bottom, GameManager.text("WASD / ARROWS", "WASD / 方向键"), Vector2(250, 14), Vector2(150, 18), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, GameManager.text("MOVE", "移动"), Vector2(406, 14), Vector2(58, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(bottom, "[TAB]", Vector2(510, 13), Vector2(54, 20), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(bottom, GameManager.text("MISSIONS", "任务"), Vector2(570, 14), Vector2(82, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)

	guidance_overlay = Control.new()
	guidance_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	guidance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_overlay.visible = false
	add_child(guidance_overlay)

	guidance_panel = Panel.new()
	guidance_panel.position = Vector2(222, 76)
	guidance_panel.size = Vector2(580, 170)
	guidance_panel.add_theme_stylebox_override("panel", _style(Color(0.030, 0.045, 0.080, 0.96), BRASS, 3, 6))
	guidance_panel.visible = InteractionFeedback.guidance_highlights_enabled()
	add_child(guidance_panel)
	_corner_pins(guidance_panel)
	guidance_maya_portrait = MayaPortrait.create(
		guidance_panel,
		"MayaRoomGuidancePortrait",
		MayaPortrait.EXPLAIN,
		Vector2(20, 28),
		Vector2(64, 104),
		1
	)
	guidance_title_label = _label_to(guidance_panel, "", Vector2(94, 14), Vector2(466, 30), 22, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_hint_label = _label_to(guidance_panel, "", Vector2(98, 48), Vector2(458, 52), 15, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_action_label = _label_to(guidance_panel, "", Vector2(98, 106), Vector2(458, 22), 14, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_action_label.add_theme_color_override("font_color", Color(0.52, 0.86, 1.0))
	guidance_outcome_label = _label_to(guidance_panel, "", Vector2(98, 136), Vector2(458, 20), 12, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_outcome_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.52))

	# Persistent route cue: compact enough to leave the room visible, but it
	# continuously points toward the next physical interaction target.
	route_edge_indicator = Control.new()
	route_edge_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	route_edge_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(route_edge_indicator)
	route_arrow_label = _label_to(route_edge_indicator, "▲", Vector2.ZERO, Vector2(54, 54), 34, HORIZONTAL_ALIGNMENT_CENTER)
	route_arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	route_arrow_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30))
	# The original triangle glyph was corrupted by a text-encoding conversion.
	# Use an ASCII caret so the directional cue renders consistently on Web.
	route_arrow_label.text = "^"
	route_distance_label = _label_to(route_edge_indicator, "", Vector2.ZERO, Vector2(160, 34), 12, HORIZONTAL_ALIGNMENT_CENTER)
	route_distance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_distance_label.add_theme_color_override("font_color", WARM_TEXT)
	route_edge_indicator.visible = false

	focus_label = _label("", Vector2(260, 662), Vector2(504, 20), 13, HORIZONTAL_ALIGNMENT_CENTER)
	if TouchInput.is_mobile():
		mobile_overlay = preload("res://scripts/ui/mobile_controls.gd").new()
		add_child(mobile_overlay)
		mobile_overlay.add_action_button("interact", GameManager.text("Interact", "互动"), _interact_with_nearby, 0)
		mobile_overlay.add_action_button("missions", GameManager.text("Missions", "任务"), _toggle_mission_board, 1)
		mobile_overlay.set_action_enabled("interact", false)
	feedback_label = _label(GameManager.text("Start at the Mission Board, then use the Assembly Table.", "先从任务公告板开始，然后去组装台。"), Vector2(112, 680), Vector2(800, 20), 13, HORIZONTAL_ALIGNMENT_CENTER)


func _move_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	# Mobile: the virtual joystick feeds the SAME movement path at the same
	# speed - keyboard and touch are interchangeable, never additive beyond 1.
	if direction == Vector2.ZERO:
		direction = TouchInput.move_vector()
	if direction == Vector2.ZERO:
		player_is_moving = false
		_update_player_animation(delta)
		return

	direction = direction.normalized()
	player_is_moving = true
	player_facing = _facing_from_direction(direction)
	_update_player_animation(delta)

	var next_pos := player_pos + direction * PLAYER_SPEED * delta
	next_pos.x = clampf(next_pos.x, ROOM_RECT.position.x + PLAYER_SIZE.x * 0.5, ROOM_RECT.end.x - PLAYER_SIZE.x * 0.5)
	next_pos.y = clampf(next_pos.y, ROOM_RECT.position.y + PLAYER_SIZE.y, ROOM_RECT.end.y)
	var next_rect := _player_collision_rect_for(next_pos)
	for obstacle in obstacles:
		if next_rect.intersects(obstacle):
			return
	_set_player_position(next_pos)


func _set_player_position(pos: Vector2) -> void:
	player_pos = pos
	if player_shadow != null:
		player_shadow.position = _player_shadow_position()
	if player != null:
		player.position = _player_visual_position()


func _player_visual_position() -> Vector2:
	# player_pos is the foot center; anchor the sprite so the drawn feet
	# (frame row PLAYER_FOOT_Y) land exactly on it.
	return player_pos - Vector2(0.0, (PLAYER_FOOT_Y - PLAYER_FRAME_SIZE.y * 0.5) * PLAYER_DISPLAY_SCALE)


func _player_shadow_position() -> Vector2:
	return player_pos - Vector2(13, 4)


func _player_collision_rect_for(pos: Vector2) -> Rect2:
	return Rect2(pos - Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y), PLAYER_SIZE)


func _facing_from_direction(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


func _update_player_animation(delta: float) -> void:
	if player_atlas == null:
		return
	if not player_is_moving:
		player_anim_frame = 0
		player_anim_time = 0.0
		_set_player_animation_frame(player_facing, player_anim_frame)
		return
	player_anim_time += delta
	var frame_duration := 1.0 / PLAYER_ANIM_FPS
	if player_anim_time >= frame_duration:
		player_anim_time = fmod(player_anim_time, frame_duration)
		player_anim_frame += 1
		if player_anim_frame > 3:
			player_anim_frame = 1
	if player_anim_frame == 0:
		player_anim_frame = 1
	_set_player_animation_frame(player_facing, player_anim_frame)


func _set_player_animation_frame(facing: String, frame: int) -> void:
	if player_atlas == null:
		return
	var row := 3
	match facing:
		"up":
			row = 3
		"left":
			row = 1
		"right":
			row = 2
		_:
			row = 0
	player_atlas.region = Rect2(
		float(frame) * PLAYER_FRAME_SIZE.x,
		float(row) * PLAYER_FRAME_SIZE.y,
		PLAYER_FRAME_SIZE.x,
		PLAYER_FRAME_SIZE.y
	)


func _update_nearby() -> void:
	var best_id := ""
	var best_distance := 99999.0
	var center := player_pos
	for data in interactables:
		var rect: Rect2 = data["rect"]
		var nearest := Vector2(
			clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y)
		)
		var distance := center.distance_to(nearest)
		if distance < best_distance and distance <= INTERACT_DISTANCE:
			best_distance = distance
			best_id = str(data["id"])
	nearby_id = best_id
	if mobile_overlay != null:
		# Interact button mirrors the E key: enabled near an interactable
		# and labeled with the object's name.
		if nearby_id == "":
			mobile_overlay.set_action_enabled("interact", false, GameManager.text("Interact", "互动"))
		else:
			mobile_overlay.set_action_enabled("interact", true, str(_get_interactable(nearby_id).get("name", "")))

	for data in interactables:
		var frame := data.get("glow") as CanvasItem
		if frame == null:
			continue
		var id := str(data["id"])
		if id == nearby_id:
			frame.modulate.a = 0.82
		elif id == GameManager.room_guidance_target and InteractionFeedback.guidance_highlights_enabled():
			frame.modulate.a = 0.72 + 0.18 * sin(float(Time.get_ticks_msec()) / 220.0)
		else:
			frame.modulate.a = 0.0


func _update_hud() -> void:
	var ready := GameManager.telescope_is_ready()
	level_value_label.text = GameManager.text("LEVEL %02d", "第 %02d 关") % int(GameManager.progress.get("current_level", 1))
	credits_value_label.text = GameManager.text("CLUB CREDITS %d", "社团积分 %d") % int(GameManager.progress.get("credits", 0))
	if GameManager.current_observation_mode() == "naked_eye":
		telescope_status_label.text = GameManager.text("MODE: NAKED EYE", "模式: 肉眼")
		telescope_status_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		telescope_status_label.text = GameManager.text("TELESCOPE: READY", "望远镜: 就绪") if ready else GameManager.text("TELESCOPE: NOT READY", "望远镜: 未就绪")
		telescope_status_label.add_theme_color_override("font_color", Color(0.48, 0.95, 0.36) if ready else Color(0.95, 0.72, 0.36))

	if nearby_id == "":
		focus_label.text = GameManager.text("Move around the observatory room", "在观测室里移动")
		if _has_feedback_override():
			InteractionFeedback.crossfade_text(feedback_label, feedback_override)
		elif GameManager.room_guidance_target != "" and InteractionFeedback.guidance_highlights_enabled():
			InteractionFeedback.crossfade_text(feedback_label, GameManager.room_guidance_hint)
		elif active_guidance == "ready_to_observe":
			feedback_label.text = GameManager.text(
				"Telescope ready. Go to the Telescope Observation Pad or Observatory Door to begin sky observation.",
				"望远镜已就绪。前往望远镜观测台或天文台门开始观星。"
			)
		elif ready:
			feedback_label.text = GameManager.text(
				"Ready to observe. Press E at the telescope pad or observatory door.",
				"可以观测了。在观测台或天文台门前按 E。"
			)
		else:
			feedback_label.text = GameManager.text("Check the Mission Board, then build the telescope at the Assembly Table.", "先查看任务公告板，然后去组装台制造望远镜。")
		_update_room_guidance_panel()
		return

	var item := _get_interactable(nearby_id)
	focus_label.text = "[E] " + str(item.get("name", ""))
	if _has_feedback_override():
		InteractionFeedback.crossfade_text(feedback_label, feedback_override)
	else:
		InteractionFeedback.crossfade_text(feedback_label, str(item.get("hint", "")))
	_update_room_guidance_panel()


func _interact_with_nearby() -> void:
	if nearby_id != "":
		_handle_interaction(nearby_id)


func _interact_at(pos: Vector2) -> void:
	for data in interactables:
		var rect: Rect2 = data["rect"]
		if rect.grow(12).has_point(pos):
			_click_interactable(str(data["id"]))
			return


func _click_interactable(id: String) -> void:
	if nearby_id == id:
		_handle_interaction(id)
		return
	_show_feedback(GameManager.text("Move closer to interact.", "靠近后互动。"), 1800)


func _handle_interaction(id: String) -> void:
	if furniture_interaction_active:
		return
	if id == "mission":
		GameManager.set_observatory_spawn("mission")
		_toggle_mission_board()
	elif id == "cabinet":
		_play_furniture_action("cabinet", _enter_parts_cabinet)
	elif id == "assembly":
		_play_furniture_action("assembly", _enter_assembly_table)
	elif id == "door":
		_play_furniture_action("door", _enter_observatory_door)
	elif id == "telescope":
		if GameManager.try_story_for_trigger("before_observation", "sky"):
			GameManager.set_observatory_spawn("telescope")
			return
		if GameManager.try_teaching_intercept("before_observation", "sky"):
			GameManager.set_observatory_spawn("telescope")
			return
		var gate: Dictionary = GameManager.can_enter_observation()
		if bool(gate.get("ok", false)):
			GameManager.set_observatory_spawn("telescope")
			GameManager.clear_room_guidance()
			_enter_sky_or_relocate("telescope")
		else:
			_show_feedback(GameManager.text(
				str(gate.get("reason_en", "The telescope is not ready yet. Go to the Assembly Table and install the core parts.")),
				str(gate.get("reason_zh", "望远镜还没有准备好。请到组装台安装核心部件。"))
			), 3600)
	elif id == "journal":
		_play_furniture_action("journal", _enter_learning_journal)
	elif id == "computer":
		_play_furniture_action("computer", _open_computer_station)


func _play_furniture_action(id: String, action: Callable) -> void:
	if furniture_interaction_active:
		return
	if furniture_animator == null or not furniture_animator.has_rig(id):
		action.call()
		return
	furniture_interaction_active = true
	furniture_animator.play_open(id, func() -> void:
		furniture_interaction_active = false
		if action.is_valid():
			action.call()
	)


func _enter_parts_cabinet() -> void:
	GameManager.set_observatory_spawn("cabinet")
	GameManager.clear_room_guidance()
	GameManager.go("parts")


func _enter_assembly_table() -> void:
	GameManager.set_observatory_spawn("assembly")
	# Re-enter the last bench directly. Telescope families are switched from
	# the Type button inside the blueprint, not through a repeated gate here.
	var assembly_dest := "assembly"
	if GameManager.try_story_for_trigger("before_assembly", assembly_dest):
		return
	if GameManager.try_teaching_intercept("before_assembly", assembly_dest):
		return
	GameManager.clear_room_guidance()
	GameManager.go(assembly_dest)


func _enter_observatory_door() -> void:
	GameManager.set_observatory_spawn("door")
	if GameManager.current_observation_mode() == "naked_eye":
		if GameManager.try_story_for_trigger("before_observation", "sky"):
			return
		if GameManager.try_teaching_intercept("before_observation", "sky"):
			return
		GameManager.clear_room_guidance()
		_enter_sky_or_relocate("door")
	else:
		GameManager.clear_room_guidance()
		GameManager.go("interior")


func _enter_learning_journal() -> void:
	GameManager.set_observatory_spawn("journal")
	GameManager.clear_room_guidance()
	GameManager.go("journal")


func _open_computer_station() -> void:
	GameManager.set_observatory_spawn("computer")
	if _space_console_active():
		_enter_space_console()
	else:
		_toggle_stats_terminal()


func _enter_space_console() -> void:
	if room_transition_active:
		return
	var gate: Dictionary = GameManager.can_enter_observation()
	if not bool(gate.get("ok", false)):
		_show_feedback(GameManager.text(
			str(gate.get("reason_en", "Finish assembling the space observatory before opening the command link.")),
			str(gate.get("reason_zh", "请先完成空间望远镜组装，再打开指挥链路。"))), 3600)
		return
	var destination := _remote_console_destination()
	if GameManager.try_story_for_trigger("before_observation", destination):
		return
	if GameManager.try_teaching_intercept("before_observation", destination):
		return
	_suspend_room_guidance_for_modal()
	pending_remote_console_scene = destination
	room_transition_active = true
	var overlay := Control.new()
	overlay.name = "SpaceConsoleTransition"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = COMPUTER_MODAL_LAYER
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var terminal := Panel.new()
	terminal.position = Vector2(738, 492)
	terminal.size = Vector2(138, 112)
	terminal.pivot_offset = terminal.size * 0.5
	terminal.add_theme_stylebox_override("panel", _style(Color(0.005, 0.005, 0.005, 0.98), Color.WHITE, 2, 0))
	overlay.add_child(terminal)
	var radio_console := _remote_console_kind() == "radio"
	_board_label(terminal, "UPLINK / FAST" if radio_console else "UPLINK / L2", Vector2(8, 8), Vector2(122, 18), 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for row in range(5):
		_rect_to(terminal, Vector2(12, 34 + row * 12), Vector2(110 - row * 9, 2), Color(0.72, 0.72, 0.72, 0.82))
	var scan := ColorRect.new()
	scan.color = Color(1, 1, 1, 0.92)
	scan.position = Vector2(0, 18)
	scan.size = Vector2(138, 2)
	terminal.add_child(scan)
	var status := _board_label(overlay,
		GameManager.text(
			"ESTABLISHING RADIO TELESCOPE LINK" if radio_console else "ESTABLISHING DEEP-SPACE COMMAND LINK",
			"正在建立射电望远镜链路" if radio_console else "正在建立深空指挥链路"),
		Vector2(240, 650), Vector2(544, 24), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	status.modulate.a = 0.0
	var tween := create_tween().bind_node(overlay).set_parallel(true)
	tween.tween_property(dim, "color:a", 0.88, 0.38)
	tween.tween_property(terminal, "position", Vector2(443, 248), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(terminal, "scale", Vector2(1.85, 1.85), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scan, "position:y", 102.0, 0.42).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(status, "modulate:a", 1.0, 0.18).set_delay(0.18)
	tween.chain().tween_callback(_finish_space_console_transition)


func _finish_space_console_transition() -> void:
	GameManager.clear_room_guidance()
	var destination := pending_remote_console_scene
	if destination == "":
		destination = _remote_console_destination()
	GameManager.go(destination)


func _enter_sky_or_relocate(spawn: String) -> void:
	# Delegates to the single unified observation entry so the open pad and the
	# dome interior share one horizon-aware path (no bypass, no lost state).
	GameManager.go_to_observation(spawn)


func _toggle_mission_board() -> void:
	if mission_board_popup != null:
		_close_mission_board(true)
		return
	_play_furniture_action("mission", _open_mission_board)


func _open_mission_board() -> void:
	if GameManager.campaign_completed():
		_open_graduated_mission_board()
		return
	_suspend_room_guidance_for_modal()
	var level := GameManager.current_level()
	var target := GameManager.current_target()
	var route := _mission_board_route()

	mission_board_popup = Control.new()
	mission_board_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mission_board_popup)
	InteractionFeedback.page_enter(mission_board_popup, Vector2(0, 8))

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.add_child(dim)

	var panel := Panel.new()
	panel.name = "MissionBoardPanel"
	panel.position = Vector2(36, 60)
	panel.size = Vector2(952, 650)
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.050, 0.090, 0.98), BRASS, 3, 5))
	mission_board_popup.add_child(panel)
	_corner_pins(panel)

	_board_label(panel, GameManager.text("CLUB MISSION", "俱乐部任务"), Vector2(22, 16), Vector2(220, 18), 12, BRASS)
	var level_number := int(level.get("level_number", 0))
	_board_label(panel, GameManager.text("LEVEL %02d", "第 %02d 关") % level_number, Vector2(718, 16), Vector2(210, 18), 12, CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	var title := _board_label(panel, GameManager.dict_text(level, "title"), Vector2(22, 38), Vector2(660, 34), 24, WARM_TEXT)
	title.max_lines_visible = 1
	var target_name := GameManager.dict_text(target, "name")
	_board_label(panel, GameManager.text("Target: ", "目标：") + target_name, Vector2(22, 78), Vector2(430, 22), 15, Color(0.96, 0.84, 0.46))
	_board_label(panel, GameManager.text("Mode: ", "模式：") + _mission_observation_mode_text(), Vector2(462, 78), Vector2(228, 22), 14, CYAN)
	_board_label(panel, _mission_readiness_text(route), Vector2(688, 78), Vector2(240, 22), 12, _mission_readiness_color(route), HORIZONTAL_ALIGNMENT_RIGHT)
	_rect_to(panel, Vector2(20, 110), Vector2(912, 1), Color(0.35, 0.45, 0.62, 0.72))

	var route_panel := _board_section(panel, Vector2(20, 128), Vector2(514, 326), GameManager.text("MISSION ROUTE", "任务路线"))
	_build_mission_checklist(route_panel, route)

	var info_panel := _board_section(panel, Vector2(550, 128), Vector2(382, 326), GameManager.text("MAYA'S NOTE", "玛雅的提示"))
	_build_mission_info_panel(info_panel, level, route)
	_build_mission_reward_preview(panel, level)

	var route_label := _board_label(panel, "", Vector2(26, 536), Vector2(900, 30), 14, Color(1.0, 0.82, 0.34), HORIZONTAL_ALIGNMENT_CENTER)
	route_label.text = GameManager.text("Next: ", "下一步：") + str(route.get("action", ""))
	route_label.clip_text = true

	var go_button := _board_button(panel, GameManager.text("Show Route", "显示路线"), Vector2(168, 582), Vector2(250, 42), Color(0.08, 0.28, 0.22), Color(0.56, 0.90, 0.54))
	go_button.name = "ShowRouteButton"
	go_button.pressed.connect(func() -> void: _close_mission_board(true))
	var log_button := _board_button(panel, GameManager.text("Open Logbook", "打开日志"), Vector2(434, 582), Vector2(250, 42), Color(0.06, 0.18, 0.34), Color(0.42, 0.74, 1.0))
	log_button.pressed.connect(_open_logbook_from_mission_board)
	var close_button := _board_button(panel, GameManager.text("Close", "关闭"), Vector2(700, 582), Vector2(126, 42), Color(0.12, 0.15, 0.22), Color(0.54, 0.62, 0.74))
	close_button.pressed.connect(func() -> void: _close_mission_board(true))
	InteractionFeedback.tutorial_highlight_once(panel, "first_mission_board", GameManager.text(
		"Review the route, required equipment, and next action before leaving.",
		"离开前先查看任务路线、所需装备和下一步操作。"
	), mission_board_popup)


func _open_graduated_mission_board() -> void:
	_suspend_room_guidance_for_modal()
	mission_board_popup = Control.new()
	mission_board_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mission_board_popup)
	InteractionFeedback.page_enter(mission_board_popup, Vector2(0, 8))

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.add_child(dim)

	var panel := Panel.new()
	panel.name = "GraduatedMissionBoardPanel"
	panel.position = Vector2(112, 82)
	panel.size = Vector2(800, 602)
	panel.add_theme_stylebox_override("panel", _style(Color(0.035, 0.050, 0.090, 0.99), BRASS, 3, 5))
	mission_board_popup.add_child(panel)
	_corner_pins(panel)

	_board_label(panel, GameManager.text("ASTRONOMY CLUB RECORD", "天文俱乐部记录"), Vector2(28, 20), Vector2(744, 24), 13, BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	_board_label(panel, GameManager.text("PROGRAM COMPLETE", "课程全部完成"), Vector2(28, 54), Vector2(744, 42), 29, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_board_label(panel, GameManager.text("YOUNG OBSERVER", "青年观测员"), Vector2(28, 102), Vector2(744, 24), 15, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_rect_to(panel, Vector2(36, 140), Vector2(728, 1), Color(0.72, 0.50, 0.22, 0.85))

	var completed_count := (GameManager.progress.get("completed_levels", []) as Array).size()
	var observed_count := (GameManager.progress.get("observed_objects", []) as Array).size()
	var journal_count := (GameManager.progress.get("journal_entries", []) as Array).size()
	var credits := int(GameManager.progress.get("credits", 0))
	var stats := GameManager.text(
		"Lessons %d    Objects %d    Log entries %d    Club Credits %d" % [completed_count, observed_count, journal_count, credits],
		"课程 %d    天体 %d    日志 %d    社团积分 %d" % [completed_count, observed_count, journal_count, credits]
	)
	_board_label(panel, stats, Vector2(40, 166), Vector2(720, 28), 15, Color(0.70, 0.92, 0.78), HORIZONTAL_ALIGNMENT_CENTER)

	var note_panel := _board_section(panel, Vector2(54, 216), Vector2(692, 226), GameManager.text("MAYA'S GRADUATION NOTE", "玛雅的毕业寄语"))
	var note := _board_label(note_panel, GameManager.text(
		"You learned to read the sky, build and align real instruments, judge observing conditions, and choose the right method instead of chasing a score. The last lesson is complete. From tonight onward, the questions are yours.",
		"你已经学会读懂天空、组装并校准真实仪器、判断观测条件，也懂得为目标选择正确方法，而不是只追逐分数。最后一课已经完成。从今晚起，问题由你来提出。"
	), Vector2(28, 52), Vector2(636, 118), 17, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_label(note_panel, GameManager.text(
		"Completed missions are archived. Opening this board will never restart the final lesson.",
		"已完成的任务已归档；再次打开任务板不会重启最后一课。"
	), Vector2(28, 176), Vector2(636, 28), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var ceremony_text := GameManager.text("Attend Ceremony", "参加毕业典礼") if GameManager.graduation_pending() \
		else GameManager.text("Replay Ceremony", "回看毕业典礼")
	var ceremony_button := _board_button(panel, ceremony_text, Vector2(82, 500), Vector2(210, 46), Color(0.34, 0.22, 0.07), Color(1.0, 0.78, 0.30))
	ceremony_button.name = "GraduationCeremonyButton"
	ceremony_button.pressed.connect(func() -> void: GameManager.go("graduation"))
	var log_button := _board_button(panel, GameManager.text("Open Logbook", "打开观测日志"), Vector2(306, 500), Vector2(210, 46), Color(0.06, 0.18, 0.34), Color(0.42, 0.74, 1.0))
	log_button.pressed.connect(_open_logbook_from_mission_board)
	var close_button := _board_button(panel, GameManager.text("Close", "关闭"), Vector2(530, 500), Vector2(188, 46), Color(0.12, 0.15, 0.22), Color(0.54, 0.62, 0.74))
	close_button.pressed.connect(func() -> void: _close_mission_board(true))


func _close_mission_board(show_guidance: bool) -> void:
	if mission_board_popup != null:
		var popup := mission_board_popup
		mission_board_popup = null
		InteractionFeedback.fade_then(popup, popup.queue_free)
	if furniture_animator != null:
		furniture_animator.play_close("mission")
	if show_guidance:
		var route := _mission_board_route()
		GameManager.set_room_guidance(str(route.get("target", "")), str(route.get("title", "")), str(route.get("hint", "")))
		active_guidance = "room_guidance"
		_resume_room_guidance_after_modal()


func _open_logbook_from_mission_board() -> void:
	if mission_board_popup != null:
		mission_board_popup.queue_free()
		mission_board_popup = null
	GameManager.set_observatory_spawn("journal")
	GameManager.go("journal")


func _mission_board_route() -> Dictionary:
	return GameManager.current_room_route()


func _mission_observation_mode_text() -> String:
	if GameManager.current_observation_mode() == "naked_eye":
		return GameManager.text("Naked Eye", "肉眼")
	if GameManager.current_observation_mode() == "constellation":
		return GameManager.text("Constellation Search", "星座搜寻")
	var required: Array = GameManager.current_level().get("required_parts", [])
	if required.has("finder_scope"):
		return GameManager.text("Finder Scope -> Telescope", "寻星镜 -> 望远镜")
	return GameManager.text("Telescope", "望远镜")


func _mission_readiness_text(route: Dictionary) -> String:
	if bool(route.get("ready", false)):
		return GameManager.text("READY TO OBSERVE", "可以观测")
	var missing_names := _mission_missing_names()
	if not missing_names.is_empty():
		return GameManager.text("MISSING: ", "缺少：") + ", ".join(missing_names)
	return GameManager.text("TELESCOPE NOT READY", "望远镜未就绪")


func _mission_readiness_color(route: Dictionary) -> Color:
	return Color(0.46, 0.94, 0.60) if bool(route.get("ready", false)) else Color(1.0, 0.64, 0.36)


func _mission_missing_names() -> Array[String]:
	var names: Array[String] = []
	for part_id in GameManager.missing_required_parts():
		var required_part := GameManager.get_part(part_id)
		var required_name := GameManager.dict_text(required_part, "name") if not required_part.is_empty() else str(part_id)
		if not names.has(required_name):
			names.append(required_name)
	var assembly_state: Dictionary = GameManager.progress.get("assembly_state", {})
	for part_type_value in GameManager.missing_parts():
		var part_type := str(part_type_value)
		var selected_part := GameManager.get_part(GameManager.equipped_part_id(part_type))
		var part_name := GameManager.dict_text(selected_part, "name") if not selected_part.is_empty() else part_type.capitalize()
		var part_state: Dictionary = assembly_state.get(part_type, {})
		if not bool(part_state.get("installed", false)) and not names.has(part_name):
			names.append(part_name)
	return names


func _mission_board_checklist(route: Dictionary) -> Array:
	var level := GameManager.current_level()
	var rows: Array = []
	rows.append({"label": GameManager.text("Read Maya's note", "阅读玛雅的提示"), "done": true})
	if not GameManager.current_requires_telescope():
		rows.append({"label": GameManager.text("Start naked-eye observation", "开始肉眼观测"), "done": false})
	else:
		var exact_missing := GameManager.missing_required_parts()
		rows.append({
			"label": GameManager.text("Equip required parts", "装备所需零件"),
			"done": exact_missing.is_empty()
		})
		var assembly_missing := GameManager.missing_parts()
		if GameManager.current_requires_focus() and assembly_missing.has("focus_knob"):
			rows.append({
				"label": GameManager.text("Install the Focus Knob near the eyepiece", "在目镜附近安装调焦旋钮"),
				"done": false
			})
		rows.append({
			"label": GameManager.text("Assemble the telescope", "组装望远镜"),
			"done": assembly_missing.is_empty() and GameManager.telescope_is_ready()
		})
		rows.append({"label": GameManager.text("Start observation", "开始观测"), "done": false})
		if GameManager.current_requires_focus() and str(level.get("variation", "")) != "eyepiece_comparison":
			rows.append({"label": GameManager.text("Adjust focus in Telescope View", "在望远镜视野中调焦"), "done": false})
	for special_row_value in _mission_special_rows(level):
		rows.append(special_row_value)
	if str(level.get("variation", "")) != "eyepiece_comparison":
		for step_value in GameManager.mission_steps():
			if not step_value is Dictionary:
				continue
			var step: Dictionary = step_value
			var step_id := str(step.get("id", ""))
			rows.append({
				"label": _mission_step_label(level, step),
				"done": GameManager.completed_mission_steps().has(step_id)
			})
	var target_name := GameManager.dict_text(GameManager.current_target(), "name")
	rows.append({"label": GameManager.text("Identify ", "识别") + target_name, "done": false})
	rows.append({"label": GameManager.text("Learning card unlocks after observation", "观测完成后解锁学习卡"), "done": false})
	var current_marked := false
	for row_value in rows:
		var row: Dictionary = row_value
		if not bool(row.get("done", false)) and not current_marked:
			row["current"] = true
			current_marked = true
		else:
			row["current"] = false
	return rows


func _mission_special_rows(level: Dictionary) -> Array:
	var variation := str(level.get("variation", ""))
	var target_name := GameManager.dict_text(GameManager.current_target(), "name")
	var rows: Array = []
	match variation:
		"eyepiece_comparison":
			var steps_done := GameManager.completed_mission_steps()
			rows.append({
				"label": GameManager.text("Low power: use 20mm, focus, observe " + target_name, "低倍率：使用 20mm，对焦后观测" + target_name),
				"done": steps_done.has("low_power")
			})
			rows.append({
				"label": GameManager.text("High power: switch to 10mm, refocus, observe again", "高倍率：换 10mm，重新调焦后再观测"),
				"done": steps_done.has("high_power")
			})
			rows.append({
				"label": GameManager.text("Compare image size, brightness, and steadiness", "比较图像大小、亮度和稳定性"),
				"done": steps_done.has("low_power") and steps_done.has("high_power")
			})
		"low_altitude_seeing":
			rows.append({"label": GameManager.text("Use low or medium power near the horizon", "低空目标使用低倍率或中倍率"), "done": false})
			rows.append({"label": GameManager.text("Separate atmospheric seeing from focus", "区分大气扰动与失焦"), "done": false})
		"moon_high_power_refocus":
			rows.append({"label": GameManager.text("Switch to high power, then refocus", "切到高倍率后重新调焦"), "done": false})
		"coordinate_navigation":
			rows.append({"label": GameManager.text("Read " + target_name + " Az/Alt coordinates", "读取" + target_name + "的方位角与俯仰角"), "done": false})
			rows.append({"label": GameManager.text("Aim by coordinates, not by the hint circle", "按坐标转向，不依赖提示圈"), "done": false})
		"finder_calibration":
			rows.append({"label": GameManager.text("Center a bright star in the main telescope", "在主望远镜中居中一颗亮星"), "done": false})
			rows.append({"label": GameManager.text("Align the finder to within 0.5 degrees", "把寻星镜校准到 0.5 度以内"), "done": GameManager.is_finder_aligned()})
		"workflow_discipline", "independent_random_target":
			rows.append({"label": GameManager.text("Navigate Eye -> Finder -> Telescope", "按肉眼 -> 寻星镜 -> 主望远镜导航"), "done": false})
		"accept_fair_quality":
			rows.append({"label": GameManager.text("Wait for dark adaptation", "等待暗适应完成"), "done": false})
			rows.append({"label": GameManager.text("Use averted vision to reveal the faint glow", "使用侧视法寻找暗淡光斑"), "done": false})
		"aperture_upgrade_comparison":
			rows.append({"label": GameManager.text("Equip the 100mm objective", "装备 100mm 大口径物镜"), "done": GameManager.equipped_part_id("objective") == "objective_100mm"})
		"city_sky":
			rows.append({"label": GameManager.text("Record the target even with city glow", "即使有城市光污染也记录目标"), "done": false})
		"dark_sky":
			rows.append({"label": GameManager.text("Let your eyes adapt to the darker sky", "让眼睛适应更暗的天空"), "done": false})
		"drift":
			rows.append({"label": GameManager.text("Keep " + target_name + " centered for %ds" % int(level.get("hold_seconds", 0)), "让" + target_name + "居中保持 %d 秒" % int(level.get("hold_seconds", 0))), "done": false})
		"tracking_mount":
			rows.append({"label": GameManager.text("Equip the tracking mount", "装备追踪支架"), "done": GameManager.has_tracking_mount_equipped()})
			rows.append({"label": GameManager.text("Set tracking close to 1.0x", "把追踪速率调到接近 1.0 倍"), "done": absf(GameManager.tracking_rate() - 1.0) <= 0.10})
		"final_endurance_watch":
			rows.append({"label": GameManager.text("Hold " + target_name + " centered for %ds without drifting", "让" + target_name + "持续居中 %d 秒且不漂移" % int(level.get("hold_seconds", 0))), "done": false})
	return rows


func _mission_step_label(level: Dictionary, step: Dictionary) -> String:
	var variation := str(level.get("variation", ""))
	var step_id := str(step.get("id", ""))
	if variation == "eyepiece_comparison":
		if step_id == "low_power":
			return GameManager.text("Low power pass: use 20mm, focus, observe " + GameManager.dict_text(GameManager.current_target(), "name"), "低倍率步骤：使用 20mm，对焦后观测" + GameManager.dict_text(GameManager.current_target(), "name"))
		if step_id == "high_power":
			return GameManager.text("High power pass: switch to 10mm, refocus, observe again", "高倍率步骤：换 10mm，重新调焦后再观测")
	return GameManager.dict_text(step, "label")


func _build_mission_checklist(parent: Control, route: Dictionary) -> void:
	var route_copy := GameManager.text("Follow the highlighted route in the observatory.", "跟随大厅中高亮的路线。") \
		if InteractionFeedback.guidance_highlights_enabled() \
		else GameManager.text("Guidance highlights are off. Use the room labels and explore freely.", "高光引导已关闭；请查看房间标签并自由探索。")
	var route_text := _board_label(parent, route_copy, Vector2(14, 30), Vector2(482, 18), 10, Color(0.62, 0.73, 0.85))
	route_text.clip_text = true
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 56)
	scroll.size = Vector2(490, 256)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var route_target := str(route.get("target", ""))
	for row_value in _mission_board_checklist(route):
		var row: Dictionary = row_value
		var done := bool(row.get("done", false))
		var current := bool(row.get("current", false))
		var card := Panel.new()
		card.custom_minimum_size = Vector2(468, 38)
		var fill := Color(0.045, 0.070, 0.105, 0.96)
		var border := Color(0.16, 0.25, 0.36, 0.85)
		if done:
			fill = Color(0.04, 0.16, 0.11, 0.96)
			border = Color(0.30, 0.78, 0.50, 0.95)
		elif current:
			fill = Color(0.22, 0.15, 0.055, 0.98)
			border = Color(1.0, 0.76, 0.26, 0.98)
		card.add_theme_stylebox_override("panel", _style(fill, border, 1 if not current else 2, 3))
		list.add_child(card)
		var marker := "✓" if done else (">" if current else "○")
		var marker_color := Color(0.42, 0.95, 0.60) if done else (Color(1.0, 0.84, 0.30) if current else Color(0.48, 0.60, 0.72))
		_board_label(card, marker, Vector2(10, 8), Vector2(24, 22), 16, marker_color, HORIZONTAL_ALIGNMENT_CENTER)
		var label := _board_label(card, str(row.get("label", "")), Vector2(40, 5), Vector2(414, 28), 12, WARM_TEXT)
		label.max_lines_visible = 2
		if current and route_target != "":
			label.tooltip_text = str(route.get("action", ""))


func _build_mission_info_panel(parent: Control, level: Dictionary, route: Dictionary) -> void:
	var note := GameManager.mission_board_note()
	var note_text := GameManager.text(str(note.get("en", "")), str(note.get("zh", "")))
	var lesson_hint := GameManager.dict_text(level, "hint_text")
	if note_text == "":
		note_text = GameManager.dict_text(level, "description")
	if lesson_hint != "" and not note_text.contains(lesson_hint):
		note_text += "\n" + lesson_hint
	MayaPortrait.create(
		parent,
		"MayaMissionNotePortrait",
		MayaPortrait.tutorial_pose("mission_%s" % str(route.get("target", "")), note_text),
		Vector2(12, 32),
		Vector2(76, 68),
		1
	)
	var maya_note := _board_label(parent, "\"" + note_text + "\"", Vector2(94, 32), Vector2(274, 62), 11, Color(0.98, 0.85, 0.58))
	maya_note.max_lines_visible = 4
	_rect_to(parent, Vector2(14, 102), Vector2(354, 1), Color(0.30, 0.40, 0.55, 0.70))
	_board_label(parent, GameManager.text("REQUIRED EQUIPMENT", "所需设备"), Vector2(14, 112), Vector2(354, 16), 11, CYAN)
	_build_required_equipment_list(parent)
	_rect_to(parent, Vector2(14, 210), Vector2(354, 1), Color(0.30, 0.40, 0.55, 0.70))
	_board_label(parent, GameManager.text("READINESS", "准备状态"), Vector2(14, 220), Vector2(354, 16), 11, CYAN)
	var readiness := _mission_readiness_text(route)
	var readiness_label := _board_label(parent, readiness, Vector2(14, 240), Vector2(354, 28), 12, _mission_readiness_color(route))
	readiness_label.max_lines_visible = 2
	var target_line := _board_label(parent, GameManager.text("Why this mission: ", "本关重点：") + GameManager.dict_text(level, "description"), Vector2(14, 276), Vector2(354, 38), 10, Color(0.73, 0.81, 0.90))
	target_line.max_lines_visible = 2


func _build_required_equipment_list(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 130)
	scroll.size = Vector2(354, 70)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	if not GameManager.current_requires_telescope():
		_board_equipment_line(list, GameManager.text("No telescope equipment required", "无需望远镜设备"), true, GameManager.text("Naked eye", "肉眼"))
		return
	var assembly_state: Dictionary = GameManager.progress.get("assembly_state", {})
	var exact_missing := GameManager.missing_required_parts()
	var added_types: Array[String] = []
	var ordered_types: Array = []
	var missing_types: Array = GameManager.missing_parts()
	if GameManager.current_requires_focus() and missing_types.has("focus_knob"):
		ordered_types.append("focus_knob")
	for part_type_value in missing_types:
		if not ordered_types.has(part_type_value):
			ordered_types.append(part_type_value)
	for part_type_value in GameManager.current_level().get("required_parts", []):
		if not ordered_types.has(part_type_value):
			ordered_types.append(part_type_value)
	for part_type_value in ordered_types:
		var part_type := str(part_type_value)
		if added_types.has(part_type):
			continue
		added_types.append(part_type)
		var selected_id := GameManager.equipped_part_id(part_type)
		var selected_part := GameManager.get_part(selected_id)
		var name := GameManager.dict_text(selected_part, "name") if not selected_part.is_empty() else part_type.capitalize()
		var part_state: Dictionary = assembly_state.get(part_type, {})
		var installed := bool(part_state.get("installed", false))
		_board_equipment_line(list, name, installed, GameManager.text("Installed", "已安装") if installed else GameManager.text("Needs assembly", "待安装"))
	for part_id in exact_missing:
		var required_part := GameManager.get_part(part_id)
		var required_name := GameManager.dict_text(required_part, "name") if not required_part.is_empty() else str(part_id)
		_board_equipment_line(list, required_name, false, GameManager.text("Missing", "缺少"))


func _board_equipment_line(parent: Control, name: String, ready: bool, status: String) -> void:
	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(336, 18)
	line.add_theme_constant_override("separation", 6)
	parent.add_child(line)
	var dot := Label.new()
	dot.text = "●"
	dot.custom_minimum_size = Vector2(12, 18)
	dot.add_theme_font_size_override("font_size", 10)
	dot.add_theme_color_override("font_color", Color(0.42, 0.95, 0.60) if ready else Color(1.0, 0.64, 0.34))
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(dot)
	var name_label := Label.new()
	name_label.text = name
	name_label.custom_minimum_size = Vector2(218, 18)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", WARM_TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)
	var status_label := Label.new()
	status_label.text = status
	status_label.custom_minimum_size = Vector2(92, 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(0.42, 0.95, 0.60) if ready else Color(1.0, 0.70, 0.36))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(status_label)


func _build_mission_reward_preview(parent: Control, level: Dictionary) -> void:
	_board_label(parent, GameManager.text("REWARD PREVIEW", "奖励预览"), Vector2(26, 462), Vector2(180, 16), 11, BRASS)
	_rect_to(parent, Vector2(20, 480), Vector2(912, 1), Color(0.30, 0.40, 0.55, 0.70))
	var items := _mission_reward_preview_items(level)
	var row := HBoxContainer.new()
	row.position = Vector2(26, 488)
	row.size = Vector2(900, 32)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	for item_value in items:
		var item: Dictionary = item_value
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(float(item.get("width", 170.0)), 30)
		chip.add_theme_stylebox_override("panel", _style(Color(0.055, 0.085, 0.12, 0.96), Color(0.25, 0.40, 0.58, 0.90), 1, 3))
		row.add_child(chip)
		var title := _board_label(chip, str(item.get("title", "")), Vector2(8, 3), Vector2(chip.custom_minimum_size.x - 16.0, 22), 10, Color(0.92, 0.84, 0.54), HORIZONTAL_ALIGNMENT_CENTER)
		title.clip_text = true


func _mission_reward_preview_items(level: Dictionary) -> Array:
	var items: Array = []
	var credits := int(level.get("reward_credits", 0))
	if credits > 0:
		items.append({"title": GameManager.text("+%d Club Credits", "+%d 社团积分") % credits, "width": 164.0})
	var concept_id := str(level.get("required_concept_card", ""))
	if concept_id != "":
		var concept := GameManager.get_learning_card(concept_id)
		var concept_title := GameManager.dict_text(concept, "title") if not concept.is_empty() else GameManager.text("Journal Entry", "观测日志")
		items.append({"title": GameManager.text("Learn: ", "知识：") + concept_title, "width": 216.0})
	var badge := str(level.get("badge", ""))
	if badge != "":
		items.append({"title": GameManager.text("Badge: ", "徽章：") + _mission_badge_text(badge), "width": 174.0})
	var unlock_names: Array[String] = []
	for part_id in level.get("unlock_parts", []):
		var part := GameManager.get_part(str(part_id))
		if not part.is_empty():
			unlock_names.append(GameManager.dict_text(part, "name"))
	if not unlock_names.is_empty():
		items.append({"title": GameManager.text("New gear: ", "新装备：") + ", ".join(unlock_names), "width": 246.0})
	return items


func _mission_badge_text(badge: String) -> String:
	return GameManager.badge_display_name(badge)


func _board_section(parent: Control, pos: Vector2, section_size: Vector2, title: String) -> Panel:
	var section := Panel.new()
	section.position = pos
	section.size = section_size
	section.add_theme_stylebox_override("panel", _style(Color(0.025, 0.040, 0.072, 0.94), Color(0.22, 0.34, 0.50, 0.92), 1, 3))
	parent.add_child(section)
	_board_label(section, title, Vector2(14, 10), Vector2(section_size.x - 28, 18), 12, BRASS)
	_rect_to(section, Vector2(12, 28), Vector2(section_size.x - 24, 1), Color(0.30, 0.40, 0.55, 0.70))
	return section


func _board_button(parent: Control, text: String, pos: Vector2, button_size: Vector2, normal_color: Color, border_color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", WARM_TEXT)
	button.add_theme_stylebox_override("normal", _style(normal_color, border_color, 2, 4))
	button.add_theme_stylebox_override("hover", _style(normal_color.lightened(0.12), border_color.lightened(0.12), 2, 4))
	button.add_theme_stylebox_override("pressed", _style(normal_color.darkened(0.12), border_color, 2, 4))
	parent.add_child(button)
	return button


func _board_label(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := _label_to(parent, text, pos, label_size, font_size, align)
	label.add_theme_color_override("font_color", color)
	return label


func _maybe_show_unlock_popup() -> void:
	# Announce newly unlocked equipment with an unmissable Maya popup, so
	# upgrades never arrive silently.
	var pending: Array = GameManager.take_pending_unlock_notice()
	if pending.is_empty():
		return

	_suspend_room_guidance_for_modal()
	unlock_popup = Control.new()
	unlock_popup.name = "EquipmentUnlockPopup"
	unlock_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	unlock_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	unlock_popup.z_index = COMPUTER_MODAL_LAYER
	add_child(unlock_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.60)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	unlock_popup.add_child(dim)

	var line_count := mini(pending.size(), 4)
	var panel_height := 250.0 + float(line_count) * 26.0
	var panel := Panel.new()
	panel.position = Vector2(252, 384.0 - panel_height * 0.5)
	panel.size = Vector2(520, panel_height)
	panel.add_theme_stylebox_override("panel", _style(Color(0.040, 0.055, 0.100, 0.98), Color(0.98, 0.80, 0.36), 3, 6))
	unlock_popup.add_child(panel)

	MayaPortrait.create(
		unlock_popup,
		"MayaEquipmentUnlockPortrait",
		MayaPortrait.DISCOVER,
		panel.position + Vector2(28, 48),
		Vector2(72, 112),
		1
	)

	var x_text := panel.position.x + 140.0
	var y := panel.position.y + 18.0
	_popup_label_on(unlock_popup, GameManager.text("NEW EQUIPMENT UNLOCKED!", "新装备已解锁！"), Vector2(panel.position.x + 20, y), Vector2(480, 24), 15, Color(0.98, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	y += 34.0
	var maya_line := _popup_label_on(unlock_popup,
		GameManager.text("Maya: \"New parts just arrived for the club!\"", "Maya：“俱乐部的新零件到货啦！”"),
		Vector2(x_text, y), Vector2(360, 40), 12, WARM_TEXT)
	maya_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 44.0
	for index in range(line_count):
		var part: Dictionary = GameManager.get_part(str(pending[index]))
		var part_name := GameManager.dict_text(part, "name")
		_popup_label_on(unlock_popup, "•  " + part_name, Vector2(x_text, y), Vector2(360, 22), 13, Color(0.60, 0.95, 0.70))
		y += 26.0
	y += 10.0
	var hint := _popup_label_on(unlock_popup,
		GameManager.text("Equip them at the Parts Cabinet, then reassemble at the Assembly Table.", "到零件柜装备它们，然后在组装台重新组装。"),
		Vector2(x_text, y), Vector2(360, 40), 11, Color(0.78, 0.86, 0.92))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var later := Button.new()
	later.text = GameManager.text("Later", "稍后")
	later.position = Vector2(350, panel.position.y + panel_height - 52.0)
	later.size = Vector2(132, 38)
	later.add_theme_font_size_override("font_size", 13)
	later.pressed.connect(func() -> void:
		_close_unlock_popup(true)
	)
	unlock_popup.add_child(later)

	var equip_now := Button.new()
	equip_now.text = GameManager.text("Equip New Parts", "前往装备新零件")
	equip_now.position = Vector2(492, panel.position.y + panel_height - 52.0)
	equip_now.size = Vector2(220, 38)
	equip_now.add_theme_font_size_override("font_size", 13)
	equip_now.pressed.connect(func() -> void:
		_close_unlock_popup(false)
		GameManager.set_room_guidance(
			"cabinet",
			GameManager.text("Maya: Equip the New Parts", "玛雅：装备新零件"),
			GameManager.text(
				"Choose the newly unlocked parts here. After equipping them, the route continues to the Assembly Table.",
				"在零件柜选择刚解锁的部件；装备后，引导会继续带你前往组装台安装。"
			)
		)
		GameManager.go("parts")
	)
	unlock_popup.add_child(equip_now)


func _close_unlock_popup(resume_guidance: bool) -> void:
	if unlock_popup != null:
		var popup := unlock_popup
		unlock_popup = null
		InteractionFeedback.fade_then(popup, popup.queue_free)
	if resume_guidance:
		_resume_room_guidance_after_modal()


func _popup_label_on(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _toggle_stats_terminal() -> void:
	# Stats Terminal popup: telescope performance + what Club Credits are for.
	if stats_terminal_popup != null:
		stats_terminal_popup.queue_free()
		stats_terminal_popup = null
		_resume_room_guidance_after_modal()
		if furniture_animator != null:
			furniture_animator.play_close("computer")
		return
	var stats := GameManager.calculate_stats()

	_suspend_room_guidance_for_modal()
	stats_terminal_popup = Control.new()
	stats_terminal_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_terminal_popup.z_index = COMPUTER_MODAL_LAYER
	add_child(stats_terminal_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(158, 60)
	panel.size = Vector2(708, 654)
	panel.add_theme_stylebox_override("panel", _style(Color(0.030, 0.055, 0.060, 0.98), Color(0.35, 0.85, 0.55), 3, 5))
	stats_terminal_popup.add_child(panel)

	_terminal_label(GameManager.text("STATS TERMINAL", "统计终端"), Vector2(178, 104), Vector2(668, 24), 16, Color(0.45, 0.95, 0.60), HORIZONTAL_ALIGNMENT_CENTER)

	var rows: Array = [
		[GameManager.text("Assembly", "组装"), float(stats.get("assembly_score", 0.0))],
		[GameManager.text("Light", "集光"), float(stats.get("light_score", 0.0))],
		[GameManager.text("Clarity", "清晰"), float(stats.get("clarity_score", 0.0))],
		[GameManager.text("Stability", "稳定"), float(stats.get("stability_score", 0.0))],
		[GameManager.text("Focus Ctrl", "调焦"), float(stats.get("focus_control_score", 0.0))]
	]
	var y := 150.0
	for row_value in rows:
		var row: Array = row_value
		var value: float = float(row[1])
		_terminal_label(str(row[0]), Vector2(188, y), Vector2(140, 18), 12, WARM_TEXT)
		var bar_bg := ColorRect.new()
		bar_bg.position = Vector2(330, y + 4)
		bar_bg.size = Vector2(154, 10)
		bar_bg.color = Color(0.06, 0.10, 0.10)
		stats_terminal_popup.add_child(bar_bg)
		var fill := ColorRect.new()
		fill.position = Vector2(330, y + 4)
		fill.size = Vector2(clampf(value, 0.0, 100.0) * 1.54, 10)
		fill.color = Color(0.40, 0.85, 0.55)
		stats_terminal_popup.add_child(fill)
		_terminal_label(str(snapped(value, 0.1)), Vector2(490, y), Vector2(42, 18), 12, Color(0.80, 0.95, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
		y += 25.0

	var divider := ColorRect.new()
	divider.position = Vector2(180, y + 8)
	divider.size = Vector2(350, 1)
	divider.color = Color(0.35, 0.85, 0.55, 0.4)
	stats_terminal_popup.add_child(divider)

	_terminal_label(GameManager.text("CLUB CREDITS: %d", "社团积分：%d") % int(GameManager.progress.get("credits", 0)), Vector2(180, y + 20), Vector2(350, 24), 16, Color(0.98, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	var note := _terminal_label(
		GameManager.text("Club Credits are saved for future equipment upgrades.", "社团积分将用于后续设备升级。"),
		Vector2(190, y + 50), Vector2(330, 40), 11, Color(0.78, 0.88, 0.82), HORIZONTAL_ALIGNMENT_CENTER
	)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var shop := Button.new()
	shop.text = GameManager.text("Upgrade Shop - Coming Soon", "升级商店 - 即将开放")
	shop.disabled = true
	shop.position = Vector2(200, y + 96)
	shop.size = Vector2(310, 34)
	shop.add_theme_font_size_override("font_size", 12)
	stats_terminal_popup.add_child(shop)

	var close := Button.new()
	close.text = GameManager.text("Close", "关闭").replace("\n", " · ")
	close.position = Vector2(432, y + 140)
	close.size = Vector2(160, 36)
	close.add_theme_font_size_override("font_size", 14)
	close.pressed.connect(_toggle_stats_terminal)
	stats_terminal_popup.add_child(close)

	# Live saved state, shared with assembly, missions, and the logbook.
	var selected_parts: Dictionary = GameManager.get_selected_parts()
	var equipped_names: Array[String] = []
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece", "focus_knob", "finder_scope"]:
		var part: Dictionary = selected_parts.get(part_type, {})
		if not part.is_empty():
			equipped_names.append(GameManager.dict_text(part, "name"))
	var completed_count := (GameManager.progress.get("completed_levels", []) as Array).size()
	var journal_count := (GameManager.progress.get("journal_entries", []) as Array).size()
	var concept_count := (GameManager.progress.get("completed_concept_cards", []) as Array).size()
	var unlocked_count := (GameManager.progress.get("unlocked_parts", []) as Array).size()
	_terminal_label(GameManager.text("EQUIPPED SETUP", "当前装备"), Vector2(556, 150), Vector2(282, 20), 13, Color(0.46, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var setup := _terminal_label(
		"\n".join(equipped_names) if not equipped_names.is_empty() else GameManager.text("No equipment selected", "尚未选择装备"),
		Vector2(556, 176), Vector2(282, 126), 11, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER
	)
	setup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup.clip_text = true
	_terminal_label(GameManager.text("PROGRESS", "进度"), Vector2(556, 316), Vector2(282, 20), 13, Color(0.46, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_terminal_label(
		GameManager.text("Levels: %d   Knowledge cards: %d\nUnlocked parts: %d", "已完成关卡：%d   知识卡：%d\n已解锁零件：%d") % [completed_count, concept_count, unlocked_count],
		Vector2(556, 342), Vector2(282, 48), 12, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER
	)
	_terminal_label(GameManager.text("OBSERVATION HISTORY", "观测历史"), Vector2(556, 410), Vector2(282, 20), 13, Color(0.46, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_terminal_label(
		GameManager.text("Recorded sessions: %d\nObserved objects: %d", "记录次数：%d\n已观测天体：%d") % [journal_count, (GameManager.progress.get("observed_objects", []) as Array).size()],
		Vector2(556, 436), Vector2(282, 48), 12, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER
	)

	# ---- Observing site: where on Earth this club actually sits ----
	var site: Dictionary = GameManager.site_info()
	var site_divider := ColorRect.new()
	site_divider.position = Vector2(178, 478)
	site_divider.size = Vector2(668, 1)
	site_divider.color = Color(0.35, 0.85, 0.55, 0.4)
	stats_terminal_popup.add_child(site_divider)
	_terminal_label(GameManager.text("OBSERVING SITE", "观测站信息"), Vector2(178, 488), Vector2(668, 20), 13, Color(0.46, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	var map_path := "res://assets/learning_diagrams/site_map.png"
	if ResourceLoader.exists(map_path):
		var map_rect := TextureRect.new()
		map_rect.custom_minimum_size = Vector2.ZERO
		map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_rect.texture = load(map_path)
		map_rect.position = Vector2(178, 514)
		map_rect.size = Vector2(336, 189)
		stats_terminal_popup.add_child(map_rect)
	var seeing_text := GameManager.text("good", "好")
	match str(site.get("seeing", "")):
		"average": seeing_text = GameManager.text("average", "中")
		"poor": seeing_text = GameManager.text("poor", "差")
	var site_facts := _terminal_label(
		GameManager.text(
			"Latitude %s | Longitude %s\nAltitude %s\nRegion: %s\nLight pollution: %s\nTonight: seeing %s, clouds %d%%\nWeather index: %d / 10",
			"纬度 %s | 经度 %s\n海拔 %s\n区域环境：%s\n光污染：%s\n今晚：视宁度%s，云量 %d%%\n天气指数：%d / 10"
		) % [str(site["lat"]), str(site["lon"]), str(site["altitude"]),
			GameManager.text(str(site["region_en"]), str(site["region_zh"])),
			str(site["bortle"]), seeing_text, int(site["cloud_pct"]), int(site["weather_index"])],
		Vector2(530, 514), Vector2(316, 189), 12, WARM_TEXT
	)
	site_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _terminal_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_terminal_popup.add_child(label)
	return label


func _show_feedback(text: String, duration_msec: int = 2800) -> void:
	feedback_override = text
	feedback_override_until_msec = Time.get_ticks_msec() + duration_msec
	if feedback_label != null:
		feedback_label.text = text


func _has_feedback_override() -> bool:
	if feedback_override == "":
		return false
	if Time.get_ticks_msec() <= feedback_override_until_msec:
		return true
	feedback_override = ""
	return false


func _suspend_room_guidance_for_modal() -> void:
	room_guidance_suspended = true
	if guidance_panel != null:
		guidance_panel.visible = false
	if route_edge_indicator != null:
		route_edge_indicator.visible = false
	if guidance_overlay != null:
		_clear(guidance_overlay)
		guidance_overlay.visible = false
	# One-shot Maya bubbles use a global z-index of 900. They belong to the
	# lobby, so dismiss only bubbles parented under this room before showing a
	# computer modal at the dedicated computer layer.
	for overlay in get_tree().get_nodes_in_group("guidance_highlight"):
		if overlay != null and is_instance_valid(overlay) and is_ancestor_of(overlay):
			overlay.queue_free()


func _resume_room_guidance_after_modal() -> void:
	room_guidance_suspended = false
	_update_room_guidance_panel()


func _update_room_guidance_panel() -> void:
	if guidance_panel == null:
		return
	if room_guidance_suspended:
		guidance_panel.visible = false
		if route_edge_indicator != null:
			route_edge_indicator.visible = false
		_update_guidance_overlay({})
		return
	if not InteractionFeedback.guidance_highlights_enabled():
		guidance_panel.visible = false
		if route_edge_indicator != null:
			route_edge_indicator.visible = false
		_update_guidance_overlay({})
		return
	if GameManager.room_guidance_target == "":
		guidance_panel.visible = false
		if route_edge_indicator != null:
			route_edge_indicator.visible = false
		_update_guidance_overlay({})
		return
	if not guidance_panel.visible:
		# First appearance: slide down 8px + fade, matching the page style.
		guidance_panel.visible = true
		if not InteractionFeedback.is_reduced_motion():
			var rest := guidance_panel.position
			guidance_panel.position = rest + Vector2(0, -8)
			guidance_panel.modulate.a = 0.0
			var tween := guidance_panel.create_tween().set_parallel(true)
			tween.tween_property(guidance_panel, "position", rest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(guidance_panel, "modulate:a", 1.0, 0.18)
	guidance_panel.visible = true
	if guidance_maya_portrait != null:
		MayaPortrait.apply_to(
			guidance_maya_portrait,
			MayaPortrait.tutorial_pose(GameManager.room_guidance_target, GameManager.room_guidance_hint)
		)
	guidance_title_label.text = GameManager.room_guidance_title
	var target_name := ""
	var item := _get_interactable(GameManager.room_guidance_target)
	if not item.is_empty():
		target_name = str(item.get("name", ""))
	var target_center: Vector2 = item.get("rect", Rect2()).get_center()
	var delta := target_center - player_pos
	var distance := int(round(delta.length()))
	# The diagnostic must stay visible while the movement cue changes below.
	# Otherwise a precise loadout error collapses back to "Go to cabinet".
	guidance_hint_label.text = GameManager.room_guidance_hint
	if nearby_id == GameManager.room_guidance_target:
		guidance_action_label.text = "[E] " + target_name + " · " + GameManager.text("Press E to continue", "按 E 继续")
		if route_edge_indicator != null:
			route_edge_indicator.visible = false
	else:
		guidance_action_label.text = _route_target_prompt(GameManager.room_guidance_target) + " · " + _route_move_hint(delta)
		_update_route_edge_indicator(delta, _route_target_prompt(GameManager.room_guidance_target), distance)
	if guidance_outcome_label != null:
		var route := GameManager.current_room_route()
		guidance_outcome_label.text = str(route.get("outcome", "")) if str(route.get("target", "")) == GameManager.room_guidance_target else ""
	_update_guidance_overlay(item)


func _update_guidance_overlay(item: Dictionary) -> void:
	if guidance_overlay == null:
		return
	_clear(guidance_overlay)
	if room_guidance_suspended or item.is_empty() or not InteractionFeedback.guidance_highlights_enabled():
		guidance_overlay.visible = false
		return
	guidance_overlay.visible = true
	var rect: Rect2 = item.get("rect", Rect2()).grow(24.0)
	rect.position.x = clampf(rect.position.x, 0.0, W)
	rect.position.y = clampf(rect.position.y, 0.0, H)
	rect.size.x = clampf(rect.size.x, 0.0, W - rect.position.x)
	rect.size.y = clampf(rect.size.y, 0.0, H - rect.position.y)
	# Dim everything except the guided device (four rects around its cutout)
	# so the next destination is unmistakable.
	var dim_color := Color(0.0, 0.0, 0.0, 0.34)
	for dim_rect in [
		Rect2(0, 0, W, rect.position.y),
		Rect2(0, rect.end.y, W, H - rect.end.y),
		Rect2(0, rect.position.y, rect.position.x, rect.size.y),
		Rect2(rect.end.x, rect.position.y, W - rect.end.x, rect.size.y)
	]:
		if dim_rect.size.x <= 0.0 or dim_rect.size.y <= 0.0:
			continue
		var shade := ColorRect.new()
		shade.color = dim_color
		shade.position = dim_rect.position
		shade.size = dim_rect.size
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guidance_overlay.add_child(shade)
	var pulse := 0.70 + 0.25 * sin(float(Time.get_ticks_msec()) / 180.0)
	var outer := _thin_highlight_frame_to(guidance_overlay, rect.grow(8.0), Color(1.0, 0.78, 0.26, pulse))
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := _thin_highlight_frame_to(guidance_overlay, rect.grow(2.0), Color(1.0, 0.95, 0.58, 0.92))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_route_edge_indicator(delta: Vector2, target_name: String, distance: int) -> void:
	if route_edge_indicator == null:
		return
	if delta.length() < 1.0 or not InteractionFeedback.guidance_highlights_enabled():
		route_edge_indicator.visible = false
		return
	route_edge_indicator.visible = true
	var direction := delta.normalized()
	# Keep the cue in the player's immediate space. It behaves like a compass
	# pointer around the observer instead of a detached screen-edge marker.
	var pointer_center := player_pos + direction * 48.0
	pointer_center.x = clampf(pointer_center.x, ROOM_RECT.position.x + 22.0, ROOM_RECT.end.x - 22.0)
	pointer_center.y = clampf(pointer_center.y, ROOM_RECT.position.y + 22.0, ROOM_RECT.end.y - 22.0)
	route_arrow_label.position = pointer_center - Vector2(27, 27)
	route_arrow_label.rotation = atan2(direction.y, direction.x) + PI * 0.5
	# The panel already carries the exact target and distance. Keeping this
	# extra label hidden avoids competing with the nearby interaction prompt.
	route_distance_label.visible = false


func _route_target_prompt(target_id: String) -> String:
	match target_id:
		"assembly":
			return GameManager.text("Go to the Assembly Table", "前往组装台")
		"cabinet":
			return GameManager.text("Go to the Parts Cabinet", "前往零件柜")
		"telescope":
			return GameManager.text("Go to the Observation Pad", "前往观测台")
		"journal":
			return GameManager.text("Go to the Club Logbook", "前往观测日志")
		"mission":
			return GameManager.text("Go to the Mission Board", "前往任务板")
		"computer":
			if _space_console_active():
				return GameManager.text("Go to the Space Telescope Console", "前往空间望远镜控制台")
			return GameManager.text("Go to the Stats Terminal", "前往统计终端")
		"door":
			return GameManager.text("Go to the Observatory Door", "前往天文台门")
	return target_id.capitalize()


func _route_move_hint(delta: Vector2) -> String:
	var horizontal := ""
	var vertical := ""
	if absf(delta.x) >= 16.0:
		horizontal = GameManager.text("right", "向右") if delta.x > 0.0 else GameManager.text("left", "向左")
	if absf(delta.y) >= 16.0:
		vertical = GameManager.text("down", "向下") if delta.y > 0.0 else GameManager.text("up", "向上")
	if horizontal != "" and vertical != "":
		return GameManager.text("Move " + horizontal + " and " + vertical + ".", horizontal + vertical + "移动。")
	if horizontal != "":
		return GameManager.text("Move " + horizontal + ".", horizontal + "移动。")
	if vertical != "":
		return GameManager.text("Move " + vertical + ".", vertical + "移动。")
	return GameManager.text("Move closer to interact.", "靠近后互动。")


func _draw_guidance_arrow(parent: Control, target_rect: Rect2) -> void:
	var label := Label.new()
	label.text = ">>>"
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32, 0.92))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var from := player_pos
	var to := target_rect.get_center()
	var mid := from.lerp(to, 0.55)
	label.position = mid - Vector2(32, 18)
	label.size = Vector2(64, 36)
	var direction := to - from
	label.rotation = atan2(direction.y, direction.x)
	parent.add_child(label)


func _spawn_position(spawn_id: String) -> Vector2:
	match spawn_id:
		"cabinet":
			return Vector2(300, 350)
		"assembly":
			return Vector2(756, 410)
		"door":
			return Vector2(517, 320)
		"telescope":
			return Vector2(517, 570)
		"journal":
			return Vector2(350, 628)
		"computer":
			return Vector2(693, 632)
		"mission":
			return Vector2(610, 250)
	return Vector2(517, 630)


func _is_ready_observation_target(id: String) -> bool:
	return bool(GameManager.can_enter_observation().get("ok", false)) and (id == "door" or id == "telescope")


func _get_interactable(id: String) -> Dictionary:
	for data in interactables:
		if str(data["id"]) == id:
			return data
	return {}


func _thin_highlight_frame(rect: Rect2, color: Color) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_frame_rect(frame, Vector2.ZERO, Vector2(rect.size.x, 2), color)
	_frame_rect(frame, Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2), color)
	_frame_rect(frame, Vector2.ZERO, Vector2(2, rect.size.y), color)
	_frame_rect(frame, Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y), color)
	return frame


func _thin_highlight_frame_to(parent: Control, rect: Rect2, color: Color) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_frame_rect(frame, Vector2.ZERO, Vector2(rect.size.x, 3), color)
	_frame_rect(frame, Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3), color)
	_frame_rect(frame, Vector2.ZERO, Vector2(3, rect.size.y), color)
	_frame_rect(frame, Vector2(rect.size.x - 3, 0), Vector2(3, rect.size.y), color)
	return frame


func _transparent_click_target(rect: Rect2, id: String) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.pressed.connect(_click_interactable.bind(id))
	add_child(button)
	return button


func _frame_rect(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _rect_to(parent: Control, pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = rect_size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()


func _style(color: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _corner_pins(parent: Control) -> void:
	var pin_color := Color(1.0, 0.78, 0.36, 0.95)
	_frame_rect(parent, Vector2(5, 5), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(5, 5), Vector2(2, 8), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 13, 5), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 7, 5), Vector2(2, 8), pin_color)
	_frame_rect(parent, Vector2(5, parent.size.y - 7), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(5, parent.size.y - 13), Vector2(2, 8), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 13, parent.size.y - 7), Vector2(8, 2), pin_color)
	_frame_rect(parent, Vector2(parent.size.x - 7, parent.size.y - 13), Vector2(2, 8), pin_color)


func _label(text: String, pos: Vector2, label_size: Vector2, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	add_child(label)
	_setup_label(label, text, font_size, align)
	return label


func _label_to(parent: Control, text: String, pos: Vector2, label_size: Vector2, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	parent.add_child(label)
	_setup_label(label, text, font_size, align)
	return label


func _setup_label(label: Label, text: String, font_size: int, align: HorizontalAlignment) -> void:
	label.text = text
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WARM_TEXT)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.76))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_language_changed() -> void:
	_build()


func _on_guidance_highlights_changed(enabled: bool) -> void:
	if guidance_overlay != null and not enabled:
		_clear(guidance_overlay)
		guidance_overlay.visible = false
	if route_edge_indicator != null and not enabled:
		route_edge_indicator.visible = false
	if guidance_panel != null:
		guidance_panel.visible = enabled and GameManager.room_guidance_target != ""
	if enabled:
		_update_room_guidance_panel()
