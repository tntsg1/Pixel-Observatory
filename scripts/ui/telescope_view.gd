extends Control

const TURBULENCE_SHADER := preload("res://shaders/turbulence.gdshader")
const GRAIN_SHADER := preload("res://shaders/grain.gdshader")
const LENS_RING_OCCLUDER_SHADER := preload("res://shaders/lens_ring_occluder.gdshader")
const NAKED_EYE_OUTER_RING_SHADER := preload("res://shaders/naked_eye_outer_ring.gdshader")
const OPTICAL_LENS_SHADER := preload("res://shaders/optical_lens.gdshader")

const COL_BG := Color(0.004, 0.006, 0.014)
const COL_NAVY := Color(0.030, 0.045, 0.085, 0.96)
const COL_PANEL := Color(0.050, 0.070, 0.120, 0.96)
const COL_GOLD := Color(0.78, 0.56, 0.28)
const COL_GOLD_LIGHT := Color(0.95, 0.76, 0.42)
const COL_BLUE_BORDER := Color(0.17, 0.25, 0.40)
const COL_TEXT := Color(0.96, 0.94, 0.88)
const COL_CROSSHAIR := Color(0.50, 0.70, 0.90, 0.22)

# Large pixel-art sprites shown through the eyepiece.
const SPRITE_MAP := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"vega": "res://assets/telescope_view/vega_chromatic_demo.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_large.png",
	"andromeda": "res://assets/telescope_view/andromeda_large.png",
	"arcturus": "res://assets/telescope_view/arcturus_clear.png",
	"canopus": "res://assets/telescope_view/canopus_clear.png",
	"alpha_centauri": "res://assets/telescope_view/alpha_cen_clear.png",
	"proxima": "res://assets/telescope_view/proxima_clear.png",
	"mercury": "res://assets/telescope_view/expansion/mercury.svg",
	"venus": "res://assets/telescope_view/expansion/venus.svg",
	"saturn": "res://assets/telescope_view/expansion/saturn.svg",
	"uranus": "res://assets/telescope_view/expansion/uranus.svg",
	"neptune": "res://assets/telescope_view/expansion/neptune.svg",
	"moon_crater_copernicus": "res://assets/telescope_view/expansion/moon_crater.svg",
	"moon_mare_tranquillitatis": "res://assets/telescope_view/expansion/moon_mare.svg",
	"moon_terminator": "res://assets/telescope_view/expansion/moon_terminator.svg",
	"albireo": "res://assets/telescope_view/expansion/albireo.svg",
	"pleiades": "res://assets/telescope_view/expansion/pleiades.svg",
	"m13": "res://assets/telescope_view/expansion/m13.svg",
	"ring_nebula": "res://assets/telescope_view/expansion/ring_nebula.svg",
	"lagoon_nebula": "res://assets/telescope_view/expansion/lagoon_nebula.svg",
	"sombrero_galaxy": "res://assets/telescope_view/expansion/sombrero.svg",
	"crab_nebula": "res://assets/telescope_view/temporary/crab_nebula.svg",
	"dumbbell_nebula": "res://assets/telescope_view/temporary/dumbbell_nebula.svg",
	"double_cluster": "res://assets/telescope_view/temporary/double_cluster.svg",
	"whirlpool_galaxy": "res://assets/telescope_view/temporary/whirlpool_galaxy.svg",
	"needle_galaxy": "res://assets/telescope_view/temporary/needle_galaxy.svg"
}

# Per-object state textures: clear (sharp art) / blurry (defocus photo,
# cross-fade overlay) / dim (light shortage). Add an entry here and the
# whole three-state pipeline picks it up automatically.
const STATE_TEXTURES := {
	"jupiter": {
		"clear": "res://assets/telescope_view/jupiter_clear.png",
		"blurry": "res://assets/telescope_view/jupiter_blurry.png",
		"dim": "res://assets/telescope_view/jupiter_dim.png"
	},
	"mars": {
		"clear": "res://assets/telescope_view/mars_clear.png",
		"blurry": "res://assets/telescope_view/mars_blurry.png",
		"dim": "res://assets/telescope_view/mars_dim.png"
	},
	"moon": {
		"clear": "res://assets/telescope_view/moon_clear.png",
		"blurry": "res://assets/telescope_view/moon_blurry.png",
		"dim": "res://assets/telescope_view/moon_dim.png"
	},
	"andromeda": {
		"clear": "res://assets/telescope_view/andromeda_clear.png",
		"blurry": "res://assets/telescope_view/andromeda_blurry.png",
		"dim": "res://assets/telescope_view/andromeda_dim.png"
	},
	"vega": {
		"clear": "res://assets/telescope_view/vega_user_clear.png",
		"blurry": "res://assets/telescope_view/vega_user_blurry.png",
		"dim": "res://assets/telescope_view/vega_user_dim.png"
	},
	"orion_nebula": {
		"clear": "res://assets/telescope_view/orion_nebula_clear.png",
		"blurry": "res://assets/telescope_view/orion_nebula_blurry.png",
		"dim": "res://assets/telescope_view/orion_nebula_dim.png"
	},
	"polaris": {
		"clear": "res://assets/telescope_view/star_white_clear.png",
		"blurry": "res://assets/telescope_view/star_white_blurry.png",
		"dim": "res://assets/telescope_view/star_white_dim.png"
	},
	"sirius": {
		"clear": "res://assets/telescope_view/star_blue_clear.png",
		"blurry": "res://assets/telescope_view/star_blue_blurry.png",
		"dim": "res://assets/telescope_view/star_blue_dim.png"
	},
	"betelgeuse": {
		"clear": "res://assets/telescope_view/star_red_clear.png",
		"blurry": "res://assets/telescope_view/star_red_blurry.png",
		"dim": "res://assets/telescope_view/star_red_dim.png"
	},
	"arcturus": {
		"clear": "res://assets/telescope_view/arcturus_clear.png",
		"blurry": "res://assets/telescope_view/arcturus_blurry.png",
		"dim": "res://assets/telescope_view/arcturus_dim.png"
	},
	"canopus": {
		"clear": "res://assets/telescope_view/canopus_clear.png",
		"blurry": "res://assets/telescope_view/canopus_blurry.png",
		"dim": "res://assets/telescope_view/canopus_dim.png"
	},
	"alpha_centauri": {
		"clear": "res://assets/telescope_view/alpha_cen_clear.png",
		"blurry": "res://assets/telescope_view/alpha_cen_blurry.png",
		"dim": "res://assets/telescope_view/alpha_cen_dim.png"
	},
	"proxima": {
		"clear": "res://assets/telescope_view/proxima_clear.png",
		"blurry": "res://assets/telescope_view/proxima_blurry.png",
		"dim": "res://assets/telescope_view/proxima_dim.png"
	}
}

# Right panel layout (1024x768): everything must stay above y = 700.
const PANEL_POS := Vector2(752, 106)
const PANEL_SIZE := Vector2(236, 594)
const CONTENT_X := 772.0
const CONTENT_W := 194.0
const FOCUS_ADJUST_SPEED := 0.22
const OBS_UI_DIR := "res://assets/ui/observation/suc/processed/"
const Z_MODAL_OVERLAY := 1000
const EYE_RETICLE_TEXTURE := OBS_UI_DIR + "eye_large_center.png"


class ConstellationField extends Control:
	var pattern: Array = []

	func _draw() -> void:
		if pattern.is_empty():
			return
		var area := Rect2(Vector2(120, 105), Vector2(396, 350))
		for star_value in pattern:
			var star: Dictionary = star_value
			var position := area.position + Vector2(float(star.get("x", 0.5)), float(star.get("y", 0.5))) * area.size
			var magnitude := float(star.get("magnitude", 2.0))
			var radius := clampf(5.0 - magnitude * 0.8, 2.0, 4.2)
			draw_circle(position, radius * 2.5, Color(0.58, 0.78, 1.0, 0.15))
			draw_circle(position, radius, Color(0.97, 0.98, 1.0, 0.98))


class AvertedVisionGuide extends Control:
	var target_position := Vector2.ZERO
	var enabled := false
	var active := false
	var adaptation := 0.0
	var hold_visual := 0.0
	var phase := 0.0

	func _process(delta: float) -> void:
		if not enabled:
			return
		phase += delta
		queue_redraw()

	func _draw() -> void:
		if not enabled:
			return
		var offset_direction := Vector2(0.84, -0.54)
		var gaze_position := target_position + offset_direction * 58.0
		var guide_color := Color(0.38, 0.86, 1.0, 0.72) if not active else Color(1.0, 0.76, 0.30, 0.94)
		var start := target_position + offset_direction * 17.0
		var end := gaze_position - offset_direction * 17.0
		for index in range(5):
			var t0 := float(index) / 5.0
			var t1 := minf(1.0, t0 + 0.10)
			var alpha := 0.24 + float(index) * 0.08
			draw_line(start.lerp(end, t0), start.lerp(end, t1), Color(guide_color.r, guide_color.g, guide_color.b, alpha), 1.0)
		var pulse := 1.0 if InteractionFeedback.is_reduced_motion() else 1.0 + sin(phase * 3.4) * 0.08
		var marker_radius := 15.0 * pulse
		draw_arc(gaze_position, marker_radius, 0.0, TAU, 28, guide_color, 1.5)
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(gaze_position + direction * 19.0, gaze_position + direction * 25.0, guide_color, 1.5)
		draw_arc(gaze_position, marker_radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * hold_visual, 32, Color(0.42, 1.0, 0.62, 0.94), 2.0)
		if active:
			for index in range(3):
				var angle := phase * (0.35 + float(index) * 0.08) + float(index) * TAU / 3.0
				var radius := 26.0 + adaptation * 9.0
				draw_circle(target_position + Vector2.RIGHT.rotated(angle) * radius, 1.5, Color(0.50, 1.0, 0.72, 0.46))


var feedback_label: Label
var quality_label: Label
var mission_step_label: Label
var choices_box: VBoxContainer
var identify_title_label: Label
var identify_choice_ids: Array[String] = []
var quiz_brief_overlay: Control
var quiz_brief_dismissed := false
var is_free_observation := false
var free_result_label: Label
var mission_return_in_progress := false
var observation: Dictionary
var selected_object: Dictionary

static var _last_correct_choice_index := -1

var observation_mode := "telescope"
var requires_focus := false
var allow_focus_input := true
var focus_value := 0.5
var target_focus_value := 0.5
var focus_tolerance := 0.06
var focus_error := 0.0
var focus_locked := false

var focus_slider: HSlider
var focus_knob_status: TextureRect
var focus_state_label: Label
var focus_pct_label: Label
var updating_slider := false
var focus_guide_panel: Panel
var focus_guide_text: Label
var focus_guide_zone: ColorRect
var focus_guide_active := false
var focus_adjustment_count := 0
var focus_direction_changes := 0
var last_focus_adjust_direction := 0
var best_focus_error := 1.0
var last_focus_improvement_adjustment := 0
var focus_lock_feedback_played := false
var focus_missing_feedback_cooldown := 0.0
var identify_transition_active := false
var stat_bar_fills: Array[ColorRect] = []

var lens_center := Vector2.ZERO
var target_center := Vector2.ZERO
var main_sprite: TextureRect
var ghost_a: TextureRect
var ghost_b: TextureRect
var blur_overlay: TextureRect
var base_alpha := 1.0
var current_sprite_path := ""
var noise_quality := ""
var constellation_field: ConstellationField

# Smoothed display values: inputs are quantized (slider steps, quality
# tiers), so visuals chase their targets each frame instead of snapping.
var visual_focus_error := 0.0
var visual_target_center := Vector2.ZERO
var visual_base_alpha := 1.0
var blur_weight := 0.0
# Final on-screen scale for the target sprites (magnification vs fit cap).
var display_scale := 1.0

# L18 dark adaptation + averted vision (nebula/galaxy targets only): purely
# cosmetic alpha boosts that help the player SEE the faint smudge, without
# changing the underlying evaluation (the physics doesn't care if your eyes
# have adjusted).
const DARK_ADAPTATION_SECONDS := 8.0
const DARK_ADAPTATION_ALPHA_BONUS := 0.10
const AVERTED_VISION_ALPHA_BONUS := 0.10
const AVERTED_VISION_BRIGHTEN := 1.06
var dark_adaptation := 0.0
var averted_vision_active := false
var averted_hold_visual := 0.0
var averted_vision_guide: AvertedVisionGuide
var dark_adaptation_label: Label
var averted_vision_label: Label
var exposure_value := 0.5
var active_filter := "none"
var observation_elapsed := 0.0
var technique_reevaluate_timer := 0.0
var technique_status_label: Label
var technique_filter_button: Button
var star_layer_nodes: Array[ColorRect] = []
var star_layer_container: Control

# --- Observation-condition realism (E1): conditions snapshot, all smoothed.
var cond_turbulence := 0.0     # 0-1, atmospheric turbulence (seeing x mag x altitude)
var cond_cloud_atten := 0.0    # 0-1, instantaneous cloud attenuation on the target
var cond_sky_lift := 0.0       # 0-1, background brightening (city 1.0 / suburban 0.5 / dark 0)
var effect_seed := 0.0         # per-observation random phase so breathing/jitter don't sync
var turbulence_material_main: ShaderMaterial
var turbulence_material_blur: ShaderMaterial
var turbulence_material_ghost: ShaderMaterial
var grain_layer: ColorRect
var grain_material: ShaderMaterial
var grain_intensity := 0.0
var target_grain_intensity := 0.0
var cloud_nodes: Array[TextureRect] = []
var cloud_velocities: Array[Vector2] = []
var cloud_strengths: Array[float] = []
var cloud_veil: Panel
var cloud_cover_level := 0.0
var cloud_reevaluate_timer := 0.0
const CLOUD_TEXTURES := [
	"res://assets/telescope_view/cloud_wisp_a.png",
	"res://assets/telescope_view/cloud_wisp_b.png",
	"res://assets/telescope_view/cloud_wisp_c.png"
]

# Real-sky background stars (deep HYG catalog, mag <= 8).
const DEEP_STARS_PATH := "res://data/deep_stars.json"
const SCOPE_FOV_RADIUS_DEG := 2.6   # eyepiece circle spans ~5.2 deg of sky
const EYE_FOV_RADIUS_DEG := 24.0    # naked-eye circle spans ~48 deg

# --- Earth-drift and tracking (E2). drift_enabled levels move the target and
# the scope's star field together (the sky is turning); the player fights it
# with WASD/arrows, or a tracking mount cancels it automatically.
# NOTE: Vector2.rotated() is not a constant expression in GDScript 4.7, so
# the drift direction is computed once in _init_drift() instead of const.
var drift_direction := Vector2.RIGHT
const DRIFT_SPEED_BASE := 6.0            # px/s at magnification 35x
const DRIFT_CORRECTION_SPEED := 90.0     # px/s, player nudging the offset back
const DRIFT_OUT_OF_VIEW := 250.0         # px, |offset| beyond this = Failed
const DRIFT_HOLD_RADIUS := 46.0          # px, inside this counts toward hold
var drift_enabled := false
var drift_offset := Vector2.ZERO
var hold_seconds_required := 0.0
var hold_timer := 0.0
var hold_strict := false
var drift_reevaluate_timer := 0.0
var tracking_slider: HSlider
var tracking_knob_status: TextureRect
var tracking_enabled_status: TextureRect
var tracking_label: Label
var hold_label: Label
var hold_bar_fill: ColorRect
var drift_label: Label
var target_off_center := false
var tracking_feedback_enabled := false
var tracking_feedback_aligned := false


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	GameManager.sync_newtonian_installed_equipment()
	selected_object = GameManager.get_object(GameManager.selected_object_id)
	if selected_object.is_empty():
		selected_object = GameManager.current_target()
		GameManager.selected_object_id = str(selected_object.get("id", ""))
	# Free observation: the player is looking at a non-mission object. It shares
	# every optical mechanic but never runs the identify quiz or completes the
	# mission.
	is_free_observation = GameManager.is_free_observation()
	observation_mode = GameManager.current_observation_mode()
	requires_focus = observation_mode == "telescope" and GameManager.current_requires_focus()
	allow_focus_input = _focus_knob_installed()
	_init_drift()
	if requires_focus:
		_init_focus()
	observation = _evaluate()
	_check_mission_step_progress()
	_build()
	InteractionFeedback.page_enter(self)
	call_deferred("_show_focus_tutorial")


func _show_focus_tutorial() -> void:
	# The object guide is modal. Queue first-use focus/weather/tracking help
	# until it closes so the shared tutorial layer cannot pierce the dialog.
	if quiz_brief_overlay != null and is_instance_valid(quiz_brief_overlay):
		return
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	if requirements.has("filter") and not InteractionFeedback.was_tutorial_seen("first_nebula_filter"):
		InteractionFeedback.tutorial_highlight_once(
			technique_filter_button,
			"first_nebula_filter",
			GameManager.text(
				"A nebula filter is not an automatic upgrade: it darkens part of the sky glow so emission nebulae stand out. Click FILTER: OFF to switch it to NEBULA before observing.",
				"星云滤镜不是自动加成：它会压暗部分天空背景，让发射星云更容易分辨。观测前点击“滤镜：关闭”，把它切换为“星云”。"
			),
			self
		)
		return
	if bool(requirements.get("require_averted_vision", false)) and not InteractionFeedback.was_tutorial_seen("first_averted_vision"):
		var technique_target: Control = averted_vision_guide if averted_vision_guide != null else technique_status_label
		InteractionFeedback.tutorial_highlight_once(
			technique_target,
			"first_averted_vision",
			GameManager.text(
				"Do not stare at the faint object. Hold SHIFT: the side marker shows where to rest your gaze, while peripheral vision reveals the target.",
				"不要直盯暗弱天体。按住 SHIFT，把视线放在旁边的侧视标记上；周边视觉会逐渐显出目标。"
			),
			self
		)
		return
	if drift_enabled and not InteractionFeedback.was_tutorial_seen("first_earth_drift"):
		var drift_target: Control = tracking_slider if tracking_slider != null else drift_label
		InteractionFeedback.tutorial_highlight_once(drift_target, "first_earth_drift", GameManager.text(
			"Earth rotation makes the target drift. Recenter it or tune tracking near 1.0x.",
			"地球自转会让目标漂移；请重新居中，或把追踪调到接近 1.0x。"
		), self)
		return
	if cloud_cover_level > 0.0 and not InteractionFeedback.was_tutorial_seen("first_scope_cloud"):
		InteractionFeedback.tutorial_highlight_once(quality_label, "first_scope_cloud", GameManager.text(
			"Cloud attenuation changes continuously. Focus cannot remove cloud cover.",
			"云层遮挡会连续变化，调焦不能消除云层。"
		), self)
		return
	InteractionFeedback.tutorial_highlight_once(
		focus_slider,
		"first_focus_control",
		GameManager.text("Turn the focus control until the image becomes sharp.", "调整调焦旋钮，直到图像变得清晰。"),
		self
	)


