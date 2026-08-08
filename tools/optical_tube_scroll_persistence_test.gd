extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	# L36 uses the same Dobsonian tube tray shown in the report.
	gm.debug_jump_to_level(36, false)
	gm.reset_assembly()
	var tube := load("res://scenes/optical_tube_assembly.tscn").instantiate() as Control
	root.add_child(tube)
	for _frame in range(4):
		await process_frame
	var scroll := tube.get("parts_scroll") as ScrollContainer
	_check(scroll != null, "tube tray exposes its scroll container")
	if scroll != null:
		scroll.scroll_vertical = 300
		await process_frame
		var remembered := scroll.scroll_vertical
		_check(remembered > 0, "tube tray can be scrolled away from the top")
		var config: Dictionary = tube.get("config")
		var order: Array = config.get("order", [])
		var target := str(order.back()) if not order.is_empty() else ""
		_check(target != "", "tube tray has a selectable final card")
		if target != "":
			tube.call("_select_newtonian_tube_part", target)
			for _frame in range(3):
				await process_frame
			scroll = tube.get("parts_scroll") as ScrollContainer
			_check(
				scroll != null and absi(scroll.scroll_vertical - remembered) <= 2,
				"selecting a tube part preserves the current tray viewport"
			)
	tube.queue_free()
	await process_frame
	if failures == 0:
		print("OPTICAL TUBE SCROLL TEST: PASS")
		quit(0)
	else:
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)
