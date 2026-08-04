extends SceneTree

# Graphical acceptance captures for the owner's eight-direction player atlas.
# Run without --headless so the viewport is rendered by the normal 2D backend.

const OUTPUT_DIR := "res://artifacts/player_smooth_animation"
const STATES := [
	["01_down_idle", Vector2(512.0, 610.0), "down", 0],
	["02_down_right_walk", Vector2(420.0, 550.0), "down_right", 2],
	["03_up_left_walk", Vector2(590.0, 550.0), "up_left", 4],
	["04_right_walk", Vector2(512.0, 465.0), "right", 5],
]

var room: Node
var state_index := 0
var settle_frames := 0


func _initialize() -> void:
	await process_frame
	var game_manager := root.get_node_or_null("GameManager")
	if game_manager != null:
		game_manager.call("new_game")
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_output)
	var packed: PackedScene = load("res://scenes/observatory_room.tscn")
	room = packed.instantiate()
	root.add_child(room)
	room.set_process(false)
	process_frame.connect(_capture_tick)


func _capture_tick() -> void:
	if state_index >= STATES.size():
		quit(0)
		return
	settle_frames += 1
	if settle_frames == 2:
		_hide_runtime_overlays()
		var state: Array = STATES[state_index]
		room.call("_set_player_position", state[1])
		room.set("player_facing", str(state[2]))
		room.call("_set_player_animation_frame", str(state[2]), int(state[3]))
	if settle_frames == 6:
		var state: Array = STATES[state_index]
		var path := "%s/%s.png" % [OUTPUT_DIR, str(state[0])]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Could not save smooth player capture: %s" % path)
			quit(1)
			return
		print("saved ", ProjectSettings.globalize_path(path))
		state_index += 1
		settle_frames = 0


func _hide_runtime_overlays() -> void:
	for property_name in [
		"guidance_overlay", "guidance_panel", "unlock_popup", "mission_board_popup",
		"stats_terminal_popup", "mobile_overlay",
	]:
		var overlay: CanvasItem = room.get(property_name) as CanvasItem
		if overlay != null:
			overlay.visible = false
