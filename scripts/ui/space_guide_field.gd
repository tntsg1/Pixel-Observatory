extends Control
class_name SpaceGuideField

signal candidate_changed(index: int)

var guide_stars: Array = []
var candidate := -1
var chosen := -1
var pointing_error := 8.0
var drift_rate := 0.9
var locked := false
var dragging := false
var input_locked := false
var search_center := Vector2(118, 322)
var history: Array[float] = []
var sequence_phase := "search"
var sequence_index := -1
var sequence_progress := 0.0
var sequence_elapsed := 0.0
var lock_pulse := 0.0

const STAR_POSITIONS := [
	Vector2(118, 118), Vector2(302, 218), Vector2(456, 112), Vector2(226, 338),
	Vector2(388, 320), Vector2(500, 260)
]
const HOT := Color(0.96, 0.96, 0.96)
const MID := Color(0.58, 0.58, 0.58)
const DIM := Color(0.28, 0.28, 0.28)
const GRAPH_HEADER_HEIGHT := 19.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func set_stars(value: Array) -> void:
	guide_stars = value
	queue_redraw()


func update_metrics(error: float, drift: float, is_locked: bool, chosen_index: int) -> void:
	pointing_error = error
	drift_rate = drift
	locked = is_locked
	chosen = chosen_index
	history.append(clampf(error / 10.0, 0.0, 1.0))
	while history.size() > 70:
		history.pop_front()
	queue_redraw()


func begin_acquisition(index: int) -> void:
	sequence_phase = "slew"
	sequence_index = index
	sequence_progress = 0.0
	sequence_elapsed = 0.0
	lock_pulse = 0.0
	queue_redraw()


func begin_fine_guidance(index: int) -> void:
	sequence_phase = "fine"
	sequence_index = index
	sequence_progress = 0.0
	sequence_elapsed = 0.0
	queue_redraw()


func update_sequence_progress(phase: String, progress: float) -> void:
	sequence_phase = phase
	sequence_progress = clampf(progress, 0.0, 1.0)
	queue_redraw()


