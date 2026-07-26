extends Control

# Sky Observation — three-stage observing flow.
#
#   1 Naked Eye  (120° x 70°)  scan the sky, bright objects only
#   2 Finder     (28° x 18°)   aim precisely, targets stay small dots
#   3 Telescope  (6° x 4°)     center the target, then enter Telescope View
#
# The view is a rotatable alt/az window with a graduated azimuth scale on
# top (N/E/S/W + degree numbers) and an altitude scale on the left. All
# angles display as DMS. Real positions come from SkyPositionService
# (AstronomyAPI online, local RA/Dec, or offline fallback).

const W := 1024.0
const H := 768.0
const BG_TEXTURE := "res://assets/reference/sky_observation_ui_bg_v2_1024.png"
const MODE_BUTTONS_TEXTURE := "res://assets/reference/sky_view_mode_cards.png"
const BRIGHT_STARS_PATH := "res://data/bright_stars.json"
const SkyPositionServiceScript := preload("res://scripts/systems/sky_position_service.gd")
const OPTICAL_LENS_SHADER := preload("res://shaders/optical_lens.gdshader")
const ICON_DIR := "res://assets/celestial_icons/"
const OBS_UI_DIR := "res://assets/ui/observation/suc/processed/"
const AZ_SCALE_TEXTURE := OBS_UI_DIR + "azimuth_scale_shell.png"
const ALT_SCALE_TEXTURE := OBS_UI_DIR + "altitude_scale_shell.png"
const AZ_TICK_MAJOR_TEXTURE := OBS_UI_DIR + "azimuth_tick_major.png"
const AZ_TICK_MINOR_TEXTURE := OBS_UI_DIR + "azimuth_tick_minor.png"
const ALT_TICK_MAJOR_TEXTURE := OBS_UI_DIR + "altitude_tick_major.png"
const ALT_TICK_MINOR_TEXTURE := OBS_UI_DIR + "altitude_tick_minor.png"
const AZ_POINTER_TEXTURE := OBS_UI_DIR + "azimuth_pointer.png"
const ALT_POINTER_TEXTURE := OBS_UI_DIR + "altitude_pointer.png"
const APPROACH_RING_TEXTURE := OBS_UI_DIR + "target_approach_ring.png"
const LOCK_RING_TEXTURE := OBS_UI_DIR + "target_lock_ring.png"
const MODE_RETICLE_TEXTURES := {
	"naked_eye": OBS_UI_DIR + "eye_precise_reticle.png",
	"finder": OBS_UI_DIR + "finder_second_ring.png",
	"telescope": OBS_UI_DIR + "scope_center_tolerance.png"
}

const Z_SKY := 0
const Z_STARS := 18
const Z_OBJECTS := 20
# Atmospheric art remains below catalog stars and target icons. Cloud strength
# still feeds the existing visibility/quality code, but the texture itself can
# no longer paint an opaque rectangle over a target.
const Z_ATMOSPHERE := 14
# The search-window lens bends the background star field and environment, but
# stays below clickable catalog objects so their visual and hit rects cannot
# diverge near the curved edge.
const Z_OPTICAL_GLASS := 19
const Z_TARGET_FEEDBACK := 60
const Z_AIM_OVERLAY := 70
const Z_DYNAMIC_READOUT := 75
const Z_GUIDANCE := 80

# Layout for the v2 mockup background: the baked crosshair + reticle ring
# are centered at (403, 383), so VIEW_RECT is symmetric around that point.
const VIEW_RECT := Rect2(88, 103, 630, 560)
# The aiming artwork shares the projection center at (315, 280), while its
# outer edge stops above the guidance band at the bottom of the sky window.
const AIM_RETICLE_RECT := Rect2(110, 75, 410, 410)
const AZ_BAND := Rect2(94, 42, 602, 42)
const ALT_BAND := Rect2(23, 120, 44, 530)
const AZ_SCALE_ART_RECT := Rect2(80, 33, 630, 66)
const ALT_SCALE_ART_RECT := Rect2(8, 103, 76, 560)
const OBSERVE_RECT := Rect2(760, 570, 238, 84)
const BACK_RECT := Rect2(760, 668, 238, 72)
const MODE_BUTTONS_OVERLAY_RECT := Rect2(754, 486, 250, 76)
const MODE_RECTS := {
	"naked_eye": Rect2(756, 488, 72, 72),
	"finder": Rect2(843, 488, 72, 72),
	"telescope": Rect2(930, 488, 72, 72)
}
const MODE_SOURCE_RECTS := {
	"naked_eye": Rect2(108, 86, 560, 520),
	"finder": Rect2(700, 86, 560, 520),
	"telescope": Rect2(1294, 86, 560, 520)
}

const PANEL_COVER := Color(0.026, 0.048, 0.080, 1.0)
const SKY_BG := Color(0.006, 0.013, 0.035, 1.0)
const BAND_BG := Color(0.020, 0.034, 0.062, 1.0)
const TEXT := Color(0.96, 0.92, 0.82)
const GOLD := Color(0.96, 0.72, 0.30)
const CYAN := Color(0.30, 0.84, 1.0)
const GREEN := Color(0.42, 0.95, 0.50)
const MUTED := Color(0.72, 0.78, 0.84)
const WARNING := Color(1.0, 0.72, 0.35)
const CROSSHAIR := Color(0.45, 0.78, 1.0, 0.30)
const FINDER_ASSIST := Color(0.45, 0.78, 1.0, 0.55)
const GROUND_COLOR := Color(0.018, 0.040, 0.026, 1.0)
const HORIZON_COLOR := Color(0.42, 0.62, 0.44, 0.75)

const AZIMUTH_SPEED := 45.0
const ALTITUDE_SPEED := 32.0
const MINIMUM_VISIBLE_ALTITUDE := 10.0
const COMFORTABLE_OBSERVING_ALTITUDE := 18.0
const STAR_POOL_SIZE := 320
const AZ_TICK_POOL := 64
const AZ_LABEL_POOL := 16
const ALT_TICK_POOL := 40
const ALT_LABEL_POOL := 12

const CENTER_TOLERANCE_FINDER := 2.0
const CENTER_TOLERANCE_TELESCOPE := 0.5
const EYE_LOCK_RADIUS_PX := 64.0
const FAINT_MISSION_WAYPOINT_DIAMETER := 40.0
const CONSTELLATION_SPAN_AZIMUTH := 26.0
const CONSTELLATION_SPAN_ALTITUDE := 18.0

const CALIBRATE_STEP_DEGREES := 0.1
const CALIBRATE_REPEAT_DELAY := 0.09
const CALIBRATE_RECT := Rect2(148, 668, 460, 46)

# L16 "Narrow Field Problem": how long / how much aimless movement in the
# telescope before Maya's stronger reminder panel appears (once per visit).
const WORKFLOW_LOST_SECONDS := 45.0
const WORKFLOW_LOST_MOVES := 25

# fov_x / fov_y per view mode.
const VIEW_MODES := {
	"naked_eye": {"fov_x": 120.0, "fov_y": 70.0, "en": "Naked Eye", "zh": "肉眼"},
	"finder": {"fov_x": 28.0, "fov_y": 18.0, "en": "Finder", "zh": "寻星镜"},
	"telescope": {"fov_x": 6.0, "fov_y": 4.0, "en": "Telescope", "zh": "望远镜"}
}

# Rendered target size in pixels per mode and object category.
# Wide FOV means objects look SMALLER, not bigger; resolved detail images
# exist only in the Telescope View scene.
const RENDER_SIZES := {
	"naked_eye": {"star": 2.0, "planet": 4.0, "moon": 18.0, "deep_sky": 10.0},
	"finder": {"star": 3.0, "planet": 6.0, "moon": 34.0, "deep_sky": 18.0},
	"telescope": {"star": 6.0, "planet": 12.0, "moon": 52.0, "deep_sky": 40.0}
}


class ModeCardArt extends Control:
	var source_texture: Texture2D
	var source_region: Rect2

	func _draw() -> void:
		if source_texture != null:
			draw_texture_rect_region(source_texture, Rect2(Vector2.ZERO, size), source_region)


class OpticalModeTransition extends Control:
	var progress := 1.0:
		set(value):
			progress = value
			queue_redraw()
	var zooming_in := true
	var active := false:
		set(value):
			active = value
			visible = value
			queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var eased := progress * progress * (3.0 - 2.0 * progress)
		var center := size * 0.5
		var outer := size.length() * 0.52
		var radius := lerpf(outer * 0.88, outer * 0.16, eased) if zooming_in else lerpf(outer * 0.16, outer * 0.88, eased)
		var envelope := sin(progress * PI)
		var cyan := Color(0.42, 0.90, 1.0, envelope * 0.70)
		var gold := Color(1.0, 0.74, 0.28, envelope * 0.46)
		draw_arc(center, maxf(12.0, radius), 0.0, TAU, 72, cyan, 2.0)
		draw_arc(center, maxf(18.0, radius + 8.0), 0.0, TAU, 72, gold, 1.0)
		var arm := clampf(radius * 0.16, 8.0, 28.0)
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.RIGHT.rotated(angle)
			var start := center + direction * maxf(10.0, radius - arm * 0.5)
			draw_line(start, start + direction * arm, cyan, 1.0)


class EdgeNavigationTrail extends Control:
	var target_direction := Vector2.RIGHT
	var panel_rect := Rect2()
	var accent := Color(1.0, 0.72, 0.30)

	func update_trail(direction: Vector2, next_panel_rect: Rect2, next_accent: Color) -> void:
		target_direction = direction
		panel_rect = next_panel_rect
		accent = next_accent
		queue_redraw()

	func _draw() -> void:
		if panel_rect.size == Vector2.ZERO:
			return
		var center := size * 0.5
		var panel_center := panel_rect.get_center()
		var end := panel_center - target_direction * 28.0
		var start := center + target_direction * 76.0
		var distance := start.distance_to(end)
		if distance <= 26.0:
			return
		var segment_count := clampi(roundi(distance / 34.0), 3, 12)
		for index in range(segment_count):
			var t0 := float(index) / float(segment_count)
			var t1 := minf(1.0, t0 + 0.42 / float(segment_count))
			var alpha := lerpf(0.12, 0.52, float(index + 1) / float(segment_count))
			draw_line(start.lerp(end, t0), start.lerp(end, t1), Color(accent.r, accent.g, accent.b, alpha), 1.0)


class ConstellationPatternOverlay extends Control:
	var positions: Array[Vector2] = []
	var magnitudes: Array[float] = []
	var marker_rect := Rect2()
	var feedback_state := ""

	func update_pattern(next_positions: Array[Vector2], next_magnitudes: Array[float], next_marker_rect: Rect2, next_feedback_state: String) -> void:
		positions = next_positions
		magnitudes = next_magnitudes
		marker_rect = next_marker_rect
		feedback_state = next_feedback_state
		queue_redraw()

	func _draw() -> void:
		for index in range(positions.size()):
			var magnitude := magnitudes[index] if index < magnitudes.size() else 2.0
			var radius := clampf(4.8 - magnitude * 0.8, 1.8, 4.0)
			draw_circle(positions[index], radius * 2.4, Color(0.60, 0.78, 1.0, 0.16))
			draw_circle(positions[index], radius, Color(0.96, 0.97, 1.0, 0.95))
		if feedback_state == "":
			return
		var color := Color(0.35, 0.86, 1.0, 0.80) if feedback_state == "approach" else Color(1.0, 0.78, 0.34, 0.95)
		var rect := marker_rect.grow(10.0)
		var arm := minf(22.0, minf(rect.size.x, rect.size.y) * 0.28)
		for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
			var sx := 1.0 if corner.x == rect.position.x else -1.0
			var sy := 1.0 if corner.y == rect.position.y else -1.0
			draw_line(corner, corner + Vector2(sx * arm, 0.0), color, 1.5)
			draw_line(corner, corner + Vector2(0.0, sy * arm), color, 1.5)


class FaintMissionTargetWaypoint extends Control:
	var accent := CYAN
	var locked := false

	func configure(next_diameter: float, next_accent: Color, next_locked: bool) -> void:
		size = Vector2.ONE * next_diameter
		pivot_offset = size * 0.5
		accent = next_accent
		locked = next_locked
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius := maxf(3.0, minf(size.x, size.y) * 0.5 - 2.0)
		var color := Color(accent.r, accent.g, accent.b, 0.98 if locked else 0.86)
		draw_arc(center, radius, 0.0, TAU, 48, color, 1.5, true)
		var notch_inner := radius - 4.0
		var notch_outer := radius + 1.0
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(center + direction * notch_inner, center + direction * notch_outer, color, 1.5, true)


var telescope_azimuth := 180.0
var telescope_altitude := 45.0
var view_mode := "naked_eye"
var fov_x := 120.0
var fov_y := 70.0
var display_azimuth := 180.0
var display_altitude := 45.0
var display_fov_x := 120.0
var display_fov_y := 70.0
var observation_mode := "telescope"
var selected_object_id := ""
var target_id := ""
var sky_service: RefCounted
var sky_data: Dictionary = {}
var observation_time_utc: Dictionary = {}
var in_view_targets: Dictionary = {}

var view_layer: Control
var optical_lens_overlay: ColorRect
var optical_lens_material: ShaderMaterial
var az_band_layer: Control
var alt_band_layer: Control
var star_points: Array[Vector4] = []
var star_pool: Array[ColorRect] = []
var object_icons: Dictionary = {}
var object_buttons: Dictionary = {}
var selection_frame: Control
var assist_frame: Control
var ground_rect: ColorRect
var horizon_line: ColorRect
var view_mode_caption: Label
var az_ticks: Array[TextureRect] = []
var az_labels: Array[Label] = []
var alt_ticks: Array[TextureRect] = []
var alt_labels: Array[Label] = []
var az_readout: Label
var alt_readout: Label
var guidance_banner: Label
var guidance_banner_bg: ColorRect
var controls_help: Label
var scope_reticle_layer: Control
var optical_mode_transition: OpticalModeTransition
var mode_transition_tween: Tween
var reticle_transition_ghost: TextureRect
var mode_content_alpha := 1.0
var mode_buttons: Dictionary = {}
var az_target_pointer: TextureRect
var alt_target_pointer: TextureRect
var az_knob_icon: TextureRect
var alt_knob_icon: TextureRect
var _knob_last_azimuth := 0.0
var _knob_last_altitude := 0.0
var aim_velocity_az := 0.0
var aim_velocity_alt := 0.0
var fov_spring_vel_x := 0.0
var fov_spring_vel_y := 0.0
var pinch_points: Dictionary = {}
var pinch_start_distance := -1.0
var _az_knob_activity := 0.0
var _alt_knob_activity := 0.0
var target_state_ring: TextureRect
var target_lock_state := "search"
var edge_target_indicator: Panel
var edge_target_arrow: Polygon2D
var edge_target_name: Label
var edge_target_delta: Label
var edge_target_tween: Tween
var edge_target_object_id := ""
var edge_target_state := "hidden"
var edge_target_transition_serial := 0
var edge_navigation_trail: EdgeNavigationTrail
var faint_mission_target_waypoint: FaintMissionTargetWaypoint
var faint_mission_target_waypoint_id := ""
var constellation_overlay: ConstellationPatternOverlay
var constellation_target_button: Button
var mouse_aim_dragging := false
var mouse_aim_press_position := Vector2.ZERO
var mouse_aim_drag_distance := 0.0
var touch_press_points: Dictionary = {}
var observe_button: Button
var observe_disabled_shade: ColorRect
var observe_transition_active := false
var calibration_success_played := false
var previous_calibration_percent := -1.0

# --- E3 sky-realism: background lift, cloud drift, star twinkle. All
# purely visual; the star magnitude filter is the only thing that changes
# what CAN be picked, and it mirrors the aim/select logic exactly.
var sky_lift_layer: ColorRect
var cloud_layer: Control
var cloud_nodes: Array[TextureRect] = []
# Clouds are anchored to SKY coordinates (azimuth, altitude in degrees) and
# reprojected to the screen every frame - panning the telescope slides them
# together with the stars. Velocities are angular (deg/s wind).
var cloud_sky_anchors: Array[Vector2] = []
var cloud_velocities: Array[Vector2] = []
var twinkle_seed := 0.0
const SKY_CLOUD_TEXTURES := [
	"res://assets/telescope_view/cloud_wisp_a.png",
	"res://assets/telescope_view/cloud_wisp_b.png",
	"res://assets/telescope_view/cloud_wisp_c.png"
]
const SKY_CLOUD_SCALE := 1.8
const TWINKLE_STAR_COUNT := 40

var mission_tonight_label: Label
var sky_condition_label: Label
var aim_label: Label
var selected_title: Label
var selected_badge: Label
var selected_panel_border: Panel
var selected_detail: Label
var guidance_label: Label
var visited_modes: Dictionary = {}

var calibration_panel: Control
var calibration_pct_label: Label
var calibration_hint_label: Label
var calibration_progress_fill: ColorRect
var calibrate_repeat_timer := 0.0
var calibration_steps_banner: Control
var calibration_step_labels: Array = []

var workflow_elapsed := 0.0
var workflow_move_count := 0
var workflow_move_tick := 0
var workflow_prompt_shown := false
var location_transition_active := false
var horizon_explanation_active := false
var horizon_explanation_layer: Control
var horizon_explanation_tween: Tween
var horizon_skip_button: Button
var low_altitude_notice_active := false
var arrival_hint_until := 0


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	if str(GameManager.current_level().get("variation", "")) == "finder_calibration":
		GameManager.seed_finder_offset_if_needed()
	target_id = GameManager.current_target_object_id()
	observation_mode = GameManager.current_observation_mode()
	# A world-map detour and a return from Telescope View must not silently throw
	# away a free-observation selection. Keep it only when it belongs to a real
	# catalog object; the normal mission panel still defaults to target_id.
	var current_level_number := int(GameManager.progress.get("current_level", 1))
	if GameManager.selected_object_level != current_level_number:
		GameManager.selected_object_id = target_id
		GameManager.selected_object_level = current_level_number
	selected_object_id = GameManager.selected_object_id
	if selected_object_id != "" and GameManager.get_object(selected_object_id).is_empty():
		selected_object_id = ""
		GameManager.selected_object_id = ""
	if selected_object_id == "":
		selected_object_id = target_id
		GameManager.selected_object_id = target_id
	GameManager.selected_object_level = current_level_number
	view_mode = "naked_eye"
	# Restore the aim from the previous visit instead of resetting to south.
	var saved_aim: Dictionary = GameManager.last_sky_aim
	if bool(saved_aim.get("valid", false)):
		telescope_azimuth = wrapf(float(saved_aim.get("azimuth", 180.0)), 0.0, 360.0)
		telescope_altitude = clampf(float(saved_aim.get("altitude", 45.0)), 0.0, 90.0)
		var saved_mode := str(saved_aim.get("view_mode", "naked_eye"))
		if bool(_mode_available(saved_mode).get("ok", false)):
			view_mode = saved_mode
	visited_modes[view_mode] = true
	_apply_view_mode()
	display_azimuth = telescope_azimuth
	display_altitude = telescope_altitude
	display_fov_x = fov_x
	display_fov_y = fov_y
	sky_service = SkyPositionServiceScript.new()
	# Compute the whole sky from the player's CURRENT observing location (the
	# world map can move them somewhere the target has risen). During L1-L10,
	# Maya schedules the supervised lesson for a real night when its target is
	# already above the club horizon.
	var loc: Dictionary = GameManager.observing_location()
	observation_time_utc = GameManager.observation_utc_datetime(target_id)
	sky_data = sky_service.get_sky_positions(
		VIEW_RECT,
		observation_time_utc,
		float(loc.get("lat", 34.0522)),
		float(loc.get("lon", -118.2437))
	)
	if GameManager.uses_foundation_training_schedule():
		for item_value in sky_data.values():
			if item_value is Dictionary:
				var item := item_value as Dictionary
				item["source"] = "scheduled_calculation"
				item["scheduled_training"] = true
	_ensure_target_observable()
	GameManager.publish_sky_positions(sky_data)
	_load_real_star_points()
	_build()
	InteractionFeedback.page_enter(self)
	_show_world_map_arrival_feedback()
	call_deferred("_show_sky_feature_tutorial")
	# AstronomyAPI describes the live sky. It must not overwrite the supervised
	# chapter's scheduled lesson time with a different current-time position.
	if not GameManager.uses_foundation_training_schedule():
		sky_service.request_online_planet_data(
			self,
			VIEW_RECT,
			_apply_online_sky_data,
			float(loc.get("lat", 34.0522)),
			float(loc.get("lon", -118.2437))
		)
	call_deferred("_redirect_to_world_map_if_needed")


func _show_sky_feature_tutorial() -> void:
	if mode_buttons.has("finder") and bool(_mode_available("finder").get("ok", false)) and not InteractionFeedback.was_tutorial_seen("first_finder"):
		var finder_button := (mode_buttons["finder"] as Dictionary).get("button") as Control
		InteractionFeedback.tutorial_highlight_once(finder_button, "first_finder", GameManager.text(
			"Use the Finder for a medium field. Calibrate it with I/J/K/L when prompted.",
			"使用寻星镜获得中等视野；出现提示时用 I/J/K/L 校准。"
		), self)
		return
	if _cloud_cover_amount() > 0.0 and cloud_layer != null:
		InteractionFeedback.tutorial_highlight_once(cloud_layer, "first_cloud_layer", GameManager.text(
			"Clouds dim the target as they cross the observing field. Wait for a clear gap.",
			"云层经过观测视野时会遮暗目标，请等待云隙。"
		), self)


func _process(delta: float) -> void:
	horizon_cloud_drift += delta
	_ensure_scope_reticle_visible()
	_update_lock_ring_pulse()
	_handle_aim_input(delta)
	_advance_visual_camera(delta)
	_handle_calibration_input(delta)
	_update_workflow_discipline_timer(delta)
	_advance_sky_conditions(delta)
	_advance_sky_rotation(delta)
	# Keep the big in-view banner mirroring whatever the side panel says
	# (guidance, observe errors, mode hints).
	if guidance_banner != null and guidance_label != null and guidance_banner.text != guidance_label.text:
		InteractionFeedback.crossfade_text(guidance_banner, guidance_label.text)


# The real sky never stands still: recompute every catalog star's alt/az
# from the CURRENT clock every few seconds, so the whole star field creeps
# westward at the true sidereal rate (0.25 deg/min) on every level. Mission
# target markers stay pinned by design (they are "tracked" waypoints) - at
# x1 real rate the mismatch within a session is far below aim tolerance.
# The L22-24 eyepiece drift mechanic is separate and unchanged.
const SKY_ROTATION_REFRESH_SECONDS := 10.0
var sky_rotation_accum := 0.0


func _advance_sky_rotation(delta: float) -> void:
	sky_rotation_accum += delta
	if sky_rotation_accum < SKY_ROTATION_REFRESH_SECONDS:
		return
	sky_rotation_accum = 0.0
	_load_real_star_points()
	_rebuild_view()


func _advance_sky_conditions(delta: float) -> void:
	var clouds_active := not cloud_nodes.is_empty()
	if clouds_active:
		_advance_clouds(delta)
	if star_pool.is_empty() and object_icons.is_empty():
		return
	if not clouds_active and _seeing_severity() <= 0.0:
		return
	_apply_star_and_icon_shading(clouds_active)


