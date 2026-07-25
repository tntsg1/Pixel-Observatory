extends SceneTree

const SOURCE_PATH := "C:/Users/tntsg/Downloads/ChatGPT Image 2026年7月24日 13_33_35.png"
const OUTPUT_PATH := "res://assets/assembly/space_segmented_blueprint_cropped.png"
const SOURCE_RECT := Rect2i(391, 36, 758, 944)


func _initialize() -> void:
	var source := Image.load_from_file(SOURCE_PATH)
	if source == null or source.is_empty():
		push_error("Unable to load source blueprint: " + SOURCE_PATH)
		quit(1)
		return
	if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(SOURCE_RECT):
		push_error("Crop rect is outside source image: %s in %s" % [SOURCE_RECT, source.get_size()])
		quit(1)
		return
	var cropped := source.get_region(SOURCE_RECT)
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := cropped.save_png(output)
	print("SPACE BLUEPRINT CROP %s source=%s crop=%s output=%s size=%s" % [
		"PASS" if error == OK else "FAIL",
		source.get_size(),
		SOURCE_RECT,
		output,
		cropped.get_size(),
	])
	quit(0 if error == OK else 1)
