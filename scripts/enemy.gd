extends CharacterBody2D

signal enemy_died(score_value: int)

enum Type { CHASER, SPRAYER, BURSTER, SNIPER }

const HIT_SFX := "res://ImportedAssets/SimpleTopDownShooterTemplate2D/assets/sound_effects/hitHurt.wav"
const SPRITE_MAP := {
	Type.CHASER: "res://spriteframes/units/neutral_shadow1.tres",
	Type.SPRAYER: "res://spriteframes/units/neutral_tribalranged1.tres",
	Type.BURSTER: "res://spriteframes/units/boss_antiswarm.tres",
	Type.SNIPER: "res://spriteframes/units/neutral_voidhunter.tres",
}

var enemy_type := Type.CHASER
var hp := 3
var max_hp := 3
var move_speed := 120.0
var score_value := 100
var shoot_interval := 1.5
var player_ref: Node2D
var bullet_scene: PackedScene
var explosion_scene: PackedScene
var screen_size: Vector2
var knockback_velocity := Vector2.ZERO

var _shoot_timer := 0.0
var _burst_count := 0
var _behavior_timer := 0.0
var _setup_done := false
var _pending_type: int = -1
var _pending_difficulty := 1.0
var _pending_player: Node2D
var _dying := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_fill: ColorRect = $HPBar/HPFill
@onready var damage_number_scene := preload("res://scenes/fx/damage_number.tscn")
@onready var impact_scene := preload("res://scenes/fx/impact_burst.tscn")


func _ready() -> void:
	bullet_scene = preload("res://scenes/bullet.tscn")
	explosion_scene = load("res://Misc/ExplosionEffect2D/explosion_2d_scene.tscn")
	screen_size = get_viewport_rect().size
	add_to_group("enemy")
	_shoot_timer = randf() * shoot_interval

	if _pending_type >= 0:
		_apply_setup()


func can_be_targeted() -> bool:
	return not _dying and hp > 0


func setup(type: Type, difficulty: float, player: Node2D) -> void:
	_pending_type = type
	_pending_difficulty = difficulty
	_pending_player = player

	if is_node_ready():
		_apply_setup()


func _apply_setup() -> void:
	if _setup_done:
		return
	_setup_done = true

	enemy_type = _pending_type as Type
	player_ref = _pending_player

	var sprite_path: String = SPRITE_MAP.get(enemy_type, "")
	if sprite_path != "":
		var sf = load(sprite_path)
		if sf:
			anim.sprite_frames = sf
			anim.play("idle")

	match enemy_type:
		Type.CHASER:
			hp = ceil(2 * _pending_difficulty)
			move_speed = 100.0 + _pending_difficulty * 30.0
			shoot_interval = max(0.4, 1.5 - _pending_difficulty * 0.15)
			score_value = 100
			anim.scale = Vector2(0.7, 0.7)
		Type.SPRAYER:
			hp = ceil(3 * _pending_difficulty)
			move_speed = 60.0 + _pending_difficulty * 15.0
			shoot_interval = max(0.6, 2.0 - _pending_difficulty * 0.2)
			score_value = 150
			anim.scale = Vector2(0.65, 0.65)
		Type.BURSTER:
			hp = ceil(4 * _pending_difficulty)
			move_speed = 40.0 + _pending_difficulty * 10.0
			shoot_interval = max(0.8, 3.0 - _pending_difficulty * 0.3)
			score_value = 200
			anim.scale = Vector2(0.9, 0.9)
		Type.SNIPER:
			hp = ceil(1.5 * _pending_difficulty)
			move_speed = 50.0
			shoot_interval = max(1.0, 3.5 - _pending_difficulty * 0.3)
			score_value = 250
			anim.scale = Vector2(0.6, 0.6)

	max_hp = hp
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	if _dying or not is_instance_valid(player_ref):
		return

	_shoot_timer -= delta
	_behavior_timer += delta

	var move_dir := Vector2.ZERO
	match enemy_type:
		Type.CHASER:
			move_dir = _chase_behavior()
		Type.SPRAYER:
			move_dir = _sprayer_behavior()
		Type.BURSTER:
			move_dir = _burster_behavior()
		Type.SNIPER:
			move_dir = _sniper_behavior()

	velocity = move_dir * move_speed + knockback_velocity
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()

	if move_dir.length() > 0.1:
		anim.flip_h = move_dir.x < 0.0

	if move_dir.length() > 0.2:
		_play_anim("run")
	else:
		_play_anim("idle")

	hp_bar.position = Vector2(-15, -30)


func _chase_behavior() -> Vector2:
	var dir := (player_ref.position - position).normalized()
	if _shoot_timer <= 0.0:
		_shoot_aimed(3, 0.15)
		_shoot_timer = shoot_interval
		_play_anim("attack")
	return dir


