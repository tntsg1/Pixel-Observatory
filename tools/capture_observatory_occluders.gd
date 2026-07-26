extends SceneTree

# Repeatable visual check for the clean furniture foreground layers.
# Run without --headless so the 1024x768 viewport is rendered.
const SPOTS: Array = [
	["computer_behind", Vector2(850, 565), "down"],
	["journal_behind", Vector2(150, 490), "down"],
	["assembly_behind", Vector2(718, 410), "right"],
	["assembly_front_line", Vector2(780, 530), "up"],
	["telescope_behind", Vector2(512, 390), "down"],
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
	if frames % 18 == 5:
		if index >= SPOTS.size():
			quit()
			return
		var spot: Array = SPOTS[index]
		view.call("_set_player_position", spot[1])
		view.set("player_facing", str(spot[2]))
		view.call("_set_player_animation_frame", str(spot[2]), 0)
	if frames % 18 == 14 and index < SPOTS.size():
		var spot: Array = SPOTS[index]
		var path := "res://artifacts/observatory_%s.png" % str(spot[0])
		root.get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		index += 1
