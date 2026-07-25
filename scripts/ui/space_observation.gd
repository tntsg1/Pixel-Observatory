extends Control

const SpaceDeploymentVisualScript := preload("res://scripts/ui/space_deployment_visual.gd")
const SpaceGuideFieldScript := preload("res://scripts/ui/space_guide_field.gd")
const SpaceGuideAttitudeDisplayScript := preload("res://scripts/ui/space_guide_attitude_display.gd")
const SpaceWavefrontDisplayScript := preload("res://scripts/ui/space_wavefront_display.gd")

# JWST-class space infrared observation. A staged science pipeline that works in
# photons, filters, attitude, temperature and data frames. It keeps its own
# space_observation state and deliberately borrows none of the ground-optic
# mechanics (no light-bucket viewer, no manual sharpening knob, no alignment
# spider game, no aiming scope).
#
# Stages: Deploy (first-time) -> Plan -> Thermal -> Guide -> Wavefront ->
#         Expose -> Process -> Filter -> Report.

# --- monochrome phosphor palette (no hue: intensity only) ---
const BG := Color("050505")          # tube black
const PANEL := Color("0b0b0b")       # panel well
const P_HOT := Color("ffffff")       # focused / active
const P_BRIGHT := Color("dcdcdc")    # primary text, headings
const P_MID := Color("9a9a9a")       # secondary text, idle borders
const P_DIM := Color("5a5a5a")       # disabled, grid, hints
const P_FAINT := Color("2e2e2e")     # separators
# legacy names kept so every stage re-themes at once
const GOLD := P_HOT
const GOLD_HI := Color("ffffff")
const CYAN := P_MID
const GREEN := P_BRIGHT
const RED := P_HOT
const ORANGE := P_BRIGHT
const TEXT := P_BRIGHT
const MUTED := P_DIM

var model: SpaceObservationModel
var stages: Array = []
var stage := 0
var running := false
var status_label: Label
var content: Control
var readout: Label
var scope: Control
var elapsed := 0.0
var acquiring := false
var deploy_animating := false
var deployment_visual: Control
var attitude_tween: Tween
var thermal_confirm_button: Button
var thermal_refresh_elapsed := 0.0
var guide_candidate := -1
var guide_field: Control
var guide_lock_logged := false
var guide_attitude_display: Control
var guide_acquire_button: Button
var guide_confirm_button: Button
var guide_slew_active := false
var guide_pending_index := -1
var wavefront_animating := false
var wavefront_display: Control
var process_animating := false
var filter_animating := false
var process_tutorial_overlay: Control
var process_tutorial_highlight: Panel
var process_tutorial_copy: Label
var process_tutorial_portrait: TextureRect
var process_tutorial_next_button: Button
var process_tutorial_step := 0
var process_tutorial_steps: Array = []
var process_step_buttons: Dictionary = {}
var process_generate_button: Button
var shutdown_overlay: Control
var shutdown_status_label: Label
var shutdown_phase := ""


func _ready() -> void:
	model = SpaceObservationModel.new()
	model.configure(_profile())
	stages = _stage_list()
	GameManager.language_changed.connect(_rebuild)
	set_process(true)
	_rebuild()
	_boot_animation()


# ---- power-on / power-off tube animation --------------------------------
func _boot_animation() -> void:
	# A CRT does not just appear; it warms up. A bright horizontal scan line
	# sweeps down the black tube, then the picture snaps in.
	var cover := ColorRect.new()
	cover.name = "BootCover"
	cover.color = Color(0, 0, 0, 1)
	cover.position = Vector2.ZERO
	cover.size = Vector2(1024, 768)
	cover.z_index = 380
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	var scan := ColorRect.new()
	scan.color = Color(1, 1, 1, 0.9)
	scan.size = Vector2(1024, 3)
	scan.position = Vector2(0, 383)
	scan.z_index = 381
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)
	_log_line("BOOT SEQUENCE", "RUN")
	# Bind to the cover itself. Stage rebuilds may remove the boot overlay while
	# the terminal scene remains alive; in that case the tween and its captures
	# must stop together instead of calling back with freed cover/scan nodes.
	var tw := create_tween().bind_node(cover)
	tw.tween_property(scan, "position:y", 0.0, 0.10)
	tw.parallel().tween_property(scan, "size:y", 768.0, 0.16)
	tw.parallel().tween_property(cover, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(scan, "modulate:a", 0.0, 0.20)
	tw.tween_callback(func() -> void:
		if is_instance_valid(cover): cover.queue_free()
		if is_instance_valid(scan): scan.queue_free()
		_log_line("DISPLAY", "READY"))


func _power_down(then: Callable, observation_complete := false) -> void:
	if shutdown_overlay != null and is_instance_valid(shutdown_overlay):
		return
	running = true
	var reduced := InteractionFeedback.is_reduced_motion()
	var beat := 0.06 if reduced else 0.22
	_log_line("SCIENCE ARCHIVE" if observation_complete else "SESSION CLOSE", "RUN")

	shutdown_overlay = Control.new()
	shutdown_overlay.name = "SpaceConsoleShutdown"
	shutdown_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	shutdown_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	shutdown_overlay.z_index = 900
	add_child(shutdown_overlay)

	var dim := ColorRect.new()
	dim.name = "ShutdownDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shutdown_overlay.add_child(dim)

	var scan := ColorRect.new()
	scan.name = "ShutdownScan"
	scan.color = Color(0.92, 0.96, 1.0, 0.82)
	scan.position = Vector2(0, 92)
	scan.size = Vector2(1024, 2)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shutdown_overlay.add_child(scan)

	var status_panel := Panel.new()
	status_panel.name = "ShutdownStatusPanel"
	status_panel.position = Vector2(276, 282)
	status_panel.size = Vector2(472, 154)
	status_panel.modulate.a = 0.0
	status_panel.add_theme_stylebox_override(
		"panel", _flat(Color(0.015, 0.025, 0.035, 0.98), Color(0.72, 0.78, 0.82), 2))
	shutdown_overlay.add_child(status_panel)
	_label_to(
		status_panel,
		GameManager.text("OBSERVATION SESSION COMPLETE", "观测会话完成") if observation_complete
			else GameManager.text("CLOSING OBSERVATORY LINK", "正在关闭天文台链路"),
		Vector2(18, 14), Vector2(436, 26), 17, P_HOT, HORIZONTAL_ALIGNMENT_CENTER)
	shutdown_status_label = _label_to(
		status_panel, "", Vector2(24, 50), Vector2(424, 48), 13, P_BRIGHT,
		HORIZONTAL_ALIGNMENT_CENTER)
	shutdown_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var meter_bg := ColorRect.new()
	meter_bg.color = Color(0.08, 0.10, 0.12, 1.0)
	meter_bg.position = Vector2(34, 112)
	meter_bg.size = Vector2(404, 10)
	status_panel.add_child(meter_bg)
	var meter := ColorRect.new()
	meter.name = "ShutdownProgress"
	meter.color = Color(0.78, 0.84, 0.88, 1.0)
	meter.position = Vector2(34, 112)
	meter.size = Vector2(0, 10)
	status_panel.add_child(meter)

	var top_shutter := ColorRect.new()
	top_shutter.name = "ShutdownTopShutter"
	top_shutter.color = Color.BLACK
	top_shutter.position = Vector2(0, 0)
	top_shutter.size = Vector2(1024, 0)
	shutdown_overlay.add_child(top_shutter)
	var bottom_shutter := ColorRect.new()
	bottom_shutter.name = "ShutdownBottomShutter"
	bottom_shutter.color = Color.BLACK
	bottom_shutter.position = Vector2(0, 768)
	bottom_shutter.size = Vector2(1024, 0)
	shutdown_overlay.add_child(bottom_shutter)
	status_panel.move_to_front()

	var tw := create_tween().bind_node(shutdown_overlay)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_set_shutdown_phase.bind(
		"archive",
		GameManager.text("REPORT ARCHIVED  ·  CHECKSUM VERIFIED", "报告已归档  ·  校验完成")))
	tw.tween_property(status_panel, "modulate:a", 1.0, beat * 0.65)
	tw.parallel().tween_property(dim, "color:a", 0.62, beat * 0.9)
	tw.parallel().tween_property(scan, "position:y", 610.0, beat * 1.8)
	tw.tween_property(meter, "size:x", 142.0, beat)
	tw.tween_callback(_set_shutdown_phase.bind(
		"detectors",
		GameManager.text("DETECTORS SAFE  ·  CRYOGENIC HOLD", "探测器已保护  ·  低温系统保持")))
	tw.tween_property(meter, "size:x", 286.0, beat)
	tw.tween_callback(_set_shutdown_phase.bind(
		"link",
		GameManager.text("HIGH-GAIN LINK CLOSED  ·  RETURNING TO CLUB ARCHIVE", "高增益链路已关闭  ·  正在返回社团档案")))
	tw.tween_property(meter, "size:x", 404.0, beat)
	tw.tween_interval(beat * 0.45)
	tw.tween_property(status_panel, "modulate:a", 0.0, beat * 0.55)
	tw.tween_callback(_set_shutdown_phase.bind("collapse", ""))
	tw.tween_property(top_shutter, "size:y", 382.0, beat)
	tw.parallel().tween_property(bottom_shutter, "position:y", 386.0, beat)
	tw.parallel().tween_property(bottom_shutter, "size:y", 382.0, beat)
	tw.tween_property(scan, "position:y", 383.0, beat * 0.35)
	tw.parallel().tween_property(scan, "size:x", 4.0, beat * 0.35)
	tw.parallel().tween_property(scan, "position:x", 510.0, beat * 0.35)
	tw.tween_property(scan, "modulate:a", 0.0, beat * 0.25)
	tw.tween_callback(func() -> void:
		shutdown_phase = "complete"
		then.call())


func _set_shutdown_phase(phase_name: String, message: String) -> void:
	shutdown_phase = phase_name
	if shutdown_status_label != null and is_instance_valid(shutdown_status_label):
		shutdown_status_label.text = message


