extends Control
class_name ObservatoryFurnitureAnimator

const ROOM_TEXTURE := "res://assets/reference/observatory_room_clean_bg_1024.png"
const BRASS := Color(0.78, 0.52, 0.23)
const INTERIOR_TINT := Color(0.42, 0.48, 0.58, 1.0)

# Every moving front is cropped from the exact room background, so the closed
# state is pixel-identical to the painted furniture beneath it.
const SPECS := {
	"cabinet": {
		"rect": Rect2(83, 297, 224, 61),
		"interior_source": Rect2(88, 211, 212, 76),
		"mode": "drawer",
		"travel": 9.0,
	},
	"door": {
		"rect": Rect2(471, 91, 86, 187),
		"interior_source": Rect2(358, 95, 68, 128),
		"mode": "hinge",
	},
	"mission": {
		"rect": Rect2(604, 94, 152, 140),
		"interior_source": Rect2(606, 96, 148, 136),
		"mode": "shutter",
	},
	"assembly": {
		"rect": Rect2(782, 214, 170, 160),
		"interior_source": Rect2(782, 214, 170, 160),
		"mode": "workbench",
		"focus_rect": Rect2(10, 5, 112, 88),
	},
	"journal": {
		"rect": Rect2(82, 568, 225, 68),
		"interior_source": Rect2(88, 211, 212, 76),
		"mode": "drawer",
		"travel": 8.0,
	},
	"computer": {
		"rect": Rect2(721, 472, 131, 93),
		"interior_source": Rect2(721, 472, 131, 93),
		"mode": "screen",
	},
}

var rigs: Dictionary = {}
var states: Dictionary = {}
var active_tweens: Dictionary = {}
var room_texture: Texture2D


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_texture = load(ROOM_TEXTURE)
	for id_value in SPECS.keys():
		_build_rig(str(id_value), SPECS[id_value])


func has_rig(id: String) -> bool:
	return rigs.has(id)


func is_open(id: String) -> bool:
	return str(states.get(id, "closed")) == "open"


func is_animating(id: String) -> bool:
	return str(states.get(id, "closed")) in ["opening", "closing"]


func open_immediately(id: String) -> void:
	if not rigs.has(id):
		return
	_kill_tween(id)
	var rig: Dictionary = rigs[id]
	var mode := str(rig.get("mode", "shutter"))
	for door_value in rig.get("doors", []):
		var door := door_value as Control
		if door == null:
			continue
		var base_position: Vector2 = door.get_meta("closed_position", door.position)
		if mode == "drawer":
			door.position = base_position + Vector2(0, float(rig.get("travel", 8.0)))
			door.scale = Vector2(1.025, 1.08)
			door.modulate = Color(1.08, 1.03, 0.93, 1.0)
		elif mode == "workbench":
			door.position = base_position
			door.scale = Vector2(1.008, 1.008)
			door.modulate = Color(1.08, 1.045, 0.94, 1.0)
		elif mode == "screen":
			door.position = base_position
			door.scale = Vector2(1.012, 1.012)
			door.modulate = Color(0.66, 1.05, 0.76, 1.0)
		else:
			door.position = base_position
			door.scale = Vector2(0.08, 1.0)
			door.modulate = Color(0.82, 0.84, 0.88, 0.94)
	var glow := rig.get("glow") as ColorRect
	if glow != null:
		glow.color.a = 0.30 if mode == "screen" else (0.14 if mode == "workbench" else 0.17)
	for mote_value in rig.get("motes", []):
		var mote := mote_value as ColorRect
		if mote != null:
			var base_pos: Vector2 = mote.get_meta("base_position", mote.position)
			mote.position = base_pos - Vector2(0, 7)
			mote.color.a = 0.62
	var scanline := rig.get("scanline") as ColorRect
	if scanline != null:
		if mode == "workbench":
			scanline.position.x = maxf(8.0, scanline.get_parent().size.x - scanline.size.x - 8.0)
			scanline.color.a = 0.58
		else:
			scanline.position.y = maxf(8.0, scanline.get_parent().size.y - 9.0)
			scanline.color.a = 0.72
	var focus_frame := rig.get("focus_frame") as Control
	if focus_frame != null:
		focus_frame.modulate.a = 0.92
		focus_frame.scale = Vector2.ONE
	states[id] = "open"


