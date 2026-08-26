extends Control
class_name ObservatoryAmbientAnimator

## Small, localised idle motion for the painted observatory hall.
##
## The hall art is intentionally kept as one immutable background.  This layer
## adds only light response, CRT refresh, reflected tool glints, and a few dust
## pixels.  Nothing here replaces or stretches the supplied furniture art.

const LIGHT_SPECS := [
	{"id": "left_wall", "center": Vector2(60, 216), "radius": 58.0, "phase": 0.20, "speed": 1.55, "color": Color(1.0, 0.55, 0.18)},
	{"id": "right_wall", "center": Vector2(964, 216), "radius": 58.0, "phase": 2.05, "speed": 1.72, "color": Color(1.0, 0.55, 0.18)},
	{"id": "left_sconce", "center": Vector2(427, 166), "radius": 45.0, "phase": 4.10, "speed": 1.42, "color": Color(1.0, 0.60, 0.22)},
	{"id": "right_sconce", "center": Vector2(599, 166), "radius": 45.0, "phase": 1.35, "speed": 1.64, "color": Color(1.0, 0.60, 0.22)},
	{"id": "workbench_lamp", "center": Vector2(956, 445), "radius": 42.0, "phase": 3.35, "speed": 1.82, "color": Color(1.0, 0.52, 0.16)},
	{"id": "lower_left", "center": Vector2(84, 650), "radius": 50.0, "phase": 2.70, "speed": 1.48, "color": Color(1.0, 0.58, 0.20)},
	{"id": "lower_right", "center": Vector2(944, 650), "radius": 50.0, "phase": 0.90, "speed": 1.68, "color": Color(1.0, 0.58, 0.20)},
	{"id": "mission_lamp", "center": Vector2(708, 247), "radius": 38.0, "phase": 5.00, "speed": 1.58, "color": Color(1.0, 0.58, 0.20)},
]

const SCREEN_SPECS := [
	{"id": "workbench_screen", "rect": Rect2(873, 351, 48, 42), "phase": 0.60, "period": 3.40, "color": Color(0.35, 0.78, 1.0)},
	{"id": "remote_screen", "rect": Rect2(795, 544, 112, 45), "phase": 2.20, "period": 3.85, "color": Color(0.30, 1.0, 0.58)},
]

const DUST_SPECS := [
	{"position": Vector2(160, 372), "phase": 0.2, "travel": Vector2(10, -8), "period": 9.0},
	{"position": Vector2(348, 295), "phase": 3.4, "travel": Vector2(-8, 12), "period": 11.0},
	{"position": Vector2(667, 304), "phase": 5.1, "travel": Vector2(8, -10), "period": 10.0},
	{"position": Vector2(928, 305), "phase": 1.4, "travel": Vector2(-9, 7), "period": 12.0},
	{"position": Vector2(690, 575), "phase": 4.3, "travel": Vector2(-7, -9), "period": 10.5},
]

var elapsed := 0.0
var quiet := false
var light_rigs: Array[Dictionary] = []
var screen_rigs: Array[Dictionary] = []
var dust_rigs: Array[Dictionary] = []
var activity: AmbientWorkbenchActivity


class AmbientHalo extends Control:
	var halo_color := Color.WHITE
	var strength := 1.0

	func _draw() -> void:
		var center := size * 0.5
		var outer := Color(halo_color.r, halo_color.g, halo_color.b, 0.040 * strength)
		var middle := Color(halo_color.r, halo_color.g, halo_color.b, 0.075 * strength)
		var inner := Color(halo_color.r, halo_color.g, halo_color.b, 0.125 * strength)
		draw_circle(center, size.x * 0.48, outer)
		draw_circle(center, size.x * 0.31, middle)
		draw_circle(center, size.x * 0.14, inner)


class AmbientFlame extends Control:
	var flame_color := Color(1.0, 0.60, 0.20)
	var strength := 1.0
	var sway := 0.0

	func _draw() -> void:
		var center := size * 0.5
		var x := roundf(sway)
		var alpha := 0.27 * strength
		# These blocks are deliberately larger than a single-pixel glint, but
		# remain inside the painted lamp core so the original sprite is never
		# duplicated or displaced.
		draw_rect(Rect2(center + Vector2(x - 2.0, -6), Vector2(5, 8)), Color(flame_color.r, flame_color.g, flame_color.b, alpha * 0.48))
		draw_rect(Rect2(center + Vector2(x - 1.0, -8), Vector2(3, 7)), Color(1.0, 0.72, 0.30, alpha * 0.76))
		draw_rect(Rect2(center + Vector2(x - 1.0, -4), Vector2(2, 5)), Color(1.0, 0.93, 0.62, alpha * 0.88))
		draw_rect(Rect2(center + Vector2(x, -1), Vector2(2, 3)), Color(1.0, 0.98, 0.80, alpha * 0.70))


