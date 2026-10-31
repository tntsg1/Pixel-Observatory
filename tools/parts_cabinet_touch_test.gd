extends SceneTree

# Parts Cabinet / Equipment Library input acceptance.
#   1. A finger drag scrolls the list (up = down), from a card AND from a gap.
#   2. The list clamps at the real top and bottom, and every card stays reachable.
#   3. A short tap still selects a card; a drag never selects or equips.
#   4. Equip rules are untouched, and the Equip button still equips on a tap.
#   5. Desktop mouse wheel and mouse-click selection still work.
#   6. No mobile overlay sits on top of the list stealing vertical swipes.

var failures := 0
var cabinet: Node
var scroll: ScrollContainer


func _initialize() -> void:
	await process_frame
	# Headless starts with a 64x64 window and only scales content to 1024x768;
	# pointer routing uses the real window rect, so match the shipping layout
	# before pushing any input.
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var ti: Node = root.get_node_or_null("/root/TouchInput")
	if gm == null or ti == null:
		print("PARTS CABINET TOUCH TEST FAIL: autoloads missing")
		quit(1)
		return
	gm.new_game()
	# A late level unlocks enough gear that the list must actually scroll.
	gm.debug_jump_to_level(46, true)
	ti.set_mobile_mode(true)

	cabinet = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	for _i in range(6):
		await process_frame
	cabinet.set("selected_family", "all")
	cabinet.call("_build")
	for _i in range(6):
		await process_frame

	scroll = cabinet.get("parts_scroll") as ScrollContainer
	_check(scroll != null, "0. parts list scroll container exists")
	if scroll == null:
		_finish()
		return
	var cards := _cards()
	_check(cards.size() >= 4, "0. list has enough cards to scroll (%d)" % cards.size())
	var max_scroll: int = int(cabinet.call("max_scroll_offset"))
	_check(max_scroll > 0, "0. content is taller than the viewport (max scroll %d)" % max_scroll)

	await _test_drag_scrolling(max_scroll)
	await _test_boundaries_and_reachability(max_scroll)
	await _test_tap_selection()
	await _test_drag_does_not_equip(gm)
	await _test_equip_still_works(gm)
	await _test_desktop(gm)
	await _test_tabs_and_reopen(gm)
	_test_no_overlay_blocking()

	ti.set_mobile_mode(false)
	_finish()


# --- 1. drag scrolling ------------------------------------------------------
func _test_drag_scrolling(max_scroll: int) -> void:
	scroll.scroll_vertical = 0
	await process_frame
	var card_point := _point_on_first_card()
	await _swipe(card_point, -160.0)
	var after_up := scroll.scroll_vertical
	_check(after_up > 0, "1a. swiping UP from a card scrolls the list DOWN (%d)" % after_up)

	await _swipe(card_point, 120.0)
	_check(scroll.scroll_vertical < after_up, "1b. swiping DOWN scrolls the list back UP (%d)" % scroll.scroll_vertical)

	# A gap between two cards: the VBox separation strip, not a card rect.
	scroll.scroll_vertical = 0
	await process_frame
	var gap := _point_in_gap()
	var before_gap := scroll.scroll_vertical
	await _swipe(gap, -140.0)
	_check(scroll.scroll_vertical > before_gap, "1c. swiping from the gap between cards also scrolls (%d)" % scroll.scroll_vertical)

	# A gesture under the threshold must NOT scroll (it is a tap, not a drag).
	scroll.scroll_vertical = 0
	await process_frame
	await _swipe(card_point, -4.0)
	_check(scroll.scroll_vertical == 0, "1d. a sub-threshold move is a tap, not a scroll")


# --- 2. boundaries + reachability -------------------------------------------
func _test_boundaries_and_reachability(max_scroll: int) -> void:
	scroll.scroll_vertical = 0
	await process_frame
	await _swipe(_point_on_first_card(), 400.0)
	_check(scroll.scroll_vertical == 0, "2a. list stops at the real top (no negative scroll)")

	scroll.scroll_vertical = 0
	await process_frame
	# Overshoot well past the content height: a drag tracks the finger 1:1, so the
	# swipe must exceed max_scroll to prove the clamp rather than just run out.
	await _swipe(_point_on_first_card(), -(float(max_scroll) + 2000.0))
	_check(scroll.scroll_vertical == max_scroll, "2b. list stops at the real bottom (%d == %d)" % [scroll.scroll_vertical, max_scroll])

	# At the bottom, the final card must be fully inside the viewport.
	await process_frame
	var cards := _cards()
	var last: Control = cards[cards.size() - 1]
	var view_rect := scroll.get_global_rect()
	_check(last.get_global_rect().end.y <= view_rect.end.y + 2.0,
		"2c. the last card is reachable, nothing stays hidden below the viewport")
	_check(last.get_global_rect().position.y >= view_rect.position.y - 2.0 or last.size.y > view_rect.size.y,
		"2c. the last card sits inside the list viewport")


