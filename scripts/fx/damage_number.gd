extends Label

var velocity := Vector2.ZERO
var lifetime := 0.55
var _age := 0.0


func setup(amount: int, pos: Vector2, tint: Color = Color.WHITE) -> void:
	text = str(amount)
	global_position = pos
	modulate = tint
	velocity = Vector2(randf_range(-22.0, 22.0), -70.0)
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	_age += delta
	global_position += velocity * delta
	velocity.y += 120.0 * delta

	var t: float = clamp(_age / lifetime, 0.0, 1.0)
	modulate.a = 1.0 - t
	scale = Vector2.ONE * lerp(1.35, 0.75, t)

	if _age >= lifetime:
		queue_free()
