extends RefCounted
class_name RadioSignalModel

# Pure, deterministic FAST radio-observation model - no nodes, no rendering, so
# it can be driven headlessly by tests and by the radio_observation UI alike.
#
# The five real concepts a radio astronomer uses (none of them optical):
#   1. Feed-cabin pointing with inertia   -> az/alt with velocity + damping
#   2. Frequency tuning                    -> a (centre, bandwidth) window over a
#                                             live spectrum of noise + RFI + source
#   3. RFI discrimination                  -> classify man-made peaks vs the source
#   4. Pulsar folding                      -> trial period + dispersion measure
#   5. Integration                         -> longer integration raises SNR
#
# Everything derives from the target profile, so different targets/levels play
# differently without any new code.

# ---- target profile ----
var target_id := "pulsar_b0329"
var target_kind := "pulsar"          # pulsar | frb | hydrogen | galaxy | solar | unknown
var target_display_name := "PSR B0329+54"
var candidate_model := "PSR B0329"
var true_azimuth := 145.0
var true_altitude := 52.0
var true_period_ms := 714.0          # pulse period (pulsars only)
var true_dm := 26.8                  # dispersion measure (pc/cm^3)
var true_center_mhz := 1250.0        # source band centre
var true_bandwidth_mhz := 90.0
var source_strength := 1.0           # relative flux (weak-signal nights < 1)
var rfi_peaks: Array = []            # each: {mhz, strength, is_rfi:bool, source}
var challenge := "balanced"
var narrative_result_en := "A stable repeating pulse matches the selected source."
var narrative_result_zh := "稳定重复的脉冲与所选目标相符。"

# ---- feed cabin state ----
var azimuth := 150.0
var altitude := 40.0
var az_velocity := 0.0
var alt_velocity := 0.0
var cable_tension := 0.30            # 0..1, rises with speed
var aim_drift_deg_s := 0.0
var aim_drift_phase := 0.0
var aim_disturbance_interval_s := 10.0
var aim_disturbance_timer_s := 10.0
var aim_disturbance_remaining_s := 0.0
var aim_disturbance_vector := Vector2.ZERO
var aim_disturbance_serial := 0
var damping_scale := 1.0
var acceleration_scale := 1.0
const MAX_SLEW := 18.0               # deg/s cap
const DAMPING := 2.4                 # velocity damping per second
const ACCEL := 26.0                  # deg/s^2 per nudge unit
const LOCK_TOLERANCE := 2.2          # deg pointing error to count as on-target
const STABLE_SPEED := 1.4            # deg/s below which pointing is "settled"
const FAST_MAX_ZENITH_ANGLE_DEG := 40.0
const AIM_DISTURBANCE_DURATION_S := 0.72

# ---- frequency window ----
var window_center_mhz := 1400.0
var window_bandwidth_mhz := 80.0
const BAND_MIN := 1000.0
const BAND_MAX := 1500.0

# ---- folding / integration ----
var trial_period_ms := 500.0
var trial_dm := 0.0
var true_phase := 0.5
var trial_phase := 0.5
var pulse_component_separation := 0.072
var pulse_secondary_strength := 0.62
var integration_s := 0.0
var required_integration_s := 180.0
var report_snr_threshold := 8.0
var period_threshold := 0.60
var dm_threshold := 0.60
var rfi_threshold := 0.75
const MAX_INTEGRATION := 600.0

# ---- classification bookkeeping ----
var classifications := {}            # index -> "rfi" | "source"


