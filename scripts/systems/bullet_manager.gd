extends Node
## 弹幕管理器 - 内联对象池

const MAX_PLAYER_BULLETS := 120
const MAX_ENEMY_BULLETS := 600

var _player_pool := []
var _player_active := []
var _enemy_pool := []
var _enemy_active := []
var _bullet_scene: PackedScene


func _ready():
	_bullet_scene = preload("res://scenes/bullets/bullet.tscn")
	# 预创建池
	for _i in range(60):
		var b := _create_bullet_node()
		_deactivate(b)
		_player_pool.append(b)
	for _i in range(200):
		var b := _create_bullet_node()
		_deactivate(b)
		_enemy_pool.append(b)


func _create_bullet_node() -> Node:
	var b := _bullet_scene.instantiate()
	b.process_mode = Node.PROCESS_MODE_DISABLED
	b.visible = false
	add_child(b)
	return b


func _acquire(is_player: bool) -> Area2D:
	var pool := _player_pool if is_player else _enemy_pool
	var active := _player_active if is_player else _enemy_active
	var max_size := MAX_PLAYER_BULLETS if is_player else MAX_ENEMY_BULLETS
	
	var node: Node
	if pool.is_empty():
		if active.size() >= max_size:
			node = active.pop_front()
			_deactivate(node)
		else:
			node = _create_bullet_node()
	else:
		node = pool.pop_back()
	
	_activate(node)
	active.append(node)
	return node as Area2D


func _activate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.visible = true


func _deactivate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.visible = false
	if node is Node2D:
		node.position = Vector2(-10000, -10000)


func spawn_bullet(is_player: bool, pos: Vector2, dir: Vector2, spd: float, dmg: int, clr: Color, sc: Vector2 = Vector2(1,1)):
	var bullet := _acquire(is_player)
	bullet.position = pos
	bullet.rotation = dir.angle()
	bullet.setup(dir, spd, dmg, is_player, clr, sc)
	return bullet


func return_bullet(bullet) -> void:
	if bullet.is_player_bullet:
		_player_active.erase(bullet)
		_deactivate(bullet)
		if _player_pool.size() < MAX_PLAYER_BULLETS:
			_player_pool.append(bullet)
	else:
		_enemy_active.erase(bullet)
		_deactivate(bullet)
		if _enemy_pool.size() < MAX_ENEMY_BULLETS:
			_enemy_pool.append(bullet)
