class_name AssemblyDependencyGraph
extends RefCounted

const DATA_PATH := "res://data/assembly_dependencies.json"

static var _cached_data: Dictionary = {}


static func dependencies_for(family: String, scope := "main") -> Dictionary:
	var family_data: Dictionary = _data().get(family, {})
	var graph_value: Variant = family_data.get(scope, {})
	return (graph_value as Dictionary).duplicate(true) if graph_value is Dictionary else {}


static func prerequisites_for(family: String, scope: String, part_type: String) -> Array[String]:
	var result: Array[String] = []
	var graph := dependencies_for(family, scope)
	var values: Variant = graph.get(part_type, [])
	if values is Array:
		for value in values:
			result.append(str(value))
	return result


static func topological_order(
	family: String,
	scope: String,
	available_parts: Array,
	installed_parts: Array = []
) -> Dictionary:
	return topological_order_from_graph(dependencies_for(family, scope), available_parts, installed_parts)


static func topological_order_from_graph(
	graph: Dictionary,
	available_parts: Array,
	installed_parts: Array = []
) -> Dictionary:
	var available: Array[String] = []
	for value in available_parts:
		var part_type := str(value)
		if part_type != "" and not available.has(part_type):
			available.append(part_type)
	var installed: Array[String] = []
	for value in installed_parts:
		var part_type := str(value)
		if part_type != "" and not installed.has(part_type):
			installed.append(part_type)

	var pending: Array[String] = []
	for part_type in available:
		if not installed.has(part_type):
			pending.append(part_type)
	var ordered: Array[String] = []
	var unresolved_external: Dictionary = {}

	while not pending.is_empty():
		var next_index := -1
		for index in range(pending.size()):
			var part_type := pending[index]
			var blocked := false
			var prerequisite_values: Variant = graph.get(part_type, [])
			var prerequisites: Array = prerequisite_values if prerequisite_values is Array else []
			for prerequisite_value in prerequisites:
				var prerequisite := str(prerequisite_value)
				if installed.has(prerequisite) or ordered.has(prerequisite):
					continue
				if not available.has(prerequisite):
					unresolved_external[part_type] = prerequisite
				blocked = true
				break
			if not blocked:
				next_index = index
				break
		if next_index < 0:
			return {
				"ok": false,
				"order": ordered,
				"cycle": pending.duplicate(),
				"missing_dependencies": unresolved_external.duplicate(),
			}
		ordered.append(pending[next_index])
		pending.remove_at(next_index)

	return {
		"ok": true,
		"order": ordered,
		"cycle": [],
		"missing_dependencies": {},
	}


static func clear_cache() -> void:
	_cached_data.clear()


static func _data() -> Dictionary:
	if not _cached_data.is_empty():
		return _cached_data
	if not FileAccess.file_exists(DATA_PATH):
		push_error("Assembly dependency data is missing: %s" % DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		push_error("Assembly dependency data is invalid JSON: %s" % DATA_PATH)
		return {}
	_cached_data = (parsed as Dictionary).duplicate(true)
	return _cached_data
