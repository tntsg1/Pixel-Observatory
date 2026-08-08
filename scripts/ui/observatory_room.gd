extends Control

const FurnitureAnimator = preload("res://scripts/ui/observatory_furniture_animator.gd")
const MayaHallNPCScript = preload("res://scripts/ui/maya_hall_npc.gd")
const W := 1024.0
const H := 768.0
const ROOM_RECT := Rect2(34, 100, 956, 578)
# Collision is anchored at the character's feet. The previous 20 px depth
# reached halfway up the sprite and created visible air walls in front of desks;
# furniture occluders already handle the upper-body overlap.
const PLAYER_SIZE := Vector2(16, 8)
const PLAYER_SPEED := 220.0
const INTERACT_DISTANCE := 56.0
const BG_TEXTURE: Texture2D = preload("res://assets/reference/observatory_room_hall_1024.png")
const PLAYER_TEXTURE: Texture2D = preload("res://assets/characters/player_observer_smooth_8dir.png")
const ASSEMBLY_OCCLUDER_TEXTURE: Texture2D = preload("res://assets/reference/observatory_occluders/assembly_table_clean.png")
const COMPUTER_OCCLUDER_TEXTURE: Texture2D = preload("res://assets/reference/observatory_furniture/remote_instrument_desk_official.png")
const COMPUTER_VISUAL_RECT := Rect2(764, 520, 172, 172.0 * 210.0 / 274.0)
const PLAYER_FRAME_SIZE := Vector2(64, 96)
# The supplied frames keep their original pixels. A single uniform scale makes
# their visible 77 px character match the previous ~66 px in-room height.
const PLAYER_DISPLAY_HEIGHT := 82.0
const PLAYER_DISPLAY_SCALE := PLAYER_DISPLAY_HEIGHT / PLAYER_FRAME_SIZE.y
const PLAYER_DISPLAY_SIZE := PLAYER_FRAME_SIZE * PLAYER_DISPLAY_SCALE
# Feet row inside the cropped 96px frame; collision remains foot-anchored.
const PLAYER_FOOT_Y := 89.0
const PLAYER_WALK_LAST_FRAME := 5
# One complete five-frame gait contains two footfalls. Advancing it by distance
# (rather than wall-clock time) keeps the feet planted at every input frame rate,
# on diagonals, and if the movement speed changes later. At 220 px/s this is a
# 0.418 s cycle / 11.96 authored frames per second: roughly 46 px per step for
# the 66 px-tall in-room character, avoiding both skating and frantic shuffling.
const PLAYER_WALK_CYCLE_DISTANCE := 92.0
const PLAYER_ANIM_FRAME_DISTANCE := PLAYER_WALK_CYCLE_DISTANCE / PLAYER_WALK_LAST_FRAME

const NAVY := Color(0.025, 0.040, 0.075, 0.92)
const NAVY_SOFT := Color(0.050, 0.075, 0.120, 0.82)
const WARM_TEXT := Color(0.96, 0.91, 0.78)
const BRASS := Color(0.90, 0.63, 0.28)
const CYAN := Color(0.52, 0.86, 1.00)
const COMPUTER_MODAL_LAYER := 1100
const REMOTE_CONSOLE_OPEN_DURATION := 1.55
const REMOTE_CONSOLE_OPEN_DURATION_REDUCED := 0.95
const STATS_TERMINAL_OPEN_DURATION := 0.72
const STATS_TERMINAL_OPEN_DURATION_REDUCED := 0.52
const STATS_TERMINAL_CLOSE_DURATION := 0.58
const STATS_TERMINAL_CLOSE_DURATION_REDUCED := 0.44
const SPACE_REMOTE_FIRST_LEVEL := 66
const SPACE_REMOTE_LAST_LEVEL := 75
const FAST_REMOTE_FIRST_LEVEL := 76
const FAST_REMOTE_LAST_LEVEL := 85

# Screen-space geometry for the 1024x768 observatory artwork. Interaction
# frames, click targets, route guidance, spawn points, and collision all share
# these rects so a background revision cannot leave one system behind.
const INTERACTION_RECTS := {
	"cabinet": Rect2(92, 88, 243, 213),
	"door": Rect2(447, 62, 131, 198),
	# Include the desk below the notice board so it can be reached from the
	# walkable floor directly in front of it.
	"mission": Rect2(681, 84, 205, 219),
	"assembly": Rect2(728, 328, 249, 176),
	"telescope": Rect2(423, 330, 190, 190),
	"journal": Rect2(48, 412, 258, 172),
	"computer": Rect2(754, 516, 201, 144),
}

# The hall has angled walls and a recessed entrance. The player's complete foot
# box must remain inside this shape, which prevents slipping beneath the floor
# or into the black border without reducing the usable room.
static var WALKABLE_FLOOR_POLYGON := PackedVector2Array([
	Vector2(96, 294),
	Vector2(445, 294),
	Vector2(445, 260),
	Vector2(579, 260),
	Vector2(579, 294),
	Vector2(928, 294),
	Vector2(989, 314),
	Vector2(989, 610),
	Vector2(950, 657),
	Vector2(653, 657),
	Vector2(653, 678),
	Vector2(371, 678),
	Vector2(371, 657),
	Vector2(75, 657),
	Vector2(34, 614),
	Vector2(34, 314),
])

# Foot-only collision traced from the user's 1448x1086 red-box guide and scaled
# uniformly to the 1024x768 game viewport. Raised furniture is separately
# redrawn as an occluder, so these rectangles describe where feet cannot enter,
# not the full visual height of each prop.
const OBSTACLE_RECTS := [
	Rect2(109, 108, 225, 191), # Parts cabinet
	Rect2(349, 226, 36, 62),   # Plant left of the dome
	Rect2(631, 207, 36, 73),   # Plant right of the dome
	Rect2(687, 127, 190, 169), # Mission board desk
	Rect2(907, 169, 27, 120),  # Tall plant beside the mission desk
	Rect2(729, 368, 239, 122), # Assembly workbench
	Rect2(74, 489, 191, 91),   # Journal desk
	Rect2(766, 591, 154, 62),  # Official remote terminal desk footprint
	Rect2(499, 417, 24, 27),   # Central telescope pivot only
]

# The round brass-and-blue observation platform is scenery the player may step
# onto, but Maya's autonomous routes must go around it.  Without this dedicated
# footprint her pathfinder only saw the 24x27 telescope pivot and marched her
# straight across the painted platform.
const MAYA_CENTRAL_PLATFORM_CENTER := Vector2(512, 445)
const MAYA_CENTRAL_PLATFORM_RADII := Vector2(156, 116)

const FURNITURE_OCCLUDER_SPECS := [
	{
		"id": "mission",
		"rect": Rect2(684, 218, 202, 85),
		"front_y": 296.0,
		"polygons": [
			[Vector2(684, 218), Vector2(886, 218), Vector2(886, 303), Vector2(684, 303)],
		],
	},
	{
		"id": "assembly",
		"rect": Rect2(730, 328, 247, 179),
		"front_y": 490.0,
		"texture": ASSEMBLY_OCCLUDER_TEXTURE,
		# Uniform 0.70x presentation preserves the supplied artwork and aligns
		# its visible pixels with the hall's workbench without stretching.
		"texture_rect": Rect2(720, 316, 273, 191),
	},
	{
		"id": "journal",
		"rect": Rect2(48, 412, 258, 173),
		"front_y": 580.0,
		"polygons": [
			[Vector2(72, 412), Vector2(210, 412), Vector2(210, 456), Vector2(72, 456)],
			[Vector2(48, 450), Vector2(277, 450), Vector2(277, 585), Vector2(48, 585)],
			[Vector2(277, 477), Vector2(306, 477), Vector2(306, 585), Vector2(277, 585)],
		],
	},
	{
		"id": "computer",
		"rect": COMPUTER_VISUAL_RECT,
		"front_y": 652.0,
		"texture": COMPUTER_OCCLUDER_TEXTURE,
		# The official 274x210 RGBA terminal is displayed at a single uniform
		# scale (172/274). Its transparent surround stays transparent; no black
		# backdrop or non-uniform stretch is introduced.
		"texture_rect": COMPUTER_VISUAL_RECT,
	},
	{
		"id": "telescope",
		"rect": Rect2(440, 334, 140, 150),
		"front_y": 444.0,
		"polygons": [
			[
				Vector2(440, 421), Vector2(447, 409), Vector2(471, 394),
				Vector2(515, 365), Vector2(546, 338), Vector2(571, 338),
				Vector2(580, 350), Vector2(567, 365), Vector2(529, 384),
				Vector2(487, 407), Vector2(456, 432),
			],
			[
				Vector2(486, 387), Vector2(531, 387), Vector2(548, 414),
				Vector2(545, 462), Vector2(528, 482), Vector2(490, 482),
				Vector2(475, 455), Vector2(475, 416),
			],
		],
	},
]

const SPAWN_POINTS := {
	"cabinet": Vector2(216, 350),
	"assembly": Vector2(688, 430),
	"door": Vector2(512, 282),
	"telescope": Vector2(512, 575),
	"journal": Vector2(343, 520),
	"computer": Vector2(721, 610),
	"mission": Vector2(676, 323),
}

