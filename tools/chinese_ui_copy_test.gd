extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	_check(gm != null, "GameManager is available")
	_check(feedback != null, "InteractionFeedback is available")
	if gm == null or feedback == null:
		_finish()
		return
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"

	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var panel: Control = feedback.operation_chain(
		host,
		"FAST 装配完成",
		"全系统自检通过",
		"FAST 观测控制台已启用"
	)
	await process_frame
	_check(panel != null, "operation-chain panel is created")
	if panel != null:
		var copy := _collect_label_text(panel)
		_check(copy.contains("操作结果\nFAST 装配完成"), "action copy uses the finished-result wording")
		_check(copy.contains("系统状态\n全系统自检通过"), "status copy uses the system-state wording")
		_check(copy.contains("已解锁\nFAST 观测控制台已启用"), "unlock copy names the FAST console")
		_check(not copy.contains("物理效果") and not copy.contains("现在可见"), "legacy literal headings are absent")
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(root.size))
		_check(viewport_rect.encloses(panel.get_global_rect()), "operation-chain panel stays inside 1024x768")
	host.queue_free()
	await process_frame

	var feedback_source := FileAccess.get_file_as_string("res://scripts/ui/interaction_feedback.gd")
	var room_source := FileAccess.get_file_as_string("res://scripts/ui/observatory_room.gd")
	var card_source := FileAccess.get_file_as_string("res://scripts/ui/learning_card.gd")
	var journal_source := FileAccess.get_file_as_string("res://scripts/ui/learning_journal.gd")
	_check(not feedback_source.contains("\"物理效果\"") and not feedback_source.contains("\"现在可见\""), "shared popup source has no legacy headings")
	_check(room_source.contains("\"FAST 装配完成\""), "FAST completion action is localized")
	_check(room_source.contains("\"全系统自检通过\""), "FAST readiness status is localized")
	_check(room_source.contains("\"FAST 观测控制台已启用\""), "FAST console unlock is localized")
	_check(card_source.contains("\"操作回顾\"") and card_source.contains("\"观测发现\""), "result card uses natural Chinese headings")
	_check(journal_source.contains("\"操作记录\""), "journal uses record-oriented wording")
	_finish()


func _collect_label_text(node: Node) -> String:
	var values: Array[String] = []
	for child in node.get_children():
		if child is Label:
			values.append((child as Label).text)
		values.append(_collect_label_text(child))
	return "\n".join(values)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)


func _finish() -> void:
	if failures == 0:
		print("CHINESE UI COPY TEST PASS")
		quit(0)
	else:
		print("CHINESE UI COPY TEST FAIL (%d)" % failures)
		quit(1)