func begin_lock_ceremony() -> void:
	sequence_phase = "locked"
	sequence_progress = 1.0
	lock_pulse = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	sequence_elapsed += delta
	if sequence_phase == "locked":
		lock_pulse = minf(1.0, lock_pulse + delta * 1.8)
	if sequence_phase != "search":
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if input_locked:
		accept_event()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		dragging = (event as InputEventMouseButton).pressed
		if dragging:
			_move_search((event as InputEventMouseButton).position)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_move_search((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventScreenTouch:
		dragging = (event as InputEventScreenTouch).pressed
		if dragging:
			_move_search((event as InputEventScreenTouch).position)
		accept_event()
	elif event is InputEventScreenDrag:
		_move_search((event as InputEventScreenDrag).position)
		accept_event()


func _move_search(position: Vector2) -> void:
	search_center = Vector2(
		clampf(position.x, 48.0, size.x - 48.0),
		clampf(position.y, 82.0, size.y - 118.0)
	)
	var next := -1
	var nearest := 46.0
	for index in range(mini(guide_stars.size(), STAR_POSITIONS.size())):
		var distance := search_center.distance_to(STAR_POSITIONS[index])
		if distance < nearest:
			nearest = distance
			next = index
	if next != candidate:
		candidate = next
		candidate_changed.emit(candidate)
	queue_redraw()


func set_input_locked(value: bool) -> void:
	input_locked = value
	dragging = false
	queue_redraw()


func guide_direction(index: int) -> Vector2:
	if index < 0 or index >= STAR_POSITIONS.size():
		return Vector2.ZERO
	var field_center := Vector2(size.x * 0.5, (68.0 + size.y - 82.0) * 0.5)
	var half_extent := Vector2(maxf(1.0, size.x * 0.5 - 28.0), maxf(1.0, (size.y - 150.0) * 0.5))
	var direction_delta: Vector2 = STAR_POSITIONS[index] - field_center
	return Vector2(
		clampf(direction_delta.x / half_extent.x, -1.0, 1.0),
		clampf(direction_delta.y / half_extent.y, -1.0, 1.0)
	)


func _draw() -> void:
	draw_rect(Rect2(Vector2(28, 68), Vector2(size.x - 56, size.y - 150)), Color(0.025, 0.025, 0.025), true)
	draw_rect(Rect2(Vector2(28, 68), Vector2(size.x - 56, size.y - 150)), DIM, false, 1.0)
	for x in range(44, int(size.x) - 30, 32):
		draw_line(Vector2(x, 68), Vector2(x, size.y - 82), Color(0.12, 0.12, 0.12), 1.0)
	for y in range(84, int(size.y) - 82, 28):
		draw_line(Vector2(28, y), Vector2(size.x - 28, y), Color(0.12, 0.12, 0.12), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(28, 50), GameManager.text(
		"DRAG SEARCH BOX ACROSS THE SENSOR FIELD", "拖动搜索框扫描传感器星场"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MID)

	for index in range(mini(guide_stars.size(), STAR_POSITIONS.size())):
		var star: Dictionary = guide_stars[index]
		var p: Vector2 = STAR_POSITIONS[index]
		var brightness := float(star.get("brightness", 0.4))
		var usable := bool(star.get("usable", false))
		var radius := 2.0 + brightness * 5.0
		var display_p := p
		if index == sequence_index and sequence_phase != "search":
			var unsettled := 0.0
			if sequence_phase == "slew":
				unsettled = 1.0 - sequence_progress
			elif sequence_phase == "fine":
				unsettled = clampf(pointing_error / 7.0, 0.0, 1.0)
			var jitter := Vector2(
				sin(sequence_elapsed * 13.0),
				cos(sequence_elapsed * 9.0 + 0.7)
			) * unsettled * 7.0
			display_p += jitter
			if sequence_phase == "locked":
				draw_circle(display_p, radius + 7.0, Color(0.32, 0.86, 1.0, 0.08 + lock_pulse * 0.10), true)
				draw_circle(display_p, radius + 2.0, Color(0.55, 0.95, 1.0, 0.20 + lock_pulse * 0.16), true)
		var star_color := Color(0.68, 0.95, 1.0) if index == sequence_index and sequence_phase == "locked" else (HOT if usable else DIM)
		draw_circle(display_p, radius, star_color, true)
		draw_line(display_p - Vector2(10, 0), display_p + Vector2(10, 0), Color(star_color, 0.35), 1.0)
		draw_line(display_p - Vector2(0, 10), display_p + Vector2(0, 10), Color(star_color, 0.35), 1.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-18, 24), str(star.get("id", "GS")),
			HORIZONTAL_ALIGNMENT_CENTER, 36, 10, HOT if index == candidate else MID)
		if index == sequence_index or index == chosen:
			_draw_acquisition_corners(p, sequence_phase == "locked")

	var box := Rect2(search_center - Vector2(42, 32), Vector2(84, 64))
	var box_color := DIM if input_locked else (HOT if candidate >= 0 else MID)
	draw_rect(box, box_color, false, 2.0)
	var corner := 10.0
	for p in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		var sx := 1.0 if p.x == box.position.x else -1.0
		var sy := 1.0 if p.y == box.position.y else -1.0
		draw_line(p, p + Vector2(sx * corner, 0), HOT, 3.0)
		draw_line(p, p + Vector2(0, sy * corner), HOT, 3.0)

	_draw_drift_graph(drift_graph_rect())


func _draw_acquisition_corners(center: Vector2, is_fine_lock: bool) -> void:
	var convergence := 0.0
	if sequence_phase == "slew":
		convergence = sequence_progress * 0.42
	elif sequence_phase == "fine":
		convergence = clampf(1.0 - pointing_error / 7.0, 0.42, 0.92)
	elif sequence_phase == "locked":
		convergence = 1.0
	var half_extent := lerpf(36.0, 15.0, convergence)
	var corner_length := 10.0
	var color := Color(0.52, 0.94, 1.0) if is_fine_lock else HOT
	for signs_value in [
		Vector2(-1, -1), Vector2(1, -1),
		Vector2(1, 1), Vector2(-1, 1)
	]:
		var signs: Vector2 = signs_value
		var corner: Vector2 = center + signs * half_extent
		draw_line(corner, corner - Vector2(signs.x * corner_length, 0), color, 2.0)
		draw_line(corner, corner - Vector2(0, signs.y * corner_length), color, 2.0)
	if is_fine_lock:
		draw_rect(Rect2(center - Vector2.ONE * half_extent, Vector2.ONE * half_extent * 2.0), Color(color, 0.52), false, 1.0)
		draw_circle(center, 1.5, color, true)


func drift_graph_rect() -> Rect2:
	return Rect2(66, size.y - 70, size.x - 132, 50)


func drift_plot_rect() -> Rect2:
	var graph := drift_graph_rect()
	return Rect2(
		graph.position + Vector2(5, GRAPH_HEADER_HEIGHT + 2.0),
		Vector2(graph.size.x - 10.0, graph.size.y - GRAPH_HEADER_HEIGHT - 7.0)
	)


func _draw_drift_graph(rect: Rect2) -> void:
	draw_rect(rect, Color(0.02, 0.02, 0.02), true)
	draw_rect(rect, DIM, false, 1.0)
	var header_rect := Rect2(rect.position + Vector2.ONE, Vector2(rect.size.x - 2.0, GRAPH_HEADER_HEIGHT))
	draw_rect(header_rect, Color(0.055, 0.055, 0.055), true)
	draw_line(
		Vector2(rect.position.x + 1.0, rect.position.y + GRAPH_HEADER_HEIGHT),
		Vector2(rect.end.x - 1.0, rect.position.y + GRAPH_HEADER_HEIGHT),
		DIM, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(7, 14),
		GameManager.text("GUIDANCE DRIFT", "导星漂移"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, MID)
	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(rect.size.x - 142.0, 14),
		"%.2f arcsec/s" % _residual_drift(),
		HORIZONTAL_ALIGNMENT_RIGHT, 134, 10, HOT if locked else MID)

	var plot_rect := drift_plot_rect()
	draw_line(
		Vector2(plot_rect.position.x, plot_rect.get_center().y),
		Vector2(plot_rect.end.x, plot_rect.get_center().y),
		Color(DIM, 0.55), 1.0)
	if history.size() < 2:
		return
	var points := PackedVector2Array()
	for index in range(history.size()):
		var x := plot_rect.position.x + float(index) / float(maxi(1, history.size() - 1)) * plot_rect.size.x
		var y := plot_rect.end.y - float(history[index]) * plot_rect.size.y
		points.append(Vector2(x, y))
	draw_polyline(points, HOT if locked else MID, 2.0)


func _residual_drift() -> float:
	if chosen < 0:
		return drift_rate
	return maxf(0.01, maxf(0.25, drift_rate) * clampf(pointing_error / 6.0, 0.04, 1.0))
