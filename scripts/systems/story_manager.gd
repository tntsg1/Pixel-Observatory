extends Node

# Story Manager - Astronomy Club narrative layer.
#
# Plays short Maya dialogues at key moments (new game intro, before an
# observation / assembly / focus session, and recap lines on the Mission
# Complete card). Works IN FRONT of TeachingFlowManager: an entry point
# first asks for a story intercept, and when the dialogue finishes this
# manager chains into the teaching intercept for the same trigger, so the
# order is always  story -> concept brief -> gameplay scene.
#
# Bookkeeping: progress["seen_story_events"] stores event ids; an event
# never replays.

const DIALOGUES_PATH := "res://data/story_dialogues.json"
const EXPANSION_DIALOGUES_PATH := "res://data/expansion/story_dialogues.json"
const REVISIONS_PATH := "res://data/story_revisions.json"
const NARRATIVE_PATH := "res://data/story_narrative.json"
const SKILL_TUTORIALS_PATH := "res://data/maya_skill_tutorials.json"
const SKILL_EVENT_PREFIX := "maya_skill_"

# Events are found by naming convention against the loaded dialogue data:
#   before_observation -> "level_N_before"
#   before_assembly    -> "level_N_before_assembly"
#   before_focus       -> "level_N_before_focus"
# A level has a story for a trigger exactly when that key exists in
# story_dialogues.json - no hardcoded per-level table to maintain.
const TRIGGER_SUFFIXES := {
	"before_observation": "level_%d_before",
	"before_assembly": "level_%d_before_assembly",
	"before_focus": "level_%d_before_focus"
}

# Semantic mechanic name -> first-time story event. UI scenes ask by mechanic
# name; they never hardcode event ids.
const MECHANIC_EVENTS := {
	"tube_subassembly": "first_tube_subassembly",
	"collimation": "first_collimation"
}

# Levels whose "level_N_after" lines play as a short epilogue dialogue after
# the Mission Complete card (L25+ family arcs). L1-24 keep recap-only behavior.
const EPILOGUE_MIN_LEVEL := 25

var dialogues: Dictionary = {}
var narrative: Dictionary = {}
var skill_tutorials: Dictionary = {}
var active_event_id := ""
var active_event_ids: Array = []
var active_lines: Array = []
var active_context: Dictionary = {}
var return_scene_key := ""
var pending_trigger := ""


func _ready() -> void:
	dialogues = _load_json_dict(DIALOGUES_PATH)
	var expansion := _load_json_dict(EXPANSION_DIALOGUES_PATH)
	_merge_dialogue_pack(expansion)
	# Story revisions are intentionally loaded last. They replace only the
	# chapter-spine moments whose causal handoff changed, while preserving the
	# target-specific science dialogue already authored for every other level.
	_merge_dialogue_pack(_load_json_dict(REVISIONS_PATH))
	narrative = _load_json_dict(NARRATIVE_PATH)
	_load_skill_tutorials()


# ------------------------------------------------------------------ queries


func get_dialogue(event_id: String) -> Array:
	if event_id.begins_with(SKILL_EVENT_PREFIX):
		return _skill_dialogue(event_id.trim_prefix(SKILL_EVENT_PREFIX))
	var lines: Variant = dialogues.get(event_id, [])
	if lines is Array and not lines.is_empty():
		return lines
	return _advanced_fallback_dialogue(event_id)


func skill_tutorial(skill_id: String) -> Dictionary:
	var tutorial: Variant = skill_tutorials.get(skill_id, {})
	if tutorial is Dictionary:
		return tutorial
	return {}


func skill_event_id(skill_id: String) -> String:
	return SKILL_EVENT_PREFIX + skill_id if skill_id != "" else ""


