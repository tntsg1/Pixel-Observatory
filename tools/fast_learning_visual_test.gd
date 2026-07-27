extends SceneTree

const APPROVED_BLUEPRINT := "res://assets/assembly/fast_blueprint_center_cropped.png"

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var gm := root.get_node_or_null("/root/GameManager")
	var teaching := root.get_node_or_null("/root/TeachingFlowManager")
	if gm == null or teaching == null:
		_fail("required autoloads are available")
		_finish()
		return

	gm.new_game()
	gm.language_mode = "en"
	gm.progress["language_mode"] = "en"
	teaching.active_card_mode = "brief"
	teaching.active_card_id = "radio_signal_observing"

	var card := load("res://scenes/learning_card.tscn").instantiate() as Control
	root.add_child(card)
	for _i in range(5):
		await process_frame

	var diagram := card.find_child("ConceptDiagram", true, false) as TextureRect
	_check(diagram != null, "FAST concept brief renders a diagram")
	if diagram != null:
		_check(diagram.texture != null, "FAST concept diagram texture is loaded")
		if diagram.texture != null:
			_check(diagram.texture.resource_path == APPROVED_BLUEPRINT,
				"FAST concept brief renders the approved user blueprint crop")
		_check(diagram.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
			"FAST concept blueprint keeps its source aspect ratio")
		_check(diagram.position.x >= 74.0 and diagram.position.y >= 120.0,
			"FAST concept blueprint stays inside the visual panel")
		_check(diagram.position.x + diagram.size.x <= 630.0
				and diagram.position.y + diagram.size.y <= 668.0,
			"FAST concept blueprint does not cover the tutorial text panel")

	card.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		_fail(message)


func _fail(message: String) -> void:
	failures += 1
	print("  FAIL: %s" % message)


func _finish() -> void:
	print("FAST LEARNING VISUAL TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
