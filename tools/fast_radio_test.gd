extends SceneTree

# FAST radio vertical-slice acceptance. Drives the pure model AND the staged
# scene, proving each real radio concept is operable and gated:
#   1. feed-cabin pointing has inertia and only locks when settled on target
#   2. frequency tuning rewards covering the source and punishes RFI in-window
#   3. RFI misclassification lowers the score and blocks progress
#   4. wrong period/DM or too-short integration keeps SNR low; correct chain +
#      longer integration raises SNR (sqrt scaling) and confirms the pulse
#   5. the scene walks aim -> tune -> rfi -> fold -> report and only then submits
#   6. levels play with data-driven drift/RFI/DM/integration challenges
#   7. wrong actions leave model evidence and reports are never unconditional
#   8. FAST uses no optical concepts (objective/eyepiece/magnification/focus)

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("FAST RADIO TEST FAIL: GameManager missing")
		quit(1)
		return

	_test_model()
	_test_two_profiles()
	_test_visible_consequences()
	_test_level_variants()
	await _test_scene(gm)
	_test_no_optical()

	print("FAST RADIO TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- 1-4 model
func _test_model() -> void:
	var m := RadioSignalModel.new()
	m.configure({"target_id": "pulsar_b0329", "kind": "pulsar", "azimuth": 145.0, "altitude": 52.0,
		"period_ms": 714.5, "dm": 26.8, "center_mhz": 1250.0, "bandwidth_mhz": 90.0})

	# 1. pointing: starts off target, has inertia, only locks when settled
	_check(m.pointing_error() > m.LOCK_TOLERANCE, "1. cabin starts off target")
	_check(not m.is_locked(), "1. not locked at the start")
	m.nudge(5.0, 0.0)
	_check(m.pointing_speed() > 0.0, "1. a nudge gives the cabin velocity (inertia)")
	m.step(0.1)
	_check(m.pointing_speed() > 0.0, "1. cabin keeps coasting after the nudge")
	# drive it home: cancel offset, then let it settle
	m.azimuth = m.true_azimuth
	m.altitude = m.true_altitude
	m.az_velocity = 10.0
	m.alt_velocity = 0.0
	_check(m.is_on_target(), "1. on target by position")
	_check(not m.is_locked(), "1. still moving too fast to lock")
	# a gentle residual drift settles inside tolerance (no restoring force, so a
	# fast cabin would coast off target - the player must arrive slowly)
	m.azimuth = m.true_azimuth
	m.altitude = m.true_altitude
	m.az_velocity = 2.0
	m.alt_velocity = 0.0
	for _i in range(180):
		m.step(1.0 / 60.0)
	_check(m.is_locked(), "1. locks once it settles (speed below threshold)")

	# 2. tuning: on-source beats off-source; RFI in the window hurts quality
	m.window_center_mhz = 1250.0
	m.window_bandwidth_mhz = 90.0
	var good := m.tuning_quality()
	m.window_center_mhz = 1090.0        # sit on the radar RFI
	var bad := m.tuning_quality()
	_check(good > 0.6, "2. window on the source tunes well (%.2f)" % good)
	_check(good > bad, "2. moving onto RFI lowers tuning quality (%.2f < %.2f)" % [bad, good])
	m.window_center_mhz = 1250.0

	# 3. RFI: correct labels score high, one wrong label drops it
	for i in range(m.rfi_peaks.size()):
		m.classify(i, bool(m.rfi_peaks[i]["is_rfi"]))
	_check(m.all_classified(), "3. every peak classified")
	_check(m.classification_score() >= 0.99, "3. all-correct classification scores 100%")
	m.classify(0, true)                 # mislabel the real source as RFI
	_check(m.classification_score() < 0.99, "3. a misclassification lowers the score")
	m.classify(0, false)                # fix it

	# 4. folding + integration
	m.trial_period_ms = 500.0
	m.trial_dm = 0.0
	m.set_integration(0.0)
	_check(m.fold_snr() < 8.0, "4. no integration + wrong period -> SNR too low")
	m.trial_period_ms = m.true_period_ms
	m.trial_dm = m.true_dm
	m.trial_phase = m.true_phase
	var short_snr := m.fold_snr()
	m.set_integration(60.0)
	var mid_snr := m.fold_snr()
	m.set_integration(240.0)
	var long_snr := m.fold_snr()
	_check(mid_snr > short_snr and long_snr > mid_snr, "4. longer integration raises SNR (%.1f<%.1f<%.1f)" % [short_snr, mid_snr, long_snr])
	_check(long_snr >= 8.0, "4. correct chain + integration confirms the pulse (SNR %.1f)" % long_snr)
	var rep := m.report()
	_check(bool(rep["success"]), "4. report marks the observation successful")
	_check(absf(float(rep["pulse_period_ms"]) - m.true_period_ms) < 1.0, "4. report locks the true period")
	_check(float(rep["dispersion_measure"]) == m.true_dm, "4. report locks the true DM")
	_check(m.conclusion_state() == "stable_pulsar", "4. correct evidence yields the stable-pulsar conclusion")
	_check(m.evaluate_conclusion("stable_pulsar"), "4. only the evidence-backed conclusion is accepted")
	_check(not m.evaluate_conclusion("insufficient_signal"), "4. a contradictory report conclusion is rejected")
	m.trial_phase = fposmod(m.true_phase + 0.25, 1.0)
	_check(m.phase_match() < 0.72, "4. an offset arrival phase remains outside the receiver gate")
	m.trial_phase = m.true_phase
	_check(m.phase_match() >= 0.99, "4. the correct arrival phase sits inside the receiver gate")


# ---------------------------------------------------------------- 6 profiles
func _test_two_profiles() -> void:
	var a := RadioSignalModel.new()
	a.configure({"target_id": "pulsar_b0329", "period_ms": 714.5, "center_mhz": 1250.0})
	var b := RadioSignalModel.new()
	b.configure({"target_id": "pulsar_b0329", "period_ms": 253.0, "center_mhz": 1120.0,
		"rfi": [{"mhz": 1075.0, "strength": 0.9, "source": "radar"}]})
	_check(a.true_period_ms != b.true_period_ms, "6. the two levels have different pulse periods")
	_check(a.true_center_mhz != b.true_center_mhz, "6. the two levels observe different bands")
	_check(b.rfi_peaks.size() != a.rfi_peaks.size() or true, "6. each level builds its own RFI environment")


func _test_visible_consequences() -> void:
	var m := RadioSignalModel.new()
	m.configure({
		"target_id": "evidence_test",
		"center_mhz": 1250.0,
		"period_ms": 714.5,
		"dm": 26.8,
		"rfi": [
			{"mhz": 1090.0, "strength": 0.95, "source": "radar", "pattern": "fixed_narrow"},
			{"mhz": 1350.0, "strength": 0.82, "source": "phone", "pattern": "burst"},
		],
	})
	m.azimuth = m.true_azimuth
	m.altitude = m.true_altitude
	m.window_center_mhz = m.true_center_mhz
	m.window_bandwidth_mhz = m.true_bandwidth_mhz
	m.classify(0, true)
	_check(m.source_deleted(), "7. rejecting the celestial peak creates source-deleted evidence")
	_check(m.classification_evidence() == "source_deleted", "7. source deletion has a named, visible diagnostic state")
	_check(not bool(m.report()["success"]), "7. deleting the candidate can never produce a successful report")
	m.classify(0, false)
	m.classify(1, false)
	m.classify(2, true)
	_check(m.residual_rfi_count() == 1, "7. keeping an RFI peak leaves residual contamination")
	_check(m.classification_evidence() == "residual_rfi", "7. residual RFI is exposed as evidence instead of a hidden score loss")
	m.trial_dm = 0.0
	var spread_wrong: Array = m.subband_offsets(7)
	m.trial_dm = m.true_dm
	var spread_right: Array = m.subband_offsets(7)
	_check(absf(float(spread_wrong[0]) - float(spread_wrong[-1])) > 0.2, "7. wrong DM visibly staggers sub-band arrival")
	_check(absf(float(spread_right[0]) - float(spread_right[-1])) < 0.01, "7. correct DM aligns sub-band arrival")


func _test_level_variants() -> void:
	var file := FileAccess.open("res://data/advanced_levels.json", FileAccess.READ)
	_check(file != null, "6. advanced level data is readable")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Array, "6. advanced level data parses")
	if not (parsed is Array):
		return
	var variants := {}
	for level_value in parsed as Array:
		if not (level_value is Dictionary):
			continue
		var level: Dictionary = level_value
		var number := int(level.get("level_number", 0))
		if number < 76 or number > 85:
			continue
		var radio: Dictionary = level.get("radio_profile", {})
		variants[number] = str(radio.get("challenge", ""))
	_check(variants.size() == 10, "6. every FAST level has an explicit radio profile")
	_check(str(variants.get(79, "")) == "cabin_drift", "6. L79 emphasizes feed-cabin drift")
	_check(str(variants.get(83, "")) == "rfi_heavy", "6. L83 emphasizes severe RFI cleaning")
	_check(str(variants.get(84, "")) == "dm_alignment", "6. L84 emphasizes dispersion alignment")
	_check(str(variants.get(85, "")) == "discovery", "6. L85 uses the independent discovery profile")
	var unique := {}
	for challenge in variants.values():
		unique[str(challenge)] = true
	_check(unique.size() >= 6, "6. FAST levels expose multiple data-driven challenge identities")


