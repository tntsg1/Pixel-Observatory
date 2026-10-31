extends CharacterBody2D
## 玩家控制器 - Echo（均衡型）
## WASD移动 / 自动瞄准最近敌人 / 自动射击 / Shift闪避 / 空格技能

signal player_died
signal player_dodged

# 基础属性（可被升级修改）
var MAX_HP := 5
var MOVE_SPEED := 320.0
var DODGE_COOLDOWN := 1.2
var DODGE_INVINCIBLE := 0.35
var DODGE_SPEED := 900.0
var DODGE_DURATION := 0.15
var SHOOT_RATE := 0.2
var PICKUP_RANGE := 80.0
var CRIT_CHANCE := 0.05
var AIM_RANGE := 600.0
var BULLET_DAMAGE := 1
var BULLET_PENETRATION := 0
var EXTRA_BULLETS := 0

# 状态
var hp := MAX_HP
var invincible_timer := 0.0
var dodge_cooldown_timer := 0.0
var shoot_timer := 0.0
var subweapon_timer := 0.0
var skill_timer := 0.0
var is_dodging := false
var dodge_dir := Vector2.ZERO
var _current_target: Node2D = null

var subweapon_cooldown := 3.0
var skill_cooldown := 8.0
var skill_duration := 3.0
var time_slow_active := false
var _dead := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	add_to_group("player")
	var sf = load("res://spriteframes/units/neutral_sol.tres")
	if sf:
		anim.sprite_frames = sf
		anim.play("idle")


func _physics_process(delta: float):
	_update_timers(delta)
	
	if is_dodging:
		_process_dodge(delta)
		return
	
	_process_movement()
	_process_auto_aim()
	_process_auto_shoot(delta)
	_process_subweapon(delta)
	_process_skill()
	_process_bullet_clear(delta)
	
	move_and_slide()
	_clamp_to_screen()
	_update_animation()


func _update_timers(delta: float):
	if invincible_timer > 0: invincible_timer -= delta
	if dodge_cooldown_timer > 0: dodge_cooldown_timer -= delta
	if shoot_timer > 0: shoot_timer -= delta
	if subweapon_timer > 0: subweapon_timer -= delta
	if skill_timer > 0: skill_timer -= delta


func _process_movement():
	if Input.is_action_just_pressed("dodge") and dodge_cooldown_timer <= 0 and not is_dodging:
		_start_dodge()
		return
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * MOVE_SPEED


func _start_dodge():
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length() < 0.1:
		input_dir = Vector2.RIGHT.rotated(rotation)
	dodge_dir = input_dir
	is_dodging = true
	invincible_timer = DODGE_INVINCIBLE
	dodge_cooldown_timer = DODGE_COOLDOWN
	$DodgeEffect.emitting = true
	player_dodged.emit()
	if GameManager: GameManager.dodge_count += 1


func _process_dodge(delta: float):
	velocity = dodge_dir * DODGE_SPEED
	move_and_slide()
	_clamp_to_screen()
	invincible_timer -= delta * 3
	if invincible_timer <= DODGE_INVINCIBLE - DODGE_DURATION:
		is_dodging = false
		invincible_timer = DODGE_INVINCIBLE - DODGE_DURATION


func _process_auto_aim():
	_current_target = _find_nearest_enemy()
	if _current_target:
		look_at(_current_target.global_position)


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist := AIM_RANGE * AIM_RANGE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		# 跳过已死亡的
		if enemy.get("_dying") == true:
			continue
		if enemy is CollisionObject2D and enemy.collision_layer == 0:
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


func _process_auto_shoot(_delta: float):
	if shoot_timer <= 0:
		shoot_timer = SHOOT_RATE
		if _current_target:
			_fire_primary()