var player: Sprite2D
var player_atlas: AtlasTexture
var player_shadow: ColorRect
var mission_board_popup: Control
var stats_terminal_popup: Control
var stats_terminal_animating := false
var unlock_popup: Control
var maya_workbench_popup: Control
var maya_rest_chat_popup: Control
var maya_workbench_open_progress := 0
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
var guidance_toggle_button: Button
var mobile_overlay: Control
var route_edge_indicator: Control
var route_arrow_label: Label
var route_distance_label: Label
var focus_label: Label
var feedback_label: Label
var control_bar: Panel
var control_bar_toggle: Button
var control_bar_expanded := false
var control_bar_manual_revision := 0
var furniture_animator: ObservatoryFurnitureAnimator
var furniture_occluders: Array[Dictionary] = []
var interactables: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var nearby_id := ""
var player_pos := Vector2(512, 646)
var active_guidance := ""
var feedback_override := ""
var feedback_override_until_msec := 0
var interact_key_was_down := false
var mission_key_was_down := false
var player_facing := "down"
var player_anim_frame := 0
var player_anim_distance := 0.0
var player_is_moving := false
var room_transition_active := false
var room_guidance_suspended := false
var pending_remote_console_scene := ""
var pending_remote_console_kind := ""
var furniture_interaction_active := false
var arrival_furniture_id := ""
var maya_npc: MayaHallNPC
var maya_initial_return_state := ""
var maya_initial_station_id := ""
var maya_return_pose: Dictionary = {}


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
	var current_route := GameManager.current_room_route()
	var current_route_target := str(current_route.get("target", ""))
	if GameManager.room_guidance_target == "" \
			or GameManager.room_guidance_target == current_route_target:
		GameManager.update_room_guidance_for_level()
	if GameManager.last_guidance == "ready_to_observe":
		active_guidance = GameManager.last_guidance
		GameManager.last_guidance = ""
	elif GameManager.room_guidance_target != "":
		active_guidance = "room_guidance"
	var arrival_id := GameManager.take_observatory_spawn()
	maya_initial_return_state = _maya_return_state(arrival_id)
	maya_initial_station_id = arrival_id
	var return_pose: Dictionary = GameManager.take_observatory_return_pose()
	maya_return_pose = GameManager.take_maya_observatory_return_pose()
	if bool(return_pose.get("valid", false)):
		player_pos = return_pose.get("position", _spawn_position(arrival_id))
		player_facing = str(return_pose.get("facing", "down"))
		# A result card may have opened the journal while the player originated
		# at the telescope. Do not play a journal-desk close animation beside an
		# exactly restored player who never approached that desk.
		if player_pos.distance_to(_spawn_position(arrival_id)) <= 96.0:
			arrival_furniture_id = arrival_id
		else:
			arrival_furniture_id = ""
	else:
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
	var fast_completion := _remote_console_kind() == "radio"
	var completion_action_zh := "FAST 装配完成" if fast_completion else "装配完成"
	var completion_status_zh := "全系统自检通过" if fast_completion else "望远镜就绪检查通过"
	var completion_unlock_zh := "FAST 观测控制台已启用" if fast_completion else "%s已启用" % destination_name
	_show_feedback(
		GameManager.text(
			"Telescope Ready. Follow the highlighted route to %s." % destination_name,
			"FAST 已完成装配。请沿高亮路线前往 FAST 观测控制台。" if fast_completion
			else "望远镜已就绪。沿高亮路线前往%s。" % destination_name
		),
		3200
	)
	if destination_glow != null:
		InteractionFeedback.success(destination_glow, "assembly_route_ready")
	var chain := InteractionFeedback.operation_chain(
		self,
		GameManager.text("Assembly complete", completion_action_zh),
		GameManager.text("The telescope passed its readiness check", completion_status_zh),
		GameManager.text("%s is now active" % destination_name, completion_unlock_zh),
		destination_glow,
		Color(0.42, 0.96, 0.58),
		3.2
	)
	if chain != null:
		chain.position.y = 636.0


func _process(delta: float) -> void:
	if maya_npc != null:
		maya_npc.set_room_blocked(
			room_transition_active or unlock_popup != null or stats_terminal_popup != null
			or mission_board_popup != null or maya_workbench_popup != null
			or maya_rest_chat_popup != null or furniture_interaction_active
		)
	if room_transition_active:
		_update_hud()
		return
	if unlock_popup != null:
		_update_hud()
		return
	if stats_terminal_popup != null:
		_update_hud()
		return
	if maya_workbench_popup != null:
		_update_hud()
		return
	if maya_rest_chat_popup != null:
		_update_hud()
		return
	_move_player(delta)
	_poll_action_keys()
	_update_nearby()
	_update_hud()
	_remember_maya_pose()


func _input(event: InputEvent) -> void:
	if room_transition_active:
		return
	if maya_workbench_popup != null:
		if event is InputEventKey:
			var workbench_key := event as InputEventKey
			if workbench_key.pressed and not workbench_key.echo and workbench_key.keycode == KEY_ESCAPE:
				_close_maya_workbench()
		return
	if maya_rest_chat_popup != null:
		if event is InputEventKey:
			var chat_key := event as InputEventKey
			if chat_key.pressed and not chat_key.echo and chat_key.keycode == KEY_ESCAPE:
				_close_maya_rest_chat()
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
			_open_main_menu()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if maya_npc != null and maya_npc.contains_screen_point(mouse_event.position):
				_interact_with_maya()
				get_viewport().set_input_as_handled()
				return
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
	control_bar_manual_revision += 1
	maya_npc = null
	for child in get_children():
		child.queue_free()
	interactables.clear()
	obstacles.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_draw_full_background()
	_draw_furniture_animation_overlays()
	_register_hitboxes()
	_draw_player()
	_draw_maya_npc()
	_draw_furniture_occluders()
	_draw_hud()
	_set_player_position(player_pos)
	_update_nearby()
	_update_hud()


func _draw_maya_npc() -> void:
	maya_npc = MayaHallNPCScript.new() as MayaHallNPC
	maya_npc.name = "MayaHallNPC"
	add_child(maya_npc)
	var start := Vector2(512, 292)
	var initial_facing := "down"
	if bool(maya_return_pose.get("valid", false)):
		start = maya_return_pose.get("position", start)
		initial_facing = str(maya_return_pose.get("facing", "down"))
	elif maya_initial_return_state != "" and maya_initial_station_id in [
		"cabinet", "door", "mission", "assembly", "telescope", "journal", "computer"
	]:
		start = _maya_destination_for(maya_initial_station_id)
	maya_npc.setup(
		start,
		Callable(self, "_maya_position_is_walkable"),
		Callable(self, "_maya_player_position"),
		Callable(self, "_maya_destination_for"),
		Callable(self, "_maya_route_target"),
		maya_initial_return_state,
		initial_facing,
		Callable(self, "_maya_focus_for")
	)
	# A stale or malformed runtime pose must never place her inside furniture.
	if not _maya_position_is_walkable(maya_npc.position):
		maya_npc.position = _maya_destination_for(maya_initial_station_id) \
			if maya_initial_station_id != "" else Vector2(512, 292)


func _maya_position_is_walkable(pos: Vector2) -> bool:
	var foot_rect := Rect2(pos - Vector2(8, 8), Vector2(16, 8))
	if not _player_rect_is_on_walkable_floor(foot_rect):
		return false
	var platform_offset := pos - MAYA_CENTRAL_PLATFORM_CENTER
	var normalized_platform_offset := Vector2(
		platform_offset.x / MAYA_CENTRAL_PLATFORM_RADII.x,
		platform_offset.y / MAYA_CENTRAL_PLATFORM_RADII.y
	)
	if normalized_platform_offset.length_squared() <= 1.0:
		return false
	for obstacle in obstacles:
		if foot_rect.intersects(obstacle):
			return false
	return true


func _maya_player_position() -> Vector2:
	return player_pos


func _maya_destination_for(destination_id: String) -> Vector2:
	var destinations := {
		"cabinet": Vector2(360, 326),
		"door": Vector2(590, 310),
		"mission": Vector2(665, 324),
		# Use the middle of the clear aisle in front of the workbench.  The old
		# left-side waypoint made Maya look detached from the telescope she was
		# meant to be assembling.
		"assembly": Vector2(852, 540),
		# Observe from the clear right-hand aisle instead of standing on, or
		# routing across, the central circular platform.
		"telescope": Vector2(680, 496),
		"journal": Vector2(322, 590),
		"computer": Vector2(724, 620),
	}
	return destinations.get(destination_id, Vector2(600, 620))


func _maya_focus_for(destination_id: String) -> Vector2:
	var station_rect: Rect2 = INTERACTION_RECTS.get(destination_id, Rect2())
	return station_rect.get_center() if station_rect.size != Vector2.ZERO \
		else _maya_destination_for(destination_id)


func _maya_route_target() -> String:
	return GameManager.room_guidance_target


func _maya_return_state(arrival_id: String) -> String:
	if arrival_id == "assembly" and GameManager.telescope_is_ready():
		return "assembly_success"
	if arrival_id == "computer" and not GameManager.last_observation.is_empty():
		return "remote_success"
	if arrival_id == "journal" and not GameManager.last_observation.is_empty():
		return "journal_saved"
	if arrival_id in ["telescope", "door"] and not GameManager.last_observation.is_empty():
		return "observation_success"
	if bool(GameManager.progress.get("graduation_seen", false)):
		return "graduated"
	return ""


func _draw_full_background() -> void:
	var bg := TextureRect.new()
	bg.name = "ObservatoryHallBackground"
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.texture = BG_TEXTURE
	bg.position = Vector2.ZERO
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -20
	add_child(bg)
	_draw_official_remote_terminal()
	if _space_console_active():
		_draw_space_console_overlay()


func _draw_official_remote_terminal() -> void:
	# The supplied terminal is always the painted lower-right station. The
	# separate occluder reuses this exact RGBA asset only when the player walks
	# behind it, so the actor is never covered by a rectangular floor patch.
	var terminal := Sprite2D.new()
	terminal.name = "OfficialRemoteInstrumentDesk"
	terminal.centered = false
	terminal.position = COMPUTER_VISUAL_RECT.position
	terminal.texture = COMPUTER_OCCLUDER_TEXTURE
	terminal.scale = COMPUTER_VISUAL_RECT.size / Vector2(
		COMPUTER_OCCLUDER_TEXTURE.get_width(), COMPUTER_OCCLUDER_TEXTURE.get_height())
	terminal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terminal.z_index = -10
	add_child(terminal)


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


func _remote_destination_for_kind(kind: String) -> String:
	return "radio_observation" if kind == "radio" else "space_observation"


func _remote_console_status(kind: String) -> Dictionary:
	var first_level := FAST_REMOTE_FIRST_LEVEL if kind == "radio" else SPACE_REMOTE_FIRST_LEVEL
	var last_level := FAST_REMOTE_LAST_LEVEL if kind == "radio" else SPACE_REMOTE_LAST_LEVEL
	var current_number := int(GameManager.current_level().get("level_number", GameManager.progress.get("current_level", 1)))
	var current_kind := _remote_console_kind()
	var completed: Array = GameManager.progress.get("completed_levels", [])
	var chapter_complete := true
	for level_number in range(first_level, last_level + 1):
		if not completed.has(level_number) and not completed.has(str(level_number)):
			chapter_complete = false
			break
	if chapter_complete:
		return {
			"state": "completed",
			"label": GameManager.text("COMPLETED", "已完成"),
			"reason": GameManager.text("Campaign archived. Independent observing time is available.", "主线观测已归档，现在可以申请自主观测。"),
			"enabled": false,
			"campaign_enabled": false,
			"free_enabled": true,
		}
	if current_kind == kind:
		var gate: Dictionary = GameManager.can_enter_observation()
		if bool(gate.get("ok", false)):
			return {
				"state": "active",
				"label": GameManager.text("ACTIVE", "任务进行中"),
				"reason": GameManager.text("The current mission is ready for remote operation.", "当前任务已经可以进行远程操作。"),
				"enabled": true,
				"campaign_enabled": true,
				"free_enabled": GameManager.remote_free_unlocked(kind),
			}
		return {
			"state": "ready",
			"label": GameManager.text("READY", "已解锁"),
			"reason": GameManager.text(
				str(gate.get("reason_en", "Complete the required assembly before opening the link.")),
				str(gate.get("reason_zh", "请先完成本关要求的组装，再打开远程链路。"))),
			"enabled": true,
			"campaign_enabled": true,
			"free_enabled": GameManager.remote_free_unlocked(kind),
		}
	if current_number < first_level:
		return {
			"state": "locked",
			"label": GameManager.text("LOCKED", "未解锁"),
			"reason": GameManager.text(
				"Unlocked when the campaign reaches Level %d." % first_level,
				"主线推进至第 %d 关后解锁。" % first_level),
			"enabled": false,
			"campaign_enabled": false,
			"free_enabled": false,
		}
	return {
		"state": "ready",
		"label": GameManager.text("READY", "已解锁"),
		"reason": GameManager.text("No matching remote mission is active tonight.", "今晚没有与这台仪器对应的远程任务。"),
		"enabled": false,
		"campaign_enabled": false,
		"free_enabled": GameManager.remote_free_unlocked(kind),
	}


