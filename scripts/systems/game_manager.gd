extends Node

signal progress_changed
signal language_changed
signal tutorial_assistance_changed(mode: String)
signal pulse_capture_assistance_changed(enabled: bool)

const LocalizationScript := preload("res://scripts/systems/localization.gd")
const TelescopeMathScript := preload("res://scripts/systems/telescope_math.gd")
const AssemblyManagerScript := preload("res://scripts/systems/assembly_manager.gd")
const ObservationSystemScript := preload("res://scripts/systems/observation_system.gd")
const DEVELOPER_CONSOLE_SCRIPT_PATH := "res://scripts/ui/developer_console.gd"
const ADVANCED_LEVELS_PATH := "res://data/advanced_levels.json"
const ADVANCED_PARTS_PATH := "res://data/advanced_telescope_parts.json"
const EXPANSION_DIR := "res://data/expansion/"
const REMOTE_FREE_CATALOG_PATH := "res://data/remote_free_observation_catalog.json"
const CAMPAIGN_VERSION := 94
const FINAL_CAMPAIGN_LEVEL := 85
const RETIRED_POST_FAST_LEVEL := 86
const FREE_OBSERVATION_CREDITS := 5
const TUTORIAL_ASSIST_FULL := "full"
const TUTORIAL_ASSIST_LIGHT := "light"
const TUTORIAL_ASSIST_FREE := "free"
const TUTORIAL_ASSIST_MODES := [
	TUTORIAL_ASSIST_FULL,
	TUTORIAL_ASSIST_LIGHT,
	TUTORIAL_ASSIST_FREE,
]
const SPACE_SEGMENTED_INSTALL_ORDER := [
	"primary_mirror",
	"secondary_mirror",
	"detector",
	"sunshield",
	"spacecraft_bus",
	"deployable_tower",
	"deployment_hinges",
	"solar_array",
	"antenna",
	"radiator",
	"steering_mirror",
	"tertiary_mirror",
	"instrument_bay",
	"detector_module",
	"nircam",
	"nirspec",
	"miri",
	"fgs_niriss",
]
const SPACE_INSTRUMENT_PART_TYPES := {
	"nircam": "nircam",
	"nirspec": "nirspec",
	"miri": "miri",
	"fgs_niriss": "fgs_niriss",
}
# The first chapter teaches the room, naked-eye aiming, refractor assembly,
# focus, magnification and the finder. These supervised sessions are scheduled
# for a real time when the lesson target is above the club's home horizon, so a
# new player is not diverted into the site-map system before L11.
const FOUNDATION_TRAINING_MAX_LEVEL := 10
const BADGE_NAMES_ZH := {
	"First Look": "初见星空",
	"Star Spotter": "寻星者",
	"First Light": "第一缕星光",
	"Sharp Eye": "锐眼",
	"Power User": "倍率掌握者",
	"Finder Scope": "寻星镜大师",
	"Mirror Master": "反射镜大师",
	"Nebula Hunter": "星云猎手",
	"Deep Sky Explorer": "深空探索者",
	"Magnification Mastery": "倍率掌握",
	"Sky Navigator": "天空导航员",
	"Deep Sky Observer": "深空观测员",
	"Senior Observer": "高级观测员",
	"Reflector Graduate": "反射式望远镜毕业章",
	"Dobsonian Graduate": "多布森望远镜毕业章",
	"Cassegrain Graduate": "卡塞格林望远镜毕业章",
	"Gregorian Graduate": "格里高利望远镜毕业章",
	"Infrared Graduate": "红外观测毕业章",
	"Radio Graduate": "射电观测毕业章",
	"Young Observer": "青年观测员"
}
# Gregorian family (levels 56-65) removed 2026-07-22. A save parked on one of
# these migrates forward to the first Infrared/Space level.
const DEPRECATED_GREGORIAN_LEVELS := [56, 57, 58, 59, 60, 61, 62, 63, 64, 65]
const FIRST_INFRARED_LEVEL := 66
const ASSEMBLY_FAMILIES := ["refractor", "newtonian", "dobsonian", "cassegrain", "gregorian", "space_segmented", "fast_radio"]
const PLAYER_OPTICAL_FAMILIES := ["refractor", "newtonian", "dobsonian", "cassegrain", "gregorian"]
const OPTICAL_OWNERSHIP_VERSION := 1

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"observatory": "res://scenes/observatory_room.tscn",
	"interior": "res://scenes/observatory_interior.tscn",
	"parts": "res://scenes/parts_cabinet.tscn",
	"assembly": "res://scenes/telescope_assembly.tscn",
	"advanced_assembly": "res://scenes/advanced_assembly.tscn",
	"telescope_types": "res://scenes/telescope_types.tscn",
	"world_map": "res://scenes/world_map.tscn",
	"optical_tube_assembly": "res://scenes/optical_tube_assembly.tscn",
	"collimation": "res://scenes/collimation.tscn",
	"radio_observation": "res://scenes/radio_observation.tscn",
	"multi_observation": "res://scenes/multi_observation.tscn",
	"space_observation": "res://scenes/space_observation.tscn",
	"constellation": "res://scenes/constellation_observation.tscn",
	"sky": "res://scenes/sky_observation.tscn",
	"telescope": "res://scenes/telescope_view.tscn",
	"journal": "res://scenes/learning_journal.tscn",
	"card": "res://scenes/learning_card.tscn",
	"story": "res://scenes/story_dialogue.tscn",
	"graduation": "res://scenes/graduation_ceremony.tscn"
}

var parts_data: Array = []
var objects_data: Array = []
var levels_data: Array = []
var learning_cards_data: Array = []
var constellations_data: Array = []
var world_locations: Dictionary = {}
var progress: Dictionary = {}
var selected_object_id := ""
# The selected catalog object may survive a Telescope View or world-map round
# trip, but it must never leak into a different mission.
var selected_object_level := 0
# Transient authoritative sky snapshot for the active observing site. This is
# intentionally not saved: it is recomputed whenever Sky Observation opens.
var current_sky_positions: Dictionary = {}
var current_sky_location_id := ""
var last_observation: Dictionary = {}
var last_learning_card: Dictionary = {}
var last_guidance := ""
var room_guidance_target := ""
var room_guidance_title := ""
var room_guidance_hint := ""
var language_mode := "en"
var observatory_spawn_id := "default"
# Exact in-room navigation pose. This is intentionally transient: it preserves
# where the player stood while visiting menus, observation screens, journals,
# or teaching cards without changing the save format or cross-session spawn.
var observatory_return_pose: Dictionary = {}
# The map can be opened from either the observatory or an already-active sky
# view. Keep that return route transient: it is navigation state, not progress.
var world_map_return_scene := "sky"
# The world map follows the object that opened it. This may be tonight's
# mission target or a player-selected free-observation object.
var world_map_target_id := ""
var world_map_observation_context: Dictionary = {}
var world_map_arrival_context: Dictionary = {}
# An explicit Return Home is allowed even when the mission target is below the
# home horizon. Consume this once in Sky Observation to avoid reopening the map.
var suppress_next_world_map_redirect := false
# Last sky-observation aim, restored when re-entering the pad.
var last_sky_aim: Dictionary = {"valid": false}
# Active bench choice. Missions may recommend a family, but the assembly table
# remembers the player's explicit selection without rewriting level data.
var assembly_family_id := ""
var developer_console: Control
var _developer_console_test_permission: Variant = null
# Developer level jumps are disposable test sessions. They must never become
# campaign saves or be repaired back to the first incomplete lesson while the
# developer is preparing equipment and moving between test entry points.
var _developer_sandbox_active := false
var _developer_sandbox_level := 0
var foundation_training_time_cache: Dictionary = {}
# Remote campaign and free-observation sessions share the same instrument
# scenes, but never the same progression path. This context is transient; only
# completed free observations are written to the save archive.
var remote_observation_context: Dictionary = {}
# The central observation pad owns local optical observing. This transient
# context keeps an active FAST/space campaign from taking over the player's
# assembled ground telescope without adding another save field.
var local_optical_observation_context: Dictionary = {}


func _ready() -> void:
	parts_data = _load_json_array("res://data/telescope_parts.json")
	parts_data.append_array(_load_json_array(ADVANCED_PARTS_PATH))
	objects_data = _load_json_array("res://data/celestial_objects.json")
	objects_data.append_array(_load_json_array(EXPANSION_DIR + "celestial_objects.json"))
	levels_data = _load_json_array("res://data/levels.json")
	levels_data.append_array(_load_json_array(ADVANCED_LEVELS_PATH))
	learning_cards_data = _load_json_array("res://data/learning_cards.json")
	learning_cards_data.append_array(_load_json_array(EXPANSION_DIR + "learning_cards.json"))
	constellations_data = _load_json_array(EXPANSION_DIR + "constellations.json")
	world_locations = _load_json_dict("res://data/world_locations.json")
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null:
		mission_manager.load_levels(levels_data)
	progress = SaveManager.load_progress(default_progress())
	_normalize_progress()
	language_mode = _normalized_language_mode(str(progress.get("language_mode", "en")))
	var website_language := _website_language_mode()
	if not website_language.is_empty():
		language_mode = website_language
		progress["language_mode"] = website_language
	_unlock_parts_for_current_level()
	save()
	set_process_unhandled_input(true)
	var cloud_sync := get_node_or_null("/root/CloudSyncManager")
	if cloud_sync != null and cloud_sync.has_signal("session_changed"):
		cloud_sync.session_changed.connect(_on_cloud_session_changed)
	call_deferred("_publish_web_context", "")


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_EQUAL:
		return
	if not can_open_developer_console():
		return
	toggle_developer_console()
	get_viewport().set_input_as_handled()


func can_open_developer_console() -> bool:
	# Production web clients are denied by default until the signed server
	# session explicitly reports the dedicated entitlement (admins inherit it).
	# Local editor builds retain their
	# development workflow; automated tests must opt in with the explicit hook.
	if _developer_console_test_permission != null:
		if not bool(_developer_console_test_permission):
			return false
		var test_cloud_sync := get_node_or_null("/root/CloudSyncManager")
		return test_cloud_sync != null and test_cloud_sync.has_method("can_use_developer_console") and bool(test_cloud_sync.can_use_developer_console())
	if OS.has_feature("web"):
		var cloud_sync := get_node_or_null("/root/CloudSyncManager")
		return cloud_sync != null and cloud_sync.has_method("can_use_developer_console") and bool(cloud_sync.can_use_developer_console())
	return true


func set_developer_console_test_permission_for_tests(allowed: bool) -> void:
	# Deliberately unavailable in production Web exports: this exists only so
	# headless regression tests can cover visitor/user/admin denial paths.
	if OS.has_feature("web"):
		return
	_developer_console_test_permission = allowed


func toggle_developer_console() -> void:
	# This is the authoritative guard. Keyboard filtering is only convenience;
	# scripts or synthetic input must not bypass the same access decision.
	if not can_open_developer_console():
		if developer_console != null and is_instance_valid(developer_console):
			developer_console.queue_free()
			developer_console = null
		return
	if developer_console != null and is_instance_valid(developer_console):
		developer_console.queue_free()
		developer_console = null
		return
	var current: Node = get_tree().current_scene
	if current == null:
		return
	# Loading here avoids a preload cycle: the panel independently verifies the
	# server-backed session role in _ready(), while this manager owns the
	# authoritative entry guard above.
	var developer_console_script := load(DEVELOPER_CONSOLE_SCRIPT_PATH) as Script
	if developer_console_script == null:
		return
	developer_console = developer_console_script.new()
	current.add_child(developer_console)


func _on_cloud_session_changed(_user: Dictionary) -> void:
	if developer_console != null and is_instance_valid(developer_console) and not can_open_developer_console():
		developer_console.queue_free()
		developer_console = null


func debug_jump_to_level(level_number: int, prepare_equipment: bool = false) -> void:
	var level_numbers := available_level_numbers()
	if level_numbers.is_empty():
		return
	var resolved_level := level_number
	if not level_numbers.has(resolved_level):
		resolved_level = level_numbers[0]
		for candidate in level_numbers:
			if candidate > level_number:
				break
			resolved_level = candidate
	_developer_sandbox_active = true
	_developer_sandbox_level = resolved_level
	progress["current_level"] = resolved_level
	# A developer jump creates a complete test context for that lesson. Normal
	# gameplay keeps the player's last bench choice; only this debug shortcut
	# follows the jumped-to mission family automatically.
	var debug_family := str(current_level().get("telescope_family", "refractor"))
	if debug_family in ASSEMBLY_FAMILIES:
		assembly_family_id = debug_family
		progress["selected_telescope_family"] = debug_family
		progress["selected_assembly_level"] = resolved_level
	selected_object_id = current_target_object_id()
	selected_object_level = int(progress.get("current_level", 1))
	current_sky_positions.clear()
	current_sky_location_id = ""
	foundation_training_time_cache.clear()
	last_observation = {}
	last_learning_card = {}
	last_sky_aim = {"valid": false}
	_unlock_parts_for_current_level()
	# Developer jumps should not be interrupted by normal progression popups.
	progress["pending_unlock_notice"] = []
	if prepare_equipment:
		_debug_prepare_equipment()
	else:
		reset_assembly()
	update_room_guidance_for_level()
	progress_changed.emit()


func debug_launch(scene_key: String, prepare_equipment: bool = false) -> void:
	if prepare_equipment:
		_debug_prepare_equipment()
	selected_object_id = current_target_object_id()
	selected_object_level = int(progress.get("current_level", 1))
	if scene_key == "observatory":
		update_room_guidance_for_level()
		clear_observatory_return_pose()
		set_observatory_spawn("default")
	go(scene_key)


func available_level_numbers() -> Array[int]:
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null and not mission_manager.campaign_order.is_empty():
		var active_levels: Array[int] = []
		for level_number in mission_manager.campaign_order:
			active_levels.append(int(level_number))
		return active_levels
	var result: Array[int] = []
	for level_value in levels_data:
		if not level_value is Dictionary:
			continue
		var level: Dictionary = level_value
		# Deprecated families (Gregorian) never appear in the developer panel.
		if bool(level.get("deprecated", false)):
			continue
		var number := int(level.get("level_number", 0))
		if number > 0 and not result.has(number):
			result.append(number)
	result.sort()
	return result


func _debug_prepare_equipment() -> void:
	# A repeatable level sandbox: select the best parts currently unlocked and
	# perfectly install the parts the selected lesson actually requires.
	var part_types: Array[String] = ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope", "focus_knob"]
	for required_type_value in current_level().get("required_parts", []):
		var required_type := str(required_type_value)
		if not part_types.has(required_type):
			part_types.append(required_type)
	for part_type in part_types:
		var best_option := best_part_for_type(part_type)
		if not best_option.is_empty():
			equip_part(str(best_option.get("id", "")))
	# Lessons that prescribe exact component IDs override the "best unlocked"
	# pick, matching what the assembly screens themselves enforce.
	for required_id_value in current_level().get("required_part_ids", []):
		equip_part(str(required_id_value))
	if _uses_tube_subassembly():
		var tube_config := tube_subassembly_config()
		var tube_order: Array = tube_config.get("order", [])
		var tube_ids: Array = tube_config.get("ids", [])
		var completed_subparts := {}
		for index in range(tube_order.size()):
			var subpart := str(tube_order[index])
			completed_subparts[subpart] = true
			if index < tube_ids.size():
				equip_part(str(tube_ids[index]))
		# Collimation BEFORE saving the tube so the snapshot carries the
		# aligned score - otherwise every prepared reflector level still
		# opens on "NEEDS COLLIMATION" and blocks the observation gate.
		if bool(current_level().get("requires_collimation", false)):
			set_collimation_score(92.0)
		save_tube_assembly(completed_subparts, 100.0, 100.0, true)
	reset_assembly()
	for required_type_value in _effective_required_parts():
		install_part(str(required_type_value), 0)
	progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	progress["finder_offset_seeded"] = false
	progress["tracking_rate"] = 1.0 if has_tracking_mount_equipped() else 0.0


func prepared_readiness_report() -> Dictionary:
	# Verifies what _debug_prepare_equipment() actually accomplished so the
	# developer console can show concrete "done" lines instead of a blind
	# "prepared" claim, and so a test can assert real completeness per family.
	var level := current_level()
	var report := {
		"main_assembly": true,
		"main_missing": [],
		"tube_interior": true,
		"collimation": -1.0,
		"observation_open": false,
		"family": str(level.get("telescope_family", "")),
		"mount_id": "",
		"tracking_capable": false,
		"tracking_rate": 0.0
	}
	if not current_requires_telescope():
		# Naked-eye-only nights: no rig to build.
		report["main_assembly"] = true
		report["observation_open"] = true
		report["needs_telescope"] = false
		return report
	report["needs_telescope"] = true
	var mount_id := equipped_part_id("mount")
	var mount := get_part(mount_id)
	report["mount_id"] = mount_id
	report["tracking_capable"] = bool(mount.get("tracking_capable", false))
	report["tracking_rate"] = tracking_rate() if report["tracking_capable"] else 0.0
	var state: Dictionary = progress.get("assembly_state", {})
	for required_type_value in _effective_required_parts():
		var required_type := str(required_type_value)
		var entry: Dictionary = state.get(required_type, {})
		if not bool(entry.get("installed", false)):
			report["main_assembly"] = false
			report["main_missing"].append(required_type)
	if _uses_tube_subassembly():
		var tube_state := tube_assembly()
		var subparts: Dictionary = tube_state.get("installed_subparts", tube_state.get("tube_assembly_state", {}))
		var tube_config := tube_subassembly_config()
		for subpart_value in tube_config.get("order", []):
			if not bool(subparts.get(str(subpart_value), false)):
				report["tube_interior"] = false
	if bool(level.get("requires_collimation", false)):
		report["collimation"] = collimation_score()
	report["observation_open"] = report["main_assembly"] and report["tube_interior"] \
		and (report["collimation"] < 0.0 or report["collimation"] >= 80.0)
	return report


func focus_control_installed() -> bool:
	var state: Dictionary = progress.get("assembly_state", {})
	for focus_type in ["focus_knob", "focuser"]:
		var entry: Dictionary = state.get(focus_type, {})
		if bool(entry.get("installed", false)):
			return true
	# Advanced reflector focusers live inside the optical-tube subassembly.
	if _uses_tube_subassembly():
		var tube_state := tube_assembly()
		var subparts: Dictionary = tube_state.get("installed_subparts", tube_state.get("tube_assembly_state", {}))
		if bool(subparts.get("focuser", false)):
			return true
	return false


func default_progress() -> Dictionary:
	return {
		"campaign_version": CAMPAIGN_VERSION,
		"save_revision": 0,
		"save_updated_at": 0,
		"cloud_synced_revision": 0,
		"cloud_owner_id": "",
		# This stays false for the bootstrap archive written before the player
		# begins a campaign. new_game() flips it so the menu can distinguish a
		# resumable L1 game from an empty/default save file.
		"save_initialized": false,
		"current_level": 1,
		"selected_telescope_family": "refractor",
		"selected_assembly_level": 1,
		"active_optical_telescope_id": "",
		"owned_optical_telescope_families": [],
		"optical_ownership_transfer_version": 0,
		"credits": 0,
		"completed_levels": [],
		"program_completed": false,
		"graduation_pending": false,
		"graduation_seen": false,
		"unlocked_parts": ["basic_tripod", "basic_mount", "starter_tube", "objective_60mm", "eyepiece_20mm"],
		"selected_parts": {
			"tripod": "basic_tripod",
			"mount": "basic_mount",
			"tube": "starter_tube",
			"objective": "objective_60mm",
			"eyepiece": "eyepiece_20mm",
			"finder_scope": "",
			"focus_knob": ""
		},
		"assembly_state": _fresh_assembly_state(),
		"telescope_ready": false,
		"family_assembly_states": {},
		"family_selected_parts": {},
		"observed_objects": [],
		"badges": [],
		"journal_entries": [],
		"remote_observation_archive": [],
		"remote_free_intro_seen": [],
		"completed_concept_cards": [],
		"seen_teaching_steps": [],
		"seen_concept_briefs": [],
		"seen_story_events": [],
		"tutorial_assistance": TUTORIAL_ASSIST_FULL,
		"tutorial_free_confirmation_seen": false,
		"wide_pulse_capture_window": false,
		"pending_unlock_notice": [],
		"unlocked_equipment_stages": ["eye"],
		"language_mode": "en",
		"mission_step_state": {},
		"level_target_overrides": {},
		"secondary_targets_found": {},
		"finder_offset": {"az": 0.0, "alt": 0.0},
		"finder_offset_seeded": false,
		"tracking_rate": 0.0,
		"collimation_scores": {"newtonian": 0.0},
		"tube_assemblies": {}
	}