func configure(profile: Dictionary) -> void:
	target_id = str(profile.get("target_id", target_id))
	target_kind = str(profile.get("kind", target_kind))
	target_display_name = str(profile.get("target_name", target_id.to_upper().replace("_", " ")))
	var inferred_candidate := target_id.to_upper().replace("PULSAR_", "PSR ").replace("_", " ")
	candidate_model = str(profile.get("candidate_model", inferred_candidate))
	true_azimuth = wrapf(float(profile.get("azimuth", true_azimuth)), 0.0, 360.0)
	# FAST can illuminate a 300 m paraboloid only inside its 40 degree
	# zenith-angle envelope. Clamp legacy profiles here so an old save cannot
	# create several visually identical targets on the unreachable outer rim.
	true_altitude = clampf(
		float(profile.get("altitude", true_altitude)),
		90.0 - FAST_MAX_ZENITH_ANGLE_DEG,
		88.0
	)
	true_period_ms = float(profile.get("period_ms", true_period_ms))
	true_dm = float(profile.get("dm", true_dm))
	true_center_mhz = float(profile.get("center_mhz", true_center_mhz))
	true_bandwidth_mhz = float(profile.get("bandwidth_mhz", true_bandwidth_mhz))
	source_strength = float(profile.get("source_strength", source_strength))
	challenge = str(profile.get("challenge", "balanced"))
	narrative_result_en = str(profile.get("result_en", narrative_result_en))
	narrative_result_zh = str(profile.get("result_zh", narrative_result_zh))
	aim_drift_deg_s = float(profile.get("aim_drift_deg_s", 0.0))
	aim_disturbance_interval_s = maxf(6.0, float(profile.get("aim_disturbance_interval_s", 10.0)))
	damping_scale = maxf(0.35, float(profile.get("damping_scale", 1.0)))
	acceleration_scale = maxf(0.35, float(profile.get("acceleration_scale", 1.0)))
	required_integration_s = clampf(float(profile.get("required_integration_s", 180.0)), 30.0, MAX_INTEGRATION)
	report_snr_threshold = maxf(4.0, float(profile.get("snr_threshold", 8.0)))
	period_threshold = clampf(float(profile.get("period_threshold", 0.60)), 0.35, 0.95)
	dm_threshold = clampf(float(profile.get("dm_threshold", 0.60)), 0.35, 0.95)
	rfi_threshold = clampf(float(profile.get("rfi_threshold", 0.75)), 0.50, 1.0)
	# Campaign profiles may provide an absolute start point so each observing
	# session has a distinct cable path. Offset fields remain supported for old
	# saves and free-observation catalog entries.
	azimuth = wrapf(
		float(profile.get(
			"start_azimuth",
			true_azimuth + float(profile.get("start_offset_az", 24.0))
		)),
		0.0,
		360.0
	)
	altitude = clampf(
		float(profile.get(
			"start_altitude",
			true_altitude - float(profile.get("start_offset_alt", 16.0))
		)),
		90.0 - FAST_MAX_ZENITH_ANGLE_DEG,
		88.0
	)
	az_velocity = 0.0
	alt_velocity = 0.0
	window_center_mhz = float(profile.get("start_center_mhz", 1400.0))
	window_bandwidth_mhz = float(profile.get("start_bandwidth_mhz", window_bandwidth_mhz))
	trial_period_ms = float(profile.get("start_period_ms", 500.0))
	trial_dm = float(profile.get("start_dm", 0.0))
	true_phase = fposmod(float(profile.get("pulse_phase", 0.5)), 1.0)
	pulse_component_separation = clampf(float(profile.get("pulse_component_separation", 0.072)), 0.025, 0.16)
	pulse_secondary_strength = clampf(float(profile.get("pulse_secondary_strength", 0.62)), 0.25, 0.90)
	# Start with a modest, readable phase residual unless a level explicitly
	# supplies its own. This makes the arrival gate an actual operation rather
	# than opening already solved.
	trial_phase = fposmod(
		float(profile.get("start_phase", true_phase + float(profile.get("start_phase_offset", 0.16)))),
		1.0
	)
	integration_s = 0.0
	aim_drift_phase = 0.0
	aim_disturbance_timer_s = aim_disturbance_interval_s
	aim_disturbance_remaining_s = 0.0
	aim_disturbance_vector = Vector2.ZERO
	aim_disturbance_serial = 0
	classifications.clear()
	_build_rfi(profile)


func _build_rfi(profile: Dictionary) -> void:
	rfi_peaks.clear()
	# The source itself is a "peak" the player must keep (is_rfi = false).
	rfi_peaks.append({"mhz": true_center_mhz, "strength": 0.85 * source_strength,
		"is_rfi": false, "source": "celestial", "pattern": "pulse_train"})
	# Deterministic man-made interference - seeded off the target id length so
	# each target has its own RFI environment without Math.random().
	var seed: Variant = profile.get("rfi", [])
	if typeof(seed) == TYPE_ARRAY and not (seed as Array).is_empty():
		for entry in seed:
			var e: Dictionary = entry
			rfi_peaks.append({"mhz": float(e.get("mhz", 1100.0)), "strength": float(e.get("strength", 0.7)),
				"is_rfi": true, "source": str(e.get("source", "rfi")),
				"pattern": str(e.get("pattern", _pattern_for_source(str(e.get("source", "rfi")))))})
		return
	var presets := [
		{"mhz": 1090.0, "strength": 0.95, "source": "radar", "pattern": "fixed_narrow"},
		{"mhz": 1176.0, "strength": 0.80, "source": "satellite", "pattern": "periodic"},
		{"mhz": 1310.0, "strength": 0.72, "source": "phone", "pattern": "burst"},
		{"mhz": 1447.0, "strength": 0.66, "source": "powerline", "pattern": "comb"},
	]
	for p in presets:
		rfi_peaks.append({"mhz": float(p["mhz"]), "strength": float(p["strength"]),
			"is_rfi": true, "source": str(p["source"]), "pattern": str(p["pattern"])})