func _init_drift() -> void:
	var level := GameManager.current_level()
	drift_enabled = observation_mode == "telescope" and bool(level.get("drift_enabled", false))
	hold_seconds_required = float(level.get("hold_seconds", 0.0)) if drift_enabled else 0.0
	hold_strict = drift_enabled and bool(level.get("hold_strict", false))
	drift_offset = Vector2.ZERO
	drift_direction = Vector2.RIGHT.rotated(0.08)
	hold_timer = 0.0
	target_off_center = false


func _focus_knob_installed() -> bool:
	return GameManager.focus_control_installed()


func _focus_control_score() -> float:
	var stats: Dictionary = GameManager.calculate_stats()
	return float(stats.get("focus_control_score", 0.0))


func _is_dark_adaptation_target() -> bool:
	if not requires_focus:
		return false
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	return type_lower.contains("nebula") or type_lower.contains("galaxy") or requirements.has("dark_adaptation_min")


# ------------------------------------------------------- object-type dispatch


func _is_star_target() -> bool:
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("star")


func _is_diffuse_target() -> bool:
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("nebula") or type_lower.contains("galaxy")


func _collimation_severity() -> float:
	if observation_mode != "telescope" or not bool(GameManager.current_level().get("requires_collimation", false)):
		return 0.0
	# Residual error at the normal acceptance threshold remains visible but
	# modest; badly tilted mirrors quickly reach the full coma treatment.
	return clampf((100.0 - GameManager.collimation_score()) / 50.0, 0.0, 1.0)


func _collimation_direction() -> Vector2:
	# Existing saves retain only alignment magnitude. Use a stable per-target
	# direction so the aberration never flips while the player is observing.
	var seed := absi(str(selected_object.get("id", "star")).hash())
	return Vector2.from_angle(deg_to_rad(fmod(float(seed), 360.0)))


# --------------------------------------------------------- conditions snapshot


func _seeing_severity() -> float:
	var environment: Dictionary = GameManager.current_environment()
	if environment.is_empty():
		return 0.06
	var seeing_label := str(observation.get("seeing_label", "Good"))
	match seeing_label:
		"Poor":
			return 0.8
		"Average":
			return 0.35
	return 0.06


func _current_altitude() -> float:
	var aim: Dictionary = GameManager.last_sky_aim
	if bool(aim.get("valid", false)):
		return float(aim.get("altitude", 45.0))
	return 45.0


func _target_turbulence() -> float:
	var stats := GameManager.calculate_stats()
	var magnification := float(stats.get("magnification", 0.0))
	var severity := _seeing_severity()
	var mag_factor := clampf(magnification / 55.0, 0.4, 1.6)
	var altitude_factor := clampf(1.6 - _current_altitude() / 60.0, 0.7, 1.3)
	var turbulence := clampf(severity * mag_factor * altitude_factor, 0.0, 1.0)
	if _is_star_target():
		# The atmosphere is never perfectly still: a point source always
		# scintillates at the eyepiece, even under "good" seeing.
		turbulence = maxf(turbulence, 0.16)
	return turbulence


func _target_sky_lift() -> float:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	match sky_key:
		"city":
			return 1.0
		"suburban":
			return 0.5
	return 0.0


func _cloud_cover() -> float:
	var environment: Dictionary = GameManager.current_environment()
	return clampf(float(environment.get("cloud_cover", 0.0)), 0.0, 1.0)


func _cloud_tier_label() -> Dictionary:
	# UI + numeric agreement: Clear / Thin / Moderate / Heavy.
	var cover := cloud_cover_level
	if cover <= 0.0:
		return {"en": "Clear", "zh": "晴朗"}
	if cover < 0.34:
		return {"en": "Thin", "zh": "薄云"}
	if cover < 0.67:
		return {"en": "Moderate", "zh": "中云"}
	return {"en": "Heavy", "zh": "厚云"}


func _sky_tier_label() -> Dictionary:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	match sky_key:
		"city":
			return {"en": "City", "zh": "城市"}
		"suburban":
			return {"en": "Suburban", "zh": "郊区"}
	return {"en": "Dark", "zh": "暗夜"}


func _contrast_label() -> Dictionary:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	var rank := 2  # 0=Low 1=Medium 2=High
	match sky_key:
		"city":
			rank = 0
		"suburban":
			rank = 1
	if cloud_tier_index() >= 2:  # Moderate or Heavy
		rank = maxi(rank - 1, 0)
	match rank:
		0:
			return {"en": "Low", "zh": "低"}
		1:
			return {"en": "Medium", "zh": "中"}
	return {"en": "High", "zh": "高"}


func cloud_tier_index() -> int:
	var cover := cloud_cover_level
	if cover <= 0.0:
		return 0
	if cover < 0.34:
		return 1
	if cover < 0.67:
		return 2
	return 3


func _process(delta: float) -> void:
	observation_elapsed += delta
	technique_reevaluate_timer += delta
	focus_missing_feedback_cooldown = maxf(0.0, focus_missing_feedback_cooldown - delta)
	if _is_dark_adaptation_target():
		_advance_dark_adaptation(delta)
		_update_averted_vision_guide(delta)
	if technique_reevaluate_timer >= 0.25 and not GameManager.current_level().get("observation_requirements", {}).is_empty():
		technique_reevaluate_timer = 0.0
		observation = _evaluate()
		_refresh_target_sprite()
		_refresh_focus_ui()
		_refresh_technique_status()
	if requires_focus or drift_enabled:
		# The chase also repositions the target sprite: on drift levels it
		# must run even without focus, or the star field slides while the
		# target itself stays frozen.
		_advance_visual_smoothing(delta)
	if observation_mode != "naked_eye" and not _is_constellation_observation():
		_advance_conditions(delta)
	if drift_enabled:
		_advance_drift(delta)
	_handle_focus_input(delta)


func _handle_focus_input(delta: float) -> void:
	if not requires_focus or focus_locked or quiz_brief_overlay != null:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_Q):
		direction -= 1.0
	if Input.is_key_pressed(KEY_E):
		direction += 1.0
	if not drift_enabled:
		# Non-drift levels keep A/D and move_left/move_right as focus aliases
		# (unchanged behavior).
		if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
			direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
			direction += 1.0
	# Mobile focus nudge buttons feed the same continuous adjustment path.
	if TouchInput.is_mobile():
		direction = clampf(direction + TouchInput.focus_direction, -1.0, 1.0)
	if direction == 0.0:
		return
	if not allow_focus_input:
		if focus_missing_feedback_cooldown <= 0.0:
			focus_missing_feedback_cooldown = 0.7
			feedback_label.text = GameManager.text("Focus knob required. Install it at the Assembly Table.", "需要调焦旋钮。请先在组装台安装。")
			InteractionFeedback.error(focus_state_label if focus_state_label != null else feedback_label)
		return
	_set_focus_value(clampf(focus_value + direction * FOCUS_ADJUST_SPEED * delta, 0.0, 1.0))


func _advance_drift(delta: float) -> void:
	# The sky turns; drift_offset accumulates the apparent motion. Q/E stay
	# focus-only on drift levels (see _handle_focus_input) - WASD / arrow
	# keys become the centering correction instead.
	var magnification := float(GameManager.calculate_stats().get("magnification", 0.0))
	var mag_factor := magnification / 35.0 if magnification > 0.0 else 1.0
	var tracking_cancel := 0.0
	if GameManager.has_tracking_mount_equipped():
		tracking_cancel = GameManager.tracking_rate()
	var drift_speed := DRIFT_SPEED_BASE * mag_factor * (1.0 - tracking_cancel)
	drift_offset += drift_direction * drift_speed * delta

	var correction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		correction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		correction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_up"):
		correction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_down"):
		correction.y += 1.0
	# Mobile: the virtual joystick doubles as the drift-correction stick.
	if correction == Vector2.ZERO:
		correction = TouchInput.move_vector()
	if correction != Vector2.ZERO:
		drift_offset -= correction.normalized() * DRIFT_CORRECTION_SPEED * delta

	# Past 300px the target is long lost (off-view Failed hits at 250) -
	# clamping keeps the sprite within the ring occluder's 900px cover and
	# spares the player an endless walk back.
	if drift_offset.length() > 300.0:
		drift_offset = drift_offset.normalized() * 300.0

	_apply_drift_offset()
	_advance_hold(delta)
	_refresh_drift_ui()

	if cloud_cover_level <= 0.0:
		# Cloud levels already re-evaluate on their own 0.6s timer; drift-only
		# levels need their own re-evaluate cadence so target_off_center /
		# hold-gated quality stays current without spamming every frame.
		drift_reevaluate_timer += delta
		if drift_reevaluate_timer >= 0.3:
			drift_reevaluate_timer = 0.0
			observation = _evaluate()
			_refresh_focus_ui()


func _apply_drift_offset() -> void:
	# Target and star field move together - "the sky is turning", not the
	# telescope. target_center just gets the new offset baked in directly;
	# the existing _advance_visual_smoothing() exponential chase (E1) is what
	# turns this into smooth on-screen motion, same as every other visual
	# target change - no separate drift-specific smoothing needed.
	target_off_center = drift_offset.length() > DRIFT_OUT_OF_VIEW
	if star_layer_container != null:
		star_layer_container.position = drift_offset
	var effect := str(observation.get("visual_effect", "clear"))
	var quality := str(observation.get("quality", "Unknown"))
	target_center = lens_center + _effect_offset(effect, quality) + drift_offset


func _advance_hold(delta: float) -> void:
	if hold_seconds_required <= 0.0:
		return
	if drift_offset.length() < DRIFT_HOLD_RADIUS:
		hold_timer = minf(hold_timer + delta, hold_seconds_required)
	elif hold_strict:
		# L24: drifting out of the hold radius actively drains progress
		# (2x delta) instead of just pausing.
		hold_timer = maxf(hold_timer - delta * 2.0, 0.0)
	# Loose mode (default): pauses outside the radius, does not reset.


func is_hold_satisfied() -> bool:
	if hold_seconds_required <= 0.0:
		return true
	return hold_timer >= hold_seconds_required


func _hold_progress_text() -> String:
	return GameManager.text(
		"Hold it steady a little longer: %.1f / %.1fs" % [hold_timer, hold_seconds_required],
		"再稳住 %.1f / %.1f 秒" % [hold_timer, hold_seconds_required]
	)


func _advance_dark_adaptation(delta: float) -> void:
	var moving := false
	if dark_adaptation < 1.0:
		dark_adaptation = clampf(dark_adaptation + delta / DARK_ADAPTATION_SECONDS, 0.0, 1.0)
		moving = true
	var shift_pressed := Input.is_key_pressed(KEY_SHIFT)
	if shift_pressed != averted_vision_active:
		averted_vision_active = shift_pressed
		moving = true
	if moving:
		var eased := _eased_dark_adaptation()
		for star_rect in star_layer_nodes:
			star_rect.modulate.a = lerpf(1.0, 0.55, eased)
		if dark_adaptation_label != null:
			dark_adaptation_label.text = GameManager.text(
				"Dark adaptation: %d%%",
				"暗适应：%d%%"
			) % int(round(eased * 100.0))
		if averted_vision_label != null:
			averted_vision_label.text = GameManager.text("Averted vision: Active", "侧视：启用") if averted_vision_active else GameManager.text("Averted vision: Inactive", "侧视：未启用")
			averted_vision_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62) if averted_vision_active else Color(0.66, 0.72, 0.80))
		_update_target_visuals()


func _update_averted_vision_guide(delta: float) -> void:
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	if not bool(requirements.get("require_averted_vision", false)):
		return
	averted_hold_visual = move_toward(averted_hold_visual, 1.0 if averted_vision_active else 0.0, delta * (1.8 if averted_vision_active else 2.8))
	if averted_vision_guide != null:
		averted_vision_guide.enabled = true
		averted_vision_guide.active = averted_vision_active
		averted_vision_guide.adaptation = _eased_dark_adaptation()
		averted_vision_guide.hold_visual = averted_hold_visual
		averted_vision_guide.target_position = visual_target_center
		averted_vision_guide.queue_redraw()


func _eased_dark_adaptation() -> float:
	# Non-linear ease: adaptation feels slow to start, then catches up
	# (spec: ease(dark_adaptation, 0.6)).
	return pow(dark_adaptation, 0.6)


func _dark_adaptation_alpha_bonus() -> float:
	if not _is_dark_adaptation_target():
		return 0.0
	var bonus := DARK_ADAPTATION_ALPHA_BONUS * _eased_dark_adaptation()
	if averted_vision_active:
		# Averted vision (spec): contour boost via alpha, not a flat add-on.
		bonus += AVERTED_VISION_ALPHA_BONUS
	return bonus


func _advance_visual_smoothing(delta: float) -> void:
	# Exponential chase toward the current targets - frame-rate independent.
	var weight := 1.0 - exp(-10.0 * delta)
	var target_blur := _target_blur_weight()
	var moving := false
	# SHARPNESS (focus_error + blur_weight) follows focus DIRECTLY, no lag.
	# focus_error is already a continuous, finely-quantized input (slider
	# step 0.005); smoothing it only added a lag that read as "blurry while
	# dragging, sharp once you release" regardless of the actual focus. Only
	# the quality-driven quantities below (position offset, brightness tier)
	# still ease, since those DO step discretely between quality tiers.
	if visual_focus_error != focus_error:
		visual_focus_error = focus_error
		moving = true
	if blur_weight != target_blur:
		blur_weight = target_blur
		moving = true
	if visual_target_center.distance_to(target_center) > 0.25:
		visual_target_center = visual_target_center.lerp(target_center, weight)
		moving = true
	elif visual_target_center != target_center:
		visual_target_center = target_center
		moving = true
	if absf(visual_base_alpha - base_alpha) > 0.004:
		visual_base_alpha = lerpf(visual_base_alpha, base_alpha, weight)
		moving = true
	elif visual_base_alpha != base_alpha:
		visual_base_alpha = base_alpha
		moving = true
	if moving:
		_update_target_visuals()


func _target_blur_weight() -> float:
	# 0 = fully sharp art, 1 = fully blurry photo. This is deliberately
	# driven by focus only: a faint Fair-quality nebula can still be in focus.
	# Telescope quality affects brightness and contrast elsewhere, never which
	# focus texture is visible.
	if blur_overlay == null:
		return 0.0
	# Keep the success tolerance forgiving, but do not make that whole range
	# visually identical. The image now improves continuously all the way to
	# the true focal plane; at the edge of the accepted zone a small residual
	# blur remains, while exact focus is fully sharp.
	if focus_error <= focus_tolerance:
		return smoothstep(0.0, focus_tolerance, focus_error) * 0.22
	return 0.22 + smoothstep(focus_tolerance, focus_tolerance * 2.8, focus_error) * 0.78


func _advance_conditions(delta: float) -> void:
	# Conditions snapshot: chase targets exponentially, same pattern as
	# _advance_visual_smoothing, so nothing ever hard-cuts.
	var weight := 1.0 - exp(-6.0 * delta)
	var t := Time.get_ticks_msec() / 1000.0
	var moving := false
	var target_turb := _target_turbulence()
	if absf(cond_turbulence - target_turb) > 0.002:
		cond_turbulence = lerpf(cond_turbulence, target_turb, weight)
		moving = true
	elif cond_turbulence != target_turb:
		cond_turbulence = target_turb
		moving = true
	var target_lift := _target_sky_lift()
	if absf(cond_sky_lift - target_lift) > 0.002:
		cond_sky_lift = lerpf(cond_sky_lift, target_lift, weight)
		moving = true
	elif cond_sky_lift != target_lift:
		cond_sky_lift = target_lift
		moving = true
	_advance_clouds(delta)
	if absf(cond_cloud_atten - _cloud_target_atten()) > 0.002:
		cond_cloud_atten = lerpf(cond_cloud_atten, _cloud_target_atten(), weight)
		moving = true
	if cloud_veil != null:
		# Dark absorption veil: the thicker the cloud over the target, the
		# darker the whole field. Attenuation stays the score's source of truth.
		cloud_veil.modulate.a = clampf(cond_cloud_atten * 0.50 + cloud_cover_level * 0.10, 0.0, 0.62)
	if absf(grain_intensity - target_grain_intensity) > 0.001:
		grain_intensity = lerpf(grain_intensity, target_grain_intensity, weight)
		if grain_material != null:
			grain_material.set_shader_parameter("intensity", grain_intensity)
	if moving:
		_apply_turbulence_uniforms()
		_apply_breathing_and_jitter(t)
		_apply_star_twinkle(t)
	elif cond_turbulence > 0.001:
		# Even when converged, the low-frequency breathing/jitter/twinkle
		# keeps animating every frame (that IS the effect).
		_apply_breathing_and_jitter(t)
		_apply_star_twinkle(t)
	if cloud_cover_level > 0.0:
		cloud_reevaluate_timer += delta
		if cloud_reevaluate_timer >= 0.6:
			cloud_reevaluate_timer = 0.0
			observation = _evaluate()
			_refresh_target_sprite()
			# Full focus-panel refresh (quality label included): on cloudy
			# DRIFT levels this is the only steady refresh path - the 0.3s
			# drift cadence is gated to cloudless levels - so without it the
			# hold/ready status under the focus slider only updated while a
			# focus key was held.
			_refresh_focus_ui()