func _draw_space_console_overlay() -> void:
	# The replacement desk has three framed sky displays. The centre display is
	# the remote link surface; status feedback stays clipped to that glass and
	# never tints the books, tabletop, cabinet, or floor.
	var screen := Control.new()
	screen.name = "SpaceConsoleScreen"
	screen.position = Vector2(813, 530)
	screen.size = Vector2(72, 40)
	screen.clip_contents = true
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	var radio_console := _remote_console_kind() == "radio"
	var status_strip := Panel.new()
	status_strip.position = Vector2(2, 26)
	status_strip.size = Vector2(68, 12)
	status_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_strip.add_theme_stylebox_override(
		"panel",
		_style(Color(0.002, 0.018, 0.018, 0.70), Color(0.22, 0.56, 0.50, 0.46), 1, 0)
	)
	screen.add_child(status_strip)
	_board_label(
		status_strip,
		("FAST LINK" if radio_console else "L2 LINK"),
		Vector2(2, 1),
		Vector2(64, 10),
		6,
		Color(0.56, 0.92, 0.82),
		HORIZONTAL_ALIGNMENT_CENTER
	)


func _register_hitboxes() -> void:
	_register_interactable("cabinet", GameManager.text("Parts Cabinet", "零件柜"), GameManager.text("Review unlocked telescope parts.", "查看已解锁的望远镜零件。"), INTERACTION_RECTS["cabinet"])
	_register_interactable("door", GameManager.text("Observatory Dome", "圆顶观星站"), GameManager.text("The ridge dome: wind-shielded formal station with its own control room. Same sky as the pad - steadier housing.", "山脊圆顶：挡风的正式观测站，带控制室。和露天观测台看同一片天空，但圆顶更稳、更抗风。"), INTERACTION_RECTS["door"])
	_register_interactable("mission", GameManager.text("Mission Board", "任务公告板"), GameManager.text("Read the current level goal here.", "在此查看当前关卡目标。"), INTERACTION_RECTS["mission"])
	_register_interactable("assembly", GameManager.text("Assembly Table", "组装台"), GameManager.text("Build and align the telescope.", "组装和校准望远镜。"), INTERACTION_RECTS["assembly"])
	if GameManager.postgraduate_free_build():
		var active_family := GameManager.active_optical_telescope_family()
		var active_name := GameManager.optical_telescope_family_name(active_family) if active_family != "" else GameManager.text("No telescope equipped", "尚未装备望远镜")
		_register_interactable(
			"telescope",
			GameManager.text("Central Optical Pad · %s" % active_name, "中央光学观测台 · %s" % active_name),
			GameManager.text(
				"Uses your currently equipped personal optical telescope. Remote facilities remain on the lower-right console.",
				"使用你当前装备的个人光学望远镜。远程科研设施仍从右下角控制台进入。"),
			INTERACTION_RECTS["telescope"])
	elif GameManager.current_observation_mode() == "naked_eye":
		_register_interactable("telescope", GameManager.text("Naked Eye Observation", "肉眼观测"), GameManager.text("Observe the night sky with your own eyes.", "用肉眼观察夜空。"), INTERACTION_RECTS["telescope"])
	elif GameManager.current_observation_mode() == "constellation":
		_register_interactable("telescope", GameManager.text("Constellation Search", "星座搜寻"), GameManager.text("Use the observation pad to locate the complete star pattern, then study it through the telescope.", "使用观测台定位完整星群，再通过望远镜观察它。"), INTERACTION_RECTS["telescope"])
	else:
		_register_interactable("telescope", GameManager.text("Telescope Observation Pad", "望远镜观测台"), GameManager.text("Open-air quick setup: carry your telescope out and observe right away. Same sky as the dome.", "露天快速架设：把你组装的望远镜搬出来立刻观测。与圆顶观星站看同一片天空。"), INTERACTION_RECTS["telescope"])
	# The logbook is opened from the chair-side/lower edge of the desk. Keeping
	# the interaction center there also makes the route cue say "lower-left"
	# from the room's central telescope instead of incorrectly pointing upward.
	_register_interactable("journal", GameManager.text("Learning Journal", "学习日志"), GameManager.text("Review completed observations and learning cards.", "查看已完成的观测和学习卡。"), INTERACTION_RECTS["journal"])
	_register_interactable(
		"computer",
		GameManager.text("Remote Instrument Console", "远程仪器控制台"),
		GameManager.text("Control the space infrared observatory and FAST radio array.", "控制空间红外天文台与 FAST 射电阵列。"),
		INTERACTION_RECTS["computer"])

	# Foot blockers preserve the top-down walkable floor while preventing the
	# player from standing inside furniture, the telescope base, or stools.
	obstacles.append_array(OBSTACLE_RECTS)


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
	player.name = "Player"
	player_atlas = AtlasTexture.new()
	player_atlas.atlas = PLAYER_TEXTURE
	player.texture = player_atlas
	player.position = _player_visual_position()
	player.centered = true
	player.scale = Vector2.ONE * PLAYER_DISPLAY_SCALE
	# Both actors normally share z=1. Maya only brackets this layer while their
	# sprites physically overlap, so furniture treats them consistently.
	player.z_index = 1
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(player)
	_set_player_animation_frame(player_facing, 0)


func _draw_furniture_occluders() -> void:
	furniture_occluders.clear()
	for spec_value in FURNITURE_OCCLUDER_SPECS:
		var spec: Dictionary = spec_value
		var rect: Rect2 = spec.get("rect", Rect2())
		var occluder := Node2D.new()
		occluder.name = "FurnitureOccluder_%s" % str(spec.get("id", "table"))
		# These cutouts appear only while an actor is physically behind a prop, so
		# they must remain above both character depth bands.
		occluder.z_index = 3
		occluder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		occluder.visible = false
		var cutout_texture := spec.get("texture") as Texture2D
		if cutout_texture != null:
			var texture_rect: Rect2 = spec.get("texture_rect", rect)
			var cutout := Sprite2D.new()
			cutout.name = "TransparentFurnitureCutout"
			cutout.centered = false
			cutout.position = texture_rect.position
			cutout.texture = cutout_texture
			var source_size := Vector2(cutout_texture.get_width(), cutout_texture.get_height())
			if source_size.x > 0.0 and source_size.y > 0.0:
				cutout.scale = texture_rect.size / source_size
			cutout.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			occluder.add_child(cutout)
		for polygon_value in spec.get("polygons", []):
			var points := PackedVector2Array(polygon_value)
			if points.size() < 3:
				continue
			var patch := Polygon2D.new()
			patch.polygon = points
			# Sample the hall at the same pixel coordinates. The foreground and
			# background are therefore identical instead of two differently
			# scaled paintings that pop when visibility changes.
			patch.uv = points
			patch.texture = BG_TEXTURE
			patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			occluder.add_child(patch)
		add_child(occluder)
		furniture_occluders.append({
			"id": str(spec.get("id", "")),
			"rect": rect,
			"front_y": float(spec.get("front_y", rect.end.y)),
			"node": occluder,
		})
	_update_furniture_occlusion()


func _update_furniture_occlusion() -> void:
	if player == null and maya_npc == null:
		return
	var visual_rect := Rect2()
	if player != null:
		visual_rect = Rect2(
			_player_visual_position() - PLAYER_DISPLAY_SIZE * 0.5,
			PLAYER_DISPLAY_SIZE
		)
	var maya_in_front_of_furniture := false
	for data in furniture_occluders:
		var occluder := data.get("node") as CanvasItem
		if occluder == null:
			continue
		var furniture_rect: Rect2 = data.get("rect", Rect2())
		var front_y := float(data.get("front_y", furniture_rect.end.y))
		var player_behind := player != null and player_pos.y <= front_y \
			and visual_rect.intersects(furniture_rect)
		var maya_behind := maya_npc != null and maya_npc.is_behind_furniture(furniture_rect, front_y)
		var maya_in_front := maya_npc != null and maya_npc.is_in_front_of_furniture(furniture_rect, front_y)
		maya_in_front_of_furniture = maya_in_front_of_furniture or maya_in_front
		occluder.visible = player_behind or maya_behind
	if maya_npc != null:
		maya_npc.set_furniture_front_layer(maya_in_front_of_furniture)


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
	menu.pressed.connect(_open_main_menu)
	add_child(menu)

	# Base HUD ends here. Site travel belongs to Sky Observation, telescope
	# families belong to Assembly, and touch setup belongs to Settings/mobile UI.
	_draw_hud_lower()


