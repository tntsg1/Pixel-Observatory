extends RefCounted

# Shared, data-bearing stage handoff for the FAST and space observatory
# consoles. It animates only the replaceable workspace; the host shell,
# navigation, title and terminal remain in place.

var active := false
var duration := 0.0
var outgoing: Control
var incoming: Control

var _host: Control
var _tween: Tween
var _blocker: Control
var _packet: Panel
var _packet_core: ColorRect
var _commit_control: Control
var _commit_origin := Vector2.ZERO
var _outgoing_origin := Vector2.ZERO
var _incoming_origin := Vector2.ZERO
var _midpoint: Callable
var _completed: Callable
var _finished := false


func begin(
		host: Control,
		old_workspace: Control,
		next_workspace: Control,
		from_point: Vector2,
		to_point: Vector2,
		reduced_motion: bool,
		on_midpoint: Callable,
		on_completed: Callable,
		commit_control: Control = null,
		accent: Color = Color(0.78, 0.9, 0.92)
	) -> void:
	abort()
	active = true
	_finished = false
	_host = host
	outgoing = old_workspace
	incoming = next_workspace
	_midpoint = on_midpoint
	_completed = on_completed
	_commit_control = commit_control
	duration = 0.17 if reduced_motion else 1.02

	_blocker = Control.new()
	_blocker.name = "StageTransitionInputGuard"
	_blocker.position = Vector2(20, 70)
	_blocker.size = Vector2(984, 612)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.z_index = 1180
	_blocker.set_meta("stage_transition_guard", true)
	_host.add_child(_blocker)

	_packet = Panel.new()
	_packet.name = "StageHandoffPacket"
	_packet.position = from_point - Vector2(8, 5)
	_packet.size = Vector2(16, 10)
	_packet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packet.z_index = 1182
	_packet.add_theme_stylebox_override("panel", _packet_style(accent))
	_packet.set_meta("handoff_from", from_point)
	_packet.set_meta("handoff_to", to_point)
	_packet.set_meta("handoff_duration", duration)
	_host.add_child(_packet)
	_packet_core = ColorRect.new()
	_packet_core.color = Color(1, 1, 1, 0.92)
	_packet_core.position = Vector2(5, 3)
	_packet_core.size = Vector2(6, 4)
	_packet_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packet.add_child(_packet_core)

	_outgoing_origin = outgoing.position
	_incoming_origin = incoming.position
	incoming.position = _incoming_origin + Vector2(20, 0)
	incoming.modulate = Color(0.72, 0.78, 0.82, 0.0)
	incoming.visible = true
	incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_instance_valid(_commit_control):
		_commit_origin = _commit_control.position
		_commit_control.position.y += 2.0
		_commit_control.modulate = Color(1.08, 1.08, 1.08, 1.0)

	var commit_time := 0.025 if reduced_motion else 0.16
	var panel_time := 0.10 if reduced_motion else 0.42
	var panel_delay := 0.035 if reduced_motion else 0.40
	var midpoint_delay := 0.075 if reduced_motion else 0.52
	var packet_time := 0.11 if reduced_motion else 0.34
	var packet_delay := 0.025 if reduced_motion else 0.28

	_tween = _host.create_tween().bind_node(_host).set_parallel(true)
	_tween.tween_property(_packet, "position", to_point - Vector2(8, 5), packet_time) \
		.set_delay(packet_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_packet, "modulate:a", 0.22, 0.08 if reduced_motion else 0.20) \
		.set_delay(packet_delay + packet_time)
	_tween.tween_property(outgoing, "position", _outgoing_origin + Vector2(-20, 0), panel_time) \
		.set_delay(panel_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(outgoing, "modulate", Color(0.42, 0.46, 0.50, 0.0), panel_time) \
		.set_delay(panel_delay)
	_tween.tween_property(incoming, "position", _incoming_origin, panel_time) \
		.set_delay(panel_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(incoming, "modulate", Color.WHITE, panel_time) \
		.set_delay(panel_delay + (0.0 if reduced_motion else 0.08))
	_tween.tween_callback(_run_midpoint).set_delay(midpoint_delay)
	if is_instance_valid(_commit_control):
		_tween.tween_property(_commit_control, "position", _commit_origin, commit_time)
		_tween.tween_property(_commit_control, "modulate", Color.WHITE, commit_time)
	_tween.tween_callback(_finish).set_delay(duration)


func finish_immediately() -> void:
	if not active:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_run_midpoint()
	_finish()


func abort() -> void:
	var was_active := active
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_commit_control):
		_commit_control.position = _commit_origin
		_commit_control.modulate = Color.WHITE
	if is_instance_valid(outgoing):
		outgoing.position = _outgoing_origin
		outgoing.modulate = Color.WHITE
	if is_instance_valid(incoming):
		incoming.position = _incoming_origin
		incoming.modulate = Color.WHITE
		if was_active:
			incoming.queue_free()
	_cleanup_overlay()
	active = false
	_finished = true


func _run_midpoint() -> void:
	if not active or _midpoint.is_null():
		return
	var callback := _midpoint
	_midpoint = Callable()
	callback.call()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_run_midpoint()
	if is_instance_valid(outgoing):
		outgoing.queue_free()
	if is_instance_valid(incoming):
		incoming.position = _incoming_origin
		incoming.modulate = Color.WHITE
		incoming.mouse_filter = Control.MOUSE_FILTER_PASS
	if is_instance_valid(_commit_control):
		_commit_control.position = _commit_origin
		_commit_control.modulate = Color.WHITE
	_cleanup_overlay()
	active = false
	if not _completed.is_null():
		var callback := _completed
		_completed = Callable()
		callback.call()


func _cleanup_overlay() -> void:
	if is_instance_valid(_blocker):
		_blocker.queue_free()
	if is_instance_valid(_packet):
		_packet.queue_free()
	_blocker = null
	_packet = null
	_packet_core = null


func _packet_style(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(accent.r * 0.20, accent.g * 0.24, accent.b * 0.26, 0.96)
	box.border_color = accent
	box.set_border_width_all(1)
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	box.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	box.shadow_size = 4
	return box
