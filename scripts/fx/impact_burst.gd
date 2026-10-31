extends Node2D

var color := Color.WHITE
var radius := 24.0
var duration := 0.18
var _age := 0.0


func setup(pos: Vector2, burst_color: Color, burst_radius := 24.0) -> void:
	global_position = pos
	color = burst_color
	radius = burst_radius
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clamp(_age / duration, 0.0, 1.0)
	var alpha: float = 1.0 - t
	var outer: float = radius * (0.35 + t * 0.85)
	var c := Color(color.r, color.g, color.b, alpha)

	draw_circle(Vector2.ZERO, 3.0 + 5.0 * t, c)
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0
		var dir := Vector2.RIGHT.rotated(angle)
		draw_line(dir * outer * 0.35, dir * outer, c, 2.0)
