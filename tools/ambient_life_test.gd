extends SceneTree

# Proves the world keeps moving while the PLAYER STANDS STILL.
#
# A screenshot cannot show motion, so this compares frames taken at different
# moments without touching the player: if the room is alive, pixels must differ.
# It also checks the ambient layer never steals input and honours reduced motion.

const OUT := "res://artifacts/ambient"
var failures := 0
var gm: Node
var room: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	if gm == null:
		print("AMBIENT LIFE TEST FAIL: GameManager missing")
		quit(1)
		return

	await _open_lobby()
	await _test_motion()
	_test_non_blocking()
	await _test_reduced_motion()

	print("AMBIENT LIFE TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _open_lobby() -> void:
	room = load("res://scenes/observatory_room.tscn").instantiate()
	root.add_child(room)
	for _i in range(20):
		await process_frame


func _test_motion() -> void:
	var life: Control = room.find_child("AmbientLife", true, false)
	_check(life != null, "1. the lobby has an ambient life layer")
	if life == null:
		return
	# dust is owned by the pre-existing ObservatoryAmbientAnimator; this layer
	# must NOT duplicate it, it only adds per-device status lamps.
	_check(int(life.get("mote_count")) == 0,
		"1. dust is left to the existing animator (no duplicate motes)")
	_check((life.get("indicators") as Array).size() >= 5,
		"1. every major device has its own indicator (%d)" % (life.get("indicators") as Array).size())

	# freeze the player: record its position and never touch input
	var player_before: Vector2 = room.get("player_pos")

	var frame_a := await _grab("01_room_t0.png")
	# let ~1.5 s of ambient time pass with NO player input at all
	for _i in range(90):
		await process_frame
	var frame_b := await _grab("02_room_t1_5.png")
	for _i in range(90):
		await process_frame
	var frame_c := await _grab("03_room_t3_0.png")

	var player_after: Vector2 = room.get("player_pos")
	_check(player_before == player_after,
		"2. the player never moved during the test (proof the motion is ambient)")

	var diff_ab := _diff(frame_a, frame_b)
	var diff_ac := _diff(frame_a, frame_c)
	var diff_bc := _diff(frame_b, frame_c)
	_check(diff_ab > 200,
		"2. the room changed after 1.5 s with the player still (%d pixels moved)" % diff_ab)
	# Comparing only against the t0 frame is a coincidence trap: several
	# indicators and the dome-glass star twinkle are periodic, so t3.0 can
	# legitimately drift back close to t0's phase without motion ever having
	# stopped. The
	# adjacent 1.5s->3.0s comparison proves the room is still animating
	# without depending on where a cycle happens to land.
	_check(diff_bc > 100,
		"2. the room is still changing between 1.5 s and 3.0 s (%d pixels moved)" % diff_bc)
	print("      motion: t0->t1.5 = %d px, t0->t3.0 = %d px, t1.5->t3.0 = %d px" % [diff_ab, diff_ac, diff_bc])

	# the indicators must not all blink together - that reads as one machine
	var styles := {}
	for entry in (life.get("indicators") as Array):
		styles[str((entry as Dictionary).get("style", ""))] = true
	_check(styles.size() >= 4,
		"3. devices use different rhythms, not one shared blink (%d distinct)" % styles.size())


func _test_non_blocking() -> void:
	var life: Control = room.find_child("AmbientLife", true, false)
	if life == null:
		return
	_check(life.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"4. the ambient layer never intercepts clicks")
	# it must sit under the HUD so it can never cover a button
	var hud_index := -1
	var life_index := life.get_index()
	for child in room.get_children():
		if str(child.name).contains("Hud") or str(child.name).contains("HUD"):
			hud_index = child.get_index()
	if hud_index >= 0:
		_check(life_index < hud_index, "4. the ambient layer draws beneath the HUD")


func _test_reduced_motion() -> void:
	# Accessibility: with reduced motion on, the layer must stop animating.
	var feedback: Node = root.get_node_or_null("/root/InteractionFeedback")
	if feedback == null or not feedback.has_method("set_reduced_motion"):
		print("  skip: reduced-motion setting unavailable")
		return
	var was: bool = feedback.call("is_reduced_motion")
	# Toggle the setting live, exactly as the pause menu does, without rebuilding
	# the room: the air must settle on the spot.
	var life: Control = room.find_child("AmbientLife", true, false)
	_check(life != null, "5. ambient layer present before toggling reduced motion")
	feedback.call("set_reduced_motion", true)
	for _i in range(10):
		await process_frame
	_check(life != null and bool(life.get("reduced")),
		"5. reduced-motion mode is picked up live by the ambient layer")
	# Judge THIS layer, not the whole screen: the room also hosts the older
	# ObservatoryAmbientAnimator, whose behaviour is not ours to assert here.
	await _grab("04_reduced_t0.png")
	var clock_before: float = float(life.get("_time"))
	for _i in range(90):
		await process_frame
	await _grab("05_reduced_t1_5.png")
	var clock_after: float = float(life.get("_time"))
	_check(is_equal_approx(clock_before, clock_after),
		"5. with reduced motion on, this layer stops advancing (%.2f -> %.2f)" % [clock_before, clock_after])
	feedback.call("set_reduced_motion", was)


# ---------------------------------------------------------------- helpers
func _grab(name: String) -> Image:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(OUT + "/" + name)
	return img


func _diff(a: Image, b: Image) -> int:
	# count pixels that changed noticeably, sampling on a grid for speed
	if a == null or b == null:
		return 0
	var changed := 0
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02:
				changed += 1
	return changed


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