func _draw_hud_lower() -> void:
	control_bar = Panel.new()
	control_bar.name = "RoomControlBar"
	control_bar.position = Vector2(172, 704)
	control_bar.size = Vector2(680, 48)
	control_bar.add_theme_stylebox_override("panel", _style(NAVY, BRASS, 2, 4))
	add_child(control_bar)
	_corner_pins(control_bar)
	_label_to(control_bar, "[E]", Vector2(40, 13), Vector2(38, 20), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(control_bar, GameManager.text("INTERACT", "互动"), Vector2(84, 14), Vector2(96, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(control_bar, GameManager.text("WASD / ARROWS", "WASD / 方向键"), Vector2(250, 14), Vector2(150, 18), 13, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(control_bar, GameManager.text("MOVE", "移动"), Vector2(406, 14), Vector2(58, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)
	_label_to(control_bar, "[TAB]", Vector2(510, 13), Vector2(54, 20), 14, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(control_bar, GameManager.text("MISSIONS", "任务"), Vector2(570, 14), Vector2(82, 18), 13, HORIZONTAL_ALIGNMENT_LEFT)

	control_bar_toggle = Button.new()
	control_bar_toggle.name = "RoomControlBarToggle"
	control_bar_toggle.position = Vector2(488, 730)
	control_bar_toggle.size = Vector2(48, 30)
	control_bar_toggle.focus_mode = Control.FOCUS_ALL
	control_bar_toggle.add_theme_font_size_override("font_size", 22)
	control_bar_toggle.add_theme_color_override("font_color", Color(1.0, 0.80, 0.24))
	control_bar_toggle.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.54))
	control_bar_toggle.add_theme_color_override("font_pressed_color", Color(1.0, 0.68, 0.16))
	control_bar_toggle.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	control_bar_toggle.add_theme_stylebox_override("hover", _style(Color(0.02, 0.04, 0.07, 0.72), Color(1.0, 0.82, 0.34, 0.72), 1, 3))
	control_bar_toggle.add_theme_stylebox_override("pressed", _style(Color(0.01, 0.02, 0.04, 0.88), Color(1.0, 0.66, 0.16, 0.86), 1, 3))
	control_bar_toggle.add_theme_stylebox_override("focus", _style(Color(0.02, 0.04, 0.07, 0.58), Color(0.52, 0.86, 1.0, 0.76), 1, 3))
	control_bar_toggle.pressed.connect(_toggle_control_bar)
	add_child(control_bar_toggle)

	var saved_expanded := bool(GameManager.progress.get("observatory_controls_expanded", false))
	var first_tutorial_reveal := (
		not bool(GameManager.progress.get("observatory_controls_seen", false))
		and GameManager.uses_full_tutorials()
		and int(GameManager.progress.get("current_level", 1)) <= 2
	)
	control_bar_expanded = saved_expanded or first_tutorial_reveal
	_apply_control_bar_state(false)
	if first_tutorial_reveal:
		GameManager.progress["observatory_controls_seen"] = true
		GameManager.save()
		call_deferred("_schedule_control_bar_auto_hide", control_bar_manual_revision)

	guidance_overlay = Control.new()
	guidance_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	guidance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guidance_overlay.visible = false
	add_child(guidance_overlay)

	guidance_panel = Panel.new()
	guidance_panel.position = Vector2(222, 76)
	guidance_panel.size = Vector2(580, 170)
	guidance_panel.add_theme_stylebox_override("panel", _style(Color(0.030, 0.045, 0.080, 0.96), BRASS, 3, 6))
	# Maya now guides in-world with a compact thought bubble. Keep this legacy
	# card as a data container for route copy, but never let it cover the room.
	guidance_panel.visible = false
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

	guidance_toggle_button = Button.new()
	guidance_toggle_button.name = "GuidanceHighlightToggle"
	guidance_toggle_button.position = Vector2(812, 82)
	guidance_toggle_button.size = Vector2(152, 34)
	guidance_toggle_button.focus_mode = Control.FOCUS_ALL
	guidance_toggle_button.add_theme_font_size_override("font_size", 12)
	guidance_toggle_button.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62))
	guidance_toggle_button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.54))
	guidance_toggle_button.add_theme_stylebox_override("normal", _style(Color(0.025, 0.040, 0.070, 0.90), Color(0.62, 0.50, 0.27, 0.86), 1, 4))
	guidance_toggle_button.add_theme_stylebox_override("hover", _style(Color(0.055, 0.075, 0.110, 0.96), Color(1.0, 0.78, 0.28), 1, 4))
	guidance_toggle_button.add_theme_stylebox_override("pressed", _style(Color(0.015, 0.025, 0.045, 1.0), Color(0.52, 0.86, 1.0), 1, 4))
	guidance_toggle_button.pressed.connect(_toggle_guidance_highlights)
	add_child(guidance_toggle_button)
	_update_guidance_toggle_button()

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


func _schedule_control_bar_auto_hide(revision: int) -> void:
	await get_tree().create_timer(5.0).timeout
	if revision != control_bar_manual_revision or not is_instance_valid(control_bar):
		return
	_set_control_bar_expanded(false, true, false)


func _toggle_control_bar() -> void:
	control_bar_manual_revision += 1
	_set_control_bar_expanded(not control_bar_expanded, true, true)


func _toggle_guidance_highlights() -> void:
	var next_enabled := not InteractionFeedback.guidance_highlights_enabled()
	InteractionFeedback.set_guidance_highlights_enabled(next_enabled)
	_show_feedback(
		GameManager.text(
			"Guidance highlights enabled." if next_enabled else "Guidance highlights hidden. Explore freely.",
			"高光引导已开启。" if next_enabled else "高光引导已关闭，可以自由探索。"
		),
		1800
	)
	_update_guidance_toggle_button()


func _update_guidance_toggle_button() -> void:
	if guidance_toggle_button == null:
		return
	var has_route := GameManager.room_guidance_target != ""
	var free_mode := str(GameManager.tutorial_assistance_mode()) == "free"
	guidance_toggle_button.visible = has_route and not room_guidance_suspended and not free_mode
	var enabled := InteractionFeedback.guidance_highlights_enabled()
	guidance_toggle_button.text = GameManager.text(
		"Hide highlights" if enabled else "Show highlights",
		"关闭高光" if enabled else "显示高光"
	)
	guidance_toggle_button.tooltip_text = GameManager.text(
		"Hide Maya's route card, target highlight, and direction arrow. You can restore them here at any time.",
		"隐藏 Maya 路线卡、目标高光和方向箭头；可随时在这里重新开启。"
	)


func _set_control_bar_expanded(expanded: bool, animate: bool, remember: bool) -> void:
	control_bar_expanded = expanded
	if remember:
		GameManager.progress["observatory_controls_expanded"] = expanded
		GameManager.progress["observatory_controls_seen"] = true
		GameManager.save()
	_apply_control_bar_state(animate)


func _apply_control_bar_state(animate: bool) -> void:
	if control_bar == null or control_bar_toggle == null:
		return
	var bar_target := Vector2(172, 704) if control_bar_expanded else Vector2(172, 760)
	var toggle_target := Vector2(494, 691) if control_bar_expanded else Vector2(494, 732)
	control_bar_toggle.text = "v" if control_bar_expanded else "^"
	control_bar_toggle.tooltip_text = GameManager.text(
		"Hide control guide" if control_bar_expanded else "Show control guide",
		"隐藏操作提示" if control_bar_expanded else "显示操作提示"
	)
	control_bar.visible = true
	if not animate or InteractionFeedback.is_reduced_motion():
		control_bar.position = bar_target
		control_bar.visible = control_bar_expanded
		control_bar_toggle.position = toggle_target
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control_bar, "position", bar_target, 0.22)
	tween.tween_property(control_bar_toggle, "position", toggle_target, 0.22)
	if not control_bar_expanded:
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(control_bar) and not control_bar_expanded:
				control_bar.visible = false
		)


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
		_update_player_animation(0.0)
		return

	direction = direction.normalized()
	player_facing = _facing_from_direction(direction)

	var next_pos := player_pos + direction * PLAYER_SPEED * delta
	next_pos.x = clampf(next_pos.x, ROOM_RECT.position.x + PLAYER_SIZE.x * 0.5, ROOM_RECT.end.x - PLAYER_SIZE.x * 0.5)
	next_pos.y = clampf(next_pos.y, ROOM_RECT.position.y + PLAYER_SIZE.y, ROOM_RECT.end.y)
	var next_rect := _player_collision_rect_for(next_pos)
	if not _player_rect_is_on_walkable_floor(next_rect):
		player_is_moving = false
		_update_player_animation(0.0)
		return
	for obstacle in obstacles:
		if next_rect.intersects(obstacle):
			player_is_moving = false
			_update_player_animation(0.0)
			return
	var travelled_distance := player_pos.distance_to(next_pos)
	player_is_moving = travelled_distance > 0.0
	_set_player_position(next_pos)
	_update_player_animation(travelled_distance)


func _set_player_position(pos: Vector2) -> void:
	player_pos = pos
	GameManager.remember_observatory_pose(player_pos, player_facing)
	if player_shadow != null:
		player_shadow.position = _player_shadow_position()
	if player != null:
		player.position = _player_visual_position()
	_update_furniture_occlusion()


func _open_main_menu() -> void:
	# The main menu is a temporary screen, not a room entrance. Preserve the
	# exact foot position and facing instead of falling back to a furniture
	# spawn when Continue returns to the observatory.
	GameManager.remember_observatory_pose(player_pos, player_facing)
	_remember_maya_pose()
	GameManager.go("menu")


func _remember_maya_pose(begin_observation_hall_roam: bool = false) -> void:
	if maya_npc == null:
		return
	maya_npc.remember_player_departure(begin_observation_hall_roam)
	GameManager.remember_maya_observatory_pose(
		maya_npc.position,
		maya_npc.current_facing(),
		maya_npc.current_destination_id()
	)


func _player_visual_position() -> Vector2:
	# player_pos is the foot center; anchor the sprite so the drawn feet
	# (frame row PLAYER_FOOT_Y) land exactly on it.
	return player_pos - Vector2(0.0, (PLAYER_FOOT_Y - PLAYER_FRAME_SIZE.y * 0.5) * PLAYER_DISPLAY_SCALE)


func _player_shadow_position() -> Vector2:
	return player_pos - Vector2(13, 4)


func _player_collision_rect_for(pos: Vector2) -> Rect2:
	return Rect2(pos - Vector2(PLAYER_SIZE.x * 0.5, PLAYER_SIZE.y), PLAYER_SIZE)


func _player_rect_is_on_walkable_floor(rect: Rect2) -> bool:
	var inset := 1.0
	var samples := [
		rect.position + Vector2(inset, inset),
		Vector2(rect.end.x - inset, rect.position.y + inset),
		Vector2(rect.position.x + inset, rect.end.y - inset),
		rect.end - Vector2(inset, inset),
	]
	for sample in samples:
		if not Geometry2D.is_point_in_polygon(sample, WALKABLE_FLOOR_POLYGON):
			return false
	return true


func _facing_from_direction(direction: Vector2) -> String:
	var horizontal := absf(direction.x)
	var vertical := absf(direction.y)
	# Eight 45-degree sectors give keyboard diagonals their authored frames while
	# keeping small analogue-stick drift on a cardinal direction.
	if horizontal < vertical * 0.41421356:
		return "down" if direction.y > 0.0 else "up"
	if vertical < horizontal * 0.41421356:
		return "right" if direction.x > 0.0 else "left"
	if direction.y > 0.0:
		return "down_right" if direction.x > 0.0 else "down_left"
	return "up_right" if direction.x > 0.0 else "up_left"


func _facing_vector(facing: String) -> Vector2:
	match facing:
		"up":
			return Vector2.UP
		"up_left":
			return Vector2(-1.0, -1.0).normalized()
		"up_right":
			return Vector2(1.0, -1.0).normalized()
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		"down_left":
			return Vector2(-1.0, 1.0).normalized()
		"down_right":
			return Vector2(1.0, 1.0).normalized()
		_:
			return Vector2.DOWN


func _update_player_animation(travelled_distance: float) -> void:
	if player_atlas == null:
		return
	if not player_is_moving:
		player_anim_frame = 0
		player_anim_distance = 0.0
		_set_player_animation_frame(player_facing, player_anim_frame)
		return
	if player_anim_frame == 0:
		player_anim_frame = 1
	player_anim_distance += maxf(travelled_distance, 0.0)
	if player_anim_distance >= PLAYER_ANIM_FRAME_DISTANCE:
		var step_count := int(floor(player_anim_distance / PLAYER_ANIM_FRAME_DISTANCE))
		player_anim_distance = fmod(player_anim_distance, PLAYER_ANIM_FRAME_DISTANCE)
		player_anim_frame = ((player_anim_frame - 1 + step_count) % PLAYER_WALK_LAST_FRAME) + 1
	_set_player_animation_frame(player_facing, player_anim_frame)