func _apply_turbulence_uniforms() -> void:
	if turbulence_material_main != null:
		turbulence_material_main.set_shader_parameter("turbulence", cond_turbulence)
	if turbulence_material_blur != null:
		turbulence_material_blur.set_shader_parameter("turbulence", cond_turbulence)
	if turbulence_material_ghost != null:
		turbulence_material_ghost.set_shader_parameter("turbulence", cond_turbulence)


func _apply_breathing_and_jitter(t: float) -> void:
	if cond_turbulence <= 0.001 or main_sprite == null:
		return
	var cloud_mult := _cloud_alpha_multiplier()
	if _is_star_target():
		# Stars: flicker via alpha, tiny position jitter, no UV shader.
		var flicker := 0.875 + 0.125 * sin(t * (2.2 + cond_turbulence * 3.0) + effect_seed)
		main_sprite.modulate.a = visual_base_alpha * flicker * cloud_mult
		var jitter := Vector2(
			sin(t * 3.7 + effect_seed) * cond_turbulence * 2.5,
			cos(t * 2.9 + effect_seed * 1.3) * cond_turbulence * 2.5
		)
		main_sprite.position = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
	elif _is_diffuse_target():
		# Nebula/galaxy: low-frequency contrast + blur breathing and a tiny
		# image wander. Extended targets should not ripple like planets, but
		# average/poor seeing must still be visibly different from still air.
		# Keep the focus cross-fade intact here. Previously this branch restored
		# the clear base art to full opacity every frame, so a defocused nebula
		# could look sharp as soon as the focus input stopped moving.
		var breathe := 1.0 + 0.05 * cond_turbulence * sin(t * 1.1 + effect_seed)
		var diffuse_alpha := clampf(visual_base_alpha * breathe * cloud_mult, 0.0, 1.0)
		var seeing_blur := cond_turbulence * 0.16 * (0.5 + 0.5 * sin(t * 1.35 + effect_seed * 0.8))
		var combined_blur := clampf(blur_weight + seeing_blur, 0.0, 1.0)
		var jitter := Vector2(
			sin(t * 1.7 + effect_seed) * cond_turbulence * 1.8,
			cos(t * 1.3 + effect_seed * 0.6) * cond_turbulence * 1.2
		)
		main_sprite.position = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
		if blur_overlay != null:
			blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5 + jitter
			main_sprite.modulate.a = diffuse_alpha * (1.0 - combined_blur)
			blur_overlay.modulate.a = diffuse_alpha * combined_blur
		else:
			main_sprite.modulate.a = diffuse_alpha
	else:
		# Planet/Moon: shader-driven UV wobble + breathing blur + jitter.
		var breathing := cond_turbulence * 0.18 * (0.5 + 0.5 * sin(t * 1.3 + effect_seed))
		var jitter_scale: float = cond_turbulence * (1.2 if str(selected_object.get("id", "")) == "moon" else 2.5)
		var jitter := Vector2(
			sin(t * 2.6 + effect_seed) * jitter_scale,
			cos(t * 1.9 + effect_seed * 0.7) * jitter_scale * 0.6
		)
		var origin: Vector2 = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
		main_sprite.position = origin
		if blur_overlay != null:
			blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5 + jitter
			blur_overlay.modulate.a = visual_base_alpha * clampf(blur_weight + breathing, 0.0, 1.0) * cloud_mult
			main_sprite.modulate.a = visual_base_alpha * (1.0 - clampf(blur_weight + breathing, 0.0, 1.0) * 0.85) * cloud_mult


func _apply_star_twinkle(t: float) -> void:
	# Background scope stars twinkle a little too, scaled by seeing severity.
	var severity := _seeing_severity()
	var base_a := lerpf(1.0, 0.55, _eased_dark_adaptation())
	for i in range(star_layer_nodes.size()):
		var star_rect := star_layer_nodes[i]
		var twinkle := 1.0 + 0.18 * severity * sin(t * (1.5 + fmod(float(i), 5.0) * 0.3) + float(i))
		star_rect.modulate.a = clampf(base_a * twinkle, 0.0, 1.0)


func _cloud_target_atten() -> float:
	# Weighted overlap of the (invisible) drifting cloud trackers over the
	# target center - strength comes from cloud_strengths, since the nodes
	# themselves are hidden (only the full-field veil is visible).
	if cloud_nodes.is_empty():
		return 0.0
	var total := 0.0
	for i in range(cloud_nodes.size()):
		var cloud := cloud_nodes[i]
		var cloud_center: Vector2 = cloud.position + cloud.size * 0.5
		var d := cloud_center.distance_to(target_center)
		var falloff := clampf(1.0 - d / 170.0, 0.0, 1.0)
		total += falloff * cloud_strengths[i]
	return clampf(total, 0.0, 1.0)


func _advance_clouds(delta: float) -> void:
	if cloud_nodes.is_empty():
		return
	for i in range(cloud_nodes.size()):
		var cloud := cloud_nodes[i]
		cloud.position += cloud_velocities[i] * delta
		# Recycle once fully outside the scope circle (diameter ~436, radius
		# 218 around lens_center) - re-enter from the opposite side.
		var c := cloud.position + cloud.size * 0.5
		if c.distance_to(lens_center) > 340.0:
			var angle: float = atan2(cloud_velocities[i].y, cloud_velocities[i].x) + PI
			cloud.position = lens_center + Vector2(cos(angle), sin(angle)) * 260.0 - cloud.size * 0.5


func _init_focus() -> void:
	var stage := GameManager.current_equipment_stage()
	var id := str(selected_object.get("id", ""))
	var eyepiece_id := GameManager.equipped_part_id("eyepiece")
	# Deterministic per target + stage + eyepiece: same level always needs
	# the same focus, but swapping the eyepiece shifts the focal plane and
	# forces a real re-focus.
	target_focus_value = 0.35 + fmod(float(absi((id + stage + eyepiece_id).hash())), 300.0) / 1000.0
	# Quantize to the slider grid so dragging can land EXACTLY on target.
	target_focus_value = snappedf(target_focus_value, 0.005)
	focus_tolerance = _tolerance_for(selected_object)
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	focus_tolerance *= float(requirements.get("focus_multiplier", 1.0))
	focus_value = 0.5
	if absf(focus_value - target_focus_value) < 0.12:
		# Always start visibly out of focus so the player learns the knob.
		focus_value = fmod(focus_value + 0.27, 1.0)
	focus_error = absf(focus_value - target_focus_value)
	best_focus_error = focus_error
	focus_adjustment_count = 0
	focus_direction_changes = 0
	last_focus_adjust_direction = 0
	last_focus_improvement_adjustment = 0
	focus_guide_active = false
	if not allow_focus_input:
		# No focus knob installed: the image stays clearly defocused.
		focus_error = maxf(focus_error, 0.25)


func _tolerance_for(obj: Dictionary) -> float:
	var object_type := str(obj.get("type_en", "")).to_lower()
	var id := str(obj.get("id", ""))
	if id == "moon":
		return 0.08
	if object_type.contains("planet"):
		return 0.05
	if object_type.contains("nebula") or object_type.contains("galaxy"):
		return 0.07
	return 0.06


func _evaluate() -> Dictionary:
	if _is_constellation_observation():
		return {
			"quality": "Good",
			"success": true,
			"visual_effect": "clear",
			"feedback_en": "The full star pattern is clear enough to identify.",
			"feedback_zh": "完整星群图形足够清晰，可以识别。",
			"observation_mode": "constellation",
			"seeing_label": "Good",
			"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}
		}
	var context := {"observation_mode": observation_mode}
	context["observation_requirements"] = GameManager.current_level().get("observation_requirements", {})
	context["exposure"] = exposure_value
	context["filter"] = active_filter
	context["dark_adaptation"] = dark_adaptation
	context["averted_vision"] = averted_vision_active
	context["tracking_rate"] = GameManager.tracking_rate()
	context["observation_elapsed"] = observation_elapsed
	if requires_focus:
		context["focus_error"] = focus_error
		context["requires_focus"] = true
		context["focus_tolerance"] = focus_tolerance
	if cloud_cover_level > 0.0:
		# Real-time cloud attenuation: as clouds drift across the target the
		# instantaneous darkening feeds back into the actual quality math
		# (observation_system uses this key when present; the static
		# cloud_cover formula stays untouched for callers that don't pass it,
		# e.g. flow_test's direct evaluate() calls).
		context["cloud_attenuation"] = cond_cloud_atten
	if drift_enabled and target_off_center:
		# E2: drifted out of the eyepiece entirely - hard Failed. Only this
		# live telescope_view loop ever sets this key; GameManager's own
		# evaluate_selected_object() call (used by flow_test) never passes
		# it, so the 24-level numeric regression path is unaffected.
		context["target_off_center"] = true
	return GameManager.evaluate_selected_object(context)


func _focus_state() -> String:
	# Focus state depends ONLY on focus_error vs tolerance - never on the
	# overall observation quality. Inside tolerance is always "sharp".
	if is_focus_acceptable():
		return "sharp"
	if focus_error <= focus_tolerance * 1.75:
		return "slightly_blurry"
	if focus_error <= focus_tolerance * 3.0:
		return "blurry"
	return "very_blurry"


# Single source of truth for "can this observation be identified".
# Selection + centering are enforced by Sky Observation before entering
# this scene; here the remaining gates are focus and overall quality.


func is_focus_acceptable() -> bool:
	if not requires_focus:
		return true
	if not allow_focus_input:
		return false
	return focus_error <= focus_tolerance


func is_quality_acceptable() -> bool:
	return bool(observation.get("success", false))


func can_identify_object() -> bool:
	return is_focus_acceptable() and is_quality_acceptable() and _missing_required_parts().is_empty() and is_hold_satisfied()


# Checks whether the CURRENTLY equipped part satisfies the level's next
# pending mission step (e.g. L10: step 1 needs the 20mm, step 2 the 10mm),
# and if the observation itself is good enough, marks that step done.
# Only advances forward - never un-marks a step that was already completed.
func _check_mission_step_progress() -> void:
	if not is_focus_acceptable() or not is_quality_acceptable():
		return
	# ORDER-INDEPENDENT: the lesson is comparing magnifications, not doing
	# them in declared order - a player who equipped the 10mm first must get
	# credit for that observation too. Any pending step whose required part
	# is currently equipped completes.
	var done := GameManager.completed_mission_steps()
	for step_value in GameManager.mission_steps():
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var step_id := str(step.get("id", ""))
		if step_id == "" or done.has(step_id):
			continue
		var require_part_id := str(step.get("require_part_id", ""))
		if require_part_id == "":
			continue
		var part := GameManager.get_part(require_part_id)
		var part_type := str(part.get("type", ""))
		if part_type == "" or GameManager.equipped_part_id(part_type) != require_part_id:
			continue
		GameManager.mark_mission_step_done(step_id)
		_announce_step_complete(step)


func _announce_step_complete(step: Dictionary) -> void:
	# Positive milestone feedback the moment a step lands - the player must
	# never have to deduce progress from the tiny Step x/y header alone.
	if feedback_label == null:
		return
	var step_label := GameManager.dict_text(step, "label").replace("\n", " ")
	var next_step := GameManager.next_pending_mission_step()
	if next_step.is_empty():
		feedback_label.text = GameManager.text(
			"Step complete: %s. All steps done - identify the target!" % step_label,
			"✓ 步骤完成：%s。全部步骤已完成——识别目标吧！" % step_label
		)
	else:
		var next_label := GameManager.dict_text(next_step, "label").replace("\n", " ")
		feedback_label.text = GameManager.text(
			"Step complete: %s. Next: %s" % [step_label, next_label],
			"✓ 步骤完成：%s。下一步：%s" % [step_label, next_label]
		)
	feedback_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))


func _pending_step_label() -> String:
	var step := GameManager.next_pending_mission_step()
	if step.is_empty():
		return ""
	return GameManager.dict_text(step, "label")


func _mission_step_progress_text() -> String:
	var steps := GameManager.mission_steps()
	if steps.is_empty():
		return ""
	var done := GameManager.completed_mission_steps().size()
	var total := steps.size()
	var label := _pending_step_label()
	if label == "":
		return "Step %d/%d: %s" % [total, total, GameManager.text("All steps complete", "全部步骤已完成")]
	return "Step %d/%d: %s" % [mini(done + 1, total), total, label]


func _missing_required_parts() -> Array[String]:
	var missing: Array[String] = GameManager.missing_required_parts()
	return missing


func _missing_required_parts_text() -> String:
	var missing := _missing_required_parts()
	var names_en: Array[String] = []
	var names_zh: Array[String] = []
	for part_id in missing:
		var part := GameManager.get_part(part_id)
		names_en.append(str(part.get("name_en", part_id)))
		names_zh.append(str(part.get("name_zh", part_id)))
	return GameManager.text(
		"This mission requires: " + ", ".join(names_en) + ". Equip it at the Parts Cabinet and reassemble.",
		"本次任务需要：" + "、".join(names_zh) + "。请到零件柜换装并重新组装。"
	)


func _quality_shortfall_text() -> String:
	var technique_failure: Dictionary = observation.get("technique_failure", {})
	if not technique_failure.is_empty():
		return GameManager.text(
			str(technique_failure.get("en", "Complete the observing method shown below.")),
			str(technique_failure.get("zh", "请完成下方标出的观测方法。"))
		)
	# Focus is fine - name the REAL limiting factor so the player never
	# blames the wrong thing (audit: story must match the mechanic).
	# Priority: focus (already excluded by caller) > collimation > cloud >
	# seeing > sky brightness > aperture/stability.
	if _collimation_severity() > 0.28:
		return GameManager.text(
			"Focused. Comet tail = coma. Collimate.",
			"已对焦。彗尾就是彗差；请准直。"
		)
	if cond_cloud_atten > 0.35:
		return GameManager.text(
			"Clouds are crossing the target. Wait for a gap.",
			"云层正在遮挡目标。等云隙再观测。"
		)
	if str(observation.get("seeing_label", "Good")) != "Good":
		return GameManager.text(
			"Focus is fine - the air itself is unsteady. Lower the magnification.",
			"焦点没问题——是大气在抖动。降低倍率试试。"
		)
	var ratios: Dictionary = observation.get("ratios", {})
	var light_ratio := float(ratios.get("light", 1.0))
	var clarity_ratio := float(ratios.get("clarity", 1.0))
	var stability_ratio := float(ratios.get("stability", 1.0))
	var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
	if sky_key == "city" and light_ratio <= clarity_ratio and light_ratio <= stability_ratio:
		return GameManager.text(
			"City sky-glow is drowning the faint light. A darker site or bigger aperture would help.",
			"城市光污染淹没了微弱的光。更暗的观测点或更大口径会有帮助。"
		)
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	if type_lower.contains("nebula") or type_lower.contains("galaxy"):
		return GameManager.text(
			"Focus aligned, but deep-sky image is still too faint. Improve aperture/stability.",
			"焦点已对准，但深空图像仍太暗。需要更大口径或更高稳定性。"
		)
	return GameManager.text(
		"Focus aligned, but telescope quality is still too low.",
		"焦点已对准，但望远镜性能仍不足。"
	)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	quiz_brief_overlay = null
	focus_knob_status = null
	tracking_knob_status = null
	tracking_enabled_status = null
	stat_bar_fills.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(self, Vector2.ZERO, Vector2(1024, 768), COL_BG)
	_pixel_frame(self, Vector2(12, 10), Vector2(1000, 744), Color(0.006, 0.008, 0.018), COL_BLUE_BORDER, COL_GOLD)

	var view := _scope_visual()
	view.position = Vector2(54, 98)
	add_child(view)
	# Wood frame AFTER the scope view: the ring occluder's clip container
	# reaches the screen edges and would repaint over the frame strips.
	_add_wood_frame()
	# Title bar AFTER the scope view: the ring occluder inside the view is
	# oversized and would otherwise paint over the title strip.
	if observation_mode == "naked_eye":
		_title_bar(GameManager.text("Naked Eye Observation", "肉眼观测"))
	elif _is_constellation_observation():
		_title_bar(GameManager.text("Constellation Field", "星座星域"))
	else:
		_title_bar(GameManager.text("Telescope View", "望远镜视野"))
	_build_observation_panel()
	if _uses_observation_method(GameManager.current_level().get("observation_requirements", {})):
		_build_technique_panel()
	if drift_enabled:
		_build_drift_panel()
	if requires_focus and allow_focus_input:
		_build_focus_novice_guide()
	if requires_focus:
		_refresh_focus_ui()
	if TouchInput.is_mobile():
		_build_mobile_view_controls()


func _build_mobile_view_controls() -> void:
	TouchInput.focus_direction = 0.0
	# Drift levels reuse the virtual joystick as the centering stick.
	if drift_enabled:
		var overlay: Control = preload("res://scripts/ui/mobile_controls.gd").new()
		add_child(overlay)
	# Focus nudge buttons (Q/E equivalent) beside the drift panel, clear of
	# the observation panel and identify buttons.
	if requires_focus and allow_focus_input:
		for spec in [["−", -1.0, Vector2(624, 690)], ["＋", 1.0, Vector2(684, 690)]]:
			var nudge := Button.new()
			nudge.text = str(spec[0])
			nudge.position = spec[2]
			nudge.size = Vector2(52, 52)
			nudge.focus_mode = Control.FOCUS_NONE
			nudge.add_theme_font_size_override("font_size", 22)
			nudge.z_index = 90
			var nudge_direction: float = float(spec[1])
			nudge.button_down.connect(func() -> void: TouchInput.focus_direction = nudge_direction)
			nudge.button_up.connect(func() -> void: TouchInput.focus_direction = 0.0)
			add_child(nudge)
	call_deferred("_animate_stat_bars")


