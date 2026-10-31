extends Node
## 通用对象池 - 避免频繁创建销毁

var _scene: PackedScene
var _pool: Array = []
var _active: Array = []
var _max_size: int = 500

func init(scene: PackedScene, initial_size: int = 50, max_size: int = 500) -> void:
	_scene = scene
	_max_size = max_size
	for _i in range(initial_size):
		_create_one()


func _create_one() -> Node:
	var node := _scene.instantiate()
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.visible = false
	add_child(node)
	_pool.append(node)
	return node


func acquire() -> Node:
	var node: Node
	if _pool.is_empty():
		if _active.size() >= _max_size:
			node = _active.pop_front()
			_deactivate(node)
			_activate(node)
			_active.append(node)
			return node
		node = _create_one()
	else:
		node = _pool.pop_back()
	
	_activate(node)
	_active.append(node)
	return node


func release(node: Node) -> void:
	_active.erase(node)
	_deactivate(node)
	if _pool.size() < _max_size:
		_pool.append(node)


func _activate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_INHERIT
	node.visible = true


func _deactivate(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	node.visible = false
	if node is Node2D:
		node.position = Vector2(-10000, -10000)


func get_active_count() -> int:
	return _active.size()
