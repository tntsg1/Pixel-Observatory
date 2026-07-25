extends RefCounted
class_name SpaceObservationModel

# Pure, deterministic JWST-class space-infrared observation model. No nodes, so
# tests and the space_observation UI drive the same logic. Every stage feeds the
# next, so the final science image really depends on the player's choices.
#
# It shares NOTHING with the ground-optical mechanics: no eyepiece, objective,
# magnification, manual focus knob, finder scope or collimation. Its own state
# lives under the space_observation namespace.
#
# Pipeline stages (mirrors the UI):
#   PLAN     instrument / filter / exposure / integrations / dither / priority
#   DEPLOY   ordered unfold of the observatory (first-time)
#   THERMAL  sun/earth/moon safe-attitude + sunshield + temperatures
#   GUIDE    guide-star pick + attitude drift + fine-guidance lock
#   WAVEFRONT segment alignment -> merge split star images -> low wavefront error
#   EXPOSE   photon accumulation, background, cosmic rays, saturation, frames
#   PROCESS  select/align/remove-CR/stack/background/SNR
#   FILTER   map bands to R/G/B, pick the science interpretation
#   REPORT   SNR / exposure quality / pointing / thermal / frames / confidence

# ------------------------------------------------------------------ target
var target_id := "andromeda"
var target_kind := "galaxy"          # galaxy | nebula | star | star_forming | distant_galaxy
var target_brightness := 0.55        # 0..1 (drives saturation vs weak-signal)
var best_instrument := "nircam"
var best_filter := "near_infrared"
var true_science := "dust_rich"      # correct scientific interpretation
var redshifted := false
var observation_seed := 0

# ------------------------------------------------------------------ 1. PLAN
const INSTRUMENTS := ["nircam", "nirspec", "miri", "fgs_niriss"]
const FILTERS := ["near_infrared", "mid_infrared", "dust", "star_forming", "emission_line"]
const DITHERS := ["none", "two_point", "three_point", "box"]
const PRIORITIES := ["survey", "balanced", "deep"]

var instrument := "nircam"
var filter := "near_infrared"
var exposure_time := 300.0           # seconds per frame
var integrations := 4                # number of frames
var dither := "three_point"
var priority := "balanced"

# ------------------------------------------------------------------ 2. DEPLOY
const DEPLOY_ORDER := ["solar_array", "sunshield", "primary_mirror", "secondary_mirror", "hinges", "actuators"]
var deployed: Array = []
var deploy_locked := false           # every step latched?

# ------------------------------------------------------------------ 3. THERMAL
var attitude_deg := 40.0             # observatory boresight vs the sun line
var sun_angle := 40.0
var earth_angle := 150.0
var moon_angle := 120.0
var hot_side_temp := 350.0           # K (sun side)
var cold_side_temp := 45.0           # K (mirror side)
const SAFE_MIN := 85.0               # sun must stay 85..135 deg off boresight
const SAFE_MAX := 135.0
const COLD_TARGET := 40.0            # optics must reach ~40 K (7 K extra for MIRI)
var thermal_target_deg := 108.0      # target-specific roll solution
var thermal_tolerance_deg := 9.0
var thermal_hold_required := 1.8
var thermal_hold_progress := 0.0
var thermal_locked := false
var thermal_drift_rate := 0.0        # deg/s, target-specific solar-pressure drift

# ------------------------------------------------------------------ 4. GUIDE
var guide_stars: Array = []          # each {id, brightness, offset, usable}
var chosen_guide := -1
var pointing_error := 8.0            # arcsec
var drift_rate := 0.9                # arcsec/s before lock
var guide_locked := false

# ------------------------------------------------------------------ 5. WAVEFRONT
var segment_alignment := 0.25        # 0..1
var wavefront_error_nm := 900.0      # target < 150 nm
var calibration_progress := 0.0

# ------------------------------------------------------------------ 6. EXPOSE
var frames: Array = []               # each {signal, cosmic_ray, saturated, kept}
var acquired := false

