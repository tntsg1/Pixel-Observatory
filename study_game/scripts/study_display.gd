extends Control
class_name StudyDisplay

enum ViewKind { ACQUIRE, OPTICAL, INFRARED, RADIO }

var view_kind := ViewKind.ACQUIRE
var target_offset := Vector2(0.48, -0.32)
var view_mode := 0
var focus_value := 35.0
var tracking := false
var eyepiece_mm := 10
var infrared_channels := ["dust", "near", "mid"]
var dispersion_measure := 8.0
var elapsed := 0.0

var clear_texture: Texture2D
var blurry_texture: Texture2D
var dim_texture: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clear_texture = load("res://assets/orion_nebula_clear.png")
	blurry_texture = load("res://assets/orion_nebula_blurry.png")
	dim_texture = load("res://assets/orion_nebula_dim.png")
	set_process(true)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("020710"), true)
	_draw_grid()
	match view_kind:
		ViewKind.ACQUIRE:
			_draw_acquire()
		ViewKind.OPTICAL:
			_draw_optical()
		ViewKind.INFRARED:
			_draw_infrared()
		ViewKind.RADIO:
			_draw_radio()


func _draw_grid() -> void:
	for x in range(0, int(size.x), 48):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.18, 0.36, 0.49, 0.12), 1.0)
	for y in range(0, int(size.y), 48):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.18, 0.36, 0.49, 0.12), 1.0)


func _star_position(index: int) -> Vector2:
	var x := float((index * 83 + 17) % 997) / 997.0 * size.x
	var y := float((index * 47 + 31) % 991) / 991.0 * size.y
	return Vector2(x, y)


func _draw_stars(alpha := 1.0) -> void:
	for index in range(110):
		var radius := 1.7 if index % 13 == 0 else (1.1 if index % 5 == 0 else 0.65)
		var colour := Color("f2d79c") if index % 11 == 0 else Color("b8d9f2")
		colour.a = alpha * (0.34 + float((index * 19) % 60) / 100.0)
		draw_circle(_star_position(index), radius, colour)


func _draw_acquire() -> void:
	_draw_stars()
	var scale_factor: float = [0.55, 1.15, 2.15][view_mode]
	var target: Vector2 = size * 0.5 + Vector2(target_offset.x * size.x, target_offset.y * size.y) * scale_factor
	var pulse := 1.0 + sin(elapsed * 3.4) * 0.08
	draw_circle(target, 25.0 * pulse, Color(0.31, 0.77, 0.96, 0.08), true)
	draw_arc(target, 18.0 * pulse, 0, TAU, 64, Color("79e0ff"), 2.0)
	draw_line(target + Vector2(-28, 0), target + Vector2(-19, 0), Color("79e0ff"), 1.0)
	draw_line(target + Vector2(19, 0), target + Vector2(28, 0), Color("79e0ff"), 1.0)
	_draw_reticle(size * 0.5, 35.0, Color("e8c567"))
	var texture_size := Vector2(96, 96) * (0.8 + view_mode * 0.35)
	draw_texture_rect(clear_texture, Rect2(target - texture_size * 0.5, texture_size), false, Color(1, 1, 1, 0.26 + view_mode * 0.2))


func _draw_reticle(center: Vector2, radius: float, colour: Color) -> void:
	draw_arc(center, radius, 0, TAU, 96, colour, 1.5)
	draw_line(center + Vector2(-radius - 14, 0), center + Vector2(-radius + 7, 0), colour, 1.2)
	draw_line(center + Vector2(radius - 7, 0), center + Vector2(radius + 14, 0), colour, 1.2)
	draw_line(center + Vector2(0, -radius - 14), center + Vector2(0, -radius + 7), colour, 1.2)
	draw_line(center + Vector2(0, radius - 7), center + Vector2(0, radius + 14), colour, 1.2)


func _optical_quality() -> float:
	var focus_score := 1.0 - minf(absf(focus_value - 72.0) / 45.0, 1.0)
	var magnification_score := 1.0 if eyepiece_mm == 25 else 0.38
	var tracking_score := 1.0 if tracking else 0.58
	return clampf(focus_score * 0.56 + magnification_score * 0.26 + tracking_score * 0.18, 0.0, 1.0)


func _draw_optical() -> void:
	_draw_stars(0.52)
	var quality := _optical_quality()
	var drift := Vector2.ZERO if tracking else Vector2(sin(elapsed * 0.55) * 36.0, cos(elapsed * 0.39) * 18.0)
	var center := size * 0.5 + drift
	var texture := clear_texture if quality > 0.78 else (blurry_texture if quality > 0.38 else dim_texture)
	var image_size := Vector2(330, 350) * (1.0 if eyepiece_mm == 25 else 1.28)
	var tint := Color(1, 1, 1, 0.45 + quality * 0.55)
	draw_texture_rect(texture, Rect2(center - image_size * 0.5, image_size), false, tint)
	draw_arc(size * 0.5, minf(size.x, size.y) * 0.43, 0, TAU, 128, Color(0.36, 0.71, 0.86, 0.42), 2.0)
	_draw_reticle(size * 0.5, 27.0, Color(0.88, 0.76, 0.38, 0.7))


func _band_colour(name: String) -> Color:
	match name:
		"dust": return Color(1.0, 0.30, 0.16, 0.72)
		"mid": return Color(0.22, 0.91, 0.55, 0.62)
		_: return Color(0.20, 0.53, 1.0, 0.70)


func _draw_infrared() -> void:
	_draw_stars(0.26)
	var rect := Rect2(size * 0.5 - Vector2(210, 220), Vector2(420, 440))
	for index in range(3):
		var tint := _band_colour(infrared_channels[index])
		tint.a *= 0.52
		draw_texture_rect(clear_texture, rect.grow(-index * 5.0), false, tint)
	draw_arc(size * 0.5, 225, 0, TAU, 128, Color(0.44, 0.86, 0.95, 0.38), 2.0)


func _draw_radio() -> void:
	var rows := 9
	var error := dispersion_measure - 14.4
	for row in range(rows):
		var y := 50.0 + row * ((size.y - 100.0) / float(rows - 1))
		var shift := error * (float(row) - 4.0) * 1.8
		var points := PackedVector2Array()
		for step in range(180):
			var x := float(step) / 179.0 * (size.x - 60.0) + 30.0
			var pulse_x := size.x * 0.52 + shift
			var gaussian := exp(-pow((x - pulse_x) / 23.0, 2.0)) * 29.0
			var noise := sin(step * 0.73 + row * 1.7) * 2.2 + sin(step * 0.21) * 1.3
			points.append(Vector2(x, y - gaussian - noise))
		draw_polyline(points, Color(0.46, 0.88, 0.95, 0.38 + row * 0.035), 1.35, true)
	var guide_x := size.x * 0.52
	draw_line(Vector2(guide_x, 26), Vector2(guide_x, size.y - 26), Color(0.90, 0.74, 0.33, 0.7), 1.0)
	var coherence := clampf(1.0 - absf(error) / 12.0, 0.0, 1.0)
	draw_arc(Vector2(size.x - 64, 54), 27, -PI * 0.75, PI * 0.75, 48, Color(0.15, 0.25, 0.33, 1), 5.0)
	draw_arc(Vector2(size.x - 64, 54), 27, -PI * 0.75, lerpf(-PI * 0.75, PI * 0.75, coherence), 48, Color("7ee9bd"), 5.0)