class AmbientWorkbenchActivity extends Control:
	const GLINT_SPECS := [
		{"from": Vector2(770, 411), "to": Vector2(791, 430), "phase": 0.0, "period": 8.7},
		{"from": Vector2(825, 414), "to": Vector2(850, 433), "phase": 3.1, "period": 10.6},
		{"from": Vector2(876, 412), "to": Vector2(903, 429), "phase": 5.2, "period": 7.9},
		{"from": Vector2(914, 413), "to": Vector2(934, 428), "phase": 1.7, "period": 12.0},
	]
	var time := 0.0
	var reduced_motion := false

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		if reduced_motion:
			return
		for spec_value in GLINT_SPECS:
			var spec: Dictionary = spec_value
			var period := float(spec["period"])
			var local := fmod(time + float(spec["phase"]), period)
			# Most of the cycle is quiet.  The short active window reads as a
			# changing reflection on a metal tool rather than a permanent sparkle.
			if local > 1.55:
				continue
			var progress := local / 1.55
			var eased := 1.0 - pow(1.0 - progress, 2.0)
			var point: Vector2 = spec["from"].lerp(spec["to"], eased)
			var alpha := sin(progress * PI) * 0.68
			var pixel_point := Vector2(roundf(point.x), roundf(point.y))
			# A short blocky streak gives the metal a readable moving reflection;
			# the dark pixel below it is a contact cue, not a second tool sprite.
			draw_rect(Rect2(pixel_point - Vector2(2, 1), Vector2(5, 2)), Color(1.0, 0.82, 0.36, alpha * 0.62))
			draw_rect(Rect2(pixel_point + Vector2(1, -2), Vector2(2, 2)), Color(1.0, 0.98, 0.78, alpha))
			if progress > 0.24 and progress < 0.76:
				var flare_progress := (progress - 0.24) / 0.52
				var flare_alpha := sin(flare_progress * PI) * 0.76
				draw_rect(Rect2(pixel_point + Vector2(-1, -4), Vector2(2, 2)), Color(1.0, 0.95, 0.64, flare_alpha))
				draw_rect(Rect2(pixel_point + Vector2(-4, -1), Vector2(2, 2)), Color(1.0, 0.82, 0.36, flare_alpha * 0.70))
				draw_rect(Rect2(pixel_point + Vector2(3, -1), Vector2(2, 2)), Color(1.0, 0.82, 0.36, flare_alpha * 0.70))
			if alpha > 0.12:
				draw_rect(Rect2(pixel_point + Vector2(-1, 2), Vector2(3, 1)), Color(0.05, 0.08, 0.09, alpha * 0.42))
		# A tiny diagnostic pixel on the workbench screen gives the blue glass
		# a living status without repainting the supplied blueprint.
		var status_phase := fmod(time + 2.4, 5.8)
		if status_phase < 0.68:
			var status_alpha := sin(status_phase / 0.68 * PI) * 0.48
			draw_rect(Rect2(914, 359, 2, 2), Color(0.58, 0.92, 1.0, status_alpha))


func setup() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	_build_lights()
	_build_screens()
	_build_dust()
	activity = AmbientWorkbenchActivity.new()
	activity.name = "WorkbenchPartActivity"
	activity.set_anchors_preset(Control.PRESET_FULL_RECT)
	activity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	activity.z_index = 1
	add_child(activity)


func set_quiet(value: bool) -> void:
	quiet = value


func _process(delta: float) -> void:
	elapsed += delta
	var reduced_motion := _reduced_motion_enabled()
	var motion_scale := 0.26 if reduced_motion else 1.0
	var intensity_scale := 0.68 if quiet else 1.0
	for rig in light_rigs:
		var wave := 0.5 + 0.5 * sin(elapsed * float(rig["speed"]) + float(rig["phase"]))
		var fine := 0.5 + 0.5 * sin(elapsed * (float(rig["speed"]) * 2.17) + float(rig["phase"]) * 1.73)
		var strength := (0.86 + wave * 0.16 + fine * 0.07) * intensity_scale
		var halo := rig["halo"] as AmbientHalo
		halo.strength = strength
		halo.scale = Vector2(1.0 + wave * 0.025 * motion_scale, 1.0 - wave * 0.014 * motion_scale)
		halo.queue_redraw()
		var flame := rig["flame"] as AmbientFlame
		flame.strength = strength
		flame.sway = (sin(elapsed * 2.31 + float(rig["phase"])) * 0.85 + sin(elapsed * 4.07 + float(rig["phase"]) * 2.0) * 0.25) * motion_scale
		flame.queue_redraw()
	for rig in screen_rigs:
		var root := rig["root"] as Control
		var scanline := rig["scanline"] as ColorRect
		var rect: Rect2 = rig["rect"]
		var travel := maxf(1.0, rect.size.y - 6.0)
		var period := float(rig["period"])
		var phase := float(rig["phase"])
		if reduced_motion:
			scanline.position.y = 3.0
		else:
			scanline.position.y = 3.0 + floorf(fmod(elapsed + phase / 2.0, period) / period * travel)
		var refresh_trail := rig["trail"] as ColorRect
		refresh_trail.position.y = maxf(0.0, scanline.position.y - 3.0)
		refresh_trail.color.a = (0.035 + 0.018 * sin(elapsed * 1.3 + phase)) * intensity_scale
		var base_alpha := 0.26 if str(rig["id"]) == "workbench_screen" else 0.30
		scanline.color.a = (base_alpha + 0.025 * sin(elapsed * 1.3 + phase)) * intensity_scale
		for index in range((rig["status_pixels"] as Array).size()):
			var pixel := (rig["status_pixels"] as Array)[index] as ColorRect
			var pixel_wave := 0.5 + 0.5 * sin(elapsed * (1.1 + index * 0.23) + phase + index * 1.7)
			pixel.color.a = (0.10 + pixel_wave * 0.24) * intensity_scale
		root.queue_redraw()
	for rig in dust_rigs:
		var mote := rig["node"] as ColorRect
		var period := float(rig["period"])
		var progress := fmod(elapsed + float(rig["phase"]), period) / period
		var travel: Vector2 = rig["travel"]
		var eased := 0.5 - 0.5 * cos(progress * TAU)
		mote.position = rig["position"] + travel * eased * motion_scale
		mote.color.a = (0.03 + sin(progress * PI) * 0.13) * intensity_scale
	if activity != null:
		activity.reduced_motion = reduced_motion


