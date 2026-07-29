extends Node

const SAVE_PATH := "user://savegame.json"
const SAVE_INITIALIZED_KEY := "save_initialized"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_raw_progress() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed = json.data
	return parsed.duplicate(true) if typeof(parsed) == TYPE_DICTIONARY else {}


func has_resumable_save() -> bool:
	return is_resumable_progress(load_raw_progress())


func is_resumable_progress(candidate: Dictionary) -> bool:
	# File existence is not enough: a blank, corrupted, or partially written
	# archive must never expose a Continue action. A newly started campaign has
	# an explicit marker; older archives remain compatible through real progress
	# signals that could safely be resumed.
	if candidate.is_empty():
		return false
	if not candidate.has("campaign_version") or not candidate.has("current_level"):
		return false
	var campaign_version := int(candidate.get("campaign_version", 0))
	var current_level := int(candidate.get("current_level", 0))
	if campaign_version < 1 or current_level < 1:
		return false
	if typeof(candidate.get("selected_parts", null)) != TYPE_DICTIONARY:
		return false
	if typeof(candidate.get("completed_levels", null)) != TYPE_ARRAY:
		return false
	if bool(candidate.get(SAVE_INITIALIZED_KEY, false)):
		return true
	if current_level > 1 or bool(candidate.get("telescope_ready", false)):
		return true
	for key in ["completed_levels", "journal_entries", "seen_story_events", "seen_concept_briefs", "observed_objects", "badges"]:
		var values = candidate.get(key, [])
		if typeof(values) == TYPE_ARRAY and not (values as Array).is_empty():
			return true
	return false


func load_progress(default_progress: Dictionary) -> Dictionary:
	var parsed := load_raw_progress()
	if parsed.is_empty():
		return default_progress.duplicate(true)
	return _merge_defaults(default_progress, parsed)


func save_progress(progress: Dictionary, queue_cloud: bool = true) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write savegame.")
		return
	file.store_string(JSON.stringify(progress, "\t"))
	if queue_cloud:
		var cloud_sync := get_node_or_null("/root/CloudSyncManager")
		if cloud_sync != null and cloud_sync.has_method("queue_upload"):
			cloud_sync.call_deferred("queue_upload", progress.duplicate(true))


func reset_progress(default_progress: Dictionary) -> Dictionary:
	var progress := default_progress.duplicate(true)
	save_progress(progress)
	return progress


func _merge_defaults(default_value: Variant, saved_value: Variant) -> Variant:
	if typeof(default_value) == TYPE_DICTIONARY and typeof(saved_value) == TYPE_DICTIONARY:
		var merged: Dictionary = default_value.duplicate(true)
		for key in saved_value.keys():
			if merged.has(key):
				merged[key] = _merge_defaults(merged[key], saved_value[key])
			else:
				merged[key] = saved_value[key]
		return merged
	return saved_value