func _sprayer_behavior() -> Vector2:
	var to_player := player_ref.position - position
	var dist := to_player.length()
	var ideal_dist := 200.0

	var move_dir: Vector2
	if dist < ideal_dist - 30.0:
		move_dir = -to_player.normalized()
	elif dist > ideal_dist + 30.0:
		move_dir = to_player.normalized()
	else:
		move_dir = to_player.normalized().rotated(PI / 2.0 * sign(sin(_behavior_timer * 0.7)))

	if _shoot_timer <= 0.0:
		_shoot_spread(5, 0.4)
		_shoot_timer = shoot_interval
		_play_anim("attack")
	return move_dir


func _burster_behavior() -> Vector2:
	var dir := (player_ref.position - position).normalized()
	if _shoot_timer <= 0.0:
		_burst_count += 1
		_shoot_circular(12 + _burst_count * 2)
		_shoot_timer = shoot_interval
		_play_anim("attack")
		if _burst_count >= 4:
			_burst_count = 0
			_shoot_timer = shoot_interval * 2.0
	return dir * 0.5


func _sniper_behavior() -> Vector2:
	var to_player := player_ref.position - position
	if _shoot_timer <= 0.0:
		var b := _create_bullet()
		b.position = position
		b.direction = to_player.normalized()
		b.speed = 350.0
		b.damage = 2
		b.color = Color.MAGENTA
		b.scale = Vector2(1.5, 1.5)
		get_parent().add_child(b)
		for angle in [-0.12, 0.12]:
			var b2 := _create_bullet()
			b2.position = position
			b2.direction = to_player.normalized().rotated(angle)
			b2.speed = 300.0
			b2.damage = 1
			b2.color = Color.HOT_PINK
			get_parent().add_child(b2)
		_shoot_timer = shoot_interval
		_play_anim("attack")
	return to_player.normalized()


func _create_bullet() -> Area2D:
	var b: Area2D = bullet_scene.instantiate()
	b.is_player_bullet = false
	b.speed = 200.0
	b.damage = 1
	b.color = Color.ORANGE_RED
	return b


func _shoot_aimed(count: int, spread: float) -> void:
	var base_dir := (player_ref.position - position).normalized()
	for i in range(count):
		var b := _create_bullet()
		b.position = position
		b.direction = base_dir.rotated((i - (count - 1) / 2.0) * spread)
		get_parent().add_child(b)


func _shoot_spread(count: int, spread: float) -> void:
	var base_dir := (player_ref.position - position).normalized()
	var start_angle := -spread * (count - 1) / 2.0
	for i in range(count):
		var b := _create_bullet()
		b.position = position
		b.direction = base_dir.rotated(start_angle + i * spread / max(count - 1, 1) * 2.0)
		b.speed = 180.0
		get_parent().add_child(b)


func _shoot_circular(count: int) -> void:
	var angle_step := TAU / count
	for i in range(count):
		var b := _create_bullet()
		b.position = position
		b.direction = Vector2.RIGHT.rotated(i * angle_step)
		b.speed = 160.0
		b.color = Color.DARK_ORANGE
		get_parent().add_child(b)


func take_damage(amount: int, hit_direction := Vector2.ZERO) -> void:
	if _dying:
		return

	hp -= amount
	_update_hp_bar()
	_show_damage_number(amount)
	_show_impact()

	if hit_direction != Vector2.ZERO:
		knockback_velocity += hit_direction.normalized() * 160.0

	if AudioManager:
		AudioManager.play_sfx(HIT_SFX, 0.08, -11.0)

	var parent := get_parent()
	if parent and parent.has_method("shake"):
		parent.shake(3.5)

	_play_anim("hit")
	modulate = Color(1.8, 1.8, 1.8)
	await get_tree().create_timer(0.06).timeout
	if not _dying:
		modulate = Color.WHITE

	if hp <= 0:
		die()


func die() -> void:
	if _dying:
		return
	_dying = true
	enemy_died.emit(score_value)
	_play_anim("death")

	var exp := explosion_scene.instantiate()
	exp.position = position
	get_parent().add_child(exp)
	exp.play_small_explosion()

	var burst := impact_scene.instantiate()
	get_parent().add_child(burst)
	burst.setup(global_position, Color(1.0, 0.45, 0.1), 34.0)

	await get_tree().create_timer(0.2).timeout
	queue_free()


func _show_damage_number(amount: int) -> void:
	var label := damage_number_scene.instantiate()
	get_parent().add_child(label)
	label.setup(amount, global_position + Vector2(-20, -38), Color(1.0, 0.9, 0.35))


func _show_impact() -> void:
	var burst := impact_scene.instantiate()
	get_parent().add_child(burst)
	burst.setup(global_position, Color(1.0, 0.8, 0.25), 20.0)


func _update_hp_bar() -> void:
	hp_bar.visible = hp < max_hp
	hp_fill.size.x = 30.0 * max(float(hp), 0.0) / max(float(max_hp), 1.0)


func _play_anim(anim_name: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		if anim.animation != anim_name:
			anim.play(anim_name)
