extends Control

# World Map — astronomical navigation transition.
#
# The map is the authored image (assets/world_map/world_map_base.png, 1672x941),
# aspect-fit + NEAREST, never redrawn procedurally. Everything dynamic lives on
# a transparent overlay above it.
#
# The relocation is a SEVEN-PHASE state machine, not a static arc:
#   INTRO   circular globe reveal, current site blue pulse, "below horizon"
#   SCAN    cyan scan wave sweeps out; candidate sites resolve one by one
#   FOUND   "Visible site found", recommended site turns gold
#   ROUTE   glowing arc draws from current -> recommended, light head travels
#   READY   waits for the player; Confirm Site enabled, compass points at it
#   CONFIRM press feedback, expanding ring, zoom-in, big destination name
#   TRAVEL  camera pans to the destination, other markers fade, arrival burst
#   DEPART  map contracts into a point of light -> sky observation
#
# Site visibility is computed ONCE in _ready (before any animation), so Skip can
# never skip the calculation - only its presentation.

const MAP_TEXTURE := "res://assets/world_map/world_map_base.png"
const MAP_SIZE := Vector2(1672.0, 941.0)
const MAP_AREA := Rect2(0.0, 92.0, 764.0, 600.0)

# The authored map is not a full-frame equirectangular image. Its decorative
# frame extends well beyond the actual graticule, and the northern/southern
# halves use slightly different spacing. Keep astronomy on true lat/lon, then
# register those coordinates to the painted graticule here.
const MAP_PRIME_MERIDIAN_X := 772.0
const MAP_EQUATOR_Y := 551.0
const MAP_WEST_PX_PER_DEGREE := 3.525
const MAP_EAST_PX_PER_DEGREE := 3.600
const MAP_FAR_WEST_LONGITUDE := -140.0
const MAP_FAR_WEST_X := 278.5
const MAP_DATE_LINE_X := 208.0
const MAP_NORTH_PX_PER_DEGREE := 3.700
const MAP_SOUTH_PX_PER_DEGREE := 4.050
const MAP_NORTH_LATITUDE := 90.0
const MAP_SOUTH_LATITUDE := -60.0

const GOLD := Color("e0aa46")
const GOLD_BRIGHT := Color("ffd27a")
const CYAN := Color("55c7df")
const CYAN_BRIGHT := Color("8ae6ff")
const GREEN := Color("6fdf8a")
const RED := Color("ef6a5a")
const WHITE_DATA := Color("eef2f6")
const TEXT := Color("ece8dc")
const DIM := Color("7f8ba0")
const SITE_DIM := Color("2f5578")

enum Phase { INTRO, SCAN, FOUND, ROUTE, READY, CONFIRM, TRAVEL, DEPART }

const DURATIONS := {
	Phase.INTRO: 1.7, Phase.SCAN: 1.5, Phase.FOUND: 0.7, Phase.ROUTE: 1.5,
	Phase.CONFIRM: 0.85, Phase.TRAVEL: 2.65, Phase.DEPART: 1.05
}

var utc: Dictionary = {}
var home_site: Dictionary = {}
var current_site: Dictionary = {}
var recommended: Dictionary = {}
var sites: Array = []
var radec: Dictionary = {}
var minimum_altitude := 10.0
var target_below := false
var target_low := false
var target_alt_now := 0.0
var map_target_id := ""
var comfortable_altitude := 18.0

var site_visibility: Dictionary = {}
var scan_order: Array = []          # site ids sorted by distance from current
var resolved_count := 0             # how many candidates the scan has revealed
var selected_id := ""

var phase: int = Phase.INTRO
var phase_t := 0.0
var anim_t := 0.0
var reveal := 0.0                   # circular globe reveal 0..1
var arc_progress := 0.0
var scan_radius := 0.0
var confirm_ring := 0.0
var travel_blend := 0.0
var travel_marker_progress := 0.0
var arrival_flash := 0.0
var depart_shrink := 0.0
var panel_reveal := 0.0
var display_latitude := 0.0
var display_longitude := 0.0
var travel_distance_km := 0.0
var travel_bearing_degrees := 0.0
var travel_geo_from := Vector2.ZERO
var travel_geo_to := Vector2.ZERO

# view transform
var map_scale := 0.0
var user_scale := 0.0
var base_scale := 1.0
var view_initialized := false
var map_origin := Vector2.ZERO
var pan := Vector2.ZERO
var zoom_boost := 0.0
var travel_pan_from := Vector2.ZERO
var travel_pan_to := Vector2.ZERO
var confirm_pan_from := Vector2.ZERO
var confirm_pan_to := Vector2.ZERO
var dragging := false
var pinch_points: Dictionary = {}
var pinch_start_dist := -1.0
var pinch_start_scale := 1.0

var map_image: TextureRect
var map_material: ShaderMaterial
var overlay: Control
var info_panel: Control
var confirm_button: Button
var skip_button: Button
var back_button: Button
var home_button: Button
var status_label: Label
var headline_label: Label
var travel_hud: Panel
var travel_title_label: Label
var travel_coords_label: Label
var travel_meta_label: Label
var travel_progress_bar: ProgressBar
var panel_rows: Array = []   # [{labels:[Label], order:int}] for staggered reveal
var tutorial_overlay: Control
var tutorial_highlight: Panel
var tutorial_maya_portrait: TextureRect
var tutorial_copy: Label
var tutorial_step := 0
var tutorial_steps: Array = []


func _ready() -> void:
	InteractionFeedback.guidance_highlights_changed.connect(_on_guidance_highlights_changed)
	utc = Time.get_datetime_dict_from_system(true)
	home_site = GameManager.home_location()
	current_site = GameManager.observing_location()
	sites = GameManager.location_sites()
	map_target_id = GameManager.world_map_target_id
	if map_target_id == "":
		map_target_id = GameManager.selected_object_id
	if map_target_id == "":
		map_target_id = GameManager.current_target_object_id()
	GameManager.world_map_target_id = map_target_id
	radec = GameManager.object_radec(map_target_id)
	var service := SkyPositionService.new()
	minimum_altitude = float(service.config.get("minimum_visible_altitude_degrees", 10.0))
	var vis_now: Dictionary = GameManager.object_visibility(map_target_id)
	target_alt_now = float(vis_now.get("altitude", 0.0))
	target_below = bool(vis_now.get("below_horizon", false))
	target_low = (not target_below) and target_alt_now < comfortable_altitude
	# ALL site maths happens here, before a single frame of animation.
	_compute_all_visibility(service)
	recommended = _recommend_site()
	selected_id = str(recommended.get("site", {}).get("id", "")) if not recommended.is_empty() else ""
	_build_scan_order()
	_build()
	# Target already comfortably up: short confirm beat, no full search.
	if not target_below and not target_low:
		_set_phase(Phase.READY)
		resolved_count = scan_order.size()
		arc_progress = 1.0
		reveal = 1.0
	set_process(true)
	call_deferred("_show_first_map_tutorial")


func _reduced() -> bool:
	return InteractionFeedback.is_reduced_motion()


func _duration(p: int) -> float:
	var d := float(DURATIONS.get(p, 1.0))
	return d * (0.35 if _reduced() else 1.0)


func _compute_all_visibility(service: SkyPositionService) -> void:
	if radec.is_empty():
		return
	for site_value in sites:
		var site: Dictionary = site_value
		var v := service.visibility_at(float(radec["ra_hours"]), float(radec["dec_degrees"]), float(site.get("lat", 0.0)), float(site.get("lon", 0.0)), utc)
		var cloud_cover := _site_cloud_cover(site)
		var seeing := _site_seeing(site)
		site_visibility[str(site.get("id", ""))] = {
			"site": site,
			"altitude": float(v["altitude"]),
			"azimuth": float(v["azimuth"]),
			"visible": float(v["altitude"]) >= 0.0,
			"comfortable": float(v["altitude"]) >= comfortable_altitude,
			"direction_text": str(v["direction_text"]),
			"local_time": service.local_time_string(float(site.get("lon", 0.0)), utc),
			"visible_hours": service.visible_duration_hours(float(radec["ra_hours"]), float(radec["dec_degrees"]), float(site.get("lat", 0.0)), float(site.get("lon", 0.0)), utc),
			"cloud_cover": cloud_cover,
			"seeing": seeing
		}


