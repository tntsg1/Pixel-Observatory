extends SceneTree

# Visual check for player scale/anchoring in the observatory room.
# Run WITHOUT --headless:
# godot --script res://tools/capture_observatory.gd

# spot name -> [player_pos, facing]
const SPOTS: Array = [
	["telescope_pad", Vector2(512, 575), "up"],
	["stats_terminal", Vector2(730, 592), "right"],
	["assembly_table", Vector2(688, 430), "right"],
	["facing_down", Vector2(512, 646), "down"]
]

var frames := 0
var index := 0
var view: Node


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	view = scene.instantiate()
	root.add_child(view)
	process_frame.connect(_tick)


func _tick() -> void:
	frames += 1
	if frames % 15 == 5:
		if index >= SPOTS.size():
			quit()
			return
		var spot: Array = SPOTS[index]
		view.call("_set_player_position", spot[1])
		view.set("player_facing", str(spot[2]))
		view.call("_set_player_animation_frame", str(spot[2]), 0)
	if frames % 15 == 12 and index < SPOTS.size():
		var spot: Array = SPOTS[index]
		var path := "user://obs_%s.png" % str(spot[0])
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
		index += 1