func _leave_observatory() -> void:
	_power_down(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory"))


func _profile() -> Dictionary:
	var level := GameManager.current_level()
	var prof: Dictionary = (level.get("space_profile", {}) as Dictionary).duplicate(true)
	if prof.is_empty():
		prof = {"target_id": GameManager.current_target_object_id()}
	# Mission number participates in the deterministic guide-field seed. Repeated
	# targets in later lessons still require a fresh search and a different slew.
	prof["guide_seed"] = int(level.get("level_number", GameManager.progress.get("current_level", 1)))
	return prof


# The five JWST teaching cards, shown as a first-time Maya briefing before the
# very first deployment. Content is pulled from data/learning_cards.json so the
# cards stay the single source of truth.
const INTRO_CARDS := ["jwst_infrared_light", "jwst_segmented_mirror", "jwst_sunshield_l2", "jwst_instruments", "jwst_false_colour"]

var intro_page := 0
var intro_why := false
var console_log: Array = []
var console_label: Label
var console_reveal := 1.0
var mission_clock := 0.0
var furthest_stage := 0
const CONSOLE_ROWS := 4
const CRT_SHADER := "res://shaders/crt_monitor.gdshader"


func _stage_list() -> Array:
	# First-ever entry: a Maya teaching briefing, then deployment. Both are
	# first-time only; later visits skip straight to planning.
	var out: Array = []
	if not bool(GameManager.progress.get("space_intro_seen", false)):
		out.append("intro")
	if not bool(GameManager.progress.get("space_deployed", false)):
		out.append("deploy")
	for s in ["plan", "thermal", "guide", "wavefront", "expose", "process", "filter", "report"]:
		out.append(s)
	return out


func _key() -> String:
	return str(stages[stage])


func _process(delta: float) -> void:
	if model == null:
		return
	mission_clock += delta
	if console_reveal < 1.0:
		console_reveal = minf(1.0, console_reveal + delta * 2.6)
		_render_console()
	if _key() == "guide" and model.chosen_guide >= 0 and not model.guide_locked:
		model.step_guiding(delta)
		_refresh_guide()
		if model.guide_locked and not guide_lock_logged:
			guide_lock_logged = true
			_log_line("FGS CLOSED LOOP", "LOCKED", "%.2f ARCSEC" % model.pointing_error)
			_say(GameManager.text(
				"Guide lock acquired. The bite marks have closed and drift is flat.",
				"导星锁定完成。锁定标记已经咬合，漂移曲线已拉平。"), GREEN)
			InteractionFeedback.success(self)
	if _key() == "thermal":
		model.step_thermal(delta)
		thermal_refresh_elapsed += delta
		if thermal_refresh_elapsed >= 0.08:
			thermal_refresh_elapsed = 0.0
			_refresh_thermal()
	if _key() == "expose" and acquiring:
		elapsed += delta
		_refresh_expose()


# ------------------------------------------------------------ shell
func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_label(GameManager.text("SPACE INFRARED OBSERVATORY", "太空红外天文台"), Vector2(24, 14), Vector2(976, 28), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(GameManager.text("Target: ", "目标：") + GameManager.dict_text(GameManager.current_target(), "name")
		+ "   ·   " + GameManager.text("A space science observation, not a point-and-look image.", "这是一次空间科学观测，不是对准就看的简单成像。"),
		Vector2(24, 44), Vector2(976, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	_build_stage_bar()
	content = Control.new()
	content.position = Vector2(0, 110)
	content.size = Vector2(1024, 566)
	add_child(content)
	# telemetry console strip (system-emitted, never typed by the player)
	var console_bg := Panel.new()
	console_bg.position = Vector2(36, 620)
	console_bg.size = Vector2(952, 56)
	console_bg.add_theme_stylebox_override("panel", _flat(Color("040a10"), Color("1d3550"), 1))
	console_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(console_bg)
	console_label = _label_to(console_bg, "", Vector2(12, 3), Vector2(928, 50), 10, GREEN)
	console_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if console_log.is_empty():
		_log_line("SPACECRAFT BUS LINK", "ONLINE")
		_log_line("CRYO SUBSYSTEM", "NOMINAL")
	console_label.text = "> " + "\n> ".join(console_log)

	status_label = _label("", Vector2(36, 686), Vector2(760, 44), 13, MUTED)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var back := _button(GameManager.text("Back", "返回"), Vector2(820, 690), Vector2(170, 40), Color("15233a"))
	back.pressed.connect(_leave_observatory)
	add_child(back)
	_build_stage()
	# Each stage opens with a "what to look at" teaching tip until the player acts.
	if status_label.text == "":
		_say(_stage_tip(), CYAN)
	_add_crt_overlay()


func _stage_tip() -> String:
	match _key():
		"intro": return GameManager.text("First-time briefing. Read each page.", "首次教学，逐页阅读。")
		"deploy": return GameManager.text("Watch the order: solar array, then sunshield, mirrors, hinges, actuators. Wrong order is blocked and explained.", "注意顺序：太阳能板→遮阳罩→镜面→铰链→执行器。乱序会被拦截并说明原因。")
		"plan": return GameManager.text("Pick the instrument and filter that fit THIS target. Each shows what it's good and bad for.", "为当前目标选择合适的仪器和滤镜。每个选项都会说明擅长与不擅长的方面。")
		"thermal": return GameManager.text("The sunshield side must face the Sun. Keep the sun 85-135 deg off boresight so the optics stay cold.", "遮阳罩一侧必须朝向太阳。让太阳保持在视轴 85-135 度，使光学保持低温。")
		"guide": return GameManager.text("A guide star is a steady reference star, not the target. Avoid dim or off-field stars.", "导星是一颗稳定的参考星，不是观测目标本身。避开太暗或偏离视场的星。")
		"wavefront": return GameManager.text("Nudge the 18 segments until the split star images merge into one small, sharp point.", "微调 18 块镜片，直到分裂的星点合并成一个又小又锐的点。")
		"expose": return GameManager.text("Photons build up frame by frame. Too short = weak signal; too long = heat noise and cosmic rays.", "光子逐帧累积。太短信号弱；太长热噪声和宇宙线增多。")
		"process": return GameManager.text("Drop saturated frames, keep repairable cosmic-ray hits, then run steps 1-4 in order. Target SNR is 10.", "剔除饱和帧，保留可修复的宇宙线击中帧，再按顺序完成第 1-4 步。目标信噪比为 10。")
		"filter": return GameManager.text("Map each filter to R/G/B, then read the structure to choose the science interpretation.", "把每个滤镜映射到 R/G/B，再根据结构选择科学解释。")
		"report": return GameManager.text("Review the real numbers, then Submit Report to finish the observation.", "查看真实数据，再点击提交报告完成观测。")
	return ""


func _build_stage_bar() -> void:
	var titles := {
		"intro": GameManager.text("Learn", "教学"),
		"deploy": GameManager.text("Deploy", "部署"), "plan": GameManager.text("Plan", "规划"),
		"thermal": GameManager.text("Thermal", "热控"), "guide": GameManager.text("Guide", "导星"),
		"wavefront": GameManager.text("Align", "对准"), "expose": GameManager.text("Expose", "曝光"),
		"process": GameManager.text("Process", "处理"), "filter": GameManager.text("Filter", "滤镜"),
		"report": GameManager.text("Report", "报告")}
	var holder := Control.new()
	holder.position = Vector2(24, 74)
	add_child(holder)
	var w := 976.0 / float(stages.size())
	for i in range(stages.size()):
		var done := i < stage
		var active := i == stage
		var reachable := i <= furthest_stage
		# Any stage you have already reached can be re-opened to review - the
		# console is a machine you can walk back through, not a one-way corridor.
		var chip := Button.new()
		chip.position = Vector2(i * w, 0)
		chip.size = Vector2(w - 6, 26)
		chip.focus_mode = Control.FOCUS_NONE
		chip.text = str(titles[stages[i]])
		chip.add_theme_font_size_override("font_size", 12)
		var border: Color = GREEN if done else (GOLD if active else Color("2a3f5a"))
		var fill: Color = Color("1c3350") if active else (Color("0e1e16") if done else Color("13233a"))
		chip.add_theme_stylebox_override("normal", _flat(fill, border, 3 if active else 2))
		chip.add_theme_stylebox_override("hover", _flat(fill.lightened(0.10), GOLD_HI if reachable else border, 3 if active else 2))
		chip.add_theme_stylebox_override("pressed", _flat(fill.darkened(0.10), CYAN, 3))
		chip.add_theme_color_override("font_color", GREEN if done else (GOLD if active else MUTED))
		if reachable and not active:
			chip.pressed.connect(_goto_stage.bind(i))
		else:
			chip.disabled = not reachable
			chip.add_theme_stylebox_override("disabled", _flat(fill, border, 2))
			chip.add_theme_color_override("font_disabled_color", MUTED)
		holder.add_child(chip)


func _goto_stage(index: int) -> void:
	# Re-open an already reached stage. Reviewing never rewinds progress: the
	# furthest point stays, so you can jump straight back to where you were.
	if index < 0 or index > furthest_stage:
		return
	stage = index
	_log_line("RECALL %s" % str(stages[index]).to_upper(), "OK")
	_rebuild()


# --------------------------------------------------- CRT tube post-process
func _add_crt_overlay() -> void:
	var shader: Shader = load(CRT_SHADER) as Shader
	if shader == null:
		return
	var glass := ColorRect.new()
	glass.name = "CRTGlass"
	glass.position = Vector2.ZERO
	glass.size = Vector2(1024, 768)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.z_index = 400
	var mat := ShaderMaterial.new()
	mat.shader = shader
	glass.material = mat
	add_child(glass)


func _clear() -> void:
	for c in content.get_children():
		c.queue_free()


func _build_stage() -> void:
	_clear()
	match _key():
		"intro": _build_intro()
		"deploy": _build_deploy()
		"plan": _build_plan()
		"thermal": _build_thermal()
		"guide": _build_guide()
		"wavefront": _build_wavefront()
		"expose": _build_expose()
		"process": _build_process()
		"filter": _build_filter()
		"report": _build_report()


func _advance() -> void:
	if _key() == "intro":
		GameManager.progress["space_intro_seen"] = true
	if _key() == "deploy":
		GameManager.progress["space_deployed"] = true
	stage = mini(stage + 1, stages.size() - 1)
	furthest_stage = maxi(furthest_stage, stage)
	_rebuild()


# ============================================================ INTRO (Maya teaching)
func _build_intro() -> void:
	var total := INTRO_CARDS.size() + 1     # page 0 = Maya, pages 1..5 = cards
	intro_page = clampi(intro_page, 0, total - 1)
	var board := _panel_to(content, Vector2(112, 6), Vector2(800, 456), Color("0b1830"), GOLD, "")
	if intro_page == 0:
		_label_to(board, GameManager.text("Maya - Observatory Club", "玛雅 - 天文社"), Vector2(0, 14), Vector2(800, 28), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_label_to(board, GameManager.text("Why we need a space telescope", "我们为什么需要一台太空望远镜"), Vector2(0, 46), Vector2(800, 24), 15, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
		_intro_diagram(board, "jwst_segmented_mirror")
		var maya := GameManager.text(
			"Our ground telescopes hit a wall: the air blurs and absorbs the faint infrared glow of cold dust and distant galaxies. So we launch this observatory to L2, keep it deep-cold behind a sunshield, and read the sky in infrared. This time you do not look through a lens - we plan, point, expose and process real data. Let's learn the parts first.",
			"我们的地面望远镜遇到了瓶颈：大气会模糊并吸收冷尘埃与遥远星系微弱的红外光。所以我们把这台天文台送到 L2，用遮阳罩保持极低温，在红外波段读取天空。这一次没有目镜——我们要规划、指向、曝光并处理真实数据。先来认识各个部件。")
		_wrap_to(board, maya, Vector2(60, 328), Vector2(680, 110), 14, TEXT)
	else:
		var card: Dictionary = GameManager.get_learning_card(str(INTRO_CARDS[intro_page - 1]))
		_label_to(board, GameManager.dict_text(card, "title"), Vector2(0, 16), Vector2(800, 30), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_intro_diagram(board, str(INTRO_CARDS[intro_page - 1]))
		_wrap_to(board, GameManager.dict_text(card, "text"), Vector2(60, 328), Vector2(680, 70), 14, TEXT)
		if intro_why:
			_wrap_to(board, _intro_why_text(str(INTRO_CARDS[intro_page - 1])), Vector2(60, 402), Vector2(680, 36), 12, CYAN)

	# page dots
	var dots := ""
	for i in range(total):
		dots += ("●" if i == intro_page else "○") + " "
	_label_to(content, dots, Vector2(112, 446), Vector2(800, 20), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# nav: Back / Why / Next-or-Start. Beginner mode: one page at a time.
	if intro_page > 0:
		var prev := _button(GameManager.text("Back", "上一页"), Vector2(180, 466), Vector2(150, 42), Color("143247"))
		prev.pressed.connect(func() -> void: intro_page -= 1; intro_why = false; _build_stage())
		content.add_child(prev)
		var why_btn := _button(GameManager.text("Why?", "为什么？"), Vector2(437, 466), Vector2(150, 42), Color("1c3350"))
		why_btn.pressed.connect(func() -> void: intro_why = not intro_why; _build_stage())
		content.add_child(why_btn)
	if intro_page < total - 1:
		var nxt := _button(GameManager.text("Next", "下一页"), Vector2(694, 466), Vector2(150, 42), Color("175238"))
		nxt.pressed.connect(func() -> void: intro_page += 1; intro_why = false; _build_stage())
		content.add_child(nxt)
	else:
		var start := _button(GameManager.text("Start Deployment", "开始部署"), Vector2(662, 466), Vector2(210, 42), Color("175238"))
		start.pressed.connect(_advance)
		content.add_child(start)
	_say(GameManager.text("First-time briefing - shown only once. Read each page, then deploy.", "首次教学——只播放一次。逐页阅读后开始部署。"), MUTED)


# ============================================================ 3D ATTITUDE GIMBAL
# A real orientable observatory instead of a slider: you grab the sphere and turn
# it. The wireframe globe, the sun vector, the sunshield plane and the boresight
# are all projected 3D->2D by hand, so dragging genuinely re-points the craft.
class AttitudeGimbal extends Control:
	var yaw := 0.0            # drag left/right
	var pitch := -0.35        # drag up/down (view tilt only)
	var sun_angle := 40.0     # the value the model cares about
	var safe_min := 85.0
	var safe_max := 135.0
	var target_angle := 108.0
	var hold_ratio := 0.0
	var dragging := false
	var on_changed: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				dragging = mb.pressed
				accept_event()
		elif event is InputEventMouseMotion and dragging:
			var mm := event as InputEventMouseMotion
			sun_angle = clampf(sun_angle + mm.relative.x * 0.45, 0.0, 180.0)
			pitch = clampf(pitch + mm.relative.y * 0.006, -1.1, 0.35)
			yaw = deg_to_rad((sun_angle - 90.0) * 0.18)
			if on_changed.is_valid():
				on_changed.call(sun_angle)
			queue_redraw()
			accept_event()
		elif event is InputEventScreenDrag:
			var sd := event as InputEventScreenDrag
			sun_angle = clampf(sun_angle + sd.relative.x * 0.45, 0.0, 180.0)
			pitch = clampf(pitch + sd.relative.y * 0.006, -1.1, 0.35)
			yaw = deg_to_rad((sun_angle - 90.0) * 0.18)
			if on_changed.is_valid():
				on_changed.call(sun_angle)
			queue_redraw()
			accept_event()
		elif event is InputEventScreenTouch:
			dragging = (event as InputEventScreenTouch).pressed
			accept_event()

	func _project(v: Vector3) -> Vector2:
		# rotate by yaw/pitch, then a simple perspective divide
		var cy := cos(yaw); var sy := sin(yaw)
		var p := Vector3(v.x * cy + v.z * sy, v.y, -v.x * sy + v.z * cy)
		var cp := cos(pitch); var sp := sin(pitch)
		p = Vector3(p.x, p.y * cp - p.z * sp, p.y * sp + p.z * cp)
		var d := 4.0
		var f := d / (d + p.z)
		return Vector2(size.x * 0.5 + p.x * size.x * 0.36 * f,
			size.y * 0.5 - p.y * size.y * 0.36 * f)

	func _safe() -> bool:
		return sun_angle >= safe_min and sun_angle <= safe_max

	func _draw() -> void:
		# phosphor intensities, not hues: brightest = the thing you control
		var green := Color(0.86, 0.86, 0.86)   # boresight
		var dim := Color(0.30, 0.30, 0.30)     # globe wireframe
		var gold := Color(1.00, 1.00, 1.00)    # sun vector (hottest)
		var red := Color(0.62, 0.62, 0.62)     # unsafe cone reads as dull, not red
		# wireframe globe: latitude rings + longitude meridians
		for lat in range(-60, 90, 30):
			var pts: PackedVector2Array = []
			for k in range(37):
				var a := TAU * float(k) / 36.0
				var r := cos(deg_to_rad(float(lat)))
				pts.append(_project(Vector3(cos(a) * r, sin(deg_to_rad(float(lat))), sin(a) * r)))
			draw_polyline(pts, dim, 1.0)
		for lon in range(0, 180, 30):
			var pts2: PackedVector2Array = []
			for k in range(37):
				var a2 := TAU * float(k) / 36.0
				var lr := deg_to_rad(float(lon))
				pts2.append(_project(Vector3(cos(a2) * cos(lr), sin(a2), cos(a2) * sin(lr))))
			draw_polyline(pts2, dim, 1.0)
		# the safe cone the sun must stay inside
		var safe_col := green if _safe() else red
		for edge in [safe_min, safe_max]:
			var pts3: PackedVector2Array = []
			for k in range(37):
				var a3 := TAU * float(k) / 36.0
				var e := deg_to_rad(edge)
				pts3.append(_project(Vector3(cos(e), sin(e) * cos(a3), sin(e) * sin(a3))))
			draw_polyline(pts3, safe_col * Color(1, 1, 1, 0.85), 2.0)
		# The target marker changes for every observation. It is the roll solution
		# the player is trying to bring the Sun vector onto, not a fixed answer.
		var target_radians := deg_to_rad(target_angle)
		var target_v := Vector3(cos(target_radians), sin(target_radians), 0.0)
		var target_pos := _project(target_v * 1.7)
		var target_col := Color(0.62, 0.90, 1.0, 0.78 + hold_ratio * 0.22)
		draw_arc(target_pos, 14.0 + hold_ratio * 4.0, 0.0, TAU, 28, target_col, 2.0)
		draw_line(target_pos + Vector2(-20, 0), target_pos + Vector2(-8, 0), target_col, 2.0)
		draw_line(target_pos + Vector2(8, 0), target_pos + Vector2(20, 0), target_col, 2.0)
		# boresight (where the telescope looks) - always +X
		var o := _project(Vector3.ZERO)
		draw_line(o, _project(Vector3(1.45, 0, 0)), green, 3.0)
		draw_circle(_project(Vector3(1.45, 0, 0)), 5.0, green)
		# sun vector at the chosen angle
		var sa := deg_to_rad(sun_angle)
		var sun_v := Vector3(cos(sa), sin(sa), 0.0)
		draw_line(o, _project(sun_v * 1.7), gold, 3.0)
		draw_circle(_project(sun_v * 1.7), 9.0, gold)
		# sunshield plane: a quad normal to the sun, between sun and optics
		var shield_n := sun_v
		var up := Vector3(0, 0, 1)
		var side := shield_n.cross(up).normalized()
		var base := shield_n * 0.55
		var quad := PackedVector2Array([
			_project(base + side * 0.85 + up * 0.45),
			_project(base - side * 0.85 + up * 0.45),
			_project(base - side * 0.85 - up * 0.45),
			_project(base + side * 0.85 - up * 0.45)])
		draw_colored_polygon(quad, (safe_col if _safe() else red) * Color(1, 1, 1, 0.22))
		draw_polyline(quad + PackedVector2Array([quad[0]]), safe_col, 2.0)


# ============================================================ SCIENCE IMAGE
# Draws the ACTUAL target, never a stand-in disc or a field of random dots.
# `detail` 0..1 drives how much structure has emerged (exposure + processing);
# `tint` comes from the false-colour channel mapping.
func _draw_target_image(parent: Control, rect: Rect2, detail: float, tint: Color = Color(1, 1, 1), cosmic: bool = false, ghost: bool = false) -> void:
	var d := clampf(detail, 0.0, 1.0)
	var cx := rect.position.x + rect.size.x * 0.5
	var cy := rect.position.y + rect.size.y * 0.5
	_rect_to(parent, rect.position, rect.size, Color("04080f"))
	var science_image_path := str(_profile().get("science_image_path", ""))
	if science_image_path != "" and ResourceLoader.exists(science_image_path):
		# Dedicated infrared targets use their own science frame. Exposure and
		# processing still control how much of that frame is visible; the art is
		# not a renamed optical stand-in.
		var image_rect := TextureRect.new()
		image_rect.name = "InfraredScienceTarget"
		image_rect.custom_minimum_size = Vector2.ZERO
		image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image_rect.texture = load(science_image_path)
		image_rect.position = rect.position
		image_rect.size = rect.size
		var reveal := lerpf(0.16, 1.0, d)
		image_rect.modulate = Color(reveal, reveal, reveal, lerpf(0.38, 1.0, d))
		image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(image_rect)
		if d < 0.92:
			_rect_to(parent, rect.position, rect.size, Color(0.01, 0.015, 0.025, (1.0 - d) * 0.58))
		if ghost:
			var ghost_rect := TextureRect.new()
			ghost_rect.custom_minimum_size = Vector2.ZERO
			ghost_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ghost_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			ghost_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ghost_rect.texture = image_rect.texture
			ghost_rect.position = rect.position + Vector2(10, 6)
			ghost_rect.size = rect.size
			ghost_rect.modulate = Color(0.45, 0.70, 1.0, 0.16)
			ghost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(ghost_rect)
		if cosmic:
			_line_to(parent, Vector2(rect.position.x + 18, rect.position.y + 20),
				Vector2(rect.end.x - 26, rect.end.y - 34), Color(1, 1, 1, 0.92))
		return
	# faint background field stars (always sparse, never the subject)
	var rnd := 1237
	for i in range(46):
		rnd = (rnd * 1103515245 + 12345) & 0x7fffffff
		var sx := rect.position.x + float(rnd % int(rect.size.x))
		rnd = (rnd * 1103515245 + 12345) & 0x7fffffff
		var sy := rect.position.y + float(rnd % int(rect.size.y))
		var sa := 0.18 + 0.5 * d
		_rect_to(parent, Vector2(sx, sy), Vector2(2, 2), Color(0.75, 0.82, 0.95, sa))

	match model.target_kind:
		"nebula", "star_forming":
			# emission nebula: irregular glowing cloud + embedded young stars
			for i in range(11):
				var t := float(i) / 10.0
				var rr := lerpf(rect.size.x * 0.42, rect.size.x * 0.06, t)
				var a := (0.05 + 0.30 * d) * (0.35 + t * 0.9)
				var col := Color(tint.r * (0.55 + 0.45 * t), tint.g * (0.35 + 0.5 * t), tint.b * (0.30 + 0.35 * t), a)
				_ellipse_to(parent, Vector2(cx - rr * 0.10, cy + rr * 0.06), Vector2(rr, rr * 0.72), col)
			for k in range(6):
				var ang := float(k) * 1.05
				var p := Vector2(cx + cos(ang) * rect.size.x * 0.17, cy + sin(ang) * rect.size.y * 0.15)
				_rect_to(parent, p, Vector2(3, 3), Color(1, 0.95, 0.85, 0.35 + 0.6 * d))
		"star":
			# a bright cool giant: point core + extended halo, no disc/crescent
			for i in range(9):
				var t2 := float(i) / 8.0
				var rr2 := lerpf(rect.size.x * 0.20, 3.0, t2)
				var a2 := (0.06 + 0.34 * d) * (0.25 + t2)
				_ellipse_to(parent, Vector2(cx, cy), Vector2(rr2, rr2), Color(tint.r, tint.g * 0.72, tint.b * 0.5, a2))
			_rect_to(parent, Vector2(cx - 2, cy - 2), Vector2(4, 4), Color(1, 0.94, 0.82, 0.5 + 0.5 * d))
		_:
			# GALAXY (Andromeda-class): inclined disc + bright core + dust lane
			var rx := rect.size.x * 0.40
			var ry := rx * 0.34
			for i in range(12):
				var t3 := float(i) / 11.0
				var a3 := (0.04 + 0.26 * d) * (0.30 + t3 * 1.1)
				var col3 := Color(tint.r * (0.52 + 0.48 * t3), tint.g * (0.48 + 0.42 * t3), tint.b * (0.55 + 0.30 * t3), a3)
				_ellipse_to(parent, Vector2(cx, cy), Vector2(lerpf(rx, rx * 0.10, t3), lerpf(ry, ry * 0.10, t3)), col3)
			# dust lane across the disc (only resolves once detail is high)
			if d > 0.35:
				var da := (d - 0.35) * 0.7
				_ellipse_to(parent, Vector2(cx - rx * 0.10, cy + ry * 0.22), Vector2(rx * 0.86, ry * 0.16), Color(0.05, 0.03, 0.04, da))
			# bright nucleus
			_ellipse_to(parent, Vector2(cx, cy), Vector2(rx * 0.13, ry * 0.30), Color(1.0, 0.95, 0.86, 0.35 + 0.6 * d))
	if ghost:
		# mis-registered frames show a doubled image until they are aligned
		_ellipse_to(parent, Vector2(cx + 12, cy + 8), Vector2(rect.size.x * 0.30, rect.size.y * 0.14), Color(0.8, 0.6, 0.5, 0.20))
	if cosmic:
		_line_to(parent, Vector2(rect.position.x + 18, rect.position.y + 20),
			Vector2(rect.end.x - 26, rect.end.y - 34), Color(1, 1, 1, 0.92))


func _ellipse_to(parent: Control, center: Vector2, radii: Vector2, color: Color) -> void:
	# filled ellipse approximated with horizontal spans (no textures needed)
	var steps := 22
	for i in range(steps):
		var t := (float(i) / float(steps - 1)) * 2.0 - 1.0
		var w := radii.x * sqrt(maxf(0.0, 1.0 - t * t))
		var y := center.y + t * radii.y
		if w <= 0.5:
			continue
		_rect_to(parent, Vector2(center.x - w, y), Vector2(w * 2.0, maxf(2.0, radii.y * 2.0 / float(steps) + 1.0)), color)


func _wrap_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	# Property ORDER matters for wrapping: autowrap_mode must be set BEFORE .text,
	# or a long CJK string caches an unwrapped width and overflows the panel.
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2.ZERO
	label.text = value
	label.position = pos
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _intro_diagram(board: Control, card_id: String) -> void:
	var card: Dictionary = GameManager.get_learning_card(card_id)
	var path := str(card.get("image", ""))
	var frame := _rect_to(board, Vector2(60, 78), Vector2(680, 240), Color("06101c"))
	if path != "" and ResourceLoader.exists(path):
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2.ZERO
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.texture = load(path)
		tex.position = Vector2(60, 78)
		tex.size = Vector2(680, 240)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(tex)


func _intro_why_text(card_id: String) -> String:
	match card_id:
		"jwst_infrared_light": return GameManager.text("Why it matters in play: the filter you pick decides which structure your image reveals.", "在游戏中的意义：你选的滤镜决定图像能显现哪种结构。")
		"jwst_segmented_mirror": return GameManager.text("Why it matters in play: you align the 18 segments until the split star images merge into one.", "在游戏中的意义：你要校准 18 块镜片，直到分裂的星点合并成一个。")
		"jwst_sunshield_l2": return GameManager.text("Why it matters in play: keep the sun in the safe zone or the cold side warms and noise rises.", "在游戏中的意义：让太阳保持在安全区，否则冷侧升温、噪声上升。")
		"jwst_instruments": return GameManager.text("Why it matters in play: the wrong instrument for the target lowers your final SNR.", "在游戏中的意义：仪器选错会降低最终信噪比。")
		"jwst_false_colour": return GameManager.text("Why it matters in play: you map filters to R/G/B, then read the science from the colours.", "在游戏中的意义：你把滤镜映射到 RGB，再从颜色读出科学结论。")
	return ""


func _say(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


# Spacecraft telemetry log. The player never types anything: every real action
# makes the console report back the way flight software does - a mission clock,
# a dotted leader out to a value, and a status word. That readback is what makes
# a single button press feel like commanding hardware.
func _log_line(label: String, status: String = "", value: String = "") -> void:
	var clock := "T+%02d:%02d" % [int(mission_clock) / 60, int(mission_clock) % 60]
	var body := label
	if value != "":
		body += " " + value
	# pad with dot leaders out to a fixed column so the log lines up like a printout
	var target_len := 46
	var dots := ""
	var pad := target_len - body.length()
	for _i in range(maxi(2, pad)):
		dots += "."
	var line := "%s  %s %s %s" % [clock, body, dots, status]
	console_log.append(line.strip_edges(false, true))
	while console_log.size() > CONSOLE_ROWS:
		console_log.pop_front()
	console_reveal = 0.0
	_render_console()


func _log(line: String) -> void:
	_log_line(line, "OK")


func _render_console() -> void:
	if console_label == null or not is_instance_valid(console_label):
		return
	# typewriter: only the newest line is revealed character by character
	var out: Array = []
	for i in range(console_log.size()):
		var raw := str(console_log[i])
		if i == console_log.size() - 1:
			var shown := int(clampf(console_reveal, 0.0, 1.0) * float(raw.length()))
			out.append(raw.substr(0, shown) + ("_" if shown < raw.length() else ""))
		else:
			out.append(raw)
	console_label.text = "\n".join(out)


# ============================================================ DEPLOY
func _build_deploy() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("OBSERVATORY DEPLOYMENT", "天文台部署"))
	deployment_visual = SpaceDeploymentVisualScript.new()
	deployment_visual.name = "DeploymentVisual"
	deployment_visual.position = Vector2(40, 8)
	deployment_visual.size = Vector2(600, 500)
	deployment_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deployment_visual.set_state(model.deployed)
	content.add_child(deployment_visual)
	scope = deployment_visual
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("DEPLOY SEQUENCE", "部署顺序"))
	_label_to(pad, GameManager.text("Deploy in order. Each stage must latch before the next.", "按顺序部署。每一步锁定后才能进行下一步。"),
		Vector2(16, 40), Vector2(284, 44), 12, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var names := {"solar_array": GameManager.text("1. Solar Array", "1. 太阳能板"),
		"sunshield": GameManager.text("2. Sunshield (5 layers)", "2. 遮阳罩（五层）"),
		"primary_mirror": GameManager.text("3. Primary Mirror Wings", "3. 主镜镜翼"),
		"secondary_mirror": GameManager.text("4. Secondary Mirror", "4. 副镜"),
		"hinges": GameManager.text("5. Latch Hinges", "5. 锁定铰链"),
		"actuators": GameManager.text("6. Start Actuators", "6. 启动执行器")}
	var y := 96.0
	for step in model.DEPLOY_ORDER:
		var b := _button(str(names[step]), Vector2(16, y), Vector2(284, 40), Color("143247"))
		if model.deployed.has(step):
			b.text = "✓ " + b.text
			b.disabled = true
			b.add_theme_stylebox_override("disabled", _flat(Color("0d2a1c"), GREEN, 2))
		b.pressed.connect(_try_deploy.bind(step))
		pad.add_child(b)
		y += 50.0
	if model.fully_deployed():
		var go := _button(GameManager.text("Deployment Complete - Continue", "部署完成——继续"), Vector2(16, 440), Vector2(284, 44), Color("175238"))
		go.pressed.connect(_advance)
		pad.add_child(go)


func _try_deploy(step: String) -> void:
	if deploy_animating:
		return
	var before := model.deployed.duplicate()
	if model.deploy(step):
		deploy_animating = true
		_log_line("DEPLOY %s" % step.to_upper(), "MOVING")
		_say(GameManager.text(
			"%s is moving. Wait for the latch confirmation." % step,
			"%s 正在展开，请等待锁定确认。" % step), CYAN)
		if deployment_visual != null and is_instance_valid(deployment_visual):
			deployment_visual.play_step(step, before, func() -> void:
				deploy_animating = false
				_log_line("LATCH %s" % step.to_upper(), "CONFIRMED")
				_say(GameManager.text("%s deployed and latched." % step, "%s 已展开并锁定。" % step), GREEN)
				_build_stage())
		else:
			deploy_animating = false
			_build_stage()
	else:
		var reason := model.deploy_blocked_reason(step)
		_say(GameManager.text("Cannot deploy yet - finish the earlier stage first (%s)." % reason,
			"还不能部署——请先完成前一步（%s）。" % reason), RED)
		InteractionFeedback.error(self)


func _draw_deploy() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# folded -> unfolded observatory schematic tied to deployment progress
	var cx := 300.0
	# sunshield layers grow as deployed
	if model.deployed.has("sunshield"):
		for i in range(5):
			var wdt := 200.0 - i * 12.0
			_rect_to(scope, Vector2(cx - wdt, 360 + i * 12), Vector2(wdt * 2, 8), lerp_color(ORANGE, Color("2a3f5a"), i / 4.0))
	elif model.deployed.has("solar_array"):
		_rect_to(scope, Vector2(cx - 60, 400), Vector2(120, 10), Color("2a3f5a"))
	# solar array wing
	if model.deployed.has("solar_array"):
		_rect_to(scope, Vector2(cx - 250, 420), Vector2(120, 40), Color("2c4a8a"))
	# primary mirror hex array (grows when deployed)
	if model.deployed.has("primary_mirror"):
		_hexes(scope, Vector2(cx, 220), 22, true)
	else:
		_hexes(scope, Vector2(cx, 220), 14, false)
	if model.deployed.has("secondary_mirror"):
		_ring_to(scope, Vector2(cx, 120), 16, CYAN)
		_line_to(scope, Vector2(cx - 60, 150), Vector2(cx, 120), CYAN)
		_line_to(scope, Vector2(cx + 60, 150), Vector2(cx, 120), CYAN)
	_label_to(scope, "%d / %d" % [model.deployed.size(), model.DEPLOY_ORDER.size()], Vector2(0, 470), Vector2(600, 24), 14,
		GREEN if model.fully_deployed() else CYAN, HORIZONTAL_ALIGNMENT_CENTER)


# ============================================================ PLAN
func _build_plan() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(944, 500), PANEL, GOLD, GameManager.text("OBSERVATION PLANNING", "观测规划"))
	_choice_row(GameManager.text("Instrument", "科学仪器"), model.INSTRUMENTS, model.instrument, Vector2(60, 56), "instrument")
	_choice_row(GameManager.text("Infrared Filter", "红外滤镜"), model.FILTERS, model.filter, Vector2(60, 150), "filter")
	_choice_row(GameManager.text("Dither Pattern", "抖动模式"), model.DITHERS, model.dither, Vector2(60, 244), "dither")
	# exposure + integrations
	_slider_row(GameManager.text("Exposure time (s)", "曝光时间 (s)"), Vector2(60, 336), 60.0, 900.0, model.exposure_time,
		func(v: float) -> void: model.exposure_time = v; _refresh_plan())
	_int_row(GameManager.text("Integrations (frames)", "积分次数（帧）"), Vector2(520, 336), 1, 8, model.integrations,
		func(v: int) -> void: model.integrations = v; _refresh_plan())
	readout = _label_to(content, "", Vector2(60, 404), Vector2(720, 60), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var go := _button(GameManager.text("Confirm Plan", "确认规划"), Vector2(760, 452), Vector2(200, 44), Color("175238"))
	go.pressed.connect(_confirm_plan)
	content.add_child(go)
	_refresh_plan()


func _choice_row(title: String, options: Array, current: String, pos: Vector2, field: String) -> void:
	_label_to(content, title, pos, Vector2(220, 22), 14, GOLD)
	# Teach the choice: the option that best fits THIS target is marked, so a
	# first-timer is never left guessing which one to press.
	var best := ""
	if field == "instrument":
		best = model.best_instrument
	elif field == "filter":
		best = model.best_filter
	if best != "":
		_label_to(content, GameManager.text("▸ best for this target: %s" % _opt_label(field, best), "▸ 本目标推荐：%s" % _opt_label(field, best)),
			pos + Vector2(0, 22), Vector2(220, 18), 11, P_MID)
	var x := pos.x + 220.0
	for opt in options:
		var selected := str(opt) == current
		var recommended := str(opt) == best
		var b := _button(("★ " if recommended else "") + _opt_label(field, str(opt)), Vector2(x, pos.y - 4), Vector2(128, 56), Color("122234"))
		b.add_theme_font_size_override("font_size", 11)
		# selected = inverted white; recommended-but-unselected = bright dashed hint
		if selected:
			b.add_theme_stylebox_override("normal", _flat(P_BRIGHT, P_HOT, 3))
			b.add_theme_color_override("font_color", BG)
		elif recommended:
			b.add_theme_stylebox_override("normal", _flat(Color("161616"), P_BRIGHT, 2))
			b.add_theme_color_override("font_color", P_HOT)
		if field == "instrument":
			var block_reason := GameManager.space_instrument_block_reason(str(opt))
			b.disabled = block_reason != ""
			b.tooltip_text = block_reason
		b.pressed.connect(func() -> void: _set_plan(field, str(opt)))
		content.add_child(b)
		x += 136.0


func _opt_label(field: String, opt: String) -> String:
	var en := {
		"nircam": "NIRCam", "nirspec": "NIRSpec", "miri": "MIRI", "fgs_niriss": "FGS/NIRISS",
		"near_infrared": "Near IR", "mid_infrared": "Mid IR", "dust": "Dust", "star_forming": "Star-forming", "emission_line": "Emission",
		"none": "None", "two_point": "Two-point", "three_point": "Three-point", "box": "Box"}
	var zh := {
		"nircam": "NIRCam", "nirspec": "NIRSpec", "miri": "MIRI", "fgs_niriss": "FGS/NIRISS",
		"near_infrared": "近红外", "mid_infrared": "中红外", "dust": "尘埃", "star_forming": "恒星形成", "emission_line": "发射线",
		"none": "无", "two_point": "两点", "three_point": "三点", "box": "方框"}
	return GameManager.text(str(en.get(opt, opt.capitalize())), str(zh.get(opt, opt)))


func _set_plan(field: String, value: String) -> void:
	match field:
		"instrument": model.instrument = value
		"filter": model.filter = value
		"dither": model.dither = value
	# console SET line + a clear "you chose X" readout, so a click is never silent
	var field_up: String = {"instrument": "INSTRUMENT", "filter": "FILTER", "dither": "DITHER"}.get(field, field.to_upper())
	_log_line("SET %s = %s" % [field_up, value.to_upper()], "OK")
	_build_stage()
	var label: String = {"instrument": GameManager.text("Instrument", "仪器"), "filter": GameManager.text("Filter", "滤镜"), "dither": GameManager.text("Dither", "抖动")}.get(field, field)
	_say(GameManager.text("▸ Selected %s: %s" % [label, _opt_label(field, value)], "▸ 已选择%s：%s" % [label, _opt_label(field, value)]), P_HOT)


func _refresh_plan() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var ih: Dictionary = model.plan_hint("instrument", model.instrument)
	var fh: Dictionary = model.plan_hint("filter", model.filter)
	var zh := GameManager.language_mode == "zh"
	var isuits: String = ih["suits_zh"] if zh else ih["suits_en"]
	var ienh: String = ih["enhances_zh"] if zh else ih["enhances_en"]
	var isac: String = ih["sacrifices_zh"] if zh else ih["sacrifices_en"]
	var fsuits: String = fh["suits_zh"] if zh else fh["suits_en"]
	var warn := ""
	if model.saturates():
		warn = GameManager.text("  WARNING: long exposure will saturate this bright target.", "  警告：过长曝光会使这个亮目标过曝。")
	elif model.underexposed():
		warn = GameManager.text("  WARNING: too little total exposure - signal will be weak.", "  警告：总曝光太少——信号会很弱。")
	readout.text = GameManager.text(
		"Instrument suits: %s (enhances %s, sacrifices %s).\nFilter suits: %s.  Total exposure %.0f s over %d frames.%s" % [
			isuits, ienh, isac, fsuits, model.planned_total_time(), model.integrations, warn],
		"仪器适合：%s（增强%s，牺牲%s）。\n滤镜适合：%s。总曝光 %.0f 秒，共 %d 帧。%s" % [
			isuits, ienh, isac, fsuits, model.planned_total_time(), model.integrations, warn])
	readout.add_theme_color_override("font_color", ORANGE if (model.saturates() or model.underexposed()) else TEXT)


func _confirm_plan() -> void:
	if not GameManager.space_instrument_is_installed(model.instrument):
		var block_reason := GameManager.space_instrument_block_reason(model.instrument)
		_say(block_reason, RED)
		InteractionFeedback.error(self)
		return
	if model.underexposed():
		_say(GameManager.text("Total exposure too low. Raise exposure time or integrations.", "总曝光太低。请提高曝光时间或积分次数。"), RED)
		InteractionFeedback.error(self)
		return
	_say(GameManager.text("Plan set. Check the thermal safety next.", "规划已设定。下一步检查热安全。"), GREEN)
	_advance()


# ============================================================ THERMAL
func _build_thermal() -> void:
	thermal_refresh_elapsed = 0.0
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("THERMAL & SAFE ATTITUDE", "热控与安全姿态"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 500)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("ATTITUDE CONTROL", "姿态控制"))
	readout = _label_to(pad, "", Vector2(16, 42), Vector2(284, 146), 11, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# 3D gimbal: grab the globe and turn the observatory. Replaces the slider so
	# the player is orienting a spacecraft, not scrubbing a value.
	_label_to(pad, GameManager.text("Drag to slew; use fine trim near the marker", "拖动进行转向，接近标记后使用微调"), Vector2(16, 188), Vector2(284, 20), 11, GOLD)
	var gimbal := AttitudeGimbal.new()
	gimbal.name = "AttitudeGimbal"
	gimbal.position = Vector2(22, 206)
	gimbal.size = Vector2(272, 188)
	gimbal.sun_angle = model.attitude_deg
	gimbal.safe_min = model.thermal_corridor_min()
	gimbal.safe_max = model.thermal_corridor_max()
	gimbal.target_angle = model.thermal_target_deg
	gimbal.hold_ratio = model.thermal_hold_ratio()
	gimbal.on_changed = func(v: float) -> void:
		model.rotate_to(v)
		_refresh_thermal()
	pad.add_child(gimbal)
	# Coarse buttons cover large slews; fine buttons make the final roll solution
	# readable and controllable on both mouse and touch.
	var adjustments := [
		[-10.0, "-10°", "AttitudeCoarseMinus"],
		[-2.0, "-2°", "AttitudeFineMinus"],
		[2.0, "+2°", "AttitudeFinePlus"],
		[10.0, "+10°", "AttitudeCoarsePlus"],
	]
	for index in range(adjustments.size()):
		var adjustment: Array = adjustments[index]
		var amount := float(adjustment[0])
		var rotate_button := _button(str(adjustment[1]), Vector2(16 + index * 69, 402), Vector2(64, 38), Color("143247"))
		rotate_button.name = str(adjustment[2])
		rotate_button.tooltip_text = GameManager.text(
			"Coarse slew" if absf(amount) >= 10.0 else "Fine attitude trim",
			"粗调转向" if absf(amount) >= 10.0 else "姿态微调"
		)
		rotate_button.pressed.connect(func() -> void: _animate_attitude_to(model.attitude_deg + amount))
		pad.add_child(rotate_button)
	var go := _button(GameManager.text("Confirm Safe Attitude", "确认安全姿态"), Vector2(16, 456), Vector2(284, 40), Color("175238"))
	go.name = "ConfirmThermalLock"
	go.pressed.connect(_confirm_thermal)
	pad.add_child(go)
	thermal_confirm_button = go
	_refresh_thermal()
	call_deferred("_show_thermal_tutorial", gimbal)


func _show_thermal_tutorial(gimbal: Control) -> void:
	if gimbal == null or not is_instance_valid(gimbal):
		return
	InteractionFeedback.tutorial_highlight_once(
		gimbal,
		"first_space_thermal_attitude",
		GameManager.text(
			"Maya: Every target needs a new spacecraft roll. Drag the globe for a large slew, use ±2° for fine trim, then keep the Sun marker inside this target's corridor while the cold side stabilizes.",
			"玛雅：每个目标都需要重新调整航天器滚转姿态。拖动球体进行大幅转向，用 ±2° 微调，再让太阳标记保持在本目标的安全走廊内，直到冷端稳定。"
		),
		self
	)


func _animate_attitude_to(requested: float) -> void:
	var target := clampf(requested, 0.0, 180.0)
	if attitude_tween != null and attitude_tween.is_valid():
		attitude_tween.kill()
	_log_line("GIMBAL SLEW", "RUN", "%.0f -> %.0f DEG" % [model.attitude_deg, target])
	attitude_tween = create_tween().bind_node(self)
	attitude_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attitude_tween.tween_method(func(value: float) -> void:
		model.rotate_to(value)
		_refresh_thermal(), model.attitude_deg, target, 0.34)
	attitude_tween.tween_callback(func() -> void:
		_log_line("GIMBAL SLEW", "HOLD", "%.0f DEG" % model.attitude_deg))


func _refresh_thermal() -> void:
	# keep the 3D gimbal in step with the model no matter what moved it
	var g := content.find_child("AttitudeGimbal", true, false) if content != null else null
	if g != null and is_instance_valid(g):
		g.set("sun_angle", model.attitude_deg)
		g.set("safe_min", model.thermal_corridor_min())
		g.set("safe_max", model.thermal_corridor_max())
		g.set("target_angle", model.thermal_target_deg)
		g.set("hold_ratio", model.thermal_hold_ratio())
		g.queue_redraw()
	if readout == null or not is_instance_valid(readout):
		return
	var signed_error := model.thermal_target_deg - model.attitude_deg
	var direction_en := "increase" if signed_error > 0.0 else "decrease"
	var direction_zh := "增加" if signed_error > 0.0 else "降低"
	readout.text = GameManager.text(
		"Sun %.1f deg  %s\nTarget %.0f deg  corridor %.0f-%.0f\n%s %.1f deg  drift %+.2f deg/s\nEarth %.0f deg  Moon %.0f deg\nCold %.1f K  Hot %.0f K\nThermal lock %.1f / %.1f s" % [
			model.sun_angle, "GLOBAL SAFE" if model.sun_safe() else "DANGER",
			model.thermal_target_deg, model.thermal_corridor_min(), model.thermal_corridor_max(),
			direction_en.capitalize(), absf(signed_error), model.thermal_drift_rate,
			model.earth_angle, model.moon_angle, model.cold_side_temp, model.hot_side_temp,
			model.thermal_hold_progress, model.thermal_hold_required],
		"太阳 %.1f°  %s\n目标姿态 %.0f°  走廊 %.0f-%.0f°\n需%s %.1f°  漂移 %+.2f°/秒\n地球 %.0f°  月球 %.0f°\n冷端 %.1f K  热端 %.0f K\n热稳定 %.1f / %.1f 秒" % [
			model.sun_angle, "全局安全" if model.sun_safe() else "危险",
			model.thermal_target_deg, model.thermal_corridor_min(), model.thermal_corridor_max(),
			direction_zh, absf(signed_error), model.thermal_drift_rate,
			model.earth_angle, model.moon_angle, model.cold_side_temp, model.hot_side_temp,
			model.thermal_hold_progress, model.thermal_hold_required])
	readout.add_theme_color_override(
		"font_color",
		GREEN if model.thermal_locked else (CYAN if model.attitude_in_corridor() else RED)
	)
	if thermal_confirm_button != null and is_instance_valid(thermal_confirm_button):
		thermal_confirm_button.text = GameManager.text(
			"Attitude Locked - Continue" if model.thermal_locked else "Hold Thermal Lock %.1fs" % maxf(0.0, model.thermal_hold_required - model.thermal_hold_progress),
			"姿态已锁定 - 继续" if model.thermal_locked else "保持热稳定 %.1f 秒" % maxf(0.0, model.thermal_hold_required - model.thermal_hold_progress)
		)
	_draw_thermal()


func _draw_thermal() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var cx := 300.0
	var cy := 240.0
	# sunshield line, hot side (sun) vs cold side (mirror)
	var ang := deg_to_rad(model.attitude_deg)
	var sun := Vector2(cx - cos(ang) * 180.0, cy - sin(ang) * 120.0)
	_line_to(scope, sun, Vector2(cx, cy), Color("f2c14a"))
	_ring_to(scope, sun, 20, Color("f2c14a"))
	_label_to(scope, GameManager.text("Sun", "太阳"), sun + Vector2(-20, 24), Vector2(40, 16), 11, Color("f2c14a"), HORIZONTAL_ALIGNMENT_CENTER)
	var target_ang := deg_to_rad(model.thermal_target_deg)
	var target_marker := Vector2(cx - cos(target_ang) * 180.0, cy - sin(target_ang) * 120.0)
	_ring_to(scope, target_marker, 13.0 + model.thermal_hold_ratio() * 5.0, CYAN)
	_label_to(scope, GameManager.text("ROLL TARGET", "姿态目标"), target_marker + Vector2(-48, -31), Vector2(96, 18), 10, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	# observatory: hot side toward sun, cold side away
	var shield_ok := model.sun_safe()
	_rect_to(scope, Vector2(cx - 90, cy - 8), Vector2(180, 16), ORANGE if not shield_ok else Color("2a3f5a"))
	_hexes(scope, Vector2(cx + 40, cy - 70), 16, true)
	# Stabilization requires holding the target-specific attitude, so the player
	# sees a continuous result rather than an instant boolean pass.
	_rect_to(scope, Vector2(60, 356), Vector2(480, 18), Color("102037"))
	_rect_to(scope, Vector2(60, 356), Vector2(480 * model.thermal_hold_ratio(), 18), GREEN)
	_label_to(scope, GameManager.text("ATTITUDE HOLD", "姿态保持"), Vector2(60, 378), Vector2(480, 18), 11, GREEN if model.attitude_in_corridor() else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	# temperature gauge (cold side)
	var temp_ratio := clampf((model.cold_side_temp - model.COLD_TARGET) / 120.0, 0.0, 1.0)
	_rect_to(scope, Vector2(60, 406), Vector2(480, 18), Color("102037"))
	_rect_to(scope, Vector2(60, 406), Vector2(480 * (1.0 - temp_ratio), 18), lerp_color(RED, CYAN, 1.0 - temp_ratio))
	_label_to(scope, GameManager.text("Cold-side temperature", "冷端温度"), Vector2(60, 428), Vector2(480, 18), 11, MUTED)
	_label_to(scope, GameManager.text("THERMAL LOCKED" if model.thermal_locked else ("HOLD TARGET ATTITUDE" if model.attitude_in_corridor() else "SLEW SUN MARKER TO TARGET"),
			"热控已锁定" if model.thermal_locked else ("保持目标姿态" if model.attitude_in_corridor() else "将太阳标记转向姿态目标")),
		Vector2(60, 452), Vector2(480, 24), 14,
		GREEN if model.thermal_locked else (ORANGE if model.attitude_in_corridor() else RED),
		HORIZONTAL_ALIGNMENT_CENTER)


func _confirm_thermal() -> void:
	if not model.thermal_locked:
		var remaining := maxf(0.0, model.thermal_hold_required - model.thermal_hold_progress)
		_say(GameManager.text(
			"Thermal lock incomplete. Put the Sun marker inside %.0f-%.0f deg, fine-trim against drift, and hold for %.1f more seconds." % [
				model.thermal_corridor_min(), model.thermal_corridor_max(), remaining],
			"热控尚未锁定。请将太阳标记保持在 %.0f-%.0f° 走廊内，用微调抵消漂移，并再稳定 %.1f 秒。" % [
				model.thermal_corridor_min(), model.thermal_corridor_max(), remaining]
		), RED)
		InteractionFeedback.error(self)
		return
	_log("THERMAL SYSTEM ONLINE")
	_say(GameManager.text("Thermally safe. Lock a guide star next.", "热安全。下一步锁定导星。"), GREEN)
	_advance()
	_space_operation_chain(
		GameManager.text("Held a safe Sun angle", "保持安全太阳夹角"),
		GameManager.text("The sunshield protected the cold optical side", "遮阳罩保护了低温光学面"),
		GameManager.text("Guide-star acquisition is now available", "导星捕获现已可用")
	)


# ============================================================ GUIDE
func _build_guide() -> void:
	guide_slew_active = false
	guide_pending_index = -1
	guide_candidate = -1
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("STAR FIELD & GUIDING", "星场与导星"))
	guide_field = SpaceGuideFieldScript.new()
	guide_field.name = "GuideField"
	guide_field.position = Vector2(40, 8)
	guide_field.size = Vector2(600, 500)
	guide_field.set_stars(model.guide_stars)
	guide_field.candidate_changed.connect(_on_guide_candidate_changed)
	content.add_child(guide_field)
	scope = guide_field
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("FINE GUIDANCE", "精细导星"))
	readout = _label_to(pad, "", Vector2(16, 40), Vector2(284, 104), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_attitude_display = SpaceGuideAttitudeDisplayScript.new()
	guide_attitude_display.name = "GuideAttitudeDisplay"
	guide_attitude_display.position = Vector2(16, 150)
	guide_attitude_display.size = Vector2(284, 170)
	guide_attitude_display.slew_finished.connect(_on_guide_slew_finished)
	pad.add_child(guide_attitude_display)
	_label_to(pad, GameManager.text(
		"Acquire a bright star.\nThe observatory slews first; guidance locks after it settles.",
		"捕获明亮恒星。\n天文台先转向并稳定，之后导星系统才会锁定。"),
		Vector2(16, 316), Vector2(284, 46), 10, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var acquire := _button(GameManager.text("Acquire Highlighted Star", "捕获搜索框中的导星"), Vector2(16, 314), Vector2(284, 44), Color("143247"))
	acquire.name = "AcquireGuideCandidate"
	acquire.pressed.connect(_acquire_guide_candidate)
	acquire.position = Vector2(16, 366)
	acquire.size = Vector2(284, 42)
	pad.add_child(acquire)
	var go := _button(GameManager.text("Confirm Lock", "确认锁定"), Vector2(16, 440), Vector2(284, 44), Color("175238"))
	go.pressed.connect(_confirm_guide)
	go.name = "ConfirmGuideLock"
	pad.add_child(go)
	guide_acquire_button = acquire
	guide_confirm_button = go
	_refresh_guide()


func _on_guide_candidate_changed(index: int) -> void:
	if guide_slew_active:
		return
	guide_candidate = index
	if index >= 0 and index < model.guide_stars.size():
		var star: Dictionary = model.guide_stars[index]
		_log_line("FGS SEARCH WINDOW", "CANDIDATE", str(star.get("id", "GS")))
	else:
		_log_line("FGS SEARCH WINDOW", "SCANNING")
	_update_guide_attitude_candidate()
	_refresh_guide()


func _acquire_guide_candidate() -> void:
	if guide_candidate < 0:
		_say(GameManager.text(
			"No candidate is inside the search box. Drag it over a star first.",
			"搜索框内没有候选星。请先把它拖到恒星上。"), RED)
		InteractionFeedback.error(content)
		return
	_choose_guide(guide_candidate)


func _choose_guide(index: int) -> void:
	if guide_slew_active or index < 0 or index >= model.guide_stars.size():
		return
	var star: Dictionary = model.guide_stars[index]
	if not bool(star.get("usable", false)):
		_log_line("FGS ACQUIRE", "REJECT", str(star.get("id", "GS")))
		_say(GameManager.text(
			"That star is too dim or too far off the detector - it cannot hold a lock.",
			"这颗导星太暗或偏离探测器太远，无法维持锁定。"), RED)
		InteractionFeedback.error(content)
		_refresh_guide()
		return
	guide_slew_active = true
	guide_pending_index = index
	guide_lock_logged = false
	_log_line("SPACECRAFT SLEW", "RUN", str(star.get("id", "GS")))
	_say(GameManager.text(
		"Guide vector accepted. Reaction wheels are rotating the observatory toward the star.",
		"导星矢量已确认。反作用轮正在转动天文台，使望远镜指向这颗恒星。"), CYAN)
	if guide_field != null and is_instance_valid(guide_field):
		guide_field.set_input_locked(true)
	if guide_attitude_display != null and is_instance_valid(guide_attitude_display):
		guide_attitude_display.begin_slew(index, guide_field.guide_direction(index), 1.55)
	_refresh_guide()


func _on_guide_slew_finished(index: int) -> void:
	if not guide_slew_active or index != guide_pending_index:
		return
	guide_slew_active = false
	guide_pending_index = -1
	if guide_field != null and is_instance_valid(guide_field):
		guide_field.set_input_locked(false)
	if model.choose_guide_star(index):
		_log_line("SPACECRAFT SLEW", "HOLD", "YAW/PITCH SETTLED")
		_log_line("FGS ACQUIRE", "TRACK", str(model.guide_stars[index].get("id", "GS")))
		_say(GameManager.text(
			"Attitude hold reached. Fine guidance is now removing the final pointing error.",
			"姿态保持已经建立。精细导星系统正在消除最后的指向误差。"), CYAN)
	else:
		_say(GameManager.text(
			"The guide vector was lost during the slew. Select another star.",
			"姿态转向期间丢失了导星矢量。请选择另一颗恒星。"), RED)
	_refresh_guide()


func _update_guide_attitude_candidate() -> void:
	if guide_attitude_display == null or not is_instance_valid(guide_attitude_display):
		return
	if guide_candidate < 0 or guide_candidate >= model.guide_stars.size():
		guide_attitude_display.set_candidate(-1, Vector2.ZERO, false)
		return
	var star: Dictionary = model.guide_stars[guide_candidate]
	guide_attitude_display.set_candidate(
		guide_candidate,
		guide_field.guide_direction(guide_candidate),
		bool(star.get("usable", false)))


func _refresh_guide() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var guidance_state := "SLEWING" if guide_slew_active else ("LOCKED" if model.guide_locked else ("stabilizing" if model.chosen_guide >= 0 else "searching"))
	var guidance_state_zh := "姿态转向中" if guide_slew_active else ("已锁定" if model.guide_locked else ("稳定中" if model.chosen_guide >= 0 else "搜索中"))
	readout.text = GameManager.text(
		"Candidate: %s\nError %.2f arcsec   Drift %.2f/s\nGuide quality %d%%\nAttitude / guidance: %s" % [
			_guide_candidate_name(),
			model.pointing_error, model.drift_rate, int(model.guide_quality() * 100),
			guidance_state],
		"搜索候选：%s\n指向误差 %.2f 角秒\n漂移速率 %.2f 角秒/秒\n导星质量 %d%%\n精细导星：%s" % [
			_guide_candidate_name(),
			model.pointing_error, model.drift_rate, int(model.guide_quality() * 100),
			guidance_state_zh])
	readout.add_theme_color_override("font_color", GREEN if model.guide_locked else (CYAN if model.chosen_guide >= 0 else MUTED))
	if guide_field != null and is_instance_valid(guide_field):
		guide_field.update_metrics(model.pointing_error, model.drift_rate, model.guide_locked, model.chosen_guide)
	if guide_attitude_display != null and is_instance_valid(guide_attitude_display):
		guide_attitude_display.update_guidance(model.pointing_error, model.drift_rate, model.guide_locked)
	if guide_acquire_button != null and is_instance_valid(guide_acquire_button):
		guide_acquire_button.disabled = guide_slew_active
		guide_acquire_button.text = GameManager.text(
			"Slewing Observatory..." if guide_slew_active else "Begin Attitude Slew",
			"天文台姿态转向中……" if guide_slew_active else "开始姿态转向")
	if guide_confirm_button != null and is_instance_valid(guide_confirm_button):
		guide_confirm_button.disabled = guide_slew_active or not model.guide_locked


func _guide_candidate_name() -> String:
	if guide_candidate < 0 or guide_candidate >= model.guide_stars.size():
		return GameManager.text("none - drag the search box", "无——请拖动搜索框")
	return str((model.guide_stars[guide_candidate] as Dictionary).get("id", "GS"))


func _draw_guide() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# detector box + candidate stars
	_rect_to(scope, Vector2(120, 100), Vector2(360, 300), Color("0a1626"))
	_label_to(scope, GameManager.text("detector field", "探测器视场"), Vector2(120, 76), Vector2(200, 18), 11, MUTED)
	var positions := [Vector2(180, 150), Vector2(300, 250), Vector2(430, 130), Vector2(250, 340)]
	for i in range(model.guide_stars.size()):
		var gs: Dictionary = model.guide_stars[i]
		var p: Vector2 = positions[i % positions.size()]
		var r := 3.0 + float(gs["brightness"]) * 7.0
		var col := GOLD if i == model.chosen_guide else (Color(0.8, 0.85, 0.95) if bool(gs["usable"]) else Color("55606e"))
		_ring_to(scope, p, r, col)
		_label_to(scope, str(gs["id"]), p + Vector2(-16, 12), Vector2(40, 14), 10, col, HORIZONTAL_ALIGNMENT_CENTER)
	# target reticle center
	_ring_to(scope, Vector2(300, 250), 20, GREEN if model.guide_locked else CYAN)
	_label_to(scope, GameManager.text("target", "目标"), Vector2(270, 274), Vector2(60, 14), 10, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(scope, GameManager.text("Bright, well-placed stars lock; dim or off-field stars drift.", "明亮且位置合适的星能锁定；暗淡或偏离视场的星会漂移。"),
		Vector2(120, 410), Vector2(360, 40), 11, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _confirm_guide() -> void:
	if not model.guide_locked:
		_say(GameManager.text("No stable lock yet. Choose a bright, well-placed guide star and let it settle.", "尚未稳定锁定。请选择明亮且位置合适的导星并等待稳定。"), RED)
		InteractionFeedback.error(self)
		return
	_log("GUIDE STAR LOCKED")
	_say(GameManager.text("Fine-guidance locked. Align the mirror segments next.", "精细导星已锁定。下一步校准镜面分段。"), GREEN)
	_advance()
	_space_operation_chain(
		GameManager.text("Locked a stable guide star", "锁定稳定导星"),
		GameManager.text("Pointing drift collapsed inside the fine-guidance loop", "指向漂移被压入精细导星闭环"),
		GameManager.text("Wavefront alignment can now resolve split star images", "波前校准现在可以处理分裂星像")
	)


# ============================================================ WAVEFRONT
func _build_wavefront() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("WAVEFRONT / MIRROR ALIGNMENT", "波前 / 镜面校准"))
	wavefront_display = SpaceWavefrontDisplayScript.new()
	wavefront_display.name = "WavefrontDisplay"
	wavefront_display.position = Vector2(40, 8)
	wavefront_display.size = Vector2(600, 500)
	wavefront_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(wavefront_display)
	scope = wavefront_display
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("SEGMENT ACTUATORS", "镜片执行器"))
	readout = _label_to(pad, "", Vector2(16, 42), Vector2(284, 136), 13, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var regime := _label_to(
		pad,
		GameManager.text(
			"COARSE  ·  six-segment bank / fast travel\nFINE       ·  one segment / sub-wave trim",
			"粗对准  ·  六镜片联动 / 快速大行程\n精对准  ·  单镜片微调 / 压低波前误差"
		),
		Vector2(16, 184), Vector2(284, 52), 10, P_MID
	)
	regime.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var coarse := _button(GameManager.text("COARSE · BANK ACTUATE", "粗对准 · 镜片组驱动"), Vector2(16, 250), Vector2(284, 44), Color("202020"))
	coarse.name = "CoarseWavefrontAlign"
	coarse.pressed.connect(_animate_wavefront_step.bind(0.18, "COARSE"))
	coarse.disabled = model.segment_alignment >= 0.82
	coarse.tooltip_text = GameManager.text(
		"Moves six segments quickly. It cannot finish precision phasing.",
		"一次快速移动六块镜片，但无法完成最终精密共相。"
	)
	pad.add_child(coarse)
	var fine := _button(GameManager.text("FINE · SINGLE SEGMENT", "精对准 · 单镜片微调"), Vector2(16, 306), Vector2(284, 44), Color("143247"))
	fine.name = "FineWavefrontAlign"
	fine.pressed.connect(_animate_wavefront_step.bind(0.07, "FINE"))
	fine.tooltip_text = GameManager.text(
		"Trims one segment and converges the star image below 150 nm.",
		"逐块微调，把分裂星点收敛到 150 nm 以下。"
	)
	pad.add_child(fine)
	var go := _button(GameManager.text("Confirm Alignment", "确认对准"), Vector2(16, 440), Vector2(284, 44), Color("175238"))
	go.pressed.connect(_confirm_wavefront)
	pad.add_child(go)
	_refresh_wavefront()


func _animate_wavefront_step(amount: float, mode: String) -> void:
	if wavefront_animating or model.segment_alignment >= 1.0:
		return
	if mode == "COARSE" and model.segment_alignment >= 0.82:
		_say(GameManager.text(
			"Coarse banks are at their limit. Use FINE control to merge the remaining star images.",
			"粗调镜片组已到行程极限。请改用精对准，让剩余星点合并。"
		), CYAN)
		InteractionFeedback.error(readout)
		return
	wavefront_animating = true
	var start := model.segment_alignment
	var target := clampf(start + amount, 0.0, 0.82 if mode == "COARSE" else 1.0)
	_log_line("WFS %s ACTUATION" % mode, "RUN", "%02d/18" % roundi(target * 18.0))
	if wavefront_display != null and is_instance_valid(wavefront_display):
		wavefront_display.flash_actuation(mode)
	var tween := create_tween().bind_node(self)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(value: float) -> void:
		model.set_segment_alignment(value)
		_refresh_wavefront(), start, target, 0.42 if mode == "COARSE" else 0.26)
	tween.tween_callback(func() -> void:
		wavefront_animating = false
		_log_line("WFS %s ACTUATION" % mode, "HOLD", "%d NM" % roundi(model.wavefront_error_nm))
		if mode == "COARSE" and model.segment_alignment >= 0.82:
			_say(GameManager.text(
				"Coarse phasing complete. Switch to FINE and close the last split peaks.",
				"粗共相完成。切换到精对准，收拢最后的分裂峰。"
			), CYAN)
		_build_stage())


func _refresh_wavefront() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	readout.text = GameManager.text(
		"Segment alignment %d%%\nWavefront error %.0f nm (target < 150)\nPSF sharpness %d%%\nCalibration %d%%" % [
			int(model.segment_alignment * 100), model.wavefront_error_nm, int(model.psf_sharpness() * 100), int(model.calibration_progress * 100)],
		"镜片对准 %d%%\n波前误差 %.0f nm（目标 < 150）\n点扩散锐度 %d%%\n校准进度 %d%%" % [
			int(model.segment_alignment * 100), model.wavefront_error_nm, int(model.psf_sharpness() * 100), int(model.calibration_progress * 100)])
	readout.add_theme_color_override("font_color", GREEN if model.wavefront_ok() else CYAN)
	if wavefront_display != null and is_instance_valid(wavefront_display):
		wavefront_display.alignment = model.segment_alignment
		wavefront_display.wavefront_error_nm = model.wavefront_error_nm


func _draw_wavefront() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var cx := 300.0
	var cy := 200.0
	var sharp := model.psf_sharpness()
	# many split star images that merge into one as alignment improves
	var spread := lerpf(70.0, 0.0, sharp)
	for i in range(6):
		var a := TAU * float(i) / 6.0
		var p := Vector2(cx + cos(a) * spread, cy + sin(a) * spread)
		var r := lerpf(6.0, 14.0, sharp)
		_ring_to(scope, p, r, lerp_color(Color("55606e"), Color(0.9, 0.95, 1.0), sharp))
	if sharp > 0.9:
		_ring_to(scope, Vector2(cx, cy), 18, Color(1, 1, 1))
	_label_to(scope, GameManager.text("Star image: 6 split spots merge into one sharp point.", "星点：6 个分裂光斑逐渐合并成一个锐利点。"),
		Vector2(60, 360), Vector2(480, 40), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _confirm_wavefront() -> void:
	if not model.wavefront_ok():
		_say(GameManager.text("Wavefront error still too high. Keep aligning until the star images merge (< 150 nm).",
			"波前误差仍然太大。继续对准直到星点合并（< 150 nm）。"), RED)
		InteractionFeedback.error(self)
		return
	_log("WAVEFRONT CONVERGED")
	_say(GameManager.text("Optics aligned. Begin the exposure.", "光学已对准。开始曝光。"), GREEN)
	_advance()
	_space_operation_chain(
		GameManager.text("Phased the mirror segments", "校准镜面分段相位"),
		GameManager.text("Wavefront error fell and the split PSF converged", "波前误差下降，分裂点扩散函数完成会聚"),
		GameManager.text("A sharp infrared exposure is now possible", "现在可以进行清晰的红外曝光")
	)


# ============================================================ EXPOSE
func _build_expose() -> void:
	_panel_to(content, Vector2(40, 8), Vector2(600, 470), PANEL, GOLD, GameManager.text("DETECTOR EXPOSURE", "探测器曝光"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 470)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	# What exposure IS - stated plainly, every visit.
	_wrap_to(content, GameManager.text(
		"Exposure collects infrared photons from the target over time. Longer total exposure lifts faint structure out of the noise.",
		"曝光就是让探测器在一段时间内累积目标发出的红外光子。总曝光越长，微弱结构越能从噪声中显现。"),
		Vector2(668, 44), Vector2(300, 74), 12, MUTED)
	var pad := _panel_to(content, Vector2(660, 8), Vector2(324, 470), PANEL, GOLD, GameManager.text("DETECTOR STATUS", "探测器状态"))
	readout = _label_to(pad, "", Vector2(16, 118), Vector2(292, 210), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Button states: before / during / after - never an endless Start.
	var start := _button("", Vector2(16, 344), Vector2(292, 44), Color("175238"))
	start.name = "StartExposure"
	if acquiring:
		start.text = GameManager.text("Exposing...", "曝光中……")
		start.disabled = true
		start.add_theme_stylebox_override("disabled", _flat(Color("1a2c1e"), GOLD, 2))
	elif model.acquired:
		start.text = GameManager.text("Exposure Complete", "曝光完成")
		start.disabled = true
		start.add_theme_stylebox_override("disabled", _flat(Color("0d2a1c"), GREEN, 2))
	else:
		start.text = GameManager.text("Start Exposure", "开始曝光")
		start.pressed.connect(_start_expose)
	pad.add_child(start)

	# Process Data becomes the primary highlighted button once frames exist.
	var go := _button(GameManager.text("Process Data", "处理数据"), Vector2(16, 398), Vector2(292, 44),
		Color("175238") if (model.acquired and not acquiring) else Color("101c2c"))
	go.name = "ProcessData"
	if model.acquired and not acquiring:
		go.add_theme_stylebox_override("normal", _flat(Color("175238"), GOLD_HI, 3))
	else:
		go.disabled = true
		go.add_theme_stylebox_override("disabled", _flat(Color("101c2c"), Color("2a3f5a"), 2))
	go.pressed.connect(_confirm_expose)
	pad.add_child(go)
	if not model.acquired:
		elapsed = 0.0
	_refresh_expose()


func _start_expose() -> void:
	if acquiring or model.acquired:
		return
	model.acquire()
	elapsed = 0.0
	acquiring = true
	_log("PHOTON INTEGRATION STARTED")
	_say(GameManager.text("Collecting photons frame by frame...", "逐帧采集光子……"), CYAN)
	_build_stage()


func _refresh_expose() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	var total_time := 4.0
	var ratio := clampf(elapsed / total_time, 0.0, 1.0) if acquiring else (1.0 if model.acquired else 0.0)
	var p: Dictionary = model.photon_progress(ratio)
	var was := acquiring
	if acquiring and ratio >= 1.0:
		acquiring = false
	# The real target, growing out of the noise as photons accumulate.
	_draw_target_image(scope, Rect2(50, 56, 500, 300), float(p["signal"]),
		Color(1, 1, 1), bool(p["cosmic_this_frame"]), false)
	_label_to(scope, GameManager.dict_text(GameManager.current_target(), "name"),
		Vector2(50, 364), Vector2(500, 22), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	# per-frame progress bars
	for i in range(model.integrations):
		var done := i < int(p["frames_done"])
		_rect_to(scope, Vector2(50 + i * 62, 396), Vector2(54, 18), GREEN if done else Color("2a3f5a"))
		_label_to(scope, "%d" % (i + 1), Vector2(50 + i * 62, 396), Vector2(54, 18), 11,
			Color(0.05, 0.1, 0.08) if done else MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label_to(scope, GameManager.text("frames captured", "已采集帧"), Vector2(50, 420), Vector2(300, 18), 11, MUTED)
	if readout != null and is_instance_valid(readout):
		var integ := model.exposure_time * float(p["frames_done"])
		readout.text = GameManager.text(
			"Target        %s\nInstrument    %s\nFilter        %s\nFrame         %d / %d\nExposure time %.0f s per frame\nIntegration   %.0f s total\nSignal        %d%%\nBackground    %d%%\nDetector      %s" % [
				GameManager.dict_text(GameManager.current_target(), "name"),
				_opt_label("instrument", model.instrument), _opt_label("filter", model.filter),
				int(p["frames_done"]), model.integrations, model.exposure_time, integ,
				int(float(p["signal"]) * 100), int(float(p["noise"]) * 100),
				("INTEGRATING" if acquiring else ("READ OUT" if model.acquired else "IDLE"))],
			"目标      %s\n仪器      %s\n滤镜      %s\n帧        %d / %d\n单帧曝光  %.0f 秒\n累计积分  %.0f 秒\n信号      %d%%\n背景噪声  %d%%\n探测器    %s" % [
				GameManager.dict_text(GameManager.current_target(), "name"),
				_opt_label("instrument", model.instrument), _opt_label("filter", model.filter),
				int(p["frames_done"]), model.integrations, model.exposure_time, integ,
				int(float(p["signal"]) * 100), int(float(p["noise"]) * 100),
				("积分中" if acquiring else ("已读出" if model.acquired else "空闲"))])
		readout.add_theme_color_override("font_color", GREEN if model.acquired and not acquiring else TEXT)
	if bool(p["cosmic_this_frame"]):
		_label_to(scope, GameManager.text("COSMIC RAY EVENT", "宇宙射线事件"), Vector2(50, 56), Vector2(500, 20), 12, RED, HORIZONTAL_ALIGNMENT_CENTER)
	# the moment the last frame lands, rebuild so the buttons flip state
	if was and not acquiring:
		_log("PHOTON INTEGRATION COMPLETE")
		call_deferred("_build_stage")


func _confirm_expose() -> void:
	if not model.acquired:
		_say(GameManager.text("Start the exposure first.", "请先开始曝光。"), RED)
		return
	_advance()
	_space_operation_chain(
		GameManager.text("Integrated infrared photons", "积累红外光子"),
		GameManager.text("Repeated frames raised signal above detector noise", "多帧积累使信号高于探测器噪声"),
		GameManager.text("Raw structure and detector events are ready for processing", "原始结构与探测器事件现已可供处理")
	)


# ============================================================ PROCESS
func _build_process() -> void:
	process_animating = false
	process_step_buttons.clear()
	process_generate_button = null
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("FRAME PROCESSING", "数据帧处理"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 500)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("PROCESSING STEPS", "处理步骤"))
	# Per-frame review: cosmic-ray hits are repaired later; only unusable frames should be dropped.
	var frame_guide := _label_to(
		pad,
		GameManager.text(
			"REVIEW FIRST: keep repairable · drop unusable",
			"先审查：保留可修复帧 · 剔除不可用帧"),
		Vector2(16, 38), Vector2(284, 24), 10, MUTED)
	frame_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var frame_y := 66.0
	for i in range(model.frames.size()):
		var f: Dictionary = model.frames[i]
		var frame_state := _frame_event_short(f)
		var keep_state := GameManager.text("K", "留") if bool(f["kept"]) else GameManager.text("D", "弃")
		var frame_text := GameManager.text(
			"F%d %s [%s]" % [i + 1, frame_state, keep_state],
			"帧%d %s [%s]" % [i + 1, frame_state, keep_state])
		var selected_correctly := bool(f["kept"]) == model.frame_should_keep(f)
		var b := _button(frame_text,
			Vector2(16 + float(i % 2) * 144.0, frame_y + float(i / 2) * 34.0),
			Vector2(138, 30),
			Color("173c32") if selected_correctly else Color("4a271c"))
		b.name = "ProcessFrame_%d" % (i + 1)
		b.add_theme_font_size_override("font_size", 9)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = _frame_event_help(f)
		b.pressed.connect(_toggle_process_frame.bind(i))
		pad.add_child(b)
	var frame_rows := ceili(float(model.frames.size()) / 2.0)
	var y := frame_y + float(frame_rows) * 34.0 + 4.0
	var steps := [
		["align", GameManager.text("Align Frames", "对齐帧"), model.frames_aligned],
		["cosmic", GameManager.text("Remove Cosmic Rays", "移除宇宙射线"), model.cosmic_rays_removed],
		["background", GameManager.text("Subtract Background", "扣除背景"), model.background_subtracted],
		["stack", GameManager.text("Stack Exposures", "叠加曝光"), model.stacked],
	]
	steps[1][1] = GameManager.text("Remove Detector Events", "移除探测器异常")
	for step_index in range(steps.size()):
		var s: Array = steps[step_index]
		var complete := bool(s[2])
		var b := _button(("%d. " % (step_index + 1)) + ("✓ " if complete else "") + str(s[1]), Vector2(16, y), Vector2(284, 32), Color("0d2a1c") if complete else Color("143247"))
		b.name = "ProcessStep_" + str(s[0])
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = complete or not _process_step_available(str(s[0]))
		b.pressed.connect(_run_process_step.bind(str(s[0])))
		pad.add_child(b)
		process_step_buttons[str(s[0])] = b
		y += 38.0
	var next_help := _process_next_help_compact()
	var help_label := _label_to(pad, next_help, Vector2(16, y + 2.0), Vector2(284, maxf(34.0, 424.0 - y)), 10,
		GREEN if model.frame_review_ready() else ORANGE)
	help_label.name = "ProcessNextInstruction"
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.clip_text = true
	help_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label_to(
		pad,
		GameManager.text("TARGET: SNR >= 10  ·  complete steps 1-4", "目标：信噪比 >= 10，并完成第 1-4 步"),
		Vector2(16, 426), Vector2(284, 20), 10, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	var go := _button(GameManager.text("Generate Science Image", "生成科学图像"), Vector2(16, 452), Vector2(284, 40), Color("175238"))
	go.name = "GenerateScienceImage"
	go.disabled = not model.processing_ready() or model.snr() < 10.0
	go.tooltip_text = GameManager.text(
		"Requires all four processing steps and SNR 10 or higher.",
		"需要完成四个处理步骤，并让信噪比达到 10 或更高。")
	go.pressed.connect(_confirm_process)
	pad.add_child(go)
	process_generate_button = go
	_refresh_process()
	call_deferred("_show_process_tutorial_if_needed")


func _process_step_available(step_id: String) -> bool:
	match step_id:
		"align":
			return model.frame_review_ready()
		"cosmic":
			return model.frames_aligned
		"background":
			return model.frames_aligned and model.cosmic_rays_removed
		"stack":
			return model.frames_aligned and model.cosmic_rays_removed and model.background_subtracted
	return false


func _frame_event_short(frame: Dictionary) -> String:
	match str(frame.get("event_type", "clean")):
		"cosmic_streak": return GameManager.text("CR", "宇宙线")
		"hot_pixels": return GameManager.text("HOT", "热点")
		"cosmic_shower": return GameManager.text("BURST", "射线簇")
		"amplifier_glow": return GameManager.text("GLOW", "辉光")
		"guide_smear": return GameManager.text("SMEAR", "拖影")
		"saturation_bloom": return GameManager.text("SAT", "饱和")
	return GameManager.text("CLEAN", "干净")


func _frame_event_help(frame: Dictionary) -> String:
	match str(frame.get("event_type", "clean")):
		"cosmic_streak", "cosmic_shower":
			return GameManager.text(
				"Transient cosmic-ray event. KEEP it; step 2 can identify and repair it.",
				"瞬态宇宙线事件。应保留；第 2 步可以识别并修复。")
		"hot_pixels":
			return GameManager.text(
				"Repairable detector hot pixels. KEEP this frame for the rejection pass.",
				"可修复的探测器热点。保留此帧，交给异常值剔除处理。")
		"amplifier_glow":
			return GameManager.text(
				"Smooth amplifier glow. KEEP it; background subtraction can remove it.",
				"平滑的放大器辉光。保留此帧；扣除背景可以消除。")
		"guide_smear":
			return GameManager.text(
				"Guide lock slipped during this frame. Detail is smeared and cannot be reconstructed: DROP it.",
				"这一帧曝光时导星锁定滑脱，细节已经拖影且无法重建：应剔除。")
		"saturation_bloom":
			return GameManager.text(
				"The detector clipped bright detail. DROP it, then return to Plan and shorten the exposure if every frame is saturated.",
				"探测器亮部已经溢出。应剔除；若所有帧都饱和，请返回规划并缩短曝光。")
	return GameManager.text(
		"Clean science frame. KEEP it so stacking retains its photons.",
		"干净的科学帧。应保留，让叠加继续利用其中的光子。")


func _toggle_process_frame(index: int) -> void:
	if index < 0 or index >= model.frames.size():
		return
	var frame: Dictionary = model.frames[index]
	var new_keep := not bool(frame.get("kept", true))
	model.toggle_keep(index, new_keep)
	var correct := new_keep == model.frame_should_keep(frame)
	_say(GameManager.text(
		"Frame %d set to %s. %s" % [
			index + 1, "KEEP" if new_keep else "DROP", _frame_event_help(frame)],
		"第 %d 帧已设为%s。%s" % [
			index + 1, "保留" if new_keep else "剔除", _frame_event_help(frame)]
	), GREEN if correct else ORANGE)
	_build_stage()


func _process_next_help_compact() -> String:
	if not model.frame_review_ready():
		return GameManager.text(
			"NEXT: REVIEW FRAMES\nKEEP CLEAN/HOT/CR · DROP SMEAR/SAT",
			"下一步：检查每一帧\n保留干净/热像素/宇宙线帧 · 丢弃拖影/过曝帧")
	if not model.frames_aligned:
		return GameManager.text(
			"NEXT 1: ALIGN FRAMES\nRegister retained stars to the same pixels.",
			"下一步 1：对齐帧\n把保留帧中的星点配准到相同像素。")
	if not model.cosmic_rays_removed:
		return GameManager.text(
			"NEXT 2: REMOVE EVENTS\nRepair cosmic rays and detector hot pixels.",
			"下一步 2：移除异常\n修复宇宙线痕迹和探测器热像素。")
	if not model.background_subtracted:
		return GameManager.text(
			"NEXT 3: SUBTRACT BACKGROUND\nRemove infrared and amplifier glow.",
			"下一步 3：扣除背景\n移除红外背景与放大器辉光。")
	if not model.stacked:
		return GameManager.text(
			"NEXT 4: STACK EXPOSURES\nCombine clean, registered photon data.",
			"下一步 4：叠加曝光\n合并干净且已经配准的光子数据。")
	return GameManager.text(
		"NEXT: GENERATE SCIENCE IMAGE\nAll required processing is complete.",
		"下一步：生成科学图像\n所有必要的数据处理已经完成。")


func _process_next_help() -> String:
	if not model.frame_review_ready():
		return GameManager.text(
			"NEXT · Inspect every frame. Keep CLEAN/FIX; drop SMEAR/SATURATED.",
			"下一步 · 检查每一帧。保留干净/可修复帧，剔除拖影/饱和帧。")
	if not model.frames_aligned:
		return GameManager.text(
			"NEXT · 1 Align Frames: register the stars to the same pixels.",
			"下一步 · 1 对齐帧：把各帧星点配准到相同像素。")
	if not model.cosmic_rays_removed:
		return GameManager.text(
			"NEXT · 2 Remove Events: reject CR lines and hot pixels.",
			"下一步 · 2 移除事件：剔除宇宙线亮痕与热点。")
	if not model.background_subtracted:
		return GameManager.text(
			"NEXT · 3 Subtract Background: remove infrared glow.",
			"下一步 · 3 扣除背景：移除红外背景辉光。")
	if not model.stacked:
		return GameManager.text(
			"NEXT · 4 Stack: combine the clean registered photons.",
			"下一步 · 4 叠加：合并干净且已配准的光子。")
	return GameManager.text(
		"READY · Confirm SNR >= 10, then generate the science image.",
		"就绪 · 确认信噪比达到 10，再生成科学图像。")


func _show_process_tutorial_if_needed() -> void:
	if _key() != "process" or not InteractionFeedback.guidance_highlights_enabled():
		return
	var seen: Array = GameManager.progress.get("seen_teaching_steps", [])
	if seen.has("space_frame_processing_v2"):
		return
	if process_tutorial_overlay != null and is_instance_valid(process_tutorial_overlay) and not process_tutorial_overlay.is_queued_for_deletion():
		return
	var frame_height := maxf(40.0, float(ceili(float(model.frames.size()) / 2.0)) * 34.0)
	var pipeline_y := 178.0 + frame_height
	process_tutorial_steps = [
		{
			"rect": Rect2(92, 156, 496, 344),
			"pose": MayaPortrait.EXPLAIN,
			"en": "This is detector data, not a finished photograph. Compare the image with the telemetry: SNR is signal divided by noise, and higher values reveal fainter structure.",
			"zh": "这不是完成的照片，而是探测器数据。请把图像与遥测数字一起看：信噪比是信号与噪声之比，数值越高，越能显出微弱结构。"
		},
		{
			"rect": Rect2(676, 174, 300, frame_height + 10.0),
			"pose": MayaPortrait.THINK,
			"en": "Review every frame. KEEP clean frames, cosmic-ray lines, hot pixels and amplifier glow because the pipeline can repair them. DROP guide smears and saturated frames because their detail is gone.",
			"zh": "逐帧审查：干净帧、宇宙线亮痕、热点和放大器辉光可以被流水线修复，应当保留；导星拖影和饱和帧已经丢失细节，必须剔除。"
		},
		{
			"rect": Rect2(92, 514, 496, 54),
			"pose": MayaPortrait.THINK,
			"en": "Your numerical reference is SNR 10. Keep useful frames so stacking raises SNR; dropping good frames throws away photons.",
			"zh": "本页最重要的数字标准是信噪比 10。保留有用帧，让叠加提高信噪比；误删好帧等于丢掉已经收集到的光子。"
		},
		{
			"rect": Rect2(676, pipeline_y - 4.0, 300, 158),
			"pose": MayaPortrait.EMPHASIZE,
			"en": "After the frame review turns correct, process in order: 1 Align frames, 2 Remove transient events, 3 Subtract background, 4 Stack exposures. The NEXT line always tells you what to press.",
			"zh": "帧审查正确后，按顺序处理：1 对齐帧，2 移除瞬态事件，3 扣除背景，4 叠加曝光。右侧的“下一步”会始终告诉你该按哪个按钮。"
		},
		{
			"rect": Rect2(676, 554, 300, 52),
			"pose": MayaPortrait.EMPHASIZE,
			"en": "Generate Science Image becomes available only when steps 1-4 are complete and SNR is at least 10. Then the image is ready for filter mapping.",
			"zh": "只有完成第 1-4 步且信噪比至少达到 10，“生成科学图像”才会启用。之后才能进行滤镜映射。"
		}
	]
	_build_process_tutorial_overlay()
	_show_process_tutorial_step(0)


func _build_process_tutorial_overlay() -> void:
	process_tutorial_overlay = Control.new()
	process_tutorial_overlay.name = "MayaProcessTutorial"
	process_tutorial_overlay.add_to_group("guidance_highlight")
	process_tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	process_tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	process_tutorial_overlay.z_index = 520
	add_child(process_tutorial_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	process_tutorial_overlay.add_child(dim)

	process_tutorial_highlight = Panel.new()
	process_tutorial_highlight.name = "ProcessTutorialHighlight"
	process_tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_tutorial_highlight.add_theme_stylebox_override(
		"panel", _flat(Color(0.0, 0.0, 0.0, 0.03), GOLD_HI, 3))
	process_tutorial_overlay.add_child(process_tutorial_highlight)

	var teaching := Panel.new()
	teaching.name = "MayaProcessTeachingCard"
	teaching.position = Vector2(40, 570)
	teaching.size = Vector2(600, 150)
	teaching.add_theme_stylebox_override("panel", _flat(Color("071323"), GOLD, 2))
	process_tutorial_overlay.add_child(teaching)

	process_tutorial_portrait = MayaPortrait.create(
		teaching,
		"MayaProcessPortrait",
		MayaPortrait.EXPLAIN,
		Vector2(10, 8),
		Vector2(88, 134),
		1)
	_label_to(
		teaching, GameManager.text("MAYA · DATA PIPELINE", "玛雅 · 数据处理"),
		Vector2(108, 10), Vector2(330, 24), 17, GOLD_HI)
	process_tutorial_copy = _label_to(
		teaching, "", Vector2(108, 36), Vector2(470, 70), 13, TEXT)
	process_tutorial_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	process_tutorial_copy.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	process_tutorial_next_button = _button(
		GameManager.text("Next", "下一步"), Vector2(440, 108), Vector2(138, 32), Color("175238"))
	process_tutorial_next_button.name = "ProcessTutorialNext"
	process_tutorial_next_button.pressed.connect(_advance_process_tutorial)
	teaching.add_child(process_tutorial_next_button)


func _show_process_tutorial_step(index: int) -> void:
	process_tutorial_step = clampi(index, 0, process_tutorial_steps.size() - 1)
	var step: Dictionary = process_tutorial_steps[process_tutorial_step]
	process_tutorial_copy.text = GameManager.text(str(step.get("en", "")), str(step.get("zh", "")))
	MayaPortrait.apply_to(process_tutorial_portrait, str(step.get("pose", MayaPortrait.EXPLAIN)))
	var rect: Rect2 = (step.get("rect", Rect2(92, 156, 496, 344)) as Rect2).grow(6.0)
	process_tutorial_highlight.position = rect.position
	process_tutorial_highlight.size = rect.size
	process_tutorial_next_button.text = GameManager.text(
		"Start Processing" if process_tutorial_step == process_tutorial_steps.size() - 1 else "Next",
		"开始处理" if process_tutorial_step == process_tutorial_steps.size() - 1 else "下一步")


func _advance_process_tutorial() -> void:
	if process_tutorial_step + 1 < process_tutorial_steps.size():
		_show_process_tutorial_step(process_tutorial_step + 1)
		return
	var seen: Array = GameManager.progress.get("seen_teaching_steps", [])
	if not seen.has("space_frame_processing_v2"):
		seen.append("space_frame_processing_v2")
		GameManager.progress["seen_teaching_steps"] = seen
		GameManager.save()
	if process_tutorial_overlay != null and is_instance_valid(process_tutorial_overlay):
		process_tutorial_overlay.queue_free()
	process_tutorial_overlay = null
	_say(GameManager.text(
		"Maya: Read the frame status, follow steps 1-4, and use SNR 10 as your final threshold.",
		"玛雅：先读懂每帧状态，再按第 1-4 步处理，最后以信噪比 10 作为通过标准。"), CYAN)


func _refresh_process() -> void:
	_draw_process()


func _run_process_step(step_id: String) -> void:
	if process_animating:
		return
	if not _process_step_available(step_id):
		var blocked_text := GameManager.text(
			"That step is not ready. Complete the numbered step immediately above it first.",
			"这一步尚未解锁。请先完成它上方紧邻的编号步骤。")
		if not model.frame_review_ready():
			blocked_text = GameManager.text(
				"Review the detector frames first. KEEP clean/repairable events and DROP guide smears or saturated frames.",
				"请先审查探测器帧。保留干净或可修复的事件，剔除导星拖影或饱和帧。")
		_say(blocked_text, RED)
		InteractionFeedback.error(content)
		return
	var before_snr := model.snr()
	match step_id:
		"align":
			model.align_frames()
		"cosmic":
			model.remove_cosmic_rays()
		"background":
			model.subtract_background()
		"stack":
			model.stack()
		_:
			return
	process_animating = true
	_log_line("PIPELINE %s" % step_id.to_upper(), "RUN", "SNR %.1f" % before_snr)
	_say(_process_action_text(step_id), CYAN)
	_play_process_animation(step_id, before_snr)


func _process_action_text(step_id: String) -> String:
	match step_id:
		"align":
			return GameManager.text("Registering star centroids. Watch the four frame outlines converge.", "正在配准星点质心。观察四个帧框合拢。")
		"cosmic":
			return GameManager.text("Scanning every transient event. Cosmic-ray lines, showers and hot pixels are being rejected.", "正在扫描所有瞬态事件。宇宙线亮痕、射线簇和热点正在被剔除。")
		"background":
			return GameManager.text("Estimating the infrared background. The noise floor is dropping.", "正在估计红外背景。噪声底正在下降。")
		"stack":
			return GameManager.text("Co-adding the registered frames. Faint structure is emerging.", "正在叠加已配准帧。微弱结构正在显现。")
	return ""


func _play_process_animation(step_id: String, before_snr: float) -> void:
	if scope == null or not is_instance_valid(scope):
		process_animating = false
		return
	var image_rect := Rect2(60, 52, 480, 300)
	var overlay := Control.new()
	overlay.name = "ProcessTransition_" + step_id
	overlay.position = Vector2.ZERO
	overlay.size = scope.size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 40
	scope.add_child(overlay)
	var tween := create_tween().bind_node(self).set_parallel(true)
	match step_id:
		"align":
			var offsets := [Vector2(-18, -12), Vector2(14, 9), Vector2(-9, 16), Vector2(20, -5)]
			for index in range(offsets.size()):
				var frame := Panel.new()
				frame.position = image_rect.position + offsets[index]
				frame.size = image_rect.size
				frame.modulate.a = 0.72
				frame.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), P_BRIGHT, 1))
				overlay.add_child(frame)
				tween.tween_property(frame, "position", image_rect.position, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(frame, "modulate:a", 0.0, 0.54).set_delay(0.12)
		"cosmic":
			var event_nodes := _create_process_event_nodes(overlay, image_rect)
			for scan_index in range(3):
				var scan := ColorRect.new()
				scan.color = Color(P_HOT, 0.78 - float(scan_index) * 0.16)
				scan.position = image_rect.position + Vector2(0, float(scan_index) * 18.0)
				scan.size = Vector2(image_rect.size.x, 2)
				overlay.add_child(scan)
				tween.tween_property(scan, "position:y", image_rect.end.y, 0.46 + float(scan_index) * 0.08) \
					.set_delay(float(scan_index) * 0.07).set_trans(Tween.TRANS_LINEAR)
				tween.tween_property(scan, "modulate:a", 0.0, 0.12).set_delay(0.48 + float(scan_index) * 0.08)
			for event_node in event_nodes:
				tween.tween_property(event_node, "modulate:a", 0.0, 0.38).set_delay(0.14)
		"background":
			var veil := ColorRect.new()
			veil.color = Color(1, 1, 1, 0.18)
			veil.position = image_rect.position
			veil.size = image_rect.size
			overlay.add_child(veil)
			for row in range(12):
				var noise_line := ColorRect.new()
				noise_line.color = Color(1, 1, 1, 0.16 if row % 2 == 0 else 0.08)
				noise_line.position = image_rect.position + Vector2(0, 8 + row * 23)
				noise_line.size = Vector2(image_rect.size.x, 1)
				overlay.add_child(noise_line)
				tween.tween_property(noise_line, "modulate:a", 0.0, 0.42 + row * 0.008)
			tween.tween_property(veil, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		"stack":
			var offsets := [Vector2(-24, -15), Vector2(-8, -5), Vector2(9, 6), Vector2(25, 15)]
			for index in range(offsets.size()):
				var frame := Panel.new()
				frame.position = image_rect.position + offsets[index]
				frame.size = image_rect.size
				frame.modulate.a = 0.35 + index * 0.10
				frame.add_theme_stylebox_override("panel", _flat(Color(0.02, 0.02, 0.02, 0.08), P_MID, 1))
				overlay.add_child(frame)
				tween.tween_property(frame, "position", image_rect.position, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				if index < offsets.size() - 1:
					tween.tween_property(frame, "modulate:a", 0.0, 0.18).set_delay(0.40)
	tween.chain().tween_callback(_finish_process_animation.bind(step_id, before_snr, overlay))


func _create_process_event_nodes(parent: Control, rect: Rect2) -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	for frame_value in model.frames:
		var frame: Dictionary = frame_value
		if not bool(frame.get("kept", false)):
			continue
		var seed := int(frame.get("event_seed", 1))
		var event_type := str(frame.get("event_type", "clean"))
		match event_type:
			"cosmic_streak":
				var line := Line2D.new()
				line.width = 3.0
				line.default_color = P_HOT
				var y1 := 24.0 + float(seed % 86)
				var y2 := rect.size.y - 28.0 - float(seed % 64)
				line.points = PackedVector2Array([
					rect.position + Vector2(18, y1),
					rect.position + Vector2(rect.size.x - 24.0, y2)])
				parent.add_child(line)
				nodes.append(line)
			"cosmic_shower":
				for ray in range(3):
					var line := Line2D.new()
					line.width = 2.0
					line.default_color = Color(P_HOT, 0.85)
					var start_x := 36.0 + float((seed + ray * 73) % 250)
					var start_y := 20.0 + float((seed + ray * 41) % 90)
					line.points = PackedVector2Array([
						rect.position + Vector2(start_x, start_y),
						rect.position + Vector2(start_x + 120.0 + ray * 22.0, start_y + 76.0 + ray * 18.0)])
					parent.add_child(line)
					nodes.append(line)
			"hot_pixels":
				for pixel in range(9):
					var hot := ColorRect.new()
					hot.color = Color(P_HOT, 0.90)
					hot.position = rect.position + Vector2(
						18.0 + float((seed + pixel * 67) % int(rect.size.x - 36.0)),
						18.0 + float((seed + pixel * 43) % int(rect.size.y - 36.0)))
					hot.size = Vector2(3, 3)
					parent.add_child(hot)
					nodes.append(hot)
	return nodes


func _draw_processing_events(parent: Control, rect: Rect2) -> void:
	if not model.cosmic_rays_removed:
		for node in _create_process_event_nodes(parent, rect):
			node.modulate.a = 0.88
	for frame_value in model.frames:
		var frame: Dictionary = frame_value
		if not bool(frame.get("kept", false)):
			continue
		var event_type := str(frame.get("event_type", "clean"))
		var seed := int(frame.get("event_seed", 1))
		if event_type == "guide_smear":
			for band in range(3):
				var y := rect.position.y + 70.0 + float((seed + band * 57) % 150)
				_line_to(parent,
					Vector2(rect.position.x + 20.0, y),
					Vector2(rect.end.x - 20.0, y + 18.0),
					Color(0.85, 0.60, 0.40, 0.24))
		elif event_type == "saturation_bloom":
			_ellipse_to(parent, rect.get_center(), Vector2(72, 32), Color(1.0, 0.95, 0.82, 0.34))
		elif event_type == "amplifier_glow" and not model.background_subtracted:
			_ellipse_to(parent,
				Vector2(rect.end.x - 18.0, rect.get_center().y),
				Vector2(52, rect.size.y * 0.42),
				Color(0.78, 0.50, 0.32, 0.15))


func _finish_process_animation(step_id: String, before_snr: float, overlay: Control) -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	process_animating = false
	_log_line("PIPELINE %s" % step_id.to_upper(), "COMPLETE", "SNR %.1f -> %.1f" % [before_snr, model.snr()])
	_say(GameManager.text("Processing step complete. The image and telemetry now agree.", "处理步骤完成。图像与遥测数据已同步更新。"), GREEN)
	var chain_copy := _space_processing_chain_copy(step_id, before_snr, model.snr())
	_space_operation_chain(str(chain_copy[0]), str(chain_copy[1]), str(chain_copy[2]))
	if _key() == "process":
		_build_stage()


func _draw_process() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# The real target: each processing step visibly cleans the image.
	var quality := clampf(model.snr() / 26.0, 0.06, 1.0)
	var image_rect := Rect2(60, 52, 480, 300)
	_draw_target_image(scope, image_rect, quality, Color(1, 1, 1), false, not model.frames_aligned)
	_draw_processing_events(scope, image_rect)
	_label_to(scope, GameManager.dict_text(GameManager.current_target(), "name"),
		Vector2(60, 358), Vector2(480, 20), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	# tell the player exactly what they are looking at right now
	var note := GameManager.text(
		"Review the frames: multiple detector events and one unrecoverable smear are present.",
		"请审查数据帧：其中包含多种探测器事件，以及一帧无法修复的拖影。")
	if model.frame_review_ready() and not model.frames_aligned:
		note = GameManager.text("Frame review correct. Align the retained star fields.", "帧审查正确。请对齐保留帧中的星场。")
	elif model.frames_aligned and not model.cosmic_rays_removed:
		note = GameManager.text("Frames aligned. Remove cosmic-ray lines, showers and hot pixels.", "各帧已对齐。请移除宇宙线亮痕、射线簇和热点。")
	elif model.cosmic_rays_removed and not model.background_subtracted:
		note = GameManager.text("Frames aligned. Subtract the background to drop the noise floor.", "各帧已对齐。扣除背景以降低噪声底。")
	elif model.background_subtracted and not model.stacked:
		note = GameManager.text("Background removed. Stack the frames to raise the signal.", "背景已扣除。叠加各帧以提升信号。")
	elif model.processing_ready():
		note = GameManager.text("Stacked science image - faint structure is now visible.", "叠加完成——微弱结构已经显现。")
	_wrap_to(scope, note, Vector2(60, 380), Vector2(480, 36), 12, CYAN)
	_label_to(scope, GameManager.text("Live SNR %.1f   Kept frames %d" % [model.snr(), model.kept_frames()],
		"实时信噪比 %.1f   保留帧 %d" % [model.snr(), model.kept_frames()]), Vector2(60, 418), Vector2(480, 22), 13,
		GREEN if model.snr() >= 10.0 else CYAN)
	var next_step := GameManager.text("Review frames", "审查帧")
	if model.frame_review_ready() and not model.frames_aligned:
		next_step = GameManager.text("Align frames", "对齐帧")
	elif model.frames_aligned and not model.cosmic_rays_removed:
		next_step = GameManager.text("Remove cosmic rays", "移除宇宙射线")
	elif model.cosmic_rays_removed and not model.background_subtracted:
		next_step = GameManager.text("Subtract background", "扣除背景")
	elif model.background_subtracted and not model.stacked:
		next_step = GameManager.text("Stack exposures", "叠加曝光")
	elif model.processing_ready() and model.snr() >= 10.0:
		next_step = GameManager.text("Generate science image", "生成科学图像")
	_label_to(
		scope,
		GameManager.text(
			"REFERENCE  SNR >= 10    NEXT  %s" % next_step,
			"参考标准  信噪比 >= 10    下一步  %s" % next_step),
		Vector2(60, 444), Vector2(480, 20), 11,
		GREEN if model.processing_ready() and model.snr() >= 10.0 else GOLD,
		HORIZONTAL_ALIGNMENT_CENTER)


func _confirm_process() -> void:
	if not model.frame_review_ready():
		_say(GameManager.text(
			"Frame review is incomplete. Keep clean/repairable frames and drop guide smears or saturation.",
			"帧审查尚未完成。请保留干净/可修复帧，并剔除导星拖影或饱和帧。"), RED)
		InteractionFeedback.error(self)
		return
	if not model.processing_ready():
		_say(GameManager.text("Finish align, cosmic-ray removal, background and stacking first.", "请先完成对齐、移除宇宙射线、扣除背景和叠加。"), RED)
		InteractionFeedback.error(self)
		return
	if model.snr() < 10.0:
		_say(GameManager.text("SNR still below 10. Keep more good frames or improve earlier stages.", "信噪比仍低于 10。请保留更多好帧或改进前面的步骤。"), ORANGE)
		return
	_log("SCIENCE IMAGE RECONSTRUCTED")
	_say(GameManager.text("Science image generated. Map the filters.", "科学图像已生成。进行滤镜映射。"), GREEN)
	_advance()
	_space_operation_chain(
		GameManager.text("Completed the processing pipeline", "完成图像处理流水线"),
		GameManager.text("Aligned frames, removed events, lowered background, and stacked photons", "对齐帧、移除事件、降低背景并堆叠光子"),
		GameManager.text("Faint infrared structure is now scientifically readable", "微弱红外结构现在可以进行科学判读")
	)


# ============================================================ FILTER
func _build_filter() -> void:
	filter_animating = false
	_panel_to(content, Vector2(40, 8), Vector2(600, 500), PANEL, GOLD, GameManager.text("FALSE-COLOUR FILTER MAPPING", "假彩色滤镜映射"))
	scope = Control.new(); scope.position = Vector2(40, 8); scope.size = Vector2(600, 500)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scope)
	var pad := _panel_to(content, Vector2(668, 8), Vector2(316, 500), PANEL, GOLD, GameManager.text("CHANNELS & SCIENCE", "通道与科学"))
	_label_to(pad, GameManager.text("1 MAP BANDS  >  2 READ STRUCTURE  >  3 INFER",
		"1 映射波段  >  2 读取结构  >  3 作出推断"), Vector2(16, 40), Vector2(284, 22), 11, P_BRIGHT)
	_label_to(pad, GameManager.text("The colour is a code for wavelength, not what an eye would see.",
		"颜色是波长编码，不是肉眼看到的颜色。"), Vector2(16, 64), Vector2(284, 34), 10, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var y := 102.0
	for ch in ["R", "G", "B"]:
		_label_to(pad, ch, Vector2(16, y), Vector2(24, 30), 15, GOLD)
		var x := 44.0
		for filt in ["near_infrared", "mid_infrared", "dust"]:
			var b := _button(_opt_label("filter", filt), Vector2(x, y - 2), Vector2(80, 30), Color("1c3a5c") if str(model.channel_map[ch]) == filt else Color("122234"))
			b.add_theme_font_size_override("font_size", 10)
			b.pressed.connect(_set_filter_channel.bind(ch, filt))
			pad.add_child(b)
			x += 84.0
		y += 44.0
	_label_to(pad, GameManager.text("Scientific interpretation:", "科学解释："), Vector2(16, y + 6), Vector2(284, 20), 12, MUTED)
	y += 34.0
	for opt in model.science_options():
		var b := _button(_science_label(opt), Vector2(16, y), Vector2(284, 30), Color("1c3a5c") if model.chosen_science == opt else Color("143247"))
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(_set_science_choice.bind(opt))
		pad.add_child(b)
		y += 36.0
	var go := _button(GameManager.text("Confirm Science Image", "确认科学图像"), Vector2(16, 452), Vector2(284, 40), Color("175238"))
	go.pressed.connect(_confirm_filter)
	pad.add_child(go)
	_draw_filter()


func _set_filter_channel(channel: String, filter_id: String) -> void:
	if filter_animating:
		return
	model.set_channel(channel, filter_id)
	_log_line("MAP CHANNEL %s" % channel, "RUN", filter_id.to_upper())
	_say(GameManager.text(
		"Recomposing %s from the %s band. Watch the scan reveal which structures brighten." % [channel, _opt_label("filter", filter_id)],
		"正在用%s波段重组%s通道。观察扫描后哪些结构变亮。" % [_opt_label("filter", filter_id), channel]), CYAN)
	_draw_filter()
	_play_filter_scan("MAP " + channel)


func _set_science_choice(option: String) -> void:
	if filter_animating:
		return
	model.choose_science(option)
	_log_line("SCIENCE HYPOTHESIS", "SET", option.to_upper())
	_draw_filter()
	if model.science_correct():
		_say(GameManager.text(
			"Hypothesis matches the visible structure. Confirm the science image.",
			"推断与可见结构吻合。请确认科学图像。"), GREEN)
	else:
		_say(GameManager.text(
			"Hypothesis recorded. Compare it with the evidence callouts before confirming.",
			"推断已记录。确认前请将它与结构证据标注对照。"), CYAN)
	_play_filter_scan("HYPOTHESIS")


func _play_filter_scan(label_text: String) -> void:
	if scope == null or not is_instance_valid(scope):
		return
	filter_animating = true
	var scan := ColorRect.new()
	scan.name = "FilterScan"
	scan.color = P_HOT
	scan.position = Vector2(60, 52)
	scan.size = Vector2(480, 2)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.z_index = 50
	scope.add_child(scan)
	var tag := _label_to(scope, label_text, Vector2(66, 58), Vector2(180, 18), 10, P_HOT)
	tag.z_index = 51
	var tween := create_tween().bind_node(self).set_parallel(true)
	tween.tween_property(scan, "position:y", 352.0, 0.34).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(scan, "modulate:a", 0.0, 0.12).set_delay(0.30)
	tween.tween_property(tag, "modulate:a", 0.0, 0.24).set_delay(0.16)
	tween.chain().tween_callback(_finish_filter_scan.bind(scan, tag))


func _finish_filter_scan(scan: ColorRect, tag: Label) -> void:
	if is_instance_valid(scan):
		scan.queue_free()
	if is_instance_valid(tag):
		tag.queue_free()
	filter_animating = false
	_log_line("FALSE COLOUR COMPOSITE", "UPDATED")
	if _key() == "filter":
		_build_stage()


func _science_label(opt: String) -> String:
	var m := {"dust_rich": ["Dust-rich region", "富尘埃区"], "star_forming": ["Star-forming region", "恒星形成区"],
		"old_stellar": ["Old stellar population", "老年恒星族"], "hot_gas": ["Hot gas", "高温气体"],
		"distant_galaxy": ["Redshifted distant galaxy", "红移遥远星系"]}
	var pair: Array = m.get(opt, [opt, opt])
	return GameManager.text(str(pair[0]), str(pair[1]))


func _draw_filter() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	for c in scope.get_children():
		c.queue_free()
	# composite tinted by the channel mapping so different maps look different
	var tint := Color(0.2, 0.2, 0.2)
	var band_col := {"near_infrared": Color(0.9, 0.4, 0.3), "mid_infrared": Color(0.3, 0.5, 0.9), "dust": Color(0.4, 0.8, 0.5)}
	if str(model.channel_map["R"]) != "":
		tint.r += 0.5 * band_col.get(str(model.channel_map["R"]), Color.WHITE).r
	if str(model.channel_map["G"]) != "":
		tint.g += 0.5 * band_col.get(str(model.channel_map["G"]), Color.WHITE).g
	if str(model.channel_map["B"]) != "":
		tint.b += 0.5 * band_col.get(str(model.channel_map["B"]), Color.WHITE).b
	# the SAME target, recoloured by the channel mapping the player chose
	_draw_target_image(scope, Rect2(60, 52, 480, 300), clampf(model.snr() / 26.0, 0.2, 1.0), tint)
	_label_to(scope, GameManager.dict_text(GameManager.current_target(), "name") + "  ·  " +
		GameManager.text("false colour", "假彩色"), Vector2(60, 358), Vector2(480, 20), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var mapped := "R=%s  G=%s  B=%s" % [
		_opt_label("filter", str(model.channel_map["R"])) if str(model.channel_map["R"]) != "" else "-",
		_opt_label("filter", str(model.channel_map["G"])) if str(model.channel_map["G"]) != "" else "-",
		_opt_label("filter", str(model.channel_map["B"])) if str(model.channel_map["B"]) != "" else "-"]
	_label_to(scope, mapped, Vector2(60, 380), Vector2(480, 20), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	if model.mapping_complete():
		_draw_filter_evidence(scope)
	else:
		_wrap_to(scope, GameManager.text(
			"Assign three different bands. Longer-wavelength dust emission and shorter-wavelength stellar light will separate into different structures.",
			"分配三个不同波段。长波尘埃辐射与短波恒星光会分离成不同结构。"),
			Vector2(60, 404), Vector2(480, 52), 12, MUTED)


func _draw_filter_evidence(parent: Control) -> void:
	var evidence := _filter_evidence()
	_label_to(parent, GameManager.text("STRUCTURE EVIDENCE", "结构证据"), Vector2(60, 402), Vector2(480, 18), 11, P_HOT)
	for index in range(mini(3, evidence.size())):
		_label_to(parent, "▸ " + str(evidence[index]), Vector2(70, 422 + index * 18), Vector2(466, 18), 10, P_BRIGHT)
	# A restrained callout points at the diagnostic feature without covering it.
	var feature_pos := Vector2(360, 230)
	var feature_text := GameManager.text("DIAGNOSTIC FEATURE", "诊断结构")
	if model.true_science == "star_forming":
		feature_pos = Vector2(338, 198)
		feature_text = GameManager.text("COMPACT KNOTS", "致密亮结")
	elif model.true_science == "dust_rich":
		feature_pos = Vector2(350, 250)
		feature_text = GameManager.text("DUST LANE", "尘埃带")
	elif model.true_science == "old_stellar":
		feature_text = GameManager.text("SMOOTH HALO", "平滑晕")
	elif model.true_science == "hot_gas":
		feature_text = GameManager.text("SHELL / ARC", "壳层 / 弧")
	elif model.true_science == "distant_galaxy":
		feature_text = GameManager.text("SHIFTED CORE", "红移核心")
	_line_to(parent, feature_pos, Vector2(474, 174), P_HOT)
	_label_to(parent, feature_text, Vector2(412, 154), Vector2(132, 18), 9, P_HOT, HORIZONTAL_ALIGNMENT_RIGHT)


func _filter_evidence() -> Array:
	match model.true_science:
		"dust_rich":
			return [
				GameManager.text("Broad dark lanes split the stellar glow.", "宽阔暗带切开恒星辉光。"),
				GameManager.text("Long-wave dust emission is spatially extended.", "长波尘埃辐射呈延展分布。"),
				GameManager.text("The compact stellar knots are not dominant.", "致密恒星亮结并不占主导。")]
		"star_forming":
			return [
				GameManager.text("Several compact bright knots mark young clusters.", "多个致密亮结标记年轻星团。"),
				GameManager.text("Filaments wrap around the embedded stars.", "丝状结构环绕嵌入恒星。"),
				GameManager.text("Dust and short-wave starlight overlap locally.", "尘埃与短波恒星光局部重合。")]
		"old_stellar":
			return [
				GameManager.text("The halo is smooth rather than clumpy.", "星晕平滑而非成团。"),
				GameManager.text("Dust lanes and compact knots are weak.", "尘埃带和致密亮结都较弱。"),
				GameManager.text("Diffuse stellar light dominates the frame.", "弥散恒星光主导画面。")]
		"hot_gas":
			return [
				GameManager.text("Shell-like arcs trace heated gas.", "壳状弧线勾勒受热气体。"),
				GameManager.text("Emission extends beyond compact stars.", "辐射延伸到致密恒星之外。"),
				GameManager.text("Shock structures are brighter than dust lanes.", "激波结构比尘埃带更明亮。")]
		"distant_galaxy":
			return [
				GameManager.text("A compact core sits inside a faint broad disc.", "致密核心位于暗弱宽盘之中。"),
				GameManager.text("The strongest signal shifts to longer bands.", "最强信号偏向更长波段。"),
				GameManager.text("Surface brightness falls smoothly outward.", "表面亮度向外平滑降低。")]
	return []


func _confirm_filter() -> void:
	if not model.mapping_complete():
		_say(GameManager.text("Assign a different filter to each of R, G and B first.", "请先给 R、G、B 各分配一个不同的滤镜。"), RED)
		InteractionFeedback.error(self)
		return
	if model.chosen_science == "":
		_say(GameManager.text("Choose the scientific interpretation.", "请选择科学解释。"), ORANGE)
		return
	if not model.science_correct():
		_say(GameManager.text("That interpretation does not match the structure this filter set reveals. Look again.",
			"该解释与这组滤镜显示的结构不符。请再观察。"), ORANGE)
		InteractionFeedback.error(self)
		return
	_log("FALSE-COLOUR COMPOSITE READY")
	_say(GameManager.text("Science image confirmed. Read the report.", "科学图像已确认。查看报告。"), GREEN)
	_advance()


# ============================================================ REPORT
func _build_report() -> void:
	var rep := model.report()
	_panel_to(content, Vector2(212, 8), Vector2(600, 480), PANEL, GOLD, GameManager.text("SCIENCE OBSERVATION REPORT", "科学观测报告"))
	var rows := [
		[GameManager.text("Signal-to-noise", "信噪比"), "%.1f" % float(rep["snr"])],
		[GameManager.text("Exposure quality", "曝光质量"), "%d%%" % int(float(rep["exposure_quality"]) * 100)],
		[GameManager.text("Pointing accuracy", "指向精度"), "%d%%" % int(float(rep["pointing_accuracy"]) * 100)],
		[GameManager.text("Thermal stability", "热稳定度"), "%d%%" % int(float(rep["thermal_stability"]) * 100)],
		[GameManager.text("Frame count", "帧数"), "%d" % int(rep["frame_count"])],
		[GameManager.text("Cosmic-ray rejection", "宇宙射线剔除"), "%d%%" % int(float(rep["cosmic_ray_rejection"]) * 100)],
		[GameManager.text("Instrument / filter", "仪器 / 滤镜"), "%s / %s" % [_opt_label("instrument", str(rep["instrument"])), _opt_label("filter", str(rep["filter"]))]],
		[GameManager.text("Scientific confidence", "科学置信度"), "%d%%" % int(float(rep["scientific_confidence"]) * 100)],
		[GameManager.text("Finding", "结论"), _science_label(str(rep["science_finding"]))],
	]
	var y := 52.0
	var reveal := create_tween().bind_node(self).set_parallel(true)
	for index in range(rows.size()):
		var row: Array = rows[index]
		var holder := Control.new()
		holder.name = "ReportRow_%02d" % index
		holder.position = Vector2(246, y)
		holder.size = Vector2(540, 28)
		holder.modulate.a = 0.0
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(holder)
		_label_to(holder, str(row[0]), Vector2(6, 0), Vector2(280, 24), 14, MUTED)
		_label_to(holder, str(row[1]), Vector2(294, 0), Vector2(240, 24), 14, TEXT)
		var pulse := ColorRect.new()
		pulse.color = Color(1, 1, 1, 0.22)
		pulse.position = Vector2(0, 25)
		pulse.size = Vector2(0, 1)
		pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pulse)
		var delay := float(index) * 0.075
		reveal.tween_property(holder, "modulate:a", 1.0, 0.16).set_delay(delay)
		reveal.tween_property(holder, "position:x", 252.0, 0.18).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal.tween_property(pulse, "size:x", 534.0, 0.18).set_delay(delay)
		reveal.tween_property(pulse, "modulate:a", 0.0, 0.14).set_delay(delay + 0.15)
		y += 38.0
	var submit := _button(GameManager.text("Submit Report", "提交报告"), Vector2(392, 430), Vector2(240, 46), Color("175238"))
	submit.modulate.a = 0.28
	submit.pressed.connect(_submit)
	content.add_child(submit)
	reveal.tween_property(submit, "modulate:a", 1.0, 0.22).set_delay(float(rows.size()) * 0.075)
	_log_line("REPORT TELEMETRY", "DECODE", "%02d FIELDS" % rows.size())


func _submit() -> void:
	if running:
		return
	running = true
	var rep := model.report()
	var observation := {
		"success": true, "quality": _quality(float(rep["snr"])),
		"clarity": clampf(float(rep["snr"]) * 3.0, 0.0, 100.0),
		"contrast": clampf(float(rep["scientific_confidence"]) * 100.0, 0.0, 100.0),
		"detail": clampf(float(rep["thermal_stability"]) * 100.0, 0.0, 100.0),
		"snr": float(rep["snr"]), "observation_mode": "space_infrared",
		"instrument": rep["instrument"], "filter": rep["filter"],
		"science_finding": rep["science_finding"],
		"feedback_en": "Infrared science image confirmed the target's structure.",
		"feedback_zh": "红外科学图像确认了目标的结构。",
	}
	_power_down(func() -> void:
		GameManager.complete_current_mission(GameManager.current_target_object_id(), observation),
		true)


func _quality(v: float) -> String:
	if v >= 24.0: return "Excellent"
	if v >= 16.0: return "Good"
	if v >= 10.0: return "Fair"
	return "Poor"


func _space_operation_chain(action_text: String, effect_text: String, reveal_text: String) -> void:
	var chain := InteractionFeedback.operation_chain(
		self,
		action_text,
		effect_text,
		reveal_text,
		null,
		CYAN,
		2.7
	)
	if chain != null:
		chain.position.y = 538.0


func _space_processing_chain_copy(step_id: String, before_snr: float, after_snr: float) -> Array[String]:
	match step_id:
		"align":
			return [
				GameManager.text("Aligned retained frames", "对齐保留的数据帧"),
				GameManager.text("Stars landed on the same detector coordinates", "恒星落到相同探测器坐标"),
				GameManager.text("Real structure stopped doubling", "真实结构不再出现重影"),
			]
		"cosmic":
			return [
				GameManager.text("Removed cosmic-ray events", "移除宇宙射线事件"),
				GameManager.text("Transient streaks and hot pixels were rejected", "瞬态亮痕与热像素被剔除"),
				GameManager.text("Persistent target detail remained", "持续存在的目标细节被保留下来"),
			]
		"background":
			return [
				GameManager.text("Subtracted the infrared background", "扣除红外背景"),
				GameManager.text("The noise floor fell from the photon stack", "光子堆栈的噪声底下降"),
				GameManager.text("Faint outer structure separated from the sky", "微弱外围结构从天空背景中分离"),
			]
		"stack":
			return [
				GameManager.text("Stacked the clean exposures", "堆叠干净曝光帧"),
				GameManager.text("SNR rose from %.1f to %.1f" % [before_snr, after_snr], "信噪比从 %.1f 提升到 %.1f" % [before_snr, after_snr]),
				GameManager.text("The science image gained stable depth", "科学图像获得了稳定的深层细节"),
			]
	return [
		GameManager.text("Processed one detector stage", "完成一个探测器处理步骤"),
		GameManager.text("Image data and telemetry became more consistent", "图像数据与遥测结果更加一致"),
		GameManager.text("The next processing decision is now available", "下一个处理决策现已可用"),
	]


# ============================================================ helpers
func _slider_row(title: String, pos: Vector2, lo: float, hi: float, value: float, changed: Callable) -> void:
	_slider_row_to(content, title, pos, lo, hi, value, changed)


func _slider_row_to(parent: Control, title: String, pos: Vector2, lo: float, hi: float, value: float, changed: Callable) -> void:
	_label_to(parent, title, pos, Vector2(300, 18), 13, GOLD)
	var s := HSlider.new()
	s.position = pos + Vector2(0, 24)
	s.size = Vector2(300, 20)
	s.min_value = lo; s.max_value = hi; s.step = (hi - lo) / 200.0; s.value = value
	s.value_changed.connect(changed)
	parent.add_child(s)


func _int_row(title: String, pos: Vector2, lo: int, hi: int, value: int, changed: Callable) -> void:
	_label_to(content, title + ": " + str(value), pos, Vector2(300, 18), 13, GOLD).name = "IntLabel"
	var minus := _button("-", pos + Vector2(0, 24), Vector2(40, 30), Color("143247"))
	minus.pressed.connect(func() -> void: changed.call(maxi(lo, value - 1)); _build_stage())
	content.add_child(minus)
	var plus := _button("+", pos + Vector2(48, 24), Vector2(40, 30), Color("143247"))
	plus.pressed.connect(func() -> void: changed.call(mini(hi, value + 1)); _build_stage())
	content.add_child(plus)


func lerp_color(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))


func _hexes(parent: Control, center: Vector2, r: float, full: bool) -> void:
	var coords := [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1], [1, -1], [-1, 1]] if full else [[0, 0], [1, 0], [-1, 0]]
	var w := r * sqrt(3.0)
	for c in coords:
		var cx: float = center.x + w * (c[0] + c[1] / 2.0)
		var cy: float = center.y + r * 1.5 * c[1]
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color("e8c65a") if full else Color("6a5a2a")
		for i in range(7):
			var a := PI / 6.0 + i * PI / 3.0
			line.add_point(Vector2(cx + cos(a) * r, cy + sin(a) * r))
		parent.add_child(line)


func _ring_to(parent: Control, center: Vector2, radius: float, color: Color) -> void:
	var node := Line2D.new()
	node.width = 2.5
	node.default_color = color
	for i in range(25):
		var a := TAU * float(i) / 24.0
		node.add_point(center + Vector2(cos(a), sin(a)) * radius)
	parent.add_child(node)


func _line_to(parent: Control, a: Vector2, b: Vector2, color: Color) -> void:
	var node := Line2D.new()
	node.width = 2.0
	node.default_color = color
	node.add_point(a); node.add_point(b)
	parent.add_child(node)


func _rect_to(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos; r.size = size; r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	return _panel_to(self, pos, size_value, fill, border, "")


func _panel_to(parent: Control, pos: Vector2, size_value: Vector2, fill: Color, border: Color, title: String) -> Panel:
	# Monochrome instrument bay: a hairline rule, dark well, and corner ticks like
	# a machine faceplate. No coloured slabs.
	var panel := Panel.new()
	panel.position = pos; panel.size = size_value
	panel.add_theme_stylebox_override("panel", _flat(PANEL, P_MID, 1))
	parent.add_child(panel)
	var tick := 12.0
	for corner in [Vector2(0, 0), Vector2(size_value.x, 0), Vector2(0, size_value.y), Vector2(size_value.x, size_value.y)]:
		var sx: float = -1.0 if corner.x > 0.0 else 1.0
		var sy: float = -1.0 if corner.y > 0.0 else 1.0
		_rect_to(panel, Vector2(corner.x + (0.0 if sx > 0.0 else -tick), corner.y + (0.0 if sy > 0.0 else -2.0)), Vector2(tick, 2), P_BRIGHT)
		_rect_to(panel, Vector2(corner.x + (0.0 if sx > 0.0 else -2.0), corner.y + (0.0 if sy > 0.0 else -tick)), Vector2(2, tick), P_BRIGHT)
	if title != "":
		# heading sits on a ruled line, printed like a section header
		_label_to(panel, title.to_upper(), Vector2(0, 7), Vector2(size_value.x, 22), 14, P_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
		_rect_to(panel, Vector2(10, 32), Vector2(size_value.x - 20, 1), P_FAINT)
	return panel


func _flat(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill; style.border_color = border
	style.set_border_width_all(width); style.set_corner_radius_all(0)
	return style


func _label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label_to(self, value, pos, size_value, font_size, color, alignment)


func _label_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value; label.position = pos; label.size = size_value
	label.horizontal_alignment = alignment; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	# One monochrome control style. `color` is now read only as an EMPHASIS hint:
	# anything that used to be the green "go" colour becomes the inverted
	# (filled-white) primary control; everything else is an outline control.
	# Legacy callers still pass their old semantic tint. Only the old green
	# action colour is primary; navy/blue choices often also have G > R, so they
	# must additionally be greener than blue and sufficiently bright.
	var primary := color.g > color.b and color.g > color.r * 1.35 and color.g > 0.25
	var button := Button.new()
	button.text = value; button.position = pos; button.size = size_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	if primary:
		button.add_theme_stylebox_override("normal", _flat(P_BRIGHT, P_HOT, 1))
		button.add_theme_stylebox_override("hover", _flat(P_HOT, P_HOT, 2))
		button.add_theme_stylebox_override("pressed", _flat(P_MID, P_HOT, 2))
		button.add_theme_color_override("font_color", BG)
		button.add_theme_color_override("font_hover_color", BG)
		button.add_theme_color_override("font_pressed_color", BG)
	else:
		button.add_theme_stylebox_override("normal", _flat(Color("101010"), P_MID, 1))
		button.add_theme_stylebox_override("hover", _flat(Color("1e1e1e"), P_HOT, 2))
		button.add_theme_stylebox_override("pressed", _flat(P_BRIGHT, P_HOT, 2))
		button.add_theme_color_override("font_color", P_BRIGHT)
		button.add_theme_color_override("font_hover_color", P_HOT)
		button.add_theme_color_override("font_pressed_color", BG)
	button.add_theme_stylebox_override("disabled", _flat(Color("0a0a0a"), P_FAINT, 1))
	button.add_theme_color_override("font_disabled_color", P_DIM)
	# Every press makes the console react - this is the "the machine is doing
	# what I told it" feedback. Connected FIRST so it fires before the specific
	# handler (which may rebuild the stage and re-render the log).
	button.pressed.connect(_emit_button.bind(value))
	return button


# Turn a button label into a plausible command line the console prints back.
func _emit_button(label: String) -> void:
	var t := label.strip_edges()
	if t == "" or t == "-" or t == "+" or t.begins_with("✓") or t.length() > 30:
		return
	var code := "CMD %s" % t.to_upper()
	var lower := t.to_lower()
	if lower.contains("confirm") or lower.contains("确认") or lower.contains("complete") or lower.contains("完成"):
		code = "COMMIT %s" % t.to_upper()
	elif lower.contains("start") or lower.contains("开始") or lower.contains("generate") or lower.contains("生成"):
		code = "EXEC %s" % t.to_upper()
	elif lower.contains("submit") or lower.contains("提交"):
		code = "UPLINK REPORT"
	elif lower.contains("back") or lower.contains("返回"):
		return
	_log_line(code, "OK")
