extends Control
class_name SpaceWavefrontDisplay

var alignment := 0.25:
	set(value):
		alignment = clampf(value, 0.0, 1.0)
		queue_redraw()
var wavefront_error_nm := 900.0:
	set(value):
		wavefront_error_nm = value
		queue_redraw()
var actuation_mode := ""
var actuation_pulse := 0.0:
	set(value):
		actuation_pulse = value
		queue_redraw()

const HOT := Color(0.96, 0.96, 0.96)
const MID := Color(0.58, 0.58, 0.58)
const DIM := Color(0.25, 0.25, 0.25)


func _mirror_coords() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q in range(-2, 3):
		for r in range(-2, 3):
			var s := -q - r
			if maxi(abs(q), maxi(abs(r), abs(s))) <= 2 and not (q == 0 and r == 0):
				out.append(Vector2i(q, r))
	return out


func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(42, 48), "18-SEGMENT PRIMARY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MID)
	draw_string(ThemeDB.fallback_font, Vector2(350, 48), "PHASE RETRIEVAL / PSF", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MID)
	_draw_segments(Vector2(176, 230))
	_draw_psf(Vector2(430, 220))
	_draw_waveform(Rect2(330, 332, 200, 78))
	_draw_actuation_feedback()


func flash_actuation(mode: String) -> void:
	actuation_mode = mode
	actuation_pulse = 1.0
	if InteractionFeedback.is_reduced_motion():
		actuation_pulse = 0.0
		return
	var tween := create_tween().bind_node(self)
	tween.tween_property(self, "actuation_pulse", 0.0, 0.42 if mode == "COARSE" else 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _draw_actuation_feedback() -> void:
	if actuation_pulse <= 0.001:
		return
	if actuation_mode == "COARSE":
		# Coarse control moves a six-segment bank at once: a broad mechanical
		# impulse crosses the primary and visibly shifts the PSF cluster.
		var radius := lerpf(42.0, 112.0, 1.0 - actuation_pulse)
		draw_arc(Vector2(176, 230), radius, 0.0, TAU, 48, Color(HOT, actuation_pulse * 0.62), 3.0)
		for index in range(6):
			var angle := TAU * float(index) / 6.0
			var start := Vector2(176, 230) + Vector2(cos(angle), sin(angle)) * 30.0
			draw_line(start, start + Vector2(cos(angle), sin(angle)) * 38.0, Color(HOT, actuation_pulse * 0.76), 3.0)
	else:
		# Fine control works one segment / one wavefront peak at a time. The
		# tight brackets make it read differently from the coarse shock ring.
		var focus := Vector2(430, 220)
		var half := lerpf(30.0, 18.0, actuation_pulse)
		var color := Color(HOT, actuation_pulse * 0.84)
		draw_line(focus + Vector2(-half, -half), focus + Vector2(-half + 12, -half), color, 2.0)
		draw_line(focus + Vector2(-half, -half), focus + Vector2(-half, -half + 12), color, 2.0)
		draw_line(focus + Vector2(half, -half), focus + Vector2(half - 12, -half), color, 2.0)
		draw_line(focus + Vector2(half, -half), focus + Vector2(half, -half + 12), color, 2.0)
		draw_line(focus + Vector2(-half, half), focus + Vector2(-half + 12, half), color, 2.0)
		draw_line(focus + Vector2(-half, half), focus + Vector2(-half, half - 12), color, 2.0)
		draw_line(focus + Vector2(half, half), focus + Vector2(half - 12, half), color, 2.0)
		draw_line(focus + Vector2(half, half), focus + Vector2(half, half - 12), color, 2.0)


func _draw_segments(center: Vector2) -> void:
	var coords := _mirror_coords()
	var aligned_count := clampi(roundi(alignment * 18.0), 0, 18)
	for index in range(coords.size()):
		var axial := coords[index]
		var ideal := Vector2(sqrt(3.0) * (axial.x + axial.y * 0.5), 1.5 * axial.y) * 17.0
		var wobble_angle := float(index) * 2.19
		var error_offset := Vector2(cos(wobble_angle), sin(wobble_angle)) * (1.0 - alignment) * (6.0 + float(index % 4))
		var p := center + ideal + error_offset
		var color := HOT if index < aligned_count else DIM
		_draw_hex(p, 16.0, color, index < aligned_count)
	draw_string(ThemeDB.fallback_font, center + Vector2(-72, 112),
		"PHASED %02d/18" % aligned_count, HORIZONTAL_ALIGNMENT_CENTER, 144, 12, HOT)


func _draw_psf(center: Vector2) -> void:
	var sharp := clampf(1.0 - wavefront_error_nm / 900.0, 0.0, 1.0)
	var spread := lerpf(72.0, 0.0, sharp)
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var p := center + Vector2(cos(angle), sin(angle)) * spread
		var radius := lerpf(12.0, 4.0, sharp)
		draw_circle(p, radius + 7.0, Color(HOT, 0.08), true)
		draw_circle(p, radius, Color(HOT, 0.42 + sharp * 0.48), true)
	if sharp > 0.88:
		draw_circle(center, 12.0, HOT, false, 2.0)
		draw_line(center - Vector2(22, 0), center + Vector2(22, 0), Color(HOT, 0.45), 1.0)
		draw_line(center - Vector2(0, 22), center + Vector2(0, 22), Color(HOT, 0.45), 1.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-88, 112),
		"PSF SHARPNESS %03d%%" % roundi(sharp * 100.0), HORIZONTAL_ALIGNMENT_CENTER, 176, 12, HOT)


func _draw_waveform(rect: Rect2) -> void:
	draw_rect(rect, Color(0.02, 0.02, 0.02), true)
	draw_rect(rect, DIM, false, 1.0)
	var amplitude := (1.0 - alignment) * rect.size.y * 0.36
	var points := PackedVector2Array()
	for index in range(81):
		var t := float(index) / 80.0
		var x := rect.position.x + t * rect.size.x
		var y := rect.get_center().y + sin(t * TAU * 3.0) * amplitude * (1.0 - t * 0.25)
		points.append(Vector2(x, y))
	draw_polyline(points, HOT if alignment > 0.88 else MID, 2.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 14),
		"WFE %04d nm" % roundi(wavefront_error_nm), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MID)


func _draw_hex(center: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := PI / 6.0 + float(index) * TAU / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if filled:
		draw_colored_polygon(points, Color(color, 0.10))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.5)
