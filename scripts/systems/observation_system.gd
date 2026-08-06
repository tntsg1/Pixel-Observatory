extends RefCounted
class_name ObservationSystem


static func evaluate(stats: Dictionary, celestial_object: Dictionary, extra_context: Dictionary = {}) -> Dictionary:
	var observation_mode := str(extra_context.get("observation_mode", "telescope"))
	if observation_mode == "naked_eye":
		return _evaluate_naked_eye(celestial_object)
	return _evaluate_telescope(stats, celestial_object, extra_context)


static func _evaluate_naked_eye(celestial_object: Dictionary) -> Dictionary:
	# Naked-eye viewing ignores telescope stats entirely. What matters is
	# whether the object is bright enough for human eyes.
	var visible := bool(celestial_object.get("naked_eye_visible", false))
	var brightness := float(celestial_object.get("brightness", 0.0))
	var object_type := str(celestial_object.get("type_en", "")).to_lower()

	var quality := "Failed"
	var feedback_en := "This object is far too faint for naked eyes. A telescope is needed."
	var feedback_zh := "这个目标对肉眼来说太暗了，需要望远镜。"
	var visual_effect := "clear"

	if not visible:
		quality = "Failed"
		visual_effect = "dim"
	elif brightness >= 90.0:
		quality = "Excellent"
		feedback_en = "The Moon is bright enough to see with your eyes, but a telescope reveals more detail."
		feedback_zh = "月亮足够亮，肉眼就能看见，但望远镜能揭示更多细节。"
	elif brightness >= 60.0:
		quality = "Good"
		feedback_en = "Bright objects like this are within reach of your naked eyes."
		feedback_zh = "像这样的明亮目标，肉眼就能看到。"
		if object_type.contains("planet"):
			feedback_en = "To your eyes a planet is just a steady bright point. A telescope shows its disk."
			feedback_zh = "在肉眼里行星只是一个稳定的亮点，望远镜才能看到它的圆面。"
	else:
		quality = "Fair"
		visual_effect = "dim"
		feedback_en = "You can barely make it out. Your eyes collect only a little light."
		feedback_zh = "勉强能看到。眼睛能收集的光很有限。"

	return {
		"quality": quality,
		"success": quality == "Excellent" or quality == "Good",
		"visual_effect": visual_effect,
		"feedback_en": feedback_en,
		"feedback_zh": feedback_zh,
		"observation_mode": "naked_eye",
		"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}
	}


