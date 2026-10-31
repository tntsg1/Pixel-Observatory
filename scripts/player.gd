extends CharacterBody2D

signal player_died

const SPEED := 280.0
const MAX_HP := 5
const INVINCIBLE_TIME := 1.5
const PRIMARY_RATE := 0.18
const FAN_RATE := 0.95
const PULSE_RATE := 3.25
const AUTO_TARGET_RANGE := 960.0
const SHOOT_SFX := "res://ImportedAssets/SimpleTopDownShooterTemplate2D/assets/sound_effects/laserShoot.wav"
const HIT_SFX := "res://ImportedAssets/SimpleTopDownShooterTemplate2D/assets/sound_effects/hitHurt.wav"

var hp := MAX_HP
var invincible_timer := 0.0
var primary_cooldown := 0.0
var fan_cooldown := 0.35
var pulse_cooldown := 1.2
var shot_index := 0
var screen_size: Vector2
var explosion_scene: PackedScene
var impact_scene := preload("res://scenes/fx/impact_burst.tscn")

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var bullet_scene := preload("res://scenes/bullet.tscn")


func _ready() -> void:
	add_to_group("player")
	screen_size = get_viewport_rect().size

	var sf = load("res://spriteframes/units/neutral_sol.tres")
	if sf:
		anim.sprite_frames = sf
		anim.play("idle")

	explosion_scene = load("res://Misc/ExplosionEffect2D/explosion_2d_scene.tscn")


func _physics_process(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer -= delta
		anim.modulate.a = 0.55 + 0.45 * abs(sin(invincible_timer * 28.0))
	else:
		anim.modulate.a = 1.0

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * SPEED
	move_and_slide()
	position = position.clamp(Vector2(20, 20), screen_size - Vector2(20, 20))

	primary_cooldown -= delta
	fan_cooldown -= delta
	pulse_cooldown -= delta

	var target := _find_auto_target()
	if is_instance_valid(target):
		var aim_dir := (target.global_position - global_position).normalized()
		rotation = aim_dir.angle()
		_auto_fire(aim_dir)
	elif input_dir.length() > 0.1:
		rotation = input_dir.angle()

	_update_animation(input_dir)


func _update_animation(input_dir: Vector2) -> void:
	if input_dir.length() > 0.1:
		if anim.sprite_frames and anim.sprite_frames.has_animation("run"):
			anim.play("run")
	else:
		if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
			anim.play("idle")


func _find_auto_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist_sq := AUTO_TARGET_RANGE * AUTO_TARGET_RANGE

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("can_be_targeted") and not enemy.can_be_targeted():
			continue
		if not enemy is Node2D:
			continue

		var dist_sq := global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest = enemy
			nearest_dist_sq = dist_sq

	return nearest


func _auto_fire(aim_dir: Vector2) -> void:
	if primary_cooldown <= 0.0:
		shot_index += 1
		if shot_index % 4 == 0:
			_fire_fan(aim_dir, 3, 0.18, 620.0, Color(0.45, 0.9, 1.0))
		else:
			_fire_bullet(aim_dir, 680.0, 1, Color(1.0, 0.92, 0.25))
		primary_cooldown = PRIMARY_RATE

	if fan_cooldown <= 0.0:
		_fire_fan(aim_dir, 5, 0.36, 540.0, Color(0.35, 1.0, 0.65))
		fan_cooldown = FAN_RATE

	if pulse_cooldown <= 0.0 and _nearby_enemy_count(260.0) >= 3:
		_fire_pulse()
		pulse_cooldown = PULSE_RATE


func _nearby_enemy_count(radius: float) -> int:
	var count := 0
	var radius_sq := radius * radius
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("can_be_targeted") and not enemy.can_be_targeted():
			continue
		if enemy is Node2D and global_position.distance_squared_to(enemy.global_position) <= radius_sq:
			count += 1
	return count


func _fire_fan(center_dir: Vector2, count: int, spread: float, bullet_speed: float, bullet_color: Color) -> void:
	var start := -spread * float(count - 1) * 0.5
	for i in range(count):
		var dir := center_dir.rotated(start + spread * float(i))
		_fire_bullet(dir, bullet_speed, 1, bullet_color, false)
	_play_shoot_feedback(center_dir, bullet_color, 18.0)


func _fire_pulse() -> void:
	var count := 12
	for i in range(count):
		var dir := Vector2.RIGHT.rotated(TAU * float(i) / float(count))
		_fire_bullet(dir, 460.0, 1, Color(0.75, 0.9, 1.0), false)
	_play_shoot_feedback(Vector2.RIGHT.rotated(rotation), Color(0.75, 0.9, 1.0), 30.0)

	var parent := get_parent()
	if parent and parent.has_method("shake"):
		parent.shake(5.0)


func _fire_bullet(dir: Vector2, bullet_speed: float, bullet_damage: int, bullet_color: Color, with_feedback := true) -> void:
	var muzzle_pos := position + dir * 20.0

	var bullet: Area2D = bullet_scene.instantiate()
	bullet.position = muzzle_pos
	bullet.rotation = dir.angle()
	bullet.direction = dir
	bullet.is_player_bullet = true
	bullet.damage = bullet_damage
	bullet.speed = bullet_speed
	bullet.color = bullet_color
	get_parent().add_child(bullet)

	if with_feedback:
		_play_shoot_feedback(dir, bullet_color, 14.0)


func _play_shoot_feedback(dir: Vector2, flash_color: Color, radius: float) -> void:
	var muzzle_pos := position + dir * 20.0
	var muzzle := impact_scene.instantiate()
	get_parent().add_child(muzzle)
	muzzle.setup(muzzle_pos, flash_color, radius)

	if anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
		anim.play("attack")

	if AudioManager:
		AudioManager.play_sfx(SHOOT_SFX, 0.04, -13.0)


func take_damage(amount: int) -> void:
	if invincible_timer > 0.0 or amount <= 0:
		return

	hp -= amount
	invincible_timer = INVINCIBLE_TIME

	if AudioManager:
		AudioManager.play_sfx(HIT_SFX, 0.05, -8.0)

	var parent := get_parent()
	if parent and parent.has_method("shake"):
		parent.shake(12.0)

	if anim.sprite_frames and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")

	modulate = Color(1.0, 0.25, 0.25)
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE

	if hp <= 0:
		die()


func die() -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation("death"):
		anim.play("death")

	var exp := explosion_scene.instantiate()
	exp.position = position
	get_parent().add_child(exp)
	exp.play_explosion()

	player_died.emit()
	await get_tree().create_timer(0.3).timeout
	queue_free()