# ------------------------------------------------------------------ 7. PROCESS
var frames_aligned := false
var cosmic_rays_removed := false
var stacked := false
var background_subtracted := false

# ------------------------------------------------------------------ 8. FILTER
var channel_map := {"R": "", "G": "", "B": ""}
var chosen_science := ""


func configure(profile: Dictionary) -> void:
	target_id = str(profile.get("target_id", target_id))
	target_kind = str(profile.get("kind", target_kind))
	target_brightness = float(profile.get("brightness", target_brightness))
	best_instrument = str(profile.get("best_instrument", best_instrument))
	best_filter = str(profile.get("best_filter", best_filter))
	true_science = str(profile.get("science", true_science))
	redshifted = bool(profile.get("redshifted", false))
	observation_seed = int(profile.get("guide_seed", 0))
	if observation_seed == 0:
		for index in range(target_id.length()):
			observation_seed += target_id.unicode_at(index) * (index + 3)
	observation_seed = absi(observation_seed)
	# starting (deliberately non-ideal) plan
	instrument = str(profile.get("start_instrument", "nircam"))
	filter = str(profile.get("start_filter", "near_infrared"))
	exposure_time = float(profile.get("start_exposure", 120.0))
	integrations = int(profile.get("start_integrations", 2))
	dither = str(profile.get("start_dither", "none"))
	priority = "balanced"
	deployed.clear()
	deploy_locked = false
	_configure_thermal_challenge(profile)
	_build_guide_stars(profile)
	segment_alignment = 0.25
	wavefront_error_nm = 900.0
	calibration_progress = 0.0
	frames.clear()
	acquired = false
	frames_aligned = false
	cosmic_rays_removed = false
	stacked = false
	background_subtracted = false
	channel_map = {"R": "", "G": "", "B": ""}
	chosen_science = ""


# ============================================================= 1. PLANNING
func plan_hint(field: String, value: String) -> Dictionary:
	# Every option says what it suits / enhances / sacrifices plus its SNR & time
	# cost. Text is bilingual (the UI picks the language) so neither mode bleeds.
	var t: Dictionary = _HINTS.get(field, {}).get(value, {})
	return {
		"suits_en": t.get("s_en", ""), "suits_zh": t.get("s_zh", ""),
		"enhances_en": t.get("e_en", ""), "enhances_zh": t.get("e_zh", ""),
		"sacrifices_en": t.get("x_en", ""), "sacrifices_zh": t.get("x_zh", ""),
		"snr": t.get("snr", 1.0), "time": t.get("time", 1.0),
	}