func _pattern_for_source(source: String) -> String:
	match source:
		"radar": return "fixed_narrow"
		"satellite": return "periodic"
		"phone": return "burst"
		"powerline": return "comb"
		"aircraft": return "swept"
		_: return "fixed_narrow"


# ---------------------------------------------------------------- 1. pointing
func nudge(d_az: float, d_alt: float, strength := 1.0) -> void:
	var impulse := ACCEL * acceleration_scale * 0.1 * maxf(strength, 0.0)
	az_velocity = clampf(az_velocity + d_az * impulse, -MAX_SLEW, MAX_SLEW)
	alt_velocity = clampf(alt_velocity + d_alt * impulse, -MAX_SLEW, MAX_SLEW)


func brake(strength := 1.0) -> void:
	var factor := clampf(1.0 - 0.32 * strength, 0.08, 1.0)
	az_velocity *= factor
	alt_velocity *= factor


func step(dt: float) -> void:
	# inertia + exponential damping = the cabin coasts and settles, never snaps
	aim_drift_phase += dt
	if aim_drift_deg_s > 0.0:
		aim_disturbance_timer_s -= dt
		if aim_disturbance_timer_s <= 0.0:
			_begin_aim_disturbance()
	aim_disturbance_remaining_s = maxf(0.0, aim_disturbance_remaining_s - dt)
	azimuth += az_velocity * dt
	altitude += alt_velocity * dt
	var damp := clampf(1.0 - DAMPING * damping_scale * dt, 0.0, 1.0)
	az_velocity *= damp
	alt_velocity *= damp
	altitude = clampf(altitude, 5.0, 88.0)
	var speed := pointing_speed()
	# cable tension tracks how hard the drive is working
	cable_tension = clampf(0.22 + speed / MAX_SLEW * 0.85, 0.0, 1.0)


func _begin_aim_disturbance() -> void:
	aim_disturbance_serial += 1
	var phase_deg := fposmod(
		true_azimuth * 0.73 + true_altitude * 1.37 + float(aim_disturbance_serial) * 137.5,
		360.0
	)
	var phase := deg_to_rad(phase_deg)
	aim_disturbance_vector = Vector2(cos(phase), sin(phase) * 0.68).normalized()
	var impulse := aim_drift_deg_s * 0.58
	az_velocity = clampf(az_velocity + aim_disturbance_vector.x * impulse, -MAX_SLEW, MAX_SLEW)
	alt_velocity = clampf(alt_velocity + aim_disturbance_vector.y * impulse, -MAX_SLEW, MAX_SLEW)
	aim_disturbance_remaining_s = AIM_DISTURBANCE_DURATION_S
	aim_disturbance_timer_s = aim_disturbance_interval_s


func aim_disturbance_active() -> bool:
	return aim_disturbance_remaining_s > 0.0


func seconds_to_aim_disturbance() -> float:
	if aim_drift_deg_s <= 0.0:
		return -1.0
	return maxf(0.0, aim_disturbance_timer_s)


func target_feed_offset_normalized() -> Vector2:
	return _feed_offset_for_direction(true_azimuth, true_altitude)


func cabin_feed_offset_normalized() -> Vector2:
	return _feed_offset_for_direction(azimuth, altitude)


func _feed_offset_for_direction(azimuth_deg: float, altitude_deg: float) -> Vector2:
	# FAST forms an off-axis paraboloid beneath the suspended receiver. The
	# receiver projection therefore rotates around the dish with azimuth and
	# moves radially with zenith angle instead of always sitting at screen centre.
	var zenith_deg := clampf(90.0 - altitude_deg, 0.0, FAST_MAX_ZENITH_ANGLE_DEG)
	var radial := sin(deg_to_rad(zenith_deg)) / sin(deg_to_rad(FAST_MAX_ZENITH_ANGLE_DEG))
	var azimuth_rad := deg_to_rad(azimuth_deg)
	return Vector2(sin(azimuth_rad), -cos(azimuth_rad)) * radial


func active_reflector_center_normalized() -> Vector2:
	# The illuminated 300 m paraboloid follows the receiver projection, but over
	# a smaller fraction of the full 500 m aperture.
	return target_feed_offset_normalized() * 0.46


func panel_tilt_vector(panel_position_normalized: Vector2) -> Vector2:
	# Relative slope of z=(x^2+y^2)/(4f), plus the off-axis steering term. This
	# is a visualization quantity: it exposes that neighbouring cable-net panels
	# use different actuator angles without changing the pointing success model.
	var local := panel_position_normalized - active_reflector_center_normalized()
	var paraboloid_gradient := local / 0.94
	var steering_gradient := target_feed_offset_normalized() * 0.34
	return paraboloid_gradient + steering_gradient


