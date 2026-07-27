extends Control
class_name SpaceWavefrontDisplay

signal segment_selected(index: int)

var alignment := 0.25
var wavefront_error_nm := 900.0
var phase_errors: Array[float] = []
var visual_phase_errors: Array[float] = []
var coarse_complete := false
var selected_group := -1
var selected_segment := -1
var actuation_mode := ""
var actuation_index := -1
var actuation_progress := 0.0
var convergence_progress := 0.0
var sensor_response_active := false
var segment_centers: Array[Vector2] = []
var _motion_tween: Tween
var _sensor_tween: Tween
var _convergence_tween: Tween

const HOT := Color(0.96, 0.96, 0.96)
const CYAN := Color(0.56, 0.92, 1.0)
const AMBER := Color(0.95, 0.66, 0.25)
const MID := Color(0.58, 0.58, 0.58)
const DIM := Color(0.25, 0.25, 0.25)
const BG := Color(0.015, 0.022, 0.03)
const RESIDUAL_THRESHOLD := 0.12
const RESIDUAL_VISUAL_MIN_OFFSET := 7.0
const RESIDUAL_VISUAL_MAX_OFFSET := 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func sync_state(
	errors: Array,
	alignment_value: float,
	error_nm: float,
	is_coarse_complete: bool,
	segment_index: int
) -> void:
	phase_errors = _float_array(errors)
	alignment = clampf(alignment_value, 0.0, 1.0)
	wavefront_error_nm = error_nm
	coarse_complete = is_coarse_complete
	selected_segment = segment_index
	if visual_phase_errors.size() != phase_errors.size() or not sensor_response_active:
		visual_phase_errors = phase_errors.duplicate()
	queue_redraw()


func set_selected_group(group_index: int) -> void:
	selected_group = group_index
	queue_redraw()


func set_selected_segment(segment_index: int) -> void:
	selected_segment = segment_index
	queue_redraw()


func start_group_actuation(group_index: int) -> void:
	_start_mechanical_actuation("COARSE", group_index, 0.34)


func start_segment_actuation(segment_index: int) -> void:
	_start_mechanical_actuation("FINE", segment_index, 0.28)


