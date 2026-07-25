extends Control
class_name SpaceGuideAttitudeDisplay

signal slew_finished(index: int)

var candidate_index := -1
var candidate_direction := Vector2.ZERO
var candidate_usable := false
var active := false
var settled := false
var locked := false
var slew_progress := 0.0
var pointing_error := 8.0
var drift_rate := 0.9

var yaw_deg := -14.0
var pitch_deg := 8.0
var roll_deg := -6.0
var _start_yaw := 0.0
var _start_pitch := 0.0
var _start_roll := 0.0
var _target_yaw := 0.0
var _target_pitch := 0.0
var _target_roll := 0.0
var _slew_duration := 1.55
var _slew_elapsed := 0.0
var _pulse := 0.0
var _previous_error := 8.0
var control_pulse_count := 0
var control_pulse_age := 9.0
var lock_ceremony := false

const BG := Color("050a12")
const GRID := Color("183047")
const CYAN := Color("57d8ff")
const GOLD := Color("e6b957")
const WHITE := Color("dce9ef")
const MUTED := Color("6f8591")
const GREEN := Color("66e59a")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func set_candidate(index: int, direction: Vector2, usable: bool) -> void:
	if active:
		return
	candidate_index = index
	candidate_direction = direction
	candidate_usable = usable
	settled = false
	queue_redraw()


func begin_slew(index: int, direction: Vector2, duration: float = 1.55) -> void:
	candidate_index = index
	candidate_direction = direction
	candidate_usable = true
	active = true
	settled = false
	locked = false
	slew_progress = 0.0
	_slew_elapsed = 0.0
	_slew_duration = maxf(0.4, duration)
	control_pulse_count = 0
	control_pulse_age = 9.0
	lock_ceremony = false
	_previous_error = 8.0
	_start_yaw = yaw_deg
	_start_pitch = pitch_deg
	_start_roll = roll_deg
	_target_yaw = clampf(direction.x * 38.0, -38.0, 38.0)
	_target_pitch = clampf(-direction.y * 25.0, -25.0, 25.0)
	_target_roll = clampf(direction.x * 9.0 - direction.y * 4.0, -12.0, 12.0)
	queue_redraw()


func update_guidance(error: float, drift: float, is_locked: bool) -> void:
	for threshold in [5.0, 3.8, 2.7, 1.7, 1.2]:
		if _previous_error > threshold and error <= threshold:
			control_pulse_count = mini(control_pulse_count + 1, 5)
			control_pulse_age = 0.0
			break
	pointing_error = error
	drift_rate = drift
	locked = is_locked
	_previous_error = error
	queue_redraw()


func begin_lock_ceremony() -> void:
	lock_ceremony = true
	locked = true
	control_pulse_age = 0.0
	queue_redraw()


func skip_slew() -> void:
	if not active:
		return
	_slew_elapsed = _slew_duration
	slew_progress = 1.0


func coarse_error_arcsec() -> float:
	if not active:
		return pointing_error
	return lerpf(7.0, 1.2, _smoothstep(slew_progress))