func skill_trigger_for_card(card_id: String, level_number: int = 0) -> String:
	# TeachingFlowManager uses this query so Maya's explanation and the visual
	# concept brief always interrupt at the same real gameplay doorway.
	for skill_value in skill_tutorials.values():
		if not skill_value is Dictionary:
			continue
		var skill: Dictionary = skill_value
		if str(skill.get("concept_card", "")) != card_id:
			continue
		if level_number > 0 and int(skill.get("level", 0)) != level_number:
			continue
		return str(skill.get("trigger", ""))
	return ""


func pending_skill_events(trigger: String, level_number: int, progress: Dictionary) -> Array:
	var pending: Array = []
	for skill_id_value in skill_tutorials:
		var skill_id := str(skill_id_value)
		var skill: Dictionary = skill_tutorial(skill_id)
		if int(skill.get("level", 0)) != level_number:
			continue
		if str(skill.get("trigger", "")) != trigger:
			continue
		var event_id := skill_event_id(skill_id)
		if not has_seen(event_id, progress):
			pending.append(event_id)
	return pending


func _skill_dialogue(skill_id: String) -> Array:
	var skill := skill_tutorial(skill_id)
	if skill.is_empty():
		return []
	var image_path := ""
	var gm := _game_manager()
	if gm != null:
		var card: Dictionary = gm.get_learning_card(str(skill.get("concept_card", "")))
		image_path = str(card.get("image", ""))
	var result: Array = []
	var phases := [
		["why_en", "why_zh"],
		["action_en", "action_zh"],
		["success_en", "success_zh"],
		["recovery_en", "recovery_zh"]
	]
	for phase_index in range(phases.size()):
		var keys: Array = phases[phase_index]
		var line := {
			"speaker": "Maya",
			"portrait": "maya",
			"text_en": str(skill.get(str(keys[0]), "")),
			"text_zh": str(skill.get(str(keys[1]), ""))
		}
		if phase_index == 1 and image_path != "" and ResourceLoader.exists(image_path):
			line["image"] = image_path
		result.append(line)
	return result


func _advanced_fallback_dialogue(event_id: String) -> Array:
	if not event_id.begins_with("level_"):
		return []
	var gm := _game_manager()
	if gm == null:
		return []
	var family := str(gm.current_level().get("telescope_family", ""))
	var target: String = str(gm.dict_text(gm.current_target(), "name"))
	var line_en := ""
	var line_zh := ""
	match family:
		"newtonian":
			line_en = "This reflector uses mirrors in a new light path. Build it in order, then align it before Orion."
			line_zh = "这台反射镜使用新的光路。按顺序组装，再为猎户座完成准直。"
		"dobsonian":
			line_en = "A Dobsonian is simple and bright, but your hands provide the tracking. Use gentle corrections."
			line_zh = "多布森结构简单而明亮，但追踪要靠你的双手。请使用轻微修正。"
		"cassegrain":
			line_en = "This compact tube folds a long focal length with two mirrors. The narrow view rewards careful aiming."
			line_zh = "这台紧凑镜筒用两面镜子折叠长焦距，狭窄视场需要更仔细地对准。"
		"gregorian":
			line_en = "This two-mirror layout is not a power upgrade. Trace where the light focuses and compare it deliberately."
			line_zh = "这套双镜布局不是单纯性能升级。追踪光线在哪里聚焦，再有目的地比较它。"
		"space_segmented":
			line_en = "A segmented mirror and cold infrared instruments reveal signals that visible light misses."
			line_zh = "分段主镜和低温红外仪器能揭示可见光错过的信号。"
		"fast_radio":
			line_en = "This time there is no eyepiece image. A dish, receiver, and data trace will guide you to the source."
			line_zh = "这次没有目镜图像。天线、接收机和数据轨迹会引导你找到目标。"
		"multi_device":
			line_en = "Choose the observatory that measures the signal needed for " + target + "."
			line_zh = "请选择能测量 " + target + " 所需信号的观测台。"
		_:
			return []
	return [{"speaker": "Maya", "portrait": "maya", "text_en": line_en, "text_zh": line_zh}]