func _start_mechanical_actuation(mode: String, index: int, duration: float) -> void:
	actuation_mode = mode
	actuation_index = index
	actuation_progress = 0.0
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	if InteractionFeedback.is_reduced_motion():
		actuation_progress = 1.0
		queue_redraw()
		return
	_motion_tween = create_tween().bind_node(self)
	_motion_tween.tween_method(func(value: float) -> void:
		actuation_progress = value
		queue_redraw(), 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func animate_sensor_response(
	target_errors: Array,
	target_alignment: float,
	target_wavefront_error: float,
	duration := 0.38
) -> void:
	var start_errors := visual_phase_errors.duplicate()
	var end_errors := _float_array(target_errors)
	if start_errors.size() != end_errors.size():
		start_errors = end_errors.duplicate()
	var start_alignment := alignment
	var start_wfe := wavefront_error_nm
	phase_errors = end_errors.duplicate()
	sensor_response_active = true
	if _sensor_tween != null and _sensor_tween.is_valid():
		_sensor_tween.kill()
	if InteractionFeedback.is_reduced_motion():
		visual_phase_errors = end_errors
		alignment = target_alignment
		wavefront_error_nm = target_wavefront_error
		sensor_response_active = false
		queue_redraw()
		return
	_sensor_tween = create_tween().bind_node(self)
	_sensor_tween.tween_method(func(value: float) -> void:
		for index in range(end_errors.size()):
			visual_phase_errors[index] = lerpf(float(start_errors[index]), float(end_errors[index]), value)
		alignment = lerpf(start_alignment, target_alignment, value)
		wavefront_error_nm = lerpf(start_wfe, target_wavefront_error, value)
		queue_redraw(), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sensor_tween.tween_callback(func() -> void:
		sensor_response_active = false
		actuation_mode = ""
		actuation_index = -1
		queue_redraw())


func begin_convergence() -> void:
	convergence_progress = 0.0
	if _convergence_tween != null and _convergence_tween.is_valid():
		_convergence_tween.kill()
	if InteractionFeedback.is_reduced_motion():
		convergence_progress = 1.0
		queue_redraw()
		return
	_convergence_tween = create_tween().bind_node(self)
	_convergence_tween.tween_method(func(value: float) -> void:
		convergence_progress = value
		queue_redraw(), 0.0, 1.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_select_nearest_segment(mouse_button.position)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_select_nearest_segment(touch.position)
			accept_event()


func _select_nearest_segment(point: Vector2) -> void:
	var best_index := -1
	var best_distance := 24.0
	for index in range(segment_centers.size()):
		var distance := point.distance_to(segment_centers[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	if best_index >= 0:
		segment_selected.emit(best_index)


func _draw() -> void:
	draw_string(
		ThemeDB.fallback_font, Vector2(42, 48),
		GameManager.text("18-SEGMENT PRIMARY", "18 片主镜"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MID)
	draw_string(
		ThemeDB.fallback_font, Vector2(350, 48),
		GameManager.text("PHASE RETRIEVAL / PSF", "相位恢复 / 点扩散函数"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MID)
	_draw_segments(Vector2(176, 218))
	_draw_psf(Vector2(430, 202))
	_draw_waveform(Rect2(328, 320, 224, 94))


func _draw_segments(center: Vector2) -> void:
	var coords := _mirror_coords()
	segment_centers.clear()
	var errors := visual_phase_errors
	if errors.size() != 18:
		errors.resize(18)
	for index in range(coords.size()):
		var axial := coords[index]
		var ideal := Vector2(sqrt(3.0) * (axial.x + axial.y * 0.5), 1.5 * axial.y) * 17.0
		var phase_error := float(errors[index])
		var error_direction := Vector2(cos(float(index) * 2.19), sin(float(index) * 2.19))
		var phase_offset := _segment_visual_offset(index, phase_error, error_direction)
		var mechanical_offset := Vector2.ZERO
		if _segment_is_actuating(index):
			var impulse := sin(actuation_progress * PI) * 2.8
			var rebound := sin(actuation_progress * TAU * 2.0) * (1.0 - actuation_progress) * 0.7
			mechanical_offset = error_direction * (impulse + rebound)
		var position := center + ideal + phase_offset + mechanical_offset
		segment_centers.append(position)
		var resolved := absf(phase_error) <= RESIDUAL_THRESHOLD or convergence_progress > 0.72
		var color := MID
		if convergence_progress > 0.0:
			color = MID.lerp(CYAN, convergence_progress)
		elif index == selected_segment:
			color = CYAN
		elif coarse_complete and not resolved:
			color = AMBER
		elif selected_group == index / 6:
			color = HOT
		elif resolved:
			color = HOT
		if coarse_complete and not resolved and convergence_progress < 0.98:
			# Phase is piston motion rather than literal sideways travel. The dim
			# ideal outline and short actuator vector make that schematic
			# displacement explicit without pretending the mirror slides freely.
			var ideal_position := center + ideal
			_draw_hex(ideal_position, 16.0, Color(DIM, 0.72), false, true)
			draw_line(ideal_position, position, Color(AMBER, 0.70), 1.5)
			draw_circle(ideal_position, 2.0, Color(DIM, 0.82), true)
			draw_circle(position, 2.3, Color(color, 0.95), true)
		_draw_hex(position, 16.0, color, resolved or convergence_progress >= 0.98, not resolved and convergence_progress < 0.98)

	var anomalies := _anomaly_indices()
	var status := GameManager.text(
		"DIAGNOSE BANKS" if not coarse_complete else "FINE RESIDUALS %d" % anomalies.size(),
		"诊断镜片组" if not coarse_complete else "精调残差 %d 片" % anomalies.size())
	if convergence_progress >= 0.98:
		status = GameManager.text("18/18 PHASED", "18/18 共相完成")
	draw_string(
		ThemeDB.fallback_font, center + Vector2(-86, 107), status,
		HORIZONTAL_ALIGNMENT_CENTER, 172, 12,
		CYAN if convergence_progress > 0.0 else (AMBER if coarse_complete else HOT))

	for group_index in range(3):
		var group_error := _visual_group_error(group_index)
		var label_color := HOT if group_index == selected_group else MID
		if coarse_complete:
			label_color = DIM
		draw_string(
			ThemeDB.fallback_font,
			Vector2(86 + group_index * 62, 372),
			"%s %.2fλ" % [String.chr(65 + group_index), group_error],
			HORIZONTAL_ALIGNMENT_CENTER, 58, 9, label_color)


func _draw_psf(center: Vector2) -> void:
	var ranked := _ranked_error_indices()
	var peak_count := mini(6, ranked.size())
	var central_energy := clampf(alignment + convergence_progress * 0.18, 0.0, 1.0)
	draw_circle(center, 4.0 + central_energy * 7.0, Color(HOT, 0.18 + central_energy * 0.56), true)
	for order in range(peak_count):
		var segment_index := int(ranked[order])
		var error := absf(float(visual_phase_errors[segment_index]))
		var angle := float(segment_index) * 2.19
		var spread := clampf(error * 78.0, 2.0, 74.0) * (1.0 - convergence_progress)
		var peak := center + Vector2(cos(angle), sin(angle)) * spread
		var peak_color := CYAN if segment_index == selected_segment else HOT
		var trail_start := peak.lerp(center, 0.62)
		draw_line(peak, trail_start, Color(peak_color, 0.12 + error * 0.24), 2.0)
		for trail_index in range(3):
			var trail_t := float(trail_index + 1) / 4.0
			var trail_pos := peak.lerp(center, trail_t * 0.52)
			draw_circle(trail_pos, maxf(1.5, 5.0 - trail_index), Color(peak_color, 0.10 + error * 0.12), true)
		draw_circle(peak, 4.0 + error * 5.0, Color(peak_color, 0.34 + error * 0.42), true)
	if central_energy > 0.86 or convergence_progress > 0.0:
		draw_arc(center, 14.0 + convergence_progress * 4.0, 0.0, TAU, 32, CYAN, 1.5)
		draw_line(center - Vector2(22, 0), center + Vector2(22, 0), Color(CYAN, 0.34), 1.0)
		draw_line(center - Vector2(0, 22), center + Vector2(0, 22), Color(CYAN, 0.34), 1.0)
	draw_string(
		ThemeDB.fallback_font, center + Vector2(-88, 108),
		GameManager.text(
			"PSF SHARPNESS %03d%%" % roundi(clampf(1.0 - wavefront_error_nm / 900.0, 0.0, 1.0) * 100.0),
			"PSF 锐度 %03d%%" % roundi(clampf(1.0 - wavefront_error_nm / 900.0, 0.0, 1.0) * 100.0)),
		HORIZONTAL_ALIGNMENT_CENTER, 176, 11, CYAN if convergence_progress > 0.0 else HOT)


func _draw_waveform(rect: Rect2) -> void:
	draw_rect(rect, BG, true)
	draw_rect(rect, DIM, false, 1.0)
	var rms := _visual_rms()
	var band_height := clampf(rms * rect.size.y * 0.42, 2.0, rect.size.y * 0.38) * (1.0 - convergence_progress)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	var center_y := rect.get_center().y
	for index in range(81):
		var t := float(index) / 80.0
		var x := rect.position.x + t * rect.size.x
		var texture := 0.72 + sin(t * TAU * 3.0) * 0.18 + sin(t * TAU * 7.0) * 0.08
		upper.append(Vector2(x, center_y - band_height * texture))
		lower.append(Vector2(x, center_y + band_height * texture))
	var band := PackedVector2Array()
	for point in upper:
		band.append(point)
	for index in range(lower.size() - 1, -1, -1):
		band.append(lower[index])
	var band_color := CYAN if convergence_progress > 0.0 or wavefront_error_nm <= 150.0 else AMBER
	if band_height > 0.5:
		draw_colored_polygon(band, Color(band_color, 0.10))
		draw_polyline(upper, Color(band_color, 0.55), 1.0)
		draw_polyline(lower, Color(band_color, 0.55), 1.0)
	draw_line(Vector2(rect.position.x, center_y), Vector2(rect.end.x, center_y), Color(CYAN, 0.72), 1.5)
	draw_string(
		ThemeDB.fallback_font, rect.position + Vector2(6, 14),
		"WFE %04d nm" % roundi(wavefront_error_nm),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, band_color)
	draw_string(
		ThemeDB.fallback_font, rect.position + Vector2(6, rect.size.y - 8),
		GameManager.text("ERROR BAND", "误差带"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MID)


func _segment_is_actuating(index: int) -> bool:
	if actuation_mode == "COARSE":
		return index / 6 == actuation_index
	if actuation_mode == "FINE":
		return index == actuation_index
	return false


func _anomaly_indices() -> Array[int]:
	var output: Array[int] = []
	for index in range(visual_phase_errors.size()):
		if absf(float(visual_phase_errors[index])) > RESIDUAL_THRESHOLD:
			output.append(index)
	return output


func _segment_visual_offset(index: int, phase_error: float, error_direction := Vector2.INF) -> Vector2:
	var direction := error_direction
	if not direction.is_finite():
		direction = Vector2(cos(float(index) * 2.19), sin(float(index) * 2.19))
	if direction.length_squared() < 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()

	var magnitude := absf(phase_error) * 8.0
	if coarse_complete and absf(phase_error) > RESIDUAL_THRESHOLD:
		# Four fine residuals must remain legible after coarse phasing. A small
		# nonlinear display gain preserves their rank while avoiding the old
		# "all mirrors suddenly aligned" visual lie.
		var residual_strength := inverse_lerp(RESIDUAL_THRESHOLD, 0.55, absf(phase_error))
		magnitude = lerpf(
			RESIDUAL_VISUAL_MIN_OFFSET,
			RESIDUAL_VISUAL_MAX_OFFSET,
			clampf(residual_strength, 0.0, 1.0))
	return direction * signf(phase_error) * magnitude * (1.0 - convergence_progress)


func _ranked_error_indices() -> Array[int]:
	var output: Array[int] = []
	for index in range(visual_phase_errors.size()):
		output.append(index)
	output.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(visual_phase_errors[a])) > absf(float(visual_phase_errors[b])))
	return output


func _visual_group_error(group_index: int) -> float:
	if visual_phase_errors.size() != 18:
		return 0.0
	var total := 0.0
	for index in range(group_index * 6, group_index * 6 + 6):
		total += absf(float(visual_phase_errors[index]))
	return total / 6.0


func _visual_rms() -> float:
	if visual_phase_errors.is_empty():
		return 1.0 - alignment
	var total := 0.0
	for error in visual_phase_errors:
		total += error * error
	return sqrt(total / float(visual_phase_errors.size()))


func _mirror_coords() -> Array[Vector2i]:
	var output: Array[Vector2i] = []
	for q in range(-2, 3):
		for r in range(-2, 3):
			var s := -q - r
			if maxi(abs(q), maxi(abs(r), abs(s))) <= 2 and not (q == 0 and r == 0):
				output.append(Vector2i(q, r))
	return output


func _draw_hex(center: Vector2, radius: float, color: Color, filled: bool, dashed: bool) -> void:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := PI / 6.0 + float(index) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if filled:
		draw_colored_polygon(points, Color(color, 0.10))
	for index in range(6):
		var start := points[index]
		var finish := points[(index + 1) % 6]
		if dashed:
			draw_dashed_line(start, finish, color, 1.5, 4.0)
		else:
			draw_line(start, finish, color, 1.5)


func _float_array(values: Array) -> Array[float]:
	var output: Array[float] = []
	for value in values:
		output.append(float(value))
	return output
