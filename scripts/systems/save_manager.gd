extends Node

const SAVE_PATH := "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_progress(default_progress: Dictionary) -> Dictionary:
	if not has_save():
		return default_progress.duplicate(true)
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_progress.duplicate(true)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
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