const SKY_BG_TEXTURE := "res://assets/reference/sky_observation_ui_bg_v2_1024.png"
const COL_BRASS := Color(0.72, 0.53, 0.26)


func _add_wood_frame() -> void:
	# Reuses the finder view's baked wooden frame (edge strips via
	# AtlasTexture regions - no new art). The top strip is the bottom strip
	# flipped, because the baked top edge carries the compass ornament.
	var base := load(SKY_BG_TEXTURE) as Texture2D
	if base == null:
		return
	# Only the LEFT column and the left 748px of the bottom edge are pure
	# wood in the baked art (the rest carries panel borders), so the frame
	# is built from those clean regions: bottom stretched full-width, top =
	# bottom flipped, right = left mirrored.
	var strips := [
		[Rect2(0, 734, 748, 34), Rect2(0, 734, 1024, 34), false, false],
		[Rect2(0, 734, 748, 34), Rect2(0, 0, 1024, 34), true, false],
		[Rect2(0, 0, 34, 768), Rect2(0, 0, 34, 768), false, false],
		[Rect2(0, 0, 34, 768), Rect2(990, 0, 34, 768), false, true],
	]
	for strip_value in strips:
		var atlas := AtlasTexture.new()
		atlas.atlas = base
		atlas.region = strip_value[0]
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2.ZERO
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.flip_v = bool(strip_value[2])
		rect.flip_h = bool(strip_value[3])
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.texture = atlas
		rect.position = (strip_value[1] as Rect2).position
		rect.size = (strip_value[1] as Rect2).size
		add_child(rect)


func _title_bar(title_text: String) -> void:
	# Brass plaque, matching the finder view's ornament styling.
	var plaque := Panel.new()
	plaque.position = Vector2(312, 16)
	plaque.size = Vector2(400, 54)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.075, 0.038, 0.97)
	style.border_color = COL_BRASS
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	plaque.add_theme_stylebox_override("panel", style)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plaque)
	var title := _plabel(title_text, Vector2(312, 22), Vector2(400, 42), 25, Color(0.96, 0.86, 0.58), HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF


# ------------------------------------------------------------- right panel


func _build_observation_panel() -> void:
	_gold_panel(self, PANEL_POS, PANEL_SIZE)
	var quality := str(observation.get("quality", "Unknown"))

	var header := _plabel(GameManager.text("Observation Quality", "观测质量"), Vector2(CONTENT_X - 4, 118), Vector2(CONTENT_W + 8, 30), 19, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF

	var mystery := _mystery_description(selected_object)
	var observed := _plabel(
		GameManager.text("Observed: " + str(mystery.get("en", "")), "观测到：" + str(mystery.get("zh", ""))),
		Vector2(CONTENT_X, 162), Vector2(CONTENT_W, 32), 10, COL_TEXT
	)
	observed.max_lines_visible = 2

	quality_label = _plabel(GameManager.text("Quality: ", "质量: ") + quality, Vector2(CONTENT_X, 198), Vector2(CONTENT_W, 22), 15, _quality_color(quality))

	var feedback_y := 320.0
	if observation_mode == "naked_eye":
		_plabel(GameManager.text("Equipment: Naked Eye", "装备：肉眼"), Vector2(CONTENT_X, 232), Vector2(CONTENT_W, 40), 13, COL_GOLD_LIGHT)
	else:
		_add_stat_bars()
		var rows_end := _add_condition_rows()
		# 4 slots max (283/295/307/319); once slot 4 is used, feedback must
		# shift down from 320 to 332 and shrink to a single line to still
		# fit above the Focus block at y=348.
		if rows_end > CONDITION_ROW_Y + CONDITION_ROW_H * 3.0 + 0.5:
			feedback_y = 332.0

	if not GameManager.mission_steps().is_empty():
		# L10-style step checklist: squeezed onto the header row's right
		# side so it costs no extra vertical space (only levels with
		# mission_steps show it; currently just L10).
		mission_step_label = _plabel(_mission_step_progress_text(), Vector2(CONTENT_X - 4, 148), Vector2(CONTENT_W + 8, 12), 8, Color(0.70, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		mission_step_label.max_lines_visible = 1
		mission_step_label.clip_text = true

	var feedback_h := 26.0 if feedback_y <= 320.0 else 14.0
	feedback_label = _plabel(_current_feedback(), Vector2(CONTENT_X, feedback_y), Vector2(CONTENT_W, feedback_h), 9, Color(0.86, 0.90, 0.88))
	feedback_label.max_lines_visible = 1 if feedback_y > 320.0 else 2

	if requires_focus:
		_build_focus_block()

	if is_free_observation:
		_build_free_observation_panel()
		return

	identify_title_label = _plabel(GameManager.text("Identify", "识别"), Vector2(CONTENT_X, 414), Vector2(CONTENT_W, 20), 16, Color(0.98, 0.82, 0.50))

	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(CONTENT_X, 436)
	choices_box.size = Vector2(CONTENT_W, 146)
	choices_box.add_theme_constant_override("separation", 6)
	add_child(choices_box)
	_add_identify_choices()

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(CONTENT_X, 600)
	bottom.size = Vector2(CONTENT_W, 38)
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)

	var retry := _pixel_button(GameManager.text("Retry", "重试"), Vector2(92, 38), 14)
	retry.pressed.connect(func() -> void: GameManager.go("sky"))
	bottom.add_child(retry)

	var back := _pixel_button(GameManager.text("Back", "返回"), Vector2(92, 38), 14)
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	bottom.add_child(back)
	_add_change_equipment_button()

	if quiz_brief_dismissed:
		_set_identify_choices_visible(true)
	else:
		_show_pre_quiz_guide()


func _build_free_observation_panel() -> void:
	# Non-mission target: no identify quiz. The player can log the result, return
	# directly to the mission target, or leave for the wider sky view.
	identify_title_label = _plabel(GameManager.text("Free Observation", "自由观测"), Vector2(CONTENT_X, 414), Vector2(CONTENT_W, 22), 17, Color(0.42, 0.82, 1.0))
	var name_line := GameManager.dict_text(selected_object, "name")
	_plabel(name_line + "  ·  " + GameManager.dict_text(selected_object, "type"), Vector2(CONTENT_X, 440), Vector2(CONTENT_W, 20), 13, COL_TEXT)
	var q := str(observation.get("quality", "Good"))
	_plabel(GameManager.text("Quality: ", "观测质量：") + q, Vector2(CONTENT_X, 466), Vector2(CONTENT_W, 20), 13, COL_GOLD_LIGHT)
	var learn := _plabel(GameManager.dict_text(selected_object, "learning_text") if selected_object.has("learning_text_en") else GameManager.dict_text(selected_object, "short_hint"), Vector2(CONTENT_X, 492), Vector2(CONTENT_W, 54), 12, Color(0.82, 0.88, 0.92))
	learn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learn.max_lines_visible = 3
	free_result_label = _plabel("", Vector2(CONTENT_X, 548), Vector2(CONTENT_W, 18), 11, Color(0.55, 1.0, 0.68))

	var mission_id := GameManager.current_target_object_id()
	var mission_object: Dictionary = GameManager.get_object(mission_id)
	var mission_name := GameManager.dict_text(mission_object, "name")
	var mission_button := _pixel_button(GameManager.text("Return to Mission", "返回任务目标"), Vector2(CONTENT_W, 34), 12)
	mission_button.name = "FreeObservationMissionButton"
	mission_button.position = Vector2(CONTENT_X, 572)
	mission_button.tooltip_text = GameManager.text(
		"Continue observing %s without leaving the telescope view." % mission_name,
		"不退出望远镜界面，继续观测任务目标%s。" % mission_name
	)
	mission_button.disabled = mission_id == "" or mission_object.is_empty()
	mission_button.pressed.connect(_return_to_mission_target)
	add_child(mission_button)

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(CONTENT_X, 614)
	bottom.size = Vector2(CONTENT_W, 34)
	var button_gap := 8.0
	var button_width := (CONTENT_W - button_gap) * 0.5
	bottom.add_theme_constant_override("separation", int(button_gap))
	add_child(bottom)
	var log_btn := _pixel_button(GameManager.text("Add to Logbook", "加入日志"), Vector2(button_width, 34), 11)
	log_btn.name = "FreeObservationLogButton"
	log_btn.tooltip_text = GameManager.text("Record this observation in the Club Logbook.", "将本次观测记录到俱乐部日志。")
	log_btn.pressed.connect(_add_free_observation_to_logbook)
	bottom.add_child(log_btn)
	var back := _pixel_button(GameManager.text("Back to Sky", "返回星图"), Vector2(button_width, 34), 11)
	back.name = "FreeObservationBackButton"
	back.pressed.connect(func() -> void: GameManager.go("sky"))
	bottom.add_child(back)
	_add_change_equipment_button(656.0, 30.0)


func _add_change_equipment_button(y := 650.0, height := 34.0) -> void:
	if observation_mode == "naked_eye":
		return
	var equipment := _pixel_button(GameManager.text("Change Equipment", "更换装备"), Vector2(CONTENT_W, height), 12)
	equipment.position = Vector2(CONTENT_X, y)
	equipment.tooltip_text = GameManager.text(
		"Open the Parts Cabinet. Reassemble after changing a component.",
		"打开零件柜。更换零件后需要重新组装。"
	)
	equipment.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("cabinet")
		GameManager.go("parts")
	)
	add_child(equipment)


func _return_to_mission_target() -> void:
	if mission_return_in_progress:
		return
	var mission_id := GameManager.current_target_object_id()
	var mission_object: Dictionary = GameManager.get_object(mission_id)
	if mission_id == "" or mission_object.is_empty():
		InteractionFeedback.error(free_result_label if free_result_label != null else self)
		return

	mission_return_in_progress = true
	GameManager.selected_object_id = mission_id
	GameManager.selected_object_level = int(GameManager.progress.get("current_level", 1))

	# The sky view publishes one canonical position per object. Reusing it here
	# lets the player continue immediately without a detour through the sky map.
	var sky_position: Dictionary = GameManager.current_sky_position(mission_id)
	if not sky_position.is_empty():
		var azimuth := float(sky_position.get("azimuth", NAN))
		var altitude := float(sky_position.get("altitude", NAN))
		if is_finite(azimuth) and is_finite(altitude):
			GameManager.last_sky_aim = {
				"valid": true,
				"azimuth": wrapf(azimuth, 0.0, 360.0),
				"altitude": clampf(altitude, 0.0, 90.0),
				"view_mode": observation_mode
			}

	if InteractionFeedback.is_reduced_motion():
		_activate_mission_target_in_place()
		return
	var fade_out := create_tween()
	fade_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade_out.tween_property(self, "modulate:a", 0.0, 0.10)
	fade_out.tween_callback(_activate_mission_target_in_place)


func _activate_mission_target_in_place() -> void:
	selected_object = GameManager.get_object(GameManager.current_target_object_id())
	is_free_observation = false
	observation_mode = GameManager.current_observation_mode()
	requires_focus = observation_mode == "telescope" and GameManager.current_requires_focus()
	allow_focus_input = _focus_knob_installed()
	observation_elapsed = 0.0
	dark_adaptation = 0.0
	averted_vision_active = false
	averted_hold_visual = 0.0
	identify_transition_active = false
	quiz_brief_dismissed = false
	focus_lock_feedback_played = false
	_init_drift()
	if requires_focus:
		_init_focus()
	observation = _evaluate()
	_build()
	modulate.a = 0.0 if not InteractionFeedback.is_reduced_motion() else 1.0
	mission_return_in_progress = false
	if InteractionFeedback.is_reduced_motion():
		InteractionFeedback.success(identify_title_label if identify_title_label != null else self, "mission_target_restored")
		return
	var fade_in := create_tween()
	fade_in.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_in.tween_property(self, "modulate:a", 1.0, 0.16)
	fade_in.tween_callback(func() -> void:
		InteractionFeedback.success(identify_title_label if identify_title_label != null else self, "mission_target_restored")
	)


func _add_free_observation_to_logbook() -> void:
	var result: Dictionary = GameManager.record_free_observation(str(selected_object.get("id", "")), observation)
	if free_result_label != null:
		if bool(result.get("repeat", false)):
			free_result_label.text = GameManager.text("Already logged with this setup. Change eyepiece or family for a new record.", "该设备下已记录。换目镜或望远镜类型可添加新记录。")
			free_result_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.52))
		else:
			var awarded := int(result.get("credits_awarded", 0))
			var total := int(result.get("credits_total", GameManager.progress.get("credits", 0)))
			free_result_label.text = GameManager.text(
				"New observation record added (+%d credits, total %d)." % [awarded, total],
				"已新增观测记录（+%d 积分，共 %d）。" % [awarded, total]
			)
			free_result_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
			InteractionFeedback.success(free_result_label, "free_observation_logged")