static func _evaluate_telescope(stats: Dictionary, celestial_object: Dictionary, extra_context: Dictionary) -> Dictionary:
	var focus_error := float(extra_context.get("focus_error", 0.0))
	var requires_focus := bool(extra_context.get("requires_focus", false))
	var focus_tolerance := float(extra_context.get("focus_tolerance", 0.06))
	var minimum_success_quality := str(extra_context.get("minimum_success_quality", "Good"))
	var environment: Dictionary = extra_context.get("environment", {})
	# E2 drift: the target has wandered out of the eyepiece entirely. This is
	# a hard Failed regardless of everything else - telescope_view is the
	# only caller that ever sets this key (flow_test's direct evaluate()
	# calls never do, so the 24-level regression path is untouched).
	if bool(extra_context.get("target_off_center", false)):
		return {
			"quality": "Failed",
			"success": false,
			"visual_effect": "dim",
			"feedback_en": "The target has drifted out of view. Re-center it.",
			"feedback_zh": "目标已漂出视野，重新居中。",
			"observation_mode": "telescope",
			"focus_error": focus_error,
			"out_of_focus": requires_focus and focus_error > focus_tolerance,
			"effective_clarity": 0.0,
			"seeing_eff": 1.0,
			"seeing_label": "Good",
			"ratios": {"light": 0.0, "clarity": 0.0, "stability": 0.0}
		}

	# Out-of-focus optics lose clarity before anything else.
	var effective_clarity := float(stats.get("clarity_score", 0.0)) - focus_error * 120.0
	effective_clarity = clampf(effective_clarity, 0.0, 100.0)

	var light_ratio := _ratio(float(stats.get("light_score", 0.0)), float(celestial_object.get("required_light_score", 1.0)))
	var clarity_ratio := _ratio(effective_clarity, float(celestial_object.get("required_clarity", 1.0)))
	var stability_ratio := _ratio(float(stats.get("stability_score", 0.0)), float(celestial_object.get("required_stability", 1.0)))
	var technique_gains := {
		"dark_adaptation": 1.0,
		"averted_vision": 1.0
	}
	var visual_detection_target := _uses_visual_detection_techniques(celestial_object, extra_context)
	if visual_detection_target and bool(extra_context.get("visual_detection_techniques_enabled", false)):
		# These are observer-side detectability gains, not upgrades to the
		# telescope. They improve faint-structure light/contrast while leaving
		# mount stability untouched.
		var adaptation := clampf(float(extra_context.get("dark_adaptation", 0.0)), 0.0, 1.0)
		# Full adaptation is deliberately meaningful under the L18 cloud
		# snapshot: it must move a barely comfortable faint-nebula observation
		# into the next readable tier instead of changing only hidden decimals.
		var adaptation_light_gain := lerpf(1.0, 1.30, adaptation)
		var adaptation_clarity_gain := lerpf(1.0, 1.06, adaptation)
		light_ratio *= adaptation_light_gain
		clarity_ratio *= adaptation_clarity_gain
		technique_gains["dark_adaptation"] = adaptation_light_gain
		if bool(extra_context.get("averted_vision", false)):
			light_ratio *= 1.08
			clarity_ratio *= 1.04
			technique_gains["averted_vision"] = 1.08

	# --- Seeing: atmospheric steadiness limits how much magnification is
	# actually usable. No environment field = good seeing, high altitude,
	# no penalty -> identical behavior to pre-environment levels (L1-L9 etc).
	var seeing_label := "Good"
	var seeing_eff := 1.0
	if not environment.is_empty():
		var seeing_key := str(environment.get("seeing", "good")).to_lower()
		var seeing_base := 1.0
		# The atmosphere also imposes an ABSOLUTE magnification ceiling that
		# no aperture can buy its way past - otherwise a 100mm objective
		# raises useful_magnification_limit enough to dodge the poor-seeing
		# penalty entirely (bypassing the L11 lesson).
		var seeing_cap := 9999.0
		match seeing_key:
			"poor":
				seeing_base = 0.72
				seeing_cap = 55.0
				seeing_label = "Poor"
			"average":
				seeing_base = 0.88
				seeing_cap = 110.0
				seeing_label = "Average"
			_:
				seeing_base = 1.0
				seeing_label = "Good"
		var altitude := float(extra_context.get("altitude", 45.0))
		var altitude_factor := clampf(altitude / 30.0, 0.62, 1.0)
		seeing_eff = seeing_base * altitude_factor
		var magnification := float(extra_context.get("magnification", 0.0))
		var useful_limit := float(stats.get("useful_magnification_limit", 0.0))
		# Altitude already discounts the relative term via seeing_eff - do
		# NOT scale the absolute cap by it too, or low-power (the intended
		# correct answer) gets punished as well.
		var useful_limit_eff := minf(useful_limit * seeing_eff, seeing_cap)
		if magnification > 0.0 and useful_limit_eff > 0.0 and magnification > useful_limit_eff:
			var penalty_ratio: float = useful_limit_eff / magnification
			clarity_ratio *= penalty_ratio
			stability_ratio *= penalty_ratio

		# --- Sky brightness / cloud cover: reduce effective light ratio.
		# NOTE: 0.7 (not the initially-specced 0.62) - with the current best
		# unlocked objective (100mm, light_score 83.3) and Andromeda's
		# required_light_score 75, 0.62 pushes L20's ratio to 0.69 (Poor),
		# making its Fair minimum_success_quality mathematically unreachable
		# even with perfect gear. 0.7 keeps a real, visible penalty (city
		# sky clearly worse than dark) while leaving L20 completable.
		var sky_brightness := str(environment.get("sky_brightness", "")).to_lower()
		match sky_brightness:
			"city":
				light_ratio *= 0.7
			"suburban":
				light_ratio *= 0.85
			"dark":
				light_ratio *= 1.08
		var active_filter := str(extra_context.get("filter", "none"))
		if active_filter == "nebula" and _nebula_filter_eligible(celestial_object):
			# A narrow nebula filter rejects part of the artificial sky glow,
			# improving emission/planetary-nebula contrast without erasing the
			# site's penalty. Galaxies and clusters receive no such bonus.
			light_ratio *= 1.10
			clarity_ratio *= 1.04
		var cloud_cover := float(environment.get("cloud_cover", 0.0))
		if extra_context.has("cloud_attenuation"):
			# Real-time attenuation from telescope_view's drifting cloud
			# layer: waiting for a gap between clouds is an actual strategy.
			# GameManager only sets this key from telescope_view's live loop;
			# callers that never pass it (e.g. flow_test's direct evaluate()
			# calls) keep the static formula below untouched.
			var atten := clampf(float(extra_context.get("cloud_attenuation", 0.0)), 0.0, 1.0)
			light_ratio *= (1.0 - 0.75 * atten)
		elif cloud_cover > 0.0:
			light_ratio *= (1.0 - 0.5 * clampf(cloud_cover, 0.0, 1.0))
		light_ratio = clampf(light_ratio, 0.0, 4.0)

	var min_ratio: float = min(light_ratio, min(clarity_ratio, stability_ratio))
	var quality := "Failed"
	if min_ratio >= 1.3:
		quality = "Excellent"
	elif min_ratio >= 1.0:
		quality = "Good"
	elif min_ratio >= 0.75:
		quality = "Fair"
	elif min_ratio >= 0.45:
		quality = "Poor"

	var out_of_focus := requires_focus and focus_error > focus_tolerance
	if out_of_focus:
		# You cannot claim a top-quality observation with a blurred image.
		if quality == "Excellent" or quality == "Good":
			quality = "Fair"
	var requirement_failure := _requirement_failure(stats, extra_context)
	var success := (not out_of_focus) and requirement_failure.is_empty() and _quality_rank(quality) >= _quality_rank(minimum_success_quality)
	if not requirement_failure.is_empty() and _quality_rank(quality) > _quality_rank("Fair"):
		quality = "Fair"

	var visual_effect := "clear"
	var feedback_en := "Good observation. Identify the object to complete the mission."
	var feedback_zh := "观测效果不错。识别目标即可完成任务。"
	if out_of_focus:
		visual_effect = "blurry"
		feedback_en = "The image is out of focus. Adjust the focus knob until the target becomes sharp."
		feedback_zh = "图像失焦了。请转动调焦旋钮，直到目标变清晰。"
	elif not requirement_failure.is_empty():
		visual_effect = str(requirement_failure.get("visual_effect", "clear"))
		feedback_en = str(requirement_failure.get("en", "The observing technique is not ready."))
		feedback_zh = str(requirement_failure.get("zh", "请完成当前关卡标出的观测方法。"))
	elif light_ratio < clarity_ratio and light_ratio < stability_ratio:
		visual_effect = "dim"
		feedback_en = "This object is dim with the current telescope. A larger objective lens would collect more light."
		feedback_zh = "这个目标在当前望远镜里偏暗。更大口径的物镜能收集更多光。"
	elif clarity_ratio < stability_ratio:
		visual_effect = "blurry"
		feedback_en = "The image is blurry. Better alignment or lower magnification can improve clarity."
		feedback_zh = "图像有些模糊。更好的安装对齐或更低倍率能提升清晰度。"
	elif stability_ratio < 1.0:
		visual_effect = "shaky"
		feedback_en = "The telescope is shaking. A stable mount makes planets and stars easier to observe."
		feedback_zh = "望远镜正在抖动。稳定支架会让行星和恒星更容易观测。"
	elif quality == "Excellent":
		feedback_en = "Excellent observation. Your telescope setup is comfortably above the target requirements."
		feedback_zh = "优秀观测。你的望远镜配置明显高于目标要求。"
	elif quality == "Fair":
		feedback_en = "The target is barely visible. You can study it, but this is not strong enough for mission completion."
		feedback_zh = "目标勉强可见。你能看到它，但还不足以完成任务。"
		if success:
			feedback_en = "The target is faint but usable for this first deep-sky observation. Identify it to complete the mission."
		else:
			feedback_en = "Focus is aligned, but this deep-sky target is still too faint for this mission. Upgrade aperture or stability."
	elif quality == "Poor" or quality == "Failed":
		feedback_en = "The target is too hard to see. Return to the workshop and improve the telescope."
		feedback_zh = "目标太难看清。回到组装台改进望远镜。"
	if success and str(extra_context.get("success_feedback_en", "")) != "":
		feedback_en = str(extra_context.get("success_feedback_en", ""))
	if success and str(extra_context.get("success_feedback_zh", "")) != "":
		feedback_zh = str(extra_context.get("success_feedback_zh", ""))
	return {
		"quality": quality,
		"success": success,
		"visual_effect": visual_effect,
		"feedback_en": feedback_en,
		"feedback_zh": feedback_zh,
		"observation_mode": "telescope",
		"focus_error": focus_error,
		"out_of_focus": out_of_focus,
		"effective_clarity": effective_clarity,
		"seeing_eff": seeing_eff,
		"seeing_label": seeing_label,
		"technique_failure": requirement_failure,
		"technique_gains": technique_gains,
		"ratios": {
			"light": light_ratio,
			"clarity": clarity_ratio,
			"stability": stability_ratio
		}
	}


