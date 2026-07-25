extends Control

# Constellation observation - four explicit teaching phases:
#   1 identify the shape  2 connect key stars in order
#   3 navigate the aim to the catalog position  4 record the observation
# The right panel always answers "what do I do NOW and why is Record locked".
# Contract kept for tests: target_id / pattern vars, complete_current_mission exit.

const GOLD := Color("d6a743")
const GOLD_BRIGHT := Color("ffd97a")
const CYAN := Color("55c7df")
const GREEN := Color("6fdf8a")
const RED := Color("ef7a6a")
const TEXT := Color("ece8dc")
const DIM := Color("8391a6")
const MAP_RECT := Rect2(58, 116, 620, 520)

enum Phase { IDENTIFY, CONNECT, NAVIGATE, READY }

var constellation: Dictionary = {}
var level: Dictionary = {}
var target_id := ""
var pattern: Array = []
var ordered_indices: Array = []
var completed_edges := 0
var shape_identified := false
var aim_az := 0.0
var aim_alt := 45.0
var target_az := 0.0
var target_alt := 45.0
var pointer_phase := 0.0
var edge_anim := 1.0
var complete_flash := 0.0
var hovered_star := -1
var drag_aiming := false
var position_is_live := false

var banner_label: Label
var instruction_label: Label
var step_label: Label
var todo_label: Label
var progress_labels: Dictionary = {}
var error_label: Label
var record_button: Button
var record_reason: Label
var choice_box: VBoxContainer
var choice_buttons: Dictionary = {}


func _ready() -> void:
	level = GameManager.current_level()
	target_id = GameManager.current_target_object_id()
	constellation = GameManager.get_constellation(target_id)
	if constellation.is_empty():
		push_error("Missing constellation data: " + target_id)
		GameManager.go("observatory")
		return
	pattern = constellation.get("stars", [])
	ordered_indices = constellation.get("connection_order", [])
	target_az = float(constellation.get("azimuth", 0.0))
	target_alt = float(constellation.get("altitude", 45.0))
	# Real sky: anchor at the RA/Dec position for the CURRENT clock and site.
	# Below the comfort altitude we keep the teaching fallback and SAY so.
	if constellation.has("ra_hours") and constellation.has("dec_degrees"):
		var service: RefCounted = preload("res://scripts/systems/sky_position_service.gd").new()
		var live: Dictionary = service.calculate_alt_az_from_ra_dec(
			float(constellation.get("ra_hours", 0.0)),
			float(constellation.get("dec_degrees", 0.0)),
			float(GameManager.observing_location().get("lat", 34.0522)),
			float(GameManager.observing_location().get("lon", -118.2437)),
			Time.get_datetime_dict_from_system(true)
		)
		var live_alt := float(live.get("altitude", target_alt))
		if live_alt >= 12.0:
			target_az = float(live.get("azimuth", target_az))
			target_alt = live_alt
			position_is_live = true
	aim_az = fposmod(target_az + 24.0, 360.0)
	aim_alt = clampf(target_alt - 12.0, 0.0, 90.0)
	_build()
	InteractionFeedback.page_enter(self)
	set_process(true)
	queue_redraw()


func _phase() -> int:
	if not shape_identified:
		return Phase.IDENTIFY
	if completed_edges < ordered_indices.size():
		return Phase.CONNECT
	if not _aim_locked():
		return Phase.NAVIGATE
	return Phase.READY