func _set_player_animation_frame(facing: String, frame: int) -> void:
	if player_atlas == null:
		return
	var row := 0
	match facing:
		"down_right":
			row = 1
		"right":
			row = 2
		"up_right":
			row = 3
		"up":
			row = 4
		"up_left":
			row = 5
		"left":
			row = 6
		"down_left":
			row = 7
		_:
			row = 0
	var safe_frame := clampi(frame, 0, PLAYER_WALK_LAST_FRAME)
	player_atlas.region = Rect2(
		float(safe_frame) * PLAYER_FRAME_SIZE.x,
		float(row) * PLAYER_FRAME_SIZE.y,
		PLAYER_FRAME_SIZE.x,
		PLAYER_FRAME_SIZE.y
	)


func _update_nearby() -> void:
	var best_id := ""
	var best_score := 99999.0
	var center := player_pos
	var facing_vector := _facing_vector(player_facing)
	for data in interactables:
		var rect: Rect2 = data["rect"]
		var nearest := Vector2(
			clampf(center.x, rect.position.x, rect.end.x),
			clampf(center.y, rect.position.y, rect.end.y)
		)
		var distance := center.distance_to(nearest)
		var alignment := 1.0
		if distance > 0.01:
			alignment = facing_vector.dot(center.direction_to(nearest))
		# In the narrow aisle between the upper mission desk and lower assembly
		# table, facing direction disambiguates which object the player means.
		var score := distance + (1.0 - alignment) * 12.0
		if score < best_score and distance <= INTERACT_DISTANCE:
			best_score = score
			best_id = str(data["id"])
	nearby_id = best_id
	if furniture_animator != null:
		# The console acknowledges proximity before the player presses E. This
		# makes the side-access interaction readable without opening the modal.
		furniture_animator.set_proximity("computer", nearby_id == "computer")
	if mobile_overlay != null:
		# Interact button mirrors the E key: enabled near an interactable
		# and labeled with the object's name.
		if nearby_id == "" and maya_npc != null and maya_npc.player_is_near():
			mobile_overlay.set_action_enabled("interact", true, maya_npc.interaction_prompt())
		elif nearby_id == "":
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
		if maya_npc != null and maya_npc.player_is_near():
			focus_label.text = "[E] " + maya_npc.interaction_prompt()
		else:
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
	elif maya_npc != null and maya_npc.player_is_near():
		_interact_with_maya()


func _interact_at(pos: Vector2) -> void:
	if maya_npc != null and maya_npc.contains_screen_point(pos):
		_interact_with_maya()
		return
	for data in interactables:
		var rect: Rect2 = data["rect"]
		if rect.grow(12).has_point(pos):
			_click_interactable(str(data["id"]))
			return


func _interact_with_maya() -> void:
	if maya_npc == null:
		return
	var request := maya_npc.postgraduate_interaction_request()
	maya_npc.respond_to_player()
	if str(request.get("action", "")) == "open_workbench":
		_open_maya_workbench()
		return
	if str(request.get("action", "")) == "rest_chat":
		_open_maya_rest_chat()
		return
	if str(request.get("action", "")) != "join_observation":
		return
	var object_id := str(request.get("object_id", ""))
	_remember_maya_pose(true)
	var instrument := {
		"id": str(request.get("instrument_id", "")),
		"name_en": str(request.get("instrument_name_en", "")),
		"name_zh": str(request.get("instrument_name_zh", "")),
		"night_id": str(request.get("night_id", "clear_stable")),
	}
	if GameManager.go_to_maya_companion_observation(object_id, instrument, "telescope"):
		maya_npc.remember_joined_observation()
		return
	_show_feedback(maya_npc.editable_text("companion_not_ready"), 4200)


