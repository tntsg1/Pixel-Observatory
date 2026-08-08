extends Node2D
class_name MayaHallNPC

const ATLAS_TEXTURE: Texture2D = preload("res://assets/characters/maya/hall_npc/maya_hall_atlas.png")
const ATLAS_METADATA_PATH := "res://assets/characters/maya/hall_npc/maya_hall_atlas.json"
const DIALOGUE_PATH := "res://data/maya_npc_dialogue.json"
const CELL_SIZE := Vector2(64, 80)
const DISPLAY_SCALE := 1.67
const FOOT_ANCHOR_Y := 74.0
const MOVE_SPEED := 76.0
const PATH_CELL_SIZE := 16.0
const WAYPOINT_EPSILON := 0.75
const PLAYER_INTERACT_DISTANCE := 64.0
const BUBBLE_EXPAND_DISTANCE := 150.0
const AMBIENT_MIN_SECONDS := 480.0
const AMBIENT_MAX_SECONDS := 780.0
const FREE_ACTIVITY_MIN_SECONDS := 18.0
const FREE_ACTIVITY_MAX_SECONDS := 30.0
const ROUTE_REACTION_COOLDOWN_MSEC := 6200
const ROUTE_SETTLE_MSEC := 2600
const ROUTE_LAG_DISTANCE := 176.0
const ROUTE_NEAR_DISTANCE := 92.0
const ROUTE_ARRIVAL_DISTANCE := 52.0
const PLAYER_STOPPED_MSEC := 5200
const PLAYER_INACTIVE_MSEC := 12500
const POSTGRADUATE_TIME_SCALE := 10.0
const POSTGRADUATE_TIMING_VERSION := 2
const OBSERVATION_HALL_ROAM_LEG_SECONDS := 36.0
const OBSERVATION_HALL_ROAM_DWELL_SECONDS := 12.0

const FACING_ROWS := {
	"down": "walk_south",
	"down_right": "walk_south_east",
	"right": "walk_east",
	"up_right": "walk_north_east",
	"up": "walk_north",
	"up_left": "walk_north_west",
	"left": "walk_west",
	"down_left": "walk_south_west",
}

var _sprite: Sprite2D
var _sprite_atlas: AtlasTexture
var _shadow: Polygon2D
var _bubble: Panel
var _bubble_icon: Label
var _bubble_status: Label
var _bubble_line: Label
var _bubble_badge: Panel
var _badge_icon: Label
var _bubble_line_marquee: Tween
var _bubble_line_marquee_enabled := false
var _bubble_line_home_position := Vector2.ZERO
var _animations: Dictionary = {}
var _dialogue_states: Dictionary = {}
var _ambient_lines: Dictionary = {}
var _room_text: Dictionary = {}
var _walkable_provider: Callable
var _player_position_provider: Callable
var _destination_provider: Callable
var _focus_provider: Callable
var _route_target_provider: Callable
var _pathfinder := AStarGrid2D.new()
var _path := PackedVector2Array()
var _path_index := 0
var _destination_id := ""
var _facing := ""
var _animation_name := ""
var _animation_frame := 0
var _animation_elapsed := 0.0
var _animation_loop := true
var _return_to_idle_after_animation := false
var _animation_speed_scale := 1.0
var _moving := false
var _arrived := false
var _room_blocked := false
var _ambient_elapsed := 0.0
var _ambient_delay := 560.0
var _free_activity_elapsed := 0.0
var _free_activity_delay := 22.0
var _free_activity_deck: Array[String] = []
var _bubble_hide_at_msec := 0
var _state_id := "idle"
var _initial_return_state := ""
var _movement_locked_until_msec := 0
var _route_enabled := false
var _route_is_guided := false
var _route_started_at_msec := 0
var _route_arrived_at_msec := 0
var _last_reaction_at_msec := -ROUTE_REACTION_COOLDOWN_MSEC
var _player_last_position := Vector2.ZERO
var _player_last_move_at_msec := 0
var _player_best_destination_distance := INF
var _reaction_seen: Dictionary = {}
var _interaction_counts: Dictionary = {}
var _player_was_near := false
var _player_has_been_near := false
var _maya_in_front_of_player := false
var _maya_in_front_of_furniture := false
var _rng := RandomNumberGenerator.new()
var _postgraduate_routines: Dictionary = {}
var _postgraduate_phase := ""
var _postgraduate_target_id := ""
var _postgraduate_instrument_id := ""
var _postgraduate_night_id := ""
var _postgraduate_event_id := "none"
var _postgraduate_cycle := 0
var _postgraduate_assembly_progress := 0
var _postgraduate_phase_started_unix := 0
var _postgraduate_phase_duration_seconds := 0.0
var _postgraduate_interaction_phase := ""
var _postgraduate_interaction_count := 0
var _postgraduate_override_copy: Dictionary = {}
var _recent_postgraduate_lines: Array[String] = []
var _postgraduate_relationship: Dictionary = {}
var _postgraduate_return_result: Dictionary = {}
var _observation_hall_roam_stations: Array[String] = []
var _observation_hall_roam_index := 0
var _observation_hall_roam_dwell_elapsed := 0.0


func setup(
	initial_foot_position: Vector2,
	walkable_provider: Callable,
	player_position_provider: Callable,
	destination_provider: Callable,
	route_target_provider: Callable,
	initial_return_state: String = "",
	initial_facing: String = "down",
	focus_provider: Callable = Callable()
) -> void:
	position = initial_foot_position
	_walkable_provider = walkable_provider
	_player_position_provider = player_position_provider
	_destination_provider = destination_provider
	_focus_provider = focus_provider
	_route_target_provider = route_target_provider
	_initial_return_state = initial_return_state
	_rng.randomize()
	_load_data()
	_build_visuals()
	_build_pathfinder()
	_set_facing(initial_facing)
	_player_last_position = _player_position_provider.call() if _player_position_provider.is_valid() else position
	_player_last_move_at_msec = Time.get_ticks_msec()
	var return_reaction: Dictionary = {}
	if _is_postgraduate_free_roam():
		_ensure_postgraduate_work_plan()
		return_reaction = _postgraduate_return_reaction()
	var accepted_companion_result := _accept_postgraduate_observation_return()
	if accepted_companion_result:
		_show_state("postgraduate_observation_return", true)
	elif _initial_return_state != "":
		_show_state(_initial_return_state, true)
	elif not return_reaction.is_empty():
		_show_postgraduate_override(return_reaction)
	else:
		_show_state("greeting", true)
	# Return-state gestures use front-facing source art, but they must not erase
	# the logical facing restored from the lobby. When the gesture finishes the
	# correct directional idle frame resumes.
	_set_facing(initial_facing)
	_resume_observation_hall_roam()
	call_deferred("_begin_first_route")


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_update_depth()
	_update_bubble_visibility()
	if _room_blocked:
		return
	if _route_enabled:
		_update_route_target()
	_update_player_behavior()
	_update_movement(delta)
	_update_animation(delta)
	_update_observation_hall_roam(delta)
	_update_ambient_bubble(delta)
	_update_free_activity(delta)


func set_room_blocked(blocked: bool) -> void:
	_room_blocked = blocked
	if blocked:
		if _bubble != null:
			_bubble.visible = false
		if _bubble_badge != null:
			_bubble_badge.visible = false
	elif _bubble != null and _bubble_badge != null:
		_update_bubble_visibility()
		# An intentionally silent state stays silent.  Never revive the retired
		# symbol badge as a fallback; it surfaced as an unexplained question mark.
		if not _bubble.visible:
			_bubble_badge.visible = false


func refresh_language() -> void:
	_apply_state_text(_state_id)


func collision_rect() -> Rect2:
	# Maya is a companion, not a piece of furniture. Players can pass through
	# her so a narrow aisle or shared workstation never becomes a soft lock.
	return Rect2(position, Vector2.ZERO)


func contains_screen_point(screen_position: Vector2) -> bool:
	var body_rect := Rect2(
		position - Vector2(CELL_SIZE.x * DISPLAY_SCALE * 0.5, FOOT_ANCHOR_Y * DISPLAY_SCALE),
		Vector2(CELL_SIZE.x * DISPLAY_SCALE, CELL_SIZE.y * DISPLAY_SCALE)
	)
	if body_rect.has_point(screen_position):
		return true
	if _bubble != null and _bubble.visible:
		return Rect2(position + _bubble.position, _bubble.size).has_point(screen_position)
	return false


func player_is_near(max_distance: float = PLAYER_INTERACT_DISTANCE) -> bool:
	return _player_position_provider.is_valid() \
		and position.distance_to(_player_position_provider.call()) <= max_distance


func respond_to_player() -> void:
	if _room_blocked or not _player_position_provider.is_valid():
		return
	_face_toward(_player_position_provider.call())
	var state := _state_id
	if _route_is_guided:
		state = _route_state("arrive", _destination_id, "route_arrived") if _arrived \
			else _route_state("guide", _destination_id, "guide")
	else:
		var manager := get_node_or_null("/root/GameManager")
		var progress_value: Variant = manager.get("progress") if manager != null else {}
		if progress_value is Dictionary and bool(progress_value.get("graduation_seen", false)):
			_ensure_postgraduate_work_plan()
			_remember_postgraduate_event("conversations")
			_register_postgraduate_interaction()
			state = _postgraduate_state_id() if _postgraduate_phase != "" \
				else ("free_join" if _player_has_been_near else "free_near")
			_player_has_been_near = true
			var interruption := _postgraduate_interruption_reaction()
			if not interruption.is_empty():
				_show_postgraduate_override(interruption)
				return
		elif _dialogue_states.has(_destination_id):
			state = _destination_id
	_show_state(state, true)


func postgraduate_interaction_request() -> Dictionary:
	if not _is_postgraduate_free_roam():
		return {}
	_ensure_postgraduate_work_plan()
	if _postgraduate_phase == "assembling" and _destination_id == "assembly" and _arrived:
		return {
			"action": "open_workbench",
			"object_id": _postgraduate_target_id,
			"instrument_id": _postgraduate_instrument_id,
			"instrument_name_en": _postgraduate_instrument_name(false),
			"instrument_name_zh": _postgraduate_instrument_name(true),
			"night_id": _postgraduate_night_id,
		}
	if _postgraduate_phase == "observing" and _destination_id == "telescope" and _arrived:
		return {
			"action": "join_observation",
			"object_id": _postgraduate_target_id,
			"instrument_id": _postgraduate_instrument_id,
			"instrument_name_en": _postgraduate_instrument_name(false),
			"instrument_name_zh": _postgraduate_instrument_name(true),
			"night_id": _postgraduate_night_id,
		}
	if _postgraduate_phase == "resting" and _destination_id == "journal" and _arrived:
		return {
			"action": "rest_chat",
			"night_id": _postgraduate_night_id,
			"relationship_stage": _postgraduate_relationship_stage(),
		}
	return {
		"action": "talk",
		"phase": _postgraduate_phase,
		"object_id": _postgraduate_target_id,
		"instrument_id": _postgraduate_instrument_id,
	}


func assist_postgraduate_assembly() -> Dictionary:
	if not _is_postgraduate_free_roam():
		return postgraduate_work_snapshot()
	_ensure_postgraduate_work_plan()
	if _postgraduate_phase != "assembling":
		return postgraduate_work_snapshot()
	var steps := _postgraduate_assembly_steps(false)
	var step_count := maxi(1, steps.size())
	_postgraduate_assembly_progress = mini(step_count, _postgraduate_assembly_progress + 1)
	_remember_postgraduate_event("assembly_assists")
	_save_postgraduate_work_plan()
	_show_state(_postgraduate_state_id(), true)
	if _postgraduate_assembly_progress >= step_count:
		_advance_postgraduate_work()
		_sync_postgraduate_activity_timer()
		_update_route_target(true)
	return postgraduate_work_snapshot()


func remember_joined_observation() -> void:
	if not _is_postgraduate_free_roam():
		return
	_remember_postgraduate_event("observations_joined")