func _process(delta: float) -> void:
	pointer_phase += delta
	edge_anim = minf(edge_anim + delta * 4.0, 1.0)
	complete_flash = maxf(complete_flash - delta * 0.8, 0.0)
	# Identify phase: the correct answer button carries a gold pulse so the
	# player knows where the teaching wants their attention.
	if _phase() == Phase.IDENTIFY and choice_buttons.has(target_id):
		var pulse := 0.5 + 0.5 * sin(pointer_phase * 4.0)
		var target_button: Button = choice_buttons[target_id]
		target_button.modulate = Color(1.0 + 0.25 * pulse, 1.0 + 0.18 * pulse, 0.9 + 0.05 * pulse)
	if _phase() >= Phase.NAVIGATE:
		var speed := 22.0 * delta
		if Input.is_key_pressed(KEY_SHIFT) or TouchInput.boost_held:
			speed *= 2.0
		var changed := false
		var move := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
			move.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
			move.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_up"):
			move.y += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_down"):
			move.y -= 1.0
		if move == Vector2.ZERO and TouchInput.is_mobile():
			var touch := TouchInput.move_vector()
			move = Vector2(touch.x, -touch.y)
		if move != Vector2.ZERO:
			aim_az = fposmod(aim_az + move.x * speed, 360.0)
			aim_alt = clampf(aim_alt + move.y * speed, 0.0, 90.0)
			changed = true
		if changed:
			_update_status()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var phase := _phase()
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		hovered_star = _nearest_star(motion.position)
		if drag_aiming and phase >= Phase.NAVIGATE:
			aim_az = fposmod(aim_az - motion.relative.x * 0.12, 360.0)
			aim_alt = clampf(aim_alt + motion.relative.y * 0.12, 0.0, 90.0)
			_update_status()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var click := event as InputEventMouseButton
		if not click.pressed:
			drag_aiming = false
			return
		if phase == Phase.CONNECT:
			_try_connect_star(_nearest_star(click.position))
		elif phase >= Phase.NAVIGATE and MAP_RECT.has_point(click.position):
			drag_aiming = true


func _try_connect_star(index: int) -> void:
	if index < 0:
		return
	var expected := int(ordered_indices[completed_edges])
	if index == expected:
		completed_edges += 1
		edge_anim = 0.0
		_set_error("")
		if completed_edges >= ordered_indices.size():
			complete_flash = 1.0
			InteractionFeedback.success(self)
			_set_feedback(GameManager.text(
				"Pattern complete! Now steer the whole constellation to the view center.",
				"连线完成！现在把整个星座移动到视野中心。"))
		else:
			_set_feedback(GameManager.text(
				"Correct. Next: star %d." % (completed_edges + 1),
				"正确。下一颗：第 %d 颗星。" % (completed_edges + 1)))
		_update_status()
	else:
		_set_error(GameManager.text(
			"Click star %d first - follow the numbered order." % (completed_edges + 1),
			"请先点击第 %d 颗星，按编号顺序连线。" % (completed_edges + 1)))
		InteractionFeedback.error(self)
	queue_redraw()


