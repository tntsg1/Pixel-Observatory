extends SceneTree

var failures := 0


func _initialize() -> void:
	await process_frame
	var best_ids: Array[String] = []
	for level_number in [66, 67, 68, 69, 70, 72, 73, 74, 75]:
		var model := SpaceObservationModel.new()
		model.configure({
			"target_id": "mission_%d" % level_number,
			"guide_seed": level_number,
		})
		var best_index := _best_guide_index(model.guide_stars)
		_check(best_index >= 0, "L%d has a valid guide candidate" % level_number)
		if best_index >= 0:
			best_ids.append(str((model.guide_stars[best_index] as Dictionary).get("id", "")))
		_check(_count_usable(model.guide_stars) >= 2, "L%d offers more than one usable candidate" % level_number)

	var distinct := {}
	for id in best_ids:
		distinct[id] = true
	_check(distinct.size() >= 3, "space missions vary the best guide-star position")
	_check(not best_ids.is_empty() and best_ids.count("GS-2") < best_ids.size(), "GS-2 is not always the answer")

	var field := SpaceGuideField.new()
	field.size = Vector2(600, 500)
	var graph := field.drift_graph_rect()
	var plot := field.drift_plot_rect()
	_check(plot.position.y > graph.position.y + 19.0, "drift curve starts below its title band")
	_check(plot.end.y < graph.end.y, "drift curve remains inside its chart frame")
	_check(graph.end.y <= field.size.y - 20.0, "drift chart stays above the lower console boundary")
	field.free()

	print("SPACE GUIDE VARIATION TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _best_guide_index(stars: Array) -> int:
	var best_index := -1
	var best_quality := -1.0
	for index in range(stars.size()):
		var star: Dictionary = stars[index]
		if not bool(star.get("usable", false)):
			continue
		var quality := float(star.get("brightness", 0.0)) - float(star.get("offset", 0.0)) / 30.0
		if quality > best_quality:
			best_quality = quality
			best_index = index
	return best_index


func _count_usable(stars: Array) -> int:
	var count := 0
	for value in stars:
		if bool((value as Dictionary).get("usable", false)):
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
