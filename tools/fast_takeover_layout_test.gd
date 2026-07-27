extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is available")
		_finish()
		return
	gm.new_game()
	gm.debug_jump_to_level(76, true)

	var scene := load("res://scenes/radio_observation.tscn").instantiate() as Control
	root.add_child(scene)
	await create_timer(1.15).timeout
	for _i in range(2):
		await process_frame
	var layout: Dictionary = scene.call("_takeover_layout_snapshot")
	var array_rect: Rect2 = layout.get("array_rect", Rect2())
	var status_rect: Rect2 = layout.get("status_rect", Rect2())
	var status_text_rect: Rect2 = layout.get("status_text_rect", Rect2())
	var skip_rect: Rect2 = layout.get("skip_rect", Rect2())
	var plot_rect := Rect2(Vector2.ZERO, Vector2(960, 688))

	_check(not array_rect.intersects(status_rect), "facility canvas does not intersect the status panel")
	_check(status_rect.encloses(status_text_rect), "all four status rows stay inside the status panel")
	_check(not status_rect.intersects(skip_rect), "status panel leaves a safe gap above Skip")
	_check(plot_rect.encloses(array_rect), "facility canvas stays inside the takeover plot")
	_check(plot_rect.encloses(status_rect), "status panel stays inside the takeover plot")
	_check(scene.intro_running, "takeover sequence is active during the layout check")
	_check(not scene.content.visible, "underlying FAST stage content is hidden during takeover")
	_check(not scene.terminal_panel.visible, "underlying terminal cannot bleed through the takeover")

	scene.call("_finish_array_takeover")
	await create_timer(0.24).timeout
	await process_frame
	_check(scene.content.visible, "FAST stage content is restored after takeover")
	_check(scene.terminal_panel.visible, "FAST terminal is restored after takeover")

	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST TAKEOVER LAYOUT TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