func pointing_error() -> float:
	var d_az := wrapf(azimuth - true_azimuth, -180.0, 180.0)
	return sqrt(d_az * d_az + (altitude - true_altitude) * (altitude - true_altitude))


func pointing_speed() -> float:
	return sqrt(az_velocity * az_velocity + alt_velocity * alt_velocity)


func is_on_target() -> bool:
	return pointing_error() <= LOCK_TOLERANCE


func is_locked() -> bool:
	return is_on_target() and pointing_speed() <= STABLE_SPEED


func tension_warning() -> bool:
	return cable_tension >= 0.9


func motion_vector() -> Vector2:
	return Vector2(az_velocity, -alt_velocity)


func predicted_error_vector(seconds := 0.55) -> Vector2:
	var predicted_az := azimuth + az_velocity * seconds
	var predicted_alt := altitude + alt_velocity * seconds
	return Vector2(
		wrapf(predicted_az - true_azimuth, -180.0, 180.0),
		predicted_alt - true_altitude
	)


func stability() -> float:
	var speed_factor := clampf(1.0 - pointing_speed() / maxf(STABLE_SPEED * 3.0, 0.1), 0.0, 1.0)
	var position_factor := clampf(1.0 - pointing_error() / maxf(LOCK_TOLERANCE * 3.0, 0.1), 0.0, 1.0)
	return speed_factor * position_factor


# ---------------------------------------------------------------- 2. tuning
func window_covers_source() -> float:
	# fraction of the source band that falls inside the tuned window (0..1)
	var lo := window_center_mhz - window_bandwidth_mhz * 0.5
	var hi := window_center_mhz + window_bandwidth_mhz * 0.5
	var s_lo := true_center_mhz - true_bandwidth_mhz * 0.5
	var s_hi := true_center_mhz + true_bandwidth_mhz * 0.5
	var overlap := minf(hi, s_hi) - maxf(lo, s_lo)
	return clampf(overlap / true_bandwidth_mhz, 0.0, 1.0)


func window_rfi_load() -> float:
	# how much strong RFI sits inside the window (0..1) - the player must avoid it
	var lo := window_center_mhz - window_bandwidth_mhz * 0.5
	var hi := window_center_mhz + window_bandwidth_mhz * 0.5
	var load := 0.0
	for peak in rfi_peaks:
		if not bool(peak["is_rfi"]):
			continue
		if float(peak["mhz"]) >= lo and float(peak["mhz"]) <= hi:
			load = maxf(load, float(peak["strength"]))
	return load


func tuning_quality() -> float:
	return clampf(window_covers_source() - window_rfi_load() * 0.8, 0.0, 1.0)


func spectrum_samples(count: int, apply_classification := false) -> Array:
	# deterministic spectrum for drawing: noise floor + source bump + RFI spikes
	var out: Array = []
	for i in range(count):
		var mhz := BAND_MIN + (BAND_MAX - BAND_MIN) * float(i) / float(max(1, count - 1))
		var v := 0.12 + 0.05 * sin(mhz * 0.09)     # noise floor ripple
		# source bump (broad)
		var ds := (mhz - true_center_mhz) / (true_bandwidth_mhz * 0.6)
		var source_visibility := 1.0
		if apply_classification and source_deleted():
			source_visibility = 0.12
		v += 0.55 * source_strength * source_visibility * exp(-ds * ds)
		# RFI spikes (narrow, tall)
		for peak_index in range(rfi_peaks.size()):
			var peak: Dictionary = rfi_peaks[peak_index]
			if not bool(peak["is_rfi"]):
				continue
			if apply_classification and str(classifications.get(peak_index, "")) == "rfi":
				continue
			var dp := (mhz - float(peak["mhz"])) / 6.0
			v += float(peak["strength"]) * exp(-dp * dp)
		out.append(clampf(v, 0.0, 1.4))
	return out


# ---------------------------------------------------------------- 3. RFI
func classify(index: int, as_rfi: bool) -> void:
	classifications[index] = "rfi" if as_rfi else "source"


func classification_score() -> float:
	if rfi_peaks.is_empty():
		return 0.0
	var correct := 0
	for i in range(rfi_peaks.size()):
		var want := "rfi" if bool(rfi_peaks[i]["is_rfi"]) else "source"
		if str(classifications.get(i, "")) == want:
			correct += 1
	return float(correct) / float(rfi_peaks.size())


func all_classified() -> bool:
	return classifications.size() >= rfi_peaks.size()


