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
var damping_scale := 1.0
var acceleration_scale := 1.0
const MAX_SLEW := 18.0               # deg/s cap
const DAMPING := 2.4                 # velocity damping per second
const ACCEL := 26.0                  # deg/s^2 per nudge unit
const LOCK_TOLERANCE := 2.2          # deg pointing error to count as on-target
const STABLE_SPEED := 1.4            # deg/s below which pointing is "settled"

# ---- frequency window ----
var window_center_mhz := 1400.0
var window_bandwidth_mhz := 80.0
const BAND_MIN := 1000.0
const BAND_MAX := 1500.0

# ---- folding / integration ----
var trial_period_ms := 500.0
var trial_dm := 0.0
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
	true_azimuth = float(profile.get("azimuth", true_azimuth))
	true_altitude = float(profile.get("altitude", true_altitude))
	true_period_ms = float(profile.get("period_ms", true_period_ms))
	true_dm = float(profile.get("dm", true_dm))
	true_center_mhz = float(profile.get("center_mhz", true_center_mhz))
	true_bandwidth_mhz = float(profile.get("bandwidth_mhz", true_bandwidth_mhz))
	source_strength = float(profile.get("source_strength", source_strength))
	challenge = str(profile.get("challenge", "balanced"))
	narrative_result_en = str(profile.get("result_en", narrative_result_en))
	narrative_result_zh = str(profile.get("result_zh", narrative_result_zh))
	aim_drift_deg_s = float(profile.get("aim_drift_deg_s", 0.0))
	damping_scale = maxf(0.35, float(profile.get("damping_scale", 1.0)))
	acceleration_scale = maxf(0.35, float(profile.get("acceleration_scale", 1.0)))
	required_integration_s = clampf(float(profile.get("required_integration_s", 180.0)), 30.0, MAX_INTEGRATION)
	report_snr_threshold = maxf(4.0, float(profile.get("snr_threshold", 8.0)))
	period_threshold = clampf(float(profile.get("period_threshold", 0.60)), 0.35, 0.95)
	dm_threshold = clampf(float(profile.get("dm_threshold", 0.60)), 0.35, 0.95)
	rfi_threshold = clampf(float(profile.get("rfi_threshold", 0.75)), 0.50, 1.0)
	# start the cabin a realistic distance off-target
	azimuth = true_azimuth + float(profile.get("start_offset_az", 24.0))
	altitude = true_altitude - float(profile.get("start_offset_alt", 16.0))
	az_velocity = 0.0
	alt_velocity = 0.0
	window_center_mhz = float(profile.get("start_center_mhz", 1400.0))
	window_bandwidth_mhz = float(profile.get("start_bandwidth_mhz", window_bandwidth_mhz))
	trial_period_ms = float(profile.get("start_period_ms", 500.0))
	trial_dm = float(profile.get("start_dm", 0.0))
	integration_s = 0.0
	aim_drift_phase = 0.0
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
		az_velocity += sin(aim_drift_phase * 1.7) * aim_drift_deg_s * dt
		alt_velocity += cos(aim_drift_phase * 1.15) * aim_drift_deg_s * 0.55 * dt
	azimuth += az_velocity * dt
	altitude += alt_velocity * dt
	var damp := clampf(1.0 - DAMPING * damping_scale * dt, 0.0, 1.0)
	az_velocity *= damp
	alt_velocity *= damp
	altitude = clampf(altitude, 5.0, 88.0)
	var speed := pointing_speed()
	# cable tension tracks how hard the drive is working
	cable_tension = clampf(0.22 + speed / MAX_SLEW * 0.85, 0.0, 1.0)


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


func subband_offsets(count: int) -> Array:
	var out: Array = []
	var mismatch := 1.0 - dm_match()
	for i in range(maxi(count, 1)):
		var normalized := 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 2.0
		out.append(normalized * mismatch * 0.34)
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
	# A clean pulse appears only when both period and DM align. A wrong period
	# visibly splits the profile; a wrong DM broadens it across sub-bands.
	var out: Array = []
	var sharp := period_match() * dm_match()
	var width := lerpf(0.5, 0.045, sharp)         # phase width of the pulse
	var amp := clampf(fold_snr() / 20.0, 0.05, 1.0)
	var split := (1.0 - period_match()) * 0.23
	for i in range(bins):
		var phase := float(i) / float(bins)
		var dphi_a := (phase - (0.5 - split)) / width
		var dphi_b := (phase - (0.5 + split)) / width
		var v := amp * exp(-dphi_a * dphi_a)
		if split > 0.015:
			v += amp * 0.72 * exp(-dphi_b * dphi_b)
		v += 0.06 * sin(phase * TAU * 3.0) * (1.0 - sharp)   # residual smear
		out.append(clampf(v, 0.0, 1.2))
	return out


func pulse_width_ms() -> float:
	return true_period_ms * lerpf(0.32, 0.04, period_match() * dm_match())


func timing_stability() -> float:
	return clampf(0.55 + 0.4 * period_match() * dm_match() + 0.05 * classification_score(), 0.0, 1.0)


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
		and dm_match() > dm_threshold
	return {
		"target_id": target_id,
		"kind": target_kind,
		"pulse_period_ms": true_period_ms if period_match() > 0.6 else trial_period_ms,
		"dispersion_measure": true_dm if dm_match() > 0.6 else trial_dm,
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
	return "stable_pulsar"


func evaluate_conclusion(choice: String) -> bool:
	return choice == conclusion_state() and bool(report().get("success", false))