static func _requirement_failure(stats: Dictionary, context: Dictionary) -> Dictionary:
	var requirements: Dictionary = context.get("observation_requirements", {})
	if requirements.is_empty(): return {}
	var altitude := float(context.get("altitude", 45.0))
	if requirements.has("altitude_min") and altitude < float(requirements["altitude_min"]): return {"en":"Target is too low. Raise the aim or wait for the observing window.","zh":"目标高度太低。请抬高视野或等待合适观测窗口。","visual_effect":"shaky","code":"altitude_low"}
	if requirements.has("altitude_max") and altitude > float(requirements["altitude_max"]): return {"en":"Mercury has left the required twilight window.","zh":"水星已经离开本关要求的暮光观测窗口。","visual_effect":"dim","code":"window"}
	var magnification := float(context.get("magnification", stats.get("magnification", 0.0)))
	if requirements.has("magnification_min") and magnification < float(requirements["magnification_min"]): return {"en":"Magnification is too low to resolve this feature. Fit a shorter eyepiece.","zh":"倍率不足以分辨该特征。请换用更短焦距目镜。","visual_effect":"blurry","code":"magnification_low"}
	if requirements.has("magnification_max") and magnification > float(requirements["magnification_max"]): return {"en":"Magnification is too high: the field is narrow and turbulence is enlarged.","zh":"倍率过高：视野过窄，而且大气扰动被放大。","visual_effect":"shaky","code":"magnification_high"}
	if requirements.has("aperture_min") and float(stats.get("aperture_mm", 0.0)) < float(requirements["aperture_min"]): return {"en":"This target is too faint for the current aperture. Use the larger mirror recommended for this mission.","zh":"这个目标对当前口径来说过于暗弱。请使用本关推荐的更大口径主镜。","visual_effect":"dim","code":"aperture_mm"}
	if requirements.has("light_min") and float(stats.get("light_score", 0.0)) < float(requirements["light_min"]): return {"en":"The aperture does not collect enough light for this target.","zh":"当前口径无法为这个目标收集足够光线。","visual_effect":"dim","code":"aperture"}
	if requirements.has("stability_min") and float(stats.get("stability_score", 0.0)) < float(requirements["stability_min"]): return {"en":"The mount is not stable enough for this detail.","zh":"当前支架不够稳定，无法分辨该细节。","visual_effect":"shaky","code":"stability"}
	var exposure := float(context.get("exposure", 0.5))
	if requirements.has("exposure_min") and exposure < float(requirements["exposure_min"]): return {"en":"Exposure is too low; the phase edge has disappeared.","zh":"曝光太低，月相边缘已经消失。","visual_effect":"dim","code":"underexposed"}
	if requirements.has("exposure_max") and exposure > float(requirements["exposure_max"]): return {"en":"Venus is overexposed. Reduce exposure until the crescent edge returns.","zh":"金星过曝。请降低曝光，直到弯月边缘重新出现。","visual_effect":"blurry","code":"overexposed"}
	if str(requirements.get("filter", "none")) != str(context.get("filter", "none")): return {"en":"Select the nebula filter to suppress the bright sky background.","zh":"请选择星云滤镜，以压低明亮天空背景。","visual_effect":"dim","code":"filter"}
	if float(context.get("dark_adaptation", 0.0)) < float(requirements.get("dark_adaptation_min", 0.0)): return {"en":"Your eyes are not dark-adapted yet. Wait without bright light.","zh":"眼睛尚未完成暗适应。请避开强光并继续等待。","visual_effect":"dim","code":"dark_adaptation"}
	if bool(requirements.get("require_averted_vision", false)) and not bool(context.get("averted_vision", false)): return {"en":"Use averted vision: hold Shift and look just beside the target.","zh":"请使用侧视法：按住 Shift，并看向目标旁边。","visual_effect":"dim","code":"averted_vision"}
	if bool(requirements.get("require_tracking", false)):
		var rate := float(context.get("tracking_rate", 0.0))
		if rate < float(requirements.get("tracking_min", 0.85)) or rate > float(requirements.get("tracking_max", 1.15)): return {"en":"Tracking rate is mismatched. Tune it close to 1.0x.","zh":"追踪速率不匹配。请调到接近 1.0x。","visual_effect":"shaky","code":"tracking"}
	if requirements.has("seeing_patience") and float(context.get("observation_elapsed", 0.0)) < 4.0 + float(requirements["seeing_patience"]) * 4.0: return {"en":"Low-altitude seeing is still boiling. Hold the view and wait for a steady instant.","zh":"低空视宁度仍在剧烈扰动。请保持视野，等待短暂稳定。","visual_effect":"shaky","code":"seeing_patience"}
	return {}


