extends SceneTree

const OUTPUT := "res://artifacts/mission_complete_typography/mission_complete_zh.png"

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		push_error("Mission Complete typography test requires GameManager and TeachingFlowManager.")
		quit(1)
		return

	gm.new_game()
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	gm.progress["current_level"] = 1
	var level: Dictionary = gm.current_level().duplicate(true)
	gm.last_learning_card = teaching.make_mission_complete_payload(
		level,
		gm.get_object("moon"),
		{
			"quality": "Excellent",
			"success": true,
			"observation_mode": "naked_eye",
			"effective_clarity": 95.0,
			"ratios": {"light": 1.3, "clarity": 1.3, "stability": 1.3},
		},
		{
			"light_score": 95.0,
			"clarity_score": 95.0,
			"stability_score": 95.0,
			"magnification": 1.0,
		}
	)
	gm.progress["current_level"] = 2
	teaching.active_card_mode = "complete"

	var card: Control = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(card)
	current_scene = card
	for _frame in range(12):
		await process_frame

	_expect_label_size(card, "观测完成", 26)
	_expect_label_size(card, "月球", 28)
	_expect_label_size(card, "天然卫星", 15)
	_expect_label_size(card, "观测质量", 17)
	for text in ["清晰度", "对比度", "细节"]:
		_expect_label_size(card, text, 15)
	_expect_label_size(card, "操作回顾", 18)
	for text in ["操作结果", "系统状态", "观测发现"]:
		_expect_label_size(card, text, 13)
	_expect_label_size(card, "奖励解锁", 18)
	_expect_button_size(card, "继续", 16)
	_expect_button_size(card, "打开观测日志", 16)
	_expect_minimum_cjk_size(card, 12)

	var output_dir := OUTPUT.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT))
	_expect(error == OK, "saved Chinese Mission Complete reference image")

	if failures == 0:
		print("MISSION COMPLETE TYPOGRAPHY TEST PASS")
		quit(0)
	else:
		print("MISSION COMPLETE TYPOGRAPHY TEST FAIL (%d)" % failures)
		quit(1)


func _expect_label_size(parent: Node, expected_text: String, minimum_size: int) -> void:
	var label := _find_text_control(parent, expected_text, "Label") as Label
	_expect(label != null, "label '%s' exists" % expected_text)
	if label != null:
		_expect(
			label.get_theme_font_size("font_size") >= minimum_size,
			"label '%s' is at least %d px" % [expected_text, minimum_size]
		)


func _expect_button_size(parent: Node, expected_text: String, minimum_size: int) -> void:
	var button := _find_text_control(parent, expected_text, "Button") as Button
	_expect(button != null, "button '%s' exists" % expected_text)
	if button != null:
		_expect(
			button.get_theme_font_size("font_size") >= minimum_size,
			"button '%s' is at least %d px" % [expected_text, minimum_size]
		)


func _expect_minimum_cjk_size(parent: Node, minimum_size: int) -> void:
	var undersized: Array[String] = []
	for label in _all_labels(parent):
		if _contains_cjk(label.text) and label.get_theme_font_size("font_size") < minimum_size:
			undersized.append("%s=%d" % [label.text, label.get_theme_font_size("font_size")])
	_expect(undersized.is_empty(), "all Chinese result-card labels are at least %d px %s" % [minimum_size, undersized])


func _find_text_control(parent: Node, expected_text: String, control_class: String) -> Control:
	for child in parent.get_children():
		if child.is_class(control_class) and str(child.get("text")) == expected_text:
			return child as Control
		var nested := _find_text_control(child, expected_text, control_class)
		if nested != null:
			return nested
	return null


func _all_labels(parent: Node) -> Array[Label]:
	var result: Array[Label] = []
	if parent is Label:
		result.append(parent as Label)
	for child in parent.get_children():
		result.append_array(_all_labels(child))
	return result


func _contains_cjk(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 0x3400 and code <= 0x9FFF:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		print("  FAIL: ", message)
