class_name AmbientLife
extends Control

# Ambient life layer: the things that keep moving when the player stands still.
#
# A room where only the player animates reads as a screenshot you can walk
# around in. This layer adds the small, continuous motion that makes a space
# feel inhabited - drifting dust, equipment that is clearly powered on and
# working, a telescope that is still tracking the sky.
#
# Design rules:
#   * pure code drawing - no assets, so it can be dropped into any scene
#   * never blocks input (MOUSE_FILTER_IGNORE) and owns no game state
#   * cheap: a few dozen points and circles per frame
#   * deterministic (seeded), so screenshots and tests stay reproducible
#   * honours the project's reduced-motion accessibility setting
#
# Usage:
#   var life := AmbientLife.new()
#   life.configure({"bounds": ROOM_RECT, "motes": 34, "indicators": [...]})
#   add_child(life)

const MOTE_TINT := Color(0.86, 0.90, 1.0)

var bounds := Rect2(0, 0, 1024, 768)
var mote_count := 0
var mote_tint := MOTE_TINT
var indicators: Array = []          # {rect, style, tint, phase}
var twinkle_zone := Rect2()         # dome-glass patch of twinkling stars
var twinkle_count := 14             # scales up for a full backdrop starfield
var streak_zone := Rect2()          # optional window/door area for meteors
var reduced := false

var _time := 0.0
var _motes: Array = []
var _stars: Array = []
var _rng := RandomNumberGenerator.new()
var _streak_t := -1.0
var _streak_from := Vector2.ZERO
var _streak_to := Vector2.ZERO
var _next_streak := 6.0
var _feedback: Node


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func configure(cfg: Dictionary) -> void:
	bounds = cfg.get("bounds", bounds)
	mote_count = int(cfg.get("motes", 0))
	mote_tint = cfg.get("mote_tint", MOTE_TINT)
	indicators = cfg.get("indicators", [])
	twinkle_zone = cfg.get("twinkle_zone", Rect2())
	twinkle_count = int(cfg.get("twinkle_count", 14))
	streak_zone = cfg.get("streak_zone", Rect2())
	_rng.seed = int(cfg.get("seed", 20260724))
	_build_motes()
	_build_stars()


func _ready() -> void:
	_feedback = get_node_or_null("/root/InteractionFeedback")
	_sync_reduced()
	set_process(true)


func _sync_reduced() -> void:
	# Read the accessibility setting live rather than caching it once at _ready:
	# the player can turn reduced motion on from the pause menu while standing in
	# this very room, and the air should settle immediately.
	if _feedback != null and _feedback.has_method("is_reduced_motion"):
		reduced = bool(_feedback.call("is_reduced_motion"))


func _build_motes() -> void:
	_motes.clear()
	for i in range(mote_count):
		# depth 0 = far (small, dim, slow), 1 = near (larger, brighter, faster)
		var depth := _rng.randf()
		_motes.append({
			"pos": Vector2(
				bounds.position.x + _rng.randf() * bounds.size.x,
				bounds.position.y + _rng.randf() * bounds.size.y),
			"depth": depth,
			"drift": Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.55, -0.12)) * (4.0 + depth * 11.0),
			"sway_phase": _rng.randf() * TAU,
			"sway_rate": _rng.randf_range(0.25, 0.7),
			"sway_amp": _rng.randf_range(2.0, 9.0),
			"twinkle": _rng.randf() * TAU,
		})


func _build_stars() -> void:
	_stars.clear()
	if twinkle_zone.size == Vector2.ZERO:
		return
	# Scattered points of light - on a dome-glass patch this reads as looking
	# straight up at the sky; stretched over a full backdrop it is a quiet
	# starfield. Either way: no scanning line, just stars doing what stars do,
	# quietly brightening and fading, each on its own clock.
	for i in range(twinkle_count):
		_stars.append({
			"pos": Vector2(
				twinkle_zone.position.x + _rng.randf() * twinkle_zone.size.x,
				twinkle_zone.position.y + _rng.randf() * twinkle_zone.size.y),
			"phase": _rng.randf() * TAU,
			"rate": _rng.randf_range(0.35, 0.9),
			"peak": _rng.randf_range(0.35, 0.95),
			"radius": 0.6 + _rng.randf() * 0.8,
			"flare_at": _rng.randf_range(4.0, 16.0),
		})