func remember_player_departure(begin_observation_hall_roam: bool = false) -> void:
	if not _is_postgraduate_free_roam():
		return
	_ensure_postgraduate_work_plan()
	var manager := get_node_or_null("/root/GameManager")
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	if not progress_value is Dictionary:
		return
	if begin_observation_hall_roam:
		var stations := _observation_hall_roam_stations_for_phase()
		if not stations.is_empty():
			(progress_value as Dictionary)["maya_observation_hall_roam"] = {
				"started_unix": _postgraduate_now_unix(),
				"stations": stations.duplicate(),
				"leg_seconds": OBSERVATION_HALL_ROAM_LEG_SECONDS,
			}
	(progress_value as Dictionary)["maya_postgraduate_presence"] = {
		"departed_unix": _postgraduate_now_unix(),
		"phase": _postgraduate_phase,
		"cycle": _postgraduate_cycle,
		"target_id": _postgraduate_target_id,
	}
	if manager.has_method("save"):
		manager.call_deferred("save")


func react_to_workbench_walkaway(open_progress: int, close_progress: int) -> void:
	if not _is_postgraduate_free_roam() or _postgraduate_phase != "assembling":
		return
	_remember_postgraduate_event("workbench_walkaways")
	var touched := close_progress > open_progress
	var reaction := _postgraduate_workbench_walkaway_reaction(touched)
	if not reaction.is_empty():
		_show_postgraduate_override(reaction)


func postgraduate_rest_chat_snapshot() -> Dictionary:
	_ensure_postgraduate_work_plan()
	_ensure_postgraduate_relationship()
	var manager := get_node_or_null("/root/GameManager")
	var chinese := manager != null and str(manager.get("language_mode")) == "zh"
	var locale := "zh" if chinese else "en"
	var chat_value: Variant = _postgraduate_routines.get("rest_chat", {})
	var chat: Dictionary = chat_value if chat_value is Dictionary else {}
	var topics_value: Variant = chat.get("topics", [])
	var topics: Array[Dictionary] = []
	if topics_value is Array:
		for value in topics_value:
			if value is Dictionary:
				var topic := value as Dictionary
				topics.append({
					"id": str(topic.get("id", "")),
					"label": str(topic.get("label_%s" % locale, "")),
				})
	var event_topic_value: Variant = _postgraduate_event_data().get("rest_topic", {})
	if event_topic_value is Dictionary and not event_topic_value.is_empty():
		var event_topic := event_topic_value as Dictionary
		topics.append({
			"id": str(event_topic.get("id", "")),
			"label": str(event_topic.get("label_%s" % locale, "")),
		})
	var memory_topic := _eligible_unseen_private_memory()
	if not memory_topic.is_empty():
		topics.append({
			"id": str(memory_topic.get("id", "")),
			"label": str(memory_topic.get("label_%s" % locale, "")),
			"private_memory": true,
		})
	return {
		"title": str(chat.get("title_%s" % locale, "")),
		"intro": str(chat.get("intro_%s" % locale, "")),
		"topics": topics,
		"night_name": _postgraduate_night_name(chinese),
		"relationship_stage": _postgraduate_relationship_stage(),
	}


func postgraduate_rest_response(topic_id: String) -> String:
	_ensure_postgraduate_work_plan()
	_ensure_postgraduate_relationship()
	var manager := get_node_or_null("/root/GameManager")
	var chinese := manager != null and str(manager.get("language_mode")) == "zh"
	var locale := "zh" if chinese else "en"
	var chat_value: Variant = _postgraduate_routines.get("rest_chat", {})
	var topics_value: Variant = (chat_value as Dictionary).get("topics", []) if chat_value is Dictionary else []
	var selected_topic: Dictionary = {}
	var selected_private_memory := false
	if topics_value is Array:
		for value in topics_value:
			if value is Dictionary and str((value as Dictionary).get("id", "")) == topic_id:
				selected_topic = value as Dictionary
				break
	if selected_topic.is_empty():
		var event_topic_value: Variant = _postgraduate_event_data().get("rest_topic", {})
		if event_topic_value is Dictionary and str((event_topic_value as Dictionary).get("id", "")) == topic_id:
			selected_topic = event_topic_value as Dictionary
	if selected_topic.is_empty():
		var eligible_memory := _eligible_unseen_private_memory()
		if str(eligible_memory.get("id", "")) == topic_id:
			selected_topic = eligible_memory
			selected_private_memory = true
	if selected_topic.is_empty():
		return ""
	var stage := _postgraduate_relationship_stage()
	var lines_value: Variant = selected_topic.get(
		"lines_%s" % locale if selected_private_memory else "%s_lines_%s" % [stage, locale],
		[]
	)
	var lines: Array = lines_value if lines_value is Array else []
	var candidates: Array[String] = []
	for value in lines:
		var formatted := _format_postgraduate_copy(str(value), chinese)
		if not _recent_postgraduate_lines.has(formatted):
			candidates.append(formatted)
	if candidates.is_empty():
		for value in lines:
			candidates.append(_format_postgraduate_copy(str(value), chinese))
	var response := candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else ""
	if response != "":
		_recent_postgraduate_lines.append(response)
		while _recent_postgraduate_lines.size() > 4:
			_recent_postgraduate_lines.pop_front()
	_remember_postgraduate_event("rest_conversations")
	if topic_id == "tea":
		_remember_postgraduate_event("tea_breaks_shared")
	if selected_private_memory:
		_remember_private_memory(topic_id)
	return response


func _accept_postgraduate_observation_return() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not manager.has_method("consume_maya_companion_observation_return"):
		return false
	var progress_value: Variant = manager.get("progress")
	if not progress_value is Dictionary or not bool((progress_value as Dictionary).get("graduation_seen", false)):
		return false
	var result_value: Variant = manager.call("consume_maya_companion_observation_return")
	var result: Dictionary = result_value if result_value is Dictionary else {}
	if result.is_empty():
		return false
	_ensure_postgraduate_work_plan()
	if _postgraduate_phase != "observing" or str(result.get("object_id", "")) != _postgraduate_target_id:
		return false
	_postgraduate_return_result = result.duplicate(true)
	_remember_postgraduate_event("observations_completed")
	_advance_postgraduate_work()
	_sync_postgraduate_activity_timer()
	return true


func interaction_prompt() -> String:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null or not _is_postgraduate_free_roam():
		return editable_text("talk_to_maya")
	_ensure_postgraduate_work_plan()
	var phase: Dictionary = _postgraduate_phase_data()
	var chinese := str(manager.get("language_mode")) == "zh"
	var key := "interaction_zh" if chinese else "interaction_en"
	return _format_postgraduate_copy(str(phase.get(key, "")), chinese)


func postgraduate_work_snapshot() -> Dictionary:
	_ensure_postgraduate_work_plan()
	_ensure_postgraduate_relationship()
	return {
		"phase": _postgraduate_phase,
		"destination": _postgraduate_destination(),
		"target_id": _postgraduate_target_id,
		"instrument_id": _postgraduate_instrument_id,
		"instrument_name_en": _postgraduate_instrument_name(false),
		"instrument_name_zh": _postgraduate_instrument_name(true),
		"night_id": _postgraduate_night_id,
		"night_name_en": _postgraduate_night_name(false),
		"night_name_zh": _postgraduate_night_name(true),
		"event_id": _postgraduate_event_id,
		"event_name_en": _postgraduate_event_name(false),
		"event_name_zh": _postgraduate_event_name(true),
		"target_name_en": _postgraduate_target_name(false),
		"target_name_zh": _postgraduate_target_name(true),
		"assembly_progress": _postgraduate_assembly_progress,
		"phase_started_unix": _postgraduate_phase_started_unix,
		"phase_duration_seconds": _postgraduate_phase_duration_seconds,
		"interaction_count": _postgraduate_interaction_count,
		"assembly_steps_en": _postgraduate_assembly_steps(false),
		"assembly_steps_zh": _postgraduate_assembly_steps(true),
		"cycle": _postgraduate_cycle,
		"relationship_stage": _postgraduate_relationship_stage(),
		"relationship": _postgraduate_relationship.duplicate(true),
	}


func react_to_interaction(interaction_id: String, phase: String = "open") -> void:
	if _room_blocked:
		return
	var count := int(_interaction_counts.get(interaction_id, 0))
	var state := ""
	if phase == "close":
		state = "close_mission" if interaction_id == "mission" else ""
	else:
		match interaction_id:
			"mission":
				state = "repeat_mission" if count > 0 else "open_mission"
			"cabinet":
				state = _cabinet_interaction_state(count)
			"assembly":
				state = "arrive_assembly"
			"telescope", "door":
				state = "operate_telescope"
			"journal":
				state = "open_journal"
			"computer":
				state = "remote_plan"
	if phase == "open":
		_interaction_counts[interaction_id] = count + 1
	if state != "":
		if _player_position_provider.is_valid():
			_face_toward(_player_position_provider.call())
		_show_state(state, true)


func current_state_id() -> String:
	return _state_id


func current_destination_id() -> String:
	return _destination_id


func current_facing() -> String:
	return _facing if _facing != "" else "down"


func is_following_route() -> bool:
	return _route_is_guided


func _cabinet_interaction_state(open_count: int) -> String:
	if open_count <= 0:
		return "inspect_cabinet"
	var manager := get_node_or_null("/root/GameManager")
	if manager != null and manager.has_method("missing_required_parts"):
		var missing: Variant = manager.call("missing_required_parts")
		if missing is Array and not missing.is_empty():
			return "cabinet_missing"
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	if progress_value is Dictionary and int(progress_value.get("current_level", 1)) >= 33:
		return "cabinet_advanced"
	return "inspect_cabinet"


func is_behind_furniture(rect: Rect2, front_y: float) -> bool:
	var visual_rect := Rect2(
		position - Vector2(18.0 * DISPLAY_SCALE, 48.0 * DISPLAY_SCALE),
		Vector2(36.0 * DISPLAY_SCALE, 50.0 * DISPLAY_SCALE)
	)
	return position.y <= front_y and visual_rect.intersects(rect)


func is_in_front_of_furniture(rect: Rect2, front_y: float) -> bool:
	var visual_rect := Rect2(
		position - Vector2(18.0 * DISPLAY_SCALE, 48.0 * DISPLAY_SCALE),
		Vector2(36.0 * DISPLAY_SCALE, 50.0 * DISPLAY_SCALE)
	)
	return position.y > front_y and visual_rect.intersects(rect)


func set_furniture_front_layer(active: bool) -> void:
	_maya_in_front_of_furniture = active


func _load_data() -> void:
	var atlas_data := _read_json(ATLAS_METADATA_PATH)
	_animations = atlas_data.get("animations", {})
	var dialogue_data := _read_json(DIALOGUE_PATH)
	_dialogue_states = dialogue_data.get("states", {})
	_ambient_lines = dialogue_data.get("ambient_lines", {})
	_postgraduate_routines = dialogue_data.get("postgraduate", {})
	_room_text = dialogue_data.get("room_text", {})