func _process(delta: float) -> void:
	_pulse += delta
	control_pulse_age += delta
	if active:
		_slew_elapsed += delta
		slew_progress = clampf(_slew_elapsed / _slew_duration, 0.0, 1.0)
		var eased := _smoothstep(slew_progress)
		yaw_deg = lerpf(_start_yaw, _target_yaw, eased)
		pitch_deg = lerpf(_start_pitch, _target_pitch, eased)
		var wheel_damping := (1.0 - eased) * sin(_slew_elapsed * 15.0) * 4.0
		roll_deg = lerpf(_start_roll, _target_roll, eased) + wheel_damping
		if slew_progress >= 1.0:
			active = false
			settled = true
			yaw_deg = _target_yaw
			pitch_deg = _target_pitch
			roll_deg = _target_roll
			slew_finished.emit(candidate_index)
		queue_redraw()
	elif settled and not locked:
		# Fine guidance does not rock the observatory. The bus holds its coarse
		# attitude while tiny control pulses collapse the residual error vector.
		roll_deg = _target_roll
		queue_redraw()
	elif locked:
		queue_redraw()


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), GRID, false, 1.0)
	for x in range(12, int(size.x), 24):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(GRID, 0.34), 1.0)
	for y in range(12, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(GRID, 0.34), 1.0)

	var center := Vector2(size.x * 0.5, size.y * 0.54)
	var target := center + Vector2(candidate_direction.x * 118.0, candidate_direction.y * 58.0)
	var current_angle := deg_to_rad(yaw_deg - 90.0)
	var target_angle := atan2(target.y - center.y, target.x - center.x)
	var attitude_color := GREEN if locked else (GOLD if settled else CYAN)

	_draw_target_marker(target, attitude_color)
	_draw_rotation_arc(center, current_angle, target_angle, attitude_color)
	_draw_spacecraft(center, attitude_color)
	_draw_error_vector(Vector2(size.x - 42.0, size.y * 0.56), attitude_color)

	var status := GameManager.text("SEARCH", "搜索")
	if active:
		status = GameManager.text("SLEWING %02d%%", "姿态转向 %02d%%") % int(slew_progress * 100.0)
	elif locked:
		status = GameManager.text("FINE GUIDANCE", "精细导星")
	elif settled:
		status = GameManager.text("ATTITUDE HOLD", "姿态保持")
	elif candidate_index >= 0:
		status = GameManager.text(
			"VECTOR READY" if candidate_usable else "UNUSABLE VECTOR",
			"矢量已就绪" if candidate_usable else "矢量不可用")
	draw_string(ThemeDB.fallback_font, Vector2(10, 15), status,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, attitude_color)
	_draw_status_chip(
		GameManager.text("FINE LOCK", "精导锁定") if locked else GameManager.text("ACQUIRE", "捕获"),
		GREEN if locked else CYAN)
	var yaw_remaining := _target_yaw - yaw_deg
	var pitch_remaining := _target_pitch - pitch_deg
	var turn_text := GameManager.text(
		"TURN %s %.1f  /  %s %.1f" % [
			"RIGHT" if yaw_remaining >= 0.0 else "LEFT", absf(yaw_remaining),
			"RAISE" if pitch_remaining >= 0.0 else "LOWER", absf(pitch_remaining)],
		"%s %.1f  /  %s %.1f" % [
			"向右转" if yaw_remaining >= 0.0 else "向左转", absf(yaw_remaining),
			"抬高" if pitch_remaining >= 0.0 else "降低", absf(pitch_remaining)])
	draw_string(ThemeDB.fallback_font, Vector2(10, 30), turn_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(attitude_color, 0.82))
	var residual := maxf(0.01, maxf(0.25, drift_rate) * clampf(pointing_error / 6.0, 0.04, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(10, 44),
		GameManager.text(
			"ERROR %.2f arcsec  RESIDUAL %.2f/s",
			"误差 %.2f 角秒  残余漂移 %.2f/秒") % [coarse_error_arcsec(), residual],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GREEN if locked else MUTED)
	draw_string(ThemeDB.fallback_font, Vector2(10, size.y - 8),
		GameManager.text(
			"YAW %+05.1f  PITCH %+05.1f  ROLL %+05.1f",
			"偏航 %+05.1f  俯仰 %+05.1f  滚转 %+05.1f") % [yaw_deg, pitch_deg, roll_deg],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MUTED)


func _draw_target_marker(position: Vector2, color: Color) -> void:
	var radius := 8.0 + sin(_pulse * 4.0) * 1.2
	draw_arc(position, radius, 0.0, TAU, 24, color, 1.5)
	draw_line(position - Vector2(13, 0), position - Vector2(5, 0), color, 1.0)
	draw_line(position + Vector2(5, 0), position + Vector2(13, 0), color, 1.0)
	draw_line(position - Vector2(0, 13), position - Vector2(0, 5), color, 1.0)
	draw_line(position + Vector2(0, 5), position + Vector2(0, 13), color, 1.0)


func _draw_rotation_arc(center: Vector2, from_angle: float, to_angle: float, color: Color) -> void:
	var shortest := wrapf(to_angle - from_angle, -PI, PI)
	draw_arc(center, 64.0, 0.0, TAU, 48, Color(GRID, 0.78), 1.0)
	for tick in range(8):
		var tick_angle := float(tick) * TAU / 8.0
		var tick_direction := Vector2(cos(tick_angle), sin(tick_angle))
		draw_line(center + tick_direction * 61.0, center + tick_direction * 67.0, Color(GRID, 0.9), 1.0)
	var points := PackedVector2Array()
	for step in range(19):
		var t := float(step) / 18.0
		var angle := from_angle + shortest * t
		points.append(center + Vector2(cos(angle), sin(angle)) * 64.0)
	draw_polyline(points, Color(color, 0.72), 2.0)
	var tip := points[points.size() - 1]
	var tangent := Vector2(-sin(to_angle), cos(to_angle)) * signf(shortest if absf(shortest) > 0.01 else 1.0)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip - tangent * 9.0 + tangent.rotated(PI * 0.5) * 4.0,
		tip - tangent * 9.0 - tangent.rotated(PI * 0.5) * 4.0
	]), color)