func correctly_rejected_rfi_count() -> int:
	var count := 0
	for i in range(rfi_peaks.size()):
		if bool(rfi_peaks[i]["is_rfi"]) and str(classifications.get(i, "")) == "rfi":
			count += 1
	return count


func residual_rfi_count() -> int:
	var count := 0
	for i in range(rfi_peaks.size()):
		if bool(rfi_peaks[i]["is_rfi"]) and str(classifications.get(i, "")) != "rfi":
			count += 1
	return count


func source_deleted() -> bool:
	for i in range(rfi_peaks.size()):
		if not bool(rfi_peaks[i]["is_rfi"]):
			return str(classifications.get(i, "")) == "rfi"
	return false


func classification_evidence() -> String:
	if source_deleted():
		return "source_deleted"
	if residual_rfi_count() > 0:
		return "residual_rfi"
	if classification_score() >= rfi_threshold:
		return "clean"
	return "uncertain"


# ---------------------------------------------------------------- 4/5. folding
func set_integration(seconds: float) -> void:
	integration_s = clampf(seconds, 0.0, MAX_INTEGRATION)


func period_match() -> float:
	if target_kind != "pulsar":
		return 1.0
	var err := absf(trial_period_ms - true_period_ms)
	return clampf(1.0 - err / 40.0, 0.0, 1.0)   # within ~40 ms to score


func dm_match() -> float:
	if target_kind != "pulsar":
		return 1.0
	var err := absf(trial_dm - true_dm)
	return clampf(1.0 - err / 12.0, 0.0, 1.0)


func phase_match() -> float:
	if target_kind != "pulsar":
		return 1.0
	var wrapped_error := absf(fposmod(trial_phase - true_phase + 0.5, 1.0) - 0.5)
	return clampf(1.0 - wrapped_error / 0.28, 0.0, 1.0)


func period_search_min_ms() -> float:
	return true_period_ms * 0.42


func period_search_max_ms() -> float:
	return true_period_ms * 2.08


func period_search_normalized() -> float:
	return clampf(
		(trial_period_ms - period_search_min_ms()) / maxf(period_search_max_ms() - period_search_min_ms(), 0.001),
		0.0,
		1.0
	)


func set_trial_period_from_search_normalized(normalized: float) -> void:
	trial_period_ms = lerpf(period_search_min_ms(), period_search_max_ms(), clampf(normalized, 0.0, 1.0))


func period_correlation_at(period_ms: float) -> float:
	# The correlation belt is derived from the same timing model that validates
	# the fold. The fundamental is the strongest repeat; half/double aliases are
	# intentionally plausible but visibly weaker so a player has to judge drift.
	var scale := maxf(true_period_ms, 0.001)
	var fundamental := exp(-pow((period_ms - true_period_ms) / (scale * 0.030), 2.0))
	var half_alias := 0.42 * exp(-pow((period_ms - true_period_ms * 0.5) / (scale * 0.026), 2.0))
	var double_alias := 0.34 * exp(-pow((period_ms - true_period_ms * 2.0) / (scale * 0.052), 2.0))
	var baseline := 0.07 + 0.035 * sin(period_ms * 0.071) + 0.020 * sin(period_ms * 0.017)
	return clampf(baseline + fundamental + half_alias + double_alias, 0.0, 1.0)


func period_correlation_curve(sample_count: int) -> Array:
	var samples: Array = []
	var safe_count := maxi(sample_count, 2)
	for index in range(safe_count):
		var normalized := float(index) / float(safe_count - 1)
		samples.append(period_correlation_at(lerpf(period_search_min_ms(), period_search_max_ms(), normalized)))
	return samples


func period_solution_state() -> String:
	if target_kind != "pulsar":
		return "fundamental"
	var ratio := trial_period_ms / maxf(true_period_ms, 0.001)
	if absf(ratio - 1.0) <= 0.018:
		return "fundamental"
	if absf(ratio - 0.5) <= 0.035:
		return "half_period"
	if absf(ratio - 2.0) <= 0.06:
		return "double_period"
	return "drifting"


func fold_phase_drift_per_window() -> float:
	if target_kind != "pulsar":
		return 0.0
	var relative_error := (trial_period_ms - true_period_ms) / maxf(true_period_ms, 0.001)
	return clampf(relative_error * 5.4, -0.46, 0.46)


func subband_offsets(count: int) -> Array:
	var out: Array = []
	# Keep the visible sweep responsive even when the trial DM is far outside
	# the scoring window. Using `1 - dm_match()` saturated at 1.0, so the first
	# several control inputs changed the number but left every trace frozen.
	# The signed residual also tells the player which way the sweep is leaning.
	var residual := (trial_dm - true_dm) / 12.0
	var signed_dispersion := clampf(
		residual / (1.0 + absf(residual) * 0.75),
		-1.0,
		1.0
	)
	for i in range(maxi(count, 1)):
		var normalized := 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 2.0
		out.append(normalized * signed_dispersion * 0.34)
	return out