func has_seen(event_id: String, progress: Dictionary) -> bool:
	return progress.get("seen_story_events", []).has(event_id)


func event_for_trigger(trigger: String, level_number: int) -> String:
	var pattern := str(TRIGGER_SUFFIXES.get(trigger, ""))
	if pattern == "":
		return ""
	var event_id := pattern % level_number
	if dialogues.has(event_id):
		return event_id
	return ""


func recap_for_level(level_number: int) -> Dictionary:
	# First line of "level_N_after" becomes Maya's recap on Mission Complete.
	var lines := get_dialogue("level_%d_after" % level_number)
	if lines.is_empty() or not lines[0] is Dictionary:
		return {}
	var line: Dictionary = lines[0]
	return {
		"en": str(line.get("text_en", "")),
		"zh": str(line.get("text_zh", ""))
	}


func board_note_for_level(level_number: int) -> Dictionary:
	var notes: Dictionary = dialogues.get("board_notes", {})
	var note: Variant = notes.get(str(level_number), {})
	if note is Dictionary:
		return note
	return {}


func context_for_event(event_id: String) -> Dictionary:
	var gm := _game_manager()
	if gm == null:
		return {}
	var skill: Dictionary = {}
	if event_id.begins_with(SKILL_EVENT_PREFIX):
		skill = skill_tutorial(event_id.trim_prefix(SKILL_EVENT_PREFIX))
	var level_number := _event_level_number(event_id)
	if event_id == "intro":
		level_number = 1
	elif not skill.is_empty():
		level_number = int(skill.get("level", 0))
	if level_number <= 0:
		level_number = int(gm.current_level().get("level_number", 0))
	var narrative_level: Dictionary = gm.current_level()
	var mission_manager := _mission_manager()
	if mission_manager != null and mission_manager.has_method("get_level"):
		var event_level: Dictionary = mission_manager.get_level(level_number)
		if not event_level.is_empty():
			narrative_level = event_level
	var chapter := _chapter_for_level(level_number)
	var locations: Dictionary = narrative.get("locations", {})
	var event_routes: Dictionary = narrative.get("event_routes", {})
	var override: Dictionary = event_routes.get(event_id, {})
	var from_id := str(override.get("from", "mission_board"))
	var to_id := str(override.get("to", "observation_pad"))
	var phase := "before"
	if event_id == "intro":
		phase = "intro"
	elif event_id.ends_with("_after"):
		phase = "after"
		from_id = _observation_location_for_level(narrative_level)
		to_id = "club_logbook"
	elif event_id.contains("before_assembly"):
		from_id = "mission_board"
		to_id = "assembly_table"
	elif event_id.contains("before_focus"):
		from_id = "assembly_table"
		to_id = "observation_pad"
	elif event_id.begins_with("first_"):
		phase = "mechanic"
	elif not skill.is_empty():
		phase = "mechanic"
		match str(skill.get("trigger", "")):
			"before_assembly":
				from_id = "mission_board"
				to_id = "assembly_table"
			"before_collimation":
				from_id = "assembly_table"
				to_id = "collimation_bench"
			"before_identify", "before_focus", "before_observation":
				from_id = "mission_board"
				to_id = _observation_location_for_level(narrative_level)
	elif event_id.contains("_before"):
		from_id = "mission_board"
		to_id = _observation_location_for_level(narrative_level)

	var from_info: Dictionary = locations.get(from_id, {})
	var to_info: Dictionary = locations.get(to_id, {})
	var reason_en := str(chapter.get("cause_en", "Tonight's result follows from the previous observation."))
	if not skill.is_empty():
		reason_en = str(skill.get("why_en", reason_en))
	var reason_zh := str(chapter.get("cause_zh", "今晚的任务来自上一项观测留下的问题。"))
	if not skill.is_empty():
		reason_zh = str(skill.get("why_zh", reason_zh))
	if phase == "after":
		reason_en = str(chapter.get("proof_en", reason_en))
		reason_zh = str(chapter.get("proof_zh", reason_zh))
	var action_en := str(override.get("action_en", ""))
	var action_zh := str(override.get("action_zh", ""))
	if not skill.is_empty():
		action_en = str(skill.get("action_en", action_en))
		action_zh = str(skill.get("action_zh", action_zh))
	if action_en == "":
		if phase == "after":
			action_en = "Record the evidence, then use the Mission Board to begin the next question."
			action_zh = "先记录证据，再通过任务板开始下一个问题。"
		else:
			action_en = "Continue at the " + str(to_info.get("name_en", to_id.capitalize())) + "."
			action_zh = "前往" + str(to_info.get("name_zh", to_id)) + "继续。"
	return {
		"event_id": event_id,
		"level_number": level_number,
		"phase": phase,
		"chapter_id": str(chapter.get("id", "")),
		"chapter_en": str(skill.get("title_en", chapter.get("title_en", "Astronomy Club"))),
		"chapter_zh": str(skill.get("title_zh", chapter.get("title_zh", "天文俱乐部"))),
		"reason_en": reason_en,
		"reason_zh": reason_zh,
		"from_id": from_id,
		"from_en": str(from_info.get("name_en", from_id.capitalize())),
		"from_zh": str(from_info.get("name_zh", from_id)),
		"to_id": to_id,
		"to_en": str(to_info.get("name_en", to_id.capitalize())),
		"to_zh": str(to_info.get("name_zh", to_id)),
		"action_en": action_en,
		"action_zh": action_zh
	}