func play_open(id: String, finished: Callable = Callable()) -> void:
	if not rigs.has(id):
		if finished.is_valid():
			finished.call()
		return
	if is_open(id):
		if finished.is_valid():
			finished.call()
		return
	_kill_tween(id)
	states[id] = "opening"
	var rig: Dictionary = rigs[id]
	var mode := str(rig.get("mode", "shutter"))
	var duration := 0.10 if _reduced_motion_enabled() else 0.42
	var tween := create_tween().bind_node(self).set_parallel(true)
	active_tweens[id] = tween
	var doors: Array = rig.get("doors", [])
	for index in range(doors.size()):
		var door := doors[index] as Control
		var base_position: Vector2 = door.get_meta("closed_position", door.position)
		if mode == "drawer":
			var travel := float(rig.get("travel", 8.0))
			tween.tween_property(door, "position", base_position + Vector2(0, travel), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(door, "scale", Vector2(1.025, 1.08), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(door, "modulate", Color(1.08, 1.03, 0.93, 1.0), duration * 0.72).set_trans(Tween.TRANS_SINE)
		elif mode == "workbench":
			# The workbench stays physically planted. Feedback comes from its
			# blueprint and tools waking up, not from furniture sliding outward.
			tween.tween_property(door, "scale", Vector2(1.008, 1.008), duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tween.tween_property(door, "modulate", Color(1.08, 1.045, 0.94, 1.0), duration * 0.66).set_trans(Tween.TRANS_SINE)
		elif mode == "screen":
			tween.tween_property(door, "scale", Vector2(1.012, 1.012), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(door, "modulate", Color(0.66, 1.05, 0.76, 1.0), duration * 0.72).set_trans(Tween.TRANS_SINE)
		else:
			tween.tween_property(door, "scale", Vector2(0.08, 1.0), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(door, "modulate", Color(0.82, 0.84, 0.88, 0.94), duration * 0.72).set_trans(Tween.TRANS_SINE)
	var glow := rig.get("glow") as ColorRect
	if glow != null:
		var glow_alpha := 0.30 if mode == "screen" else (0.14 if mode == "workbench" else 0.17)
		tween.tween_property(glow, "color:a", glow_alpha, duration * 0.72).set_trans(Tween.TRANS_SINE)
	var scanline := rig.get("scanline") as ColorRect
	if scanline != null:
		if mode == "workbench":
			scanline.position.x = 10.0
			tween.tween_property(scanline, "position:x", maxf(10.0, scanline.get_parent().size.x - scanline.size.x - 10.0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(scanline, "color:a", 0.58, duration * 0.20)
		else:
			scanline.position.y = 7.0
			tween.tween_property(scanline, "position:y", maxf(8.0, scanline.get_parent().size.y - 9.0), duration).set_trans(Tween.TRANS_LINEAR)
			tween.tween_property(scanline, "color:a", 0.72, duration * 0.22)
	var focus_frame := rig.get("focus_frame") as Control
	if focus_frame != null:
		focus_frame.modulate.a = 0.0
		focus_frame.scale = Vector2(0.965, 0.965)
		tween.tween_property(focus_frame, "modulate:a", 0.92, duration * 0.52).set_trans(Tween.TRANS_SINE)
		tween.tween_property(focus_frame, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for mote_value in rig.get("motes", []):
		var mote := mote_value as ColorRect
		if mote == null:
			continue
		var base_pos: Vector2 = mote.get_meta("base_position", mote.position)
		mote.position = base_pos + Vector2(0, 5)
		tween.tween_property(mote, "position", base_pos - Vector2(0, 7), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mote, "color:a", 0.62, duration * 0.44).set_delay(duration * 0.16)
	tween.chain().tween_callback(func() -> void:
		states[id] = "open"
		active_tweens.erase(id)
		if finished.is_valid():
			finished.call()
	)


func play_close(id: String, finished: Callable = Callable()) -> void:
	if not rigs.has(id):
		if finished.is_valid():
			finished.call()
		return
	if str(states.get(id, "closed")) == "closed":
		if finished.is_valid():
			finished.call()
		return
	_kill_tween(id)
	states[id] = "closing"
	var rig: Dictionary = rigs[id]
	var mode := str(rig.get("mode", "shutter"))
	var duration := 0.08 if _reduced_motion_enabled() else 0.32
	var tween := create_tween().bind_node(self).set_parallel(true)
	active_tweens[id] = tween
	for door_value in rig.get("doors", []):
		var door := door_value as Control
		if door == null:
			continue
		var base_position: Vector2 = door.get_meta("closed_position", door.position)
		tween.tween_property(door, "position", base_position, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(door, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(door, "modulate", Color.WHITE, duration * 0.72).set_trans(Tween.TRANS_SINE)
	var glow := rig.get("glow") as ColorRect
	if glow != null:
		tween.tween_property(glow, "color:a", 0.0, duration * 0.58)
	for mote_value in rig.get("motes", []):
		var mote := mote_value as ColorRect
		if mote != null:
			tween.tween_property(mote, "color:a", 0.0, duration * 0.38)
	var scanline := rig.get("scanline") as ColorRect
	if scanline != null:
		tween.tween_property(scanline, "color:a", 0.0, duration * 0.24)
	var focus_frame := rig.get("focus_frame") as Control
	if focus_frame != null:
		tween.tween_property(focus_frame, "modulate:a", 0.0, duration * 0.44)
		tween.tween_property(focus_frame, "scale", Vector2(0.98, 0.98), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		states[id] = "closed"
		active_tweens.erase(id)
		if finished.is_valid():
			finished.call()
	)


func close_all_immediately() -> void:
	for id_value in rigs.keys():
		var id := str(id_value)
		_kill_tween(id)
		var rig: Dictionary = rigs[id]
		for door_value in rig.get("doors", []):
			var door := door_value as Control
			if door != null:
				door.position = door.get_meta("closed_position", door.position)
				door.scale = Vector2.ONE
				door.modulate = Color.WHITE
		var glow := rig.get("glow") as ColorRect
		if glow != null:
			glow.color.a = 0.0
		for mote_value in rig.get("motes", []):
			var mote := mote_value as ColorRect
			if mote != null:
				mote.color.a = 0.0
		var scanline := rig.get("scanline") as ColorRect
		if scanline != null:
			scanline.color.a = 0.0
		var focus_frame := rig.get("focus_frame") as Control
		if focus_frame != null:
			focus_frame.modulate.a = 0.0
			focus_frame.scale = Vector2.ONE
		states[id] = "closed"


func _build_rig(id: String, spec: Dictionary) -> void:
	var rect: Rect2 = spec.get("rect", Rect2())
	var mode := str(spec.get("mode", "shutter"))
	var rig_root := Control.new()
	rig_root.name = "%sFurnitureRig" % id.capitalize()
	rig_root.position = rect.position
	rig_root.size = rect.size
	rig_root.clip_contents = mode in ["hinge", "shutter", "screen", "workbench"]
	rig_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rig_root)

	var interior := TextureRect.new()
	interior.name = "Interior"
	interior.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	interior.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	interior.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	interior.texture = _atlas_texture(spec.get("interior_source", rect))
	if mode == "drawer":
		interior.position = Vector2(3, 1)
		interior.size = Vector2(rect.size.x - 6, 13)
		interior.modulate = Color(0.22, 0.25, 0.31, 0.96)
	else:
		interior.position = Vector2.ZERO
		interior.size = rect.size
		interior.modulate = Color(0.70, 0.67, 0.61, 1.0) if mode == "shutter" else INTERIOR_TINT
	interior.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig_root.add_child(interior)

	if mode not in ["drawer", "workbench"]:
		var inner_frame := Panel.new()
		inner_frame.position = Vector2(2, 2)
		inner_frame.size = rect.size - Vector2(4, 4)
		inner_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner_frame.add_theme_stylebox_override("panel", _interior_style())
		rig_root.add_child(inner_frame)

	var glow := ColorRect.new()
	glow.name = "WarmInteriorGlow"
	if mode == "drawer":
		glow.position = Vector2(5, 2)
		glow.size = Vector2(rect.size.x - 10, 10)
	elif mode == "workbench":
		glow.position = Vector2(7, 5)
		glow.size = Vector2(rect.size.x - 14, 88)
	else:
		glow.position = Vector2(5, 5)
		glow.size = rect.size - Vector2(10, 10)
	glow.color = Color(0.95, 0.61, 0.20, 0.0) if mode != "screen" else Color(0.24, 1.0, 0.48, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rig_root.add_child(glow)

	var motes: Array = []
	var mote_count := 0 if mode == "screen" else 5
	for index in range(mote_count):
		var mote := ColorRect.new()
		mote.size = Vector2(2, 2) if index % 2 == 0 else Vector2(1, 1)
		mote.position = Vector2(
			8.0 + fmod(float(index * 37), maxf(10.0, rect.size.x - 16.0)),
			10.0 + fmod(float(index * 19), maxf(10.0, rect.size.y - 20.0))
		)
		mote.color = Color(1.0, 0.80, 0.37, 0.0)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.set_meta("base_position", mote.position)
		rig_root.add_child(mote)
		motes.append(mote)

	var scanline: ColorRect
	var doors: Array = []
	if mode in ["hinge", "drawer", "screen", "workbench"]:
		var door := _door_piece(rect, rect, Vector2.ZERO)
		door.pivot_offset = Vector2(0, rect.size.y * 0.5) if mode == "hinge" else rect.size * 0.5
		rig_root.add_child(door)
		doors.append(door)
	else:
		var half_width := floorf(rect.size.x * 0.5)
		var left_rect := Rect2(rect.position, Vector2(half_width, rect.size.y))
		var right_rect := Rect2(rect.position + Vector2(half_width, 0), Vector2(rect.size.x - half_width, rect.size.y))
		var left := _door_piece(left_rect, Rect2(Vector2.ZERO, left_rect.size), Vector2.ZERO)
		left.pivot_offset = Vector2(0, left.size.y * 0.5)
		rig_root.add_child(left)
		doors.append(left)
		var right := _door_piece(right_rect, Rect2(Vector2.ZERO, right_rect.size), Vector2(half_width, 0))
		right.pivot_offset = Vector2(right.size.x, right.size.y * 0.5)
		rig_root.add_child(right)
		doors.append(right)

	var focus_frame: Panel
	if mode == "workbench":
		scanline = ColorRect.new()
		scanline.name = "BlueprintLightSweep"
		scanline.position = Vector2(10, 8)
		scanline.size = Vector2(3, 84)
		scanline.color = Color(0.60, 0.91, 1.0, 0.0)
		scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rig_root.add_child(scanline)

		focus_frame = Panel.new()
		focus_frame.name = "BlueprintFocusFrame"
		var focus_rect: Rect2 = spec.get("focus_rect", Rect2(8, 6, rect.size.x - 16, rect.size.y * 0.55))
		focus_frame.position = focus_rect.position
		focus_frame.size = focus_rect.size
		focus_frame.pivot_offset = focus_frame.size * 0.5
		focus_frame.modulate.a = 0.0
		focus_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_frame.add_theme_stylebox_override("panel", _workbench_focus_style())
		rig_root.add_child(focus_frame)
	elif mode == "screen":
		scanline = ColorRect.new()
		scanline.name = "CRTScanline"
		scanline.position = Vector2(6, 7)
		scanline.size = Vector2(rect.size.x - 12, 2)
		scanline.color = Color(0.55, 1.0, 0.68, 0.0)
		scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rig_root.add_child(scanline)

	for door_value in doors:
		var door := door_value as Control
		door.set_meta("closed_position", door.position)

	rigs[id] = {
		"root": rig_root,
		"doors": doors,
		"glow": glow,
		"motes": motes,
		"mode": mode,
		"travel": float(spec.get("travel", 0.0)),
		"scanline": scanline,
		"focus_frame": focus_frame,
	}
	states[id] = "closed"


func _door_piece(source_rect: Rect2, local_rect: Rect2, local_position: Vector2) -> TextureRect:
	var door := TextureRect.new()
	door.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	door.stretch_mode = TextureRect.STRETCH_SCALE
	door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	door.texture = _atlas_texture(source_rect)
	door.position = local_position
	door.size = local_rect.size
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return door


func _atlas_texture(region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = room_texture
	atlas.region = region
	return atlas


func _interior_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.022, 0.032, 0.34)
	style.border_color = Color(BRASS.r, BRASS.g, BRASS.b, 0.72)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	return style


func _workbench_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.14, 0.20, 0.08)
	style.border_color = Color(0.48, 0.86, 0.96, 0.82)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_left = 1
	style.corner_radius_bottom_right = 1
	return style


func _kill_tween(id: String) -> void:
	var old: Variant = active_tweens.get(id)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	active_tweens.erase(id)


func _reduced_motion_enabled() -> bool:
	var feedback := get_node_or_null("/root/InteractionFeedback")
	return feedback != null and bool(feedback.get("reduced_motion"))
