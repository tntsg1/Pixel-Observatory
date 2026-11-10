extends Node2D
class_name ObservatoryAmbientDirector

# The hall background remains the source of truth for furniture art. Ambient
# animation reuses cropped source pixels instead of drawing substitute UI art.
# It intentionally never moves a prop, player, or NPC.

const ROOM_TEXTURE := preload("res://assets/reference/observatory_room_hall_1024.png")

const AMBIENT_LAMP_POINTS := [
	Vector2(60, 197), Vector2(425, 143), Vector2(599, 143), Vector2(704, 217),
	Vector2(964, 197), Vector2(82, 645), Vector2(954, 410), Vector2(940, 647),
]
const LAMP_PIXEL_PATCHES := [
	Rect2(52, 180, 17, 29), Rect2(416, 121, 19, 34), Rect2(590, 121, 19, 34),
	Rect2(693, 202, 22, 31), Rect2(955, 180, 17, 29), Rect2(74, 628, 17, 30),
	Rect2(945, 395, 20, 29), Rect2(931, 630, 18, 30),
]
const AMBIENT_MOTE_POINTS := [
	Vector2(54, 185), Vector2(67, 204), Vector2(417, 133), Vector2(608, 133),
	Vector2(696, 207), Vector2(715, 224), Vector2(956, 185), Vector2(973, 205),
]
const TERMINAL_SCREEN := Rect2(795, 544, 112, 45)
const TERMINAL_SCREEN_PATCH := Rect2(795, 544, 112, 45)
const JOURNAL_RIGHT_PAGE_PATCH := Rect2(145, 488, 34, 27)
const TELESCOPE_FOCUS_PATCH := Rect2(499, 421, 30, 30)
const BENCH_ACTIVITY_RECT := Rect2(827, 347, 138, 72)
const MISSION_ACTIVITY_RECT := Rect2(715, 128, 144, 65)
const CABINET_ACTIVITY_RECT := Rect2(130, 164, 176, 35)
const JOURNAL_ACTIVITY_RECT := Rect2(96, 508, 151, 38)
const TELESCOPE_PIVOT := Vector2(514, 430)
const TELESCOPE_TRACK_POINTS := [
	Vector2(514, 382), Vector2(548, 396), Vector2(562, 430), Vector2(548, 464),
	Vector2(514, 478), Vector2(480, 464), Vector2(466, 430), Vector2(480, 396),
]

const WARM_DIM := Color(1.0, 0.68, 0.24, 0.18)
const WARM_BRIGHT := Color(1.0, 0.80, 0.42, 0.48)
const CYAN_DIM := Color(0.36, 0.88, 1.0, 0.16)
const CYAN_BRIGHT := Color(0.54, 0.96, 1.0, 0.72)
const GREEN_DIM := Color(0.34, 1.0, 0.60, 0.18)
const GREEN_BRIGHT := Color(0.52, 1.0, 0.68, 0.76)

var ambient_layer: Node2D
var task_layer: Node2D
var elapsed := 0.0
var _redraw_elapsed := 0.0


func setup() -> void:
	name = "ObservatoryAmbientDirector"
	# Keep the room alive above the painted furniture but below actors.  The old
	# negative layer made the animation technically present yet visually lost in
	# the source texture.
	z_index = 0
	ambient_layer = _AmbientLayer.new()
	ambient_layer.name = "AmbientLayer"
	ambient_layer.director = self
	ambient_layer.z_index = 0
	add_child(ambient_layer)
	ambient_layer.setup()
	task_layer = _TaskPerformanceLayer.new()
	task_layer.name = "TaskPerformanceLayer"
	task_layer.director = self
	task_layer.z_index = 8
	add_child(task_layer)


func _process(delta: float) -> void:
	elapsed += delta
	_redraw_elapsed += delta
	# The room has a painted pixel style. 30 fps is smoother than the source art
	# needs and avoids spending a redraw on every physics frame in the browser.
	if _redraw_elapsed < (1.0 / 30.0):
		return
	_redraw_elapsed = 0.0
	if ambient_layer != null:
		ambient_layer.animate_pixels(elapsed, _reduced_motion_enabled())
		ambient_layer.queue_redraw()
	if task_layer != null:
		task_layer.queue_redraw()


func ambient_snapshot() -> Dictionary:
	var pixel_state: Dictionary = {}
	if ambient_layer != null:
		pixel_state = ambient_layer.call("pixel_snapshot") as Dictionary
	return {
		"ambient_layer": ambient_layer != null,
		"task_layer": task_layer != null,
		"ambient_lamps": AMBIENT_LAMP_POINTS.size(),
		"ambient_motes": AMBIENT_MOTE_POINTS.size(),
		"task_target": _task_target(),
		"ambient_intensity": 0.32,
		"task_intensity": 0.88,
		"reduced_motion": _reduced_motion_enabled(),
		"mote_motion": 0.0 if _reduced_motion_enabled() else 1.0,
		"pixel_lamps": int(pixel_state.get("lamp_pixels", 0)),
		"terminal_pixel_animation": bool(pixel_state.get("terminal", false)),
		"journal_page_animation": bool(pixel_state.get("journal_page", false)),
		"focus_pixel_animation": bool(pixel_state.get("focus", false)),
	}