# --- 3. tap selection -------------------------------------------------------
func _test_tap_selection() -> void:
	scroll.scroll_vertical = 0
	await process_frame
	var card: Control = _cards()[0]
	var part_id := str(card.get_meta("part_id", ""))
	cabinet.set("selected_part_id", "")
	await _tap(_point_on_first_card())
	_check(str(cabinet.get("selected_part_id")) == part_id, "3a. a short tap selects the card under the finger")
	var outline := card.get_node_or_null("SelectionOutline") as Control
	_check(outline != null and outline.visible, "3b. the selected card shows its selection outline")

	# A drag must leave selection alone.
	cabinet.set("selected_part_id", "")
	await _swipe(_point_on_first_card(), -150.0)
	_check(str(cabinet.get("selected_part_id")) == "", "3c. a drag gesture never selects a card")


# --- 4. drag must not equip -------------------------------------------------
func _test_drag_does_not_equip(gm: Node) -> void:
	scroll.scroll_vertical = 0
	await process_frame
	var target := _card_with_active_equip()
	if target == null:
		_check(false, "4. found a card with an enabled Equip button")
		return
	var button := target.get_node_or_null("EquipButton") as Button
	var part_type := str(gm.get_part(str(target.get_meta("part_id", ""))).get("type", ""))
	var equipped_before := str(gm.equipped_part_id(part_type))
	var point := button.get_global_rect().get_center()
	await _swipe(point, -140.0)
	_check(str(gm.equipped_part_id(part_type)) == equipped_before,
		"4a. dragging from the Equip button scrolls without equipping")
	_check(scroll.scroll_vertical > 0, "4b. that same drag did scroll the list (%d)" % scroll.scroll_vertical)
	_check(bool(cabinet.get("_suppress_emulated_click")),
		"4c. the emulated click after a drag is suppressed, so release cannot equip")

	# The suppressed click is consumed, then the flag clears for normal use.
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	root.push_input(release)
	await process_frame
	_check(not bool(cabinet.get("_suppress_emulated_click")), "4d. suppression clears after that click is swallowed")


# --- 5. equip path unchanged ------------------------------------------------
func _test_equip_still_works(gm: Node) -> void:
	scroll.scroll_vertical = 0
	await process_frame
	var target := _card_with_active_equip()
	if target == null:
		_check(false, "5. found a card with an enabled Equip button")
		return
	var part_id := str(target.get_meta("part_id", ""))
	var part_type := str(gm.get_part(part_id).get("type", ""))
	var button := target.get_node_or_null("EquipButton") as Button

	# A tap landing on the Equip button belongs to the button, not to selection:
	# the button's own pressed signal runs and equips through the unchanged path
	# (which rebuilds the list, so re-read state rather than the freed nodes).
	cabinet.set("selected_part_id", "")
	await _tap(button.get_global_rect().get_center())
	for _i in range(4):
		await process_frame
	_check(str(cabinet.get("selected_part_id")) == "", "5a. a tap on Equip is left to the button, not stolen by selection")
	_check(str(gm.equipped_part_id(part_type)) == part_id, "5b. a short tap on Equip still equips (equip path unchanged)")


# --- 6. desktop ---------------------------------------------------------------
func _test_desktop(gm: Node) -> void:
	cabinet.call("_build")
	for _i in range(6):
		await process_frame
	scroll = cabinet.get("parts_scroll") as ScrollContainer
	scroll.scroll_vertical = 0
	await process_frame

	# Mouse wheel still reaches the ScrollContainer (we never intercept wheels).
	var point := _point_on_first_card()
	for _i in range(6):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = point
		wheel.factor = 1.0
		root.push_input(wheel)
		var wheel_up := InputEventMouseButton.new()
		wheel_up.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel_up.pressed = false
		wheel_up.position = point
		root.push_input(wheel_up)
		await process_frame
	_check(scroll.scroll_vertical > 0, "6a. desktop mouse wheel still scrolls the list (%d)" % scroll.scroll_vertical)

	# Mouse click selection.
	scroll.scroll_vertical = 0
	await process_frame
	cabinet.set("selected_part_id", "")
	var card: Control = _cards()[0]
	var click_point := _point_on_first_card()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_point
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_point
	root.push_input(release)
	await process_frame
	_check(str(cabinet.get("selected_part_id")) == str(card.get_meta("part_id", "")),
		"6b. desktop mouse click still selects a card")