func _apply_star_and_icon_shading(clouds_active: bool) -> void:
	# Single per-frame pass: brightest ~40 visible stars twinkle (alpha
	# double-sine, amplitude by seeing severity); every visible star and
	# object icon darkens under whatever cloud currently covers it. Purely
	# visual - never touches aim/identification logic.
	var severity := _seeing_severity()
	var t := Time.get_ticks_msec() / 1000.0
	var twinkle_budget := TWINKLE_STAR_COUNT
	for i in range(star_pool.size()):
		var star := star_pool[i]
		if not star.visible:
			continue
		var base_color: Color = star.get_meta("base_color", star.color)
		var shading := 1.0
		if clouds_active:
			shading = 1.0 - 0.75 * _cloud_alpha_at(star.position + star.size * 0.5)
		var twinkle := 1.0
		if severity > 0.0 and twinkle_budget > 0:
			twinkle_budget -= 1
			var phase: float = twinkle_seed + float(i) * 0.7
			twinkle = 1.0 + 0.125 * (severity / 0.8) * sin(t * (2.0 + severity * 2.5) + phase)
		star.color = Color(base_color.r, base_color.g, base_color.b, clampf(base_color.a * twinkle * shading, 0.0, 1.0))
	if not clouds_active:
		return
	for id_value in object_icons.keys():
		var object_id: String = str(id_value)
		var icon: TextureRect = object_icons[object_id]
		if not icon.visible:
			continue
		var base_alpha: float = float(icon.get_meta("base_alpha", icon.modulate.a))
		var local_pos: Vector2 = icon.position + icon.size * icon.scale * 0.5
		var shading := 1.0 - 0.75 * _cloud_alpha_at(local_pos)
		icon.modulate.a = clampf(base_alpha * shading, 0.0, 1.0)


