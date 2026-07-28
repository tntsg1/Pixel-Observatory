extends Control

# FAST remains a five-stage radio pipeline. The pure RadioSignalModel owns all
# scientific state; this screen turns that state into a physical control-room
# experience without introducing optical-telescope concepts.

const FAST_CRT_SHADER := preload("res://shaders/fast_crt_monitor.gdshader")
const StageHandoffTransitionScript := preload("res://scripts/ui/stage_handoff_transition.gd")
const BG := Color("010203")
const PANEL := Color("090b0d")
const PANEL_DEEP := Color("030506")
const GOLD := Color("d8d9d4")
const BRASS := Color("69706e")
const CYAN := Color("c7d7d8")
const CRT := Color("d6dbd8")
const GREEN := Color("86aa8d")
const AMBER := Color("b5a06e")
const RED := Color("a66f67")
const TEXT := Color("ecece7")
const MUTED := Color("858b89")
const STAGE_KEYS := ["aim", "tune", "rfi", "fold", "report"]
const SIMULATED_INTEGRATION_RATE := 42.0
const WATERFALL_ROWS := 24
const TERMINAL_HISTORY_LINES := 6
const IDLE_HINT_DELAY := 20.0
const FAST_TUTORIAL_PREFIX := "fast_guided_stage_"
const RADIO_CONSOLE_BOOT_DURATION := 0.92
const RADIO_CONSOLE_BOOT_DURATION_REDUCED := 0.64
const RADIO_CONSOLE_SHUTDOWN_DURATION := 1.62
const RADIO_CONSOLE_SHUTDOWN_DURATION_REDUCED := 1.08
const FAST_MAX_ZENITH_ANGLE_DEG := 40.0
const ACQUISITION_COARSE_TOLERANCE_DEG := 7.5
const ACQUISITION_FINE_TOLERANCE_DEG := 1.4
const ACQUISITION_FINE_SPEED_DEG_S := 0.42
const ACQUISITION_MAX_SPEED_DEG_S := 8.0
const FOLD_ADJUST_IDLE_SECONDS := 0.10
const FOLD_VALIDATION_WINDOW_SECONDS := 0.46
const FOLD_STABLE_WINDOWS_REQUIRED := 3
const REPORT_ANALYSIS_DURATION := 4.2
const REPORT_ANALYSIS_SKIP_DELAY := 1.0
const FAST_TAKEOVER_ARRAY_RECT := Rect2(30, 138, 900, 344)
const FAST_TAKEOVER_STATUS_RECT := Rect2(94, 504, 772, 118)

static var _array_takeover_seen_this_session := false


class RadioPlot:
	extends Control
	var renderer: Callable

	func _draw() -> void:
		if renderer.is_valid():
			renderer.call(self)


var model: RadioSignalModel
var profile: Dictionary = {}
var stage := 0
var running := false
var discovery_running := false
var intro_running := false
var intro_progress := 0.0
var intro_overlay: Panel
var intro_plot: RadioPlot
var intro_underlay_visibility: Dictionary = {}
var objective_label: Label
var crt_glass: ColorRect
var terminal_panel: Panel
var terminal_label: Label
var terminal_log: Array[String] = []
var terminal_clock := 0.0
var terminal_last_events: Dictionary = {}
var terminal_emphasis_until := 0.0
var last_input_drive := Vector2.ZERO
var last_input_brake := false
var last_aim_disturbance_active := false

var status_label: Label
var readout: Label
var scope: RadioPlot
var stage_bar_holder: Control
var content: Control
var stage_transition = StageHandoffTransitionScript.new()
var stage_transition_active := false
var stage_handoff_snapshot: Dictionary = {}
var stage_handoff_summary := ""
var stage_transition_duration := 0.0

var drive_vector := Vector2.ZERO
var drive_braking := false
var aim_trail: Array[Vector2] = []
var aim_lamp: Panel
var lock_button: Button

var tune_drag_mode := ""
var tune_log_label: Label
var tune_waterfall: Array = []
var waterfall_clock := 0.0
var waterfall_phase := 0.0

var selected_peak := -1
var rfi_evidence_label: Label
var rfi_waterfall: Array = []
var rfi_keep_button: Button
var rfi_reject_button: Button
var rfi_verify_button: Button
var rfi_restore_button: Button
var rfi_last_decision := ""
var rfi_tutorial_panel: Panel
var rfi_tutorial_label: Label
var rfi_tutorial_next: Button
var rfi_tutorial_step := 0

var fold_step := 0
var fold_slider: HSlider
var fold_phase_slider: HSlider
var fold_action_button: Button
var fold_confirm_button: Button
var integration_held := false
var fold_adjust_audio_idle := -1.0
var fold_step_label: Label
var fold_controls_panel: Panel
var fold_drag_mode := ""
var fold_drag_last := Vector2.ZERO
var fold_validation_clock := 0.0
var fold_validation_window_index := 0
var fold_stable_windows := 0
var fold_candidate_ready := false
var fold_profile_history: Array = []
var fold_last_peak_phase := -1.0
var prediction_running := false
var prediction_armed := false
var prediction_confirmed := false
var prediction_time_left := 0.0
var prediction_duration := 7.0
var prediction_misses := 0
var prediction_overlay: Panel
var prediction_plot: RadioPlot
var prediction_countdown_label: Label
var prediction_state_label: Label
var prediction_arm_button: Button

var report_choice := ""
var report_choice_buttons: Dictionary = {}
var submit_button: Button
var report_product: Dictionary = {}
var report_product_plot: RadioPlot
var report_analysis_progress := 0.0
var report_analysis_elapsed := 0.0
var report_analysis_phase := -1
var report_analysis_running := false
var report_analysis_status: Label
var report_analysis_skip_button: Button
var report_evidence_label: Label
var report_reanalyse_button: Button
var report_next_target_button: Button
var report_choose_next_requested := false
var aim_capture_progress := 0.0
var aim_capture_state := ""
var discovery_phase := 0.0
var discovery_plot: RadioPlot
var discovery_event_trace: Array[String] = []

var tutorial_steps: Array[Dictionary] = []
var tutorial_step := -1
var tutorial_waiting_action := ""
var tutorial_action_complete := false
var tutorial_frame: Panel
var tutorial_next_button: Button
var tutorial_mode_button: Button
var tutorial_help_button: Button
var tutorial_target: Control
var tutorial_idle_seconds := 0.0
var tutorial_idle_tier := 0
var tutorial_active := false
var console_shutdown_active := false

var aim_drive_panel: Control
var aim_brake_button: Button
var tune_controls_panel: Control
var tune_confirm_button: Button
var report_panel_ref: Control
var report_choices_holder: Control

var acquisition_required := false
var acquisition_active := false
var acquisition_completed := false
var acquisition_state := "search"
var acquisition_azimuth := 0.0
var acquisition_altitude := 70.0
var acquisition_velocity := Vector2.ZERO
var acquisition_drive_vector := Vector2.ZERO
var acquisition_braking := false
var acquisition_dragging := false
var acquisition_scope: RadioPlot
var acquisition_readout: Label
var acquisition_lock_button: Button
var acquisition_brake_button: Button
var acquisition_guide: Control
var acquisition_boundary_warning := ""
var acquisition_transition_pending := false
var acquisition_entries: Array[Dictionary] = []
var acquisition_candidate_id := ""


func _ready() -> void:
	profile = _profile()
	model = RadioSignalModel.new()
	model.configure(profile)
	_initialize_target_acquisition()
	GameManager.language_changed.connect(_rebuild)
	set_process(true)
	_rebuild()
	InteractionFeedback.page_enter(self)
	_radio_console_boot()


func _exit_tree() -> void:
	stage_transition.abort()
	_stop_tune_ratchet(0.0)
	_stop_fold_adjust_audio(0.0)
	report_analysis_running = false


static func fast_zenith_angle(altitude_deg: float) -> float:
	return 90.0 - altitude_deg


static func acquisition_direction_reachable(altitude_deg: float) -> bool:
	return fast_zenith_angle(altitude_deg) <= FAST_MAX_ZENITH_ANGLE_DEG + 0.001


func _initialize_target_acquisition() -> void:
	acquisition_required = GameManager.is_remote_free_observation("radio")
	acquisition_active = acquisition_required
	acquisition_completed = not acquisition_required
	acquisition_entries = _radio_acquisition_entries()
	acquisition_state = "search"
	acquisition_transition_pending = false
	var seed_entry := _active_radio_acquisition_entry()
	if seed_entry.is_empty() and not acquisition_entries.is_empty():
		seed_entry = acquisition_entries[0]
	var target_altitude := float(seed_entry.get("altitude", model.true_altitude))
	var target_azimuth := float(seed_entry.get("azimuth", model.true_azimuth))
	acquisition_azimuth = wrapf(target_azimuth + 18.0, 0.0, 360.0)
	acquisition_altitude = clampf(target_altitude + 9.0, 50.0, 88.0)
	acquisition_candidate_id = str(seed_entry.get("id", ""))
	acquisition_velocity = Vector2.ZERO
	acquisition_drive_vector = Vector2.ZERO
	acquisition_braking = false
	acquisition_boundary_warning = ""


func _radio_acquisition_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value in GameManager.remote_free_catalog("radio"):
		if not value is Dictionary:
			continue
		var catalog_entry := (value as Dictionary).duplicate(true)
		var entry_profile: Dictionary = catalog_entry.get("profile", {})
		catalog_entry["azimuth"] = wrapf(float(entry_profile.get("azimuth", 0.0)), 0.0, 360.0)
		catalog_entry["altitude"] = clampf(float(entry_profile.get("altitude", 0.0)), 0.0, 90.0)
		catalog_entry["center_mhz"] = float(entry_profile.get("center_mhz", 0.0))
		catalog_entry["bandwidth_mhz"] = float(entry_profile.get("bandwidth_mhz", 0.0))
		catalog_entry["reachable"] = acquisition_direction_reachable(float(catalog_entry["altitude"]))
		result.append(catalog_entry)
	return result


func _active_radio_acquisition_entry() -> Dictionary:
	var active_id := str(GameManager.active_remote_free_entry("radio").get("id", ""))
	for entry in acquisition_entries:
		if str(entry.get("id", "")) == active_id:
			return entry
	return {}


func _acquisition_entry(entry_id: String) -> Dictionary:
	for entry in acquisition_entries:
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _nearest_acquisition_entry() -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_error := INF
	for entry in acquisition_entries:
		var az_error := wrapf(acquisition_azimuth - float(entry.get("azimuth", 0.0)), -180.0, 180.0)
		var projected_az_error := az_error * cos(deg_to_rad(float(entry.get("altitude", 0.0))))
		var error := Vector2(
			projected_az_error,
			acquisition_altitude - float(entry.get("altitude", 0.0))
		).length()
		if error < nearest_error:
			nearest_error = error
			nearest = entry
	return nearest


func _selected_acquisition_entry() -> Dictionary:
	var entry := _acquisition_entry(acquisition_candidate_id)
	if entry.is_empty():
		entry = _nearest_acquisition_entry()
	return entry