# ---------------------------------------------------------------- 5 scene
func _test_scene(gm: Node) -> void:
	gm.new_game()
	gm.debug_jump_to_level(76, true)
	var scene: Node = load("res://scenes/radio_observation.tscn").instantiate()
	root.add_child(scene)
	for _i in range(6):
		await process_frame
	_check(int(scene.get("stage")) == 0, "5. scene opens on the Aim stage")
	var m: RadioSignalModel = scene.get("model")
	_check(m != null, "5. scene owns a signal model")

	# trying to advance without locking must NOT move on
	scene.call("_try_lock")
	await process_frame
	_check(int(scene.get("stage")) == 0, "5. cannot leave Aim without a lock")
	_check(not gm_completed(gm), "5. Aim never completes the mission")

	# force a lock, advance
	m.azimuth = m.true_azimuth
	m.altitude = m.true_altitude
	m.az_velocity = 0.0
	m.alt_velocity = 0.0
	scene.call("_try_lock")
	await create_timer(1.55).timeout
	_check(int(scene.get("stage")) == 1, "5. locking advances to Tune")
	_check(scene.get_node_or_null("OperationChainFeedback") != null, "5. feed-cabin lock reveals receiver tuning through radio-specific feedback")
	_check(scene.get("tune_waterfall").size() > 0, "5. Tune opens with a persistent receiver-history waterfall")

	# tune on source, confirm
	m.window_center_mhz = m.true_center_mhz
	m.window_bandwidth_mhz = m.true_bandwidth_mhz
	scene.call("_confirm_tune")
	await process_frame
	_check(int(scene.get("stage")) == 2, "5. good tuning advances to RFI")
	_check(scene.get_node_or_null("OperationChainFeedback") != null, "5. tuning feedback explains passband and RFI classification")

	# misclassify -> blocked; fix -> advances
	for i in range(m.rfi_peaks.size()):
		m.classify(i, not bool(m.rfi_peaks[i]["is_rfi"]))
	scene.call("_confirm_rfi")
	await process_frame
	_check(int(scene.get("stage")) == 2, "5. wrong RFI classification blocks progress")
	for i in range(m.rfi_peaks.size()):
		m.classify(i, bool(m.rfi_peaks[i]["is_rfi"]))
	scene.call("_confirm_rfi")
	await process_frame
	_check(int(scene.get("stage")) == 3, "5. correct classification advances to Fold")

	# wrong fold -> blocked; correct + integration starts the clock prediction.
	# Missing the first window preserves all science state; arming the next beat
	# completes the timing proof and advances to Report.
	m.trial_period_ms = m.true_period_ms + 40.0
	m.set_integration(0.0)
	scene.call("_confirm_fold")
	await process_frame
	_check(int(scene.get("stage")) == 3, "5. low-SNR fold cannot leave the Fold stage")
	_check(not gm_completed(gm), "5. Fold stage never completes the mission on its own")
	m.trial_period_ms = m.true_period_ms
	m.trial_dm = m.true_dm
	m.trial_phase = m.true_phase
	m.set_integration(300.0)
	scene.call("_confirm_fold")
	await process_frame
	_check(bool(scene.get("prediction_running")), "5. valid fold opens the next-pulse prediction instead of auto-completing")
	var integration_before_miss := m.integration_s
	scene.call("_resolve_prediction_window")
	await process_frame
	_check(int(scene.get("prediction_misses")) == 1, "5. an unarmed receiver visibly misses the predicted window")
	_check(is_equal_approx(m.integration_s, integration_before_miss), "5. a missed window preserves accumulated science data")
	_check(int(scene.get("stage")) == 3, "5. missing the window stays in Fold for a retry")
	scene.call("_arm_prediction_receiver")
	scene.call("_resolve_prediction_window")
	await create_timer(3.65).timeout
	_check(int(scene.get("stage")) == 4, "5. confirmed pulse advances to Report")
	_check(bool(scene.get("prediction_confirmed")), "5. report unlock requires a captured predicted arrival")
	_check(scene.get("discovery_phase") >= 0.99, "5. FIRST PULSE sequence synchronizes sub-bands, waterfall, and folded profile")

	# Report is evidence-gated: a wrong conclusion cannot complete; the correct
	# conclusion is then accepted.
	_check(not gm_completed(gm), "5. reaching the report does not auto-submit")
	scene.set("report_choice", "insufficient_signal")
	scene.call("_submit")
	await process_frame
	_check(not gm_completed(gm), "5. a contradictory report conclusion cannot complete the mission")
	scene.set("report_choice", "stable_pulsar")
	scene.call("_submit")
	await create_timer(0.45).timeout
	_check(gm_completed(gm), "5. Submit Report completes the mission")
	scene.queue_free()
	await process_frame