const _HINTS := {
	"instrument": {
		"nircam": {"s_en": "near-IR imaging of stars & galaxies", "s_zh": "恒星与星系的近红外成像", "e_en": "sharp structure", "e_zh": "清晰结构", "x_en": "no spectrum", "x_zh": "没有光谱", "snr": 1.0, "time": 1.0},
		"nirspec": {"s_en": "spectra: composition, motion, redshift", "s_zh": "光谱：成分、运动、红移", "e_en": "spectral lines", "e_zh": "谱线", "x_en": "no wide image", "x_zh": "没有宽场图像", "snr": 0.85, "time": 1.2},
		"miri": {"s_en": "mid-IR cold dust & molecules", "s_zh": "中红外冷尘埃与分子", "e_en": "cold dust", "e_zh": "冷尘埃", "x_en": "needs 7 K, slower", "x_zh": "需要 7K，更慢", "snr": 0.8, "time": 1.4},
		"fgs_niriss": {"s_en": "precise guiding + niche near-IR", "s_zh": "精确导星 + 特定近红外", "e_en": "pointing", "e_zh": "指向", "x_en": "weak imaging", "x_zh": "成像较弱", "snr": 0.7, "time": 1.0},
	},
	"filter": {
		"near_infrared": {"s_en": "young stars, galaxies", "s_zh": "年轻恒星、星系", "e_en": "stellar cores", "e_zh": "恒星核心", "x_en": "misses coldest dust", "x_zh": "看不到最冷的尘埃", "snr": 1.0, "time": 1.0},
		"mid_infrared": {"s_en": "cold dust, distant galaxies", "s_zh": "冷尘埃、遥远星系", "e_en": "cold structure", "e_zh": "冷结构", "x_en": "brighter thermal background", "x_zh": "热背景更强", "snr": 0.85, "time": 1.2},
		"dust": {"s_en": "dust lanes & clouds", "s_zh": "尘埃带与尘埃云", "e_en": "dust", "e_zh": "尘埃", "x_en": "faint on hot stars", "x_zh": "对高温恒星较弱", "snr": 0.9, "time": 1.0},
		"star_forming": {"s_en": "star-forming knots", "s_zh": "恒星形成结点", "e_en": "young nurseries", "e_zh": "年轻恒星苗圃", "x_en": "loses old stars", "x_zh": "丢失老年恒星", "snr": 0.9, "time": 1.0},
		"emission_line": {"s_en": "hot gas emission", "s_zh": "高温气体发射", "e_en": "ionised gas", "e_zh": "电离气体", "x_en": "narrow, needs more time", "x_zh": "窄带，需要更多时间", "snr": 0.8, "time": 1.3},
	},
	"dither": {
		"none": {"s_en": "fastest", "s_zh": "最快", "e_en": "nothing", "e_zh": "无", "x_en": "keeps bad pixels & gaps", "x_zh": "保留坏点与缝隙", "snr": 0.85, "time": 1.0},
		"two_point": {"s_en": "basic defect removal", "s_zh": "基础缺陷去除", "e_en": "cleaner", "e_zh": "更干净", "x_en": "small time cost", "x_zh": "少量时间成本", "snr": 1.0, "time": 1.1},
		"three_point": {"s_en": "good defect + gap filling", "s_zh": "良好缺陷与缝隙填补", "e_en": "clean image", "e_zh": "干净图像", "x_en": "more time", "x_zh": "更多时间", "snr": 1.08, "time": 1.2},
		"box": {"s_en": "best sampling", "s_zh": "最佳采样", "e_en": "sharpest", "e_zh": "最锐利", "x_en": "most time", "x_zh": "时间最多", "snr": 1.12, "time": 1.35},
	},
}


func instrument_match() -> float:
	return 1.0 if instrument == best_instrument else 0.55


func filter_match() -> float:
	return 1.0 if filter == best_filter else 0.5


func planned_total_time() -> float:
	var dh: Dictionary = plan_hint("dither", dither)
	return exposure_time * float(integrations) * float(dh.get("time", 1.0))


func saturates() -> bool:
	# a bright target with very long single exposures overexposes
	return exposure_time > 500.0 and target_brightness > 0.7


func underexposed() -> bool:
	return exposure_time * float(integrations) < 300.0


# ============================================================= 2. DEPLOYMENT
func can_deploy(step: String) -> bool:
	if deployed.has(step):
		return false
	var idx := DEPLOY_ORDER.find(step)
	if idx < 0:
		return false
	return idx == deployed.size()     # must be the next in order


func deploy(step: String) -> bool:
	if not can_deploy(step):
		return false
	deployed.append(step)
	if deployed.size() == DEPLOY_ORDER.size():
		deploy_locked = true
	return true


func deploy_blocked_reason(step: String) -> String:
	if deployed.has(step):
		return "already_deployed"
	var idx := DEPLOY_ORDER.find(step)
	if idx < 0:
		return "unknown"
	if idx > deployed.size():
		return "out_of_order"          # needs the previous stage first
	return ""


func fully_deployed() -> bool:
	return deploy_locked


