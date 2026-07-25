extends SceneTree

var failures := 0
var gm: Node


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager autoload is missing")
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"

	_check_learning_order()
	await _check_filter_first_use()
	await _check_noninteractive_requirements()

	if failures == 0:
		print("OBSERVATION METHOD GUIDANCE TEST PASS")
		quit(0)
	else:
		print("OBSERVATION METHOD GUIDANCE TEST FAIL: ", failures)
		quit(1)


func _check_learning_order() -> void:
	gm.debug_jump_to_level(18, true)
	var l18_steps: Array = gm.current_level().get("teaching_steps", [])
	var has_l18_method_intro := false
	for step_value in l18_steps:
		var step: Dictionary = step_value
		if str(step.get("card_id", "")) == "dark_adaptation_averted_vision" and str(step.get("trigger", "")) == "before_observation":
			has_l18_method_intro = true
			break
	_check(has_l18_method_intro, "L18 teaches dark adaptation and averted vision before either becomes a hard requirement")
	gm.debug_jump_to_level(30, true)
	_check(
		bool(gm.current_level().get("observation_requirements", {}).get("require_averted_vision", false)),
		"L30 is the first hard averted-vision practice"
	)
	gm.debug_jump_to_level(33, true)
	_check(
		str(gm.current_level().get("observation_requirements", {}).get("filter", "")) == "nebula",
		"L33 is the first nebula-filter practice"
	)


func _check_filter_first_use() -> void:
	gm.debug_jump_to_level(33, true)
	gm.selected_object_id = gm.current_target_object_id()
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await _settle()

	var filter_button: Button = view.get("technique_filter_button")
	var status: Label = view.get("technique_status_label")
	_check(filter_button != null, "first filter mission exposes a named nebula-filter control")
	_check(filter_button != null and filter_button.tooltip_text.contains("提高发射星云的对比度"), "filter tooltip explains what the filter changes")
	_check(status != null and status.text.contains("点击开启星云滤镜"), "status tells the player the exact next action")

	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await create_timer(0.35).timeout
	view.call("_show_focus_tutorial")
	await process_frame
	_check(view.get_node_or_null("TutorialHighlight_first_nebula_filter") != null, "first filter use highlights the filter button and teaches it")

	view.set("dark_adaptation", 1.0)
	view.set("observation_elapsed", 10.0)
	filter_button.emit_signal("pressed")
	view.set("observation", view.call("_evaluate"))
	view.call("_refresh_technique_status")
	_check(status.text.contains("星云滤镜：已开启"), "ready status names the enabled nebula filter")
	_check(status.text.contains("暗适应：100% 已达标"), "ready status names the achieved dark-adaptation requirement")
	_check(not status.text.contains("观测技巧已就绪"), "generic unexplained ready text is gone")

	view.queue_free()
	await process_frame


func _check_noninteractive_requirements() -> void:
	gm.debug_jump_to_level(28, true)
	gm.selected_object_id = gm.current_target_object_id()
	var view: Node = load("res://scenes/telescope_view.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	await _settle()
	_check(view.get("technique_status_label") == null, "equipment-only requirements do not create an empty technique panel")
	view.queue_free()
	await process_frame


func _settle() -> void:
	for frame in range(8):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