func _open_maya_workbench() -> void:
	if maya_workbench_popup != null or maya_npc == null:
		return
	_suspend_room_guidance_for_modal()
	maya_workbench_open_progress = int(maya_npc.postgraduate_work_snapshot().get("assembly_progress", 0))
	maya_workbench_popup = Control.new()
	maya_workbench_popup.name = "MayaCollaborativeWorkbench"
	maya_workbench_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	maya_workbench_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	maya_workbench_popup.z_index = COMPUTER_MODAL_LAYER
	add_child(maya_workbench_popup)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.010, 0.022, 0.76)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	maya_workbench_popup.add_child(dim)

	var panel := Panel.new()
	panel.name = "MayaWorkbenchPanel"
	panel.position = Vector2(190, 112)
	panel.size = Vector2(644, 536)
	panel.add_theme_stylebox_override("panel", _style(Color(0.020, 0.037, 0.064, 0.99), Color(0.47, 0.82, 0.98), 2, 8))
	maya_workbench_popup.add_child(panel)
	_board_label(panel, maya_npc.editable_text("workbench_title"), Vector2(28, 22), Vector2(588, 30), 20, BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	_board_label(
		panel,
		maya_npc.editable_text("workbench_subtitle"),
		Vector2(28, 54), Vector2(588, 22), 12, Color(0.58, 0.84, 0.96), HORIZONTAL_ALIGNMENT_CENTER
	)
	_rect_to(panel, Vector2(26, 86), Vector2(592, 1), Color(0.34, 0.58, 0.75, 0.72))
	var content := Control.new()
	content.name = "MayaWorkbenchContent"
	content.position = Vector2(26, 98)
	content.size = Vector2(592, 356)
	panel.add_child(content)
	var close := _board_button(
		panel, maya_npc.editable_text("workbench_close"),
		Vector2(34, 470), Vector2(220, 42), Color(0.08, 0.13, 0.20), Color(0.35, 0.55, 0.72)
	)
	close.name = "MayaWorkbenchCloseButton"
	close.pressed.connect(_close_maya_workbench)
	var assist := _board_button(
		panel, maya_npc.editable_text("workbench_assist"),
		Vector2(270, 470), Vector2(340, 42), Color(0.08, 0.24, 0.28), Color(0.42, 0.90, 0.88)
	)
	assist.name = "MayaWorkbenchAssistButton"
	assist.pressed.connect(_assist_maya_at_workbench)
	_refresh_maya_workbench()
	InteractionFeedback.page_enter(maya_workbench_popup, Vector2(0, 8))


func _refresh_maya_workbench() -> void:
	if maya_workbench_popup == null or maya_npc == null:
		return
	var panel := maya_workbench_popup.find_child("MayaWorkbenchPanel", true, false) as Panel
	var content := maya_workbench_popup.find_child("MayaWorkbenchContent", true, false) as Control
	var assist := maya_workbench_popup.find_child("MayaWorkbenchAssistButton", true, false) as Button
	if panel == null or content == null or assist == null:
		return
	for child in content.get_children():
		child.queue_free()
	var work := maya_npc.postgraduate_work_snapshot()
	var chinese := GameManager.language_mode == "zh"
	var instrument_name := str(work.get("instrument_name_zh" if chinese else "instrument_name_en", ""))
	var target_name := str(work.get("target_name_zh" if chinese else "target_name_en", ""))
	var night_name := str(work.get("night_name_zh" if chinese else "night_name_en", ""))
	var event_name := str(work.get("event_name_zh" if chinese else "event_name_en", ""))
	var night_display := night_name if event_name == "" else "%s · %s" % [night_name, event_name]
	var progress := int(work.get("assembly_progress", 0))
	var steps_value: Variant = work.get("assembly_steps_zh" if chinese else "assembly_steps_en", [])
	var steps: Array = steps_value if steps_value is Array else []
	_board_label(content, maya_npc.editable_text("workbench_instrument"), Vector2(8, 4), Vector2(130, 20), 11, Color(0.52, 0.82, 1.0))
	_board_label(content, instrument_name, Vector2(138, 0), Vector2(438, 26), 17, WARM_TEXT)
	_board_label(content, maya_npc.editable_text("workbench_target"), Vector2(8, 34), Vector2(130, 20), 11, Color(0.52, 0.82, 1.0))
	_board_label(content, target_name, Vector2(138, 30), Vector2(438, 26), 17, Color(0.98, 0.84, 0.45))
	_board_label(content, maya_npc.editable_text("workbench_night"), Vector2(8, 64), Vector2(130, 20), 11, Color(0.52, 0.82, 1.0))
	_board_label(content, night_display, Vector2(138, 60), Vector2(438, 26), 15, Color(0.68, 0.91, 0.96))
	var progress_text := maya_npc.editable_text("workbench_progress", {
		"progress": progress,
		"total": steps.size(),
	})
	_board_label(content, progress_text, Vector2(8, 94), Vector2(568, 24), 13, Color(0.64, 0.94, 0.86))
	var assembly_row_height := 44.0 if steps.size() > 3 else 52.0
	var assembly_row_step := 52.0 if steps.size() > 3 else 62.0
	var assembly_row_start := 120.0 if steps.size() > 3 else 126.0
	for index in range(steps.size()):
		var complete := index < progress
		var row := Panel.new()
		row.position = Vector2(8, assembly_row_start + index * assembly_row_step)
		row.size = Vector2(568, assembly_row_height)
		row.add_theme_stylebox_override("panel", _style(
			Color(0.04, 0.13, 0.13, 0.92) if complete else Color(0.035, 0.055, 0.085, 0.94),
			Color(0.38, 0.88, 0.68) if complete else Color(0.25, 0.39, 0.55), 1, 5
		))
		content.add_child(row)
		_board_label(row, "✓" if complete else str(index + 1), Vector2(12, 5), Vector2(38, 34), 18, Color(0.50, 1.0, 0.72) if complete else BRASS, HORIZONTAL_ALIGNMENT_CENTER)
		_board_label(row, str(steps[index]), Vector2(62, 5), Vector2(488, 34), 14, WARM_TEXT)
	var relationship_stage := str(work.get("relationship_stage", "colleague"))
	var relationship_name := maya_npc.editable_text("relationship_colleague")
	match relationship_stage:
		"familiar":
			relationship_name = maya_npc.editable_text("relationship_familiar")
		"trusted":
			relationship_name = maya_npc.editable_text("relationship_trusted")
	var project_caption := maya_npc.editable_text("shared_project", {
		"cycle": int(work.get("cycle", 1)),
		"relationship": relationship_name,
	})
	_board_label(content, project_caption, Vector2(8, 320), Vector2(568, 24), 11, Color(0.52, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	assist.disabled = progress >= steps.size() or str(work.get("phase", "")) != "assembling"
	assist.text = maya_npc.editable_text("workbench_finish") \
		if progress == steps.size() - 1 else maya_npc.editable_text("workbench_assist")


func _assist_maya_at_workbench() -> void:
	if maya_npc == null:
		return
	var result := maya_npc.assist_postgraduate_assembly()
	if str(result.get("phase", "")) == "observing":
		_close_maya_workbench(true)
		_show_feedback(maya_npc.editable_text("assembly_complete"), 3600)
		return
	_refresh_maya_workbench()


func _close_maya_workbench(completed: bool = false) -> void:
	if maya_workbench_popup == null:
		return
	var close_progress := maya_workbench_open_progress
	if maya_npc != null:
		close_progress = int(maya_npc.postgraduate_work_snapshot().get("assembly_progress", close_progress))
	var popup := maya_workbench_popup
	maya_workbench_popup = null
	InteractionFeedback.fade_then(popup, popup.queue_free)
	_resume_room_guidance_after_modal()
	if not completed and maya_npc != null:
		maya_npc.react_to_workbench_walkaway(maya_workbench_open_progress, close_progress)
	maya_workbench_open_progress = 0


func _open_maya_rest_chat() -> void:
	if maya_rest_chat_popup != null or maya_npc == null:
		return
	var chat := maya_npc.postgraduate_rest_chat_snapshot()
	var topics_value: Variant = chat.get("topics", [])
	var topics: Array = topics_value if topics_value is Array else []
	if topics.is_empty():
		return
	_suspend_room_guidance_for_modal()
	maya_rest_chat_popup = Control.new()
	maya_rest_chat_popup.name = "MayaRestConversation"
	maya_rest_chat_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	maya_rest_chat_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	maya_rest_chat_popup.z_index = COMPUTER_MODAL_LAYER
	add_child(maya_rest_chat_popup)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.010, 0.022, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	maya_rest_chat_popup.add_child(dim)

	var panel := Panel.new()
	panel.name = "MayaRestConversationPanel"
	panel.position = Vector2(220, 134)
	panel.size = Vector2(584, 500)
	panel.add_theme_stylebox_override("panel", _style(Color(0.024, 0.035, 0.055, 0.99), Color(0.73, 0.58, 0.36), 2, 9))
	maya_rest_chat_popup.add_child(panel)
	_board_label(panel, str(chat.get("title", "")), Vector2(24, 20), Vector2(536, 30), 20, BRASS, HORIZONTAL_ALIGNMENT_CENTER)
	_board_label(
		panel,
		maya_npc.editable_text("rest_tonight", {"night": str(chat.get("night_name", ""))}),
		Vector2(24, 52), Vector2(536, 22), 12, Color(0.60, 0.83, 0.92), HORIZONTAL_ALIGNMENT_CENTER
	)
	var intro := _board_label(panel, str(chat.get("intro", "")), Vector2(38, 80), Vector2(508, 44), 13, Color(0.76, 0.80, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var response_panel := Panel.new()
	response_panel.position = Vector2(30, 132)
	response_panel.size = Vector2(524, 104)
	response_panel.add_theme_stylebox_override("panel", _style(Color(0.038, 0.057, 0.078, 0.96), Color(0.32, 0.46, 0.58), 1, 6))
	panel.add_child(response_panel)
	_board_label(response_panel, "MAYA", Vector2(16, 10), Vector2(70, 18), 11, Color(0.52, 0.82, 1.0))
	var response := _board_label(
		response_panel,
		maya_npc.editable_text("rest_prompt"),
		Vector2(16, 32), Vector2(492, 58), 14, WARM_TEXT
	)
	response.name = "MayaRestConversationResponse"
	response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	response.max_lines_visible = 3

	var five_topic_layout := topics.size() > 4
	var topic_height := 34.0 if five_topic_layout else (40.0 if topics.size() > 3 else 46.0)
	var topic_step := 38.0 if five_topic_layout else (44.0 if topics.size() > 3 else 56.0)
	var topic_start_y := 238.0 if five_topic_layout else (244.0 if topics.size() > 3 else 252.0)
	for index in range(topics.size()):
		var topic_value: Variant = topics[index]
		if not topic_value is Dictionary:
			continue
		var topic := topic_value as Dictionary
		var topic_id := str(topic.get("id", ""))
		var button := _board_button(
			panel, str(topic.get("label", "")),
			Vector2(42, topic_start_y + index * topic_step), Vector2(500, topic_height),
			Color(0.055, 0.085, 0.115), Color(0.36, 0.51, 0.62)
		)
		button.name = "MayaRestTopic_%s" % topic_id
		button.pressed.connect(_choose_maya_rest_topic.bind(topic_id))
	var close := _board_button(
		panel, maya_npc.editable_text("rest_close"),
		Vector2(172, 432), Vector2(240, 42), Color(0.10, 0.12, 0.15), Color(0.55, 0.45, 0.34)
	)
	close.name = "MayaRestConversationCloseButton"
	close.pressed.connect(_close_maya_rest_chat)
	InteractionFeedback.page_enter(maya_rest_chat_popup, Vector2(0, 8))


func _choose_maya_rest_topic(topic_id: String) -> void:
	if maya_rest_chat_popup == null or maya_npc == null:
		return
	var response := maya_rest_chat_popup.find_child("MayaRestConversationResponse", true, false) as Label
	if response == null:
		return
	var reply := maya_npc.postgraduate_rest_response(topic_id)
	if reply == "":
		return
	response.text = reply
	InteractionFeedback.pulse(response)


func _close_maya_rest_chat() -> void:
	if maya_rest_chat_popup == null:
		return
	var popup := maya_rest_chat_popup
	maya_rest_chat_popup = null
	InteractionFeedback.fade_then(popup, popup.queue_free)
	_resume_room_guidance_after_modal()


func _click_interactable(id: String) -> void:
	if nearby_id == id:
		_handle_interaction(id)
		return
	_show_feedback(GameManager.text("Move closer to interact.", "靠近后互动。"), 1800)


func _handle_interaction(id: String) -> void:
	if furniture_interaction_active:
		return
	_remember_maya_pose()
	if maya_npc != null:
		maya_npc.react_to_interaction(id, "open")
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
		if GameManager.postgraduate_free_build() or _space_console_active():
			_remember_maya_pose(true)
			if GameManager.go_to_local_optical_observation("telescope"):
				GameManager.clear_room_guidance()
				return
			_show_feedback(GameManager.text(
				"This pad uses your assembled ground telescope. Finish a local optical build, or use the lower-right console for the remote mission.",
				"中央观测台使用你已组装的地面光学望远镜。请先完成一台地面望远镜，远程任务则从右下角控制台进入。"), 4200)
			return
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
			_remember_maya_pose(true)
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
	_toggle_remote_instrument_console()


func _toggle_remote_instrument_console() -> void:
	if stats_terminal_animating:
		return
	if stats_terminal_popup != null:
		_animate_stats_terminal_close()
		return
	_suspend_room_guidance_for_modal()
	stats_terminal_popup = Control.new()
	stats_terminal_popup.name = "RemoteInstrumentConsole"
	stats_terminal_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_terminal_popup.z_index = COMPUTER_MODAL_LAYER
	stats_terminal_popup.pivot_offset = Vector2(512, 384)
	add_child(stats_terminal_popup)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(170, 112)
	panel.size = Vector2(684, 520)
	panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.035, 0.052, 0.985), Color(0.30, 0.76, 0.82), 2, 4))
	stats_terminal_popup.add_child(panel)
	_terminal_label(GameManager.text("REMOTE INSTRUMENT CONSOLE", "远程仪器控制台"), Vector2(194, 132), Vector2(636, 34), 20, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_terminal_label(
		GameManager.text("Local optical observing remains on the central pad.", "中央观测台继续负责本地光学观测。"),
		Vector2(214, 170), Vector2(596, 24), 12, Color(0.62, 0.74, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	_add_remote_instrument_card("space", Vector2(202, 214), GameManager.text("SPACE INFRARED OBSERVATORY", "空间红外天文台"))
	_add_remote_instrument_card("radio", Vector2(202, 368), GameManager.text("FAST RADIO ARRAY", "FAST 射电阵列"))

	var stats := Button.new()
	stats.text = GameManager.text("SYSTEM STATS", "系统状态")
	stats.position = Vector2(222, 558)
	stats.size = Vector2(186, 44)
	stats.pressed.connect(func() -> void:
		if stats_terminal_popup != null:
			stats_terminal_popup.queue_free()
			stats_terminal_popup = null
			stats_terminal_animating = false
		_toggle_stats_terminal()
	)
	stats_terminal_popup.add_child(stats)
	var close := Button.new()
	close.text = GameManager.text("CLOSE", "关闭")
	close.position = Vector2(616, 558)
	close.size = Vector2(186, 44)
	close.pressed.connect(_toggle_remote_instrument_console)
	stats_terminal_popup.add_child(close)
	_animate_stats_terminal_open()


func _add_remote_instrument_card(kind: String, pos: Vector2, title: String) -> void:
	var status := _remote_console_status(kind)
	var card := Panel.new()
	card.position = pos
	card.size = Vector2(620, 132)
	var state := str(status.get("state", "locked"))
	var border := Color(0.28, 0.82, 0.72) if state == "active" else (Color(0.82, 0.62, 0.27) if state == "ready" else Color(0.34, 0.40, 0.48))
	card.add_theme_stylebox_override("panel", _style(Color(0.025, 0.052, 0.072, 0.96), border, 2, 2))
	stats_terminal_popup.add_child(card)
	var title_label := Label.new()
	title_label.text = title
	title_label.position = Vector2(18, 14)
	title_label.size = Vector2(390, 26)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", WARM_TEXT)
	card.add_child(title_label)
	var state_label := Label.new()
	state_label.text = str(status.get("label", ""))
	state_label.position = Vector2(420, 14)
	state_label.size = Vector2(176, 26)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", border)
	card.add_child(state_label)
	var reason := Label.new()
	reason.text = str(status.get("reason", ""))
	reason.position = Vector2(18, 48)
	reason.size = Vector2(390, 66)
	reason.custom_minimum_size = Vector2.ZERO
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.clip_text = true
	reason.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reason.add_theme_font_size_override("font_size", 11)
	reason.add_theme_color_override("font_color", Color(0.78, 0.86, 0.88))
	card.add_child(reason)
	var campaign := Button.new()
	campaign.text = (
		GameManager.text("CAMPAIGN COMPLETE", "主线已完成")
		if state == "completed"
		else GameManager.text("CAMPAIGN", "主线观测"))
	campaign.position = Vector2(430, 48)
	campaign.size = Vector2(166, 32)
	campaign.disabled = not bool(status.get("campaign_enabled", status.get("enabled", false)))
	campaign.pressed.connect(_launch_remote_from_selector.bind(kind, "campaign"))
	card.add_child(campaign)
	var free_observe := Button.new()
	free_observe.text = GameManager.text("FREE OBSERVATION", "自由观测")
	free_observe.position = Vector2(430, 86)
	free_observe.size = Vector2(166, 32)
	free_observe.disabled = not bool(status.get("free_enabled", false))
	free_observe.tooltip_text = GameManager.text(
		"Choose an independent observing program. This never advances the campaign.",
		"选择自主观测计划；自由观测不会推进主线。")
	free_observe.pressed.connect(_launch_remote_from_selector.bind(kind, "free"))
	card.add_child(free_observe)


func _launch_remote_from_selector(kind: String, mode: String = "campaign") -> void:
	if mode == "free":
		_show_remote_free_catalog(kind)
		return
	if stats_terminal_popup != null:
		stats_terminal_popup.queue_free()
		stats_terminal_popup = null
		stats_terminal_animating = false
	GameManager.begin_remote_campaign(kind)
	_enter_space_console(kind, "campaign")


func _show_remote_free_catalog(kind: String) -> void:
	# Free targets are acquired from the instrument itself. This compatibility
	# entrypoint seeds the session and opens the console without presenting the
	# legacy name-list modal.
	if not GameManager.remote_free_unlocked(kind):
		_show_feedback(GameManager.text(
			"Complete the instrument's first campaign observation to unlock independent time.",
			"请先完成这台仪器的首个主线观测，再进入自由观测。"), 3200)
		return
	var acquisition_catalog := GameManager.remote_free_catalog(kind)
	if acquisition_catalog.is_empty():
		_show_feedback(GameManager.text(
			"No independent observing programs are available.",
			"当前没有可用的自由观测计划。"), 2600)
		return
	var seed_entry := acquisition_catalog[0] as Dictionary
	if not GameManager.begin_remote_free_observation(kind, str(seed_entry.get("id", ""))):
		_show_feedback(GameManager.text(
			"The remote acquisition console could not start.",
			"远程目标截获控制台无法启动。"), 2600)
		return
	GameManager.consume_remote_free_intro(kind)
	if stats_terminal_popup != null:
		stats_terminal_popup.queue_free()
		stats_terminal_popup = null
	stats_terminal_animating = false
	_enter_space_console(kind, "free")
	return
	if not GameManager.remote_free_unlocked(kind):
		_show_feedback(GameManager.text(
			"Complete the instrument's first campaign observation to unlock independent time.",
			"请先完成这台仪器的首个主线观测，再申请自主观测。"), 3200)
		return
	if stats_terminal_popup != null:
		stats_terminal_popup.queue_free()
	stats_terminal_popup = Control.new()
	stats_terminal_popup.name = "RemoteFreeObservationCatalog"
	stats_terminal_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_terminal_popup.z_index = COMPUTER_MODAL_LAYER
	add_child(stats_terminal_popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(142, 74)
	panel.size = Vector2(740, 620)
	panel.add_theme_stylebox_override("panel", _style(Color(0.018, 0.035, 0.052, 0.99), Color(0.30, 0.76, 0.82), 2, 4))
	stats_terminal_popup.add_child(panel)
	_terminal_label(
		GameManager.text("DEEP-SKY PROGRAM" if kind == "space" else "RADIO SCIENCE PROGRAM",
			"深空观测计划" if kind == "space" else "射电科学计划"),
		Vector2(170, 94), Vector2(684, 34), 20, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var first_intro := GameManager.consume_remote_free_intro(kind)
	var intro_en := (
		"Campaign complete, but observing time remains. Choose a deep-sky target and decide how to reveal it."
		if kind == "space"
		else "There is no assigned answer this time. Choose a radio target and build the evidence.")
	var intro_zh := (
		"主线结束了，但观测时间还在。挑一个深空目标，自己决定怎样把它显出来。"
		if kind == "space"
		else "这次没有指定答案。挑一个无线电目标，把证据做出来。")
	_terminal_label(
		GameManager.text(
			intro_en if first_intro else "Choose an independent observing program.",
			intro_zh if first_intro else "选择一项自主观测计划。"),
		Vector2(174, 130), Vector2(676, 30), 11, Color(0.70, 0.82, 0.85), HORIZONTAL_ALIGNMENT_CENTER)

	var catalog := GameManager.remote_free_catalog(kind)
	if catalog.is_empty():
		_terminal_label(GameManager.text("No programs are available.", "暂无可用观测计划。"), Vector2(186, 190), Vector2(650, 40), 14, WARM_TEXT)
		return
	stats_terminal_popup.set_meta("remote_catalog_kind", kind)
	stats_terminal_popup.set_meta("remote_catalog_entry_id", str((catalog[0] as Dictionary).get("id", "")))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(174, 176)
	scroll.size = Vector2(318, 426)
	stats_terminal_popup.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(298, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var details := Label.new()
	details.name = "CatalogDetails"
	details.position = Vector2(516, 178)
	details.size = Vector2(326, 344)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 12)
	details.add_theme_color_override("font_color", Color(0.82, 0.90, 0.92))
	stats_terminal_popup.add_child(details)
	for value in catalog:
		var entry := value as Dictionary
		var button := Button.new()
		button.text = GameManager.text(str(entry.get("name_en", "")), str(entry.get("name_zh", "")))
		button.custom_minimum_size = Vector2(292, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_remote_catalog_entry.bind(kind, str(entry.get("id", "")), details))
		list.add_child(button)
	_select_remote_catalog_entry(kind, str((catalog[0] as Dictionary).get("id", "")), details)
	var start := Button.new()
	start.text = GameManager.text("BEGIN FREE OBSERVATION", "开始自由观测")
	start.position = Vector2(516, 540)
	start.size = Vector2(326, 54)
	start.pressed.connect(_start_selected_remote_free_observation)
	stats_terminal_popup.add_child(start)
	var back := Button.new()
	back.text = GameManager.text("BACK", "返回")
	back.position = Vector2(516, 608)
	back.size = Vector2(156, 44)
	back.pressed.connect(func() -> void:
		if stats_terminal_popup != null:
			stats_terminal_popup.queue_free()
			stats_terminal_popup = null
		_toggle_remote_instrument_console()
	)
	stats_terminal_popup.add_child(back)
	_animate_stats_terminal_open()


func _select_remote_catalog_entry(kind: String, entry_id: String, details: Label) -> void:
	if stats_terminal_popup == null:
		return
	var entry := GameManager.remote_free_entry(kind, entry_id)
	if entry.is_empty():
		return
	stats_terminal_popup.set_meta("remote_catalog_entry_id", entry_id)
	details.text = "%s\n\n%s\n%s\n\n%s\n\n%s" % [
		GameManager.text(str(entry.get("name_en", "")), str(entry.get("name_zh", ""))),
		GameManager.text("TYPE: " + str(entry.get("category_en", "")), "类型：" + str(entry.get("category_zh", ""))),
		GameManager.text("DIFFICULTY: " + str(entry.get("difficulty_en", "")), "难度：" + str(entry.get("difficulty_zh", ""))),
		GameManager.text("RECOMMENDED: " + str(entry.get("recommended_band_en", "Measured radio data")),
			"推荐：" + str(entry.get("recommended_band_zh", "射电数据分析"))),
		GameManager.text(str(entry.get("science_en", "")), str(entry.get("science_zh", ""))),
	]


func _start_selected_remote_free_observation() -> void:
	if stats_terminal_popup == null:
		return
	var kind := str(stats_terminal_popup.get_meta("remote_catalog_kind", ""))
	var entry_id := str(stats_terminal_popup.get_meta("remote_catalog_entry_id", ""))
	if not GameManager.begin_remote_free_observation(kind, entry_id):
		_show_feedback(GameManager.text("This observing program is not available.", "该观测计划当前不可用。"), 2600)
		return
	stats_terminal_popup.queue_free()
	stats_terminal_popup = null
	stats_terminal_animating = false
	_enter_space_console(kind, "free")


func _enter_space_console(kind: String = "", mode: String = "campaign") -> void:
	if room_transition_active:
		return
	var selected_kind := kind if kind != "" else _remote_console_kind()
	var free_mode := mode == "free" and GameManager.is_remote_free_observation(selected_kind)
	if selected_kind == "" or (not free_mode and selected_kind != _remote_console_kind()):
		_show_feedback(GameManager.text(
			"No matching remote mission is active for this instrument.",
			"当前没有与这台仪器对应的远程任务。"), 3200)
		return
	var gate: Dictionary = GameManager.can_enter_observation()
	if not free_mode and not bool(gate.get("ok", false)):
		_show_feedback(GameManager.text(
			str(gate.get("reason_en", "Finish assembling the space observatory before opening the command link.")),
			str(gate.get("reason_zh", "请先完成空间望远镜组装，再打开指挥链路。"))), 3600)
		return
	var destination := _remote_destination_for_kind(selected_kind)
	if not free_mode and GameManager.try_story_for_trigger("before_observation", destination):
		return
	if not free_mode and GameManager.try_teaching_intercept("before_observation", destination):
		return
	_suspend_room_guidance_for_modal()
	pending_remote_console_kind = selected_kind
	pending_remote_console_scene = destination
	room_transition_active = true
	var overlay := Control.new()
	overlay.name = "SpaceConsoleTransition"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = COMPUTER_MODAL_LAYER
	var reduced_motion := InteractionFeedback.is_reduced_motion()
	overlay.set_meta(
		"transition_duration",
		REMOTE_CONSOLE_OPEN_DURATION_REDUCED if reduced_motion else REMOTE_CONSOLE_OPEN_DURATION)
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
	var radio_console := selected_kind == "radio"
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
	var zoom_time := 0.42 if reduced_motion else 0.72
	var scan_time := 0.28 if reduced_motion else 0.48
	var settle_time := 0.12 if reduced_motion else 0.18
	var fade_time := 0.13 if reduced_motion else 0.17
	var tween := create_tween().bind_node(overlay)
	tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	# First beat: the physical console is claimed by the modal layer and moves
	# into view. The slight overshoot gives the movement weight without shake.
	tween.tween_property(dim, "color:a", 0.88, zoom_time * 0.72)
	tween.parallel().tween_property(terminal, "position", Vector2(438, 243), zoom_time)
	tween.parallel().tween_property(terminal, "scale", Vector2(1.92, 1.92), zoom_time)
	tween.parallel().tween_property(status, "modulate:a", 1.0, zoom_time * 0.48).set_delay(zoom_time * 0.30)
	# Second beat: the local screen scans once while the remote link answers.
	tween.tween_callback(func() -> void:
		status.text = GameManager.text(
			"RADIO ARRAY RESPONDING  ·  SYNCHRONISING RECEIVER" if radio_console
				else "L2 OBSERVATORY RESPONDING  ·  SYNCHRONISING CLOCK",
			"射电阵列已响应  ·  正在同步接收机" if radio_console
				else "L2 天文台已响应  ·  正在同步时钟"))
	tween.tween_property(scan, "position:y", 102.0, scan_time).set_trans(Tween.TRANS_LINEAR)
	# Third beat: the overshoot settles before routing, so the transition reads
	# as a completed hand-off instead of an abrupt scene replacement.
	tween.tween_property(terminal, "scale", Vector2(1.85, 1.85), settle_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		status.text = GameManager.text(
			"REMOTE CONSOLE READY  ·  TRANSFERRING CONTROL",
			"远程控制台就绪  ·  正在移交控制权"))
	tween.tween_interval(fade_time)
	tween.chain().tween_callback(_finish_space_console_transition)


func _finish_space_console_transition() -> void:
	GameManager.clear_room_guidance()
	var destination := pending_remote_console_scene
	if destination == "":
		destination = _remote_destination_for_kind(pending_remote_console_kind if pending_remote_console_kind != "" else _remote_console_kind())
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
	mission_board_popup.name = "MissionBoardModal"
	mission_board_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_board_popup.z_index = COMPUTER_MODAL_LAYER
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
	mission_board_popup.name = "GraduatedMissionBoardModal"
	mission_board_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	mission_board_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	mission_board_popup.z_index = COMPUTER_MODAL_LAYER
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

	var note_panel := _board_section(panel, Vector2(54, 216), Vector2(692, 226), GameManager.text("FIRST INDEPENDENT NIGHT", "独立观测第一夜"))
	var note := _board_label(note_panel, GameManager.text(
		"Choose one question. Choose the instrument that can answer it. Make one record another observer could trust. Ground telescopes, Space Infrared, and FAST now remain open for independent work.",
		"选一个问题，选一台能回答它的仪器，再留下让另一位观测者也能相信的记录。地面望远镜、空间红外与 FAST 现已持续开放，供你独立使用。"
	), Vector2(28, 52), Vector2(636, 118), 17, WARM_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_label(note_panel, GameManager.text(
		"No score is required. Your next result belongs in the Club Logbook.",
		"这次没有分数要求。你的下一份成果，将由你亲自写进俱乐部观测档案。"
	), Vector2(28, 176), Vector2(636, 28), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var ceremony_text := GameManager.text("Attend Ceremony", "参加毕业典礼") if GameManager.graduation_pending() \
		else GameManager.text("Replay Ceremony", "回看毕业典礼")
	var ceremony_button := _board_button(panel, ceremony_text, Vector2(82, 500), Vector2(210, 46), Color(0.34, 0.22, 0.07), Color(1.0, 0.78, 0.30))
	ceremony_button.name = "GraduationCeremonyButton"
	ceremony_button.pressed.connect(func() -> void: GameManager.go("graduation"))
	var log_button := _board_button(panel, GameManager.text("Open Logbook", "打开观测日志"), Vector2(306, 500), Vector2(210, 46), Color(0.06, 0.18, 0.34), Color(0.42, 0.74, 1.0))
	log_button.pressed.connect(_open_logbook_from_mission_board)
	var close_button := _board_button(panel, GameManager.text("Start Exploring", "开始自由探索"), Vector2(530, 500), Vector2(188, 46), Color(0.08, 0.30, 0.20), Color(0.52, 0.90, 0.54))
	close_button.pressed.connect(func() -> void: _close_mission_board(true))


func _close_mission_board(show_guidance: bool) -> void:
	if mission_board_popup != null:
		var popup := mission_board_popup
		mission_board_popup = null
		InteractionFeedback.fade_then(popup, popup.queue_free)
	if furniture_animator != null:
		furniture_animator.play_close("mission")
	if maya_npc != null:
		maya_npc.react_to_interaction("mission", "close")
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
	if GameManager.current_observation_mode() == "naked_eye":
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
	if GameManager.current_observation_mode() == "naked_eye":
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
		GameManager.text("Maya: \"New parts just arrived for the club!\"", "玛雅：“俱乐部的新零件到货啦！”"),
		Vector2(x_text, y), Vector2(360, 40), 12, WARM_TEXT)
	maya_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	y += 44.0
	for index in range(line_count):
		var part: Dictionary = GameManager.get_part(str(pending[index]))
		var part_name := GameManager.dict_text(part, "name")
		_popup_label_on(unlock_popup, "•  " + part_name, Vector2(x_text, y), Vector2(360, 22), 13, Color(0.60, 0.95, 0.70))
		y += 26.0
	y += 10.0
	var opens_observation_pad := int(GameManager.current_level().get("level_number", 0)) == 6
	var hint_text := GameManager.text(
		"The 10mm eyepiece is now in your inventory. Return to the Observation Pad to continue.",
		"10mm 目镜已加入库存，返回观星台继续。"
	) if opens_observation_pad else GameManager.text(
		"Equip them at the Parts Cabinet, then reassemble at the Assembly Table.",
		"到零件柜装备它们，然后在组装台重新组装。"
	)
	var hint := _popup_label_on(unlock_popup,
		hint_text,
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
	equip_now.text = GameManager.text("Open Observation Pad", "打开观星台") if opens_observation_pad else GameManager.text("Open Parts Cabinet", "打开零件柜")
	equip_now.position = Vector2(492, panel.position.y + panel_height - 52.0)
	equip_now.size = Vector2(220, 38)
	equip_now.add_theme_font_size_override("font_size", 13)
	equip_now.pressed.connect(func() -> void:
		_close_unlock_popup(false)
		if opens_observation_pad:
			_handle_interaction("telescope")
			return
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
	if stats_terminal_animating:
		return
	if stats_terminal_popup != null:
		_animate_stats_terminal_close()
		return
	var stats := GameManager.calculate_stats()

	_suspend_room_guidance_for_modal()
	stats_terminal_popup = Control.new()
	stats_terminal_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_terminal_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_terminal_popup.z_index = COMPUTER_MODAL_LAYER
	stats_terminal_popup.pivot_offset = Vector2(512, 384)
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
	_animate_stats_terminal_open()


func _animate_stats_terminal_open() -> void:
	if stats_terminal_popup == null:
		return
	stats_terminal_animating = true
	var reduced := InteractionFeedback.is_reduced_motion()
	var duration := (
		STATS_TERMINAL_OPEN_DURATION_REDUCED
		if reduced else STATS_TERMINAL_OPEN_DURATION)
	stats_terminal_popup.set_meta("transition_duration", duration)
	stats_terminal_popup.modulate = Color(0.80, 0.94, 0.86, 0.0)
	stats_terminal_popup.position = Vector2(16, 12)
	stats_terminal_popup.scale = Vector2(0.975, 0.975)
	var tween := create_tween().bind_node(stats_terminal_popup)
	tween.set_parallel(true)
	tween.tween_property(
		stats_terminal_popup, "modulate", Color.WHITE, duration * 0.62
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		stats_terminal_popup, "position", Vector2.ZERO, duration
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		stats_terminal_popup, "scale", Vector2.ONE, duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func() -> void:
		stats_terminal_animating = false
	)


func _animate_stats_terminal_close() -> void:
	if stats_terminal_popup == null:
		return
	stats_terminal_animating = true
	var popup := stats_terminal_popup
	var reduced := InteractionFeedback.is_reduced_motion()
	var duration := (
		STATS_TERMINAL_CLOSE_DURATION_REDUCED
		if reduced else STATS_TERMINAL_CLOSE_DURATION)
	popup.set_meta("close_transition_duration", duration)
	var tween := create_tween().bind_node(popup)
	tween.set_parallel(true)
	tween.tween_property(
		popup, "modulate", Color(0.62, 0.82, 0.70, 0.0), duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(
		popup, "position", Vector2(14, 10), duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(
		popup, "scale", Vector2(0.982, 0.982), duration
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
		if stats_terminal_popup == popup:
			stats_terminal_popup = null
		stats_terminal_animating = false
		_resume_room_guidance_after_modal()
		if furniture_animator != null:
			furniture_animator.play_close("computer")
	)


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
	# Furniture cutouts only exist to occlude the player while walking behind a
	# prop. They are not modal decoration and must never float over mission,
	# unlock, or remote-console content.
	for data in furniture_occluders:
		var occluder := data.get("node") as CanvasItem
		if occluder != null:
			occluder.visible = false
	_update_guidance_toggle_button()
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
	_update_furniture_occlusion()
	_update_guidance_toggle_button()
	_update_room_guidance_panel()


func _update_room_guidance_panel() -> void:
	if guidance_panel == null:
		return
	_update_guidance_toggle_button()
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
	guidance_panel.visible = false
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
	if room_guidance_suspended or item.is_empty() or not GameManager.uses_full_tutorials() or not InteractionFeedback.guidance_highlights_enabled():
		guidance_overlay.visible = false
		return
	guidance_overlay.visible = true
	var rect: Rect2 = item.get("rect", Rect2()).grow(24.0)
	rect.position.x = clampf(rect.position.x, 0.0, W)
	rect.position.y = clampf(rect.position.y, 0.0, H)
	rect.size.x = clampf(rect.size.x, 0.0, W - rect.position.x)
	rect.size.y = clampf(rect.size.y, 0.0, H - rect.position.y)
	# Keep the room readable. A restrained focus wash plus short corner brackets
	# guides the eye without turning the destination into a hard debug rectangle.
	var dim_color := Color(0.0, 0.0, 0.0, 0.16)
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
	var focus_wash := Panel.new()
	focus_wash.name = "GuidanceFocusWash"
	focus_wash.position = rect.position
	focus_wash.size = rect.size
	focus_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1.0, 0.78, 0.24, 0.035)
	focus_style.border_color = Color(0.52, 0.86, 1.0, 0.18)
	focus_style.set_border_width_all(1)
	focus_style.set_corner_radius_all(12)
	focus_wash.add_theme_stylebox_override("panel", focus_style)
	guidance_overlay.add_child(focus_wash)
	var pulse := 0.62 if InteractionFeedback.is_reduced_motion() else 0.54 + 0.18 * sin(float(Time.get_ticks_msec()) / 360.0)
	var outer := _thin_highlight_frame_to(guidance_overlay, rect.grow(10.0), Color(0.52, 0.86, 1.0, pulse))
	outer.name = "GuidanceCornerFrameOuter"
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := _thin_highlight_frame_to(guidance_overlay, rect.grow(2.0), Color(1.0, 0.82, 0.30, 0.88))
	inner.name = "GuidanceCornerFrameInner"
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
			return GameManager.text("Go to the Remote Instrument Console", "前往远程仪器控制台")
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
	return SPAWN_POINTS.get(spawn_id, Vector2(512, 646))


func _is_ready_observation_target(id: String) -> bool:
	return bool(GameManager.can_enter_observation().get("ok", false)) and (id == "door" or id == "telescope")


func _get_interactable(id: String) -> Dictionary:
	for data in interactables:
		if str(data["id"]) == id:
			return data
	return {}


func _thin_highlight_frame(rect: Rect2, color: Color) -> Control:
	var frame := _corner_highlight_frame_to(self, rect, color, 2.0, 22.0)
	frame.name = "InteractableCornerFrame"
	return frame


func _thin_highlight_frame_to(parent: Control, rect: Rect2, color: Color) -> Control:
	var frame := _corner_highlight_frame_to(parent, rect, color, 2.0, 26.0)
	return frame


func _corner_highlight_frame_to(parent: Control, rect: Rect2, color: Color, thickness: float, arm_length: float) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	var arm := minf(arm_length, minf(rect.size.x, rect.size.y) * 0.32)
	var right := rect.size.x - thickness
	var bottom := rect.size.y - thickness
	for segment in [
		Rect2(0, 0, arm, thickness),
		Rect2(0, 0, thickness, arm),
		Rect2(rect.size.x - arm, 0, arm, thickness),
		Rect2(right, 0, thickness, arm),
		Rect2(0, bottom, arm, thickness),
		Rect2(0, rect.size.y - arm, thickness, arm),
		Rect2(rect.size.x - arm, bottom, arm, thickness),
		Rect2(right, rect.size.y - arm, thickness, arm),
	]:
		_frame_rect(frame, segment.position, segment.size, color)
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
	GameManager.update_room_guidance_for_level()
	_build()


func _on_guidance_highlights_changed(enabled: bool) -> void:
	if guidance_overlay != null and not enabled:
		_clear(guidance_overlay)
		guidance_overlay.visible = false
	if route_edge_indicator != null and not enabled:
		route_edge_indicator.visible = false
	if guidance_panel != null:
		guidance_panel.visible = false
	_update_guidance_toggle_button()
	if enabled:
		_update_room_guidance_panel()