# ============================================================= 3. THERMAL
func _configure_thermal_challenge(profile: Dictionary) -> void:
	var seed := absi(target_id.hash())
	thermal_target_deg = clampf(
		float(profile.get("thermal_target_angle", 96.0 + float(seed % 27))),
		92.0,
		128.0
	)
	thermal_tolerance_deg = clampf(
		float(profile.get("thermal_tolerance", 6.0 if best_instrument == "miri" else 9.0)),
		4.0,
		14.0
	)
	thermal_hold_required = clampf(float(profile.get("thermal_hold_seconds", 2.0)), 1.2, 3.5)
	var drift_sign := -1.0 if seed % 2 == 0 else 1.0
	thermal_drift_rate = drift_sign * (0.45 + float(seed % 5) * 0.14)
	thermal_hold_progress = 0.0
	thermal_locked = false

	attitude_deg = clampf(float(profile.get("start_attitude", 40.0)), 0.0, 180.0)
	# Several old profiles started inside the broad 85-135 degree safety cone,
	# which made every later thermal stage a free confirm. Start each new target
	# outside its narrower roll corridor while retaining the profile's direction.
	if attitude_in_corridor(attitude_deg):
		var side := -1.0 if seed % 2 == 0 else 1.0
		attitude_deg = clampf(
			thermal_target_deg + side * (thermal_tolerance_deg + 20.0 + float(seed % 8)),
			0.0,
			180.0
		)
	_recompute_thermal(true)


func rotate_to(attitude: float) -> void:
	attitude_deg = clampf(attitude, 0.0, 180.0)
	if not attitude_in_corridor(attitude_deg):
		thermal_locked = false
	_recompute_thermal(false)


func _recompute_thermal(snap_temperature := false) -> void:
	sun_angle = attitude_deg
	# earth & moon trail the sun line; they stay roughly opposite the cold side
	earth_angle = wrapf(attitude_deg + 110.0, 0.0, 180.0)
	moon_angle = wrapf(attitude_deg + 80.0, 0.0, 180.0)
	if snap_temperature:
		cold_side_temp = thermal_equilibrium_temp()
		hot_side_temp = thermal_hot_equilibrium_temp()


func step_thermal(delta: float) -> void:
	if thermal_locked:
		return
	attitude_deg = clampf(attitude_deg + thermal_drift_rate * delta, 0.0, 180.0)
	_recompute_thermal(false)
	var cold_goal := thermal_equilibrium_temp()
	var hot_goal := thermal_hot_equilibrium_temp()
	var cold_speed := 72.0 if cold_goal < cold_side_temp else 24.0
	cold_side_temp = move_toward(cold_side_temp, cold_goal, cold_speed * delta)
	hot_side_temp = move_toward(hot_side_temp, hot_goal, 32.0 * delta)
	if attitude_in_corridor() and thermal_ok():
		thermal_hold_progress = minf(thermal_hold_required, thermal_hold_progress + delta)
	else:
		thermal_hold_progress = maxf(0.0, thermal_hold_progress - delta * 1.8)
	thermal_locked = thermal_hold_progress >= thermal_hold_required


func thermal_equilibrium_temp() -> float:
	var global_penalty := 0.0
	if not sun_safe():
		global_penalty = minf(absf(attitude_deg - clampf(attitude_deg, SAFE_MIN, SAFE_MAX)), 90.0) * 2.4
	var roll_penalty := maxf(0.0, attitude_error() - active_thermal_tolerance()) * 0.85
	return COLD_TARGET + global_penalty + roll_penalty


func thermal_hot_equilibrium_temp() -> float:
	return 300.0 + (85.0 - absf(attitude_deg - 90.0)) * 0.4


func thermal_corridor_min() -> float:
	return maxf(SAFE_MIN, thermal_target_deg - active_thermal_tolerance())


func thermal_corridor_max() -> float:
	return minf(SAFE_MAX, thermal_target_deg + active_thermal_tolerance())


func active_thermal_tolerance() -> float:
	return minf(thermal_tolerance_deg, 6.0) if instrument == "miri" else thermal_tolerance_deg


func attitude_error() -> float:
	return absf(attitude_deg - thermal_target_deg)


func attitude_in_corridor(value := NAN) -> bool:
	var angle := attitude_deg if is_nan(value) else float(value)
	return angle >= thermal_corridor_min() and angle <= thermal_corridor_max()


func thermal_hold_ratio() -> float:
	return clampf(thermal_hold_progress / maxf(thermal_hold_required, 0.01), 0.0, 1.0)


