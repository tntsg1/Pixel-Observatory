extends Node

var levels: Array = []
# Play sequence of level NUMBERS. This is the single mainline authority and
# intentionally ends at the FAST graduation.
var campaign_order: Array[int] = []


func load_levels(level_data: Array) -> void:
	levels = level_data
	_load_campaign_order()


func _load_campaign_order() -> void:
	campaign_order.clear()
	var available: Array[int] = []
	for level in levels:
		# Deprecated lessons (e.g. the removed Gregorian family) stay in the data
		# file for save compatibility but are NOT part of the play sequence.
		if bool(level.get("deprecated", false)):
			continue
		var level_number := int(level.get("level_number", 0))
		if level_number > 0 and not available.has(level_number):
			available.append(level_number)
	available.sort()
	var requested: Array[int] = []
	if FileAccess.file_exists("res://data/campaign_order.json"):
		var file := FileAccess.open("res://data/campaign_order.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for value in parsed.get("order", []):
					requested.append(int(value))
	if _is_complete_campaign_order(requested, available):
		campaign_order = requested
		return
	# A malformed order must never splice advanced missions into the opening
	# lessons. Numeric order is the safe fallback until the data is repaired.
	if not requested.is_empty():
		push_error("Invalid campaign_order.json; using strict numeric campaign order.")
	campaign_order = available


func _is_complete_campaign_order(requested: Array[int], available: Array[int]) -> bool:
	if requested.size() != available.size():
		return false
	var seen: Dictionary = {}
	for level_number in requested:
		if level_number <= 0 or not available.has(level_number) or seen.has(level_number):
			return false
		seen[level_number] = true
	return true


func get_level(level_number: int) -> Dictionary:
	for level in levels:
		if int(level.get("level_number", 0)) == level_number:
			return level
	return {}


func order_index(level_number: int) -> int:
	return campaign_order.find(level_number)


func next_level_number(after_level: int) -> int:
	var index := order_index(after_level)
	if index < 0 or index + 1 >= campaign_order.size():
		return after_level
	return campaign_order[index + 1]


func next_incomplete_level_number(after_level: int, completed_levels: Array) -> int:
	var index := order_index(after_level)
	if index < 0:
		return first_incomplete_level_number(completed_levels)
	for next_index in range(index + 1, campaign_order.size()):
		var candidate := campaign_order[next_index]
		if not completed_levels.has(candidate):
			return candidate
	return campaign_order[campaign_order.size() - 1] if not campaign_order.is_empty() else after_level


func first_incomplete_level_number(completed_levels: Array) -> int:
	for candidate in campaign_order:
		if not completed_levels.has(candidate):
			return candidate
	return campaign_order[campaign_order.size() - 1] if not campaign_order.is_empty() else 1


func has_level(level_number: int) -> bool:
	return campaign_order.has(level_number)


func campaign_order_issues() -> Array[String]:
	var available: Array[int] = []
	for level in levels:
		if bool(level.get("deprecated", false)):
			continue
		var level_number := int(level.get("level_number", 0))
		if level_number > 0 and not available.has(level_number):
			available.append(level_number)
	available.sort()
	var issues: Array[String] = []
	if not _is_complete_campaign_order(campaign_order, available):
		issues.append("campaign_order must contain each real level exactly once")
	return issues


func is_final_level(level_number: int) -> bool:
	if campaign_order.is_empty():
		return level_number >= levels.size()
	return level_number == campaign_order[campaign_order.size() - 1]


func get_max_level() -> int:
	return campaign_order[-1] if not campaign_order.is_empty() else 0
