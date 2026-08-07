extends SceneTree

const ISOLATED_USER_MARKER := "pixel_observatory_test_user"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var active_user_dir := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not active_user_dir.contains(ISOLATED_USER_MARKER):
		push_error(
			"Maya NPC test refused to run against the player profile. "
			+ "Launch it with APPDATA pointing at an isolated pixel_observatory_test_user directory."
		)
		quit(2)
		return
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager autoload is available")
	if gm == null:
		quit(1)
		return
	var prior_language := str(gm.language_mode)
	var prior_level := int(gm.progress.get("current_level", 1))
	var prior_graduated := bool(gm.progress.get("graduation_seen", false))
	var prior_program_completed := bool(gm.progress.get("program_completed", false))
	gm.language_mode = "zh"
	gm.clear_maya_observatory_return_pose()
	gm.progress["current_level"] = 1
	gm.progress["graduation_seen"] = false
	gm.progress["program_completed"] = false
	gm.room_guidance_target = "telescope"
	var room := (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	await process_frame

	var maya := room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	_check(maya != null, "hall creates Maya as an in-world NPC")
	if maya != null:
		_check(maya.get_node_or_null("MayaSprite") != null, "Maya uses the imported pixel animation atlas")
		_check(maya.get_node_or_null("MayaThoughtBubble") != null, "Maya owns a compact thought bubble")
		var atlas_metadata: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/characters/maya/hall_npc/maya_hall_atlas.json")
		)
		var atlas_cell_size: Array = atlas_metadata.get("cell_size", [])
		var atlas_foot_anchor: Array = atlas_metadata.get("foot_anchor", [])
		_check(
			atlas_cell_size.size() == 2
			and int(atlas_cell_size[0]) == 64
			and int(atlas_cell_size[1]) == 80,
			"Maya atlas leaves head and ponytail safety room"
		)
		_check(
			atlas_foot_anchor.size() == 2
			and int(atlas_foot_anchor[0]) == 32
			and int(atlas_foot_anchor[1]) == 74,
			"every animation shares one foot anchor"
		)
		var walk_metadata: Dictionary = atlas_metadata.get("animations", {}).get("walk_south", {})
		_check(
			float(walk_metadata.get("frame_duration", 0.0)) >= 0.24,
			"walking cadence stays calm instead of flickering through frames"
		)
		_check(
			atlas_metadata.get("animations", {}).has("assembly_work"),
			"Maya has an authored workbench interaction instead of only pointing at it"
		)
		var dialogue_states: Dictionary = maya.get("_dialogue_states")
		_check(dialogue_states.size() >= 40, "Maya loads the complete dialogue library from UTF-8 JSON")
		_check(
			FileAccess.file_exists("res://data/maya_npc_dialogue.json")
			and not FileAccess.file_exists("res://data/maya_hall_npc_dialogue.json")
			and not FileAccess.file_exists("res://data/maya_postgraduate_routines.json"),
			"all hall and postgraduate Maya copy lives in one editable JSON file"
		)
		var greeting_state: Dictionary = dialogue_states.get("greeting", {})
		var greeting_lines: Array = greeting_state.get("lines_zh", [])
		_check(
			not greeting_lines.is_empty()
			and not str(greeting_lines[0]).strip_edges().is_empty(),
			"Maya preserves the user's authored Chinese dialogue without encoding damage"
		)
		dialogue_states["__silent_zh_test"] = {
			"icon": "·",
			"lines_en": ["English must not leak into Chinese."],
			"lines_zh": [],
		}
		maya.call("_show_state", "__silent_zh_test", true)
		var silent_line := maya.get("_bubble_line") as Label
		var silent_bubble := maya.get_node("MayaThoughtBubble") as Panel
		var silent_badge := maya.get_node("MayaThoughtBadge") as Panel
		_check(
			silent_line.text == "" and not silent_bubble.visible and not silent_badge.visible,
			"an empty Chinese state stays silent without English or a symbol fallback"
		)
		dialogue_states.erase("__silent_zh_test")
		var marquee_line := "Here we are—don't jump to high power yet, little stargazer~"
		dialogue_states["__marquee_test"] = {
			"lines_en": [marquee_line],
			"lines_zh": [],
		}
		gm.language_mode = "en"
		maya.call("_show_state", "__marquee_test", true)
		await process_frame
		await process_frame
		var marquee_label := maya.get("_bubble_line") as Label
		_check(
			marquee_label.text == marquee_line
			and maya.get("_bubble_line_marquee") != null,
			"long Maya speech keeps its full text and starts an in-bubble marquee"
		)
		dialogue_states.erase("__marquee_test")
		gm.language_mode = "zh"
		maya.call("_show_state", "greeting", true)
		_check_postgraduate_bubble_copy()
		_check(maya.collision_rect().size == Vector2.ZERO, "Maya never blocks the player")
		_check(maya.position.distance_to(Vector2(512, 292)) < 2.0, "Maya begins inside the hall entrance")
		_check(maya.contains_screen_point(maya.position - Vector2(0, 30)), "Maya's pixel body is clickable")
		var maya_sprite := maya.get_node("MayaSprite") as Sprite2D
		var thought_bubble := maya.get_node("MayaThoughtBubble") as Panel
		_check(maya_sprite.scale.y >= 1.65, "Maya stands about one head taller than the player")
		var player_sprite := room.get_node_or_null("Player") as Sprite2D
		var furniture_animator := room.get_node_or_null("FurnitureAnimator") as Control
		_check(player_sprite != null and player_sprite.z_index == 1, "player occupies the middle actor depth band")
		_check(maya.z_index >= 0, "entrance Maya stays above closed furniture copies so her head remains visible")
		if furniture_animator != null:
			var door_rig := furniture_animator.get_node_or_null("DoorFurnitureRig") as Control
			_check(door_rig != null and maya.z_index >= door_rig.z_index, "closed observatory door cannot crop Maya's greeting pose")
		_check(thought_bubble.size.x <= 180.0 and thought_bubble.size.y <= 48.0, "hall bubble stays compact")
		_check(
			thought_bubble.position.y + thought_bubble.size.y <= -76.0,
			"thought bubble clears Maya's head instead of painting over it"
		)
		var telescope_focus: Vector2 = room.call("_maya_focus_for", "telescope")
		maya.position = telescope_focus + Vector2(96, 0)
		maya.set("_destination_id", "telescope")
		maya.call("_show_state", "arrive_telescope", true)
		_check(maya_sprite.flip_h, "Maya mirrors her gesture left when the telescope is on her left")
		maya.position = telescope_focus - Vector2(96, 0)
		maya.call("_show_state", "arrive_telescope", true)
		_check(not maya_sprite.flip_h, "Maya keeps the source gesture when the telescope is on her right")
		maya.call("_set_facing", "left")
		maya.call("_play_animation", "walk_west", true)
		_check(not maya_sprite.flip_h, "station gesture mirroring never leaks into directional walking")
		maya.set("_moving", false)
		var idle_region_before: Rect2 = (maya_sprite.texture as AtlasTexture).region
		for _idle_tick in range(8):
			maya.call("_update_animation", 0.30)
		var idle_region_after: Rect2 = (maya_sprite.texture as AtlasTexture).region
		_check(
			idle_region_after == idle_region_before and int(maya.get("_animation_frame")) == 0,
			"stationary Maya stays on one stable frame instead of flashing a walk frame"
		)
		maya.position = Vector2(512, 292)
		for destination_id in ["cabinet", "door", "mission", "assembly", "telescope", "journal", "computer"]:
			var destination: Vector2 = room.call("_maya_destination_for", destination_id)
			_check(
				bool(room.call("_maya_position_is_walkable", destination)),
				"Maya destination '%s' is reachable" % destination_id
			)
			_check(
				str(maya.call("_route_state", "guide", destination_id, "guide")) == "guide_%s" % destination_id,
				"Maya has destination-specific guide dialogue for '%s'" % destination_id
			)
			_check(
				str(maya.call("_route_state", "arrive", destination_id, "route_arrived")) == "arrive_%s" % destination_id,
				"Maya has destination-specific arrival dialogue for '%s'" % destination_id
			)
		var route_ids := ["cabinet", "door", "mission", "assembly", "telescope", "journal", "computer"]
		_check(
			not bool(room.call("_maya_position_is_walkable", Vector2(512, 445))),
			"Maya treats the central telescope platform as a no-walk route footprint"
		)
		var telescope_destination: Vector2 = room.call("_maya_destination_for", "telescope")
		_check(
			telescope_destination.distance_to(Vector2(680, 496)) < 1.0,
			"Maya observes from the clear aisle beside the central platform"
		)
		for from_id in route_ids:
			for to_id in route_ids:
				if from_id == to_id:
					continue
				var from_pos: Vector2 = room.call("_maya_destination_for", from_id)
				var to_pos: Vector2 = room.call("_maya_destination_for", to_id)
				var route_path: PackedVector2Array = maya.call("_make_path", from_pos, to_pos)
				_check(not route_path.is_empty(), "Maya can walk from '%s' to '%s'" % [from_id, to_id])
				var previous := from_pos
				for waypoint in route_path:
					var leg: Vector2 = waypoint - previous
					_check(
						bool(maya.call("_segment_is_walkable", previous, waypoint)),
						"Maya route '%s' to '%s' never crosses the central platform" % [from_id, to_id]
					)
					_check(
						absf(leg.x) <= 0.01 or absf(leg.y) <= 0.01,
						"Maya route '%s' to '%s' has no diagonal stair-step leg" % [from_id, to_id]
					)
					previous = waypoint
		var entrance := Vector2(512, 292)
		var assembly_destination: Vector2 = room.call("_maya_destination_for", "assembly")
		_check(
			assembly_destination.distance_to(Vector2(852, 540)) < 1.0,
			"Maya assembles from the centered front edge of the workbench"
		)
		maya.position = assembly_destination
		room.call("_update_furniture_occlusion")
		maya.call("_update_depth")
		_check(
			maya.z_index > 3,
			"Maya at the front of the workbench stays above its foreground cutout"
		)
		var entrance_route: PackedVector2Array = maya.call("_make_path", entrance, assembly_destination)
		print("MAYA ENTRANCE -> ASSEMBLY ROUTE: ", entrance_route)
		_check(entrance_route.size() <= 5, "entrance route uses a few deliberate turns instead of a staircase")
		var previous_step := entrance
		for waypoint in entrance_route:
			var step: Vector2 = waypoint - previous_step
			_check(absf(step.x) <= 0.01 or absf(step.y) <= 0.01, "entrance route is strictly rectilinear")
			previous_step = waypoint

		maya.call("_show_state", "greeting", true)
		var bubble_status: Label = maya.get("_bubble_status") as Label
		var bubble_line: Label = maya.get("_bubble_line") as Label
		_check(
			bubble_status.text == str(greeting_state.get("status_zh", "")) and bubble_status.visible,
			"hall bubble shows a readable Maya status instead of a symbol"
		)
		_check(greeting_lines.has(bubble_line.text), "greeting uses the user's current authored line")
		gm.progress["current_level"] = 3
		gm.update_room_guidance_for_level()
		maya.call("_show_state", "greeting", true)
		_check(
			bubble_line.text.length() <= 12
			and not bubble_line.text.contains("60mm")
			and not bubble_line.text.contains("当前装备"),
			"ambient bubble never turns into a route or equipment briefing"
		)
		gm.progress["current_level"] = 1
		gm.update_room_guidance_for_level()

		var overlap_start := maya.position
		room.set("player_pos", overlap_start)
		maya.set("_path", PackedVector2Array([overlap_start + Vector2(40, 0)]))
		maya.set("_path_index", 0)
		maya.set("_movement_locked_until_msec", 0)
		maya.call("_update_movement", 0.1)
		_check(maya.position.x > overlap_start.x, "Maya can walk through the player without stopping")
		maya.position = overlap_start
		maya.call("_update_depth")
		var overlap_depth := maya.z_index
		room.set("player_pos", overlap_start + Vector2(0, 5))
		maya.call("_update_depth")
		_check(maya.z_index == overlap_depth, "overlap depth uses hysteresis instead of flickering")
		maya.position = Vector2(120, 700)
		room.call("_update_furniture_occlusion")
		maya.call("_update_depth")
		_check(maya.z_index == 1, "separated Maya returns to the same normal actor layer as the player")

		maya.position = Vector2(500, 610)
		room.call("_set_player_position", Vector2(450, 610))
		Input.action_press("move_right")
		for _step in range(5):
			room.call("_move_player", 0.1)
		Input.action_release("move_right")
		_check(Vector2(room.get("player_pos")).x > 520.0, "player can pass through Maya in the same aisle")

		maya.call("_update_route_target", true)
		_check(maya.is_following_route(), "Maya distinguishes a lesson route from free roaming")
		_check(maya.current_destination_id() == "telescope", "Maya follows the current telescope route")
		_check(maya.current_state_id() == "guide_telescope", "telescope route says the approved 'look at the sky' line")
		maya.react_to_interaction("mission", "open")
		_check(maya.current_state_id() == "open_mission", "first mission-board opening gets a direct target reminder")
		maya.react_to_interaction("mission", "open")
		_check(maya.current_state_id() == "repeat_mission", "reopening the mission board gets a contextual response")
		maya.react_to_interaction("mission", "close")
		_check(maya.current_state_id() == "close_mission", "closing the mission board sends the player onward")

		var now := Time.get_ticks_msec()
		room.set("player_pos", Vector2(100, 600))
		maya.set("_route_started_at_msec", now - 8000)
		maya.set("_last_reaction_at_msec", now - 8000)
		maya.set("_player_last_position", Vector2(100, 600))
		maya.set("_player_last_move_at_msec", now)
		maya.call("_update_player_behavior")
		_check(maya.current_state_id() == "route_lag", "Maya notices when the player does not follow")

		var prior_postgraduate_room_guidance := str(gm.room_guidance_target)
		var prior_work_value: Variant = gm.progress.get("maya_postgraduate_work", null)
		var prior_relationship_value: Variant = gm.progress.get("maya_postgraduate_relationship", null)
		var prior_presence_value: Variant = gm.progress.get("maya_postgraduate_presence", null)
		var prior_observation_roam_value: Variant = gm.progress.get("maya_observation_hall_roam", null)
		gm.progress["graduation_seen"] = true
		gm.progress.erase("maya_postgraduate_work")
		gm.progress.erase("maya_postgraduate_relationship")
		maya.set("_postgraduate_phase", "")
		maya.set("_postgraduate_target_id", "")
		maya.set("_postgraduate_instrument_id", "")
		maya.set("_postgraduate_relationship", {})
		gm.room_guidance_target = "assembly"
		maya.call("_update_route_target", true)
		_check(
			not maya.is_following_route(),
			"post-graduation Maya keeps her own schedule even when the player's HUD points at a workbench"
		)
		var first_work: Dictionary = maya.postgraduate_work_snapshot()
		_check(
			str(first_work.get("phase", "")) == "assembling"
			and str(first_work.get("destination", "")) == "assembly",
			"post-graduation Maya starts a real observing project at the assembly bench"
		)
		_check(
			int(first_work.get("phase_started_unix", 0)) > 0
			and float(first_work.get("phase_duration_seconds", 0.0)) >= 240.0,
			"Maya's current work phase uses the slower ten-times real-world clock"
		)
		maya.position = room.call("_maya_destination_for", "assembly")
		maya.call("remember_player_departure", true)
		var saved_roam_value: Variant = gm.progress.get("maya_observation_hall_roam", {})
		var saved_roam: Dictionary = saved_roam_value if saved_roam_value is Dictionary else {}
		_check(
			not saved_roam.is_empty() and (saved_roam.get("stations", []) as Array).size() >= 2,
			"leaving for an observation schedules Maya's off-screen hall walk"
		)
		if not saved_roam.is_empty():
			saved_roam["started_unix"] = int(Time.get_unix_time_from_system()) - 40
			gm.progress["maya_observation_hall_roam"] = saved_roam
			maya.call("_resume_observation_hall_roam")
			_check(
				maya.current_destination_id() == "assembly" and maya.position.distance_to(room.call("_maya_destination_for", "cabinet")) < 0.1,
				"returning from observation resumes Maya from a later hall station instead of freezing her old pose"
			)
			maya.set("_movement_locked_until_msec", 0)
			maya.call("_update_movement", 0.5)
			_check(bool(maya.get("_moving")), "Maya visibly continues her hall route after the player returns")
		var first_cycle := int(first_work.get("cycle", 0))
		gm.progress["maya_postgraduate_presence"] = {
			"departed_unix": int(Time.get_unix_time_from_system()) - 2,
			"phase": "assembling",
			"cycle": first_cycle,
			"target_id": str(first_work.get("target_id", "")),
		}
		maya.set("_postgraduate_phase_started_unix", int(Time.get_unix_time_from_system()) - 2)
		maya.set("_postgraduate_phase_duration_seconds", 1.0)
		maya.call("_catch_up_postgraduate_work")
		var caught_up_work: Dictionary = maya.postgraduate_work_snapshot()
		_check(
			str(caught_up_work.get("phase", "")) == "observing",
			"Maya keeps working while the player is outside the observatory"
		)
		var return_reaction: Dictionary = maya.call("_postgraduate_return_reaction")
		_check(
			bool(return_reaction.get("advanced", false))
			and str(return_reaction.get("line", "")) != "",
			"Maya notices that her work advanced before the player returned"
		)
		maya.set("_postgraduate_phase", "assembling")
		maya.set("_postgraduate_assembly_progress", 0)
		maya.call("_reset_postgraduate_phase_clock")
		maya.call("_save_postgraduate_work_plan")
		maya.set("_postgraduate_night_id", "cold_clear")
		maya.set("_postgraduate_event_id", "finder_recalibration")
		var finder_work: Dictionary = maya.postgraduate_work_snapshot()
		var finder_steps_value: Variant = finder_work.get("assembly_steps_zh", [])
		var finder_steps: Array = finder_steps_value if finder_steps_value is Array else []
		_check(
			finder_steps.size() == 4 and str(finder_steps[3]).contains("标定寻星镜"),
			"a finder-drift night adds a real recalibration task to Maya's workbench"
		)
		maya.set("_postgraduate_event_id", "dew_control")
		first_work = maya.postgraduate_work_snapshot()
		var project_target := str(first_work.get("target_id", ""))
		var project_instrument := str(first_work.get("instrument_id", ""))
		var project_night := str(first_work.get("night_id", ""))
		_check(
			project_night != "" and str(first_work.get("night_name_zh", "")) != "",
			"each postgraduate project owns a named night condition independent from the campaign mission"
		)
		var first_free_destination := maya.current_destination_id()
		maya.call("_update_route_target")
		_check(
			maya.current_destination_id() == first_free_destination,
			"Maya keeps her current work commitment instead of rerolling every frame"
		)
		maya.set("_destination_id", "assembly")
		maya.set("_arrived", true)
		maya.set("_moving", false)
		maya.call("_show_state", "postgraduate_assembling", false)
		var postgraduate_bubble_line: Label = maya.get("_bubble_line") as Label
		_check(
			postgraduate_bubble_line != null
			and postgraduate_bubble_line.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
			"postgraduate activity bubbles wrap wide Chinese copy instead of clipping it"
		)
		_check(
			str(maya.get("_animation_name")) == "assembly_work",
			"Maya physically works on her selected telescope at the centered bench"
		)
		_check(
			bool(maya.get("_animation_loop"))
			and not bool(maya.get("_return_to_idle_after_animation"))
			and float(maya.get("_animation_speed_scale")) >= 2.5,
			"assembly work continues at a calm cadence instead of ending after 1.8 seconds"
		)
		var postgraduate_data: Dictionary = maya.get("_postgraduate_routines")
		var phases: Dictionary = postgraduate_data.get("phases", {})
		var assembly_phase: Dictionary = phases.get("assembling", {})
		var saved_assembly_lines: Variant = assembly_phase.get("lines_zh", []).duplicate(true)
		var saved_assembly_status := str(assembly_phase.get("status_zh", ""))
		assembly_phase["lines_zh"] = []
		assembly_phase["status_zh"] = ""
		var silent_work_copy: Dictionary = maya.call("_postgraduate_copy", true)
		_check(
			str(silent_work_copy.get("line", "")) == ""
			and str(silent_work_copy.get("status", "")) == "",
			"an empty postgraduate Chinese state is not refilled by event or target chatter"
		)
		assembly_phase["lines_zh"] = saved_assembly_lines
		assembly_phase["status_zh"] = saved_assembly_status
		var work_status: Label = maya.get("_bubble_status") as Label
		_check(work_status.visible and work_status.text.contains("正在组装"), "work bubble names Maya's live assembly state")
		var varied_lines: Dictionary = {}
		for _line_sample in range(6):
			maya.call("_show_state", "postgraduate_assembling", false)
			varied_lines[(maya.get("_bubble_line") as Label).text] = true
		_check(varied_lines.size() >= 4, "the same work phase rotates through varied non-repeating dialogue")
		maya.set("_ambient_elapsed", 999.0)
		maya.set("_ambient_delay", 0.0)
		maya.call("_update_ambient_bubble", 0.1)
		_check(
			maya.current_destination_id() == "assembly",
			"ambient speech never interrupts a workstation activity"
		)
		var assembly_request: Dictionary = maya.postgraduate_interaction_request()
		_check(
			str(assembly_request.get("action", "")) == "open_workbench",
			"players can enter Maya's live assembly project instead of only reading a bubble"
		)
		var assembly_steps_value: Variant = first_work.get("assembly_steps_zh", [])
		var assembly_steps: Array = assembly_steps_value if assembly_steps_value is Array else []
		_check(
			assembly_steps.size() == 4
			and str(assembly_steps[3]).contains("除露")
			and int(first_work.get("assembly_progress", -1)) == 0,
			"a dew-control night adds a real fourth assembly step instead of only changing dialogue"
		)
		room.call("_interact_with_maya")
		_check(room.get("maya_workbench_popup") != null, "interacting at the bench opens Maya's collaborative workbench")
		room.call("_close_maya_workbench")
		var walkaway_relationship: Dictionary = maya.postgraduate_work_snapshot().get("relationship", {})
		_check(
			int(walkaway_relationship.get("workbench_walkaways", 0)) == 1,
			"Maya remembers when the player only looks at her workbench and walks away"
		)
		room.call("_interact_with_maya")
		_check(
			room.get("maya_workbench_popup") != null,
			"Maya lets the player return to the same unfinished collaboration"
		)
		for step_index in range(assembly_steps.size()):
			room.call("_assist_maya_at_workbench")
			var assisted_work: Dictionary = maya.postgraduate_work_snapshot()
			if step_index < assembly_steps.size() - 1:
				_check(
					int(assisted_work.get("assembly_progress", 0)) == step_index + 1,
					"workbench assistance persists assembly step %d" % (step_index + 1)
				)
		_check(room.get("maya_workbench_popup") == null, "finishing the build closes the workbench and releases the room")
		var observing_work: Dictionary = maya.postgraduate_work_snapshot()
		var relationship_after_assembly: Dictionary = observing_work.get("relationship", {})
		_check(
			int(relationship_after_assembly.get("assembly_assists", 0)) == assembly_steps.size(),
			"Maya remembers how many assembly steps the player completed with her"
		)
		_check(
			str(observing_work.get("relationship_stage", "")) == "familiar",
			"working together advances Maya from a new colleague to a familiar partner"
		)
		_check(
			str(observing_work.get("phase", "")) == "observing"
			and str(observing_work.get("destination", "")) == "telescope"
			and str(observing_work.get("target_id", "")) == project_target
			and str(observing_work.get("instrument_id", "")) == project_instrument,
			"finishing assembly sends Maya, the same instrument, and the same target to the telescope"
		)
		maya.set("_destination_id", "telescope")
		maya.set("_arrived", true)
		maya.set("_moving", false)
		maya.call("_show_state", "postgraduate_observing", true)
		var target_specific_lines: Array = maya.call("_postgraduate_target_lines", true)
		_check(
			target_specific_lines.size() >= 2,
			"Maya has celestial-object-specific expertise for the exact target she selected"
		)
		var active_event_lines: Array = maya.call("_postgraduate_active_event_lines", true)
		_check(
			active_event_lines.size() >= 2,
			"the active dew event continues to influence Maya at the telescope"
		)
		var observation_request: Dictionary = maya.postgraduate_interaction_request()
		_check(
			str(observation_request.get("action", "")) == "join_observation"
			and str(observation_request.get("object_id", "")) == project_target
			and str(observation_request.get("instrument_id", "")) == project_instrument,
			"players can join Maya's exact celestial target with the telescope she assembled"
		)
		maya.remember_joined_observation()
		var relationship_after_join: Dictionary = maya.postgraduate_work_snapshot().get("relationship", {})
		_check(
			int(relationship_after_join.get("observations_joined", 0)) == 1,
			"Maya remembers a shared observation instead of greeting the player like a stranger next time"
		)
		var persisted_relationship: Dictionary = gm.progress.get("maya_postgraduate_relationship", {})
		_check(
			int(persisted_relationship.get("observations_joined", 0)) == 1,
			"relationship memory is persisted in progress rather than living only on the current sprite"
		)
		maya.respond_to_player()
		_check(maya.current_state_id() == "postgraduate_observing", "talking to Maya preserves her real work context")
		_check((maya.get("_bubble_status") as Label).text.contains("正在观测"), "observing bubble names Maya's selected target")
		maya.respond_to_player()
		_check(
			int(maya.postgraduate_work_snapshot().get("interaction_count", 0)) == 2
			and not (maya.get("_bubble_icon") as Label).visible
			and not (maya.get("_bubble_line") as Label).text.strip_edges().is_empty(),
			"repeatedly interrupting Maya produces a deliberate text response without a symbol badge"
		)
		for expected_phase in ["recording", "reviewing"]:
			maya.set("_free_activity_elapsed", 999.0)
			maya.set("_free_activity_delay", 0.0)
			maya.call("_update_free_activity", 0.1)
			var next_work: Dictionary = maya.postgraduate_work_snapshot()
			_check(str(next_work.get("phase", "")) == expected_phase, "Maya advances her project to '%s'" % expected_phase)
			_check(str(next_work.get("target_id", "")) == project_target, "Maya remembers the project target through '%s'" % expected_phase)
			maya.set("_destination_id", str(next_work.get("destination", "")))
			maya.set("_arrived", true)
			maya.set("_moving", false)
		maya.set("_free_activity_elapsed", 999.0)
		maya.set("_free_activity_delay", 0.0)
		maya.call("_update_free_activity", 0.1)
		var resting_work: Dictionary = maya.postgraduate_work_snapshot()
		_check(
			str(resting_work.get("phase", "")) == "resting"
			and str(resting_work.get("destination", "")) == "journal",
			"Maya takes a human pause between projects instead of working forever"
		)
		maya.set("_destination_id", "journal")
		maya.set("_arrived", true)
		maya.set("_moving", false)
		maya.set("_postgraduate_event_id", "old_logbook")
		maya.call("_show_state", "postgraduate_resting", true)
		_check(
			(maya.get("_bubble_status") as Label).text.contains("短暂休息"),
			"Maya's bubble communicates her quiet tea break with limited sprite art"
		)
		var rest_request: Dictionary = maya.postgraduate_interaction_request()
		_check(
			str(rest_request.get("action", "")) == "rest_chat",
			"Maya's tea break offers a two-way conversation instead of another one-line status"
		)
		var rest_chat: Dictionary = maya.postgraduate_rest_chat_snapshot()
		var rest_topics_value: Variant = rest_chat.get("topics", [])
		var rest_topics: Array = rest_topics_value if rest_topics_value is Array else []
		_check(
			rest_topics.size() == 5
			and str((rest_topics[3] as Dictionary).get("id", "")) == "old_logbook",
			"an event topic and an earned private memory can coexist during Maya's break"
		)
		_check(
			str((rest_topics[4] as Dictionary).get("id", "")) == "first_solo_night",
			"sharing an observation unlocks Maya's first relationship-gated memory"
		)
		room.call("_interact_with_maya")
		_check(room.get("maya_rest_chat_popup") != null, "interacting during the break opens Maya's conversation panel")
		var memory_button := room.find_child("MayaRestTopic_first_solo_night", true, false) as Button
		var rest_close_button := room.find_child("MayaRestConversationCloseButton", true, false) as Button
		_check(
			memory_button != null and rest_close_button != null
			and not memory_button.get_global_rect().intersects(rest_close_button.get_global_rect()),
			"five tea-break topics fit without covering the return button"
		)
		var chat_response := room.find_child("MayaRestConversationResponse", true, false) as Label
		var initial_chat_text := chat_response.text if chat_response != null else ""
		room.call("_choose_maya_rest_topic", "tonight")
		_check(
			chat_response != null and chat_response.text != "" and chat_response.text != initial_chat_text,
			"asking about tonight produces a night-aware reply"
		)
		var night_reply := chat_response.text if chat_response != null else ""
		room.call("_choose_maya_rest_topic", "tea")
		_check(
			chat_response != null and chat_response.text != night_reply,
			"switching topics produces a distinct relationship-aware reply"
		)
		var tea_reply := chat_response.text if chat_response != null else ""
		room.call("_choose_maya_rest_topic", "old_logbook")
		_check(
			chat_response != null and chat_response.text != "" and chat_response.text != tea_reply,
			"the old-logbook event reveals a distinct personal answer"
		)
		var logbook_reply := chat_response.text if chat_response != null else ""
		room.call("_choose_maya_rest_topic", "first_solo_night")
		_check(
			chat_response != null and chat_response.text != "" and chat_response.text != logbook_reply,
			"Maya tells a one-time personal memory instead of another generic tea line"
		)
		var rest_relationship: Dictionary = maya.postgraduate_work_snapshot().get("relationship", {})
		var known_memories_value: Variant = rest_relationship.get("known_private_memories", [])
		var known_memories: Array = known_memories_value if known_memories_value is Array else []
		_check(
			int(rest_relationship.get("rest_conversations", 0)) >= 4
			and int(rest_relationship.get("tea_breaks_shared", 0)) == 1
			and known_memories.has("first_solo_night"),
			"Maya persists shared conversations, tea, and known private memories separately"
		)
		var persisted_memory_relationship: Dictionary = gm.progress.get("maya_postgraduate_relationship", {})
		var persisted_known_value: Variant = persisted_memory_relationship.get("known_private_memories", [])
		_check(
			persisted_known_value is Array
			and (persisted_known_value as Array).has("first_solo_night"),
			"private memories survive beyond the current Maya scene instance"
		)
		_check(
			maya.call("_eligible_unseen_private_memory").is_empty(),
			"Maya does not offer the same one-time memory twice at the familiar stage"
		)
		var memory_echoes: Array = maya.call("_postgraduate_known_memory_lines", true)
		_check(
			not memory_echoes.is_empty(),
			"a private memory returns naturally in Maya's later work chatter"
		)
		room.call("_close_maya_rest_chat")
		_check(room.get("maya_rest_chat_popup") == null, "closing the conversation releases the observatory room")
		maya.set("_free_activity_elapsed", 999.0)
		maya.set("_free_activity_delay", 0.0)
		maya.call("_update_free_activity", 0.1)
		var next_project: Dictionary = maya.postgraduate_work_snapshot()
		_check(
			str(next_project.get("phase", "")) == "assembling"
			and int(next_project.get("cycle", 0)) == int(first_work.get("cycle", 0)) + 1,
			"after resting Maya begins a new persisted observing night"
		)
		_check(
			str(next_project.get("night_id", "")) != project_night,
			"consecutive projects rotate night conditions instead of replaying the same context"
		)
		_check(
			str(next_project.get("event_id", "")) != "old_logbook",
			"a personal night event does not immediately repeat on the next project"
		)
		maya.set("_postgraduate_relationship", {
			"conversations": 12,
			"assembly_assists": 7,
			"observations_joined": 4,
			"observations_completed": 4,
			"rest_conversations": 5,
			"tea_breaks_shared": 3,
			"known_private_memories": ["first_solo_night"],
		})
		var trusted_project: Dictionary = maya.postgraduate_work_snapshot()
		_check(
			str(trusted_project.get("relationship_stage", "")) == "trusted",
			"several shared nights promote Maya's relationship language to trusted night-shift partners"
		)
		var trusted_phase: Dictionary = maya.call("_postgraduate_phase_data")
		_check(
			(trusted_phase.get("trusted_lines_zh", []) as Array).size() >= 2,
			"trusted partners receive phase-specific dialogue instead of only a renamed badge"
		)
		var next_private_memory: Dictionary = maya.call("_eligible_unseen_private_memory")
		_check(
			str(next_private_memory.get("id", "")) == "dome_spare_key",
			"trusted shared nights unlock Maya's spare-dome-key memory in sequence"
		)
		maya.call("_remember_private_memory", "dome_spare_key")
		var future_private_memory: Dictionary = maya.call("_eligible_unseen_private_memory")
		_check(
			str(future_private_memory.get("id", "")) == "next_year_roster",
			"after receiving the dome key, Maya's next private memory looks toward next year's shifts"
		)
		maya.set("_postgraduate_phase", "assembling")
		maya.set("_destination_id", "assembly")
		maya.set("_arrived", true)
		maya.set("_moving", false)
		maya.call("_show_state", "postgraduate_assembling", false)
		maya.set("_player_was_near", false)
		maya.set("_player_has_been_near", false)
		room.set("player_pos", maya.position)
		maya.call("_update_player_behavior")
		_check(
			maya.current_state_id() == "postgraduate_assembling",
			"Maya stays focused when the player merely passes during work"
		)
		maya.set("_bubble_hide_at_msec", 0)
		room.set("player_pos", Vector2(100, 700))
		maya.call("_update_bubble_visibility")
		_check(
			(maya.get("_bubble") as Panel).visible
			and not (maya.get("_bubble_badge") as Panel).visible
			and not (maya.get("_bubble_icon") as Label).visible
			and not (maya.get("_bubble_status") as Label).text.strip_edges().is_empty(),
			"working Maya keeps a readable activity status instead of a symbol badge"
		)
		maya.set("_postgraduate_phase", "resting")
		maya.set("_destination_id", "journal")
		maya.set("_arrived", true)
		maya.set("_moving", false)
		maya.call("_show_state", "postgraduate_resting", false)
		maya.set("_player_was_near", false)
		maya.set("_player_has_been_near", false)
		room.set("player_pos", maya.position)
		maya.call("_update_player_behavior")
		var free_near_state: Dictionary = (maya.get("_dialogue_states") as Dictionary).get("free_near", {})
		var free_near_lines: Array = free_near_state.get("lines_zh", [])
		_check(
			maya.current_state_id() == "postgraduate_resting"
			and not free_near_lines.is_empty()
			and (maya.get("_bubble_line") as Label).text == str(free_near_lines[0]),
			"resting Maya notices the player without losing her rest status"
		)
		room.set("player_pos", Vector2(100, 700))
		maya.call("_update_player_behavior")
		_check(
			maya.current_state_id() == "postgraduate_resting",
			"resting Maya keeps her real phase after the player leaves"
		)
		gm.progress["graduation_seen"] = prior_graduated
		gm.progress["program_completed"] = prior_program_completed
		if prior_work_value == null:
			gm.progress.erase("maya_postgraduate_work")
		else:
			gm.progress["maya_postgraduate_work"] = prior_work_value
		if prior_relationship_value == null:
			gm.progress.erase("maya_postgraduate_relationship")
		else:
			gm.progress["maya_postgraduate_relationship"] = prior_relationship_value
		if prior_presence_value == null:
			gm.progress.erase("maya_postgraduate_presence")
		else:
			gm.progress["maya_postgraduate_presence"] = prior_presence_value
		if prior_observation_roam_value == null:
			gm.progress.erase("maya_observation_hall_roam")
		else:
			gm.progress["maya_observation_hall_roam"] = prior_observation_roam_value
		gm.room_guidance_target = prior_postgraduate_room_guidance

	var legacy_card := room.find_child("MayaRoomGuidancePortrait", true, false)
	_check(legacy_card != null, "legacy route data remains available")
	if legacy_card != null:
		var legacy_panel := legacy_card.get_parent()
		_check(not legacy_panel.visible, "large legacy guidance card no longer covers Maya")

	var preserved_position := Vector2(620, 330)
	maya.position = preserved_position
	maya.call("_set_facing", "right")
	room.call("_remember_maya_pose")
	room.queue_free()
	await process_frame

	var prior_observation: Dictionary = gm.last_observation.duplicate(true)
	gm.last_observation = {"target_id": "moon", "quality": "excellent"}
	gm.set_observatory_spawn("journal")
	var returned_room := (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(returned_room)
	await process_frame
	await process_frame
	var returned_maya := returned_room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	_check(returned_maya != null, "Maya remains present after returning from another screen")
	if returned_maya != null:
		_check(returned_maya.position.distance_to(preserved_position) < 0.1, "Maya returns to her exact pre-transition position")
		_check(returned_maya.current_facing() == "right", "Maya returns with her exact pre-transition facing")
		_check(returned_maya.current_state_id() == "journal_saved", "journal return remembers that the result was filed")
	returned_room.queue_free()
	await process_frame
	var companion_prior_graduated := bool(gm.progress.get("graduation_seen", false))
	var companion_prior_program_completed := bool(gm.progress.get("program_completed", false))
	var companion_prior_work: Variant = gm.progress.get("maya_postgraduate_work", null)
	var companion_prior_relationship: Variant = gm.progress.get("maya_postgraduate_relationship", null)
	var companion_prior_context: Dictionary = gm.local_optical_observation_context.duplicate(true)
	var companion_prior_serial := int(gm.observation_result_serial)
	var companion_prior_guidance := str(gm.room_guidance_target)
	gm.progress["program_completed"] = true
	gm.progress["graduation_seen"] = true
	gm.progress["maya_postgraduate_work"] = {
		"phase": "observing",
		"target_id": "jupiter",
		"instrument_id": "refractor_80",
		"night_id": "clear_stable",
		"assembly_progress": 3,
		"cycle": 7,
	}
	gm.progress["maya_postgraduate_relationship"] = {
		"conversations": 2,
		"assembly_assists": 3,
		"observations_joined": 1,
		"observations_completed": 0,
	}
	gm.observation_result_serial = companion_prior_serial + 1
	gm.last_observation = {
		"result_serial": gm.observation_result_serial,
		"object_id": "jupiter",
		"object_name_en": "Jupiter",
		"object_name_zh": "木星",
		"quality": "Good",
	}
	gm.local_optical_observation_context = {
		"active": true,
		"companion": "maya",
		"companion_target_id": "jupiter",
		"started_observation_serial": companion_prior_serial,
		"companion_instrument_id": "refractor_80",
		"companion_instrument_name_en": "80 mm refractor",
		"companion_instrument_name_zh": "80 毫米折射镜",
	}
	gm.room_guidance_target = ""
	gm.clear_maya_observatory_return_pose()
	gm.set_observatory_spawn("telescope")
	var companion_return_room := (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(companion_return_room)
	await process_frame
	await process_frame
	var companion_return_maya := companion_return_room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	_check(companion_return_maya != null, "Maya is present when a shared eyepiece session returns to the hall")
	if companion_return_maya != null:
		var companion_return_work: Dictionary = companion_return_maya.postgraduate_work_snapshot()
		_check(
			str(companion_return_work.get("phase", "")) == "recording",
			"an actual shared result moves Maya from observing to recording immediately"
		)
		_check(
			companion_return_maya.current_state_id() == "postgraduate_observation_return"
			and (companion_return_maya.get("_bubble_status") as Label).text.contains("共同观测完成"),
			"Maya acknowledges the exact shared observation instead of replaying generic work chatter"
		)
		var companion_return_relationship: Dictionary = companion_return_work.get("relationship", {})
		_check(
			int(companion_return_relationship.get("observations_completed", 0)) == 1,
			"Maya distinguishes a completed observing night from merely accepting her invitation"
		)
	_check(gm.local_optical_observation_context.is_empty(), "the consumed companion session cannot replay on a later hall visit")
	companion_return_room.queue_free()
	gm.progress["program_completed"] = companion_prior_program_completed
	gm.progress["graduation_seen"] = companion_prior_graduated
	if companion_prior_work == null:
		gm.progress.erase("maya_postgraduate_work")
	else:
		gm.progress["maya_postgraduate_work"] = companion_prior_work
	if companion_prior_relationship == null:
		gm.progress.erase("maya_postgraduate_relationship")
	else:
		gm.progress["maya_postgraduate_relationship"] = companion_prior_relationship
	gm.local_optical_observation_context = companion_prior_context
	gm.observation_result_serial = companion_prior_serial
	gm.room_guidance_target = companion_prior_guidance
	gm.last_observation = prior_observation
	gm.progress["current_level"] = prior_level
	gm.progress["graduation_seen"] = prior_graduated
	gm.progress["program_completed"] = prior_program_completed
	gm.language_mode = prior_language
	gm.clear_maya_observatory_return_pose()
	await process_frame
	if failures.is_empty():
		print("MAYA HALL NPC TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)


func _check_postgraduate_bubble_copy() -> void:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/maya_npc_dialogue.json")
	)
	_check(parsed is Dictionary, "the unified Maya dialogue file parses as UTF-8 JSON")
	if not parsed is Dictionary:
		return
	var routine_value: Variant = (parsed as Dictionary).get("postgraduate", {})
	var routine_data: Dictionary = routine_value if routine_value is Dictionary else {}
	_check(not routine_data.is_empty(), "the unified Maya dialogue file contains postgraduate copy")
	var violations: Array[String] = []
	for section_id in [
		"target_lines",
		"night_profiles",
		"time_lines",
		"observation_return",
		"return_reactions",
		"interruptions",
		"workbench_walkaway",
		"phases",
	]:
		_collect_bubble_line_violations(
			routine_data.get(section_id, {}),
			section_id,
			violations
		)
	for event_value in routine_data.get("night_events", []):
		if not event_value is Dictionary:
			continue
		var event: Dictionary = event_value
		var event_path := "night_events.%s" % str(event.get("id", "unknown"))
		for line_key in ["lines_en", "lines_zh"]:
			var event_lines: Array = event.get(line_key, [])
			var limit := 22 if line_key == "lines_zh" else 60
			for line_value in event_lines:
				if str(line_value).length() > limit:
					violations.append("%s.%s: %s" % [event_path, line_key, str(line_value)])
	for memory_value in routine_data.get("private_memories", []):
		if not memory_value is Dictionary:
			continue
		var memory: Dictionary = memory_value
		_collect_bubble_line_violations(
			memory.get("echoes", {}),
			"private_memories.%s.echoes" % str(memory.get("id", "unknown")),
			violations
		)
	_check(
		violations.is_empty(),
		"all postgraduate thought-bubble lines fit without truncation%s" % (
			"" if violations.is_empty() else ": " + " | ".join(violations)
		)
	)


func _collect_bubble_line_violations(
	node: Variant,
	path: String,
	violations: Array[String]
) -> void:
	if node is Dictionary:
		var data: Dictionary = node
		for key_value in data.keys():
			var key := str(key_value)
			var value: Variant = data[key_value]
			var is_english_lines := key == "lines_en" or key.ends_with("_lines_en")
			var is_chinese_lines := key == "lines_zh" or key.ends_with("_lines_zh")
			if (is_english_lines or is_chinese_lines) and value is Array:
				var limit := 22 if is_chinese_lines else 60
				for line_value in value:
					if str(line_value).length() > limit:
						violations.append("%s.%s: %s" % [path, key, str(line_value)])
			elif value is Dictionary or value is Array:
				_collect_bubble_line_violations(value, "%s.%s" % [path, key], violations)
	elif node is Array:
		var values: Array = node
		for index in range(values.size()):
			_collect_bubble_line_violations(values[index], "%s[%d]" % [path, index], violations)