func sun_safe() -> bool:
	return sun_angle >= SAFE_MIN and sun_angle <= SAFE_MAX


func thermal_ok() -> bool:
	var limit := COLD_TARGET + (4.0 if instrument == "miri" else 8.0)
	return sun_safe() and attitude_in_corridor() and cold_side_temp <= limit


func thermal_stability() -> float:
	var over := maxf(0.0, cold_side_temp - COLD_TARGET)
	return clampf(1.0 - over / 60.0, 0.0, 1.0)


func safe_to_observe() -> bool:
	return sun_safe() and attitude_in_corridor() and thermal_ok()


# ============================================================= 4. GUIDE STAR
func _build_guide_stars(profile: Dictionary) -> void:
	guide_stars.clear()
	var preset: Variant = profile.get("guide_stars", [])
	if typeof(preset) == TYPE_ARRAY and not (preset as Array).is_empty():
		for e in preset:
			guide_stars.append(e)
	else:
		# Each observation receives a deterministic detector field. The best
		# guide therefore moves between sensor quadrants instead of GS-2 being
		# the answer in every mission, while reloading a mission stays stable.
		var seed := int(profile.get("guide_seed", 0))
		for index in range(target_id.length()):
			seed += target_id.unicode_at(index) * (index + 3)
		seed = absi(seed)
		var best_index := seed % 4
		var secondary_index := (best_index + 2) % 4
		var dim_index := (best_index + 1) % 4
		var off_detector_index := (best_index + 3) % 4
		for index in range(4):
			var star := {
				"id": "GS-%d" % (index + 1),
				"brightness": 0.45,
				"offset": 5.0,
				"usable": false,
				"reason": "unusable",
			}
			if index == best_index:
				star["brightness"] = 0.82 + float(seed % 7) * 0.01
				star["offset"] = 1.4 + float(seed % 4) * 0.18
				star["usable"] = true
				star["reason"] = "best"
			elif index == secondary_index:
				star["brightness"] = 0.62 + float(seed % 5) * 0.015
				star["offset"] = 3.0 + float(seed % 3) * 0.25
				star["usable"] = true
				star["reason"] = "acceptable"
			elif index == dim_index:
				star["brightness"] = 0.22 + float(seed % 4) * 0.015
				star["offset"] = 4.2
				star["reason"] = "too_dim"
			elif index == off_detector_index:
				star["brightness"] = 0.88
				star["offset"] = 13.0 + float(seed % 4)
				star["reason"] = "off_detector"
			guide_stars.append(star)
	chosen_guide = -1
	pointing_error = 8.0
	drift_rate = 0.9
	guide_locked = false


func choose_guide_star(index: int) -> bool:
	if index < 0 or index >= guide_stars.size():
		return false
	chosen_guide = index
	var gs: Dictionary = guide_stars[index]
	if not bool(gs.get("usable", false)):
		# dim or off-detector stars cannot hold a lock
		drift_rate = 1.4
		guide_locked = false
		return false
	drift_rate = lerpf(0.6, 0.05, float(gs.get("brightness", 0.5)))
	pointing_error = float(gs.get("offset", 3.0)) + 4.0
	return true


func nudge_pointing(delta: float) -> void:
	pointing_error = maxf(0.0, pointing_error + delta)


func step_guiding(dt: float) -> void:
	# fine guidance pulls the error down only if a usable star is chosen
	if chosen_guide < 0:
		return
	var gs: Dictionary = guide_stars[chosen_guide]
	if not bool(gs.get("usable", false)):
		pointing_error += drift_rate * dt      # drifts away
		return
	pointing_error = maxf(0.0, pointing_error - (2.0 - drift_rate) * dt * 3.0)
	guide_locked = pointing_error <= 1.2


func guide_quality() -> float:
	if chosen_guide < 0:
		return 0.0
	var gs: Dictionary = guide_stars[chosen_guide]
	if not bool(gs.get("usable", false)):
		return 0.1
	return clampf(float(gs.get("brightness", 0.5)) - float(gs.get("offset", 3.0)) / 30.0, 0.0, 1.0)


