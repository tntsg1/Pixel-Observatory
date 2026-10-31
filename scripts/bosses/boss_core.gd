extends CharacterBody2D
## Boss: 废弃观测站核心 - 3阶段

signal boss_died

enum Phase { ONE, TWO, THREE }

var phase: Phase = Phase.ONE
var hp: int = 80
var max_hp: int = 80
var player_ref: CharacterBody2D
var screen_size: Vector2

# 攻击计时
var _main_timer := 0.0
var _attack_index := 0
var _laser_timer := 0.0
var _laser_active := false
var _laser_angle := 0.0
var _summon_timer := 0.0
var _phase_transition := false
var _dying := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var laser_warning: ColorRect = $LaserWarning
@onready var hp_fill: ColorRect = $HPBarBg/HPBarFill


func _ready():
	add_to_group("enemy")
	add_to_group("boss")
	screen_size = get_viewport_rect().size
	position = Vector2(screen_size.x / 2, 120)
	
	# 加载精灵
	var sf = load("res://spriteframes/units/boss_chaosknight.tres")
	if sf:
		anim.sprite_frames = sf
		anim.play("idle")
	
	_update_hp_bar()


func setup(player: CharacterBody2D):
	player_ref = player


func _physics_process(delta: float):
	if _phase_transition or not is_instance_valid(player_ref):
		return
	
	_main_timer += delta
	
	# 阶段转换
	if hp < max_hp * 0.65 and phase == Phase.ONE:
		_enter_phase(Phase.TWO)
	elif hp < max_hp * 0.3 and phase == Phase.TWO:
		_enter_phase(Phase.THREE)
	
	match phase:
		Phase.ONE: _process_phase1(delta)
		Phase.TWO: _process_phase2(delta)
		Phase.THREE: _process_phase3(delta)
	
	_update_hp_bar()


func _enter_phase(new_phase: Phase):
	_phase_transition = true
	modulate = Color.WHITE
	anim.play("hit")
	
	# 清除屏幕上所有敌方子弹
	for bullet in get_tree().get_nodes_in_group("enemy_bullet"):
		if is_instance_valid(bullet) and bullet.has_method("_recycle"):
			bullet._recycle()
	
	# 阶段转换震屏
	_trigger_boss_shake(1.0)
	
	# 白色闪光
	modulate = Color.WHITE
	await get_tree().create_timer(0.3).timeout
	
	phase = new_phase
	_attack_index = 0
	_main_timer = 0
	modulate = Color.WHITE
	anim.play("idle")
	_phase_transition = false
	
	match new_phase:
		Phase.TWO:
			anim.scale = Vector2(1.7, 1.7)
			modulate = Color(1, 0.8, 0.6)
		Phase.THREE:
			anim.scale = Vector2(2.0, 2.0)
			modulate = Color(1, 0.4, 0.3)


func _process_phase1(delta: float):
	# 阶段一：教学 - 环形弹 + 召唤无人机 + 激光预警
	_laser_timer += delta
	
	# 缓慢左右移动
	var t := _main_timer * 0.5
	position.x = screen_size.x / 2 + sin(t) * 200
	position.y = 120 + sin(t * 1.3) * 40
	
	match _attack_index:
		0:  # 环形弹
			if _main_timer > 3.0:
				_fire_ring(12, 160)
				_main_timer = 0
				_attack_index = 1
		1:  # 召唤无人机
			if _main_timer > 2.0:
				_summon_drones(2)
				_main_timer = 0
				_attack_index = 2
		2:  # 激光预警
			if _main_timer > 4.0 and not _laser_active:
				_start_laser()
				_main_timer = 0
				_attack_index = 0


func _process_phase2(delta: float):
	# 阶段二：双层环 + 旋转激光 + 边缘危险区
	_laser_timer += delta
	
	var t := _main_timer * 0.7
	position.x = screen_size.x / 2 + sin(t) * 250
	position.y = 120 + sin(t * 0.8) * 60
	
	match _attack_index:
		0:  # 双层环
			if _main_timer > 2.5:
				_fire_ring(12, 160)
				_fire_ring(18, 200)
				_main_timer = 0
				_attack_index = 1
		1:  # 旋转激光
			if _main_timer > 2.0 and not _laser_active:
				_start_laser_rotating()
				_main_timer = 0
				_attack_index = 2
		2:  # 追踪弹 + 环形弹混合
			if _main_timer > 3.0:
				_fire_ring(8, 180)
				for _i in range(3):
					var dir := (player_ref.position - position).normalized()
					_shoot_bullet(dir.rotated(randf_range(-0.3, 0.3)), 220, Color(1, 0.3, 0.6))
				_main_timer = 0
				_attack_index = 0


