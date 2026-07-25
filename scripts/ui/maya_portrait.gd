class_name MayaPortrait
extends RefCounted

# One source of truth for Maya's supplied full-body artwork. The PNGs remain
# untouched; every scene uses the full 408x612 canvas and scales it only through
# TextureRect so her head, hands, boots and accessories are never cropped.

const DISCOVER := "discover"
const THINK := "think"
const EXPLAIN := "explain"
const EMPHASIZE := "emphasize"

const POSE_PATHS := {
	DISCOVER: "res://assets/characters/maya/点子.png",
	THINK: "res://assets/characters/maya/思考.png",
	EXPLAIN: "res://assets/characters/maya/讲解.png",
	EMPHASIZE: "res://assets/characters/maya/讲解 (2).png"
}


static func texture_path(pose: String) -> String:
	return str(POSE_PATHS.get(_normalized_pose(pose), POSE_PATHS[EXPLAIN]))


static func apply_to(rect: TextureRect, pose: String) -> void:
	if rect == null:
		return
	# Set presentation rules before assigning the image, matching the project's
	# pixel-art import contract and avoiding one-frame stretch artifacts.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := texture_path(pose)
	rect.texture = load(path) if ResourceLoader.exists(path) else null
	rect.visible = rect.texture != null
	rect.set_meta("maya_pose", _normalized_pose(pose))
	rect.set_meta("maya_source_path", path)


static func create(
	parent: Node,
	node_name: String,
	pose: String,
	position: Vector2,
	size: Vector2,
	z_index := 0
) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.position = position
	rect.size = size
	rect.z_index = z_index
	apply_to(rect, pose)
	parent.add_child(rect)
	return rect


static func story_pose(line: Dictionary, event_id: String, line_index: int, line_count: int) -> String:
	var explicit := str(line.get("maya_pose", ""))
	if explicit != "":
		return _normalized_pose(explicit)
	var speaker := str(line.get("speaker", "Maya")).to_lower()
	var portrait := str(line.get("portrait", "maya")).to_lower()
	if speaker != "maya" and portrait != "maya":
		return ""

	# The opening deliberately demonstrates all four supplied actions while
	# Maya introduces the room, reasons about the course, discovers the first
	# target and emphasizes the first controls.
	if event_id == "intro":
		match line_index:
			0: return EXPLAIN
			1: return DISCOVER
			2: return EXPLAIN
			3: return THINK
			5: return EMPHASIZE
			_: return EMPHASIZE if line_index >= line_count - 1 else EXPLAIN

	var event := event_id.to_lower()
	if event.ends_with("_after") or event.contains("epilogue") or event.contains("result"):
		return THINK
	if event.contains("below_horizon") or event.contains("unlock") or event.contains("discovery"):
		return DISCOVER
	if (
		event.contains("assembly")
		or event.contains("focus")
		or event.contains("finder")
		or event.contains("collimation")
		or event.contains("tube")
	):
		return EMPHASIZE

	var copy := (
		str(line.get("text_en", "")) + " " + str(line.get("text_zh", ""))
	).to_lower()
	if _contains_any(copy, ["result", "compare", "evidence", "analy", "why", "结果", "比较", "证据", "分析", "为什么"]):
		return THINK
	if _contains_any(copy, ["found", "discover", "appears", "notice", "发现", "出现", "注意到", "升起"]):
		return DISCOVER
	if _contains_any(copy, ["press", "hold", "must", "remember", "step", "按", "必须", "记住", "步骤", "先"]):
		return EMPHASIZE
	return EXPLAIN


static func tutorial_pose(key: String, copy := "") -> String:
	var context := (key + " " + copy).to_lower()
	if _contains_any(context, ["cloud", "below_horizon", "unlock", "new_", "发现", "云", "地平线", "解锁"]):
		return DISCOVER
	if _contains_any(context, ["result", "quality", "compare", "logbook", "结果", "质量", "比较", "日志"]):
		return THINK
	if _contains_any(context, ["focus", "finder", "collimation", "assembly", "tube", "tracking", "map", "调焦", "寻星", "准直", "组装", "追踪", "地图"]):
		return EMPHASIZE
	return EXPLAIN


static func brief_pose(card_id: String, is_complete := false) -> String:
	if is_complete:
		return THINK
	var id := card_id.to_lower()
	if _contains_any(id, ["focus", "finder", "collimation", "assembly", "tracking", "manual", "controls"]):
		return EMPHASIZE
	if _contains_any(id, ["discovery", "horizon", "spectrum", "infrared", "radio"]):
		return DISCOVER
	return EXPLAIN


static func _normalized_pose(pose: String) -> String:
	match pose.to_lower():
		"discover", "discovery", "发现":
			return DISCOVER
		"think", "thinking", "analysis", "思考":
			return THINK
		"emphasize", "important", "explain2", "讲解2":
			return EMPHASIZE
		_:
			return EXPLAIN


static func _contains_any(copy: String, needles: Array) -> bool:
	for needle_value in needles:
		if copy.contains(str(needle_value)):
			return true
	return false
