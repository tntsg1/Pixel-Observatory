extends Area2D
## 池化子弹 - 被BulletManager管理

var direction := Vector2.RIGHT
var speed := 500.0
var damage := 1
var is_player_bullet := false
var bullet_color := Color.RED
var lifetime := 5.0
var _age := 0.0
var _screen_size := Vector2(1024, 768)

@onready var _collision: CollisionShape2D = $CollisionShape2D


func setup(dir: Vector2, spd: float, dmg: int, is_player: bool, clr: Color, sc: Vector2 = Vector2(1,1)) -> void:
	direction = dir
	speed = spd
	damage = dmg
	is_player_bullet = is_player
	bullet_color = clr
	scale = sc
	_age = 0.0
	_collision.disabled = false
	
	if is_player:
		collision_mask = 2
	else:
		collision_mask = 1
		add_to_group("enemy_bullet")


func _ready():
	body_entered.connect(_on_body_hit)
	area_entered.connect(_on_area_hit)


func _physics_process(delta: float):
	position += direction * speed * delta
	_age += delta
	
	if _age > lifetime:
		_recycle()
		return
	
	var margin := 60.0
	if position.x < -margin or position.x > _screen_size.x + margin or position.y < -margin or position.y > _screen_size.y + margin:
		_recycle()
		return
	
	queue_redraw()


func _on_body_hit(body: Node):
	if is_player_bullet:
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(damage)
			_spawn_hit_effect()
			_recycle()
	else:
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			_spawn_hit_effect()
			_recycle()


func _spawn_hit_effect():
	var burst := preload("res://scenes/fx/impact_burst.tscn").instantiate()
	burst.setup(position, bullet_color, 10)
	get_parent().add_child(burst)


func _on_area_hit(area: Area2D):
	if area.has_method("setup") and area.get("is_player_bullet") != null:
		if area.is_player_bullet != is_player_bullet:
			area._recycle()
			_recycle()


func _recycle() -> void:
	_collision.disabled = true
	remove_from_group("enemy_bullet")
	if BulletManager:
		BulletManager.return_bullet(self)


func _draw():
	draw_circle(Vector2.ZERO, 3 * scale.x, bullet_color)
	draw_circle(Vector2.ZERO, 1.5 * scale.x, Color.WHITE if is_player_bullet else bullet_color.lightened(0.3))