func _build_focus_block() -> void:
	if not allow_focus_input:
		_plabel(GameManager.text("Focus", "对焦"), Vector2(CONTENT_X, 348), Vector2(70, 18), 13, COL_GOLD_LIGHT)
		var missing := _plabel(GameManager.text("Knob: not installed", "旋钮：未安装"), Vector2(CONTENT_X + 60, 346), Vector2(CONTENT_W - 60, 26), 9, Color(1.0, 0.45, 0.32), HORIZONTAL_ALIGNMENT_RIGHT)
		missing.max_lines_visible = 2
		focus_state_label = _plabel(
			GameManager.text("Install it at the Assembly Table.", "请回组装台安装调焦旋钮。"),
			Vector2(CONTENT_X, 378), Vector2(CONTENT_W, 32), 9, Color(1.0, 0.62, 0.40)
		)
		focus_state_label.max_lines_visible = 3
		return

	# Equipment property, deliberately constant: the knob's mechanical
	# precision (finer slider steps at >=60), NOT a live focus readout.
	focus_knob_status = _hud_asset(OBS_UI_DIR + "focus_knob_ui.png", Rect2(Vector2(CONTENT_X, 343), Vector2(28, 28)))
	focus_knob_status.pivot_offset = focus_knob_status.size * 0.5
	focus_knob_status.rotation = lerpf(-PI * 0.72, PI * 0.72, focus_value)
	_plabel(GameManager.text("Knob precision %d%%" % int(_focus_control_score()), "旋钮精度 %d%%" % int(_focus_control_score())), Vector2(CONTENT_X + 32, 350), Vector2(94, 18), 10, COL_GOLD_LIGHT)
	focus_pct_label = _plabel("", Vector2(CONTENT_X + 126, 351), Vector2(CONTENT_W - 126, 18), 11, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	focus_slider = HSlider.new()
	focus_slider.min_value = 0.0
	focus_slider.max_value = 1.0
	# A better focus knob gives finer slider control.
	focus_slider.step = 0.005 if _focus_control_score() >= 60.0 else 0.015
	focus_slider.value = focus_value
	focus_slider.position = Vector2(CONTENT_X, 370)
	focus_slider.size = Vector2(CONTENT_W, 18)
	var clear_start := clampf(target_focus_value - focus_tolerance, 0.0, 1.0)
	var clear_end := clampf(target_focus_value + focus_tolerance, 0.0, 1.0)
	focus_guide_zone = _rect(
		self,
		Vector2(CONTENT_X + CONTENT_W * clear_start, 368),
		Vector2(maxf(4.0, CONTENT_W * (clear_end - clear_start)), 22),
		Color(0.28, 0.95, 0.48, 0.28)
	)
	focus_guide_zone.visible = false
	focus_slider.value_changed.connect(func(value: float) -> void:
		if not updating_slider:
			_set_focus_value(value)
	)
	add_child(focus_slider)

	focus_state_label = _plabel("", Vector2(CONTENT_X, 388), Vector2(CONTENT_W, 24), 9, COL_TEXT)
	focus_state_label.max_lines_visible = 2


func _set_focus_value(value: float) -> void:
	var old_value := focus_value
	var was_acceptable := is_focus_acceptable()
	focus_value = clampf(value, 0.0, 1.0)
	if focus_knob_status != null:
		InteractionFeedback.tween_rotation(focus_knob_status, lerpf(-PI * 0.72, PI * 0.72, focus_value), 0.11)
	focus_error = absf(focus_value - target_focus_value)
	_track_focus_attempt(old_value)
	observation = _evaluate()
	_refresh_focus_ui()
	if not was_acceptable and is_focus_acceptable() and not focus_lock_feedback_played:
		focus_lock_feedback_played = true
		InteractionFeedback.success(focus_slider, "focus_locked")
		if main_sprite != null:
			InteractionFeedback.pulse(main_sprite, Color(1.08, 1.06, 0.88, 1.0), 0.46)


func _track_focus_attempt(old_value: float) -> void:
	var movement := focus_value - old_value
	if absf(movement) < 0.0005:
		return
	focus_adjustment_count += 1
	var direction := 1 if movement > 0.0 else -1
	if last_focus_adjust_direction != 0 and direction != last_focus_adjust_direction:
		focus_direction_changes += 1
	last_focus_adjust_direction = direction
	if focus_error + 0.002 < best_focus_error:
		best_focus_error = focus_error
		last_focus_improvement_adjustment = focus_adjustment_count

	if is_focus_acceptable():
		focus_guide_active = false
		_update_focus_novice_guide()
		return

	var near_miss := best_focus_error <= focus_tolerance * 2.25
	var oscillating := focus_direction_changes >= 2
	var stalled := focus_adjustment_count - last_focus_improvement_adjustment >= 5
	if (focus_adjustment_count >= 6 and near_miss) \
			or (focus_adjustment_count >= 8 and oscillating) \
			or (focus_adjustment_count >= 14 and stalled):
		focus_guide_active = true
	_update_focus_novice_guide()


func _build_focus_novice_guide() -> void:
	var guide_y := 558.0 if drift_enabled else 584.0
	focus_guide_panel = _styled_panel(
		self,
		Vector2(84, guide_y), Vector2(576, 94),
		Color(0.025, 0.050, 0.085, 0.98), Color(0.35, 0.78, 1.0),
		3, 4, false, Color(0.35, 0.78, 1.0)
	)
	focus_guide_panel.z_index = 120
	var title := _plabel(GameManager.text("Focus Help", "调焦帮助"), Vector2(104, guide_y + 12), Vector2(536, 22), 16, Color(0.55, 0.88, 1.0))
	title.z_index = 121
	focus_guide_text = _plabel("", Vector2(104, guide_y + 36), Vector2(536, 46), 12, COL_TEXT)
	focus_guide_text.z_index = 121
	focus_guide_text.max_lines_visible = 3
	focus_guide_panel.visible = false
	title.visible = false
	focus_guide_text.visible = false
	focus_guide_panel.set_meta("title_label", title)
	_update_focus_novice_guide()


func _update_focus_novice_guide() -> void:
	if focus_guide_panel == null:
		return
	var show_guide := focus_guide_active and not is_focus_acceptable()
	focus_guide_panel.visible = show_guide
	var title := focus_guide_panel.get_meta("title_label") as Label
	if title != null:
		title.visible = show_guide
	if focus_guide_text != null:
		focus_guide_text.visible = show_guide
	if focus_guide_zone != null:
		focus_guide_zone.visible = show_guide
	if not show_guide:
		return
	var remaining := int(round(focus_error * 100.0))
	if focus_value < target_focus_value:
		focus_guide_text.text = GameManager.text(
			"Hold E to move right about %d%%. Stop inside the green clear zone; if the image worsens, tap Q back." % remaining,
			"按住 E 向右调约 %d%%。进入绿色清晰区就停下；如果画面变糊，轻按 Q 往回调。" % remaining
		)
	else:
		focus_guide_text.text = GameManager.text(
			"Hold Q to move left about %d%%. Stop inside the green clear zone; if the image worsens, tap E back." % remaining,
			"按住 Q 向左调约 %d%%。进入绿色清晰区就停下；如果画面变糊，轻按 E 往回调。" % remaining
		)


# --------------------------------------------------------- E2 drift / track


const DRIFT_PANEL_POS := Vector2(54, 664)
const DRIFT_PANEL_SIZE := Vector2(560, 72)
const DRIFT_ROW_H := 20.0


func _build_technique_panel() -> void:
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	var panel_pos := Vector2(54, 614)
	var panel_size := Vector2(680, 44)
	_pixel_panel(self, panel_pos, panel_size, COL_NAVY, COL_BRASS)
	_plabel(GameManager.text("METHOD", "观测方法"), panel_pos + Vector2(10, 5), Vector2(82, 16), 10, COL_GOLD_LIGHT)
	var x := panel_pos.x + 92.0
	if requirements.has("exposure_min") or requirements.has("exposure_max"):
		_plabel(GameManager.text("Exposure", "曝光"), Vector2(x, panel_pos.y + 5), Vector2(58, 14), 9, COL_TEXT)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.02
		slider.value = exposure_value
		slider.position = Vector2(x + 60, panel_pos.y + 2)
		slider.size = Vector2(118, 20)
		slider.value_changed.connect(func(value: float) -> void:
			exposure_value = value
			observation = _evaluate()
			_refresh_target_sprite()
			_refresh_technique_status()
		)
		add_child(slider)
		x += 190.0
	if requirements.has("filter"):
		technique_filter_button = _pixel_button(GameManager.text("Filter: Off", "滤镜：关闭"), Vector2(112, 26), 9)
		technique_filter_button.position = Vector2(x, panel_pos.y + 4)
		technique_filter_button.tooltip_text = GameManager.text(
			"Nebula filter: reduces part of the sky glow to improve emission-nebula contrast. Click to toggle.",
			"星云滤镜：削弱部分天空背景光，提高发射星云的对比度。点击切换。"
		)
		technique_filter_button.pressed.connect(func() -> void:
			active_filter = "nebula" if active_filter == "none" else "none"
			technique_filter_button.text = GameManager.text("Filter: Nebula", "滤镜：星云") if active_filter == "nebula" else GameManager.text("Filter: Off", "滤镜：关闭")
			observation = _evaluate()
			_refresh_target_sprite()
			_refresh_technique_status()
		)
		add_child(technique_filter_button)
		x += 122.0
	if bool(requirements.get("require_averted_vision", false)):
		var shift_hint := _plabel(
			GameManager.text("Hold SHIFT + use side marker", "按住 SHIFT，看侧视标记"),
			Vector2(x, panel_pos.y + 4), Vector2(172, 14), 9,
			Color(0.48, 0.88, 1.0)
		)
		shift_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		shift_hint.clip_text = true
		x += 178.0
	technique_status_label = _plabel("", Vector2(x, panel_pos.y + 4), Vector2(panel_pos.x + panel_size.x - x - 8, 32), 9, Color(0.74, 0.86, 0.96))
	technique_status_label.max_lines_visible = 2
	_refresh_technique_status()


func _uses_observation_method(requirements: Dictionary) -> bool:
	for key in ["exposure_min", "exposure_max", "filter", "dark_adaptation_min", "require_averted_vision", "seeing_patience"]:
		if requirements.has(key):
			return true
	return false


func _refresh_technique_status() -> void:
	if technique_status_label == null:
		return
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	var pending: Array[String] = []
	var ready: Array[String] = []
	if requirements.has("filter"):
		var required_filter := str(requirements.get("filter", "nebula"))
		if active_filter != required_filter:
			pending.append(GameManager.text("Click to enable the nebula filter", "点击开启星云滤镜"))
		else:
			ready.append(GameManager.text("Nebula filter ON", "星云滤镜：已开启"))
	if requirements.has("exposure_min") or requirements.has("exposure_max"):
		var exposure_low := float(requirements.get("exposure_min", 0.0))
		var exposure_high := float(requirements.get("exposure_max", 1.0))
		if exposure_value < exposure_low:
			pending.append(GameManager.text("Raise exposure", "提高曝光"))
		elif exposure_value > exposure_high:
			pending.append(GameManager.text("Reduce exposure", "降低曝光"))
		else:
			ready.append(GameManager.text("Exposure %d%%" % roundi(exposure_value * 100.0), "曝光：%d%%" % roundi(exposure_value * 100.0)))
	var required_adaptation := float(requirements.get("dark_adaptation_min", 0.0))
	if dark_adaptation + 0.001 < required_adaptation:
		pending.append(GameManager.text(
			"Dark adapt %d / %d%%" % [roundi(dark_adaptation * 100.0), roundi(required_adaptation * 100.0)],
			"暗适应 %d / %d%%" % [roundi(dark_adaptation * 100.0), roundi(required_adaptation * 100.0)]
		))
	elif required_adaptation > 0.0:
		ready.append(GameManager.text(
			"Dark adapted %d%%" % roundi(dark_adaptation * 100.0),
			"暗适应：%d%% 已达标" % roundi(dark_adaptation * 100.0)
		))
	if bool(requirements.get("require_averted_vision", false)):
		if not averted_vision_active:
			pending.append(GameManager.text("Averted vision: hold SHIFT, look beside target", "侧视法：按住 SHIFT，看目标旁的标记"))
		else:
			ready.append(GameManager.text("Averted vision active", "侧视法：已生效"))
	if requirements.has("seeing_patience"):
		var steady_seconds := 4.0 + float(requirements.get("seeing_patience", 0.0)) * 4.0
		if observation_elapsed + 0.001 < steady_seconds:
			pending.append(GameManager.text(
				"Hold steady %.1f / %.1fs" % [observation_elapsed, steady_seconds],
				"等待视宁度稳定 %.1f / %.1f 秒" % [observation_elapsed, steady_seconds]
			))
		else:
			ready.append(GameManager.text("Seeing window found", "已等到稳定视宁度"))
	if not pending.is_empty():
		technique_status_label.text = " · ".join(pending)
		technique_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.36))
		return
	var failure: Dictionary = observation.get("technique_failure", {})
	if not failure.is_empty():
		technique_status_label.text = GameManager.text(
			str(failure.get("en", "Complete the highlighted observing method.")),
			str(failure.get("zh", "请完成高亮显示的观测方法。"))
		)
		technique_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.36))
		return
	technique_status_label.text = " · ".join(ready)
	technique_status_label.add_theme_color_override("font_color", Color(0.48, 0.96, 0.60))


func _build_drift_panel() -> void:
	# Center Hold / tracking UI lives below the scope circle, left of the
	# right-hand observation panel - never competes with it for space.
	# Three fixed, non-wrapping rows: Drift+Track status / Hold bar / rate slider.
	var panel_h := DRIFT_PANEL_SIZE.y if GameManager.has_tracking_mount_equipped() else DRIFT_PANEL_SIZE.y - DRIFT_ROW_H
	_pixel_panel(self, DRIFT_PANEL_POS, Vector2(DRIFT_PANEL_SIZE.x, panel_h), COL_NAVY, COL_BRASS)
	var x := DRIFT_PANEL_POS.x + 12.0
	var y := DRIFT_PANEL_POS.y + 8.0

	drift_label = _plabel(_drift_status_text(), Vector2(x, y), Vector2(DRIFT_PANEL_SIZE.x - 24.0, 14), 10, Color(0.90, 0.86, 0.60))
	drift_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	drift_label.clip_text = true
	if GameManager.has_tracking_mount_equipped():
		tracking_enabled_status = _hud_asset(OBS_UI_DIR + "tracking_enabled_icon.png", Rect2(Vector2(DRIFT_PANEL_POS.x + DRIFT_PANEL_SIZE.x - 32, y - 3), Vector2(20, 20)))
	y += DRIFT_ROW_H

	if hold_seconds_required > 0.0:
		_rect(self, Vector2(x, y + 3.0), Vector2(74, 8), Color(0.10, 0.14, 0.22))
		hold_bar_fill = _rect(self, Vector2(x, y + 3.0), Vector2(0, 8), Color(0.45, 0.80, 0.95))
		hold_label = _plabel("", Vector2(x + 84.0, y - 2.0), Vector2(DRIFT_PANEL_SIZE.x - 24.0 - 84.0, 14), 9, Color(0.80, 0.90, 0.95))
		hold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		hold_label.clip_text = true
		y += DRIFT_ROW_H

	if GameManager.has_tracking_mount_equipped():
		var rate_label := _plabel(GameManager.text("Rate", "速率"), Vector2(x, y + 2.0), Vector2(52, 14), 9, Color(0.75, 0.85, 0.95))
		rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tracking_knob_status = _hud_asset(OBS_UI_DIR + "tracking_rate_knob.png", Rect2(Vector2(x + 54.0, y - 4.0), Vector2(26, 26)))
		tracking_knob_status.pivot_offset = tracking_knob_status.size * 0.5
		tracking_knob_status.rotation = lerpf(-PI * 0.72, PI * 0.72, clampf(GameManager.tracking_rate() / 2.0, 0.0, 1.0))
		tracking_slider = HSlider.new()
		tracking_slider.min_value = 0.0
		tracking_slider.max_value = 2.0
		tracking_slider.step = 0.05
		tracking_slider.value = GameManager.tracking_rate()
		tracking_slider.position = Vector2(x + 88.0, y)
		tracking_slider.size = Vector2(200, 18)
		tracking_slider.value_changed.connect(func(value: float) -> void:
			GameManager.set_tracking_rate(value)
			if tracking_knob_status != null:
				InteractionFeedback.tween_rotation(tracking_knob_status, lerpf(-PI * 0.72, PI * 0.72, clampf(value / 2.0, 0.0, 1.0)), 0.11)
			_refresh_drift_ui()
		)
		add_child(tracking_slider)
		tracking_label = _plabel("", Vector2(x + 294.0, y + 2.0), Vector2(DRIFT_PANEL_SIZE.x - 24.0 - 294.0, 14), 9, Color(0.80, 0.90, 0.95))
		tracking_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	_refresh_drift_ui()


func _drift_status_text() -> String:
	return GameManager.text("Drift: On", "漂移：开启")


func _tracking_state_label() -> Dictionary:
	if not GameManager.has_tracking_mount_equipped():
		return {"en": "Off", "zh": "关"}
	var rate := GameManager.tracking_rate()
	if rate < 0.05:
		return {"en": "Off", "zh": "关"}
	if absf(rate - 1.0) <= 0.1:
		return {"en": "Matched 1x", "zh": "匹配 1倍"}
	if rate < 1.0:
		return {"en": "Too slow", "zh": "过慢"}
	return {"en": "Too fast", "zh": "过快"}


func _refresh_drift_ui() -> void:
	if drift_label != null:
		var tracking_state := _tracking_state_label()
		var track_text := GameManager.text(
			"Tracking: %s" % str(tracking_state.get("en", "")),
			"追踪：%s" % str(tracking_state.get("zh", ""))
		)
		if GameManager.has_tracking_mount_equipped():
			var rate_error := absf(GameManager.tracking_rate() - 1.0)
			track_text += "  Δ%.2fx" % rate_error
		drift_label.text = "%s   %s" % [_drift_status_text(), track_text]
	if hold_bar_fill != null and hold_seconds_required > 0.0:
		var ratio := clampf(hold_timer / hold_seconds_required, 0.0, 1.0)
		hold_bar_fill.size = Vector2(74.0 * ratio, 8)
	if hold_label != null:
		hold_label.text = GameManager.text(
			"Centered: %.1f/%.1fs" % [hold_timer, hold_seconds_required],
			"居中：%.1f/%.1f秒" % [hold_timer, hold_seconds_required]
		)
	if tracking_label != null:
		tracking_label.text = "%.2fx" % GameManager.tracking_rate()
	if tracking_enabled_status != null:
		var enabled := GameManager.tracking_rate() >= 0.05
		var aligned := absf(GameManager.tracking_rate() - 1.0) <= 0.1
		tracking_enabled_status.visible = enabled
		tracking_enabled_status.modulate = Color(0.58, 1.0, 0.72, 1.0) if aligned else Color(1.0, 0.76, 0.34, 0.78)
		if enabled and not tracking_feedback_enabled:
			InteractionFeedback.pulse(tracking_enabled_status, Color(0.70, 1.0, 0.78), 0.38)
		elif aligned and not tracking_feedback_aligned:
			InteractionFeedback.success(tracking_enabled_status, "tracking_rate_matched")
		tracking_feedback_enabled = enabled
		tracking_feedback_aligned = aligned