func _draw_spacecraft(center: Vector2, color: Color) -> void:
	var roll := deg_to_rad(roll_deg)
	var yaw_scale := maxf(0.42, absf(cos(deg_to_rad(yaw_deg))))
	var pitch_scale := maxf(0.64, absf(cos(deg_to_rad(pitch_deg))))
	var transform_point := func(local: Vector2) -> Vector2:
		var shaped := Vector2(local.x * yaw_scale, local.y * pitch_scale)
		return center + shaped.rotated(roll)

	for layer in range(4, -1, -1):
		var spread := 39.0 + float(layer) * 3.0
		var shield := PackedVector2Array([
			transform_point.call(Vector2(-spread, 12 + layer * 1.5)),
			transform_point.call(Vector2(0, 24 + layer * 1.8)),
			transform_point.call(Vector2(spread, 12 + layer * 1.5)),
			transform_point.call(Vector2(0, 5 + layer * 1.1))
		])
		draw_colored_polygon(shield, Color(0.10, 0.16, 0.24, 0.86))
		draw_polyline(shield + PackedVector2Array([shield[0]]), Color(color, 0.42), 1.0)

	var bus_center: Vector2 = transform_point.call(Vector2(0, 5))
	draw_rect(Rect2(bus_center - Vector2(10, 8), Vector2(20, 16)), Color("17283a"), true)
	draw_rect(Rect2(bus_center - Vector2(10, 8), Vector2(20, 16)), color, false, 1.0)

	var mirror_center: Vector2 = transform_point.call(Vector2(0, -21))
	for q in [
		Vector2.ZERO, Vector2(9, 0), Vector2(-9, 0),
		Vector2(4.5, 7.8), Vector2(-4.5, 7.8), Vector2(4.5, -7.8), Vector2(-4.5, -7.8)
	]:
		_draw_hex(mirror_center + q.rotated(roll) * yaw_scale, 5.3, roll, GOLD)

	var boresight := Vector2(cos(deg_to_rad(yaw_deg - 90.0)), sin(deg_to_rad(yaw_deg - 90.0)))
	draw_line(mirror_center, mirror_center + boresight * 48.0, Color(color, 0.88), 2.0)
	var wheel: Vector2 = transform_point.call(Vector2(-25, 2))
	draw_arc(wheel, 7.0, 0.0, TAU, 18, WHITE, 1.0)
	var wheel_angle := _pulse * (15.0 if active else 2.0)
	for spoke in range(3):
		var a := wheel_angle + float(spoke) * TAU / 3.0
		draw_line(wheel, wheel + Vector2(cos(a), sin(a)) * 6.0, WHITE, 1.0)
	if control_pulse_age < 0.42 and not active:
		var pulse_t := clampf(control_pulse_age / 0.42, 0.0, 1.0)
		draw_arc(wheel, lerpf(8.0, 17.0, pulse_t), 0.0, TAU, 24, Color(CYAN, 0.72 * (1.0 - pulse_t)), 1.5)


func _draw_error_vector(center: Vector2, color: Color) -> void:
	var radius := 27.0
	draw_circle(center, radius, Color(0.01, 0.035, 0.06, 0.92), true)
	draw_arc(center, radius, 0.0, TAU, 32, Color(GRID, 0.95), 1.0)
	draw_line(center - Vector2(radius - 4.0, 0), center + Vector2(radius - 4.0, 0), Color(GRID, 0.70), 1.0)
	draw_line(center - Vector2(0, radius - 4.0), center + Vector2(0, radius - 4.0), Color(GRID, 0.70), 1.0)
	var normalized_error := clampf(coarse_error_arcsec() / 7.0, 0.0, 1.0)
	var vector_angle := atan2(candidate_direction.y, candidate_direction.x) + sin(_pulse * 1.7) * normalized_error * 0.35
	var vector := Vector2(cos(vector_angle), sin(vector_angle)) * normalized_error * (radius - 5.0)
	draw_line(center, center + vector, Color(color, 0.85), 1.5)
	draw_circle(center + vector, 2.5 if not locked else 1.8, GREEN if locked else WHITE, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, -radius - 4.0),
		GameManager.text("ERROR VECTOR", "误差矢量"),
		HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 8, MUTED)
	if locked:
		draw_circle(center, 2.0, GREEN, true)
		draw_arc(center, 6.0 + sin(_pulse * 3.0), 0.0, TAU, 18, Color(GREEN, 0.55), 1.0)


func _draw_status_chip(text: String, color: Color) -> void:
	var rect := Rect2(Vector2(size.x - 91.0, 5.0), Vector2(81.0, 18.0))
	draw_rect(rect, Color(0.02, 0.07, 0.10, 0.94), true)
	draw_rect(rect, color, false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(4.0, 13.0), text,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0, 9, color)


func _draw_hex(center: Vector2, radius: float, rotation: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := rotation + PI / 6.0 + float(index) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(color, 0.46))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.0)
