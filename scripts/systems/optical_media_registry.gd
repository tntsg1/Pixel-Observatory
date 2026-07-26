class_name OpticalMediaRegistry
extends RefCounted

const REGISTRY_PATH := "res://data/optical_observation_media.json"

static var _cache: Dictionary = {}


static func all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	if not FileAccess.file_exists(REGISTRY_PATH):
		return {}
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_cache = parsed as Dictionary
	return _cache


static func entry(object_id: String) -> Dictionary:
	var value: Variant = all().get(object_id, {})
	return value as Dictionary if value is Dictionary else {}


static func master_path(object_id: String) -> String:
	var path := str(entry(object_id).get("master_path", ""))
	if path != "" and ResourceLoader.exists(path):
		return path
	return ""


static func media_class(object_id: String) -> String:
	return str(entry(object_id).get("media_class", ""))


static func render_mode(object_id: String) -> String:
	return str(entry(object_id).get("render_mode", ""))


static func crop_metadata(object_id: String) -> Dictionary:
	var value: Variant = entry(object_id).get("crop", {})
	return value as Dictionary if value is Dictionary else {}


static func is_isolated_planet(object_id: String) -> bool:
	return media_class(object_id) == "isolated_planet"


static func is_extended_field(object_id: String) -> bool:
	return media_class(object_id) == "extended_field"


static func clear_cache() -> void:
	_cache.clear()
