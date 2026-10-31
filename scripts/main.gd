extends Node2D

const ARENA_BACKGROUND_SCRIPT := preload("res://scripts/fx/arena_background.gd")

var score := 0
var wave := 0
var enemies_alive := 0
var game_running := true
var difficulty := 1.0

var enemy_scene: PackedScene
var player_scene: PackedScene
var explosion_scene: PackedScene
var player: CharacterBody2D
var screen_size: Vector2

var _wave_timer := 0.0
var _wave_cooldown := 2.0
var _spawn_timer := 0.0
var _spawn_interval := 0.6
var _enemies_to_spawn := 0
var _shake_strength := 0.0
var _shake_noise := FastNoiseLite.new()
var _shake_time := 0.0
var _camera: Camera2D

@onready var score_label := $CanvasLayer/ScoreLabel
@onready var wave_label := $CanvasLayer/WaveLabel
@onready var hp_label := $CanvasLayer/HPLabel
@onready var game_over_panel := $CanvasLayer/GameOver
@onready var game_over_label := $CanvasLayer/GameOver/Label
@onready var restart_button := $CanvasLayer/GameOver/RestartButton


func _ready() -> void:
	randomize()
	screen_size = get_viewport_rect().size

	enemy_scene = preload("res://scenes/enemy.tscn")
	player_scene = preload("res://scenes/player.tscn")
	explosion_scene = load("res://Misc/ExplosionEffect2D/explosion_2d_scene.tscn")

	_setup_background()
	_setup_camera()
	spawn_player()
	start_next_wave()

	restart_button.pressed.connect(_on_restart)
	game_over_panel.visible = false


func _setup_background() -> void:
	var bg := $Background as ColorRect
	bg.color = Color(0.035, 0.036, 0.043, 1.0)

	var arena := Node2D.new()
	arena.name = "ArenaBackground"
	arena.set_script(ARENA_BACKGROUND_SCRIPT)
	add_child(arena)
	move_child(arena, 1)


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "GameCamera"
	_camera.position = screen_size / 2.0
	_camera.enabled = true
	add_child(_camera)

	_shake_noise.seed = randi()
	_shake_noise.frequency = 0.18


func spawn_player() -> void:
	player = player_scene.instantiate()
	player.position = screen_size / 2.0
	player.player_died.connect(_on_player_died)
	add_child(player)


func _process(delta: float) -> void:
	_update_camera_shake(delta)

	if not game_running:
		return

	score_label.text = "分数: %d" % score
	wave_label.text = "波次: %d" % wave

	if is_instance_valid(player):
		hp_label.text = "HP: %d / %d" % [player.hp, player.MAX_HP]

	_wave_timer += delta

	if enemies_alive <= 0 and _enemies_to_spawn <= 0 and _wave_timer > 1.0:
		if _wave_timer > _wave_cooldown:
			start_next_wave()
		else:
			wave_label.text = "波次 %d 完成! 下一波..." % wave

	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _enemies_to_spawn > 0:
		spawn_enemy()
		_spawn_timer = _spawn_interval
		_enemies_to_spawn -= 1


func _update_camera_shake(delta: float) -> void:
	if _camera == null:
		return

	_shake_time += delta * 24.0
	_shake_strength = move_toward(_shake_strength, 0.0, 32.0 * delta)

	if _shake_strength <= 0.01:
		_camera.offset = Vector2.ZERO
		return

	_camera.offset = Vector2(
		_shake_noise.get_noise_2d(_shake_time, 11.0),
		_shake_noise.get_noise_2d(29.0, _shake_time)
	) * _shake_strength


func shake(amount := 8.0) -> void:
	_shake_strength = max(_shake_strength, amount)


func start_next_wave() -> void:
	wave += 1
	difficulty = 1.0 + wave * 0.25
	_enemies_to_spawn = 4 + wave * 2
	_spawn_interval = max(0.3, 0.8 - wave * 0.04)
	_spawn_timer = 0.3
	_wave_timer = 0.0
	wave_label.text = "波次: %d - 开始!" % wave
	shake(5.0)


func spawn_enemy() -> void:
	var e: CharacterBody2D = enemy_scene.instantiate()

	var edge := randi() % 4
	match edge:
		0:
			e.position = Vector2(randf() * screen_size.x, -30.0)
		1:
			e.position = Vector2(randf() * screen_size.x, screen_size.y + 30.0)
		2:
			e.position = Vector2(-30.0, randf() * screen_size.y)
		3:
			e.position = Vector2(screen_size.x + 30.0, randf() * screen_size.y)

	var type := _pick_enemy_type()
	e.setup(type, difficulty, player)
	e.enemy_died.connect(_on_enemy_died)
	add_child(e)
	enemies_alive += 1


func _pick_enemy_type() -> int:
	var weights := []
	weights.append_array([0])

	if wave >= 2:
		for _i in range(3):
			weights.append(1)
	if wave >= 3:
		for _i in range(2):
			weights.append(2)
	if wave >= 5:
		weights.append(3)

	return weights[randi() % weights.size()]


func _on_enemy_died(value: int) -> void:
	score += value
	enemies_alive -= 1
	shake(7.0)


func _on_player_died() -> void:
	game_running = false
	game_over_label.text = "游戏结束!\n最终分数: %d\n存活到波次: %d" % [score, wave]
	game_over_panel.visible = true
	shake(16.0)


func _on_restart() -> void:
	get_tree().reload_current_scene()