func fold_snr() -> float:
	# SNR grows with sqrt(integration), scaled by how well the whole chain is set:
	# pointing lock, tuning, RFI rejection, correct period + DM.
	var chain := 0.0
	chain += 0.28 * (1.0 if is_locked() else clampf(1.0 - pointing_error() / 12.0, 0.0, 1.0))
	chain += 0.24 * tuning_quality()
	chain += 0.18 * classification_score()
	chain += 0.15 * period_match()
	chain += 0.15 * dm_match()
	var integ := sqrt(integration_s / 30.0)     # sqrt(t) radiometer scaling
	return clampf(chain, 0.0, 1.0) * integ * 22.0 * source_strength


func folded_profile(bins: int) -> Array:
	return folded_profile_for_window(bins, 0)


func folded_profile_for_window(bins: int, window_index: int) -> Array:
	# A clean pulse appears only when period, DM and phase align. Consecutive
	# windows expose a wrong period as horizontal drift instead of a hidden
	# percentage. Half- and double-period aliases remain plausible but visibly
	# split, so one lucky peak cannot pass as a stable candidate.
	var out: Array = []
	var sharp := period_match() * dm_match()
	var width := lerpf(0.5, 0.045, sharp)         # phase width of the pulse
	var amp := clampf(fold_snr() / 20.0, 0.05, 1.0)
	var solution := period_solution_state()
	# A real folded pulsar profile can have two emission components. The pair is
	# subtle in raw noise, then becomes the player's visible discovery once the
	# period, DM and phase agree. Aliases remain much wider/farther apart.
	var split := pulse_component_separation
	if solution == "half_period":
		# A half-period alias can look deceptively convincing: two narrow peaks
		# appear per trial cycle instead of one stable fundamental pulse.
		width = 0.07
		amp = maxf(amp, 0.5)
		split = 0.25
	elif solution == "double_period":
		# A double-period alias retains a narrow pulse but alternates in energy
		# between validation windows, exposing the skipped rotation.
		width = 0.085
		amp = maxf(amp, 0.42)
		split = 0.18
	var phase_shift := (trial_phase - true_phase) * 0.42
	phase_shift += fold_phase_drift_per_window() * float(window_index)
	for i in range(bins):
		var phase := float(i) / float(bins)
		var center_a := fposmod(0.5 + phase_shift - split, 1.0)
		var center_b := fposmod(0.5 + phase_shift + split, 1.0)
		var delta_a := fposmod(phase - center_a + 0.5, 1.0) - 0.5
		var delta_b := fposmod(phase - center_b + 0.5, 1.0) - 0.5
		var dphi_a := delta_a / width
		var dphi_b := delta_b / width
		var v := amp * exp(-dphi_a * dphi_a)
		if split > 0.015 or solution in ["half_period", "double_period"]:
			var alias_gain := 0.84 if solution == "half_period" else (0.62 if solution == "double_period" else pulse_secondary_strength)
			v += amp * alias_gain * exp(-dphi_b * dphi_b)
		if solution == "double_period" and window_index % 2 == 1:
			v *= 0.62
		v += 0.06 * sin(phase * TAU * 3.0) * (1.0 - sharp)   # residual smear
		out.append(clampf(v, 0.0, 1.2))
	return out


func folded_peak_phase(window_index: int) -> float:
	var profile := folded_profile_for_window(128, window_index)
	var peak_index := 0
	var peak_value := -INF
	for index in range(profile.size()):
		var value := float(profile[index])
		if value > peak_value:
			peak_value = value
			peak_index = index
	return float(peak_index) / float(maxi(profile.size() - 1, 1))


func candidate_window_is_stable(previous_peak_phase: float, window_index: int) -> bool:
	if period_solution_state() != "fundamental":
		return false
	if dm_match() < 0.78 or phase_match() < 0.72:
		return false
	var current_peak := folded_peak_phase(window_index)
	var wrapped_delta := absf(fposmod(current_peak - previous_peak_phase + 0.5, 1.0) - 0.5)
	return wrapped_delta <= 0.035


func pulse_width_ms() -> float:
	return true_period_ms * lerpf(0.32, 0.04, period_match() * dm_match())


func timing_stability() -> float:
	return clampf(0.55 + 0.4 * period_match() * dm_match() + 0.05 * classification_score(), 0.0, 1.0)