func _refresh_focus_ui() -> void:
	_check_mission_step_progress()
	if mission_step_label != null:
		mission_step_label.text = _mission_step_progress_text()
	if focus_slider != null:
		updating_slider = true
		focus_slider.value = focus_value
		updating_slider = false
	if focus_pct_label != null:
		focus_pct_label.text = "%d%%  (Q/E)" % int(round(focus_value * 100.0))
	if focus_state_label != null and allow_focus_input:
		var state := _focus_state()
		match state:
			"sharp":
				# Sharp focus alone is not permission to identify - the
				# overall quality (and, on drift levels, the hold timer) must
				# also pass.
				if _collimation_severity() > 0.28:
					focus_state_label.text = GameManager.text("Coma: collimate mirrors.", "彗差：请准直镜面。")
					focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
				elif drift_enabled and not is_hold_satisfied():
					focus_state_label.text = _hold_progress_text()
					focus_state_label.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
				elif is_quality_acceptable():
					focus_state_label.text = GameManager.text("Image clear enough. Ready to identify.", "图像已足够清晰，可以识别。")
					focus_state_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
				else:
					focus_state_label.text = _quality_shortfall_text()
					focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			"slightly_blurry":
				focus_state_label.text = GameManager.text("Almost sharp. Fine-tune Q/E a little more.", "已经接近清晰，请用 Q/E 再微调一点。")
				focus_state_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
			"blurry":
				focus_state_label.text = GameManager.text("Blurry. Keep adjusting.", "模糊，继续调整。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			_:
				focus_state_label.text = GameManager.text("Very blurry. Turn the focus knob.", "非常模糊，请转动调焦旋钮。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.30))
	var quality := str(observation.get("quality", "Unknown"))
	if quality_label != null:
		quality_label.text = GameManager.text("Quality: ", "质量: ") + quality
		quality_label.add_theme_color_override("font_color", _quality_color(quality))
	if feedback_label != null:
		InteractionFeedback.crossfade_text(feedback_label, _current_feedback())
	if drift_enabled:
		_refresh_drift_ui()
	_update_target_visuals()


func _current_feedback() -> String:
	if requires_focus and not allow_focus_input:
		return GameManager.text(
			"A focus knob is required. Return to the Assembly Table and install it near the eyepiece.",
			"需要调焦旋钮。请回到组装台，把它安装在目镜附近。"
		)
	if not _missing_required_parts().is_empty():
		return _missing_required_parts_text()
	if is_focus_acceptable() and _collimation_severity() > 0.28:
		return _quality_shortfall_text()
	if drift_enabled and not is_hold_satisfied():
		return _hold_progress_text()
	if not is_focus_acceptable():
		return GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
	if requires_focus and not is_quality_acceptable():
		# The feedback box names the REAL limiting factor, in priority order
		# (cloud > seeing > sky brightness > aperture/stability): see
		# _quality_shortfall_text(). Only fall back to the generic "equip a
		# bigger lens" nebula copy when none of those environmental causes
		# are the dominant one.
		var type_lower := str(selected_object.get("type_en", "")).to_lower()
		var is_diffuse := type_lower.contains("nebula") or type_lower.contains("galaxy")
		var environmental_cause := _collimation_severity() > 0.28 or cond_cloud_atten > 0.35 or str(observation.get("seeing_label", "Good")) != "Good"
		if is_diffuse and not environmental_cause:
			return GameManager.text(
				"Focus aligned, but the image is too faint. Equip a bigger lens / stable mount at the Parts Cabinet, then reassemble.",
				"焦点已对准，但图像太暗。请到零件柜换装大口径物镜和稳定支架，再重新组装。"
			)
		return _quality_shortfall_text()
	if requires_focus and can_identify_object():
		return GameManager.text("Image clear enough. Ready to identify.", "图像已足够清晰，可以识别。")
	return _short_feedback(str(observation.get("quality", "Unknown")))


func _add_stat_bars() -> void:
	var stats := GameManager.calculate_stats()
	var rows: Array = [
		{"name": GameManager.text("Light", "集光"), "value": float(stats.get("light_score", 0.0))},
		{"name": GameManager.text("Clarity", "清晰"), "value": float(stats.get("clarity_score", 0.0))},
		{"name": GameManager.text("Stability", "稳定"), "value": float(stats.get("stability_score", 0.0))}
	]
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var value: float = float(row.get("value", 0.0))
		var y := 224.0 + float(index) * 20.0
		_plabel("%s %s" % [str(row.get("name", "")), snapped(value, 0.1)], Vector2(CONTENT_X, y), Vector2(96, 15), 10, Color(0.78, 0.86, 0.90))
		_rect(self, Vector2(CONTENT_X + 100, y + 3), Vector2(94, 8), Color(0.10, 0.14, 0.22))
		var fill_width := clampf(value, 0.0, 100.0) * 0.94
		var fill := _rect(self, Vector2(CONTENT_X + 100, y + 3), Vector2(0, 8), Color(0.45, 0.75, 0.50))
		fill.set_meta("result_width", fill_width)
		stat_bar_fills.append(fill)


func _animate_stat_bars() -> void:
	if stat_bar_fills.is_empty():
		return
	await get_tree().process_frame
	for fill in stat_bar_fills:
		if fill == null or not is_instance_valid(fill):
			continue
		InteractionFeedback.tween_size(fill, Vector2(float(fill.get_meta("result_width", 0.0)), 8), 0.28)
		await get_tree().create_timer(0.08 if not InteractionFeedback.is_reduced_motion() else 0.02).timeout


# Dynamic condition-row slots (spec: UI 条件行重构). Slot 1 (equipment) is
# always shown; slots 2-4 (condition A / condition B / dark adaptation)
# appear only when there is something real to report. Returns the Y
# position immediately below the last slot used, so the caller can place
# feedback_label without overlapping.
const CONDITION_ROW_Y := 283.0
const CONDITION_ROW_H := 12.0


func _add_condition_rows() -> float:
	var y := CONDITION_ROW_Y
	y = _add_equipment_row(y)
	y = _add_condition_row_a(y)
	y = _add_condition_row_b(y)
	y = _add_dark_adaptation_row(y)
	return y


func _add_equipment_row(y: float) -> float:
	# Slot 1: "100mm · 10mm · 80.0x" - always shown.
	var stats := GameManager.calculate_stats()
	var objective := GameManager.get_part(GameManager.equipped_part_id("objective"))
	var eyepiece := GameManager.get_part(GameManager.equipped_part_id("eyepiece"))
	var objective_mm := int(objective.get("aperture_mm", 0))
	var eyepiece_mm := int(eyepiece.get("focal_length_mm", 0))
	var magnification := float(stats.get("magnification", 0.0))
	var equip_line := "%dmm · %dmm · %sx" % [objective_mm, eyepiece_mm, snapped(magnification, 0.1)]
	var font_size := 9
	if bool(GameManager.current_level().get("requires_collimation", false)):
		equip_line += GameManager.text("  Coll. %d%%" % roundi(GameManager.collimation_score()), "  准直 %d%%" % roundi(GameManager.collimation_score()))
		font_size = 8
	_plabel(equip_line, Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), font_size, Color(0.72, 0.80, 0.88))
	return y + CONDITION_ROW_H


func _add_condition_row_a(y: float) -> float:
	# Slot 2: "Seeing视宁度: Poor·差  Cloud云: Thin·薄" - shown when either
	# seeing or cloud cover is defined for this level.
	var environment: Dictionary = GameManager.current_environment()
	var parts: Array[String] = []
	if environment.has("seeing"):
		var seeing_label := str(observation.get("seeing_label", ""))
		if seeing_label == "":
			seeing_label = str(environment.get("seeing", "")).capitalize()
		var seeing_zh := "好"
		match seeing_label:
			"Poor": seeing_zh = "差"
			"Average": seeing_zh = "中"
		parts.append(GameManager.text("Seeing: %s" % seeing_label, "视宁度：%s" % seeing_zh))
	if cloud_cover_level > 0.0:
		var cloud_tier := _cloud_tier_label()
		parts.append(GameManager.text(
			"Clouds: %s" % str(cloud_tier.get("en", "")),
			"云层：%s" % str(cloud_tier.get("zh", ""))
		))
	if parts.is_empty():
		return y
	_plabel("  ".join(parts), Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.95, 0.78, 0.45))
	return y + CONDITION_ROW_H


func _add_condition_row_b(y: float) -> float:
	# Slot 3: "Sky天空: City·城市  Contrast对比: Low·低" - shown when the
	# level defines a sky_brightness tier.
	var environment: Dictionary = GameManager.current_environment()
	if not environment.has("sky_brightness"):
		return y
	var sky_tier := _sky_tier_label()
	var contrast_tier := _contrast_label()
	var line := GameManager.text(
		"Sky: %s  Contrast: %s" % [str(sky_tier.get("en", "")), str(contrast_tier.get("en", ""))],
		"天空：%s  对比度：%s" % [str(sky_tier.get("zh", "")), str(contrast_tier.get("zh", ""))]
	)
	_plabel(line, Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.95, 0.78, 0.45))
	return y + CONDITION_ROW_H


func _add_dark_adaptation_row(y: float) -> float:
	# Slot 4: dark adaptation % (left) + averted vision state (right) -
	# deep-sky targets only.
	if not _is_dark_adaptation_target():
		return y
	dark_adaptation_label = _plabel(
		GameManager.text("Dark adaptation: %d%%", "暗适应：%d%%") % int(round(dark_adaptation * 100.0)),
		Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 8, Color(0.70, 0.82, 0.98)
	)
	averted_vision_label = _plabel(
		GameManager.text("Averted vision: Active", "侧视：启用") if averted_vision_active else GameManager.text("Averted vision: Inactive", "侧视：未启用"),
		Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 8, Color(0.66, 0.72, 0.80), HORIZONTAL_ALIGNMENT_RIGHT
	)
	return y + CONDITION_ROW_H


func _short_feedback(quality: String) -> String:
	if _is_constellation_observation():
		return GameManager.text("Trace the shape you centered, then identify the constellation.", "观察刚才居中的星群形状，再识别对应星座。")
	if observation_mode == "naked_eye":
		return GameManager.text(str(observation.get("feedback_en", "")), str(observation.get("feedback_zh", "")))
	match quality:
		"Excellent":
			return GameManager.text("Clear image. Ready to identify.", "图像清晰，可以识别目标。")
		"Good":
			return GameManager.text("Stable enough to identify.", "足够稳定，可以识别目标。")
		"Fair":
			return GameManager.text("Visible, but slightly unclear.", "可以看到目标，但略有不清。")
		"Poor":
			return GameManager.text("Too blurry. Improve alignment.", "太模糊了，请改进安装对齐。")
		"Failed":
			return GameManager.text("Observation failed. Reassemble or retry.", "观测失败，请重新组装或重试。")
	return GameManager.text("Observation complete.", "观测完成。")


func _add_identify_choices() -> void:
	if identify_choice_ids.is_empty():
		identify_choice_ids = _build_identify_choice_ids()
	var letters := ["A", "B", "C", "D"]
	for index in range(identify_choice_ids.size()):
		var id := identify_choice_ids[index]
		var obj := GameManager.get_object(id)
		if obj.is_empty():
			continue
		var letter := str(letters[index]) if index < letters.size() else str(index + 1)
		var label := "%s. %s" % [letter, GameManager.dict_text(obj, "name").replace("\n", " · ")]
		var button := _pixel_button(label, Vector2(CONTENT_W, 32), 12)
		button.clip_text = true
		button.set_meta("object_id", id)
		button.set_meta("choice_index", index)
		button.pressed.connect(_identify.bind(id))
		choices_box.add_child(button)


func _build_identify_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	var correct_id := str(selected_object.get("id", ""))
	if _is_constellation_observation():
		for data_value in GameManager.constellations_data:
			var data: Dictionary = data_value
			_add_unique(ids, str(data.get("id", "")))
		ids.erase(correct_id)
		ids.shuffle()
		while ids.size() > 3:
			ids.pop_back()
		ids.insert(0, correct_id)
		ids.shuffle()
		return ids
	_add_unique(ids, correct_id)
	_add_unique(ids, str(GameManager.current_target().get("id", "")))
	for id in _distractors_for(correct_id):
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	for id in ["sirius", "betelgeuse", "jupiter", "polaris"]:
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	if ids.size() > 4:
		ids.resize(4)
	ids.erase(correct_id)
	ids.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var correct_index := rng.randi_range(0, ids.size())
	if ids.size() > 0 and correct_index == _last_correct_choice_index:
		correct_index = (correct_index + rng.randi_range(1, ids.size())) % (ids.size() + 1)
	ids.insert(correct_index, correct_id)
	_last_correct_choice_index = correct_index
	return ids


func _set_identify_choices_visible(show_choices: bool) -> void:
	if identify_title_label != null:
		identify_title_label.visible = show_choices
	if choices_box != null:
		choices_box.visible = show_choices