func _task_target() -> String:
	var manager := get_node_or_null("/root/GameManager")
	return str(manager.get("room_guidance_target")) if manager != null else ""


func _reduced_motion_enabled() -> bool:
	var feedback := get_node_or_null("/root/InteractionFeedback")
	return feedback != null and bool(feedback.get("reduced_motion"))


class _AmbientLayer extends Node2D:
	var director: ObservatoryAmbientDirector
	var lamp_pixels: Array[Control] = []
	var terminal_pixels: Control
	var journal_page_pixels: Control
	var focus_pixels: Control
	var _terminal_base := Vector2.ZERO
	var _page_base := Vector2.ZERO
	var _focus_base := Vector2.ZERO

	func setup() -> void:
		for region in LAMP_PIXEL_PATCHES:
			lamp_pixels.append(_make_pixel_patch(region))
		terminal_pixels = _make_pixel_patch(TERMINAL_SCREEN_PATCH)
		_terminal_base = terminal_pixels.position
		journal_page_pixels = _make_pixel_patch(JOURNAL_RIGHT_PAGE_PATCH)
		_page_base = journal_page_pixels.position
		journal_page_pixels.pivot_offset = Vector2(1, journal_page_pixels.size.y - 2)
		focus_pixels = _make_pixel_patch(TELESCOPE_FOCUS_PATCH)
		_focus_base = focus_pixels.position

	func _make_pixel_patch(region: Rect2) -> Control:
		var atlas := AtlasTexture.new()
		atlas.atlas = ROOM_TEXTURE
		atlas.region = region
		var patch := TextureRect.new()
		patch.texture = atlas
		patch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patch.position = region.position
		patch.size = region.size
		add_child(patch)
		return patch

	func animate_pixels(t: float, reduced: bool) -> void:
		for index in range(lamp_pixels.size()):
			var patch := lamp_pixels[index]
			var flicker := 0.84 if reduced else 0.78 + sin(t * (2.1 + float(index % 3) * 0.29) + float(index) * 1.67) * 0.18
			patch.modulate = Color(1.0 + flicker * 0.12, 0.94 + flicker * 0.16, 0.76 + flicker * 0.10, 0.36 + flicker * 0.48)
		# The book uses the original right-page pixels. Once per calm cycle it
		# lifts at the spine, narrows edge-on, then settles back onto the desk.
		var page_cycle := 0.0 if reduced else fposmod(t, 6.8)
		var page_turn := sin(clampf(page_cycle / 0.82, 0.0, 1.0) * PI) if page_cycle < 0.82 else 0.0
		journal_page_pixels.scale = Vector2(1.0 - page_turn * 0.82, 1.0 + page_turn * 0.08)
		journal_page_pixels.position = _page_base + Vector2(page_turn * 5.0, -page_turn * 3.0)
		journal_page_pixels.modulate = Color(1.0 + page_turn * 0.20, 0.98 + page_turn * 0.12, 0.86 + page_turn * 0.08, 1.0)
		# The terminal remains its supplied CRT pixels, but its content shifts
		# through a tiny four-state self-test rather than receiving a fake overlay.
		var terminal_tick := 0 if reduced else int(floor(t * 5.0)) % 4
		terminal_pixels.position = _terminal_base + Vector2(terminal_tick % 2, 0)
		var crt_strength := 0.88 if reduced else 0.82 + float(terminal_tick) * 0.05
		terminal_pixels.modulate = Color(0.86, 1.0 + crt_strength * 0.10, 0.90, 0.72 + crt_strength * 0.26)
		# The real brass focus assembly moves one pixel through a maintenance
		# cycle. Its original artwork stays intact; only the foreground part shifts.
		var focus_step := 0 if reduced else int(floor(t * 2.2)) % 4
		var focus_offset: Vector2 = [Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)][focus_step]
		focus_pixels.position = _focus_base + focus_offset
		focus_pixels.modulate = Color(1.0 + float(focus_step) * 0.025, 1.0, 0.96, 0.76)

	func pixel_snapshot() -> Dictionary:
		return {
			"lamp_pixels": lamp_pixels.size(),
			"terminal": terminal_pixels != null,
			"journal_page": journal_page_pixels != null,
			"focus": focus_pixels != null,
		}

	func _draw() -> void:
		if director == null:
			return
		var reduced := director._reduced_motion_enabled()
		var t := director.elapsed
		for index in range(AMBIENT_LAMP_POINTS.size()):
			var point: Vector2 = AMBIENT_LAMP_POINTS[index]
			var pulse := 0.72 if reduced else 0.68 + sin(t * (1.18 + float(index % 3) * 0.17) + float(index) * 1.83) * 0.14
			var outer := WARM_DIM
			outer.a *= pulse * 0.48
			draw_rect(Rect2(point - Vector2(2, 0), Vector2(4, 1)), outer, true)
			var core := WARM_BRIGHT
			core.a *= pulse * 0.42
			draw_rect(Rect2(point, Vector2(1, 1)), core, true)
			if not reduced and sin(t * 2.17 + float(index) * 1.43) > 0.74:
				draw_rect(Rect2(point + Vector2(3, -4), Vector2(1, 1)), Color(1.0, 0.86, 0.50, 0.72), true)
		if reduced:
			return
		for index in range(AMBIENT_MOTE_POINTS.size()):
			var home: Vector2 = AMBIENT_MOTE_POINTS[index]
			var phase := t * (0.56 + float(index % 4) * 0.11) + float(index) * 1.71
			var rise := fposmod(phase * 7.0, 18.0)
			var drift := sin(phase * 1.73) * 1.5
			var alpha := 0.12 + (sin(phase * 2.31) + 1.0) * 0.12
			draw_rect(Rect2(home + Vector2(drift, -rise), Vector2(1, 1)), Color(1.0, 0.78, 0.39, alpha), true)