func _fire_primary():
	if not BulletManager: return
	var dir := Vector2.RIGHT.rotated(rotation)
	var spawn_pos := position + dir * 20
	var crit := randf() < CRIT_CHANCE
	var dmg := BULLET_DAMAGE * (2 if crit else 1)
	var clr := Color.CYAN if crit else Color.DODGER_BLUE
	var sc := Vector2(1.3 if crit else 1, 1.3 if crit else 1)
	
	# 主子弹
	BulletManager.spawn_bullet(true, spawn_pos, dir, 650, dmg, clr, sc)
	
	# 散射额外子弹
	for i in range(EXTRA_BULLETS):
		var offset := deg_to_rad(-5 - i * 3)
		BulletManager.spawn_bullet(true, spawn_pos, dir.rotated(offset), 600, dmg, clr, Vector2(0.8, 0.8))
		if EXTRA_BULLETS > 1:
			BulletManager.spawn_bullet(true, spawn_pos, dir.rotated(-offset), 600, dmg, clr, Vector2(0.8, 0.8))


func _process_subweapon(_delta: float):
	if subweapon_timer <= 0:
		subweapon_timer = subweapon_cooldown
		_fire_subweapon()


func _fire_subweapon():
	if not BulletManager: return
	var dir := Vector2.RIGHT.rotated(rotation)
	var spawn_pos := position + dir * 15
	for i in range(3):
		var angle := deg_to_rad(-10 + i * 10)
		BulletManager.spawn_bullet(true, spawn_pos, dir.rotated(angle), 400, 3, Color.GOLD, Vector2(1.5, 1.5))


func _process_skill():
	if Input.is_action_just_pressed("skill") and skill_timer <= 0:
		skill_timer = skill_cooldown
		_activate_skill()


func _activate_skill():
	time_slow_active = true
	Engine.time_scale = 0.4
	modulate = Color(0.6, 0.8, 1.0, 0.9)
	await get_tree().create_timer(skill_duration * 0.4, false).timeout
	Engine.time_scale = 1.0
	time_slow_active = false
	modulate = Color.WHITE


func _process_bullet_clear(delta: float):
	if not has_meta("bullet_clear_active"):
		return
	var timer: float = get_meta("bullet_clear_timer", 0.0) + delta
	if timer >= 30.0:
		timer = 0.0
		# 清除周围敌方子弹
		var clear_range := 200.0
		for bullet in get_tree().get_nodes_in_group("enemy_bullet"):
			if not is_instance_valid(bullet):
				continue
			if global_position.distance_squared_to(bullet.global_position) < clear_range * clear_range:
				if bullet.has_method("_recycle"):
					bullet._recycle()
		# 视觉反馈
		modulate = Color(1, 1, 1, 1)
		var burst := preload("res://scenes/fx/impact_burst.tscn").instantiate()
		burst.setup(global_position, Color.CYAN, clear_range)
		get_parent().add_child(burst)
	set_meta("bullet_clear_timer", timer)


func take_damage(amount: int):
	if invincible_timer > 0 or amount <= 0 or time_slow_active or _dead: return
	hp -= amount
	if hp < 0: hp = 0
	if GameManager: GameManager.damage_taken += 1
	
	# 震屏
	_trigger_player_shake(0.6)
	
	# 受击闪烁
	modulate = Color.RED
	anim.modulate = Color.WHITE
	if anim.sprite_frames and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	invincible_timer = 0.2
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	anim.modulate = Color.WHITE
	if hp <= 0: die()


func die():
	if _dead: return
	_dead = true
	collision_layer = 0
	
	# 大震屏
	_trigger_player_shake(1.5)
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("death"):
		anim.play("death")
	player_died.emit()
	await get_tree().create_timer(0.5).timeout
	queue_free()


func _trigger_player_shake(intensity: float):
	var parent := get_parent()
	if parent and parent.has_method("add_shake"):
		parent.add_shake(intensity)


func _clamp_to_screen():
	var vpr: Rect2 = get_viewport_rect()
	var margin := 20.0
	position = position.clamp(Vector2(margin, margin), Vector2(vpr.size.x - margin, vpr.size.y - margin))


func _update_animation():
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_dodging or input_dir.length() > 0.1:
		if anim.sprite_frames and anim.sprite_frames.has_animation("run"):
			if anim.animation != "run": anim.play("run")
	else:
		if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
			if anim.animation != "idle": anim.play("idle")
