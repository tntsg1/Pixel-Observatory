extends SceneTree

var failures := 0
var audio: Node
var feedback: Node
var events: Array[String] = []


func _initialize() -> void:
	await process_frame
	audio = root.get_node_or_null("/root/AudioManager")
	feedback = root.get_node_or_null("/root/InteractionFeedback")
	_check(audio != null, "AudioManager is available")
	_check(feedback != null, "InteractionFeedback is available")
	if audio == null or feedback == null:
		quit(1)
		return
	feedback.feedback_sfx_requested.connect(func(event_name: String) -> void: events.append(event_name))
	var view := load("res://scenes/collimation.tscn").instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	var sliders := _find_sliders(view)
	_check(sliders.size() == 4, "collimation exposes four mechanical mirror sliders")
	if sliders.is_empty():
		view.queue_free()
		quit(1)
		return
	var slider := sliders[0]
	_check(bool(slider.get_meta("feedback_sfx_suppressed", false)), "collimation slider suppresses the release ui_adjust sound")
	events.clear()
	slider.value += slider.step
	await process_frame
	_check(audio.is_event_loop_playing("collimation_adjust_loop"), "value movement starts one continuous ratchet loop")
	_check(not events.has("ui_adjust"), "value movement does not emit a one-shot ui_adjust")
	await create_timer(0.13).timeout
	_check(not audio.is_event_loop_playing("collimation_adjust_loop"), "ratchet stops within 120ms after the value stops changing")

	slider.value += slider.step
	await process_frame
	slider.drag_ended.emit(true)
	await process_frame
	_check(not audio.is_event_loop_playing("collimation_adjust_loop"), "drag end stops the ratchet without a delayed click")
	_check(not events.has("ui_adjust"), "drag end does not add a generic adjustment sound")

	for index in range(10):
		slider.value += slider.step if index % 2 == 0 else -slider.step
		await process_frame
	_check(audio._loop_event_players.size() <= 1, "repeated movement reuses one loop player")
	view.queue_free()
	await process_frame
	_check(audio._loop_event_players.is_empty(), "leaving collimation clears the loop player")
	print("COLLIMATION AUDIO FEEDBACK TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _find_sliders(node: Node) -> Array[HSlider]:
	var found: Array[HSlider] = []
	for child in node.get_children():
		if child is HSlider:
			found.append(child as HSlider)
		found.append_array(_find_sliders(child))
	return found


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  fail: " + label)
