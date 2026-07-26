extends SceneTree

const OUTPUT_DIR := "res://artifacts/observatory_hall_relayout"
const INTERACTION_RECTS := {
	"cabinet": Rect2(92, 88, 243, 213),
	"door": Rect2(447, 62, 131, 198),
	"mission": Rect2(681, 84, 205, 219),
	"assembly": Rect2(728, 328, 249, 176),
	"telescope": Rect2(423, 330, 190, 190),
	"journal": Rect2(48, 412, 258, 172),
	"computer": Rect2(783, 532, 168, 124),
}
const OBSTACLE_RECTS := [
	Rect2(92, 154, 243, 152),
	Rect2(454, 243, 117, 18),
	Rect2(686, 221, 198, 82),
	Rect2(730, 377, 246, 129),
	Rect2(54, 500, 250, 86),
	Rect2(112, 566, 78, 58),
	Rect2(783, 575, 168, 83),
	Rect2(480, 404, 69, 68),
	Rect2(850, 474, 55, 54),
	Rect2(931, 548, 53, 84),
	Rect2(46, 456, 39, 72),
]

var gm: Node
var active_room: Control


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		push_error("Observatory hall capture requires GameManager.")
		quit(1)
		return

	await _capture_language("en", "01_observatory_hall_en.png")
	await _capture_language("zh", "02_observatory_hall_zh.png")
	await _capture_hitbox_overlay()
	await _capture_table_depth()
	await _capture_telescope_depth()
	await _capture_access_points()
	await _capture_control_bar_states()
	await _capture_guidance_highlight_states()
	print("OBSERVATORY HALL RELAYOUT CAPTURE PASS")
	quit(0)


func _prepare_room(language: String) -> void:
	if active_room != null:
		active_room.queue_free()
		await process_frame
	gm.language_mode = language
	gm.progress["language_mode"] = language
	gm.progress["current_level"] = 1
	gm.progress["tutorial_assistance"] = "full"
	gm.clear_room_guidance()
	gm.update_room_guidance_for_level()
	gm.set_observatory_spawn("default")
	active_room = load("res://scenes/observatory_room.tscn").instantiate() as Control
	root.add_child(active_room)
	current_scene = active_room
	for _frame in range(5):
		await process_frame
	active_room.call("_set_player_position", Vector2(512, 646))
	await process_frame


func _capture_language(language: String, file_name: String) -> void:
	await _prepare_room(language)
	await create_timer(0.2).timeout
	_save(file_name)


func _capture_hitbox_overlay() -> void:
	await _prepare_room("en")
	var guidance := active_room.get("guidance_panel") as Control
	if guidance != null:
		guidance.visible = false
	for data_value in active_room.get("interactables"):
		var data: Dictionary = data_value
		var glow := data.get("glow") as CanvasItem
		if glow != null:
			glow.modulate.a = 0.92

	var overlay := Control.new()
	overlay.name = "InteractionRectVerification"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 2000
	active_room.add_child(overlay)

	for id_value in INTERACTION_RECTS:
		var id := str(id_value)
		var rect: Rect2 = INTERACTION_RECTS[id]
		_add_outline(overlay, rect, Color(0.22, 0.90, 1.0, 0.95), 2.0)
		_add_tag(overlay, id.to_upper(), rect.position + Vector2(4, 4), Color(0.01, 0.08, 0.11, 0.92))
	for obstacle: Rect2 in OBSTACLE_RECTS:
		var block := ColorRect.new()
		block.position = obstacle.position
		block.size = obstacle.size
		block.color = Color(1.0, 0.26, 0.18, 0.22)
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(block)
	_add_tag(
		overlay,
		"CYAN: INTERACTION / RED: COLLISION",
		Vector2(334, 70),
		Color(0.01, 0.03, 0.06, 0.94)
	)
	await process_frame
	_save("03_interaction_collision_overlay.png")


