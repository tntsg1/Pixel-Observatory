extends Node2D

const GRID := 64


func _ready() -> void:
	z_index = -100
	queue_redraw()
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.047, 0.055), true)

	for x in range(0, int(size.x) + GRID, GRID):
		var major := x % (GRID * 4) == 0
		var color := Color(0.16, 0.18, 0.21, 0.45 if major else 0.22)
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 2.0 if major else 1.0)

	for y in range(0, int(size.y) + GRID, GRID):
		var major := y % (GRID * 4) == 0
		var color := Color(0.16, 0.18, 0.21, 0.45 if major else 0.22)
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 2.0 if major else 1.0)

	for i in range(18):
		var pos := Vector2(fposmod(i * 173.0, size.x), fposmod(i * 97.0, size.y))
		draw_circle(pos, 2.0, Color(0.8, 0.95, 1.0, 0.08))