func new_game() -> void:
	# The menu is available before a meaningful campaign save exists. Preserve
	# the language the player explicitly selected there instead of recreating a
	# default-English progress dictionary and then reading it back.
	_developer_sandbox_active = false
	_developer_sandbox_level = 0
	var selected_language := _normalized_language_mode(language_mode)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null and audio_manager.has_method("clear_music_progress"):
		audio_manager.clear_music_progress()
	progress = default_progress()
	progress["save_initialized"] = true
	progress["language_mode"] = selected_language
	language_mode = selected_language
	# Save exactly the initialized game state.  Writing the default progress
	# first would transiently persist English and could queue an incorrect cloud
	# upload when the player starts a Chinese game from the main menu.
	# A fresh campaign replaces the one cloud slot. Do not send it through the
	# normal monotonic upload/merge path: that path intentionally keeps the
	# highest level and would resurrect the previous campaign.
	SaveManager.save_progress(progress, false)
	var cloud_sync := get_node_or_null("/root/CloudSyncManager")
	if cloud_sync != null and cloud_sync.has_method("start_new_campaign"):
		cloud_sync.call("start_new_campaign", progress.duplicate(true))
	selected_object_id = ""
	selected_object_level = 0
	world_map_return_scene = "sky"
	world_map_target_id = ""
	world_map_observation_context.clear()
	world_map_arrival_context.clear()
	suppress_next_world_map_redirect = false
	current_sky_positions.clear()
	current_sky_location_id = ""
	foundation_training_time_cache.clear()
	remote_observation_context.clear()
	local_optical_observation_context.clear()
	last_observation = {}
	last_learning_card = {}
	last_guidance = ""
	clear_room_guidance()
	observatory_spawn_id = "default"
	clear_observatory_return_pose()
	last_sky_aim = {"valid": false}
	assembly_family_id = str(progress.get("selected_telescope_family", "refractor"))
	TeachingFlowManager.reset_flow()
	StoryManager.reset_flow()
	progress_changed.emit()


func has_save() -> bool:
	return SaveManager.has_resumable_save()


func save() -> void:
	progress["language_mode"] = language_mode
	SaveManager.save_progress(progress)
	progress_changed.emit()


func developer_sandbox_active() -> bool:
	return _developer_sandbox_active


func resume_saved_campaign() -> void:
	# Continue always means the player's persisted campaign, not a developer
	# lesson that happened to be active in memory after closing the console.
	_developer_sandbox_active = false
	_developer_sandbox_level = 0
	progress = SaveManager.load_progress(default_progress())
	_normalize_progress()
	language_mode = _normalized_language_mode(str(progress.get("language_mode", language_mode)))
	selected_object_id = ""
	selected_object_level = 0
	current_sky_positions.clear()
	current_sky_location_id = ""
	last_observation = {}
	last_learning_card = {}
	last_sky_aim = {"valid": false}
	assembly_family_id = str(progress.get("selected_telescope_family", "refractor"))
	progress_changed.emit()


func tutorial_assistance_mode() -> String:
	var mode := str(progress.get("tutorial_assistance", TUTORIAL_ASSIST_FULL))
	if not mode in TUTORIAL_ASSIST_MODES:
		return TUTORIAL_ASSIST_FULL
	return mode


func set_tutorial_assistance_mode(mode: String) -> void:
	var normalized := mode if mode in TUTORIAL_ASSIST_MODES else TUTORIAL_ASSIST_FULL
	if tutorial_assistance_mode() == normalized:
		return
	progress["tutorial_assistance"] = normalized
	save()
	tutorial_assistance_changed.emit(normalized)


func uses_wide_pulse_capture_window() -> bool:
	return bool(progress.get("wide_pulse_capture_window", false))


func set_wide_pulse_capture_window(enabled: bool) -> void:
	if uses_wide_pulse_capture_window() == enabled:
		return
	progress["wide_pulse_capture_window"] = enabled
	save()
	pulse_capture_assistance_changed.emit(enabled)


func uses_full_tutorials() -> bool:
	return tutorial_assistance_mode() == TUTORIAL_ASSIST_FULL


func allows_tutorial_hints() -> bool:
	return tutorial_assistance_mode() != TUTORIAL_ASSIST_FREE


func acknowledge_free_exploration_confirmation() -> void:
	if bool(progress.get("tutorial_free_confirmation_seen", false)):
		return
	progress["tutorial_free_confirmation_seen"] = true
	save()


func go(scene_key: String) -> void:
	if scene_key == "sky" and not is_local_optical_free_observation():
		match current_observation_mode():
			"radio": scene_key = "radio_observation"
			"multi_device": scene_key = "multi_observation"
			"space_infrared": scene_key = "space_observation"
			"telescope" when str(current_level().get("telescope_family", "")) == "space_segmented": scene_key = "space_observation"
	if scene_key == "assembly" and assembly_family() != "refractor":
		scene_key = "advanced_assembly"
	if not SCENES.has(scene_key):
		push_error("Unknown scene key: " + scene_key)
		return
	# Reaching the guided destination completes the guidance.
	if (scene_key in ["sky", "telescope"] and room_guidance_target == "telescope") \
			or (scene_key == "assembly" and room_guidance_target == "assembly") \
			or (scene_key == "parts" and room_guidance_target == "cabinet"):
		clear_room_guidance()
	var packed_scene: PackedScene = load(SCENES[scene_key])
	if packed_scene == null:
		push_error("Could not load scene: " + str(SCENES[scene_key]))
		return
	var next_scene: Node = packed_scene.instantiate()
	var current: Node = get_tree().current_scene
	if current != null:
		current.queue_free()
	get_tree().root.add_child(next_scene)
	get_tree().current_scene = next_scene
	_publish_web_context(scene_key)
	# Universal soft entry: every screen change fades in instead of hard
	# cutting. Scenes that already call page_enter simply restart the same
	# keyed tween, so there is no double animation.
	if next_scene.has_method("play_custom_entrance"):
		# Scenes with a themed entrance (e.g. the observation deck's dome
		# doors) own their arrival - the generic fade would double up and
		# every screen sharing one fade breeds animation fatigue.
		next_scene.call_deferred("play_custom_entrance")
	elif next_scene is Control:
		InteractionFeedback.page_enter(next_scene, Vector2.ZERO)


func set_observatory_spawn(spawn_id: String) -> void:
	observatory_spawn_id = spawn_id


func remember_observatory_pose(position: Vector2, facing: String) -> void:
	if not is_finite(position.x) or not is_finite(position.y):
		return
	var safe_facing := facing if facing in [
		"up", "up_right", "right", "down_right",
		"down", "down_left", "left", "up_left",
	] else "down"
	observatory_return_pose = {
		"valid": true,
		"position": position,
		"facing": safe_facing,
	}


func take_observatory_return_pose() -> Dictionary:
	var pose := observatory_return_pose.duplicate(true)
	observatory_return_pose.clear()
	return pose


func clear_observatory_return_pose() -> void:
	observatory_return_pose.clear()


func take_observatory_spawn() -> String:
	var spawn_id := observatory_spawn_id
	observatory_spawn_id = "default"
	return spawn_id


func text(en: String, zh: String) -> String:
	return LocalizationScript.text(en, zh, language_mode)


func dict_text(data: Dictionary, base: String) -> String:
	return LocalizationScript.from_dict(data, base, language_mode)


func cycle_language() -> void:
	if language_mode == "en":
		language_mode = "zh"
	else:
		language_mode = "en"
	save()
	_sync_website_language()
	language_changed.emit()
	_publish_web_context("")


func _publish_web_context(scene_key: String) -> void:
	# The surrounding Web shell receives only presentation context for a feedback
	# report. It never receives a save, account/session data, or player input.
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return
	var resolved_scene := scene_key
	if resolved_scene.is_empty():
		var current := get_tree().current_scene
		var current_path := "" if current == null else str(current.scene_file_path)
		for key_value in SCENES:
			if str(SCENES[key_value]) == current_path:
				resolved_scene = str(key_value)
				break
	if resolved_scene.is_empty():
		resolved_scene = "unknown"
	var payload := {
		"scene": resolved_scene,
		"level": int(progress.get("current_level", 1)),
		"language": language_mode,
		"assembly_family": assembly_family(),
		"observation_mode": current_observation_mode(),
	}
	JavaScriptBridge.eval("window.dispatchEvent(new CustomEvent('observatory:game-context',{detail:" + JSON.stringify(payload) + "}));", true)


func _normalized_language_mode(mode: String) -> String:
	if mode == "zh":
		return "zh"
	return "en"


func _website_language_mode() -> String:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var value: Variant = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('so-lang')||''}catch(_){return ''}})()", true)
	var mode := str(value).to_lower()
	if mode == "zh" or mode == "en":
		return mode
	return ""


func _sync_website_language() -> void:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return
	var mode := _normalized_language_mode(language_mode)
	var script := "(()=>{try{localStorage.setItem('so-lang','%s')}catch(_){}const u=new URL(location.href);u.searchParams.set('lang','%s');history.replaceState(history.state,'',u);document.documentElement.dataset.lang='%s';document.documentElement.lang='%s';document.dispatchEvent(new CustomEvent('po:language-changed',{detail:{lang:'%s'}}));})()" % [mode, mode, mode, "zh-CN" if mode == "zh" else "en", mode]
	JavaScriptBridge.eval(script, true)


func current_level() -> Dictionary:
	var mission_manager: Variant = _mission_manager()
	if mission_manager == null:
		return {}
	return mission_manager.get_level(int(progress.get("current_level", 1)))


func select_assembly_family(family: String) -> void:
	if not family in ASSEMBLY_FAMILIES:
		push_warning("Unknown telescope family: " + family)
		return
	var previous_family := assembly_family()
	if postgraduate_free_build() and previous_family != family:
		_store_postgraduate_family_state(previous_family)
	assembly_family_id = family
	progress["selected_telescope_family"] = family
	progress["selected_assembly_level"] = int(progress.get("current_level", 1))
	if postgraduate_free_build() and previous_family != family:
		_restore_postgraduate_family_state(family)
	elif previous_family != family:
		_clear_incompatible_selected_parts(family)
	save()


func _clear_incompatible_selected_parts(family: String) -> void:
	# Generic starter optics occupy refractor-only slots and must not survive a
	# transition to a reflector bench.
	var selected: Dictionary = progress.get("selected_parts", {})
	for part_type_value in selected.keys():
		var part_type := str(part_type_value)
		var part_id := str(selected.get(part_type, ""))
		var part_family := str(get_part(part_id).get("telescope_family", ""))
		if (part_family != "" and part_family != family) or (family != "refractor" and part_type in ["tube", "objective", "focus_knob"]):
			selected[part_type] = ""
	progress["telescope_ready"] = false


func _sync_assembly_family_for_level() -> void:
	if postgraduate_free_build():
		return
	var level_number := int(progress.get("current_level", 1))
	if int(progress.get("selected_assembly_level", 0)) == level_number:
		return
	var family := str(current_level().get("telescope_family", "refractor"))
	if not family in ASSEMBLY_FAMILIES:
		return
	var family_changed := assembly_family() != family
	assembly_family_id = family
	progress["selected_telescope_family"] = family
	progress["selected_assembly_level"] = level_number
	if family_changed:
		_clear_incompatible_selected_parts(family)


func assembly_family() -> String:
	if assembly_family_id != "":
		return assembly_family_id
	var saved := str(progress.get("selected_telescope_family", "refractor"))
	return saved if saved in ASSEMBLY_FAMILIES else "refractor"


func assembly_scene_key() -> String:
	return "assembly" if assembly_family() == "refractor" else "advanced_assembly"


func postgraduate_free_build() -> bool:
	return campaign_completed() and bool(progress.get("graduation_seen", false))


func is_player_optical_family(family: String) -> bool:
	return family in PLAYER_OPTICAL_FAMILIES


func unlocked_optical_telescope_families() -> Array[String]:
	var unlocked: Array[String] = []
	var completed: Array = progress.get("completed_levels", [])
	var reached := int(progress.get("current_level", 1))
	var unlocked_parts: Array = progress.get("unlocked_parts", [])
	for family in PLAYER_OPTICAL_FAMILIES:
		var available: bool = family == "refractor"
		for level_value in levels_data:
			if not level_value is Dictionary:
				continue
			var level: Dictionary = level_value
			if bool(level.get("deprecated", false)) or str(level.get("telescope_family", "")) != family:
				continue
			var number := int(level.get("level_number", level.get("id", 0)))
			if number > 0 and (reached >= number or completed.has(number) or completed.has(str(number))):
				available = true
				break
		if not available:
			for part_id_value in unlocked_parts:
				var part := get_part(str(part_id_value))
				if str(part.get("telescope_family", "")) == family:
					available = true
					break
		if available:
			unlocked.append(family)
	return unlocked


func transfer_unlocked_optical_equipment_ownership() -> Array[String]:
	if not campaign_completed() or not bool(progress.get("graduation_seen", false)):
		return []
	_ensure_progress_array("owned_optical_telescope_families")
	var transferred: Array[String] = []
	for family in unlocked_optical_telescope_families():
		if not progress["owned_optical_telescope_families"].has(family):
			progress["owned_optical_telescope_families"].append(family)
			transferred.append(family)
	progress["optical_ownership_transfer_version"] = OPTICAL_OWNERSHIP_VERSION
	_ensure_active_optical_telescope()
	return transferred


func owned_optical_telescope_families() -> Array[String]:
	var result: Array[String] = []
	for family_value in progress.get("owned_optical_telescope_families", []):
		var family := str(family_value)
		if is_player_optical_family(family) and not result.has(family):
			result.append(family)
	return result


func owns_optical_telescope_family(family: String) -> bool:
	return owned_optical_telescope_families().has(family)


func optical_equipment_ownership_label(family: String = "") -> String:
	var resolved := family if family != "" else assembly_family()
	if owns_optical_telescope_family(resolved):
		return text("MY EQUIPMENT · OWNED", "我的设备 · 已拥有")
	if is_player_optical_family(resolved):
		return text("CLUB COURSE EQUIPMENT · ON LOAN", "俱乐部课程器材 · 借用中")
	return text("REMOTE RESEARCH FACILITY · ACCESS ONLY", "远程科研设施 · 仅限使用权")


func optical_telescope_family_name(family: String) -> String:
	return _family_display_name(family)


func active_optical_telescope_family() -> String:
	var family := str(progress.get("active_optical_telescope_id", ""))
	return family if is_player_optical_family(family) else ""


func set_active_optical_telescope(family: String) -> bool:
	if not is_player_optical_family(family):
		return false
	if bool(progress.get("graduation_seen", false)) and not owns_optical_telescope_family(family):
		return false
	if assembly_family() == family:
		_store_postgraduate_family_state(family)
	progress["active_optical_telescope_id"] = family
	save()
	return true


func active_optical_telescope_is_ready() -> bool:
	var family := active_optical_telescope_family()
	if family == "":
		return false
	if assembly_family() == family:
		return telescope_is_ready()
	var saved_states: Dictionary = progress.get("family_assembly_states", {})
	var state_value: Variant = saved_states.get(family, {})
	return state_value is Dictionary and bool((state_value as Dictionary).get("telescope_ready", false))


func equip_completed_optical_telescope(family: String = "") -> bool:
	var resolved := family if family != "" else assembly_family()
	if not is_player_optical_family(resolved) or not telescope_is_ready():
		return false
	return set_active_optical_telescope(resolved)


func _ensure_active_optical_telescope() -> void:
	var active := active_optical_telescope_family()
	if active != "" and (not bool(progress.get("graduation_seen", false)) or owns_optical_telescope_family(active)):
		return
	var saved_states: Dictionary = progress.get("family_assembly_states", {})
	var owned := owned_optical_telescope_families()
	for index in range(owned.size() - 1, -1, -1):
		var family := owned[index]
		var state_value: Variant = saved_states.get(family, {})
		if state_value is Dictionary and bool((state_value as Dictionary).get("telescope_ready", false)):
			progress["active_optical_telescope_id"] = family
			return
	var selected := str(progress.get("selected_telescope_family", ""))
	if is_player_optical_family(selected) and (not bool(progress.get("graduation_seen", false)) or owns_optical_telescope_family(selected)):
		if bool(progress.get("telescope_ready", false)) and not saved_states.has(selected):
			_store_postgraduate_family_state(selected)
		progress["active_optical_telescope_id"] = selected
		return
	var last_completed := _last_completed_optical_family()
	if last_completed != "" and (not bool(progress.get("graduation_seen", false)) or owned.has(last_completed)):
		progress["active_optical_telescope_id"] = last_completed


func _last_completed_optical_family() -> String:
	var completed: Array = progress.get("completed_levels", [])
	var best_family := ""
	var best_number := -1
	for level_value in levels_data:
		if not level_value is Dictionary:
			continue
		var level: Dictionary = level_value
		var number := int(level.get("level_number", level.get("id", 0)))
		var family := str(level.get("telescope_family", ""))
		if number <= best_number or not is_player_optical_family(family):
			continue
		if completed.has(number) or completed.has(str(number)):
			best_number = number
			best_family = family
	return best_family


func assembly_context_family() -> String:
	if postgraduate_free_build():
		return assembly_family()
	return str(current_level().get("telescope_family", "refractor"))


func _store_postgraduate_family_state(family: String) -> void:
	if family == "" or not family in ASSEMBLY_FAMILIES:
		return
	if not progress.get("family_assembly_states") is Dictionary:
		progress["family_assembly_states"] = {}
	if not progress.get("family_selected_parts") is Dictionary:
		progress["family_selected_parts"] = {}
	progress["family_assembly_states"][family] = {
		"assembly_state": (progress.get("assembly_state", {}) as Dictionary).duplicate(true),
		"telescope_ready": bool(progress.get("telescope_ready", false))
	}
	progress["family_selected_parts"][family] = (progress.get("selected_parts", {}) as Dictionary).duplicate(true)


func _restore_postgraduate_family_state(family: String) -> void:
	var saved_states: Dictionary = progress.get("family_assembly_states", {})
	var saved_parts: Dictionary = progress.get("family_selected_parts", {})
	var state_value: Variant = saved_states.get(family, {})
	if state_value is Dictionary and not (state_value as Dictionary).is_empty():
		var state_record: Dictionary = state_value
		progress["assembly_state"] = (state_record.get("assembly_state", _fresh_assembly_state()) as Dictionary).duplicate(true)
		progress["telescope_ready"] = bool(state_record.get("telescope_ready", false))
	else:
		progress["assembly_state"] = _fresh_assembly_state()
		progress["telescope_ready"] = false
	var parts_value: Variant = saved_parts.get(family, {})
	if parts_value is Dictionary and not (parts_value as Dictionary).is_empty():
		progress["selected_parts"] = (parts_value as Dictionary).duplicate(true)
	else:
		var compatible_parts: Dictionary = (progress.get("selected_parts", {}) as Dictionary).duplicate(true)
		for part_type_value in compatible_parts.keys():
			var part_id := str(compatible_parts.get(part_type_value, ""))
			var part := get_part(part_id)
			var part_family := str(part.get("telescope_family", ""))
			if part_id != "" and part_family != "" and part_family != family:
				compatible_parts[part_type_value] = ""
		progress["selected_parts"] = compatible_parts


func assembly_level_context() -> Dictionary:
	var family := assembly_family()
	var current := current_level()
	if str(current.get("telescope_family", "refractor")) == family:
		return current
	var reached := int(progress.get("current_level", 1))
	var best: Dictionary = {}
	var best_number := -1
	for level_value in levels_data:
		if not level_value is Dictionary:
			continue
		var level: Dictionary = level_value
		var number := int(level.get("level_number", level.get("id", 0)))
		if number > reached or str(level.get("telescope_family", "refractor")) != family:
			continue
		if str(level.get("assembly_mode", "")) == "" or number <= best_number:
			continue
		best = level
		best_number = number
	return best if not best.is_empty() else current


func current_target() -> Dictionary:
	return get_object(current_target_object_id())


# ------------------------------------------------- level-scoped target tuning
#
# The same catalog object is reused at very different points in the campaign.
# Saturn's shipped requirements are tuned for the 140mm Newtonian chapter, so
# dropping it into the basic-refractor chapter would make that level
# mathematically unwinnable. A level may therefore soften (or tighten) the
# target's requirement fields for itself only; the catalog entry - and every
# other level using it - is untouched.
func target_requirement_overrides_for(object_id: String) -> Dictionary:
	var level := current_level()
	var merged: Dictionary = {}
	var choice := target_choice_entry(object_id)
	if not choice.is_empty():
		var choice_overrides: Variant = choice.get("requirement_overrides", {})
		if choice_overrides is Dictionary:
			merged.merge(choice_overrides as Dictionary, true)
	if object_id == current_target_object_id():
		var level_overrides: Variant = level.get("target_requirement_overrides", {})
		if level_overrides is Dictionary:
			merged.merge(level_overrides as Dictionary, true)
	return merged


func apply_target_requirement_overrides(obj: Dictionary) -> Dictionary:
	var object_id := str(obj.get("id", ""))
	if object_id == "":
		return obj
	var overrides := target_requirement_overrides_for(object_id)
	if overrides.is_empty():
		return obj
	var tuned := obj.duplicate(true)
	tuned.merge(overrides, true)
	return tuned


# ------------------------------------------------------------ target choices
#
# A choice level (L13) lets the player pick the target instead of being
# assigned one. Each entry may carry its own observation requirements, so
# "the right power" differs per target - that comparison is the lesson.
func target_choices() -> Array:
	var choices: Variant = current_level().get("target_choices", [])
	if choices is Array:
		return choices as Array
	return []


func level_requires_target_choice() -> bool:
	return bool(current_level().get("requires_target_choice", false)) and not target_choices().is_empty()


func target_choice_entry(object_id: String) -> Dictionary:
	for choice_value in target_choices():
		if not choice_value is Dictionary:
			continue
		var choice: Dictionary = choice_value
		if str(choice.get("object_id", "")) == object_id:
			return choice
	return {}


func has_chosen_level_target() -> bool:
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return false
	var overrides: Dictionary = progress.get("level_target_overrides", {})
	return overrides.has(level_id)