func confidence_score() -> float:
	return clampf(
		pointing_quality() * 0.18
		+ tuning_quality() * 0.17
		+ classification_score() * 0.20
		+ period_match() * 0.18
		+ dm_match() * 0.14
		+ clampf(fold_snr() / maxf(report_snr_threshold * 1.6, 1.0), 0.0, 1.0) * 0.13,
		0.0,
		1.0
	)


func sky_position() -> Dictionary:
	return {
		"azimuth_deg": true_azimuth,
		"altitude_deg": true_altitude,
		"label": "AZ %.1f°  ALT %.1f°" % [true_azimuth, true_altitude],
	}


func pointing_quality() -> float:
	return 1.0 if is_locked() else clampf(1.0 - pointing_error() / 18.0, 0.0, 1.0)


func dynamic_spectrum(
	time_bins := 72,
	frequency_bins := 24,
	apply_cleaning := false,
	apply_dedispersion := false
) -> Array:
	# Deterministic time-frequency data product. Every visible feature is tied to
	# pointing, passband placement, RFI decisions, and the current DM solution.
	var rows: Array = []
	var safe_time_bins := maxi(time_bins, 8)
	var safe_frequency_bins := maxi(frequency_bins, 6)
	var signal_scale := pointing_quality() * tuning_quality() * source_strength
	if source_deleted():
		signal_scale *= 0.04
	var remaining_dispersion := 0.0 if apply_dedispersion else 1.0
	if apply_dedispersion:
		remaining_dispersion = 1.0 - dm_match()
	for frequency_index in range(safe_frequency_bins):
		var frequency_normalized := float(frequency_index) / float(safe_frequency_bins - 1)
		var row: Array = []
		for time_index in range(safe_time_bins):
			var time_normalized := float(time_index) / float(safe_time_bins - 1)
			var deterministic_noise := (
				sin(float(time_index) * 1.73 + float(frequency_index) * 0.61)
				+ sin(float(time_index) * 0.37 - float(frequency_index) * 1.19)
			) * 0.035
			var value := 0.09 + deterministic_noise
			if target_kind == "pulsar":
				var delay := (1.0 - frequency_normalized) * 0.30 * remaining_dispersion
				var pulse_phase := fposmod(time_normalized * 4.0 - delay - true_phase, 1.0)
				var pulse_distance := minf(pulse_phase, 1.0 - pulse_phase)
				value += exp(-pow(pulse_distance / 0.052, 2.0)) * 0.58 * signal_scale
			elif target_kind in ["repeating_frb", "frb"]:
				var burst_delay := (1.0 - frequency_normalized) * 0.52 * remaining_dispersion
				var burst_distance := absf(time_normalized - (0.57 + burst_delay * 0.45))
				value += exp(-pow(burst_distance / 0.032, 2.0)) * 0.72 * signal_scale
			else:
				var line_center := clampf(
					(true_center_mhz - BAND_MIN) / (BAND_MAX - BAND_MIN),
					0.0,
					1.0
				)
				value += exp(-pow((frequency_normalized - line_center) / 0.055, 2.0)) * 0.42 * signal_scale

			for peak_index in range(rfi_peaks.size()):
				var peak: Dictionary = rfi_peaks[peak_index]
				if not bool(peak.get("is_rfi", false)):
					continue
				var peak_frequency := clampf(
					(float(peak.get("mhz", BAND_MIN)) - BAND_MIN) / (BAND_MAX - BAND_MIN),
					0.0,
					1.0
				)
				var frequency_distance := absf(frequency_normalized - peak_frequency)
				var pattern := str(peak.get("pattern", "fixed_narrow"))
				var pattern_strength := 0.0
				match pattern:
					"periodic":
						pattern_strength = 0.65 if sin(time_normalized * TAU * 9.0) > 0.30 else 0.05
					"burst":
						pattern_strength = 0.78 if absf(time_normalized - 0.63) < 0.075 else 0.02
					"comb":
						pattern_strength = 0.56 if posmod(time_index, 8) <= 1 else 0.07
					"sweep":
						var sweep_frequency := fposmod(time_normalized * 0.85 + 0.12, 1.0)
						frequency_distance = absf(frequency_normalized - sweep_frequency)
						pattern_strength = 0.70
					_:
						pattern_strength = 0.62
				var rejected := apply_cleaning and str(classifications.get(peak_index, "")) == "rfi"
				var rejection_gain := 0.08 if rejected else 1.0
				value += (
					exp(-pow(frequency_distance / 0.018, 2.0))
					* pattern_strength
					* float(peak.get("strength", 0.7))
					* rejection_gain
				)
			row.append(clampf(value, 0.0, 1.0))
		rows.append(row)
	return rows


