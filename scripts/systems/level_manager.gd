extends Node
## 关卡管理器 - 波次生成、升级选择、Boss触发

signal wave_completed(wave_num: int)
signal upgrade_ready(choices: Array)
signal boss_spawned
signal level_completed

# 关卡配置
var current_wave := 0
var enemies_alive := 0
var enemies_to_spawn := 0
var wave_active := false
var boss_spawned_flag := false
var difficulty := 1.0
var player: CharacterBody2D

# 波次配置: [敌人类型数组, 数量, 精英数]
var _wave_configs := []
var _current_wave_config_idx := 0
var _wave_elapsed := 0.0
const WAVE_TIMEOUT := 90.0  # 90秒超时自动清理

# 升级池
const UPGRADE_POOL := [
	{"name": "伤害提升", "desc": "子弹伤害+1", "rarity": 0, "icon": "🔺"},
	{"name": "射速提升", "desc": "射击间隔-15%", "rarity": 0, "icon": "⚡"},
	{"name": "移速提升", "desc": "移动速度+10%", "rarity": 0, "icon": "💨"},
	{"name": "生命上限", "desc": "最大生命+1，回复1HP", "rarity": 0, "icon": "❤️"},
	{"name": "子弹穿透", "desc": "子弹穿透+1个敌人", "rarity": 1, "icon": "🔷"},
	{"name": "闪避冷却", "desc": "闪避冷却-15%", "rarity": 1, "icon": "🌀"},
	{"name": "暴击强化", "desc": "暴击率+10%", "rarity": 1, "icon": "💎"},
	{"name": "击杀回复", "desc": "每杀10个回复1HP", "rarity": 1, "icon": "💚"},
	{"name": "副武器冷却", "desc": "副武器冷却-25%", "rarity": 2, "icon": "🟣"},
	{"name": "散射子弹", "desc": "射击时额外发射2发", "rarity": 2, "icon": "✨"},
	{"name": "时间延长", "desc": "技能持续时间+50%", "rarity": 2, "icon": "⏱️"},
	{"name": "弹幕清除", "desc": "每30秒清除附近弹幕", "rarity": 3, "icon": "🌟"},
]

var _used_upgrades: Array[Dictionary] = []
var screen_size: Vector2

@onready var enemy_scene := preload("res://scenes/enemies/enemy.tscn")
@onready var boss_scene := preload("res://scenes/bosses/boss_core.tscn")
@onready var spawn_timer := $SpawnTimer
@onready var upgrade_panel := $CanvasLayer/UpgradePanel


func _ready():
	screen_size = get_viewport().get_visible_rect().size
	upgrade_panel.visible = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)


func _process(delta: float):
	if not wave_active:
		return
	_wave_elapsed += delta
	
	# 超时保护：强制清理所有敌人
	if _wave_elapsed > WAVE_TIMEOUT:
		_force_clear_wave()


func start_level(p: CharacterBody2D):
	player = p
	difficulty = 1.0
	current_wave = 0
	boss_spawned_flag = false
	
	# 配置波次（按设计文档第1关）
	_setup_wave_configs()
	_start_next_wave()


func _setup_wave_configs():
	_wave_configs = [
		{"types": [0], "count": 3, "elite": 0},          # 波1: 教学 3眼球
		{"types": [0, 2], "count": 5, "elite": 0},       # 波2: 眼球+无人机
		{"types": [0, 2, 3], "count": 6, "elite": 0},    # 波3: +爆裂球
		{"types": [1, 2, 3], "count": 7, "elite": 0},    # 波4: +裂虫
		{"types": [0, 2, 4], "count": 8, "elite": 1},    # 波5: +护盾兵+精英
		{"types": [0, 1, 2, 3, 4], "count": 10, "elite": 1},  # 波6: 全种类
		{"types": [1, 3, 4], "count": 8, "elite": 2},    # 波7: 虫+爆裂+护盾+双精英
		{"types": [0, 1, 2, 3, 4], "count": 12, "elite": 2},  # 波8: 全种类强化
	]
	difficulty = 1.0


func _start_next_wave():
	if boss_spawned_flag:
		return
	
	current_wave += 1
	wave_active = true
	_wave_elapsed = 0.0
	
	if current_wave > _wave_configs.size():
		_spawn_boss()
		return
	
	var config: Dictionary = _wave_configs[current_wave - 1]
	enemies_to_spawn = config["count"]
	enemies_alive = 0
	difficulty = 1.0 + current_wave * 0.3
	
	spawn_timer.wait_time = max(0.4, 1.2 - current_wave * 0.1)
	spawn_timer.start()
	
	print("Wave %d: %d enemies" % [current_wave, enemies_to_spawn])


