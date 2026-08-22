extends SceneTree

# Functional parts in the same telescope family must remain visually
# distinguishable. Sharing one icon hid the difference between the 12 mm and
# 40 mm Cassegrain eyepieces even though they produce very different views.

const PART_FILES := [
	"res://data/telescope_parts.json",
	"res://data/advanced_telescope_parts.json",
]

var failures := 0


func _initialize() -> void:
	var parts: Array = []
	for path in PART_FILES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed != null, "%s parses" % path)
		if parsed is Array:
			parts.append_array(parsed)
		elif parsed is Dictionary:
			parts.append_array(parsed.get("parts", []))

	var icons_by_family: Dictionary = {}
	for raw_part in parts:
		if not raw_part is Dictionary:
			continue
		var part: Dictionary = raw_part
		if bool(part.get("is_placeholder", false)):
			continue
		var icon_path := str(part.get("icon_path", ""))
		var part_id := str(part.get("id", ""))
		var family := str(part.get("telescope_family", "default"))
		_check(not icon_path.is_empty(), "%s declares an icon" % part_id)
		_check(ResourceLoader.exists(icon_path), "%s icon exists" % part_id)
		if icon_path.is_empty():
			continue
		var image := Image.new()
		var image_error := image.load(ProjectSettings.globalize_path(icon_path))
		_check(image_error == OK, "%s icon pixels load" % part_id)
		if image_error == OK:
			_check(_has_clear_corners(image), "%s icon has no rectangular backdrop" % part_id)
		var family_icons: Dictionary = icons_by_family.get(family, {})
		if family_icons.has(icon_path):
			_check(
				false,
				"%s and %s do not share one icon inside %s" % [
					str(family_icons[icon_path]),
					part_id,
					family,
				]
			)
		else:
			family_icons[icon_path] = part_id
		icons_by_family[family] = family_icons

	print("PART TEXTURE IDENTITY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _has_clear_corners(image: Image) -> bool:
	if image.get_width() < 2 or image.get_height() < 2:
		return false
	var corners := [
		Vector2i(0, 0),
		Vector2i(image.get_width() - 1, 0),
		Vector2i(0, image.get_height() - 1),
		Vector2i(image.get_width() - 1, image.get_height() - 1),
	]
	for point in corners:
		if image.get_pixelv(point).a > 0.05:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