# ============================================================= 5. WAVEFRONT
func align_step(amount: float) -> void:
	set_segment_alignment(segment_alignment + amount)


func set_segment_alignment(value: float) -> void:
	segment_alignment = clampf(value, 0.0, 1.0)
	wavefront_error_nm = lerpf(900.0, 60.0, segment_alignment)
	calibration_progress = clampf(segment_alignment, 0.0, 1.0)


func psf_sharpness() -> float:
	# split star images merge into one sharp peak as alignment improves
	return clampf(1.0 - wavefront_error_nm / 900.0, 0.0, 1.0)


func wavefront_ok() -> bool:
	return wavefront_error_nm <= 150.0


# ============================================================= 6. EXPOSURE
func acquire() -> void:
	frames.clear()
	var per_frame := clampf(exposure_time / 300.0, 0.2, 2.0)
	var dh: Dictionary = plan_hint("dither", dither)
	var base_signal := per_frame * target_brightness * instrument_match() * filter_match() * float(dh.get("snr", 1.0))
	# A compact detector review exercise. Standard four-frame integrations carry
	# four different outcomes: clean data, two repairable transient events, and
	# one unrecoverable guide smear. Their order changes per mission.
	var event_cycle := ["clean", "cosmic_streak", "hot_pixels", "guide_smear"]
	var event_offset := observation_seed % event_cycle.size()
	for i in range(integrations):
		var saturated := saturates()
		var event_type := "saturation_bloom" if saturated else str(event_cycle[(i + event_offset) % event_cycle.size()])
		if i >= event_cycle.size() and not saturated:
			event_type = "cosmic_shower" if i % 2 == 0 else "amplifier_glow"
		var repairable := event_type in ["cosmic_streak", "hot_pixels", "cosmic_shower", "amplifier_glow"]
		var unusable := event_type in ["guide_smear", "saturation_bloom"]
		var cosmic := event_type in ["cosmic_streak", "hot_pixels", "cosmic_shower"]
		var sig := base_signal * (0.6 + 0.4 * float(i + 1) / float(integrations))
		frames.append({
			"signal": sig,
			"event_type": event_type,
			"event_seed": observation_seed + i * 37,
			"repairable": repairable,
			"unusable": unusable,
			"cosmic_ray": cosmic,
			"saturated": saturated,
			"kept": true,
		})
	acquired = true


func photon_progress(elapsed_ratio: float) -> Dictionary:
	# for the animated acquisition bar: signal rises, noise falls with sqrt(frames)
	var f := clampf(elapsed_ratio, 0.0, 1.0)
	var shown := int(round(f * integrations))
	return {
		"frames_done": shown,
		"signal": clampf(f * target_brightness * 1.1, 0.0, 1.0),
		"noise": clampf(0.6 / sqrt(maxf(1.0, f * integrations)), 0.0, 1.0),
		"cosmic_this_frame": (shown % 3 == 0 and shown > 0),
	}


func exposure_quality() -> float:
	if saturates():
		return 0.35
	if underexposed():
		return 0.45
	return clampf(0.7 + 0.3 * clampf(float(integrations) / 6.0, 0.0, 1.0), 0.0, 1.0)


# ============================================================= 7. PROCESSING
func toggle_keep(index: int, keep: bool) -> void:
	if index >= 0 and index < frames.size():
		frames[index]["kept"] = keep


func kept_frames() -> int:
	var n := 0
	for f in frames:
		if bool(f.get("kept", false)):
			n += 1
	return n


func frame_should_keep(frame: Dictionary) -> bool:
	return not bool(frame.get("unusable", false))


func frame_review_ready() -> bool:
	if frames.is_empty():
		return false
	for frame_value in frames:
		var frame: Dictionary = frame_value
		if bool(frame.get("kept", false)) != frame_should_keep(frame):
			return false
	return kept_frames() > 0


