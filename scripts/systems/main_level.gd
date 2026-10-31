extends Node2D
## 关卡主脚本 - 整合所有系统

var player: CharacterBody2D
var game_active := false

# 震屏
var _shake_intensity := 0.0
var _shake_decay := 8.0
var _shake_noise := FastNoiseLite.new()
var _shake_time := 0.0

@onready var player_scene := preload("res://scenes/player/echo.tscn")
var damage_number_scene := preload("res://scenes/fx/damage_number.tscn")
var impact_scene := preload("res://scenes/fx/impact_burst.tscn")

# UI引用
@onready var hp_fill := $GameCanvas/HPBar/HPFill
@onready var hp_label := $GameCanvas/HPLabel
@onready var score_label := $GameCanvas/ScoreLabel
@onready var wave_label := $GameCanvas/WaveLabel
@onready var dodge_cd := $GameCanvas/DodgeCooldown
@onready var skill_cd := $GameCanvas/SkillCooldown
@onready var boss_hp_bar := $GameCanvas/BossHPBar
@onready var boss_hp_fill := $GameCanvas/BossHPBar/BossHPFill
@onready var boss_name := $GameCanvas/BossName
@onready var result_panel := $GameCanvas/ResultPanel
@onready var result_label := $GameCanvas/ResultPanel/ResultLabel
@onready var retry_btn := $GameCanvas/ResultPanel/RetryButton


func _ready():
	randomize()
	_shake_noise.seed = randi()
	_shake_noise.frequency = 0.08
	
	# 连接LevelManager信号
	var lm = $LevelManager
	if lm.has_signal("upgrade_ready"):
		lm.connect("upgrade_ready", _on_upgrade_ready)
	if lm.has_signal("boss_spawned"):
		lm.connect("boss_spawned", _on_boss_spawned)
	if lm.has_signal("level_completed"):
		lm.connect("level_completed", _on_level_complete)
	
	result_panel.visible = false
	retry_btn.pressed.connect(_on_retry)
	
	_start_game()


func add_shake(intensity: float) -> void:
	_shake_intensity = max(_shake_intensity, intensity)


func _start_game():
	player = player_scene.instantiate()
	player.position = get_viewport().get_visible_rect().size / 2
	player.player_died.connect(_on_player_died)
	player.player_dodged.connect(_on_player_dodged)
	add_child(player)
	
	$LevelManager.call("start_level", player)
	game_active = true
	
	if GameManager:
		GameManager.set_state(GameManager.GameState.PLAYING)
		GameManager.reset_run()


func _process(delta: float):
	# 震屏
	if _shake_intensity > 0.01:
		_shake_time += delta * 30
		_shake_intensity = lerp(_shake_intensity, 0.0, _shake_decay * delta)
		var ox := _shake_noise.get_noise_1d(_shake_time) * _shake_intensity * 8
		var oy := _shake_noise.get_noise_1d(_shake_time + 100) * _shake_intensity * 6
		position = Vector2(ox, oy)
	else:
		_shake_intensity = 0.0
		position = Vector2.ZERO
	
	if not game_active or not is_instance_valid(player):
		return
	
	hp_fill.size.x = 200.0 * player.hp / player.MAX_HP
	hp_label.text = "%d / %d" % [player.hp, player.MAX_HP]
	
	if GameManager:
		score_label.text = "分数: %d" % GameManager.score
	wave_label.text = "波次: %d" % $LevelManager.current_wave
	
	var dodge_ratio: float = 1.0 - (player.dodge_cooldown_timer / player.DODGE_COOLDOWN)
	dodge_cd.size.x = 40.0 * dodge_ratio
	
	var skill_ratio: float = 1.0 - (player.skill_timer / player.skill_cooldown)
	skill_cd.size.x = 40.0 * skill_ratio
	
	# Boss血条
	if boss_hp_bar.visible:
		var boss := get_first_boss()
		if boss:
			boss_hp_fill.size.x = 300.0 * boss.hp / boss.max_hp


func _on_upgrade_ready(_choices: Array):
	pass


func _on_boss_spawned():
	boss_hp_bar.visible = true
	boss_name.visible = true
	var vpr: Rect2 = get_viewport().get_visible_rect()
	boss_hp_bar.offset_left = vpr.size.x / 2 - 150
	boss_hp_bar.offset_top = 5
	boss_name.offset_left = vpr.size.x / 2 - 100
	boss_name.offset_top = 15


func _on_level_complete():
	game_active = false
	result_label.text = "🎉 关卡完成！\n\n分数: %d\n击杀: %d\n闪避: %d" % [
		GameManager.score if GameManager else 0,
		GameManager.kills if GameManager else 0,
		GameManager.dodge_count if GameManager else 0,
	]
	result_panel.visible = true


func _on_player_died():
	game_active = false
	result_label.text = "💀 已阵亡\n\n分数: %d\n波次: %d" % [
		GameManager.score if GameManager else 0,
		$LevelManager.current_wave,
	]
	result_panel.visible = true


func _on_player_dodged():
	pass


func _on_retry():
	get_tree().reload_current_scene()


func get_first_boss() -> Node:
	for node in get_children():
		if node.is_in_group("boss"):
			return node
	return null