func set_level_target_choice(object_id: String) -> bool:
	if object_id == "" or target_choice_entry(object_id).is_empty():
		return false
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return false
	if not progress.get("level_target_overrides") is Dictionary:
		progress["level_target_overrides"] = {}
	var overrides: Dictionary = progress["level_target_overrides"]
	overrides[level_id] = object_id
	progress["level_target_overrides"] = overrides
	selected_object_id = object_id
	last_sky_aim = {}
	save()
	return true


# Requirements actually in force: the level's own block, overlaid by the
# chosen target's block on a choice level.
func active_observation_requirements() -> Dictionary:
	var level := current_level()
	var base: Variant = level.get("observation_requirements", {})
	var merged: Dictionary = (base as Dictionary).duplicate(true) if base is Dictionary else {}
	var choice := target_choice_entry(current_target_object_id())
	if not choice.is_empty():
		var choice_requirements: Variant = choice.get("observation_requirements", {})
		if choice_requirements is Dictionary:
			merged.merge(choice_requirements as Dictionary, true)
	return merged


# --------------------------------------------------------- secondary targets
#
# L55 logs Neptune AND Triton. The secondary is a real, separately confirmed
# object rather than decoration painted into the primary's sprite.
func current_secondary_target() -> Dictionary:
	var secondary: Variant = current_level().get("secondary_target", {})
	if secondary is Dictionary:
		return secondary as Dictionary
	return {}


func secondary_target_found() -> bool:
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return false
	var found: Variant = progress.get("secondary_targets_found", {})
	if not found is Dictionary:
		return false
	return bool((found as Dictionary).get(level_id, false))


func mark_secondary_target_found() -> void:
	var level_id := str(current_level().get("id", ""))
	if level_id == "" or current_secondary_target().is_empty():
		return
	if not progress.get("secondary_targets_found") is Dictionary:
		progress["secondary_targets_found"] = {}
	var found: Dictionary = progress["secondary_targets_found"]
	if bool(found.get(level_id, false)):
		return
	found[level_id] = true
	progress["secondary_targets_found"] = found
	save()


# Resolves the level's actual target for this playthrough: levels with a
# target_pool get a random pick on first visit (stable afterward via
# progress["level_target_overrides"]); levels without one just use their
# fixed target_object_id, unaffected.
func current_target_object_id() -> String:
	var level := current_level()
	var default_id := str(level.get("target_object_id", "moon"))
	var pool: Array = level.get("target_pool", [])
	if pool.is_empty():
		return default_id
	var level_id := str(level.get("id", ""))
	if level_id == "":
		return default_id
	var overrides: Dictionary = progress.get("level_target_overrides", {})
	if overrides.has(level_id):
		return str(overrides[level_id])
	# Choice levels wait for the player instead of rolling for them. The
	# declared target_object_id is only a placeholder so every existing caller
	# (sky placement, mission board preview) still has something valid to read.
	if level_requires_target_choice():
		return default_id
	var pick := str(pool[randi() % pool.size()])
	overrides[level_id] = pick
	progress["level_target_overrides"] = overrides
	save()
	return pick


func current_observation_mode() -> String:
	if is_local_optical_free_observation():
		return "telescope"
	return str(current_level().get("observation_mode", "telescope"))


func current_equipment_stage() -> String:
	return str(current_level().get("equipment_stage", "refractor_basic"))


func current_requires_telescope() -> bool:
	# Constellations now use the same observation pad and optical workflow as
	# other targets; they no longer bypass the assembled telescope.
	if current_observation_mode() == "constellation":
		return true
	var level := current_level()
	if level.has("requires_telescope"):
		return bool(level.get("requires_telescope", true))
	return current_observation_mode() != "naked_eye"


func current_requires_focus() -> bool:
	if is_local_optical_free_observation():
		return true
	return bool(current_level().get("requires_focus", false))


func required_part_types_for_current_level() -> Array[String]:
	var types: Array[String] = []
	for type_value in _effective_required_parts():
		var part_type := str(type_value)
		if part_type != "" and not types.has(part_type):
			types.append(part_type)
	if not postgraduate_free_build():
		for required_id_value in current_level().get("required_part_ids", []):
			var part := get_part(str(required_id_value))
			var part_type := str(part.get("type", ""))
			if part_type != "" and not types.has(part_type):
				types.append(part_type)
	return types


func is_part_compatible_with_current_level(part: Dictionary) -> bool:
	if part.is_empty():
		return false
	var part_type := str(part.get("type", ""))
	var part_family := str(part.get("telescope_family", ""))
	var level_family := assembly_context_family()
	if level_family != "refractor" and part_type in ["tube", "objective", "focus_knob"]:
		return false
	return part_family == "" or part_family == level_family


func locked_required_equipment() -> Dictionary:
	if postgraduate_free_build():
		return {"ids": [], "types": []}
	# This is deliberately about ownership, not installation. It prevents a
	# mission from sending the player to an assembly slot for an item they can
	# neither select nor obtain yet.
	var missing_ids: Array[String] = []
	var missing_types: Array[String] = []
	var pinned_types: Dictionary = {}
	for required_id_value in current_level().get("required_part_ids", []):
		var required_id := str(required_id_value)
		var part := get_part(required_id)
		var part_type := str(part.get("type", ""))
		if part_type != "":
			pinned_types[part_type] = true
		if part.is_empty() or not progress.get("unlocked_parts", []).has(required_id) or not is_part_compatible_with_current_level(part):
			missing_ids.append(required_id)
	for part_type in required_part_types_for_current_level():
		if part_type == "optical_tube_assembly" or pinned_types.has(part_type):
			continue
		var has_option := false
		for option_value in unlocked_parts_by_type(part_type):
			if is_part_compatible_with_current_level(option_value as Dictionary):
				has_option = true
				break
		if not has_option:
			missing_types.append(part_type)
	return {"ids": missing_ids, "types": missing_types}


func has_locked_required_equipment() -> bool:
	var locked := locked_required_equipment()
	return not (locked.get("ids", []) as Array).is_empty() or not (locked.get("types", []) as Array).is_empty()


func required_equipment_lock_reason() -> Dictionary:
	var locked := locked_required_equipment()
	var ids: Array = locked.get("ids", [])
	var types: Array = locked.get("types", [])
	var finder_missing := types.has("finder_scope")
	for part_id_value in ids:
		var part := get_part(str(part_id_value))
		finder_missing = finder_missing or str(part.get("type", "")) == "finder_scope"
	if finder_missing:
		return {
			"reason_en": "This mission requires a Finder Scope. Complete Finder Scope Introduction first, then equip it in the Parts Cabinet and install it at the Assembly Table.",
			"reason_zh": "本关需要寻星镜。请先完成寻星镜教学，再到零件柜装备并在组装台安装。"
		}
	var names: Array[String] = []
	for part_id_value in ids:
		var part := get_part(str(part_id_value))
		names.append(dict_text(part, "name") if not part.is_empty() else str(part_id_value))
	for part_type_value in types:
		names.append(AssemblyManagerScript._zh_name(str(part_type_value)))
	return {
		"reason_en": "Required equipment is not unlocked yet: " + ", ".join(names) + ". Complete its introduction mission first.",
		"reason_zh": "当前任务所需设备尚未解锁：" + "、".join(names) + "。请先完成对应教学关。"
	}


func current_concept_card_id() -> String:
	return str(current_level().get("required_concept_card", ""))


func get_learning_card(card_id: String) -> Dictionary:
	for card in learning_cards_data:
		if str(card.get("id", "")) == card_id:
			return card
	return {}


func get_constellation(constellation_id: String) -> Dictionary:
	for constellation in constellations_data:
		if str(constellation.get("id", "")) == constellation_id:
			return constellation
	return {}


func completed_concept_cards() -> Array:
	return progress.get("completed_concept_cards", [])


func current_concept_card() -> Dictionary:
	return get_learning_card(current_concept_card_id())


func has_seen_current_concept_brief() -> bool:
	var card_id := current_concept_card_id()
	if card_id == "":
		return true
	return progress.get("seen_concept_briefs", []).has(card_id)


func mark_concept_brief_seen(card_id: String) -> void:
	if card_id == "":
		return
	_ensure_progress_array("seen_concept_briefs")
	if not progress["seen_concept_briefs"].has(card_id):
		progress["seen_concept_briefs"].append(card_id)
	_ensure_progress_array("seen_teaching_steps")
	for step_value in TeachingFlowManager.get_steps_for_level(current_level()):
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		if str(step.get("card_id", "")) == card_id:
			var step_id: String = str(step.get("id", ""))
			if step_id != "" and not progress["seen_teaching_steps"].has(step_id):
				progress["seen_teaching_steps"].append(step_id)
	save()


func should_show_concept_brief_for_current_level() -> bool:
	var card_id := current_concept_card_id()
	if card_id == "":
		return false
	return not has_seen_current_concept_brief()


# ------------------------------------------------------ story flow wrappers


func try_story_event(event_id: String, return_scene_key: String) -> bool:
	return StoryManager.begin_event(event_id, return_scene_key)


func try_story_for_trigger(trigger: String, return_scene_key: String) -> bool:
	if not uses_full_tutorials():
		return false
	return StoryManager.begin_event_for_trigger(trigger, return_scene_key)


func complete_current_story() -> void:
	StoryManager.finish_active_event()


# Observing-site facts. The base site matches SkyPositionService's default
# observer (34.05N 118.24W): a suburban ridge NE of Los Angeles. Levels with
# a city/dark sky_brightness are field trips and override region + Bortle.
# --------------------------------------------------- observing location / horizon


func home_location() -> Dictionary:
	var home: Dictionary = world_locations.get("home", {})
	if home.is_empty():
		return {"id": "home", "name_en": "Home Base", "name_zh": "主基地", "country_en": "", "country_zh": "", "lat": 34.0522, "lon": -118.2437, "bortle": 5}
	return home


func location_sites() -> Array:
	return world_locations.get("sites", [])


func observing_location() -> Dictionary:
	# The site the player is currently observing from; defaults to home.
	var loc: Dictionary = progress.get("observing_location", {})
	if loc.is_empty() or not loc.has("lat"):
		return home_location()
	return loc


func is_at_home_location() -> bool:
	return str(observing_location().get("id", "home")) == str(home_location().get("id", "home"))


func set_observing_location(location: Dictionary) -> void:
	progress["observing_location"] = location.duplicate(true)
	foundation_training_time_cache.clear()
	save()


func reset_observing_location() -> void:
	progress["observing_location"] = home_location().duplicate(true)
	foundation_training_time_cache.clear()
	save()


func current_target_radec() -> Dictionary:
	return object_radec(current_target_object_id())


func object_radec(object_id: String) -> Dictionary:
	return object_radec_at(object_id, Time.get_datetime_dict_from_system(true))


func object_radec_at(object_id: String, utc_datetime: Dictionary) -> Dictionary:
	# Resolve any catalog object through the same local ephemeris used by the
	# mission target. This keeps free observation and the map on one data source.
	if object_id == "":
		return {}
	var service := SkyPositionService.new()
	for entry_value in service.catalog:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) != object_id:
			continue
		if entry.has("ra_hours") and entry.has("dec_degrees"):
			return {"ra_hours": float(entry["ra_hours"]), "dec_degrees": float(entry["dec_degrees"])}
		if entry.has("planet_body"):
			var eph: Dictionary = service.planet_ra_dec(str(entry["planet_body"]), utc_datetime)
			if not eph.is_empty():
				return {"ra_hours": float(eph["ra_hours"]), "dec_degrees": float(eph["dec_degrees"])}
	# Constellations carry their anchor coordinates separately.
	var constellation := get_constellation(object_id)
	if constellation.has("ra_hours") and constellation.has("dec_degrees"):
		return {"ra_hours": float(constellation["ra_hours"]), "dec_degrees": float(constellation["dec_degrees"])}
	return {}


func uses_foundation_training_schedule() -> bool:
	var level_number := int(current_level().get("level_number", progress.get("current_level", 1)))
	return level_number >= 1 and level_number <= FOUNDATION_TRAINING_MAX_LEVEL


func observation_utc_datetime(object_id: String = "") -> Dictionary:
	var now := Time.get_datetime_dict_from_system(true)
	if not uses_foundation_training_schedule():
		return now
	var target_id := object_id if object_id != "" else current_target_object_id()
	var location := observing_location()
	var cache_key := "%d|%s|%s|%04d-%02d-%02d" % [
		int(current_level().get("level_number", progress.get("current_level", 1))),
		target_id,
		str(location.get("id", "home")),
		int(now.get("year", 0)),
		int(now.get("month", 0)),
		int(now.get("day", 0))
	]
	if foundation_training_time_cache.has(cache_key):
		return (foundation_training_time_cache[cache_key] as Dictionary).duplicate(true)

	var service := SkyPositionService.new()
	var latitude := float(location.get("lat", 34.0522))
	var longitude := float(location.get("lon", -118.2437))
	var start_jd := service.julian_date(now)
	var best_time := now.duplicate(true)
	var best_altitude := -90.0
	# Search the next six months in two-hour steps, but only accept local night.
	# Return the earliest comfortable session instead of silently moving the
	# observatory to another continent during the foundation chapter.
	for sample in range(180 * 12):
		var candidate := service.datetime_from_julian(start_jd + float(sample) * (2.0 / 24.0))
		var local_hour := fposmod(
			float(candidate.get("hour", 0)) + float(candidate.get("minute", 0)) / 60.0 + longitude / 15.0,
			24.0
		)
		if local_hour > 6.0 and local_hour < 18.0:
			continue
		var radec := object_radec_at(target_id, candidate)
		if radec.is_empty():
			break
		var alt_az := service.calculate_alt_az_from_ra_dec(
			float(radec["ra_hours"]),
			float(radec["dec_degrees"]),
			latitude,
			longitude,
			candidate
		)
		var altitude := float(alt_az.get("altitude", -90.0))
		if altitude > best_altitude:
			best_altitude = altitude
			best_time = candidate.duplicate(true)
		if altitude >= 28.0:
			best_time["foundation_training"] = true
			foundation_training_time_cache[cache_key] = best_time.duplicate(true)
			return best_time
	best_time["foundation_training"] = true
	foundation_training_time_cache[cache_key] = best_time.duplicate(true)
	return best_time


func target_visibility() -> Dictionary:
	return object_visibility(current_target_object_id())


func object_visibility(object_id: String) -> Dictionary:
	# Real visibility of tonight's target from the current observing location.
	# {has_coords:false} for targets without sky coordinates (never gated).
	var shared := current_sky_position(object_id)
	if not shared.is_empty():
		return {
			"has_coords": true,
			"visible": bool(shared.get("visible", false)),
			"below_horizon": bool(shared.get("below_horizon", float(shared.get("altitude", 0.0)) < 0.0)),
			"altitude": float(shared.get("altitude", 0.0)),
			"azimuth": float(shared.get("azimuth", 0.0)),
			"direction_text": str(shared.get("direction_text", "")),
			"source": str(shared.get("source", "calculated"))
		}
	var observation_time := observation_utc_datetime()
	var radec := object_radec_at(object_id, observation_time)
	if radec.is_empty():
		return {"has_coords": false, "visible": true, "below_horizon": false}
	var loc := observing_location()
	var service := SkyPositionService.new()
	var vis: Dictionary = service.visibility_at(
		float(radec["ra_hours"]), float(radec["dec_degrees"]),
		float(loc.get("lat", 34.0522)), float(loc.get("lon", -118.2437)),
		observation_time)
	vis["has_coords"] = true
	if uses_foundation_training_schedule():
		vis["source"] = "scheduled_calculation"
	return vis


func recommend_observation_location() -> Dictionary:
	return recommend_location_for_object(current_target_object_id())


