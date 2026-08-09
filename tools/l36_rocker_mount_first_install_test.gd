extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return
	gm.new_game()
	gm.debug_jump_to_level(36, true)
	gm.select_assembly_family("dobsonian")
	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	await process_frame
	await process_frame
	_check(str(bench.call("_family")) == "dobsonian", "L36 opens the Dobsonian assembly blueprint")
	bench.set("selected_type", "mount")
	bench.call("_install_main_part", "mount")
	await process_frame
	var mount_state: Dictionary = gm.progress.get("assembly_state", {}).get("mount", {})
	_check(bool(mount_state.get("installed", false)), "L36 installs the Dobsonian rocker mount as the first main component")
	_check(str(mount_state.get("installed_part_id", "")) == "dobsonian_rocker_mount", "L36 stores the selected rocker mount id, not a stale equipped part")
	bench.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("L36 ROCKER MOUNT FIRST INSTALL TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  FAIL: " + label)