func _process(delta: float) -> void:
	_sync_reduced()
	if reduced:
		# hold the last frame: no drift, no blinking, no redraw churn
		return
	_time += delta
	for mote in _motes:
		var m: Dictionary = mote
		var p: Vector2 = m["pos"]
		p += (m["drift"] as Vector2) * delta
		# gentle lateral sway so motes never travel in dead-straight lines
		p.x += sin(_time * float(m["sway_rate"]) + float(m["sway_phase"])) * float(m["sway_amp"]) * delta
		# wrap: dust that leaves the top re-enters from the bottom
		if p.y < bounds.position.y - 6.0:
			p.y = bounds.end.y + 4.0
			p.x = bounds.position.x + _rng.randf() * bounds.size.x
		if p.x < bounds.position.x - 6.0:
			p.x = bounds.end.x + 4.0
		elif p.x > bounds.end.x + 6.0:
			p.x = bounds.position.x - 4.0
		m["pos"] = p
	_update_streak(delta)
	queue_redraw()


func _update_streak(delta: float) -> void:
	if streak_zone.size == Vector2.ZERO:
		return
	if _streak_t >= 0.0:
		_streak_t += delta * 1.7
		if _streak_t > 1.0:
			_streak_t = -1.0
			_next_streak = _rng.randf_range(9.0, 22.0)
		return
	_next_streak -= delta
	if _next_streak <= 0.0:
		# a meteor crosses the window: enters top, exits lower and to one side
		var dir: float = 1.0 if _rng.randf() > 0.5 else -1.0
		var start_x: float = streak_zone.position.x + _rng.randf() * streak_zone.size.x
		_streak_from = Vector2(start_x, streak_zone.position.y + _rng.randf() * streak_zone.size.y * 0.35)
		_streak_to = _streak_from + Vector2(dir * streak_zone.size.x * 0.55, streak_zone.size.y * 0.5)
		_streak_t = 0.0


# --- indicator brightness curves ------------------------------------------
# Each style is a different rhythm so two devices never blink in lockstep -
# that is what sells "several machines, each doing its own job".
func _indicator_level(style: String, phase: float) -> float:
	var t: float = _time + phase
	match style:
		"data":
			# irregular activity flicker, like a console processing packets
			var step: float = floorf(t * 7.0)
			var h: float = sin(step * 12.9898 + phase * 78.233) * 43758.5453
			var r: float = h - floorf(h)
			return 0.25 + 0.75 * (1.0 if r > 0.45 else 0.0)
		"standby":
			# slow, calm breathing - powered but idle
			return 0.30 + 0.30 * (0.5 + 0.5 * sin(t * 1.1))
		"pulse":
			# a sharp blip every ~2.4 s
			var cycle: float = fposmod(t, 2.4) / 2.4
			return 0.18 + 0.82 * pow(maxf(0.0, 1.0 - cycle * 7.0), 2.0)
		"track":
			# steady sweep-and-hold, like a mount following the sky
			return 0.35 + 0.45 * (0.5 + 0.5 * sin(t * 0.55))
		"idle":
			return 0.12 + 0.12 * (0.5 + 0.5 * sin(t * 0.7))
	return 0.5