func recommend_location_for_object(object_id: String, comfortable_altitude := 18.0) -> Dictionary:
	# Prefer a comfortably high target, then reward dark skies. Fall back to any
	# legal above-horizon station so a rare target can never dead-end the player.
	var radec := object_radec(object_id)
	if radec.is_empty():
		return {}
	var service := SkyPositionService.new()
	var best: Dictionary = {}
	var fallback: Dictionary = {}
	var best_score := -INF
	var fallback_score := -INF
	for site_value in location_sites():
		var site: Dictionary = site_value
		var vis: Dictionary = service.visibility_at(
			float(radec["ra_hours"]), float(radec["dec_degrees"]),
			float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
		var altitude := float(vis.get("altitude", -90.0))
		if altitude < 0.0:
			continue
		var bortle := float(site.get("bortle", 5))
		var score := altitude * 4.0 + (9.0 - bortle) * 6.0
		var candidate := {
			"site": site,
			"altitude": altitude,
			"azimuth": float(vis.get("azimuth", 0.0)),
			"direction_text": str(vis.get("direction_text", "")),
			"local_time": service.local_time_string(float(site.get("lon", 0.0))),
			"visible_hours": service.visible_duration_hours(
				float(radec["ra_hours"]), float(radec["dec_degrees"]),
				float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
		}
		if score > fallback_score:
			fallback_score = score
			fallback = candidate
		if altitude >= comfortable_altitude and score > best_score:
			best_score = score
			best = candidate
	return best if not best.is_empty() else fallback


func position_source_label(source: String) -> String:
	# Turns an internal position-source tag into a clear, non-alarming label.
	# Local calculation is a FEATURE, never an error state.
	match source:
		"online":
			return text("AstronomyAPI live", "AstronomyAPI 实时数据")
		"scheduled_calculation":
			return text("Club training schedule", "俱乐部训练时刻")
		"cached":
			return text("Local calculation", "本地计算")
		"calculated", "constellation", "planet", "moon", "planet_ephemeris":
			return text("Local calculation", "本地计算")
		"fallback":
			return text("Teaching simulation", "教学模拟")
		_:
			return text("Offline fallback", "离线备用")


func is_free_observation() -> bool:
	# True when the player has selected a sky object that is NOT tonight's
	# mission target. Free observations never complete or fail the mission.
	if bool(local_optical_observation_context.get("active", false)):
		return true
	var sel := selected_object_id
	return sel != "" and sel != current_target_object_id()


func _local_optical_seed_object_id() -> String:
	var current_selection := selected_object_id
	if current_selection != "" and current_selection != current_target_object_id() and not get_object(current_selection).is_empty():
		return current_selection
	for candidate in ["moon", "jupiter", "saturn", "sirius", "pleiades"]:
		if candidate != current_target_object_id() and not get_object(candidate).is_empty():
			return candidate
	return ""


func begin_local_optical_free_observation() -> bool:
	var family := active_optical_telescope_family()
	if family == "" and not postgraduate_free_build():
		family = assembly_family() if is_player_optical_family(assembly_family()) else ""
	if not is_player_optical_family(family):
		return false
	if assembly_family() != family and postgraduate_free_build():
		var previous_family := assembly_family()
		_store_postgraduate_family_state(previous_family)
		assembly_family_id = family
		progress["selected_telescope_family"] = family
		_restore_postgraduate_family_state(family)
	if not active_optical_telescope_is_ready():
		return false
	var seed_object_id := _local_optical_seed_object_id()
	if seed_object_id == "":
		return false
	remote_observation_context.clear()
	local_optical_observation_context = {
		"active": true,
		"family": family,
	}
	selected_object_id = seed_object_id
	selected_object_level = int(progress.get("current_level", 1))
	current_sky_positions.clear()
	current_sky_location_id = ""
	return true


func is_local_optical_free_observation() -> bool:
	return bool(local_optical_observation_context.get("active", false))


func active_observation_target_object_id() -> String:
	if is_local_optical_free_observation():
		var selected := selected_object_id
		if selected != "" and not get_object(selected).is_empty():
			return selected
	return current_target_object_id()


func go_to_local_optical_observation(spawn: String) -> bool:
	if not begin_local_optical_free_observation():
		return false
	set_observatory_spawn(spawn)
	go("sky")
	return true


func publish_sky_positions(positions: Dictionary) -> void:
	current_sky_positions = positions.duplicate(true)
	current_sky_location_id = str(observing_location().get("id", "home"))


func current_sky_position(object_id: String) -> Dictionary:
	if current_sky_location_id != str(observing_location().get("id", "home")):
		return {}
	var item: Variant = current_sky_positions.get(object_id, {})
	return (item as Dictionary).duplicate(true) if item is Dictionary else {}


func is_observed(object_id: String) -> bool:
	# Whether this object has ever been observed (mission or free). Completely
	# separate from whether it is currently visible - completing a mission never
	# removes the object from the sky.
	return progress.get("observed_objects", []).has(object_id)


func object_detail(object_id: String) -> Dictionary:
	# Combined, panel-ready facts for any catalog object at the current site.
	var obj := get_object(object_id)
	var detail := {
		"id": object_id,
		"name_en": str(obj.get("name_en", object_id)),
		"name_zh": str(obj.get("name_zh", object_id)),
		"type_en": str(obj.get("type_en", "Object")),
		"type_zh": str(obj.get("type_zh", "天体")),
		"magnitude": obj.get("apparent_magnitude", null),
		"constellation_en": str(obj.get("constellation_en", obj.get("constellation", ""))),
		"constellation_zh": str(obj.get("constellation_zh", obj.get("constellation", ""))),
		"distance_en": str(obj.get("distance_en", obj.get("distance", ""))),
		"distance_zh": str(obj.get("distance_zh", obj.get("distance", ""))),
		"learning_en": str(obj.get("learning_text_en", "")),
		"learning_zh": str(obj.get("learning_text_zh", "")),
		"is_mission_target": object_id == current_target_object_id(),
		"is_observed": is_observed(object_id),
		"has_coords": false
	}
	# RA/Dec plus the exact alt/az snapshot currently used by Sky Observation.
	var service := SkyPositionService.new()
	var observation_time := observation_utc_datetime()
	var ra := NAN
	var dec := NAN
	for entry_value in service.catalog:
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) != object_id:
			continue
		if entry.has("ra_hours") and entry.has("dec_degrees"):
			ra = float(entry["ra_hours"])
			dec = float(entry["dec_degrees"])
		elif entry.has("planet_body"):
			var eph: Dictionary = service.planet_ra_dec(str(entry["planet_body"]), observation_time)
			if not eph.is_empty():
				ra = float(eph["ra_hours"])
				dec = float(eph["dec_degrees"])
		break
	var loc := observing_location()
	var shared_position := current_sky_position(object_id)
	if not is_nan(ra):
		detail["has_coords"] = true
		detail["ra_hours"] = ra
		detail["dec_degrees"] = dec
		if not shared_position.is_empty():
			detail["altitude"] = float(shared_position.get("altitude", 0.0))
			detail["azimuth"] = float(shared_position.get("azimuth", 0.0))
			detail["visible"] = bool(shared_position.get("visible", false))
			detail["below_horizon"] = bool(shared_position.get("below_horizon", float(shared_position.get("altitude", 0.0)) < 0.0))
			detail["direction_text"] = str(shared_position.get("direction_text", ""))
		else:
			var vis := service.visibility_at(
				ra, dec,
				float(loc.get("lat", 34.0522)),
				float(loc.get("lon", -118.2437)),
				observation_time)
			detail["altitude"] = float(vis["altitude"])
			detail["azimuth"] = float(vis["azimuth"])
			detail["visible"] = bool(vis["visible"])
			detail["below_horizon"] = bool(vis["below_horizon"])
			detail["direction_text"] = str(vis["direction_text"])
	detail["location_en"] = str(dict_text_for(loc, "name", "en"))
	detail["location_zh"] = str(dict_text_for(loc, "name", "zh"))
	detail["local_time"] = service.local_time_string(float(loc.get("lon", -118.2437)), observation_time)
	# Data provenance (separate from the astronomy itself): planets/Moon use the
	# local ephemeris; catalog stars use local RA/Dec math; anything without
	# coordinates falls back to a teaching position.
	var src := str(shared_position.get("source", "calculated" if detail["has_coords"] else "fallback"))
	detail["position_source_en"] = position_source_label_for(src, "en")
	detail["position_source_zh"] = position_source_label_for(src, "zh")
	detail["weather_source_en"] = "Mission scenario data"
	detail["weather_source_zh"] = "关卡环境数据"
	var now := Time.get_datetime_dict_from_system(false)
	detail["last_updated"] = "%02d:%02d" % [int(now.get("hour", 0)), int(now.get("minute", 0))]
	return detail


func position_source_label_for(source: String, locale: String) -> String:
	var prev := language_mode
	language_mode = locale
	var label := position_source_label(source)
	language_mode = prev
	return label


func _sky_service_offline() -> bool:
	var service := SkyPositionService.new()
	return bool(service.config.get("offline_mode", false)) or not bool(service.config.get("use_online_planet_data", true))


func observation_advice(object_id: String) -> Array:
	# Dynamic per-object + per-equipment observing tips. Returns [{en, zh}].
	var obj := get_object(object_id)
	var type_lower := (str(obj.get("type_en", "")) + " " + object_id).to_lower()
	var tips: Array = []
	var seeing := str(current_environment().get("seeing", "good"))
	if type_lower.contains("nebula") or type_lower.contains("galaxy"):
		tips.append({"en": "Use a LOW magnification and a wide-field eyepiece.", "zh": "使用低倍率和广角目镜。"})
		tips.append({"en": "Let your eyes dark-adapt; use averted vision for faint detail.", "zh": "让眼睛暗适应，用侧视法看暗弱细节。"})
	elif type_lower.contains("cluster"):
		tips.append({"en": "Frame the whole cluster at low power, then push in on member stars.", "zh": "先用低倍率取全景，再放大看成员星。"})
	elif type_lower.contains("planet"):
		tips.append({"en": "Recommended magnification: 80-130x for surface/disk detail.", "zh": "推荐倍率：80-130 倍以看清盘面细节。"})
		if seeing != "good":
			tips.append({"en": "Seeing is unsteady - lower the magnification and wait for calm moments.", "zh": "视宁度不稳，降低倍率并等待大气平静的瞬间。"})
	elif object_id.begins_with("moon"):
		tips.append({"en": "High magnification reveals craters; watch the terminator shadows.", "zh": "高倍率能看清环形山，注意终结线的阴影。"})
	elif type_lower.contains("double"):
		tips.append({"en": "A medium magnification cleanly splits the pair.", "zh": "中等倍率即可干净分开双星。"})
	else:
		tips.append({"en": "A finder scope helps you center this target before high power.", "zh": "先用寻星镜把目标居中，再上高倍率。"})
	if float(current_environment().get("cloud_cover", 0.0)) > 0.0:
		tips.append({"en": "Clouds are crossing the field - wait for a clear gap.", "zh": "有云经过视野——请等待云隙。"})
	return tips


func record_free_observation(object_id: String, observation: Dictionary) -> Dictionary:
	# Writes a FREE observation into the Club Logbook (a separate entry_kind
	# from mission records). Returns {new_record, repeat}. Never completes the
	# mission or unlocks anything; a small credit reward is granted once per
	# distinct (object + equipment + quality) combination.
	_ensure_progress_array("journal_entries")
	_ensure_progress_array("observed_objects")
	var stats := calculate_stats()
	var eyepiece := get_part(equipped_part_id("eyepiece"))
	var family := assembly_family()
	var signature := "%s|%s|%s|%d" % [object_id, family, str(observation.get("quality", "")), int(round(float(stats.get("magnification", 0.0))))]
	var repeat := false
	for entry_value in progress["journal_entries"]:
		var entry: Dictionary = entry_value
		if str(entry.get("entry_kind", "")) == "free_observation" and str(entry.get("signature", "")) == signature:
			repeat = true
			break
	if repeat:
		return {
			"new_record": false,
			"repeat": true,
			"credits_awarded": 0,
			"credits_total": int(progress.get("credits", 0))
		}
	var obj := get_object(object_id)
	progress["journal_entries"].append({
		"object_id": object_id,
		"object_name_en": str(obj.get("name_en", object_id)),
		"object_name_zh": str(obj.get("name_zh", object_id)),
		"object_type_en": str(obj.get("type_en", "")),
		"object_type_zh": str(obj.get("type_zh", "")),
		"entry_kind": "free_observation",
		"signature": signature,
		"observation_quality": str(observation.get("quality", "Good")),
		"observation_mode": "free",
		"telescope_family": family,
		"eyepiece_focal_length_mm": int(eyepiece.get("focal_length_mm", 0)),
		"magnification": float(stats.get("magnification", 0.0)),
		"location_en": str(dict_text_for(observing_location(), "name", "en")),
		"location_zh": str(dict_text_for(observing_location(), "name", "zh")),
		"learning_text_en": str(obj.get("learning_text_en", "")),
		"learning_text_zh": str(obj.get("learning_text_zh", ""))
	})
	if not progress["observed_objects"].has(object_id):
		progress["observed_objects"].append(object_id)
	progress["credits"] = int(progress.get("credits", 0)) + FREE_OBSERVATION_CREDITS
	save()
	return {
		"new_record": true,
		"repeat": false,
		"credits_awarded": FREE_OBSERVATION_CREDITS,
		"credits_total": int(progress.get("credits", 0))
	}


func remote_free_catalog(kind: String) -> Array:
	var root := _load_json_dict(REMOTE_FREE_CATALOG_PATH)
	var entries: Variant = root.get(kind, [])
	return (entries as Array).duplicate(true) if entries is Array else []


func remote_free_entry(kind: String, entry_id: String) -> Dictionary:
	for value in remote_free_catalog(kind):
		var entry := value as Dictionary
		if str(entry.get("id", "")) == entry_id:
			return entry.duplicate(true)
	return {}


func remote_free_unlocked(kind: String) -> bool:
	var first_level := 76 if kind == "radio" else 66
	var completed: Array = progress.get("completed_levels", [])
	if completed.has(first_level) or completed.has(str(first_level)):
		return true
	# Old saves from earlier campaign orders may have a later chapter lesson
	# completed without retaining the first lesson id. Preserve that legal
	# progress instead of relocking the instrument.
	for level_value in completed:
		var number := int(level_value)
		if kind == "space" and number >= 66 and number <= 75:
			return true
		if kind == "radio" and number >= 76 and number <= 85:
			return true
	return int(progress.get("current_level", 1)) > first_level


func begin_remote_campaign(kind: String) -> void:
	local_optical_observation_context.clear()
	remote_observation_context = {
		"mode": "campaign",
		"kind": kind,
		"entry_id": "",
	}


func begin_remote_free_observation(kind: String, entry_id: String) -> bool:
	if not remote_free_unlocked(kind):
		return false
	var entry := remote_free_entry(kind, entry_id)
	if entry.is_empty():
		return false
	local_optical_observation_context.clear()
	remote_observation_context = {
		"mode": "free",
		"kind": kind,
		"entry_id": entry_id,
		"target_id": str(entry.get("target_id", entry_id)),
	}
	return true


func consume_remote_free_intro(kind: String) -> bool:
	_ensure_progress_array("remote_free_intro_seen")
	if progress["remote_free_intro_seen"].has(kind):
		return false
	progress["remote_free_intro_seen"].append(kind)
	save()
	return true


func is_remote_free_observation(kind: String = "") -> bool:
	if str(remote_observation_context.get("mode", "")) != "free":
		return false
	return kind == "" or str(remote_observation_context.get("kind", "")) == kind


func active_remote_free_entry(kind: String = "") -> Dictionary:
	if not is_remote_free_observation(kind):
		return {}
	return remote_free_entry(
		str(remote_observation_context.get("kind", "")),
		str(remote_observation_context.get("entry_id", "")))


func record_remote_free_observation(kind: String, observation: Dictionary) -> Dictionary:
	var entry := active_remote_free_entry(kind)
	if entry.is_empty():
		return {"recorded": false}
	_ensure_progress_array("remote_observation_archive")
	var now := Time.get_datetime_dict_from_system(true)
	var record := {
		"entry_kind": "remote_free_observation",
		"instrument_kind": kind,
		"catalog_entry_id": str(entry.get("id", "")),
		"target_id": str(entry.get("target_id", "")),
		"target_name_en": str(entry.get("name_en", "")),
		"target_name_zh": str(entry.get("name_zh", "")),
		"category_en": str(entry.get("category_en", "")),
		"category_zh": str(entry.get("category_zh", "")),
		"quality": str(observation.get("quality", "Good")),
		"instrument": str(observation.get("instrument", kind)),
		"filter": str(observation.get("filter", "")),
		"exposure": float(observation.get("exposure", observation.get("integration_s", 0.0))),
		"snr": float(observation.get("snr", 0.0)),
		"result_kind": str(entry.get("result_kind", "infrared_composite")),
		"science_en": str(entry.get("science_en", "")),
		"science_zh": str(entry.get("science_zh", "")),
		"observation_utc": "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
			int(now.get("year", 0)), int(now.get("month", 0)), int(now.get("day", 0)),
			int(now.get("hour", 0)), int(now.get("minute", 0)), int(now.get("second", 0))],
	}
	# A remote radio run is a measurement, not just a generic completion badge.
	# Keep the one authoritative product (spectra, folded curve and measured
	# report) so the Learning Journal can reconstruct its thumbnail and exact
	# values without inventing a second set of results.
	if kind == "radio":
		record["radio_observation"] = observation.duplicate(true)
		record["radio_data_product"] = (observation.get("radio_data_product", {}) as Dictionary).duplicate(true)
		record["pulse_period_ms"] = float(observation.get("pulse_period_ms", 0.0))
		record["dispersion_measure"] = float(observation.get("dispersion_measure", 0.0))
		record["pulse_width_ms"] = float(observation.get("pulse_width_ms", 0.0))
		record["confidence"] = float(observation.get("confidence", 0.0))
		record["candidate_model"] = str(observation.get("candidate_model", ""))
		record["sky_position"] = (observation.get("sky_position", {}) as Dictionary).duplicate(true)
		record["observed_at_unix"] = float(observation.get("observed_at_unix", Time.get_unix_time_from_system()))
	progress["remote_observation_archive"].append(record)
	save()
	return {"recorded": true, "record": record}


func badge_display_name(badge: String) -> String:
	if language_mode == "zh":
		return str(BADGE_NAMES_ZH.get(badge, badge))
	return badge


func dict_text_for(d: Dictionary, key: String, locale: String) -> String:
	return str(d.get(key + "_" + locale, d.get(key + "_en", "")))


func record_horizon_lesson_if_first() -> void:
	# First relocation ever writes a Club Logbook entry about horizons.
	if bool(progress.get("horizon_lesson_recorded", false)):
		return
	progress["horizon_lesson_recorded"] = true
	_ensure_progress_array("journal_entries")
	progress["journal_entries"].append({
		"object_id": "horizon_lesson",
		"object_name_en": "Horizons, Latitude & Location",
		"object_name_zh": "地平线、纬度与观测地点",
		"object_type_en": "Field note",
		"object_type_zh": "观测笔记",
		"level_completed": int(progress.get("current_level", 1)),
		"observation_quality": "Note",
		"learning_text_en": "A target below the horizon is not a broken telescope - Earth's rotation and your latitude decide what has risen. Travel to a site where it is up.",
		"learning_text_zh": "目标在地平线以下不代表望远镜坏了——地球自转和你所在的纬度决定了什么已经升起。前往它已升到地平线以上的地点即可观测。",
		"observation_mode": "location",
		"entry_kind": "field_note"
	})
	save()


func go_to_observation(spawn: String) -> void:
	# Observation doors always enter Sky Observation. Sky owns the decision to
	# offer relocation; the base/lobby never opens or controls the world map.
	set_observatory_spawn(spawn)
	local_optical_observation_context.clear()
	_select_current_mission_target()
	go("sky")


func open_world_map(return_scene_key := "sky") -> void:
	# The map never owns mission progression. It only changes an observing site
	# after a deliberate confirmation. It is a child workflow of Sky Observation.
	if return_scene_key != "sky" or uses_foundation_training_schedule():
		return
	world_map_return_scene = "sky"
	go("world_map")


func return_from_world_map() -> void:
	world_map_return_scene = "sky"
	go("sky")


func target_requires_relocation() -> bool:
	if uses_foundation_training_schedule():
		return false
	# True only when the target genuinely cannot be observed from here now AND a
	# reachable site exists where it IS up - otherwise we never dead-end a
	# lesson, and the sky view keeps its teaching-fallback position.
	var vis := target_visibility()
	if not bool(vis.get("has_coords", false)):
		return false
	# "Too low for a good observation" belongs in Sky's guidance. Automatic
	# relocation is reserved for a body that is physically below the horizon.
	if not bool(vis.get("below_horizon", false)):
		return false
	return not recommend_observation_location().is_empty()


func site_info() -> Dictionary:
	var env := current_environment()
	var sky := str(env.get("sky_brightness", "suburban"))
	var region_en := "Suburban ridge, San Gabriel foothills"
	var region_zh := "郊区山脊 · 圣加布里埃尔山麓"
	var bortle := "Bortle 5"
	match sky:
		"city":
			region_en = "City rooftop field trip"
			region_zh = "城市天台（本关外出观测）"
			bortle = "Bortle 8"
		"dark":
			region_en = "Dark-sky camp field trip"
			region_zh = "暗夜营地（本关外出观测）"
			bortle = "Bortle 3"
	var seeing := str(env.get("seeing", "good"))
	var seeing_score := 8
	match seeing:
		"average": seeing_score = 6
		"poor": seeing_score = 3
	var cloud_pct := int(round(float(env.get("cloud_cover", 0.0)) * 100.0))
	var weather_index: int = clampi(seeing_score - cloud_pct / 20, 1, 10)
	return {
		"lat": "34.05° N", "lon": "118.24° W", "altitude": "1100 m",
		"region_en": region_en, "region_zh": region_zh, "bortle": bortle,
		"seeing": seeing, "cloud_pct": cloud_pct, "weather_index": weather_index
	}


func assembly_hints_enabled() -> bool:
	return bool(progress.get("assembly_hints_enabled", true))


func set_assembly_hints(enabled: bool) -> void:
	progress["assembly_hints_enabled"] = enabled
	save()


# ------------------------------------------------- auto-equip (scored)
# Task profile for part scoring: what does TONIGHT's observation reward?
func _task_profile() -> String:
	var target_type := str(current_target().get("type_en", "")).to_lower()
	if target_type.contains("nebula") or target_type.contains("galaxy") or target_type.contains("cluster"):
		return "deep_sky"
	if str(current_environment().get("seeing", "")) == "poor":
		return "steady"
	return "planet"


# Composite performance score of a part under the given task profile.
func _part_score(part: Dictionary, profile: String) -> float:
	var s := 0.0
	s += float(part.get("quality", 0.0))
	s += float(part.get("stability", 0.0)) * (1.5 if profile == "steady" else 0.8)
	s += float(part.get("stability_bonus", 0.0))
	s += float(part.get("alignment_quality", 0.0)) * 0.5
	s += float(part.get("tracking", 0.0)) * (1.2 if profile == "steady" else 0.5)
	if bool(part.get("tracking_capable", false)):
		s += 25.0 if profile == "steady" else 12.0
	s += (float(part.get("focus_sensitivity", 0.0)) + float(part.get("focus_stability", 0.0))) * 30.0
	s += float(part.get("aim_assist", 0.0))
	var aperture := float(part.get("aperture_mm", 0.0))
	if aperture > 0.0:
		s += log(aperture) * (22.0 if profile == "deep_sky" else 10.0)
	if str(part.get("type", "")) == "eyepiece":
		var focal := float(part.get("focal_length_mm", 20.0))
		s += float(part.get("field_of_view", 0.0)) * (0.8 if profile == "deep_sky" else 0.3)
		if profile == "planet":
			# Planetary detail wants magnification: shorter focal = higher power.
			s += (40.0 - focal) * 2.5
		else:
			# Deep sky / rough air want the wide, bright, forgiving field.
			s += focal * 2.0
	return s


# The exact part id this level PINS for a slot type ("" = free slot).
func pinned_part_id(part_type: String) -> String:
	if postgraduate_free_build():
		return ""
	for required_id_value in current_level().get("required_part_ids", []):
		var part := get_part(str(required_id_value))
		if str(part.get("type", "")) == part_type:
			return str(part.get("id", ""))
	return ""


# Best unlocked, family-compatible part for a slot under tonight's profile.
func best_part_for_type(part_type: String) -> Dictionary:
	var profile := _task_profile()
	var best: Dictionary = {}
	var best_score := -1.0
	var current_family := assembly_context_family()
	for option_value in unlocked_parts_by_type(part_type):
		var option: Dictionary = option_value
		var part_family := str(option.get("telescope_family", ""))
		if part_family != "" and part_family != current_family:
			continue
		if part_type == "eyepiece" and not eyepiece_meets_active_magnification(option):
			continue
		var score := _part_score(option, profile)
		if score > best_score:
			best_score = score
			best = option
	return best


func eyepiece_meets_active_magnification(eyepiece: Dictionary) -> bool:
	var requirements := active_observation_requirements()
	if not requirements.has("magnification_min") and not requirements.has("magnification_max"):
		return true
	var objective_type := "primary_mirror" if current_level().get("required_parts", []).has("primary_mirror") else "objective"
	var objective_id := pinned_part_id(objective_type)
	var objective := get_part(objective_id) if objective_id != "" else best_part_for_type(objective_type)
	if objective.is_empty():
		objective = get_part(equipped_part_id(objective_type))
	var objective_focal := float(objective.get("focal_length_mm", 0.0))
	var eyepiece_focal := float(eyepiece.get("focal_length_mm", 0.0))
	if objective_focal <= 0.0 or eyepiece_focal <= 0.0:
		return true
	var magnification := objective_focal / eyepiece_focal
	return (
		(not requirements.has("magnification_min") or magnification >= float(requirements["magnification_min"]))
		and (not requirements.has("magnification_max") or magnification <= float(requirements["magnification_max"]))
	)


func recommended_space_instrument_type() -> String:
	if assembly_context_family() != "space_segmented" or postgraduate_free_build():
		return ""
	var profile: Dictionary = current_level().get("space_profile", {})
	return str(SPACE_INSTRUMENT_PART_TYPES.get(str(profile.get("best_instrument", "nircam")), ""))


func _auto_reason(part_type: String, profile: String, part: Dictionary) -> Dictionary:
	match part_type:
		"eyepiece":
			var focal := int(part.get("focal_length_mm", 0))
			if profile == "planet":
				return {"en": "Planetary detail needs power: the %dmm eyepiece gives the highest usable magnification." % focal,
					"zh": "行星/恒星细节需要倍率：%dmm 目镜提供最高可用放大倍数。" % focal}
			if profile == "steady":
				return {"en": "Rough air punishes high power: the %dmm keeps the image low-power and steady." % focal,
					"zh": "视宁度差时高倍率吃亏：%dmm 目镜保持低倍率、画面更稳。" % focal}
			return {"en": "Deep sky wants a wide, bright field: the %dmm shows the most sky." % focal,
				"zh": "深空目标需要宽而亮的视场：%dmm 目镜视场最大。" % focal}
		"mount":
			if bool(part.get("tracking_capable", false)):
				return {"en": "Highest stability, and its tracking motor cancels Earth-rotation drift.",
					"zh": "稳定性最高，且追踪马达能抵消地球自转漂移。"}
			return {"en": "Highest stability of the compatible mounts.", "zh": "兼容支架中稳定性最高。"}
		"objective", "primary_mirror":
			return {"en": "Largest aperture: %dmm collects the most light." % int(part.get("aperture_mm", 0)),
				"zh": "口径最大：%dmm 收集的光最多。" % int(part.get("aperture_mm", 0))}
		"finder_scope":
			return {"en": "Best available finder for this chapter.", "zh": "当前章节可用的最佳寻星镜。"}
		"focus_knob", "focuser":
			return {"en": "Finest focus control available.", "zh": "可用调焦部件中控制精度最高。"}
	return {"en": "Highest overall score among compatible parts.", "zh": "兼容零件中综合评分最高。"}