func frame_selection_quality() -> float:
	if frames.is_empty():
		return 0.0
	var correct := 0
	for frame_value in frames:
		var frame: Dictionary = frame_value
		if bool(frame.get("kept", false)) == frame_should_keep(frame):
			correct += 1
	return float(correct) / float(frames.size())


func align_frames() -> void:
	frames_aligned = true


func remove_cosmic_rays() -> void:
	cosmic_rays_removed = true


func stack() -> void:
	stacked = true


func subtract_background() -> void:
	background_subtracted = true


func cosmic_ray_rejection() -> float:
	if not cosmic_rays_removed:
		return 0.0
	# rejection also credits dropping the worst frames manually
	var cr_frames := 0
	var dropped := 0
	for f in frames:
		if bool(f.get("cosmic_ray", false)):
			cr_frames += 1
			if not bool(f.get("kept", false)):
				dropped += 1
	var auto := 0.7
	if cr_frames > 0:
		auto += 0.3 * float(dropped) / float(cr_frames)
	return clampf(auto, 0.0, 1.0)


func pointing_accuracy() -> float:
	return clampf(1.0 - pointing_error / 8.0, 0.0, 1.0) if guide_locked else clampf(0.4 - pointing_error / 20.0, 0.0, 0.4)


func snr() -> float:
	if not acquired:
		return 0.0
	var kept := kept_frames()
	if kept == 0:
		return 0.0
	var chain := 0.0
	chain += 0.20 * exposure_quality()
	chain += 0.18 * pointing_accuracy()
	chain += 0.16 * thermal_stability()
	chain += 0.16 * psf_sharpness()
	chain += 0.10 * guide_quality()
	chain += 0.10 * (1.0 if stacked else 0.3)
	chain += 0.10 * cosmic_ray_rejection()
	var stack_gain := sqrt(float(kept)) if stacked else 1.0
	# the chosen instrument + filter set how much real target signal is collected,
	# so a poor match genuinely lowers the achievable SNR
	var signal_factor := 0.5 + 0.5 * instrument_match() * filter_match()
	var raw := chain * stack_gain * 12.0 * signal_factor
	raw *= lerpf(0.55, 1.0, frame_selection_quality())
	if saturates():
		raw *= 0.5
	if not background_subtracted:
		raw *= 0.8
	return clampf(raw, 0.0, 99.0)


func processing_ready() -> bool:
	return frame_review_ready() and frames_aligned and cosmic_rays_removed and stacked and background_subtracted


# ============================================================= 8. FILTER MAP
func set_channel(channel: String, filter_id: String) -> void:
	if channel_map.has(channel):
		channel_map[channel] = filter_id


func mapping_complete() -> bool:
	return channel_map["R"] != "" and channel_map["G"] != "" and channel_map["B"] != "" \
		and channel_map["R"] != channel_map["G"] and channel_map["G"] != channel_map["B"] and channel_map["R"] != channel_map["B"]


func science_options() -> Array:
	return ["dust_rich", "star_forming", "old_stellar", "hot_gas", "distant_galaxy"]


func choose_science(option: String) -> void:
	chosen_science = option


func science_correct() -> bool:
	return chosen_science == true_science


# ============================================================= REPORT
func spectral_confidence() -> float:
	var c := 0.5 * filter_match() + 0.3 * clampf(snr() / 20.0, 0.0, 1.0) + 0.2 * psf_sharpness()
	if mapping_complete():
		c += 0.1
	return clampf(c, 0.0, 1.0)


func report() -> Dictionary:
	return {
		"target_id": target_id,
		"snr": snr(),
		"exposure_quality": exposure_quality(),
		"pointing_accuracy": pointing_accuracy(),
		"thermal_stability": thermal_stability(),
		"frame_count": kept_frames(),
		"cosmic_ray_rejection": cosmic_ray_rejection(),
		"filter": filter,
		"instrument": instrument,
		"scientific_confidence": spectral_confidence(),
		"science_finding": chosen_science,
		"science_correct": science_correct(),
		"success": snr() >= 10.0 and science_correct() and safe_to_observe(),
	}