func editable_text(key: String, replacements: Dictionary = {}) -> String:
	var value: Variant = _room_text.get(key, {})
	var localized: Dictionary = value if value is Dictionary else {}
	var manager := get_node_or_null("/root/GameManager")
	var locale := "zh" if manager != null and str(manager.get("language_mode")) == "zh" else "en"
	var result := str(localized.get(locale, key))
	for replacement_key in replacements:
		result = result.replace("{%s}" % str(replacement_key), str(replacements[replacement_key]))
	return result


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _build_visuals() -> void:
	_shadow = Polygon2D.new()
	_shadow.name = "MayaShadow"
	_shadow.polygon = PackedVector2Array([
		Vector2(-15, -3), Vector2(-10, -6), Vector2(10, -6),
		Vector2(15, -3), Vector2(10, 0), Vector2(-10, 0),
	])
	_shadow.color = Color(0.0, 0.0, 0.0, 0.30)
	add_child(_shadow)

	_sprite = Sprite2D.new()
	_sprite.name = "MayaSprite"
	_sprite.centered = false
	_sprite.position = Vector2(-CELL_SIZE.x * DISPLAY_SCALE * 0.5, -FOOT_ANCHOR_Y * DISPLAY_SCALE)
	_sprite.scale = Vector2.ONE * DISPLAY_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_atlas = AtlasTexture.new()
	_sprite_atlas.atlas = ATLAS_TEXTURE
	_sprite.texture = _sprite_atlas
	add_child(_sprite)

	_bubble_badge = Panel.new()
	_bubble_badge.name = "MayaThoughtBadge"
	_bubble_badge.position = Vector2(-17, -110)
	_bubble_badge.size = Vector2(34, 28)
	_bubble_badge.z_as_relative = false
	_bubble_badge.z_index = 70
	_bubble_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_badge.add_theme_stylebox_override("panel", _bubble_style(Color(0.52, 0.86, 1.0), 0.96, 8))
	add_child(_bubble_badge)
	_badge_icon = Label.new()
	_badge_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge_icon.add_theme_font_size_override("font_size", 13)
	_badge_icon.add_theme_color_override("font_color", Color(0.95, 0.91, 0.76))
	_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_badge.add_child(_badge_icon)

	_bubble = Panel.new()
	_bubble.name = "MayaThoughtBubble"
	# Hall bubbles are quick emotional beats, not miniature mission panels.
	_bubble.position = Vector2(-87, -126)
	_bubble.size = Vector2(174, 44)
	_bubble.z_as_relative = false
	_bubble.z_index = 70
	_bubble.clip_contents = true
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_theme_stylebox_override("panel", _bubble_style(Color(0.52, 0.86, 1.0), 0.97, 8))
	add_child(_bubble)

	_bubble_icon = Label.new()
	_bubble_icon.position = Vector2(8, 4)
	_bubble_icon.size = Vector2(28, 36)
	_bubble_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_icon.add_theme_font_size_override("font_size", 15)
	_bubble_icon.add_theme_color_override("font_color", Color(1.0, 0.78, 0.30))
	_bubble_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_bubble_icon)

	_bubble_status = Label.new()
	_bubble_status.position = Vector2.ZERO
	_bubble_status.size = Vector2.ZERO
	_bubble_status.visible = false
	_bubble_status.add_theme_font_size_override("font_size", 11)
	_bubble_status.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0))
	_bubble_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bubble_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_bubble_status)

	_bubble_line = Label.new()
	_bubble_line.position = Vector2(40, 4)
	_bubble_line.size = Vector2(126, 36)
	_bubble_line.add_theme_font_size_override("font_size", 13)
	_bubble_line.add_theme_color_override("font_color", Color(0.96, 0.93, 0.84))
	_bubble_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bubble_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_bubble_line)


func _bubble_style(border: Color, alpha: float, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.080, alpha)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	return style


func _build_pathfinder() -> void:
	_pathfinder.region = Rect2i(0, 0, 64, 48)
	_pathfinder.cell_size = Vector2(PATH_CELL_SIZE, PATH_CELL_SIZE)
	# Diagonal cell paths made Maya alternate left/right every few pixels. The
	# hall is laid out as corridors, so rectilinear movement reads as deliberate
	# walking: finish one direction, turn once, then continue.
	_pathfinder.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_pathfinder.update()
	for y in range(_pathfinder.region.position.y, _pathfinder.region.end.y):
		for x in range(_pathfinder.region.position.x, _pathfinder.region.end.x):
			var point := Vector2(x * PATH_CELL_SIZE + PATH_CELL_SIZE * 0.5, y * PATH_CELL_SIZE + PATH_CELL_SIZE * 0.5)
			if not bool(_walkable_provider.call(point)):
				_pathfinder.set_point_solid(Vector2i(x, y), true)


func _begin_first_route() -> void:
	# Let the entrance greeting read as an actual acknowledgement instead of
	# replacing it with route copy on the very next frame.
	await get_tree().create_timer(1.5).timeout
	_route_enabled = true
	if not _observation_hall_roam_stations.is_empty():
		return
	_update_route_target(true)


func _update_route_target(force: bool = false) -> void:
	if not _route_target_provider.is_valid():
		return
	if not _observation_hall_roam_stations.is_empty():
		return
	# Graduation ends Maya's tutorial job. The player's postgraduate equipment
	# HUD may still point at a bench, but it must not commandeer Maya's own night
	# shift or turn her back into a route marker.
	var guided_target_id := "" if _is_postgraduate_free_roam() else str(_route_target_provider.call())
	var target_id := guided_target_id
	if target_id == "":
		if _is_postgraduate_free_roam():
			_ensure_postgraduate_work_plan()
			target_id = _postgraduate_destination()
		# Free-roaming destinations persist until their dwell timer expires. The
		# old code rolled a different random destination every frame, making Maya
		# reverse direction continuously and repeatedly restart arrival events.
		elif not force and not _route_is_guided and _destination_id != "":
			return
		else:
			target_id = _idle_destination_id()
	var guided := guided_target_id != ""
	if not force and target_id == _destination_id and guided == _route_is_guided:
		return
	_destination_id = target_id
	_route_is_guided = guided
	_arrived = false
	_route_started_at_msec = Time.get_ticks_msec()
	_route_arrived_at_msec = 0
	# The route introduction gets a full read before any contextual nudge can
	# replace it. Later reactions use the same cooldown and are one-shot.
	_last_reaction_at_msec = _route_started_at_msec
	_reaction_seen.clear()
	var destination: Vector2 = _destination_provider.call(_destination_id)
	var player_position: Vector2 = _player_position_provider.call()
	_player_best_destination_distance = player_position.distance_to(destination)
	_path = _make_path(position, destination)
	_path_index = 0
	if _path.size() > 0 and _route_is_guided:
		_show_state(_route_state("guide", _destination_id, "guide"), true)


func _idle_destination_id() -> String:
	if _free_activity_deck.is_empty():
		_refill_free_activity_deck()
	return _free_activity_deck.pop_front() if not _free_activity_deck.is_empty() else "telescope"