func _exit_tree() -> void:
	# Remember where the telescope was pointing for the next visit.
	GameManager.last_sky_aim = {
		"valid": true,
		"azimuth": telescope_azimuth,
		"altitude": telescope_altitude,
		"view_mode": view_mode
	}


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				_set_view_mode("naked_eye")
			KEY_2:
				_set_view_mode("finder")
			KEY_3:
				_set_view_mode("telescope")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_aim_dragging = VIEW_RECT.has_point(event.position)
			mouse_aim_press_position = event.position
			mouse_aim_drag_distance = 0.0
		else:
			var was_short_click := mouse_aim_dragging and mouse_aim_drag_distance <= 7.0 and VIEW_RECT.has_point(event.position)
			mouse_aim_dragging = false
			if was_short_click:
				_select_object_at_screen_position(event.position)
	if event is InputEventMouseMotion and mouse_aim_dragging:
		var motion := event as InputEventMouseMotion
		mouse_aim_drag_distance += motion.relative.length()
		# Touch drags arrive here too via Godot's mouse emulation; mobile
		# sensitivity and pitch inversion apply only in mobile mode so PC
		# mouse aiming keeps its exact historical feel.
		var sensitivity := TouchInput.touch_sensitivity if TouchInput.is_mobile() else 1.0
		var pitch_sign := -1.0
		if TouchInput.is_mobile() and TouchInput.invert_pitch:
			pitch_sign = 1.0
		var az_delta := motion.relative.x * fov_x / VIEW_RECT.size.x * sensitivity
		var alt_delta := pitch_sign * motion.relative.y * fov_y / VIEW_RECT.size.y * sensitivity
		_apply_aim_delta(az_delta, alt_delta)
	# Two-finger pinch (Android delivers the second finger as raw touches):
	# spreading zooms IN one view tier (eye->finder->scope), pinching zooms
	# out - same gates and logic as pressing 1/2/3.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			pinch_points[touch.index] = touch.position
			touch_press_points[touch.index] = touch.position
		else:
			var was_single_touch := pinch_points.size() <= 1
			var touch_start: Vector2 = touch_press_points.get(touch.index, touch.position)
			pinch_points.erase(touch.index)
			touch_press_points.erase(touch.index)
			pinch_start_distance = -1.0
			if was_single_touch and touch_start.distance_to(touch.position) <= 12.0:
				_select_object_at_screen_position(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if pinch_points.has(drag.index):
			pinch_points[drag.index] = drag.position
		if pinch_points.size() >= 2:
			mouse_aim_dragging = false
			var keys: Array = pinch_points.keys()
			var span: float = (pinch_points[keys[0]] as Vector2).distance_to(pinch_points[keys[1]] as Vector2)
			if pinch_start_distance <= 0.0:
				pinch_start_distance = span
			elif span > pinch_start_distance * 1.35:
				_pinch_switch_mode(1)
				pinch_start_distance = span
			elif span < pinch_start_distance * 0.74:
				_pinch_switch_mode(-1)
				pinch_start_distance = span


func _pinch_switch_mode(step: int) -> void:
	# Walk toward the pinch direction, skipping tiers the current rig lacks
	# (e.g. a telescope with no finder scope goes eye <-> telescope directly).
	var tiers := ["naked_eye", "finder", "telescope"]
	var index: int = tiers.find(view_mode) + step
	while index >= 0 and index < tiers.size():
		if bool(_mode_available(tiers[index]).get("ok", false)):
			_set_view_mode(tiers[index])
			return
		index += step


func _handle_aim_input(delta: float) -> void:
	# Narrow views turn slowly for fine aiming.
	var speed_scale := clampf(fov_x / 90.0, 0.10, 1.0)
	var azimuth_speed := AZIMUTH_SPEED * speed_scale
	var altitude_speed := ALTITUDE_SPEED * speed_scale
	if Input.is_action_pressed("dodge") or Input.is_key_pressed(KEY_SHIFT) or TouchInput.boost_held:
		azimuth_speed *= 2.0
		altitude_speed *= 2.0

	var azimuth_dir := 0.0
	var altitude_dir := 0.0
	if Input.is_action_pressed("move_left"):
		azimuth_dir -= 1.0
	if Input.is_action_pressed("move_right"):
		azimuth_dir += 1.0
	if Input.is_action_pressed("move_up"):
		altitude_dir += 1.0
	if Input.is_action_pressed("move_down"):
		altitude_dir -= 1.0

	# Velocity model with inertia: quick attack while a key is held, then a
	# short glide instead of a hard stop on release. Reduced-motion keeps the
	# old instant behavior.
	if InteractionFeedback.is_reduced_motion():
		if azimuth_dir == 0.0 and altitude_dir == 0.0:
			aim_velocity_az = 0.0
			aim_velocity_alt = 0.0
			return
		_apply_aim_delta(azimuth_dir * azimuth_speed * delta, altitude_dir * altitude_speed * delta)
		return
	var attack := 1.0 - exp(-16.0 * delta)
	var release := 1.0 - exp(-5.5 * delta)
	aim_velocity_az = lerpf(aim_velocity_az, azimuth_dir * azimuth_speed, attack if azimuth_dir != 0.0 else release)
	aim_velocity_alt = lerpf(aim_velocity_alt, altitude_dir * altitude_speed, attack if altitude_dir != 0.0 else release)
	if absf(aim_velocity_az) < 0.05 and absf(aim_velocity_alt) < 0.05:
		aim_velocity_az = 0.0
		aim_velocity_alt = 0.0
		return
	_apply_aim_delta(aim_velocity_az * delta, aim_velocity_alt * delta)


func _apply_aim_delta(azimuth_delta: float, altitude_delta: float) -> void:
	telescope_azimuth = wrapf(telescope_azimuth + azimuth_delta, 0.0, 360.0)
	telescope_altitude = clampf(telescope_altitude + altitude_delta, 0.0, 90.0)
	_count_workflow_move()
	_advance_visual_camera(1.0 / 30.0)


func _advance_visual_camera(delta: float) -> void:
	var response := 40.0 if InteractionFeedback.is_reduced_motion() else 14.0
	var blend := 1.0 - exp(-response * delta)
	var az_delta := shortest_angle_degrees(display_azimuth, telescope_azimuth)
	var old_values := Vector4(display_azimuth, display_altitude, display_fov_x, display_fov_y)
	display_azimuth = wrapf(display_azimuth + az_delta * blend, 0.0, 360.0)
	display_altitude = lerpf(display_altitude, telescope_altitude, blend)
	if InteractionFeedback.is_reduced_motion():
		display_fov_x = lerpf(display_fov_x, fov_x, blend)
		display_fov_y = lerpf(display_fov_y, fov_y, blend)
	else:
		# Springy FOV, TASTEFULLY: near-critical damping plus a hard 6%
		# overshoot ceiling. The zoom lands with a small visible settle,
		# never a huge blow-up-and-snap-back.
		var clamped_delta: float = minf(delta, 1.0 / 30.0)
		fov_spring_vel_x += (fov_x - display_fov_x) * 110.0 * clamped_delta
		fov_spring_vel_y += (fov_y - display_fov_y) * 110.0 * clamped_delta
		var damping: float = exp(-10.0 * clamped_delta)
		fov_spring_vel_x *= damping
		fov_spring_vel_y *= damping
		display_fov_x = clampf(display_fov_x + fov_spring_vel_x * clamped_delta, 2.0, 160.0)
		display_fov_y = clampf(display_fov_y + fov_spring_vel_y * clamped_delta, 2.0, 120.0)
		# Overshoot cap: once PAST the target and still moving away, pin the
		# deviation to 6% and bleed the spring so it settles immediately.
		if signf(display_fov_x - fov_x) == signf(fov_spring_vel_x) and absf(display_fov_x - fov_x) > fov_x * 0.06:
			display_fov_x = fov_x + signf(fov_spring_vel_x) * fov_x * 0.06
			fov_spring_vel_x *= 0.25
		if signf(display_fov_y - fov_y) == signf(fov_spring_vel_y) and absf(display_fov_y - fov_y) > fov_y * 0.06:
			display_fov_y = fov_y + signf(fov_spring_vel_y) * fov_y * 0.06
			fov_spring_vel_y *= 0.25
	if absf(az_delta) < 0.0005:
		display_azimuth = telescope_azimuth
	if absf(display_altitude - telescope_altitude) < 0.0005:
		display_altitude = telescope_altitude
	if absf(display_fov_x - fov_x) < 0.001:
		display_fov_x = fov_x
	if absf(display_fov_y - fov_y) < 0.001:
		display_fov_y = fov_y
	var current_values := Vector4(display_azimuth, display_altitude, display_fov_x, display_fov_y)
	if old_values.distance_to(current_values) > 0.0001:
		_rebuild_view(false)


func _count_workflow_move() -> void:
	# One "move" per ~0.15s of active steering, so holding a key doesn't
	# spam thousands of counts per second - used by L16's lost-in-6-degrees
	# detection (see _update_workflow_discipline_timer).
	if str(GameManager.current_level().get("variation", "")) != "workflow_discipline":
		return
	if view_mode != "telescope":
		return
	workflow_move_tick += 1
	if workflow_move_tick >= 9:
		workflow_move_tick = 0
		workflow_move_count += 1


# ------------------------------------------------------------ view modes


func _is_finder_calibration_level() -> bool:
	return str(GameManager.current_level().get("variation", "")) == "finder_calibration"


func _handle_calibration_input(delta: float) -> void:
	if not _is_finder_calibration_level() or view_mode != "finder" or GameManager.is_finder_aligned():
		if calibration_panel != null:
			calibration_panel.visible = _is_finder_calibration_level() and view_mode == "finder"
		# Keep the step guide live even when not in Finder, so its "Switch to
		# Finder" step is visible from the telescope/naked-eye view.
		_update_calibration_steps_banner()
		return
	if calibration_panel != null:
		calibration_panel.visible = true
	calibrate_repeat_timer -= delta
	var delta_az := 0.0
	var delta_alt := 0.0
	if Input.is_key_pressed(KEY_J):
		delta_az -= CALIBRATE_STEP_DEGREES
	if Input.is_key_pressed(KEY_L):
		delta_az += CALIBRATE_STEP_DEGREES
	# Mobile: on-screen calibration arrows feed the same step values.
	if TouchInput.is_mobile() and TouchInput.calibration_vector != Vector2.ZERO:
		delta_az += TouchInput.calibration_vector.x * CALIBRATE_STEP_DEGREES
		delta_alt += TouchInput.calibration_vector.y * CALIBRATE_STEP_DEGREES
	if Input.is_key_pressed(KEY_I):
		delta_alt += CALIBRATE_STEP_DEGREES
	if Input.is_key_pressed(KEY_K):
		delta_alt -= CALIBRATE_STEP_DEGREES
	if delta_az == 0.0 and delta_alt == 0.0:
		return
	if calibrate_repeat_timer > 0.0:
		return
	calibrate_repeat_timer = CALIBRATE_REPEAT_DELAY
	# adjust_finder_offset REDUCES the misalignment: the offset represents
	# how far off the finder is, so nudging "toward true" subtracts from it.
	GameManager.adjust_finder_offset(-delta_az, -delta_alt)
	_update_calibration_panel()
	_rebuild_view()


func _update_calibration_panel() -> void:
	_update_calibration_steps_banner()
	if calibration_pct_label == null:
		return
	var aligned := GameManager.is_finder_aligned()
	var pct := GameManager.finder_alignment_percent()
	var prior_pct := previous_calibration_percent
	if calibration_progress_fill != null:
		InteractionFeedback.tween_size(calibration_progress_fill, Vector2((CALIBRATE_RECT.size.x - 24.0) * pct / 100.0, 5.0), 0.14)
		if prior_pct >= 0.0 and pct > prior_pct + 0.05:
			InteractionFeedback.pulse(calibration_progress_fill, Color(0.62, 1.0, 0.92), 0.28)
	previous_calibration_percent = pct
	if aligned:
		calibration_pct_label.text = GameManager.text("Aligned!", "校准完成！")
		calibration_pct_label.add_theme_color_override("font_color", GREEN)
		calibration_hint_label.text = GameManager.text("Finder now matches the telescope.", "寻星镜现在与主镜一致了。")
		if not calibration_success_played:
			calibration_success_played = true
			InteractionFeedback.success(calibration_panel, "finder_aligned")
			if scope_reticle_layer != null:
				InteractionFeedback.pulse(scope_reticle_layer, GOLD, 0.48)
			if target_state_ring != null:
				InteractionFeedback.success(target_state_ring, "finder_lock")
	else:
		# Single-line inline bilingual (GameManager.text stacks EN+ZH and
		# overflows this 46px panel) + a live signed readout so the player
		# always knows WHICH key moves toward zero.
		var offset: Dictionary = GameManager.finder_offset()
		var az := float(offset.get("az", 0.0))
		var alt := float(offset.get("alt", 0.0))
		if absf(az) < 0.35 and absf(alt) < 0.35 and pct > prior_pct:
			InteractionFeedback.pulse(calibration_panel, CYAN, 0.34)
		calibration_pct_label.text = GameManager.text(
			"Finder alignment %d%%   Δaz %+.1f°  Δalt %+.1f°",
			"寻星镜校准 %d%%   方位差 %+.1f°  高度差 %+.1f°"
		) % [int(pct), az, alt]
		calibration_pct_label.add_theme_color_override("font_color", WARNING)
		var keys: Array[String] = []
		if absf(az) > 0.05:
			keys.append("L→" if az > 0.0 else "J←")
		if absf(alt) > 0.05:
			keys.append("I↑" if alt > 0.0 else "K↓")
		var key_hint := " ".join(keys) if not keys.is_empty() else "IJKL"
		calibration_hint_label.text = GameManager.text(
			"Press %s to move the offsets toward zero",
			"按 %s 将偏差调向 0"
		) % key_hint


func _mode_available(mode: String) -> Dictionary:
	if mode == "naked_eye":
		return {"ok": true}
	if not GameManager.current_requires_telescope():
		return {
			"ok": false,
			"en": "Tonight is a naked eye session.",
			"zh": "今晚是肉眼观测环节。"
		}
	if mode == "finder" and not _finder_installed():
		return {
			"ok": false,
			"en": "No finder scope installed yet.",
			"zh": "还没有安装寻星镜。"
		}
	if mode == "telescope" and not GameManager.telescope_is_ready():
		return {
			"ok": false,
			"en": "The telescope is not assembled yet.",
			"zh": "望远镜还没有组装完成。"
		}
	if mode == "telescope" and _is_finder_calibration_level() and not GameManager.is_finder_aligned():
		return {
			"ok": false,
			"en": "Calibrate the finder scope first (switch to Finder, use IJKL).",
			"zh": "请先校准寻星镜（切换到寻星镜视角，用 IJKL 微调）。"
		}
	return {"ok": true}


func play_custom_entrance() -> void:
	# Dome-door arrival: two dark wooden shutters part vertically, revealing
	# the sky - a themed entrance distinct from the generic page fade.
	if InteractionFeedback.is_reduced_motion():
		return
	var top_door := ColorRect.new()
	top_door.color = Color(0.085, 0.052, 0.028)
	top_door.position = Vector2.ZERO
	top_door.size = Vector2(1024, 384)
	top_door.z_index = 210
	top_door.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(top_door)
	var top_edge := ColorRect.new()
	top_edge.color = Color(0.72, 0.53, 0.26)
	top_edge.position = Vector2(0, 380)
	top_edge.size = Vector2(1024, 4)
	top_door.add_child(top_edge)
	var bottom_door := ColorRect.new()
	bottom_door.color = Color(0.085, 0.052, 0.028)
	bottom_door.position = Vector2(0, 384)
	bottom_door.size = Vector2(1024, 384)
	bottom_door.z_index = 210
	bottom_door.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bottom_door)
	var bottom_edge := ColorRect.new()
	bottom_edge.color = Color(0.72, 0.53, 0.26)
	bottom_edge.position = Vector2.ZERO
	bottom_edge.size = Vector2(1024, 4)
	bottom_door.add_child(bottom_edge)
	var doors_tween := create_tween().set_parallel(true)
	doors_tween.tween_property(top_door, "position:y", -390.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	doors_tween.tween_property(bottom_door, "position:y", 772.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	doors_tween.chain().tween_callback(func() -> void:
		top_door.queue_free()
		bottom_door.queue_free()
	)


func _set_view_mode(mode: String) -> void:
	if mode == view_mode:
		# Re-selecting the active view is also a repair path for a scene that
		# survived a language/UI rebuild with its aiming overlay hidden.
		_update_mode_buttons()
		_ensure_scope_reticle_visible()
		return
	var check := _mode_available(mode)
	if not bool(check.get("ok", false)):
		if guidance_label != null:
			guidance_label.text = GameManager.text(str(check.get("en", "")), str(check.get("zh", "")))
			InteractionFeedback.error(guidance_label)
		if mode_buttons.has(mode):
			InteractionFeedback.error((mode_buttons[mode] as Dictionary).get("button") as Control)
		return
	var previous_mode := view_mode
	view_mode = mode
	visited_modes[view_mode] = true
	_apply_view_mode()
	_update_optical_lens_mode()
	_update_mode_buttons()
	if cloud_layer != null:
		# Cloud screen-size/speed scale with FOV, so switching views rebuilds
		# them; the underlying cloud_cover amount is unchanged.
		for cloud in cloud_nodes:
			cloud.queue_free()
		_build_cloud_layer()
	_rebuild_view()
	_animate_mode_transition(mode, previous_mode)


func _animate_mode_transition(mode: String, previous_mode := "") -> void:
	if view_layer == null:
		return
	var reduced := InteractionFeedback.is_reduced_motion()
	# Reduced motion suppresses the optical zoom sweep but retains a legible
	# crossfade; an 80 ms switch looked like a broken instant state change.
	var duration := 0.28 if reduced else 0.46
	var previous_fov := float(VIEW_MODES.get(previous_mode, VIEW_MODES[mode]).get("fov_x", fov_x))
	var zooming_in := fov_x < previous_fov
	if mode_transition_tween != null and mode_transition_tween.is_valid():
		mode_transition_tween.kill()
	mode_content_alpha = 0.92 if reduced else 0.76
	mode_transition_tween = create_tween().bind_node(self).set_parallel(true)
	mode_transition_tween.tween_property(self, "mode_content_alpha", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if optical_mode_transition != null:
		optical_mode_transition.zooming_in = zooming_in
		optical_mode_transition.progress = 0.0
		optical_mode_transition.active = not reduced
		if not reduced:
			mode_transition_tween.tween_property(optical_mode_transition, "progress", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			mode_transition_tween.chain().tween_callback(func() -> void:
				if optical_mode_transition != null:
					optical_mode_transition.active = false
			)
	# TRANS_BACK overshoots past 1.0 and springs back - the "Q弹" settle,
	# The reticles crossfade while the FOV spring performs the real zoom.
	if scope_reticle_layer != null:
		scope_reticle_layer.modulate.a = 0.0
		var target_alpha := 1.0 if mode != "naked_eye" else 0.55
		var reticle_tween := create_tween().bind_node(scope_reticle_layer)
		reticle_tween.tween_interval(0.05 if reduced else 0.08)
		reticle_tween.tween_property(scope_reticle_layer, "modulate:a", target_alpha, 0.22 if reduced else 0.28).set_trans(Tween.TRANS_SINE)
	if previous_mode != "" and previous_mode != mode and not reduced:
		if reticle_transition_ghost != null and is_instance_valid(reticle_transition_ghost):
			reticle_transition_ghost.queue_free()
		reticle_transition_ghost = TextureRect.new()
		reticle_transition_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reticle_transition_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reticle_transition_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		reticle_transition_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reticle_transition_ghost.texture = _load_png_texture(str(MODE_RETICLE_TEXTURES.get(previous_mode, MODE_RETICLE_TEXTURES["naked_eye"])))
		reticle_transition_ghost.position = AIM_RETICLE_RECT.position
		reticle_transition_ghost.size = AIM_RETICLE_RECT.size
		reticle_transition_ghost.pivot_offset = reticle_transition_ghost.size * 0.5
		reticle_transition_ghost.modulate.a = 0.72 if previous_mode == "naked_eye" else 0.92
		reticle_transition_ghost.z_index = Z_AIM_OVERLAY
		view_layer.add_child(reticle_transition_ghost)
		var ghost := reticle_transition_ghost
		var ghost_tween := create_tween().bind_node(ghost).set_parallel(true)
		ghost_tween.tween_property(ghost, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
		ghost_tween.tween_property(ghost, "scale", Vector2.ONE * (0.94 if zooming_in else 1.06), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ghost_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(ghost):
				ghost.queue_free()
			if reticle_transition_ghost == ghost:
				reticle_transition_ghost = null
		)
	if mode_buttons.has(mode):
		InteractionFeedback.success((mode_buttons[mode] as Dictionary).get("button") as Control, "mode_switch")


func _apply_view_mode() -> void:
	var config: Dictionary = VIEW_MODES[view_mode]
	fov_x = float(config.get("fov_x", 120.0))
	fov_y = float(config.get("fov_y", 70.0))


func _mode_label(mode: String) -> String:
	var config: Dictionary = VIEW_MODES[mode]
	return GameManager.text(str(config.get("en", mode)), str(config.get("zh", mode)))


func _center_tolerance() -> float:
	if view_mode == "telescope":
		return CENTER_TOLERANCE_TELESCOPE
	return CENTER_TOLERANCE_FINDER


func _target_screen_distance(object_id: String) -> float:
	if not in_view_targets.has(object_id):
		return INF
	var info: Dictionary = in_view_targets[object_id]
	var rect: Rect2 = info.get("rect", Rect2())
	return rect.get_center().distance_to(VIEW_RECT.size * 0.5)


func _active_observation_object_id() -> String:
	# A clicked non-mission body is a valid observing target in its own right.
	# Do not fall back to tonight's mission target once the player has selected it.
	return selected_object_id if selected_object_id != "" else target_id


func _is_free_selection() -> bool:
	return _active_observation_object_id() != "" and _active_observation_object_id() != target_id


func _is_target_centered(object_id: String) -> bool:
	if not in_view_targets.has(object_id):
		return false
	if view_mode == "naked_eye":
		return _target_screen_distance(object_id) <= EYE_LOCK_RADIUS_PX
	return _center_offset(object_id) <= _center_tolerance()


# ------------------------------------------------------------- data


func _apply_online_sky_data(online_data: Dictionary) -> void:
	for object_id_value in online_data.keys():
		var object_id: String = str(object_id_value)
		var online_item: Variant = online_data[object_id]
		if not sky_service.is_valid_position_item(online_item):
			continue
		# Invalid or partial API data never replaces the local ephemeris.
		sky_data[object_id] = (online_item as Dictionary).duplicate(true)
	_ensure_target_observable()
	GameManager.publish_sky_positions(sky_data)
	_update_mission_tonight_text()
	_update_selected_text()
	_rebuild_view()
	call_deferred("_redirect_to_world_map_if_needed")


func _ensure_target_observable() -> void:
	_ensure_object_observable(target_id)
	var active_id := _active_observation_object_id()
	if active_id != target_id:
		_ensure_object_observable(active_id)


func _ensure_object_observable(object_id: String) -> void:
	# Keep the mission target represented even when an online request fails. Do
	# not rewrite a valid local result or move a below-horizon body into view.
	if object_id == "" or sky_data.has(object_id):
		return
	var location := GameManager.observing_location()
	var local_positions: Dictionary = sky_service.get_sky_positions(
		VIEW_RECT,
		observation_time_utc,
		float(location.get("lat", 34.0522)),
		float(location.get("lon", -118.2437))
	)
	if local_positions.has(object_id):
		sky_data[object_id] = local_positions[object_id]
		if GameManager.uses_foundation_training_schedule():
			(sky_data[object_id] as Dictionary)["source"] = "scheduled_calculation"
			(sky_data[object_id] as Dictionary)["scheduled_training"] = true
		return
	# Expansion targets such as constellation fields have valid catalog RA/Dec
	# but are not individual entries in SkyPositionService's star list. Resolve
	# them through the same observer/time transform instead of hiding them.
	var radec: Dictionary = GameManager.object_radec_at(object_id, observation_time_utc)
	if radec.has("ra_hours") and radec.has("dec_degrees"):
		var computed: Dictionary = sky_service.visibility_at(
			float(radec.get("ra_hours", 0.0)),
			float(radec.get("dec_degrees", 0.0)),
			float(location.get("lat", 34.0522)),
			float(location.get("lon", -118.2437)),
			observation_time_utc)
		computed["source"] = "scheduled_calculation" if GameManager.uses_foundation_training_schedule() else "calculated"
		computed["scheduled_training"] = GameManager.uses_foundation_training_schedule()
		sky_data[object_id] = computed
		return
	var fallbacks: Dictionary = sky_service.fallback_positions(VIEW_RECT)
	if fallbacks.has(object_id):
		sky_data[object_id] = fallbacks[object_id]


func _redirect_to_world_map_if_needed() -> void:
	if not is_inside_tree() or location_transition_active or horizon_explanation_active:
		return
	if GameManager.suppress_next_world_map_redirect:
		GameManager.suppress_next_world_map_redirect = false
		return
	if GameManager.uses_foundation_training_schedule():
		_update_low_altitude_notice(false)
		return
	var active_id := _active_observation_object_id()
	var item := _sky_item(active_id)
	if active_id == "" or item.is_empty():
		return
	var altitude := float(item.get("altitude", 0.0))
	if altitude < 0.0:
		_start_below_horizon_explanation()
		return
	_update_low_altitude_notice(altitude < COMFORTABLE_OBSERVING_ALTITUDE)


func _start_below_horizon_explanation() -> void:
	if horizon_explanation_active or view_layer == null:
		return
	horizon_explanation_active = true
	_update_low_altitude_notice(false)
	var active_id := _active_observation_object_id()
	var item := _sky_item(active_id)
	GameManager.world_map_target_id = active_id
	GameManager.world_map_observation_context = {
		"target_id": active_id,
		"free_observation": active_id != target_id,
		"level": int(GameManager.progress.get("current_level", 1)),
		"view_mode": view_mode,
		"azimuth": telescope_azimuth,
		"altitude": telescope_altitude
	}
	# Light and free modes keep the real below-horizon consequence and site
	# routing, but skip the blocking Maya explanation sequence.
	if not GameManager.uses_full_tutorials():
		call_deferred("_finish_below_horizon_explanation")
		return

	horizon_explanation_layer = Control.new()
	horizon_explanation_layer.name = "BelowHorizonExplanation"
	horizon_explanation_layer.size = VIEW_RECT.size
	horizon_explanation_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	horizon_explanation_layer.z_index = 240
	view_layer.add_child(horizon_explanation_layer)
	var dim := _rect(horizon_explanation_layer, Vector2.ZERO, VIEW_RECT.size, Color(0.005, 0.012, 0.030, 0.44))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP

	var horizon_y := 390.0
	var ground := _rect(horizon_explanation_layer, Vector2(0, horizon_y), Vector2(VIEW_RECT.size.x, VIEW_RECT.size.y - horizon_y), Color(0.012, 0.020, 0.032, 0.94))
	ground.z_index = 5
	var horizon_glow := _rect(horizon_explanation_layer, Vector2(0, horizon_y - 1), Vector2(VIEW_RECT.size.x, 2), Color(0.95, 0.48, 0.28, 0.78))
	horizon_glow.z_index = 6
	var horizon_soft := _rect(horizon_explanation_layer, Vector2(0, horizon_y - 5), Vector2(VIEW_RECT.size.x, 10), Color(0.28, 0.55, 0.78, 0.12))
	horizon_soft.z_index = 6

	var ghost_group := Control.new()
	ghost_group.name = "BelowHorizonGhostTarget"
	ghost_group.size = Vector2(72, 72)
	var delta_az := shortest_angle_degrees(display_azimuth, float(item.get("azimuth", display_azimuth)))
	var projected_x := _fov_to_local(delta_az, 0.0).x
	ghost_group.position = Vector2(clampf(projected_x - 36.0, 54.0, VIEW_RECT.size.x - 126.0), horizon_y - 70.0)
	ghost_group.z_index = 4
	horizon_explanation_layer.add_child(ghost_group)
	var icon_path := _icon_path_for_object(active_id)
	if ResourceLoader.exists(icon_path):
		for echo_data in [
			{"offset": Vector2(-3, 0), "color": Color(0.25, 0.65, 1.0, 0.25)},
			{"offset": Vector2(3, 0), "color": Color(1.0, 0.28, 0.34, 0.20)},
			{"offset": Vector2.ZERO, "color": Color(0.72, 0.82, 1.0, 0.50)}
		]:
			var ghost := TextureRect.new()
			ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ghost.texture = load(icon_path)
			ghost.position = Vector2(-4, -4) + (echo_data as Dictionary)["offset"]
			ghost.size = Vector2(80, 80)
			ghost.modulate = (echo_data as Dictionary)["color"]
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ghost_group.add_child(ghost)

	var title := _label(horizon_explanation_layer,
		GameManager.text("TARGET BELOW THE HORIZON", "目标位于当前地点地平线以下"),
		Vector2(42, 38), Vector2(546, 34), 22, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
	title.z_index = 8
	var explanation := _label(horizon_explanation_layer,
		GameManager.text("This object cannot be observed from the current site now.", "当前地点现在无法观测这个天体。"),
		Vector2(48, 78), Vector2(534, 42), 15, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	explanation.z_index = 8
	MayaPortrait.create(
		horizon_explanation_layer,
		"MayaHorizonPortrait",
		MayaPortrait.THINK,
		Vector2(48, 116),
		Vector2(72, 108),
		8
	)
	var maya_name := _label(horizon_explanation_layer, GameManager.text("MAYA", "玛雅"), Vector2(128, 128), Vector2(90, 24), 15, GOLD)
	maya_name.z_index = 8
	var maya := _label(horizon_explanation_layer,
		GameManager.text("The sky changes with location and time.\nLet's find a site where the target has risen.", "不同地点和时间看到的天空不同。\n我们去寻找目标已经升起的观测地点。"),
		Vector2(128, 150), Vector2(438, 64), 14, Color(0.72, 0.88, 1.0))
	maya.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	maya.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	maya.z_index = 8
	var target_name := _label(horizon_explanation_layer,
		GameManager.dict_text(GameManager.get_object(active_id), "name"),
		Vector2(ghost_group.position.x - 30, horizon_y - 103), Vector2(132, 24), 13, Color(0.72, 0.82, 1.0, 0.82), HORIZONTAL_ALIGNMENT_CENTER)
	target_name.z_index = 8

	horizon_skip_button = Button.new()
	horizon_skip_button.name = "HorizonSkipButton"
	horizon_skip_button.text = GameManager.text("Continue", "继续")
	horizon_skip_button.position = Vector2(VIEW_RECT.size.x - 128, 218)
	horizon_skip_button.size = Vector2(104, 34)
	horizon_skip_button.z_index = 9
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.04, 0.08, 0.13, 0.96)
	skip_style.border_color = GOLD
	skip_style.set_border_width_all(1)
	skip_style.set_corner_radius_all(3)
	horizon_skip_button.add_theme_stylebox_override("normal", skip_style)
	horizon_skip_button.add_theme_stylebox_override("disabled", skip_style)
	horizon_skip_button.add_theme_color_override("font_disabled_color", Color(0.76, 0.70, 0.56))
	horizon_skip_button.pressed.connect(_skip_horizon_explanation)
	horizon_explanation_layer.add_child(horizon_skip_button)
	var seen: Array = GameManager.progress.get("seen_teaching_steps", [])
	var first_time := not seen.has("below_horizon_flow_v1")
	if first_time:
		seen.append("below_horizon_flow_v1")
		GameManager.progress["seen_teaching_steps"] = seen
		GameManager.save()
		horizon_skip_button.disabled = true
		get_tree().create_timer(0.75).timeout.connect(func() -> void:
			if horizon_skip_button != null and is_instance_valid(horizon_skip_button):
				horizon_skip_button.disabled = false
		)

	var duration := 0.9 if InteractionFeedback.is_reduced_motion() else (2.25 if first_time else 1.65)
	horizon_explanation_tween = create_tween().bind_node(horizon_explanation_layer).set_parallel(true)
	horizon_explanation_tween.tween_property(ghost_group, "position:y", horizon_y + 72.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	horizon_explanation_tween.tween_property(ghost_group, "modulate:a", 0.08, duration * 0.88).set_delay(duration * 0.12)
	horizon_explanation_tween.tween_property(horizon_glow, "modulate:a", 0.40, duration * 0.75)
	horizon_explanation_tween.set_parallel(false)
	horizon_explanation_tween.tween_callback(_finish_below_horizon_explanation)


func _skip_horizon_explanation() -> void:
	if not horizon_explanation_active or (horizon_skip_button != null and horizon_skip_button.disabled):
		return
	if horizon_explanation_tween != null:
		horizon_explanation_tween.kill()
	_finish_below_horizon_explanation()


func _finish_below_horizon_explanation() -> void:
	if not horizon_explanation_active:
		return
	horizon_explanation_active = false
	_open_world_map_from_sky()


func _update_low_altitude_notice(enabled: bool) -> void:
	low_altitude_notice_active = enabled
	var button := get_node_or_null("ChangeSiteButton") as Button
	if button == null:
		return
	button.text = GameManager.text("Low target - Change Site?", "目标高度较低 - 更换地点？") if enabled else GameManager.text("Location / Change Site", "地点 / 更换地点")
	button.add_theme_color_override("font_color", WARNING if enabled else TEXT)
	button.tooltip_text = GameManager.text(
		"The target has just risen or is about to set. You may observe here or choose a more comfortable site.",
		"目标刚刚升起或即将落下。你可以继续在此观测，或选择更舒适的地点。") if enabled else ""


func _show_world_map_arrival_feedback() -> void:
	var context: Dictionary = GameManager.world_map_arrival_context
	if context.is_empty() or str(context.get("target_id", "")) != _active_observation_object_id():
		return
	GameManager.world_map_arrival_context.clear()
	arrival_hint_until = Time.get_ticks_msec() + 4500
	var notice := Panel.new()
	notice.name = "WorldMapArrivalFeedback"
	notice.position = Vector2(82, 344)
	notice.size = Vector2(466, 82)
	notice.z_index = 210
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.09, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	notice.add_theme_stylebox_override("panel", style)
	view_layer.add_child(notice)
	var copy := _label(notice,
		GameManager.text("The target is now above the horizon.\nUse Eye, Finder, or Telescope to locate it.", "目标现在已经升到地平线以上。\n使用肉眼、寻星镜或望远镜寻找目标。"),
		Vector2(18, 10), Vector2(430, 62), 15, GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tween := create_tween().bind_node(notice)
	tween.tween_property(notice, "modulate:a", 1.0, 0.22)
	tween.tween_interval(3.0)
	tween.tween_property(notice, "modulate:a", 0.0, 0.35)
	tween.tween_callback(notice.queue_free)


func _target_altitude_bias() -> String:
	var level := GameManager.current_level()
	var environment: Dictionary = level.get("environment", {})
	return str(environment.get("target_altitude_bias", ""))


# ------------------------------------------------------ E3 sky conditions


func _sky_brightness_key() -> String:
	# No environment on the level at all = every legacy/no-environment level
	# (L1-L9, most of L10-24) behaves exactly as before: full star field, no
	# lift, no filtering.
	var environment := GameManager.current_environment()
	if environment.is_empty():
		return ""
	return str(environment.get("sky_brightness", "")).to_lower()


func _cloud_cover_amount() -> float:
	var environment := GameManager.current_environment()
	if environment.is_empty():
		return 0.0
	return clampf(float(environment.get("cloud_cover", 0.0)), 0.0, 1.0)


func _seeing_severity() -> float:
	var environment := GameManager.current_environment()
	if environment.is_empty():
		return 0.06
	match str(environment.get("seeing", "")).capitalize():
		"Poor":
			return 0.8
		"Average":
			return 0.35
	return 0.06


func _magnitude_limit() -> float:
	# Star-catalog visibility ceiling by sky brightness. No environment
	# (empty key) keeps every star, matching pre-E3 behavior exactly.
	match _sky_brightness_key():
		"city":
			return 3.6
		"suburban":
			return 4.5
	return 99.0


func _deep_sky_city_dim() -> float:
	# Deep-sky (faint, low-contrast) targets take the biggest hit under
	# city glow - matches the telescope-view E1 rule.
	if _sky_brightness_key() == "city":
		return 0.6
	return 1.0


func _sky_lift_color() -> Color:
	match _sky_brightness_key():
		"city":
			return Color(0.030, 0.034, 0.050, 1.0)
		"suburban":
			return Color(0.015, 0.017, 0.025, 1.0)
	return Color(0.0, 0.0, 0.0, 0.0)


func _build_cloud_layer() -> void:
	cloud_nodes.clear()
	cloud_velocities.clear()
	cloud_sky_anchors.clear()
	twinkle_seed = fmod(float(absi(target_id.hash())), 1000.0)
	var cover := _cloud_cover_amount()
	if cover <= 0.0:
		return
	var tier := 1
	if cover >= 0.67:
		tier = 3
	elif cover >= 0.34:
		tier = 2
	var alpha_for_tier := 0.28
	match tier:
		2:
			alpha_for_tier = 0.5
		3:
			alpha_for_tier = 0.75
	var count: int = clampi(1 + tier, 2, 5)
	for i in range(count):
		var tex_path: String = SKY_CLOUD_TEXTURES[i % SKY_CLOUD_TEXTURES.size()]
		if not ResourceLoader.exists(tex_path):
			continue
		var texture: Texture2D = load(tex_path)
		var cloud := TextureRect.new()
		cloud.texture = texture
		cloud.stretch_mode = TextureRect.STRETCH_KEEP
		# Soft wisp art, not pixel art - linear filtering keeps it a smooth
		# haze instead of blocky mush when scaled up for narrow FOVs.
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# Narrower FOV = the same physical cloud fills more of the frame, but
		# capped gently so it never balloons past a soft haze over the view.
		var fov_scale := clampf(sqrt(60.0 / fov_x), 1.0, 2.2)
		cloud.scale = Vector2.ONE * SKY_CLOUD_SCALE * fov_scale
		cloud.size = texture.get_size()
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Night clouds are dark SILHOUETTES that swallow the stars behind
		# them - they absorb light, they do not reflect white.
		cloud.modulate = Color(0.055, 0.070, 0.105, clampf(alpha_for_tier * 1.6, 0.0, 0.92))
		# Sky-anchored spawn: scatter around the current aim in DEGREES.
		var seed_angle: float = fmod(float(i) * 137.5 + twinkle_seed, 360.0) * PI / 180.0
		var offset_az: float = cos(seed_angle) * fov_x * (0.20 + 0.12 * float(i))
		var offset_alt: float = sin(seed_angle) * 0.4 * fov_y * (0.20 + 0.12 * float(i))
		var anchor := Vector2(
			wrapf(telescope_azimuth + offset_az, 0.0, 360.0),
			clampf(telescope_altitude + offset_alt, 4.0, 86.0)
		)
		cloud_sky_anchors.append(anchor)
		# Angular wind (deg/s): same real speed in every mode - narrow FOV
		# crossings automatically look faster on screen, which is physical.
		var wind_az: float = (1.2 + fmod(float(i) * 0.7, 1.4)) * (1.0 if i % 2 == 0 else -1.0)
		var wind_alt: float = 0.05 + fmod(float(i), 3.0) * 0.03
		cloud_velocities.append(Vector2(wind_az, wind_alt))
		cloud_layer.add_child(cloud)
		cloud_nodes.append(cloud)
		_position_cloud(i)


func _advance_clouds(delta: float) -> void:
	if cloud_nodes.is_empty():
		return
	for i in range(cloud_nodes.size()):
		# Wind moves the anchor through the SKY; the screen position below
		# also re-reads the current aim, so panning slides clouds together
		# with the stars (they are part of the sky, not the UI).
		var anchor := cloud_sky_anchors[i]
		anchor.x = wrapf(anchor.x + cloud_velocities[i].x * delta, 0.0, 360.0)
		anchor.y = clampf(anchor.y + cloud_velocities[i].y * delta, 4.0, 86.0)
		# Recycle once the cloud has fully left the field: re-enter from the
		# opposite side of the CURRENT aim, slightly upwind.
		var d_az := shortest_angle_degrees(telescope_azimuth, anchor.x)
		var d_alt := anchor.y - telescope_altitude
		if absf(d_az) > fov_x * 0.95:
			anchor.x = wrapf(telescope_azimuth - signf(d_az) * fov_x * 0.9, 0.0, 360.0)
		if absf(d_alt) > fov_y * 0.95:
			anchor.y = clampf(telescope_altitude - signf(d_alt) * fov_y * 0.9, 4.0, 86.0)
		cloud_sky_anchors[i] = anchor
		_position_cloud(i)


func _position_cloud(index: int) -> void:
	var cloud := cloud_nodes[index]
	var anchor := cloud_sky_anchors[index]
	var d_az := shortest_angle_degrees(display_azimuth, anchor.x)
	var d_alt := anchor.y - display_altitude
	cloud.position = _fov_to_local(d_az, d_alt) - cloud.size * cloud.scale * 0.5


func _cloud_alpha_at(local_pos: Vector2) -> float:
	# How much a cloud dims a given point in the view (0 = clear, 1 = fully
	# obscured). Purely visual - never touches identification/aim logic.
	if cloud_nodes.is_empty():
		return 0.0
	var total := 0.0
	for cloud in cloud_nodes:
		var effective_size: Vector2 = cloud.size * cloud.scale
		var cloud_center: Vector2 = cloud.position + effective_size * 0.5
		var radius: float = maxf(effective_size.x, effective_size.y) * 0.5
		var d := cloud_center.distance_to(local_pos)
		var falloff := clampf(1.0 - d / maxf(radius, 1.0), 0.0, 1.0)
		total += falloff * cloud.modulate.a
	return clampf(total, 0.0, 1.0)


func _load_real_star_points() -> void:
	# Real night sky: HYG bright-star catalog converted to tonight's alt/az.
	star_points.clear()
	sky_service.load_config()
	# Background stars must come from the SAME site as everything else, so
	# travelling to another observatory really changes the visible sky.
	var loc: Dictionary = GameManager.observing_location()
	var latitude: float = float(loc.get("lat", 34.0522))
	var longitude: float = float(loc.get("lon", -118.2437))
	var utc_now: Dictionary = Time.get_datetime_dict_from_system(true)

	var file := FileAccess.open(BRIGHT_STARS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	var stars: Array = data.get("stars", [])
	for star_value in stars:
		if not star_value is Array:
			continue
		var star: Array = star_value
		if star.size() < 3:
			continue
		var alt_az: Dictionary = sky_service.calculate_alt_az_from_ra_dec(
			float(star[0]), float(star[1]), latitude, longitude, utc_now
		)
		var altitude: float = float(alt_az.get("altitude", -90.0))
		if altitude <= 0.0:
			continue
		var magnitude: float = float(star[2])
		if magnitude > _magnitude_limit():
			continue
		var size := 1.0
		if magnitude <= 1.0:
			size = 3.0
		elif magnitude <= 3.0:
			size = 2.0
		var brightness := clampf(1.0 - magnitude * 0.13, 0.42, 0.98)
		star_points.append(Vector4(float(alt_az.get("azimuth", 0.0)), altitude, size, brightness))


# ------------------------------------------------------------------ helpers


func shortest_angle_degrees(from_deg: float, to_deg: float) -> float:
	var diff := fmod((to_deg - from_deg + 540.0), 360.0) - 180.0
	return diff


func _direction_text_for_azimuth(azimuth: float) -> String:
	var directions: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index: int = int(floor((wrapf(azimuth, 0.0, 360.0) + 22.5) / 45.0)) % directions.size()
	return directions[index]


func _format_dms(value: float, signed: bool = false) -> String:
	var sign := ""
	var amount := value
	if signed and value < 0.0:
		sign = "-"
		amount = -value
	elif signed and value > 0.0:
		sign = "+"
	amount = absf(amount)
	var degrees := int(floor(amount))
	var minutes_float := (amount - float(degrees)) * 60.0
	var minutes := int(floor(minutes_float))
	var seconds := int(round((minutes_float - float(minutes)) * 60.0))
	if seconds >= 60:
		seconds -= 60
		minutes += 1
	if minutes >= 60:
		minutes -= 60
		degrees += 1
	return "%s%d°%02d'%02d\"" % [sign, degrees, minutes, seconds]


func _icon_path_for_object(object_id: String) -> String:
	var exact_path := ICON_DIR + object_id + ".png"
	if ResourceLoader.exists(exact_path):
		return exact_path
	var obj := GameManager.get_object(object_id)
	var category := _object_category(obj)
	var fallback_by_category := {
		"star": ICON_DIR + "sirius.png",
		"planet": ICON_DIR + "mars.png",
		"moon": ICON_DIR + "moon.png",
		"deep_sky": ICON_DIR + "orion_nebula.png"
	}
	return str(fallback_by_category.get(category, ICON_DIR + "sirius.png"))


# ---------------------------------------------------------------- build


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_background()
	_cover_baked_text()
	_build_scale_bands()
	_build_view_layer()
	_build_panel_text()
	_build_mode_buttons()
	_build_calibration_panel()
	_draw_action_hitboxes()
	_build_mobile_sky_controls()
	_update_mode_buttons()
	_rebuild_view()


func _build_mobile_sky_controls() -> void:
	if not TouchInput.is_mobile():
		return
	TouchInput.boost_held = false
	TouchInput.calibration_vector = Vector2.ZERO
	# Hold-to-boost (Shift equivalent), tucked under the altitude band so it
	# never covers the sky window, hints, or the right panel.
	var boost := Button.new()
	boost.text = GameManager.text("Boost", "加速")
	boost.position = Vector2(96, 686)
	boost.size = Vector2(120, 48)
	boost.focus_mode = Control.FOCUS_NONE
	boost.add_theme_font_size_override("font_size", 14)
	boost.z_index = 90
	boost.button_down.connect(func() -> void: TouchInput.boost_held = true)
	boost.button_up.connect(func() -> void: TouchInput.boost_held = false)
	add_child(boost)
	# Calibration pad (IJKL equivalent) only on finder-calibration lessons.
	if not _is_finder_calibration_level():
		return
	var directions := [["▲", Vector2(0, 1), Vector2(600, 630)], ["▼", Vector2(0, -1), Vector2(600, 686)],
		["◀", Vector2(-1, 0), Vector2(548, 658)], ["▶", Vector2(1, 0), Vector2(652, 658)]]
	for spec in directions:
		var pad := Button.new()
		pad.text = str(spec[0])
		pad.position = spec[2]
		pad.size = Vector2(48, 48)
		pad.focus_mode = Control.FOCUS_NONE
		pad.z_index = 90
		var pad_vector: Vector2 = spec[1]
		pad.button_down.connect(func() -> void: TouchInput.calibration_vector = pad_vector)
		pad.button_up.connect(func() -> void: TouchInput.calibration_vector = Vector2.ZERO)
		add_child(pad)


func _build_calibration_panel() -> void:
	if not _is_finder_calibration_level():
		return
	calibration_panel = Control.new()
	calibration_panel.position = CALIBRATE_RECT.position
	calibration_panel.size = CALIBRATE_RECT.size
	calibration_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calibration_panel.visible = false
	add_child(calibration_panel)
	_rect(calibration_panel, Vector2.ZERO, CALIBRATE_RECT.size, Color(0.02, 0.03, 0.05, 0.72))
	calibration_pct_label = _label(calibration_panel, "", Vector2(10, 2), Vector2(CALIBRATE_RECT.size.x - 20, 18), 12, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
	_rect(calibration_panel, Vector2(12, 21), Vector2(CALIBRATE_RECT.size.x - 24, 5), Color(0.08, 0.13, 0.20, 0.9))
	calibration_progress_fill = _rect(calibration_panel, Vector2(12, 21), Vector2(0, 5), CYAN)
	calibration_hint_label = _label(calibration_panel, GameManager.text("IJKL to adjust", "IJKL 微调"), Vector2(10, 27), Vector2(CALIBRATE_RECT.size.x - 20, 17), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_build_calibration_steps_banner()
	_update_calibration_panel()


func _build_calibration_steps_banner() -> void:
	# Prominent center-top guide so the player is never locked in Finder mode
	# without knowing the calibration routine. The active step lights up.
	var banner_w := 566.0
	calibration_steps_banner = Control.new()
	calibration_steps_banner.position = Vector2(VIEW_RECT.position.x + (VIEW_RECT.size.x - banner_w) * 0.5, VIEW_RECT.position.y + 34.0)
	calibration_steps_banner.size = Vector2(banner_w, 62)
	calibration_steps_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calibration_steps_banner.z_index = 40
	add_child(calibration_steps_banner)
	_rect(calibration_steps_banner, Vector2.ZERO, Vector2(banner_w, 62), Color(0.02, 0.03, 0.06, 0.86))
	_rect(calibration_steps_banner, Vector2.ZERO, Vector2(banner_w, 2), GOLD)
	_label(calibration_steps_banner, GameManager.text("FINDER CALIBRATION", "寻星镜校准步骤"), Vector2(0, 4), Vector2(banner_w, 18), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	calibration_step_labels.clear()
	var steps := [
		GameManager.text("1 Switch to Finder", "1 切换到寻星镜"),
		GameManager.text("2 Move with I/J/K/L", "2 方向键移动目标"),
		GameManager.text("3 Center the target", "3 移到中心"),
		GameManager.text("4 Alignment done", "4 完成校准"),
	]
	var chip_w := banner_w / float(steps.size())
	for i in range(steps.size()):
		var chip := _label(calibration_steps_banner, str(steps[i]), Vector2(chip_w * i, 26), Vector2(chip_w, 30), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		calibration_step_labels.append(chip)


func _active_calibration_step() -> int:
	if view_mode != "finder":
		return 0
	if GameManager.is_finder_aligned():
		return 3
	var offset: Dictionary = GameManager.finder_offset()
	var az := absf(float(offset.get("az", 0.0)))
	var alt := absf(float(offset.get("alt", 0.0)))
	return 2 if (az < 1.0 and alt < 1.0) else 1


func _update_calibration_steps_banner() -> void:
	if calibration_steps_banner == null or calibration_step_labels.is_empty():
		return
	# Show it whenever calibration is incomplete (in any view, so the "Switch to
	# Finder" step is visible from the telescope view too); hide once aligned.
	calibration_steps_banner.visible = _is_finder_calibration_level() and not GameManager.is_finder_aligned()
	var active := _active_calibration_step()
	for i in range(calibration_step_labels.size()):
		var chip := calibration_step_labels[i] as Label
		if i < active:
			chip.add_theme_color_override("font_color", GREEN)
		elif i == active:
			chip.add_theme_color_override("font_color", CYAN)
		else:
			chip.add_theme_color_override("font_color", MUTED)


func _draw_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_TEXTURE)
	bg.position = Vector2.ZERO
	bg.size = Vector2(W, H)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _load_png_texture(path: String) -> Texture2D:
	# `Image.load_from_file()` cannot read res:// assets once a Web build packs
	# them into the PCK. ResourceLoader keeps the texture available in-editor
	# and in exported builds.
	var texture := load(path) as Texture2D
	if texture == null:
		push_warning("Could not load sky observation texture: " + path)
		return null
	return texture


func _asset_texture_rect(parent: Control, path: String, rect: Rect2, stretch_mode := TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var texture_rect := TextureRect.new()
	# Set presentation rules before assigning geometry/texture so imported UI
	# art never flashes at source size during a rebuild.
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = stretch_mode
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _load_png_texture(path)
	texture_rect.position = rect.position
	texture_rect.size = rect.size
	parent.add_child(texture_rect)
	return texture_rect


func _build_scale_bands() -> void:
	# Fixed end caps and rails use the supplied art with its baked ticks removed.
	# The live tick pools below use pixel crops from that same art, so the actual
	# brass marks scroll with aim while labels remain authoritative Godot text.
	var az_shell_clip := Control.new()
	az_shell_clip.position = AZ_SCALE_ART_RECT.position
	az_shell_clip.size = AZ_SCALE_ART_RECT.size
	az_shell_clip.clip_contents = true
	az_shell_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(az_shell_clip)
	_asset_texture_rect(az_shell_clip, AZ_SCALE_TEXTURE, Rect2(Vector2.ZERO, AZ_SCALE_ART_RECT.size), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	var alt_shell_clip := Control.new()
	alt_shell_clip.position = ALT_SCALE_ART_RECT.position
	alt_shell_clip.size = ALT_SCALE_ART_RECT.size
	alt_shell_clip.clip_contents = true
	alt_shell_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alt_shell_clip)
	_asset_texture_rect(alt_shell_clip, ALT_SCALE_TEXTURE, Rect2(Vector2.ZERO, ALT_SCALE_ART_RECT.size), TextureRect.STRETCH_KEEP_ASPECT_COVERED)

	# Azimuth band (top): 0-360 with N/E/S/W and numbered majors.
	_rect(self, AZ_BAND.position + Vector2(0, AZ_BAND.size.y - 2), Vector2(AZ_BAND.size.x, 1), Color(GOLD.r, GOLD.g, GOLD.b, 0.45))
	az_band_layer = Control.new()
	az_band_layer.position = AZ_BAND.position
	az_band_layer.size = AZ_BAND.size
	az_band_layer.clip_contents = true
	az_band_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(az_band_layer)
	for index in range(AZ_TICK_POOL):
		var tick := TextureRect.new()
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.stretch_mode = TextureRect.STRETCH_KEEP
		tick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		az_band_layer.add_child(tick)
		az_ticks.append(tick)
	for index in range(AZ_LABEL_POOL):
		var label := _label(az_band_layer, "", Vector2.ZERO, Vector2(64, 16), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		label.visible = false
		az_labels.append(label)
	az_target_pointer = _asset_texture_rect(self, AZ_POINTER_TEXTURE, Rect2(Vector2.ZERO, Vector2(12, 70)))
	az_target_pointer.flip_v = true
	az_target_pointer.z_index = 62
	az_target_pointer.tooltip_text = GameManager.text("Current azimuth", "当前方位角")
	az_knob_icon = _asset_texture_rect(self, OBS_UI_DIR + "azimuth_knob.png", Rect2(Vector2(38, 50), Vector2(48, 48)))
	az_knob_icon.pivot_offset = az_knob_icon.size * 0.5
	az_knob_icon.z_index = 61

	# Altitude band (left): 0 horizon .. 90 zenith.
	_rect(self, ALT_BAND.position + Vector2(ALT_BAND.size.x - 2, 0), Vector2(1, ALT_BAND.size.y), Color(GOLD.r, GOLD.g, GOLD.b, 0.45))
	alt_band_layer = Control.new()
	alt_band_layer.position = ALT_BAND.position
	alt_band_layer.size = ALT_BAND.size
	alt_band_layer.clip_contents = true
	alt_band_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(alt_band_layer)
	for index in range(ALT_TICK_POOL):
		var tick := TextureRect.new()
		tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tick.stretch_mode = TextureRect.STRETCH_KEEP
		tick.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tick.visible = false
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alt_band_layer.add_child(tick)
		alt_ticks.append(tick)
	for index in range(ALT_LABEL_POOL):
		var label := _label(alt_band_layer, "", Vector2.ZERO, Vector2(30, 14), 10, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		label.visible = false
		alt_labels.append(label)
	alt_target_pointer = _asset_texture_rect(self, ALT_POINTER_TEXTURE, Rect2(Vector2.ZERO, Vector2(12, 70)))
	alt_target_pointer.pivot_offset = alt_target_pointer.size * 0.5
	alt_target_pointer.rotation = PI * 0.5
	alt_target_pointer.z_index = 62
	alt_target_pointer.tooltip_text = GameManager.text("Current altitude", "当前俯仰角")
	alt_knob_icon = _asset_texture_rect(self, OBS_UI_DIR + "altitude_knob.png", Rect2(Vector2(38, 624), Vector2(48, 48)))
	alt_knob_icon.pivot_offset = alt_knob_icon.size * 0.5
	alt_knob_icon.z_index = 61


func _build_view_layer() -> void:
	view_layer = Control.new()
	view_layer.position = VIEW_RECT.position
	view_layer.size = VIEW_RECT.size
	view_layer.clip_contents = true
	add_child(view_layer)

	# Sky brightness lift: a flat tint under everything else, strictly
	# clipped to the view rect by the parent's clip_contents (city/suburban
	# only; empty environment = fully transparent = zero visual change).
	sky_lift_layer = _rect(view_layer, Vector2.ZERO, VIEW_RECT.size, _sky_lift_color())
	sky_lift_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_lift_layer.z_index = Z_SKY

	for index in range(STAR_POOL_SIZE):
		var star := ColorRect.new()
		star.visible = false
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.z_index = Z_STARS
		view_layer.add_child(star)
		star_pool.append(star)

	# Ground band + horizon line, shown when aiming low.
	ground_rect = _rect(view_layer, Vector2.ZERO, Vector2.ZERO, GROUND_COLOR)
	ground_rect.visible = false
	horizon_line = _rect(view_layer, Vector2.ZERO, Vector2.ZERO, HORIZON_COLOR)
	horizon_line.visible = false
	_build_horizon_layers()

	# Cloud layer: above the star field, below the object icons/crosshair/UI.
	cloud_layer = Control.new()
	cloud_layer.size = VIEW_RECT.size
	cloud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_layer.z_index = Z_ATMOSPHERE
	view_layer.add_child(cloud_layer)
	_build_cloud_layer()

	for id_value in sky_data.keys():
		var object_id: String = str(id_value)
		if _is_constellation_target(object_id):
			constellation_overlay = ConstellationPatternOverlay.new()
			constellation_overlay.name = "ConstellationPatternOverlay"
			constellation_overlay.size = VIEW_RECT.size
			constellation_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			constellation_overlay.z_index = Z_OBJECTS
			view_layer.add_child(constellation_overlay)
			constellation_target_button = _transparent_button(Rect2(Vector2.ZERO, Vector2.ONE), GameManager.dict_text(GameManager.get_object(object_id), "name"))
			constellation_target_button.visible = false
			constellation_target_button.z_index = Z_OBJECTS + 1
			var constellation_id := object_id
			constellation_target_button.pressed.connect(func() -> void: _select_object(constellation_id))
			view_layer.add_child(constellation_target_button)
			object_buttons[object_id] = constellation_target_button
			continue
		var icon_path := _icon_path_for_object(object_id)
		if not ResourceLoader.exists(icon_path):
			continue
		var texture: Texture2D = load(icon_path)
		var icon := TextureRect.new()
		icon.texture = texture
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size = texture.get_size()
		icon.visible = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = Z_OBJECTS
		view_layer.add_child(icon)
		object_icons[object_id] = icon

		var button := _transparent_button(Rect2(Vector2.ZERO, texture.get_size()), GameManager.dict_text(GameManager.get_object(object_id), "name"))
		button.visible = false
		var captured_id := object_id
		button.pressed.connect(func() -> void: _select_object(captured_id))
		button.z_index = Z_OBJECTS + 1
		view_layer.add_child(button)
		object_buttons[object_id] = button

	_build_optical_lens_overlay()
	_build_edge_target_indicator()
	_build_faint_mission_target_waypoint()
	_build_scope_reticle_overlay()
	_build_mode_transition_overlay()

	# DMS readouts on the center lines (the crosshair + reticle ring are
	# baked into the v2 background, centered on this view).
	az_readout = _label(view_layer, "", Vector2(VIEW_RECT.size.x * 0.5 - 110, 6), Vector2(220, 22), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	alt_readout = _label(view_layer, "", Vector2(10, VIEW_RECT.size.y * 0.5 - 28), Vector2(180, 22), 14, GOLD)
	az_readout.z_index = Z_DYNAMIC_READOUT
	alt_readout.z_index = Z_DYNAMIC_READOUT

	# Reserve one HUD band at the bottom of the viewport. The permanent key
	# legend comes first; live target guidance sits below it and never covers
	# the telescope's optical center.
	guidance_banner_bg = _rect(view_layer, Vector2(0, VIEW_RECT.size.y - 118), Vector2(VIEW_RECT.size.x, 118), Color(0.01, 0.02, 0.035, 0.90))
	guidance_banner_bg.z_index = Z_GUIDANCE
	guidance_banner = _label(view_layer, "", Vector2(18, VIEW_RECT.size.y - 80), Vector2(VIEW_RECT.size.x - 36, 72), 15, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	guidance_banner.z_index = Z_GUIDANCE + 1
	guidance_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guidance_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_banner.max_lines_visible = 2

	# Persistent control legend. Live guidance is deliberately below this row.
	controls_help = _label(
		view_layer,
		GameManager.text(
			"MOVE  A/D: west/east   W/S: up/down   Shift: faster   1/2/3: view",
			"移动  A/D：向西/向东   W/S：抬高/降低   Shift：加速   1/2/3：视野"
		),
		Vector2(12, VIEW_RECT.size.y - 112),
		Vector2(VIEW_RECT.size.x - 24, 30),
		14,
		Color(0.88, 0.91, 0.94),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	controls_help.z_index = Z_GUIDANCE + 1
	controls_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART



func _build_edge_target_indicator() -> void:
	edge_navigation_trail = EdgeNavigationTrail.new()
	edge_navigation_trail.name = "EdgeNavigationTrail"
	edge_navigation_trail.size = VIEW_RECT.size
	edge_navigation_trail.visible = false
	edge_navigation_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_navigation_trail.z_index = Z_DYNAMIC_READOUT + 1
	view_layer.add_child(edge_navigation_trail)

	edge_target_indicator = Panel.new()
	edge_target_indicator.name = "EdgeTargetIndicator"
	edge_target_indicator.size = Vector2(224, 68)
	edge_target_indicator.visible = false
	edge_target_indicator.modulate.a = 0.0
	edge_target_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_target_indicator.z_index = Z_DYNAMIC_READOUT + 2
	view_layer.add_child(edge_target_indicator)

	edge_target_arrow = Polygon2D.new()
	edge_target_arrow.polygon = PackedVector2Array([Vector2(-7, -8), Vector2(10, 0), Vector2(-7, 8), Vector2(-2, 0)])
	edge_target_arrow.position = Vector2(18, 34)
	edge_target_indicator.add_child(edge_target_arrow)
	edge_target_name = _label(edge_target_indicator, "", Vector2(38, 6), Vector2(178, 22), 13, GOLD)
	edge_target_name.clip_text = true
	edge_target_delta = _label(edge_target_indicator, "", Vector2(38, 27), Vector2(178, 36), 12, TEXT)
	edge_target_delta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edge_target_delta.max_lines_visible = 2


func _build_faint_mission_target_waypoint() -> void:
	faint_mission_target_waypoint = FaintMissionTargetWaypoint.new()
	faint_mission_target_waypoint.name = "FaintMissionTargetWaypoint"
	faint_mission_target_waypoint.visible = false
	faint_mission_target_waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faint_mission_target_waypoint.z_index = Z_TARGET_FEEDBACK
	view_layer.add_child(faint_mission_target_waypoint)


func _build_mode_buttons() -> void:
	# Fully hide the old baked controls before adding the independent supplied
	# icons. Labels and availability remain dynamic in both languages.
	_rect(self, MODE_BUTTONS_OVERLAY_RECT.position, MODE_BUTTONS_OVERLAY_RECT.size, PANEL_COVER)

	view_mode_caption = _label(self, "", Vector2(288, 708), Vector2(230, 20), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var icon_paths := {
		"naked_eye": OBS_UI_DIR + "mode_eye_icon.png",
		"finder": OBS_UI_DIR + "mode_finder_icon.png",
		"telescope": OBS_UI_DIR + "mode_scope_icon.png"
	}
	for mode_value in MODE_RECTS.keys():
		var mode: String = str(mode_value)
		var rect: Rect2 = MODE_RECTS[mode]
		var shade := _rect(self, rect.position, rect.size, Color(0.01, 0.03, 0.07, 0.18))
		var icon_rect := Rect2(rect.position + Vector2(8, 5), Vector2(rect.size.x - 16, 46))
		var icon := _asset_texture_rect(self, str(icon_paths[mode]), icon_rect)
		# Keep the selected-state border inside the shared button bounds so all
		# three view icons retain exactly the same outer size.
		var frame := _make_frame(self, rect.grow(-2.0), CYAN, 3)
		frame.visible = false
		var caption := _label(self, _mode_label(mode), rect.position + Vector2(2, 51), Vector2(rect.size.x - 4, 18), 11, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		var status := _label(self, "", rect.position + Vector2(50, 3), Vector2(18, 18), 12, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
		var hot := _transparent_button(rect, _mode_label(mode))
		var captured := mode
		hot.pressed.connect(func() -> void: _set_view_mode(captured))
		add_child(hot)
		mode_buttons[mode] = {"shade": shade, "frame": frame, "icon": icon, "button": hot, "status": status, "caption": caption}
		hot.mouse_entered.connect(func() -> void:
			var state: Dictionary = mode_buttons.get(captured, {})
			if captured != view_mode and bool(_mode_available(captured).get("ok", false)):
				var hover_shade: ColorRect = state.get("shade")
				hover_shade.color = Color(0.12, 0.52, 0.72, 0.22)
		)
		hot.mouse_exited.connect(func() -> void: _update_mode_buttons())


func _update_mode_buttons() -> void:
	for mode_value in mode_buttons.keys():
		var mode: String = str(mode_value)
		var parts: Dictionary = mode_buttons[mode]
		var shade: ColorRect = parts.get("shade")
		var frame: Control = parts.get("frame")
		var icon: TextureRect = parts.get("icon")
		var button: Button = parts.get("button")
		var status: Label = parts.get("status")
		var caption: Label = parts.get("caption")
		var active := mode == view_mode
		var availability := _mode_available(mode)
		var available := bool(availability.get("ok", false))
		frame.visible = active
		shade.color = Color(0.10, 0.62, 0.96, 0.28) if active else (Color(0.20, 0.06, 0.04, 0.38) if not available else Color(0.01, 0.03, 0.07, 0.18))
		icon.modulate = Color.WHITE if active else (Color(0.42, 0.45, 0.48, 0.62) if not available else Color(0.82, 0.88, 0.94, 0.90))
		caption.add_theme_color_override("font_color", CYAN if active else (Color(0.58, 0.58, 0.58) if not available else TEXT))
		status.text = "!" if not available else ""
		button.disabled = not available
		InteractionFeedback.selection(button, active, CYAN, true, "mode_selected")
		button.tooltip_text = _mode_label(mode) if available else GameManager.text(str(availability.get("en", "Unavailable")), str(availability.get("zh", "不可用")))
	if view_mode_caption != null:
		var captions := {"naked_eye": GameManager.text("EYE VIEW", "肉眼视野"), "finder": GameManager.text("FINDER VIEW", "寻星镜视野"), "telescope": GameManager.text("SCOPE VIEW", "望远镜视野")}
		view_mode_caption.text = "·  %s  ·" % str(captions.get(view_mode, "VIEW"))
	_update_reticle_asset()


func _build_scope_reticle_overlay() -> void:
	# Exactly one supplied transparent aiming overlay is active per mode.
	var reticle := TextureRect.new()
	reticle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	reticle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	reticle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope_reticle_layer = reticle
	scope_reticle_layer.position = AIM_RETICLE_RECT.position
	scope_reticle_layer.size = AIM_RETICLE_RECT.size
	scope_reticle_layer.z_index = Z_AIM_OVERLAY
	view_layer.add_child(scope_reticle_layer)
	_update_reticle_asset()
	scope_reticle_layer.visible = true
	_ensure_scope_reticle_visible()


func _build_mode_transition_overlay() -> void:
	optical_mode_transition = OpticalModeTransition.new()
	optical_mode_transition.name = "OpticalModeTransition"
	optical_mode_transition.size = VIEW_RECT.size
	optical_mode_transition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	optical_mode_transition.z_index = Z_AIM_OVERLAY - 1
	optical_mode_transition.active = false
	view_layer.add_child(optical_mode_transition)


func _build_optical_lens_overlay() -> void:
	# Post-process only the moving sky/environment. Target feedback, reticles,
	# coordinates and guidance live at higher z-indices and remain undistorted.
	optical_lens_overlay = ColorRect.new()
	optical_lens_overlay.name = "OpticalLensOverlay"
	optical_lens_overlay.position = Vector2.ZERO
	optical_lens_overlay.size = VIEW_RECT.size
	optical_lens_overlay.color = Color.WHITE
	optical_lens_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	optical_lens_overlay.z_index = Z_OPTICAL_GLASS
	optical_lens_material = ShaderMaterial.new()
	optical_lens_material.shader = OPTICAL_LENS_SHADER
	optical_lens_material.set_shader_parameter(
		"region_uv_size",
		Vector2(VIEW_RECT.size.x / W, VIEW_RECT.size.y / H)
	)
	optical_lens_material.set_shader_parameter("circular_lens", 0.0)
	optical_lens_overlay.material = optical_lens_material
	view_layer.add_child(optical_lens_overlay)
	_update_optical_lens_mode()


func _update_optical_lens_mode() -> void:
	if optical_lens_material == null:
		return
	var curvature := 0.018
	var vignette := 0.075
	var chroma := 0.06
	var highlight := 0.025
	var bloom := 0.025
	var scanline := 0.006
	var rim := 0.0
	var caustic := 0.0
	match view_mode:
		"finder":
			curvature = 0.046
			vignette = 0.13
			chroma = 0.15
			highlight = 0.046
			bloom = 0.060
			scanline = 0.012
			rim = 0.035
			caustic = 0.025
		"telescope":
			curvature = 0.082
			vignette = 0.21
			chroma = 0.30
			highlight = 0.072
			bloom = 0.11
			scanline = 0.018
			rim = 0.075
			caustic = 0.050
	optical_lens_material.set_shader_parameter("curvature", curvature)
	optical_lens_material.set_shader_parameter("vignette_strength", vignette)
	optical_lens_material.set_shader_parameter("chroma_px", chroma)
	optical_lens_material.set_shader_parameter("glass_highlight", highlight)
	optical_lens_material.set_shader_parameter("edge_bloom", bloom)
	optical_lens_material.set_shader_parameter("scanline_strength", scanline)
	optical_lens_material.set_shader_parameter("lens_rim_strength", rim)
	optical_lens_material.set_shader_parameter("lens_caustic_strength", caustic)


func _update_reticle_asset() -> void:
	if not scope_reticle_layer is TextureRect:
		return
	var reticle := scope_reticle_layer as TextureRect
	reticle.texture = _load_png_texture(str(MODE_RETICLE_TEXTURES.get(view_mode, MODE_RETICLE_TEXTURES["naked_eye"])))
	reticle.modulate = Color(1.0, 1.0, 1.0, 0.72 if view_mode == "naked_eye" else (0.86 if view_mode == "finder" else 1.0))
	reticle.set_meta("reticle_mode", view_mode)


func _ensure_scope_reticle_visible() -> void:
	if view_layer == null or not is_instance_valid(view_layer):
		return
	if scope_reticle_layer == null or not is_instance_valid(scope_reticle_layer):
		scope_reticle_layer = null
		_build_scope_reticle_overlay()
		return
	if scope_reticle_layer.get_parent() != view_layer:
		scope_reticle_layer.queue_free()
		scope_reticle_layer = null
		_build_scope_reticle_overlay()
		return
	# The aiming frame is functional UI, not a mode-specific decoration. Keep
	# it above stars, target icons, clouds and sky lift in every view mode.
	scope_reticle_layer.visible = true
	scope_reticle_layer.z_index = Z_AIM_OVERLAY
	scope_reticle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(scope_reticle_layer.get_meta("reticle_mode", "")) != view_mode:
		_update_reticle_asset()


func _cover_baked_text() -> void:
	# The v2 background bakes in static scale numbers, a sample galaxy at
	# the reticle center and a "SCOPE VIEW" caption - hide those so the
	# dynamic versions can take over. Background there is pure black.
	_rect(self, AZ_BAND.position, AZ_BAND.size, Color.BLACK)
	_rect(self, ALT_BAND.position, ALT_BAND.size, Color.BLACK)
	# The replacement sky layer supplies every star, horizon and reticle. A
	# clean field removes the old baked crosshair/ring in all three modes.
	_rect(self, VIEW_RECT.position, VIEW_RECT.size, Color.BLACK)
	_rect(self, Vector2(326, 706), Vector2(170, 26), Color.BLACK)


func _build_panel_text() -> void:
	# MISSION panel interior: (775..995, 75..228) on the v2 background.
	var target: Dictionary = GameManager.get_object(target_id)

	_label(self, GameManager.text("Target:", "目标:"), Vector2(778, 80), Vector2(70, 22), 14, WARNING)
	_label(self, GameManager.dict_text(target, "name"), Vector2(848, 80), Vector2(140, 22), 14, Color(0.84, 0.62, 1.0))

	var hint_label := _label(self, _wrapped_mission_hint(target), Vector2(778, 106), Vector2(210, 78), 13, TEXT)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.max_lines_visible = 5
	mission_tonight_label = _label(self, "", Vector2(778, 188), Vector2(212, 18), 12, MUTED)
	_update_mission_tonight_text()
	sky_condition_label = _label(self, "", Vector2(778, 207), Vector2(212, 17), 11, MUTED)
	_update_sky_condition_text()

	# SELECTED panel state is driven by the same active object as Observe.
	selected_panel_border = Panel.new()
	selected_panel_border.position = Vector2(768, 282)
	selected_panel_border.size = Vector2(232, 194)
	selected_panel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_panel_border.z_index = 1
	add_child(selected_panel_border)
	selected_badge = _label(self, "", Vector2(778, 287), Vector2(210, 18), 12, GOLD)
	selected_title = _label(self, "", Vector2(778, 306), Vector2(210, 20), 14, Color(0.84, 0.62, 1.0))
	selected_title.clip_text = true
	selected_detail = _label(self, "", Vector2(778, 328), Vector2(214, 58), 11, TEXT)
	selected_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_detail.max_lines_visible = 4

	aim_label = _label(self, "", Vector2(778, 389), Vector2(214, 46), 11, TEXT)
	aim_label.max_lines_visible = 3

	guidance_label = _label(self, "", Vector2(778, 440), Vector2(214, 30), 11, WARNING, HORIZONTAL_ALIGNMENT_CENTER)
	guidance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guidance_label.max_lines_visible = 2

	_update_selected_text()


func _mission_hint(target: Dictionary) -> String:
	var level := GameManager.current_level()
	if _is_constellation_target(str(target.get("id", ""))):
		return GameManager.text("Find the complete star pattern first; use the finder to center the whole group.", "先寻找完整星群，再用寻星镜把整组星星居中。")
	# Coordinate-navigation lessons hide the distant locator, so keep their
	# explicit steering instructions instead of replacing them with object trivia.
	if bool(level.get("hide_target_hint", false)) and level.has("hint_text_en"):
		return GameManager.dict_text(level, "hint_text")
	match str(target.get("id", "")):
		"moon":
			return GameManager.text("Look for the brightest round object.", "寻找最亮的圆形目标。")
		"polaris":
			return GameManager.text("Look toward the northern sky.", "望向北方天空。")
		"sirius":
			return GameManager.text("Find a bright blue-white star.", "寻找明亮的蓝白色恒星。")
		"betelgeuse":
			return GameManager.text("Find a reddish star in Orion.", "寻找猎户座方向偏红的恒星。")
		"mars":
			return GameManager.text("Find a reddish planet.", "寻找偏红的行星。")
		"jupiter":
			return GameManager.text("Find the large striped planet.", "寻找带条纹的大行星。")
		"orion_nebula":
			return GameManager.text("Find the purple cloud near Orion.", "寻找猎户座附近的紫色云雾。")
		"andromeda":
			return GameManager.text("Find a faint oval galaxy.", "寻找暗淡的椭圆形星系。")
	var fallback := GameManager.text("Rotate the view to find the mission target.", "转动视野寻找任务目标。")
	return GameManager.dict_text(level, "hint_text") if level.has("hint_text_en") else fallback


func _wrapped_mission_hint(target: Dictionary) -> String:
	var source := _mission_hint(target)
	if source.contains("\n"):
		return source
	if GameManager.language_mode == "zh":
		var lines: Array[String] = []
		for start in range(0, source.length(), 18):
			lines.append(source.substr(start, mini(18, source.length() - start)))
		return "\n".join(lines)
	var words := source.split(" ", false)
	var lines: Array[String] = []
	var current := ""
	for word_value in words:
		var word := str(word_value)
		if current == "":
			current = word
		elif current.length() + 1 + word.length() <= 32:
			current += " " + word
		else:
			lines.append(current)
			current = word
	if current != "":
		lines.append(current)
	return "\n".join(lines)


func _draw_action_hitboxes() -> void:
	observe_disabled_shade = _rect(self, OBSERVE_RECT.position + Vector2(4, 4), OBSERVE_RECT.size - Vector2(8, 8), Color(0.0, 0.0, 0.0, 0.52))
	observe_disabled_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	observe_button = _transparent_button(OBSERVE_RECT, "Observe")
	observe_button.pressed.connect(_observe)
	add_child(observe_button)

	var back := _transparent_button(BACK_RECT, GameManager.text("Back to Base", "返回基地"))
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	add_child(back)

	# Maya introduces site selection after the ten local foundation lessons.
	# Until then, that UI is absent rather than presenting an unexplained route.
	if not GameManager.uses_foundation_training_schedule():
		var location_button := Button.new()
		location_button.name = "ChangeSiteButton"
		location_button.text = GameManager.text("Location / Change Site", "地点 / 更换地点")
		location_button.position = Vector2(778, 233)
		location_button.size = Vector2(210, 27)
		location_button.add_theme_font_size_override("font_size", 12)
		var location_style := StyleBoxFlat.new()
		location_style.bg_color = Color(0.035, 0.075, 0.12, 0.96)
		location_style.border_color = CYAN
		location_style.set_border_width_all(1)
		location_style.set_corner_radius_all(3)
		location_button.add_theme_stylebox_override("normal", location_style)
		location_button.pressed.connect(_open_world_map_from_sky)
		add_child(location_button)

	# Object details button: fixed in the SELECTED panel's title bar (right side)
	# so it never covers the object name, coordinates, or aim text below.
	var details_btn := Button.new()
	details_btn.name = "DetailsButton"
	details_btn.text = GameManager.text("ⓘ", "ⓘ")
	details_btn.position = Vector2(936, 291)
	details_btn.size = Vector2(56, 19)
	details_btn.tooltip_text = GameManager.text("Object details", "天体详情")
	details_btn.add_theme_font_size_override("font_size", 11)
	details_btn.add_theme_color_override("font_color", CYAN)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.04, 0.09, 0.14, 0.9)
	ds.border_color = CYAN
	ds.set_border_width_all(1)
	ds.set_corner_radius_all(3)
	details_btn.add_theme_stylebox_override("normal", ds)
	details_btn.pressed.connect(_open_detail_panel)
	add_child(details_btn)
	_update_observe_state()


func _open_world_map_from_sky() -> void:
	if location_transition_active or not is_inside_tree() or GameManager.uses_foundation_training_schedule():
		return
	location_transition_active = true
	GameManager.last_sky_aim = {
		"valid": true,
		"azimuth": telescope_azimuth,
		"altitude": telescope_altitude,
		"view_mode": view_mode
	}
	GameManager.selected_object_id = _active_observation_object_id()
	GameManager.selected_object_level = int(GameManager.progress.get("current_level", 1))
	GameManager.world_map_target_id = _active_observation_object_id()
	GameManager.world_map_observation_context = {
		"target_id": _active_observation_object_id(),
		"free_observation": _is_free_selection(),
		"level": int(GameManager.progress.get("current_level", 1)),
		"view_mode": view_mode,
		"azimuth": telescope_azimuth,
		"altitude": telescope_altitude
	}
	if InteractionFeedback.is_reduced_motion():
		GameManager.open_world_map("sky")
		return
	var fade := ColorRect.new()
	fade.name = "MapTransitionFade"
	fade.color = Color(0.01, 0.02, 0.05, 0.0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	fade.z_index = 1000
	add_child(fade)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade, "color:a", 0.82, 0.24)
	if view_layer != null:
		view_layer.pivot_offset = VIEW_RECT.get_center()
		tween.tween_property(view_layer, "scale", Vector2(0.96, 0.96), 0.24).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void: GameManager.open_world_map("sky"))


# ------------------------------------------------------------ view refresh


func _fov_to_local(delta_az: float, delta_alt: float) -> Vector2:
	return Vector2(
		VIEW_RECT.size.x * 0.5 + (delta_az / (display_fov_x * 0.5)) * (VIEW_RECT.size.x * 0.48),
		VIEW_RECT.size.y * 0.5 - (delta_alt / (display_fov_y * 0.5)) * (VIEW_RECT.size.y * 0.48)
	)


func _object_category(obj: Dictionary) -> String:
	var id := str(obj.get("id", ""))
	if id == "moon":
		return "moon"
	var type_lower := str(obj.get("type_en", "")).to_lower()
	if type_lower.contains("nebula") or type_lower.contains("galaxy"):
		return "deep_sky"
	if type_lower.contains("planet"):
		return "planet"
	return "star"


func _is_constellation_target(object_id: String) -> bool:
	return not GameManager.get_constellation(object_id).is_empty()


func _constellation_positions(delta_az: float, delta_alt: float, data: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for star_value in data.get("stars", []):
		var star: Dictionary = star_value
		var star_delta_az := delta_az + (float(star.get("x", 0.5)) - 0.5) * CONSTELLATION_SPAN_AZIMUTH
		var star_delta_alt := delta_alt + (0.5 - float(star.get("y", 0.5))) * CONSTELLATION_SPAN_ALTITUDE
		result.append(_fov_to_local(star_delta_az, star_delta_alt))
	return result


func _rebuild_constellation_target(object_id: String, half_x: float, half_y: float, offset_az: float, offset_alt: float) -> void:
	if constellation_overlay == null or constellation_target_button == null:
		return
	var data := GameManager.get_constellation(object_id)
	var item := _sky_item(object_id)
	var altitude := float(item.get("altitude", 0.0))
	var delta_az := shortest_angle_degrees(display_azimuth, float(item.get("azimuth", 0.0))) + offset_az
	var delta_alt := altitude - display_altitude + offset_alt
	var positions := _constellation_positions(delta_az, delta_alt, data)
	var magnitudes: Array[float] = []
	var bounds := Rect2()
	for index in range(positions.size()):
		var star: Dictionary = data.get("stars", [])[index]
		magnitudes.append(float(star.get("magnitude", 2.0)))
		var point_rect := Rect2(positions[index] - Vector2.ONE * 4.0, Vector2.ONE * 8.0)
		bounds = point_rect if index == 0 else bounds.merge(point_rect)
	var constellation_half_az := CONSTELLATION_SPAN_AZIMUTH * 0.5
	var constellation_half_alt := CONSTELLATION_SPAN_ALTITUDE * 0.5
	var in_view := altitude > 0.0 and absf(delta_az) <= half_x + constellation_half_az and absf(delta_alt) <= half_y + constellation_half_alt
	var visible_rect := Rect2(Vector2.ZERO, VIEW_RECT.size).grow(20.0)
	in_view = in_view and visible_rect.intersects(bounds)
	var centered := absf(shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0)))) <= _center_tolerance() and absf(float(item.get("altitude", 0.0)) - telescope_altitude) <= _center_tolerance()
	var feedback_state := ""
	if in_view:
		feedback_state = "locked" if centered else ("approach" if maxf(absf(delta_az), absf(delta_alt)) <= maxf(fov_x, fov_y) * 0.22 else "")
	constellation_overlay.visible = in_view
	constellation_overlay.update_pattern(positions, magnitudes, bounds, feedback_state)
	constellation_target_button.visible = in_view
	if not in_view:
		return
	var hit_rect := bounds.grow(16.0)
	constellation_target_button.position = hit_rect.position
	constellation_target_button.size = hit_rect.size
	in_view_targets[object_id] = {
		"delta_az": delta_az,
		"delta_alt": delta_alt,
		"rect": bounds,
		"detection_rect": hit_rect
	}


func _object_visual_for_mode(obj: Dictionary) -> Dictionary:
	# How an object appears in the CURRENT view mode. Detail images belong
	# to the Telescope View only; here everything is a finding mark whose
	# rendered pixel size comes from RENDER_SIZES (mode x category).
	var magnitude: float = float(obj.get("apparent_magnitude", 6.0))
	var category := _object_category(obj)
	var size_px := _continuous_render_size(category, magnitude)
	var alpha := 1.0
	var shown := true
	match view_mode:
		"naked_eye":
			if magnitude > 7.5:
				shown = false
			elif category == "deep_sky" or magnitude > 5.5:
				alpha = 0.14  # unknown faint smudge
		"finder":
			if magnitude > 9.0:
				shown = false
			elif category == "deep_sky":
				alpha = 0.5  # still a blur, no structure
		"telescope":
			alpha = 0.9
			if category == "deep_sky":
				alpha = 0.6
	if category == "deep_sky":
		alpha *= _deep_sky_city_dim()
	alpha *= mode_content_alpha
	return {"shown": shown, "alpha": alpha, "size_px": size_px}


func _continuous_render_size(category: String, magnitude: float) -> float:
	var eye_size := float((RENDER_SIZES["naked_eye"] as Dictionary).get(category, 2.0))
	var finder_size := float((RENDER_SIZES["finder"] as Dictionary).get(category, eye_size))
	var scope_size := float((RENDER_SIZES["telescope"] as Dictionary).get(category, finder_size))
	if category == "star" and magnitude > 0.0:
		eye_size = 1.0
		finder_size = 2.0
	if display_fov_x >= float(VIEW_MODES["finder"]["fov_x"]):
		var eye_to_finder := clampf(inverse_lerp(
			float(VIEW_MODES["naked_eye"]["fov_x"]),
			float(VIEW_MODES["finder"]["fov_x"]),
			display_fov_x
		), 0.0, 1.0)
		return lerpf(eye_size, finder_size, eye_to_finder)
	var finder_to_scope := clampf(inverse_lerp(
		float(VIEW_MODES["finder"]["fov_x"]),
		float(VIEW_MODES["telescope"]["fov_x"]),
		display_fov_x
	), 0.0, 1.0)
	return lerpf(finder_size, scope_size, finder_to_scope)


func _rebuild_view(sync_camera := true) -> void:
	# Direct rebuilds are used by level jumps, tests and catalog refreshes.
	# Those are camera teleports, not player steering, so the visual camera
	# must start at the new real aim. The per-frame chase opts out above.
	if sync_camera:
		display_azimuth = telescope_azimuth
		display_altitude = telescope_altitude
	in_view_targets.clear()
	var half_x := display_fov_x * 0.5
	var half_y := display_fov_y * 0.5
	var offset_az := 0.0
	var offset_alt := 0.0
	if view_mode == "finder":
		# The finder crosshair itself does not move, but everything it shows
		# is displaced by the (uncalibrated) mechanical misalignment: what
		# looks centered in the finder may not really be centered.
		var offset: Dictionary = GameManager.finder_offset()
		offset_az = float(offset.get("az", 0.0))
		offset_alt = float(offset.get("alt", 0.0))

	var pool_index := 0
	for point in star_points:
		var star_delta_az := shortest_angle_degrees(display_azimuth, point.x) + offset_az
		var star_delta_alt := point.y - display_altitude + offset_alt
		if absf(star_delta_az) > half_x or absf(star_delta_alt) > half_y:
			continue
		if pool_index >= star_pool.size():
			break
		var star := star_pool[pool_index]
		pool_index += 1
		var star_pos := _fov_to_local(star_delta_az, star_delta_alt)
		star.position = star_pos - Vector2(point.z, point.z) * 0.5
		star.size = Vector2(point.z, point.z)
		var base_color := Color(point.w, point.w, minf(point.w + 0.08, 1.0), 0.85)
		star.set_meta("base_color", base_color)
		star.color = base_color
		star.visible = true
	for index in range(pool_index, star_pool.size()):
		star_pool[index].visible = false

	for id_value in sky_data.keys():
		var object_id: String = str(id_value)
		if _is_constellation_target(object_id):
			_rebuild_constellation_target(object_id, half_x, half_y, offset_az, offset_alt)
			continue
		if not object_icons.has(object_id):
			continue
		var icon: TextureRect = object_icons[object_id]
		var button: Button = object_buttons[object_id]
		var item: Dictionary = sky_data[object_id]
		var obj: Dictionary = GameManager.get_object(object_id)
		var altitude: float = float(item.get("altitude", 0.0))
		var delta_az := shortest_angle_degrees(display_azimuth, float(item.get("azimuth", 0.0))) + offset_az
		var delta_alt := altitude - display_altitude + offset_alt
		var visual := _object_visual_for_mode(obj)
		var center_local := _fov_to_local(delta_az, delta_alt)
		var geometrically_in_view: bool = altitude > 0.0 and absf(delta_az) <= half_x and absf(delta_alt) <= half_y
		if geometrically_in_view and view_mode == "telescope":
			var aperture_radius := minf(VIEW_RECT.size.x, VIEW_RECT.size.y) * 0.445
			geometrically_in_view = center_local.distance_to(VIEW_RECT.size * 0.5) <= aperture_radius
		var faint_mission_target := object_id == target_id and geometrically_in_view and not bool(visual.get("shown", true))
		var object_visible := geometrically_in_view and bool(visual.get("shown", true)) and not faint_mission_target
		# A faint mission object can be scientifically invisible to the naked
		# eye while its catalog coordinates are still known. Keep the object
		# itself dark, but retain a waypoint at its true projected position.
		var mission_waypoint_visible := geometrically_in_view and object_id == target_id and (faint_mission_target or not bool(visual.get("shown", true)))
		icon.visible = object_visible
		button.visible = object_visible or mission_waypoint_visible
		if not object_visible and not mission_waypoint_visible:
			continue
		var texture_size: Vector2 = icon.texture.get_size()
		var icon_scale: float = float(visual.get("size_px", 2.0)) / maxf(texture_size.x, texture_size.y)
		icon.scale = Vector2.ONE * icon_scale
		var icon_size: Vector2 = texture_size * icon_scale if object_visible else Vector2(2.0, 2.0)
		var rect := Rect2(center_local - icon_size * 0.5, icon_size)
		icon.position = rect.position
		var alpha: float = float(visual.get("alpha", 1.0))
		if str(item.get("visibility_text", "")) == "Low on horizon":
			alpha *= 0.7
		icon.set_meta("base_alpha", alpha)
		icon.modulate = Color(1, 1, 1, alpha)
		# The visible target marker and the real pointer/click detection region
		# are deliberately identical.
		var detection_diameter := _target_feedback_ring_size(maxf(icon_size.x, icon_size.y))
		var hit_rect := Rect2(center_local - Vector2.ONE * detection_diameter * 0.5, Vector2.ONE * detection_diameter)
		button.position = hit_rect.position
		button.size = hit_rect.size
		in_view_targets[object_id] = {
			"delta_az": delta_az,
			"delta_alt": delta_alt,
			"rect": rect,
			"detection_rect": hit_rect,
			"object_visible": object_visible,
			"faint_waypoint": faint_mission_target and not object_visible
		}

	_update_ground()
	_update_scales()
	_update_marker_frames()
	_update_aim_text()
	_update_selected_text()
	_update_guidance()


const HORIZON_SETS_PATH := "res://data/horizon_sets.json"
const HORIZON_DIR := "res://assets/horizon/processed/"
const HORIZON_SHADER_PATH := "res://assets/shaders/horizon_night_cleanup.gdshader"
# Art layers all stay below Z_STARS. `vertical` controls pitch response: distant
# silhouettes move less vertically than the nearby platform.
const HORIZON_LAYER_SPEC := [
	{"key": "far", "role": "far_mountains", "parallax": 0.18, "vertical": 0.55, "z": 2, "height": 0.20, "rise": 1.28, "alpha": 0.74, "tint": Color.WHITE, "exposure": 1.00, "saturation": 1.00},
	{"key": "mid", "role": "midground_observatory", "parallax": 0.48, "vertical": 0.76, "z": 5, "height": 0.25, "rise": 0.86, "alpha": 0.88, "tint": Color.WHITE, "exposure": 1.00, "saturation": 1.00},
	{"key": "near", "role": "foreground_platform_equipment", "parallax": 1.00, "vertical": 1.00, "z": 8, "height": 0.31, "rise": 0.62, "alpha": 0.92, "tint": Color.WHITE, "exposure": 1.00, "saturation": 1.00}
]
const HORIZON_TILE_COPIES := 6
const HORIZON_CLOUD_TILE_COPIES := 4

var horizon_layers: Array = []      # [{sprites:[TextureRect,TextureRect], spec:Dictionary, width:float}]
var horizon_cloud_sprites: Array = []
var horizon_cloud_drift := 0.0
var horizon_unwrapped_azimuth := 0.0
var horizon_last_azimuth := 0.0
var horizon_azimuth_initialized := false


func _build_horizon_layers() -> void:
	horizon_layers.clear()
	horizon_cloud_sprites.clear()
	var manifest: Dictionary = _load_horizon_manifest()
	if manifest.is_empty():
		return
	var set_name := _horizon_set_name(manifest)
	var sets: Dictionary = manifest.get("sets", {})
	var layer_set: Dictionary = sets.get(set_name, {})
	for spec_value in HORIZON_LAYER_SPEC:
		var spec: Dictionary = spec_value
		var asset := str(layer_set.get(str(spec["key"]), ""))
		if asset == "":
			continue
		var path := HORIZON_DIR + asset + ".png"
		if not ResourceLoader.exists(path):
			continue
		var texture: Texture2D = load(path)
		# Small source strips can be narrower than the viewport after scaling.
		# Six copies cover the widest supported view plus one spare tile on each
		# side, so rotation cannot expose a black gap.
		var sprites: Array = []
		for i in range(HORIZON_TILE_COPIES):
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.texture = texture
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.z_index = Z_SKY + int(spec["z"])
			tr.modulate = Color(1, 1, 1, float(spec["alpha"]))
			tr.material = _horizon_material(spec)
			view_layer.add_child(tr)
			sprites.append(tr)
		horizon_layers.append({"sprites": sprites, "spec": spec, "texture": texture})
	# Horizon clouds: the user's transparent cloud bands, only near the horizon.
	var clouds: Dictionary = manifest.get("clouds", {})
	for cloud_key in ["band", "layer"]:
		var cname := str(clouds.get(cloud_key, ""))
		if cname == "":
			continue
		var cpath := HORIZON_DIR + cname + ".png"
		if not ResourceLoader.exists(cpath):
			continue
		var ctex: Texture2D = load(cpath)
		var pair: Array = []
		for i in range(HORIZON_CLOUD_TILE_COPIES):
			var ct := TextureRect.new()
			ct.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ct.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ct.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ct.texture = ctex
			ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ct.z_index = Z_SKY + 11
			ct.material = _horizon_material({
				"tint": Color(0.38, 0.48, 0.64),
				"exposure": 0.38,
				"saturation": 0.36
			})
			view_layer.add_child(ct)
			pair.append(ct)
		horizon_cloud_sprites.append({
			"sprites": pair,
			"texture": ctex,
			"drift_speed": 0.20 if cloud_key == "band" else 0.13,
			"parallax": 0.14
		})


func _horizon_material(spec: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(HORIZON_SHADER_PATH)
	material.set_shader_parameter("night_tint", spec.get("tint", Color(0.52, 0.62, 0.76)))
	material.set_shader_parameter("exposure", float(spec.get("exposure", 0.66)))
	material.set_shader_parameter("saturation", float(spec.get("saturation", 0.72)))
	return material


func _load_horizon_manifest() -> Dictionary:
	if not FileAccess.file_exists(HORIZON_SETS_PATH):
		return {}
	var f := FileAccess.open(HORIZON_SETS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _horizon_set_name(manifest: Dictionary) -> String:
	var site_id := str(GameManager.observing_location().get("id", ""))
	var by_site: Dictionary = manifest.get("site_sets", {})
	if by_site.has(site_id):
		return str(by_site[site_id])
	return str(manifest.get("default_set", "mountain"))


func _update_horizon_layers(horizon_y: float) -> void:
	# A full turn returns every layer to the same texture phase. A small,
	# periodic depth offset makes nearby layers travel farther during a pan
	# without accumulating drift after repeated 360-degree rotations.
	var view_w := VIEW_RECT.size.x
	var view_h := VIEW_RECT.size.y
	_update_horizon_heading()
	var heading := fposmod(display_azimuth, 360.0)
	var heading_rad := deg_to_rad(heading)
	var pitch_shift := horizon_y - view_h
	for entry_value in horizon_layers:
		var entry: Dictionary = entry_value
		var spec: Dictionary = entry["spec"]
		var sprites: Array = entry["sprites"]
		var texture: Texture2D = entry["texture"]
		# Keep environmental scale restrained in narrow optical modes. The scope
		# magnifies the sky target, not a nearby building into the whole aperture.
		var mode_scale := 1.0 if view_mode == "naked_eye" else (0.94 if view_mode == "finder" else 0.76)
		var band_h: float = view_h * float(spec["height"]) * mode_scale
		var scale_factor: float = band_h / maxf(float(texture.get_height()), 1.0)
		var draw_w: float = float(texture.get_width()) * scale_factor
		if draw_w <= 1.0:
			continue
		var parallax := float(spec["parallax"])
		var base_phase := heading / 360.0 * draw_w
		# The first term keeps every panorama tied to the same real heading.
		# Periodic harmonics add depth-dependent screen travel without building
		# cumulative drift or breaking the 0/360 seam. The derivative is larger
		# for nearby art, so platform/equipment visibly outrun distant ridges.
		var depth_phase := (
			sin(heading_rad) * view_w * 0.14
			+ sin(heading_rad * 2.0) * view_w * 0.035
		) * parallax
		var offset: float = -fposmod(base_phase + depth_phase, draw_w)
		# The transparent artwork rises above the horizon instead of beginning at
		# it as a rectangular strip. Nearby layers react more to pitch than the
		# distant ridge, which keeps the scene grounded instead of floating.
		var layer_horizon_y := view_h + pitch_shift * float(spec["vertical"])
		var top: float = layer_horizon_y - band_h * float(spec["rise"])
		var visible_layer: bool = top < view_h and top + band_h > 0.0
		var mode_visibility := _horizon_layer_mode_visibility(spec)
		for i in range(sprites.size()):
			var tr: TextureRect = sprites[i]
			tr.visible = visible_layer and mode_visibility > 0.01
			tr.size = Vector2(draw_w, band_h)
			tr.position = Vector2(offset + float(i) * draw_w, top)
			tr.modulate.a = float(spec["alpha"]) * mode_visibility
	_update_horizon_clouds(horizon_y)


func _update_horizon_heading() -> void:
	if not horizon_azimuth_initialized:
		horizon_last_azimuth = display_azimuth
		horizon_unwrapped_azimuth = display_azimuth
		horizon_azimuth_initialized = true
		return
	var delta := shortest_angle_degrees(horizon_last_azimuth, display_azimuth)
	horizon_unwrapped_azimuth += delta
	horizon_last_azimuth = display_azimuth


func _horizon_mode_visibility() -> float:
	match view_mode:
		"finder":
			return 0.52
		"telescope":
			return 0.08
		_:
			return 1.0


func _horizon_layer_mode_visibility(spec: Dictionary) -> float:
	if view_mode == "telescope":
		# A narrow optical field retains only a faint lower-edge reference.
		# Nearby equipment is suppressed most strongly so it never balloons
		# across the target at high magnification.
		match str(spec.get("key", "")):
			"far":
				return 0.12
			"mid":
				return 0.055
			_:
				return 0.025
	return _horizon_mode_visibility()


func _update_horizon_clouds(horizon_y: float) -> void:
	var cover := _cloud_cover_amount()
	var view_h := VIEW_RECT.size.y
	for entry_value in horizon_cloud_sprites:
		var entry: Dictionary = entry_value
		var sprites: Array = entry["sprites"]
		var texture: Texture2D = entry["texture"]
		var drift_speed := float(entry["drift_speed"])
		var parallax := float(entry["parallax"])
		if cover <= 0.0:
			for s in sprites:
				(s as TextureRect).visible = false
			continue
		var mode_scale := 1.0 if view_mode == "naked_eye" else (0.94 if view_mode == "finder" else 0.76)
		var band_h: float = view_h * 0.12 * mode_scale
		var scale_factor: float = band_h / maxf(float(texture.get_height()), 1.0)
		var draw_w: float = float(texture.get_width()) * scale_factor
		if draw_w <= 1.0:
			continue
		# Clouds share the same wrapped heading as the terrain and add a gentle
		# independent drift. They never accumulate camera-heading drift.
		var heading := fposmod(display_azimuth, 360.0)
		var heading_rad := deg_to_rad(heading)
		var depth_phase := (
			sin(heading_rad) * VIEW_RECT.size.x * 0.14
			+ sin(heading_rad * 2.0) * VIEW_RECT.size.x * 0.035
		) * parallax
		var offset: float = -fposmod(
			heading / 360.0 * draw_w
			+ depth_phase
			+ horizon_cloud_drift * drift_speed * 22.0,
			draw_w
		)
		var top: float = horizon_y - band_h * 0.85
		# Thicker cover = denser cloud; the transparent PNG lets sky through.
		var alpha: float = clampf(0.035 + cover * 0.20, 0.0, 0.24) * _horizon_mode_visibility()
		for i in range(sprites.size()):
			var tr: TextureRect = sprites[i]
			tr.visible = horizon_y > -band_h and horizon_y < view_h + band_h
			tr.size = Vector2(draw_w, band_h)
			tr.position = Vector2(offset + float(i) * draw_w, top)
			tr.modulate = Color(1, 1, 1, alpha)


func _update_ground() -> void:
	# Environment is a visual lower-edge reference, not a second coordinate
	# system. At Alt=0 the natural horizon sits at the bottom of the view; as the
	# observer raises the tube it slides down and leaves the frame. The actual
	# celestial projection remains exclusively in _fov_to_local().
	var horizon_y := VIEW_RECT.size.y + display_altitude / maxf(display_fov_y * 0.5, 0.001) * VIEW_RECT.size.y
	_update_horizon_layers(horizon_y)
	# Old solid ColorRects made a visible black/green horizon bar. All ground
	# presence now comes from alpha-backed far/mid/near art above.
	ground_rect.visible = false
	horizon_line.visible = false


func _scale_steps(fov: float) -> Vector3:
	# (minor, mid, major-with-number) tick spacing in degrees.
	if fov >= 60.0:
		return Vector3(5.0, 10.0, 30.0)
	if fov >= 12.0:
		return Vector3(1.0, 5.0, 10.0)
	return Vector3(0.25, 0.5, 2.0)


func _update_scales() -> void:
	_update_az_scale()
	_update_alt_scale()
	az_readout.text = "Az " + _format_dms(display_azimuth) + " " + _direction_text_for_azimuth(display_azimuth)
	alt_readout.text = "Alt " + _format_dms(display_altitude)
	_update_scale_asset_state()


func _update_scale_asset_state() -> void:
	# Knob "liveliness": spinning while the player pans/tilts makes the two
	# rotation controls read as real machinery - brighter and slightly
	# enlarged while active, settling back when the view rests.
	if az_knob_icon != null:
		var az_delta: float = absf(shortest_angle_degrees(_knob_last_azimuth, display_azimuth))
		_knob_last_azimuth = display_azimuth
		_az_knob_activity = clampf(_az_knob_activity * 0.90 + az_delta * 0.35, 0.0, 1.0)
		az_knob_icon.rotation = deg_to_rad(display_azimuth)
		var az_boost := 0.0 if InteractionFeedback.is_reduced_motion() else _az_knob_activity
		az_knob_icon.scale = Vector2.ONE * (1.0 + 0.16 * az_boost)
		az_knob_icon.modulate = Color(1.0 + 0.35 * az_boost, 1.0 + 0.28 * az_boost, 1.0 + 0.10 * az_boost)
	if alt_knob_icon != null:
		var alt_delta: float = absf(display_altitude - _knob_last_altitude)
		_knob_last_altitude = display_altitude
		_alt_knob_activity = clampf(_alt_knob_activity * 0.90 + alt_delta * 0.55, 0.0, 1.0)
		alt_knob_icon.rotation = deg_to_rad(display_altitude - 45.0)
		var alt_boost := 0.0 if InteractionFeedback.is_reduced_motion() else _alt_knob_activity
		alt_knob_icon.scale = Vector2.ONE * (1.0 + 0.16 * alt_boost)
		alt_knob_icon.modulate = Color(1.0 + 0.35 * alt_boost, 1.0 + 0.28 * alt_boost, 1.0 + 0.10 * alt_boost)
	# The pointers mark the actively selected object in the SAME scrolling-window
	# coordinates as the ticks (current aim = band center). This is crucial for
	# free observation: the mission target must not keep steering the player away
	# from the object they intentionally clicked.
	# When the target is outside the window they pin to the band edge,
	# dimmed - "keep turning this way". They never ride along with the aim.
	var target_item := _sky_item(_active_observation_object_id())
	if az_target_pointer != null:
		if target_item.is_empty():
			az_target_pointer.visible = false
		else:
			var half_az := display_fov_x * 0.5
			var target_delta_az := shortest_angle_degrees(display_azimuth, float(target_item.get("azimuth", 0.0)))
			var clamped_az: float = clampf(target_delta_az, -half_az, half_az)
			var off_window_az := absf(target_delta_az) > half_az
			var pointer_x := AZ_BAND.position.x + AZ_BAND.size.x * 0.5 + (clamped_az / half_az) * (AZ_BAND.size.x * 0.47)
			az_target_pointer.position = Vector2(pointer_x - az_target_pointer.size.x * 0.5, AZ_SCALE_ART_RECT.position.y - 2.0)
			az_target_pointer.modulate.a = 0.55 if off_window_az else 1.0
			az_target_pointer.visible = true
	if alt_target_pointer != null:
		if target_item.is_empty():
			alt_target_pointer.visible = false
		else:
			var half_alt := display_fov_y * 0.5
			var target_delta_alt := float(target_item.get("altitude", 0.0)) - display_altitude
			var clamped_alt: float = clampf(target_delta_alt, -half_alt, half_alt)
			var off_window_alt := absf(target_delta_alt) > half_alt
			var pointer_y := ALT_BAND.position.y + ALT_BAND.size.y * 0.5 - (clamped_alt / half_alt) * (ALT_BAND.size.y * 0.47)
			alt_target_pointer.position = Vector2(ALT_SCALE_ART_RECT.position.x + 12.0, pointer_y - alt_target_pointer.size.y * 0.5)
			alt_target_pointer.modulate.a = 0.55 if off_window_alt else 1.0
			alt_target_pointer.visible = true


func _update_az_scale() -> void:
	for tick in az_ticks:
		tick.visible = false
	for label in az_labels:
		label.visible = false
	var steps := _scale_steps(display_fov_x)
	var minor := steps.x
	var mid := steps.y
	var major := steps.z
	var half := display_fov_x * 0.5
	var tick_index := 0
	var label_index := 0
	var start_index := int(ceil((display_azimuth - half) / minor))
	var end_index := int(floor((display_azimuth + half) / minor))
	for i in range(start_index, end_index + 1):
		var azimuth := float(i) * minor
		var delta := shortest_angle_degrees(display_azimuth, azimuth)
		var x := VIEW_RECT.size.x * 0.5 + (delta / half) * (VIEW_RECT.size.x * 0.48)
		if x < 2.0 or x > AZ_BAND.size.x - 2.0:
			continue
		var az_normalized := wrapf(azimuth, 0.0, 360.0)
		var is_major := absf(fmod(absf(az_normalized) + 0.001, major)) < 0.01
		var is_mid := absf(fmod(absf(az_normalized) + 0.001, mid)) < 0.01
		if tick_index >= az_ticks.size():
			break
		var tick := az_ticks[tick_index]
		tick_index += 1
		tick.texture = _load_png_texture(AZ_TICK_MAJOR_TEXTURE if is_major or is_mid else AZ_TICK_MINOR_TEXTURE)
		var tick_size := tick.texture.get_size() if tick.texture != null else Vector2(1.0, 6.0)
		tick.position = Vector2(round(x - tick_size.x * 0.5), AZ_BAND.size.y - 2.0 - tick_size.y)
		tick.size = tick_size
		tick.modulate = Color(1.0, 1.0, 1.0, 1.0 if is_major else (0.72 if is_mid else 0.48))
		tick.visible = true
		if is_major and label_index < az_labels.size():
			var label := az_labels[label_index]
			label_index += 1
			var cardinal := _cardinal_for(az_normalized)
			if cardinal != "":
				label.text = "%s %d°" % [cardinal, int(round(az_normalized))]
				label.add_theme_color_override("font_color", GOLD)
			else:
				label.text = "%d°" % int(round(az_normalized))
				label.add_theme_color_override("font_color", MUTED)
			label.position = Vector2(x - 32.0, 2.0)
			label.visible = true


func _cardinal_for(az_normalized: float) -> String:
	var rounded := int(round(az_normalized)) % 360
	match rounded:
		0:
			return "N"
		90:
			return "E"
		180:
			return "S"
		270:
			return "W"
	return ""


func _update_alt_scale() -> void:
	for tick in alt_ticks:
		tick.visible = false
	for label in alt_labels:
		label.visible = false
	var steps := _scale_steps(display_fov_y)
	var minor := steps.x
	var mid := steps.y
	var major := steps.z
	var half := display_fov_y * 0.5
	var tick_index := 0
	var label_index := 0
	var start_index := int(ceil((display_altitude - half) / minor))
	var end_index := int(floor((display_altitude + half) / minor))
	for i in range(start_index, end_index + 1):
		var altitude := float(i) * minor
		if altitude < 0.0 or altitude > 90.0:
			continue
		var delta := altitude - display_altitude
		var y := ALT_BAND.size.y * 0.5 - (delta / half) * (VIEW_RECT.size.y * 0.48)
		if y < 2.0 or y > ALT_BAND.size.y - 2.0:
			continue
		var is_major := absf(fmod(absf(altitude) + 0.001, major)) < 0.01
		var is_mid := absf(fmod(absf(altitude) + 0.001, mid)) < 0.01
		if tick_index >= alt_ticks.size():
			break
		var tick := alt_ticks[tick_index]
		tick_index += 1
		tick.texture = _load_png_texture(ALT_TICK_MAJOR_TEXTURE if is_major or is_mid else ALT_TICK_MINOR_TEXTURE)
		var tick_size := tick.texture.get_size() if tick.texture != null else Vector2(6.0, 1.0)
		tick.position = Vector2(ALT_BAND.size.x - 2.0 - tick_size.x, round(y - tick_size.y * 0.5))
		tick.size = tick_size
		tick.modulate = Color(1.0, 1.0, 1.0, 1.0 if is_major else (0.72 if is_mid else 0.48))
		tick.visible = true
		if is_major and label_index < alt_labels.size():
			var label := alt_labels[label_index]
			label_index += 1
			label.text = "%d" % int(round(altitude))
			label.position = Vector2(0.0, y - 7.0)
			label.visible = true


func _update_marker_frames() -> void:
	if selection_frame != null:
		selection_frame.queue_free()
		selection_frame = null
	var tracked_id := _active_observation_object_id()
	var free_selection := tracked_id != "" and tracked_id != target_id
	var previous_state := target_lock_state
	var next_state := "search"
	_update_edge_target_indicator(tracked_id)
	if _update_faint_mission_target_waypoint(tracked_id):
		if target_state_ring != null and is_instance_valid(target_state_ring):
			target_state_ring.queue_free()
		target_state_ring = null
		assist_frame = faint_mission_target_waypoint
		target_lock_state = "locked" if _is_target_centered(tracked_id) else "approach"
		return
	_hide_faint_mission_target_waypoint()
	if _is_constellation_target(tracked_id):
		if target_state_ring != null and is_instance_valid(target_state_ring):
			target_state_ring.queue_free()
		target_state_ring = null
		assist_frame = constellation_overlay
		if in_view_targets.has(tracked_id):
			next_state = "locked" if _is_target_centered(tracked_id) else "approach"
		target_lock_state = next_state
		return

	# Asset-backed target feedback stays centered on the same projected rect
	# used by hit testing, so the ring cannot drift away from the real object.
	var current_level_data: Dictionary = GameManager.current_level()
	var target_is_close := in_view_targets.has(tracked_id) and _center_offset(tracked_id) <= maxf(fov_x, fov_y) * 0.18
	# hide_target_hint suppresses long-range help during coordinate navigation.
	# Once the player has acquired the target, approach and lock feedback return.
	var show_target_feedback := in_view_targets.has(tracked_id) and (free_selection or not bool(current_level_data.get("hide_target_hint", false)) or target_is_close)
	if show_target_feedback:
		var target_info: Dictionary = in_view_targets[tracked_id]
		var target_rect: Rect2 = target_info.get("rect", Rect2())
		var offset := _center_offset(tracked_id)
		var centered := _is_target_centered(tracked_id)
		# Approach and lock use the same target-derived footprint. The feedback
		# ring must always surround the rendered object instead of shrinking
		# inside large Moon/planet/deep-sky textures.
		var detection_rect: Rect2 = target_info.get("detection_rect", target_rect)
		# The moving marker belongs to the celestial object, not to the whole
		# telescope aperture. Keep it close to small stars while allowing Moon
		# and deep-sky textures to grow the ring just beyond their visible edge.
		var ring_size := maxf(detection_rect.size.x, detection_rect.size.y)
		var ring_path := LOCK_RING_TEXTURE if centered else APPROACH_RING_TEXTURE
		var alpha := 1.0 if centered else 0.82
		next_state = "locked" if centered else ("approach" if offset <= maxf(fov_x, fov_y) * 0.22 else "search")
		if target_state_ring == null or not is_instance_valid(target_state_ring):
			target_state_ring = _target_ring(view_layer, ring_path, target_rect.get_center(), ring_size, 0.0)
			assist_frame = target_state_ring
		else:
			target_state_ring.texture = _load_png_texture(ring_path)
		target_state_ring.set_meta("fading", false)
		target_state_ring.position = target_rect.get_center() - Vector2.ONE * ring_size * 0.5
		target_state_ring.size = Vector2.ONE * ring_size
		target_state_ring.pivot_offset = target_state_ring.size * 0.5
		var proximity := clampf(1.0 - offset / maxf(maxf(fov_x, fov_y) * 0.22, 0.001), 0.0, 1.0)
		var approach_tint := CYAN if free_selection else CYAN.lerp(GOLD, proximity * 0.78)
		target_state_ring.modulate = (Color(CYAN.r, CYAN.g, CYAN.b, 1.0) if free_selection and centered else (Color.WHITE if centered else Color(approach_tint.r, approach_tint.g, approach_tint.b, alpha)))
		if previous_state != next_state:
			if next_state == "locked":
				# A lock contracts onto the real target footprint. Expanding
				# from inside the object looked like a generic selection ring.
				target_state_ring.scale = Vector2.ONE * (1.34 if not InteractionFeedback.is_reduced_motion() else 1.0)
				var lock_tween := create_tween().bind_node(target_state_ring).set_parallel(true)
				lock_tween.tween_property(target_state_ring, "scale", Vector2.ONE, 0.30 if not InteractionFeedback.is_reduced_motion() else 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				lock_tween.tween_property(target_state_ring, "modulate:a", 1.0, 0.22)
				if observe_button != null:
					InteractionFeedback.success(observe_button, "target_locked")
				var tracked_object := GameManager.get_object(tracked_id)
				var tracked_name := GameManager.dict_text(tracked_object, "name")
				InteractionFeedback.operation_chain(
					view_layer,
					GameManager.text("Centered %s" % tracked_name, "已居中%s" % tracked_name),
					GameManager.text("The target is inside the observing tolerance", "目标已进入观测容差范围"),
					GameManager.text("Observe is ready" if not free_selection else "Free observation is ready", "观测按钮已就绪" if not free_selection else "自由观测已就绪"),
					observe_button,
					CYAN if free_selection else GOLD,
					2.4
				)
			else:
				create_tween().bind_node(target_state_ring).tween_property(target_state_ring, "modulate:a", alpha, 0.18)
	else:
		if target_state_ring != null and is_instance_valid(target_state_ring) and not bool(target_state_ring.get_meta("fading", false)):
			target_state_ring.set_meta("fading", true)
			var fading_ring := target_state_ring
			var fade := create_tween().bind_node(fading_ring)
			fade.tween_property(fading_ring, "modulate:a", 0.0, 0.18 if not InteractionFeedback.is_reduced_motion() else 0.05)
			fade.tween_callback(func() -> void:
				if is_instance_valid(fading_ring):
					fading_ring.queue_free()
			)
			target_state_ring = null
			assist_frame = null
	target_lock_state = next_state

	if free_selection and in_view_targets.has(selected_object_id):
		var info: Dictionary = in_view_targets[selected_object_id]
		var rect: Rect2 = info.get("rect", Rect2())
		selection_frame = _make_frame(view_layer, rect.grow(7.0), CYAN, 2)


func _update_faint_mission_target_waypoint(object_id: String) -> bool:
	if faint_mission_target_waypoint == null or object_id != target_id:
		return false
	var info: Dictionary = in_view_targets.get(object_id, {})
	if info.is_empty() or not bool(info.get("faint_waypoint", false)):
		return false
	var diameter := FAINT_MISSION_WAYPOINT_DIAMETER
	var center: Vector2 = (info.get("rect", Rect2()) as Rect2).get_center()
	var centered := _is_target_centered(object_id)
	faint_mission_target_waypoint.configure(diameter, GOLD if centered else CYAN, centered)
	faint_mission_target_waypoint.position = center - faint_mission_target_waypoint.size * 0.5
	faint_mission_target_waypoint.visible = true
	faint_mission_target_waypoint_id = object_id
	return true


func _hide_faint_mission_target_waypoint() -> void:
	if faint_mission_target_waypoint != null:
		faint_mission_target_waypoint.visible = false
	faint_mission_target_waypoint_id = ""


func _update_edge_target_indicator(object_id: String) -> void:
	if edge_target_indicator == null:
		return
	if object_id == "":
		_hide_edge_target_indicator()
		return
	var item := _sky_item(object_id)
	if item.is_empty() or float(item.get("altitude", -90.0)) < 0.0:
		_hide_edge_target_indicator()
		return
	if in_view_targets.has(object_id):
		_fade_edge_target_indicator_to_object(object_id)
		return

	var delta_az := shortest_angle_degrees(display_azimuth, float(item.get("azimuth", 0.0)))
	var delta_alt := float(item.get("altitude", 0.0)) - display_altitude
	var projected := _fov_to_local(delta_az, delta_alt)
	var center := VIEW_RECT.size * 0.5
	var direction := (projected - center).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var half_bounds := Vector2(
		center.x - edge_target_indicator.size.x * 0.5 - 12.0,
		center.y - edge_target_indicator.size.y * 0.5 - 118.0)
	var edge_distance := INF
	if absf(direction.x) > 0.0001:
		edge_distance = minf(edge_distance, half_bounds.x / absf(direction.x))
	if absf(direction.y) > 0.0001:
		edge_distance = minf(edge_distance, half_bounds.y / absf(direction.y))
	var desired := center + direction * edge_distance - edge_target_indicator.size * 0.5
	var safe_rect := Rect2(
		Vector2(10.0, 10.0),
		Vector2(
			VIEW_RECT.size.x - 20.0,
			VIEW_RECT.size.y - 118.0
		)
	)
	desired.x = clampf(desired.x, safe_rect.position.x, safe_rect.end.x - edge_target_indicator.size.x)
	desired.y = clampf(desired.y, safe_rect.position.y, safe_rect.end.y - edge_target_indicator.size.y)
	var target_changed := edge_target_object_id != object_id
	var was_visible := edge_target_indicator.visible and not target_changed and edge_target_state == "visible"
	if edge_target_tween != null:
		edge_target_tween.kill()
		edge_target_tween = null
	edge_target_transition_serial += 1
	edge_target_object_id = object_id
	edge_target_state = "visible"
	edge_target_indicator.visible = true
	edge_target_indicator.set_meta("fading", false)
	edge_target_indicator.position = desired if not was_visible else edge_target_indicator.position.lerp(desired, 0.34)
	var is_mission := object_id == target_id
	var accent := GOLD if is_mission else CYAN
	_apply_edge_indicator_style(accent)
	edge_target_arrow.rotation = direction.angle()
	edge_target_arrow.color = accent
	edge_target_name.text = GameManager.dict_text(GameManager.get_object(object_id), "name").replace("\n", " / ")
	edge_target_name.add_theme_color_override("font_color", accent)
	var az_arrow := GameManager.text("RIGHT", "向右") if delta_az > 0.0 else GameManager.text("LEFT", "向左")
	var alt_arrow := GameManager.text("UP", "抬高") if delta_alt > 0.0 else GameManager.text("DOWN", "降低")
	edge_target_delta.text = GameManager.text(
		"A/D  %s %s\nW/S  %s %s" % [az_arrow, _format_dms(absf(delta_az)), alt_arrow, _format_dms(absf(delta_alt))],
		"A/D  %s %s\nW/S  %s %s" % [az_arrow, _format_dms(absf(delta_az)), alt_arrow, _format_dms(absf(delta_alt))]
	)
	if edge_navigation_trail != null:
		edge_navigation_trail.visible = true
		edge_navigation_trail.update_trail(direction, Rect2(edge_target_indicator.position, edge_target_indicator.size), accent)
	if not was_visible:
		edge_target_indicator.modulate.a = 0.0
		edge_target_tween = create_tween().bind_node(edge_target_indicator)
		edge_target_tween.tween_property(edge_target_indicator, "modulate:a", 1.0, 0.16)
	else:
		edge_target_indicator.modulate.a = 1.0


func _apply_edge_indicator_style(accent: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.03, 0.055, 0.94)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	edge_target_indicator.add_theme_stylebox_override("panel", style)


func _hide_edge_target_indicator() -> void:
	if edge_target_indicator == null:
		return
	if edge_target_tween != null:
		edge_target_tween.kill()
		edge_target_tween = null
	edge_target_transition_serial += 1
	edge_target_object_id = ""
	edge_target_state = "hidden"
	edge_target_indicator.visible = false
	edge_target_indicator.modulate.a = 0.0
	edge_target_indicator.set_meta("fading", false)
	if edge_navigation_trail != null:
		edge_navigation_trail.visible = false


func _fade_edge_target_indicator_to_object(object_id: String) -> void:
	if edge_target_object_id != "" and edge_target_object_id != object_id:
		_hide_edge_target_indicator()
		return
	if not edge_target_indicator.visible:
		edge_target_state = "hidden"
		return
	if bool(edge_target_indicator.get_meta("fading", false)) and edge_target_object_id == object_id:
		return
	edge_target_transition_serial += 1
	var transition_serial := edge_target_transition_serial
	edge_target_object_id = object_id
	edge_target_state = "retracting"
	edge_target_indicator.set_meta("fading", true)
	if edge_navigation_trail != null:
		edge_navigation_trail.visible = false
	var info: Dictionary = in_view_targets.get(object_id, {})
	var target_rect: Rect2 = info.get("rect", Rect2())
	var target_center: Vector2 = target_rect.get_center()
	var destination := target_center - edge_target_indicator.size * 0.5
	var duration := 0.05 if InteractionFeedback.is_reduced_motion() else 0.20
	if edge_target_tween != null:
		edge_target_tween.kill()
	edge_target_tween = create_tween().bind_node(edge_target_indicator).set_parallel(true)
	edge_target_tween.tween_property(edge_target_indicator, "position", destination, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	edge_target_tween.tween_property(edge_target_indicator, "modulate:a", 0.0, duration)
	edge_target_tween.chain().tween_callback(func() -> void:
		if edge_target_indicator != null and transition_serial == edge_target_transition_serial and edge_target_object_id == object_id and in_view_targets.has(object_id):
			edge_target_indicator.visible = false
			edge_target_indicator.set_meta("fading", false)
			edge_target_state = "hidden"
			edge_target_tween = null
	)


func _target_feedback_ring_size(target_diameter: float) -> float:
	var ring_minimum := 40.0 if view_mode == "naked_eye" else (44.0 if view_mode == "finder" else 48.0)
	var ring_padding := maxf(12.0, target_diameter * 0.25)
	return maxf(ring_minimum, target_diameter + ring_padding)


func _target_ring(parent: Control, texture_path: String, center: Vector2, diameter: float, alpha: float) -> TextureRect:
	var ring := _asset_texture_rect(parent, texture_path, Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter))
	ring.z_index = Z_TARGET_FEEDBACK
	ring.modulate.a = alpha
	return ring


func _update_lock_ring_pulse() -> void:
	if target_state_ring == null or not is_instance_valid(target_state_ring):
		return
	if target_lock_state != "approach" and target_lock_state != "locked" and target_lock_state != "success":
		return
	if InteractionFeedback.is_reduced_motion():
		target_state_ring.modulate.a = 1.0 if target_lock_state == "success" else (0.82 if target_lock_state == "approach" else 0.88)
		target_state_ring.rotation = 0.0
		return
	var phase := Time.get_ticks_msec() / 1000.0
	var base := 1.0 if target_lock_state == "success" else (0.82 if target_lock_state == "approach" else 0.90)
	var amplitude := 0.0 if target_lock_state == "success" else (0.10 if target_lock_state == "approach" else 0.08)
	target_state_ring.modulate.a = clampf(base + sin(phase * 3.2) * amplitude, 0.55, 1.0)
	# Rotating cardinal marks make acquisition visible without filling the
	# transparent center or covering the celestial texture.
	target_state_ring.rotation = phase * (0.22 if target_lock_state == "approach" else -0.12)


func _single(en: String, zh: String) -> String:
	# One language only - for compact single-line rows that must not stack.
	if GameManager.language_mode == "zh":
		return zh
	return en


func _source_text() -> String:
	var item := _sky_item(target_id)
	if float(item.get("altitude", 0.0)) < 0.0:
		return _single("Below horizon", "地平线以下")
	return GameManager.position_source_label(str(item.get("source", "fallback")))


func _update_aim_text() -> void:
	var config: Dictionary = VIEW_MODES[view_mode]
	var mode_name := _single(str(config.get("en", view_mode)), str(config.get("zh", view_mode)))
	aim_label.text = "Az: %s (%s)\nAlt: %s\nFOV: %s x %s\n%s · %s" % [
		_format_dms(display_azimuth),
		_direction_text_for_azimuth(display_azimuth),
		_format_dms(display_altitude),
		_format_dms(display_fov_x),
		_format_dms(display_fov_y),
		mode_name,
		_source_text()
	]
	# The source is already shown in the mission/selection panels. Keep this
	# compact readout to three lines so it never overlaps the guidance row.
	aim_label.text = "Az: %s (%s)\nAlt: %s\nFOV: %s x %s  %s" % [
		_format_dms(display_azimuth),
		_direction_text_for_azimuth(display_azimuth),
		_format_dms(display_altitude),
		_format_dms(display_fov_x),
		_format_dms(display_fov_y),
		mode_name
	]


func _update_mission_tonight_text() -> void:
	var target_sky := _sky_item(target_id)
	var direction := str(target_sky.get("direction_text", ""))
	# Clear, non-alarming data-source label instead of a bare "Offline".
	var source_label := GameManager.position_source_label(str(target_sky.get("source", "calculated")))
	mission_tonight_label.text = GameManager.text("Position: %s (%s)", "位置来源：%s（%s）") % [source_label, direction]
	mission_tonight_label.add_theme_color_override("font_color", _visibility_color(target_sky))


func _update_sky_condition_text() -> void:
	# Show one language only; legacy/no-environment levels show nothing here.
	if sky_condition_label == null:
		return
	var sky_key := _sky_brightness_key()
	var cover := _cloud_cover_amount()
	var parts: Array[String] = []
	if sky_key != "":
		var sky_names_en := {"city": "City", "suburban": "Suburban", "dark": "Dark"}
		var sky_names_zh := {"city": "城市", "suburban": "郊区", "dark": "暗夜"}
		var sky_name := str(sky_names_zh.get(sky_key, sky_key)) if GameManager.language_mode == "zh" else str(sky_names_en.get(sky_key, sky_key.capitalize()))
		parts.append(GameManager.text("Sky: %s", "天空：%s") % sky_name)
	if cover > 0.0:
		var tier := GameManager.text("Thin clouds", "薄云")
		if cover >= 0.67:
			tier = GameManager.text("Heavy clouds", "厚云")
		elif cover >= 0.34:
			tier = GameManager.text("Moderate clouds", "中云")
		parts.append(GameManager.text("Clouds: %s", "云层：%s") % tier)
	sky_condition_label.text = "  ·  ".join(parts)
	sky_condition_label.visible = not parts.is_empty()


# --------------------------------------------------------------- interaction


func _select_object(object_id: String) -> void:
	var previous_object_id := _active_observation_object_id()
	selected_object_id = object_id
	GameManager.selected_object_id = object_id
	GameManager.selected_object_level = int(GameManager.progress.get("current_level", 1))
	_update_selected_text()
	_update_marker_frames()
	_update_guidance()
	call_deferred("_redirect_to_world_map_if_needed")
	if detail_panel != null and is_instance_valid(detail_panel):
		_open_detail_panel()  # refresh open panel to the new selection
	if object_id == target_id and previous_object_id != object_id:
		var object_data := GameManager.get_object(object_id)
		var object_name := GameManager.dict_text(object_data, "name")
		var sky_item := _sky_item(object_id)
		var altitude := float(sky_item.get("altitude", -90.0))
		var visibility := GameManager.text("Above horizon", "位于地平线上方") if altitude >= 0.0 else GameManager.text("Below horizon", "位于地平线以下")
		InteractionFeedback.operation_chain(
			view_layer,
			GameManager.text("Selected mission target: %s" % object_name, "已选择任务目标：%s" % object_name),
			visibility,
			_mission_target_action_instruction(),
			null,
			GOLD,
			2.6
		)


func _mission_target_action_instruction() -> String:
	if view_mode == "naked_eye":
		return GameManager.text("Use Az and Alt to bring it into the wide field", "调整方位角和俯仰角，使目标进入宽视场")
	if view_mode == "finder":
		return GameManager.text("Center the point in the finder field", "将目标光点移到寻星镜视场中央")
	return GameManager.text("Center the target, then press Observe", "将目标居中，然后点击观测")


func _select_object_at_screen_position(screen_position: Vector2) -> bool:
	if not VIEW_RECT.has_point(screen_position):
		return false
	var local_position := screen_position - VIEW_RECT.position
	var selected_id := ""
	var nearest_distance := INF
	for id_value in in_view_targets.keys():
		var object_id := str(id_value)
		var info: Dictionary = in_view_targets[object_id]
		var hit_rect: Rect2 = info.get("detection_rect", info.get("rect", Rect2()))
		if not hit_rect.has_point(local_position):
			continue
		var distance := hit_rect.get_center().distance_to(local_position)
		if distance < nearest_distance:
			nearest_distance = distance
			selected_id = object_id
	if selected_id == "":
		return false
	_select_object(selected_id)
	return true


var detail_panel: Control


func _open_detail_panel() -> void:
	if detail_panel != null and is_instance_valid(detail_panel):
		detail_panel.queue_free()
		detail_panel = null
	var object_id := selected_object_id if selected_object_id != "" else target_id
	if object_id == "":
		return
	var detail: Dictionary = GameManager.object_detail(object_id)
	var is_mission := bool(detail.get("is_mission_target", false))
	var accent := GOLD if is_mission else CYAN

	detail_panel = Control.new()
	detail_panel.name = "ObjectDetailsPanel"
	detail_panel.position = Vector2(754, 288)
	detail_panel.size = Vector2(250, 190)
	detail_panel.z_index = 100
	detail_panel.set_meta("scrollable_details", true)
	add_child(detail_panel)

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.03, 0.05, 0.09, 0.99)
	ps.border_color = accent
	ps.set_border_width_all(3)
	ps.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", ps)
	detail_panel.add_child(panel)

	# --- fixed header: name + type + mission/free badge ---
	_dlabel(panel, GameManager.text(str(detail.get("name_en", "")), str(detail.get("name_zh", ""))), Vector2(12, 10), Vector2(190, 26), 17, accent)
	_dlabel(panel, GameManager.text(str(detail.get("type_en", "")), str(detail.get("type_zh", ""))), Vector2(12, 38), Vector2(118, 20), 11, TEXT)
	var badge := GameManager.text("MISSION TARGET", "任务目标") if is_mission else GameManager.text("FREE OBSERVATION", "自由观测")
	if bool(detail.get("is_observed", false)):
		badge = GameManager.text("✓ OBSERVED · ", "✓ 已观测 · ") + badge
	var badge_label := _dlabel(panel, badge, Vector2(126, 38), Vector2(104, 20), 10, accent, HORIZONTAL_ALIGNMENT_RIGHT)
	badge_label.clip_text = true
	badge_label.tooltip_text = badge
	badge_label.add_theme_color_override("font_color", GREEN if bool(detail.get("is_observed", false)) else accent)
	# Details stay in the right inspector, so only a compact close affordance is
	# needed here. Observe and Back remain the fixed global actions below.
	var compact_close := _detail_button("×", Vector2(28, 24), Color(0.16, 0.20, 0.30))
	compact_close.position = Vector2(212, 8)
	compact_close.pressed.connect(_close_detail_panel)
	panel.add_child(compact_close)

	# --- scrollable middle ---
	var scroll := ScrollContainer.new()
	scroll.name = "DetailsScroll"
	scroll.position = Vector2(8, 66)
	scroll.size = Vector2(234, 116)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.custom_minimum_size = Vector2(220, 0)
	body.set_meta("detail_width", 220.0)
	body.add_theme_constant_override("separation", 4)
	scroll.add_child(body)

	# astronomy facts
	_dsection(body, GameManager.text("Astronomy", "天文资料"))
	var mag = detail.get("magnitude", null)
	var rows: Array = []
	if mag != null:
		rows.append([GameManager.text("Apparent magnitude", "视星等"), "%.1f" % float(mag)])
	var constellation := GameManager.text(str(detail.get("constellation_en", "")), str(detail.get("constellation_zh", "")))
	if constellation != "":
		rows.append([GameManager.text("Constellation", "所属星座"), constellation])
	var distance := GameManager.text(str(detail.get("distance_en", "")), str(detail.get("distance_zh", "")))
	if distance != "":
		rows.append([GameManager.text("Distance", "距离"), distance])
	if bool(detail.get("has_coords", false)):
		rows.append([GameManager.text("Right ascension", "赤经 RA"), "%.2f h" % float(detail.get("ra_hours", 0.0))])
		rows.append([GameManager.text("Declination", "赤纬 Dec"), "%.2f°" % float(detail.get("dec_degrees", 0.0))])
		rows.append([GameManager.text("Azimuth", "方位角"), "%.1f° %s" % [float(detail.get("azimuth", 0.0)), str(detail.get("direction_text", ""))]])
		rows.append([GameManager.text("Altitude", "高度角"), "%.1f°" % float(detail.get("altitude", 0.0))])
		rows.append([GameManager.text("Visibility", "可见性"), _visibility_phrase(detail)])
	else:
		rows.append([GameManager.text("Position", "位置"), GameManager.text("Live (planet/Moon)", "实时（行星/月球）")])
	rows.append([GameManager.text("Observing site", "观测地点"), GameManager.text(str(detail.get("location_en", "")), str(detail.get("location_zh", "")))])
	rows.append([GameManager.text("Local time", "当地时间"), str(detail.get("local_time", "--:--"))])
	for row in rows:
		_drow(body, str(row[0]), str(row[1]))

	# The same equipment and environment data used by observation quality.
	_dsection(body, GameManager.text("Equipment & conditions", "设备与环境"))
	var equipment_names: Array[String] = []
	for part_type in GameManager.required_part_types_for_current_level():
		var part_id := GameManager.equipped_part_id(part_type)
		if part_id == "":
			continue
		var part := GameManager.get_part(part_id)
		var part_name := GameManager.dict_text(part, "name")
		if part_name != "" and not equipment_names.has(part_name):
			equipment_names.append(part_name)
	_drow(body, GameManager.text("Current equipment", "当前设备"), GameManager.text("Naked eye", "肉眼") if equipment_names.is_empty() else ", ".join(equipment_names))
	var stats := GameManager.calculate_stats()
	_drow(body, GameManager.text("Magnification", "当前倍率"), "%.1fx" % float(stats.get("magnification", 1.0)))
	var env := GameManager.current_environment()
	_drow(body, GameManager.text("Seeing", "视宁度"), str(env.get("seeing", GameManager.text("Good", "良好"))).capitalize() if GameManager.language_mode == "en" else str(env.get("seeing_zh", "良好")))
	_drow(body, GameManager.text("Cloud cover", "云层覆盖"), "%d%%" % roundi(clampf(float(env.get("cloud_cover", 0.0)), 0.0, 1.0) * 100.0))
	var drift_enabled := bool(GameManager.current_level().get("drift_enabled", false))
	var drift_text := GameManager.text("Off", "关闭")
	if drift_enabled:
		drift_text = GameManager.text("Tracking %.2fx" % GameManager.tracking_rate(), "追踪 %.2f 倍速" % GameManager.tracking_rate()) if GameManager.has_tracking_mount_equipped() else GameManager.text("Earth-rotation drift active", "地球自转漂移开启")
	_drow(body, GameManager.text("Drift / tracking", "漂移 / 追踪"), drift_text)

	# Data provenance - so "Local calculation" never reads as an error.
	_dsection(body, GameManager.text("Data source", "数据来源"))
	_drow(body, GameManager.text("Position source", "位置来源"), GameManager.text(str(detail.get("position_source_en", "")), str(detail.get("position_source_zh", ""))))
	_drow(body, GameManager.text("Weather source", "天气来源"), GameManager.text(str(detail.get("weather_source_en", "")), str(detail.get("weather_source_zh", ""))))
	_drow(body, GameManager.text("Last updated", "更新时间"), str(detail.get("last_updated", "--:--")))

	# observing advice
	_dsection(body, GameManager.text("Observing advice", "观测建议"))
	for tip in GameManager.observation_advice(object_id):
		var t: Dictionary = tip
		var tl := _dlabel(body, "· " + GameManager.text(str(t.get("en", "")), str(t.get("zh", ""))), Vector2.ZERO, Vector2(220, 0), 12, Color(0.82, 0.90, 0.72))
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.custom_minimum_size = Vector2(220, 0)

	# science note
	if str(detail.get("learning_en", "")) != "":
		_dsection(body, GameManager.text("Did you know", "科学知识"))
		var note := _dlabel(body, GameManager.text(str(detail.get("learning_en", "")), str(detail.get("learning_zh", ""))), Vector2.ZERO, Vector2(220, 0), 12, TEXT)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(220, 0)

	# Observe and Back remain the original fixed actions below this inspector.


func _close_detail_panel() -> void:
	if detail_panel != null and is_instance_valid(detail_panel):
		detail_panel.queue_free()
		detail_panel = null


func _visibility_phrase(detail: Dictionary) -> String:
	if bool(detail.get("below_horizon", false)):
		return GameManager.text("Below horizon", "地平线以下")
	if not bool(detail.get("visible", true)):
		return GameManager.text("Too low", "高度过低")
	return GameManager.text("Visible", "当前可见")


func _dsection(parent: Control, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", GOLD)
	label.custom_minimum_size = Vector2(float(parent.get_meta("detail_width", 370.0)), 24)
	parent.add_child(label)


func _drow(parent: Control, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	var row_width := float(parent.get_meta("detail_width", 370.0))
	row.custom_minimum_size = Vector2(row_width, 20)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", MUTED)
	k.custom_minimum_size = Vector2(minf(180.0, row_width * 0.48), 20)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 12)
	v.add_theme_color_override("font_color", TEXT)
	v.custom_minimum_size = Vector2(maxf(74.0, row_width - k.custom_minimum_size.x - 4.0), 20)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(v)
	parent.add_child(row)


func _dlabel(parent: Control, value: String, pos: Vector2, sz: Vector2, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	if pos != Vector2.ZERO or sz != Vector2.ZERO:
		label.position = pos
		label.size = sz
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	parent.add_child(label)
	return label


func _detail_button(text_value: String, sz: Vector2, tint: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = sz
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	var style := StyleBoxFlat.new()
	style.bg_color = tint.darkened(0.5)
	style.border_color = tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", style)
	InteractionFeedback.bind_button(button)
	return button


func _center_offset(object_id: String) -> float:
	# Largest axis offset from the view center, in degrees.
	if not in_view_targets.has(object_id):
		return 99999.0
	var item := _sky_item(object_id)
	return maxf(
		absf(shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 999.0)))),
		absf(float(item.get("altitude", 999.0)) - telescope_altitude)
	)


func _nearest_center_object() -> String:
	var nearest_id := ""
	var nearest_distance := 99999.0
	for id_value in in_view_targets.keys():
		var object_id: String = str(id_value)
		var distance := _center_offset(object_id)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = object_id
	return nearest_id


func _centered_observation_candidate() -> String:
	var candidate := _nearest_center_object()
	return candidate if candidate != "" and _is_target_centered(candidate) else ""


func _observe() -> void:
	if observe_transition_active:
		return
	call_deferred("_animate_observe_failure_if_needed")
	var active_id := _active_observation_object_id()
	if active_id == "" or not _is_target_centered(active_id):
		var centered_candidate := _centered_observation_candidate()
		if centered_candidate != "" and centered_candidate != active_id:
			_select_object(centered_candidate)
			active_id = centered_candidate
	if _is_constellation_target(active_id):
		if selected_object_id == "" and _is_target_centered(active_id):
			_select_object(active_id)
		var constellation_availability := _observe_availability()
		if not bool(constellation_availability.get("ok", false)):
			guidance_label.text = str(constellation_availability.get("reason", ""))
			return
		GameManager.selected_object_id = active_id
		await _go_to_telescope_with_lock_feedback()
		return
	# Naked-eye levels (L1/L2): the eyes ARE the instrument.
	if not GameManager.current_requires_telescope():
		if selected_object_id == "":
			var nearest_id := _nearest_center_object()
			if nearest_id != "" and _is_target_centered(nearest_id):
				_select_object(nearest_id)
		if selected_object_id != "":
			GameManager.selected_object_id = selected_object_id
			await _go_to_telescope_with_lock_feedback()
			return
		guidance_label.text = GameManager.text("Pick a bright object first.", "先选择一个明亮的目标。")
		return

	# Telescope levels: only the telescope view mode can start an observation.
	if view_mode == "naked_eye":
		guidance_label.text = GameManager.text(
			"Naked eye is for scanning. Switch to the telescope (3) to observe.",
			"肉眼只用来找方向。请切换到望远镜（按 3）进行观测。"
		)
		return
	if view_mode == "finder":
		guidance_label.text = GameManager.text(
			"The finder is for aiming only. Press 3 for the telescope.",
			"寻星镜只用来对准目标。按 3 切换到主望远镜。"
		)
		return

	if selected_object_id == "":
		var nearest_id := _nearest_center_object()
		if nearest_id != "" and _is_target_centered(nearest_id):
			_select_object(nearest_id)
	if selected_object_id == "":
		guidance_label.text = GameManager.text("No target near the center.", "中心附近没有目标。")
		return
	var offset := _center_offset(selected_object_id)
	if not _is_target_centered(selected_object_id):
		guidance_label.text = GameManager.text(
			"Center the target first. Off by %s." % _format_dms(offset),
			"请先把目标居中，还差 %s。" % _format_dms(offset)
		)
		return

	GameManager.selected_object_id = selected_object_id
	if GameManager.current_requires_focus():
		if GameManager.try_story_for_trigger("before_focus", "telescope"):
			return
		if GameManager.try_teaching_intercept("before_focus", "telescope"):
			return
	await _go_to_telescope_with_lock_feedback()


func _go_to_telescope_with_lock_feedback() -> void:
	observe_transition_active = true
	target_lock_state = "success"
	InteractionFeedback.success(observe_button, "target_observed")
	if target_state_ring != null and is_instance_valid(target_state_ring):
		target_state_ring.texture = _load_png_texture(LOCK_RING_TEXTURE)
		target_state_ring.modulate = Color(1.15, 1.08, 0.72, 1.0)
		var start_size := target_state_ring.size
		if not InteractionFeedback.is_reduced_motion():
			target_state_ring.pivot_offset = start_size * 0.5
			target_state_ring.scale = Vector2.ONE * 0.82
			var tween := create_tween().bind_node(target_state_ring)
			tween.tween_property(target_state_ring, "scale", Vector2.ONE * 1.08, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(target_state_ring, "scale", Vector2.ONE, 0.14)
	if InteractionFeedback.is_reduced_motion():
		await get_tree().create_timer(0.10).timeout
	else:
		# Shutter iris: the sky closes down to the point you locked, selling
		# "putting your eye to the telescope" before the eyepiece view opens.
		var shutter := ColorRect.new()
		shutter.set_anchors_preset(Control.PRESET_FULL_RECT)
		shutter.mouse_filter = Control.MOUSE_FILTER_STOP
		var shader := Shader.new()
		shader.code = "shader_type canvas_item;\nuniform float radius : hint_range(0.0, 1.5) = 1.4;\nvoid fragment() {\n\tvec2 centered = UV - vec2(0.5);\n\tcentered.x *= 1024.0 / 768.0;\n\tfloat edge = smoothstep(radius - 0.03, radius, length(centered));\n\tCOLOR = vec4(0.0, 0.0, 0.0, edge);\n}"
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("radius", 1.4)
		shutter.material = material
		shutter.z_index = 200
		add_child(shutter)
		var shutter_tween := create_tween().bind_node(shutter)
		shutter_tween.tween_method(func(value: float) -> void:
			material.set_shader_parameter("radius", value), 1.4, 0.02, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await shutter_tween.finished
		await get_tree().create_timer(0.06).timeout
	GameManager.go("telescope")


func _animate_observe_failure_if_needed() -> void:
	if observe_transition_active or not is_inside_tree():
		return
	InteractionFeedback.error(observe_button if observe_button != null else guidance_label)


func _update_selected_text() -> void:
	# The mission target is always shown here (no manual pick needed);
	# clicking another object in the view temporarily inspects it instead.
	var display_id := selected_object_id
	if display_id == "":
		display_id = target_id
	var obj: Dictionary = GameManager.get_object(display_id)
	var item: Dictionary = _sky_item(display_id)
	var is_mission := display_id == target_id
	var accent := GOLD if is_mission else CYAN
	if selected_badge != null:
		selected_badge.text = GameManager.text("MISSION TARGET", "任务目标") if is_mission else GameManager.text("FREE OBSERVATION", "自由观测")
		selected_badge.add_theme_color_override("font_color", accent)
	if selected_panel_border != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		panel_style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(4)
		selected_panel_border.add_theme_stylebox_override("panel", panel_style)
	selected_title.add_theme_color_override("font_color", accent)
	var prefix := ""
	if display_id == target_id:
		prefix = "★ "
	selected_title.text = prefix + GameManager.dict_text(obj, "name").replace("\n", " · ")
	# Always show the selected object's true angles AND how far the current aim
	# is from it. Mission and free observation use the exact same coordinate math.
	var label_prefix := GameManager.text("Target", "目标") if display_id == target_id else GameManager.text("Object", "天体")
	var delta_az := shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0)))
	var delta_alt := float(item.get("altitude", 0.0)) - telescope_altitude
	selected_detail.text = "%s Az: %s (%s)\n%s Alt: %s\nΔ Az: %s   Δ Alt: %s\n%s" % [
		label_prefix,
		_format_dms(float(item.get("azimuth", 0.0))),
		str(item.get("direction_text", "Estimate")),
		label_prefix,
		_format_dms(float(item.get("altitude", 0.0))),
		_format_dms(delta_az, true),
		_format_dms(delta_alt, true),
		GameManager.text(str(obj.get("type_en", item.get("type", "Object"))), str(obj.get("type_zh", "天体")))
	]


func _update_guidance() -> void:
	var text := _guidance_for_target()
	text = _apply_workflow_discipline_hint(text)
	text = _apply_mission_step_hint(text)
	guidance_label.text = text
	if guidance_banner != null:
		guidance_banner.text = text
		var centered := text.contains("Observe") or text.contains("识别") or text.contains("可以观测")
		guidance_banner.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62) if centered else Color(1.0, 0.85, 0.45))
	_update_observe_state()


func _observe_availability() -> Dictionary:
	var object_id := _active_observation_object_id()
	if object_id == "" or not _is_target_centered(object_id):
		var centered_candidate := _centered_observation_candidate()
		if centered_candidate != "":
			object_id = centered_candidate
	var free_selection := object_id != target_id
	if object_id == "" or not in_view_targets.has(object_id):
		return {"ok": false, "reason": GameManager.text("Selected object is outside the current field. Adjust azimuth and altitude.", "目标位于当前视野外，请根据方位角和俯仰角调整镜头。") if free_selection else GameManager.text("Target is outside the current field.", "目标位于当前视野外，请根据方位角和俯仰角调整镜头。")}
	var offset := _center_offset(object_id)
	if _is_constellation_target(object_id):
		if view_mode == "naked_eye":
			return {"ok": false, "reason": GameManager.text("The pattern is acquired. Switch to Finder to study and center the star field.", "已找到星群。请切换到寻星镜观察并居中整片星域。")}
		if offset > _center_tolerance():
			return {"ok": false, "reason": GameManager.text("Center the whole constellation field before observing.", "请先把整片星群居中，再开始观测。")}
		return {"ok": true, "reason": GameManager.text("Constellation field locked. Ready to observe.", "星座星域已锁定，可以观测。")}
	if not GameManager.current_requires_telescope():
		var eye_ok := view_mode == "naked_eye" and _is_target_centered(object_id)
		return {"ok": eye_ok, "reason": GameManager.text("Center the target for naked-eye observation.", "先把目标移到肉眼视野中央。")}
	if view_mode == "naked_eye":
		return {"ok": false, "reason": GameManager.text("Switch to Finder, then Scope, before observing.", "请先切换寻星镜，再进入主望远镜观测。")}
	if view_mode == "finder":
		return {"ok": false, "reason": GameManager.text("Finder is for aiming. Switch to Scope to observe.", "寻星镜用于瞄准，请切换主望远镜观测。")}
	if offset > CENTER_TOLERANCE_TELESCOPE:
		return {"ok": false, "reason": GameManager.text("Center the target inside the gold lock ring.", "请把目标移入金色锁定环。")}
	return {"ok": true, "reason": GameManager.text("Target locked. Ready to observe.", "目标已锁定，可以观测。")}


func _update_observe_state() -> void:
	if observe_button == null:
		return
	var availability := _observe_availability()
	var available := bool(availability.get("ok", false))
	observe_button.disabled = not available
	observe_button.tooltip_text = str(availability.get("reason", ""))
	if observe_disabled_shade != null:
		observe_disabled_shade.visible = not available


func _guidance_for_target() -> String:
	var active_id := _active_observation_object_id()
	var item := _sky_item(active_id)
	if item.is_empty():
		return ""
	var altitude: float = float(item.get("altitude", 0.0))
	if arrival_hint_until > Time.get_ticks_msec():
		return GameManager.text("The target is above the horizon at the new site. Use Eye, Finder, or Telescope to locate it.", "目标在新地点已经升起。请使用肉眼、寻星镜或望远镜寻找目标。")
	if altitude >= 0.0 and altitude < COMFORTABLE_OBSERVING_ALTITUDE:
		return GameManager.text("The target has just risen or is about to set. Observe here, or choose a more comfortable site.", "目标刚刚升起或即将落下。可以在此观测，或更换到更舒适的地点。")
	if active_id != target_id:
		if altitude <= 0.0:
			return GameManager.text("This free-observation target is below the horizon at the current site.", "该自由观测目标位于当前地点的地平线以下。")
		if not in_view_targets.has(active_id):
			return GameManager.text("Selected free target is outside the current field. Adjust azimuth and altitude.", "目标位于当前视野外，请根据方位角和俯仰角调整镜头。")
		if _is_target_centered(active_id):
			return GameManager.text("Free target centered. Ready to observe without affecting the mission.", "自由观测目标已居中，可观测；不会影响当前任务。")
		var free_delta_az := shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0)))
		var free_delta_alt := altitude - telescope_altitude
		return _movement_guidance(free_delta_az, free_delta_alt)
	if altitude <= 0.0:
		return GameManager.text("Below horizon. Cannot observe tonight.", "目标在地平线以下，今晚无法观测。")
	var delta_az := shortest_angle_degrees(telescope_azimuth, float(item.get("azimuth", 0.0)))
	var delta_alt := altitude - telescope_altitude
	var half_x := fov_x * 0.5
	var half_y := fov_y * 0.5
	if _is_constellation_target(target_id):
		if absf(delta_az) <= half_x and absf(delta_alt) <= half_y:
			if view_mode == "naked_eye":
				return GameManager.text("Constellation in view. Switch to Finder (2) and center the full pattern.", "星座已进入视野。切换到寻星镜（2），将完整星群居中。")
			if _is_target_centered(target_id):
				return GameManager.text("Constellation field locked. Observe the pattern.", "星座星域已锁定，可以观察图形。")
			return GameManager.text("Keep the entire constellation pattern centered.", "继续调整，让整片星座图形保持居中。")
		return _movement_guidance(delta_az, delta_alt)
	if int(GameManager.current_level().get("level_number", 0)) == 25 and maxf(absf(delta_az), absf(delta_alt)) > fov_x * 0.05:
		return _movement_guidance(delta_az, delta_alt)

	if absf(delta_az) <= half_x and absf(delta_alt) <= half_y:
		var offset := maxf(absf(delta_az), absf(delta_alt))
		if view_mode == "telescope":
			if _is_target_centered(target_id):
				return GameManager.text("Centered. Ready for telescope. Observe!", "已居中，可以观测了！")
			return GameManager.text(
				"In telescope view. Center within %s." % _format_dms(CENTER_TOLERANCE_TELESCOPE),
				"目标在望远镜视野中，请居中到 %s 以内。" % _format_dms(CENTER_TOLERANCE_TELESCOPE)
			)
		if view_mode == "finder":
			if _is_target_centered(target_id):
				return GameManager.text("Centered enough for telescope. Press 3.", "已接近望远镜视野，按 3 切换主望远镜。")
			return GameManager.text("Target in finder scope. Center it.", "目标已进入寻星镜视野，请居中。")
		if not GameManager.current_requires_telescope():
			if _is_target_centered(target_id):
				return GameManager.text("Target in sight. Observe with your eyes!", "目标就在眼前，直接观察吧！")
			return GameManager.text("Target in view. Move it toward the center.", "目标在视野中，把它移向中心。")
		if _is_target_centered(target_id):
			return GameManager.text("Target locked. Press 2 to zoom in with the finder.", "目标已金色锁定，按 2 用寻星镜放大。")
		if bool(GameManager.current_level().get("hide_target_hint", false)) and offset <= fov_x * 0.18:
			return GameManager.text("Target acquired. Follow the cyan ring to the center.", "已捕获目标。跟随青色环将它移到中心。")
		return GameManager.text("Target in view. Move it toward the center.", "目标在视野中，把它移向中心。")

	# Out of view: give exact DMS turn amounts.
	var en_parts: Array[String] = []
	var zh_parts: Array[String] = []
	if delta_az > 1.0:
		en_parts.append("Hold D: turn east %s." % _format_dms(absf(delta_az)))
		zh_parts.append("按住 D：向东转 %s。" % _format_dms(absf(delta_az)))
	elif delta_az < -1.0:
		en_parts.append("Hold A: turn west %s." % _format_dms(absf(delta_az)))
		zh_parts.append("按住 A：向西转 %s。" % _format_dms(absf(delta_az)))
	if delta_alt > 1.0:
		en_parts.append("Hold W: raise %s." % _format_dms(absf(delta_alt)))
		zh_parts.append("按住 W：抬高 %s。" % _format_dms(absf(delta_alt)))
	elif delta_alt < -1.0:
		en_parts.append("Hold S: lower %s." % _format_dms(absf(delta_alt)))
		zh_parts.append("按住 S：降低 %s。" % _format_dms(absf(delta_alt)))
	if en_parts.is_empty():
		return GameManager.text("Target just outside view. Nudge slightly.", "目标就在视野边缘，微调一下。")
	return GameManager.text(" ".join(en_parts), "".join(zh_parts))


func _movement_guidance(delta_az: float, delta_alt: float) -> String:
	var en_parts: Array[String] = []
	var zh_parts: Array[String] = []
	if delta_az > 0.25:
		en_parts.append("Hold D: move east %s." % _format_dms(absf(delta_az)))
		zh_parts.append("按住 D：向东移动 %s。" % _format_dms(absf(delta_az)))
	elif delta_az < -0.25:
		en_parts.append("Hold A: move west %s." % _format_dms(absf(delta_az)))
		zh_parts.append("按住 A：向西移动 %s。" % _format_dms(absf(delta_az)))
	if delta_alt > 0.25:
		en_parts.append("Hold W: raise %s." % _format_dms(absf(delta_alt)))
		zh_parts.append("按住 W：抬高 %s。" % _format_dms(absf(delta_alt)))
	elif delta_alt < -0.25:
		en_parts.append("Hold S: lower %s." % _format_dms(absf(delta_alt)))
		zh_parts.append("按住 S：降低 %s。" % _format_dms(absf(delta_alt)))
	return GameManager.text(" ".join(en_parts), "".join(zh_parts))


func _apply_mission_step_hint(default_text: String) -> String:
	# When the level has an unfinished checklist (e.g. L10's 20mm-then-10mm),
	# lead with which step is still pending instead of the generic aim hint.
	var step := GameManager.next_pending_mission_step()
	if step.is_empty():
		return default_text
	var label := GameManager.dict_text(step, "label")
	var steps := GameManager.mission_steps()
	var done := GameManager.completed_mission_steps().size()
	return GameManager.text(
		"Step %d/%d: %s" % [done + 1, steps.size(), label],
		"步骤 %d/%d：%s" % [done + 1, steps.size(), label]
	)


func _update_workflow_discipline_timer(delta: float) -> void:
	# L16 "Narrow Field Problem": if the player is stuck in the telescope
	# view without ever visiting the finder, and the target still isn't
	# centered after a while, show Maya's stronger one-time reminder panel
	# (the persistent bottom-bar hint from _apply_workflow_discipline_hint
	# stays as-is; this is an additional, harder-to-miss layer).
	if not GameManager.uses_full_tutorials():
		return
	var level_variation: String = str(GameManager.current_level().get("variation", ""))
	if level_variation != "workflow_discipline" or workflow_prompt_shown:
		return
	if view_mode != "telescope" or visited_modes.has("finder"):
		return
	var target_centered := _is_target_centered(target_id)
	if target_centered:
		return
	workflow_elapsed += delta
	if workflow_elapsed >= WORKFLOW_LOST_SECONDS or workflow_move_count >= WORKFLOW_LOST_MOVES:
		_show_workflow_lost_panel()


func _show_workflow_lost_panel() -> void:
	workflow_prompt_shown = true
	var lines: Array = StoryManager.get_dialogue("level_16_mid")
	var text_en := "Lost? Everyone gets lost in six degrees. Wide first, narrow last."
	var text_zh := "迷路了吧？在 6 度的视野里谁都会迷路。先宽后窄。"
	if not lines.is_empty() and lines[0] is Dictionary:
		var line: Dictionary = lines[0]
		text_en = str(line.get("text_en", text_en))
		text_zh = str(line.get("text_zh", text_zh))

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_rect(overlay, Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.55))

	var panel_size := Vector2(560, 220)
	var panel_pos := Vector2((W - panel_size.x) * 0.5, (H - panel_size.y) * 0.5)
	_rect(overlay, panel_pos, panel_size, Color(0.04, 0.05, 0.09, 0.97))
	var frame := _make_frame(overlay, Rect2(panel_pos, panel_size), GOLD, 3)
	frame.visible = true

	var name_label := _label(overlay, "Maya", panel_pos + Vector2(24, 18), Vector2(panel_size.x - 48, 24), 15, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var body := _label(overlay, GameManager.text(text_en, text_zh), panel_pos + Vector2(24, 52), Vector2(panel_size.x - 48, 110), 14, TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = 5

	var hint := _label(overlay, GameManager.text("Press SPACE to continue", "按 SPACE 继续"), panel_pos + Vector2(24, panel_size.y - 34), Vector2(panel_size.x - 48, 20), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			overlay.queue_free()
		elif event is InputEventMouseButton and event.pressed:
			overlay.queue_free()
	)
	# Also allow unhandled key input in case focus isn't on the overlay.
	overlay.focus_mode = Control.FOCUS_ALL
	overlay.grab_focus()


func _apply_workflow_discipline_hint(default_text: String) -> String:
	# L16 "Narrow Field Problem": if the player jumps straight to the
	# telescope without ever visiting the finder, swap in Maya's reminder
	# instead of the normal guidance line.
	var level_variation: String = str(GameManager.current_level().get("variation", ""))
	if level_variation != "workflow_discipline":
		return default_text
	if view_mode != "telescope" or visited_modes.has("finder"):
		return default_text
	return GameManager.text(
		"Lost? Everyone gets lost in six degrees. Wide first, narrow last.",
		"迷路了吧？在 6 度的视野里谁都会迷路。先宽后窄。"
	)


# --------------------------------------------------------------------- state


func _finder_installed() -> bool:
	var state: Dictionary = GameManager.progress.get("assembly_state", {})
	var finder: Dictionary = state.get("finder_scope", {})
	return bool(finder.get("installed", false))


func _sky_item(object_id: String) -> Dictionary:
	if sky_data.has(object_id):
		return sky_data[object_id]
	return {}


func _visibility_color(item: Dictionary) -> Color:
	var text := str(item.get("visibility_text", ""))
	if text == "Visible tonight":
		return GREEN
	if text == "Low on horizon":
		return WARNING
	return MUTED


# ------------------------------------------------------------------- helpers


func _transparent_button(rect: Rect2, tooltip: String) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = ""
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	return button


func _make_frame(parent: Control, rect: Rect2, color: Color, width: int) -> Control:
	var frame := Control.new()
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	_rect(frame, Vector2.ZERO, Vector2(rect.size.x, width), color)
	_rect(frame, Vector2(0, rect.size.y - width), Vector2(rect.size.x, width), color)
	_rect(frame, Vector2.ZERO, Vector2(width, rect.size.y), color)
	_rect(frame, Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y), color)
	return frame


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _on_language_changed() -> void:
	_clear_built_ui()
	_build()


func _clear_built_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	star_pool.clear()
	object_icons.clear()
	object_buttons.clear()
	az_ticks.clear()
	az_labels.clear()
	alt_ticks.clear()
	alt_labels.clear()
	mode_buttons.clear()
	cloud_nodes.clear()
	cloud_sky_anchors.clear()
	cloud_velocities.clear()
	selection_frame = null
	assist_frame = null
	guidance_banner = null
	guidance_banner_bg = null
	controls_help = null
	scope_reticle_layer = null
	optical_mode_transition = null
	reticle_transition_ghost = null
	if mode_transition_tween != null and mode_transition_tween.is_valid():
		mode_transition_tween.kill()
	mode_transition_tween = null
	mode_content_alpha = 1.0
	az_target_pointer = null
	alt_target_pointer = null
	az_knob_icon = null
	alt_knob_icon = null
	target_state_ring = null
	edge_target_indicator = null
	edge_target_arrow = null
	edge_target_name = null
	edge_target_delta = null
	edge_target_tween = null
	edge_target_object_id = ""
	edge_target_state = "hidden"
	edge_target_transition_serial = 0
	faint_mission_target_waypoint = null
	faint_mission_target_waypoint_id = ""
	selected_badge = null
	selected_panel_border = null