func _on_spawn_timer_timeout():
	if not wave_active or enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	
	var config: Dictionary = _wave_configs[current_wave - 1]
	var type_pool: Array = config["types"]
	var enemy_type: int = type_pool[randi() % type_pool.size()]
	
	var e := enemy_scene.instantiate() as CharacterBody2D
	# 随机边缘出生
	var edge := randi() % 4
	match edge:
		0: e.position = Vector2(randf() * screen_size.x, -30)
		1: e.position = Vector2(randf() * screen_size.x, screen_size.y + 30)
		2: e.position = Vector2(-30, randf() * screen_size.y)
		3: e.position = Vector2(screen_size.x + 30, randf() * screen_size.y)
	
	e.setup(enemy_type, difficulty, player)
	e.enemy_died.connect(_on_enemy_died)
	
	# 精英判定
	if config["elite"] > 0 and randi() % 3 == 0:
		e.setup(5, difficulty * 1.3, player)  # Type.TURRET
		config["elite"] -= 1
	
	add_child(e)
	enemies_to_spawn -= 1
	enemies_alive += 1


func _on_enemy_died(_score: int):
	enemies_alive -= 1
	
	if enemies_alive <= 0 and enemies_to_spawn <= 0:
		wave_active = false
		spawn_timer.stop()
		
		if current_wave >= _wave_configs.size():
			_spawn_boss()
		else:
			_show_upgrade_choice()


func _show_upgrade_choice():
	var choices: Array[Dictionary] = []
	var pool := UPGRADE_POOL.duplicate()
	pool.shuffle()
	
	# 选3个不重复的
	for u in pool:
		if choices.size() >= 3:
			break
		if not u in _used_upgrades:
			choices.append(u)
	
	# fallback：不够3个时用已选过的
	if choices.size() < 3:
		for u in pool:
			if choices.size() >= 3:
				break
			if not u in choices:
				choices.append(u)
	
	# 暂停游戏
	get_tree().paused = true
	upgrade_ready.emit(choices)
	_show_upgrade_panel(choices)


func _show_upgrade_panel(choices: Array):
	# 确保暂停时UI可交互
	upgrade_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	upgrade_panel.visible = true
	
	for i in range(3):
		var btn: Button = upgrade_panel.get_node("Choice%d" % (i+1))
		var label: Label = upgrade_panel.get_node("Choice%d/Label" % (i+1))
		
		if i < choices.size():
			btn.visible = true
			btn.process_mode = Node.PROCESS_MODE_ALWAYS
			label.text = "%s %s\n%s" % [choices[i]["icon"], choices[i]["name"], choices[i]["desc"]]
			# 断开上次的信号（用标志位避免重复绑定）
			if btn.has_meta("upgrade_connected"):
				btn.pressed.disconnect(btn.get_meta("upgrade_connected"))
			var captured := i
			var cb := func(): _select_upgrade(choices[captured])
			btn.pressed.connect(cb)
			btn.set_meta("upgrade_connected", cb)
		else:
			btn.visible = false


func _select_upgrade(choice: Dictionary):
	_used_upgrades.append(choice)
	_apply_upgrade(choice)
	upgrade_panel.visible = false
	get_tree().paused = false
	_start_next_wave()


func _apply_upgrade(upgrade: Dictionary):
	match upgrade["name"]:
		"伤害提升":
			player.BULLET_DAMAGE += 1
		"射速提升":
			player.SHOOT_RATE *= 0.85
		"移速提升":
			player.MOVE_SPEED *= 1.10
		"生命上限":
			player.MAX_HP += 1
			player.hp = min(player.hp + 1, player.MAX_HP)
		"子弹穿透":
			player.BULLET_PENETRATION += 1
		"闪避冷却":
			player.DODGE_COOLDOWN *= 0.85
		"暴击强化":
			player.CRIT_CHANCE += 0.10
		"击杀回复":
			# 每10击杀回1HP（可叠加回复量）
			var heal_amount: int = player.get_meta("kill_heal_amount", 1) + 1
			player.set_meta("kill_heal_amount", heal_amount)
			player.set_meta("kill_heal_active", true)
		"副武器冷却":
			player.subweapon_cooldown *= 0.75
		"散射子弹":
			player.EXTRA_BULLETS += 2
		"时间延长":
			player.skill_duration *= 1.5
		"弹幕清除":
			player.set_meta("bullet_clear_active", true)
			player.set_meta("bullet_clear_timer", 0.0)


func _spawn_boss():
	boss_spawned_flag = true
	wave_active = false
	spawn_timer.stop()
	
	var boss := boss_scene.instantiate()
	boss.position = Vector2(screen_size.x / 2, 120)
	boss.setup(player)
	boss.boss_died.connect(_on_boss_died)
	add_child(boss)
	boss_spawned.emit()


func _on_boss_died():
	level_completed.emit()


func _force_clear_wave():
	print("WAVE TIMEOUT: Force clearing wave %d, alive=%d" % [current_wave, enemies_alive])
	for child in get_children():
		if child.is_in_group("enemy") and child.has_method("die"):
			if not child.get("_dying"):
				child.die()
	wave_active = false
	spawn_timer.stop()
	enemies_alive = 0
	enemies_to_spawn = 0
	_show_upgrade_choice()
