extends SceneTree

var failures := 0
var gm: Node
var sm: Node
var original_language := "en"
var original_progress: Dictionary = {}


func _initialize() -> void:
	await process_frame
	gm = root.get_node_or_null("/root/GameManager")
	sm = root.get_node_or_null("/root/StoryManager")
	if gm == null or sm == null:
		print("MAYA PORTRAIT / LANGUAGE TEST FAIL (autoloads missing)")
		quit(1)
		return
	original_language = str(gm.language_mode)
	original_progress = gm.progress.duplicate(true)

	_test_source_art()
	await _test_intro_actions_and_language()
	_test_language_specific_helpers()
	_test_graduation_portrait_and_language()

	gm.language_mode = original_language
	gm.progress = original_progress
	if failures == 0:
		print("MAYA PORTRAIT / LANGUAGE TEST PASS")
		quit(0)
	else:
		print("MAYA PORTRAIT / LANGUAGE TEST FAIL (%d)" % failures)
		quit(1)


func _test_source_art() -> void:
	var expected := {
		MayaPortrait.DISCOVER: "点子.png",
		MayaPortrait.THINK: "思考.png",
		MayaPortrait.EXPLAIN: "讲解.png",
		MayaPortrait.EMPHASIZE: "讲解 (2).png"
	}
	for pose_value in expected:
		var pose := str(pose_value)
		var path := MayaPortrait.texture_path(pose)
		_check(path.ends_with(str(expected[pose])), "%s keeps the supplied filename mapping" % pose)
		_check(ResourceLoader.exists(path), "%s source exists in project resources" % pose)
		var texture := load(path) as Texture2D
		_check(texture != null, "%s loads as Texture2D" % pose)
		if texture != null:
			_check(texture.get_size() == Vector2(408, 612), "%s keeps the original 408x612 canvas" % pose)

	var host := Control.new()
	host.size = Vector2(1024, 768)
	root.add_child(host)
	var portrait := MayaPortrait.create(host, "PortraitContract", MayaPortrait.EXPLAIN, Vector2(40, 40), Vector2(220, 288))
	_check(portrait.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "portrait ignores source size expansion")
	_check(portrait.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "portrait preserves aspect ratio")
	_check(portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "portrait uses nearest-neighbour filtering")
	_check(_inside(Rect2(Vector2.ZERO, host.size), portrait.get_rect()), "portrait stays inside its fixed UI region")
	host.queue_free()


func _test_intro_actions_and_language() -> void:
	var intro: Array = sm.get_dialogue("intro")
	_check(intro.size() >= 6, "new-game intro has enough lines to demonstrate Maya's actions")
	sm.active_event_id = "intro"
	sm.active_event_ids = ["intro"]
	sm.active_lines = intro
	sm.active_context = sm.context_for_event("intro")

	gm.language_mode = "en"
	var story := load("res://scenes/story_dialogue.tscn").instantiate() as Control
	root.add_child(story)
	await process_frame
	var portrait := story.find_child("CharacterPortrait", true, false) as TextureRect
	var portrait_frame := story.find_child("DialoguePortraitFrame", true, false) as Panel
	_check(portrait != null, "story dialogue creates the official Maya portrait region")
	_check(portrait_frame != null, "story dialogue keeps Maya inside the dialogue portrait frame")
	var poses: Dictionary = {}
	for index in range(intro.size()):
		story.set("line_index", index)
		story.call("_show_line")
		if portrait != null:
			poses[str(portrait.get_meta("maya_pose", ""))] = true
			_check(
				portrait_frame != null and _inside(Rect2(Vector2.ZERO, Vector2(1024, 768)), portrait_frame.get_global_rect()),
				"intro portrait frame %d stays on screen" % index
			)
		_check(not _has_cjk(_visible_text(story)), "English intro line %d contains no Chinese" % index)
	var text_label := story.get("text_label") as Label
	if portrait_frame != null and text_label != null:
		_check(not portrait_frame.get_global_rect().intersects(text_label.get_global_rect()), "dialogue portrait does not cover spoken text")
	for required_pose in [MayaPortrait.DISCOVER, MayaPortrait.THINK, MayaPortrait.EXPLAIN, MayaPortrait.EMPHASIZE]:
		_check(poses.has(required_pose), "new-game intro displays Maya pose: %s" % required_pose)

	gm.language_mode = "zh"
	story.call("_on_language_changed")
	var chinese_ui := _visible_text(story)
	_check(_has_cjk(chinese_ui), "Chinese intro renders Chinese copy")
	_check(not _contains_forbidden_english(chinese_ui), "Chinese intro has no English UI labels")
	story.queue_free()
	await process_frame


func _test_language_specific_helpers() -> void:
	var view: Node = load("res://scripts/ui/constellation_observation.gd").new()
	var item := {"name_en": "Orion", "name_zh": "猎户座"}
	gm.language_mode = "en"
	_check(str(view.call("_bilingual_name", item)) == "Orion", "English constellation name is English-only")
	gm.language_mode = "zh"
	_check(str(view.call("_bilingual_name", item)) == "猎户座", "Chinese constellation name is Chinese-only")
	view.free()


func _test_graduation_portrait_and_language() -> void:
	for language in ["en", "zh"]:
		gm.language_mode = language
		var ceremony := load("res://scripts/ui/graduation_ceremony.gd").new() as Control
		ceremony.size = Vector2(1024, 768)
		ceremony.call("_build")
		var portrait := ceremony.find_child("MayaGraduationPortrait", true, false) as TextureRect
		_check(portrait != null and portrait.texture != null, "graduation uses the supplied Maya artwork in %s" % language)
		if portrait != null:
			_check(str(portrait.get_meta("maya_source_path", "")).ends_with("点子.png"), "graduation uses Maya's discovery pose")
			_check(_inside(Rect2(Vector2.ZERO, Vector2(1024, 768)), portrait.get_global_rect()), "graduation portrait stays on screen")
		var copy := _visible_text(ceremony)
		if language == "en":
			_check(not _has_cjk(copy), "English graduation contains no Chinese")
		else:
			_check(_has_cjk(copy), "Chinese graduation renders Chinese copy")
			_check(not _contains_forbidden_english(copy), "Chinese graduation has no English UI labels")
		ceremony.free()


func _visible_text(node: Node) -> String:
	var values: Array[String] = []
	_collect_visible_text(node, values)
	return "\n".join(values)


func _collect_visible_text(node: Node, values: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Label:
		values.append((node as Label).text)
	elif node is RichTextLabel:
		values.append((node as RichTextLabel).get_parsed_text())
	elif node is BaseButton:
		values.append((node as BaseButton).text)
	for child in node.get_children():
		_collect_visible_text(child, values)


func _has_cjk(value: String) -> bool:
	var regex := RegEx.new()
	regex.compile("[一-龿]")
	return regex.search(value) != null


func _contains_forbidden_english(value: String) -> bool:
	var normalized := value.to_lower()
	for word in [
		"astronomy club", "maya", "mission", "progress", "record observation",
		"concept brief", "next", "continue", "graduation", "return to observatory",
		"open club logbook"
	]:
		if normalized.contains(word):
			return true
	return false


func _inside(bounds: Rect2, rect: Rect2) -> bool:
	return (
		rect.position.x >= bounds.position.x
		and rect.position.y >= bounds.position.y
		and rect.end.x <= bounds.end.x
		and rect.end.y <= bounds.end.y
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		print("FAIL: " + message)