func _recommend_site() -> Dictionary:
	var best: Dictionary = {}
	var fallback: Dictionary = {}
	var best_score := -INF
	var fallback_score := -INF
	for id_value in site_visibility.keys():
		var candidate: Dictionary = site_visibility[id_value]
		var altitude := float(candidate.get("altitude", -90.0))
		if altitude < 0.0:
			continue
		var site: Dictionary = candidate.get("site", {})
		var seeing_score: float = float({"excellent": 3.0, "good": 2.0, "average": 1.0}.get(str(candidate.get("seeing", "average")), 1.0))
		var score := altitude * 4.0 + (9.0 - float(site.get("bortle", 5))) * 6.0 + float(seeing_score) * 5.0 - float(candidate.get("cloud_cover", 0.25)) * 24.0
		if score > fallback_score:
			fallback_score = score
			fallback = candidate.duplicate(true)
		if altitude >= comfortable_altitude and score > best_score:
			best_score = score
			best = candidate.duplicate(true)
	return best if not best.is_empty() else fallback


func _site_cloud_cover(site: Dictionary) -> float:
	if site.has("cloud_cover"):
		return clampf(float(site.get("cloud_cover", 0.0)), 0.0, 1.0)
	var condition := str(site.get("condition_en", "")).to_lower()
	if "above the clouds" in condition or "driest" in condition or "dry summit" in condition:
		return 0.08
	if "clear" in condition or "crisp" in condition or "dry" in condition:
		return 0.14
	return 0.24


func _site_seeing(site: Dictionary) -> String:
	if site.has("seeing"):
		return str(site.get("seeing", "average")).to_lower()
	var condition := str(site.get("condition_en", "")).to_lower()
	if "excellent" in condition or "stable" in condition or "calm" in condition or "superb" in condition:
		return "excellent"
	if "clear" in condition or "dry" in condition or "crisp" in condition:
		return "good"
	return "average"


func _build_scan_order() -> void:
	# The scan wave resolves sites in order of distance from the current site.
	var cur := Vector2(float(current_site.get("lon", 0.0)), float(current_site.get("lat", 0.0)))
	var entries: Array = []
	for site_value in sites:
		var s: Dictionary = site_value
		var d := Vector2(float(s.get("lon", 0.0)), float(s.get("lat", 0.0))).distance_to(cur)
		entries.append({"id": str(s.get("id", "")), "d": d})
	entries.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	scan_order.clear()
	for e in entries:
		scan_order.append(str((e as Dictionary)["id"]))


# ------------------------------------------------------- view transform


func _recompute_view() -> void:
	# user_scale is the player's own zoom; zoom_boost is the animation's, applied
	# as a DERIVED factor so it can never compound frame over frame.
	base_scale = minf(MAP_AREA.size.x / MAP_SIZE.x, MAP_AREA.size.y / MAP_SIZE.y)
	if not view_initialized:
		user_scale = base_scale
		view_initialized = true
	user_scale = clampf(user_scale, base_scale, base_scale * 3.0)
	map_scale = user_scale * (1.0 + zoom_boost)
	var drawn := MAP_SIZE * map_scale
	map_origin = MAP_AREA.position + (MAP_AREA.size - drawn) * 0.5 + pan


func _image_to_screen(p: Vector2) -> Vector2:
	return map_origin + p * map_scale


func _geo_to_image(lat: float, lon: float) -> Vector2:
	var wrapped_lon := fposmod(lon + 180.0, 360.0) - 180.0
	# Preserve +180 at the map's right edge instead of wrapping it to -180.
	if is_equal_approx(lon, 180.0):
		wrapped_lon = 180.0
	var ix := MAP_PRIME_MERIDIAN_X
	if wrapped_lon < MAP_FAR_WEST_LONGITUDE:
		var pacific_t := inverse_lerp(-180.0, MAP_FAR_WEST_LONGITUDE, wrapped_lon)
		ix = lerpf(MAP_DATE_LINE_X, MAP_FAR_WEST_X, pacific_t)
	elif wrapped_lon < 0.0:
		ix += wrapped_lon * MAP_WEST_PX_PER_DEGREE
	else:
		ix += wrapped_lon * MAP_EAST_PX_PER_DEGREE
	var registered_lat := clampf(lat, MAP_SOUTH_LATITUDE, MAP_NORTH_LATITUDE)
	var iy := MAP_EQUATOR_Y
	if registered_lat >= 0.0:
		iy -= registered_lat * MAP_NORTH_PX_PER_DEGREE
	else:
		iy -= registered_lat * MAP_SOUTH_PX_PER_DEGREE
	return Vector2(ix, iy)


func _project(lat: float, lon: float) -> Vector2:
	return _image_to_screen(_geo_to_image(lat, lon))


func debug_image_position_for_coordinates(lat: float, lon: float) -> Vector2:
	return _geo_to_image(lat, lon)


# --------------------------------------------------------------- build


