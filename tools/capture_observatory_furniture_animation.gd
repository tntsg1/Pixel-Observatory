extends SceneTree

const OUTPUT_DIR := "res://artifacts/observatory_furniture"
const FURNITURE_IDS := [
	"cabinet",
	"door",
	"mission",
	"assembly",
	"journal",
	"computer",
]

var room: Control
var animator: ObservatoryFurnitureAnimator
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	had_save = FileAccess.file_exists("user://savegame.json")
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes("user://savegame.json")
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	room = scene.instantiate()
	root.add_child(room)
	await process_frame
	await create_timer(0.25).timeout
	_save("01_all_closed.png")

	animator = room.get_node("FurnitureAnimator") as ObservatoryFurnitureAnimator
	animator.play_open("assembly")
	await create_timer(0.46).timeout
	_save("02_assembly_workbench_active.png")
	animator.play_close("assembly")
	await create_timer(0.36).timeout
	for id in FURNITURE_IDS:
		animator.play_open(id)
	await create_timer(0.50).timeout
	_save("03_all_open.png")

	for id in FURNITURE_IDS:
		animator.play_close(id)
	await create_timer(0.40).timeout
	_save("04_all_closed_after_cycle.png")
	print("OBSERVATORY FURNITURE VISUAL CAPTURE PASS")
	_restore_save()
	quit(0)


func _restore_save() -> void:
	if had_save:
		var save_file := FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(saved_bytes)
	elif FileAccess.file_exists("user://savegame.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://savegame.json"))


func _save(file_name: String) -> void:
	var path := ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
	else:
		print("CAPTURE ", path)
