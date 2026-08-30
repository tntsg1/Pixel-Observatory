extends Control

const GOLD := Color(0.94, 0.71, 0.30)
const CYAN := Color(0.43, 0.84, 0.96)
const PALE := Color(0.88, 0.92, 0.96)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_notify_parent()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.008, 0.018, 0.035)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# Between the background fill and the panel below, so the panel still draws
	# on top. This is a milestone screen the player reads at the end of a study
	# chapter; a faint starfield suits the moment better than a flat slab.
	var life := AmbientLife.new()
	life.name = "AmbientLife"
	life.configure({
		"twinkle_zone": Rect2(0, 0, 1024, 768),
		"twinkle_count": 20,
		"seed": 20260827,
	})
	add_child(life)

	var panel := Panel.new()
	panel.position = Vector2(112, 78)
	panel.size = Vector2(800, 612)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.085, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_add_label(panel, GameManager.text("RESEARCH ROUTE COMPLETE", "研究路线完成"), Vector2(54, 42), Vector2(692, 44), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(panel, GameManager.text("A concise graduation from the original Pixel Observatory curriculum", "从《像素天文台》原课程中完成一次精简毕业"), Vector2(54, 90), Vector2(692, 30), 16, CYAN, HORIZONTAL_ALIGNMENT_CENTER)

	var divider := ColorRect.new()
	divider.position = Vector2(72, 138)
	divider.size = Vector2(656, 1)
	divider.color = Color(GOLD, 0.55)
	panel.add_child(divider)

	_add_label(panel, GameManager.text("You used the actual game instruments to:", "你刚才使用原游戏仪器完成了："), Vector2(72, 164), Vector2(656, 30), 19, PALE)
	var achievements := GameManager.text(
		"• acquire a target from naked eye to finder and main telescope\n• balance focus, eyepiece power, seeing and light pollution\n• compensate for Earth’s rotation with tracking\n• compare refractive colour fringe with a mirror system\n• construct infrared false colour and recover a weak radio signal",
		"• 从肉眼、寻星镜到主望远镜逐级捕获目标\n• 平衡调焦、目镜倍率、视宁度与光污染\n• 使用追踪补偿地球自转\n• 比较折射色差与反射镜成像\n• 制作红外假彩色图并恢复微弱射电信号"
	)
	_add_label(panel, achievements, Vector2(88, 206), Vector2(624, 188), 17, Color(0.78, 0.88, 0.91))
	_add_label(panel, GameManager.text("Your formal campaign save was never changed.", "你的正式游戏存档没有被修改。"), Vector2(72, 414), Vector2(656, 28), 15, Color(0.57, 0.78, 0.66), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(panel, GameManager.text("Return to the study page to answer the final questions.", "请返回研究页面完成最后的后测问题。"), Vector2(72, 452), Vector2(656, 30), 18, PALE, HORIZONTAL_ALIGNMENT_CENTER)

	var button := Button.new()
	button.position = Vector2(244, 516)
	button.size = Vector2(312, 54)
	button.text = GameManager.text("CONTINUE TO FINAL QUESTIONS", "继续完成后测")
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_notify_parent)
	panel.add_child(button)


func _add_label(parent: Control, value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _notify_parent() -> void:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return
	JavaScriptBridge.eval("window.parent.postMessage({source:'pixel-observatory-study-godot',event:'complete',complete:true}, location.origin)", true)