func _build() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("03050c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_recompute_view()
	map_image = TextureRect.new()
	map_image.name = "MapImage"
	map_image.texture = load(MAP_TEXTURE)
	map_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_image.stretch_mode = TextureRect.STRETCH_SCALE
	map_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_image.position = map_origin
	map_image.size = MAP_SIZE * map_scale
	# Circular "globe" reveal: the map opens out of a disc instead of a fade.
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.6) = 0.0;
uniform float travel : hint_range(0.0, 1.0) = 0.0;
uniform float arrival : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 1.78;
void fragment() {
	vec2 sample_uv = UV;
	float flight_wave = sin((UV.y * 24.0 + travel * 9.0) * 3.14159) * 0.0012 * travel * (1.0 - arrival);
	sample_uv.x += flight_wave;
	vec4 c = texture(TEXTURE, sample_uv);
	vec2 d = UV - vec2(0.5);
	d.x *= aspect;
	float r = length(d);
	float edge = smoothstep(reveal, reveal - 0.06, r);
	float rim = smoothstep(reveal - 0.02, reveal, r) * smoothstep(reveal + 0.05, reveal, r);
	c.rgb += vec3(0.55, 0.42, 0.16) * rim * 1.4;
	float scan = 1.0 - smoothstep(0.0, 0.055, abs(UV.y - fract(travel * 0.72 + 0.12)));
	c.rgb += vec3(0.10, 0.34, 0.46) * scan * travel * (1.0 - arrival) * 0.12;
	float vignette = 1.0 - smoothstep(0.22, 0.82, length(UV - vec2(0.5)));
	c.rgb *= mix(0.78, 1.0, vignette);
	c.rgb += vec3(0.95, 0.65, 0.22) * arrival * (1.0 - r) * 0.18;
	c.a *= edge;
	COLOR = c;
}"""
	map_material = ShaderMaterial.new()
	map_material.shader = shader
	map_material.set_shader_parameter("reveal", 0.0)
	map_material.set_shader_parameter("travel", 0.0)
	map_material.set_shader_parameter("arrival", 0.0)
	map_material.set_shader_parameter("aspect", MAP_SIZE.x / MAP_SIZE.y)
	map_image.material = map_material
	add_child(map_image)

	overlay = Control.new()
	overlay.name = "DynamicOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)

	headline_label = _label("", Vector2(20, 12), Vector2(744, 30), 21, RED, HORIZONTAL_ALIGNMENT_CENTER)
	status_label = _label("", Vector2(20, 44), Vector2(744, 42), 13, CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible = 2
	_refresh_headline()

	# This used to be a bare Control - a dozen text rows floating directly on
	# the map with no frame at all, which read as an unfinished debug overlay
	# rather than a real instrument readout.
	info_panel = Panel.new()
	info_panel.position = Vector2(784, 150)
	info_panel.size = Vector2(228, 452)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.020, 0.032, 0.058, 0.94)
	info_style.border_color = GOLD
	info_style.set_border_width_all(2)
	info_style.set_corner_radius_all(5)
	info_style.content_margin_left = 10.0
	info_style.content_margin_right = 10.0
	info_style.content_margin_top = 10.0
	info_style.content_margin_bottom = 10.0
	info_style.shadow_color = Color(0, 0, 0, 0.55)
	info_style.shadow_size = 14
	info_style.shadow_offset = Vector2(0, 5)
	info_panel.add_theme_stylebox_override("panel", info_style)
	add_child(info_panel)
	UiKit.add_bevel(self, Rect2(info_panel.position, info_panel.size))

	# Buttons live at FIXED positions and never move with the animation.
	confirm_button = _button(GameManager.text("Confirm Site", "确认地点"), Vector2(784, 614), Vector2(228, 46), GOLD)
	confirm_button.pressed.connect(_on_confirm)
	add_child(confirm_button)
	skip_button = _button(GameManager.text("Skip", "跳过"), Vector2(784, 668), Vector2(70, 34), Color(0.16, 0.20, 0.28))
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.pressed.connect(_skip_animation)
	add_child(skip_button)
	back_button = _button(GameManager.text("Back to Observation", "返回观星"), Vector2(862, 668), Vector2(150, 34), Color(0.16, 0.20, 0.28))
	back_button.add_theme_font_size_override("font_size", 11)
	back_button.pressed.connect(_on_back)
	add_child(back_button)
	home_button = _button(GameManager.text("Return Home", "返回默认地点"), Vector2(784, 710), Vector2(228, 34), Color(0.10, 0.14, 0.20))
	home_button.name = "ReturnHomeButton"
	home_button.add_theme_font_size_override("font_size", 12)
	home_button.visible = not GameManager.is_at_home_location()
	home_button.pressed.connect(_on_return_home)
	add_child(home_button)

	_build_site_buttons()
	_build_travel_hud()
	_refresh_info()


func _build_travel_hud() -> void:
	travel_hud = Panel.new()
	travel_hud.name = "TravelCoordinateHUD"
	travel_hud.position = Vector2(132, 600)
	travel_hud.size = Vector2(500, 76)
	travel_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_hud.z_index = 35
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.015, 0.026, 0.055, 0.94)
	hud_style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.86)
	hud_style.set_border_width_all(2)
	hud_style.set_corner_radius_all(4)
	hud_style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	hud_style.shadow_size = 7
	travel_hud.add_theme_stylebox_override("panel", hud_style)
	travel_hud.modulate.a = 0.0
	travel_hud.visible = false
	add_child(travel_hud)

	travel_title_label = Label.new()
	travel_title_label.position = Vector2(14, 7)
	travel_title_label.size = Vector2(472, 18)
	travel_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_title_label.add_theme_font_size_override("font_size", 11)
	travel_title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	travel_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_hud.add_child(travel_title_label)

	travel_coords_label = Label.new()
	travel_coords_label.position = Vector2(14, 25)
	travel_coords_label.size = Vector2(472, 22)
	travel_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_coords_label.add_theme_font_size_override("font_size", 16)
	travel_coords_label.add_theme_color_override("font_color", WHITE_DATA)
	travel_coords_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_hud.add_child(travel_coords_label)

	travel_meta_label = Label.new()
	travel_meta_label.position = Vector2(14, 47)
	travel_meta_label.size = Vector2(472, 15)
	travel_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_meta_label.add_theme_font_size_override("font_size", 10)
	travel_meta_label.add_theme_color_override("font_color", CYAN_BRIGHT)
	travel_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	travel_hud.add_child(travel_meta_label)

	travel_progress_bar = ProgressBar.new()
	travel_progress_bar.position = Vector2(14, 65)
	travel_progress_bar.size = Vector2(472, 4)
	travel_progress_bar.min_value = 0.0
	travel_progress_bar.max_value = 1.0
	travel_progress_bar.show_percentage = false
	travel_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_bg := StyleBoxFlat.new()
	progress_bg.bg_color = Color(0.10, 0.16, 0.24, 0.92)
	progress_bg.set_corner_radius_all(2)
	var progress_fill := StyleBoxFlat.new()
	progress_fill.bg_color = GOLD_BRIGHT
	progress_fill.set_corner_radius_all(2)
	travel_progress_bar.add_theme_stylebox_override("background", progress_bg)
	travel_progress_bar.add_theme_stylebox_override("fill", progress_fill)
	travel_hud.add_child(travel_progress_bar)


func _show_first_map_tutorial() -> void:
	if not GameManager.uses_full_tutorials() or not InteractionFeedback.guidance_highlights_enabled():
		return
	var seen: Array = GameManager.progress.get("seen_teaching_steps", [])
	if seen.has("world_map_controls_v1") or not is_inside_tree():
		return
	# Maya explains the existing map controls in place. This temporary overlay
	# disappears after the lesson and does not become another information panel.
	tutorial_steps = [
		{"rect": MAP_AREA, "pose": MayaPortrait.EXPLAIN, "en": "This map chooses where you observe. Earth's rotation and latitude decide whether a target has risen.", "zh": "世界地图用于选择观测地点。地球自转和纬度会决定目标是否已经升起。"},
		{"kind": "current", "pose": MayaPortrait.DISCOVER, "en": "The blue pulse marks your current observing site.", "zh": "蓝色脉冲标记表示当前观测地点。"},
		{"kind": "recommended", "pose": MayaPortrait.DISCOVER, "en": "The gold pulse marks a recommended site where the target is visible. The arc shows the travel direction.", "zh": "金色脉冲表示目标可见的推荐地点，弧线表示移动方向。"},
		{"rect": MAP_AREA, "pose": MayaPortrait.EMPHASIZE, "en": "Drag the map to pan. Use the mouse wheel or a two-finger pinch to zoom.", "zh": "拖动地图可以平移；使用鼠标滚轮或双指手势可以缩放。"},
		{"kind": "info", "pose": MayaPortrait.THINK, "en": "The site panel shows latitude, longitude, target altitude, azimuth, local time, visibility window and conditions.", "zh": "右侧地点栏显示经纬度、目标高度角、方位角、当地时间、可见时段和观测条件。"},
		{"kind": "confirm", "pose": MayaPortrait.EMPHASIZE, "en": "Select a site, then confirm it. The sky will be recalculated and you will return to Observation.", "zh": "选择地点后点击确认。系统会重新计算天空位置并返回观星界面。"},
		{"kind": "back", "pose": MayaPortrait.EXPLAIN, "en": "Back cancels without changing location. Return Home selects the default observing site.", "zh": "返回会取消选择且不改变地点；返回默认地点会切回基地观测点。"}
	]
	_build_map_tutorial_overlay()
	_show_map_tutorial_step(0)


func _build_map_tutorial_overlay() -> void:
	tutorial_overlay = Control.new()
	tutorial_overlay.name = "MayaMapTutorial"
	tutorial_overlay.add_to_group("guidance_highlight")
	tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.z_index = 500
	add_child(tutorial_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.68)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_overlay.add_child(dim)
	tutorial_highlight = Panel.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.0, 0.0, 0.0, 0.03)
	hs.border_color = GOLD_BRIGHT
	hs.set_border_width_all(3)
	hs.set_corner_radius_all(5)
	tutorial_highlight.add_theme_stylebox_override("panel", hs)
	tutorial_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_overlay.add_child(tutorial_highlight)
	var teaching := Panel.new()
	teaching.position = Vector2(126, 558)
	teaching.size = Vector2(624, 164)
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.025, 0.045, 0.08, 0.98)
	ts.border_color = GOLD
	ts.set_border_width_all(2)
	ts.set_corner_radius_all(5)
	teaching.add_theme_stylebox_override("panel", ts)
	tutorial_overlay.add_child(teaching)
	tutorial_maya_portrait = MayaPortrait.create(
		teaching,
		"MayaTutorialPortrait",
		MayaPortrait.EXPLAIN,
		Vector2(10, 8),
		Vector2(88, 146),
		1
	)
	var maya := Label.new()
	maya.text = GameManager.text("MAYA", "玛雅")
	maya.position = Vector2(104, 10)
	maya.size = Vector2(100, 26)
	maya.add_theme_font_size_override("font_size", 20)
	maya.add_theme_color_override("font_color", GOLD_BRIGHT)
	teaching.add_child(maya)
	tutorial_copy = Label.new()
	tutorial_copy.position = Vector2(104, 40)
	tutorial_copy.size = Vector2(500, 68)
	tutorial_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_copy.add_theme_font_size_override("font_size", 15)
	tutorial_copy.add_theme_color_override("font_color", TEXT)
	teaching.add_child(tutorial_copy)
	var next := _button(GameManager.text("Next", "下一步"), Vector2(448, 112), Vector2(156, 38), GOLD)
	next.name = "TutorialNextButton"
	next.pressed.connect(_advance_map_tutorial)
	teaching.add_child(next)


func _tutorial_rect(step: Dictionary) -> Rect2:
	match str(step.get("kind", "")):
		"current":
			var p := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
			return Rect2(p - Vector2(34, 34), Vector2(68, 68))
		"recommended":
			var site: Dictionary = recommended.get("site", current_site)
			var p := _project(float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
			return Rect2(p - Vector2(38, 38), Vector2(76, 76))
		"info": return Rect2(info_panel.position, info_panel.size)
		"confirm": return Rect2(confirm_button.position, confirm_button.size)
		"back": return Rect2(back_button.position, back_button.size)
	return step.get("rect", MAP_AREA)


func _show_map_tutorial_step(index: int) -> void:
	tutorial_step = clampi(index, 0, tutorial_steps.size() - 1)
	var step: Dictionary = tutorial_steps[tutorial_step]
	tutorial_copy.text = GameManager.text(str(step.get("en", "")), str(step.get("zh", "")))
	if tutorial_maya_portrait != null:
		MayaPortrait.apply_to(tutorial_maya_portrait, str(step.get("pose", MayaPortrait.EXPLAIN)))
	var rect := _tutorial_rect(step).grow(6.0)
	tutorial_highlight.position = rect.position
	tutorial_highlight.size = rect.size


func _advance_map_tutorial() -> void:
	if tutorial_step + 1 < tutorial_steps.size():
		_show_map_tutorial_step(tutorial_step + 1)
		return
	var seen: Array = GameManager.progress.get("seen_teaching_steps", [])
	if not seen.has("world_map_controls_v1"):
		seen.append("world_map_controls_v1")
		GameManager.progress["seen_teaching_steps"] = seen
		GameManager.record_horizon_lesson_if_first()
		GameManager.save()
	if tutorial_overlay != null:
		tutorial_overlay.queue_free()
	tutorial_overlay = null


func _on_guidance_highlights_changed(enabled: bool) -> void:
	if enabled or tutorial_overlay == null:
		return
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.queue_free()
	tutorial_overlay = null


func _refresh_headline() -> void:
	if headline_label == null:
		return
	if target_below:
		headline_label.text = GameManager.text("TARGET BELOW THE HORIZON", "目标位于地平线以下")
		headline_label.add_theme_color_override("font_color", RED)
	elif target_low:
		headline_label.text = GameManager.text("TARGET TOO LOW HERE", "目标在此高度过低")
		headline_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	else:
		headline_label.text = GameManager.text("CHANGE OBSERVATION SITE", "更换观测地点")
		headline_label.add_theme_color_override("font_color", GOLD)


func _build_site_buttons() -> void:
	for site_value in sites:
		var site: Dictionary = site_value
		var id := str(site.get("id", ""))
		var btn := Button.new()
		btn.name = "site_" + id
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(34, 34)
		btn.size = Vector2(34, 34)
		btn.tooltip_text = GameManager.dict_text(site, "name")
		btn.modulate = Color(1, 1, 1, 0)
		var captured := id
		btn.pressed.connect(func() -> void: _pick_site(captured))
		add_child(btn)


func _update_site_button_positions() -> void:
	var interactive := phase == Phase.READY or phase == Phase.SCAN or phase == Phase.FOUND or phase == Phase.ROUTE
	for site_value in sites:
		var site: Dictionary = site_value
		var btn := get_node_or_null(NodePath("site_" + str(site.get("id", "")))) as Button
		if btn == null:
			continue
		var p := _project(float(site.get("lat", 0.0)), float(site.get("lon", 0.0)))
		btn.position = p - Vector2(17, 17)
		btn.visible = interactive and MAP_AREA.has_point(p) and _is_resolved(str(site.get("id", "")))


func _is_resolved(id: String) -> bool:
	var idx := scan_order.find(id)
	return idx >= 0 and idx < resolved_count


func _pick_site(id: String) -> void:
	if not _is_resolved(id):
		return
	selected_id = id
	for site_value in sites:
		var site_id := str((site_value as Dictionary).get("id", ""))
		var site_button := get_node_or_null(NodePath("site_" + site_id)) as Control
		if site_button != null:
			InteractionFeedback.selection(site_button, site_id == selected_id, GOLD_BRIGHT, true, "site_selected")
	arc_progress = 0.0
	if phase == Phase.READY:
		_set_phase(Phase.ROUTE)
	_refresh_info()


# ------------------------------------------------------------ state machine


func _set_phase(p: int) -> void:
	phase = p
	phase_t = 0.0
	match p:
		Phase.INTRO:
			pass
		Phase.SCAN:
			scan_radius = 0.0
			resolved_count = 0
		Phase.FOUND:
			resolved_count = scan_order.size()
		Phase.ROUTE:
			arc_progress = 0.0
		Phase.READY:
			resolved_count = scan_order.size()
			arc_progress = 1.0
			travel_blend = 0.0
			travel_marker_progress = 0.0
			arrival_flash = 0.0
			zoom_boost = 0.0
		Phase.CONFIRM:
			confirm_ring = 0.0
			travel_blend = 0.0
			travel_marker_progress = 0.0
			arrival_flash = 0.0
			confirm_pan_from = pan
			confirm_pan_to = _pan_to_coordinates(
				float(current_site.get("lat", 0.0)),
				float(current_site.get("lon", 0.0))
			)
			_prepare_travel_coordinates()
		Phase.TRAVEL:
			travel_pan_from = pan
			travel_pan_to = _pan_to_center(selected_id)
			travel_blend = 0.0
			travel_marker_progress = 0.0
		Phase.DEPART:
			depart_shrink = 0.0
			arrival_flash = 1.0
	_update_status_text()
	_update_button_states()
	_update_travel_hud()


func _pan_to_center(id: String) -> Vector2:
	var v: Dictionary = site_visibility.get(id, {})
	var s: Dictionary = v.get("site", {})
	if s.is_empty():
		return pan
	return _pan_to_coordinates(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))


func _pan_to_coordinates(lat: float, lon: float) -> Vector2:
	# pan so the destination sits at the middle of the map area
	var target_img := _geo_to_image(lat, lon)
	var centre := MAP_AREA.position + MAP_AREA.size * 0.5
	var drawn := MAP_SIZE * map_scale
	var origin_wanted := centre - target_img * map_scale
	return origin_wanted - (MAP_AREA.position + (MAP_AREA.size - drawn) * 0.5)


func _prepare_travel_coordinates() -> void:
	var v: Dictionary = site_visibility.get(selected_id, {})
	var destination: Dictionary = v.get("site", {})
	travel_geo_from = Vector2(float(current_site.get("lon", 0.0)), float(current_site.get("lat", 0.0)))
	travel_geo_to = Vector2(float(destination.get("lon", 0.0)), float(destination.get("lat", 0.0)))
	display_longitude = travel_geo_from.x
	display_latitude = travel_geo_from.y
	travel_distance_km = _great_circle_distance_km(travel_geo_from.y, travel_geo_from.x, travel_geo_to.y, travel_geo_to.x)
	travel_bearing_degrees = _initial_bearing_degrees(travel_geo_from.y, travel_geo_from.x, travel_geo_to.y, travel_geo_to.x)


func _update_status_text() -> void:
	if status_label == null:
		return
	var t := ""
	var c := CYAN
	match phase:
		Phase.INTRO:
			t = GameManager.text("Searching for visible sites...", "正在寻找可观测地点……")
		Phase.SCAN:
			t = GameManager.text("Scanning the globe...", "正在扫描全球观测点……")
		Phase.FOUND:
			t = GameManager.text("Visible site found", "找到可观测地点")
			c = GOLD_BRIGHT
		Phase.ROUTE:
			t = GameManager.text("Calculating a new observing location...", "正在计算新的观测地点……")
		Phase.READY:
			var selected: Dictionary = site_visibility.get(selected_id, {})
			var site: Dictionary = selected.get("site", {})
			var target_object: Dictionary = GameManager.get_object(map_target_id)
			t = GameManager.text(
				"Recommended site: %s. %s will be %.1f° above the horizon.\nConfirm the site to travel there.",
				"推荐观测点：%s。在这里，%s 高度角为 %.1f°。\n点击确认地点即可前往。") % [
				GameManager.dict_text(site, "name"),
				GameManager.dict_text(target_object, "name"),
				float(selected.get("altitude", 0.0))]
			c = GOLD
		Phase.CONFIRM:
			t = GameManager.text("Route locked. Synchronizing coordinates...", "路线已锁定，正在同步坐标……")
			c = GOLD_BRIGHT
		Phase.TRAVEL:
			t = GameManager.text("Travelling to the observing site...", "正在前往观测地点……")
			c = GOLD_BRIGHT
		Phase.DEPART:
			t = GameManager.text("Coordinates synchronized. Target position recalculated.", "坐标同步完成，目标位置已重新计算。")
			c = GREEN
	status_label.text = t
	status_label.add_theme_color_override("font_color", c)


func _update_button_states() -> void:
	if confirm_button == null:
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	var can_confirm := phase == Phase.READY and bool(v.get("visible", false))
	confirm_button.disabled = not can_confirm
	if skip_button != null:
		skip_button.disabled = phase >= Phase.CONFIRM
	# Back is always available.


func _process(delta: float) -> void:
	anim_t += delta
	phase_t += delta
	var d := _duration(phase)

	match phase:
		Phase.INTRO:
			reveal = _ease_out(clampf(phase_t / d, 0.0, 1.0)) * 1.25
			if phase_t >= d:
				reveal = 1.25
				_set_phase(Phase.SCAN)
		Phase.SCAN:
			reveal = 1.25
			var k := clampf(phase_t / d, 0.0, 1.0)
			scan_radius = k * 1100.0
			resolved_count = int(round(k * float(scan_order.size())))
			if phase_t >= d:
				_set_phase(Phase.FOUND)
		Phase.FOUND:
			if phase_t >= d:
				_set_phase(Phase.ROUTE)
		Phase.ROUTE:
			arc_progress = _ease_out(clampf(phase_t / d, 0.0, 1.0))
			if phase_t >= d:
				arc_progress = 1.0
				_set_phase(Phase.READY)
		Phase.READY:
			pass
		Phase.CONFIRM:
			var k := clampf(phase_t / d, 0.0, 1.0)
			confirm_ring = _ease_out(k)
			pan = confirm_pan_from.lerp(confirm_pan_to, _smoother_step(k))
			zoom_boost = sin(k * PI) * 0.075 + k * 0.10
			if phase_t >= d:
				_set_phase(Phase.TRAVEL)
		Phase.TRAVEL:
			var raw := clampf(phase_t / d, 0.0, 1.0)
			travel_blend = _smoother_step(raw)
			travel_marker_progress = _ease_in_out_sine(raw)
			pan = travel_pan_from.lerp(travel_pan_to, travel_blend)
			if not _reduced():
				pan += Vector2(0.0, -18.0 * sin(raw * PI))
			# Pull back during the long middle leg, then settle decisively on
			# the destination. This keeps both endpoints legible.
			zoom_boost = 0.10 - sin(raw * PI) * 0.15 + pow(raw, 2.0) * 0.38
			var geo_t := _smoother_step(raw)
			display_latitude = lerpf(travel_geo_from.y, travel_geo_to.y, geo_t)
			display_longitude = _lerp_longitude(travel_geo_from.x, travel_geo_to.x, geo_t)
			arrival_flash = _ease_out(clampf((raw - 0.76) / 0.24, 0.0, 1.0))
			if status_label != null:
				status_label.text = GameManager.text(
					"Relocating observatory • %d%%" % roundi(raw * 100.0),
					"正在切换观测地点 • %d%%" % roundi(raw * 100.0)
				)
			if phase_t >= d:
				display_latitude = travel_geo_to.y
				display_longitude = travel_geo_to.x
				arrival_flash = 1.0
				_set_phase(Phase.DEPART)
		Phase.DEPART:
			depart_shrink = clampf(phase_t / d, 0.0, 1.0)
			arrival_flash = 1.0 - _ease_out(depart_shrink) * 0.82
			zoom_boost = 0.48 - _ease_in_out(depart_shrink) * 0.93
			reveal = 1.25 * (1.0 - _ease_in_out(depart_shrink))
			if phase_t >= d:
				_enter_sky()
				return

	panel_reveal = minf(panel_reveal + delta * (5.0 if _reduced() else 1.9), 1.0)
	for row_value in panel_rows:
		var row: Dictionary = row_value
		var node := row["node"] as Control
		if node != null and is_instance_valid(node):
			node.modulate = Color(1, 1, 1, clampf(panel_reveal * 14.0 - float(row["order"]), 0.0, 1.0))
	if map_material != null:
		map_material.set_shader_parameter("reveal", reveal)
		map_material.set_shader_parameter("travel", travel_blend if phase >= Phase.TRAVEL else 0.0)
		map_material.set_shader_parameter("arrival", arrival_flash)
	_recompute_view()
	if map_image != null:
		map_image.position = map_origin
		map_image.size = MAP_SIZE * map_scale
	_update_site_button_positions()
	_update_button_states()
	_update_travel_hud()
	_update_travel_chrome()
	if overlay != null:
		overlay.queue_redraw()


func _skip_animation() -> void:
	# Presentation only: the site maths already ran in _ready.
	if phase >= Phase.CONFIRM:
		return
	reveal = 1.25
	resolved_count = scan_order.size()
	arc_progress = 1.0
	panel_reveal = 1.0
	_set_phase(Phase.READY)


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


func _ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _smoother_step(t: float) -> float:
	var k := clampf(t, 0.0, 1.0)
	return k * k * k * (k * (k * 6.0 - 15.0) + 10.0)


func _ease_in_out_sine(t: float) -> float:
	return -(cos(PI * clampf(t, 0.0, 1.0)) - 1.0) * 0.5


func _update_travel_hud() -> void:
	if travel_hud == null:
		return
	var active := phase >= Phase.CONFIRM
	travel_hud.visible = active
	if not active:
		travel_hud.modulate.a = 0.0
		return
	var alpha := 1.0
	if phase == Phase.CONFIRM:
		alpha = clampf(confirm_ring * 1.8, 0.0, 1.0)
	elif phase == Phase.DEPART:
		alpha = 1.0 - _ease_in_out(depart_shrink)
	travel_hud.modulate.a = alpha
	travel_hud.position.y = 600.0 + (1.0 - alpha) * (4.0 if _reduced() else 12.0)

	match phase:
		Phase.CONFIRM:
			travel_title_label.text = GameManager.text("ROUTE LOCKED • COORDINATE HANDOFF", "路线锁定 • 坐标交接")
		Phase.TRAVEL:
			travel_title_label.text = GameManager.text("RELOCATING OBSERVATORY", "正在切换观测地点")
		_:
			travel_title_label.text = GameManager.text("COORDINATES SYNCHRONIZED", "坐标同步完成")

	travel_coords_label.text = GameManager.text(
		"LAT %s    LON %s" % [_latitude_text(display_latitude), _longitude_text(display_longitude)],
		"纬度 %s    经度 %s" % [_latitude_text(display_latitude), _longitude_text(display_longitude)]
	)
	var progress := 0.0
	if phase == Phase.TRAVEL:
		progress = travel_marker_progress
	elif phase == Phase.DEPART:
		progress = 1.0
	var remaining := maxi(0, roundi(travel_distance_km * (1.0 - progress)))
	travel_meta_label.text = GameManager.text(
		"%s • bearing %03d° • %s" % [
			_format_distance(remaining),
			roundi(travel_bearing_degrees),
			"target sky recalculating" if phase == Phase.TRAVEL else "target sky ready"
		],
		"%s • 航向 %03d° • %s" % [
			_format_distance(remaining),
			roundi(travel_bearing_degrees),
			"正在重新计算目标天空" if phase == Phase.TRAVEL else "目标天空已就绪"
		]
	)
	travel_progress_bar.value = progress


func _update_travel_chrome() -> void:
	var focus := 0.0
	if phase == Phase.CONFIRM:
		focus = clampf(confirm_ring, 0.0, 1.0) * 0.72
	elif phase >= Phase.TRAVEL:
		focus = 0.82
	if phase == Phase.DEPART:
		focus = lerpf(0.82, 1.0, depart_shrink)
	if info_panel != null:
		info_panel.modulate.a = lerpf(1.0, 0.28, focus)
	for control in [confirm_button, skip_button, back_button, home_button]:
		if control != null:
			(control as Control).modulate.a = lerpf(1.0, 0.18, focus)


func _latitude_text(value: float) -> String:
	return "%06.3f°%s" % [absf(value), "N" if value >= 0.0 else "S"]


func _longitude_text(value: float) -> String:
	return "%07.3f°%s" % [absf(value), "E" if value >= 0.0 else "W"]


func _format_distance(kilometres: int) -> String:
	var raw := str(kilometres)
	var grouped := ""
	while raw.length() > 3:
		grouped = "," + raw.right(3) + grouped
		raw = raw.left(raw.length() - 3)
	return raw + grouped + " km"


func _lerp_longitude(from_lon: float, to_lon: float, weight: float) -> float:
	var shortest := fposmod(to_lon - from_lon + 180.0, 360.0) - 180.0
	return wrapf(from_lon + shortest * weight, -180.0, 180.0)


func _great_circle_distance_km(from_lat: float, from_lon: float, to_lat: float, to_lon: float) -> float:
	var lat_a := deg_to_rad(from_lat)
	var lat_b := deg_to_rad(to_lat)
	var d_lat := lat_b - lat_a
	var d_lon := deg_to_rad(fposmod(to_lon - from_lon + 180.0, 360.0) - 180.0)
	var h := pow(sin(d_lat * 0.5), 2.0) + cos(lat_a) * cos(lat_b) * pow(sin(d_lon * 0.5), 2.0)
	return 6371.0 * 2.0 * atan2(sqrt(h), sqrt(maxf(1.0 - h, 0.0)))


func _initial_bearing_degrees(from_lat: float, from_lon: float, to_lat: float, to_lon: float) -> float:
	var lat_a := deg_to_rad(from_lat)
	var lat_b := deg_to_rad(to_lat)
	var d_lon := deg_to_rad(fposmod(to_lon - from_lon + 180.0, 360.0) - 180.0)
	var y := sin(d_lon) * cos(lat_b)
	var x := cos(lat_a) * sin(lat_b) - sin(lat_a) * cos(lat_b) * cos(d_lon)
	return fposmod(rad_to_deg(atan2(y, x)), 360.0)


# ------------------------------------------------------------------ input


func _gui_input(event: InputEvent) -> void:
	if phase >= Phase.CONFIRM:
		return  # camera is under animation control
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed and MAP_AREA.has_point(mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1.12)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / 1.12)
	elif event is InputEventMouseMotion and dragging:
		pan += (event as InputEventMouseMotion).relative
		_clamp_pan()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			pinch_points[t.index] = t.position
		else:
			pinch_points.erase(t.index)
			pinch_start_dist = -1.0
	elif event is InputEventScreenDrag:
		var dg := event as InputEventScreenDrag
		if pinch_points.has(dg.index):
			pinch_points[dg.index] = dg.position
		if pinch_points.size() >= 2:
			var keys: Array = pinch_points.keys()
			var span: float = (pinch_points[keys[0]] as Vector2).distance_to(pinch_points[keys[1]] as Vector2)
			if pinch_start_dist <= 0.0:
				pinch_start_dist = span
				pinch_start_scale = user_scale
			else:
				var c: Vector2 = ((pinch_points[keys[0]] as Vector2) + (pinch_points[keys[1]] as Vector2)) * 0.5
				_set_zoom(pinch_start_scale * (span / pinch_start_dist), c)
		else:
			pan += dg.relative
			_clamp_pan()


func _zoom_at(center: Vector2, factor: float) -> void:
	_set_zoom(map_scale * factor, center)


func _set_zoom(new_scale: float, center: Vector2) -> void:
	var before := (center - map_origin) / map_scale
	user_scale = clampf(new_scale, base_scale, base_scale * 3.0)
	_recompute_view()
	var after := (center - map_origin) / map_scale
	pan += (after - before) * map_scale
	_clamp_pan()


func _clamp_pan() -> void:
	var slack: Vector2 = (MAP_SIZE * map_scale - MAP_AREA.size) * 0.5
	slack.x = maxf(slack.x, 0.0)
	slack.y = maxf(slack.y, 0.0)
	pan.x = clampf(pan.x, -slack.x, slack.x)
	pan.y = clampf(pan.y, -slack.y, slack.y)
	_recompute_view()
	if map_image != null:
		map_image.position = map_origin
		map_image.size = MAP_SIZE * map_scale
	if overlay != null:
		overlay.queue_redraw()


# ---------------------------------------------------------------- drawing


func _draw_overlay() -> void:
	if overlay == null or reveal <= 0.02:
		return
	var font := get_theme_default_font()
	var fade: float = clampf(reveal / 1.25, 0.0, 1.0)
	_draw_terminator(fade)
	_draw_scan(font)
	_draw_route(font, fade)
	_draw_markers(font, fade)
	_draw_confirm_fx(font)


func _draw_terminator(fade: float) -> void:
	# Subtle day/night shading, drawn on the overlay (the artwork is untouched).
	var utc_hour := float(utc.get("hour", 0)) + float(utc.get("minute", 0)) / 60.0
	var night_lon := fposmod(180.0 - utc_hour * 15.0 + 180.0 + 180.0, 360.0) - 180.0
	var cols := 60
	for c in range(cols):
		var lon := -180.0 + (float(c) + 0.5) / float(cols) * 360.0
		var dlon := absf(fposmod(lon - night_lon + 180.0, 360.0) - 180.0)
		if dlon >= 90.0:
			continue
		var a := (1.0 - dlon / 90.0) * 0.22 * fade
		var x0 := _project(0.0, lon - 180.0 / float(cols)).x
		var x1 := _project(0.0, lon + 180.0 / float(cols)).x
		var top := _project(90.0, lon).y
		var bot := _project(-90.0, lon).y
		var r := Rect2(Vector2(x0, top), Vector2(maxf(x1 - x0, 1.5), bot - top))
		var clipped := r.intersection(MAP_AREA)
		if clipped.size.x > 0.0 and clipped.size.y > 0.0:
			overlay.draw_rect(clipped, Color(0.0, 0.02, 0.06, a))


func _draw_scan(font: Font) -> void:
	if phase != Phase.SCAN or scan_radius <= 0.0:
		return
	var origin := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	# expanding cyan scan wave
	for i in range(3):
		var r := scan_radius - float(i) * 42.0
		if r <= 0.0:
			continue
		var a: float = clampf(1.0 - r / 1100.0, 0.0, 1.0) * (0.5 - float(i) * 0.13)
		overlay.draw_arc(origin, r, 0.0, TAU, 64, Color(CYAN.r, CYAN.g, CYAN.b, a), 2.0)
	# scanning graticule rows sweeping down
	var sweep_y: float = MAP_AREA.position.y + fmod(anim_t * 300.0, MAP_AREA.size.y)
	overlay.draw_line(Vector2(MAP_AREA.position.x, sweep_y), Vector2(MAP_AREA.end.x, sweep_y), Color(CYAN.r, CYAN.g, CYAN.b, 0.22), 1.0)


func _draw_markers(font: Font, fade: float) -> void:
	# --- current site: blue pulse (3 beats during INTRO) ---
	var cur := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	if MAP_AREA.has_point(cur):
		var beat := sin(anim_t * 4.2)
		var fading_out: float = 1.0 - travel_blend
		_draw_marker(cur, CYAN_BRIGHT, 6.0, true, fade * fading_out)
		if phase <= Phase.ROUTE:
			# expanding confirmation rings
			var t: float = fmod(anim_t * 0.9, 1.0)
			overlay.draw_arc(cur, 8.0 + t * 26.0, 0.0, TAU, 32, Color(CYAN.r, CYAN.g, CYAN.b, (1.0 - t) * 0.55 * fade), 2.0)
		_draw_tag(font, cur + Vector2(11, -12), GameManager.dict_text(current_site, "name"), CYAN_BRIGHT, fade * fading_out)
		if phase <= Phase.FOUND:
			var alt_txt := GameManager.text("%s Alt: %s" % [GameManager.dict_text(GameManager.current_target(), "name"), _dms(target_alt_now)],
				"%s 高度：%s" % [GameManager.dict_text(GameManager.current_target(), "name"), _dms(target_alt_now)])
			_draw_tag(font, cur + Vector2(11, 4), alt_txt, WHITE_DATA, fade * fading_out)
			if target_below:
				_draw_tag(font, cur + Vector2(11, 20), GameManager.text("Below horizon", "地平线以下"), RED, fade * fading_out)

	# --- candidate sites, resolved progressively by the scan ---
	for i in range(scan_order.size()):
		var id: String = scan_order[i]
		if id == str(current_site.get("id", "")):
			continue
		var v: Dictionary = site_visibility.get(id, {})
		var s: Dictionary = v.get("site", {})
		if s.is_empty():
			continue
		var p := _project(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))
		if not MAP_AREA.has_point(p):
			continue
		var resolved := i < resolved_count
		var is_rec := id == str(recommended.get("site", {}).get("id", ""))
		var is_sel := id == selected_id
		var vis := bool(v.get("visible", false))
		var alpha := fade
		if phase >= Phase.TRAVEL and not is_sel:
			alpha *= (1.0 - travel_blend)        # others fade out while travelling
		if not resolved:
			# not yet reached by the scan: faint tick only
			overlay.draw_arc(p, 4.0, 0.0, TAU, 16, Color(SITE_DIM.r, SITE_DIM.g, SITE_DIM.b, 0.35 * alpha), 1.0)
			continue
		var color := SITE_DIM if not vis else Color(0.36, 0.60, 0.82)
		if is_rec:
			color = GOLD_BRIGHT
		_draw_marker(p, color, 6.0 if is_rec else 4.5, is_rec or is_sel, alpha)
		# brief Alt/Az preview as each candidate resolves
		if phase == Phase.SCAN and i >= resolved_count - 3:
			_draw_tag(font, p + Vector2(9, -9), "Alt %.0f°" % float(v.get("altitude", 0.0)), CYAN if vis else RED, alpha)
		elif is_rec or is_sel:
			_draw_tag(font, p + Vector2(10, -11), GameManager.dict_text(s, "name"), GOLD_BRIGHT if is_rec else CYAN, alpha)
		if is_sel and phase >= Phase.READY:
			overlay.draw_arc(p, 13.0 + sin(anim_t * 4.0) * 2.0, 0.0, TAU, 28, Color(GOLD.r, GOLD.g, GOLD.b, alpha), 2.0)


func _draw_route(font: Font, fade: float) -> void:
	if selected_id == "" or phase < Phase.ROUTE or arc_progress <= 0.0:
		return
	if _selected_site().is_empty():
		return
	var a := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	var last := a
	var segments := 52
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		if t > arc_progress:
			break
		var q := _route_point(t)
		if MAP_AREA.has_point(last) and MAP_AREA.has_point(q):
			# double-stroke: soft glow under a crisp core
			overlay.draw_line(last, q, Color(GOLD.r, GOLD.g, GOLD.b, 0.28 * fade), 5.0)
			overlay.draw_line(last, q, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.95 * fade), 1.8)
		last = q
	# travelling light head + trailing sparks
	if arc_progress < 1.0 and MAP_AREA.has_point(last):
		overlay.draw_circle(last, 4.0, GOLD_BRIGHT)
		overlay.draw_circle(last, 9.0, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.25))
		for k in range(4):
			var sp := last - (last - a).normalized() * float(k + 1) * 7.0
			if MAP_AREA.has_point(sp):
				overlay.draw_circle(sp, 1.4, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.42 - float(k) * 0.09))

	# During relocation, the observing-site beacon actually travels along the
	# route. A soft tail keeps it readable without covering country labels.
	if phase >= Phase.CONFIRM:
		for k in range(12, 0, -1):
			var tail_t := maxf(0.0, travel_marker_progress - float(k) * 0.014)
			var tail := _route_point(tail_t)
			if MAP_AREA.has_point(tail):
				var tail_alpha := (1.0 - float(k) / 13.0) * 0.36 * (1.0 - depart_shrink)
				overlay.draw_circle(tail, 1.2 + (12.0 - float(k)) * 0.08, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, tail_alpha))
		var traveller := _route_point(travel_marker_progress)
		if MAP_AREA.has_point(traveller):
			var pulse := 1.0 + sin(anim_t * 9.0) * 0.12
			overlay.draw_circle(traveller, 15.0 * pulse, Color(GOLD.r, GOLD.g, GOLD.b, 0.12 * (1.0 - depart_shrink)))
			overlay.draw_arc(traveller, 9.0 * pulse, 0.0, TAU, 24, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.92 * (1.0 - depart_shrink)), 2.0)
			overlay.draw_line(traveller + Vector2(-5, 0), traveller + Vector2(5, 0), Color.WHITE, 1.0)
			overlay.draw_line(traveller + Vector2(0, -5), traveller + Vector2(0, 5), Color.WHITE, 1.0)


func _selected_site() -> Dictionary:
	var v: Dictionary = site_visibility.get(selected_id, {})
	return v.get("site", {})


func _route_point(t: float) -> Vector2:
	var s := _selected_site()
	if s.is_empty():
		return Vector2.ZERO
	var a := _project(float(current_site.get("lat", 0.0)), float(current_site.get("lon", 0.0)))
	var b := _project(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))
	var distance := a.distance_to(b)
	var lift := clampf(distance * 0.34, 54.0, 170.0)
	var mid := (a + b) * 0.5 - Vector2(0.0, lift)
	var k := clampf(t, 0.0, 1.0)
	return a.lerp(mid, k).lerp(mid.lerp(b, k), k)


func _draw_confirm_fx(font: Font) -> void:
	if phase < Phase.CONFIRM or selected_id == "":
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	var s: Dictionary = v.get("site", {})
	if s.is_empty():
		return
	var p := _project(float(s.get("lat", 0.0)), float(s.get("lon", 0.0)))
	# expanding confirmation rings at the destination
	if phase == Phase.CONFIRM:
		for i in range(3):
			var t: float = clampf(confirm_ring - float(i) * 0.18, 0.0, 1.0)
			if t <= 0.0:
				continue
			overlay.draw_arc(p, 10.0 + t * 70.0, 0.0, TAU, 40, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, (1.0 - t) * 0.8), 2.5)
	# arrival burst
	if phase >= Phase.TRAVEL and MAP_AREA.has_point(p):
		var burst: float = clampf(arrival_flash, 0.0, 1.0)
		for i in range(10):
			var ang := TAU * float(i) / 10.0 + anim_t * 0.4
			var rr := 12.0 + burst * 30.0
			overlay.draw_line(p + Vector2(cos(ang), sin(ang)) * (rr - 8.0), p + Vector2(cos(ang), sin(ang)) * rr,
				Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, burst * 0.7), 2.0)
		_draw_marker(p, GOLD_BRIGHT, 8.0, true, 1.0)
	# big destination name during confirm/travel
	if phase >= Phase.CONFIRM:
		var name_alpha: float = clampf(confirm_ring * 1.4, 0.0, 1.0) * (1.0 - depart_shrink)
		var nm := GameManager.dict_text(s, "name")
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		overlay.draw_string(font, Vector2(MAP_AREA.position.x + (MAP_AREA.size.x - w) * 0.5, MAP_AREA.position.y + 44),
			nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, name_alpha))
		var sub := GameManager.text("Alt %.1f°   Az %.1f° %s   %s" % [float(v.get("altitude", 0.0)), float(v.get("azimuth", 0.0)), str(v.get("direction_text", "")), str(v.get("local_time", ""))],
			"高度 %.1f°   方位 %.1f° %s   当地 %s" % [float(v.get("altitude", 0.0)), float(v.get("azimuth", 0.0)), str(v.get("direction_text", "")), str(v.get("local_time", ""))])
		var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		overlay.draw_string(font, Vector2(MAP_AREA.position.x + (MAP_AREA.size.x - w2) * 0.5, MAP_AREA.position.y + 68),
			sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(WHITE_DATA.r, WHITE_DATA.g, WHITE_DATA.b, name_alpha))


func _draw_tag(font: Font, pos: Vector2, value: String, color: Color, alpha := 1.0) -> void:
	if alpha <= 0.02:
		return
	var w := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	overlay.draw_rect(Rect2(pos - Vector2(3, 11), Vector2(w + 6, 15)), Color(0.02, 0.03, 0.06, 0.7 * alpha))
	overlay.draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color.r, color.g, color.b, alpha))


func _draw_marker(p: Vector2, color: Color, r: float, pulse: bool, alpha := 1.0) -> void:
	if alpha <= 0.02:
		return
	var rr := r
	if pulse:
		rr = r + sin(anim_t * 4.0) * 1.8
		overlay.draw_circle(p, rr + 6.0, Color(color.r, color.g, color.b, 0.16 * alpha))
	overlay.draw_circle(p, rr, Color(color.r, color.g, color.b, alpha))
	overlay.draw_circle(p, rr * 0.42, Color(0.04, 0.06, 0.10, alpha))


func _dms(degrees: float) -> String:
	var sign_txt := "-" if degrees < 0.0 else ""
	var a := absf(degrees)
	var d := int(a)
	var m := int((a - float(d)) * 60.0)
	var s := int((((a - float(d)) * 60.0) - float(m)) * 60.0)
	return "%s%d° %02d' %02d\"" % [sign_txt, d, m, s]


# ------------------------------------------------------------------- panel


func _refresh_info() -> void:
	if info_panel == null:
		return
	for child in info_panel.get_children():
		child.queue_free()
	panel_rows.clear()
	var v: Dictionary = site_visibility.get(selected_id, {})
	var site: Dictionary = v.get("site", {})
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(10, 8)
	scroll.size = Vector2(208, 436)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(196, 0)
	body.add_theme_constant_override("separation", 4)
	scroll.add_child(body)

	_prow(body, GameManager.text("SELECTED SITE", "选中地点"), "", GOLD, 13, 0)
	if site.is_empty():
		_prow(body, GameManager.text("Scanning...", "扫描中……"), "", DIM, 12, 1)
		return
	var is_rec := str(site.get("id", "")) == str(recommended.get("site", {}).get("id", ""))
	var target_object: Dictionary = GameManager.get_object(map_target_id)
	var free_observation := map_target_id != GameManager.current_target_object_id()
	_prow(body, GameManager.text("FREE OBSERVATION", "自由观测") if free_observation else GameManager.text("MISSION TARGET", "任务目标"), "", CYAN if free_observation else GOLD, 12, 1)
	_prow(body, GameManager.text("Observing target", "观测目标"), GameManager.dict_text(target_object, "name"), CYAN, 11, 1)
	_prow(body, GameManager.text("Current site", "当前地点"), GameManager.dict_text(current_site, "name"), DIM, 11, 2)
	_prow(body, GameManager.text("Current target Alt", "当前目标高度角"), "%.1f°" % target_alt_now, RED if target_below else TEXT, 11, 3)
	_pdivider(body)
	_prow(body, GameManager.dict_text(site, "name"), "", GOLD_BRIGHT, 16, 1)
	_prow(body, GameManager.dict_text(site, "country"), "", DIM, 11, 2)
	_pdivider(body)
	var rows := [
		[GameManager.text("Latitude", "纬度"), "%.2f°" % float(site.get("lat", 0.0))],
		[GameManager.text("Longitude", "经度"), "%.2f°" % float(site.get("lon", 0.0))],
		[GameManager.text("Target Alt", "目标高度角"), "%.1f°" % float(v.get("altitude", 0.0))],
		[GameManager.text("Target Az", "目标方位角"), "%.1f° %s" % [float(v.get("azimuth", 0.0)), str(v.get("direction_text", ""))]],
		[GameManager.text("Local time", "当地时间"), str(v.get("local_time", "--:--"))],
		[GameManager.text("Visible for", "可见时长"), "%.1f h" % float(v.get("visible_hours", 0.0))],
	]
	var step := 3
	for row in rows:
		_prow(body, str(row[0]), str(row[1]), TEXT, 11, step)
		step += 1
	_pdivider(body)
	var condition_rows := [
		[GameManager.text("Sky quality", "天空条件"), "Bortle %d" % int(site.get("bortle", 5))],
		[GameManager.text("Conditions", "观测条件"), GameManager.dict_text(site, "condition")],
		[GameManager.text("Cloud cover", "云量"), "%d%% (%s)" % [int(round(float(v.get("cloud_cover", 0.0)) * 100.0)), GameManager.text("local site estimate", "本地站点估计")]],
		[GameManager.text("Seeing", "视宁度"), str(v.get("seeing", "average")).capitalize()],
	]
	for row in condition_rows:
		_prow(body, str(row[0]), str(row[1]), TEXT, 11, step)
		step += 1
	_pdivider(body)
	var vis := bool(v.get("visible", false))
	var comfort := bool(v.get("comfortable", false))
	var visibility_text := GameManager.text("Comfortably above the horizon", "适合观测") if comfort else GameManager.text("Above the horizon, but low", "已升起，但高度较低")
	if not vis:
		visibility_text = GameManager.text("Below the horizon here", "在此地点位于地平线以下")
	_prow(body, ("★ " if is_rec else "") + visibility_text, "", GREEN if comfort else (GOLD if vis else RED), 12, step + 1)
	if is_rec:
		_prow(body, GameManager.text("Recommended site", "推荐观测点"), GameManager.dict_text(site, "name"), GOLD_BRIGHT, 12, step + 2)
		_prow(body,
			GameManager.text("The target will be %.1f° above the horizon.", "目标在这里的高度角为 %.1f°。") % float(v.get("altitude", 0.0)),
			"", TEXT, 11, step + 3)


func _pdivider(parent: Control) -> void:
	# A quiet hairline instead of another text row - the panel used to be one
	# unbroken stack of a dozen key/value pairs with no visual grouping at all.
	var line := ColorRect.new()
	line.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.22)
	line.custom_minimum_size = Vector2(196, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(196, 2)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)


func _prow(parent: Control, key: String, value: String, color: Color, size_px: int, order: int) -> void:
	# Staggered reveal: rows are registered and their alpha is animated in
	# _process, so the reveal actually plays instead of freezing at build time.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", size_px)
	k.add_theme_color_override("font_color", color)
	k.custom_minimum_size = Vector2(210, 0)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(k)
	if value != "":
		var val := Label.new()
		val.text = value
		val.add_theme_font_size_override("font_size", 12)
		val.add_theme_color_override("font_color", WHITE_DATA)
		val.custom_minimum_size = Vector2(210, 0)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(val)
	parent.add_child(box)
	box.modulate = Color(1, 1, 1, 0)
	panel_rows.append({"node": box, "order": order})


# ----------------------------------------------------------------- actions


func _on_confirm() -> void:
	if phase != Phase.READY:
		return
	var v: Dictionary = site_visibility.get(selected_id, {})
	if v.is_empty() or not bool(v.get("visible", false)):
		return
	InteractionFeedback.success(confirm_button, "site_confirmed")
	_set_phase(Phase.CONFIRM)


func _enter_sky() -> void:
	var v: Dictionary = site_visibility.get(selected_id, {})
	var site: Dictionary = v.get("site", {})
	if site.is_empty():
		GameManager.return_from_world_map()
		return
	GameManager.set_observing_location(site)
	GameManager.world_map_arrival_context = {
		"target_id": map_target_id,
		"site_id": str(site.get("id", "")),
		"site_name_en": str(site.get("name_en", "")),
		"site_name_zh": str(site.get("name_zh", "")),
		"altitude": float(v.get("altitude", 0.0)),
		"azimuth": float(v.get("azimuth", 0.0)),
		"free_observation": map_target_id != GameManager.current_target_object_id()
	}
	GameManager.record_horizon_lesson_if_first()
	GameManager.return_from_world_map()


func _on_back() -> void:
	# Never clears the target, the save, or the observing location. Cancelling a
	# below-horizon prompt returns to the exact entry point that opened the map.
	GameManager.return_from_world_map()


func _on_return_home() -> void:
	if GameManager.is_at_home_location():
		return
	GameManager.reset_observing_location()
	# Returning home is an explicit player decision. Let Sky show Below Horizon
	# guidance once instead of immediately bouncing back into this map.
	GameManager.suppress_next_world_map_redirect = true
	GameManager.return_from_world_map()


# ----------------------------------------------------------------- helpers


func _label(value: String, pos: Vector2, sz: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = sz
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _button(value: String, pos: Vector2, sz: Vector2, tint: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.size = sz
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = tint.darkened(0.5)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = tint.darkened(0.3)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate()
	pressed.bg_color = tint.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := style.duplicate()
	disabled.bg_color = Color(0.07, 0.09, 0.13)
	disabled.border_color = Color(0.28, 0.32, 0.38)
	button.add_theme_stylebox_override("disabled", disabled)
	InteractionFeedback.bind_button(button)
	return button
