extends Area2D

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 1
var is_player_bullet := false
var color := Color.RED:
	set(v):
		color = v
		queue_redraw()
var lifetime := 3.0

var _timer := 0.0
var impact_scene := preload("res://scenes/fx/impact_burst.tscn")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_timer += delta

	if _timer > lifetime:
		queue_free()
		return

	var vpr := get_viewport_rect()
	if position.x < -50.0 or position.x > vpr.size.x + 50.0 or position.y < -50.0 or position.y > vpr.size.y + 50.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if is_player_bullet:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(damage, direction)
			_spawn_impact(Color(1.0, 0.82, 0.25), 18.0)
			queue_free()
	else:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_spawn_impact(Color(1.0, 0.2, 0.1), 22.0)
			queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.get("is_player_bullet") == null:
		return
	if area.is_player_bullet == is_player_bullet:
		return
	_spawn_impact(Color(1.0, 0.55, 0.15), 16.0)
	area.queue_free()
	queue_free()


func _spawn_impact(burst_color: Color, radius: float) -> void:
	if not is_inside_tree():
		return
	var burst := impact_scene.instantiate()
	get_tree().current_scene.add_child(burst)
	burst.setup(global_position, burst_color, radius)


func _draw() -> void:
	var outer := 4.0 if is_player_bullet else 3.5
	draw_circle(Vector2.ZERO, outer, color)
	draw_circle(Vector2.ZERO, outer * 0.45, Color.WHITE if is_player_bullet else color.lightened(0.35))
