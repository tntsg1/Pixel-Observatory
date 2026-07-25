extends SceneTree

var failures := 0
var gm: Node
var teaching: Node


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	gm = root.get_node_or_null("/root/GameManager")
	teaching = root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		_fail("required autoloads are missing")
		quit(1)
		return
	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"

	_check_all_assets()
	await _check_all_briefs_render()
	await _check_dobsonian_chinese_tutorial()

	if failures == 0:
		print("LEARNING CARD COMPLETENESS TEST PASS")
		quit(0)
	else:
		print("LEARNING CARD COMPLETENESS TEST FAIL: ", failures)
		quit(1)


func _check_all_assets() -> void:
	var empty_images: Array[String] = []
	var missing_images: Array[String] = []
	var unloadable_images: Array[String] = []
	for card_value in gm.learning_cards_data:
		var card: Dictionary = card_value
		var card_id := str(card.get("id", ""))
		var image_path := str(card.get("image", ""))
		if image_path == "":
			empty_images.append(card_id)
			continue
		if not ResourceLoader.exists(image_path):
			missing_images.append("%s -> %s" % [card_id, image_path])
			continue
		if not load(image_path) is Texture2D:
			unloadable_images.append("%s -> %s" % [card_id, image_path])
	_check(empty_images.is_empty(), "every learning card declares an image: %s" % str(empty_images))
	_check(missing_images.is_empty(), "every learning-card image exists: %s" % str(missing_images))
	_check(unloadable_images.is_empty(), "every learning-card image loads as Texture2D: %s" % str(unloadable_images))


func _check_all_briefs_render() -> void:
	var broken: Array[String] = []
	for card_value in gm.learning_cards_data:
		var card: Dictionary = card_value
		var card_id := str(card.get("id", ""))
		teaching.active_card_mode = "brief"
		teaching.active_card_id = card_id
		var node: Node = load("res://scenes/learning_card.tscn").instantiate()
		root.add_child(node)
		await process_frame
		await process_frame
		var diagram := node.get_node_or_null("ConceptDiagram") as TextureRect
		var scroll := node.get_node_or_null("ConceptTutorialScroll") as ScrollContainer
		var notes := node.get_node_or_null("ConceptTutorialScroll/ConceptTutorialText") as RichTextLabel
		var drawn: Rect2 = node.call("debug_diagram_draw_rect")
		var valid := (
			diagram != null
			and diagram.texture != null
			and diagram.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
			and diagram.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			and scroll != null
			and notes != null
			and notes.get_parsed_text().contains("WHY IT WORKS")
			and notes.get_parsed_text().contains("WHAT YOU DO")
			and notes.get_parsed_text().contains("WATCH FOR")
			and drawn.size.x > 80.0
			and drawn.size.y > 80.0
			and Rect2(0, 0, 1024, 768).encloses(drawn)
		)
		if not valid:
			broken.append(card_id)
		node.queue_free()
		await process_frame
	_check(broken.is_empty(), "all concept briefs render a diagram and three-part tutorial: %s" % str(broken))


func _check_dobsonian_chinese_tutorial() -> void:
	gm.language_mode = "zh"
	gm.progress["language_mode"] = "zh"
	teaching.active_card_mode = "brief"
	teaching.active_card_id = "dobsonian_manual_altaz"
	var node: Node = load("res://scenes/learning_card.tscn").instantiate()
	root.add_child(node)
	await process_frame
	await process_frame
	var notes := node.get_node_or_null("ConceptTutorialScroll/ConceptTutorialText") as RichTextLabel
	var diagram := node.get_node_or_null("ConceptDiagram") as TextureRect
	_check(diagram != null and diagram.texture.resource_path.ends_with("dobsonian_main_blueprint.png"), "Dobsonian brief uses the formal blueprint")
	_check(notes != null and notes.get_parsed_text().contains("左右转动摇箱调整方位"), "Dobsonian tutorial explains the actual Alt/Az controls")
	_check(notes != null and notes.get_parsed_text().contains("轻推、松手、观察"), "Dobsonian tutorial teaches the manual tracking rhythm")
	_check(notes != null and notes.get_parsed_text().contains("大幅推动很容易冲过目标"), "Dobsonian tutorial names the common overshoot mistake")
	node.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("FAIL: ", message)
