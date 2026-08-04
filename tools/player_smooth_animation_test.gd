extends SceneTree

# Validates the owner's eight supplied GIF directions after lossless atlas
# packing and proves the observatory movement code selects every authored row.

const DIRECTION_ROWS := [
	["down", 0],
	["down_right", 1],
	["right", 2],
	["up_right", 3],
	["up", 4],
	["up_left", 5],
	["left", 6],
	["down_left", 7],
]

const VECTOR_DIRECTIONS := [
	[Vector2.DOWN, "down"],
	[Vector2(1.0, 1.0), "down_right"],
	[Vector2.RIGHT, "right"],
	[Vector2(1.0, -1.0), "up_right"],
	[Vector2.UP, "up"],
	[Vector2(-1.0, -1.0), "up_left"],
	[Vector2.LEFT, "left"],
	[Vector2(-1.0, 1.0), "down_left"],
]

var failures := 0
var room: Node
var player: Sprite2D
var atlas: AtlasTexture


func _initialize() -> void:
	await process_frame
	var game_manager := root.get_node_or_null("/root/GameManager")
	if game_manager == null:
		print("FAIL: GameManager missing")
		quit(1)
		return
	game_manager.call("new_game")
	var packed: PackedScene = load("res://scenes/observatory_room.tscn")
	room = packed.instantiate()
	root.add_child(room)
	await process_frame
	player = room.get("player") as Sprite2D
	_check(player != null, "observatory creates the player sprite")
	if player == null:
		_finish()
		return
	atlas = player.texture as AtlasTexture
	_check(atlas != null, "player uses an atlas texture")
	if atlas == null:
		_finish()
		return
	_check(atlas.atlas.resource_path.ends_with("player_observer_smooth_8dir.png"), "room uses the supplied smooth atlas")
	_check(atlas.atlas.get_width() == 384 and atlas.atlas.get_height() == 768, "atlas is six frames by eight directions")
	_check(player.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "pixel sampling remains nearest-neighbour")
	_check(is_equal_approx(player.scale.x, player.scale.y), "player keeps uniform aspect ratio")
	_check_directions()
	_check_distance_matched_animation()
	_check_foot_anchor()
	_check_pose_round_trip(game_manager)
	_finish()


func _check_directions() -> void:
	for item_value in DIRECTION_ROWS:
		var item: Array = item_value
		var direction: String = str(item[0])
		var expected_row: int = int(item[1])
		room.call("_set_player_animation_frame", direction, 5)
		var expected := Rect2(320.0, float(expected_row * 96), 64.0, 96.0)
		_check(atlas.region == expected, "%s selects authored atlas row %d" % [direction, expected_row])
	for item_value in VECTOR_DIRECTIONS:
		var item: Array = item_value
		var direction_vector: Vector2 = item[0]
		var expected_direction: String = str(item[1])
		var actual: String = str(room.call("_facing_from_direction", direction_vector.normalized()))
		_check(actual == expected_direction, "%s movement selects %s" % [str(direction_vector), expected_direction])
	# Small stick drift stays cardinal instead of flickering diagonally.
	var drift_direction: String = str(room.call("_facing_from_direction", Vector2(0.08, -1.0).normalized()))
	_check(drift_direction == "up", "small analogue drift stays on the cardinal frame")


func _check_distance_matched_animation() -> void:
	room.set("player_facing", "down_right")
	room.set("player_is_moving", true)
	room.set("player_anim_frame", 1)
	room.set("player_anim_distance", 0.0)
	var observed: Array[int] = []
	for _step in range(5):
		room.call("_update_player_animation", 18.5)
		observed.append(int(room.get("player_anim_frame")))
	_check(observed == [2, 3, 4, 5, 1], "92 px of travel uses all five motion frames and loops cleanly")
	room.set("player_anim_frame", 1)
	room.set("player_anim_distance", 0.0)
	room.call("_update_player_animation", 55.3)
	_check(int(room.get("player_anim_frame")) == 4, "animation catches up after a slow frame instead of visibly stalling")
	room.set("player_anim_frame", 1)
	room.set("player_anim_distance", 0.0)
	room.call("_update_player_animation", 22.0)
	_check(int(room.get("player_anim_frame")) == 2, "one 100 ms movement step at 220 px/s advances exactly one authored frame")
	var constants: Dictionary = room.get_script().get_script_constant_map()
	var cycle_distance: float = float(constants.get("PLAYER_WALK_CYCLE_DISTANCE", 0.0))
	var movement_speed: float = float(constants.get("PLAYER_SPEED", 1.0))
	var cycle_seconds := cycle_distance / movement_speed
	_check(cycle_seconds > 0.40 and cycle_seconds < 0.43, "gait cadence is derived from movement speed (0.418 s per two-footfall cycle)")
	room.set("player_is_moving", false)
	room.call("_update_player_animation", 0.0)
	_check(int(room.get("player_anim_frame")) == 0, "idle returns to the authored rest frame")
	_check(atlas.region.position.x == 0.0, "idle displays frame zero")


func _check_foot_anchor() -> void:
	var foot_position: Vector2 = room.get("player_pos")
	var visual_position: Vector2 = room.call("_player_visual_position")
	var scale_value: float = player.scale.y
	var reconstructed_foot_y := visual_position.y + (89.0 - 48.0) * scale_value
	_check(is_equal_approx(reconstructed_foot_y, foot_position.y), "new artwork remains anchored to the existing foot collision point")


func _check_pose_round_trip(game_manager: Node) -> void:
	game_manager.call("remember_observatory_pose", Vector2(500.0, 600.0), "up_right")
	var pose: Dictionary = game_manager.call("take_observatory_return_pose")
	_check(str(pose.get("facing", "")) == "up_right", "diagonal facing survives a room round trip")


func _finish() -> void:
	if is_instance_valid(room):
		room.queue_free()
	if failures == 0:
		print("PLAYER SMOOTH ANIMATION TEST PASS")
		quit(0)
	else:
		print("PLAYER SMOOTH ANIMATION TEST FAIL (%d failures)" % failures)
		quit(1)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
