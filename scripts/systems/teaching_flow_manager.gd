extends Node

# Teaching Flow State Machine.
#
# Centralizes the "concept brief before an action -> action -> mission
# complete review -> journal unlock" loop. UI scenes never decide by
# themselves whether a teaching card should appear; they call
# GameManager.try_teaching_intercept(trigger, return_scene) at the few
# entry points (observation pad, assembly table, observe button) and this
# manager decides from level data.
#
# Data model (levels.json):
#   "teaching_steps": [
#     {"id": "focus_intro", "card_id": "focus_focal_plane",
#      "trigger": "before_focus", "mode": "brief", "required_once": true}
#   ]
# Levels without teaching_steps but with required_concept_card get one
# auto-generated fallback step (see _fallback_steps).
#
# Bookkeeping separation (in progress):
#   seen_teaching_steps    - step ids the player has SEEN (brief shown)
#   seen_concept_briefs    - card ids seen as briefs (derived convenience)
#   completed_concept_cards- ONLY written by complete_current_mission;
#                            a brief seen is NOT a journal unlock.

const KNOWN_TRIGGERS := [
	"before_observation",
	"before_assembly",
	"before_focus",
	"before_identify",
	"before_collimation"
]

var active_card_mode := ""
var active_card_id := ""
var active_step_id := ""
var active_trigger := ""
var return_scene_key := ""
var return_trigger_key := ""
var return_payload: Dictionary = {}


# ------------------------------------------------------------------ queries


func get_steps_for_level(level: Dictionary) -> Array:
	var steps: Array = level.get("teaching_steps", [])
	if not steps.is_empty():
		return steps
	return _fallback_steps(level)


func _fallback_steps(level: Dictionary) -> Array:
	# Backwards compatibility: derive one brief from required_concept_card.
	var card_id := str(level.get("required_concept_card", ""))
	if card_id == "":
		return []
	var trigger := "before_assembly"
	var story_manager: Node = get_node_or_null("/root/StoryManager")
	var registered_trigger := ""
	var level_number := int(level.get("level_number", 0))
	if level_number > 0 and story_manager != null and story_manager.has_method("skill_trigger_for_card"):
		registered_trigger = str(story_manager.skill_trigger_for_card(
			card_id,
			level_number
		))
	if registered_trigger != "":
		trigger = registered_trigger
	elif str(level.get("observation_mode", "")) == "naked_eye":
		trigger = "before_observation"
	elif bool(level.get("requires_focus", false)):
		trigger = "before_focus"
	return [{
		"id": "auto_" + card_id,
		"card_id": card_id,
		"trigger": trigger,
		"mode": "brief",
		"required_once": true
	}]


func get_pending_step(level: Dictionary, trigger: String, progress: Dictionary) -> Dictionary:
	var seen: Array = progress.get("seen_teaching_steps", [])
	var seen_cards: Array = progress.get("seen_concept_briefs", [])
	var completed_cards: Array = progress.get("completed_concept_cards", [])
	for step_value in get_steps_for_level(level):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if str(step.get("trigger", "")) != trigger:
			continue
		var card_id: String = str(step.get("card_id", ""))
		if card_id != "" and completed_cards.has(card_id):
			continue
		if card_id != "" and seen_cards.has(card_id):
			continue
		if bool(step.get("required_once", true)) and seen.has(str(step.get("id", ""))):
			continue
		return step
	return {}


func should_intercept(level: Dictionary, trigger: String, progress: Dictionary) -> bool:
	return not get_pending_step(level, trigger, progress).is_empty()


# ------------------------------------------------------------------- routing


func begin_step(level: Dictionary, trigger: String, scene_key: String, payload: Dictionary = {}) -> bool:
	# Interrupt the requested navigation with a concept brief, remembering
	# where to continue afterwards. Never touches selected_object_id,
	# sky data or current_level.
	var gm := _game_manager()
	if gm == null or not gm.uses_full_tutorials():
		return false
	var step := get_pending_step(level, trigger, gm.progress)
	if step.is_empty():
		return false
	var card_id: String = str(step.get("card_id", ""))
	if card_id == "" or gm.get_learning_card(card_id).is_empty():
		return false
	active_card_mode = str(step.get("mode", "brief"))
	active_card_id = card_id
	active_step_id = str(step.get("id", ""))
	active_trigger = trigger
	return_scene_key = scene_key
	return_trigger_key = trigger
	return_payload = payload
	gm.go("card")
	return true


func show_brief(card_id: String, scene_key: String, payload: Dictionary = {}) -> bool:
	if card_id == "":
		return false
	var gm := _game_manager()
	if gm == null or gm.get_learning_card(card_id).is_empty():
		return false
	active_card_mode = "brief"
	active_card_id = card_id
	active_step_id = "manual_" + card_id
	active_trigger = "manual"
	return_scene_key = scene_key
	return_trigger_key = "manual"
	return_payload = payload
	gm.go("card")
	return true


func complete_active_brief(progress: Dictionary) -> void:
	# Mark the step as seen. Deliberately does NOT touch
	# completed_concept_cards - that is a mission-completion reward.
	if active_step_id != "":
		if not progress.has("seen_teaching_steps"):
			progress["seen_teaching_steps"] = []
		if not progress["seen_teaching_steps"].has(active_step_id):
			progress["seen_teaching_steps"].append(active_step_id)
	if active_card_id != "":
		if not progress.has("seen_concept_briefs"):
			progress["seen_concept_briefs"] = []
		if not progress["seen_concept_briefs"].has(active_card_id):
			progress["seen_concept_briefs"].append(active_card_id)
	active_card_mode = ""
	active_card_id = ""
	active_step_id = ""
	active_trigger = ""


func consume_return_scene() -> String:
	# The brief was triggered by the player interacting with the right
	# device (or pressing Observe), so afterwards we continue STRAIGHT to
	# that destination. Only intro / mission-complete transitions route
	# through the observatory with room guidance.
	var scene := return_scene_key
	return_scene_key = ""
	return_trigger_key = ""
	return_payload = {}
	if scene == "":
		scene = "observatory"
	return scene


func make_mission_complete_payload(level: Dictionary, object: Dictionary, observation: Dictionary, stats: Dictionary) -> Dictionary:
	var gm := _game_manager()
	var concept: Dictionary = {}
	if gm != null:
		concept = gm.get_learning_card(str(level.get("required_concept_card", "")))
	var story_manager: Node = get_node_or_null("/root/StoryManager")
	var recap: Dictionary = {}
	if story_manager != null:
		recap = story_manager.recap_for_level(int(level.get("level_number", 0)))
	return {
		"object": object,
		"level": level,
		"observation": observation,
		"stats": stats,
		"concept_card": concept,
		"maya_recap_en": str(recap.get("en", "")),
		"maya_recap_zh": str(recap.get("zh", ""))
	}


func show_mission_complete(payload: Dictionary) -> void:
	active_card_mode = "complete"
	active_card_id = ""
	active_step_id = ""
	active_trigger = ""
	var gm := _game_manager()
	if gm != null:
		gm.last_learning_card = payload
		gm.go("card")


func acknowledge_card_shown() -> void:
	# Called by the learning card scene once a "complete" card is displayed,
	# so a stale mode never leaks into the next visit.
	if active_card_mode == "complete":
		active_card_mode = ""


func reset_flow() -> void:
	active_card_mode = ""
	active_card_id = ""
	active_step_id = ""
	active_trigger = ""
	return_scene_key = ""
	return_trigger_key = ""
	return_payload = {}


func _game_manager() -> Node:
	return get_node_or_null("/root/GameManager")