# ------------------------------------------------------------------- routing


func begin_event(event_id: String, scene_key: String, follow_trigger: String = "") -> bool:
	return _begin_events([event_id], scene_key, follow_trigger)


func _begin_events(event_ids: Array, scene_key: String, follow_trigger: String = "") -> bool:
	var gm := _game_manager()
	if gm == null:
		return false
	var playable_ids: Array = []
	var combined_lines: Array = []
	var context_event_id := ""
	for event_id_value in event_ids:
		var event_id := str(event_id_value)
		if event_id == "" or has_seen(event_id, gm.progress):
			continue
		var lines := get_dialogue(event_id)
		if lines.is_empty():
			continue
		playable_ids.append(event_id)
		combined_lines.append_array(lines)
		if context_event_id == "" or event_id.begins_with(SKILL_EVENT_PREFIX):
			context_event_id = event_id
	if playable_ids.is_empty():
		return false
	active_event_ids = playable_ids
	active_event_id = str(playable_ids[0])
	active_lines = combined_lines
	active_context = context_for_event(context_event_id)
	return_scene_key = scene_key
	pending_trigger = follow_trigger
	gm.go("story")
	return true


func begin_mechanic_event(mechanic: String, scene_key: String, follow_trigger: String = "") -> bool:
	# First-time introduction for a game mechanic (tube sub-assembly,
	# collimation, ...). Replays never happen thanks to seen_story_events.
	var gm := _game_manager()
	if gm == null:
		return false
	var event_ids: Array = [str(MECHANIC_EVENTS.get(mechanic, ""))]
	if follow_trigger != "":
		var level_number := int(gm.current_level().get("level_number", 0))
		event_ids.append_array(pending_skill_events(follow_trigger, level_number, gm.progress))
	return _begin_events(event_ids, scene_key, follow_trigger)


func begin_epilogue(level_number: int, scene_key: String) -> bool:
	# Post-mission Maya dialogue for advanced levels: summary + motivation for
	# the next stage. The same lines' first entry stays the recap on the
	# Mission Complete card.
	if level_number < EPILOGUE_MIN_LEVEL:
		return false
	return begin_event("level_%d_after" % level_number, scene_key)


func begin_event_for_trigger(trigger: String, scene_key: String) -> bool:
	var gm := _game_manager()
	if gm == null:
		return false
	var level_number: int = int(gm.current_level().get("level_number", 0))
	var event_ids: Array = [event_for_trigger(trigger, level_number)]
	event_ids.append_array(pending_skill_events(trigger, level_number, gm.progress))
	return _begin_events(event_ids, scene_key, trigger)