func _process_phase3(delta: float):
	# 阶段三：暴走 - 密集弹幕 + 快速攻击
	var t := _main_timer * 1.2
	position.x = screen_size.x / 2 + sin(t) * 300
	position.y = 120 + sin(t * 1.5) * 80
	
	var attack_interval := 1.2
	
	if _main_timer > attack_interval:
		match _attack_index % 3:
			0:
				_fire_ring(16, 180)
				_fire_ring(24, 220)
			1:
				for _i in range(5):
					var dir := (player_ref.position - position).normalized()
					_shoot_bullet(dir.rotated(randf_range(-0.4, 0.4)), 280, Color.MAGENTA)
			2:
				_fire_spiral(20)
		_attack_index += 1
		_main_timer = 0


func _fire_ring(count: int, speed: float):
	for i in range(count):
		var dir := Vector2.RIGHT.rotated(TAU * i / count)
		_shoot_bullet(dir, speed, Color.ORANGE_RED)


func _fire_spiral(count: int):
	var base := Time.get_ticks_msec() * 0.001 * 4  # 用真实时间而非_main_timer（已被重置）
	for i in range(count):
		var angle := base + TAU * i / count
		_shoot_bullet(Vector2.RIGHT.rotated(angle), 120 + i * 10, Color.DARK_ORANGE)


func _summon_drones(count: int):
	for _i in range(count):
		var drone := preload("res://scenes/enemies/enemy.tscn").instantiate()
		drone.position = position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		drone.setup(0, 1.0, player_ref)  # Type.EYE = 0
		drone.enemy_died.connect(func(_s): pass)
		get_parent().add_child(drone)


func _start_laser():
	_laser_active = true
	_laser_angle = (player_ref.position - position).angle()
	laser_warning.visible = true
	laser_warning.rotation = _laser_angle
	laser_warning.position = position
	
	await get_tree().create_timer(1.2).timeout  # 预警时间
	laser_warning.visible = false
	
	# 激光伤害判定
	for _i in range(5):
		if is_instance_valid(player_ref):
			var to_player := player_ref.position - position
			var angle_diff: float = abs(to_player.angle() - _laser_angle)
			if angle_diff < 0.08 and to_player.length() < 400:
				player_ref.take_damage(1)
		await get_tree().create_timer(0.15).timeout
	
	_laser_active = false


func _start_laser_rotating():
	_laser_active = true
	_laser_angle = 0
	laser_warning.visible = true
	laser_warning.position = position
	
	for _i in range(60):
		if _dying or _phase_transition:
			break
		_laser_angle += 0.05
		laser_warning.rotation = _laser_angle
		
		if is_instance_valid(player_ref):
			var to_player := player_ref.position - position
			var angle_diff: float = abs(to_player.angle() - _laser_angle)
			if angle_diff < 0.06 and to_player.length() < 400:
				player_ref.take_damage(1)
		
		await get_tree().create_timer(0.05).timeout
	
	laser_warning.visible = false
	_laser_active = false


func _shoot_bullet(dir: Vector2, spd: float, clr: Color):
	if BulletManager:
		BulletManager.spawn_bullet(false, position, dir, spd, 1, clr)


func take_damage(amount: int):
	if _dying: return
	hp -= amount
	modulate = Color.RED
	if anim.sprite_frames and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	await get_tree().create_timer(0.06).timeout
	modulate = Color.WHITE
	
	if hp <= 0:
		die()


func die():
	if _dying: return
	_dying = true
	collision_layer = 0
	remove_from_group("enemy")
	boss_died.emit()
	
	if GameManager:
		GameManager.add_score(1000)
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("death"):
		anim.play("death")
	
	# 大爆炸
	for _i in range(3):
		var exp := preload("res://Misc/ExplosionEffect2D/explosion_2d_scene.tscn").instantiate()
		exp.position = position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		get_parent().add_child(exp)
		exp.play_explosion()
		await get_tree().create_timer(0.2).timeout
	
	queue_free()


func _update_hp_bar():
	hp_fill.size.x = 200.0 * hp / max_hp


func _trigger_boss_shake(intensity: float):
	var parent := get_parent()
	if parent and parent.has_method("add_shake"):
		parent.add_shake(intensity)
