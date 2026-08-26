extends SceneTree

const OUTPUT_DIR := "res://artifacts/observatory_ambient"
const CAPTURES := [
	["01_idle_0_6s.png", 0.6],
	["02_idle_3_4s.png", 2.8],
	["03_idle_7_8s.png", 4.4],
]

var room: Control


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	room = scene.instantiate()
	root.add_child(room)
	await process_frame
	_hide_guidance_for_capture()
	for capture_value in CAPTURES:
		var capture: Array = capture_value
		await create_timer(float(capture[1])).timeout
		_save(str(capture[0]))
	print("OBSERVATORY AMBIENT VISUAL CAPTURE PASS")
	quit(0)


func _hide_guidance_for_capture() -> void:
	for property_name in ["guidance_panel", "guidance_overlay", "route_edge_indicator", "mobile_overlay"]:
		var node := room.get(property_name) as CanvasItem
		if node != null:
			node.visible = false


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