class _TaskPerformanceLayer extends Node2D:
	var director: ObservatoryAmbientDirector

	func _draw() -> void:
		if director == null:
			return
		var target := director._task_target()
		if target.is_empty():
			return
		var t := director.elapsed
		var reduced := director._reduced_motion_enabled()
		var pulse := 0.72 if reduced else 0.58 + (sin(t * 2.5) + 1.0) * 0.16
		match target:
			"assembly":
				_draw_station_frame(BENCH_ACTIVITY_RECT, CYAN_BRIGHT, pulse)
				var sweep_x := BENCH_ACTIVITY_RECT.position.x + 7.0 + fposmod(t * 42.0, BENCH_ACTIVITY_RECT.size.x - 14.0)
				draw_rect(Rect2(sweep_x, BENCH_ACTIVITY_RECT.position.y + 6.0, 2, BENCH_ACTIVITY_RECT.size.y - 12.0), Color(0.62, 0.96, 1.0, 0.64 * pulse), true)
			"telescope":
				_draw_crosshair(TELESCOPE_PIVOT, GREEN_BRIGHT, pulse)
			"computer":
				_draw_station_frame(TERMINAL_SCREEN.grow(2), GREEN_BRIGHT, pulse)
				var task_scan := TERMINAL_SCREEN.position.y + 3.0 + fposmod(t * 28.0, TERMINAL_SCREEN.size.y - 6.0)
				draw_line(Vector2(TERMINAL_SCREEN.position.x + 2, task_scan), Vector2(TERMINAL_SCREEN.end.x - 2, task_scan), Color(0.56, 1.0, 0.70, 0.72 * pulse), 1.0)
			"mission":
				_draw_station_frame(MISSION_ACTIVITY_RECT, WARM_BRIGHT, pulse)
				_draw_corner_pin(MISSION_ACTIVITY_RECT.get_center(), WARM_BRIGHT, pulse)
			"cabinet":
				_draw_station_frame(CABINET_ACTIVITY_RECT, WARM_BRIGHT, pulse)
			"journal":
				_draw_station_frame(JOURNAL_ACTIVITY_RECT, CYAN_BRIGHT, pulse)
			"door":
				_draw_station_frame(Rect2(465, 108, 95, 95), WARM_BRIGHT, pulse)
				_draw_corner_pin(Vector2(513, 152), WARM_BRIGHT, pulse)

	func _draw_station_frame(rect: Rect2, color: Color, pulse: float) -> void:
		var line_color := color
		line_color.a *= pulse
		draw_rect(rect, line_color, false, 1.0)
		draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), Color(line_color.r, line_color.g, line_color.b, line_color.a * 0.38), false, 1.0)

	func _draw_crosshair(center: Vector2, color: Color, pulse: float) -> void:
		var line_color := color
		line_color.a *= pulse
		draw_line(center + Vector2(-16, 0), center + Vector2(-5, 0), line_color, 1.0)
		draw_line(center + Vector2(5, 0), center + Vector2(16, 0), line_color, 1.0)
		draw_line(center + Vector2(0, -16), center + Vector2(0, -5), line_color, 1.0)
		draw_line(center + Vector2(0, 5), center + Vector2(0, 16), line_color, 1.0)
		draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), line_color, false, 1.0)

	func _draw_corner_pin(center: Vector2, color: Color, pulse: float) -> void:
		var pin := color
		pin.a *= pulse
		draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), pin, true)
		draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), pin, 1.0)
		draw_line(center + Vector2(0, -7), center + Vector2(0, 7), pin, 1.0)