func _show_pre_quiz_guide() -> void:
	_set_identify_choices_visible(false)
	quiz_brief_overlay = Control.new()
	quiz_brief_overlay.name = "PreQuizObjectGuide"
	quiz_brief_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	quiz_brief_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	quiz_brief_overlay.z_index = Z_MODAL_OVERLAY
	add_child(quiz_brief_overlay)
	InteractionFeedback.page_enter(quiz_brief_overlay, Vector2(0, 8))

	_rect(quiz_brief_overlay, Vector2.ZERO, Vector2(1024, 768), Color(0.0, 0.0, 0.0, 0.82))
	_styled_panel(quiz_brief_overlay, Vector2(132, 62), Vector2(760, 642), Color(0.018, 0.032, 0.058, 0.995), COL_GOLD, 3, 2, true)
	_rect(quiz_brief_overlay, Vector2(152, 82), Vector2(720, 2), COL_GOLD.darkened(0.45))
	_plabel_on(quiz_brief_overlay, "OBSERVATORY FIELD MANUAL  //  01", Vector2(162, 88), Vector2(700, 16), 9, Color(0.50, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	_plabel_on(quiz_brief_overlay, GameManager.text("Object Field Guide", "天体辨识指南"), Vector2(164, 108), Vector2(696, 32), 23, COL_GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_rect(quiz_brief_overlay, Vector2(180, 146), Vector2(664, 1), Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.48))
	var intro := _plabel_on(
		quiz_brief_overlay,
		GameManager.text(
			"Compare the observed silhouette with these reference records: shape, colour, brightness and object class.",
			"把刚才看到的轮廓与参考记录比较：形状、颜色、亮度和天体类别。"
		),
		Vector2(178, 154), Vector2(668, 38), 11, Color(0.74, 0.84, 0.91), HORIZONTAL_ALIGNMENT_CENTER
	)
	intro.max_lines_visible = 2

	for index in range(identify_choice_ids.size()):
		var id := identify_choice_ids[index]
		var obj := GameManager.get_object(id)
		var column := index % 2
		var row := index / 2
		var card_pos := Vector2(164 + column * 354, 202 + row * 174)
		var card := _styled_panel(quiz_brief_overlay, card_pos, Vector2(338, 156), Color(0.035, 0.060, 0.096, 1.0), Color(0.24, 0.43, 0.62), 2, 1, false)
		_corner(card, Vector2(0, 0), Color(0.44, 0.72, 0.88))
		_corner(card, Vector2(324, 142), Color(0.44, 0.72, 0.88))
		_rect(card, Vector2(10, 36), Vector2(318, 1), Color(0.24, 0.43, 0.62, 0.74))
		var name_text := "%s. %s" % [String.chr(65 + index), GameManager.dict_text(obj, "name").replace("\n", " · ")]
		_plabel_on(card, name_text, Vector2(14, 8), Vector2(306, 24), 14, COL_GOLD_LIGHT)
		var thumbnail_well := _styled_panel(card, Vector2(12, 48), Vector2(76, 94), Color(0.006, 0.014, 0.030, 1.0), Color(0.18, 0.34, 0.50), 1, 0, false)
		var thumbnail_path := _guide_thumbnail_path(id)
		if thumbnail_path != "" and ResourceLoader.exists(thumbnail_path):
			var thumbnail := TextureRect.new()
			thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumbnail.texture = load(thumbnail_path) as Texture2D
			thumbnail.position = Vector2(7, 8)
			thumbnail.size = Vector2(62, 62)
			thumbnail_well.add_child(thumbnail)
		_plabel_on(thumbnail_well, GameManager.dict_text(obj, "type").to_upper(), Vector2(4, 72), Vector2(68, 16), 7, Color(0.52, 0.78, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
		var feature := _object_guide_text(obj)
		var feature_label := _plabel_on(card, feature, Vector2(98, 47), Vector2(226, 98), 9, COL_TEXT)
		feature_label.max_lines_visible = 7
		if not InteractionFeedback.is_reduced_motion():
			var final_pos := card.position
			card.position = final_pos + Vector2(0, 8)
			card.modulate.a = 0.0
			var reveal := create_tween().bind_node(card)
			reveal.tween_interval(0.05 + float(index) * 0.055)
			reveal.set_parallel(true)
			reveal.tween_property(card, "position", final_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			reveal.tween_property(card, "modulate:a", 1.0, 0.16)

	var start_button := _pixel_button(GameManager.text("Start Identification", "开始识别"), Vector2(250, 42), 14)
	start_button.position = Vector2(387, 646)
	start_button.pressed.connect(_dismiss_pre_quiz_guide)
	quiz_brief_overlay.add_child(start_button)
	start_button.grab_focus()


func _object_guide_text(obj: Dictionary) -> String:
	var type_text := GameManager.dict_text(obj, "type")
	var clue := GameManager.dict_text(obj, "short_hint")
	var learning := GameManager.dict_text(obj, "learning_text")
	return GameManager.text("Type: %s\n%s\n%s", "类型：%s\n%s\n%s") % [type_text, clue, learning]


func _guide_thumbnail_path(object_id: String) -> String:
	if STATE_TEXTURES.has(object_id):
		return str((STATE_TEXTURES[object_id] as Dictionary).get("clear", ""))
	return str(SPRITE_MAP.get(object_id, ""))


func _dismiss_pre_quiz_guide() -> void:
	quiz_brief_dismissed = true
	if quiz_brief_overlay != null:
		var overlay := quiz_brief_overlay
		quiz_brief_overlay = null
		InteractionFeedback.fade_then(overlay, func() -> void:
			overlay.queue_free()
			call_deferred("_show_focus_tutorial")
		)
	_set_identify_choices_visible(true)


func _identify(choice_id: String) -> void:
	if identify_transition_active:
		return
	call_deferred("_animate_identify_failure_if_needed")
	# Reset any lingering milestone-green from _announce_step_complete.
	feedback_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.88))
	# Concept brief tied to the identification moment (e.g. chromatic
	# aberration on L25): explain what the player is looking at, then let
	# them come back and answer.
	if GameManager.try_story_for_trigger("before_identify", "telescope"):
		return
	if GameManager.try_teaching_intercept("before_identify", "telescope"):
		return
	if requires_focus and not allow_focus_input:
		feedback_label.text = GameManager.text(
			"Install the Focus Knob before trying to identify this target.",
			"请先安装调焦旋钮，再尝试识别这个目标。"
		)
		return
	if not _missing_required_parts().is_empty():
		feedback_label.text = _missing_required_parts_text()
		return
	if drift_enabled and not is_hold_satisfied():
		feedback_label.text = _hold_progress_text()
		return
	if not is_focus_acceptable():
		feedback_label.text = GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
		return
	if choice_id != str(selected_object.get("id", "")):
		feedback_label.text = GameManager.text("Not what you observed. Try again.", "与观测到的目标不符，再试一次。")
		return
	if not is_quality_acceptable():
		# Correct answer, but the observation itself is not good enough:
		# the mission must not complete.
		if requires_focus:
			feedback_label.text = _quality_shortfall_text()
		else:
			feedback_label.text = GameManager.text(
				"Identified, but the observation quality is too low.",
				"识别正确，但观测质量不足。"
			)
		return
	var pending_step := GameManager.next_pending_mission_step()
	if not pending_step.is_empty():
		feedback_label.text = GameManager.text(
			"Not yet - complete: " + GameManager.dict_text(pending_step, "label"),
			"还没完成：" + GameManager.dict_text(pending_step, "label")
		)
		return
	# Observation confirmation is visual only; mission conditions and the
	# completion call remain unchanged.
	identify_transition_active = true
	feedback_label.text = GameManager.text("Observation confirmed...", "观测已确认...")
	feedback_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
	InteractionFeedback.success(choices_box, "observation_confirmed")
	if main_sprite != null:
		InteractionFeedback.pulse(main_sprite, Color(1.10, 1.06, 0.82, 1.0), 0.42)
	await get_tree().create_timer(0.38 if not InteractionFeedback.is_reduced_motion() else 0.10).timeout
	# On success GameManager routes to the Mission Complete card itself.
	var completed := GameManager.complete_current_mission(choice_id, observation)
	if completed:
		return
	identify_transition_active = false
	var target := GameManager.current_target()
	if choice_id != str(target.get("id", "")):
		feedback_label.text = GameManager.text("Correct, but not the mission target.", "识别正确，但不是当前任务目标。")
	else:
		feedback_label.text = GameManager.text("Identified, but quality is too low.", "识别正确，但观测质量不足。")


func _animate_identify_failure_if_needed() -> void:
	if identify_transition_active or not is_inside_tree():
		return
	var control: Control = choices_box
	if requires_focus and not allow_focus_input:
		control = focus_state_label if focus_state_label != null else feedback_label
	elif drift_enabled and not is_hold_satisfied():
		control = tracking_slider if tracking_slider != null else drift_label
	elif not is_focus_acceptable():
		control = focus_slider if focus_slider != null else focus_state_label
	elif not is_quality_acceptable():
		control = cloud_veil if cond_cloud_atten > 0.35 and cloud_veil != null else quality_label
	InteractionFeedback.error(control if control != null else feedback_label)


# ------------------------------------------------------------- scope visual


func _scope_visual() -> Control:
	var root := Control.new()
	root.size = Vector2(640, 620)
	var center := Vector2(318, 300)
	lens_center = center
	effect_seed = fmod(float(str(selected_object.get("id", "")).hash()), 100.0)
	cloud_cover_level = _cloud_cover() if observation_mode != "naked_eye" else 0.0
	if _is_constellation_observation():
		_add_sky_background(root, center)
		_add_scope_stars(root, center)
		_add_constellation_field(root)
		return root
	if observation_mode == "naked_eye":
		# Open night sky, no telescope barrel.
		_circle(root, center - Vector2(262, 262), Vector2(524, 524), Color(0.006, 0.012, 0.032), Color.TRANSPARENT, 0)
	else:
		_circle(root, center - Vector2(218, 218), Vector2(436, 436), Color(0.0, 0.0, 0.0), Color.TRANSPARENT, 0)
		_add_sky_background(root, center)
	_add_scope_stars(root, center)
	_add_target_visual(root, center)
	if observation_mode != "naked_eye":
		_add_cloud_layer(root, center)
	_add_quality_noise(root, center)
	_add_optical_lens_effect(root, center)
	_add_averted_vision_guide(root)
	if observation_mode != "naked_eye":
		# Ring occluder ABOVE all lens content: clips drifting sprites /
		# clouds / stars to the circle by repainting the barrel on top.
		# Wrapped in a clipper so the oversized rect never paints over the
		# outer pixel frame (screen-safe rect 16,14 .. 748,748; this root
		# sits at screen 54,98).
		var clipper := Control.new()
		clipper.position = Vector2(-38, -84)
		clipper.size = Vector2(732, 734)
		clipper.clip_contents = true
		clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var occluder := ColorRect.new()
		occluder.position = center - Vector2(450, 450) - clipper.position
		occluder.size = Vector2(900, 900)
		occluder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var occluder_mat := ShaderMaterial.new()
		occluder_mat.shader = LENS_RING_OCCLUDER_SHADER
		occluder.material = occluder_mat
		clipper.add_child(occluder)
		root.add_child(clipper)
	# The detailed telescope image stays optically clean: no barrel artwork,
	# crosshair, or center circle over the observed object. Naked-eye sessions
	# retain their dedicated wide-field reference overlay.
	if observation_mode == "naked_eye":
		_add_observation_reticle(root, center)
	return root


func _add_optical_lens_effect(parent: Control, center: Vector2) -> void:
	if _is_constellation_observation():
		return
	var lens_size := 524.0 if observation_mode == "naked_eye" else 436.0
	var overlay := ColorRect.new()
	overlay.name = "OpticalLensOverlay"
	overlay.position = center - Vector2.ONE * lens_size * 0.5
	overlay.size = Vector2.ONE * lens_size
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = OPTICAL_LENS_SHADER
	material.set_shader_parameter("region_uv_size", Vector2(lens_size / 1024.0, lens_size / 768.0))
	material.set_shader_parameter("circular_lens", 1.0)
	if observation_mode == "naked_eye":
		material.set_shader_parameter("curvature", 0.020)
		material.set_shader_parameter("vignette_strength", 0.075)
		material.set_shader_parameter("chroma_px", 0.06)
		material.set_shader_parameter("glass_highlight", 0.024)
		material.set_shader_parameter("edge_bloom", 0.025)
		material.set_shader_parameter("scanline_strength", 0.004)
		material.set_shader_parameter("lens_rim_strength", 0.028)
		material.set_shader_parameter("lens_caustic_strength", 0.018)
	else:
		material.set_shader_parameter("curvature", 0.088)
		material.set_shader_parameter("vignette_strength", 0.22)
		material.set_shader_parameter("chroma_px", 0.32)
		material.set_shader_parameter("glass_highlight", 0.074)
		material.set_shader_parameter("edge_bloom", 0.12)
		material.set_shader_parameter("scanline_strength", 0.016)
		material.set_shader_parameter("lens_rim_strength", 0.19)
		material.set_shader_parameter("lens_caustic_strength", 0.13)
	overlay.material = material
	parent.add_child(overlay)


func _add_averted_vision_guide(parent: Control) -> void:
	var requirements: Dictionary = GameManager.current_level().get("observation_requirements", {})
	if not bool(requirements.get("require_averted_vision", false)) or not _is_diffuse_target():
		return
	averted_vision_guide = AvertedVisionGuide.new()
	averted_vision_guide.name = "AvertedVisionGuide"
	averted_vision_guide.size = Vector2(640, 620)
	averted_vision_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	averted_vision_guide.enabled = true
	averted_vision_guide.active = averted_vision_active
	averted_vision_guide.adaptation = _eased_dark_adaptation()
	averted_vision_guide.hold_visual = averted_hold_visual
	averted_vision_guide.target_position = target_center
	parent.add_child(averted_vision_guide)


func _is_constellation_observation() -> bool:
	return observation_mode == "constellation" and not GameManager.get_constellation(str(selected_object.get("id", ""))).is_empty()


func _add_constellation_field(parent: Control) -> void:
	constellation_field = ConstellationField.new()
	constellation_field.name = "ConstellationField"
	constellation_field.size = Vector2(640, 620)
	constellation_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	constellation_field.pattern = GameManager.get_constellation(str(selected_object.get("id", ""))).get("stars", [])
	parent.add_child(constellation_field)


func _add_observation_reticle(parent: Control, center: Vector2) -> void:
	var overlay := TextureRect.new()
	overlay.name = "ObservationReticleOverlay"
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture = load(EYE_RETICLE_TEXTURE) as Texture2D
	# The open-sky observation stage needs one quiet perimeter reference, not
	# the focusing rings baked into the source artwork.
	var outer_ring_material := ShaderMaterial.new()
	outer_ring_material.shader = NAKED_EYE_OUTER_RING_SHADER
	overlay.material = outer_ring_material
	overlay.position = center - Vector2(280, 280)
	overlay.size = Vector2(560, 560)
	parent.add_child(overlay)


func _add_sky_background(parent: Control, center: Vector2) -> void:
	# Light-pollution background fill, clipped to the inner scope circle.
	# Even a dark site keeps a faint navy glass floor so the curved lens and
	# full-colour rim remain visible instead of reading as a flat black disc.
	var lift := _target_sky_lift()
	var color := Color(0.004, 0.008, 0.020).lerp(Color(0.045, 0.052, 0.075), lift)
	var panel := Panel.new()
	panel.position = center - Vector2(218, 218)
	panel.size = Vector2(436, 436)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(218)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)


func _add_crosshair(parent: Control, center: Vector2) -> void:
	# Thin reticle lines with a wide gap so the target stays unobstructed.
	_rect(parent, center + Vector2(-170, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(55, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, -170), Vector2(2, 115), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, 55), Vector2(2, 115), COL_CROSSHAIR)


func _add_target_visual(parent: Control, scope_center: Vector2) -> void:
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = scope_center + _effect_offset(effect, quality) + drift_offset
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif effect == "dim" and quality in ["Poor", "Failed"] and not _city_glow_diffuse_target():
		base_alpha *= 0.55
	base_alpha = clampf(base_alpha + _dark_adaptation_alpha_bonus(), 0.0, 1.0)
	# Brightness floor: a solid target never fades below identifiability.
	base_alpha = maxf(base_alpha, _target_alpha_floor())
	if GameManager.current_level().get("observation_requirements", {}).has("exposure_max"):
		base_alpha = clampf(base_alpha * lerpf(0.42, 1.35, exposure_value), 0.0, 1.0)

	var path: String = _sprite_path_for_target(id, quality, effect)
	current_sprite_path = path
	var texture: Texture2D = _load_target_texture(path)

	var has_blur_variant := _has_blur_variant(id)
	var ghost_texture := texture
	if has_blur_variant:
		var state_textures: Dictionary = STATE_TEXTURES[id]
		ghost_texture = _load_target_texture(str(state_textures["blurry"]))

	var sprite_scale := 1.0
	if observation_mode == "naked_eye":
		sprite_scale = _naked_eye_scale(id)
	else:
		sprite_scale = _magnification_scale() * _object_view_scale(id)
		if base_alpha > 0.0 and _magnification_scale() > 1.0:
			# Higher magnification spreads the same light over a larger
			# image: bigger but dimmer, same real telescope trade-off.
			base_alpha *= 0.85
		# The scaled sprite must stay inside the 436px scope circle - the
		# large state textures are already 300-360px at scale 1.0.
		var largest_dim := maxf(
			maxf(texture.get_size().x, texture.get_size().y),
			maxf(ghost_texture.get_size().x, ghost_texture.get_size().y)
		)
		if largest_dim > 0.0:
			sprite_scale = minf(sprite_scale, 380.0 / largest_dim)
	display_scale = sprite_scale

	ghost_a = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	ghost_b = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	main_sprite = _add_sprite(parent, texture, target_center, base_alpha, sprite_scale)
	if has_blur_variant:
		blur_overlay = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	if effect == "dim" and quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, base_alpha)
	if effect == "shaky":
		ghost_a.modulate.a = base_alpha * 0.30
		ghost_a.position += Vector2(-9, 5)
	_setup_turbulence_materials()
	# Poor/Failed contrast flattening + averted-vision brighten are applied
	# uniformly in _refresh_target_sprite (called below via
	# _update_target_visuals), so they stay correct every frame instead of
	# only at build time.
	# Deep-sky targets take an extra contrast hit under a city sky.
	if _is_diffuse_target() and observation_mode != "naked_eye":
		var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
		if sky_key == "city":
			base_alpha *= 0.8
	# Start the smoothed values converged so the scene doesn't animate in.
	visual_focus_error = focus_error
	visual_target_center = target_center
	visual_base_alpha = base_alpha
	blur_weight = _target_blur_weight()
	cond_turbulence = _target_turbulence()
	cond_sky_lift = _target_sky_lift()
	cond_cloud_atten = 0.0
	_apply_turbulence_uniforms()
	_update_target_visuals()


func _has_blur_variant(id: String) -> bool:
	return STATE_TEXTURES.has(id) and requires_focus and observation_mode != "naked_eye"


func _sprite_path_for_target(id: String, quality: String, effect: String) -> String:
	if STATE_TEXTURES.has(id):
		var textures: Dictionary = STATE_TEXTURES[id]
		if _has_blur_variant(id):
			# Focus blur is handled by the cross-fade overlay; the base
			# sprite only distinguishes light shortage (dim) vs sharp art.
			# Quality verdict only - visual_effect is a relative hint.
			if quality in ["Poor", "Failed"] and is_focus_acceptable():
				# City glow destroys contrast, not focus. Using the already-dark
				# asset here and then applying the city alpha/noise penalties made
				# a correctly focused galaxy disappear completely. Preserve its
				# focused contour; the sky lift, grain, tint and alpha still show
				# how difficult the observation is.
				var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
				if _is_diffuse_target() and sky_key == "city":
					return str(textures["clear"])
				return str(textures["dim"])
			return str(textures["clear"])
		# Quality verdict ONLY - visual_effect is a relative weakest-stat
		# hint and can read "blurry"/"dim" even at Excellent (same bug class
		# as the L11 mars fix, this is the no-focus/naked-eye branch).
		if quality in ["Poor", "Failed"]:
			return str(textures["dim"])
		if quality == "Fair":
			return str(textures["blurry"])
		return str(textures["clear"])
	return str(SPRITE_MAP.get(id, SPRITE_MAP["polaris"]))


func _load_target_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path)
		if loaded != null:
			return loaded
	var image := Image.load_from_file(path)
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return load(SPRITE_MAP["polaris"])


func _naked_eye_alpha() -> float:
	# What your eyes can actually see: bright targets clear, deep sky ~gone.
	var visible := bool(selected_object.get("naked_eye_visible", false))
	if not visible:
		return 0.06
	var brightness := float(selected_object.get("brightness", 50.0))
	return clampf(0.35 + brightness / 130.0, 0.35, 1.0)


func _object_view_scale(id: String) -> float:
	# Relative apparent size in the eyepiece - keeps the REAL ordering even
	# though absolute angular scale is compressed for gameplay: the Moon is
	# the only object that fills the view; planets are small resolved discs
	# (Jupiter > Mars); Andromeda is an extended glow, not a wall of light.
	match id:
		"moon":
			return 1.0
		"jupiter":
			return 0.60
		"mars":
			return 0.46
		"andromeda":
			return 0.62
		"orion_nebula":
			return 0.70
		"mercury": return 0.28
		"venus": return 0.44
		"saturn": return 0.72
		"uranus": return 0.24
		"neptune": return 0.20
		"moon_crater_copernicus", "moon_mare_tranquillitatis", "moon_terminator": return 0.92
		"albireo": return 0.46
		"pleiades": return 0.90
		"m13": return 0.55
		"ring_nebula": return 0.42
		"lagoon_nebula": return 0.82
		"sombrero_galaxy": return 0.68
		"crab_nebula": return 0.62
		"dumbbell_nebula": return 0.58
		"double_cluster": return 0.92
		"whirlpool_galaxy": return 0.66
		"needle_galaxy": return 0.76
	return 1.0


func _magnification_scale() -> float:
	# Higher magnification makes the target visibly larger in the eyepiece
	# (and, per base_alpha above, dimmer) - a real trade-off, not just text.
	# Stars stay point-like regardless of magnification (verdict 9): higher
	# power never turns a star into a resolvable disc.
	if _is_star_target():
		return 1.0
	var stats: Dictionary = GameManager.calculate_stats()
	var magnification := float(stats.get("magnification", 0.0))
	return clampf(magnification / 35.0, 1.0, 1.4)


func _naked_eye_scale(id: String) -> float:
	# No magnification: the Moon is small, planets are just points of light.
	match id:
		"moon":
			return 0.34
		"mars", "jupiter":
			return 0.28
		"orion_nebula", "andromeda":
			return 0.45
	return 0.55


func _refresh_target_sprite() -> void:
	# Re-pick the state texture (clear/blurry/dim) whenever the evaluation
	# changes - the build-time pick goes stale as soon as focus improves.
	if main_sprite == null:
		return
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = lens_center + _effect_offset(effect, quality) + drift_offset
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif effect == "dim" and quality in ["Poor", "Failed"] and not _city_glow_diffuse_target():
		base_alpha *= 0.55
	base_alpha = clampf(base_alpha + _dark_adaptation_alpha_bonus(), 0.0, 1.0)
	# Brightness floor: a solid target never fades below identifiability.
	base_alpha = maxf(base_alpha, _target_alpha_floor())
	if GameManager.current_level().get("observation_requirements", {}).has("exposure_max"):
		base_alpha = clampf(base_alpha * lerpf(0.42, 1.35, exposure_value), 0.0, 1.0)
	var path := _sprite_path_for_target(id, quality, effect)
	if path != current_sprite_path:
		current_sprite_path = path
		var texture: Texture2D = _load_target_texture(path)
		main_sprite.texture = texture
		main_sprite.size = texture.get_size()
		if blur_overlay == null:
			# No cross-fade overlay: ghosts share the base texture.
			ghost_a.texture = texture
			ghost_a.size = texture.get_size()
			ghost_b.texture = texture
			ghost_b.size = texture.get_size()
	if effect == "dim" and quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, main_sprite.modulate.a)
	else:
		var rgb := 1.0
		if quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
			# Contrast flattening for poor/failed quality (grain layer above
			# handles the noise half of this; this is the color-desaturation half).
			rgb *= 0.85
		if averted_vision_active and _is_diffuse_target():
			# Averted vision: subtle contour brighten, not a flat clean-up.
			rgb *= AVERTED_VISION_BRIGHTEN
		main_sprite.modulate = Color(rgb, rgb, rgb, main_sprite.modulate.a)
	_rebuild_quality_noise()


func _cloud_alpha_multiplier() -> float:
	# Clouds crossing the target darken it in real time - the 0.6s
	# re-evaluation loop (_advance_conditions) applies the same factor to
	# the actual quality math via extra_context["cloud_attenuation"].
	# Solid bright bodies (Moon, planets, stars) keep a floor so a cloud dims
	# them but can never turn them into an unreadable black disc. Faint diffuse
	# targets keep the full range - fading out IS their observing challenge.
	var raw := 1.0 - 0.75 * cond_cloud_atten
	if _is_diffuse_target():
		return raw
	return maxf(raw, 0.45)


func _target_alpha_floor() -> float:
	# Minimum brightness a lit target may reach after seeing/cloud/low-light so
	# it is always still IDENTIFIABLE. Diffuse deep-sky is allowed to go faint.
	if _is_diffuse_target():
		return 0.12
	return 0.55


func _city_glow_diffuse_target() -> bool:
	return _is_diffuse_target() and str(GameManager.current_environment().get("sky_brightness", "")).to_lower() == "city"


