extends SceneTree

# Observatory room interaction QA.
# Run: godot --headless --path <project> --script res://tools/observatory_room_interaction_test.gd

const POINTS := {
	"cabinet": Vector2(216, 350),
	"assembly": Vector2(688, 430),
	"door": Vector2(512, 282),
	"telescope": Vector2(512, 575),
	"mission": Vector2(676, 323),
	"journal": Vector2(343, 520),
	"computer": Vector2(721, 610)
}

const EXPECTED_RECTS := {
	"cabinet": Rect2(92, 88, 243, 213),
	"door": Rect2(447, 62, 131, 198),
	"mission": Rect2(681, 84, 205, 219),
	"assembly": Rect2(728, 328, 249, 176),
	"telescope": Rect2(423, 330, 190, 190),
	"journal": Rect2(48, 412, 258, 172),
	"computer": Rect2(754, 516, 201, 144),
}

const EXPECTED_COLLISION_RECTS := [
	Rect2(109, 108, 225, 191),
	Rect2(349, 226, 36, 62),
	Rect2(631, 207, 36, 73),
	Rect2(687, 127, 190, 169),
	Rect2(907, 169, 27, 120),
	Rect2(729, 368, 239, 122),
	Rect2(74, 489, 191, 91),
	Rect2(766, 591, 154, 62),
	Rect2(499, 417, 24, 27),
]

const MARKED_FURNITURE_POINTS := {
	"parts cabinet": Vector2(130, 230),
	"left dome plant": Vector2(365, 250),
	"right dome plant": Vector2(645, 242),
	"mission board desk": Vector2(760, 270),
	"tall mission-side plant": Vector2(920, 220),
	"assembly workbench": Vector2(850, 440),
	"learning journal desk": Vector2(160, 530),
	"official remote terminal desk": Vector2(840, 620),
	"central telescope pivot": Vector2(512, 430),
}

var failures := 0
var gm: Node
var view: Node


func _initialize() -> void:
	await process_frame
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAIL: GameManager missing")
		quit(1)
		return
	gm.new_game()
	_load_room()
	_check_remote_click_requires_nearby()
	_check_focus_points()
	_check_visual_hitboxes()
	_check_table_depth_and_occlusion()
	_check_marked_furniture_collision()
	_check_key_walkways()
	_check_spawn_clearance()
	_check_control_bar_toggle()
	_check_exact_pose_restore()
	await _check_not_ready_pad()
	await _check_ready_pad()
	_check_return_spawns()
	if failures == 0:
		print("OBSERVATORY INTERACTION TEST PASS")
		quit(0)
	else:
		print("OBSERVATORY INTERACTION TEST FAIL (%d failures)" % failures)
		quit(1)


func _load_room() -> void:
	if view != null:
		view.queue_free()
	var scene: PackedScene = load("res://scenes/observatory_room.tscn")
	view = scene.instantiate()
	root.add_child(view)


func _set_player_at(id: String) -> void:
	view.call("_set_player_position", POINTS[id])
	view.call("_update_nearby")


func _nearby_id() -> String:
	return str(view.get("nearby_id"))


func _check_focus_points() -> void:
	for id in POINTS.keys():
		_set_player_at(id)
		_check(_nearby_id() == id, "E focus near " + id)
		if id == "computer":
			var animator := view.get("furniture_animator") as Control
			var rigs: Dictionary = animator.get("rigs")
			var rig: Dictionary = rigs.get("computer", {})
			var scanline := rig.get("scanline") as ColorRect
			_check(scanline != null and scanline.color.a > 0.0, "computer screen previews a live response when the player is in range")


func _check_visual_hitboxes() -> void:
	for id in EXPECTED_RECTS.keys():
		var data: Dictionary = view.call("_get_interactable", id)
		var actual: Rect2 = data.get("rect", Rect2())
		_check(actual == EXPECTED_RECTS[id], "%s hitbox matches the new hall artwork" % id)
	var obstacles: Array = view.get("obstacles")
	_check(obstacles == EXPECTED_COLLISION_RECTS, "all foot blockers match the user-marked red rectangles")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(512, 430))), "central telescope pivot has collision")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(512, 450))), "central telescope platform outside the pivot remains walkable")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(420, 450))), "observation platform remains walkable")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(535, 350))), "raised telescope tube is an occluder, not a foot blocker")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(130, 230))), "parts cabinet body cannot be entered from its side")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(760, 600))), "computer left aisle has no rectangular air wall")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(820, 625))), "official computer desk blocks the whole marked footprint")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(780, 630))), "computer left cabinet blocks the player's feet")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(910, 620))), "computer right cabinet blocks the player's feet")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(735, 350))), "assembly rear approach remains open above the marked footprint")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(720, 410))), "assembly left aisle remains open outside the marked footprint")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(735, 390))), "assembly feet cannot enter the marked left edge")
	_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(850, 440))), "assembly feet cannot enter the marked tabletop footprint")
	var mission_front_rect: Rect2 = view.call("_player_collision_rect_for", Vector2(760, 312))
	_check(
		not obstacles.any(func(rect: Rect2) -> bool: return rect.intersects(mission_front_rect)),
		"mission desk front aisle has no body-height air wall"
	)
	var door_mat_rect: Rect2 = view.call("_player_collision_rect_for", Vector2(545, 280))
	_check(view.call("_player_rect_is_on_walkable_floor", door_mat_rect), "door mat remains inside the walkable floor")
	_check(not obstacles.any(func(rect: Rect2) -> bool: return rect.intersects(door_mat_rect)), "door mat has no duplicate threshold collision")


