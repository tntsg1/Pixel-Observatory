extends SceneTree

const TEST_TIMEOUT_SECONDS := 30.0

var failures := 0
var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_start_watchdog()
	_backup_save()
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		_finish(1)
		return

	gm.new_game()
	gm.language_mode = "en"
	gm.debug_jump_to_level(66, true)
	gm.reset_assembly()

	var bench := load("res://scenes/advanced_assembly.tscn").instantiate() as Control
	root.add_child(bench)
	for _i in range(5):
		await process_frame

	var scroll := bench.get("flat_parts_scroll") as ScrollContainer
	_check(scroll != null, "infrared parts tray exposes its scroll container")
	if scroll == null:
		bench.queue_free()
		await process_frame
		_finish(1)
		return

	scroll.scroll_vertical = 300
	await process_frame
	var remembered := scroll.scroll_vertical
	_check(remembered > 0, "parts tray can be scrolled away from the top")

	var order: Array = bench.get("order")
	var target_type := str(order.back()) if not order.is_empty() else ""
	_check(target_type != "", "infrared assembly exposes selectable parts")
	if target_type != "":
		bench.call("_select_flat_part", target_type)
		for _i in range(3):
			await process_frame
		scroll = bench.get("flat_parts_scroll") as ScrollContainer
		_check(
			scroll != null and absi(scroll.scroll_vertical - remembered) <= 2,
			"selecting a part preserves the left tray scroll position"
		)

		bench.call("_install_at_slot", target_type)
		for _i in range(4):
			await process_frame
		scroll = bench.get("flat_parts_scroll") as ScrollContainer
		_check(
			scroll != null and absi(scroll.scroll_vertical - remembered) <= 2,
			"installing a part preserves the left tray scroll position"
		)

	bench.queue_free()
	await process_frame
	_finish(0 if failures == 0 else 1)


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if finished:
			return
		push_error("ADVANCED ASSEMBLY SCROLL TEST TIMEOUT after %.1f seconds" % TEST_TIMEOUT_SECONDS)
		_finish(1)
	)


func _backup_save() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	failures += 1
	print("  FAIL: " + label)


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	_restore_save()
	print("ADVANCED ASSEMBLY SCROLL TEST %s" % ("PASS" if exit_code == 0 else "FAIL"))
	quit(exit_code)
