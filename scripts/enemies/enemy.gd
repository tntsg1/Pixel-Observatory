extends CharacterBody2D
## 敌人统一脚本 - 6种类型，按设计文档

enum Type {
	EYE,      # 漂浮眼球：缓慢接近，单发直线弹
	WORM,     # 裂片虫：死亡后分裂3发弹幕
	DRONE,    # 游荡无人机：保持距离，横向射击
	BURST,    # 爆裂球：靠近自爆，地面预警
	SHIELD,   # 护盾兵：正面护盾
	TURRET,   # 精英旋转炮台：静止，螺旋弹幕
}

signal enemy_died(score_value: int)

# 精灵映射
const SPRITE_MAP := {
	Type.EYE: "res://spriteframes/units/neutral_zyx.tres",
	Type.WORM: "res://spriteframes/units/neutral_serpenti.tres",
	Type.DRONE: "res://spriteframes/units/neutral_ubo.tres",
	Type.BURST: "res://spriteframes/units/neutral_paddo.tres",
	Type.SHIELD: "res://spriteframes/units/f1_kingsguard.tres",
	Type.TURRET: "res://spriteframes/units/neutral_tombstone.tres",
}

var enemy_type: Type = Type.EYE
var hp := 2
var max_hp := 2
var move_speed := 80.0
var score_value := 50
var shoot_interval := 2.0
var is_elite := false
var _dying := false

var _shoot_timer := 0.0
var _behavior_timer := 0.0
var _warn_timer := 0.0
var _facing_dir := 0.0
var player_ref: CharacterBody2D
var screen_size: Vector2

# 延迟setup（因为setup在_ready前被调用）
var _pending_type: int = -1
var _pending_difficulty: float = 1.0
var _pending_player: CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var warning_area: ColorRect = $WarningArea
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_fill: ColorRect = $HPBar/HPFill
@onready var shield_indicator: ColorRect = $ShieldIndicator


func _ready():
	add_to_group("enemy")
	screen_size = get_viewport_rect().size
	_shoot_timer = randf() * shoot_interval
	
	# 应用延迟的setup
	if _pending_type >= 0:
		_apply_setup()


func setup(type: Type, difficulty: float, player: CharacterBody2D):
	_pending_type = type
	_pending_difficulty = difficulty
	_pending_player = player
	
	if is_node_ready():
		_apply_setup()


func _apply_setup():
	enemy_type = _pending_type as Type
	player_ref = _pending_player
	var difficulty: float = _pending_difficulty
	
	# 加载精灵
	var path: String = SPRITE_MAP.get(enemy_type, "")
	if path != "":
		var sf = load(path)
		if sf:
			anim.sprite_frames = sf
			anim.play("idle")
	
	# 按类型设置属性
	match enemy_type:
		Type.EYE:
			hp = ceil(2 * difficulty)
			move_speed = 60 + difficulty * 20
			shoot_interval = max(1.2, 2.5 - difficulty * 0.2)
			score_value = 50
		Type.WORM:
			hp = ceil(1.5 * difficulty)
			move_speed = 100 + difficulty * 25
			shoot_interval = max(1.5, 3.0 - difficulty * 0.3)
			score_value = 60
		Type.DRONE:
			hp = ceil(2.5 * difficulty)
			move_speed = 70 + difficulty * 15
			shoot_interval = max(0.8, 1.8 - difficulty * 0.15)
			score_value = 70
		Type.BURST:
			hp = ceil(1 * difficulty)
			move_speed = 130 + difficulty * 30
			shoot_interval = 999  # 不自爆不射击
			score_value = 80
			warning_area.visible = true
			warning_area.size = Vector2(50, 50)
		Type.SHIELD:
			hp = ceil(4 * difficulty)
			move_speed = 40 + difficulty * 10
			shoot_interval = max(1.5, 3.0 - difficulty * 0.2)
			score_value = 90
			shield_indicator.visible = true
		Type.TURRET:
			hp = ceil(6 * difficulty)
			move_speed = 0  # 静止
			shoot_interval = max(0.4, 1.0 - difficulty * 0.1)
			score_value = 200
			is_elite = true
			anim.scale = Vector2(1.0, 1.0)
	
	max_hp = hp
	_update_hp_bar()