# One-click best loadout for the CURRENT level and target. Returns a plan
# WITHOUT touching the save - the cabinet shows a preview (with per-part
# reasons) and only applies on confirmation.
#
# Selection order per slot: family compatibility -> unlocked -> the level's
# PINNED part if any (teaching levels, shown with the teaching reason) ->
# otherwise the highest-scoring candidate for tonight's task profile.
func auto_equip_plan() -> Array:
	var profile := _task_profile()
	var plan: Array = []
	var slot_types: Array = []
	for type_value in _effective_required_parts():
		if str(type_value) != "optical_tube_assembly" and not slot_types.has(str(type_value)):
			slot_types.append(str(type_value))
	for type_value in current_level().get("required_parts", []):
		if str(type_value) != "optical_tube_assembly" and not slot_types.has(str(type_value)):
			slot_types.append(str(type_value))
	var science_type := recommended_space_instrument_type()
	if science_type != "" and not slot_types.has(science_type):
		slot_types.append(science_type)
	for slot_value in slot_types:
		var part_type := str(slot_value)
		var pending_step_id := pending_mission_step_part_id(part_type)
		if pending_step_id != "" and progress.get("unlocked_parts", []).has(pending_step_id):
			var pending_part := get_part(pending_step_id)
			plan.append(_auto_equip_entry(part_type, pending_part, true, {
				"en": "The current experiment requires this exact part.",
				"zh": "当前未完成的实验指定使用该零件。"
			}))
			continue
		var pinned_id := pinned_part_id(part_type)
		if pinned_id != "" and progress.get("unlocked_parts", []).has(pinned_id):
			var pinned := get_part(pinned_id)
			plan.append(_auto_equip_entry(part_type, pinned, true, {
				"en": "This lesson prescribes this exact part - it is what the level is teaching.",
				"zh": "本关指定使用该零件——这正是本关要学习/要求的设备。"
			}))
			continue
		var best := best_part_for_type(part_type)
		if best.is_empty():
			continue
		var reason := _auto_reason(part_type, profile, best)
		if part_type == science_type:
			reason = {
				"en": "This target's observing plan recommends this science instrument. Install it on the Instruments blueprint before observing.",
				"zh": "本关目标的观测计划推荐使用该科学仪器。请先在“科学仪器”蓝图页安装，再开始观测。"
			}
		plan.append(_auto_equip_entry(part_type, best, false, reason))
	return plan


func _auto_equip_entry(part_type: String, part: Dictionary, pinned: bool, reason: Dictionary) -> Dictionary:
	return {
		"part_type": part_type,
		"part_id": str(part.get("id", "")),
		"name_en": str(part.get("name_en", part.get("id", ""))),
		"name_zh": str(part.get("name_zh", part.get("id", ""))),
		"changed": equipped_part_id(part_type) != str(part.get("id", "")),
		"pinned": pinned,
		"reason_en": str(reason.get("en", "")),
		"reason_zh": str(reason.get("zh", ""))
	}


func apply_auto_equip(plan: Array) -> int:
	var applied := 0
	for entry_value in plan:
		var entry: Dictionary = entry_value
		if bool(entry.get("changed", false)) and equip_part(str(entry.get("part_id", ""))):
			applied += 1
	return applied


func try_story_mechanic(mechanic: String, return_scene_key: String, follow_trigger: String = "") -> bool:
	if not uses_full_tutorials():
		return false
	return StoryManager.begin_mechanic_event(mechanic, return_scene_key, follow_trigger)


func try_story_epilogue(level_number: int, return_scene_key: String) -> bool:
	return StoryManager.begin_epilogue(level_number, return_scene_key)


func set_room_guidance(target: String, title: String, hint: String) -> void:
	room_guidance_target = target
	room_guidance_title = title
	room_guidance_hint = hint


func clear_room_guidance() -> void:
	room_guidance_target = ""
	room_guidance_title = ""
	room_guidance_hint = ""


func update_room_guidance_for_level() -> void:
	var route := current_room_route()
	set_room_guidance(
		str(route.get("target", "")),
		str(route.get("title", "")),
		str(route.get("hint", ""))
	)


func campaign_completed() -> bool:
	return bool(progress.get("program_completed", false))


func graduation_pending() -> bool:
	return campaign_completed() and bool(progress.get("graduation_pending", false)) \
		and not bool(progress.get("graduation_seen", false))


func mark_graduation_presented() -> void:
	if not campaign_completed():
		return
	progress["graduation_seen"] = true
	progress["graduation_pending"] = false
	transfer_unlocked_optical_equipment_ownership()
	save()


func postgraduate_room_route() -> Dictionary:
	if graduation_pending():
		return {
			"target": "mission",
			"title": text("Maya: Graduation Ceremony", "玛雅：毕业典礼"),
			"hint": text(
				"The observing program is complete. Your graduation ceremony is ready.",
				"观测课程已经全部完成。你的毕业典礼已经准备好了。"
			),
			"action": text("Attend the Graduation Ceremony", "参加毕业典礼"),
			"outcome": text("Receive the Young Observer badge and review your full record.", "领取青年观测员徽章，并回顾完整的观测记录。"),
			"ready": true,
			"completed": true
		}
	return {
		# The observatory stays open, but graduation ends the mandatory route.
		# No furniture is recreated as a permanent next step after the ceremony.
		"target": "",
		"title": text("Maya: Program Complete", "玛雅：课程已完成"),
		"hint": text(
			"You have graduated from the club program. The observatory and your logbook remain open for independent observing.",
			"你已经从俱乐部课程毕业。天文台与观测日志仍会开放，可继续自主观测。"
		),
		"action": text("Review the Club Logbook", "查看俱乐部观测日志"),
		"outcome": text("Completed missions remain archived and will not restart automatically.", "已完成任务会永久归档，不会自动重新开始。"),
		"ready": true,
		"completed": true
	}


func route_outcome_text() -> String:
	# "What happens after": the reward the guided step leads to.
	var pieces: Array[String] = []
	var concept := current_concept_card()
	if not concept.is_empty() and not completed_concept_cards().has(str(concept.get("id", ""))):
		pieces.append(text("learn \"" + dict_text(concept, "title") + "\"", "学到「" + dict_text(concept, "title") + "」"))
	var unlock_names: Array[String] = []
	for part_id_value in current_level().get("unlock_parts", []):
		var part := get_part(str(part_id_value))
		if not part.is_empty():
			unlock_names.append(dict_text(part, "name"))
	if not unlock_names.is_empty():
		pieces.append(text("unlock " + ", ".join(unlock_names), "解锁 " + "、".join(unlock_names)))
	if pieces.is_empty():
		return ""
	return text("Complete this mission to ", "完成本关将") + text(" and ", "并").join(pieces) + text(".", "。")


func _required_equipment_route(required_missing: Array) -> Dictionary:
	var required_id := str(required_missing[0])
	var required_part := get_part(required_id)
	var part_type := str(required_part.get("type", ""))
	var required_name := dict_text(required_part, "name") if not required_part.is_empty() else required_id
	var equipped_id := equipped_part_id(part_type)
	var equipped_part := get_part(equipped_id)
	var equipped_name := dict_text(equipped_part, "name") if not equipped_part.is_empty() else ""
	var total_required := int(current_level().get("required_part_ids", []).size())
	var matched_required := maxi(0, total_required - required_missing.size())
	var progress_en := "Required loadout matched: %d/%d." % [matched_required, total_required]
	var progress_zh := "本关指定配置已匹配：%d/%d。" % [matched_required, total_required]
	var title_en := "Maya: Equip " + required_name
	var title_zh := "玛雅：装备" + required_name
	var hint_en := "Required: " + required_name + ". " + progress_en
	var hint_zh := "本关指定：" + required_name + "。" + progress_zh
	if equipped_name != "" and equipped_id != required_id:
		title_en = "Maya: Replace " + equipped_name
		title_zh = "玛雅：更换" + equipped_name
		hint_en = "Equipped: %s. This mission specifically requires %s; higher stats do not replace the prescribed part. %s" % [equipped_name, required_name, progress_en]
		hint_zh = "当前装备：%s。本关指定：%s；数值更高也不能替代指定零件。%s" % [equipped_name, required_name, progress_zh]
	return {
		"target": "cabinet",
		"title": text(title_en, title_zh),
		"hint": text(hint_en, hint_zh),
		"action": text("Equip " + required_name, "装备" + required_name),
		"outcome": text("Then return to the Assembly Table. The guide will check the next item automatically.", "然后返回组装台；引导会自动检查下一项。"),
		"ready": false,
		"missing": required_missing,
		"required_part_id": required_id,
		"equipped_part_id": equipped_id,
		"matched_required": matched_required,
		"total_required": total_required
	}


func pending_mission_step_part_id(part_type: String = "") -> String:
	var step := next_pending_mission_step()
	if step.is_empty():
		return ""
	var required_id := str(step.get("require_part_id", ""))
	if required_id == "":
		return ""
	if part_type == "":
		return required_id
	var part := get_part(required_id)
	return required_id if str(part.get("type", "")) == part_type else ""


func _pending_mission_step_equipment_route() -> Dictionary:
	var step := next_pending_mission_step()
	var required_id := pending_mission_step_part_id()
	if step.is_empty() or required_id == "":
		return {}
	var part := get_part(required_id)
	if part.is_empty():
		return {}
	var part_type := str(part.get("type", ""))
	var required_name := dict_text(part, "name")
	var step_name := dict_text(step, "label")
	var unlocked: Array = progress.get("unlocked_parts", [])
	if not unlocked.has(required_id):
		return {
			"target": "cabinet",
			"title": text("Maya: Experiment equipment is still locked", "玛雅：实验设备尚未解锁"),
			"hint": text(
				"This experiment needs %s, but it has not been unlocked yet." % required_name,
				"本次实验需要%s，但它尚未解锁。" % required_name
			),
			"action": text("Review the Parts Cabinet", "查看零件柜"),
			"outcome": text("Continue the course to unlock this component.", "继续完成课程即可解锁该零件。"),
			"ready": false,
			"required_part_id": required_id
		}

	var equipped_id := equipped_part_id(part_type)
	if equipped_id != required_id:
		var equipped_part := get_part(equipped_id)
		var equipped_name := dict_text(equipped_part, "name") if not equipped_part.is_empty() else text("none", "未装备")
		return {
			"target": "cabinet",
			"title": text("Maya: Prepare the next eyepiece test", "玛雅：准备下一档目镜实验"),
			"hint": text(
				"Next experiment: %s. You currently have %s equipped; choose %s in the Parts Cabinet." % [step_name, equipped_name, required_name],
				"下一项实验：%s。当前装备的是%s，请到零件柜换成%s。" % [step_name, equipped_name, required_name]
			),
			"action": text("Equip " + required_name, "装备" + required_name),
			"outcome": text(
				"Then install it at the Assembly Table before returning to the Observation Pad.",
				"随后到组装台重新安装，再返回观测台。"
			),
			"ready": false,
			"required_part_id": required_id,
			"equipped_part_id": equipped_id
		}

	var slot_value: Variant = progress.get("assembly_state", {}).get(part_type, {})
	var slot: Dictionary = slot_value if slot_value is Dictionary else {}
	var installed_id := str(slot.get("installed_part_id", ""))
	var installed_current := bool(slot.get("installed", false)) and (installed_id == "" or installed_id == required_id)
	if not installed_current:
		return {
			"target": "assembly",
			"title": text("Maya: Install the experiment eyepiece", "玛雅：安装实验目镜"),
			"hint": text(
				"%s is equipped. Install it at the Assembly Table before observing again." % required_name,
				"%s已经装备，请先到组装台完成安装，再进行下一次观测。" % required_name
			),
			"action": text("Install " + required_name, "安装" + required_name),
			"outcome": text("The Observation Pad reopens after the eyepiece is installed.", "目镜安装完成后，观测台会重新开放。"),
			"ready": false,
			"required_part_id": required_id
		}
	return {}


func current_room_route() -> Dictionary:
	# The observatory, mission board, result card, and route indicator all use
	# this one decision. It keeps the next physical action consistent.
	if campaign_completed():
		return postgraduate_room_route()
	# Choice assessments have no physical destination until the player has
	# actually selected an object. The level's fallback target keeps legacy
	# data callers safe, but must never leak into player-facing guidance as if
	# the choice had already been made.
	if level_requires_target_choice() and not has_chosen_level_target():
		return {
			"target": "mission",
			"title": text("Maya: Choose tonight's target", "玛雅：选择今晚的目标"),
			"hint": text(
				"Open the Mission Board and choose the Moon, Saturn, or the Pleiades before equipping the telescope.",
				"先打开任务板，从月球、土星和昴星团中选择一个目标，再为望远镜配装。"
			),
			"action": text("Choose a target on the Mission Board", "在任务板上选择目标"),
			"outcome": text("Your chosen target sets the eyepiece test for tonight.", "你选择的目标会决定今晚要匹配的目镜。"),
			"ready": false,
			"choice_pending": true
		}
	var target_name := dict_text(current_target(), "name")
	if current_observation_mode() == "naked_eye":
		return _with_site_route_status({
			"target": "telescope",
			"title": text("Maya: Observation Pad", "玛雅：观测台"),
			"hint": text("Use naked-eye observation to find " + target_name + ".", "用肉眼观测寻找" + target_name + "。"),
			"action": text("Go to the Observation Pad", "前往观测台"),
			"outcome": route_outcome_text(),
			"ready": true
		})

	if has_locked_required_equipment():
		var lock_reason := required_equipment_lock_reason()
		return {
			"target": "cabinet",
			"title": text("Maya: Required equipment locked", "玛雅：任务设备尚未解锁"),
			"hint": text(str(lock_reason.get("reason_en", "")), str(lock_reason.get("reason_zh", ""))),
			"action": text("Review the Parts Cabinet", "查看零件柜"),
			"outcome": text("The mission opens after the required equipment is unlocked, equipped, and installed.", "解锁、装备并安装所需设备后，本关才会开放。"),
			"ready": false,
			"locked": locked_required_equipment()
		}

	var required_missing: Array = missing_required_parts()
	if not required_missing.is_empty():
		return _required_equipment_route(required_missing)

	var mission_step_route := _pending_mission_step_equipment_route()
	if not mission_step_route.is_empty():
		return mission_step_route

	var assembly_missing: Array = missing_parts()
	if not assembly_missing.is_empty() or not telescope_is_ready():
		var install_names: Array[String] = []
		for part_type_value in assembly_missing:
			var part_type := str(part_type_value)
			var selected_part := get_part(equipped_part_id(part_type))
			var part_name := dict_text(selected_part, "name") if not selected_part.is_empty() else part_type.capitalize()
			if not install_names.has(part_name):
				install_names.append(part_name)
		var install_text := ", ".join(install_names)
		var focus_missing := assembly_missing.has("focus_knob")
		var hint := text(
			"Prepare %s by installing %s at the Assembly Table." % [target_name, install_text],
			"为观测%s做准备：请在组装台安装%s。" % [target_name, install_text]
		)
		if focus_missing:
			hint = text(
				"Before observing %s, install the Focus Knob near the eyepiece." % target_name,
				"观测%s之前，请在目镜附近安装调焦旋钮。" % target_name
			)
		return {
			"target": "assembly",
			"title": text("Maya: Assembly Table", "玛雅：组装台"),
			"hint": hint,
			"action": text("Prepare %s: install %s" % [target_name, install_text], "准备观测%s：安装%s" % [target_name, install_text]),
			"outcome": text("A finished telescope unlocks the Observation Pad.", "望远镜组装完成后，观测台即可使用。"),
			"ready": false,
			"missing": assembly_missing
		}

	if bool(current_level().get("requires_collimation", false)) and not collimation_is_acceptable():
		var collimation_now := roundi(collimation_score())
		var collimation_target := int(current_level().get("collimation_threshold", 80))
		return {
			"target": "assembly",
			"title": text("Maya: Collimation Bench", "玛雅：准直工作台"),
			"hint": text(
				"Collimation is %d%%; this mission requires at least %d%%. Open the Assembly Table and choose Collimate Mirrors." % [collimation_now, collimation_target],
				"当前准直 %d%%；本关至少需要 %d%%。进入组装台后点击“准直镜面”。" % [collimation_now, collimation_target]
			),
			"action": text("Collimate the reflector", "为反射镜准直"),
			"outcome": text("A collimated mirror gives sharp, centered images.", "准直合格后，反射镜才能给出清晰居中的图像。"),
			"ready": false
		}

	if current_level().get("required_part_ids", []).is_empty() and _deep_sky_target() and str(current_level().get("minimum_success_quality", "Good")) == "Good" and _has_better_unequipped_part():
		return {
			"target": "cabinet",
			"title": text("Maya: Upgrade the optics", "玛雅：升级光学部件"),
			"hint": text("Equip the stronger unlocked optics for this faint target.", "为这个暗弱目标装备刚解锁的更强光学部件。"),
			"action": text("Choose a better optical part", "选择更好的光学部件"),
			"outcome": text("More aperture means a brighter deep-sky image.", "更大口径意味着更亮的深空图像。"),
			"ready": false
		}

	if str(current_level().get("telescope_family", "")) == "space_segmented":
		return _with_site_route_status({
			"target": "computer",
			"title": text("Maya: Space Telescope Console", "玛雅：空间望远镜控制台"),
			"hint": text("The L2 observatory is ready for %s. Use the bottom-right console to open the command link." % target_name,
				"L2 望远镜已经准备观测%s。使用右下角控制台打开指挥链路。" % target_name),
			"action": text("Command the infrared observation of " + target_name, "指挥红外观测" + target_name),
			"outcome": route_outcome_text(),
			"ready": true
		})
	if str(current_level().get("telescope_family", "")) == "fast_radio" \
			or str(current_level().get("observation_mode", "")) == "radio":
		return _with_site_route_status({
			"target": "computer",
			"title": text("Maya: FAST Radio Telescope Console", "玛雅：FAST 射电望远镜控制台"),
			"hint": text(
				"FAST is ready for %s. Use the bottom-right console to open the radio command link." % target_name,
				"FAST 已准备观测%s。使用右下角控制台打开射电指挥链路。" % target_name),
			"action": text("Command the radio observation of " + target_name, "指挥射电观测" + target_name),
			"outcome": route_outcome_text(),
			"ready": true
		})
	return _with_site_route_status({
		"target": "telescope",
		"title": text("Maya: Observation Pad", "玛雅：观测台"),
		"hint": text("The telescope is ready. Find and observe " + target_name + ".", "望远镜已准备好。寻找并观测" + target_name + "。"),
		"action": text("Observe " + target_name, "观测" + target_name),
		"outcome": route_outcome_text(),
		"ready": true
	})


func _with_site_route_status(route: Dictionary) -> Dictionary:
	# The lobby never opens the map. It only explains what will happen after the
	# player enters the Observation Pad, keeping travel under Sky Observation.
	#
	# A SPACE observatory is not on the ground: an object below the local horizon
	# is irrelevant to a telescope at Sun-Earth L2, and telling the player to
	# "travel to a visible site" would be both wrong and unfollowable. Space
	# levels use their own attitude / sun-angle constraints inside the space
	# observation screen instead.
	if str(current_level().get("telescope_family", "")) in ["space_segmented", "fast_radio"]:
		route["needs_site_change"] = false
		route["remote_instrument"] = true
		route["space_constraints"] = str(current_level().get("telescope_family", "")) == "space_segmented"
		return route
	var visibility := target_visibility()
	var altitude := float(visibility.get("altitude", 0.0))
	var needs_site_change := bool(visibility.get("has_coords", false)) and bool(visibility.get("below_horizon", false))
	route["needs_site_change"] = needs_site_change
	route["target_altitude"] = altitude
	if needs_site_change:
		route["hint"] = text(
			"%s is below the horizon here (Alt %.1f°). Enter the Observation Pad; it will explain the horizon and open the Site Map." % [dict_text(current_target(), "name"), altitude],
			"%s 在当前地点位于地平线以下（高度角 %.1f°）。进入观测台后，系统会讲解地平线并打开地点地图。" % [dict_text(current_target(), "name"), altitude]
		)
		route["action"] = text("Enter Observation, then choose a visible site", "进入观测台，再选择可见地点")
		route["outcome"] = text("The same target and mission resume after travel.", "移动后会恢复同一目标和当前任务。")
	return route


func _part_name_list(part_ids: Array) -> String:
	var names: Array[String] = []
	for part_id_value in part_ids:
		var part := get_part(str(part_id_value))
		var part_name := dict_text(part, "name") if not part.is_empty() else str(part_id_value)
		if not names.has(part_name):
			names.append(part_name)
	return ", ".join(names)