func science_product(time_bins := 72, frequency_bins := 24) -> Dictionary:
	var report_data := report()
	var measured_period := maxf(float(report_data.get("trial_period_ms", trial_period_ms)), 0.001)
	var width_ms := pulse_width_ms()
	var confidence := confidence_score()
	var rfi_marks: Array = []
	for peak_index in range(rfi_peaks.size()):
		var peak: Dictionary = rfi_peaks[peak_index]
		if not bool(peak.get("is_rfi", false)):
			continue
		rfi_marks.append({
			"frequency_normalized": clampf(
				(float(peak.get("mhz", BAND_MIN)) - BAND_MIN) / (BAND_MAX - BAND_MIN),
				0.0,
				1.0
			),
			"removed": str(classifications.get(peak_index, "")) == "rfi",
			"pattern": str(peak.get("pattern", "fixed_narrow")),
		})
	var folded_two_cycles: Array = []
	var one_cycle := folded_profile(96)
	for _cycle in range(2):
		folded_two_cycles.append_array(one_cycle)
	return {
		"raw_spectrum": dynamic_spectrum(time_bins, frequency_bins, false, false),
		"clean_spectrum": dynamic_spectrum(time_bins, frequency_bins, true, false),
		"corrected_spectrum": dynamic_spectrum(time_bins, frequency_bins, true, true),
		"folded_two_cycles": folded_two_cycles,
		"rfi_marks": rfi_marks,
		"pointing_quality": pointing_quality(),
		"tuning_quality": tuning_quality(),
		"rfi_quality": classification_score(),
		"period_quality": period_match(),
		"dm_quality": dm_match(),
		"phase_quality": phase_match(),
		"confidence": confidence,
		"pulse_width_ms": width_ms,
		"duty_cycle_percent": clampf(width_ms / measured_period * 100.0, 0.0, 100.0),
		"raw_rfi_count": maxi(0, rfi_peaks.size() - 1),
		"removed_rfi_count": correctly_rejected_rfi_count(),
		"residual_rfi_count": residual_rfi_count(),
		"period_error_ms": absf(trial_period_ms - true_period_ms),
		"dm_residual": absf(trial_dm - true_dm),
		"target_name": target_display_name,
		"candidate_model": candidate_model,
		"sky_position": sky_position(),
		"observed_at_unix": Time.get_unix_time_from_system(),
		"report": report_data,
	}


func report() -> Dictionary:
	var snr := fold_snr()
	var success := is_locked() \
		and tuning_quality() >= 0.55 \
		and classification_score() >= rfi_threshold \
		and not source_deleted() \
		and residual_rfi_count() == 0 \
		and integration_s >= required_integration_s \
		and snr >= report_snr_threshold \
		and period_match() > period_threshold \
		and dm_match() > dm_threshold \
		and phase_match() >= 0.72 \
		and period_solution_state() == "fundamental"
	return {
		"target_id": target_id,
		"kind": target_kind,
		"pulse_period_ms": trial_period_ms,
		"dispersion_measure": trial_dm,
		"snr": snr,
		"pulse_width_ms": pulse_width_ms(),
		"timing_stability": timing_stability(),
		"band_mhz": window_center_mhz,
		"bandwidth_mhz": window_bandwidth_mhz,
		"integration_s": integration_s,
		"rfi_score": classification_score(),
		"rfi_cleared": correctly_rejected_rfi_count(),
		"rfi_residual": residual_rfi_count(),
		"source_deleted": source_deleted(),
		"tuning_quality": tuning_quality(),
		"pointing_error": pointing_error(),
		"trial_period_ms": trial_period_ms,
		"trial_dm": trial_dm,
		"trial_phase": trial_phase,
		"phase_match": phase_match(),
		"confidence": confidence_score(),
		"target_name": target_display_name,
		"candidate_model": candidate_model,
		"sky_position": sky_position(),
		"challenge": challenge,
		"result_en": narrative_result_en,
		"result_zh": narrative_result_zh,
		"success": success,
	}


func conclusion_state() -> String:
	if source_deleted():
		return "candidate_removed"
	if residual_rfi_count() > 0 or classification_score() < rfi_threshold:
		return "residual_rfi"
	if fold_snr() < report_snr_threshold:
		return "insufficient_signal"
	if period_match() <= period_threshold or dm_match() <= dm_threshold:
		return "unstable_candidate"
	if target_kind in ["hi_line", "hydrogen"]:
		return "confirmed_hi"
	if target_kind in ["repeating_frb", "frb"]:
		return "confirmed_frb"
	return "stable_pulsar"


func evaluate_conclusion(choice: String) -> bool:
	return choice == conclusion_state() and bool(report().get("success", false))
