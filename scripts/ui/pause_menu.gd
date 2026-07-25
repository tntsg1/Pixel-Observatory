extends CanvasLayer

var _paused := false

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel/ResumeBtn.pressed.connect(_on_resume)
	$Panel/RestartBtn.pressed.connect(_on_restart)
	$Panel/MenuBtn.pressed.connect(_on_menu)
	_build_tutorial_mode()


func _input(event):
	if event.is_action_pressed("pause"):
		if _paused:
			_resume()
		else:
			_pause()


func _pause():
	_paused = true
	visible = true
	get_tree().paused = true


func _resume():
	_paused = false
	visible = false
	get_tree().paused = false


func _on_resume():
	_resume()


func _on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _build_tutorial_mode() -> void:
	var panel := $Panel as Panel
	panel.offset_left = -180.0
	panel.offset_top = -194.0
	panel.offset_right = 180.0
	panel.offset_bottom = 194.0
	$Panel/Title.position = Vector2(20, 10)
	$Panel/Title.size = Vector2(320, 32)
	$Panel/Title.text = GameManager.text("PAUSED", "暂停")
	$Panel/ResumeBtn.position = Vector2(30, 232)
	$Panel/ResumeBtn.size = Vector2(300, 34)
	$Panel/ResumeBtn.text = GameManager.text("Resume", "继续")
	$Panel/RestartBtn.position = Vector2(30, 274)
	$Panel/RestartBtn.size = Vector2(300, 34)
	$Panel/RestartBtn.text = GameManager.text("Restart Scene", "重新开始当前场景")
	$Panel/MenuBtn.position = Vector2(30, 316)
	$Panel/MenuBtn.size = Vector2(300, 34)
	$Panel/MenuBtn.text = GameManager.text("Main Menu", "返回主菜单")

	var tutorial_label := Label.new()
	tutorial_label.text = GameManager.text("Tutorial assistance", "教程辅助")
	tutorial_label.position = Vector2(24, 50)
	tutorial_label.size = Vector2(312, 24)
	tutorial_label.add_theme_color_override("font_color", Color(0.48, 0.86, 1.0))
	panel.add_child(tutorial_label)

	var selector := OptionButton.new()
	selector.name = "TutorialMode"
	selector.position = Vector2(24, 78)
	selector.size = Vector2(312, 36)
	for mode in GameManager.TUTORIAL_ASSIST_MODES:
		selector.add_item(_mode_label(mode))
		selector.set_item_metadata(selector.item_count - 1, mode)
		if mode == GameManager.tutorial_assistance_mode():
			selector.select(selector.item_count - 1)
	panel.add_child(selector)

	var description := Label.new()
	description.name = "TutorialDescription"
	description.position = Vector2(24, 120)
	description.size = Vector2(312, 54)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	panel.add_child(description)
	var help := Button.new()
	help.text = GameManager.text("Mission / Help", "任务记录 / 帮助")
	help.position = Vector2(30, 184)
	help.size = Vector2(300, 36)
	help.pressed.connect(_show_mission_help)
	panel.add_child(help)
	selector.item_selected.connect(_on_tutorial_mode_selected.bind(selector))
	_refresh_tutorial_description()


func _on_tutorial_mode_selected(index: int, selector: OptionButton) -> void:
	var mode := str(selector.get_item_metadata(index))
	GameManager.set_tutorial_assistance_mode(mode)
	_refresh_tutorial_description()
	if mode == GameManager.TUTORIAL_ASSIST_FREE and not bool(GameManager.progress.get("tutorial_free_confirmation_seen", false)):
		_show_free_confirmation()


func _mode_label(mode: String) -> String:
	match mode:
		GameManager.TUTORIAL_ASSIST_LIGHT:
			return GameManager.text("Light Hints", "轻度提示")
		GameManager.TUTORIAL_ASSIST_FREE:
			return GameManager.text("Free Exploration", "自由探索")
	return GameManager.text("Full Guidance", "完整引导")


func _refresh_tutorial_description() -> void:
	var copy := $Panel.get_node_or_null("TutorialDescription") as Label
	if copy == null:
		return
	match GameManager.tutorial_assistance_mode():
		GameManager.TUTORIAL_ASSIST_LIGHT:
			copy.text = GameManager.text("Objectives, errors, and short hints remain.", "保留目标、错误说明和短提示。")
		GameManager.TUTORIAL_ASSIST_FREE:
			copy.text = GameManager.text("No forced lessons. All gameplay rules remain active.", "不再强制教学，所有玩法规则仍然有效。")
		_:
			copy.text = GameManager.text("All story lessons and teaching overlays are enabled.", "启用全部剧情教学和引导界面。")


func _show_free_confirmation() -> void:
	var dialog := AcceptDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = GameManager.text("Free Exploration", "自由探索")
	dialog.dialog_text = GameManager.text(
		"Tutorial interruptions are off. Equipment, failures, rewards, and mission progress are unchanged. Guidance can be restored here at any time.",
		"强制教学已关闭。设备、失败、奖励和任务进度均保持不变；你可以随时在这里恢复引导。"
	)
	dialog.confirmed.connect(func() -> void:
		GameManager.acknowledge_free_exploration_confirmation()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 210))


func _show_mission_help() -> void:
	var level := GameManager.current_level()
	var dialog := AcceptDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = GameManager.text("Mission / Help", "任务记录 / 帮助")
	var title := GameManager.text(str(level.get("title_en", "Current Mission")), str(level.get("title_zh", "当前任务")))
	var objective := GameManager.text(str(level.get("description_en", "")), str(level.get("description_zh", "")))
	var hint := GameManager.text(str(level.get("hint_text_en", "")), str(level.get("hint_text_zh", "")))
	dialog.dialog_text = "%s\n\n%s\n\n%s" % [title, objective, hint]
	add_child(dialog)
	dialog.popup_centered(Vector2i(620, 300))