func _draw() -> void:
	# --- drifting dust -----------------------------------------------------
	for mote in _motes:
		var m: Dictionary = mote
		var depth := float(m["depth"])
		var radius := 0.7 + depth * 1.7
		var twinkle := 0.72 + 0.28 * sin(_time * 1.6 + float(m["twinkle"]))
		var alpha := (0.05 + depth * 0.16) * twinkle
		draw_circle(m["pos"], radius, Color(mote_tint.r, mote_tint.g, mote_tint.b, alpha))

	# --- equipment indicators ---------------------------------------------
	for entry in indicators:
		var ind: Dictionary = entry
		var rect: Rect2 = ind.get("rect", Rect2())
		if rect.size == Vector2.ZERO:
			continue
		var level := _indicator_level(str(ind.get("style", "standby")), float(ind.get("phase", 0.0)))
		if reduced:
			level = 0.45
		var tint: Color = ind.get("tint", Color(0.55, 0.95, 0.70))
		var at: Vector2 = rect.position + rect.size * Vector2(float(ind.get("ax", 0.82)), float(ind.get("ay", 0.16)))
		# Three hard circles read as a sticker. A real lamp has a bloom that falls
		# off smoothly, so stack thin rings with a quadratic falloff, then add a
		# hot white core and a faint cross-flare once it is actually bright.
		var layers := 7
		for li in range(layers):
			var t: float = float(li) / float(layers - 1)      # 0 = core, 1 = outer
			var rr: float = 1.8 + t * 7.2
			var fall: float = pow(1.0 - t, 2.4)
			draw_circle(at, rr, Color(tint.r, tint.g, tint.b, 0.13 * fall * level))
		# hot core: washes toward white as it brightens, like a real emitter
		var core := Color(tint.r, tint.g, tint.b).lerp(Color(1, 1, 1), 0.45 * level)
		draw_circle(at, 1.7, Color(core.r, core.g, core.b, 0.45 + 0.5 * level))
		if level > 0.72:
			var flare: float = (level - 0.72) / 0.28
			var arm := 7.5 * flare
			var fc := Color(tint.r, tint.g, tint.b, 0.30 * flare)
			draw_line(at - Vector2(arm, 0), at + Vector2(arm, 0), fc, 1.0)
			draw_line(at - Vector2(0, arm), at + Vector2(0, arm), fc, 1.0)

	# --- twinkling stars on the observation pad's dome glass ----------------
	if not reduced:
		for star_value in _stars:
			var star: Dictionary = star_value
			var t: float = _time * float(star["rate"]) + float(star["phase"])
			var level: float = maxf(0.0, sin(t)) * float(star["peak"])
			# most stars just breathe; occasionally one flares up brighter, like
			# a real star catching a moment of clearer air.
			var since_flare: float = fposmod(_time + float(star["phase"]) * 3.0, float(star["flare_at"]))
			var flare: float = 0.0
			if since_flare < 0.5:
				flare = sin(since_flare / 0.5 * PI)
			var alpha: float = clampf(level + flare * 0.5, 0.0, 1.0)
			if alpha < 0.03:
				continue
			var pos: Vector2 = star["pos"]
			var r: float = float(star["radius"])
			draw_circle(pos, r * 2.2, Color(0.75, 0.88, 1.0, alpha * 0.18))
			draw_circle(pos, r, Color(0.90, 0.95, 1.0, alpha * 0.85))
			if flare > 0.5:
				var arm := r * 3.0 * flare
				var fc := Color(1.0, 1.0, 1.0, (flare - 0.5) * 0.7)
				draw_line(pos - Vector2(arm, 0), pos + Vector2(arm, 0), fc, 0.7)
				draw_line(pos - Vector2(0, arm), pos + Vector2(0, arm), fc, 0.7)

	# --- occasional meteor through the window ------------------------------
	if _streak_t >= 0.0 and not reduced:
		var head: Vector2 = _streak_from.lerp(_streak_to, _streak_t)
		var tail: Vector2 = _streak_from.lerp(_streak_to, maxf(0.0, _streak_t - 0.16))
		var fade := sin(_streak_t * PI)
		draw_line(tail, head, Color(0.86, 0.92, 1.0, 0.42 * fade), 1.6)
		draw_circle(head, 1.7, Color(1.0, 1.0, 1.0, 0.70 * fade))