func _update_target_visuals() -> void:
	if main_sprite == null:
		return
	_refresh_target_sprite()
	var collimation_severity := _collimation_severity()
	if not requires_focus and collimation_severity <= 0.001:
		return
	# Defocus rendering, driven by SMOOTHED values so quantized inputs
	# (slider steps, quality tiers) never snap the image around.
	# NOTE: TextureRect scales from its top-left corner, so centering must
	# use size * display_scale, not the raw texture size.
	var spread := visual_focus_error * 130.0
	var cloud_mult := _cloud_alpha_multiplier()
	var ghost_alpha := clampf(visual_focus_error * 2.6, 0.0, 0.55) * visual_base_alpha * cloud_mult
	var collimation_blur := collimation_severity * (0.24 if _is_star_target() else 0.42)
	var combined_blur := maxf(blur_weight, collimation_blur)
	var origin := visual_target_center - main_sprite.size * display_scale * 0.5
	if blur_overlay != null:
		# Cross-fade: blurry photo dissolves into the sharp art.
		# At full defocus the sharp base must be completely hidden. Leaving even
		# a small clear-art alpha made some diffuse targets appear to switch back
		# to their sharp texture after the focus input stopped.
		main_sprite.modulate.a = visual_base_alpha * (1.0 - combined_blur) * cloud_mult
		blur_overlay.modulate.a = visual_base_alpha * combined_blur * cloud_mult
		blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5
	else:
		main_sprite.modulate.a = visual_base_alpha * clampf(1.0 - visual_focus_error * 1.1, 0.30, 1.0) * cloud_mult
	main_sprite.position = origin
	ghost_a.scale = Vector2.ONE * display_scale
	ghost_b.scale = Vector2.ONE * display_scale
	ghost_a.rotation = 0.0
	ghost_b.rotation = 0.0
	if bool(GameManager.current_level().get("chromatic_aberration", false)):
		# The separation remains visible at best focus. Extended targets need a
		# wider split than star points so the colored rims read at the same scale.
		var target_scale := 1.65 if _is_diffuse_target() else (1.30 if not _is_star_target() else 1.0)
		var chroma_offset := (12.0 + visual_focus_error * 20.0) * target_scale
		var chroma_alpha := 0.50 if _is_diffuse_target() else 0.68
		ghost_a.modulate = Color(1.0, 0.12, 0.18, visual_base_alpha * chroma_alpha * cloud_mult)
		ghost_b.modulate = Color(0.10, 0.36, 1.0, visual_base_alpha * chroma_alpha * cloud_mult)
		ghost_a.position = visual_target_center - ghost_a.size * display_scale * 0.5 + Vector2(chroma_offset, 0)
		ghost_b.position = visual_target_center - ghost_b.size * display_scale * 0.5 - Vector2(chroma_offset, 0)
	else:
		var coma_direction := _collimation_direction()
		var coma_tail := coma_direction * collimation_severity * (34.0 if _is_star_target() else 20.0)
		# Keep severe coma legible even when the quality verdict has already
		# dimmed the core; otherwise the player only sees "dark" and cannot
		# diagnose the mirror alignment problem from the star shape.
		var coma_alpha := collimation_severity * (0.48 if _is_star_target() else 0.30) * maxf(visual_base_alpha, 0.65) * cloud_mult
		ghost_a.modulate = Color(0.72, 0.88, 1.0, maxf(ghost_alpha, coma_alpha))
		ghost_a.position = visual_target_center - ghost_a.size * display_scale * 0.5 + Vector2(spread, spread * 0.6) + coma_tail
		ghost_b.modulate = Color(1.0, 0.78, 0.40, maxf(ghost_alpha * 0.8, coma_alpha * 0.55))
		ghost_b.position = visual_target_center - ghost_b.size * display_scale * 0.5 + Vector2(-spread * 0.8, spread * 0.4) + coma_tail * 0.48
		if _is_star_target() and collimation_severity > 0.01:
			ghost_a.pivot_offset = ghost_a.size * 0.5
			ghost_b.pivot_offset = ghost_b.size * 0.5
			ghost_a.rotation = coma_direction.angle()
			ghost_b.rotation = coma_direction.angle()
			ghost_a.scale = Vector2(display_scale * (1.0 + collimation_severity * 0.55), display_scale * (1.0 - collimation_severity * 0.12))
			ghost_b.scale = Vector2(display_scale * (1.0 + collimation_severity * 0.28), display_scale)


func _setup_turbulence_materials() -> void:
	# Only planets/moon get the UV-distortion shader (verdict 9): stars
	# flicker via alpha/position only, nebula/galaxy breathe via alpha only.
	turbulence_material_main = null
	turbulence_material_blur = null
	turbulence_material_ghost = null
	if _is_star_target() or _is_diffuse_target():
		return
	if main_sprite != null:
		var mat_main := ShaderMaterial.new()
		mat_main.shader = TURBULENCE_SHADER
		main_sprite.material = mat_main
		turbulence_material_main = mat_main
	if blur_overlay != null:
		var mat_blur := ShaderMaterial.new()
		mat_blur.shader = TURBULENCE_SHADER
		blur_overlay.material = mat_blur
		turbulence_material_blur = mat_blur
	if ghost_a != null:
		var mat_ghost := ShaderMaterial.new()
		mat_ghost.shader = TURBULENCE_SHADER
		ghost_a.material = mat_ghost
		ghost_b.material = mat_ghost
		turbulence_material_ghost = mat_ghost


func _add_sprite(parent: Control, texture: Texture2D, center: Vector2, alpha: float, sprite_scale: float = 1.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = texture.get_size()
	icon.scale = Vector2.ONE * sprite_scale
	icon.position = center - icon.size * sprite_scale * 0.5
	icon.modulate = Color(1, 1, 1, alpha)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _add_scope_stars(parent: Control, scope_center: Vector2) -> void:
	star_layer_nodes.clear()
	# All star dots live inside one container so drift (E2) can translate the
	# whole star field with a single position set - "the sky is turning",
	# not each star repositioned individually.
	star_layer_container = Control.new()
	star_layer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_layer_container.position = drift_offset
	parent.add_child(star_layer_container)
	# REAL sky: stars come from the deep HYG catalog (mag <= 8) projected
	# around the current aim direction - the same star field the player saw
	# at the sky observation deck, never a random sprinkle.
	var fov_radius := SCOPE_FOV_RADIUS_DEG
	var mag_limit := 8.0
	if observation_mode == "naked_eye":
		fov_radius = EYE_FOV_RADIUS_DEG
		mag_limit = 5.0
	else:
		# Light pollution raises the limiting magnitude: faint stars drown
		# in the bright sky first - "fewer, brighter dots survive".
		var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
		match sky_key:
			"city":
				mag_limit = 6.2
			"suburban":
				mag_limit = 7.2
	_add_real_sky_stars(star_layer_container, scope_center, fov_radius, mag_limit)


static var _deep_stars_cache: Array = []


func _load_deep_stars() -> Array:
	# Parsed once per session (static): {"stars": [[ra_hours, dec_deg, mag],
	# ...]} sorted by magnitude ascending (brightest first).
	if not _deep_stars_cache.is_empty():
		return _deep_stars_cache
	var file := FileAccess.open(DEEP_STARS_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var data: Dictionary = parsed
		_deep_stars_cache = data.get("stars", [])
	return _deep_stars_cache


func _current_aim() -> Vector2:
	# (azimuth, altitude) the telescope is pointed at. Capture tools / tests
	# enter without a sky aim - fall back to a fixed patch of real sky so the
	# view stays deterministic.
	var aim: Dictionary = GameManager.last_sky_aim
	if bool(aim.get("valid", false)):
		return Vector2(float(aim.get("azimuth", 150.0)), float(aim.get("altitude", 45.0)))
	return Vector2(150.0, 45.0)


func _add_real_sky_stars(parent: Control, scope_center: Vector2, fov_radius: float, mag_limit: float) -> void:
	var stars: Array = _load_deep_stars()
	if stars.is_empty():
		return
	var service := SkyPositionService.new()
	service.load_config()
	# Eyepiece star field uses the player's actual observing site too.
	var loc: Dictionary = GameManager.observing_location()
	var latitude: float = float(loc.get("lat", 34.0522))
	var longitude: float = float(loc.get("lon", -118.2437))
	var utc_now: Dictionary = Time.get_datetime_dict_from_system(true)
	var aim := _current_aim()
	var aim_alt_rad := deg_to_rad(aim.y)
	var az_scale := cos(aim_alt_rad)
	# Cheap declination pre-filter: the aim direction's declination band is
	# the only place FOV stars can live, so 41k catalog rows shrink to a few
	# hundred full alt/az computations.
	var lat_rad := deg_to_rad(latitude)
	var aim_dec_rad := asin(
		sin(aim_alt_rad) * sin(lat_rad)
		+ cos(aim_alt_rad) * cos(lat_rad) * cos(deg_to_rad(aim.x))
	)
	var aim_dec := rad_to_deg(aim_dec_rad)
	var dec_margin := fov_radius + 2.0
	var added := 0
	for star_value in stars:
		if not star_value is Array:
			continue
		var star: Array = star_value
		if star.size() < 3:
			continue
		var magnitude := float(star[2])
		if magnitude > mag_limit:
			break  # sorted by magnitude - nothing fainter can qualify
		if absf(float(star[1]) - aim_dec) > dec_margin:
			continue
		var alt_az: Dictionary = service.calculate_alt_az_from_ra_dec(
			float(star[0]), float(star[1]), latitude, longitude, utc_now
		)
		var d_alt := float(alt_az.get("altitude", -90.0)) - aim.y
		var d_az := wrapf(float(alt_az.get("azimuth", 0.0)) - aim.x, -180.0, 180.0) * az_scale
		if Vector2(d_az, d_alt).length() > fov_radius:
			continue
		var pos := scope_center + Vector2(d_az, -d_alt) / fov_radius * 205.0
		# Brightness from real magnitude: alpha lives in the rect color so
		# modulate stays free for the twinkle/dark-adaptation channel.
		var alpha := clampf(0.95 - magnitude * 0.088, 0.22, 0.95)
		var dot_size := 2.0
		if magnitude <= 1.5:
			dot_size = 4.0
		elif magnitude <= 3.5:
			dot_size = 3.0
		var star_rect := _rect(parent, pos - Vector2(dot_size, dot_size) * 0.5, Vector2(dot_size, dot_size), Color(0.88, 0.90, 0.97, alpha))
		star_layer_nodes.append(star_rect)
		added += 1
		if added >= 170:
			break  # brightest-first cap keeps the node count sane


func _add_cloud_layer(parent: Control, scope_center: Vector2) -> void:
	# Moving translucent wisps make the current cloud attenuation legible.
	# Their overlap is also what lowers the actual observation score.
	cloud_nodes.clear()
	cloud_velocities.clear()
	cloud_strengths.clear()
	if cloud_cover_level <= 0.0:
		return
	var tier := cloud_tier_index()  # 1 Thin / 2 Moderate / 3 Heavy
	var alpha_for_tier := 0.28
	match tier:
		2:
			alpha_for_tier = 0.5
		3:
			alpha_for_tier = 0.75

	cloud_veil = Panel.new()
	cloud_veil.position = scope_center - Vector2(218, 218)
	cloud_veil.size = Vector2(436, 436)
	var veil_style := StyleBoxFlat.new()
	# ABSORPTION, not reflection: at night an eyepiece cloud shows as the
	# field going DARK (starlight absorbed), never as a bright gray haze.
	veil_style.bg_color = Color(0.010, 0.014, 0.026)
	veil_style.set_corner_radius_all(218)
	cloud_veil.add_theme_stylebox_override("panel", veil_style)
	cloud_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_veil.modulate.a = 0.0
	parent.add_child(cloud_veil)

	var count: int = clampi(1 + tier, 2, 4)
	for i in range(count):
		var tex_path: String = CLOUD_TEXTURES[i % CLOUD_TEXTURES.size()]
		var texture: Texture2D = _load_target_texture(tex_path)
		var cloud := TextureRect.new()
		cloud.texture = texture
		cloud.size = texture.get_size()
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Near-black wisps: clouds OCCLUDE starlight (the target goes patchy
		# and dark as one drifts across), they do not glow white.
		cloud.modulate = Color(0.012, 0.016, 0.030, 0.50 + alpha_for_tier * 0.40)
		# Deterministic per-index seed: same level always drifts the same
		# way, but the field still fills the scope circle unevenly.
		var seed_angle: float = fmod(float(i) * 137.5 + effect_seed, 360.0) * PI / 180.0
		var start_offset := Vector2(cos(seed_angle), sin(seed_angle) * 0.5) * (60.0 + float(i) * 35.0)
		cloud.position = scope_center + start_offset - cloud.size * 0.5
		var speed: float = 8.0 + fmod(float(i) * 3.7, 8.0)
		var direction := Vector2(1.0, 0.15 + fmod(float(i), 3.0) * 0.05).normalized()
		if i % 2 == 1:
			direction.x = -direction.x
		cloud_velocities.append(direction * speed)
		cloud_strengths.append(alpha_for_tier)
		parent.add_child(cloud)
		cloud_nodes.append(cloud)


func _add_quality_noise(parent: Control, scope_center: Vector2) -> void:
	# Quality "grain" shader layer replaces the old white-dot noise system:
	# a single shimmering ColorRect masked to the scope circle, intensity
	# smoothly chased toward the current quality tier (never a hard cut).
	if observation_mode == "naked_eye":
		return
	grain_layer = ColorRect.new()
	grain_layer.position = scope_center - Vector2(218, 218)
	grain_layer.size = Vector2(436, 436)
	grain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GRAIN_SHADER
	mat.set_shader_parameter("intensity", 0.0)
	grain_layer.material = mat
	grain_material = mat
	parent.add_child(grain_layer)
	target_grain_intensity = _grain_intensity_for_quality(str(observation.get("quality", "Unknown")))
	grain_intensity = target_grain_intensity
	mat.set_shader_parameter("intensity", grain_intensity)


func _grain_intensity_for_quality(quality: String) -> float:
	match quality:
		"Excellent":
			return 0.0
		"Good":
			return 0.03
		"Fair":
			return 0.08
		"Poor":
			return 0.16
		"Failed":
			return 0.30
	return 0.0


func _rebuild_quality_noise() -> void:
	# Retarget the grain intensity toward the current quality tier; the
	# actual value is chased in _advance_conditions (no hard cuts).
	var quality := str(observation.get("quality", "Unknown"))
	target_grain_intensity = _grain_intensity_for_quality(quality)
	if grain_material == null:
		return
	if noise_quality == quality:
		return
	noise_quality = quality


# ------------------------------------------------------------------- logic


func _distractors_for(id: String) -> Array[String]:
	match id:
		"moon": return ["jupiter", "sirius"]
		"mars": return ["jupiter", "betelgeuse"]
		"jupiter": return ["mars", "moon"]
		"orion_nebula": return ["andromeda", "betelgeuse"]
		"andromeda": return ["orion_nebula", "sirius"]
		# Star vs star confusions teach color/context identification.
		"sirius": return ["canopus", "polaris"]
		"arcturus": return ["betelgeuse", "canopus"]
		"canopus": return ["sirius", "arcturus"]
		"alpha_centauri": return ["proxima", "sirius"]
		"proxima": return ["alpha_centauri", "betelgeuse"]
	return ["sirius", "betelgeuse"]


func _mystery_description(obj: Dictionary) -> Dictionary:
	var id := str(obj.get("id", ""))
	if _is_constellation_observation():
		return {"en": "a complete pattern of bright field stars", "zh": "一整组明亮的星群图形"}
	match id:
		"moon":
			if str(GameManager.current_level().get("variation", "")) == "lunar_detail_comparison":
				return {
					"en": "a resolved lunar disk with dark maria and a cratered bright rim",
					"zh": "能分辨暗色月海与明亮撞击坑边缘的月面圆盘"
				}
			return {"en": "bright round object", "zh": "明亮圆形目标"}
		"mars", "jupiter":
			return {"en": "small disk-like object", "zh": "小圆盘状目标"}
		"orion_nebula":
			return {"en": "faint cloud-like object", "zh": "淡淡云雾状目标"}
		"andromeda":
			return {"en": "faint oval glow", "zh": "淡淡椭圆光斑"}
	return {"en": "star-like object", "zh": "星点状目标"}


func _effect_offset(effect: String, quality: String) -> Vector2:
	if effect == "shaky":
		return Vector2(10, -7)
	match quality:
		"Fair":
			return Vector2(6, -4)
		"Poor":
			return Vector2(12, 8)
	return Vector2.ZERO


func _quality_alpha(quality: String) -> float:
	match quality:
		"Excellent": return 1.0
		"Good": return 0.92
		"Fair": return 0.62
		"Poor": return 0.36
		"Failed": return 0.14
	return 0.80


func _quality_color(quality: String) -> Color:
	match quality:
		"Excellent": return Color(0.35, 1.0, 0.55)
		"Good": return Color(0.58, 0.92, 0.36)
		"Fair": return Color(0.95, 0.82, 0.28)
		"Poor": return Color(1.0, 0.55, 0.28)
		"Failed": return Color(1.0, 0.24, 0.24)
	return COL_TEXT


func _add_unique(ids: Array[String], id: String) -> void:
	if id != "" and not ids.has(id):
		ids.append(id)


# ----------------------------------------------------------------- helpers


func _pixel_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 3, false)


func _gold_panel(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	return _styled_panel(parent, pos, size, COL_PANEL, COL_GOLD, 3, 3, true)


func _pixel_frame(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, corner: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 4, true, corner)


func _styled_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, border_width: int, radius: int, decorated: bool, corner_color: Color = COL_GOLD) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	if decorated:
		_corner(parent, pos, corner_color)
		_corner(parent, pos + Vector2(size.x - 14, 0), corner_color)
		_corner(parent, pos + Vector2(0, size.y - 14), corner_color)
		_corner(parent, pos + size - Vector2(14, 14), corner_color)
	return panel


func _corner(parent: Control, pos: Vector2, color: Color) -> void:
	_rect(parent, pos, Vector2(12, 4), color)
	_rect(parent, pos, Vector2(4, 12), color)


func _pixel_button(text: String, min_size: Vector2 = Vector2(194, 32), font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.15, 0.25), COL_BLUE_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.23, 0.34), COL_GOLD_LIGHT))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.15, 0.08), COL_GOLD_LIGHT))
	return button


func _hud_asset(path: String, rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load(path) as Texture2D
	icon.position = rect.position
	icon.size = rect.size
	add_child(icon)
	return icon


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _circle(parent: Control, pos: Vector2, size: Vector2, color: Color, border: Color, border_width: int) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(max(size.x, size.y) * 0.5))
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _plabel(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _plabel_on(self, text, pos, size, font_size, color, align)


func _plabel_on(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	# autowrap BEFORE size, otherwise the text's minimum width clamps the
	# label wider than the panel.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _on_language_changed() -> void:
	_build()