func _refill_free_activity_deck() -> void:
	_free_activity_deck.assign(["assembly", "telescope", "computer", "journal", "cabinet"])
	# Fisher-Yates with the NPC's RNG keeps the cycle varied while guaranteeing
	# that every workstation, especially the assembly bench, is visited once.
	for index in range(_free_activity_deck.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var held := _free_activity_deck[index]
		_free_activity_deck[index] = _free_activity_deck[swap_index]
		_free_activity_deck[swap_index] = held
	if _free_activity_deck.size() > 1 and _free_activity_deck[0] == _destination_id:
		var first := _free_activity_deck[0]
		_free_activity_deck[0] = _free_activity_deck[1]
		_free_activity_deck[1] = first


func _ensure_postgraduate_work_plan() -> void:
	if _postgraduate_phase != "":
		return
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	var progress_value: Variant = manager.get("progress")
	if not progress_value is Dictionary:
		return
	var progress: Dictionary = progress_value
	var saved_value: Variant = progress.get("maya_postgraduate_work", {})
	var saved: Dictionary = saved_value if saved_value is Dictionary else {}
	var saved_phase := str(saved.get("phase", ""))
	var phase_order: Array = _postgraduate_routines.get("phase_order", [])
	if saved_phase in phase_order:
		var saved_target := str(saved.get("target_id", ""))
		var saved_instrument := str(saved.get("instrument_id", ""))
		var saved_night := str(saved.get("night_id", ""))
		var saved_event := str(saved.get("event_id", "none"))
		if not manager.call("get_object", saved_target).is_empty() and saved_instrument != "":
			var timing_migrated := int(saved.get("timing_version", 1)) < POSTGRADUATE_TIMING_VERSION
			_postgraduate_phase = saved_phase
			_postgraduate_target_id = saved_target
			_postgraduate_instrument_id = saved_instrument
			_postgraduate_night_id = saved_night if saved_night != "" else "clear_stable"
			_postgraduate_event_id = saved_event if saved_event != "" else "none"
			_postgraduate_cycle = int(saved.get("cycle", 0))
			_postgraduate_assembly_progress = int(saved.get("assembly_progress", 0))
			_postgraduate_phase_started_unix = int(saved.get("phase_started_unix", 0))
			_postgraduate_phase_duration_seconds = float(saved.get("phase_duration_seconds", 0.0))
			if timing_migrated and _postgraduate_phase_duration_seconds > 0.0:
				_postgraduate_phase_duration_seconds *= POSTGRADUATE_TIME_SCALE
			_postgraduate_interaction_phase = str(saved.get("interaction_phase", ""))
			_postgraduate_interaction_count = int(saved.get("interaction_count", 0))
			if _postgraduate_phase_started_unix <= 0 or _postgraduate_phase_duration_seconds <= 0.0:
				_reset_postgraduate_phase_clock()
				_save_postgraduate_work_plan()
			_catch_up_postgraduate_work()
			if timing_migrated:
				_save_postgraduate_work_plan()
			return
	_start_new_postgraduate_project()


func _start_new_postgraduate_project(started_unix: int = -1) -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	var previous_target := _postgraduate_target_id
	var candidates: Array[String] = []
	var target_values: Array = _postgraduate_routines.get("targets", [])
	for value in target_values:
		var target_id := str(value)
		if target_id != previous_target and not manager.call("get_object", target_id).is_empty():
			candidates.append(target_id)
	if candidates.is_empty() and previous_target != "":
		candidates.append(previous_target)
	_postgraduate_target_id = candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else "moon"
	var instruments: Array = _postgraduate_routines.get("instruments", [])
	if not instruments.is_empty():
		var instrument: Dictionary = instruments[_rng.randi_range(0, instruments.size() - 1)]
		_postgraduate_instrument_id = str(instrument.get("id", "refractor_80"))
	else:
		_postgraduate_instrument_id = "refractor_80"
	var previous_night := _postgraduate_night_id
	var night_profiles_value: Variant = _postgraduate_routines.get("night_profiles", [])
	var night_candidates: Array[String] = []
	if night_profiles_value is Array:
		for value in night_profiles_value:
			if value is Dictionary:
				var night_id := str((value as Dictionary).get("id", ""))
				if night_id != "" and night_id != previous_night:
					night_candidates.append(night_id)
	_postgraduate_night_id = night_candidates[_rng.randi_range(0, night_candidates.size() - 1)] \
		if not night_candidates.is_empty() else (previous_night if previous_night != "" else "clear_stable")
	_postgraduate_event_id = _choose_postgraduate_night_event(_postgraduate_event_id)
	_postgraduate_cycle += 1
	_postgraduate_assembly_progress = 0
	var phase_order: Array = _postgraduate_routines.get("phase_order", [])
	_postgraduate_phase = str(phase_order[0]) if not phase_order.is_empty() else "assembling"
	_reset_postgraduate_phase_clock(started_unix)
	_save_postgraduate_work_plan()


func _advance_postgraduate_work(started_unix: int = -1) -> void:
	_ensure_postgraduate_work_plan()
	var phase_order: Array = _postgraduate_routines.get("phase_order", [])
	var current_index := phase_order.find(_postgraduate_phase)
	if _postgraduate_phase == "assembling":
		_postgraduate_assembly_progress = _postgraduate_assembly_steps(false).size()
	if current_index < 0 or current_index + 1 >= phase_order.size():
		_start_new_postgraduate_project(started_unix)
	else:
		_postgraduate_phase = str(phase_order[current_index + 1])
		_reset_postgraduate_phase_clock(started_unix)
		_save_postgraduate_work_plan()


func _save_postgraduate_work_plan() -> void:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	var progress_value: Variant = manager.get("progress")
	if not progress_value is Dictionary:
		return
	var progress: Dictionary = progress_value
	progress["maya_postgraduate_work"] = {
		"phase": _postgraduate_phase,
		"target_id": _postgraduate_target_id,
		"instrument_id": _postgraduate_instrument_id,
		"night_id": _postgraduate_night_id,
		"event_id": _postgraduate_event_id,
		"assembly_progress": _postgraduate_assembly_progress,
		"cycle": _postgraduate_cycle,
		"phase_started_unix": _postgraduate_phase_started_unix,
		"phase_duration_seconds": _postgraduate_phase_duration_seconds,
		"interaction_phase": _postgraduate_interaction_phase,
		"interaction_count": _postgraduate_interaction_count,
		"timing_version": POSTGRADUATE_TIMING_VERSION,
	}
	if manager.has_method("save"):
		manager.call_deferred("save")


func _ensure_postgraduate_relationship() -> void:
	if _postgraduate_relationship.is_empty():
		var manager := get_node_or_null("/root/GameManager")
		if manager == null:
			return
		var progress_value: Variant = manager.get("progress")
		if not progress_value is Dictionary:
			return
		var saved_value: Variant = (progress_value as Dictionary).get("maya_postgraduate_relationship", {})
		_postgraduate_relationship = saved_value.duplicate(true) if saved_value is Dictionary else {}
	for key in ["conversations", "assembly_assists", "observations_joined", "observations_completed", "rest_conversations", "tea_breaks_shared", "workbench_walkaways"]:
		if not _postgraduate_relationship.has(key):
			_postgraduate_relationship[key] = 0
	if not _postgraduate_relationship.get("known_private_memories", []) is Array:
		_postgraduate_relationship["known_private_memories"] = []
	elif not _postgraduate_relationship.has("known_private_memories"):
		_postgraduate_relationship["known_private_memories"] = []


func _remember_postgraduate_event(event_id: String) -> void:
	_ensure_postgraduate_relationship()
	_postgraduate_relationship[event_id] = int(_postgraduate_relationship.get(event_id, 0)) + 1
	_postgraduate_relationship["last_target_id"] = _postgraduate_target_id
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return
	var progress_value: Variant = manager.get("progress")
	if not progress_value is Dictionary:
		return
	(progress_value as Dictionary)["maya_postgraduate_relationship"] = _postgraduate_relationship.duplicate(true)
	if manager.has_method("save"):
		manager.call_deferred("save")


func _postgraduate_relationship_stage() -> String:
	_ensure_postgraduate_relationship()
	var assists := int(_postgraduate_relationship.get("assembly_assists", 0))
	var joined := int(_postgraduate_relationship.get("observations_joined", 0))
	var completed := int(_postgraduate_relationship.get("observations_completed", 0))
	if assists >= 6 and completed >= 3:
		return "trusted"
	if assists >= 2 or joined >= 1 or int(_postgraduate_relationship.get("conversations", 0)) >= 3 \
		or int(_postgraduate_relationship.get("rest_conversations", 0)) >= 2:
		return "familiar"
	return "colleague"


func _postgraduate_is_familiar() -> bool:
	return _postgraduate_relationship_stage() != "colleague"


func _postgraduate_stage_rank(stage: String) -> int:
	return {"colleague": 0, "familiar": 1, "trusted": 2}.get(stage, 0)


func _private_memory_data(memory_id: String) -> Dictionary:
	var memories_value: Variant = _postgraduate_routines.get("private_memories", [])
	if memories_value is Array:
		for value in memories_value:
			if value is Dictionary and str((value as Dictionary).get("id", "")) == memory_id:
				return value as Dictionary
	return {}


func _private_memory_requirements_met(memory: Dictionary) -> bool:
	var required_stage := str(memory.get("required_stage", "colleague"))
	if _postgraduate_stage_rank(_postgraduate_relationship_stage()) < _postgraduate_stage_rank(required_stage):
		return false
	var requirements_value: Variant = memory.get("requirements", {})
	if requirements_value is Dictionary:
		for key_value in (requirements_value as Dictionary).keys():
			var key := str(key_value)
			if int(_postgraduate_relationship.get(key, 0)) < int((requirements_value as Dictionary)[key_value]):
				return false
	return true


func _eligible_unseen_private_memory() -> Dictionary:
	_ensure_postgraduate_relationship()
	var known_value: Variant = _postgraduate_relationship.get("known_private_memories", [])
	var known: Array = known_value if known_value is Array else []
	var memories_value: Variant = _postgraduate_routines.get("private_memories", [])
	if memories_value is Array:
		for value in memories_value:
			if not value is Dictionary:
				continue
			var memory := value as Dictionary
			var memory_id := str(memory.get("id", ""))
			if memory_id != "" and not known.has(memory_id) and _private_memory_requirements_met(memory):
				return memory
	return {}


func _remember_private_memory(memory_id: String) -> void:
	if memory_id == "":
		return
	_ensure_postgraduate_relationship()
	var known_value: Variant = _postgraduate_relationship.get("known_private_memories", [])
	var known: Array = known_value.duplicate() if known_value is Array else []
	if not known.has(memory_id):
		known.append(memory_id)
	_postgraduate_relationship["known_private_memories"] = known
	_postgraduate_relationship["last_private_memory"] = memory_id
	var manager := get_node_or_null("/root/GameManager")
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	if progress_value is Dictionary:
		(progress_value as Dictionary)["maya_postgraduate_relationship"] = _postgraduate_relationship.duplicate(true)
		if manager.has_method("save"):
			manager.call_deferred("save")


func _postgraduate_known_memory_lines(chinese: bool) -> Array:
	_ensure_postgraduate_relationship()
	var known_value: Variant = _postgraduate_relationship.get("known_private_memories", [])
	var known: Array = known_value if known_value is Array else []
	var locale := "zh" if chinese else "en"
	var key := "%s_lines_%s" % [_postgraduate_phase, locale]
	var lines: Array = []
	for memory_id_value in known:
		var memory := _private_memory_data(str(memory_id_value))
		var echoes_value: Variant = memory.get("echoes", {})
		if echoes_value is Dictionary:
			var phase_lines_value: Variant = (echoes_value as Dictionary).get(key, [])
			if phase_lines_value is Array:
				lines.append_array(phase_lines_value)
	return lines


func _postgraduate_phase_data() -> Dictionary:
	var phases_value: Variant = _postgraduate_routines.get("phases", {})
	var phases: Dictionary = phases_value if phases_value is Dictionary else {}
	var phase_value: Variant = phases.get(_postgraduate_phase, {})
	return phase_value if phase_value is Dictionary else {}


func _postgraduate_night_profile() -> Dictionary:
	var profiles_value: Variant = _postgraduate_routines.get("night_profiles", [])
	if profiles_value is Array:
		for value in profiles_value:
			if value is Dictionary and str((value as Dictionary).get("id", "")) == _postgraduate_night_id:
				return value
	return {}


func _postgraduate_night_name(chinese: bool) -> String:
	var profile := _postgraduate_night_profile()
	return str(profile.get("name_zh" if chinese else "name_en", _postgraduate_night_id))


func _choose_postgraduate_night_event(previous_event_id: String) -> String:
	var events_value: Variant = _postgraduate_routines.get("night_events", [])
	var weighted_pool: Array[String] = []
	if events_value is Array:
		for value in events_value:
			if not value is Dictionary:
				continue
			var event := value as Dictionary
			var event_id := str(event.get("id", "none"))
			if event_id != "none" and event_id == previous_event_id:
				continue
			var eligible_value: Variant = event.get("eligible_night_ids", [])
			if eligible_value is Array and not eligible_value.is_empty() and not eligible_value.has(_postgraduate_night_id):
				continue
			for _weight in range(maxi(1, int(event.get("weight", 1)))):
				weighted_pool.append(event_id)
	return weighted_pool[_rng.randi_range(0, weighted_pool.size() - 1)] \
		if not weighted_pool.is_empty() else "none"


func _postgraduate_event_data() -> Dictionary:
	var events_value: Variant = _postgraduate_routines.get("night_events", [])
	if events_value is Array:
		for value in events_value:
			if value is Dictionary and str((value as Dictionary).get("id", "")) == _postgraduate_event_id:
				return value
	return {}


func _postgraduate_event_name(chinese: bool) -> String:
	var event := _postgraduate_event_data()
	return str(event.get("name_zh" if chinese else "name_en", ""))


func _postgraduate_event_is_active() -> bool:
	var active_value: Variant = _postgraduate_event_data().get("active_phases", [])
	return active_value is Array and active_value.has(_postgraduate_phase)


func _postgraduate_assembly_steps(chinese: bool) -> Array:
	var phase := _postgraduate_phase_data()
	var key := "steps_zh" if chinese else "steps_en"
	var steps_value: Variant = phase.get(key, [])
	var steps: Array = steps_value.duplicate() if steps_value is Array else []
	var event := _postgraduate_event_data()
	var extra := str(event.get("extra_assembly_step_zh" if chinese else "extra_assembly_step_en", ""))
	if extra != "":
		steps.append(extra)
	return steps


func _postgraduate_target_lines(chinese: bool) -> Array:
	if not (_postgraduate_phase in ["observing", "recording", "reviewing"]):
		return []
	var target_lines_value: Variant = _postgraduate_routines.get("target_lines", {})
	if not target_lines_value is Dictionary:
		return []
	var target_copy_value: Variant = (target_lines_value as Dictionary).get(_postgraduate_target_id, {})
	if not target_copy_value is Dictionary:
		return []
	var lines_value: Variant = (target_copy_value as Dictionary).get("lines_zh" if chinese else "lines_en", [])
	return lines_value.duplicate() if lines_value is Array else []


func _postgraduate_active_event_lines(chinese: bool) -> Array:
	if not _postgraduate_event_is_active():
		return []
	var lines_value: Variant = _postgraduate_event_data().get("lines_zh" if chinese else "lines_en", [])
	return lines_value.duplicate() if lines_value is Array else []


func _postgraduate_time_band() -> String:
	var local_time := Time.get_datetime_dict_from_system(false)
	var hour := int(local_time.get("hour", 21))
	if hour >= 22 or hour < 2:
		return "midnight"
	if hour >= 2 and hour < 6:
		return "predawn"
	return "evening"


func _postgraduate_destination() -> String:
	return str(_postgraduate_phase_data().get("destination", "telescope"))


func _observation_hall_roam_stations_for_phase() -> Array[String]:
	# When the player is inside a telescope screen, Maya remains a physical person
	# in the hall. These are short errand loops around her actual work, not a new
	# task: she returns to the station that owns the active phase afterwards.
	var primary := _postgraduate_destination()
	var by_phase := {
		"assembling": ["cabinet", "assembly", "computer", "assembly"],
		"observing": ["computer", "journal", "telescope"],
		"recording": ["computer", "journal", "telescope", "journal"],
		"reviewing": ["computer", "cabinet", "journal"],
		"resting": ["cabinet", "computer", "journal"],
	}
	var raw: Array = by_phase.get(_postgraduate_phase, ["computer", primary])
	var stations: Array[String] = []
	for value in raw:
		var station := str(value)
		if station != "" and (stations.is_empty() or stations.back() != station):
			stations.append(station)
	if stations.is_empty() or stations.back() != primary:
		stations.append(primary)
	return stations


func _resume_observation_hall_roam() -> void:
	if not _is_postgraduate_free_roam():
		return
	var manager := get_node_or_null("/root/GameManager")
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	if not progress_value is Dictionary:
		return
	var progress: Dictionary = progress_value
	var saved_value: Variant = progress.get("maya_observation_hall_roam", {})
	if not saved_value is Dictionary:
		return
	progress.erase("maya_observation_hall_roam")
	var saved: Dictionary = saved_value
	var stations_value: Variant = saved.get("stations", [])
	var stations: Array[String] = []
	if stations_value is Array:
		for value in stations_value:
			var station := str(value)
			if station != "":
				stations.append(station)
	if stations.is_empty():
		return
	var leg_seconds := maxf(1.0, float(saved.get("leg_seconds", OBSERVATION_HALL_ROAM_LEG_SECONDS)))
	var elapsed := maxf(0.0, float(_postgraduate_now_unix() - int(saved.get("started_unix", _postgraduate_now_unix()))))
	var completed := mini(stations.size(), floori(elapsed / leg_seconds))
	# The hall scene was unloaded while the player observed. Resume at the last
	# station Maya could plausibly have reached, then animate the remaining legs.
	if completed > 0:
		var settled_station := stations[completed - 1]
		var settled_position: Vector2 = _destination_provider.call(settled_station)
		if bool(_walkable_provider.call(settled_position)):
			position = settled_position
			_set_facing(_facing_from_vector(_station_focus(settled_station) - position))
	for index in range(completed, stations.size()):
		_observation_hall_roam_stations.append(stations[index])
	_observation_hall_roam_index = 0
	_observation_hall_roam_dwell_elapsed = 0.0
	if manager != null and manager.has_method("save"):
		manager.call_deferred("save")
	if not _observation_hall_roam_stations.is_empty():
		_begin_observation_hall_roam_leg()


func _begin_observation_hall_roam_leg() -> void:
	if _observation_hall_roam_index >= _observation_hall_roam_stations.size():
		_observation_hall_roam_stations.clear()
		_update_route_target(true)
		return
	_destination_id = _observation_hall_roam_stations[_observation_hall_roam_index]
	_route_is_guided = false
	_arrived = false
	_route_started_at_msec = Time.get_ticks_msec()
	_route_arrived_at_msec = 0
	_path = _make_path(position, _destination_provider.call(_destination_id))
	_path_index = 0


func _update_observation_hall_roam(delta: float) -> void:
	if _observation_hall_roam_stations.is_empty() or _moving or not _arrived:
		return
	_observation_hall_roam_dwell_elapsed += delta
	if _observation_hall_roam_dwell_elapsed < OBSERVATION_HALL_ROAM_DWELL_SECONDS:
		return
	_observation_hall_roam_dwell_elapsed = 0.0
	_observation_hall_roam_index += 1
	_begin_observation_hall_roam_leg()


func _postgraduate_state_id() -> String:
	return "postgraduate_%s" % _postgraduate_phase


func _postgraduate_phase_duration() -> float:
	var phase := _postgraduate_phase_data()
	return POSTGRADUATE_TIME_SCALE * _rng.randf_range(
		float(phase.get("duration_min", FREE_ACTIVITY_MIN_SECONDS)),
		float(phase.get("duration_max", FREE_ACTIVITY_MAX_SECONDS))
	)


func _postgraduate_now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func _reset_postgraduate_phase_clock(started_unix: int = -1) -> void:
	_postgraduate_phase_started_unix = started_unix if started_unix >= 0 else _postgraduate_now_unix()
	_postgraduate_phase_duration_seconds = maxf(1.0, _postgraduate_phase_duration())
	_postgraduate_interaction_phase = "%d:%s" % [_postgraduate_cycle, _postgraduate_phase]
	_postgraduate_interaction_count = 0
	_sync_postgraduate_activity_timer()


func _sync_postgraduate_activity_timer() -> void:
	_free_activity_delay = maxf(1.0, _postgraduate_phase_duration_seconds)
	_free_activity_elapsed = clampf(
		float(_postgraduate_now_unix() - _postgraduate_phase_started_unix),
		0.0,
		_free_activity_delay
	)


func _catch_up_postgraduate_work() -> void:
	var now := _postgraduate_now_unix()
	var transitions := 0
	while transitions < 20 and _postgraduate_phase_started_unix > 0 \
			and _postgraduate_phase_duration_seconds > 0.0:
		var phase_end := _postgraduate_phase_started_unix + int(ceil(_postgraduate_phase_duration_seconds))
		if phase_end > now:
			break
		_advance_postgraduate_work(phase_end)
		transitions += 1
	_sync_postgraduate_activity_timer()


func _register_postgraduate_interaction() -> void:
	var phase_key := "%d:%s" % [_postgraduate_cycle, _postgraduate_phase]
	if _postgraduate_interaction_phase != phase_key:
		_postgraduate_interaction_phase = phase_key
		_postgraduate_interaction_count = 0
	_postgraduate_interaction_count += 1
	_save_postgraduate_work_plan()


func _show_postgraduate_override(copy: Dictionary) -> void:
	if copy.is_empty():
		return
	_postgraduate_override_copy = copy.duplicate(true)
	_show_state(_postgraduate_state_id(), true)


func _postgraduate_reaction_copy(lines: Array, chinese: bool, icon: String) -> Dictionary:
	var candidates: Array[String] = []
	for value in lines:
		var line := _format_postgraduate_copy(str(value), chinese)
		if line != "" and not _recent_postgraduate_lines.has(line):
			candidates.append(line)
	if candidates.is_empty():
		for value in lines:
			var line := _format_postgraduate_copy(str(value), chinese)
			if line != "":
				candidates.append(line)
	if candidates.is_empty():
		return {}
	var line := candidates[_rng.randi_range(0, candidates.size() - 1)]
	_recent_postgraduate_lines.append(line)
	while _recent_postgraduate_lines.size() > 4:
		_recent_postgraduate_lines.pop_front()
	var phase := _postgraduate_phase_data()
	var status_key := "status_zh" if chinese else "status_en"
	return {
		"status": _format_postgraduate_copy(str(phase.get(status_key, "")), chinese),
		"line": line,
		"icon": icon,
	}


func _postgraduate_can_notice_player() -> bool:
	return _is_postgraduate_free_roam() \
		and _postgraduate_phase == "resting" \
		and _arrived \
		and not _moving


func _show_postgraduate_rest_proximity(state_id: String) -> void:
	var manager := get_node_or_null("/root/GameManager")
	var chinese := manager != null and str(manager.get("language_mode")) == "zh"
	var line := _ambient_bubble_copy(state_id, chinese)
	if line == "":
		return
	var phase := _postgraduate_phase_data()
	var status_key := "status_zh" if chinese else "status_en"
	_show_postgraduate_override({
		"status": _format_postgraduate_copy(str(phase.get(status_key, "")), chinese),
		"line": line,
		"icon": "",
	})


func _postgraduate_return_reaction() -> Dictionary:
	var manager := get_node_or_null("/root/GameManager")
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	if not progress_value is Dictionary:
		return {}
	var presence_value: Variant = (progress_value as Dictionary).get("maya_postgraduate_presence", {})
	if not presence_value is Dictionary or presence_value.is_empty():
		return {}
	var presence: Dictionary = presence_value
	var advanced := int(presence.get("cycle", -1)) != _postgraduate_cycle \
		or str(presence.get("phase", "")) != _postgraduate_phase
	var return_value: Variant = _postgraduate_routines.get("return_reactions", {})
	if not return_value is Dictionary:
		return {}
	var return_data: Dictionary = return_value
	var phase_value: Variant = return_data.get(_postgraduate_phase, {})
	if not phase_value is Dictionary:
		return {}
	var manager_language := str(manager.get("language_mode")) if manager != null else "en"
	var chinese := manager_language == "zh"
	var locale := "zh" if chinese else "en"
	var phase_reactions: Dictionary = phase_value
	var key := "%s_lines_%s" % ["advanced" if advanced else "same", locale]
	var lines_value: Variant = phase_reactions.get(key, [])
	var lines: Array = lines_value.duplicate() if lines_value is Array else []
	# When work advanced during the player's absence, always name that change.
	# Relationship-flavoured greetings are useful only when Maya is still on the
	# same task; they must not hide the evidence that she kept living off-screen.
	if not advanced:
		var stage := _postgraduate_relationship_stage()
		if stage in ["familiar", "trusted"]:
			var familiar_value: Variant = return_data.get("familiar_lines_%s" % locale, [])
			if familiar_value is Array:
				lines.append_array(familiar_value)
		if stage == "trusted":
			var trusted_value: Variant = return_data.get("trusted_lines_%s" % locale, [])
			if trusted_value is Array:
				lines.append_array(trusted_value)
	var copy := _postgraduate_reaction_copy(lines, chinese, "↺")
	copy["advanced"] = advanced
	return copy


func _postgraduate_interruption_reaction() -> Dictionary:
	if _postgraduate_interaction_count < 2:
		return {}
	var interruptions_value: Variant = _postgraduate_routines.get("interruptions", {})
	if not interruptions_value is Dictionary:
		return {}
	var phase_value: Variant = (interruptions_value as Dictionary).get(_postgraduate_phase, {})
	if not phase_value is Dictionary:
		return {}
	var manager := get_node_or_null("/root/GameManager")
	var chinese := manager != null and str(manager.get("language_mode")) == "zh"
	var locale := "zh" if chinese else "en"
	var response_key := "second_lines_%s" % locale if _postgraduate_interaction_count == 2 \
		else "repeated_lines_%s" % locale
	var lines_value: Variant = (phase_value as Dictionary).get(response_key, [])
	var lines: Array = lines_value if lines_value is Array else []
	return _postgraduate_reaction_copy(lines, chinese, "·")


func _postgraduate_workbench_walkaway_reaction(touched: bool) -> Dictionary:
	var reaction_value: Variant = _postgraduate_routines.get("workbench_walkaway", {})
	if not reaction_value is Dictionary:
		return {}
	var reaction: Dictionary = reaction_value
	var manager := get_node_or_null("/root/GameManager")
	var chinese := manager != null and str(manager.get("language_mode")) == "zh"
	var locale := "zh" if chinese else "en"
	var lines_value: Variant = reaction.get(
		("partial_lines_%s" if touched else "untouched_lines_%s") % locale,
		[]
	)
	var lines: Array = lines_value.duplicate() if lines_value is Array else []
	if _postgraduate_relationship_stage() == "trusted":
		var trusted_value: Variant = reaction.get("trusted_lines_%s" % locale, [])
		if trusted_value is Array:
			lines.append_array(trusted_value)
	return _postgraduate_reaction_copy(lines, chinese, "+")


func _postgraduate_instrument_name(chinese: bool) -> String:
	var instruments: Array = _postgraduate_routines.get("instruments", [])
	for value in instruments:
		var instrument: Dictionary = value
		if str(instrument.get("id", "")) == _postgraduate_instrument_id:
			return str(instrument.get("name_zh" if chinese else "name_en", _postgraduate_instrument_id))
	return _postgraduate_instrument_id


func _postgraduate_target_name(chinese: bool) -> String:
	var manager := get_node_or_null("/root/GameManager")
	if manager == null:
		return _postgraduate_target_id
	var target: Dictionary = manager.call("get_object", _postgraduate_target_id)
	return str(target.get("name_zh" if chinese else "name_en", _postgraduate_target_id))


func _format_postgraduate_copy(value: String, chinese: bool) -> String:
	return value.replace("{target}", _postgraduate_target_name(chinese)).replace(
		"{instrument}", _postgraduate_instrument_name(chinese)
	).replace("{night}", _postgraduate_night_name(chinese))


func _copy_array_has_text(value: Variant) -> bool:
	if not value is Array:
		return false
	for line_value in value:
		if not str(line_value).strip_edges().is_empty():
			return true
	return false


func _postgraduate_copy(chinese: bool) -> Dictionary:
	var phase := _postgraduate_phase_data()
	var status_key := "status_zh" if chinese else "status_en"
	var lines_key := "lines_zh" if chinese else "lines_en"
	var status := _format_postgraduate_copy(str(phase.get(status_key, "")), chinese)
	var raw_lines_value: Variant = phase.get(lines_key, [])
	# An empty or deleted localized phase array is an explicit authoring choice:
	# this phase has no spoken line in that language. Do not refill it with night,
	# target, event, memory, or English fallback copy.
	var localized_phase_has_lines := _copy_array_has_text(raw_lines_value)
	var raw_lines: Array = raw_lines_value.duplicate() \
		if raw_lines_value is Array and localized_phase_has_lines else []
	var night_profile := _postgraduate_night_profile()
	var night_lines_value: Variant = night_profile.get(lines_key, [])
	if localized_phase_has_lines and night_lines_value is Array:
		raw_lines.append_array(night_lines_value)
	var time_lines_value: Variant = _postgraduate_routines.get("time_lines", {})
	if localized_phase_has_lines and time_lines_value is Dictionary:
		var band_value: Variant = (time_lines_value as Dictionary).get(_postgraduate_time_band(), {})
		if band_value is Dictionary:
			var band_lines_value: Variant = (band_value as Dictionary).get(lines_key, [])
			if band_lines_value is Array:
				raw_lines.append_array(band_lines_value)
	if localized_phase_has_lines:
		raw_lines.append_array(_postgraduate_target_lines(chinese))
		raw_lines.append_array(_postgraduate_active_event_lines(chinese))
		raw_lines.append_array(_postgraduate_known_memory_lines(chinese))
	if localized_phase_has_lines and _postgraduate_is_familiar():
		var familiar_key := "familiar_lines_zh" if chinese else "familiar_lines_en"
		var familiar_value: Variant = phase.get(familiar_key, [])
		if familiar_value is Array:
			raw_lines.append_array(familiar_value)
	if localized_phase_has_lines and _postgraduate_relationship_stage() == "trusted":
		var trusted_key := "trusted_lines_zh" if chinese else "trusted_lines_en"
		var trusted_value: Variant = phase.get(trusted_key, [])
		if trusted_value is Array:
			raw_lines.append_array(trusted_value)
	var candidates: Array[String] = []
	for value in raw_lines:
		var formatted := _format_postgraduate_copy(str(value), chinese)
		if not _recent_postgraduate_lines.has(formatted):
			candidates.append(formatted)
	if candidates.is_empty():
		for value in raw_lines:
			candidates.append(_format_postgraduate_copy(str(value), chinese))
	var line := candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else ""
	if line != "":
		_recent_postgraduate_lines.append(line)
		while _recent_postgraduate_lines.size() > 4:
			_recent_postgraduate_lines.pop_front()
	return {"status": status, "line": line, "icon": str(phase.get("icon", "..."))}


func _postgraduate_observation_return_copy(chinese: bool) -> Dictionary:
	var return_value: Variant = _postgraduate_routines.get("observation_return", {})
	var return_data: Dictionary = return_value if return_value is Dictionary else {}
	var quality := str(_postgraduate_return_result.get("quality", "Failed")).to_lower()
	var quality_group := "failed"
	if quality == "excellent":
		quality_group = "excellent"
	elif quality == "good":
		quality_group = "good"
	elif quality in ["fair", "poor"]:
		quality_group = "fair"
	var locale := "zh" if chinese else "en"
	var status := _format_postgraduate_copy(str(return_data.get("status_%s" % locale, "")), chinese)
	var lines_value: Variant = return_data.get("%s_lines_%s" % [quality_group, locale], [])
	var lines: Array = lines_value if lines_value is Array else []
	var candidates: Array[String] = []
	for value in lines:
		var formatted := _format_postgraduate_copy(str(value), chinese)
		if not _recent_postgraduate_lines.has(formatted):
			candidates.append(formatted)
	if candidates.is_empty():
		for value in lines:
			candidates.append(_format_postgraduate_copy(str(value), chinese))
	var line := candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else ""
	if line != "":
		_recent_postgraduate_lines.append(line)
		while _recent_postgraduate_lines.size() > 4:
			_recent_postgraduate_lines.pop_front()
	return {"status": status, "line": line, "icon": "✓"}


func _make_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	# Prefer a single human-readable L-shaped route. In the common entrance to
	# workbench journey this means walking across the aisle first, then straight
	# down, instead of descending in a left-right staircase.
	var direct := _axis_route(from, to, true)
	if not direct.is_empty():
		return direct
	direct = _axis_route(from, to, false)
	if not direct.is_empty():
		return direct
	direct = _best_corridor_route(from, to, true)
	if not direct.is_empty():
		return direct
	direct = _best_corridor_route(from, to, false)
	if not direct.is_empty():
		return direct
	direct = _best_two_corridor_route(from, to)
	if not direct.is_empty():
		return direct
	var from_id := _nearest_open_id(_world_to_id(from))
	var to_id := _nearest_open_id(_world_to_id(to))
	if from_id.x < 0 or to_id.x < 0:
		return PackedVector2Array([to])
	var ids := _pathfinder.get_id_path(from_id, to_id)
	var result := PackedVector2Array()
	for id in ids:
		result.append(_id_to_world(id))
	if result.size() > 0:
		result[result.size() - 1] = to
	return _compress_orthogonal_path(result)


func _axis_route(from: Vector2, to: Vector2, horizontal_first: bool) -> PackedVector2Array:
	var corner := Vector2(to.x, from.y) if horizontal_first else Vector2(from.x, to.y)
	if not _segment_is_walkable(from, corner) or not _segment_is_walkable(corner, to):
		return PackedVector2Array()
	var result := PackedVector2Array()
	if from.distance_to(corner) > WAYPOINT_EPSILON:
		result.append(corner)
	if corner.distance_to(to) > WAYPOINT_EPSILON or result.is_empty():
		result.append(to)
	return result


func _best_corridor_route(from: Vector2, to: Vector2, horizontal_corridor: bool) -> PackedVector2Array:
	# Most stations are connected by broad floor aisles. Searching a continuous
	# aisle before invoking A* turns the route into two or three long human
	# strides instead of alternating 16 px grid directions.
	var best := PackedVector2Array()
	var best_score := INF
	var axis_limit := 768 if horizontal_corridor else 1024
	for coordinate in range(0, axis_limit + 1, 8):
		var corridor := float(coordinate)
		var first := Vector2(from.x, corridor) if horizontal_corridor else Vector2(corridor, from.y)
		var second := Vector2(to.x, corridor) if horizontal_corridor else Vector2(corridor, to.y)
		var points := PackedVector2Array([from, first, second, to])
		var valid := true
		var score := 0.0
		for index in range(1, points.size()):
			if not _segment_is_walkable(points[index - 1], points[index]):
				valid = false
				break
			score += points[index - 1].distance_to(points[index])
		if not valid or score >= best_score:
			continue
		var candidate := PackedVector2Array()
		for index in range(1, points.size()):
			if points[index].distance_to(points[index - 1]) > WAYPOINT_EPSILON:
				candidate.append(points[index])
		if not candidate.is_empty():
			best = candidate
			best_score = score
	return best


func _best_two_corridor_route(from: Vector2, to: Vector2) -> PackedVector2Array:
	# A single L-shaped aisle cannot get from the narrow north entrance to the
	# east workbench while also clearing the round platform. Try a small set of
	# authored hall aisles before falling back to the 16 px A* grid; this keeps
	# Maya's route to four deliberate straight legs instead of a tiled staircase.
	var corridor_xs := [320.0, 344.0, 672.0, 680.0, 712.0]
	var corridor_ys := [296.0, 312.0, 320.0, 504.0, 520.0, 584.0]
	var best := PackedVector2Array()
	var best_score := INF
	for corridor_y in corridor_ys:
		for corridor_x in corridor_xs:
			var candidates := [
				PackedVector2Array([
					from,
					Vector2(from.x, corridor_y),
					Vector2(corridor_x, corridor_y),
					Vector2(corridor_x, to.y),
					to,
				]),
				PackedVector2Array([
					from,
					Vector2(corridor_x, from.y),
					Vector2(corridor_x, corridor_y),
					Vector2(to.x, corridor_y),
					to,
				]),
			]
			for points in candidates:
				var valid := true
				var score := 0.0
				for index in range(1, points.size()):
					if not _segment_is_walkable(points[index - 1], points[index]):
						valid = false
						break
					score += points[index - 1].distance_to(points[index])
				if not valid or score >= best_score:
					continue
				var candidate := PackedVector2Array()
				for index in range(1, points.size()):
					if points[index].distance_to(points[index - 1]) > WAYPOINT_EPSILON:
						candidate.append(points[index])
				if not candidate.is_empty():
					best = candidate
					best_score = score
	return best


func _segment_is_walkable(from: Vector2, to: Vector2) -> bool:
	var distance := from.distance_to(to)
	var samples := maxi(1, ceili(distance / 6.0))
	for index in range(1, samples + 1):
		var sample := from.lerp(to, float(index) / float(samples))
		if not bool(_walkable_provider.call(sample)):
			return false
	return true


func _compress_orthogonal_path(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var result := PackedVector2Array()
	result.append(points[0])
	for index in range(1, points.size() - 1):
		var before := (points[index] - points[index - 1]).sign()
		var after := (points[index + 1] - points[index]).sign()
		if before != after:
			result.append(points[index])
	result.append(points[points.size() - 1])
	return result


func _nearest_open_id(origin: Vector2i) -> Vector2i:
	if _pathfinder.is_in_boundsv(origin) and not _pathfinder.is_point_solid(origin):
		return origin
	for radius in range(1, 7):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var candidate := Vector2i(x, y)
				if _pathfinder.is_in_boundsv(candidate) and not _pathfinder.is_point_solid(candidate):
					return candidate
	return Vector2i(-1, -1)


func _world_to_id(value: Vector2) -> Vector2i:
	return Vector2i(floori(value.x / PATH_CELL_SIZE), floori(value.y / PATH_CELL_SIZE))


func _id_to_world(value: Vector2i) -> Vector2:
	return Vector2(value.x * PATH_CELL_SIZE + PATH_CELL_SIZE * 0.5, value.y * PATH_CELL_SIZE + PATH_CELL_SIZE * 0.5)


func _update_player_behavior() -> void:
	if not _player_position_provider.is_valid():
		return
	var now := Time.get_ticks_msec()
	var player_position: Vector2 = _player_position_provider.call()
	var player_moved := player_position.distance_to(_player_last_position) >= 1.4
	if player_moved:
		_player_last_move_at_msec = now
	_player_last_position = player_position

	var player_near := position.distance_to(player_position) <= PLAYER_INTERACT_DISTANCE
	if not _route_is_guided:
		var was_near := _player_was_near
		var manager := get_node_or_null("/root/GameManager")
		var graduated := manager != null and bool(manager.progress.get("graduation_seen", false))
		# Passing Maya while she is assembling, observing, recording, or
		# reviewing must not pull her out of the job.  Only a settled tea break
		# has passive player awareness; working Maya responds only to an explicit
		# interaction.
		if graduated and not _postgraduate_can_notice_player():
			_player_was_near = false
			return
		if player_near and not _player_was_near:
			if graduated:
				_show_postgraduate_rest_proximity(
					"free_return" if _player_has_been_near else "free_near"
				)
			_player_has_been_near = true
		elif was_near and not player_near and _player_has_been_near and graduated:
			_show_postgraduate_rest_proximity("free_leave")
		_player_was_near = player_near
		return

	_player_was_near = player_near
	if _destination_id == "" or now - _route_started_at_msec < ROUTE_SETTLE_MSEC:
		return
	var destination: Vector2 = _destination_provider.call(_destination_id)
	var player_distance := player_position.distance_to(destination)
	var maya_distance := position.distance_to(destination)
	var previous_best := _player_best_destination_distance
	_player_best_destination_distance = minf(_player_best_destination_distance, player_distance)

	if now - _player_last_move_at_msec >= PLAYER_INACTIVE_MSEC and player_distance > ROUTE_ARRIVAL_DISTANCE:
		_react_once("inactive", "inactive")
		return
	if not _arrived and player_distance <= ROUTE_ARRIVAL_DISTANCE and maya_distance > ROUTE_NEAR_DISTANCE:
		_react_once("player_first", "route_player_first")
		return
	if _arrived:
		if now - _route_arrived_at_msec >= 1700 and player_distance <= ROUTE_ARRIVAL_DISTANCE:
			_react_once("player_near", "route_player_near")
		elif now - _route_arrived_at_msec >= 4200 and player_distance > ROUTE_NEAR_DISTANCE:
			_react_once("not_close", "route_not_close")
		return
	if player_distance <= ROUTE_NEAR_DISTANCE and maya_distance > ROUTE_ARRIVAL_DISTANCE:
		_react_once("almost", "route_almost")
		return
	if player_moved and previous_best < INF and player_distance > previous_best + 64.0:
		_react_once("wrong_way", "route_wrong_way")
		return
	if position.distance_to(player_position) > ROUTE_LAG_DISTANCE:
		_react_once("lag", "route_lag")
		return
	if now - _player_last_move_at_msec >= PLAYER_STOPPED_MSEC:
		_react_once("stopped", "route_stopped")


func _react_once(reaction_id: String, state_id: String) -> bool:
	if _room_blocked or _reaction_seen.has(reaction_id):
		return false
	var now := Time.get_ticks_msec()
	if now - _last_reaction_at_msec < ROUTE_REACTION_COOLDOWN_MSEC:
		return false
	_reaction_seen[reaction_id] = true
	_last_reaction_at_msec = now
	_show_state(state_id, true)
	return true


func _update_movement(delta: float) -> void:
	if Time.get_ticks_msec() < _movement_locked_until_msec:
		_moving = false
		return
	var remaining := MOVE_SPEED * delta
	var travelled := 0.0
	while remaining > 0.0 and _path_index < _path.size():
		var waypoint := _path[_path_index]
		var offset := waypoint - position
		var distance := offset.length()
		if distance <= WAYPOINT_EPSILON:
			position = waypoint
			_path_index += 1
			continue
		var direction := offset / distance
		_set_facing(_facing_from_vector(direction))
		var step := minf(remaining, distance)
		position += direction * step
		travelled += step
		remaining -= step
		if step >= distance - WAYPOINT_EPSILON:
			position = waypoint
			_path_index += 1
		else:
			break
	_moving = travelled > 0.0
	if _path_index >= _path.size() and not _arrived and _destination_id != "":
		_arrived = true
		_on_arrived()


func _on_arrived() -> void:
	if _route_is_guided:
		_face_toward(_player_position_provider.call())
	else:
		_face_toward(_station_focus(_destination_id))
	_route_arrived_at_msec = Time.get_ticks_msec()
	var state := _destination_id if _dialogue_states.has(_destination_id) else "route_arrived"
	if _route_is_guided:
		state = _route_state("arrive", _destination_id, "route_arrived")
	elif _is_postgraduate_free_roam():
		_ensure_postgraduate_work_plan()
		state = _postgraduate_state_id()
	_show_state(state, true)
	_ambient_elapsed = 0.0
	_ambient_delay = _rng.randf_range(AMBIENT_MIN_SECONDS, AMBIENT_MAX_SECONDS)
	if _is_postgraduate_free_roam():
		_sync_postgraduate_activity_timer()
	else:
		_free_activity_elapsed = 0.0
		_free_activity_delay = _rng.randf_range(FREE_ACTIVITY_MIN_SECONDS, FREE_ACTIVITY_MAX_SECONDS)


func _route_state(prefix: String, destination_id: String, fallback: String) -> String:
	var candidate := "%s_%s" % [prefix, destination_id]
	return candidate if _dialogue_states.has(candidate) else fallback


func _update_animation(delta: float) -> void:
	var desired_walk := str(FACING_ROWS.get(_facing, "walk_south"))
	if _moving and not _return_to_idle_after_animation:
		if _animation_name != desired_walk:
			_play_animation(desired_walk, true)
	elif not _return_to_idle_after_animation and _animation_name.begins_with("walk_"):
		# A stopped character must remain on one authored pose. Previously the
		# timer below advanced to frame 1 for a single render frame before this
		# branch reset it to frame 0, which looked like Maya was flickering beside
		# workstations.
		if _animation_name != desired_walk or _animation_frame != 0:
			_animation_name = desired_walk
			_animation_frame = 0
			_apply_animation_frame()
		_animation_elapsed = 0.0
		return

	_animation_elapsed += delta
	var animation: Dictionary = _animations.get(_animation_name, {})
	var frame_duration := float(animation.get("frame_duration", 0.2)) * _animation_speed_scale
	if _animation_elapsed < frame_duration:
		return
	_animation_elapsed = fmod(_animation_elapsed, frame_duration)
	var frame_count := maxi(1, int(animation.get("frames", 1)))
	_animation_frame += 1
	if _animation_frame >= frame_count:
		if _animation_loop:
			_animation_frame = 0
		elif _return_to_idle_after_animation:
			_return_to_idle_after_animation = false
			_play_animation(str(FACING_ROWS.get(_facing, "walk_south")), true)
			_animation_frame = 0
		else:
			_animation_frame = frame_count - 1
	_apply_animation_frame()


func _play_animation(
	name: String,
	loop: bool = false,
	return_to_idle: bool = false,
	speed_scale: float = 1.0
) -> void:
	if not _animations.has(name):
		return
	if name.begins_with("walk_") and _sprite != null:
		# Directional walking already has dedicated left/right atlas rows. A
		# mirrored station gesture must never leak into the next walk cycle.
		_sprite.flip_h = false
	_animation_name = name
	_animation_frame = 0
	_animation_elapsed = 0.0
	_animation_loop = loop
	_return_to_idle_after_animation = return_to_idle
	_animation_speed_scale = maxf(0.1, speed_scale)
	_apply_animation_frame()


func _apply_animation_frame() -> void:
	var animation: Dictionary = _animations.get(_animation_name, {})
	var row := int(animation.get("row", 0))
	_sprite_atlas.region = Rect2(_animation_frame * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)


func _set_facing(value: String) -> void:
	if value == _facing:
		return
	_facing = value
	if not _return_to_idle_after_animation:
		if _sprite != null:
			_sprite.flip_h = false
		_animation_name = str(FACING_ROWS.get(_facing, "walk_south"))
		_apply_animation_frame()


func _face_toward(target: Vector2) -> void:
	var direction := target - position
	if direction.length() > 1.0:
		_set_facing(_facing_from_vector(direction.normalized()))


func _station_focus(destination_id: String) -> Vector2:
	if _focus_provider.is_valid():
		return _focus_provider.call(destination_id)
	if _destination_provider.is_valid():
		return _destination_provider.call(destination_id)
	return position


func _facing_from_vector(direction: Vector2) -> String:
	var angle := atan2(direction.y, direction.x)
	var octant := posmod(int(round(angle / (PI / 4.0))), 8)
	return ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"][octant]


func _show_state(state_id: String, important: bool = false) -> void:
	var postgraduate_state := state_id.begins_with("postgraduate_")
	if not _dialogue_states.has(state_id) and not postgraduate_state:
		state_id = "idle"
	_state_id = state_id
	_apply_state_text(state_id)
	var state: Dictionary = _dialogue_states.get(state_id, {})
	var action := str(state.get("action", ""))
	if postgraduate_state:
		action = str(_postgraduate_phase_data().get("action", ""))
	if state_id == "assembly" and _animations.has("assembly_work"):
		action = "assembly_work"
	if action != "":
		# Action rows use front-facing source art, but the logical facing must stay
		# fixed. When the gesture ends Maya returns to the same station-facing idle
		# instead of snapping east/west as the player moves past her.
		var keep_working := postgraduate_state and bool(_postgraduate_phase_data().get("action_loop", false))
		var hold_work_pose := postgraduate_state and bool(_postgraduate_phase_data().get("action_hold", false))
		var speed_scale := float(_postgraduate_phase_data().get("action_speed_scale", 1.0)) \
			if postgraduate_state else 1.0
		_play_animation(action, keep_working, not keep_working and not hold_work_pose, speed_scale)
		_orient_station_gesture(state_id)
		if not keep_working and not hold_work_pose:
			var animation: Dictionary = _animations.get(action, {})
			_movement_locked_until_msec = Time.get_ticks_msec() + int(
				float(animation.get("frames", 1)) * float(animation.get("frame_duration", 0.2)) * 1000.0
			)
	if _bubble_has_visible_text():
		_bubble_hide_at_msec = Time.get_ticks_msec() + (5600 if important else 4200)
		_expand_bubble()
	else:
		_bubble.visible = false
		_bubble_badge.visible = false


func _orient_station_gesture(state_id: String) -> void:
	if _sprite == null:
		return
	var destination_id := _destination_for_state(state_id)
	if state_id.begins_with("postgraduate_"):
		destination_id = _postgraduate_destination()
	if destination_id == "" and (
		state_id.begins_with("guide_")
		or state_id.begins_with("arrive_")
		or state_id in ["route_arrived", "route_player_near", "route_player_first"]
	):
		destination_id = _destination_id
	if destination_id != "" and (_focus_provider.is_valid() or _destination_provider.is_valid()):
		var target: Vector2 = _focus_provider.call(destination_id) \
			if _focus_provider.is_valid() else _destination_provider.call(destination_id)
		# The source gesture points to screen-right. Mirror it whenever Maya is
		# standing to the right of the station she is presenting.
		_sprite.flip_h = target.x < position.x
	elif _player_position_provider.is_valid():
		var player_position: Vector2 = _player_position_provider.call()
		_sprite.flip_h = player_position.x < position.x


func _apply_state_text(state_id: String) -> void:
	if _bubble == null:
		return
	var manager := get_node_or_null("/root/GameManager")
	var chinese := manager != null and str(manager.get("language_mode")) == "zh"
	if state_id == "postgraduate_observation_return":
		_set_postgraduate_bubble_layout(true)
		var return_copy := _postgraduate_observation_return_copy(chinese)
		var return_icon := str(return_copy.get("icon", "✓"))
		_bubble_icon.text = ""
		_badge_icon.text = ""
		_bubble_status.text = _short_bubble_text(str(return_copy.get("status", "")), 18 if chinese else 30)
		_bubble_line.text = _short_bubble_text(str(return_copy.get("line", "")), 22 if chinese else 60)
		_bubble_line_marquee_enabled = false
		_queue_bubble_line_marquee()
		return
	if state_id.begins_with("postgraduate_"):
		_set_postgraduate_bubble_layout(true)
		var copy := _postgraduate_override_copy.duplicate(true) \
			if not _postgraduate_override_copy.is_empty() else _postgraduate_copy(chinese)
		_postgraduate_override_copy.clear()
		var postgraduate_icon := str(copy.get("icon", "..."))
		_bubble_icon.text = ""
		_badge_icon.text = ""
		_bubble_status.text = _short_bubble_text(str(copy.get("status", "")), 18 if chinese else 30)
		_bubble_line.text = _short_bubble_text(str(copy.get("line", "")), 22 if chinese else 60)
		_bubble_line_marquee_enabled = false
		_queue_bubble_line_marquee()
		return
	_set_postgraduate_bubble_layout(false)
	var state: Dictionary = _dialogue_states.get(state_id, _dialogue_states.get("idle", {}))
	var status_key := "status_zh" if chinese else "status_en"
	var status := _short_bubble_text(str(state.get(status_key, "")), 14 if chinese else 28)
	var line := _ambient_bubble_copy(state_id, chinese)
	# The source icon remains editable for compatibility, but never becomes a
	# mystery symbol in the hall.  The activity text is what players need.
	_bubble_icon.text = ""
	_bubble_icon.visible = false
	_badge_icon.text = ""
	_bubble_badge.visible = false
	_bubble_status.visible = not status.is_empty()
	_bubble_status.text = status
	if status.is_empty():
		_bubble_line.position = Vector2(8, 4)
		_bubble_line.size = Vector2(158, 36)
		_bubble_line.add_theme_font_size_override("font_size", 13)
		_bubble_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_bubble_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_bubble_status.position = Vector2(8, 3)
		_bubble_status.size = Vector2(158, 15)
		_bubble_line.position = Vector2(8, 17)
		_bubble_line.size = Vector2(158, 24)
		_bubble_line.add_theme_font_size_override("font_size", 11)
		_bubble_line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_bubble_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Normal hall bubbles are one-line speech.  Keep the full authored text and
	# pan it within the bubble when necessary instead of replacing the ending
	# with an ellipsis.
	_bubble_line.text = line
	_bubble_line_marquee_enabled = true
	_queue_bubble_line_marquee()


func _set_postgraduate_bubble_layout(active: bool) -> void:
	if active:
		_bubble.position = Vector2(-122, -150)
		_bubble.size = Vector2(244, 66)
		# Postgraduate phases already have a clear text status.  Hiding the
		# symbolic phase glyph avoids meaningless collapsed badges such as '#'
		# and gives the actual activity the full width of the bubble.
		_bubble_icon.visible = false
		_bubble_status.position = Vector2(10, 6)
		_bubble_status.size = Vector2(224, 20)
		_bubble_status.visible = true
		_bubble_line.position = Vector2(10, 26)
		_bubble_line.size = Vector2(224, 34)
		_bubble_line.add_theme_font_size_override("font_size", 12)
		_bubble_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	_bubble.position = Vector2(-87, -126)
	_bubble.size = Vector2(174, 44)
	_bubble_icon.visible = false
	_bubble_icon.position = Vector2(8, 4)
	_bubble_icon.size = Vector2(28, 36)
	_bubble_status.position = Vector2.ZERO
	_bubble_status.size = Vector2.ZERO
	_bubble_status.visible = false
	_bubble_line.position = Vector2(40, 4)
	_bubble_line.size = Vector2(126, 36)
	_bubble_line.add_theme_font_size_override("font_size", 13)
	_bubble_line.autowrap_mode = TextServer.AUTOWRAP_OFF


func _queue_bubble_line_marquee() -> void:
	call_deferred("_start_bubble_line_marquee")


func _start_bubble_line_marquee() -> void:
	if _bubble_line_marquee != null and _bubble_line_marquee.is_valid():
		_bubble_line_marquee.kill()
	_bubble_line_home_position = _bubble_line.position
	_bubble_line.position = _bubble_line_home_position
	_bubble_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not _bubble_line_marquee_enabled or _bubble_line.text.strip_edges().is_empty():
		return
	_bubble_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font := _bubble_line.get_theme_font("font")
	var font_size := _bubble_line.get_theme_font_size("font_size")
	if font == null or font_size <= 0:
		return
	var text_width := font.get_string_size(
		_bubble_line.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x
	var overflow := text_width - _bubble_line.size.x
	if overflow <= 2.0:
		return
	_bubble_line.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var travel_seconds := clampf(overflow / 28.0, 1.3, 5.5)
	_bubble_line_marquee = _bubble_line.create_tween().set_loops()
	_bubble_line_marquee.tween_interval(0.55)
	_bubble_line_marquee.tween_property(
		_bubble_line,
		"position:x",
		_bubble_line_home_position.x - overflow,
		travel_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bubble_line_marquee.tween_interval(0.8)
	_bubble_line_marquee.tween_property(
		_bubble_line,
		"position:x",
		_bubble_line_home_position.x,
		travel_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _ambient_bubble_copy(state_id: String, chinese: bool) -> String:
	var locale_key := "lines_zh" if chinese else "lines_en"
	var state_value: Variant = _dialogue_states.get(state_id, {})
	if state_value is Dictionary and not (state_value as Dictionary).is_empty():
		var lines_value: Variant = (state_value as Dictionary).get(locale_key, [])
		if not _copy_array_has_text(lines_value):
			return ""
		var candidates: Array[String] = []
		for line_value in lines_value:
			var line := str(line_value).strip_edges()
			if line != "":
				candidates.append(line)
		return candidates[_rng.randi_range(0, candidates.size() - 1)] \
			if not candidates.is_empty() else ""
	# Only unknown legacy states may use the short-copy compatibility table. A
	# known state with missing Chinese remains silent by authoring intent.
	var key := "zh" if chinese else "en"
	var fallback_value: Variant = _ambient_lines.get("idle", {})
	var fallback: Dictionary = fallback_value if fallback_value is Dictionary else {}
	return str(fallback.get(key, ""))


func _contextual_state_copy(
	state_id: String,
	chinese: bool,
	manager: Node,
	fallback_status: String,
	fallback_line: String
) -> Dictionary:
	if manager == null:
		return {"status": fallback_status, "line": fallback_line}
	var route: Dictionary = manager.call("current_room_route") \
		if manager.has_method("current_room_route") else {}
	var level: Dictionary = manager.call("current_level") \
		if manager.has_method("current_level") else {}
	var board_note: Dictionary = manager.call("mission_board_note") \
		if manager.has_method("mission_board_note") else {}
	var locale := "zh" if chinese else "en"
	var level_number := int(level.get("level_number", 0))
	var level_title := str(level.get("title_%s" % locale, ""))
	var route_title := _strip_maya_prefix(str(route.get("title", "")))
	var route_action := str(route.get("action", ""))
	var route_hint := str(route.get("hint", ""))
	var board_line := str(board_note.get(locale, ""))
	var result := {"status": fallback_status, "line": fallback_line}

	if state_id == "greeting":
		result["status"] = editable_text("level_status", {"level": level_number, "title": level_title})
		result["line"] = board_line if board_line != "" else route_action
		return result

	if state_id.begins_with("guide_") or state_id == "guide":
		result["status"] = route_title if route_title != "" else fallback_status
		result["line"] = route_action if route_action != "" else fallback_line
		return result

	if state_id.begins_with("arrive_") or state_id in ["route_arrived", "route_player_near"]:
		result["status"] = route_title if route_title != "" else fallback_status
		result["line"] = route_hint if route_hint != "" else route_action
		return result

	if state_id in ["route_lag", "route_wrong_way", "route_stopped", "route_almost", "route_not_close", "inactive"]:
		if route_title != "":
			result["status"] = "%s · %s" % [fallback_status, route_title]
		return result

	if state_id in ["mission", "open_mission", "repeat_mission", "close_mission"]:
		result["status"] = editable_text("level_status", {"level": level_number, "title": level_title})
		result["line"] = board_line if board_line != "" else route_hint
		return result

	if state_id in ["assembly_success", "tutorial_complete"]:
		result["status"] = fallback_status
		result["line"] = editable_text("next_prefix") + route_action \
			if route_action != "" else fallback_line
		return result

	if state_id in ["observation_success", "remote_success", "journal_saved"]:
		return _observation_return_copy(
			state_id, chinese, manager, route_action, fallback_status, fallback_line
		)

	var contextual_destination := _destination_for_state(state_id)
	if contextual_destination != "" and str(route.get("target", "")) == contextual_destination:
		result["status"] = route_title if route_title != "" else fallback_status
		result["line"] = route_action if route_action != "" else fallback_line
	return result


func _observation_return_copy(
	state_id: String,
	chinese: bool,
	manager: Node,
	route_action: String,
	fallback_status: String,
	fallback_line: String
) -> Dictionary:
	var observation_value: Variant = manager.get("last_observation")
	var observation: Dictionary = observation_value if observation_value is Dictionary else {}
	var target: Dictionary = manager.call("current_target") \
		if manager.has_method("current_target") else {}
	var locale := "zh" if chinese else "en"
	var target_name := str(observation.get("object_name_%s" % locale, ""))
	if target_name == "":
		target_name = str(observation.get("target_name_%s" % locale, ""))
	if target_name == "":
		target_name = str(target.get("name_%s" % locale, ""))
	var maya_line := str(observation.get("maya_%s" % locale, ""))
	var status := fallback_status
	var line := maya_line
	if target_name != "":
		if state_id == "journal_saved":
			status = editable_text("observation_filed", {"target": target_name})
		elif state_id == "remote_success":
			status = editable_text("observation_data_returned", {"target": target_name})
		else:
			status = editable_text("observation_complete", {"target": target_name})
	if line == "":
		line = editable_text("next_prefix") + route_action \
			if route_action != "" else fallback_line
	return {"status": status, "line": line}


func _destination_for_state(state_id: String) -> String:
	for destination_id in ["mission", "cabinet", "assembly", "telescope", "door", "journal", "computer"]:
		if state_id == destination_id or state_id.ends_with("_%s" % destination_id):
			return destination_id
	if state_id in ["inspect_cabinet", "cabinet_missing", "cabinet_advanced"]:
		return "cabinet"
	if state_id == "operate_telescope":
		return "telescope"
	if state_id.begins_with("remote_"):
		return "computer"
	return ""


func _strip_maya_prefix(value: String) -> String:
	return value.trim_prefix("Maya: ").trim_prefix("玛雅：")


func _short_bubble_text(value: String, max_characters: int) -> String:
	var compact := value.replace("\n", " ").strip_edges()
	if compact.length() <= max_characters:
		return compact
	var candidate := compact.substr(0, maxi(1, max_characters - 1))
	var last_break := maxi(candidate.rfind("。"), candidate.rfind("；"))
	last_break = maxi(last_break, candidate.rfind(". "))
	if last_break >= int(float(max_characters) * 0.58):
		candidate = candidate.substr(0, last_break + 1)
	return candidate.strip_edges() + "…"


func _expand_bubble() -> void:
	_bubble.visible = true
	_bubble_badge.visible = false
	var feedback := get_node_or_null("/root/InteractionFeedback")
	if feedback != null and bool(feedback.call("is_reduced_motion")):
		_bubble.scale = Vector2.ONE
		_bubble.modulate.a = 1.0
		return
	_bubble.pivot_offset = Vector2(_bubble.size.x * 0.5, _bubble.size.y)
	_bubble.scale = Vector2(0.88, 0.88)
	_bubble.modulate.a = 0.0
	var tween := _bubble.create_tween().set_parallel(true)
	tween.tween_property(_bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bubble, "modulate:a", 1.0, 0.16)


func _bubble_has_visible_text() -> bool:
	return (_bubble_status != null and not _bubble_status.text.strip_edges().is_empty()) \
		or (_bubble_line != null and not _bubble_line.text.strip_edges().is_empty())


func _update_bubble_visibility() -> void:
	if _room_blocked or _bubble == null:
		return
	# Her job is readable from the room at all times.  Proximity does not
	# expand or replace it; the full status is the default presentation.
	if _state_id.begins_with("postgraduate_") and _postgraduate_phase != "":
		if not _bubble.visible:
			_apply_state_text(_state_id)
			if _bubble_has_visible_text():
				_expand_bubble()
		_bubble_badge.visible = false
		return
	var player_position: Vector2 = _player_position_provider.call()
	var nearby := position.distance_to(player_position) <= BUBBLE_EXPAND_DISTANCE
	var expired := Time.get_ticks_msec() >= _bubble_hide_at_msec
	if expired and not nearby:
		_bubble.visible = false
		_bubble_badge.visible = false
	elif nearby and not _bubble.visible:
		_apply_state_text(_state_id)
		if _bubble_has_visible_text():
			_expand_bubble()
		else:
			_bubble_badge.visible = false


func _update_ambient_bubble(delta: float) -> void:
	if _moving or not _arrived:
		return
	_ambient_elapsed += delta
	if _ambient_elapsed < _ambient_delay:
		return
	_ambient_elapsed = 0.0
	_ambient_delay = _rng.randf_range(AMBIENT_MIN_SECONDS, AMBIENT_MAX_SECONDS)
	var state := _destination_id if _dialogue_states.has(_destination_id) else "idle"
	var manager := get_node_or_null("/root/GameManager")
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	if str(_route_target_provider.call()) == "" and progress_value is Dictionary \
			and bool(progress_value.get("graduation_seen", false)):
		_ensure_postgraduate_work_plan()
		state = _postgraduate_state_id()
	_show_state(state, false)


func _update_free_activity(delta: float) -> void:
	if _moving or not _arrived or _route_is_guided or not _is_postgraduate_free_roam():
		return
	_free_activity_elapsed = maxf(
		_free_activity_elapsed + delta,
		float(_postgraduate_now_unix() - _postgraduate_phase_started_unix)
	)
	if _free_activity_elapsed < _free_activity_delay:
		return
	var next_started_unix := _postgraduate_phase_started_unix + int(ceil(_postgraduate_phase_duration_seconds))
	_advance_postgraduate_work(next_started_unix)
	_sync_postgraduate_activity_timer()
	_update_route_target(true)


func _is_postgraduate_free_roam() -> bool:
	var manager := get_node_or_null("/root/GameManager")
	var progress_value: Variant = manager.get("progress") if manager != null else {}
	return progress_value is Dictionary and bool(progress_value.get("graduation_seen", false))


func _update_depth() -> void:
	# Maya and the player share the same normal actor layer.  Relative depth is
	# only needed while their sprites actually overlap; keeping Maya at z=0/2
	# everywhere made unrelated furniture animation copies cut through her.
	z_index = 1
	if _maya_in_front_of_furniture:
		# A foreground cutout is shared by both actors.  When the player happens
		# to be behind this desk, keep Maya (whose feet are below its front edge)
		# above that cutout instead of cutting her body in half.
		z_index = 4
		return
	if not _player_position_provider.is_valid():
		return
	var player_position: Vector2 = _player_position_provider.call()
	if absf(position.x - player_position.x) > 34.0 \
		or absf(position.y - player_position.y) > 48.0:
		return
	var depth_delta := position.y - player_position.y
	# A small hysteresis band prevents the two sprites from swapping layers on
	# every sub-pixel step while they pass through one another.
	if depth_delta > 10.0:
		_maya_in_front_of_player = true
	elif depth_delta < -10.0:
		_maya_in_front_of_player = false
	# During the brief actor/actor overlap, bracket the player's z=1 layer. The
	# separate furniture occluders remain responsible for real desk occlusion.
	z_index = 2 if _maya_in_front_of_player else 0