func _deep_sky_target() -> bool:
	var type_lower := str(current_target().get("type_en", "")).to_lower()
	return type_lower.contains("nebula") or type_lower.contains("galaxy")


func _has_better_unequipped_part() -> bool:
	# Unlocked upgrades (later entries in parts_data) that are not equipped.
	for part_type in ["objective", "mount"]:
		var options: Array = unlocked_parts_by_type(part_type)
		if options.size() < 2:
			continue
		var best_id := str(options[options.size() - 1].get("id", ""))
		if equipped_part_id(part_type) != best_id:
			return true
	return false


func set_room_guidance_for_scene(scene_key: String, trigger: String = "") -> void:
	var target := ""
	var title := ""
	var hint := ""
	match scene_key:
		"assembly":
			target = "assembly"
			title = text("Maya: Assembly Table", "玛雅：组装台")
			hint = text("Walk to the Assembly Table and press E.", "前往组装台，按 E 键互动。")
		"sky", "telescope":
			target = "telescope"
			title = text("Maya: Observation Pad", "玛雅：观测台")
			hint = text("Walk to the Observation Pad and press E.", "前往观测台，按 E 键互动。")
		"interior":
			target = "door"
			title = text("Maya: Observatory Door", "玛雅：天文台入口")
			hint = text("Walk to the Observatory Door and press E.", "前往天文台入口，按 E 键互动。")
		"parts":
			target = "cabinet"
			title = text("Maya: Parts Cabinet", "玛雅：零件柜")
			hint = text("Walk to the Parts Cabinet and press E.", "前往零件柜，按 E 键互动。")
	var assembly_state: Dictionary = progress.get("assembly_state", {})
	var focus_entry: Dictionary = assembly_state.get("focus_knob", {})
	if trigger == "before_focus" and not bool(focus_entry.get("installed", false)):
		target = "assembly"
		title = text("Maya: Install the Focus Knob", "玛雅：安装调焦旋钮")
		hint = text(
			"Install the Focus Knob at the Assembly Table before focusing.",
			"请先在组装台安装调焦旋钮，再进行调焦。"
		)
	if target != "":
		set_room_guidance(target, title, hint)


func mission_board_note() -> Dictionary:
	return StoryManager.board_note_for_level(int(current_level().get("level_number", 0)))


# --------------------------------------------------- teaching flow wrappers


func try_teaching_intercept(trigger: String, return_scene_key: String, return_payload: Dictionary = {}) -> bool:
	if not uses_full_tutorials():
		return false
	return TeachingFlowManager.begin_step(current_level(), trigger, return_scene_key, return_payload)


func show_concept_brief(card_id: String, return_scene_key: String) -> void:
	if not TeachingFlowManager.show_brief(card_id, return_scene_key):
		go(return_scene_key)


func current_learning_card_mode() -> String:
	return TeachingFlowManager.active_card_mode


func current_brief_card() -> Dictionary:
	return get_learning_card(TeachingFlowManager.active_card_id)


func complete_current_brief() -> void:
	TeachingFlowManager.complete_active_brief(progress)
	save()
	go(TeachingFlowManager.consume_return_scene())


func show_mission_complete_card(payload: Dictionary) -> void:
	TeachingFlowManager.show_mission_complete(payload)


func can_enter_observation() -> Dictionary:
	# Some later instruments (infrared and radio) are not player-held
	# telescopes, but they still need their own assembled hardware. Only true
	# naked-eye lessons may bypass equipment and collimation checks.
	var level := current_level()
	if current_observation_mode() != "naked_eye" and has_locked_required_equipment():
		return required_equipment_lock_reason().merged({"ok": false}, true)
	if current_observation_mode() != "naked_eye" and not current_requires_telescope():
		if not missing_required_parts().is_empty():
			return {"ok": false, "reason_en": "Required equipment is not selected. Use the Parts Cabinet first.", "reason_zh": "尚未选择所需设备。请先前往零件柜。"}
		if not missing_parts().is_empty():
			return {"ok": false, "reason_en": "Equipment is not assembled. Use the Assembly Table.", "reason_zh": "设备尚未组装。请前往组装台。"}
		if bool(level.get("requires_collimation", false)) and not collimation_is_acceptable():
			return {"ok": false, "reason_en": "Collimation is required. Return to the Assembly Table and align the optical axis.", "reason_zh": "需要先完成准直。请回到组装台校正光轴。"}
	if current_observation_mode() == "naked_eye":
		return {
			"ok": true,
			"reason_en": "Naked eye observation - no telescope needed.",
			"reason_zh": "肉眼观测——不需要望远镜。"
		}
	if telescope_is_ready():
		if bool(current_level().get("requires_collimation", false)) and not collimation_is_acceptable():
			return {
				"ok": false,
				"reason_en": "Collimation is required. Return to the Assembly Table and align the optical axis.",
				"reason_zh": "需要先完成准直。请回到组装台校正光轴。"
			}
		return {"ok": true, "reason_en": "", "reason_zh": ""}
	var missing: Array = missing_parts()
	var names_en: Array[String] = []
	var names_zh: Array[String] = []
	for part_type_value in missing:
		var part_type := str(part_type_value)
		names_en.append(part_type.capitalize())
		names_zh.append(AssemblyManagerScript._zh_name(part_type))
	return {
		"ok": false,
		"reason_en": "Telescope not ready. Missing: " + ", ".join(names_en) + ". Use the Assembly Table.",
		"reason_zh": "望远镜未就绪，缺少：" + "、".join(names_zh) + "。请前往组装台。"
	}


func get_object(object_id: String) -> Dictionary:
	for obj in objects_data:
		if str(obj.get("id", "")) == object_id:
			return obj
	return {}


func get_part(part_id: String) -> Dictionary:
	for part in parts_data:
		if str(part.get("id", "")) == part_id:
			return part
	return {}


func level_data_issues(level: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var mission_manager: Variant = _mission_manager()
	var level_number := int(level.get("level_number", 0))
	var level_index: int = mission_manager.order_index(level_number) if mission_manager != null else -1
	if level_number <= 0 or level_index < 0:
		issues.append("level is absent from campaign_order")
		return issues
	var target_id := str(level.get("target_object_id", ""))
	var mode := str(level.get("observation_mode", ""))
	if mode == "":
		issues.append("missing observation_mode")
	elif mode == "constellation":
		if get_constellation(target_id).is_empty():
			issues.append("missing constellation target: " + target_id)
	elif get_object(target_id).is_empty():
		issues.append("missing celestial target: " + target_id)
	if str(level.get("required_concept_card", "")) == "" or get_learning_card(str(level.get("required_concept_card", ""))).is_empty():
		issues.append("missing learning card")
	for text_key in ["title_en", "title_zh", "description_en", "description_zh", "hint_text_en", "hint_text_zh", "success_text_en", "success_text_zh"]:
		if str(level.get(text_key, "")).strip_edges() == "":
			issues.append("missing mission feedback: " + text_key)

	var required_types: Array = level.get("required_parts", [])
	var pinned_types: Dictionary = {}
	var has_collimation_tool := required_types.has("collimation_tool")
	for required_id_value in level.get("required_part_ids", []):
		var required_id := str(required_id_value)
		var part := get_part(required_id)
		if part.is_empty():
			issues.append("missing required part id: " + required_id)
			continue
		var part_type := str(part.get("type", ""))
		pinned_types[part_type] = true
		if part_type == "collimation_tool":
			has_collimation_tool = true
		if not required_types.has(part_type) and not _is_internal_advanced_tube_type(level, part_type):
			issues.append("required_part_ids type is absent from required_parts: " + required_id)
		if not _part_is_available_before_level(required_id, level_index):
			issues.append("required part unlocks too late: " + required_id)
		if not _part_family_matches_level(part, level):
			issues.append("required part family is incompatible: " + required_id)
	for type_value in required_types:
		var part_type := str(type_value)
		if part_type == "" or pinned_types.has(part_type):
			continue
		if not _has_compatible_part_before_level(part_type, level, level_index):
			issues.append("no compatible unlocked part for type: " + part_type)
	if bool(level.get("requires_focus", false)) and not (required_types.has("focus_knob") or required_types.has("focuser")):
		issues.append("focus lesson has no focus control")
	if bool(level.get("requires_collimation", false)) and not has_collimation_tool:
		issues.append("collimation lesson has no collimation tool")
	if str(level.get("variation", "")) == "finder_calibration" and not required_types.has("finder_scope"):
		issues.append("finder calibration has no finder scope")
	if str(level.get("assembly_mode", "")) == "advanced" and str(level.get("telescope_family", "")) in ["newtonian", "dobsonian", "cassegrain", "gregorian"]:
		if not required_types.has("reflector_tube") or not required_types.has("focuser"):
			issues.append("advanced tube lesson is missing required tube components")
	return issues


func all_level_data_issues() -> Dictionary:
	var results: Dictionary = {}
	for level_value in levels_data:
		if not level_value is Dictionary:
			continue
		var level: Dictionary = level_value
		if bool(level.get("deprecated", false)):
			continue
		var issues := level_data_issues(level)
		if not issues.is_empty():
			results[int(level.get("level_number", 0))] = issues
	return results


func _part_is_available_before_level(part_id: String, level_index: int) -> bool:
	var mission_manager: Variant = _mission_manager()
	if mission_manager == null:
		return false
	var earliest_index := 999999
	var part := get_part(part_id)
	if not part.is_empty():
		var configured_index: int = mission_manager.order_index(int(part.get("unlock_level", 999999)))
		if configured_index >= 0:
			earliest_index = min(earliest_index, configured_index)
	for source_level_value in levels_data:
		var source_level: Dictionary = source_level_value
		if source_level.get("unlock_parts", []).has(part_id):
			var reward_index: int = mission_manager.order_index(int(source_level.get("level_number", 0)))
			if reward_index >= 0:
				earliest_index = min(earliest_index, reward_index)
	return earliest_index < level_index


func _has_compatible_part_before_level(part_type: String, level: Dictionary, level_index: int) -> bool:
	for part in parts_data:
		if str(part.get("type", "")) == part_type and _part_family_matches_level(part, level) and _part_is_available_before_level(str(part.get("id", "")), level_index):
			return true
	return false


func _part_family_matches_level(part: Dictionary, level: Dictionary) -> bool:
	var part_family := str(part.get("telescope_family", ""))
	var level_family := str(level.get("telescope_family", "refractor"))
	return part_family == "" or part_family == level_family


func _is_internal_advanced_tube_type(level: Dictionary, part_type: String) -> bool:
	if str(level.get("assembly_mode", "")) != "advanced":
		return false
	var family := str(level.get("telescope_family", ""))
	if family in ["newtonian", "dobsonian"]:
		return part_type in ["mirror_cell", "secondary_spider", "collimation_tool"]
	if family == "cassegrain":
		# Internal tube parts that must never appear on the MAIN cassegrain bench.
		return part_type in ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_mirror", "central_baffle", "focuser", "eyepiece", "collimation_tool"]
	return false


func get_selected_parts() -> Dictionary:
	var selected: Dictionary = {}
	for part_type in progress.get("selected_parts", {}).keys():
		var part: Dictionary = get_part(str(progress["selected_parts"][part_type]))
		if not part.is_empty():
			selected[part_type] = part
	return selected


func unlocked_parts_by_type(part_type: String) -> Array:
	var result: Array = []
	var unlocked: Array = progress.get("unlocked_parts", [])
	for part in parts_data:
		if str(part.get("type", "")) == part_type and unlocked.has(str(part.get("id", ""))):
			result.append(part)
	return result


func space_segmented_install_types() -> Array[String]:
	# The space observatory is a system, not only four optical components.
	# Every component unlocked by the current chapter gets a real assembly slot;
	# later unlocks therefore become usable instead of remaining cabinet-only.
	var result: Array[String] = []
	var unlocked: Array = progress.get("unlocked_parts", [])
	for part_type_value in SPACE_SEGMENTED_INSTALL_ORDER:
		var part_type := str(part_type_value)
		for part_value in parts_data:
			var part: Dictionary = part_value
			if (
				str(part.get("telescope_family", "")) == "space_segmented"
				and str(part.get("type", "")) == part_type
				and unlocked.has(str(part.get("id", "")))
			):
				result.append(part_type)
				break
	return result


func space_instrument_is_installed(instrument_id: String) -> bool:
	var part_type := str(SPACE_INSTRUMENT_PART_TYPES.get(instrument_id, ""))
	if part_type == "":
		return false
	var entry: Dictionary = progress.get("assembly_state", {}).get(part_type, {})
	return bool(entry.get("installed", false))


func space_instrument_block_reason(instrument_id: String) -> String:
	var part_type := str(SPACE_INSTRUMENT_PART_TYPES.get(instrument_id, ""))
	if part_type == "":
		return text("Unknown science instrument.", "未知科学仪器。")
	var options := unlocked_parts_by_type(part_type)
	if options.is_empty():
		return text(
			"%s has not been unlocked yet." % instrument_id.to_upper(),
			"%s 尚未解锁。" % instrument_id.to_upper()
		)
	if not space_instrument_is_installed(instrument_id):
		return text(
			"Equip %s in the Parts Cabinet, then install it on the Instruments blueprint." % instrument_id.to_upper(),
			"请先在零件柜装备 %s，再到“科学仪器”蓝图页安装。" % instrument_id.to_upper()
		)
	return ""


func reset_assembly() -> void:
	progress["assembly_state"] = _fresh_assembly_state()
	progress["telescope_ready"] = false
	save()


func install_part(part_type: String, wrong_attempts: int, part_id: String = "") -> int:
	# Resolve which part to install: the player's explicit choice on the bench,
	# else whatever is currently equipped, else the unlocked option for this
	# slot. Auto-equip the resolved part so an unlocked-but-not-equipped item
	# (the default state for focus_knob / finder_scope once earned) installs
	# instead of failing with a misleading "locked" error.
	var resolved_id := part_id
	if resolved_id == "":
		resolved_id = equipped_part_id(part_type)
	if resolved_id == "":
		var options := unlocked_parts_by_type(part_type)
		if not options.is_empty():
			resolved_id = str(options[options.size() - 1].get("id", ""))
	if resolved_id != "" and equipped_part_id(part_type) != resolved_id:
		equip_part(resolved_id)
	if not can_install_part_type(part_type, resolved_id):
		return -1
	var score: int = AssemblyManagerScript.alignment_from_wrong_attempts(wrong_attempts)
	progress["assembly_state"][part_type] = {
		"installed": true,
		"alignment_score": score,
		"wrong_attempts": wrong_attempts,
		"installed_part_id": equipped_part_id(part_type)
	}
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())
	save()
	return score


func can_install_part_type(part_type: String, part_id: String = "") -> bool:
	if part_type == "optical_tube_assembly":
		return advanced_tube_completed()
	# Validate the SPECIFIC part the player chose (falls back to the equipped id
	# for callers that do not pass one).
	var check_id := part_id if part_id != "" else equipped_part_id(part_type)
	var selected_part := get_part(check_id)
	if selected_part.is_empty() or not progress.get("unlocked_parts", []).has(check_id):
		return false
	if not is_part_compatible_with_current_level(selected_part):
		return false
	# Graduation turns the observatory into a free-build lab. Campaign pinned
	# part IDs remain instructional constraints for their own lessons, but they
	# must not reject an otherwise unlocked compatible component after the
	# player has completed the program.
	if postgraduate_free_build():
		return true
	var pinned_id := pinned_part_id(part_type)
	return pinned_id == "" or check_id == pinned_id


func part_slot_state(part_type: String, part_id: String = "") -> String:
	# Four-state model the assembly bench renders: locked / incompatible /
	# installed / equipped / unlocked. "installed" is tracked per slot.
	var check_id := part_id if part_id != "" else equipped_part_id(part_type)
	var part := get_part(check_id)
	if part.is_empty() or not progress.get("unlocked_parts", []).has(check_id):
		return "locked"
	if not is_part_compatible_with_current_level(part):
		return "incompatible"
	var slot: Dictionary = progress.get("assembly_state", {}).get(part_type, {}) if progress.get("assembly_state", {}).get(part_type, {}) is Dictionary else {}
	if bool(slot.get("installed", false)):
		return "installed"
	if equipped_part_id(part_type) == check_id:
		return "equipped"
	return "unlocked"


func install_part_block_reason(part_type: String, part_id: String = "") -> String:
	if part_type == "finder_scope" and not locked_required_equipment().get("types", []).has("finder_scope"):
		return text("Equip the Finder Scope in the Parts Cabinet, then install it here.", "请先在零件柜装备寻星镜，再回到这里安装。")
	if part_type == "finder_scope" and equipped_part_id("finder_scope") == "" and unlocked_parts_by_type("finder_scope").is_empty():
		return text("This mission requires a Finder Scope, but it is locked. Complete Finder Scope Introduction first.", "本关需要寻星镜，但它尚未解锁。请先完成寻星镜教学。")
	var check_id := part_id if part_id != "" else equipped_part_id(part_type)
	var part := get_part(check_id)
	# 1. Locked: not owned yet.
	if part.is_empty() or not progress.get("unlocked_parts", []).has(check_id):
		return text("This part is locked. Complete its introduction lesson to unlock it first.", "该零件尚未解锁。请先完成对应教学关卡再来安装。")
	# 2. Incompatible telescope family.
	if not is_part_compatible_with_current_level(part):
		var fam := _family_display_name(str(part.get("telescope_family", "")))
		var cur := _family_display_name(assembly_context_family())
		return text("This part belongs to the %s telescope; tonight's mission uses a %s telescope." % [fam, cur],
			"该零件属于%s望远镜，当前任务使用%s望远镜。" % [fam, cur])
	# 3. Pinned: mission demands a specific part for this slot.
	var pinned_id := pinned_part_id(part_type)
	if pinned_id != "" and check_id != pinned_id:
		var pin_name := dict_text(get_part(pinned_id), "name")
		return text("This mission requires %s in this slot." % pin_name, "本关此安装位指定使用 %s。" % pin_name)
	# 4. Otherwise it is installable - selection guidance.
	return text("Select this part card, then click its matching blueprint slot.", "请选择该零件卡，再点击蓝图上的对应安装位。")


func _family_display_name(family: String) -> String:
	match family:
		"", "refractor": return text("refractor", "折射式")
		"newtonian": return text("Newtonian", "牛顿反射式")
		"dobsonian": return text("Dobsonian", "多布森")
		"cassegrain": return text("Cassegrain", "卡塞格林")
		"gregorian": return text("Gregorian", "格里高利")
		"space_segmented": return text("infrared/space", "红外/空间")
		"fast_radio": return text("FAST radio", "FAST 射电")
		_: return family


func uses_family_selection() -> bool:
	# Levels whose lesson is built on a reflector bench get the telescope-type
	# selection screen in front of the assembly. Refractor (basic) and the
	# multi-device finale route straight to their own screens.
	return str(current_level().get("assembly_mode", "")) == "advanced"


func telescope_is_ready() -> bool:
	if _uses_tube_subassembly():
		return advanced_tube_completed() and AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())
	return bool(progress.get("telescope_ready", false)) and AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())