func _physics_process(delta: float):
	if not is_instance_valid(player_ref):
		return
	
	_shoot_timer -= delta
	_behavior_timer += delta
	
	match enemy_type:
		Type.EYE: _behavior_eye(delta)
		Type.WORM: _behavior_worm(delta)
		Type.DRONE: _behavior_drone(delta)
		Type.BURST: _behavior_burst(delta)
		Type.SHIELD: _behavior_shield(delta)
		Type.TURRET: _behavior_turret(delta)
	
	move_and_slide()
	
	# 更新朝向和UI
	if velocity.length() > 10:
		anim.flip_h = velocity.x < 0
	hp_bar.position = Vector2(-15, -28)
	shield_indicator.position = Vector2(12, -10)
	
	# 出屏太远自动死亡
	var margin := 200.0
	if position.x < -margin or position.x > screen_size.x + margin or position.y < -margin or position.y > screen_size.y + margin:
		die()


func _behavior_eye(_delta: float):
	# 缓慢接近 + 单发直线弹
	var dir := (player_ref.position - position).normalized()
	velocity = dir * move_speed
	
	if _shoot_timer <= 0:
		_shoot_aimed(1, 0)
		_shoot_timer = shoot_interval
	_anim_from_velocity()


func _behavior_worm(_delta: float):
	# 快速接近
	var dir := (player_ref.position - position).normalized()
	velocity = dir * move_speed
	_anim_from_velocity()


func _behavior_drone(_delta: float):
	# 保持距离 + 横向移动 + 射击
	var to_player := player_ref.position - position
	var dist := to_player.length()
	var ideal := 180.0
	
	if dist < ideal - 30:
		velocity = -to_player.normalized() * move_speed
	elif dist > ideal + 30:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = to_player.normalized().rotated(PI/2) * move_speed * 0.7
	
	if _shoot_timer <= 0:
		var perp := to_player.normalized().rotated(PI/2)
		for side in [-1, 1]:
			_shoot_bullet(perp * side, 250, Color.ORANGE)
		_shoot_timer = shoot_interval
	_anim_from_velocity()


func _behavior_burst(_delta: float):
	# 快速冲脸 + 自爆预警
	var to_player := player_ref.position - position
	velocity = to_player.normalized() * move_speed
	
	warning_area.position = Vector2(-25, -25)
	
	var dist := to_player.length()
	if dist < 50:
		_warn_timer += _delta
		warning_area.color = Color(1, 0.2, 0, 0.3 + _warn_timer * 2)
		if _warn_timer > 0.8:
			_explode()
	else:
		_warn_timer = 0
		warning_area.color = Color(1, 0.3, 0, 0.3)
	_anim_from_velocity()


func _behavior_shield(_delta: float):
	# 面向玩家，正面护盾
	var to_player := player_ref.position - position
	velocity = to_player.normalized() * move_speed * 0.5
	_facing_dir = to_player.angle()
	
	# 护盾始终面朝玩家
	shield_indicator.position = Vector2(cos(_facing_dir) * 16 - 10, sin(_facing_dir) * 16 - 14)
	
	if _shoot_timer <= 0:
		_shoot_aimed(3, 0.25)
		_shoot_timer = shoot_interval
	_anim_from_velocity()


func _behavior_turret(_delta: float):
	# 静止 + 旋转螺旋弹幕
	velocity = Vector2.ZERO
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
	
	if _shoot_timer <= 0:
		var count := 8
		var base_angle := _behavior_timer * 2
		for i in range(count):
			var angle := base_angle + TAU * i / count
			_shoot_bullet(Vector2.RIGHT.rotated(angle), 150, Color.PURPLE)
		_shoot_timer = shoot_interval


func _explode():
	# 爆裂球自爆
	if _dying:
		return
	_dying = true
	collision_layer = 0
	remove_from_group("enemy")
	warning_area.visible = false
	var count := 12
	for i in range(count):
		_shoot_bullet(Vector2.RIGHT.rotated(TAU * i / count), 200, Color.ORANGE_RED)
	
	_spawn_explosion()
	enemy_died.emit(score_value)
	queue_free()


func _shoot_aimed(count: int, spread: float):
	var base := (player_ref.position - position).normalized()
	for i in range(count):
		var offset := (i - (count - 1) / 2.0) * spread
		_shoot_bullet(base.rotated(offset), 200, Color.ORANGE_RED)


