extends SceneTree

const EXPECTED_HALL := "res://assets/reference/observatory_room_hall_1024.png"
const EXPECTED_TERMINAL := "res://assets/reference/observatory_furniture/remote_instrument_desk_official.png"

var failures := 0
var room: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	if gm == null:
		_fail("GameManager is available")
		_finish()
		return
	gm.new_game()
	gm.debug_jump_to_level(66, true)
	room = (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	await process_frame

	_check_assets()
	_check_collision_and_depth()
	await _check_remote_entry()
	_finish()


func _check_assets() -> void:
	var background := room.get_node_or_null("ObservatoryHallBackground") as TextureRect
	_check(background != null and background.texture != null, "replacement hall background is rendered")
	if background != null and background.texture != null:
		_check(background.texture.resource_path == EXPECTED_HALL, "hall uses the lower-right terminal hall background")

	var official_terminal := room.get_node_or_null("OfficialRemoteInstrumentDesk") as Sprite2D
	_check(official_terminal != null and official_terminal.texture != null, "official terminal has a permanent room-layer sprite")
	if official_terminal != null and official_terminal.texture != null:
		_check(official_terminal.texture.resource_path == EXPECTED_TERMINAL, "room renders the user-supplied official terminal PNG")
		_check(is_equal_approx(official_terminal.scale.x, official_terminal.scale.y), "official terminal preserves its original aspect ratio")
		_check(official_terminal.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "official terminal uses pixel-nearest sampling")

	var computer_data := _occluder_data("computer")
	var occluder := computer_data.get("node") as Node2D
	_check(occluder != null, "computer has a dedicated depth occluder")
	if occluder == null:
		return
	_check(occluder.get_child_count() == 1, "computer occluder contains no rectangular floor patch")
	var foreground := occluder.get_child(0) as Sprite2D
	_check(foreground != null and foreground.texture != null, "computer uses an alpha-cut foreground sprite")
	if foreground == null or foreground.texture == null:
		return
	_check(foreground.texture.resource_path == EXPECTED_TERMINAL, "foreground reuses the official terminal RGBA asset")
	var image := foreground.texture.get_image()
	_check(
		image.get_pixel(0, 0).a < 0.01
			and image.get_pixel(image.get_width() - 1, 0).a < 0.01,
		"transparent outer corners never become a black floor patch"
	)
	_check(
		image.get_pixel(image.get_width() / 2, image.get_height() / 2).a > 0.5,
		"terminal monitor and desk retain real foreground pixels"
	)
	_check(not _contains_annotation_red(image), "runtime terminal image contains no red reference-box pixels")


func _check_collision_and_depth() -> void:
	var obstacles: Array = room.get("obstacles")
	_check(_blocked(obstacles, Vector2(820, 625)), "official desk blocks the marked lower-right footprint")
	_check(_blocked(obstacles, Vector2(780, 630)), "left terminal cabinet has foot collision")
	_check(_blocked(obstacles, Vector2(910, 620)), "right terminal cabinet has foot collision")
	_check(not _blocked(obstacles, Vector2(750, 610)), "left approach remains reachable")

	var computer_data := _occluder_data("computer")
	var occluder := computer_data.get("node") as CanvasItem
	room.call("_set_player_position", Vector2(850, 575))
	_check(occluder != null and occluder.visible, "player behind the desk is covered by the real desk edge")
	room.call("_set_player_position", Vector2(735, 635))
	_check(occluder != null and not occluder.visible, "player in front of the desk stays above the furniture")
	room.call("_set_player_position", Vector2(720, 605))
	_check(occluder != null and not occluder.visible, "walking beside the transparent edge does not flash a rectangle")


func _check_remote_entry() -> void:
	room.call("_set_player_position", Vector2(721, 610))
	room.set("player_facing", "right")
	room.call("_update_nearby")
	_check(str(room.get("nearby_id")) == "computer", "remote desk remains reachable from its left aisle")
	var computer: Dictionary = room.call("_get_interactable", "computer")
	_check(str(computer.get("id", "")) == "computer" and not str(computer.get("name", "")).is_empty(), "desk still owns the Remote Instrument Console")
	room.call("_toggle_remote_instrument_console")
	await process_frame
	var popup := room.get("stats_terminal_popup") as Control
	_check(popup != null or room.get_node_or_null("RemoteInstrumentConsole") != null, "interacting opens the remote facility selector")


func _occluder_data(id: String) -> Dictionary:
	for value in room.get("furniture_occluders"):
		var data: Dictionary = value
		if str(data.get("id", "")) == id:
			return data
	return {}


func _blocked(obstacles: Array, point: Vector2) -> bool:
	for value in obstacles:
		var rect: Rect2 = value
		if rect.has_point(point):
			return true
	return false


func _contains_annotation_red(image: Image) -> bool:
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var pixel := image.get_pixel(x, y)
			if pixel.r > 0.82 and pixel.g < 0.28 and pixel.b < 0.28 and pixel.a > 0.75:
				return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)


func _finish() -> void:
	if failures == 0:
		print("REMOTE DESK LAYERING TEST PASS")
		quit(0)
	else:
		print("REMOTE DESK LAYERING TEST FAIL (%d failures)" % failures)
		quit(1)