func equip_part(part_id: String) -> bool:
	var part := get_part(part_id)
	if part.is_empty():
		return false
	var part_type: String = str(part.get("type", ""))
	if part_type == "":
		return false
	if not progress.get("unlocked_parts", []).has(part_id):
		return false
	if not is_part_compatible_with_current_level(part):
		return false
	if str(progress["selected_parts"].get(part_type, "")) == part_id:
		return true
	progress["selected_parts"][part_type] = part_id
	# Swapping a part means it must be reinstalled on the bench.
	if progress["assembly_state"].has(part_type):
		progress["assembly_state"][part_type] = {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
	progress["telescope_ready"] = AssemblyManagerScript.is_complete(progress["assembly_state"], _effective_required_parts())
	save()
	return true


func equipped_part_id(part_type: String) -> String:
	return str(progress.get("selected_parts", {}).get(part_type, ""))


func missing_parts() -> Array:
	return AssemblyManagerScript.missing_parts(progress["assembly_state"], _effective_required_parts())


func _uses_tube_subassembly() -> bool:
	var level := assembly_level_context() if postgraduate_free_build() else current_level()
	return str(level.get("assembly_mode", "")) == "advanced" and assembly_context_family() in ["newtonian", "dobsonian", "cassegrain", "gregorian"]


func _effective_required_parts() -> Array:
	var level := assembly_level_context() if postgraduate_free_build() else current_level()
	var family := assembly_context_family()
	# Constellation lessons now share the optical observation workflow. They use
	# the established refractor and finder, not an unrelated advanced tube
	# subassembly, so the late-night pattern lessons remain playable.
	if not postgraduate_free_build() and current_observation_mode() == "constellation":
		return ["tripod", "mount", "tube", "objective", "eyepiece", "finder_scope"]
	if family == "space_segmented":
		# Campaign levels promise a compact four-part commissioning contract.
		# Later-unlocked spacecraft and science modules remain installable on
		# the bench, but they are optional capabilities and must not silently
		# become new mission blockers. Postgraduate free build intentionally
		# exposes the complete unlocked observatory.
		if postgraduate_free_build():
			return space_segmented_install_types()
		return level.get("required_parts", [])
	if not _uses_tube_subassembly():
		return level.get("required_parts", [])
	if family == "dobsonian":
		# The rocker box replaces tripod+mount; the finder rides on the tube.
		return ["mount", "optical_tube_assembly", "finder_scope"]
	if family == "newtonian":
		# Newtonian main bench mirrors the refractor flow: base, mount, the
		# completed optical tube, then the aiming aid.
		return ["tripod", "mount", "optical_tube_assembly", "finder_scope"]
	return ["tripod", "mount", "optical_tube_assembly"]


func tube_assembly() -> Dictionary:
	var family := assembly_context_family()
	var all_states: Dictionary = progress.get("tube_assemblies", {})
	var state: Variant = all_states.get(family, {})
	return state if state is Dictionary else {}


func advanced_tube_completed() -> bool:
	return bool(tube_assembly().get("completed", false))


func update_tube_subassembly_progress(installed_subparts: Dictionary) -> void:
	var config := tube_subassembly_config()
	if config.is_empty():
		return
	var family := str(config.get("family", ""))
	if not progress.get("tube_assemblies") is Dictionary:
		progress["tube_assemblies"] = {}
	var previous := tube_assembly()
	progress["tube_assemblies"][family] = {
		"telescope_family": family,
		"tube_assembly_state": installed_subparts.duplicate(),
		"installed_subparts": installed_subparts.duplicate(),
		"subassembly_score": float(previous.get("subassembly_score", 0.0)),
		"collimation_score": collimation_score(),
		"optical_alignment": float(previous.get("optical_alignment", 0.0)),
		"completed": false,
		"placeholder_assets_used": true
	}
	save()


func _required_part_id_for_type(part_type: String, fallback_id: String) -> String:
	if postgraduate_free_build():
		return fallback_id
	for required_value in current_level().get("required_part_ids", []):
		var required_id := str(required_value)
		var required_part := get_part(required_id)
		if str(required_part.get("type", "")) == part_type:
			return required_id
	return fallback_id


func tube_subassembly_config() -> Dictionary:
	var family := assembly_context_family()
	match family:
		"newtonian":
			return {"family": family, "order": ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"], "ids": ["newtonian_reflector_tube", "newtonian_mirror_cell", "newtonian_primary_mirror", "newtonian_secondary_spider", "newtonian_secondary_mirror", "newtonian_focuser", "newtonian_25mm_eyepiece", "newtonian_collimation_cap"]}
		"dobsonian":
			return {"family": family, "order": ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_spider", "secondary_mirror", "focuser", "eyepiece", "collimation_tool"], "ids": ["dobsonian_reflector_tube", "dobsonian_mirror_cell", "dobsonian_primary_mirror", "dobsonian_secondary_spider", "dobsonian_secondary_mirror", "dobsonian_crayford_focuser", "dobsonian_30mm_eyepiece", "dobsonian_collimation_tool"]}
		"cassegrain":
			# Eight-slot folded path: tube -> primary cell -> concave primary ->
			# convex secondary -> central baffle -> rear focuser -> eyepiece ->
			# collimation tool (matches the user's tube blueprint art).
			var eyepiece_id := _required_part_id_for_type("eyepiece", "cassegrain_12mm_eyepiece")
			return {"family": family, "order": ["reflector_tube", "mirror_cell", "primary_mirror", "secondary_mirror", "central_baffle", "focuser", "eyepiece", "collimation_tool"], "ids": ["cassegrain_compact_tube", "cassegrain_mirror_cell", "cassegrain_primary_mirror", "cassegrain_convex_secondary", "cassegrain_central_baffle", "cassegrain_rear_focuser", eyepiece_id, "cassegrain_collimation_tool"]}
		"gregorian":
			return {"family": family, "order": ["reflector_tube", "primary_mirror", "optical_support", "secondary_mirror", "focuser", "eyepiece"], "ids": ["gregorian_optical_tube", "gregorian_primary_mirror", "gregorian_optical_support", "gregorian_concave_secondary", "gregorian_focuser", "gregorian_18mm_eyepiece"]}
	return {}


func save_tube_assembly(installed_subparts: Dictionary, score: float, optical_alignment: float, placeholder_assets_used: bool) -> bool:
	var config := tube_subassembly_config()
	if config.is_empty():
		return false
	for subpart_value in config.get("order", []):
		if not bool(installed_subparts.get(str(subpart_value), false)):
			return false
	var family := str(config.get("family", ""))
	if not progress.get("tube_assemblies") is Dictionary:
		progress["tube_assemblies"] = {}
	progress["tube_assemblies"][family] = {
		"telescope_family": family,
		"tube_assembly_state": installed_subparts.duplicate(),
		"installed_subparts": installed_subparts.duplicate(),
		"subassembly_score": clampf(score, 0.0, 100.0),
		"collimation_score": collimation_score(),
		"optical_alignment": clampf(optical_alignment, 0.0, 100.0),
		"completed": true,
		"placeholder_assets_used": placeholder_assets_used
	}
	progress["assembly_state"]["optical_tube_assembly"] = {"installed": false, "alignment_score": roundi(score), "wrong_attempts": 0}
	progress["telescope_ready"] = false
	save()
	return true


# Hard gate: specific part IDs (not just part types) the current level
# requires, e.g. ["eyepiece_10mm"]. Empty when the level has no such field
# (older levels are unaffected).
func missing_required_parts() -> Array[String]:
	if postgraduate_free_build():
		return []
	var required: Array = current_level().get("required_part_ids", [])
	var missing: Array[String] = []
	var selected: Dictionary = progress.get("selected_parts", {})
	for required_value in required:
		var required_id := str(required_value)
		var part := get_part(required_id)
		var part_type := str(part.get("type", ""))
		var equipped_id := str(selected.get(part_type, ""))
		if equipped_id != required_id:
			missing.append(required_id)
	return missing


# Older Newtonian saves can have a main slot installed while selected_parts
# still names the previously equipped mount, incorrectly locking Identify.
func sync_newtonian_installed_equipment() -> bool:
	var level := current_level()
	if str(level.get("assembly_mode", "")) != "advanced" or not str(level.get("telescope_family", "")) in ["newtonian", "dobsonian"]:
		return false
	var state: Dictionary = progress.get("assembly_state", {})
	var selected: Dictionary = progress.get("selected_parts", {})
	var changed := false
	for required_value in level.get("required_part_ids", []):
		var required_id := str(required_value)
		var part := get_part(required_id)
		var part_type := str(part.get("type", ""))
		if not part_type in ["tripod", "mount", "finder_scope"]:
			continue
		var installed_entry: Dictionary = state.get(part_type, {})
		if bool(installed_entry.get("installed", false)) and str(selected.get(part_type, "")) != required_id:
			selected[part_type] = required_id
			changed = true
	if changed:
		progress["selected_parts"] = selected
		save()
	return changed


# ------------------------------------------------------------ mission steps


# The current level's ordered checklist (e.g. L10's "observe with 20mm, then
# switch to 10mm"). Empty array when the level has none.
func mission_steps() -> Array:
	return current_level().get("mission_steps", [])


func completed_mission_steps() -> Array:
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return []
	var state: Dictionary = progress.get("mission_step_state", {})
	var done: Variant = state.get(level_id, [])
	if done is Array:
		return done
	return []


# First step (in declared order) not yet marked done; empty dict when the
# level has no steps or all steps are complete.
func next_pending_mission_step() -> Dictionary:
	var steps := mission_steps()
	if steps.is_empty():
		return {}
	var done := completed_mission_steps()
	for step_value in steps:
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var step_id := str(step.get("id", ""))
		if step_id != "" and not done.has(step_id):
			return step
	return {}


# Only ever appends (steps do not un-complete once reached).
func mark_mission_step_done(step_id: String) -> void:
	if step_id == "":
		return
	var level_id := str(current_level().get("id", ""))
	if level_id == "":
		return
	if not progress.get("mission_step_state") is Dictionary:
		progress["mission_step_state"] = {}
	var state: Dictionary = progress["mission_step_state"]
	var done: Variant = state.get(level_id, [])
	if not done is Array:
		done = []
	if not done.has(step_id):
		done.append(step_id)
	state[level_id] = done
	progress["mission_step_state"] = state
	save()


# ------------------------------------------------------------ finder offset


const FINDER_ALIGNED_THRESHOLD := 0.5


# A persistent (across sessions) misalignment between the finder scope and
# the main telescope. Only L15's variation surfaces a calibration UI for it,
# but the offset itself applies whenever it is non-zero, everywhere.
func finder_offset() -> Dictionary:
	var offset: Variant = progress.get("finder_offset", {"az": 0.0, "alt": 0.0})
	if offset is Dictionary:
		return offset
	return {"az": 0.0, "alt": 0.0}


func finder_offset_length() -> float:
	var offset := finder_offset()
	return Vector2(float(offset.get("az", 0.0)), float(offset.get("alt", 0.0))).length()


func finder_alignment_percent() -> float:
	# Normalize by the INITIAL seeded misalignment, not a fixed 3.0 - the
	# seed can exceed 3 deg, which pinned the readout at 0% and gave the
	# player no feedback gradient while adjusting.
	var initial := maxf(float(progress.get("finder_offset_initial_len", 3.0)), 0.5)
	return clampf(1.0 - finder_offset_length() / initial, 0.0, 1.0) * 100.0


func is_finder_aligned() -> bool:
	return finder_offset_length() < FINDER_ALIGNED_THRESHOLD


# L15 seeds a real, persistent misalignment the first time the player enters
# the sky on that level; every level after inherits whatever offset is left
# (zero once L15 is calibrated, per the design).
func seed_finder_offset_if_needed() -> void:
	if bool(progress.get("finder_offset_seeded", false)):
		return
	var sign_az := 1.0 if (randi() % 2 == 0) else -1.0
	var sign_alt := 1.0 if (randi() % 2 == 0) else -1.0
	var az := sign_az * (1.5 + randf() * 1.5)
	var alt := sign_alt * (1.5 + randf() * 1.5)
	# Guarantee a real, noticeable misalignment (>= 2 deg total).
	if Vector2(az, alt).length() < 2.0:
		az *= 1.6
		alt *= 1.6
	progress["finder_offset"] = {"az": az, "alt": alt}
	progress["finder_offset_initial_len"] = Vector2(az, alt).length()
	progress["finder_offset_seeded"] = true
	save()


func adjust_finder_offset(delta_az: float, delta_alt: float) -> void:
	var offset := finder_offset()
	var az := float(offset.get("az", 0.0)) + delta_az
	var alt := float(offset.get("alt", 0.0)) + delta_alt
	progress["finder_offset"] = {"az": az, "alt": alt}
	if finder_offset_length() < FINDER_ALIGNED_THRESHOLD:
		# Calibrated: snap to true zero and persist so the finder stays
		# trustworthy in every later level.
		progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	save()


# ------------------------------------------------------------ tracking rate


# Tracking-mount rate (0-2x), persisted across sessions (E2 drift/tracking).
# Only meaningful when a tracking-capable mount is equipped on a drift level,
# but the value itself is harmless to keep around otherwise.
func tracking_rate() -> float:
	return float(progress.get("tracking_rate", 0.0))


func set_tracking_rate(value: float) -> void:
	progress["tracking_rate"] = clampf(value, 0.0, 2.0)
	save()


func has_tracking_mount_equipped() -> bool:
	var mount := get_part(equipped_part_id("mount"))
	return bool(mount.get("tracking_capable", false))


func current_environment() -> Dictionary:
	var level := current_level()
	if is_local_optical_free_observation():
		level = assembly_level_context()
	var environment: Dictionary = level.get("environment", {})
	if not environment.is_empty():
		return environment
	# Backward-compatible fallback: L20/21-style top-level fields, folded
	# into an environment dict so ObservationSystem only has one shape to read.
	if level.has("sky_brightness"):
		return {"sky_brightness": str(level.get("sky_brightness", ""))}
	return {}


func calculate_stats() -> Dictionary:
	var selected_parts := get_selected_parts()
	# A save can retain selections from a different telescope family. Keep
	# those parts in inventory, but only feed generic parts and parts belonging
	# to this lesson's family into the optical calculation.
	var family := assembly_context_family()
	for part_type in selected_parts.keys():
		var part: Dictionary = selected_parts[part_type]
		var part_family := str(part.get("telescope_family", ""))
		if part_family != "" and part_family != family:
			selected_parts.erase(part_type)
	var assembly_state: Dictionary = progress.get("assembly_state", {}).duplicate(true)
	if _uses_tube_subassembly():
		var installed_subparts: Dictionary = tube_assembly().get("installed_subparts", {})
		if bool(installed_subparts.get("focuser", false)):
			var tube_focus_score := float(tube_assembly().get("optical_alignment", tube_assembly().get("subassembly_score", 0.0)))
			assembly_state["focuser"] = {"installed": true, "alignment_score": tube_focus_score, "wrong_attempts": 0}
	var stats: Dictionary = TelescopeMathScript.calculate(selected_parts, assembly_state)
	if _uses_tube_subassembly():
		var tube_state := tube_assembly()
		var subassembly_score := float(tube_state.get("subassembly_score", 0.0))
		stats["subassembly_score"] = subassembly_score
		stats["assembly_score"] = minf(float(stats.get("assembly_score", 0.0)), subassembly_score)
		stats["clarity_score"] = snapped(float(stats.get("clarity_score", 0.0)) * subassembly_score / 100.0, 0.1)
	var assembly_level := assembly_level_context() if postgraduate_free_build() else current_level()
	if bool(assembly_level.get("requires_collimation", false)):
		var score: float = collimation_score()
		stats["collimation_score"] = score
		stats["clarity_score"] = snapped(float(stats.get("clarity_score", 0.0)) * (0.45 + score / 200.0), 0.1)
	else:
		stats["collimation_score"] = 100.0
	return stats


func collimation_score() -> float:
	var family := assembly_context_family()
	var scores: Dictionary = progress.get("collimation_scores", {})
	return float(scores.get(family, 0.0))


func collimation_is_acceptable() -> bool:
	var level := assembly_level_context() if postgraduate_free_build() else current_level()
	var threshold := float(level.get("collimation_threshold", 0.0))
	return threshold <= 0.0 or collimation_score() >= threshold


func set_collimation_score(value: float) -> void:
	var family := assembly_context_family()
	if not progress.get("collimation_scores") is Dictionary:
		progress["collimation_scores"] = {}
	progress["collimation_scores"][family] = clampf(value, 0.0, 100.0)
	if progress.get("tube_assemblies") is Dictionary and progress["tube_assemblies"].has(family):
		var tube_state: Dictionary = progress["tube_assemblies"][family]
		tube_state["collimation_score"] = progress["collimation_scores"][family]
		progress["tube_assemblies"][family] = tube_state
	save()


func evaluate_selected_object(extra_context: Dictionary = {}) -> Dictionary:
	var obj := get_object(selected_object_id)
	var free_observation := is_free_observation()
	if not free_observation:
		obj = apply_target_requirement_overrides(obj)
	if not extra_context.has("observation_mode"):
		extra_context["observation_mode"] = current_observation_mode()
	if not extra_context.has("minimum_success_quality"):
		extra_context["minimum_success_quality"] = "Poor" if free_observation else str(current_level().get("minimum_success_quality", "Good"))
	if not free_observation and not extra_context.has("success_feedback_en") and current_level().has("observation_success_feedback_en"):
		extra_context["success_feedback_en"] = str(current_level().get("observation_success_feedback_en", ""))
	if not free_observation and not extra_context.has("success_feedback_zh") and current_level().has("observation_success_feedback_zh"):
		extra_context["success_feedback_zh"] = str(current_level().get("observation_success_feedback_zh", ""))
	var stats := calculate_stats()
	if str(extra_context["observation_mode"]) == "telescope":
		if not extra_context.has("environment"):
			extra_context["environment"] = current_environment()
		if not extra_context.has("altitude"):
			var aim: Dictionary = last_sky_aim
			var altitude := 45.0
			if bool(aim.get("valid", false)):
				altitude = float(aim.get("altitude", 45.0))
			extra_context["altitude"] = altitude
		if not extra_context.has("magnification"):
			extra_context["magnification"] = float(stats.get("magnification", 0.0))
	last_observation = ObservationSystemScript.evaluate(stats, obj, extra_context)
	return last_observation


func complete_current_mission(object_id: String, observation: Dictionary) -> bool:
	var level := current_level()
	if object_id != current_target_object_id():
		return false
	if not next_pending_mission_step().is_empty():
		return false
	if not bool(observation.get("success", false)):
		return false
	# A system-level mission is not complete until its secondary object has
	# been confirmed separately (L55: Neptune alone is not Neptune + Triton).
	if not current_secondary_target().is_empty() and not secondary_target_found():
		return false
	var level_number: int = int(level.get("level_number", progress.get("current_level", 1)))
	var already_completed: bool = progress["completed_levels"].has(level_number)
	var credits_before := int(progress.get("credits", 0))
	var credits_awarded := 0
	var badges_awarded: Array[String] = []
	if already_completed:
		# A result screen can be closed, a browser tab can be suspended, or an
		# older save can be written after completed_levels was updated but before
		# current_level advanced. Treat that as an interrupted handoff: repair
		# the campaign cursor without awarding credits or writing a duplicate
		# journal entry.
		var completion_manager: Variant = _mission_manager()
		if completion_manager != null and completion_manager.is_final_level(level_number):
			progress["program_completed"] = true
			if not bool(progress.get("graduation_seen", false)):
				progress["graduation_pending"] = true
			update_room_guidance_for_level()
			save()
			if graduation_pending():
				go("graduation")
			else:
				go("observatory")
			return true
		_advance_past_completed_current_level()
		set_room_guidance(
			str(current_room_route().get("target", "telescope")),
			text("Maya: Continue the Program", "玛雅：继续课程"),
			text(
				"This observation was already logged. The next unfinished lesson is ready.",
				"这次观测已经记入日志。下一项未完成课程已准备好。"
			)
		)
		save()
		go("observatory")
		return true
	if not already_completed:
		progress["completed_levels"].append(level_number)
		credits_awarded = int(level.get("reward_credits", 0))
		progress["credits"] = credits_before + credits_awarded
		for part_id in level.get("unlock_parts", []):
			if not progress["unlocked_parts"].has(part_id):
				progress["unlocked_parts"].append(part_id)
				_queue_unlock_notice(str(part_id))
		var badge: String = str(level.get("badge", ""))
		if badge != "" and not progress["badges"].has(badge):
			progress["badges"].append(badge)
			badges_awarded.append(badge)
	var concept_card_id := str(level.get("required_concept_card", ""))
	if concept_card_id != "":
		if not progress.has("completed_concept_cards"):
			progress["completed_concept_cards"] = []
		if not progress["completed_concept_cards"].has(concept_card_id):
			progress["completed_concept_cards"].append(concept_card_id)
	var stage := str(level.get("unlock_equipment_stage", level.get("equipment_stage", "")))
	if stage != "":
		if not progress.has("unlocked_equipment_stages"):
			progress["unlocked_equipment_stages"] = ["eye"]
		if not progress["unlocked_equipment_stages"].has(stage):
			progress["unlocked_equipment_stages"].append(stage)
	_add_journal_entry(object_id, observation)
	var mission_manager: Variant = _mission_manager()
	if mission_manager != null and mission_manager.is_final_level(level_number):
		# Finishing the whole club program earns the final story badge.
		if not progress["badges"].has("Young Observer"):
			progress["badges"].append("Young Observer")
			badges_awarded.append("Young Observer")
		progress["program_completed"] = true
		progress["graduation_pending"] = not bool(progress.get("graduation_seen", false))
	var payload: Dictionary = TeachingFlowManager.make_mission_complete_payload(
		level, get_object(object_id), observation, calculate_stats()
	)
	payload["reward_summary"] = {
		"credits_before": credits_before,
		"credits_awarded": credits_awarded,
		"credits_total": int(progress.get("credits", 0)),
		"badges_awarded": badges_awarded
	}
	if mission_manager != null and not mission_manager.is_final_level(level_number):
		# Campaign-order progression is the sole authority for the mainline.
		# Skip only levels already completed in an older save; a side or stale
		# completion can never jump the player forward past unfinished lessons.
		var completed_index: int = mission_manager.order_index(level_number)
		var current_index: int = mission_manager.order_index(int(progress.get("current_level", 1)))
		if completed_index >= 0 and completed_index >= current_index:
			progress["current_level"] = mission_manager.next_incomplete_level_number(level_number, progress["completed_levels"])
			_sync_assembly_family_for_level()
			_unlock_parts_for_current_level()
			_select_current_mission_target()
	save()
	AudioManager.play_event("mission_completed")
	# Point the player at the next step for the (possibly new) level.
	update_room_guidance_for_level()
	show_mission_complete_card(payload)
	return true


func _advance_past_completed_current_level() -> bool:
	var mission_manager: Variant = _mission_manager()
	if mission_manager == null:
		return false
	var current := int(progress.get("current_level", 1))
	var completed: Array = progress.get("completed_levels", [])
	if not completed.has(current):
		return false
	var next_level := int(mission_manager.next_incomplete_level_number(current, completed))
	if next_level <= 0 or next_level == current:
		return false
	progress["current_level"] = next_level
	_sync_assembly_family_for_level()
	_unlock_parts_for_current_level()
	_select_current_mission_target()
	update_room_guidance_for_level()
	return true


func _select_current_mission_target() -> void:
	# A completed lesson may leave a free-observation body selected. The next
	# lesson starts with its own target while keeping the previous camera aim,
	# so the edge navigator can immediately show the player where to turn.
	selected_object_id = current_target_object_id()
	selected_object_level = int(progress.get("current_level", 1))
	current_sky_positions.clear()
	current_sky_location_id = ""


func _mission_manager() -> Variant:
	return get_node_or_null("/root/MissionManager")


func _add_journal_entry(object_id: String, observation: Dictionary) -> void:
	var obj := get_object(object_id)
	var stats := calculate_stats()
	var level := current_level()
	var objective := get_part(equipped_part_id("objective"))
	var eyepiece := get_part(equipped_part_id("eyepiece"))
	var mount := get_part(equipped_part_id("mount"))
	var environment := current_environment()
	var concept_id := str(level.get("required_concept_card", ""))
	var concept := get_learning_card(concept_id)
	# Repeat practice of a known concept is logged as a comparison run, not a
	# duplicate knowledge card.
	var prior_index := -1
	for entry_index in range(progress["journal_entries"].size()):
		var prior: Dictionary = progress["journal_entries"][entry_index]
		if concept_id != "" and str(prior.get("concept_card_id", "")) == concept_id:
			prior_index = entry_index + 1
			break
	var knowledge_en := str(concept.get("title_en", obj.get("learning_text_en", "")))
	var knowledge_zh := str(concept.get("title_zh", obj.get("learning_text_zh", "")))
	var entry_kind_en := "First experiment"
	var entry_kind_zh := "首次实验"
	if prior_index > 0:
		entry_kind_en = "Repeat experiment"
		entry_kind_zh = "对比实验"
		knowledge_en = "Repeat practice of \"%s\" - compare with entry #%02d." % [knowledge_en, prior_index]
		knowledge_zh = "再次练习「%s」——与第 %02d 条记录对比。" % [knowledge_zh, prior_index]
	var recap: Dictionary = StoryManager.recap_for_level(int(level.get("level_number", 0)))
	# Process record: what the player actually had to manage this session.
	var process_en: Array[String] = []
	var process_zh: Array[String] = []
	if bool(level.get("requires_focus", false)):
		process_en.append("Focus: locked in")
		process_zh.append("调焦：已合焦")
	if bool(level.get("requires_collimation", false)):
		process_en.append("Collimation: %d%%" % roundi(collimation_score()))
		process_zh.append("准直：%d%%" % roundi(collimation_score()))
	if bool(level.get("drift_enabled", false)):
		if has_tracking_mount_equipped() and tracking_rate() > 0.5:
			process_en.append("Tracking: mount at %.2fx" % tracking_rate())
			process_zh.append("追踪：支架 %.2f 倍速" % tracking_rate())
		else:
			process_en.append("Tracking: held by hand (%ds)" % int(level.get("hold_seconds", 0)))
			process_zh.append("追踪：手动保持 %d 秒" % int(level.get("hold_seconds", 0)))
	progress["journal_entries"].append({
		"object_id": object_id,
		"object_name_en": obj.get("name_en", object_id),
		"object_name_zh": obj.get("name_zh", object_id),
		"object_type_en": obj.get("type_en", ""),
		"object_type_zh": obj.get("type_zh", ""),
		"level_completed": level.get("level_number", progress.get("current_level", 1)),
		"assembly_score": stats.get("assembly_score", 0),
		"observation_quality": observation.get("quality", "Unknown"),
		"learning_text_en": obj.get("learning_text_en", ""),
		"learning_text_zh": obj.get("learning_text_zh", ""),
		"observation_mode": observation.get("observation_mode", current_observation_mode()),
		"concept_card_id": concept_id,
		"concept_title_en": str(concept.get("title_en", "")),
		"concept_title_zh": str(concept.get("title_zh", "")),
		"variation": str(level.get("variation", "")),
		"magnification": float(stats.get("magnification", 0.0)),
		"objective_aperture_mm": int(objective.get("aperture_mm", 0)),
		"objective_focal_length_mm": int(objective.get("focal_length_mm", 0)),
		"eyepiece_focal_length_mm": int(eyepiece.get("focal_length_mm", 0)),
		"equipment_en": _journal_equipment_summary("en", objective, eyepiece, mount),
		"equipment_zh": _journal_equipment_summary("zh", objective, eyepiece, mount),
		"environment_en": _journal_environment_summary("en", environment),
		"environment_zh": _journal_environment_summary("zh", environment),
		"actions_en": _journal_action_summary("en", level, observation),
		"actions_zh": _journal_action_summary("zh", level, observation),
		"result_en": "Recorded " + str(observation.get("quality", "Unknown")) + " quality after this setup.",
		"result_zh": "使用本次配置记录到" + str(observation.get("quality", "Unknown")) + "质量的观测结果。",
		"knowledge_en": knowledge_en,
		"knowledge_zh": knowledge_zh,
		"entry_kind_en": entry_kind_en,
		"entry_kind_zh": entry_kind_zh,
		"process_en": " | ".join(process_en),
		"process_zh": " | ".join(process_zh),
		"maya_en": str(recap.get("en", "")),
		"maya_zh": str(recap.get("zh", "")),
		# Campaign FAST reports share the exact packet as free-observation cards.
		# Retaining it in the main journal makes the recovered spectrum and fold
		# profile reviewable after graduation as well.
		"radio_observation": observation.duplicate(true) if str(observation.get("observation_mode", "")) == "radio" else {}
	})
	if not progress["observed_objects"].has(object_id):
		progress["observed_objects"].append(object_id)


func _journal_equipment_summary(locale: String, objective: Dictionary, eyepiece: Dictionary, mount: Dictionary) -> String:
	var objective_name := str(objective.get("name_%s" % locale, objective.get("id", "objective")))
	var eyepiece_name := str(eyepiece.get("name_%s" % locale, eyepiece.get("id", "eyepiece")))
	var mount_name := str(mount.get("name_%s" % locale, mount.get("id", "mount")))
	return "%s | %s | %s" % [objective_name, eyepiece_name, mount_name]


func _journal_environment_summary(locale: String, environment: Dictionary) -> String:
	if environment.is_empty():
		return "Clear sky" if locale == "en" else "晴朗天空"
	var parts: Array[String] = []
	var seeing := str(environment.get("seeing", ""))
	var clouds := float(environment.get("cloud_cover", 0.0))
	var sky := str(environment.get("sky_brightness", ""))
	if seeing != "":
		parts.append("Seeing: " + seeing.capitalize() if locale == "en" else "视宁度：" + seeing)
	if clouds > 0.0:
		parts.append("Cloud: %d%%" % int(round(clouds * 100.0)) if locale == "en" else "云量：%d%%" % int(round(clouds * 100.0)))
	if sky != "":
		parts.append("Sky: " + sky.capitalize() if locale == "en" else "天空：" + sky)
	return " | ".join(parts)


func _journal_action_summary(locale: String, level: Dictionary, observation: Dictionary) -> String:
	var actions: Array[String] = []
	if bool(level.get("requires_focus", false)):
		actions.append("Focused the eyepiece" if locale == "en" else "调节目镜焦点")
	var variation := str(level.get("variation", ""))
	if variation == "eyepiece_comparison":
		actions.append("Compared low and high power" if locale == "en" else "比较低倍率与高倍率")
	elif variation == "finder_calibration":
		actions.append("Calibrated finder alignment" if locale == "en" else "校准寻星镜")
	elif variation == "tracking_mount":
		actions.append("Set the tracking rate" if locale == "en" else "设置追踪速率")
	elif variation == "accept_fair_quality" or variation == "dark_sky":
		actions.append("Waited for dark adaptation" if locale == "en" else "等待暗适应")
	elif bool(level.get("drift_enabled", false)):
		actions.append("Kept the target centered" if locale == "en" else "持续保持目标居中")
	if actions.is_empty():
		actions.append("Centered and identified the target" if locale == "en" else "居中并识别目标")
	return "; ".join(actions)


func _unlock_parts_for_current_level() -> void:
	var current: int = int(progress.get("current_level", 1))
	# Unlock levels are resolved through the validated campaign order rather
	# than trusting raw save values, so a malformed current_level cannot leak
	# equipment from a future chapter.
	var mission_manager: Variant = _mission_manager()
	var current_index: int = mission_manager.order_index(current) if mission_manager != null else -1
	for part in parts_data:
		var unlock_at := int(part.get("unlock_level", 999))
		if current_index >= 0:
			var unlock_index: int = mission_manager.order_index(unlock_at)
			if unlock_index < 0 or unlock_index > current_index:
				continue
		elif unlock_at > current:
			continue
		var part_id: String = str(part.get("id", ""))
		if part_id != "" and not progress["unlocked_parts"].has(part_id):
			progress["unlocked_parts"].append(part_id)
			_queue_unlock_notice(part_id)


# Save migration: a level's target_pool can change between builds (L13 moved
# from jupiter/moon/mars to moon/saturn/pleiades). A stored pick that is no
# longer offered would strand the player on a target the level no longer
# describes, so it is dropped and the level simply asks again. Completed
# levels, credits, badges and every other stored pick are left alone.
func _migrate_stale_level_targets() -> void:
	var overrides: Dictionary = progress.get("level_target_overrides", {})
	if overrides.is_empty():
		return
	var stale: Array[String] = []
	for level_id_value in overrides.keys():
		var level_id := str(level_id_value)
		var level := get_level_by_id(level_id)
		if level.is_empty():
			continue
		var pool: Variant = level.get("target_pool", [])
		if not pool is Array or (pool as Array).is_empty():
			continue
		if not (pool as Array).has(str(overrides[level_id_value])):
			stale.append(level_id)
	for level_id in stale:
		overrides.erase(level_id)
	if not stale.is_empty():
		progress["level_target_overrides"] = overrides


func get_level_by_id(level_id: String) -> Dictionary:
	if level_id == "":
		return {}
	for level_value in levels_data:
		if not level_value is Dictionary:
			continue
		if str((level_value as Dictionary).get("id", "")) == level_id:
			return level_value as Dictionary
	return {}


func _queue_unlock_notice(part_id: String) -> void:
	# Newly unlocked parts are announced with a popup the next time the
	# player stands in the observatory (see observatory_room).
	if not progress.has("pending_unlock_notice") or not progress["pending_unlock_notice"] is Array:
		progress["pending_unlock_notice"] = []
	if not progress["pending_unlock_notice"].has(part_id):
		progress["pending_unlock_notice"].append(part_id)


func take_pending_unlock_notice() -> Array:
	var pending: Array = progress.get("pending_unlock_notice", [])
	if pending.is_empty():
		return []
	var result := pending.duplicate()
	progress["pending_unlock_notice"] = []
	save()
	return result


func _fresh_assembly_state() -> Dictionary:
	return {
		"tripod": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"mount": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"tube": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"objective": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"eyepiece": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"finder_scope": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"focus_knob": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"reflector_tube": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"mirror_cell": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"primary_mirror": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"secondary_spider": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"secondary_mirror": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"focuser": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"collimation_tool": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"detector": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"sunshield": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"radio_dish": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"receiver": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"signal_processor": {"installed": false, "alignment_score": 0, "wrong_attempts": 0},
		"optical_tube_assembly": {"installed": false, "alignment_score": 0, "wrong_attempts": 0}
	}


func _normalize_progress() -> void:
	var defaults := default_progress()
	for key in defaults.keys():
		if not progress.has(key):
			progress[key] = defaults[key]
	_ensure_progress_array("completed_levels")
	_ensure_progress_array("unlocked_parts")
	_ensure_progress_array("observed_objects")
	_ensure_progress_array("badges")
	_ensure_progress_array("journal_entries")
	_ensure_progress_array("completed_concept_cards")
	_ensure_progress_array("seen_teaching_steps")
	_ensure_progress_array("seen_concept_briefs")
	_ensure_progress_array("seen_story_events")
	_ensure_progress_array("pending_unlock_notice")
	_ensure_progress_array("remote_observation_archive")
	_ensure_progress_array("remote_free_intro_seen")
	var tutorial_mode := str(progress.get("tutorial_assistance", TUTORIAL_ASSIST_FULL))
	if not tutorial_mode in TUTORIAL_ASSIST_MODES:
		progress["tutorial_assistance"] = TUTORIAL_ASSIST_FULL
	progress["wide_pulse_capture_window"] = bool(progress.get("wide_pulse_capture_window", false))
	var saved_family := str(progress.get("selected_telescope_family", "refractor"))
	if not saved_family in ASSEMBLY_FAMILIES:
		saved_family = "refractor"
	progress["selected_telescope_family"] = saved_family
	assembly_family_id = saved_family
	_migrate_progress_schema()
	if _developer_sandbox_active and _mission_manager() != null and _mission_manager().has_level(_developer_sandbox_level):
		progress["current_level"] = _developer_sandbox_level
	else:
		_repair_campaign_progress()
	_sync_assembly_family_for_level()
	_unlock_parts_for_current_level()
	if campaign_completed() and bool(progress.get("graduation_seen", false)):
		transfer_unlocked_optical_equipment_ownership()
	else:
		_ensure_active_optical_telescope()
	save()


func _migrate_progress_schema() -> void:
	# Campaign renumbering (90 -> 91 levels, 2026-07-18): the 10th Newtonian
	# level was inserted at L34, shifting every later level up by one. Saves
	# without a campaign_version that sit at L34+ follow their content.
	if int(progress.get("campaign_version", 0)) < 91:
		var current: int = int(progress.get("current_level", 1))
		if current >= 34:
			progress["current_level"] = current + 1
		var shifted_completed: Array = []
		for completed_value in progress.get("completed_levels", []):
			var completed: int = int(completed_value)
			shifted_completed.append(completed + 1 if completed >= 34 else completed)
		progress["completed_levels"] = shifted_completed
		progress["campaign_version"] = 91
	# Old saves predate newer part types (e.g. focus_knob): backfill any
	# missing assembly_state slots and selected_parts defaults.
	if not progress.get("assembly_state") is Dictionary:
		progress["assembly_state"] = _fresh_assembly_state()
	if not progress.get("selected_parts") is Dictionary:
		progress["selected_parts"] = default_progress()["selected_parts"]
	var fresh := _fresh_assembly_state()
	for part_type in fresh.keys():
		if not progress["assembly_state"].has(part_type):
			progress["assembly_state"][part_type] = fresh[part_type]
	var default_selected: Dictionary = default_progress()["selected_parts"]
	for part_type in default_selected.keys():
		if not progress["selected_parts"].has(part_type):
			progress["selected_parts"][part_type] = default_selected[part_type]
	if not progress.get("mission_step_state") is Dictionary:
		progress["mission_step_state"] = {}
	if not progress.get("level_target_overrides") is Dictionary:
		progress["level_target_overrides"] = {}
	if not progress.get("secondary_targets_found") is Dictionary:
		progress["secondary_targets_found"] = {}
	_migrate_stale_level_targets()
	if not progress.get("finder_offset") is Dictionary:
		progress["finder_offset"] = {"az": 0.0, "alt": 0.0}
	if not progress.has("finder_offset_seeded"):
		progress["finder_offset_seeded"] = false
	if not progress.has("finder_offset_initial_len"):
		# Saves seeded before the field existed: use whichever is larger of
		# the legacy 3.0 baseline and the live offset, so the alignment
		# readout starts responsive instead of pinned at 0%.
		progress["finder_offset_initial_len"] = maxf(3.0, finder_offset_length())
	if not (progress.get("tracking_rate") is float or progress.get("tracking_rate") is int):
		progress["tracking_rate"] = 0.0
	if not progress.get("collimation_scores") is Dictionary:
		progress["collimation_scores"] = {"newtonian": 0.0}
	elif not progress["collimation_scores"].has("newtonian"):
		progress["collimation_scores"]["newtonian"] = 0.0
	if not progress.get("tube_assemblies") is Dictionary:
		progress["tube_assemblies"] = {}
	if not progress.get("family_assembly_states") is Dictionary:
		progress["family_assembly_states"] = {}
	if not progress.get("family_selected_parts") is Dictionary:
		progress["family_selected_parts"] = {}
	# Gregorian removal (2026-07-22): a save currently ON a Gregorian level jumps
	# to the first Infrared/Space lesson; credits, logbook and completed levels
	# are all preserved, and no Gregorian part is unlocked.
	if int(progress.get("campaign_version", 0)) < 93:
		if DEPRECATED_GREGORIAN_LEVELS.has(int(progress.get("current_level", 1))):
			progress["current_level"] = FIRST_INFRARED_LEVEL
		# Drop any Gregorian part that a broken save might have unlocked.
		if progress.get("unlocked_parts") is Array:
			progress["unlocked_parts"] = (progress["unlocked_parts"] as Array).filter(
				func(pid): return not str(pid).begins_with("gregorian_"))
		# A stored Gregorian cabinet tab falls back to a valid family.
		if str(progress.get("selected_family", "")) == "gregorian":
			progress["selected_family"] = "cassegrain"
	# Post-FAST missions were retired in campaign v94. Their celestial catalog,
	# art, and free-observation records remain available, but no save may resume
	# inside a removed lesson.
	if int(progress.get("campaign_version", 0)) < 94:
		var retired_level := int(progress.get("current_level", 1))
		if retired_level >= RETIRED_POST_FAST_LEVEL:
			progress["current_level"] = FINAL_CAMPAIGN_LEVEL
	progress["language_mode"] = _normalized_language_mode(str(progress.get("language_mode", "en")))
	language_mode = str(progress["language_mode"])
	progress["campaign_version"] = CAMPAIGN_VERSION


func _repair_campaign_progress() -> void:
	# Retired or malformed level ids resume at the nearest unfinished campaign
	# lesson. Completed FAST campaigns settle on L85 instead of entering removed
	# post-FAST content.
	var mission_manager: Variant = _mission_manager()
	if mission_manager == null:
		return
	var valid_completed: Array = []
	for completed_value in progress.get("completed_levels", []):
		var completed := int(completed_value)
		if mission_manager.has_level(completed) and not valid_completed.has(completed):
			valid_completed.append(completed)
	progress["completed_levels"] = valid_completed
	var repaired_level: int = mission_manager.first_incomplete_level_number(valid_completed)
	if repaired_level <= 0:
		repaired_level = 1
	var previous_level := int(progress.get("current_level", 1))

	# Only rewind a save that is genuinely impossible. The old rule ALWAYS reset
	# current_level to the first incomplete lesson, so any save with a gap in
	# completed_levels (a level jump, a skipped optional lesson) was dragged back
	# on every launch - e.g. finishing L66 and relaunching to find yourself at
	# L11 again, with the later parts pruned. A saved position is trusted when it
	# is a real level and is no further than one step past the furthest level the
	# player has actually completed; retired or otherwise impossible ids still
	# fail that test and are repaired.
	var furthest_completed := 0
	for completed_value in valid_completed:
		furthest_completed = maxi(furthest_completed, int(completed_value))
	# A campaign cursor that still points at a completed lesson is an
	# interrupted completion handoff, not a plausible resume position.
	var saved_is_plausible: bool = mission_manager.has_level(previous_level) \
		and previous_level <= maxi(furthest_completed + 1, repaired_level) \
		and not valid_completed.has(previous_level)
	if saved_is_plausible:
		repaired_level = previous_level
	var changed_level: bool = previous_level != repaired_level
	progress["current_level"] = repaired_level

	# Preserve only inventory that could have been earned from the restored
	# progression position. This removes equipment leaked by the malformed
	# order without resetting credits, journals, cards, or legitimate rewards.
	var legal_parts := _legal_unlocked_part_ids(mission_manager, repaired_level, valid_completed)
	var retained_parts: Array = []
	for part_id_value in progress.get("unlocked_parts", []):
		var part_id := str(part_id_value)
		if legal_parts.has(part_id) and not retained_parts.has(part_id):
			retained_parts.append(part_id)
	var inventory_changed := retained_parts.size() != (progress.get("unlocked_parts", []) as Array).size()
	progress["unlocked_parts"] = retained_parts
	var selected: Dictionary = progress.get("selected_parts", {})
	for part_type_value in selected.keys():
		var part_type := str(part_type_value)
		var selected_id := str(selected.get(part_type, ""))
		if selected_id != "" and not retained_parts.has(selected_id):
			selected[part_type] = ""
	progress["selected_parts"] = selected
	var final_level: int = mission_manager.campaign_order[-1] if not mission_manager.campaign_order.is_empty() else FINAL_CAMPAIGN_LEVEL
	if valid_completed.has(final_level):
		progress["program_completed"] = true
		progress["graduation_pending"] = not bool(progress.get("graduation_seen", false))
		if not progress["badges"].has("Young Observer"):
			progress["badges"].append("Young Observer")
	if changed_level or inventory_changed:
		progress["telescope_ready"] = false


func _legal_unlocked_part_ids(mission_manager: Variant, level_number: int, completed_levels: Array) -> Dictionary:
	var legal: Dictionary = {}
	for part_id_value in default_progress().get("unlocked_parts", []):
		legal[str(part_id_value)] = true
	var current_index: int = mission_manager.order_index(level_number)
	for part in parts_data:
		var unlock_at := int(part.get("unlock_level", 999))
		var unlock_index: int = mission_manager.order_index(unlock_at)
		if unlock_index >= 0 and unlock_index <= current_index:
			legal[str(part.get("id", ""))] = true
	for completed_value in completed_levels:
		var completed_level: Dictionary = mission_manager.get_level(int(completed_value))
		for part_id_value in completed_level.get("unlock_parts", []):
			var part_id := str(part_id_value)
			if not get_part(part_id).is_empty():
				legal[part_id] = true
	return legal


func _ensure_progress_array(key: String) -> void:
	if not progress.has(key) or not progress[key] is Array:
		progress[key] = []


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	push_warning("Expected JSON array: " + path)
	return []


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	push_warning("Expected JSON object: " + path)
	return {}