func finish_active_event() -> void:
	# Mark seen, then hand over to the teaching flow (concept brief) or go
	# straight to the stored scene.
	var gm := _game_manager()
	if gm == null:
		return
	if not active_event_ids.is_empty():
		if not gm.progress.has("seen_story_events"):
			gm.progress["seen_story_events"] = []
		for event_id_value in active_event_ids:
			var event_id := str(event_id_value)
			if event_id != "" and not gm.progress["seen_story_events"].has(event_id):
				gm.progress["seen_story_events"].append(event_id)
	var completed_event_id := active_event_id
	var completed_context := active_context.duplicate(true)
	var scene := return_scene_key
	var trigger := pending_trigger
	active_event_id = ""
	active_event_ids = []
	active_lines = []
	active_context = {}
	return_scene_key = ""
	pending_trigger = ""
	if scene == "":
		scene = "observatory"
	gm.save()
	# Device-triggered stories continue straight into the destination the
	# player already chose; only the intro routes through the observatory
	# with room guidance.
	if completed_event_id == "intro":
		gm.set_room_guidance(
			"telescope",
			gm.text("Maya: Observation Pad", "玛雅：观测台"),
			gm.text(
				str(completed_context.get("action_en", "Walk to the Observation Pad and press E.")),
				str(completed_context.get("action_zh", "前往观测台并按 E。"))
			)
		)
	if trigger != "" and gm.try_teaching_intercept(trigger, scene):
		return
	if scene == "observatory" and completed_event_id != "intro":
		gm.update_room_guidance_for_level()
	gm.go(scene)


func reset_flow() -> void:
	active_event_id = ""
	active_event_ids = []
	active_lines = []
	active_context = {}
	return_scene_key = ""
	pending_trigger = ""


func _game_manager() -> Node:
	return get_node_or_null("/root/GameManager")


func _mission_manager() -> Node:
	return get_node_or_null("/root/MissionManager")


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _load_skill_tutorials() -> void:
	skill_tutorials.clear()
	var pack := _load_json_dict(SKILL_TUTORIALS_PATH)
	for skill_value in pack.get("skills", []):
		if not skill_value is Dictionary:
			continue
		var skill: Dictionary = skill_value
		var skill_id := str(skill.get("id", ""))
		if skill_id == "":
			continue
		skill_tutorials[skill_id] = skill


func _merge_dialogue_pack(pack: Dictionary) -> void:
	for event_id in pack:
		# Supplemental dialogue packs may contribute board notes without
		# replacing the base campaign's note map.
		if event_id == "board_notes" and dialogues.get("board_notes") is Dictionary and pack[event_id] is Dictionary:
			var merged: Dictionary = dialogues["board_notes"]
			for note_key in pack[event_id]:
				merged[note_key] = pack[event_id][note_key]
			dialogues["board_notes"] = merged
		else:
			dialogues[event_id] = pack[event_id]


func _event_level_number(event_id: String) -> int:
	if not event_id.begins_with("level_"):
		return 0
	var remainder := event_id.trim_prefix("level_")
	return int(remainder.get_slice("_", 0))


func _chapter_for_level(level_number: int) -> Dictionary:
	var chapters: Array = narrative.get("chapters", [])
	for chapter_value in chapters:
		if not chapter_value is Dictionary:
			continue
		var chapter: Dictionary = chapter_value
		if level_number >= int(chapter.get("min_level", 0)) and level_number <= int(chapter.get("max_level", 0)):
			return chapter
	return {}


func _observation_location_for_level(level: Dictionary) -> String:
	match str(level.get("telescope_family", "")):
		"space_segmented":
			return "space_console"
		"fast_radio":
			return "radio_console"
		_:
			return "observation_pad"