func _build_lights() -> void:
	for spec_value in LIGHT_SPECS:
		var spec: Dictionary = spec_value
		var radius := float(spec["radius"])
		var halo := AmbientHalo.new()
		halo.name = "%sHalo" % str(spec["id"])
		halo.position = spec["center"] - Vector2.ONE * radius
		halo.size = Vector2.ONE * radius * 2.0
		halo.halo_color = spec["color"]
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.z_index = -1
		add_child(halo)
		var flame := AmbientFlame.new()
		flame.name = "%sFlameCore" % str(spec["id"])
		flame.position = spec["center"] - Vector2(5, 7)
		flame.size = Vector2(10, 14)
		flame.flame_color = spec["color"]
		flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flame.z_index = 0
		add_child(flame)
		light_rigs.append({"halo": halo, "flame": flame, "phase": float(spec["phase"]), "speed": float(spec["speed"])})


func _build_screens() -> void:
	for spec_value in SCREEN_SPECS:
		var spec: Dictionary = spec_value
		var rect: Rect2 = spec["rect"]
		var root := Control.new()
		root.name = "%sAmbientScreen" % str(spec["id"]).capitalize()
		root.position = rect.position
		root.size = rect.size
		root.clip_contents = true
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The furniture animator keeps the original desk/screen raster at z=4.
		# This layer is still clipped to the screen glass, so it can sit above
		# that raster without covering the desk, tools, or player.
		root.z_index = 5
		add_child(root)
		var tint := ColorRect.new()
		tint.position = Vector2(2, 2)
		tint.size = rect.size - Vector2(4, 4)
		tint.color = Color(spec["color"].r, spec["color"].g, spec["color"].b, 0.045)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tint)
		var refresh_trail := ColorRect.new()
		refresh_trail.name = "RefreshTrail"
		refresh_trail.position = Vector2(3, 1)
		refresh_trail.size = Vector2(maxf(1.0, rect.size.x - 6.0), 7.0)
		refresh_trail.color = Color(spec["color"].r, spec["color"].g, spec["color"].b, 0.070)
		refresh_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(refresh_trail)
		var scanline := ColorRect.new()
		scanline.name = "IdleScanline"
		scanline.position = Vector2(3, 3)
		scanline.size = Vector2(maxf(1.0, rect.size.x - 6.0), 3.0)
		scanline.color = Color(spec["color"].r, spec["color"].g, spec["color"].b, 0.30)
		scanline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(scanline)
		var status_pixels: Array[ColorRect] = []
		var pixel_positions := [Vector2(6, 6), Vector2(12, 6), Vector2(18, 6)]
		for pixel_position in pixel_positions:
			var pixel := ColorRect.new()
			pixel.position = pixel_position
			pixel.size = Vector2(2, 2)
			pixel.color = Color(spec["color"].r, spec["color"].g, spec["color"].b, 0.30)
			pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(pixel)
			status_pixels.append(pixel)
		screen_rigs.append({"id": str(spec["id"]), "root": root, "rect": rect, "trail": refresh_trail, "scanline": scanline, "status_pixels": status_pixels, "phase": float(spec["phase"]), "period": float(spec["period"])})


func _build_dust() -> void:
	for index in range(DUST_SPECS.size()):
		var spec: Dictionary = DUST_SPECS[index]
		var mote := ColorRect.new()
		mote.name = "AmbientDust_%02d" % index
		mote.position = spec["position"]
		mote.size = Vector2(1, 1) if index % 2 == 0 else Vector2(2, 1)
		mote.color = Color(1.0, 0.84, 0.48, 0.0)
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mote.z_index = 0
		add_child(mote)
		dust_rigs.append({"node": mote, "position": spec["position"], "travel": spec["travel"], "phase": float(spec["phase"]), "period": float(spec["period"])})


func _reduced_motion_enabled() -> bool:
	var feedback := get_node_or_null("/root/InteractionFeedback")
	return feedback != null and bool(feedback.get("reduced_motion"))