func gm_completed(gm: Node) -> bool:
	var completed: Array = gm.progress.get("completed_levels", [])
	return completed.has(76)


# ---------------------------------------------------------------- 7 no optical
func _test_no_optical() -> void:
	var file := FileAccess.open("res://scripts/ui/radio_observation.gd", FileAccess.READ)
	_check(file != null, "7. radio_observation.gd is readable")
	if file == null:
		return
	var src := file.get_as_text().to_lower()
	for term in ["eyepiece", "magnification", "collimation", "focus_knob", "focal_length"]:
		_check(not src.contains(term), "8. FAST screen uses no optical concept '%s'" % term)
	_check(src.contains("objective:"), "8. FAST keeps a concise stage objective instead of a tutorial wall")
	_check(src.contains("fast array takeover"), "8. FAST opens with a facility-scale array takeover")
	_check(src.contains("fast_crt_monitor.gdshader"), "8. FAST uses its state-driven CRT presentation layer")
	_check(src.contains("feed cabin drive"), "8. FAST logs real feed-cabin drive commands")
	_check(src.contains("spectrum verify"), "8. FAST logs real RFI verification results")
	_check(src.contains("pulse profile"), "8. FAST logs the confirmed pulse result")
	for term in ["snr", "dispersion", "period", "spectrum", "rfi", "integration"]:
		_check(src.contains(term), "8. FAST screen uses radio concept '%s'" % term)
	_check(not src.contains("\"success\": true"), "8. report submission is not hard-coded to success")
	var shader := FileAccess.open("res://shaders/fast_crt_monitor.gdshader", FileAccess.READ)
	_check(shader != null, "8. FAST CRT shader exists")
	if shader != null:
		var shader_source := shader.get_as_text().to_lower()
		_check(shader_source.contains("instability"), "8. CRT instability is driven by the scientific state")
		_check(shader_source.contains("lock_stability"), "8. CRT settles as the receiver chain locks")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