func _check_marked_furniture_collision() -> void:
	var obstacles: Array = view.get("obstacles")
	for label in MARKED_FURNITURE_POINTS:
		var point: Vector2 = MARKED_FURNITURE_POINTS[label]
		_check(obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(point)), "%s footprint cannot be entered" % label)


func _check_key_walkways() -> void:
	var start := Vector2(512, 646)
	var routes := {
		"central floor to cabinet front": Vector2(216, 350),
		"central floor to dome doorway": Vector2(512, 282),
		"central floor to remote-terminal left approach": Vector2(721, 610),
	}
	for label in routes:
		_check(_route_is_reachable(start, routes[label]), "%s remains reachable without clipping furniture" % label)


func _route_is_reachable(start: Vector2, goal: Vector2) -> bool:
	const STEP := 8.0
	var queue: Array[Vector2] = [start]
	var seen := {}
	seen[_grid_key(start, STEP)] = true
	var offsets: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	while not queue.is_empty():
		var current: Vector2 = queue.pop_front()
		if current.distance_to(goal) <= STEP:
			return true
		for offset in offsets:
			var candidate: Vector2 = current + offset * STEP
			var key := _grid_key(candidate, STEP)
			if seen.has(key) or not _can_occupy(candidate):
				continue
			seen[key] = true
			queue.append(candidate)
	return false


func _grid_key(point: Vector2, step: float) -> String:
	return "%d:%d" % [roundi(point.x / step), roundi(point.y / step)]


func _can_occupy(position: Vector2) -> bool:
	var collision: Rect2 = view.call("_player_collision_rect_for", position)
	if not view.call("_player_rect_is_on_walkable_floor", collision):
		return false
	for obstacle_value in view.get("obstacles"):
		if collision.intersects(obstacle_value as Rect2):
			return false
	return true


func _check_table_depth_and_occlusion() -> void:
	var obstacles: Array = view.get("obstacles")
	var depth_points := {
		"parts cabinet": Vector2(130, 230),
		"mission desk": Vector2(760, 270),
		"assembly lower cabinet": Vector2(780, 470),
		"journal desk": Vector2(160, 530),
		"computer console": Vector2(840, 620),
	}
	for label in depth_points:
		var point: Vector2 = depth_points[label]
		_check(
			obstacles.any(func(rect: Rect2) -> bool: return rect.has_point(point)),
			"%s blocks its tabletop depth" % label
		)

	var sample_positions := {
		"telescope": [Vector2(520, 370), Vector2(520, 505)],
		"assembly": [Vector2(850, 360), Vector2(850, 530)],
		"journal": [Vector2(160, 480), Vector2(160, 610)],
		"computer": [Vector2(850, 575), Vector2(735, 635)],
	}
	for id in sample_positions:
		var positions: Array = sample_positions[id]
		view.call("_set_player_position", positions[0])
		var occluder := _occluder(id)
		_check(occluder != null and occluder.visible, "%s hides the lower body from behind" % id)
		if occluder != null:
			for child in occluder.get_children():
				if id in ["assembly", "computer"]:
					var cutout := child as Sprite2D
					_check(
						cutout != null and cutout.texture != null,
						"%s occluder uses the supplied transparent furniture cutout" % id
					)
					if cutout != null and cutout.texture != null:
						var image := cutout.texture.get_image()
						_check(
							image.get_pixel(0, 0).a < 0.05
								and image.get_pixel(image.get_width() - 1, 0).a < 0.05,
							"%s cutout keeps transparent background corners" % id
						)
				else:
					var patch := child as Polygon2D
					_check(
						patch != null and patch.polygon == patch.uv,
						"%s occluder samples the hall artwork at exact 1:1 coordinates" % id
					)
		view.call("_set_player_position", positions[1])
		_check(occluder != null and not occluder.visible, "%s stays behind the player from the front" % id)

	view.call("_set_player_position", Vector2(760, 323))
	view.set("player_facing", "up")
	view.call("_update_nearby")
	_check(_nearby_id() == "mission", "mission desk is reachable from the floor directly in front")

	var right_edge_rect: Rect2 = view.call("_player_collision_rect_for", Vector2(990, 600))
	_check(not view.call("_player_rect_is_on_walkable_floor", right_edge_rect), "angled right wall and black border are not walkable")


func _occluder(id: String) -> CanvasItem:
	for data_value in view.get("furniture_occluders"):
		var data: Dictionary = data_value
		if str(data.get("id", "")) == id:
			return data.get("node") as CanvasItem
	return null


