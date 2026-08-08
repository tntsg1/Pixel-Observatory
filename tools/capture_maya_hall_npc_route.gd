extends SceneTree

const OUTPUT_DIR := "res://artifacts/maya_npc_motion_route/frames"
const STEP_SECONDS := 0.24
const MAX_FRAMES := 36

var room: Control
var maya: MayaHallNPC


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var manager := root.get_node_or_null("GameManager")
	if manager == null:
		push_error("GameManager unavailable")
		quit(1)
		return
	manager.progress["current_level"] = 3
	manager.progress["graduation_seen"] = false
	manager.language_mode = "zh"
	manager.room_guidance_target = "assembly"

	room = (load("res://scenes/observatory_room.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	maya = room.get_node_or_null("MayaHallNPC") as MayaHallNPC
	if maya == null:
		push_error("MayaHallNPC unavailable")
		quit(1)
		return

	# Drive the same runtime movement code at a fixed cadence so the result is a
	# deterministic visual proof of the real route, foot anchoring and facing.
	maya.set_process(false)
	maya.position = Vector2(512, 292)
	maya.set("_route_enabled", false)
	maya.set("_route_is_guided", true)
	maya.set("_destination_id", "assembly")
	maya.set("_arrived", false)
	maya.set("_path", maya.call("_make_path", maya.position, room.call("_maya_destination_for", "assembly")))
	maya.set("_path_index", 0)
	maya.call("_apply_state_text", "guide_assembly")
	maya.call("_expand_bubble")
	maya.set("_movement_locked_until_msec", 0)
	maya.set("_return_to_idle_after_animation", false)
	maya.call("_set_facing", "down")

	var captured := 0
	for frame_index in range(MAX_FRAMES):
		await process_frame
		_save_frame(frame_index)
		captured += 1
		maya.call("_update_movement", STEP_SECONDS)
		maya.call("_update_animation", STEP_SECONDS)
		maya.call("_update_depth")
		if int(maya.get("_path_index")) >= (maya.get("_path") as PackedVector2Array).size() \
			and not bool(maya.get("_moving")):
			break

	# Hold the exact arrival pose long enough for the result to read in the GIF.
	for hold_index in range(3):
		await process_frame
		_save_frame(captured + hold_index)
	print("MAYA HALL ROUTE CAPTURE: PASS (", captured + 3, " frames)")
	quit(0)


func _save_frame(frame_index: int) -> void:
	var path := "%s/frame_%03d.png" % [OUTPUT_DIR, frame_index]
	root.get_texture().get_image().save_png(path)
