extends SceneTree


func _initialize() -> void:
	await process_frame
	var game_manager: Node = root.get_node_or_null("/root/GameManager")
	var cloud_sync: Node = root.get_node_or_null("/root/CloudSyncManager")
	var save_manager: Node = root.get_node_or_null("/root/SaveManager")
	_assert(game_manager != null and cloud_sync != null and save_manager != null, "Cloud-save autoloads must be available.")
	var local: Dictionary = game_manager.call("default_progress")
	local["save_initialized"] = true
	local["current_level"] = 8
	local["save_revision"] = 7
	local["save_updated_at"] = 700
	local["credits"] = 320
	local["completed_levels"] = [1, 2, 3, 4, 5, 6, 7]
	local["observed_objects"] = ["moon", "jupiter"]
	local["journal_entries"] = ["first_light"]
	local["selected_telescope_family"] = "dobsonian"

	var cloud: Dictionary = game_manager.call("default_progress")
	cloud["save_initialized"] = true
	cloud["current_level"] = 4
	cloud["save_revision"] = 3
	cloud["save_updated_at"] = 300
	cloud["credits"] = 700
	cloud["completed_levels"] = [1, 2, 3]
	cloud["observed_objects"] = ["moon", "saturn"]
	cloud["journal_entries"] = ["cloud_note"]
	cloud["unlocked_parts"] = (cloud["unlocked_parts"] as Array) + ["cloud_only_part"]
	cloud["selected_telescope_family"] = "refractor"

	var merged: Dictionary = cloud_sync.call("_merge_progress", local, cloud)
	_assert(int(merged["current_level"]) == 8, "Cloud merge must not lower the local level.")
	_assert(int(merged["credits"]) == 700, "Monotonic credits keep the higher archive value.")
	_assert(str(merged["selected_telescope_family"]) == "dobsonian", "Mutable equipment follows the richer archive.")
	_assert(_contains_all(merged["completed_levels"], [1, 2, 3, 4, 5, 6, 7]), "Completed levels must be preserved.")
	_assert(_contains_all(merged["observed_objects"], ["moon", "jupiter", "saturn"]), "Observed objects must be unioned.")
	_assert(_contains_all(merged["journal_entries"], ["first_light", "cloud_note"]), "Journal entries must be unioned.")
	_assert((merged["unlocked_parts"] as Array).has("cloud_only_part"), "Cloud-only unlocks must survive a local-primary merge.")
	_assert(int(cloud_sync.call("_compare_progress", local, cloud)) > 0, "An older cloud archive must never outrank richer local progress.")

	var first := local.duplicate(true)
	save_manager.call("_update_archive_metadata", first, {})
	_assert(int(first["save_revision"]) == 8, "A meaningful local save increments its revision.")
	var unchanged := first.duplicate(true)
	save_manager.call("_update_archive_metadata", unchanged, first)
	_assert(int(unchanged["save_revision"]) == 8, "An unchanged save must not fabricate a new revision.")

	print("CLOUD_SAVE_MERGE_TEST_PASS")
	quit(0)


func _contains_all(values: Variant, expected: Array) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for value in expected:
		if not (values as Array).has(value):
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