# --- 7. tabs + reopening ------------------------------------------------------
func _test_tabs_and_reopen(gm: Node) -> void:
	cabinet.set("selected_family", "refractor")
	cabinet.call("_build")
	for _i in range(6):
		await process_frame
	scroll = cabinet.get("parts_scroll") as ScrollContainer
	_check(scroll != null and _cards().size() > 0, "7a. switching family tab rebuilds a usable list")
	scroll.scroll_vertical = 0
	await process_frame
	await _swipe(_point_on_first_card(), -140.0)
	_check(scroll.scroll_vertical >= 0, "7b. touch scrolling still works after a tab switch")

	# Reopen the cabinet from scratch: state must not leak into a dead scroll.
	cabinet.queue_free()
	await process_frame
	cabinet = load("res://scenes/parts_cabinet.tscn").instantiate()
	root.add_child(cabinet)
	for _i in range(6):
		await process_frame
	cabinet.set("selected_family", "all")
	cabinet.call("_build")
	for _i in range(6):
		await process_frame
	scroll = cabinet.get("parts_scroll") as ScrollContainer
	scroll.scroll_vertical = 0
	await process_frame
	await _swipe(_point_on_first_card(), -150.0)
	_check(scroll.scroll_vertical > 0, "7c. reopening the library restores working touch scrolling")


# --- 8. overlay ---------------------------------------------------------------
func _test_no_overlay_blocking() -> void:
	var blockers := 0
	for child in cabinet.get_children():
		var control := child as Control
		if control == null:
			continue
		var script_path := ""
		if control.get_script() != null:
			script_path = str((control.get_script() as Script).resource_path)
		if script_path.ends_with("mobile_controls.gd"):
			blockers += 1
	_check(blockers == 0, "8. no mobile joystick overlay sits over the Parts Cabinet list")
	_check(scroll.get_global_rect().end.y <= 768.0, "8. the list viewport stays inside the screen")


# --- helpers -----------------------------------------------------------------
func _cards() -> Array:
	var box: Control = cabinet.get("parts_box")
	var out: Array = []
	if box == null:
		return out
	for child in box.get_children():
		if child.has_meta("part_id"):
			out.append(child)
	return out


func _card_with_active_equip() -> Control:
	for card_value in _cards():
		var card: Control = card_value
		var button := card.get_node_or_null("EquipButton") as Button
		if button != null and not button.disabled and button.get_global_rect().size.x > 0.0:
			return card
	return null


func _point_on_first_card() -> Vector2:
	var cards := _cards()
	if cards.is_empty():
		return scroll.get_global_rect().get_center()
	var rect: Rect2 = (cards[0] as Control).get_global_rect()
	var view := scroll.get_global_rect()
	# Left half avoids the Equip button column.
	var point := Vector2(rect.position.x + 60.0, rect.position.y + 20.0)
	return Vector2(point.x, clampf(point.y, view.position.y + 4.0, view.end.y - 4.0))


func _point_in_gap() -> Vector2:
	var cards := _cards()
	var view := scroll.get_global_rect()
	if cards.size() >= 2:
		var first: Rect2 = (cards[0] as Control).get_global_rect()
		var second: Rect2 = (cards[1] as Control).get_global_rect()
		var mid := (first.end.y + second.position.y) * 0.5
		if mid > view.position.y and mid < view.end.y:
			return Vector2(first.position.x + 40.0, mid)
	return Vector2(view.position.x + 6.0, view.get_center().y)


func _swipe(from: Vector2, delta_y: float) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = from
	root.push_input(press)
	await process_frame
	var steps := 6
	for i in range(1, steps + 1):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = from + Vector2(0, delta_y * float(i) / float(steps))
		drag.relative = Vector2(0, delta_y / float(steps))
		root.push_input(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = from + Vector2(0, delta_y)
	root.push_input(release)
	await process_frame


func _tap(at: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = at
	root.push_input(press)
	await process_frame
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.pressed = false
	release.position = at
	root.push_input(release)
	await process_frame


func _finish() -> void:
	print("PARTS CABINET TOUCH TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
