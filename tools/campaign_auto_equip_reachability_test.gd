extends SceneTree

var failures := 0
var cases := 0

func _initialize() -> void:
	await process_frame
	var gm: Node = root.get_node("/root/GameManager")
	var cabinet: Control = load("res://scripts/ui/parts_cabinet.gd").new()
	for number in gm.available_level_numbers():
		gm.new_game()
		gm.debug_jump_to_level(number, false)
		var targets: Array = gm.current_level().get("target_pool", []).duplicate()
		if targets.is_empty():
			targets.append(gm.current_target_object_id())
		for target in targets:
			gm.new_game()
			gm.debug_jump_to_level(number, false)
			if not gm.set_level_target_choice(str(target)):
				var overrides: Dictionary = gm.progress.get("level_target_overrides", {})
				overrides[str(gm.current_level().get("id", ""))] = str(target)
				gm.progress["level_target_overrides"] = overrides
			cases += 1
			var label := "L%d/%s" % [number, str(target)]
			while not gm.next_pending_mission_step().is_empty():
				var step: Dictionary = gm.next_pending_mission_step()
				gm.apply_auto_equip(gm.auto_equip_plan())
				var id := str(step.get("require_part_id", ""))
				_check(gm.equipped_part_id(str(gm.get_part(id).get("type", ""))) == id, label + " prescribed experiment part")
				gm.mark_mission_step_done(str(step.get("id", "")))
			var plan: Array = gm.auto_equip_plan()
			gm.apply_auto_equip(plan)
			for entry in plan:
				var part: Dictionary = gm.get_part(str(entry.part_id))
				_check(gm.is_part_compatible_with_current_level(part), label + " compatible " + str(entry.part_id))
				_check(gm.equipped_part_id(str(entry.part_type)) == str(entry.part_id), label + " apply matches preview")
			if gm.current_observation_mode() == "naked_eye":
				continue
			if gm.call("_uses_tube_subassembly"):
				var config: Dictionary = gm.tube_subassembly_config()
				var subparts := {}
				for i in range(config.order.size()):
					subparts[str(config.order[i])] = true
					gm.equip_part(str(config.ids[i]))
				gm.set_collimation_score(100.0)
				gm.save_tube_assembly(subparts, 100.0, 100.0, false)
			gm.reset_assembly()
			for type in gm.required_part_types_for_current_level():
				gm.install_part(str(type), 0)
			_check(gm.telescope_is_ready(), label + " rig ready")
			_check(gm.missing_required_parts().is_empty(), label + " exact required parts")
			var science_type: String = gm.recommended_space_instrument_type()
			if science_type != "":
				_check(gm.equipped_part_id(science_type) != "", label + " science instrument included")
				gm.install_part(science_type, 0)
				_check(gm.space_instrument_block_reason(science_type) == "", label + " science planning unlocked")
				continue
			if str(gm.current_level().get("telescope_family", "")) == "fast_radio":
				_check(plan.size() == 3, label + " unchanged FAST chain")
				continue
			gm.selected_object_id = gm.current_target_object_id()
			gm.set_collimation_score(100.0)
			gm.set_tracking_rate(1.0 if gm.has_tracking_mount_equipped() else 0.0)
			var req: Dictionary = gm.active_observation_requirements()
			var altitude := clampf(60.0, float(req.get("altitude_min", 0.0)), float(req.get("altitude_max", 90.0)))
			var result: Dictionary = gm.evaluate_selected_object({
				"requires_focus": gm.current_requires_focus(), "focus_error": 0.0,
				"observation_requirements": req, "altitude": altitude,
				"filter": str(req.get("filter", "none")), "exposure": (float(req.get("exposure_min", 0.0)) + float(req.get("exposure_max", 1.0))) * 0.5,
				"dark_adaptation": 1.0, "averted_vision": true, "visual_detection_techniques_enabled": true,
				"tracking_rate": gm.tracking_rate(), "observation_elapsed": 120.0, "cloud_attenuation": 0.0,
			})
			_check(bool(result.get("success", false)), label + " recommended observation succeeds " + str(result.get("technique_failure", {})))
			_check(bool(cabinet.call("_is_recommended", gm.get_part(gm.equipped_part_id("eyepiece")))), label + " cabinet badge matches eyepiece")
			print("PASS CASE ", label)
	cabinet.free()
	print("CAMPAIGN AUTO EQUIP cases=%d failures=%d" % [cases, failures])
	quit(0 if failures == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL " + label)