func _check_spawn_clearance() -> void:
	var obstacles: Array = view.get("obstacles")
	for id in POINTS.keys():
		var collision: Rect2 = view.call("_player_collision_rect_for", POINTS[id])
		var blocked := false
		for obstacle_value in obstacles:
			var obstacle: Rect2 = obstacle_value
			if collision.intersects(obstacle):
				blocked = true
				break
		_check(not blocked, "%s return spawn is outside furniture collision" % id)
		_check(view.call("_player_rect_is_on_walkable_floor", collision), "%s return spawn stays on the walkable floor" % id)


func _check_exact_pose_restore() -> void:
	var exact_position := Vector2(544, 602)
	view.set("player_facing", "left")
	view.call("_set_player_position", exact_position)
	# A later screen may set a coarse fallback spawn (the journal did this
	# after an observation). The exact room pose must still win.
	gm.set_observatory_spawn("journal")
	_load_room()
	var restored_position: Vector2 = view.get("player_pos")
	_check(restored_position.distance_to(exact_position) < 0.1, "menu and journal round trips preserve exact room position")
	_check(str(view.get("player_facing")) == "left", "room round trips preserve player facing")
	_check(str(view.get("arrival_furniture_id")) == "", "exact pose restore does not animate an unrelated fallback desk")


func _check_control_bar_toggle() -> void:
	var bar := view.get("control_bar") as Panel
	var toggle := view.get("control_bar_toggle") as Button
	_check(bar != null and bar.visible, "new-player control guide is shown briefly")
	_check(toggle != null and toggle.text == "v", "expanded guide exposes a yellow collapse arrow")
	view.call("_set_control_bar_expanded", false, false, true)
	_check(not bar.visible and toggle.text == "^", "control guide collapses to the reveal arrow")
	_check(toggle.position.y + toggle.size.y <= 768.0, "collapsed guide arrow remains inside 1024x768")
	_load_room()
	bar = view.get("control_bar") as Panel
	toggle = view.get("control_bar_toggle") as Button
	_check(bar != null and not bar.visible, "player control-guide choice persists on room re-entry")
	view.call("_set_control_bar_expanded", true, false, true)
	_check(bar.visible and toggle.text == "v", "player can reveal the control guide again")
	view.call("_set_control_bar_expanded", false, false, true)


func _check_remote_click_requires_nearby() -> void:
	view.call("_set_player_position", Vector2(517, 630))
	view.call("_update_nearby")
	view.call("_click_interactable", "cabinet")
	_check(_scene_is("observatory_room"), "remote click cabinet does not navigate")


func _check_not_ready_pad() -> void:
	gm.new_game()
	gm.progress["current_level"] = 3
	gm.progress["seen_story_events"] = ["intro", "level_1_before", "level_3_before_assembly"]
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro", "refractor_intro"]
	gm.progress["seen_concept_briefs"] = ["eye_imaging", "refractor_light_path"]
	gm.reset_assembly()
	_load_room()
	_set_player_at("telescope")
	view.call("_interact_with_nearby")
	await process_frame
	_check(_scene_is("observatory_room"), "not-ready pad stays in observatory")


func _check_ready_pad() -> void:
	gm.new_game()
	gm.progress["seen_story_events"] = ["intro", "level_1_before"]
	gm.progress["seen_teaching_steps"] = ["eye_imaging_intro"]
	gm.progress["seen_concept_briefs"] = ["eye_imaging"]
	gm.progress["current_level"] = 3
	gm.progress["seen_story_events"].append("level_3_before_assembly")
	# Mark the pre-observation story AND Maya's one-time below-horizon lesson as
	# seen, so this case exercises the pad -> observation routing itself rather
	# than stopping on a story panel.
	gm.progress["seen_story_events"].append("level_3_before")
	gm.progress["seen_story_events"].append("first_below_horizon")
	gm.progress["seen_teaching_steps"].append("refractor_intro")
	gm.progress["seen_concept_briefs"].append("refractor_light_path")
	for part_type in ["tripod", "mount", "tube", "objective", "eyepiece"]:
		gm.install_part(part_type, 0)
	gm.save()
	_load_room()
	_set_player_at("telescope")
	view.call("_interact_with_nearby")
	await process_frame
	# The base always enters Sky Observation. Only Sky may offer/open the map.
	_check(_scene_is("sky_observation"), "ready pad enters Sky Observation, never the map directly")


func _check_return_spawns() -> void:
	var expected := {
		"cabinet": Vector2(216, 350),
		"assembly": Vector2(688, 430),
		"journal": Vector2(343, 520),
		"door": Vector2(512, 282),
		"telescope": Vector2(512, 575)
	}
	for id in expected.keys():
		gm.clear_observatory_return_pose()
		gm.set_observatory_spawn(id)
		_load_room()
		var actual: Vector2 = view.get("player_pos")
		_check(actual.distance_to(expected[id]) < 1.0, "return spawn near " + id)


func _scene_is(name_part: String) -> bool:
	var scene: Node = current_scene
	if scene == null:
		scene = root.get_child(root.get_child_count() - 1)
	return scene != null and str(scene.scene_file_path).contains(name_part)


func _check(condition: bool, name: String) -> void:
	if condition:
		print("  ok: " + name)
	else:
		print("  FAIL: " + name)
		failures += 1