func _capture_table_depth() -> void:
	await _prepare_room("en")
	var guidance := active_room.get("guidance_panel") as Control
	if guidance != null:
		guidance.visible = false
	active_room.call("_set_player_position", Vector2(790, 360))
	active_room.set("player_facing", "down")
	active_room.call("_set_player_animation_frame", "down", 0)
	await process_frame
	_save("04_assembly_approach_from_behind.png")
	active_room.call("_set_player_position", Vector2(740, 530))
	active_room.set("player_facing", "up")
	active_room.call("_set_player_animation_frame", "up", 0)
	await process_frame
	_save("05_assembly_standing_in_front.png")


func _capture_telescope_depth() -> void:
	await _prepare_room("en")
	var guidance := active_room.get("guidance_panel") as Control
	if guidance != null:
		guidance.visible = false
	active_room.call("_set_player_position", Vector2(520, 370))
	active_room.set("player_facing", "down")
	active_room.call("_set_player_animation_frame", "down", 0)
	await process_frame
	_save("06_telescope_walking_behind.png")
	active_room.call("_set_player_position", Vector2(520, 505))
	active_room.set("player_facing", "up")
	active_room.call("_set_player_animation_frame", "up", 0)
	await process_frame
	_save("07_telescope_standing_in_front.png")


func _capture_access_points() -> void:
	await _prepare_room("en")
	var guidance := active_room.get("guidance_panel") as Control
	if guidance != null:
		guidance.visible = false
	active_room.call("_set_player_position", Vector2(760, 323))
	active_room.set("player_facing", "up")
	active_room.call("_set_player_animation_frame", "up", 0)
	active_room.call("_update_nearby")
	await process_frame
	_save("08_mission_desk_front_access.png")
	active_room.call("_set_player_position", Vector2(216, 326))
	active_room.call("_update_nearby")
	await process_frame
	_save("09_parts_cabinet_front_access.png")


func _capture_control_bar_states() -> void:
	await _prepare_room("en")
	var guidance := active_room.get("guidance_panel") as Control
	if guidance != null:
		guidance.visible = false
	active_room.call("_set_control_bar_expanded", false, false, false)
	await process_frame
	_save("10_control_bar_collapsed.png")
	active_room.call("_set_control_bar_expanded", true, false, false)
	await process_frame
	_save("11_control_bar_expanded.png")


func _capture_guidance_highlight_states() -> void:
	var feedback := root.get_node_or_null("/root/InteractionFeedback")
	if feedback != null:
		feedback.set_guidance_highlights_enabled(true)
	await _prepare_room("zh")
	active_room.call("_update_room_guidance_panel")
	await process_frame
	_save("12_guidance_corner_highlight_zh.png")
	active_room.call("_toggle_guidance_highlights")
	await process_frame
	_save("13_guidance_highlight_disabled_zh.png")
	if feedback != null:
		feedback.set_guidance_highlights_enabled(true)


func _add_outline(parent: Control, rect: Rect2, color: Color, width: float) -> void:
	var top := ColorRect.new()
	top.position = rect.position
	top.size = Vector2(rect.size.x, width)
	top.color = color
	parent.add_child(top)
	var bottom := ColorRect.new()
	bottom.position = Vector2(rect.position.x, rect.end.y - width)
	bottom.size = Vector2(rect.size.x, width)
	bottom.color = color
	parent.add_child(bottom)
	var left := ColorRect.new()
	left.position = rect.position
	left.size = Vector2(width, rect.size.y)
	left.color = color
	parent.add_child(left)
	var right := ColorRect.new()
	right.position = Vector2(rect.end.x - width, rect.position.y)
	right.size = Vector2(width, rect.size.y)
	right.color = color
	parent.add_child(right)


func _add_tag(parent: Control, text_value: String, at: Vector2, background: Color) -> void:
	var label := Label.new()
	label.position = at
	label.text = " " + text_value + " "
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.80, 0.96, 1.0))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := Panel.new()
	panel.position = at
	panel.size = Vector2(maxf(90.0, float(text_value.length()) * 8.0 + 12.0), 22.0)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.22, 0.90, 1.0, 0.85)
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	parent.add_child(label)


func _save(file_name: String) -> void:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR + "/" + file_name)
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("Could not save %s: %s" % [output, error_string(error)])
	else:
		print("CAPTURE ", output)