func _shoot_bullet(dir: Vector2, spd: float, clr: Color):
	if BulletManager:
		BulletManager.spawn_bullet(false, position, dir, spd, 1, clr)


func take_damage(amount: int):
	if _dying:
		return
	# 护盾兵正面减伤
	if enemy_type == Type.SHIELD:
		var to_attacker := (player_ref.position - position)
		if abs(to_attacker.angle() - _facing_dir) < PI / 3:
			amount = max(1, amount - 2)
	
	hp -= amount
	_update_hp_bar()
	
	# === 打击反馈 ===
	# 击退
	if player_ref:
		var knockback := (position - player_ref.position).normalized() * 40.0
		position += knockback * 0.5
	
	# 受击闪烁
	modulate = Color.WHITE
	anim.modulate = Color.RED
	
	# 冲击波特效
	_spawn_impact(Color.ORANGE, 18)
	
	# 伤害数字
	_spawn_damage_number(amount)
	
	# 受击动画
	if anim.sprite_frames and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")
	
	await get_tree().create_timer(0.06).timeout
	modulate = Color.WHITE
	anim.modulate = Color.WHITE
	
	if hp <= 0:
		die()


func _spawn_impact(clr: Color, radius: float):
	var burst := preload("res://scenes/fx/impact_burst.tscn").instantiate()
	burst.setup(position, clr, radius)
	get_parent().add_child(burst)


func _spawn_damage_number(amount: int):
	var label := preload("res://scenes/fx/damage_number.tscn").instantiate()
	label.setup(amount, position + Vector2(randf_range(-10, 10), -20), Color.WHITE)
	get_parent().add_child(label)


func die():
	if _dying:
		return
	_dying = true
	collision_layer = 0  # 立即关闭碰撞
	remove_from_group("enemy")  # 立刻从敌人组移除，防止自动瞄准锁定尸体
	
	# === 击杀反馈 ===
	# 大冲击波
	_spawn_impact(Color.ORANGE_RED, 36)
	
	# 伤害数字（大号）
	var label := preload("res://scenes/fx/damage_number.tscn").instantiate()
	label.setup(score_value, position, Color.GOLD)
	get_parent().add_child(label)
	
	# 震屏
	_trigger_shake(0.5 if is_elite else 0.2)
	
	# 立即隐藏所有UI
	hp_bar.visible = false
	shield_indicator.visible = false
	warning_area.visible = false
	
	if enemy_type == Type.WORM:
		# 死亡分裂弹幕
		for i in range(3):
			var angle := randf() * TAU
			_shoot_bullet(Vector2.RIGHT.rotated(angle), 180, Color.ORANGE)
	
	_spawn_explosion()
	enemy_died.emit(score_value)
	
	if GameManager:
		GameManager.add_kill()
		GameManager.add_score(score_value)
	
	# 击杀回复
	if player_ref and player_ref.has_meta("kill_heal_active"):
		var count: int = player_ref.get_meta("kill_heal_count", 0) + 1
		if count >= 10:
			var heal_amount: int = player_ref.get_meta("kill_heal_amount", 1)
			player_ref.hp = min(player_ref.hp + heal_amount, player_ref.MAX_HP)
			count = 0
		player_ref.set_meta("kill_heal_count", count)
	
	if anim.sprite_frames and anim.sprite_frames.has_animation("death"):
		anim.play("death")
		collision_layer = 0
		await get_tree().create_timer(0.3).timeout
	
	queue_free()


func _spawn_explosion():
	var exp := preload("res://Misc/ExplosionEffect2D/explosion_2d_scene.tscn").instantiate()
	exp.position = position
	get_parent().add_child(exp)
	if is_elite:
		exp.play_explosion()
	else:
		exp.play_small_explosion()


func _update_hp_bar():
	hp_bar.visible = hp < max_hp
	hp_fill.size.x = 30.0 * hp / max_hp


func _anim_from_velocity():
	if velocity.length() > 10:
		if anim.sprite_frames and anim.sprite_frames.has_animation("run"):
			if anim.animation != "run":
				anim.play("run")
	else:
		if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
			if anim.animation != "idle":
				anim.play("idle")


func _trigger_shake(intensity: float):
	var parent := get_parent()
	if parent and parent.has_method("add_shake"):
		parent.add_shake(intensity)