func _radio_console_boot() -> void:
	var reduced := InteractionFeedback.is_reduced_motion()
	var total_duration := (
		RADIO_CONSOLE_BOOT_DURATION_REDUCED
		if reduced else RADIO_CONSOLE_BOOT_DURATION)
	var overlay := Control.new()
	overlay.name = "FastConsoleBoot"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1300
	overlay.set_meta("transition_duration", total_duration)
	add_child(overlay)

	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cover)
	var scan := ColorRect.new()
	scan.color = Color(CRT, 0.86)
	scan.position = Vector2(512, 383)
	scan.size = Vector2(0, 2)
	overlay.add_child(scan)
	var status := Label.new()
	status.position = Vector2(246, 418)
	status.size = Vector2(532, 30)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", CRT)
	status.text = GameManager.text("RECEIVER CONSOLE  ·  WARMING CRT", "接收机控制台  ·  显像管预热")
	overlay.add_child(status)

	var line_time := total_duration * 0.28
	var unfold_time := total_duration * 0.46
	var settle_time := total_duration * 0.26
	var tween := create_tween().bind_node(overlay)
	tween.tween_property(scan, "position:x", 0.0, line_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(scan, "size:x", 1024.0, line_time)
	tween.tween_callback(func() -> void:
		status.text = GameManager.text("ARRAY LINK  ·  SYNCHRONISING", "阵列链路  ·  正在同步"))
	tween.tween_property(scan, "position:y", 0.0, unfold_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(scan, "size:y", 768.0, unfold_time)
	tween.parallel().tween_property(cover, "modulate:a", 0.16, unfold_time)
	tween.tween_callback(func() -> void:
		status.text = GameManager.text("FAST CONTROL  ·  READY", "FAST 控制系统  ·  就绪"))
	tween.tween_property(cover, "modulate:a", 0.0, settle_time)
	tween.parallel().tween_property(scan, "modulate:a", 0.0, settle_time)
	tween.parallel().tween_property(status, "modulate:a", 0.0, settle_time)
	tween.tween_callback(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
		call_deferred("_maybe_play_array_takeover"))


func _radio_console_power_down() -> void:
	if console_shutdown_active:
		return
	_stop_tune_ratchet()
	console_shutdown_active = true
	running = true
	var reduced := InteractionFeedback.is_reduced_motion()
	var total_duration := (
		RADIO_CONSOLE_SHUTDOWN_DURATION_REDUCED
		if reduced else RADIO_CONSOLE_SHUTDOWN_DURATION)
	var overlay := Control.new()
	overlay.name = "FastConsoleShutdown"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1300
	overlay.set_meta("transition_duration", total_duration)
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var status := Label.new()
	status.position = Vector2(244, 346)
	status.size = Vector2(536, 32)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", CRT)
	status.text = GameManager.text("RECEIVER CHAIN  ·  SAFE", "接收链路  ·  已保护")
	overlay.add_child(status)
	var scan := ColorRect.new()
	scan.color = Color(CRT, 0.82)
	scan.position = Vector2(0, 383)
	scan.size = Vector2(1024, 2)
	overlay.add_child(scan)
	var top := ColorRect.new()
	top.color = Color.BLACK
	top.position = Vector2.ZERO
	top.size = Vector2(1024, 0)
	overlay.add_child(top)
	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.position = Vector2(0, 768)
	bottom.size = Vector2(1024, 0)
	overlay.add_child(bottom)
	status.move_to_front()

	var first_time := total_duration * 0.28
	var close_time := total_duration * 0.46
	var dot_time := total_duration * 0.26
	var tween := create_tween().bind_node(overlay)
	tween.tween_property(dim, "color:a", 0.48, first_time)
	tween.tween_callback(func() -> void:
		status.text = GameManager.text("ARRAY CONTROL  ·  RELEASED", "阵列控制权  ·  已释放"))
	tween.tween_property(top, "size:y", 382.0, close_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(bottom, "position:y", 386.0, close_time)
	tween.parallel().tween_property(bottom, "size:y", 382.0, close_time)
	tween.tween_callback(func() -> void:
		status.text = GameManager.text("REMOTE LINK  ·  CLOSED", "远程链路  ·  已关闭"))
	tween.tween_property(scan, "position:x", 510.0, dot_time)
	tween.parallel().tween_property(scan, "size:x", 4.0, dot_time)
	tween.parallel().tween_property(status, "modulate:a", 0.0, dot_time)
	tween.tween_callback(func() -> void:
		GameManager.set_observatory_spawn("computer")
		GameManager.go("observatory"))


func _profile() -> Dictionary:
	if GameManager.is_remote_free_observation("radio"):
		var free_entry := GameManager.active_remote_free_entry("radio")
		var free_profile: Variant = free_entry.get("profile", {})
		if free_profile is Dictionary and not (free_profile as Dictionary).is_empty():
			var result := (free_profile as Dictionary).duplicate(true)
			result["free_observation"] = true
			result["catalog_entry_id"] = str(free_entry.get("id", ""))
			return result
	var level := GameManager.current_level()
	var value: Variant = level.get("radio_profile", {})
	if value is Dictionary and not (value as Dictionary).is_empty():
		return (value as Dictionary).duplicate(true)
	return {
		"target_id": GameManager.current_target_object_id(),
		"kind": "pulsar",
		"challenge": "balanced",
	}


func _process(delta: float) -> void:
	if model == null:
		return
	if report_analysis_running:
		_advance_report_analysis(delta)
	if tune_drag_mode != "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		tune_drag_mode = ""
		_stop_tune_ratchet()
	if fold_drag_mode != "" and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fold_drag_mode = ""
		_stop_fold_adjust_audio()
	if fold_adjust_audio_idle >= 0.0:
		fold_adjust_audio_idle += delta
		if fold_adjust_audio_idle >= FOLD_ADJUST_IDLE_SECONDS:
			_stop_fold_adjust_audio()
	terminal_clock += delta
	if terminal_emphasis_until > 0.0 and terminal_clock >= terminal_emphasis_until:
		terminal_emphasis_until = 0.0
		if terminal_label != null and is_instance_valid(terminal_label):
			terminal_label.add_theme_color_override("font_color", CRT)
	if stage_transition_active:
		return
	if not intro_running and not discovery_running and not running:
		tutorial_idle_seconds += delta
		if tutorial_idle_seconds >= IDLE_HINT_DELAY:
			tutorial_idle_seconds = 0.0
			_show_progressive_idle_hint()
	_update_fast_crt()
	if intro_running:
		intro_progress = clampf(intro_progress + delta / 2.8, 0.0, 1.0)
		if intro_plot != null and is_instance_valid(intro_plot):
			intro_plot.queue_redraw()
		return
	if acquisition_active:
		_process_target_acquisition(delta)
		return
	if stage == 0 and not running:
		var keyboard_drive := _keyboard_drive()
		var active_drive := keyboard_drive if keyboard_drive != Vector2.ZERO else drive_vector
		var brake_active := drive_braking or Input.is_key_pressed(KEY_SPACE)
		if active_drive != last_input_drive:
			if active_drive != Vector2.ZERO:
				_terminal_event("FEED CABIN DRIVE", "RUN", _drive_direction_name(active_drive))
				_note_player_activity()
				_tutorial_action("aim_drive")
			elif last_input_drive != Vector2.ZERO:
				_terminal_event("FEED CABIN DRIVE", "COAST")
			last_input_drive = active_drive
		if brake_active != last_input_brake:
			_terminal_event("INERTIAL BRAKE", "HOLD" if brake_active else "RELEASE")
			if brake_active:
				_note_player_activity()
				_tutorial_action("aim_brake")
			last_input_brake = brake_active
		if active_drive != Vector2.ZERO:
			model.nudge(active_drive.x, -active_drive.y, delta * 6.2)
		if brake_active:
			model.brake(delta * 7.0)
		model.step(delta)
		var disturbance_active := model.aim_disturbance_active()
		if disturbance_active and not last_aim_disturbance_active:
			_terminal_event("CABLE LOAD PULSE", "DAMPING", "NEXT IN %.0f s" % model.aim_disturbance_interval_s)
			InteractionFeedback.feedback_sfx_requested.emit("fast_cable_settle")
		last_aim_disturbance_active = disturbance_active
		_record_aim_trail()
		_refresh_aim()
	if prediction_running:
		prediction_time_left = maxf(0.0, prediction_time_left - delta)
		_refresh_prediction_capture()
		if prediction_time_left <= 0.0:
			_resolve_prediction_window()
		return
	elif stage == 3 and integration_held and not discovery_running:
		var integration_rate := maxf(SIMULATED_INTEGRATION_RATE, model.required_integration_s / 1.6)
		model.set_integration(model.integration_s + delta * integration_rate)
		fold_validation_clock += delta
		if fold_validation_clock >= FOLD_VALIDATION_WINDOW_SECONDS:
			fold_validation_clock = fmod(fold_validation_clock, FOLD_VALIDATION_WINDOW_SECONDS)
			_record_fold_validation_window()
		_terminal_event(
			"PULSE INTEGRATION",
			"ACCUMULATE",
			"SNR %.1f  WINDOW %d/%d" % [
				model.fold_snr(),
				fold_stable_windows,
				FOLD_STABLE_WINDOWS_REQUIRED,
			],
			"fold_integrate",
			0.75
		)
		_note_player_activity()
		if model.integration_s >= minf(20.0, model.required_integration_s * 0.2):
			_tutorial_action("fold_integrate")
		_refresh_fold()
	elif stage in [1, 2] and not running:
		waterfall_clock += delta
		if waterfall_clock >= 0.14:
			waterfall_clock = 0.0
			waterfall_phase += 1.0
			_capture_waterfall_row(tune_waterfall if stage == 1 else rfi_waterfall, stage == 2)
			if scope != null and is_instance_valid(scope):
				scope.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if running or discovery_running or intro_running or stage_transition_active:
		return
	if acquisition_active:
		if event is InputEventKey:
			var acquisition_key := event as InputEventKey
			if acquisition_key.keycode == KEY_SPACE:
				if acquisition_key.pressed:
					_note_player_activity()
				get_viewport().set_input_as_handled()
				return
			if acquisition_key.pressed and not acquisition_key.echo:
				if acquisition_key.keycode == KEY_ENTER:
					_attempt_acquisition_lock()
					get_viewport().set_input_as_handled()
					return
				if acquisition_key.keycode == KEY_R:
					_reset_target_acquisition()
					get_viewport().set_input_as_handled()
					return
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if prediction_running and key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ENTER]:
			_arm_prediction_receiver()
			get_viewport().set_input_as_handled()
			return
		if key.keycode == KEY_SPACE and stage == 3:
			integration_held = key.pressed
			_terminal_event(
				"PULSE INTEGRATION",
				"ACCUMULATE" if key.pressed else "HOLD",
				"%.0f s" % model.integration_s
			)
			get_viewport().set_input_as_handled()
			return
		if not key.pressed or key.echo:
			return
		match stage:
			0:
				if key.keycode == KEY_ENTER:
					_try_lock()
			1:
				_tune_keyboard(key.keycode)
			2:
				_rfi_keyboard(key.keycode)
			3:
				_fold_keyboard(key.keycode)


func _keyboard_drive() -> Vector2:
	if stage != 0:
		return Vector2.ZERO
	var value := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		value.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		value.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		value.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		value.y += 1.0
	return value.normalized()


func _keyboard_acquisition_drive() -> Vector2:
	var value := Vector2.ZERO
	if (
		InputMap.has_action("move_left")
		and InputMap.has_action("move_right")
		and InputMap.has_action("move_up")
		and InputMap.has_action("move_down")
	):
		value += Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		value.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		value.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		value.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		value.y += 1.0
	return value.normalized()


func _process_target_acquisition(delta: float) -> void:
	var keyboard_drive := _keyboard_acquisition_drive()
	var active_drive := keyboard_drive if keyboard_drive != Vector2.ZERO else acquisition_drive_vector
	var brake_active := Input.is_key_pressed(KEY_SPACE) or acquisition_braking
	_step_target_acquisition(active_drive, brake_active, delta)


func _step_target_acquisition(input_vector: Vector2, brake_active: bool, delta: float) -> void:
	if not acquisition_active or acquisition_state == "locked":
		return
	var response_scale := 0.46 if acquisition_state == "coarse" else 1.0
	var acceleration := 11.5 * response_scale
	acquisition_velocity.x += input_vector.x * acceleration * delta
	acquisition_velocity.y += -input_vector.y * acceleration * delta
	acquisition_velocity = acquisition_velocity.limit_length(ACQUISITION_MAX_SPEED_DEG_S * response_scale)
	if brake_active:
		acquisition_velocity = acquisition_velocity.move_toward(Vector2.ZERO, 18.0 * delta)
	else:
		acquisition_velocity *= pow(0.38, delta)
	acquisition_azimuth = wrapf(acquisition_azimuth + acquisition_velocity.x * delta, 0.0, 360.0)
	var next_altitude := acquisition_altitude + acquisition_velocity.y * delta
	if next_altitude < 50.0:
		acquisition_altitude = 50.0
		acquisition_velocity.y = maxf(0.0, acquisition_velocity.y)
		acquisition_boundary_warning = GameManager.text(
			"40° zenith-angle boundary reached. Choose a source inside the FAST sky window.",
			"已到达 40° 天顶角边界。请选择 FAST 可达天区内的射电源。"
		)
	else:
		acquisition_altitude = clampf(next_altitude, 50.0, 88.0)
		if acquisition_boundary_warning != "" and input_vector.y <= 0.0:
			acquisition_boundary_warning = ""
	if input_vector != Vector2.ZERO or brake_active:
		_note_player_activity()
	var nearest := _nearest_acquisition_entry()
	acquisition_candidate_id = str(nearest.get("id", "")) if not nearest.is_empty() else ""
	_refresh_target_acquisition()


func _acquisition_pointing_error() -> float:
	var entry := _selected_acquisition_entry()
	if entry.is_empty():
		return INF
	var target_altitude := float(entry.get("altitude", 0.0))
	var az_error := wrapf(acquisition_azimuth - float(entry.get("azimuth", 0.0)), -180.0, 180.0)
	var projected_az_error := az_error * cos(deg_to_rad(target_altitude))
	return Vector2(projected_az_error, acquisition_altitude - target_altitude).length()


func _acquisition_speed() -> float:
	return acquisition_velocity.length()


func _acquisition_target_reachable() -> bool:
	var entry := _selected_acquisition_entry()
	return (
		not entry.is_empty()
		and acquisition_direction_reachable(float(entry.get("altitude", 0.0)))
	)


func _acquisition_can_coarse_lock() -> bool:
	return (
		_acquisition_target_reachable()
		and _acquisition_pointing_error() <= ACQUISITION_COARSE_TOLERANCE_DEG
		and _acquisition_speed() <= 2.2
	)


func _acquisition_can_fine_lock() -> bool:
	return (
		acquisition_state == "coarse"
		and _acquisition_pointing_error() <= ACQUISITION_FINE_TOLERANCE_DEG
		and _acquisition_speed() <= ACQUISITION_FINE_SPEED_DEG_S
	)


func _reset_target_acquisition() -> void:
	acquisition_state = "search"
	acquisition_completed = false
	acquisition_transition_pending = false
	var entry := _active_radio_acquisition_entry()
	if entry.is_empty():
		entry = _selected_acquisition_entry()
	acquisition_azimuth = wrapf(float(entry.get("azimuth", model.true_azimuth)) + 18.0, 0.0, 360.0)
	acquisition_altitude = clampf(float(entry.get("altitude", model.true_altitude)) + 9.0, 50.0, 88.0)
	acquisition_velocity = Vector2.ZERO
	acquisition_boundary_warning = ""
	_terminal_event("TARGET ACQUISITION", "RESET", str(model.target_id).to_upper())
	_refresh_target_acquisition()


func _drive_direction_name(value: Vector2) -> String:
	var horizontal := ""
	var vertical := ""
	if value.x < -0.1:
		horizontal = "WEST"
	elif value.x > 0.1:
		horizontal = "EAST"
	if value.y < -0.1:
		vertical = "NORTH"
	elif value.y > 0.1:
		vertical = "SOUTH"
	if horizontal != "" and vertical != "":
		return vertical + "-" + horizontal
	return horizontal if horizontal != "" else vertical


func _terminal_event(
	command: String,
	state: String,
	detail: String = "",
	throttle_key: String = "",
	min_interval: float = 0.0,
	important: bool = false
) -> void:
	var event_key := throttle_key if throttle_key != "" else "%s|%s|%s" % [command, state, detail]
	var last_time := float(terminal_last_events.get(event_key, -999.0))
	if terminal_clock - last_time < min_interval:
		return
	terminal_last_events[event_key] = terminal_clock
	var total_seconds := maxi(0, int(terminal_clock))
	var stamp := "T+%02d:%02d" % [total_seconds / 60, total_seconds % 60]
	var dot_count := maxi(2, 31 - command.length())
	var line := "%s  %s %s %s" % [stamp, command, ".".repeat(dot_count), state]
	if detail != "":
		line += "  " + detail
	terminal_log.append(line)
	while terminal_log.size() > TERMINAL_HISTORY_LINES:
		terminal_log.pop_front()
	if important:
		terminal_emphasis_until = terminal_clock + 0.75
	_refresh_terminal()


func _refresh_terminal() -> void:
	if terminal_label == null or not is_instance_valid(terminal_label):
		return
	terminal_label.text = "\n".join(terminal_log)
	terminal_label.add_theme_color_override(
		"font_color",
		GREEN if terminal_emphasis_until > terminal_clock else CRT
	)


func _fast_visual_instability() -> float:
	match stage:
		0:
			# A pointing error should not make the whole CRT shake forever. The
			# brief cable-load event is the only strong AIM-stage disturbance.
			if model.aim_disturbance_active():
				return 0.72
			return clampf(0.015 + model.pointing_speed() * 0.012, 0.015, 0.12)
		1:
			return clampf(0.18 + model.window_rfi_load() * 0.58 + (1.0 - model.tuning_quality()) * 0.28, 0.0, 1.0)
		2:
			var remaining := float(model.residual_rfi_count()) / float(maxi(1, model.rfi_peaks.size() - 1))
			return clampf(0.12 + remaining * 0.72 + (0.22 if model.source_deleted() else 0.0), 0.0, 1.0)
		3:
			if fold_step == 0:
				return clampf(0.85 - model.period_match() * 0.68, 0.08, 0.92)
			if fold_step == 1:
				return clampf(0.76 - model.dm_match() * 0.62, 0.08, 0.88)
			return clampf(0.64 - minf(model.fold_snr() / maxf(model.report_snr_threshold, 0.1), 1.0) * 0.56, 0.04, 0.72)
		_:
			return 0.03


func _update_fast_crt() -> void:
	if crt_glass == null or not is_instance_valid(crt_glass):
		return
	var material := crt_glass.material as ShaderMaterial
	if material == null:
		return
	var instability := _fast_visual_instability()
	var stable := 1.0 - instability
	material.set_shader_parameter("instability", instability)
	material.set_shader_parameter("lock_stability", stable)
	material.set_shader_parameter("flicker_strength", lerpf(0.002, 0.012, instability))
	material.set_shader_parameter("rolling_refresh", lerpf(0.016, 0.045, instability))


func _add_fast_crt_overlay() -> void:
	crt_glass = ColorRect.new()
	crt_glass.name = "FastCrtGlassOverlay"
	crt_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_glass.z_index = 1200
	var shader_material := ShaderMaterial.new()
	shader_material.shader = FAST_CRT_SHADER
	crt_glass.material = shader_material
	add_child(crt_glass)
	_update_fast_crt()


# ---------------------------------------------------------------- layout
func _rebuild() -> void:
	stage_transition.abort()
	stage_transition_active = false
	_stop_tune_ratchet(0.0)
	_stop_fold_adjust_audio(0.0)
	tune_drag_mode = ""
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel(Vector2.ZERO, Vector2(1024, 768), BG, BG)
	_panel(Vector2(14, 10), Vector2(996, 724), Color("030405"), BRASS)
	_label(GameManager.text("FAST RADIO OBSERVATION", "FAST 射电观测"), Vector2(24, 18), Vector2(976, 30), 23, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var target := GameManager.current_target()
	var free_entry := GameManager.active_remote_free_entry("radio")
	if acquisition_active:
		var acquisition_entry := _selected_acquisition_entry()
		if not acquisition_entry.is_empty():
			free_entry = acquisition_entry
	var target_name := (
		GameManager.text(str(free_entry.get("name_en", "")), str(free_entry.get("name_zh", "")))
		if not free_entry.is_empty()
		else GameManager.dict_text(target, "name"))
	_label(
		GameManager.text("Target: ", "目标：") + target_name
			+ "   ·   " + _challenge_title(),
		Vector2(24, 48), Vector2(976, 22), 13, CRT, HORIZONTAL_ALIGNMENT_CENTER
	)
	_build_stage_bar()
	objective_label = _label(
		_stage_objective(),
		Vector2(42, 108), Vector2(940, 24), 12, CYAN, HORIZONTAL_ALIGNMENT_CENTER
	)
	objective_label.add_theme_stylebox_override("normal", _flat(Color("030607"), Color("525a58"), 1))

	content = Control.new()
	content.position = Vector2(0, 128)
	content.size = Vector2(1024, 546)
	add_child(content)

	var terminal_bg := Panel.new()
	terminal_panel = terminal_bg
	terminal_bg.name = "FastEventTerminal"
	terminal_bg.position = Vector2(40, 614)
	terminal_bg.size = Vector2(750, 66)
	terminal_bg.clip_contents = true
	terminal_bg.add_theme_stylebox_override("panel", _flat(Color("020303"), Color("404645"), 1))
	terminal_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(terminal_bg)
	terminal_label = _label_to(terminal_bg, "", Vector2(12, 3), Vector2(726, 60), 9, CRT)
	terminal_label.name = "FastEventStream"
	terminal_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	terminal_label.clip_text = true
	if terminal_log.is_empty():
		_terminal_event("FAST ARRAY CONTROL", "ONLINE")
		_terminal_event("REAL-TIME RECEIVER", "READY")
	_refresh_terminal()

	status_label = _label("", Vector2(40, 684), Vector2(520, 42), 12, MUTED)
	status_label.name = "FastStatusLine"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.clip_text = true
	tutorial_next_button = _button(GameManager.text("NEXT", "下一步"), Vector2(570, 688), Vector2(104, 34), Color("183844"))
	tutorial_next_button.name = "FastTutorialNext"
	tutorial_next_button.visible = false
	tutorial_next_button.pressed.connect(_advance_fast_tutorial)
	add_child(tutorial_next_button)
	tutorial_mode_button = _button(GameManager.text("LESS GUIDE", "减少引导"), Vector2(680, 688), Vector2(112, 34), Color("242b31"))
	tutorial_mode_button.name = "FastTutorialLessGuide"
	tutorial_mode_button.visible = false
	tutorial_mode_button.pressed.connect(_disable_full_fast_tutorial)
	add_child(tutorial_mode_button)
	tutorial_help_button = _button(GameManager.text("HELP", "操作说明"), Vector2(680, 688), Vector2(112, 34), Color("172235"))
	tutorial_help_button.name = "FastTutorialReplay"
	tutorial_help_button.pressed.connect(_replay_stage_tutorial)
	add_child(tutorial_help_button)
	var back := _button(GameManager.text("Back", "返回"), Vector2(812, 686), Vector2(178, 38), Color("172235"))
	back.name = "FastBackButton"
	back.pressed.connect(_back)
	add_child(back)
	_build_stage()
	call_deferred("_configure_stage_guidance")
	_add_fast_crt_overlay()


func _stage_objective() -> String:
	if acquisition_active:
		return GameManager.text(
			"OBJECTIVE: STEER THE FAST BEAM THROUGH THE REACHABLE SKY, THEN COARSE- AND FINE-LOCK THE RADIO BEACON",
			"当前目标：在 FAST 可达天区内连续移动波束，依次完成射电信标的粗锁定与精锁定"
		)
	match STAGE_KEYS[stage]:
		"aim":
			return GameManager.text(
				"OBJECTIVE: DRIVE, BRAKE, AND SETTLE THE FEED CABIN INSIDE THE STABILITY RING",
				"当前目标：驱动并提前制动，让馈源舱稳定停在锁定环内"
			)
		"tune":
			return GameManager.text(
				"OBJECTIVE: PRESERVE THE BROAD CANDIDATE BAND WHILE REDUCING RFI LOAD",
				"当前目标：保留宽缓候选频段，同时降低射频干扰负载"
			)
		"rfi":
			return GameManager.text(
				"OBJECTIVE: REMOVE PATTERNED HUMAN RFI; PRESERVE THE REPEATING SKY CANDIDATE",
				"当前目标：剔除规律性人造干扰，保留重复出现的天体候选"
			)
		"fold":
			return GameManager.text(
				"OBJECTIVE: ALIGN PERIOD AND SUB-BANDS, THEN HOLD INTEGRATION UNTIL SNR IS CREDIBLE",
				"当前目标：对齐周期与子频段，再持续积分，直到信噪比可信"
			)
		_:
			return GameManager.text(
				"OBJECTIVE: SELECT THE CONCLUSION SUPPORTED BY THE RECORDED RADIO EVIDENCE",
				"当前目标：依据已记录的射电证据选择科学结论"
			)


func _challenge_title() -> String:
	match str(profile.get("challenge", "balanced")):
		"cabin_drift": return GameManager.text("Precision feed-cabin control", "馈源舱精密控制")
		"rfi_heavy": return GameManager.text("Severe interference night", "强干扰观测夜")
		"long_integration": return GameManager.text("Long-integration search", "长积分搜索")
		"dm_alignment": return GameManager.text("Dispersion alignment", "色散对齐")
		"weak_window": return GameManager.text("Weak-source frequency search", "微弱源频窗搜索")
		"discovery": return GameManager.text("Independent discovery session", "独立发现观测")
		"period_search": return GameManager.text("Pulse-period measurement", "脉冲周期测量")
		_: return GameManager.text("Commissioning the giant", "巨型设备联调")


func _maybe_play_array_takeover() -> void:
	if _array_takeover_seen_this_session:
		return
	_array_takeover_seen_this_session = true
	await _play_array_takeover()


func _play_array_takeover() -> void:
	if intro_running:
		return
	intro_running = true
	intro_progress = 0.0
	_hide_array_takeover_underlay()
	intro_overlay = Panel.new()
	intro_overlay.name = "FastArrayTakeover"
	intro_overlay.position = Vector2(14, 10)
	intro_overlay.size = Vector2(996, 724)
	intro_overlay.z_index = 980
	intro_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	intro_overlay.add_theme_stylebox_override("panel", _flat(Color("030910"), BRASS, 2))
	add_child(intro_overlay)

	intro_plot = RadioPlot.new()
	intro_plot.position = Vector2(18, 18)
	intro_plot.size = Vector2(960, 688)
	intro_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_plot.renderer = _draw_array_takeover
	intro_overlay.add_child(intro_plot)

	var skip := _button(GameManager.text("SKIP", "跳过"), Vector2(864, 654), Vector2(84, 28), Color("111d29"))
	skip.z_index = 4
	skip.pressed.connect(_finish_array_takeover)
	intro_overlay.add_child(skip)

	var duration := 2.8 if not InteractionFeedback.is_reduced_motion() else 0.72
	for _step in range(4):
		await get_tree().create_timer(duration / 5.0).timeout
		if not intro_running:
			return
		InteractionFeedback.feedback_sfx_requested.emit("fast_array_relay")
	await get_tree().create_timer(duration / 5.0).timeout
	_finish_array_takeover()


func _finish_array_takeover() -> void:
	if not intro_running:
		return
	intro_running = false
	if intro_overlay != null and is_instance_valid(intro_overlay):
		var overlay := intro_overlay
		intro_overlay = null
		intro_plot = null
		if InteractionFeedback.is_reduced_motion():
			overlay.queue_free()
			call_deferred("_restore_array_takeover_underlay")
		else:
			var exit := create_tween().bind_node(overlay)
			exit.tween_property(overlay, "modulate:a", 0.0, 0.18)
			exit.tween_callback(overlay.queue_free)
			exit.tween_callback(_restore_array_takeover_underlay)
	else:
		_restore_array_takeover_underlay()
	InteractionFeedback.feedback_sfx_requested.emit("fast_array_online")


func _hide_array_takeover_underlay() -> void:
	intro_underlay_visibility.clear()
	for child in get_children():
		if child is CanvasItem:
			var canvas_item := child as CanvasItem
			intro_underlay_visibility[canvas_item] = canvas_item.visible
			canvas_item.visible = false


func _restore_array_takeover_underlay() -> void:
	for item in intro_underlay_visibility:
		if is_instance_valid(item):
			(item as CanvasItem).visible = bool(intro_underlay_visibility[item])
	intro_underlay_visibility.clear()


func _takeover_layout_snapshot() -> Dictionary:
	return {
		"array_rect": FAST_TAKEOVER_ARRAY_RECT,
		"status_rect": FAST_TAKEOVER_STATUS_RECT,
		"status_text_rect": Rect2(
			FAST_TAKEOVER_STATUS_RECT.position + Vector2(30, 16),
			Vector2(676, 88)
		),
		"skip_rect": Rect2(864, 654, 84, 28),
	}


func _draw_array_takeover(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("02070d"), true)
	for i in range(90):
		var x := fposmod(float(i * 83 + 17), plot.size.x)
		var y := fposmod(float(i * 47 + 29), 300.0)
		var alpha := 0.16 + 0.28 * absf(sin(float(i) * 1.71))
		plot.draw_circle(Vector2(x, y), 0.8 + float(i % 3) * 0.35, Color(0.66, 0.78, 0.82, alpha))

	# The facility view and the status readout deliberately occupy separate
	# fixed bands. Keeping the dish inside this rectangle prevents its frame,
	# cables, or reflector grid from crossing the four status rows.
	plot.draw_rect(FAST_TAKEOVER_ARRAY_RECT, Color("020a11"), true)
	var horizon_y := 326.0
	var mountain_back := PackedVector2Array([
		Vector2(30, horizon_y + 14), Vector2(108, 274), Vector2(198, 314),
		Vector2(300, 246), Vector2(392, 304), Vector2(488, 236),
		Vector2(596, 304), Vector2(706, 260), Vector2(824, 308),
		Vector2(930, 266), Vector2(930, 438), Vector2(30, 438),
	])
	plot.draw_colored_polygon(mountain_back, Color("091620"))
	var mountain_front := PackedVector2Array([
		Vector2(30, 388), Vector2(136, 312), Vector2(242, 356),
		Vector2(352, 294), Vector2(464, 348), Vector2(582, 290),
		Vector2(704, 344), Vector2(820, 298), Vector2(930, 358),
		Vector2(930, 468), Vector2(30, 468),
	])
	plot.draw_colored_polygon(mountain_front, Color("0d1d28"))

	var dish_center := Vector2(480, 278)
	var dish_radius := 188.0
	var reveal := clampf((intro_progress - 0.05) / 0.58, 0.0, 1.0)
	var start_angle := PI * 0.10
	var end_angle := PI * 0.90
	var revealed_end := lerpf(start_angle, end_angle, reveal)
	for ring in range(7):
		var radius := dish_radius - float(ring) * 22.0
		plot.draw_arc(dish_center, radius, start_angle, revealed_end, 96, Color(CRT, 0.18 + ring * 0.025), 1.2, true)
	for spoke in range(19):
		var angle := lerpf(start_angle, end_angle, float(spoke) / 18.0)
		if angle > revealed_end:
			continue
		var outer := dish_center + Vector2(cos(angle), sin(angle)) * dish_radius
		var inner := dish_center + Vector2(cos(angle), sin(angle)) * 94.0
		plot.draw_line(inner, outer, Color(CRT, 0.17), 1.0)

	var cabin_alpha := clampf((intro_progress - 0.25) / 0.30, 0.0, 1.0)
	var cabin := Vector2(480, 248)
	var towers := [Vector2(216, 184), Vector2(744, 184), Vector2(154, 400), Vector2(806, 400)]
	for tower in towers:
		plot.draw_line(tower, cabin, Color(GOLD, cabin_alpha * 0.58), 1.4)
		plot.draw_circle(tower, 5.0, Color(BRASS, cabin_alpha))
	var cabin_shape := PackedVector2Array([
		cabin + Vector2(-20, -8), cabin + Vector2(18, -8),
		cabin + Vector2(24, 5), cabin + Vector2(12, 16),
		cabin + Vector2(-14, 16), cabin + Vector2(-24, 4),
	])
	plot.draw_colored_polygon(cabin_shape, Color(0.12, 0.23, 0.29, cabin_alpha))
	plot.draw_polyline(PackedVector2Array(Array(cabin_shape) + [cabin_shape[0]]), Color(CYAN, cabin_alpha), 2.0, true)
	plot.draw_rect(FAST_TAKEOVER_ARRAY_RECT, Color(CRT, 0.72), false, 2.0)

	_draw_plot_text(plot, GameManager.text("FAST ARRAY TAKEOVER", "FAST 阵列接管"), Vector2(34, 42), 24, GOLD)
	_draw_plot_text(plot, GameManager.text("500 m ACTIVE REFLECTOR · GUIZHOU", "500 米主动反射面 · 贵州"), Vector2(36, 68), 12, CRT)
	_draw_plot_text(
		plot,
		GameManager.text(
			"FAST receives radio timing, not a colour portrait. It excels at pulsars, hydrogen lines and fast bursts.",
			"FAST 接收的是射电时序，不是彩色照片；它擅长脉冲星、中性氢谱线和快速射电爆发。"
		),
		Vector2(36, 92),
		10,
		CYAN
	)
	_draw_plot_text(
		plot,
		GameManager.text(
			"Tonight, recover a known pulsar's rhythm from noise instead of imaging a planet surface.",
			"今晚要从噪声中找回一颗已知脉冲星的节奏，而不是观察行星表面。"
		),
		Vector2(36, 112),
		10,
		MUTED
	)
	var status_lines := [
		GameManager.text("ARRAY SURFACE ........ ONLINE", "主动反射面 ........ 在线"),
		GameManager.text("FEED CABIN ........... LINKED", "悬吊馈源舱 ........ 已连接"),
		GameManager.text("RECEIVER CHAIN ....... READY", "接收机链路 ........ 就绪"),
		GameManager.text("TIME STANDARD ........ LOCKED", "时间基准 .......... 已锁定"),
	]
	var terminal_rect := FAST_TAKEOVER_STATUS_RECT
	plot.draw_rect(terminal_rect, Color("06131b"), true)
	plot.draw_rect(terminal_rect, Color(BRASS, 0.72), false, 2.0)
	for i in range(status_lines.size()):
		var threshold := 0.36 + float(i) * 0.14
		var color := GREEN if intro_progress >= threshold else Color(MUTED, 0.28)
		_draw_plot_text(plot, str(status_lines[i]), Vector2(126, 534 + i * 22), 13, color)
		if intro_progress >= threshold:
			plot.draw_circle(Vector2(822, 529 + i * 22), 4.0, GREEN)
	var scan_y := lerpf(terminal_rect.position.y, terminal_rect.end.y, fposmod(intro_progress * 4.0, 1.0))
	plot.draw_line(Vector2(terminal_rect.position.x, scan_y), Vector2(terminal_rect.end.x, scan_y), Color(CYAN, 0.12), 1.0)


func _build_stage_bar() -> void:
	if stage_bar_holder != null and is_instance_valid(stage_bar_holder):
		if stage_bar_holder.get_parent() != null:
			stage_bar_holder.get_parent().remove_child(stage_bar_holder)
		stage_bar_holder.queue_free()
	stage_bar_holder = Control.new()
	stage_bar_holder.position = Vector2(28, 78)
	stage_bar_holder.size = Vector2(968, 28)
	add_child(stage_bar_holder)
	if acquisition_active:
		var acquisition_labels := [
			GameManager.text("0 ACQUIRE", "0 截获"),
			GameManager.text("1 AIM", "1 对准"),
			GameManager.text("2 TUNE", "2 调谐"),
			GameManager.text("3 RFI", "3 净化"),
			GameManager.text("4 FOLD", "4 折叠"),
			GameManager.text("5 REPORT", "5 报告"),
		]
		for acquisition_index in range(acquisition_labels.size()):
			var acquisition_chip := Panel.new()
			acquisition_chip.position = Vector2(acquisition_index * 160.0, 0)
			acquisition_chip.size = Vector2(150, 28)
			acquisition_chip.add_theme_stylebox_override(
				"panel",
				_flat(
					Color("14253a") if acquisition_index == 0 else Color("0c1825"),
					GOLD if acquisition_index == 0 else Color("314154"),
					2
				)
			)
			stage_bar_holder.add_child(acquisition_chip)
			_label_to(
				acquisition_chip,
				str(acquisition_labels[acquisition_index]),
				Vector2.ZERO,
				acquisition_chip.size,
				11,
				GOLD if acquisition_index == 0 else MUTED,
				HORIZONTAL_ALIGNMENT_CENTER
			)
		return
	var labels := [
		GameManager.text("1 AIM", "1 对准"),
		GameManager.text("2 TUNE", "2 调谐"),
		GameManager.text("3 RFI", "3 净化"),
		GameManager.text("4 FOLD", "4 折叠"),
		GameManager.text("5 REPORT", "5 报告"),
	]
	for i in range(labels.size()):
		var done := i < stage
		var active := i == stage
		var chip := Panel.new()
		chip.position = Vector2(i * 194.0, 0)
		chip.size = Vector2(184, 28)
		chip.add_theme_stylebox_override("panel", _flat(
			Color("14253a") if active else Color("0c1825"),
			GREEN if done else (GOLD if active else Color("314154")),
			2
		))
		stage_bar_holder.add_child(chip)
		_label_to(chip, str(labels[i]), Vector2.ZERO, chip.size, 12, GREEN if done else (GOLD if active else MUTED), HORIZONTAL_ALIGNMENT_CENTER)


func _clear_content() -> void:
	if content == null:
		return
	for child in content.get_children():
		child.queue_free()


func _build_stage() -> void:
	_clear_content()
	if acquisition_active:
		_build_target_acquisition()
		return
	match STAGE_KEYS[stage]:
		"aim": _build_aim()
		"tune": _build_tune()
		"rfi": _build_rfi()
		"fold": _build_fold()
		"report": _build_report()


func _configure_stage_guidance() -> void:
	if not is_inside_tree() or content == null:
		return
	tutorial_step = -1
	tutorial_waiting_action = ""
	tutorial_action_complete = false
	tutorial_active = false
	tutorial_idle_seconds = 0.0
	tutorial_idle_tier = 0
	_clear_tutorial_frame()
	if tutorial_next_button != null:
		tutorial_next_button.visible = false
	if tutorial_mode_button != null:
		tutorial_mode_button.visible = false
	if tutorial_help_button != null:
		tutorial_help_button.visible = true
	if acquisition_active:
		# Acquisition owns a compact instrument-local guide. Do not construct
		# stage tutorial steps here: their controls belonged to the report page
		# that was just handed off and may already be queued for deletion.
		tutorial_steps.clear()
		if tutorial_help_button != null:
			tutorial_help_button.visible = false
		return
	tutorial_steps = _tutorial_steps_for_stage()
	# Free observation is intentionally self-directed. Keep the compact Help
	# affordance available, but never replay campaign tutorials or lock controls.
	if GameManager.is_remote_free_observation("radio"):
		return
	var seen_key := _tutorial_seen_key()
	match GameManager.tutorial_assistance_mode():
		GameManager.TUTORIAL_ASSIST_FULL:
			if not InteractionFeedback.was_tutorial_seen(seen_key):
				_start_stage_tutorial()
		GameManager.TUTORIAL_ASSIST_LIGHT:
			var light_key := seen_key + "_light"
			if not InteractionFeedback.was_tutorial_seen(light_key):
				InteractionFeedback.mark_tutorial_seen(light_key)
				status_label.text = _light_stage_hint()
				status_label.add_theme_color_override("font_color", CYAN)
		_:
			pass


func _tutorial_steps_for_stage() -> Array[Dictionary]:
	match STAGE_KEYS[stage]:
		"aim":
			return [
				_tutorial_step_data(
					"Mountains Between the Heartbeats: tonight you remotely take control of FAST in Guizhou. Radio astronomy begins by recognizing rhythm inside noise.",
					"“群山之间的心跳”从贵州 FAST 的远程接管开始。射电观测不是拍照，而是在噪声中辨认节奏。",
					"", scope,
					"FAST is a fixed 500 m reflector; its active 300 m region and suspended cabin form the beam.",
					"FAST 的 500 米反射面不会整体转动；活动的 300 米区域与悬吊馈源舱共同形成波束。"
				),
				_tutorial_step_data(
					"Drive the cabin toward the projected sky beam. Watch the velocity arrow and predicted stopping point.",
					"驱动馈源舱靠近天空波束投影，同时观察速度箭头和预计停止点。",
					"aim_drive", aim_drive_panel,
					"The cabin has inertia: releasing the control starts coasting, not an instant stop.",
					"馈源舱具有惯性：松开控制后会继续滑行，不会立即停住。"
				),
				_tutorial_step_data(
					"Brake before the cabin crosses the stability ring.",
					"在馈源舱穿过稳定环之前提前制动。",
					"aim_brake", aim_brake_button,
					"Correct direction is not enough. Excess speed raises cable load and prevents a lock.",
					"方向正确还不够；速度过高会增加缆索载荷，因此无法锁定。"
				),
				_tutorial_step_data(
					"When error and speed are both low, engage the cabin lock.",
					"误差和速度都降下来后，锁定馈源舱。",
					"aim_lock", lock_button,
					"The active reflector, six-cable suspension and receiver chain are now stable.",
					"活动反射面、六索悬吊与接收机链路现在都已稳定。"
				),
			]
		"tune":
			return [
				_tutorial_step_data(
					"The receiver hears a wide radio band. First place its center over the broad, persistent candidate.",
					"接收机会同时听见一大片频段。先把频窗中心移到宽缓、持续的候选信号上。",
					"", scope,
					"Center frequency chooses where the receiver listens.",
					"中心频率决定接收机正在监听哪一段频谱。"
				),
				_tutorial_step_data(
					"Move the center frequency and watch the candidate enter the window.",
					"调整中心频率，观察候选信号进入频窗。",
					"tune_center", scope,
					"The source coverage rose because the window moved, not because it became wider.",
					"信号覆盖率提高，是因为频窗位置改变，而不是因为带宽变宽。"
				),
				_tutorial_step_data(
					"Now adjust bandwidth. Keep the broad candidate, but exclude tall patterned RFI.",
					"现在调整带宽：保留宽缓候选，同时把高耸、规律的干扰挡在窗外。",
					"tune_width", tune_controls_panel,
					"Bandwidth controls how much spectrum enters. Wider is not always cleaner.",
					"带宽决定有多少频谱进入接收机；更宽并不一定更干净。"
				),
				_tutorial_step_data(
					"Stabilize the window when source coverage is high and RFI load is low.",
					"信号覆盖率高、干扰负载低时，稳定频窗。",
					"tune_confirm", tune_confirm_button,
					"The candidate band is preserved for peak-by-peak review.",
					"候选频段已保留，可以开始逐峰审查。"
				),
			]
		"rfi":
			return [
				_tutorial_step_data(
					"Human transmitters leave shapes in the spectrum. Select one peak and judge the evidence, not only its height.",
					"人类发射源会在频谱留下不同形态。选择一个频峰，依据形态而不是只看高度。",
					"", scope,
					"Broad repeating structure suggests the sky; narrow, comb-like, burst or sweep patterns suggest RFI.",
					"宽缓并重复的结构更像天体；窄带、梳状、突发或扫频更像人造干扰。"
				),
				_tutorial_step_data(
					"Select a peak in the spectrum.",
					"在频谱中选择一个峰。",
					"rfi_select", scope,
					"The review panel now names the peak shape and keeps your last decision visible.",
					"审查面板会显示峰形，并持续保留你刚才的判定。"
				),
				_tutorial_step_data(
					"Keep the broad repeating candidate or mark patterned interference.",
					"保留宽缓、重复的候选；把规律性污染标记为干扰。",
					"rfi_classify", rfi_keep_button,
					"Removed contamination disappears from the cleaned trace. A mistaken deletion can be restored.",
					"被剔除的污染会从净化轨迹消失；误删候选时可以恢复原始频谱。"
				),
				_tutorial_step_data(
					"Review every peak, then verify the cleaned spectrum.",
					"检查全部频峰，然后验证净化结果。",
					"rfi_verify", rfi_verify_button,
					"The time series is now clean enough to search for a repeating period.",
					"时间序列已经足够干净，可以搜索重复周期。"
				),
			]
		"fold":
			return [
				_tutorial_step_data(
					"First straighten the slanted sub-band arrivals by dragging the upper data trace.",
					"先拖动上方数据轨迹，把斜着到达的各子频段拉直。",
					"", scope,
					"Correct DM removes the frequency-dependent arrival delay.",
					"正确的 DM 会消除不同频率之间的到达延迟。"
				),
				_tutorial_step_data(
					"Drag the lower two-cycle profile until the pulse stops drifting or splitting.",
					"再拖动下方双周期轮廓，直到脉冲不再漂移或分裂。",
					"fold_period_adjust", scope,
					"A stable fundamental period puts every repetition in the same phase bin.",
					"稳定的基频会让每次脉冲都落入同一相位区间。"
				),
				_tutorial_step_data(
					"Hold the receiver. A real candidate must keep the same peak position for three windows.",
					"最后保持接收。真实候选必须在连续三个窗口中保持同一峰位。",
					"fold_integrate", fold_action_button,
					"Random noise averages down; the repeating pulse remains fixed.",
					"随机噪声逐渐被平均，重复脉冲则留在固定位置。"
				),
				_tutorial_step_data(
					"Confirm the stable candidate, then use its recovered timing to predict the next pulse.",
					"确认稳定候选，再用恢复出的计时结果预测下一次脉冲。",
					"fold_confirm", fold_confirm_button,
					"A real periodic source should arrive again when your model predicts.",
					"真实的周期信号应当在模型预报的时刻再次抵达。"
				),
			]
		_:
			return [
				_tutorial_step_data(
					"A scientific conclusion must agree with the evidence you produced.",
					"科学结论必须与刚才亲手得到的证据一致。",
					"", report_panel_ref,
					"Compare residual RFI, aligned period and DM, and final SNR.",
					"请比较残余干扰、周期与 DM 对齐情况，以及最终信噪比。"
				),
				_tutorial_step_data(
					"Select the conclusion supported by the report card.",
					"选择观测卡证据支持的结论。",
					"report_choose", report_choices_holder,
					"The selected statement can now be checked against measured evidence.",
					"现在可以用实测证据检验这项结论。"
				),
				_tutorial_step_data(
					"Submit the science report.",
					"提交科学报告。",
					"report_submit", submit_button,
					"The observation is archived as a formal FAST data product.",
					"本次观测将作为正式 FAST 数据成果归档。"
				),
			]


func _tutorial_step_data(
	text_en: String,
	text_zh: String,
	wait_action: String,
	target: Control,
	result_en: String,
	result_zh: String
) -> Dictionary:
	return {
		"text": GameManager.text(text_en, text_zh),
		"wait": wait_action,
		"target": target,
		"result": GameManager.text(result_en, result_zh),
	}


func _start_stage_tutorial() -> void:
	if tutorial_steps.is_empty():
		return
	tutorial_active = true
	tutorial_step = 0
	tutorial_idle_seconds = 0.0
	tutorial_idle_tier = 0
	tutorial_help_button.visible = false
	tutorial_next_button.visible = true
	tutorial_mode_button.visible = GameManager.uses_full_tutorials()
	_show_fast_tutorial_step()


func _show_fast_tutorial_step() -> void:
	_clear_tutorial_frame()
	if tutorial_step < 0 or tutorial_step >= tutorial_steps.size():
		_finish_stage_tutorial()
		return
	var data := tutorial_steps[tutorial_step]
	tutorial_waiting_action = str(data.get("wait", ""))
	tutorial_action_complete = false
	tutorial_target = data.get("target") as Control
	status_label.text = str(data.get("text", ""))
	status_label.add_theme_color_override("font_color", CYAN)
	tutorial_next_button.text = GameManager.text(
		"START" if tutorial_waiting_action == "" else "SKIP STEP",
		"开始" if tutorial_waiting_action == "" else "跳过本步"
	)
	_create_tutorial_frame(tutorial_target)


func _tutorial_action(action: String) -> void:
	if not tutorial_active or tutorial_waiting_action == "" or tutorial_action_complete:
		return
	if action != tutorial_waiting_action:
		return
	tutorial_action_complete = true
	var data := tutorial_steps[tutorial_step]
	status_label.text = str(data.get("result", ""))
	status_label.add_theme_color_override("font_color", GREEN)
	tutorial_next_button.text = GameManager.text("NEXT", "下一步")
	if tutorial_frame != null and is_instance_valid(tutorial_frame):
		InteractionFeedback.pulse(tutorial_frame, GREEN, 0.35)
	_terminal_event("GUIDED ACTION", "COMPLETE", action.to_upper(), "tutorial_%s" % action, 0.1, true)


func _advance_fast_tutorial() -> void:
	if not tutorial_active:
		return
	tutorial_step += 1
	if tutorial_step >= tutorial_steps.size():
		_finish_stage_tutorial()
	else:
		_show_fast_tutorial_step()


func _finish_stage_tutorial() -> void:
	if tutorial_active:
		InteractionFeedback.mark_tutorial_seen(_tutorial_seen_key())
	tutorial_active = false
	tutorial_waiting_action = ""
	tutorial_action_complete = false
	_clear_tutorial_frame()
	if tutorial_next_button != null:
		tutorial_next_button.visible = false
	if tutorial_mode_button != null:
		tutorial_mode_button.visible = false
	if tutorial_help_button != null:
		tutorial_help_button.visible = true
	status_label.text = _light_stage_hint()
	status_label.add_theme_color_override("font_color", MUTED)


func _disable_full_fast_tutorial() -> void:
	GameManager.set_tutorial_assistance_mode(GameManager.TUTORIAL_ASSIST_LIGHT)
	tutorial_active = false
	_clear_tutorial_frame()
	tutorial_next_button.visible = false
	tutorial_mode_button.visible = false
	tutorial_help_button.visible = true
	status_label.text = GameManager.text(
		"Full guidance is off. Use Help to replay this stage, or restore it from Settings.",
		"完整引导已关闭。可用“操作说明”重看本阶段，也可随时在设置中恢复。"
	)
	status_label.add_theme_color_override("font_color", CYAN)


func _replay_stage_tutorial() -> void:
	tutorial_steps = _tutorial_steps_for_stage()
	_start_stage_tutorial()


func _create_tutorial_frame(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return
	tutorial_frame = Panel.new()
	tutorial_frame.name = "FastTutorialFocus"
	tutorial_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_frame.z_index = 1100
	var local_origin := get_global_rect().position
	var target_rect := target.get_global_rect()
	tutorial_frame.position = target_rect.position - local_origin - Vector2(5, 5)
	tutorial_frame.size = target_rect.size + Vector2(10, 10)
	tutorial_frame.add_theme_stylebox_override("panel", _flat(Color.TRANSPARENT, CYAN, 2))
	add_child(tutorial_frame)
	if not InteractionFeedback.is_reduced_motion():
		var pulse := create_tween().bind_node(tutorial_frame).set_loops()
		pulse.tween_property(tutorial_frame, "modulate:a", 0.52, 0.58).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(tutorial_frame, "modulate:a", 1.0, 0.58).set_trans(Tween.TRANS_SINE)


func _clear_tutorial_frame() -> void:
	if tutorial_frame != null and is_instance_valid(tutorial_frame):
		tutorial_frame.queue_free()
	tutorial_frame = null
	tutorial_target = null


func _note_player_activity() -> void:
	tutorial_idle_seconds = 0.0
	tutorial_idle_tier = 0


func _show_progressive_idle_hint() -> void:
	if GameManager.tutorial_assistance_mode() == GameManager.TUTORIAL_ASSIST_FREE:
		return
	tutorial_idle_tier = mini(tutorial_idle_tier + 1, 3)
	var hint := _idle_hint_for_state(tutorial_idle_tier)
	if hint == "":
		return
	status_label.text = hint
	status_label.add_theme_color_override("font_color", AMBER if tutorial_idle_tier < 3 else CYAN)
	if tutorial_target != null and is_instance_valid(tutorial_target):
		InteractionFeedback.pulse(tutorial_target, AMBER, 0.42)


func _idle_hint_for_state(tier: int) -> String:
	var area := ""
	var phenomenon := ""
	var action := ""
	match STAGE_KEYS[stage]:
		"aim":
			area = GameManager.text("Look at the cabin vector and stability ring.", "请看馈源舱矢量与稳定环。")
			phenomenon = GameManager.text("A cabin inside the ring still cannot lock while its speed is high.", "即使馈源舱进入圆环，速度过高时仍无法锁定。")
			action = GameManager.text("Drive gently, brake before the center, then engage the lock.", "轻推方向，抵达中心前提前制动，再执行锁定。")
		"tune":
			area = GameManager.text("Look at the broad candidate and the movable passband.", "请看宽缓候选信号与可拖动频窗。")
			phenomenon = GameManager.text("Center moves the window; width decides how much RFI enters.", "中心频率移动频窗，带宽决定多少干扰会进入。")
			action = GameManager.text("Center on the broad feature, narrow away from tall peaks, then stabilize.", "把中心对准宽缓结构，缩窄以避开高峰，再稳定频窗。")
		"rfi":
			area = GameManager.text("Inspect the selected peak's shape in Peak Review.", "请在“频峰审查”中查看所选峰的形态。")
			phenomenon = GameManager.text("Repeating broad structure is the candidate; patterned narrow features are RFI.", "重复的宽缓结构是候选；规律性窄峰是干扰。")
			action = GameManager.text("Select each peak, keep the candidate, reject interference, then verify.", "逐个选择频峰，保留候选、剔除干扰，然后验证。")
		"fold":
			if fold_step == 0:
				area = GameManager.text("Look at the seven sub-band arrival rows.", "请看七条子频段到达轨迹。")
				phenomenon = GameManager.text("A diagonal sweep means the DM correction is incomplete.", "斜向扫频说明 DM 校正尚未完成。")
				action = GameManager.text("Drag the upper trace until all arrivals stand vertically.", "拖动上方轨迹，直到所有到达点垂直对齐。")
			elif fold_step == 1:
				area = GameManager.text("Compare both cycles of the folded pulse.", "请比较折叠脉冲的两个周期。")
				phenomenon = GameManager.text("Drift or a split pair exposes a wrong or aliased period.", "峰位漂移或成对分裂，说明周期错误或落入假解。")
				action = GameManager.text("Drag the lower profile and use Q/E to keep one full peak in the gate.", "拖动下方轮廓，并用 Q/E 把完整单峰放入接收门。")
			else:
				area = GameManager.text("Watch the three recent folded profiles and stable-window counter.", "请看最近三次折叠轮廓与稳定窗口计数。")
				phenomenon = GameManager.text("One lucky peak is not evidence; a real pulse stays in place.", "一次偶然峰值不是证据；真实脉冲会持续停在同一位置。")
				action = GameManager.text("Hold Space until three consecutive windows agree, then confirm.", "按住空格，直到连续三个窗口一致，再确认候选。")
		_:
			area = GameManager.text("Compare the raw band, clean band and folded profile.", "请比较原始频段、净化频段与折叠轮廓。")
			phenomenon = GameManager.text("The conclusion must agree with residual RFI, DM alignment and SNR.", "结论必须与残余干扰、DM 对齐和信噪比一致。")
			action = GameManager.text("Choose the evidence-backed conclusion, then submit the report.", "选择证据支持的结论，再提交报告。")
	return [area, phenomenon, action][clampi(tier - 1, 0, 2)]


func _light_stage_hint() -> String:
	match STAGE_KEYS[stage]:
		"aim": return GameManager.text("Drive toward the ring, brake before center, and lock only after speed settles.", "驶向稳定环，在中心前制动；速度稳定后再锁定。")
		"tune": return GameManager.text("Center chooses where to listen; bandwidth decides how much interference enters.", "中心频率决定监听位置，带宽决定多少干扰进入。")
		"rfi": return GameManager.text("Keep broad repeating evidence; remove narrow or patterned human interference.", "保留宽缓、重复的证据；剔除窄带或规律性人造干扰。")
		"fold": return _challenge_hint()
		_: return GameManager.text("Submit only the conclusion supported by residual RFI, aligned timing and SNR.", "只提交残余干扰、时间对齐和信噪比共同支持的结论。")


func _tutorial_seen_key() -> String:
	if STAGE_KEYS[stage] == "fold":
		return FAST_TUTORIAL_PREFIX + "fold_capture"
	return FAST_TUTORIAL_PREFIX + STAGE_KEYS[stage]


func _advance(next_stage: int = stage + 1) -> void:
	var target_stage := clampi(next_stage, 0, STAGE_KEYS.size() - 1)
	if target_stage == stage or stage_transition_active:
		return
	_begin_stage_handoff(target_stage)


func _begin_stage_handoff(target_stage: int) -> void:
	var previous_stage := stage
	var outgoing_workspace := content
	var commit_control := get_viewport().gui_get_focus_owner() as Control
	stage_handoff_snapshot = _fast_handoff_snapshot(previous_stage)
	stage_handoff_summary = _fast_handoff_summary(previous_stage, stage_handoff_snapshot)
	_terminal_event(
		STAGE_KEYS[previous_stage].to_upper() + " HANDOFF",
		"VERIFIED",
		stage_handoff_summary,
		"",
		0.0,
		true
	)

	var incoming_workspace := Control.new()
	incoming_workspace.name = "FastStageWorkspace_%s" % STAGE_KEYS[target_stage]
	incoming_workspace.position = outgoing_workspace.position
	incoming_workspace.size = outgoing_workspace.size
	add_child(incoming_workspace)
	content = incoming_workspace
	if target_stage == 3:
		_reset_fold_capture_validation(true)
	stage = target_stage
	_build_stage()
	_add_fast_handoff_summary(incoming_workspace)

	stage_transition_active = true
	# Keep the packet on the stage rail's lower edge so it never obscures
	# the stage label itself.
	var from_point := Vector2(28.0 + float(previous_stage) * 194.0 + 92.0, 103.0)
	var to_point := Vector2(28.0 + float(target_stage) * 194.0 + 92.0, 103.0)
	stage_transition.begin(
		self,
		outgoing_workspace,
		incoming_workspace,
		from_point,
		to_point,
		InteractionFeedback.is_reduced_motion(),
		func() -> void:
			_build_stage_bar()
			if objective_label != null and is_instance_valid(objective_label):
				objective_label.text = _stage_objective()
			_terminal_event(
				"DATA PACKET",
				"LOCKED",
				"%s > %s" % [
					STAGE_KEYS[previous_stage].to_upper(),
					STAGE_KEYS[target_stage].to_upper()
				],
				"",
				0.0,
				true
			)
			AudioManager.play_event("fast_array_relay"),
		func() -> void:
			stage_transition_active = false
			stage_transition_duration = stage_transition.duration
			_terminal_event(
				STAGE_KEYS[target_stage].to_upper() + " STAGE",
				"READY",
				stage_handoff_summary,
				"",
				0.0,
				true
			)
			call_deferred("_configure_stage_guidance")
			call_deferred("_focus_first_stage_control", incoming_workspace),
		commit_control,
		CYAN
	)
	stage_transition_duration = stage_transition.duration


func _fast_handoff_snapshot(completed_stage: int) -> Dictionary:
	match STAGE_KEYS[completed_stage]:
		"aim":
			return {
				"azimuth": model.azimuth,
				"altitude": model.altitude,
				"stability": model.stability(),
				"cable_load": model.cable_tension,
			}
		"tune":
			return {
				"center_mhz": model.window_center_mhz,
				"bandwidth_mhz": model.window_bandwidth_mhz,
				"rfi_load": model.window_rfi_load(),
				"quality": model.tuning_quality(),
			}
		"rfi":
			return {
				"rejected": model.correctly_rejected_rfi_count(),
				"residual": model.residual_rfi_count(),
				"center_mhz": model.window_center_mhz,
			}
		"fold":
			return {
				"period_ms": model.trial_period_ms,
				"dm": model.trial_dm,
				"snr": model.fold_snr(),
				"integration_s": model.integration_s,
			}
	return model.report().duplicate(true)


func _fast_handoff_summary(completed_stage: int, snapshot: Dictionary) -> String:
	match STAGE_KEYS[completed_stage]:
		"aim":
			return "AZ %.1f ALT %.1f  STAB %.0f%%  LOAD %.0f%%" % [
				float(snapshot.get("azimuth", 0.0)),
				float(snapshot.get("altitude", 0.0)),
				float(snapshot.get("stability", 0.0)) * 100.0,
				float(snapshot.get("cable_load", 0.0)) * 100.0,
			]
		"tune":
			return "%.0f MHz / %.0f MHz  RFI %.0f%%  Q %.0f%%" % [
				float(snapshot.get("center_mhz", 0.0)),
				float(snapshot.get("bandwidth_mhz", 0.0)),
				float(snapshot.get("rfi_load", 0.0)) * 100.0,
				float(snapshot.get("quality", 0.0)) * 100.0,
			]
		"rfi":
			return "CLEAN BAND %.0f MHz  REJECTED %d  RESIDUAL %d" % [
				float(snapshot.get("center_mhz", 0.0)),
				int(snapshot.get("rejected", 0)),
				int(snapshot.get("residual", 0)),
			]
		"fold":
			return "P %.3f ms  DM %.2f  SNR %.1f  INT %.0fs" % [
				float(snapshot.get("period_ms", 0.0)),
				float(snapshot.get("dm", 0.0)),
				float(snapshot.get("snr", 0.0)),
				float(snapshot.get("integration_s", 0.0)),
			]
	return GameManager.text("SCIENCE EVIDENCE ARCHIVED", "科学证据已归档")


func _add_fast_handoff_summary(workspace: Control) -> void:
	if stage_handoff_summary == "":
		return
	var summary := Label.new()
	summary.name = "FastHandoffInputSummary"
	# The workspace begins directly below the objective rail. The title-to-data
	# gap is the only shared safe strip across AIM/TUNE/RFI/FOLD/REPORT.
	summary.position = Vector2(470, 28)
	summary.size = Vector2(490, 14)
	summary.text = GameManager.text("INPUT  ", "输入  ") + stage_handoff_summary
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	summary.add_theme_font_size_override("font_size", 9)
	summary.add_theme_color_override("font_color", MUTED)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary.z_index = 40
	workspace.add_child(summary)


func _focus_first_stage_control(root: Control) -> void:
	if not is_instance_valid(root):
		return
	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is BaseButton:
			var button := node as BaseButton
			if button.visible and not button.disabled:
				button.focus_mode = Control.FOCUS_ALL
				button.grab_focus()
				return
		for child in node.get_children():
			queue.append(child)


func _back() -> void:
	if console_shutdown_active:
		return
	if stage_transition_active:
		stage_transition.finish_immediately()
		stage_transition_active = false
	if stage > 0 and stage < 4:
		stage -= 1
		_reset_fold_capture_validation(false)
		_rebuild()
		return
	_radio_console_power_down()


# ------------------------------------------------------ FREE TARGET ACQUISITION
func _build_target_acquisition() -> void:
	var sky_panel := _panel_to(
		content,
		Vector2(34, 18),
		Vector2(650, 468),
		PANEL_DEEP,
		BRASS,
		GameManager.text("REACHABLE RADIO SKY / FEED-CABIN CAPTURE", "可达射电天区 / 馈源舱目标截获")
	)
	acquisition_scope = RadioPlot.new()
	acquisition_scope.name = "FastTargetAcquisitionPlot"
	acquisition_scope.position = Vector2(12, 40)
	acquisition_scope.size = Vector2(626, 416)
	acquisition_scope.mouse_default_cursor_shape = Control.CURSOR_CROSS
	acquisition_scope.renderer = _draw_target_acquisition
	acquisition_scope.gui_input.connect(_on_acquisition_scope_input)
	sky_panel.add_child(acquisition_scope)

	var control_panel := _panel_to(
		content,
		Vector2(696, 18),
		Vector2(294, 468),
		PANEL,
		BRASS,
		GameManager.text("BEAM ACQUISITION", "波束截获")
	)
	acquisition_readout = _label_to(
		control_panel,
		"",
		Vector2(16, 38),
		Vector2(262, 166),
		11,
		TEXT
	)
	acquisition_readout.name = "FastAcquisitionReadout"
	acquisition_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acquisition_readout.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	if GameManager.tutorial_assistance_mode() != GameManager.TUTORIAL_ASSIST_FREE:
		acquisition_guide = Panel.new()
		acquisition_guide.name = "FastAcquisitionGuide"
		acquisition_guide.position = Vector2(16, 204)
		acquisition_guide.size = Vector2(262, 70)
		acquisition_guide.add_theme_stylebox_override("panel", _flat(Color("081116"), Color("4a5758"), 1))
		control_panel.add_child(acquisition_guide)
		var guide_text := _label_to(
			acquisition_guide,
			GameManager.text(
				"Hold WASD or drag; brake near the beacon.\nPress Enter for coarse lock, then fine lock.",
				"按住 WASD 或拖动天区，接近信标前制动。\n按回车先粗锁，再完成精锁。"
			),
			Vector2(8, 4),
			Vector2(246, 38),
			10,
			CYAN
		)
		guide_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var close_guide := _button(GameManager.text("HIDE", "关闭"), Vector2(214, 43), Vector2(42, 21), Color("182027"))
		close_guide.add_theme_font_size_override("font_size", 9)
		close_guide.pressed.connect(func() -> void:
			if acquisition_guide != null and is_instance_valid(acquisition_guide):
				acquisition_guide.queue_free()
				acquisition_guide = null
		)
		acquisition_guide.add_child(close_guide)

	var controls_y := 282.0
	var up := _button("▲", Vector2(110, controls_y), Vector2(64, 34), Color("16242b"))
	var left := _button("◀", Vector2(40, controls_y + 38), Vector2(64, 34), Color("16242b"))
	acquisition_brake_button = _button(GameManager.text("BRAKE", "制动"), Vector2(110, controls_y + 38), Vector2(64, 34), Color("30291e"))
	var right := _button("▶", Vector2(180, controls_y + 38), Vector2(64, 34), Color("16242b"))
	var down := _button("▼", Vector2(110, controls_y + 76), Vector2(64, 34), Color("16242b"))
	for button in [up, left, acquisition_brake_button, right, down]:
		control_panel.add_child(button)
	up.button_down.connect(func() -> void: acquisition_drive_vector = Vector2.UP)
	up.button_up.connect(func() -> void: acquisition_drive_vector = Vector2.ZERO)
	down.button_down.connect(func() -> void: acquisition_drive_vector = Vector2.DOWN)
	down.button_up.connect(func() -> void: acquisition_drive_vector = Vector2.ZERO)
	left.button_down.connect(func() -> void: acquisition_drive_vector = Vector2.LEFT)
	left.button_up.connect(func() -> void: acquisition_drive_vector = Vector2.ZERO)
	right.button_down.connect(func() -> void: acquisition_drive_vector = Vector2.RIGHT)
	right.button_up.connect(func() -> void: acquisition_drive_vector = Vector2.ZERO)
	acquisition_brake_button.button_down.connect(func() -> void: acquisition_braking = true)
	acquisition_brake_button.button_up.connect(func() -> void: acquisition_braking = false)

	acquisition_lock_button = _button("", Vector2(16, 410), Vector2(262, 42), Color("18452f"))
	acquisition_lock_button.name = "FastAcquisitionLock"
	acquisition_lock_button.pressed.connect(_attempt_acquisition_lock)
	control_panel.add_child(acquisition_lock_button)
	if tutorial_help_button != null:
		tutorial_help_button.visible = false
	_refresh_target_acquisition()


func _refresh_target_acquisition() -> void:
	if not acquisition_active:
		return
	var entry := _selected_acquisition_entry()
	var error := _acquisition_pointing_error()
	var speed := _acquisition_speed()
	var zenith_angle := fast_zenith_angle(acquisition_altitude)
	var state_text := _acquisition_state_text()
	var target_azimuth := float(entry.get("azimuth", 0.0))
	var target_altitude := float(entry.get("altitude", 0.0))
	var target_name := GameManager.text(
		str(entry.get("name_en", entry.get("target_id", "NO BEACON"))),
		str(entry.get("name_zh", entry.get("target_id", "NO BEACON"))))
	var target_center_mhz := float(entry.get("center_mhz", model.true_center_mhz))
	var target_bandwidth_mhz := float(entry.get("bandwidth_mhz", model.true_bandwidth_mhz))
	var reachable_text := (
		GameManager.text("INSIDE 40° ENVELOPE", "位于 40° 可达边界内")
		if _acquisition_target_reachable()
		else GameManager.text("OUTSIDE 40° ENVELOPE", "超出 40° 可达边界")
	)
	if acquisition_readout != null and is_instance_valid(acquisition_readout):
		acquisition_readout.text = GameManager.text(
			"STATE  %s\nBEACON %s\nCURRENT  Az %06.2f°  Alt %05.2f°\nTARGET   Az %06.2f°  Alt %05.2f°\nZENITH   %04.1f° / 40.0°\nERROR    %05.2f°   SPEED %04.2f°/s\nBAND     %.0f MHz ± %.0f MHz\n%s" % [
				state_text, target_name, acquisition_azimuth, acquisition_altitude,
				target_azimuth, target_altitude, zenith_angle,
				error, speed, target_center_mhz, target_bandwidth_mhz * 0.5,
				reachable_text
			],
			"状态  %s\n信标 %s\n当前  方位 %06.2f°  高度 %05.2f°\n目标  方位 %06.2f°  高度 %05.2f°\n天顶角  %04.1f° / 40.0°\n误差  %05.2f°   速度 %04.2f°/秒\n频段  %.0f MHz ± %.0f MHz\n%s" % [
				state_text, target_name, acquisition_azimuth, acquisition_altitude,
				target_azimuth, target_altitude, zenith_angle,
				error, speed, target_center_mhz, target_bandwidth_mhz * 0.5,
				reachable_text
			]
		)
		acquisition_readout.add_theme_color_override(
			"font_color",
			RED if not _acquisition_target_reachable() else (GREEN if acquisition_state == "locked" else TEXT)
		)
	if acquisition_lock_button != null and is_instance_valid(acquisition_lock_button):
		match acquisition_state:
			"search":
				acquisition_lock_button.text = GameManager.text("CAPTURE COARSE TRACK", "捕获粗跟踪")
				acquisition_lock_button.disabled = not _acquisition_can_coarse_lock()
			"coarse":
				acquisition_lock_button.text = GameManager.text("ENGAGE FINE LOCK", "执行精锁定")
				acquisition_lock_button.disabled = not _acquisition_can_fine_lock()
			_:
				acquisition_lock_button.text = GameManager.text("TARGET LOCKED", "目标已锁定")
				acquisition_lock_button.disabled = true
	if status_label != null and is_instance_valid(status_label):
		if acquisition_boundary_warning != "":
			status_label.text = acquisition_boundary_warning
			status_label.add_theme_color_override("font_color", RED)
		elif not _acquisition_target_reachable():
			status_label.text = GameManager.text(
				"This catalogue coordinate is outside FAST's current 40° zenith-angle window. Return and choose a reachable source.",
				"该目录坐标超出 FAST 当前 40°天顶角可达范围。请返回并选择可达射电源。"
			)
			status_label.add_theme_color_override("font_color", RED)
		elif acquisition_state == "search":
			status_label.text = GameManager.text(
				"Drive the suspended cabin until the radio beacon enters the broad beam.",
				"连续驱动悬吊馈源舱，让射电信标进入宽波束。"
			)
			status_label.add_theme_color_override("font_color", CYAN)
		elif acquisition_state == "coarse":
			status_label.text = GameManager.text(
				"Coarse track captured. Reduce angular error and settle the cable velocity for fine lock.",
				"粗跟踪已捕获。继续降低角误差并稳定索系速度，再执行精锁定。"
			)
			status_label.add_theme_color_override("font_color", AMBER)
		else:
			status_label.text = GameManager.text(
				"Fine lock confirmed. The receiver chain is handing the target to feed-cabin aiming.",
				"精锁定已确认。接收机链路正在把目标移交给馈源舱对准阶段。"
			)
			status_label.add_theme_color_override("font_color", GREEN)
	if acquisition_scope != null and is_instance_valid(acquisition_scope):
		acquisition_scope.queue_redraw()


func _acquisition_state_text() -> String:
	match acquisition_state:
		"coarse":
			return GameManager.text("COARSE TRACK", "粗跟踪")
		"locked":
			return GameManager.text("FINE LOCK", "精锁定")
		_:
			return GameManager.text("SEARCH", "搜索")


func _draw_target_acquisition(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("02070a"), true)
	var center := Vector2(plot.size.x * 0.50, 186.0)
	var boundary_radius := 158.0
	for zenith_ring_value in [10.0, 20.0, 30.0, 40.0]:
		var zenith_ring := float(zenith_ring_value)
		var radius: float = boundary_radius * zenith_ring / FAST_MAX_ZENITH_ANGLE_DEG
		plot.draw_arc(center, radius, 0.0, TAU, 96, Color(CRT, 0.12 if zenith_ring < 40.0 else 0.52), 1.0, true)
		_draw_plot_text(plot, "%d°" % int(zenith_ring), center + Vector2(5, -radius + 12), 9, MUTED)
	for azimuth_line in range(0, 360, 30):
		var direction := Vector2(sin(deg_to_rad(float(azimuth_line))), -cos(deg_to_rad(float(azimuth_line))))
		plot.draw_line(center, center + direction * boundary_radius, Color(CRT, 0.08), 1.0)
	_draw_plot_text(plot, "N", center + Vector2(-4, -boundary_radius - 8), 10, CRT)
	_draw_plot_text(plot, "E", center + Vector2(boundary_radius + 6, 4), 10, CRT)
	_draw_plot_text(plot, "S", center + Vector2(-4, boundary_radius + 16), 10, CRT)
	_draw_plot_text(plot, "W", center + Vector2(-boundary_radius - 16, 4), 10, CRT)

	var selected_entry := _selected_acquisition_entry()
	for entry in acquisition_entries:
		var beacon_pos := _acquisition_sky_point(
			center,
			boundary_radius,
			float(entry.get("azimuth", 0.0)),
			maxf(float(entry.get("altitude", 0.0)), 50.0)
		)
		var is_selected := str(entry.get("id", "")) == str(selected_entry.get("id", ""))
		var is_reachable := bool(entry.get("reachable", false))
		var beacon_color := RED if not is_reachable else (AMBER if is_selected else Color(CRT, 0.42))
		plot.draw_circle(beacon_pos, 3.5 if is_selected else 2.4, beacon_color)
		plot.draw_arc(beacon_pos, 10.0 if is_selected else 6.0, 0.0, TAU, 28, Color(beacon_color, 0.72), 1.0, true)
		if is_selected and _acquisition_pointing_error() <= 24.0:
			_draw_plot_text(
				plot,
				GameManager.text(
					str(entry.get("name_en", entry.get("target_id", ""))),
					str(entry.get("name_zh", entry.get("target_id", "")))),
				beacon_pos + Vector2(12, -8),
				9,
				beacon_color
			)

	var target_pos := _acquisition_sky_point(
		center,
		boundary_radius,
		float(selected_entry.get("azimuth", 0.0)),
		maxf(float(selected_entry.get("altitude", 50.0)), 50.0)
	)
	var current_pos := _acquisition_sky_point(
		center,
		boundary_radius,
		acquisition_azimuth,
		acquisition_altitude
	)
	var target_color := RED if not _acquisition_target_reachable() else (GREEN if acquisition_state == "locked" else AMBER)
	var beacon_pulse := 1.0 + sin(terminal_clock * 4.0) * 0.08
	plot.draw_arc(target_pos, 13.0 * beacon_pulse, 0.0, TAU, 40, target_color, 2.0, true)
	plot.draw_line(target_pos + Vector2(-18, 0), target_pos + Vector2(18, 0), Color(target_color, 0.45), 1.0)
	plot.draw_line(target_pos + Vector2(0, -18), target_pos + Vector2(0, 18), Color(target_color, 0.45), 1.0)

	var beam_radius := lerpf(28.0, 13.0, clampf(1.0 - _acquisition_pointing_error() / 12.0, 0.0, 1.0))
	plot.draw_circle(current_pos, 4.5, CRT)
	plot.draw_arc(current_pos, beam_radius, 0.0, TAU, 48, CYAN, 2.0, true)
	plot.draw_arc(current_pos, beam_radius * 0.42, 0.0, TAU, 32, Color(CYAN, 0.34), 1.0, true)
	var predicted_az := wrapf(acquisition_azimuth + acquisition_velocity.x * 0.8, 0.0, 360.0)
	var predicted_alt := clampf(acquisition_altitude + acquisition_velocity.y * 0.8, 50.0, 88.0)
	var predicted_pos := _acquisition_sky_point(center, boundary_radius, predicted_az, predicted_alt)
	plot.draw_dashed_line(current_pos, predicted_pos, Color(CYAN, 0.56), 5.0, 1.0)
	plot.draw_circle(predicted_pos, 3.0, Color(CYAN, 0.62), false, 1.0)
	plot.draw_dashed_line(current_pos, target_pos, Color(AMBER, 0.36), 8.0, 1.0)

	var receiver_rect := Rect2(Vector2(28, 360), Vector2(plot.size.x - 56, 36))
	plot.draw_rect(receiver_rect, Color("071014"), true)
	plot.draw_rect(receiver_rect, Color(BRASS, 0.48), false, 1.0)
	for sample in range(72):
		var x := receiver_rect.position.x + float(sample) / 71.0 * receiver_rect.size.x
		var noise := sin(float(sample) * 1.73 + terminal_clock * 1.8) * 3.0
		var candidate := exp(-pow((float(sample) - 38.0) / 6.5, 2.0)) * clampf(12.0 - _acquisition_pointing_error(), 0.0, 10.0)
		plot.draw_line(
			Vector2(x, receiver_rect.end.y - 8.0),
			Vector2(x, receiver_rect.end.y - 8.0 - absf(noise) - candidate),
			Color(CRT, 0.24 + candidate * 0.035),
			1.0
		)
	_draw_plot_text(
		plot,
		GameManager.text("LIVE BEAM POWER · TARGET CANDIDATE EMERGES ONLY INSIDE THE BEAM", "实时波束功率 · 目标进入波束后候选信号才会浮现"),
		Vector2(32, 352),
		9,
		MUTED
	)


func _acquisition_sky_point(center: Vector2, radius: float, azimuth_deg: float, altitude_deg: float) -> Vector2:
	var zenith_angle := clampf(fast_zenith_angle(altitude_deg), 0.0, FAST_MAX_ZENITH_ANGLE_DEG)
	var radial := zenith_angle / FAST_MAX_ZENITH_ANGLE_DEG * radius
	var angle := deg_to_rad(azimuth_deg)
	return center + Vector2(sin(angle), -cos(angle)) * radial


func _on_acquisition_scope_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			acquisition_dragging = mouse_button.pressed
			if not acquisition_dragging:
				acquisition_drive_vector = Vector2.ZERO
			accept_event()
	elif event is InputEventMouseMotion and acquisition_dragging:
		var motion := event as InputEventMouseMotion
		if motion.relative.length_squared() > 0.04:
			var impulse := Vector2(motion.relative.x, -motion.relative.y) * 0.055
			acquisition_velocity = (acquisition_velocity + impulse).limit_length(ACQUISITION_MAX_SPEED_DEG_S)
			_note_player_activity()
			_refresh_target_acquisition()
		accept_event()


func _attempt_acquisition_lock() -> void:
	if acquisition_transition_pending or not acquisition_active:
		return
	var entry := _selected_acquisition_entry()
	if entry.is_empty():
		acquisition_boundary_warning = GameManager.text(
			"No radio catalogue beacon is inside the acquisition sky.",
			"鎴幏澶╁尯鍐呮病鏈夊皠鐢电洰褰曚俊鏍囥€?"
		)
		InteractionFeedback.error(acquisition_lock_button)
		_refresh_target_acquisition()
		return
	if not _acquisition_target_reachable():
		acquisition_boundary_warning = GameManager.text(
			"Target is outside FAST's 40° zenith-angle envelope.",
			"目标位于 FAST 的 40°天顶角可达范围之外。"
		)
		InteractionFeedback.error(acquisition_lock_button)
		_refresh_target_acquisition()
		return
	if acquisition_state == "search":
		if not _acquisition_can_coarse_lock():
			acquisition_boundary_warning = GameManager.text(
				"Coarse capture needs the beacon inside 7.5° and the cabin moving below 2.2°/s.",
				"粗捕获要求信标进入 7.5°范围，并把馈源舱速度降到 2.2°/秒以下。"
			)
			InteractionFeedback.error(acquisition_lock_button)
			_refresh_target_acquisition()
			return
		acquisition_state = "coarse"
		acquisition_velocity *= 0.22
		acquisition_boundary_warning = ""
		_terminal_event(
			"RADIO BEACON %s" % str(entry.get("target_id", "")).to_upper(),
			"COARSE TRACK",
			"ERROR %.2f DEG" % _acquisition_pointing_error(), "", 0.0, true)
		InteractionFeedback.feedback_sfx_requested.emit("fast_tune_locked")
		_refresh_target_acquisition()
		return
	if acquisition_state != "coarse" or not _acquisition_can_fine_lock():
		acquisition_boundary_warning = GameManager.text(
			"Fine lock needs angular error below 1.4° and cable motion below 0.42°/s.",
			"精锁定要求角误差低于 1.4°，索系运动速度低于 0.42°/秒。"
		)
		InteractionFeedback.error(acquisition_lock_button)
		_refresh_target_acquisition()
		return
	acquisition_state = "locked"
	acquisition_completed = true
	acquisition_transition_pending = true
	acquisition_velocity = Vector2.ZERO
	acquisition_boundary_warning = ""
	if not GameManager.begin_remote_free_observation("radio", str(entry.get("id", ""))):
		acquisition_state = "coarse"
		acquisition_completed = false
		acquisition_transition_pending = false
		acquisition_boundary_warning = GameManager.text(
			"The selected radio programme is no longer available.",
			"鎵€閫夊皠鐢佃娴嬭鍒掑綋鍓嶄笉鍙敤銆?"
		)
		InteractionFeedback.error(acquisition_lock_button)
		_refresh_target_acquisition()
		return
	profile = _profile()
	model = RadioSignalModel.new()
	model.configure(profile)
	_terminal_event("RADIO BEACON", "FINE LOCK", str(entry.get("target_id", "")).to_upper(), "", 0.0, true)
	_terminal_event("BEAM CENTRE", "CAPTURED", "40 DEG ENVELOPE VERIFIED", "", 0.0, true)
	InteractionFeedback.success(acquisition_lock_button, "fast_cabin_lock")
	_refresh_target_acquisition()
	var hold_time := 0.28 if InteractionFeedback.is_reduced_motion() else 0.92
	get_tree().create_timer(hold_time).timeout.connect(_finish_target_acquisition)


func _finish_target_acquisition() -> void:
	if not is_inside_tree() or not acquisition_active or not acquisition_completed:
		return
	acquisition_active = false
	acquisition_transition_pending = false
	model.azimuth = model.true_azimuth + 8.0
	model.altitude = clampf(model.true_altitude - 5.0, 5.0, 88.0)
	model.az_velocity = 0.0
	model.alt_velocity = 0.0
	_terminal_event("TARGET HANDOFF", "AIM CONTROL", str(model.target_id).to_upper(), "", 0.0, true)
	_rebuild()


# ---------------------------------------------------------------- 1. AIM
func _build_aim() -> void:
	var display := _panel_to(content, Vector2(32, 6), Vector2(626, 478), PANEL_DEEP, GOLD, GameManager.text("SUSPENDED FEED CABIN", "悬吊馈源舱"))
	scope = RadioPlot.new()
	scope.position = Vector2(18, 42)
	scope.size = Vector2(590, 414)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.renderer = _draw_aim_plot
	display.add_child(scope)

	var drive := _panel_to(content, Vector2(674, 6), Vector2(318, 478), PANEL, GOLD, GameManager.text("CABIN DRIVE", "馈源舱驱动"))
	aim_drive_panel = drive
	aim_lamp = Panel.new()
	aim_lamp.position = Vector2(274, 14)
	aim_lamp.size = Vector2(20, 20)
	aim_lamp.add_theme_stylebox_override("panel", _flat(AMBER, Color("302817"), 2))
	drive.add_child(aim_lamp)
	readout = _label_to(drive, "", Vector2(16, 44), Vector2(286, 130), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_meter(drive, GameManager.text("Cable tension", "缆索张力"), Vector2(16, 178), Vector2(286, 12), model.cable_tension, RED if model.tension_warning() else AMBER)
	_meter(drive, GameManager.text("Stability", "稳定度"), Vector2(16, 214), Vector2(286, 12), model.stability(), GREEN)

	var pad_center := Vector2(159, 318)
	_drive_button(drive, "▲", Vector2(pad_center.x - 32, pad_center.y - 74), Vector2(64, 44), Vector2(0, -1))
	_drive_button(drive, "▼", Vector2(pad_center.x - 32, pad_center.y + 30), Vector2(64, 44), Vector2(0, 1))
	_drive_button(drive, "◀", Vector2(pad_center.x - 102, pad_center.y - 22), Vector2(64, 44), Vector2(-1, 0))
	_drive_button(drive, "▶", Vector2(pad_center.x + 38, pad_center.y - 22), Vector2(64, 44), Vector2(1, 0))
	var brake := _button(GameManager.text("BRAKE", "制动"), Vector2(pad_center.x - 42, pad_center.y - 22), Vector2(84, 44), Color("3a2a1d"))
	aim_brake_button = brake
	brake.button_down.connect(func() -> void:
		drive_braking = true
		_note_player_activity()
		_tutorial_action("aim_brake")
	)
	brake.button_up.connect(func() -> void: drive_braking = false)
	drive.add_child(brake)

	lock_button = _button(GameManager.text("ENGAGE CABIN LOCK", "锁定馈源舱"), Vector2(28, 404), Vector2(262, 42), Color("18452f"))
	lock_button.pressed.connect(_try_lock)
	drive.add_child(lock_button)
	_label_to(drive, GameManager.text("WASD / arrows: drive   Space: brake", "WASD / 方向键：驱动   空格：制动"), Vector2(16, 374), Vector2(286, 22), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	_refresh_aim()


func _drive_button(parent: Control, text_value: String, pos: Vector2, size_value: Vector2, vector: Vector2) -> void:
	var button := _button(text_value, pos, size_value, Color("153249"))
	button.add_theme_font_size_override("font_size", 19)
	button.button_down.connect(func() -> void:
		drive_vector = vector
		_note_player_activity()
		_tutorial_action("aim_drive")
		InteractionFeedback.feedback_sfx_requested.emit("fast_cabin_drive")
	)
	button.button_up.connect(func() -> void:
		if drive_vector == vector:
			drive_vector = Vector2.ZERO
	)
	parent.add_child(button)


func _record_aim_trail() -> void:
	var err := Vector2(
		wrapf(model.azimuth - model.true_azimuth, -180.0, 180.0),
		model.altitude - model.true_altitude
	)
	if aim_trail.is_empty() or aim_trail[-1].distance_to(err) > 0.05:
		aim_trail.append(err)
	while aim_trail.size() > 42:
		aim_trail.pop_front()


func _refresh_aim() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var disturbance_text := (
		GameManager.text("QUIET", "稳定")
		if model.seconds_to_aim_disturbance() < 0.0
		else GameManager.text("%.1f s" % model.seconds_to_aim_disturbance(), "%.1f 秒" % model.seconds_to_aim_disturbance())
	)
	var active_patch := model.active_reflector_center_normalized()
	readout.text = GameManager.text(
		"Cabin  AZ %06.2f°  ALT %05.2f°\nTarget AZ %06.2f°  ALT %05.2f°\nError %.2f°   Speed %.2f°/s\nPatch %+0.2f/%+0.2f   Pulse %s" % [
			model.azimuth, model.altitude, model.true_azimuth, model.true_altitude,
			model.pointing_error(), model.pointing_speed(), active_patch.x, active_patch.y, disturbance_text,
		],
		"馈源舱  方位 %06.2f°  高度 %05.2f°\n目标    方位 %06.2f°  高度 %05.2f°\n误差 %.2f°   速度 %.2f°/秒\n工作区 %+0.2f/%+0.2f   扰动 %s" % [
			model.azimuth, model.altitude, model.true_azimuth, model.true_altitude,
			model.pointing_error(), model.pointing_speed(), active_patch.x, active_patch.y, disturbance_text,
		]
	)
	var color := GREEN if model.is_locked() else (AMBER if model.is_on_target() else TEXT)
	readout.add_theme_color_override("font_color", RED if model.tension_warning() else color)
	if aim_lamp != null and is_instance_valid(aim_lamp):
		aim_lamp.add_theme_stylebox_override("panel", _flat(GREEN if model.is_locked() else (AMBER if model.is_on_target() else RED), Color("2d322c"), 2))
	if lock_button != null and is_instance_valid(lock_button):
		lock_button.disabled = running
	scope.queue_redraw()


func _draw_aim_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("020405"), true)
	_draw_crt_grid(plot, Rect2(Vector2(12, 10), plot.size - Vector2(24, 38)), 42.0, Color(0.46, 0.50, 0.49, 0.13))
	var projection_origin := Vector2(plot.size.x * 0.5, plot.size.y * 0.40)
	var target_projection := model.target_feed_offset_normalized()
	var center := projection_origin + Vector2(target_projection.x * 118.0, target_projection.y * 54.0)
	_draw_fast_reflector_wireframe(plot, center)
	var scale_factor := 7.0
	var err_az := wrapf(model.azimuth - model.true_azimuth, -180.0, 180.0)
	var err_alt := model.altitude - model.true_altitude
	var marker := center + Vector2(err_az, -err_alt) * scale_factor
	marker.x = clampf(marker.x, 34.0, plot.size.x - 34.0)
	marker.y = clampf(marker.y, 30.0, plot.size.y - 54.0)

	var stability_radius := lerpf(27.0, 15.0, model.stability())
	plot.draw_arc(center, 34.0, 0.0, TAU, 72, Color(CYAN, 0.45), 1.0, true)
	plot.draw_arc(center, stability_radius, 0.0, TAU * clampf(model.stability() + 0.08, 0.08, 1.0), 72, GREEN if model.is_locked() else AMBER, 3.0, true)
	plot.draw_line(center - Vector2(48, 0), center + Vector2(48, 0), Color(CRT, 0.45), 1.0)
	plot.draw_line(center - Vector2(0, 48), center + Vector2(0, 48), Color(CRT, 0.45), 1.0)
	_draw_plot_text(
		plot,
		GameManager.text(
			"SKY BEAM  AZ %.1f°  ALT %.1f°" % [model.true_azimuth, model.true_altitude],
			"天空波束  方位 %.1f°  高度 %.1f°" % [model.true_azimuth, model.true_altitude]
		),
		center + Vector2(-66, -42),
		9,
		Color(CRT, 0.62)
	)

	var cable_anchors := [
		Vector2(38, 26),
		Vector2(plot.size.x - 38, 26),
		Vector2(18, plot.size.y * 0.48),
		Vector2(plot.size.x - 18, plot.size.y * 0.48),
		Vector2(38, plot.size.y - 48),
		Vector2(plot.size.x - 38, plot.size.y - 48),
	]
	var tension_color := RED if model.tension_warning() else Color(GOLD, 0.64)
	for cable_index in range(cable_anchors.size()):
		var anchor: Vector2 = cable_anchors[cable_index]
		var load_phase := sin(float(cable_index) * 1.17 + model.cable_tension * 2.0)
		var cable_color := Color(
			tension_color,
			clampf(0.46 + model.cable_tension * 0.38 + load_phase * 0.06, 0.35, 0.96)
		)
		plot.draw_line(anchor, marker, cable_color, 1.0 + model.cable_tension * 0.8)
		plot.draw_circle(anchor, 4.0, BRASS)
		_draw_plot_text(plot, "C%d" % (cable_index + 1), anchor + Vector2(5, -3), 7, Color(CRT, 0.38))

	if aim_trail.size() > 1:
		var trail := PackedVector2Array()
		for trail_error in aim_trail:
			var point := center + Vector2(trail_error.x, -trail_error.y) * scale_factor
			point.x = clampf(point.x, 34.0, plot.size.x - 34.0)
			point.y = clampf(point.y, 30.0, plot.size.y - 54.0)
			trail.append(point)
		plot.draw_polyline(trail, Color(CYAN, 0.34), 1.5, true)

	var cabin_shape := PackedVector2Array([
		marker + Vector2(0, -12),
		marker + Vector2(14, -3),
		marker + Vector2(10, 10),
		marker + Vector2(-10, 10),
		marker + Vector2(-14, -3),
	])
	plot.draw_colored_polygon(cabin_shape, Color("203849"))
	plot.draw_polyline(PackedVector2Array(Array(cabin_shape) + [cabin_shape[0]]), GREEN if model.is_locked() else GOLD, 2.0, true)

	var velocity := model.motion_vector() * 12.0
	if velocity.length() > 2.0:
		_draw_arrow(plot, marker, marker + velocity, RED if model.tension_warning() else CYAN)
	var predicted_error := model.predicted_error_vector()
	var predicted := center + Vector2(predicted_error.x, -predicted_error.y) * scale_factor
	predicted.x = clampf(predicted.x, 24.0, plot.size.x - 24.0)
	predicted.y = clampf(predicted.y, 24.0, plot.size.y - 48.0)
	plot.draw_dashed_line(marker, predicted, Color(AMBER, 0.72), 6.0, 1.0)
	plot.draw_arc(predicted, 6.0, 0.0, TAU, 20, AMBER, 1.0)

	var state_text := GameManager.text("LOCKED · CABLE LOAD STABLE", "已锁定 · 缆索载荷稳定") if model.is_locked() else (
		GameManager.text("ON TARGET · BRAKE TO SETTLE", "已对准 · 制动并等待稳定") if model.is_on_target()
		else GameManager.text("DRIVE CABIN INTO THE STABILITY RING", "将馈源舱驶入稳定环")
	)
	if aim_capture_progress > 0.0:
		var capture_radius := lerpf(62.0, 18.0, aim_capture_progress)
		plot.draw_arc(center, capture_radius, -PI * 0.5, -PI * 0.5 + TAU * aim_capture_progress, 64, CYAN, 3.0, true)
		plot.draw_line(
			Vector2(center.x, plot.size.y - 48.0),
			center + Vector2(0, 14),
			Color(GREEN, 0.28 + aim_capture_progress * 0.62),
			2.0 + aim_capture_progress * 3.0
		)
		_draw_plot_text(plot, aim_capture_state, Vector2(18, 22), 11, GREEN)
		state_text = GameManager.text("RECEIVER CAPTURE SEQUENCE", "接收机捕获序列")
	_draw_plot_text(plot, state_text, Vector2(18, plot.size.y - 18), 12, GREEN if model.is_locked() else AMBER)


func _draw_fast_reflector_wireframe(plot: RadioPlot, feed_target: Vector2) -> void:
	var dish_center := Vector2(plot.size.x * 0.5, plot.size.y * 0.82)
	var dish_width := plot.size.x * 0.43
	var dish_depth := plot.size.y * 0.22
	var wire := Color(CRT, 0.14)
	var bright_wire := Color(CRT, 0.24)

	for ring in range(7):
		var t := float(ring + 1) / 7.0
		var half_width := dish_width * t
		var y := dish_center.y - dish_depth * (1.0 - t * t)
		var points := PackedVector2Array()
		for sample in range(49):
			var x_norm := lerpf(-1.0, 1.0, float(sample) / 48.0)
			var x := dish_center.x + x_norm * half_width
			var sag := (x_norm * x_norm) * 12.0 * t
			points.append(Vector2(x, y + sag))
		plot.draw_polyline(points, bright_wire if ring == 6 else wire, 1.0, true)

	for spoke in range(15):
		var x_norm := lerpf(-1.0, 1.0, float(spoke) / 14.0)
		var rim := Vector2(
			dish_center.x + x_norm * dish_width,
			dish_center.y + x_norm * x_norm * 12.0
		)
		var inner := Vector2(
			dish_center.x + x_norm * 18.0,
			dish_center.y - dish_depth + 2.0
		)
		plot.draw_line(inner, rim, wire, 1.0)

	# The illuminated 300 m patch follows the target direction. Each small
	# diamond carries its own actuator-slope mark, so the reflector reads as a
	# deformable cable-net surface instead of one rigid bowl.
	var active_normalized := model.active_reflector_center_normalized()
	var active_center := Vector2(
		dish_center.x + active_normalized.x * dish_width * 0.74,
		dish_center.y - dish_depth * 0.43 + active_normalized.y * dish_depth * 0.34
	)
	var active_radius := Vector2(dish_width * 0.28, dish_depth * 0.30)
	var active_outline := PackedVector2Array()
	for sample in range(41):
		var angle := TAU * float(sample) / 40.0
		active_outline.append(active_center + Vector2(cos(angle) * active_radius.x, sin(angle) * active_radius.y))
	plot.draw_polyline(active_outline, Color(CYAN, 0.38), 1.0, true)
	for row in range(-4, 5):
		for column in range(-8, 9):
			var panel_normalized := Vector2(float(column) / 8.5, float(row) / 4.5)
			if panel_normalized.length_squared() > 1.0:
				continue
			var panel_point := Vector2(
				dish_center.x + panel_normalized.x * dish_width,
				dish_center.y - dish_depth * 0.44 + panel_normalized.y * dish_depth * 0.42
			)
			var active_delta := panel_point - active_center
			var in_active_patch := (
				pow(active_delta.x / active_radius.x, 2.0)
				+ pow(active_delta.y / active_radius.y, 2.0)
			) <= 1.0
			var formation := clampf(0.28 + model.stability() * 0.72, 0.28, 1.0)
			var panel_color := Color(CYAN, 0.30 + formation * 0.48) if in_active_patch else Color(CRT, 0.13)
			var half_size := Vector2(5.0, 2.5)
			var panel_outline := PackedVector2Array([
				panel_point + Vector2(-half_size.x, 0),
				panel_point + Vector2(0, -half_size.y),
				panel_point + Vector2(half_size.x, 0),
				panel_point + Vector2(0, half_size.y),
				panel_point + Vector2(-half_size.x, 0),
			])
			plot.draw_polyline(panel_outline, panel_color, 1.0, true)
			if in_active_patch:
				var tilt := model.panel_tilt_vector(panel_normalized)
				var tilt_line := tilt.normalized() * clampf(tilt.length() * 4.2, 1.5, 5.0)
				plot.draw_line(panel_point - tilt_line, panel_point + tilt_line, Color(AMBER, 0.76), 1.0)

	plot.draw_dashed_line(feed_target, active_center, Color(CYAN, 0.24), 8.0, 1.0)
	_draw_plot_text(
		plot,
		GameManager.text("ACTIVE PARABOLOID", "活动抛物面"),
		active_center + Vector2(-50, 18),
		8,
		Color(CYAN, 0.48)
	)

	var tower_y := plot.size.y * 0.23
	var left_tower := Vector2(40, tower_y)
	var right_tower := Vector2(plot.size.x - 40, tower_y)
	for tower in [left_tower, right_tower]:
		plot.draw_line(tower, Vector2(tower.x, dish_center.y + 8.0), Color(CRT, 0.22), 1.0)
		plot.draw_line(tower + Vector2(-8, 0), tower + Vector2(8, 0), Color(CRT, 0.32), 1.0)
	_draw_plot_text(
		plot,
		GameManager.text("500 m FULL APERTURE · 300 m ACTIVE PARABOLOID · 6-CABLE CABIN", "500 米全口径 · 300 米活动抛物面 · 六索馈源舱"),
		Vector2(18, plot.size.y - 40),
		9,
		Color(CRT, 0.46)
	)


func _try_lock() -> void:
	if running:
		return
	if model.is_locked():
		_terminal_event("FEED CABIN LOCK", "ACQUIRE", "ERROR %.2f deg" % model.pointing_error())
		_terminal_event("SIX-CABLE LOAD", "BALANCED", "SPEED %.2f deg/s" % model.pointing_speed())
		_terminal_event("ACTIVE SURFACE", "FORMING", "300 m PARABOLOID")
		running = true
		await _play_cabin_capture_sequence()
		running = false
		_tutorial_action("aim_lock")
		_terminal_event("RECEIVER CHAIN", "CAPTURED", "PSR %s" % str(model.target_id).to_upper(), "", 0.0, true)
		_maya_reaction(
			"The cabin is steady. FAST is no longer looking everywhere; it is listening in one precise direction.",
			"馈源舱稳定了。FAST 不再听整片天空，而是在一个精确方向上开始倾听。"
		)
		_advance(1)
		_radio_operation_chain(
			GameManager.text("Locked the suspended feed cabin", "锁定悬吊馈源舱"),
			GameManager.text("Velocity collapsed and cable tension settled", "运动速度收束，缆索张力稳定"),
			GameManager.text("The receiver can now search the radio band", "接收机现在可以搜索射电频段")
		)
	elif model.is_on_target():
		_note_player_activity()
		_terminal_event("FEED CABIN LOCK", "WAIT", "SPEED %.2f deg/s" % model.pointing_speed())
		status_label.text = GameManager.text("The cabin is crossing the target too fast. Brake and let the stable ring close.", "馈源舱掠过目标的速度过快。请制动并等待稳定环闭合。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(lock_button)
	else:
		_note_player_activity()
		_terminal_event("FEED CABIN LOCK", "REJECT", "ERROR %.2f deg" % model.pointing_error())
		status_label.text = GameManager.text("Position error remains visible in the cabin plot. Follow the vector toward the central ring.", "馈源舱位置图仍显示明显误差。请沿矢量驶向中央稳定环。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(lock_button)


func _play_cabin_capture_sequence() -> void:
	var states := [
		[
			GameManager.text("SLEW COMPLETE · BRAKE APPLIED", "转向完成 · 制动已施加"),
			GameManager.text("SLEW ................. COMPLETE\nBRAKE COMMAND ........ HOLD", "转向 ................ 完成\n制动指令 ............ 保持"),
		],
		[
			GameManager.text("CABLE LOAD SETTLING", "缆索载荷正在稳定"),
			GameManager.text("OVERSHOOT ............ ARRESTED\nCABLE LOAD ........... SETTLING", "过冲 ................ 已抑制\n缆索载荷 ............ 稳定中"),
		],
		[
			GameManager.text("RECEIVER CAPTURE", "接收机捕获"),
			GameManager.text("STABILITY RING ....... CLOSED\nRECEIVER CAPTURE ..... LOCKED", "稳定环 .............. 闭合\n接收机捕获 .......... 已锁定"),
		],
	]
	InteractionFeedback.feedback_sfx_requested.emit("fast_cabin_brake")
	for i in range(states.size()):
		aim_capture_state = str(states[i][0])
		status_label.text = str(states[i][1])
		status_label.add_theme_color_override("font_color", GREEN if i == states.size() - 1 else AMBER)
		var start := float(i) / float(states.size())
		var finish := float(i + 1) / float(states.size())
		var duration := 0.34 if not InteractionFeedback.is_reduced_motion() else 0.08
		var tween := create_tween().bind_node(self)
		tween.tween_method(func(value: float) -> void:
			aim_capture_progress = value
			if scope != null and is_instance_valid(scope):
				scope.queue_redraw()
		, start, finish, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
		_terminal_event(
			["ATTITUDE SLEW", "CABLE LOAD", "RECEIVER CAPTURE"][i],
			["COMPLETE", "SETTLED", "LOCKED"][i]
		)
		if i == 1:
			InteractionFeedback.feedback_sfx_requested.emit("fast_cable_settle")
	aim_capture_progress = 1.0
	InteractionFeedback.feedback_sfx_requested.emit("fast_cabin_lock")
	InteractionFeedback.success(scope, "fast_cabin_lock")
	await get_tree().create_timer(0.34 if not InteractionFeedback.is_reduced_motion() else 0.08).timeout


# ---------------------------------------------------------------- 2. TUNE
func _build_tune() -> void:
	var spectrum_panel := _panel_to(content, Vector2(32, 6), Vector2(960, 352), PANEL_DEEP, GOLD, GameManager.text("LIVE RECEIVER SPECTRUM", "实时接收机频谱"))
	scope = RadioPlot.new()
	scope.position = Vector2(18, 42)
	scope.size = Vector2(924, 292)
	scope.mouse_filter = Control.MOUSE_FILTER_STOP
	scope.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	scope.renderer = _draw_tune_plot
	scope.gui_input.connect(_on_tune_scope_input)
	spectrum_panel.add_child(scope)

	var controls := _panel_to(content, Vector2(32, 366), Vector2(960, 116), PANEL, GOLD, GameManager.text("PASSBAND CONTROLS", "通带控制"))
	controls.name = "TuneControlsPanel"
	if controls.get_child_count() > 0:
		controls.get_child(0).name = "TuneControlsTitle"
	tune_controls_panel = controls
	readout = _label_to(controls, "", Vector2(18, 42), Vector2(330, 64), 11, TEXT)
	readout.name = "TuneReadout"
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stepper(controls, GameManager.text("CENTER MHz", "中心 MHz"), Vector2(372, 68), 150.0, _adjust_tune_center.bind(-5.0), _adjust_tune_center.bind(5.0), "TuneCenter")
	_stepper(controls, GameManager.text("WIDTH MHz", "带宽 MHz"), Vector2(552, 68), 150.0, _adjust_tune_width.bind(-5.0), _adjust_tune_width.bind(5.0), "TuneWidth")
	tune_log_label = _label_to(controls, "", Vector2(718, 40), Vector2(224, 30), 10, CRT, HORIZONTAL_ALIGNMENT_CENTER)
	tune_log_label.name = "TuneSignalStatus"
	tune_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var confirm := _button(GameManager.text("STABILIZE WINDOW", "稳定频窗"), Vector2(728, 76), Vector2(204, 30), Color("18452f"))
	confirm.name = "TuneConfirmButton"
	tune_confirm_button = confirm
	confirm.pressed.connect(_confirm_tune)
	controls.add_child(confirm)
	if tune_waterfall.is_empty():
		_capture_waterfall_row(tune_waterfall, false)
	_refresh_tune()


func _adjust_tune_center(delta: float) -> void:
	model.window_center_mhz = clampf(model.window_center_mhz + delta, model.BAND_MIN, model.BAND_MAX)
	_note_player_activity()
	_tutorial_action("tune_center")
	_terminal_event("RECEIVER WINDOW", "MOVING", "CENTER %.0f MHz" % model.window_center_mhz, "tune_center", 0.28)
	_terminal_event("CANDIDATE COVERAGE", "MEASURE", "%d%%" % int(model.window_covers_source() * 100.0), "tune_coverage", 0.42)
	InteractionFeedback.feedback_sfx_requested.emit("fast_tune_window")
	_refresh_tune()


func _adjust_tune_width(delta: float) -> void:
	model.window_bandwidth_mhz = clampf(model.window_bandwidth_mhz + delta, 20.0, 180.0)
	_note_player_activity()
	_tutorial_action("tune_width")
	_terminal_event("PASSBAND WIDTH", "MOVING", "%.0f MHz" % model.window_bandwidth_mhz, "tune_width", 0.28)
	_terminal_event("RFI LOAD", "MEASURE", "%d%%" % int(model.window_rfi_load() * 100.0), "tune_rfi", 0.42)
	InteractionFeedback.feedback_sfx_requested.emit("fast_tune_window")
	_refresh_tune()


func _tune_keyboard(keycode: Key) -> void:
	match keycode:
		KEY_LEFT, KEY_A: _adjust_tune_center(-5.0)
		KEY_RIGHT, KEY_D: _adjust_tune_center(5.0)
		KEY_UP, KEY_W: _adjust_tune_width(5.0)
		KEY_DOWN, KEY_S: _adjust_tune_width(-5.0)
		KEY_ENTER: _confirm_tune()


func _on_tune_scope_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_note_player_activity()
			var rect := _tune_window_rect(scope.size)
			if absf(mouse.position.x - rect.position.x) <= 12.0:
				tune_drag_mode = "left"
			elif absf(mouse.position.x - rect.end.x) <= 12.0:
				tune_drag_mode = "right"
			else:
				tune_drag_mode = "center"
				_set_tune_center_from_x(mouse.position.x)
			_start_tune_ratchet()
		else:
			var completed_drag_mode := tune_drag_mode
			tune_drag_mode = ""
			_stop_tune_ratchet()
			_terminal_event(
				"RECEIVER WINDOW",
				"HOLD",
				"%.0f / %.0f MHz" % [model.window_center_mhz, model.window_bandwidth_mhz]
			)
			_tutorial_action("tune_center" if completed_drag_mode == "center" else "tune_width")
		_refresh_tune()
	elif event is InputEventMouseMotion and tune_drag_mode != "":
		_start_tune_ratchet()
		var motion := event as InputEventMouseMotion
		var mhz := _x_to_mhz(motion.position.x, scope.size.x)
		if tune_drag_mode == "center":
			model.window_center_mhz = mhz
			_tutorial_action("tune_center")
		else:
			var other := model.window_center_mhz + model.window_bandwidth_mhz * (0.5 if tune_drag_mode == "left" else -0.5)
			model.window_center_mhz = (mhz + other) * 0.5
			model.window_bandwidth_mhz = clampf(absf(mhz - other), 20.0, 180.0)
			_tutorial_action("tune_width")
		_note_player_activity()
		_refresh_tune()


func _start_tune_ratchet() -> void:
	if AudioManager != null:
		AudioManager.start_event_loop("fast_tune_window", -1.5)


func _stop_tune_ratchet(fade_seconds := 0.045) -> void:
	if AudioManager != null:
		AudioManager.stop_event_loop("fast_tune_window", fade_seconds)


func _set_tune_center_from_x(x: float) -> void:
	model.window_center_mhz = _x_to_mhz(x, scope.size.x)
	_refresh_tune()


func _x_to_mhz(x: float, width: float) -> float:
	return lerpf(model.BAND_MIN, model.BAND_MAX, clampf((x - 30.0) / maxf(width - 60.0, 1.0), 0.0, 1.0))


func _mhz_to_x(mhz: float, width: float) -> float:
	return 30.0 + (width - 60.0) * (mhz - model.BAND_MIN) / (model.BAND_MAX - model.BAND_MIN)


func _tune_window_rect(plot_size: Vector2) -> Rect2:
	var lo := model.window_center_mhz - model.window_bandwidth_mhz * 0.5
	var hi := model.window_center_mhz + model.window_bandwidth_mhz * 0.5
	return Rect2(
		Vector2(_mhz_to_x(lo, plot_size.x), 26),
		Vector2(_mhz_to_x(hi, plot_size.x) - _mhz_to_x(lo, plot_size.x), plot_size.y - 58)
	)


func _refresh_tune() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	var quality := model.tuning_quality()
	readout.text = GameManager.text(
		"Window %4.0f ± %2.0f MHz\nSource %3d%%   RFI load %3d%%   Quality %3d%%" % [
			model.window_center_mhz, model.window_bandwidth_mhz * 0.5,
			int(model.window_covers_source() * 100.0), int(model.window_rfi_load() * 100.0), int(quality * 100.0),
		],
		"频窗 %4.0f ± %2.0f MHz\n信号 %3d%%   干扰负载 %3d%%   质量 %3d%%" % [
			model.window_center_mhz, model.window_bandwidth_mhz * 0.5,
			int(model.window_covers_source() * 100.0), int(model.window_rfi_load() * 100.0), int(quality * 100.0),
		]
	)
	readout.add_theme_color_override("font_color", GREEN if quality >= 0.55 else (AMBER if quality >= 0.28 else RED))
	if tune_log_label != null and is_instance_valid(tune_log_label):
		tune_log_label.text = GameManager.text(
			"RECEIVER WINDOW ....... MOVING" if tune_drag_mode != "" else (
				"CANDIDATE BAND ........ PRESERVED" if quality >= 0.55 else "RFI LOAD .............. HIGH"
			),
			"接收频窗 .......... 移动中" if tune_drag_mode != "" else (
				"候选频段 .......... 已保留" if quality >= 0.55 else "干扰负载 .......... 偏高"
			)
		)
	_capture_waterfall_row(tune_waterfall, false)
	scope.queue_redraw()


func _draw_tune_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var spectrum_rect := Rect2(Vector2(30, 18), Vector2(plot.size.x - 60, 142))
	var waterfall_rect := Rect2(Vector2(30, 174), Vector2(plot.size.x - 60, 82))
	_draw_crt_grid(plot, spectrum_rect, 44.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_crt_grid(plot, waterfall_rect, 44.0, Color(0.18, 0.34, 0.38, 0.12))
	var samples := model.spectrum_samples(220)
	var points := PackedVector2Array()
	var rfi_load := model.window_rfi_load()
	var plot_h := spectrum_rect.size.y - 20.0
	for i in range(samples.size()):
		var x := spectrum_rect.position.x + spectrum_rect.size.x * float(i) / float(samples.size() - 1)
		var jitter := sin(float(i) * 1.73) * rfi_load * 2.4
		var y := spectrum_rect.position.y + spectrum_rect.size.y - 6.0 - clampf(float(samples[i]) / 1.4, 0.0, 1.0) * plot_h + jitter
		points.append(Vector2(x, y))
	var trace_color := Color(RED, 0.90) if rfi_load > 0.72 else (Color(AMBER, 0.95) if rfi_load > 0.35 else CRT)
	plot.draw_polyline(points, Color(trace_color, 0.22), 5.0, true)
	plot.draw_polyline(points, trace_color, 1.7, true)

	var window := _tune_window_rect(Vector2(plot.size.x, spectrum_rect.end.y + 32.0))
	window.position.y = spectrum_rect.position.y
	window.size.y = spectrum_rect.size.y
	var quality := model.tuning_quality()
	var window_color := GREEN if quality >= 0.55 else (AMBER if quality >= 0.28 else RED)
	plot.draw_rect(window, Color(window_color, 0.10), true)
	plot.draw_rect(window, window_color, false, 2.0)
	plot.draw_rect(Rect2(window.position - Vector2(3, 0), Vector2(6, window.size.y)), window_color, true)
	plot.draw_rect(Rect2(Vector2(window.end.x - 3, window.position.y), Vector2(6, window.size.y)), window_color, true)
	for mhz in [1000.0, 1100.0, 1200.0, 1300.0, 1400.0, 1500.0]:
		var x := _mhz_to_x(mhz, plot.size.x)
		_draw_plot_text(plot, "%.0f" % mhz, Vector2(x - 16, plot.size.y - 8), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("MHz · live receiver power", "MHz · 实时接收功率"), Vector2(34, 14), 10, MUTED)
	_draw_waterfall(plot, waterfall_rect, tune_waterfall, false)
	_draw_plot_text(plot, GameManager.text("RECEIVER HISTORY", "接收历史"), waterfall_rect.position + Vector2(4, -4), 9, MUTED)
	if rfi_load > 0.55:
		_draw_plot_text(plot, GameManager.text("RFI RAISING NOISE FLOOR", "干扰正在抬高噪声底"), Vector2(plot.size.x - 226, 14), 11, RED)
	elif model.window_covers_source() > 0.75:
		_draw_plot_text(plot, GameManager.text("STABLE CANDIDATE FEATURE", "稳定候选特征"), Vector2(plot.size.x - 220, 14), 11, GREEN)


func _confirm_tune() -> void:
	var quality := model.tuning_quality()
	if quality >= 0.55:
		_terminal_event("CANDIDATE BAND", "PRESERVED", "QUALITY %d%%" % int(quality * 100.0))
		_terminal_event("RFI LOAD", "REDUCED", "%d%%" % int(model.window_rfi_load() * 100.0))
		_terminal_event("RECEIVER WINDOW", "STABLE", "%.0f ± %.0f MHz" % [model.window_center_mhz, model.window_bandwidth_mhz * 0.5], "", 0.0, true)
		_tutorial_action("tune_confirm")
		_maya_reaction(
			"There it is: not a picture, only a weak repeating structure that refuses to disappear with the noise.",
			"看见了吗？它不是图像，只是一段不会随噪声消失的微弱重复结构。"
		)
		status_label.text = GameManager.text("Passband stable. The candidate remains while the receiver noise drops.", "通带已经稳定。候选信号保留，接收机噪声下降。")
		status_label.add_theme_color_override("font_color", GREEN)
		InteractionFeedback.feedback_sfx_requested.emit("fast_tune_locked")
		_advance(2)
		_radio_operation_chain(
			GameManager.text("Stabilized the receiver window", "稳定接收机频窗"),
			GameManager.text("The source band stayed inside while strong RFI stayed outside", "信号频段被保留，强干扰留在通带之外"),
			GameManager.text("Individual peaks can now be inspected and cleaned", "现在可以逐个检查并净化频谱峰")
		)
	else:
		_note_player_activity()
		_terminal_event("PASSBAND VERIFY", "REJECT", "QUALITY %d%%" % int(quality * 100.0))
		status_label.text = GameManager.text(
			"The visual evidence is not stable: recenter the broad source feature or narrow away from the tall RFI peaks.",
			"视觉证据尚不稳定：重新框住宽缓的信号特征，或缩窄频窗避开高耸干扰峰。"
		)
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)


# ---------------------------------------------------------------- 3. RFI
func _build_rfi() -> void:
	var spectrum_panel := _panel_to(content, Vector2(32, 6), Vector2(676, 478), PANEL_DEEP, GOLD, GameManager.text("SPECTRUM CLEANING", "频谱净化"))
	scope = RadioPlot.new()
	scope.position = Vector2(18, 42)
	scope.size = Vector2(640, 414)
	scope.mouse_filter = Control.MOUSE_FILTER_STOP
	scope.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	scope.renderer = _draw_rfi_plot
	scope.gui_input.connect(_on_rfi_scope_input)
	spectrum_panel.add_child(scope)

	var actions := _panel_to(content, Vector2(724, 6), Vector2(268, 478), PANEL, GOLD, GameManager.text("PEAK REVIEW", "频峰审查"))
	readout = _label_to(actions, GameManager.text("Select a peak in the spectrum.", "请在频谱中选择一个峰。"), Vector2(14, 44), Vector2(240, 116), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rfi_keep_button = _button(GameManager.text("KEEP CANDIDATE  [K]", "保留候选  [K]"), Vector2(18, 176), Vector2(232, 42), Color("153e34"))
	rfi_keep_button.pressed.connect(_classify_selected.bind(false))
	actions.add_child(rfi_keep_button)
	rfi_reject_button = _button(GameManager.text("MARK INTERFERENCE [X]", "标记干扰  [X]"), Vector2(18, 230), Vector2(232, 42), Color("42271e"))
	rfi_reject_button.pressed.connect(_classify_selected.bind(true))
	actions.add_child(rfi_reject_button)
	rfi_evidence_label = _label_to(actions, "", Vector2(18, 282), Vector2(232, 60), 11, AMBER)
	rfi_evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rfi_restore_button = _button(GameManager.text("RESTORE RAW SPECTRUM", "恢复原始频谱"), Vector2(18, 348), Vector2(232, 32), Color("2c3034"))
	rfi_restore_button.name = "RestoreRawSpectrum"
	rfi_restore_button.pressed.connect(_restore_raw_spectrum)
	actions.add_child(rfi_restore_button)
	rfi_verify_button = _button(GameManager.text("VERIFY CLEAN SPECTRUM", "验证净化频谱"), Vector2(18, 402), Vector2(232, 44), Color("18452f"))
	rfi_verify_button.pressed.connect(_confirm_rfi)
	actions.add_child(rfi_verify_button)
	_label_to(actions, GameManager.text("←/→ select · K keep · X reject", "←/→ 选择 · K 保留 · X 剔除"), Vector2(12, 382), Vector2(244, 18), 9, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if rfi_waterfall.is_empty():
		_capture_waterfall_row(rfi_waterfall, true)
	_refresh_rfi()


func _show_rfi_tutorial(actions: Control) -> void:
	if actions == null or not is_instance_valid(actions):
		return
	if rfi_tutorial_panel != null and is_instance_valid(rfi_tutorial_panel):
		return
	rfi_tutorial_step = 0
	readout.visible = false
	rfi_tutorial_panel = Panel.new()
	rfi_tutorial_panel.name = "RfiMayaTutorial"
	rfi_tutorial_panel.position = Vector2(8, 34)
	rfi_tutorial_panel.size = Vector2(252, 136)
	rfi_tutorial_panel.z_index = 40
	rfi_tutorial_panel.add_theme_stylebox_override("panel", _flat(Color("08131a"), AMBER, 2))
	actions.add_child(rfi_tutorial_panel)
	MayaPortrait.create(
		rfi_tutorial_panel,
		"MayaPortrait",
		MayaPortrait.EXPLAIN,
		Vector2(5, 24),
		Vector2(54, 104),
		1
	)
	var title := _label_to(rfi_tutorial_panel, "", Vector2(64, 7), Vector2(176, 18), 10, AMBER)
	title.name = "TutorialTitle"
	rfi_tutorial_label = _label_to(rfi_tutorial_panel, "", Vector2(64, 25), Vector2(176, 77), 11, TEXT)
	rfi_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rfi_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	rfi_tutorial_next = _button("", Vector2(164, 105), Vector2(76, 24), Color("183844"))
	rfi_tutorial_next.add_theme_font_size_override("font_size", 10)
	rfi_tutorial_next.pressed.connect(_advance_rfi_tutorial)
	rfi_tutorial_panel.add_child(rfi_tutorial_next)
	_update_rfi_tutorial()


func _advance_rfi_tutorial() -> void:
	rfi_tutorial_step += 1
	if rfi_tutorial_step < 3:
		_update_rfi_tutorial()
		InteractionFeedback.pulse(rfi_tutorial_panel, CYAN, 0.24)
		return
	InteractionFeedback.mark_tutorial_seen("first_fast_rfi_review")
	if readout != null and is_instance_valid(readout):
		readout.visible = true
	if rfi_tutorial_panel != null and is_instance_valid(rfi_tutorial_panel):
		rfi_tutorial_panel.queue_free()
	rfi_tutorial_panel = null
	rfi_tutorial_label = null
	rfi_tutorial_next = null
	InteractionFeedback.pulse(scope, CYAN, 0.45)
	status_label.text = GameManager.text(
		"Select a peak, inspect its shape, then keep the candidate or remove interference.",
		"选择一个频谱峰，先判断其形态，再保留候选或剔除干扰。"
	)
	status_label.add_theme_color_override("font_color", CYAN)


func _update_rfi_tutorial() -> void:
	if rfi_tutorial_panel == null or not is_instance_valid(rfi_tutorial_panel):
		return
	var title := rfi_tutorial_panel.get_node_or_null("TutorialTitle") as Label
	if title != null:
		title.text = GameManager.text(
			"MAYA / RFI  %d/3" % (rfi_tutorial_step + 1),
			"玛雅 / 干扰辨识  %d/3" % (rfi_tutorial_step + 1)
		)
	match rfi_tutorial_step:
		0:
			rfi_tutorial_label.text = GameManager.text(
				"Click a peak. Read its shape, not only its height.",
				"先点击一个频谱峰。判断依据是形态，不只是峰值高度。"
			)
		1:
			rfi_tutorial_label.text = GameManager.text(
				"Broad and repeating: keep it. Narrow, comb-like, bursting or sweeping: remove it.",
				"宽缓且重复：保留。窄带、梳状、突发或扫频：剔除。"
			)
		_:
			rfi_tutorial_label.text = GameManager.text(
				"Green is kept, red is removed, amber is unreviewed. Review every peak, then verify.",
				"绿色表示保留，红色表示剔除，琥珀色表示尚未处理。全部检查后再验证。"
			)
	rfi_tutorial_next.text = GameManager.text(
		"START" if rfi_tutorial_step == 2 else "NEXT",
		"开始" if rfi_tutorial_step == 2 else "下一步"
	)


func _rfi_keyboard(keycode: Key) -> void:
	match keycode:
		KEY_LEFT, KEY_A:
			selected_peak = wrapi(selected_peak - 1, 0, model.rfi_peaks.size())
			_note_player_activity()
			_tutorial_action("rfi_select")
			_refresh_rfi()
		KEY_RIGHT, KEY_D:
			selected_peak = wrapi(selected_peak + 1, 0, model.rfi_peaks.size())
			_note_player_activity()
			_tutorial_action("rfi_select")
			_refresh_rfi()
		KEY_K: _classify_selected(false)
		KEY_X: _classify_selected(true)
		KEY_ENTER: _confirm_rfi()


func _on_rfi_scope_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var nearest := -1
	var distance := 9999.0
	for i in range(model.rfi_peaks.size()):
		var x := _mhz_to_x(float(model.rfi_peaks[i]["mhz"]), scope.size.x)
		var current := absf(mouse.position.x - x)
		if current < distance:
			distance = current
			nearest = i
	if nearest >= 0 and distance <= 34.0:
		selected_peak = nearest
		_note_player_activity()
		_tutorial_action("rfi_select")
		InteractionFeedback.selection(scope, true, CYAN, false, "fast_peak_selected")
		_refresh_rfi()


func _classify_selected(as_rfi: bool) -> void:
	if selected_peak < 0 or selected_peak >= model.rfi_peaks.size():
		status_label.text = GameManager.text("Select a visible peak before issuing a keep or reject command.", "请先选择可见频谱峰，再执行保留或剔除。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(scope)
		return
	var classified_index := selected_peak
	model.classify(classified_index, as_rfi)
	_note_player_activity()
	_tutorial_action("rfi_classify")
	var peak: Dictionary = model.rfi_peaks[classified_index]
	rfi_last_decision = GameManager.text(
		"Last: %.1f MHz -> %s" % [float(peak["mhz"]), "INTERFERENCE" if as_rfi else "CANDIDATE"],
		"刚才：%.1f MHz -> %s" % [float(peak["mhz"]), "干扰" if as_rfi else "候选"]
	)
	_terminal_event(
		"RFI REVIEW %.1f MHz" % float(peak["mhz"]),
		"REJECT" if as_rfi else "PRESERVE",
		str(peak.get("pattern", "fixed_narrow")).to_upper()
	)
	InteractionFeedback.feedback_sfx_requested.emit("fast_rfi_mark")
	InteractionFeedback.success(
		rfi_reject_button if as_rfi else rfi_keep_button,
		"fast_rfi_reject" if as_rfi else "fast_rfi_keep"
	)
	var immediate_feedback := GameManager.text(
		"Marked %.1f MHz as interference. Its contaminated trace is now suppressed." % float(peak["mhz"])
		if as_rfi
		else "Kept %.1f MHz as the sky candidate. Its repeating structure remains." % float(peak["mhz"]),
		"已将 %.1f MHz 标记为干扰，受污染的轨迹已被抑制。" % float(peak["mhz"])
		if as_rfi
		else "已将 %.1f MHz 保留为天体候选，其重复结构仍然可见。" % float(peak["mhz"])
	)
	var next_peak := _next_unreviewed_peak(classified_index)
	if next_peak >= 0:
		selected_peak = next_peak
	_refresh_rfi()
	var evidence := model.classification_evidence()
	if evidence == "source_deleted":
		_terminal_event("CANDIDATE BAND", "LOST", "%.1f MHz" % float(peak["mhz"]), "", 0.0, true)
		status_label.text = GameManager.text("The broad repeating candidate collapsed: you rejected the celestial source.", "宽缓的重复候选信号消失了：你误删了天体源。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		_maya_reaction(
			"The receiver went quiet because the repeating sky signal was removed. Restore the raw spectrum and compare its shape again.",
			"接收机突然安静，是因为重复的天体信号被误删了。恢复原始频谱，再比较一次它的形态。"
		)
	elif evidence == "residual_rfi":
		status_label.text = GameManager.text("A tall or patterned contaminant still survives in the cleaned trace.", "净化轨迹中仍有高耸或带规律的污染峰。")
		status_label.add_theme_color_override("font_color", AMBER)
	else:
		_terminal_event("CLEANED TRACE", "UPDATED", "RESIDUAL %d" % model.residual_rfi_count(), "rfi_trace", 0.12)
		status_label.text = immediate_feedback
		status_label.add_theme_color_override("font_color", GREEN)


func _restore_raw_spectrum() -> void:
	if model.classifications.is_empty():
		status_label.text = GameManager.text("The spectrum is already in its original state.", "频谱已经处于原始状态。")
		status_label.add_theme_color_override("font_color", MUTED)
		return
	var lost_candidate := model.source_deleted()
	model.classifications.clear()
	selected_peak = -1
	rfi_last_decision = GameManager.text("Last: raw spectrum restored", "刚才：已恢复原始频谱")
	_note_player_activity()
	_terminal_event("RFI MASK", "RESET", "ALL PEAKS RESTORED")
	_terminal_event("CANDIDATE BAND", "RECOVERED" if lost_candidate else "VISIBLE", "REVIEW REQUIRED", "", 0.0, true)
	status_label.text = GameManager.text(
		"The original spectrum is back. No evidence was lost; review every peak again.",
		"原始频谱已经恢复，证据没有丢失。请重新审查每个频峰。"
	)
	status_label.add_theme_color_override("font_color", CYAN)
	InteractionFeedback.success(rfi_restore_button, "fast_rfi_restore")
	_maya_reaction(
		"Good recovery. In radio work, a reversible mask is safer than silently deleting evidence.",
		"恢复得很好。射电处理中，可撤销的掩膜比悄悄删掉证据更可靠。"
	)
	_refresh_rfi()


func _next_unreviewed_peak(after_index: int) -> int:
	if model.rfi_peaks.is_empty():
		return -1
	for offset in range(1, model.rfi_peaks.size() + 1):
		var candidate := wrapi(after_index + offset, 0, model.rfi_peaks.size())
		if str(model.classifications.get(candidate, "")) == "":
			return candidate
	return -1


func _refresh_rfi() -> void:
	if scope == null or not is_instance_valid(scope):
		return
	if selected_peak >= 0 and selected_peak < model.rfi_peaks.size():
		var peak: Dictionary = model.rfi_peaks[selected_peak]
		var pattern := _pattern_text(str(peak.get("pattern", "fixed_narrow")))
		var mark := str(model.classifications.get(selected_peak, ""))
		var decision_en := "UNREVIEWED"
		var decision_zh := "尚未处理"
		var decision_color := AMBER
		if mark == "source":
			decision_en = "KEPT AS SKY CANDIDATE"
			decision_zh = "已保留为天体候选"
			decision_color = GREEN
		elif mark == "rfi":
			decision_en = "MARKED AS INTERFERENCE"
			decision_zh = "已标记为人造干扰"
			decision_color = RED
		readout.text = GameManager.text(
			"Peak %d / %d\n%.1f MHz   Strength %.2f\nShape: %s\nDecision: %s" % [
				selected_peak + 1, model.rfi_peaks.size(), float(peak["mhz"]), float(peak["strength"]), pattern, decision_en,
			],
			"频峰 %d / %d\n%.1f MHz   强度 %.2f\n形态：%s\n判定：%s" % [
				selected_peak + 1, model.rfi_peaks.size(), float(peak["mhz"]), float(peak["strength"]), pattern, decision_zh,
			]
		)
		readout.add_theme_color_override("font_color", decision_color)
	else:
		readout.text = GameManager.text("Select a peak. Its shape and persistence are evidence.", "选择一个频谱峰。它的形态和持续性就是证据。")
		readout.add_theme_color_override("font_color", TEXT)
	if rfi_keep_button != null and is_instance_valid(rfi_keep_button):
		var keep_mark := str(model.classifications.get(selected_peak, ""))
		rfi_keep_button.add_theme_stylebox_override(
			"normal",
			_flat(Color("153e34"), GREEN if keep_mark == "source" else GOLD, 3 if keep_mark == "source" else 2)
		)
		rfi_keep_button.disabled = selected_peak < 0
	if rfi_reject_button != null and is_instance_valid(rfi_reject_button):
		var reject_mark := str(model.classifications.get(selected_peak, ""))
		rfi_reject_button.add_theme_stylebox_override(
			"normal",
			_flat(Color("42271e"), RED if reject_mark == "rfi" else GOLD, 3 if reject_mark == "rfi" else 2)
		)
		rfi_reject_button.disabled = selected_peak < 0
	if rfi_verify_button != null and is_instance_valid(rfi_verify_button):
		var ready := model.all_classified()
		rfi_verify_button.disabled = not ready
		if ready and not bool(rfi_verify_button.get_meta("ready_announced", false)):
			rfi_verify_button.set_meta("ready_announced", true)
			InteractionFeedback.pulse(rfi_verify_button, GREEN, 0.65)
	if rfi_restore_button != null and is_instance_valid(rfi_restore_button):
		rfi_restore_button.disabled = model.classifications.is_empty()
	var evidence := model.classification_evidence()
	if rfi_evidence_label != null and is_instance_valid(rfi_evidence_label):
		match evidence:
			"source_deleted":
				rfi_evidence_label.text = GameManager.text("EVIDENCE: candidate band missing. Restore the celestial peak.", "证据：候选频段已消失。请恢复天体频峰。")
				rfi_evidence_label.add_theme_color_override("font_color", RED)
			"residual_rfi":
				rfi_evidence_label.text = GameManager.text("EVIDENCE: residual patterned peaks remain in the cleaned trace.", "证据：净化轨迹中仍残留规律性干扰峰。")
				rfi_evidence_label.add_theme_color_override("font_color", AMBER)
			"clean":
				rfi_evidence_label.text = GameManager.text("EVIDENCE: noise floor is quiet and the broad pulse candidate remains.", "证据：噪声底已安静，宽缓脉冲候选仍然存在。")
				rfi_evidence_label.add_theme_color_override("font_color", GREEN)
			_:
				rfi_evidence_label.text = (
					GameManager.text("Review every visible feature before verification.", "验证前请检查每个可见特征。")
					+ ("\n" + rfi_last_decision if rfi_last_decision != "" else "")
				)
				rfi_evidence_label.add_theme_color_override("font_color", MUTED)
	_capture_waterfall_row(rfi_waterfall, true)
	scope.queue_redraw()


func _pattern_text(pattern: String) -> String:
	match pattern:
		"pulse_train": return GameManager.text("broad, repeating candidate", "宽缓、重复的候选信号")
		"periodic": return GameManager.text("regular mechanical cadence", "规则机械周期")
		"burst": return GameManager.text("short impulsive bursts", "短促突发")
		"comb": return GameManager.text("equally spaced comb", "等间距梳状谱")
		"swept": return GameManager.text("frequency-swept trace", "扫频轨迹")
		_: return GameManager.text("narrow fixed carrier", "窄带固定载波")


func _draw_rfi_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var spectrum_rect := Rect2(Vector2(30, 16), Vector2(plot.size.x - 60, 220))
	var waterfall_rect := Rect2(Vector2(30, 252), Vector2(plot.size.x - 60, 112))
	_draw_crt_grid(plot, spectrum_rect, 40.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_crt_grid(plot, waterfall_rect, 40.0, Color(0.18, 0.34, 0.38, 0.12))
	var samples := model.spectrum_samples(180, true)
	var points := PackedVector2Array()
	var plot_h := spectrum_rect.size.y - 26.0
	for i in range(samples.size()):
		var x := spectrum_rect.position.x + spectrum_rect.size.x * float(i) / float(samples.size() - 1)
		var y := spectrum_rect.position.y + spectrum_rect.size.y - 6.0 - clampf(float(samples[i]) / 1.4, 0.0, 1.0) * plot_h
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(CRT, 0.22), 5.0, true)
	plot.draw_polyline(points, CRT, 1.7, true)

	for i in range(model.rfi_peaks.size()):
		var peak: Dictionary = model.rfi_peaks[i]
		var x := _mhz_to_x(float(peak["mhz"]), plot.size.x)
		var y := spectrum_rect.position.y + 24.0 + plot_h * (1.0 - clampf(float(peak["strength"]) / 1.2, 0.0, 1.0))
		var mark := str(model.classifications.get(i, ""))
		var color := CYAN if i == selected_peak else AMBER
		if mark == "rfi":
			color = RED
			plot.draw_line(Vector2(x - 10, y - 10), Vector2(x + 10, y + 10), Color(RED, 0.78), 2.0)
			plot.draw_line(Vector2(x + 10, y - 10), Vector2(x - 10, y + 10), Color(RED, 0.78), 2.0)
		elif mark == "source":
			color = GREEN
			plot.draw_arc(Vector2(x, y), 12.0, 0.0, TAU, 24, GREEN, 2.0)
		_draw_peak_signature(plot, Vector2(x, y), str(peak.get("pattern", "fixed_narrow")), color)
		if i == selected_peak:
			plot.draw_rect(Rect2(Vector2(x - 21, y - 26), Vector2(42, 48)), CYAN, false, 2.0)
			_draw_plot_text(plot, "%.0f MHz" % float(peak["mhz"]), Vector2(x - 28, y - 31), 10, CYAN)

	_draw_waterfall(plot, waterfall_rect, rfi_waterfall, true)
	var reviewed_ratio := float(model.classifications.size()) / float(maxi(1, model.rfi_peaks.size()))
	_meter_draw(
		plot,
		Rect2(Vector2(34, plot.size.y - 22), Vector2(plot.size.x - 68, 8)),
		reviewed_ratio,
		GREEN if model.all_classified() else CYAN
	)
	_draw_plot_text(plot, GameManager.text("CLEANING HISTORY", "净化历史"), waterfall_rect.position + Vector2(4, -4), 9, MUTED)
	_draw_plot_text(
		plot,
		GameManager.text(
			"REVIEWED %d/%d   GREEN KEEP   RED REMOVE   AMBER OPEN" % [model.classifications.size(), model.rfi_peaks.size()],
			"已检查 %d/%d   绿色保留   红色剔除   琥珀色待处理" % [model.classifications.size(), model.rfi_peaks.size()]
		),
		Vector2(34, plot.size.y - 28),
		9,
		TEXT
	)


func _draw_peak_signature(plot: RadioPlot, pos: Vector2, pattern: String, color: Color) -> void:
	match pattern:
		"pulse_train":
			plot.draw_arc(pos, 8.0, 0.0, TAU, 24, color, 2.0)
			for offset in [-16.0, 16.0]:
				plot.draw_arc(pos + Vector2(offset, 0), 4.0, 0.0, TAU, 16, Color(color, 0.65), 1.0)
		"periodic":
			for offset in [-9.0, 0.0, 9.0]:
				plot.draw_line(pos + Vector2(offset, 8), pos + Vector2(offset, -8), color, 1.5)
		"burst":
			plot.draw_polyline(PackedVector2Array([
				pos + Vector2(-12, 5), pos + Vector2(-5, 4), pos + Vector2(-2, -10),
				pos + Vector2(2, 8), pos + Vector2(5, -4), pos + Vector2(12, 4),
			]), color, 2.0, true)
		"comb":
			for offset in [-12.0, -6.0, 0.0, 6.0, 12.0]:
				plot.draw_line(pos + Vector2(offset, 7), pos + Vector2(offset, -7 + absf(offset) * 0.25), color, 1.2)
		"swept":
			plot.draw_line(pos + Vector2(-13, 8), pos + Vector2(13, -8), color, 2.0)
		_:
			plot.draw_line(pos + Vector2(0, 10), pos + Vector2(0, -12), color, 2.0)


func _confirm_rfi() -> void:
	if not model.all_classified():
		_terminal_event("SPECTRUM VERIFY", "WAIT", "UNREVIEWED PEAKS")
		status_label.text = GameManager.text("Unreviewed peaks remain. Select each visible feature before verification.", "仍有频谱峰尚未审查。验证前请逐个选择可见特征。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(scope)
		return
	if model.source_deleted():
		_terminal_event("SPECTRUM VERIFY", "REJECT", "CANDIDATE LOST")
		status_label.text = GameManager.text("Verification failed: the celestial candidate was removed. Restore it and review the shape.", "验证失败：天体候选被误删。请根据形态恢复它。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		return
	if model.residual_rfi_count() > 0 or model.classification_score() < model.rfi_threshold:
		_terminal_event("SPECTRUM VERIFY", "REJECT", "RESIDUAL RFI %d" % model.residual_rfi_count())
		status_label.text = GameManager.text("Verification found residual interference. The surviving patterned peak is the evidence.", "验证发现残余干扰。仍然存在的规律性频峰就是证据。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		return
	status_label.text = GameManager.text("Spectrum verified clean. The preserved candidate can now be folded in time.", "频谱净化验证通过。保留的候选信号现在可以进行时间折叠。")
	_terminal_event("SPECTRUM VERIFY", "CLEAN", "RFI REMOVED %d" % model.correctly_rejected_rfi_count())
	_terminal_event("CANDIDATE BAND", "PRESERVED", "REPEATING SKY SOURCE", "", 0.0, true)
	_tutorial_action("rfi_verify")
	_maya_reaction(
		"Human transmitters are gone. What remains repeats like a clock, but we still have to prove its period.",
		"人造发射源已经退去。剩下的信号像时钟一样重复，但我们还要证明它的周期。"
	)
	status_label.add_theme_color_override("font_color", GREEN)
	InteractionFeedback.feedback_sfx_requested.emit("fast_rfi_clean")
	_advance(3)
	_radio_operation_chain(
		GameManager.text("Removed man-made radio interference", "剔除人造射频干扰"),
		GameManager.text("Patterned contaminants vanished while the celestial band remained", "规律污染峰消失，天体频段被保留"),
		GameManager.text("The remaining time series can reveal a repeating period", "剩余时间序列可以寻找重复周期")
	)


# ---------------------------------------------------------------- 4. FOLD
func _build_fold() -> void:
	var signal_panel := _panel_to(content, Vector2(32, 6), Vector2(646, 478), PANEL_DEEP, GOLD, GameManager.text("PULSE RECOVERY", "脉冲恢复"))
	scope = RadioPlot.new()
	scope.position = Vector2(16, 42)
	scope.size = Vector2(614, 414)
	scope.mouse_filter = Control.MOUSE_FILTER_STOP
	scope.mouse_default_cursor_shape = Control.CURSOR_CROSS
	scope.renderer = _draw_fold_plot
	scope.gui_input.connect(_on_fold_plot_gui_input)
	signal_panel.add_child(scope)
	_build_fold_controls_panel()


func _build_fold_controls_panel() -> void:
	if fold_controls_panel != null and is_instance_valid(fold_controls_panel):
		fold_controls_panel.queue_free()
	fold_controls_panel = _panel_to(content, Vector2(694, 6), Vector2(298, 478), PANEL, GOLD, GameManager.text("FOLDING CONSOLE", "折叠控制台"))
	fold_step_label = _label_to(fold_controls_panel, "", Vector2(14, 42), Vector2(270, 28), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	readout = _label_to(fold_controls_panel, "", Vector2(14, 76), Vector2(270, 126), 12, TEXT)
	readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_fold_control(fold_controls_panel)
	_refresh_fold()


func _build_fold_control(parent: Control) -> void:
	fold_slider = null
	fold_phase_slider = null
	fold_action_button = _button(
		GameManager.text("HOLD RECEIVER [SPACE]", "保持接收 [空格]"),
		Vector2(18, 214),
		Vector2(262, 52),
		Color("153249")
	)
	fold_action_button.set_meta("feedback_sfx_suppressed", true)
	fold_action_button.button_down.connect(func() -> void:
		integration_held = true
		_note_player_activity()
		_terminal_event("FOLD BUFFER", "OPEN", "ACCUMULATING WINDOWS")
	)
	fold_action_button.button_up.connect(func() -> void:
		integration_held = false
		_terminal_event("FOLD BUFFER", "HOLD", "%d/%d STABLE" % [fold_stable_windows, FOLD_STABLE_WINDOWS_REQUIRED])
	)
	parent.add_child(fold_action_button)

	fold_confirm_button = _button(
		GameManager.text("CONFIRM CANDIDATE", "确认候选信号"),
		Vector2(18, 278),
		Vector2(262, 48),
		Color("18452f")
	)
	fold_confirm_button.disabled = not fold_candidate_ready
	fold_confirm_button.pressed.connect(_confirm_fold)
	parent.add_child(fold_confirm_button)

	var controls := _label_to(
		parent,
		GameManager.text(
			"Upper trace: drag DM · Lower trace: drag period\nQ/E or wheel: arrival phase",
			"上方轨迹：拖动 DM · 下方轮廓：拖动周期\nQ/E 或滚轮：调整到达相位"
		),
		Vector2(12, 336),
		Vector2(274, 38),
		10,
		MUTED,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var challenge_label := _label_to(parent, _challenge_hint(), Vector2(18, 382), Vector2(262, 58), 11, CRT, HORIZONTAL_ALIGNMENT_CENTER)
	challenge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _challenge_hint() -> String:
	match str(profile.get("challenge", "balanced")):
		"long_integration":
			return GameManager.text("Weak source: hold integration.\nSNR rises with the square root of time.", "微弱源：持续积分。\n信噪比随时间平方根增长。")
		"dm_alignment":
			return GameManager.text("Watch the sub-bands.\nCorrect DM aligns every arrival.", "观察子频段。\n正确 DM 会对齐所有脉冲。")
		"period_search":
			return GameManager.text("A wrong period splits the peak.\nConverge the two profiles.", "错误周期会分裂峰形。\n让两个轮廓逐渐重合。")
		_:
			return GameManager.text("Search period, align dispersion,\nthen integrate for certainty.", "搜索周期并校正色散，\n再通过积分确认信号。")


func _note_fold_adjust_audio() -> void:
	if stage != 3:
		return
	fold_adjust_audio_idle = 0.0
	AudioManager.start_event_loop("fast_fold_adjust", -1.5)


func _stop_fold_adjust_audio(fade_seconds := 0.035) -> void:
	fold_adjust_audio_idle = -1.0
	AudioManager.stop_event_loop("fast_fold_adjust", fade_seconds)


func _on_fold_plot_gui_input(event: InputEvent) -> void:
	if stage != 3 or discovery_running or prediction_running:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				fold_drag_last = button.position
				fold_drag_mode = _fold_drag_region(button.position)
				_note_player_activity()
			else:
				fold_drag_mode = ""
				_stop_fold_adjust_audio()
			accept_event()
			return
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := 1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			var region := _fold_drag_region(button.position)
			if region == "dm":
				model.trial_dm = clampf(model.trial_dm + direction * 0.25, 0.0, maxf(model.true_dm + 35.0, 60.0))
			elif region == "phase":
				model.trial_phase = fposmod(model.trial_phase + direction * 0.012, 1.0)
			else:
				model.trial_period_ms = clampf(
					model.trial_period_ms + direction * 0.5,
					model.true_period_ms * 0.42,
					model.true_period_ms * 2.08
				)
			_fold_parameters_changed(region)
			_note_player_activity()
			_refresh_fold()
			accept_event()
	elif event is InputEventMouseMotion and fold_drag_mode != "":
		var motion := event as InputEventMouseMotion
		var delta_x := motion.position.x - fold_drag_last.x
		fold_drag_last = motion.position
		if absf(delta_x) < 0.05:
			return
		match fold_drag_mode:
			"dm":
				model.trial_dm = clampf(model.trial_dm + delta_x * 0.08, 0.0, maxf(model.true_dm + 35.0, 60.0))
				_tutorial_action("fold_dm_adjust")
			"phase":
				model.trial_phase = fposmod(model.trial_phase + delta_x * 0.0025, 1.0)
				_tutorial_action("fold_phase_adjust")
			_:
				model.trial_period_ms = clampf(
					model.trial_period_ms + delta_x * 1.1,
					model.true_period_ms * 0.42,
					model.true_period_ms * 2.08
				)
				_tutorial_action("fold_period_adjust")
		_fold_parameters_changed(fold_drag_mode)
		_note_player_activity()
		_refresh_fold()
		accept_event()


func _fold_drag_region(local_position: Vector2) -> String:
	if local_position.y <= 224.0:
		return "dm"
	if local_position.x >= 474.0 and local_position.y >= 238.0:
		return "phase"
	return "period"


func _fold_parameters_changed(parameter: String) -> void:
	_note_fold_adjust_audio()
	fold_validation_clock = 0.0
	fold_stable_windows = 0
	fold_candidate_ready = false
	fold_last_peak_phase = -1.0
	fold_profile_history.clear()
	var detail := ""
	match parameter:
		"dm":
			detail = "DM %.2f" % model.trial_dm
			_terminal_event("DEDISPERSION", "TRIM", detail, "fold_dm_trim", 0.32)
		"phase":
			detail = "PHASE %.3f" % model.trial_phase
			_terminal_event("ARRIVAL GATE", "ROTATE", detail, "fold_phase_trim", 0.32)
		_:
			detail = "P %.3f ms" % model.trial_period_ms
			_terminal_event("FOLD DRUM", "SEARCH", detail, "fold_period_trim", 0.32)
	_sync_fold_capture_state()


func _reset_fold_capture_validation(reset_integration: bool) -> void:
	fold_step = 0
	fold_drag_mode = ""
	fold_validation_clock = 0.0
	fold_validation_window_index = 0
	fold_stable_windows = 0
	fold_candidate_ready = false
	fold_profile_history.clear()
	fold_last_peak_phase = -1.0
	integration_held = false
	if reset_integration and model != null:
		model.set_integration(0.0)
	_stop_fold_adjust_audio(0.0)


func _sync_fold_capture_state() -> void:
	if model.dm_match() < 0.72:
		fold_step = 0
	elif model.period_solution_state() != "fundamental" or model.phase_match() < 0.72:
		fold_step = 1
	else:
		fold_step = 2
	fold_candidate_ready = (
		fold_stable_windows >= FOLD_STABLE_WINDOWS_REQUIRED
		and bool(model.report().get("success", false))
	)


func _record_fold_validation_window() -> void:
	fold_validation_window_index += 1
	var profile_window := model.folded_profile_for_window(120, fold_validation_window_index)
	fold_profile_history.append(profile_window)
	while fold_profile_history.size() > FOLD_STABLE_WINDOWS_REQUIRED:
		fold_profile_history.pop_front()
	var peak_phase := model.folded_peak_phase(fold_validation_window_index)
	var signal_is_coherent := (
		model.period_solution_state() == "fundamental"
		and model.dm_match() >= 0.78
		and model.phase_match() >= 0.72
	)
	if not signal_is_coherent:
		fold_stable_windows = 0
	elif fold_last_peak_phase < 0.0:
		fold_stable_windows = 1
	elif model.candidate_window_is_stable(fold_last_peak_phase, fold_validation_window_index):
		fold_stable_windows = mini(FOLD_STABLE_WINDOWS_REQUIRED, fold_stable_windows + 1)
	else:
		fold_stable_windows = 1
	fold_last_peak_phase = peak_phase
	var was_ready := fold_candidate_ready
	_sync_fold_capture_state()
	_terminal_event(
		"FOLD WINDOW %02d" % fold_validation_window_index,
		"STABLE" if signal_is_coherent else "DRIFT",
		"PEAK %.3f  SNR %.1f" % [peak_phase, model.fold_snr()],
		"fold_window",
		0.0,
		fold_candidate_ready
	)
	if fold_candidate_ready and not was_ready:
		integration_held = false
		_terminal_event("REPEATING SOURCE", "CANDIDATE", "3 WINDOWS COHERENT", "", 0.0, true)
		InteractionFeedback.feedback_sfx_requested.emit("fast_tune_locked")
		_tutorial_action("fold_integrate")
	_refresh_fold()


func _fold_solution_label(solution: String) -> String:
	match solution:
		"fundamental":
			return GameManager.text("fundamental candidate", "基频候选")
		"half_period":
			return GameManager.text("half-period double peak", "半周期双峰假解")
		"double_period":
			return GameManager.text("double-period missing beat", "双周期漏拍假解")
	return GameManager.text("phase drift", "相位漂移")


func _fold_next_action_text() -> String:
	if model.dm_match() < 0.72:
		return GameManager.text(
			"Drag the upper sub-band arrivals until the diagonal sweep stands vertical.",
			"拖动上方子频段到达轨迹，直到斜向扫频变为垂直。"
		)
	if model.period_solution_state() != "fundamental":
		return GameManager.text(
			"Drag the two-cycle profile until the peak stops drifting; reject split aliases.",
			"拖动双周期轮廓，让峰停止漂移，并排除分裂的周期假解。"
		)
	if model.phase_match() < 0.72:
		return GameManager.text(
			"Rotate the arrival phase with Q/E or the wheel so the peak clears the plot edge.",
			"用 Q/E 或滚轮调整到达相位，让峰完整进入观察窗。"
		)
	if fold_stable_windows < FOLD_STABLE_WINDOWS_REQUIRED:
		return GameManager.text(
			"Hold the receiver and verify the peak stays put for three consecutive windows.",
			"保持接收，确认脉冲峰在连续三个窗口中位置稳定。"
		)
	if not fold_candidate_ready:
		return GameManager.text(
			"The timing is coherent; keep integrating until the signal rises above the noise.",
			"计时已经相干；继续积分，直到信号可靠地高出噪声。"
		)
	return GameManager.text(
		"Three windows agree. Confirm the candidate, then predict its next arrival.",
		"三个窗口结果一致。确认候选后，预测下一次到达。"
	)


func _fold_keyboard(keycode: Key) -> void:
	var direction := -1.0 if keycode in [KEY_LEFT, KEY_A] else (1.0 if keycode in [KEY_RIGHT, KEY_D] else 0.0)
	var phase_direction := -1.0 if keycode == KEY_Q else (1.0 if keycode == KEY_E else 0.0)
	var dm_direction := -1.0 if keycode in [KEY_DOWN, KEY_S] else (1.0 if keycode in [KEY_UP, KEY_W] else 0.0)
	if phase_direction != 0.0:
		model.trial_phase = fposmod(model.trial_phase + phase_direction * 0.012, 1.0)
		_fold_parameters_changed("phase")
		_note_player_activity()
		_tutorial_action("fold_phase_adjust")
		_refresh_fold()
		return
	if dm_direction != 0.0:
		model.trial_dm = clampf(model.trial_dm + dm_direction * 0.25, 0.0, maxf(model.true_dm + 35.0, 60.0))
		_fold_parameters_changed("dm")
		_note_player_activity()
		_tutorial_action("fold_dm_adjust")
		_refresh_fold()
		return
	if direction != 0.0:
		model.trial_period_ms = clampf(
			model.trial_period_ms + direction * 0.5,
			model.true_period_ms * 0.42,
			model.true_period_ms * 2.08
		)
		_fold_parameters_changed("period")
		_note_player_activity()
		_tutorial_action("fold_period_adjust")
		_refresh_fold()
	elif keycode == KEY_ENTER:
		if fold_candidate_ready:
			_confirm_fold()


func _confirm_fold_step() -> void:
	# Kept as a compatibility entry point for old save/test calls. Calibration
	# is now continuous on one capture desk; it never advances hidden steps.
	_sync_fold_capture_state()
	if fold_candidate_ready:
		_confirm_fold()
	else:
		status_label.text = _fold_next_action_text()
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(scope)


func _refresh_fold() -> void:
	if readout == null or not is_instance_valid(readout):
		return
	_sync_fold_capture_state()
	if fold_step_label != null and is_instance_valid(fold_step_label):
		fold_step_label.text = GameManager.text("PULSE CAPTURE DESK", "脉冲捕获台")
	var snr := model.fold_snr()
	var solution := model.period_solution_state()
	var solution_text := _fold_solution_label(solution)
	readout.text = GameManager.text(
		"Trial DM  %.1f pc/cm³\nTrial period  %.3f ms\nCurrent S/N  %.1f\nCandidate  %s\nStable windows  %d / %d" % [
			model.trial_dm,
			model.trial_period_ms,
			snr,
			solution_text,
			fold_stable_windows,
			FOLD_STABLE_WINDOWS_REQUIRED,
		],
		"试验 DM  %.1f pc/cm³\n试验周期  %.3f ms\n当前信噪比  %.1f\n候选状态  %s\n稳定窗口  %d / %d" % [
			model.trial_dm,
			model.trial_period_ms,
			snr,
			solution_text,
			fold_stable_windows,
			FOLD_STABLE_WINDOWS_REQUIRED,
		]
	)
	readout.add_theme_color_override(
		"font_color",
		GREEN if fold_candidate_ready else (AMBER if fold_step >= 1 else TEXT)
	)
	if fold_confirm_button != null and is_instance_valid(fold_confirm_button):
		fold_confirm_button.disabled = not fold_candidate_ready
		fold_confirm_button.text = (
			GameManager.text("CONFIRM STABLE CANDIDATE", "确认稳定候选")
			if fold_candidate_ready
			else GameManager.text("VERIFY 3 STABLE WINDOWS", "等待 3 个稳定窗口")
		)
	if status_label != null and is_instance_valid(status_label) and not integration_held:
		status_label.text = _fold_next_action_text()
		status_label.add_theme_color_override("font_color", GREEN if fold_candidate_ready else CRT)
	if scope != null and is_instance_valid(scope):
		scope.queue_redraw()


func _draw_fold_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var waterfall_rect := Rect2(Vector2(28, 24), Vector2(plot.size.x - 56, 186))
	var profile_rect := Rect2(Vector2(28, 246), Vector2(430, 140))
	_draw_crt_grid(plot, waterfall_rect, 38.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_crt_grid(plot, profile_rect, 38.0, Color(0.18, 0.34, 0.38, 0.18))
	_draw_plot_text(plot, GameManager.text("DRAG · SUB-BAND ARRIVAL / DISPERSION", "拖动 · 子频段到达 / 色散"), Vector2(28, 17), 10, MUTED)
	_draw_plot_text(plot, GameManager.text("DRAG · TWO-CYCLE FOLDED PROFILE", "拖动 · 双周期折叠轮廓"), Vector2(28, 239), 10, MUTED)

	var offsets := model.subband_offsets(7)
	for row in range(offsets.size()):
		var y := waterfall_rect.position.y + 18.0 + row * 24.0
		plot.draw_line(Vector2(waterfall_rect.position.x, y), Vector2(waterfall_rect.end.x, y), Color(CRT, 0.12), 1.0)
		var center_x := waterfall_rect.position.x + waterfall_rect.size.x * (0.5 + float(offsets[row]))
		var row_color := Color(CYAN, lerpf(0.32, 0.92, model.dm_match()))
		_draw_gaussian_trace(
			plot,
			Vector2(center_x, y),
			12.0 + (1.0 - model.dm_match()) * 24.0,
			row_color
		)
		_draw_plot_text(plot, "B%d" % (row + 1), Vector2(waterfall_rect.position.x - 24, y + 4), 9, MUTED)
	plot.draw_line(
		Vector2(waterfall_rect.get_center().x, waterfall_rect.position.y),
		Vector2(waterfall_rect.get_center().x, waterfall_rect.end.y),
		Color(GREEN if model.dm_match() >= 0.78 else AMBER, 0.44),
		1.0
	)

	var display_profiles: Array = fold_profile_history.duplicate()
	if display_profiles.is_empty():
		display_profiles.append(model.folded_profile_for_window(120, fold_validation_window_index))
	var line_color := GREEN if bool(model.report().get("success", false)) else (CYAN if model.period_match() > 0.45 else AMBER)
	for history_index in range(display_profiles.size()):
		var history_profile: Array = display_profiles[history_index]
		var alpha := lerpf(0.18, 0.95, float(history_index + 1) / float(display_profiles.size()))
		_draw_two_cycle_profile(plot, profile_rect, history_profile, Color(line_color, alpha), history_index)
	var gate_x := profile_rect.position.x + profile_rect.size.x * 0.5
	plot.draw_rect(
		Rect2(Vector2(gate_x - 10.0, profile_rect.position.y), Vector2(20.0, profile_rect.size.y)),
		Color(GREEN if model.phase_match() >= 0.72 else AMBER, 0.08),
		true
	)
	plot.draw_line(Vector2(gate_x, profile_rect.position.y), Vector2(gate_x, profile_rect.end.y), Color(GOLD, 0.48), 1.0)
	_meter_draw(plot, Rect2(Vector2(profile_rect.position.x, plot.size.y - 14), Vector2(profile_rect.size.x, 8)), clampf(model.fold_snr() / maxf(model.report_snr_threshold, 0.1), 0.0, 1.0), GREEN)
	_draw_plot_text(plot, "SNR %.1f" % model.fold_snr(), Vector2(profile_rect.end.x - 70, plot.size.y - 20), 10, GREEN if model.fold_snr() >= model.report_snr_threshold else AMBER)
	_draw_phase_wheel(plot, Vector2(532, 314), 50.0)
	_draw_plot_text(
		plot,
		GameManager.text("STABLE %d/%d" % [fold_stable_windows, FOLD_STABLE_WINDOWS_REQUIRED], "稳定 %d/%d" % [fold_stable_windows, FOLD_STABLE_WINDOWS_REQUIRED]),
		Vector2(482, 390),
		10,
		GREEN if fold_candidate_ready else MUTED
	)


func _draw_two_cycle_profile(
	plot: RadioPlot,
	rect: Rect2,
	profile: Array,
	color: Color,
	history_index: int
) -> void:
	if profile.is_empty():
		return
	var points := PackedVector2Array()
	var max_amp := 1.25
	var sample_count := profile.size() * 2
	for i in range(sample_count):
		var sample_index := i % profile.size()
		var x := rect.position.x + rect.size.x * float(i) / float(maxi(sample_count - 1, 1))
		var deterministic_noise := (
			sin(float(i) * 2.17 + model.integration_s * 0.02 + float(history_index) * 0.71)
			* (1.0 - clampf(model.integration_s / maxf(model.required_integration_s, 1.0), 0.0, 1.0))
			* 0.06
		)
		var y := rect.end.y - clampf((float(profile[sample_index]) + deterministic_noise) / max_amp, 0.0, 1.0) * (rect.size.y - 10.0)
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(color, color.a * 0.22), 5.0, true)
	plot.draw_polyline(points, color, 1.6, true)


func _draw_phase_wheel(plot: RadioPlot, center: Vector2, radius: float) -> void:
	var wheel_color := GREEN if model.phase_match() >= 0.72 else AMBER
	plot.draw_arc(center, radius, 0.0, TAU, 64, Color(BRASS, 0.82), 1.4, true)
	plot.draw_arc(center, radius - 8.0, 0.0, TAU, 64, Color(CRT, 0.18), 1.0, true)
	var gate_width := 0.22
	plot.draw_arc(center, radius + 2.0, -PI * 0.5 - gate_width, -PI * 0.5 + gate_width, 18, GOLD, 5.0, true)
	var phase_angle := -PI * 0.5 + (model.trial_phase - model.true_phase) * TAU
	var marker := center + Vector2(cos(phase_angle), sin(phase_angle)) * (radius - 8.0)
	plot.draw_line(center, marker, Color(wheel_color, 0.45), 1.0)
	plot.draw_circle(marker, 6.0, wheel_color)
	plot.draw_circle(center, 3.0, Color(CRT, 0.8))
	_draw_plot_text(plot, GameManager.text("ARRIVAL GATE", "到达门"), center + Vector2(-42, -62), 9, GOLD)
	_draw_plot_text(plot, "%d%%" % int(model.phase_match() * 100.0), center + Vector2(-15, 5), 10, wheel_color)


func _draw_gaussian_trace(plot: RadioPlot, center: Vector2, width: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var x := center.x - width * 1.8 + width * 3.6 * float(i) / 24.0
		var d := (x - center.x) / maxf(width, 1.0)
		var y := center.y - exp(-d * d) * 13.0
		points.append(Vector2(x, y))
	plot.draw_polyline(points, color, 1.6, true)


func _confirm_fold() -> void:
	if discovery_running or prediction_running:
		return
	_sync_fold_capture_state()
	if not fold_candidate_ready:
		_terminal_event(
			"PULSE CANDIDATE",
			"HOLD",
			"%d/%d STABLE WINDOWS" % [fold_stable_windows, FOLD_STABLE_WINDOWS_REQUIRED]
		)
		status_label.text = _fold_next_action_text()
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(fold_confirm_button if fold_confirm_button != null else scope)
		return
	var rep := model.report()
	if not bool(rep.get("success", false)):
		var reason := model.conclusion_state()
		_terminal_event("PULSE CONFIRM", "REJECT", reason.to_upper())
		match reason:
			"residual_rfi":
				status_label.text = GameManager.text("Residual RFI still contaminates the fold. Return to the cleaning stage.", "残余干扰仍在污染折叠结果。请返回净化阶段。")
			"insufficient_signal":
				status_label.text = GameManager.text("The pulse shape is aligned but not yet significant. Continue integrating.", "脉冲形态已经对齐，但显著性仍不足。请继续积分。")
			_:
				status_label.text = GameManager.text("The pulse is still split or dispersed. Recheck period and DM.", "脉冲仍然分裂或色散。请重新检查周期与 DM。")
		status_label.add_theme_color_override("font_color", RED)
		InteractionFeedback.error(scope)
		return
	_terminal_event("PERIODICITY", "DETECTED", "%.3f ms" % model.trial_period_ms)
	_terminal_event("PULSE PROFILE", "CONFIRMED", "3 WINDOWS · SNR %.1f" % model.fold_snr())
	_tutorial_action("fold_confirm")
	if tutorial_active:
		_finish_stage_tutorial()
	_start_pulse_prediction()


func _start_pulse_prediction() -> void:
	prediction_running = true
	prediction_armed = false
	prediction_confirmed = false
	prediction_misses = 0
	# The display interval is a playable verification window derived from the
	# recovered period. It does not replace or alter the measured period.
	prediction_duration = clampf(model.trial_period_ms / 1000.0 * 10.0, 6.0, 10.0)
	prediction_time_left = prediction_duration
	_terminal_event("TIMING MODEL", "PREDICTING", "NEXT ARRIVAL %.1f s" % prediction_duration, "", 0.0, true)

	prediction_overlay = Panel.new()
	prediction_overlay.name = "PulsePredictionCapture"
	prediction_overlay.position = Vector2(32, 106)
	prediction_overlay.size = Vector2(960, 506)
	prediction_overlay.z_index = 950
	prediction_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	prediction_overlay.add_theme_stylebox_override("panel", _flat(Color("061119"), GOLD, 3))
	add_child(prediction_overlay)

	_label_to(
		prediction_overlay,
		GameManager.text("CLOCK VERIFICATION", "宇宙时钟验证"),
		Vector2(24, 16),
		Vector2(912, 30),
		20,
		GOLD,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_label_to(
		prediction_overlay,
		GameManager.text(
			"The fold predicts the next arrival. Arm the receiver before the pulse reaches the gate.",
			"折叠结果已经预测出下一次到达时刻。请在脉冲抵达接收门前准备接收。"
		),
		Vector2(36, 46),
		Vector2(888, 36),
		12,
		CRT,
		HORIZONTAL_ALIGNMENT_CENTER
	).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	prediction_plot = RadioPlot.new()
	prediction_plot.position = Vector2(64, 88)
	prediction_plot.size = Vector2(832, 278)
	prediction_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prediction_plot.renderer = _draw_prediction_plot
	prediction_overlay.add_child(prediction_plot)

	prediction_countdown_label = _label_to(
		prediction_overlay,
		"",
		Vector2(32, 374),
		Vector2(300, 30),
		18,
		GOLD,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	prediction_state_label = _label_to(
		prediction_overlay,
		"",
		Vector2(32, 408),
		Vector2(514, 54),
		12,
		CRT,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	prediction_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prediction_arm_button = _button(
		GameManager.text("ARM RECEIVER  [SPACE]", "准备接收  [空格]"),
		Vector2(574, 386),
		Vector2(276, 58),
		Color("18452f")
	)
	prediction_arm_button.pressed.connect(_arm_prediction_receiver)
	prediction_overlay.add_child(prediction_arm_button)
	_refresh_prediction_capture()

	if not InteractionFeedback.is_reduced_motion():
		prediction_overlay.modulate.a = 0.0
		var enter := create_tween().bind_node(prediction_overlay)
		enter.tween_property(prediction_overlay, "modulate:a", 1.0, 0.18)


func _arm_prediction_receiver() -> void:
	if not prediction_running or prediction_armed:
		return
	prediction_armed = true
	_note_player_activity()
	_terminal_event("RECEIVER GATE", "ARMED", "WINDOW %.2f s" % prediction_time_left, "", 0.0, true)
	if prediction_arm_button != null and is_instance_valid(prediction_arm_button):
		prediction_arm_button.disabled = true
		prediction_arm_button.text = GameManager.text("RECEIVER ARMED", "接收机已准备")
		InteractionFeedback.success(prediction_arm_button, "fast_receiver_armed")
	_refresh_prediction_capture()


func _refresh_prediction_capture() -> void:
	if not prediction_running:
		return
	if prediction_countdown_label != null and is_instance_valid(prediction_countdown_label):
		prediction_countdown_label.text = GameManager.text(
			"NEXT ARRIVAL  T−%.2f s" % prediction_time_left,
			"下一次到达  T−%.2f 秒" % prediction_time_left
		)
		prediction_countdown_label.add_theme_color_override("font_color", GREEN if prediction_armed else GOLD)
	if prediction_state_label != null and is_instance_valid(prediction_state_label):
		prediction_state_label.text = GameManager.text(
			"Gate open. Hold the timing model steady; the next pulse will test your prediction." if prediction_armed else "Receiver is not armed. Press Space or use the button before T−0.",
			"接收门已打开。保持计时模型稳定，下一拍将检验你的预测。" if prediction_armed else "接收机尚未准备。请在倒计时归零前按空格或点击按钮。"
		)
		prediction_state_label.add_theme_color_override("font_color", GREEN if prediction_armed else AMBER)
	if prediction_plot != null and is_instance_valid(prediction_plot):
		prediction_plot.queue_redraw()


func _resolve_prediction_window(force_hit: bool = false) -> void:
	if not prediction_running:
		return
	if force_hit:
		prediction_armed = true
	if not prediction_armed:
		prediction_misses += 1
		prediction_time_left = clampf(prediction_duration * 0.72, 4.0, 7.0)
		_terminal_event("PREDICTED ARRIVAL", "MISSED", "NEXT BEAT %.1f s" % prediction_time_left, "", 0.0, true)
		if prediction_state_label != null and is_instance_valid(prediction_state_label):
			prediction_state_label.text = GameManager.text(
				"The pulse passed while the receiver gate was closed. The timing solution is intact; arm for the next beat.",
				"脉冲抵达时接收门尚未打开。计时解没有丢失，请准备接收下一拍。"
			)
			prediction_state_label.add_theme_color_override("font_color", AMBER)
		if prediction_arm_button != null and is_instance_valid(prediction_arm_button):
			prediction_arm_button.disabled = false
			prediction_arm_button.text = GameManager.text("ARM FOR NEXT BEAT  [SPACE]", "准备接收下一拍  [空格]")
			InteractionFeedback.error(prediction_arm_button)
		return

	prediction_running = false
	prediction_confirmed = true
	_terminal_event("PREDICTED ARRIVAL", "CAPTURED", "RESIDUAL < 1 WINDOW", "", 0.0, true)
	_terminal_event("CLOCK MODEL", "CONFIRMED", str(model.target_id).to_upper(), "", 0.0, true)
	if prediction_countdown_label != null and is_instance_valid(prediction_countdown_label):
		prediction_countdown_label.text = GameManager.text("PULSE ARRIVED IN GATE", "脉冲已抵达接收门")
		prediction_countdown_label.add_theme_color_override("font_color", GREEN)
	if prediction_state_label != null and is_instance_valid(prediction_state_label):
		prediction_state_label.text = GameManager.text(
			"RAW → FOLDED → PREDICTED: the next radio pulse arrived when your timing model said it would.",
			"原始信号 → 折叠轮廓 → 到达预测：下一次射电脉冲在计时模型预报的时刻抵达。"
		)
		prediction_state_label.add_theme_color_override("font_color", GREEN)
	if prediction_arm_button != null and is_instance_valid(prediction_arm_button):
		prediction_arm_button.disabled = true
		prediction_arm_button.text = GameManager.text("CLOCK CONFIRMED", "宇宙时钟已确认")
	if prediction_plot != null and is_instance_valid(prediction_plot):
		prediction_plot.queue_redraw()
	InteractionFeedback.feedback_sfx_requested.emit("fast_discovery")
	call_deferred("_finish_prediction_capture")


func _finish_prediction_capture() -> void:
	await get_tree().create_timer(0.85 if not InteractionFeedback.is_reduced_motion() else 0.20).timeout
	if prediction_overlay != null and is_instance_valid(prediction_overlay):
		prediction_overlay.queue_free()
	prediction_overlay = null
	prediction_plot = null
	await _play_discovery_moment()
	_advance(4)
	_radio_operation_chain(
		GameManager.text("Predicted and captured the next pulse", "预测并捕获下一次脉冲"),
		GameManager.text("The recovered period opened the receiver gate at the correct arrival time", "恢复出的周期让接收门在正确的到达时刻打开"),
		GameManager.text("The source is a stable cosmic clock, not a random burst", "信号源是一座稳定的宇宙时钟，而不是随机爆发")
	)


func _draw_prediction_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("041018"), true)
	var raw_rect := Rect2(Vector2(12, 28), Vector2(252, 218))
	var folded_rect := Rect2(Vector2(290, 28), Vector2(252, 218))
	var predicted_rect := Rect2(Vector2(568, 28), Vector2(252, 218))
	for rect in [raw_rect, folded_rect, predicted_rect]:
		_draw_crt_grid(plot, rect, 28.0, Color(0.20, 0.40, 0.42, 0.14))
		plot.draw_rect(rect, Color(BRASS, 0.58), false, 1.0)
	_draw_plot_text(plot, GameManager.text("RAW · UNCERTAIN", "原始 · 候选"), Vector2(18, 20), 10, MUTED)
	_draw_plot_text(plot, GameManager.text("FOLDED · PERIODIC", "折叠 · 周期"), Vector2(296, 20), 10, CYAN)
	_draw_plot_text(plot, GameManager.text("PREDICTED · ARRIVAL", "预测 · 到达"), Vector2(574, 20), 10, GREEN if prediction_confirmed else GOLD)

	var raw_points := PackedVector2Array()
	for i in range(100):
		var x := raw_rect.position.x + 8.0 + (raw_rect.size.x - 16.0) * float(i) / 99.0
		var noise := sin(float(i) * 2.81) * 0.24 + sin(float(i) * 0.71) * 0.12
		var pulse := exp(-pow((float(i) - 54.0) / 10.0, 2.0)) * 0.24
		var y := raw_rect.get_center().y - (noise + pulse) * 82.0
		raw_points.append(Vector2(x, y))
	plot.draw_polyline(raw_points, Color(CRT, 0.66), 1.2, true)

	var profile := model.folded_profile(120)
	var folded_points := PackedVector2Array()
	for i in range(profile.size()):
		var x := folded_rect.position.x + 8.0 + (folded_rect.size.x - 16.0) * float(i) / float(profile.size() - 1)
		var y := folded_rect.end.y - 18.0 - clampf(float(profile[i]), 0.0, 1.2) * 154.0
		folded_points.append(Vector2(x, y))
	plot.draw_polyline(folded_points, Color(CYAN, 0.22), 6.0, true)
	plot.draw_polyline(folded_points, CYAN, 1.8, true)

	var gate_x := predicted_rect.get_center().x
	var travel := 1.0 - clampf(prediction_time_left / maxf(prediction_duration, 0.01), 0.0, 1.0)
	var pulse_x := lerpf(predicted_rect.position.x + 12.0, gate_x, travel)
	plot.draw_rect(Rect2(Vector2(gate_x - 12.0, predicted_rect.position.y + 10.0), Vector2(24.0, predicted_rect.size.y - 20.0)), Color(GREEN if prediction_armed else AMBER, 0.10), true)
	plot.draw_line(Vector2(gate_x, predicted_rect.position.y + 8.0), Vector2(gate_x, predicted_rect.end.y - 8.0), GREEN if prediction_armed else AMBER, 2.0)
	plot.draw_line(Vector2(pulse_x, predicted_rect.end.y - 22.0), Vector2(pulse_x, predicted_rect.position.y + 42.0), Color(CRT, 0.82), 2.0)
	if prediction_confirmed:
		plot.draw_line(Vector2(gate_x, predicted_rect.end.y - 18.0), Vector2(gate_x, predicted_rect.position.y + 24.0), GREEN, 5.0)
		_draw_plot_text(plot, GameManager.text("CLOCK CONFIRMED", "宇宙时钟已确认"), predicted_rect.position + Vector2(52, 196), 11, GREEN)
	else:
		_draw_plot_text(plot, "T−%.2f s" % prediction_time_left, predicted_rect.position + Vector2(88, 196), 12, GOLD)


func _play_discovery_moment() -> void:
	discovery_running = true
	integration_held = false
	discovery_phase = 0.0
	discovery_event_trace.clear()
	var overlay := Panel.new()
	overlay.name = "FastDiscoveryMoment"
	overlay.position = Vector2(70, 112)
	overlay.size = Vector2(884, 492)
	overlay.z_index = 950
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_theme_stylebox_override("panel", _flat(Color("061119"), GOLD, 3))
	add_child(overlay)
	var title := _label_to(overlay, GameManager.text("FIRST PULSE", "首次脉冲确认"), Vector2(24, 18), Vector2(836, 34), 22, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	discovery_plot = RadioPlot.new()
	discovery_plot.position = Vector2(28, 62)
	discovery_plot.size = Vector2(828, 292)
	discovery_plot.renderer = _draw_discovery_plot
	overlay.add_child(discovery_plot)
	var printout := _label_to(overlay, "", Vector2(48, 366), Vector2(788, 66), 13, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	printout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var maya_line := _label_to(
		overlay,
		GameManager.text(
			"You did not take a picture. You proved that a dead star is still speaking in time.",
			"你没有拍下一张照片。你证明了一颗死去的恒星仍在用时间说话。"
		),
		Vector2(48, 434),
		Vector2(788, 42),
		13,
		CYAN,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	maya_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	InteractionFeedback.feedback_sfx_requested.emit("fast_discovery")
	if not InteractionFeedback.is_reduced_motion():
		overlay.modulate.a = 0.0
		overlay.scale = Vector2(1.02, 0.98)
		overlay.pivot_offset = overlay.size * 0.5
		var enter := create_tween().bind_node(overlay).set_parallel(true)
		enter.tween_property(overlay, "modulate:a", 1.0, 0.18)
		enter.tween_property(overlay, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var pulse := create_tween().bind_node(title)
		pulse.tween_property(title, "modulate", GREEN, 0.28)
		pulse.tween_property(title, "modulate", GOLD, 0.38)
	var sequence := [
		["SUB-BANDS ALIGNED", GameManager.text("SUB-BANDS ............ ALIGNED", "子频段 .............. 已对齐")],
		["WATERFALL PERIODIC", GameManager.text("CLEAN WATERFALL ...... PERIODIC", "净化瀑布图 .......... 周期稳定")],
		["PROFILE EMERGED", GameManager.text("FOLDED PROFILE ....... EMERGED", "折叠轮廓 ............ 已显现")],
		["REPEATING SOURCE CONFIRMED", GameManager.text("REPEATING SOURCE ..... CONFIRMED", "重复信号源 .......... 已确认")],
	]
	for i in range(sequence.size()):
		if not is_instance_valid(printout) or not is_inside_tree():
			discovery_running = false
			discovery_plot = null
			return
		discovery_event_trace.append(str(sequence[i][0]))
		printout.text += ("" if printout.text == "" else "\n") + str(sequence[i][1])
		_terminal_event(str(sequence[i][0]), "LOCKED" if i == sequence.size() - 1 else "RUN", "", "", 0.0, i == sequence.size() - 1)
		var target_phase := float(i + 1) / float(sequence.size())
		var tween := create_tween().bind_node(self)
		tween.tween_method(func(value: float) -> void:
			discovery_phase = value
			if discovery_plot != null and is_instance_valid(discovery_plot):
				discovery_plot.queue_redraw()
		, discovery_phase, target_phase, 0.40 if not InteractionFeedback.is_reduced_motion() else 0.10)
		await tween.finished
		if i == 2:
			await get_tree().create_timer(0.18 if not InteractionFeedback.is_reduced_motion() else 0.03).timeout
	_terminal_event("KNOWN PULSAR", "INDEPENDENTLY CONFIRMED", "PSR %s" % str(model.target_id).to_upper(), "", 0.0, true)
	await get_tree().create_timer(0.55 if not InteractionFeedback.is_reduced_motion() else 0.16).timeout
	if is_instance_valid(overlay):
		overlay.queue_free()
	discovery_plot = null
	discovery_running = false


func _draw_discovery_plot(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("041018"), true)
	var subband_rect := Rect2(Vector2(12, 14), Vector2(258, 248))
	var waterfall_rect := Rect2(Vector2(285, 14), Vector2(246, 248))
	var profile_rect := Rect2(Vector2(546, 14), Vector2(270, 248))
	for rect in [subband_rect, waterfall_rect, profile_rect]:
		_draw_crt_grid(plot, rect, 28.0, Color(0.20, 0.40, 0.42, 0.16))
		plot.draw_rect(rect, Color(BRASS, 0.55), false, 1.0)

	_draw_plot_text(plot, GameManager.text("SUB-BANDS", "子频段"), subband_rect.position + Vector2(8, 14), 10, MUTED)
	var offsets := model.subband_offsets(7)
	for row in range(offsets.size()):
		var y := subband_rect.position.y + 42.0 + row * 27.0
		var correction := lerpf(float(offsets[row]), 0.0, discovery_phase)
		var x := subband_rect.position.x + subband_rect.size.x * (0.50 + correction)
		plot.draw_line(Vector2(subband_rect.position.x + 12, y), Vector2(subband_rect.end.x - 12, y), Color(CRT, 0.10), 1.0)
		_draw_gaussian_trace(plot, Vector2(x, y), lerpf(19.0, 9.0, discovery_phase), Color(CYAN, 0.38 + discovery_phase * 0.56))

	_draw_plot_text(plot, GameManager.text("CLEAN WATERFALL", "净化瀑布图"), waterfall_rect.position + Vector2(8, 14), 10, MUTED)
	for row in range(26):
		var y := waterfall_rect.position.y + 34.0 + row * 7.6
		var phase_x := waterfall_rect.position.x + waterfall_rect.size.x * (0.50 + sin(float(row) * 0.77) * (1.0 - discovery_phase) * 0.16)
		var alpha := 0.12 + discovery_phase * 0.48
		plot.draw_line(Vector2(waterfall_rect.position.x + 8, y), Vector2(waterfall_rect.end.x - 8, y), Color(CRT, 0.04), 1.0)
		plot.draw_rect(Rect2(Vector2(phase_x - 3, y - 2), Vector2(6, 4)), Color(CYAN, alpha), true)
		if row % 5 == 0:
			plot.draw_rect(Rect2(Vector2(phase_x - 10, y - 1), Vector2(20, 2)), Color(GREEN, alpha * 0.62), true)

	_draw_plot_text(plot, GameManager.text("FOLDED PROFILE", "折叠轮廓"), profile_rect.position + Vector2(8, 14), 10, MUTED)
	var values := model.folded_profile(120)
	var points := PackedVector2Array()
	for i in range(values.size()):
		var x := profile_rect.position.x + 10.0 + (profile_rect.size.x - 20.0) * float(i) / float(values.size() - 1)
		var noise := sin(float(i) * 2.91) * (1.0 - discovery_phase) * 0.12
		var y := profile_rect.end.y - 18.0 - clampf(float(values[i]) + noise, 0.0, 1.2) * 148.0
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(GREEN, 0.14 + discovery_phase * 0.18), 7.0, true)
	plot.draw_polyline(points, Color(GREEN, 0.42 + discovery_phase * 0.58), 2.2, true)
	_draw_plot_text(
		plot,
		"%.3f ms · DM %.2f · SNR %.1f" % [model.trial_period_ms, model.trial_dm, model.fold_snr()],
		profile_rect.position + Vector2(12, 32),
		10,
		GREEN
	)


# ---------------------------------------------------------------- 5. REPORT
func _build_report() -> void:
	var rep := model.report()
	report_choice = ""
	report_product = model.science_product(72, 24)
	report_analysis_progress = 1.0 if InteractionFeedback.is_reduced_motion() else 0.0
	report_analysis_elapsed = 0.0
	report_analysis_phase = -1
	report_analysis_running = not InteractionFeedback.is_reduced_motion()
	var report_panel := _panel_to(content, Vector2(32, 6), Vector2(960, 478), PANEL, GOLD, GameManager.text("RADIO OBSERVATION REPORT", "射电观测报告"))
	report_panel_ref = report_panel
	report_choices_holder = report_panel
	_label_to(report_panel, GameManager.text("FAST SCIENCE DATA PRODUCT", "FAST 科学数据成果"), Vector2(20, 38), Vector2(566, 24), 14, GOLD)
	report_product_plot = RadioPlot.new()
	report_product_plot.name = "FastScienceProductPlot"
	report_product_plot.position = Vector2(20, 62)
	report_product_plot.size = Vector2(574, 304)
	report_product_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	report_product_plot.renderer = _draw_report_product
	report_panel.add_child(report_product_plot)
	var rows := [
		[GameManager.text("Period", "周期"), "%.3f ms" % float(rep["trial_period_ms"])],
		["DM", "%.2f pc/cm³" % float(rep["trial_dm"])],
		["SNR", "%.1f" % float(rep["snr"])],
		[GameManager.text("Integration", "积分"), "%.0f s" % float(rep["integration_s"])],
		[GameManager.text("RFI removed", "剔除干扰"), "%d" % int(rep["rfi_cleared"])],
		[GameManager.text("Pulse width", "脉冲宽度"), "%.2f ms" % float(rep.get("pulse_width_ms", 0.0))],
	]
	for i in range(rows.size()):
		var col := i % 3
		var row_index := i / 3
		var x := 22.0 + float(col) * 190.0
		var y := 370.0 + float(row_index) * 38.0
		_label_to(report_panel, str(rows[i][0]), Vector2(x, y), Vector2(178, 16), 9, MUTED)
		_label_to(report_panel, str(rows[i][1]), Vector2(x, y + 14), Vector2(178, 20), 12, TEXT)
	var science_text := GameManager.text(
		"Radio timing result: the pulse is recovered from repeated arrival times, not from an optical image.",
		"射电计时结果：脉冲来自重复到达时刻的叠加，并不是一张光学照片。"
	)
	var science := _label_to(report_panel, science_text, Vector2(22, 444), Vector2(566, 26), 10, CRT)
	science.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	science.clip_text = true

	var divider := ColorRect.new()
	divider.position = Vector2(606, 48)
	divider.size = Vector2(1, 390)
	divider.color = Color(BRASS, 0.65)
	report_panel.add_child(divider)
	_label_to(report_panel, GameManager.text("EVIDENCE CHAIN", "证据链"), Vector2(622, 38), Vector2(314, 24), 14, GOLD)
	report_evidence_label = _label_to(
		report_panel,
		_report_evidence_chain_text(),
		Vector2(622, 64),
		Vector2(316, 116),
		10,
		CRT
	)
	report_evidence_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_evidence_label.clip_text = true
	_label_to(report_panel, GameManager.text("CONCLUSION", "科学结论"), Vector2(622, 184), Vector2(314, 22), 13, GOLD)
	var positive_key := "stable_pulsar"
	var positive_title := GameManager.text("Stable pulsar candidate", "稳定脉冲星候选")
	var positive_evidence := GameManager.text("Period, DM and SNR agree.", "周期、DM 与信噪比相互吻合。")
	if str(model.target_kind) in ["hi_line", "hydrogen"]:
		positive_key = "confirmed_hi"
		positive_title = GameManager.text("Neutral-hydrogen line confirmed", "中性氢谱线已确认")
		positive_evidence = GameManager.text("A coherent 21 cm velocity profile remains.", "净化后保留了相干的 21 厘米速度轮廓。")
	elif str(model.target_kind) in ["repeating_frb", "frb"]:
		positive_key = "confirmed_frb"
		positive_title = GameManager.text("Repeating dispersed burst confirmed", "重复色散爆发已确认")
		positive_evidence = GameManager.text("The cleaned dispersion sweep repeats.", "净化后的色散扫频再次出现。")
	var choices := [
		[positive_key, positive_title, positive_evidence],
		["residual_rfi", GameManager.text("Residual interference dominates", "残余干扰占主导"), GameManager.text("Patterned contamination remains.", "频谱中仍有规律性污染。")],
		["insufficient_signal", GameManager.text("Signal remains insufficient", "信号仍然不足"), GameManager.text("The folded peak is not yet credible.", "折叠峰尚未可靠高出噪声。")],
	]
	choices = _ordered_report_choices(choices)
	report_choice_buttons.clear()
	for i in range(choices.size()):
		var key := str(choices[i][0])
		var button := _button("", Vector2(622, 210 + i * 61), Vector2(314, 54), Color("0b1117"))
		button.name = "ReportChoice_%s" % key
		button.set_meta("choice_key", key)
		button.set_meta("choice_title", str(choices[i][1]))
		button.set_meta("choice_evidence", str(choices[i][2]))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_select_report_choice.bind(key))
		button.disabled = report_analysis_running
		button.modulate.a = 0.42 if report_analysis_running else 1.0
		report_panel.add_child(button)
		report_choice_buttons[key] = button
	var free_report := GameManager.is_remote_free_observation("radio")
	report_reanalyse_button = _button(GameManager.text("REANALYSE", "重新分析"), Vector2(622, 402), Vector2(94, 42), Color("222b31"))
	report_reanalyse_button.disabled = report_analysis_running
	report_reanalyse_button.pressed.connect(_reanalyse_report)
	report_panel.add_child(report_reanalyse_button)
	report_next_target_button = null
	if free_report:
		report_next_target_button = _button(GameManager.text("NEXT TARGET", "下个目标"), Vector2(722, 402), Vector2(104, 42), Color("172d38"))
		report_next_target_button.disabled = true
		report_next_target_button.pressed.connect(_archive_and_choose_next_target)
		report_panel.add_child(report_next_target_button)
	submit_button = _button(
		GameManager.text("ARCHIVE", "归档"),
		Vector2(832 if free_report else 722, 402),
		Vector2(104 if free_report else 214, 42),
		Color("18452f")
	)
	submit_button.disabled = true
	submit_button.pressed.connect(_submit)
	report_panel.add_child(submit_button)
	report_analysis_status = _label_to(
		report_panel,
		GameManager.text("ANALYSIS: reconstructing evidence chain", "分析中：正在重建证据链"),
		Vector2(622, 450),
		Vector2(220, 18),
		9,
		AMBER
	)
	report_analysis_skip_button = _button(GameManager.text("SKIP", "跳过"), Vector2(850, 446), Vector2(86, 24), Color("111d29"))
	report_analysis_skip_button.disabled = report_analysis_running
	report_analysis_skip_button.pressed.connect(_finish_report_analysis)
	report_panel.add_child(report_analysis_skip_button)
	if not report_analysis_running:
		_finish_report_analysis()
	_refresh_report_choice()


func _advance_report_analysis(delta: float) -> void:
	if not report_analysis_running:
		return
	report_analysis_elapsed += delta
	report_analysis_progress = clampf(report_analysis_elapsed / REPORT_ANALYSIS_DURATION, 0.0, 1.0)
	var phase := mini(4, int(floor(report_analysis_progress * 5.0)))
	if phase != report_analysis_phase:
		report_analysis_phase = phase
		var events := [
			["RAW BUFFER", "INGEST", "NOISE + SKY SIGNAL"],
			["RFI MASK", "APPLIED", "%d REMOVED" % int(report_product.get("removed_rfi_count", 0))],
			["DISPERSION", "CORRECTED", "DM %.2f" % model.trial_dm],
			["PERIOD FOLD", "STACKED", "%.3f ms" % model.trial_period_ms],
			["EVIDENCE CHAIN", "READY", "SNR %.1f" % model.fold_snr()],
		]
		_terminal_event(str(events[phase][0]), str(events[phase][1]), str(events[phase][2]), "", 0.0, phase == 4)
	if report_analysis_skip_button != null and is_instance_valid(report_analysis_skip_button):
		report_analysis_skip_button.disabled = report_analysis_elapsed < REPORT_ANALYSIS_SKIP_DELAY
	if report_analysis_status != null and is_instance_valid(report_analysis_status):
		var statuses := [
			GameManager.text("ANALYSIS: ingesting raw receiver buffer", "分析中：正在读入原始接收数据"),
			GameManager.text("ANALYSIS: removing classified interference", "分析中：正在剔除已标记干扰"),
			GameManager.text("ANALYSIS: correcting frequency-dependent delay", "分析中：正在校正频率相关延迟"),
			GameManager.text("ANALYSIS: folding repeated arrival times", "分析中：正在折叠重复到达时刻"),
			GameManager.text("ANALYSIS: evidence chain ready", "分析完成：证据链已建立"),
		]
		report_analysis_status.text = statuses[phase]
	if report_product_plot != null and is_instance_valid(report_product_plot):
		report_product_plot.queue_redraw()
	if report_analysis_progress >= 1.0:
		_finish_report_analysis()


func _finish_report_analysis() -> void:
	report_analysis_running = false
	report_analysis_progress = 1.0
	report_analysis_phase = 4
	if report_product_plot != null and is_instance_valid(report_product_plot):
		report_product_plot.queue_redraw()
	if report_analysis_status != null and is_instance_valid(report_analysis_status):
		report_analysis_status.text = GameManager.text("EVIDENCE READY · choose the supported conclusion", "证据已就绪 · 请选择有数据支持的结论")
		report_analysis_status.add_theme_color_override("font_color", GREEN)
	if report_analysis_skip_button != null and is_instance_valid(report_analysis_skip_button):
		report_analysis_skip_button.visible = false
	for key in report_choice_buttons:
		var button := report_choice_buttons[key] as Button
		button.disabled = false
		button.modulate.a = 1.0
	if report_reanalyse_button != null and is_instance_valid(report_reanalyse_button):
		report_reanalyse_button.disabled = false
	if report_next_target_button != null and is_instance_valid(report_next_target_button):
		report_next_target_button.disabled = report_choice == ""
	_refresh_report_choice()


func _reanalyse_report() -> void:
	if report_analysis_running or running or stage_transition_active:
		return
	_reset_report_choice()
	_reset_fold_capture_validation(true)
	_terminal_event("SCIENCE PRODUCT", "REOPEN", "PERIOD SEARCH", "", 0.0, true)
	_begin_stage_handoff(3)


func _reset_report_choice() -> void:
	report_choice = ""
	_refresh_report_choice()


func _archive_and_choose_next_target() -> void:
	if report_analysis_running or running or report_choice == "":
		return
	report_choose_next_requested = true
	_submit()


func _report_evidence_chain_text() -> String:
	if report_product.is_empty():
		return ""
	return GameManager.text(
		"POINTING  %.0f%%  → received power\nPASSBAND  %.0f%%  → candidate retained\nRFI  %d/%d removed → noise floor lower\nFOLD  P %.0f%% · DM %.0f%% → peak SNR %.1f" % [
			float(report_product.get("pointing_quality", 0.0)) * 100.0,
			float(report_product.get("tuning_quality", 0.0)) * 100.0,
			int(report_product.get("removed_rfi_count", 0)),
			int(report_product.get("raw_rfi_count", 0)),
			float(report_product.get("period_quality", 0.0)) * 100.0,
			float(report_product.get("dm_quality", 0.0)) * 100.0,
			model.fold_snr(),
		],
		"指向  %.0f%%  → 接收功率\n通带  %.0f%%  → 候选信号保留\n干扰  已剔除 %d/%d → 噪声底下降\n折叠  周期 %.0f%% · DM %.0f%% → 峰值 SNR %.1f" % [
			float(report_product.get("pointing_quality", 0.0)) * 100.0,
			float(report_product.get("tuning_quality", 0.0)) * 100.0,
			int(report_product.get("removed_rfi_count", 0)),
			int(report_product.get("raw_rfi_count", 0)),
			float(report_product.get("period_quality", 0.0)) * 100.0,
			float(report_product.get("dm_quality", 0.0)) * 100.0,
			model.fold_snr(),
		]
	)


func _ordered_report_choices(choices: Array) -> Array:
	if choices.size() < 2:
		return choices.duplicate(true)
	# Rebuilding the report or changing language must not move a choice under
	# the pointer. Adjacent FAST levels alternate the successful evidence
	# conclusion between the second and third slot; evaluation still uses IDs.
	var level_number := int(GameManager.current_level().get("level_number", 0))
	var rotation := 1 + posmod(level_number, choices.size() - 1)
	var ordered: Array = []
	for index in range(choices.size()):
		ordered.append(choices[(index + rotation) % choices.size()])
	return ordered


func _draw_report_product(plot: RadioPlot) -> void:
	if str(model.target_kind) in ["hi_line", "hydrogen"]:
		_draw_hi_report_product(plot)
		return
	if str(model.target_kind) in ["repeating_frb", "frb"]:
		_draw_frb_report_product(plot)
		return
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var waterfall_rect := Rect2(Vector2(8, 22), Vector2(558, 100))
	var raw_dm_rect := Rect2(Vector2(8, 148), Vector2(272, 62))
	var corrected_dm_rect := Rect2(Vector2(294, 148), Vector2(272, 62))
	var folded_rect := Rect2(Vector2(8, 236), Vector2(558, 60))
	for rect in [waterfall_rect, raw_dm_rect, corrected_dm_rect, folded_rect]:
		_draw_crt_grid(plot, rect, 22.0, Color(0.18, 0.34, 0.38, 0.14))
		plot.draw_rect(rect, Color(BRASS, 0.48), false, 1.0)
	_draw_plot_text(plot, GameManager.text("TIME-FREQUENCY WATERFALL · RAW → RFI CLEAN", "时频瀑布图 · 原始 → 干扰净化"), Vector2(12, 14), 9, GOLD)
	_draw_plot_text(plot, GameManager.text("DISPERSION BEFORE", "色散校正前"), raw_dm_rect.position + Vector2(4, -5), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("DM-CORRECTED", "色散校正后"), corrected_dm_rect.position + Vector2(4, -5), 9, CYAN)
	_draw_plot_text(plot, GameManager.text("TWO-PERIOD FOLDED PROFILE", "双周期折叠轮廓"), folded_rect.position + Vector2(4, -5), 9, GREEN)
	_draw_science_waterfall(plot, waterfall_rect)
	_draw_dispersion_evidence(plot, raw_dm_rect, false)
	_draw_dispersion_evidence(plot, corrected_dm_rect, true)
	_draw_folded_science_profile(plot, folded_rect)


func _draw_science_waterfall(plot: RadioPlot, rect: Rect2) -> void:
	var raw: Array = report_product.get("raw_spectrum", [])
	var clean: Array = report_product.get("clean_spectrum", [])
	if raw.is_empty() or clean.is_empty():
		return
	var frequency_bins := raw.size()
	var time_bins := (raw[0] as Array).size()
	var reveal := clampf((report_analysis_progress - 0.02) / 0.38, 0.0, 1.0)
	var visible_columns := maxi(1, int(float(time_bins) * reveal))
	var half_width := (rect.size.x - 5.0) * 0.5
	for side in range(2):
		var spectrum: Array = raw if side == 0 else clean
		var side_x := rect.position.x + 2.0 + float(side) * (half_width + 3.0)
		for frequency_index in range(frequency_bins):
			for time_index in range(mini(time_bins, visible_columns)):
				var value := float((spectrum[frequency_index] as Array)[time_index])
				var cell_x := side_x + float(time_index) * half_width / float(time_bins)
				var cell_y := rect.end.y - 2.0 - float(frequency_index + 1) * (rect.size.y - 4.0) / float(frequency_bins)
				var color := Color(
					lerpf(0.025, 0.42, value),
					lerpf(0.045, 0.86, value),
					lerpf(0.055, 0.74, value),
					0.92
				)
				plot.draw_rect(
					Rect2(
						Vector2(cell_x, cell_y),
						Vector2(half_width / float(time_bins) + 0.35, (rect.size.y - 4.0) / float(frequency_bins) + 0.35)
					),
					color,
					true
				)
	_draw_plot_text(plot, GameManager.text("RAW", "原始"), rect.position + Vector2(5, 12), 8, MUTED)
	_draw_plot_text(plot, GameManager.text("CLEAN", "净化"), rect.position + Vector2(half_width + 9, 12), 8, CYAN)
	plot.draw_line(Vector2(rect.position.x + half_width + 2.5, rect.position.y), Vector2(rect.position.x + half_width + 2.5, rect.end.y), Color(BRASS, 0.65), 1.0)
	for mark_value in report_product.get("rfi_marks", []):
		var mark: Dictionary = mark_value
		var y := rect.end.y - 2.0 - float(mark.get("frequency_normalized", 0.5)) * (rect.size.y - 4.0)
		plot.draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.position.x + half_width, y), Color(RED, 0.70), 1.0)
		var clean_color := Color(GREEN, 0.58) if bool(mark.get("removed", false)) else Color(RED, 0.70)
		plot.draw_line(Vector2(rect.position.x + half_width + 5, y), Vector2(rect.end.x - 2, y), clean_color, 1.0)


func _draw_dispersion_evidence(plot: RadioPlot, rect: Rect2, corrected: bool) -> void:
	var reveal_start := 0.38 if not corrected else 0.52
	var reveal := clampf((report_analysis_progress - reveal_start) / 0.20, 0.0, 1.0)
	if reveal <= 0.0:
		return
	var rows := 10
	var mismatch := 1.0 if not corrected else 1.0 - float(report_product.get("dm_quality", 0.0))
	for row in range(rows):
		var frequency_normalized := float(row) / float(rows - 1)
		var y := rect.position.y + 7.0 + frequency_normalized * (rect.size.y - 14.0)
		var arrival := 0.32 + (1.0 - frequency_normalized) * mismatch * 0.46
		var x := rect.position.x + 8.0 + arrival * (rect.size.x - 16.0)
		var pulse_width := lerpf(10.0, 4.0, float(report_product.get("dm_quality", 0.0)) if corrected else 0.0)
		plot.draw_line(Vector2(rect.position.x + 6.0, y), Vector2(rect.end.x - 6.0, y), Color(CRT, 0.07), 1.0)
		plot.draw_line(Vector2(x - pulse_width, y), Vector2(x + pulse_width, y), Color(CYAN if corrected else AMBER, 0.25 + reveal * 0.62), 2.0)
	if corrected:
		_draw_plot_text(plot, "DM %.2f pc/cm³" % model.trial_dm, rect.position + Vector2(166, 12), 8, GREEN)
	else:
		_draw_plot_text(plot, GameManager.text("frequency delay", "低频延迟"), rect.position + Vector2(168, 12), 8, AMBER)


func _draw_folded_science_profile(plot: RadioPlot, rect: Rect2) -> void:
	var reveal := clampf((report_analysis_progress - 0.68) / 0.24, 0.0, 1.0)
	if reveal <= 0.0:
		return
	var values: Array = report_product.get("folded_two_cycles", [])
	if values.is_empty():
		return
	var visible_values := maxi(2, int(float(values.size()) * reveal))
	var points := PackedVector2Array()
	for i in range(mini(values.size(), visible_values)):
		var x := rect.position.x + 5.0 + (rect.size.x - 10.0) * float(i) / float(values.size() - 1)
		var y := rect.end.y - 5.0 - clampf(float(values[i]), 0.0, 1.2) * (rect.size.y - 12.0)
		points.append(Vector2(x, y))
	if points.size() >= 2:
		plot.draw_polyline(points, Color(GREEN, 0.16), 6.0, true)
		plot.draw_polyline(points, GREEN, 1.6, true)
	plot.draw_line(Vector2(rect.get_center().x, rect.position.y + 2), Vector2(rect.get_center().x, rect.end.y - 2), Color(BRASS, 0.35), 1.0)
	_draw_plot_text(
		plot,
		GameManager.text(
			"W %.2f ms · duty %.1f%% · confidence %.0f%%" % [
				float(report_product.get("pulse_width_ms", 0.0)),
				float(report_product.get("duty_cycle_percent", 0.0)),
				float(report_product.get("confidence", 0.0)) * 100.0,
			],
			"脉宽 %.2f ms · 占空比 %.1f%% · 置信度 %.0f%%" % [
				float(report_product.get("pulse_width_ms", 0.0)),
				float(report_product.get("duty_cycle_percent", 0.0)),
				float(report_product.get("confidence", 0.0)) * 100.0,
			]
		),
		rect.position + Vector2(304, 12),
		8,
		CRT
	)


func _draw_hi_report_product(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var raw_rect := Rect2(Vector2(8, 22), Vector2(272, 104))
	var clean_rect := Rect2(Vector2(294, 22), Vector2(272, 104))
	var velocity_rect := Rect2(Vector2(8, 150), Vector2(558, 142))
	for rect in [raw_rect, clean_rect, velocity_rect]:
		_draw_crt_grid(plot, rect, 24.0, Color(0.18, 0.34, 0.38, 0.14))
		plot.draw_rect(rect, Color(BRASS, 0.48), false, 1.0)
	_draw_plot_text(plot, GameManager.text("RAW BAND", "原始频带"), raw_rect.position + Vector2(4, -5), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("CLEAN 21 CM LINE", "净化后的 21 厘米谱线"), clean_rect.position + Vector2(4, -5), 9, CYAN)
	_draw_plot_text(plot, GameManager.text("GALACTIC GAS VELOCITY PROFILE", "银河气体速度轮廓"), velocity_rect.position + Vector2(4, -5), 9, GREEN)
	var raw_samples := model.spectrum_samples(96, false)
	var clean_samples := model.spectrum_samples(96, true)
	_draw_spectrum_trace_in_rect(plot, raw_rect, raw_samples, Color(CRT, 0.62))
	_draw_spectrum_trace_in_rect(plot, clean_rect, clean_samples, CYAN)
	var velocity_points := PackedVector2Array()
	for i in range(120):
		var normalized := float(i) / 119.0
		var left_component := exp(-pow((normalized - 0.40) / 0.10, 2.0))
		var right_component := 0.72 * exp(-pow((normalized - 0.63) / 0.13, 2.0))
		var value := clampf((left_component + right_component) * model.window_covers_source(), 0.0, 1.0)
		velocity_points.append(Vector2(
			velocity_rect.position.x + 7.0 + normalized * (velocity_rect.size.x - 14.0),
			velocity_rect.end.y - 8.0 - value * (velocity_rect.size.y - 18.0)))
	plot.draw_polyline(velocity_points, Color(GREEN, 0.18), 5.0, true)
	plot.draw_polyline(velocity_points, GREEN, 1.7, true)
	_draw_plot_text(plot, GameManager.text("DATA PRODUCT · SPECTRAL-LINE VELOCITY", "数据产品 · 谱线速度分布"), Vector2(12, 13), 9, GOLD)


func _draw_frb_report_product(plot: RadioPlot) -> void:
	plot.draw_rect(Rect2(Vector2.ZERO, plot.size), Color("061119"), true)
	var raw_rect := Rect2(Vector2(8, 22), Vector2(272, 104))
	var dedispersed_rect := Rect2(Vector2(294, 22), Vector2(272, 104))
	var waterfall_rect := Rect2(Vector2(8, 150), Vector2(558, 142))
	for rect in [raw_rect, dedispersed_rect, waterfall_rect]:
		_draw_crt_grid(plot, rect, 24.0, Color(0.18, 0.34, 0.38, 0.14))
		plot.draw_rect(rect, Color(BRASS, 0.48), false, 1.0)
	_draw_plot_text(plot, GameManager.text("RAW TRANSIENT", "原始暂现信号"), raw_rect.position + Vector2(4, -5), 9, MUTED)
	_draw_plot_text(plot, GameManager.text("DM-CORRECTED BURST", "色散校正后的爆发"), dedispersed_rect.position + Vector2(4, -5), 9, CYAN)
	_draw_plot_text(plot, GameManager.text("DISPERSION SWEEP · REPEAT CONFIRMED", "色散扫频 · 重复已确认"), waterfall_rect.position + Vector2(4, -5), 9, GREEN)
	var raw := PackedVector2Array()
	var corrected := PackedVector2Array()
	for i in range(72):
		var normalized := float(i) / 71.0
		var noise := (sin(float(i) * 2.17) + sin(float(i) * 0.61)) * 0.08
		var broad := exp(-pow((normalized - 0.56) / 0.16, 2.0)) * 0.42
		var narrow := exp(-pow((normalized - 0.54) / 0.045, 2.0)) * model.dm_match()
		raw.append(Vector2(raw_rect.position.x + 5.0 + normalized * (raw_rect.size.x - 10.0),
			raw_rect.end.y - 8.0 - clampf(0.18 + noise + broad, 0.0, 1.0) * (raw_rect.size.y - 16.0)))
		corrected.append(Vector2(dedispersed_rect.position.x + 5.0 + normalized * (dedispersed_rect.size.x - 10.0),
			dedispersed_rect.end.y - 8.0 - clampf(0.12 + noise * 0.28 + narrow, 0.0, 1.0) * (dedispersed_rect.size.y - 16.0)))
	plot.draw_polyline(raw, Color(CRT, 0.62), 1.1, true)
	plot.draw_polyline(corrected, CYAN, 1.6, true)
	for row in range(16):
		var y := waterfall_rect.position.y + 6.0 + float(row) * (waterfall_rect.size.y - 12.0) / 15.0
		var sweep_x := waterfall_rect.position.x + 32.0 + float(row) * 17.0 * (1.0 - model.dm_match())
		var confirmed_x := waterfall_rect.position.x + waterfall_rect.size.x * 0.62
		var x := lerpf(sweep_x, confirmed_x, model.dm_match())
		plot.draw_line(Vector2(x - 6.0, y), Vector2(x + 6.0, y), Color(GREEN, 0.28 + 0.04 * row), 2.0)
	_draw_plot_text(plot, GameManager.text("DATA PRODUCT · TIME-FREQUENCY WATERFALL", "数据产品 · 时频瀑布图"), Vector2(12, 13), 9, GOLD)


func _draw_timing_evidence_thumbnail(plot: RadioPlot, rect: Rect2, evidence_stage: int) -> void:
	if evidence_stage == 0:
		var raw := PackedVector2Array()
		for i in range(48):
			var x := rect.position.x + 5.0 + (rect.size.x - 10.0) * float(i) / 47.0
			var noise := sin(float(i) * 2.61) * 0.25 + sin(float(i) * 0.73) * 0.12
			var y := rect.get_center().y - noise * 48.0
			raw.append(Vector2(x, y))
		plot.draw_polyline(raw, Color(CRT, 0.58), 1.0, true)
		return
	if evidence_stage == 1:
		var small_profile := model.folded_profile(64)
		var folded := PackedVector2Array()
		for i in range(small_profile.size()):
			var x := rect.position.x + 5.0 + (rect.size.x - 10.0) * float(i) / float(small_profile.size() - 1)
			var y := rect.end.y - 7.0 - clampf(float(small_profile[i]), 0.0, 1.2) * (rect.size.y - 16.0)
			folded.append(Vector2(x, y))
		plot.draw_polyline(folded, CYAN, 1.3, true)
		return
	var gate_x := rect.get_center().x
	plot.draw_rect(Rect2(Vector2(gate_x - 8.0, rect.position.y + 6.0), Vector2(16.0, rect.size.y - 12.0)), Color(GREEN, 0.12), true)
	plot.draw_line(Vector2(gate_x, rect.end.y - 6.0), Vector2(gate_x, rect.position.y + 8.0), GREEN, 3.0)
	plot.draw_circle(Vector2(gate_x, rect.position.y + 14.0), 3.5, Color("d7fff3"))


func _draw_spectrum_trace_in_rect(plot: RadioPlot, rect: Rect2, samples: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(samples.size()):
		var x := rect.position.x + 4.0 + (rect.size.x - 8.0) * float(i) / float(maxi(1, samples.size() - 1))
		var y := rect.end.y - 5.0 - clampf(float(samples[i]) / 1.4, 0.0, 1.0) * (rect.size.y - 10.0)
		points.append(Vector2(x, y))
	plot.draw_polyline(points, Color(color, 0.18), 4.0, true)
	plot.draw_polyline(points, color, 1.2, true)


func _select_report_choice(choice: String) -> void:
	if report_analysis_running:
		return
	if report_choice == choice:
		return
	report_choice = choice
	_note_player_activity()
	_tutorial_action("report_choose")
	_refresh_report_choice()
	InteractionFeedback.feedback_sfx_requested.emit("ui_select")


func _refresh_report_choice() -> void:
	for key in report_choice_buttons:
		var button := report_choice_buttons[key] as Button
		_apply_report_choice_style(button, str(key) == report_choice)
	if submit_button != null and is_instance_valid(submit_button):
		submit_button.disabled = report_analysis_running or report_choice == ""
	if report_next_target_button != null and is_instance_valid(report_next_target_button):
		report_next_target_button.disabled = report_analysis_running or report_choice == ""


func _apply_report_choice_style(button: Button, selected: bool) -> void:
	if button == null or not is_instance_valid(button):
		return
	var title := str(button.get_meta("choice_title", ""))
	var evidence := str(button.get_meta("choice_evidence", ""))
	var marker := "✓" if selected else "○"
	button.text = "%s  %s\n    %s" % [marker, title, evidence]
	var normal_fill := Color("142a2a") if selected else Color("0b1117")
	var normal_border := Color("63d9bd") if selected else Color("46515c")
	var hover_fill := Color("16232a") if not selected else Color("183634")
	var hover_border := Color("a8c5cc") if not selected else Color("8af1d5")
	button.add_theme_stylebox_override("normal", _flat(normal_fill, normal_border, 2 if selected else 1))
	button.add_theme_stylebox_override("hover", _flat(hover_fill, hover_border, 2))
	button.add_theme_stylebox_override("focus", _flat(hover_fill, hover_border, 2))
	button.add_theme_stylebox_override("pressed", _flat(Color("1a3b35"), GREEN, 2))
	button.add_theme_color_override("font_color", Color("d7fff3") if selected else Color("c4cbd0"))
	button.add_theme_color_override("font_hover_color", Color("f1ffff"))
	button.add_theme_color_override("font_focus_color", Color("f1ffff"))
	if selected and not InteractionFeedback.is_reduced_motion():
		button.modulate = Color(0.76, 1.0, 0.91, 1.0)
		var tween := button.create_tween()
		tween.tween_property(button, "modulate", Color.WHITE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		button.modulate = Color.WHITE if not button.disabled else Color(1.0, 1.0, 1.0, 0.42)


func _submit() -> void:
	if running:
		return
	# UI controls stay disabled until the analysis reveal completes. Direct
	# automation and restored saves may invoke submission without replaying the
	# presentation, so finish the reveal deterministically before validation.
	if report_analysis_running:
		_finish_report_analysis()
	if report_choice == "":
		status_label.text = GameManager.text("Select the conclusion supported by the measured evidence.", "请选择实测证据支持的结论。")
		status_label.add_theme_color_override("font_color", AMBER)
		InteractionFeedback.error(submit_button)
		return
	var rep := model.report()
	if not model.evaluate_conclusion(report_choice):
		status_label.text = _report_contradiction(report_choice, rep)
		status_label.add_theme_color_override("font_color", RED)
		_terminal_event("SCIENCE REPORT", "CONTRADICTION", report_choice.to_upper(), "", 0.0, true)
		InteractionFeedback.error(report_choice_buttons.get(report_choice, submit_button) as Control)
		return
	_tutorial_action("report_submit")
	if tutorial_active:
		_finish_stage_tutorial()
	running = true
	_terminal_event("EVIDENCE MATRIX", "CONSISTENT", "PERIOD · DM · SNR")
	_terminal_event("FAST OBSERVATION CARD", "ARCHIVED", str(model.target_id).to_upper(), "", 0.0, true)
	_maya_reaction(
		"Not pretty, but hard to fake. It is rotating, and we now know when its next pulse reaches us.",
		"它不漂亮，却很难伪造。它正在旋转，而我们已经知道下一次脉冲何时抵达。"
	)
	InteractionFeedback.success(submit_button, "fast_report_confirmed")
	var observation := {
		"success": bool(rep.get("success", false)),
		"quality": _quality(float(rep["snr"])),
		"clarity": clampf(float(rep["snr"]) * 3.0, 0.0, 100.0),
		"contrast": clampf(float(rep["rfi_score"]) * 100.0, 0.0, 100.0),
		"detail": clampf(float(rep["timing_stability"]) * 100.0, 0.0, 100.0),
		"snr": float(rep["snr"]),
		"observation_mode": "radio",
		"pulse_period_ms": float(rep["trial_period_ms"]),
		"dispersion_measure": float(rep["trial_dm"]),
		"rfi_cleared": int(rep["rfi_cleared"]),
		"prediction_confirmed": prediction_confirmed,
		"report_conclusion": report_choice,
		"radio_target_kind": str(model.target_kind),
		"integration_s": float(rep.get("integration_s", 0.0)),
		"pulse_width_ms": float(rep.get("pulse_width_ms", 0.0)),
		"duty_cycle_percent": float(rep.get("duty_cycle_percent", 0.0)),
		"confidence": float(rep.get("confidence", report_product.get("confidence", 0.0))),
		"pointing_quality": float(report_product.get("pointing_quality", 0.0)),
		"tuning_quality": float(report_product.get("tuning_quality", 0.0)),
		"raw_rfi_count": int(report_product.get("raw_rfi_count", 0)),
		"radio_data_product": model.science_product(48, 12),
		"feedback_en": "Clock confirmed: the recovered period predicted and captured the next radio pulse. " + str(rep.get("result_en", "A repeating radio pulse confirmed the source.")),
		"feedback_zh": "宇宙时钟已确认：恢复出的周期准确预报并捕获了下一次射电脉冲。" + str(rep.get("result_zh", "重复射电脉冲确认了目标。")),
	}
	if GameManager.is_remote_free_observation("radio"):
		var current_entry_id := str(GameManager.active_remote_free_entry("radio").get("id", ""))
		observation["integration_s"] = float(rep.get("integration_s", 0.0))
		var archived := GameManager.record_remote_free_observation("radio", observation)
		_terminal_event("FREE OBSERVATION", "ARCHIVED" if bool(archived.get("recorded", false)) else "HOLD", str(model.target_id).to_upper(), "", 0.0, true)
		await get_tree().create_timer(0.34 if not InteractionFeedback.is_reduced_motion() else 0.08).timeout
		if report_choose_next_requested:
			_begin_next_radio_target_acquisition(current_entry_id)
			return
		GameManager.remote_observation_context.clear()
		GameManager.set_observatory_spawn("computer")
		GameManager.go("observatory")
		return
	await get_tree().create_timer(0.34 if not InteractionFeedback.is_reduced_motion() else 0.08).timeout
	GameManager.complete_current_mission(GameManager.current_target_object_id(), observation)


func _begin_next_radio_target_acquisition(current_entry_id: String) -> void:
	report_choose_next_requested = false
	running = false
	report_choice = ""
	report_product.clear()
	stage = 0
	_reset_fold_capture_validation(true)
	prediction_running = false
	prediction_confirmed = false
	acquisition_entries = _radio_acquisition_entries()
	if acquisition_entries.is_empty():
		GameManager.remote_observation_context.clear()
		GameManager.set_observatory_spawn("computer")
		GameManager.go("observatory")
		return
	var next_index := 0
	for index in range(acquisition_entries.size()):
		if str(acquisition_entries[index].get("id", "")) == current_entry_id:
			next_index = (index + 1) % acquisition_entries.size()
			break
	var next_entry: Dictionary = acquisition_entries[next_index]
	acquisition_required = true
	acquisition_active = true
	acquisition_completed = false
	acquisition_transition_pending = false
	acquisition_state = "search"
	acquisition_candidate_id = str(next_entry.get("id", ""))
	acquisition_azimuth = wrapf(float(next_entry.get("azimuth", model.true_azimuth)) + 18.0, 0.0, 360.0)
	acquisition_altitude = clampf(float(next_entry.get("altitude", model.true_altitude)) + 9.0, 50.0, 88.0)
	acquisition_velocity = Vector2.ZERO
	acquisition_drive_vector = Vector2.ZERO
	acquisition_braking = false
	acquisition_boundary_warning = ""
	_terminal_event(
		"OBSERVATION ARCHIVE",
		"SEALED",
		current_entry_id.to_upper(),
		"",
		0.0,
		true
	)
	_terminal_event(
		"RADIO SKY",
		"SEARCH",
		str(next_entry.get("target_id", next_entry.get("id", ""))).to_upper(),
		"",
		0.0,
		true
	)
	_rebuild()


func _report_contradiction(choice: String, rep: Dictionary) -> String:
	var residual := int(rep.get("rfi_residual", 0))
	var snr := float(rep.get("snr", 0.0))
	match choice:
		"stable_pulsar":
			if residual > 0:
				return GameManager.text(
					"The report says 'stable pulsar', but %d patterned interference peak(s) remain." % residual,
					"报告写的是“稳定脉冲星”，但频谱仍残留 %d 个规律性干扰峰。" % residual
				)
			return GameManager.text(
				"The report says 'stable pulsar', but period, DM, or SNR has not reached its measured threshold.",
				"报告写的是“稳定脉冲星”，但周期、DM 或信噪比尚未达到实测门槛。"
			)
		"residual_rfi":
			return GameManager.text(
				"The cleaned spectrum has no residual patterned peak, while period and DM agree.",
				"净化频谱已经没有规律性残余峰，而且周期与 DM 相互吻合。"
			)
		_:
			return GameManager.text(
				"The report calls the signal insufficient, but SNR %.1f exceeds %.1f and the folded pulse is coherent." % [snr, model.report_snr_threshold],
				"报告认为信号不足，但信噪比 %.1f 已超过 %.1f，折叠脉冲也已相干。" % [snr, model.report_snr_threshold]
			)


func _quality(snr: float) -> String:
	if snr >= 20.0:
		return "Excellent"
	if snr >= 13.0:
		return "Good"
	if snr >= model.report_snr_threshold:
		return "Fair"
	return "Poor"


func _wrap_words(value: String, line_length: int) -> String:
	var lines: Array[String] = []
	var current := ""
	for word in value.split(" ", false):
		var candidate := word if current == "" else current + " " + word
		if current != "" and candidate.length() > line_length:
			lines.append(current)
			current = word
		else:
			current = candidate
	if current != "":
		lines.append(current)
	return "\n".join(lines)


func _wrap_characters(value: String, line_length: int) -> String:
	var lines: Array[String] = []
	var offset := 0
	while offset < value.length():
		lines.append(value.substr(offset, line_length))
		offset += line_length
	return "\n".join(lines)


# ---------------------------------------------------------------- shared drawing / controls
func _radio_operation_chain(action_text: String, effect_text: String, reveal_text: String) -> void:
	var existing := get_node_or_null("OperationChainFeedback")
	if existing != null:
		remove_child(existing)
		existing.queue_free()
	var chain := Panel.new()
	chain.name = "OperationChainFeedback"
	# The operation chain temporarily occupies the terminal bay instead of
	# competing with the status line and footer buttons for the last 44 px.
	chain.position = terminal_panel.position if terminal_panel != null else Vector2(40, 614)
	chain.size = terminal_panel.size if terminal_panel != null else Vector2(750, 66)
	chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chain.z_index = 840
	chain.clip_contents = true
	chain.add_theme_stylebox_override("panel", _flat(Color("061018"), CYAN, 2))
	add_child(chain)
	var headings := [
		GameManager.text("ACTION RESULT", "操作结果"),
		GameManager.text("SYSTEM STATUS", "系统状态"),
		GameManager.text("UNLOCKED", "已解锁"),
	]
	var values := [action_text, effect_text, reveal_text]
	var column_width := 232.0
	for i in range(3):
		var column_x := 10.0 + float(i) * 246.0
		var heading := _label_to(
			chain, str(headings[i]), Vector2(column_x, 3), Vector2(column_width, 16),
			9, CYAN
		)
		heading.clip_text = true
		var value := _label_to(
			chain, str(values[i]), Vector2(column_x, 19), Vector2(column_width, 42),
			9, TEXT
		)
		value.name = "OperationChainValue%d" % i
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		value.clip_text = true
		if i < 2:
			var separator := _label_to(
				chain, ">", Vector2(column_x + column_width + 3.0, 23),
				Vector2(8, 18), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER
			)
			separator.clip_text = true
	if not InteractionFeedback.is_reduced_motion():
		chain.modulate.a = 0.0
		var enter := create_tween().bind_node(chain)
		enter.tween_property(chain, "modulate:a", 1.0, 0.14)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(chain):
			return
		if InteractionFeedback.is_reduced_motion():
			chain.queue_free()
			return
		var exit := create_tween().bind_node(chain)
		exit.tween_property(chain, "modulate:a", 0.0, 0.16)
		exit.tween_callback(chain.queue_free)
	)
	chain.add_child(timer)
	timer.start()


func _maya_reaction(text_en: String, text_zh: String) -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	status_label.text = GameManager.text("Maya: " + text_en, "玛雅：" + text_zh)
	status_label.add_theme_color_override("font_color", CYAN)


func _capture_waterfall_row(history: Array, apply_classification: bool) -> void:
	if model == null:
		return
	var source: Array = model.spectrum_samples(96, apply_classification)
	var row := PackedFloat32Array()
	for i in range(source.size()):
		var receiver_noise := sin(float(i) * 1.71 + waterfall_phase * 0.67) * 0.018
		row.append(clampf(float(source[i]) / 1.4 + receiver_noise, 0.0, 1.0))
	history.append(row)
	while history.size() > WATERFALL_ROWS:
		history.pop_front()


func _draw_waterfall(plot: Control, rect: Rect2, history: Array, cleaned: bool) -> void:
	if history.is_empty():
		return
	var row_height := rect.size.y / float(WATERFALL_ROWS)
	for row_index in range(history.size()):
		var row: PackedFloat32Array = history[row_index]
		if row.is_empty():
			continue
		var y := rect.end.y - float(history.size() - row_index) * row_height
		var cell_width := rect.size.x / float(row.size())
		for i in range(row.size()):
			var strength := clampf(float(row[i]), 0.0, 1.0)
			var color := Color(
				lerpf(0.03, 0.40 if cleaned else 0.56, strength),
				lerpf(0.08, 0.78 if cleaned else 0.58, strength),
				lerpf(0.10, 0.72 if cleaned else 0.30, strength),
				0.18 + strength * 0.70
			)
			plot.draw_rect(
				Rect2(Vector2(rect.position.x + float(i) * cell_width, y), Vector2(maxf(1.0, cell_width + 0.2), row_height + 0.2)),
				color,
				true
			)


func _draw_crt_grid(plot: Control, rect: Rect2, spacing: float, color: Color) -> void:
	plot.draw_rect(rect, Color("061019"), true)
	var x := rect.position.x
	while x <= rect.end.x:
		plot.draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), color, 1.0)
		x += spacing
	var y := rect.position.y
	while y <= rect.end.y:
		plot.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color, 1.0)
		y += spacing
	var scan_y := rect.position.y + 3.0
	while scan_y <= rect.end.y:
		plot.draw_line(Vector2(rect.position.x, scan_y), Vector2(rect.end.x, scan_y), Color(0.0, 0.0, 0.0, 0.10), 1.0)
		scan_y += 5.0


func _draw_arrow(plot: Control, from: Vector2, to: Vector2, color: Color) -> void:
	plot.draw_line(from, to, color, 2.0)
	var direction := (to - from).normalized()
	var side := Vector2(-direction.y, direction.x)
	plot.draw_colored_polygon(PackedVector2Array([to, to - direction * 10.0 + side * 5.0, to - direction * 10.0 - side * 5.0]), color)


func _draw_plot_text(plot: Control, value: String, pos: Vector2, font_size: int, color: Color) -> void:
	plot.draw_string(ThemeDB.fallback_font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _meter(parent: Control, label_text: String, pos: Vector2, size_value: Vector2, value: float, color: Color) -> void:
	_label_to(parent, label_text, pos - Vector2(0, 16), Vector2(size_value.x, 16), 10, MUTED)
	var holder := Panel.new()
	holder.position = pos
	holder.size = size_value
	holder.add_theme_stylebox_override("panel", _flat(Color("07111b"), Color("26384b"), 1))
	parent.add_child(holder)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = Vector2((size_value.x - 4.0) * clampf(value, 0.0, 1.0), maxf(1.0, size_value.y - 4.0))
	fill.color = color
	holder.add_child(fill)


func _meter_draw(plot: Control, rect: Rect2, value: float, color: Color) -> void:
	plot.draw_rect(rect, Color("142333"), true)
	plot.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0.0, 1.0), rect.size.y)), color, true)
	plot.draw_rect(rect, Color("34495e"), false, 1.0)


func _stepper(parent: Control, label_text: String, pos: Vector2, width: float, minus_action: Callable, plus_action: Callable, node_prefix := "") -> void:
	var caption := _label_to(parent, label_text, pos - Vector2(0, 20), Vector2(width, 18), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if node_prefix != "":
		caption.name = node_prefix + "Label"
	var minus := _button("−", pos, Vector2(width * 0.5 - 2.0, 30), Color("153249"))
	if node_prefix != "":
		minus.name = node_prefix + "Minus"
	minus.pressed.connect(minus_action)
	parent.add_child(minus)
	var plus := _button("+", pos + Vector2(width * 0.5 + 2.0, 0), Vector2(width * 0.5 - 2.0, 30), Color("153249"))
	if node_prefix != "":
		plus.name = node_prefix + "Plus"
	plus.pressed.connect(plus_action)
	parent.add_child(plus)


func _panel(pos: Vector2, size_value: Vector2, fill: Color, border: Color) -> Panel:
	return _panel_to(self, pos, size_value, fill, border, "")


func _panel_to(parent: Control, pos: Vector2, size_value: Vector2, fill: Color, border: Color, title: String) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size_value
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _flat(fill, border, 2))
	parent.add_child(panel)
	if title != "":
		_label_to(panel, title, Vector2(0, 8), Vector2(size_value.x, 26), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	return panel


func _flat(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style


func _label(value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _label_to(self, value, pos, size_value, font_size, color, alignment)


func _label_to(parent: Control, value: String, pos: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = size_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(value: String, pos: Vector2, size_value: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = size_value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _flat(color, GOLD, 2))
	button.add_theme_stylebox_override("hover", _flat(color.lightened(0.10), CYAN, 2))
	button.add_theme_stylebox_override("pressed", _flat(color.darkened(0.12), GREEN, 2))
	button.add_theme_stylebox_override("disabled", _flat(color.darkened(0.35), Color("344255"), 1))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_disabled_color", Color(MUTED, 0.55))
	return button