static func _ratio(value: float, required: float) -> float:
	return value / max(1.0, required)


static func _nebula_filter_eligible(celestial_object: Dictionary) -> bool:
	# Broadband galaxies, clusters and the synchrotron-dominated Crab do not
	# receive a blanket brightness upgrade. These targets have strong emission
	# lines that a beginner nebula filter can actually isolate.
	return str(celestial_object.get("id", "")) in [
		"orion_nebula",
		"ring_nebula",
		"lagoon_nebula",
		"dumbbell_nebula",
	]


static func _is_diffuse_target(celestial_object: Dictionary) -> bool:
	# A supernova remnant is an extended low-surface-brightness source even
	# when its catalog type does not contain the word "nebula". The Crab used
	# to miss both dark-adaptation and averted-vision gains for exactly that
	# naming reason, while galaxies passed through the same flow correctly.
	var type_lower := str(celestial_object.get("type_en", "")).to_lower()
	var visual_profile := str(celestial_object.get("visual_profile", "")).to_lower()
	return (
		type_lower.contains("nebula")
		or type_lower.contains("galaxy")
		or type_lower.contains("supernova remnant")
		or visual_profile == "supernova_remnant"
	)


static func _uses_visual_detection_techniques(celestial_object: Dictionary, context: Dictionary) -> bool:
	if _is_diffuse_target(celestial_object):
		return true
	var requirements_value: Variant = context.get("observation_requirements", {})
	var requirements: Dictionary = requirements_value if requirements_value is Dictionary else {}
	var type_lower := str(celestial_object.get("type_en", "")).to_lower()
	# Only clusters whose mission explicitly asks for averted vision belong in
	# this detection path. Bright open clusters keep their normal presentation.
	return type_lower.contains("cluster") and bool(requirements.get("require_averted_vision", false))


static func _quality_rank(quality: String) -> int:
	match quality:
		"Failed":
			return 0
		"Poor":
			return 1
		"Fair":
			return 2
		"Good":
			return 3
		"Excellent":
			return 4
	return 3
