extends SceneTree

# Concept diagram acceptance for the "Why Some Objects Are Hard to See" card
# (id: naked_eye_limits).
#   1. Only that card's image reference moved, to a real file; its title, text
#      and level progression are untouched.
#   2. Concept Brief renders the art with no stretch, no crop and
#      nearest-neighbour filtering in the dedicated visual column.
#   3. The diagram and scrollable tutorial column never overlap the title or
#      Start button and stay on screen.
#   4. English mode stays English-only; Chinese mode translates the explanation
#      outside the image.
#   5. Mission Complete still builds with its existing layout.

const CARD_ID := "naked_eye_limits"
const NEW_IMAGE := "res://assets/learning_diagrams/naked_eye_limits_light_gathering.png"
const SOURCE_SIZE := Vector2(1672, 941)
const PANEL_RECT := Rect2(56, 74, 912, 612)

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var tf: Node = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or tf == null:
		print("LEARNING CARD DIAGRAM TEST FAIL: autoloads missing")
		quit(1)
		return
	gm.new_game()

	_test_data(gm)
	await _test_brief(gm, tf)
	await _test_language(gm, tf)
	await _test_mission_complete(gm, tf)

	print("LEARNING CARD DIAGRAM TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# --- 1. data ----------------------------------------------------------------
func _test_data(gm: Node) -> void:
	var card: Dictionary = gm.get_learning_card(CARD_ID)
	_check(not card.is_empty(), "1a. card '%s' exists" % CARD_ID)
	_check(str(card.get("image", "")) == NEW_IMAGE, "1b. card points at the new diagram")
	_check(ResourceLoader.exists(NEW_IMAGE), "1c. the new diagram file is in the project")
	var texture := load(NEW_IMAGE) as Texture2D
	_check(texture != null and texture.get_size() == SOURCE_SIZE,
		"1d. supplied artwork imported at its real size %s" % str(SOURCE_SIZE))

	# Title / explanation / progression untouched.
	_check(str(card.get("title_en", "")) == "Why Some Objects Are Hard to See", "1e. English title unchanged")
	_check(str(card.get("title_zh", "")) == "为什么有些天体肉眼难以看见", "1e. Chinese title unchanged")
	_check(str(card.get("text_en", "")).begins_with("Your eyes collect only a small amount of light"), "1f. English explanation unchanged")
	_check(str(card.get("text_zh", "")).begins_with("眼睛能收集的光很少"), "1f. Chinese explanation unchanged")
	var level_2: Dictionary = gm.get_level(2) if gm.has_method("get_level") else {}
	if level_2.is_empty():
		var mm: Node = root.get_node_or_null("/root/MissionManager")
		if mm != null:
			level_2 = mm.get_level(2)
	_check(str(level_2.get("required_concept_card", "")) == CARD_ID, "1g. L2 still requires this concept card (progression unchanged)")

	# No other card was touched, and nothing references the art twice.
	var users := 0
	var missing: Array[String] = []
	for entry_value in gm.learning_cards_data:
		var entry: Dictionary = entry_value
		var image := str(entry.get("image", ""))
		if image == NEW_IMAGE:
			users += 1
		if image != "" and not ResourceLoader.exists(image):
			missing.append(str(entry.get("id", "")))
	_check(users == 1, "1h. exactly one learning card uses the new diagram (%d)" % users)
	_check(missing.is_empty(), "1i. every learning card image still resolves %s" % str(missing))


# --- 2 + 3. brief rendering --------------------------------------------------
func _test_brief(gm: Node, tf: Node) -> void:
	var card_node := await _open_brief(gm, tf, "en")

	var diagram := card_node.get_node_or_null("ConceptDiagram") as TextureRect
	_check(diagram != null, "2a. the brief renders a concept diagram")
	if diagram == null:
		card_node.queue_free()
		await process_frame
		return
	_check(diagram.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "2b. pixel-art nearest-neighbour filtering")
	_check(diagram.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "2c. KEEP_ASPECT_CENTERED: never stretched, never cropped")
	_check(diagram.texture != null and diagram.texture.get_size() == SOURCE_SIZE, "2d. the brief shows the supplied artwork")

	var drawn: Rect2 = card_node.call("debug_diagram_draw_rect")
	_check(drawn.size.x > 0.0, "2e. diagram has a real drawn rect %s" % str(drawn))
	var source_aspect := SOURCE_SIZE.x / SOURCE_SIZE.y
	var drawn_aspect := drawn.size.x / maxf(drawn.size.y, 1.0)
	_check(absf(drawn_aspect - source_aspect) < 0.01,
		"2f. aspect ratio preserved (%.4f vs %.4f)" % [drawn_aspect, source_aspect])

	_check(drawn.size.x >= 500.0 and drawn.size.y >= 280.0,
		"2g. diagram remains a large readable teaching visual (%.0fx%.0f)" % [drawn.size.x, drawn.size.y])

	# 3. containment + no overlap with any text or button.
	_check(Rect2(0, 0, 1024, 768).encloses(drawn), "3a. diagram stays fully on screen (no clipping)")
	_check(PANEL_RECT.grow(1.0).encloses(drawn), "3b. diagram stays inside the concept panel")
	var tutorial_scroll := card_node.get_node_or_null("ConceptTutorialScroll") as ScrollContainer
	_check(tutorial_scroll != null, "3c. concept explanation has a dedicated scrollable tutorial column")
	if tutorial_scroll != null:
		_check(not Rect2(tutorial_scroll.position, tutorial_scroll.size).intersects(drawn), "3d. tutorial column does not cover the diagram")
	var clashes: Array[String] = []
	for child in card_node.get_children():
		var control := child as Control
		if control == null or control == diagram:
			continue
		if not (control is Label or control is Button):
			continue
		var rect := Rect2(control.position, control.size)
		var overlap := rect.intersection(drawn)
		if overlap.size.x > 1.0 and overlap.size.y > 1.0:
			var text := ""
			if control is Label:
				text = (control as Label).text
			else:
				text = (control as Button).text
			clashes.append("%s@%s" % [text.substr(0, 18), str(rect)])
	_check(clashes.is_empty(), "3e. no overlap with title or Start button %s" % str(clashes))

	card_node.queue_free()
	await process_frame


# --- 4. language -------------------------------------------------------------
func _test_language(gm: Node, tf: Node) -> void:
	var en_node := await _open_brief(gm, tf, "en")
	var en_text := _all_text(en_node)
	_check(not _has_cjk(en_text), "4a. English mode shows no Chinese anywhere on the brief")
	_check(en_text.contains("Why Some Objects Are Hard to See"), "4b. English title rendered from the language system")
	en_node.queue_free()
	await process_frame

	var zh_node := await _open_brief(gm, tf, "zh")
	var zh_text := _all_text(zh_node)
	_check(zh_text.contains("为什么有些天体肉眼难以看见"), "4c. Chinese mode translates the title outside the image")
	_check(zh_text.contains("眼睛能收集的光很少"), "4d. Chinese mode translates the explanation outside the image")
	# The art itself is untouched English pixel labels - verified by 2d above.
	zh_node.queue_free()
	await process_frame
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"


# --- 5. mission complete -----------------------------------------------------
func _test_mission_complete(gm: Node, tf: Node) -> void:
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["current_level"] = 2
	var level: Dictionary = gm.current_level()
	var observation := {
		"quality": "Good", "success": true, "observation_mode": "naked_eye",
		"effective_clarity": 78.0,
		"ratios": {"light": 1.04, "clarity": 1.04, "stability": 1.04}
	}
	var stats := {"light_score": 78.0, "clarity_score": 78.0, "stability_score": 78.0, "magnification": 1.0}
	gm.last_learning_card = tf.call("make_mission_complete_payload", level, gm.get_object("moon"), observation, stats)
	tf.active_card_mode = "complete"

	var node: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(node)
	for _i in range(6):
		await process_frame
	var text := _all_text(node)
	_check(text.contains("MISSION COMPLETE"), "5a. Mission Complete still renders its banner")
	_check(text.contains("Continue"), "5b. Continue button still present")
	_check(text.contains("Open Journal"), "5c. Open Journal button still present")
	_check(node.get_node_or_null("ConceptDiagram") == null,
		"5d. Mission Complete layout unchanged (concept art belongs to the brief only)")
	node.queue_free()
	await process_frame


# --- helpers -----------------------------------------------------------------
func _open_brief(gm: Node, tf: Node, language: String) -> Node:
	gm.language_mode = language
	gm.progress["language_mode"] = language
	tf.active_card_mode = "brief"
	tf.active_card_id = CARD_ID
	var node: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(node)
	for _i in range(6):
		await process_frame
	return node


func _all_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	elif node is RichTextLabel:
		out += (node as RichTextLabel).get_parsed_text() + "\n"
	for child in node.get_children():
		out += _all_text(child)
	return out


func _has_cjk(text: String) -> bool:
	for c in text:
		if c >= "一" and c <= "鿿":
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