# ------------------------------------------------------------------ build ui


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var target_name := _bilingual_name(constellation)
	banner_label = _add_label(GameManager.text("Target: ", "目标：") + target_name, Vector2(58, 18), Vector2(620, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	instruction_label = _add_label("", Vector2(58, 56), Vector2(620, 52), 16, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# ---- right panel: mission / step / what-to-do / progress / actions ----
	var panel_x := 700.0
	var panel_w := 306.0
	_add_label(GameManager.text("MISSION", "任务"), Vector2(panel_x + 16, 100), Vector2(panel_w - 32, 22), 14, GOLD)
	_add_label(target_name, Vector2(panel_x + 16, 124), Vector2(panel_w - 32, 24), 16, TEXT)
	_add_label(GameManager.text("Type: Constellation (naked eye)", "类型：星座（肉眼观测）"), Vector2(panel_x + 16, 150), Vector2(panel_w - 32, 20), 11, DIM)
	var tip := _add_label(GameManager.dict_text(constellation, "navigation_tip"), Vector2(panel_x + 16, 172), Vector2(panel_w - 32, 40), 11, DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	step_label = _add_label("", Vector2(panel_x + 16, 220), Vector2(panel_w - 32, 24), 15, CYAN)
	todo_label = _add_label("", Vector2(panel_x + 16, 248), Vector2(panel_w - 32, 84), 15, TEXT)
	todo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_add_label(GameManager.text("PROGRESS", "进度"), Vector2(panel_x + 16, 340), Vector2(panel_w - 32, 20), 13, GOLD)
	var progress_rows := ["shape", "edges", "azimuth", "altitude", "season"]
	for i in range(progress_rows.size()):
		progress_labels[progress_rows[i]] = _add_label("", Vector2(panel_x + 16, 364 + i * 22), Vector2(panel_w - 32, 20), 12, TEXT)

	error_label = _add_label("", Vector2(panel_x + 16, 478), Vector2(panel_w - 32, 66), 13, RED)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(panel_x + 16, 478)
	choice_box.size = Vector2(panel_w - 32, 180)
	choice_box.add_theme_constant_override("separation", 8)
	add_child(choice_box)
	_build_shape_choices()

	record_button = _button("", Vector2(panel_x + 16, 620), Vector2(panel_w - 32, 46))
	add_child(record_button)
	record_button.pressed.connect(_record)
	record_reason = _add_label("", Vector2(panel_x + 16, 668), Vector2(panel_w - 32, 34), 10, DIM)
	record_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(GameManager.text("Back", "返回"), Vector2(panel_x + 16, 706), Vector2(panel_w - 32, 34))
	add_child(back)
	back.pressed.connect(func() -> void: GameManager.go("observatory"))

	_add_label(GameManager.text("A/D: West/East   W/S: Up/Down   Shift: Fast   (drag the map on touch)",
		"A/D：向西/向东转动   W/S：抬高/降低   Shift：加速（触屏可拖动星图）"),
		Vector2(58, 644), Vector2(620, 24), 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	if not position_is_live:
		_add_label(GameManager.text("Tonight: teaching simulation position (real spot is below the horizon).",
			"今晚：教学模拟位置（真实位置低于地平线）。"),
			Vector2(58, 668), Vector2(620, 22), 10, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_update_status()


func _bilingual_name(item: Dictionary) -> String:
	var en := str(item.get("name_en", ""))
	var zh := str(item.get("name_zh", ""))
	if en == "":
		return zh
	if zh == "" or en == zh:
		return en
	return GameManager.text(en, zh)


func _build_shape_choices() -> void:
	var choices: Array = [target_id]
	for candidate in GameManager.constellations_data:
		var id := str(candidate.get("id", ""))
		if id != target_id and choices.size() < 4:
			choices.append(id)
	choices.shuffle()
	for id_value in choices:
		var id := str(id_value)
		var item := GameManager.get_constellation(id)
		var button := _button(_bilingual_name(item), Vector2.ZERO, Vector2(274, 40))
		button.pressed.connect(_choose_shape.bind(id))
		choice_box.add_child(button)
		choice_buttons[id] = button


func _choose_shape(id: String) -> void:
	if id != target_id:
		_set_error(GameManager.text(
			"That is not tonight's target. Compare the WHOLE pattern shape, not one bright star.",
			"这不是当前任务目标。请比较整个星座的形状，不要只看最亮的一颗星。"))
		InteractionFeedback.error(choice_box)
		return
	shape_identified = true
	choice_box.visible = false
	_set_error("")
	InteractionFeedback.success(self)
	_set_feedback(GameManager.text(
		"Shape identified! Now click the key stars in numbered order.",
		"星座形状识别正确！现在按编号顺序点击关键恒星。"))
	_update_status()
	queue_redraw()


# ---------------------------------------------------------------- recording


func _record() -> void:
	var reason := _record_block_reason()
	if reason != "":
		_set_error(reason)
		InteractionFeedback.error(record_button)
		return
	var observation := {
		"success": true,
		"quality": "Good",
		"visual_effect": "clear",
		"observation_mode": "constellation",
		"feedback_en": "Shape, star order, season, and sky position verified.",
		"feedback_zh": "已验证形状、恒星顺序、季节与天空位置。",
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0},
		"constellation_edges": completed_edges,
		"aim_azimuth": aim_az,
		"aim_altitude": aim_alt
	}
	InteractionFeedback.success(record_button, "constellation_logged")
	GameManager.complete_current_mission(target_id, observation)


func _record_block_reason() -> String:
	if not shape_identified:
		return GameManager.text("Record locked: identify the constellation first (step 1).",
			"记录未开放：请先完成第 1 步识别星座。")
	if completed_edges < ordered_indices.size():
		return GameManager.text("Record locked: connect all key stars (%d/%d done)." % [completed_edges, ordered_indices.size()],
			"记录未开放：请连完全部关键星（当前 %d/%d）。" % [completed_edges, ordered_indices.size()])
	if not _season_visible():
		return GameManager.text("Record locked: this constellation is outside its seasonal window.",
			"记录未开放：当前季节不在这个星座的可见窗口内。")
	if not _aim_locked():
		return GameManager.text("Record locked: center the constellation (Az delta %.1f°, Alt delta %.1f°)." % [_wrapped_delta(target_az, aim_az), target_alt - aim_alt],
			"记录未开放：请把星座移到中心（方位差 %.1f°，高度差 %.1f°）。" % [_wrapped_delta(target_az, aim_az), target_alt - aim_alt])
	return ""


# ------------------------------------------------------------------- status


func _update_status() -> void:
	var phase := _phase()
	var step_names := [
		GameManager.text("Step 1/4 - Identify the constellation", "第 1/4 步 · 识别星座"),
		GameManager.text("Step 2/4 - Connect the key stars", "第 2/4 步 · 连接关键星"),
		GameManager.text("Step 3/4 - Aim at the sky position", "第 3/4 步 · 调整观测方向"),
		GameManager.text("Step 4/4 - Record the observation", "第 4/4 步 · 记录观测")
	]
	step_label.text = str(step_names[phase])
	match phase:
		Phase.IDENTIFY:
			todo_label.text = GameManager.text(
				"Pick the correct constellation from the buttons below. Look at the overall shape of the faint outline on the map.",
				"从下方选项中选择正确的星座。观察星图上淡色轮廓的整体形状，不要只看最亮的一颗星。")
			instruction_label.text = GameManager.text(
				"Step 1: choose the constellation that matches the highlighted outline.",
				"第一步：从右侧选项中选择与淡色轮廓一致的星座。")
		Phase.CONNECT:
			todo_label.text = GameManager.text(
				"Click the key stars in numbered order. The next star pulses gold.",
				"按编号顺序点击关键星。下一颗星带金色脉冲环和箭头。")
			instruction_label.text = GameManager.text(
				"Step 2: connect star %d of %d - follow the gold ring." % [completed_edges + 1, ordered_indices.size()],
				"第二步：连接第 %d / %d 颗星——跟随金色脉冲环。" % [completed_edges + 1, ordered_indices.size()])
		Phase.NAVIGATE:
			var near := _aim_near()
			todo_label.text = GameManager.text(
				"Use A/D and W/S (Shift to speed up) until the target ring sits in the map center.",
				"用 A/D 和 W/S（Shift 加速）移动视野，直到目标环停在星图中心。")
			instruction_label.text = GameManager.text(
				"Almost there - keep fine-tuning, the target is nearly centered." if near else "Step 3: steer the telescope so the constellation reaches the view center.",
				"继续微调，目标即将居中。" if near else "第三步：调整望远镜方向，将目标移到视野中心。")
		Phase.READY:
			todo_label.text = GameManager.text(
				"Everything checks out. Press Record to write this observation into the Club Logbook.",
				"所有条件已满足。点击「记录观测」写入社团日志。")
			instruction_label.text = GameManager.text(
				"Target centered - ready to record!", "目标已居中，可以记录观测！")
			instruction_label.add_theme_color_override("font_color", GREEN)
	if phase != Phase.READY:
		instruction_label.add_theme_color_override("font_color", TEXT)

	var check := "✓"
	var cross := "—"
	progress_labels["shape"].text = GameManager.text("Shape identified: ", "星座识别：") + (check if shape_identified else cross)
	progress_labels["shape"].add_theme_color_override("font_color", GREEN if shape_identified else DIM)
	var edges_done := completed_edges >= ordered_indices.size() and ordered_indices.size() > 0
	progress_labels["edges"].text = GameManager.text("Star links: %d / %d", "星座连线：%d / %d") % [completed_edges, ordered_indices.size()]
	progress_labels["edges"].add_theme_color_override("font_color", GREEN if edges_done else TEXT)
	var d_az := _wrapped_delta(target_az, aim_az)
	var d_alt := target_alt - aim_alt
	progress_labels["azimuth"].text = GameManager.text("Azimuth Δ: %+.1f°  (aim %.1f°)", "方位差：%+.1f°（当前 %.1f°）") % [d_az, aim_az]
	progress_labels["azimuth"].add_theme_color_override("font_color", GREEN if absf(d_az) <= 2.0 else TEXT)
	progress_labels["altitude"].text = GameManager.text("Altitude Δ: %+.1f°  (aim %.1f°)", "高度差：%+.1f°（当前 %.1f°）") % [d_alt, aim_alt]
	progress_labels["altitude"].add_theme_color_override("font_color", GREEN if absf(d_alt) <= 2.0 else TEXT)
	var season_ok := _season_visible()
	progress_labels["season"].text = GameManager.text("Season window: ", "季节可见性：") + (check if season_ok else GameManager.text("not visible", "不可见"))
	progress_labels["season"].add_theme_color_override("font_color", GREEN if season_ok else RED)

	var block := _record_block_reason()
	record_button.disabled = block != ""
	record_button.text = GameManager.text("Record Observation", "记录观测")
	record_reason.text = block
	if block == "" and phase == Phase.READY:
		record_reason.text = GameManager.text("All conditions met - the button is live.", "全部条件满足，按钮已点亮。")
		record_reason.add_theme_color_override("font_color", GREEN)
		if record_button.modulate == Color.WHITE:
			var tween := create_tween()
			tween.tween_property(record_button, "modulate", Color(1.35, 1.25, 0.9), 0.25)
			tween.tween_property(record_button, "modulate", Color.WHITE, 0.35)
	else:
		record_reason.add_theme_color_override("font_color", DIM)


func _set_feedback(message: String) -> void:
	# Positive guidance goes through the What To Do slot color flash.
	error_label.text = message
	error_label.add_theme_color_override("font_color", GREEN)


func _set_error(message: String) -> void:
	error_label.text = message
	error_label.add_theme_color_override("font_color", RED)


func _season_visible() -> bool:
	var season := str(level.get("environment", {}).get("season", "all"))
	var seasons: Array = constellation.get("visible_seasons", ["all"])
	return seasons.has("all") or seasons.has(season)


func _aim_locked() -> bool:
	return absf(_wrapped_delta(aim_az, target_az)) <= 2.0 and absf(aim_alt - target_alt) <= 2.0


func _aim_near() -> bool:
	return absf(_wrapped_delta(aim_az, target_az)) <= 8.0 and absf(aim_alt - target_alt) <= 8.0


# ------------------------------------------------------------------ drawing


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("02050d"))
	draw_rect(Rect2(MAP_RECT.position - Vector2(12, 12), MAP_RECT.size + Vector2(24, 24)), Color("07101e"))
	draw_rect(Rect2(MAP_RECT.position - Vector2(12, 12), MAP_RECT.size + Vector2(24, 24)), Color("2f5578"), false, 2.0)
	draw_rect(Rect2(694, 92, 318, 656), Color("07101e"))
	draw_rect(Rect2(694, 92, 318, 656), GOLD, false, 2.0)
	if constellation.is_empty():
		return
	var phase := _phase()

	# Background stars: deliberately dimmer than every key star.
	for i in range(72):
		var seed := float((i * 83 + target_id.hash()) & 1023)
		var p := Vector2(MAP_RECT.position.x + fmod(seed * 1.73, MAP_RECT.size.x), MAP_RECT.position.y + fmod(seed * 2.41, MAP_RECT.size.y))
		draw_circle(p, 0.9 if i % 5 else 1.3, Color(0.50, 0.60, 0.74, 0.30))

	var positions: Array[Vector2] = []
	for star_value in pattern:
		var star: Dictionary = star_value
		positions.append(MAP_RECT.position + Vector2(float(star.get("x", 0.5)), float(star.get("y", 0.5))) * MAP_RECT.size)

	# Faint outline preview: identify phase shows the target silhouette; the
	# connect phase keeps unfinished edges as a dotted route preview.
	var outline_alpha := 0.20 if phase == Phase.IDENTIFY else 0.12
	if phase <= Phase.CONNECT:
		for edge_index in range(ordered_indices.size() - 1):
			var a := int(ordered_indices[edge_index])
			var b := int(ordered_indices[edge_index + 1])
			if edge_index >= maxi(0, completed_edges - 1) and a < positions.size() and b < positions.size():
				_draw_dashed(positions[a], positions[b], Color(GOLD.r, GOLD.g, GOLD.b, outline_alpha))

	# Completed connections in solid gold; the newest edge animates its growth.
	for edge_index in range(maxi(0, completed_edges - 1)):
		var a := int(ordered_indices[edge_index])
		var b := int(ordered_indices[edge_index + 1])
		if a < positions.size() and b < positions.size():
			var to := positions[b]
			if edge_index == completed_edges - 2 and edge_anim < 1.0:
				to = positions[a].lerp(positions[b], edge_anim)
			draw_line(positions[a], to, GOLD, 2.4)

	# Completion flash: whole outline glows once when the pattern closes.
	if complete_flash > 0.0:
		for edge_index in range(ordered_indices.size() - 1):
			var a := int(ordered_indices[edge_index])
			var b := int(ordered_indices[edge_index + 1])
			if a < positions.size() and b < positions.size():
				draw_line(positions[a], positions[b], Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, complete_flash * 0.8), 4.0)

	var next_index := int(ordered_indices[completed_edges]) if phase == Phase.CONNECT else -1
	var font := get_theme_default_font()
	for i in range(positions.size()):
		var star: Dictionary = pattern[i]
		var radius := 3.0 + float(star.get("magnitude", 1.0))
		var order := ordered_indices.find(i)
		var done := order >= 0 and order < maxi(0, completed_edges)
		var color := TEXT
		if done:
			color = GREEN
		elif i == next_index:
			color = GOLD_BRIGHT
		draw_circle(positions[i], radius, color)
		# Key-star numbers appear from the connect phase on.
		if phase >= Phase.CONNECT and order >= 0:
			draw_string(font, positions[i] + Vector2(9, -8), str(order + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD if not done else GREEN)
		# Hover: name/number tag.
		if i == hovered_star:
			var tag := GameManager.text("Key star %d", "关键星 %d") % (order + 1) if order >= 0 else GameManager.text("Field star", "背景星")
			draw_string(font, positions[i] + Vector2(10, 18), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CYAN)

	# Next-star cue: pulsing gold ring + arrow pointing at it.
	if next_index >= 0 and next_index < positions.size():
		var pulse := 10.0 + sin(pointer_phase * 5.0) * 3.0
		draw_arc(positions[next_index], pulse, 0, TAU, 28, GOLD_BRIGHT, 2.2)
		var arrow_from := positions[next_index] + Vector2(0, -34)
		_draw_arrow(arrow_from, positions[next_index] + Vector2(0, -14), GOLD_BRIGHT)

	# Navigate phase: target ring in scrolling-window coordinates + direction
	# arrow from the map center when the target is off-center.
	if phase >= Phase.NAVIGATE:
		var dx := _wrapped_delta(target_az, aim_az) * 8.0
		var dy := (aim_alt - target_alt) * 8.0
		var marker := MAP_RECT.get_center() + Vector2(dx, dy)
		marker.x = clampf(marker.x, MAP_RECT.position.x + 20, MAP_RECT.end.x - 20)
		marker.y = clampf(marker.y, MAP_RECT.position.y + 20, MAP_RECT.end.y - 20)
		var locked := _aim_locked()
		var ring_color := GREEN if locked else (GOLD if _aim_near() else CYAN)
		draw_arc(marker, 18.0 + sin(pointer_phase * 3.0) * 1.5, 0, TAU, 32, ring_color, 2.0)
		for offset in [Vector2(-26, 0), Vector2(26, 0), Vector2(0, -26), Vector2(0, 26)]:
			var v := offset as Vector2
			draw_line(marker + v * 0.34, marker + v, ring_color, 2.0)
		var center := MAP_RECT.get_center()
		if not locked and center.distance_to(marker) > 34.0:
			_draw_arrow(center, center + (marker - center).normalized() * 46.0, ring_color)
		# Center cross reference.
		draw_line(center - Vector2(10, 0), center + Vector2(10, 0), Color(TEXT.r, TEXT.g, TEXT.b, 0.5), 1.0)
		draw_line(center - Vector2(0, 10), center + Vector2(0, 10), Color(TEXT.r, TEXT.g, TEXT.b, 0.5), 1.0)
		draw_string(font, Vector2(MAP_RECT.position.x + 8, MAP_RECT.position.y + 22),
			"Az %.1f°   Alt %.1f°" % [aim_az, aim_alt], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)


func _draw_dashed(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / maxf(length, 0.001)
	var travelled := 0.0
	while travelled < length:
		var segment_end := minf(travelled + 6.0, length)
		draw_line(from + direction * travelled, from + direction * segment_end, color, 1.4)
		travelled += 11.0


func _draw_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 2.0)
	var direction := (to - from).normalized()
	var left := direction.rotated(2.6) * 8.0
	var right := direction.rotated(-2.6) * 8.0
	draw_line(to, to + left, color, 2.0)
	draw_line(to, to + right, color, 2.0)


func _nearest_star(point: Vector2) -> int:
	var best := -1
	var best_distance := 18.0
	for i in range(pattern.size()):
		var star: Dictionary = pattern[i]
		var p := MAP_RECT.position + Vector2(float(star.get("x", 0.5)), float(star.get("y", 0.5))) * MAP_RECT.size
		var distance := point.distance_to(p)
		if distance < best_distance:
			best = i
			best_distance = distance
	return best


func _wrapped_delta(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


func _add_label(value: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(value: String, pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.custom_minimum_size = button_size
	button.size = button_size
	button.add_theme_font_size_override("font_size", 12)
	InteractionFeedback.bind_button(button)
	return button
