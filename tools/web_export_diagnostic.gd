extends SceneTree

# The public game index is permanently owned by the custom shell builder.
const RELEASE_OUTPUT := "E:/godot/ai-game-0628/build/web/.godot-export/index.html"
const RELEASE_EXCLUDES := "addons/tama/**,addons/blastbullets2d/**,artifacts/**,web/**,output/**,TIWAN/**,tama-web-backup/**,ImportedAssets/_archives/**,spritesheets/**,spriteframes/**,assets/audio/music/giant_telescope.mp3,assets/audio/music/space_fast_theme.mp3,assets/audio/ambient/fast_terminal_hum.ogg,assets/reference/observatory_ai_mockup.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await create_timer(3.0).timeout
	var platform := EditorExportPlatformWeb.new()
	print("WEB_TEMPLATE_RELEASE=", platform.find_export_template("web_nothreads_release.zip"))
	var presets := platform.get_current_presets()
	print("WEB_PRESET_COUNT=", presets.size())
	if presets.is_empty():
		var manual_preset := platform.create_preset()
		var names: Array[String] = []
		for property in manual_preset.get_property_list():
			names.append(str(property.get("name", "")))
		print("WEB_MANUAL_PROPERTIES=", names)
		manual_preset.set("name", "Web Diagnostic")
		manual_preset.set("export_path", RELEASE_OUTPUT)
		manual_preset.set("export_filter", 1)
		manual_preset.set("exclude_filter", RELEASE_EXCLUDES)
		manual_preset.set("variant/extensions_support", false)
		manual_preset.set("variant/thread_support", false)
		platform.clear_messages()
		var manual_result := platform.export_project(manual_preset, false, RELEASE_OUTPUT, 0, false)
		print("WEB_MANUAL_EXPORT_RESULT=", manual_result)
		for index in range(platform.get_message_count()):
			print("WEB_MANUAL_MESSAGE=", platform.get_message_type(index), "|", platform.get_message_category(index), "|", platform.get_message_text(index))
	for preset in presets:
		print("WEB_PRESET=", preset.get_preset_name(), " PATH=", preset.get_export_path())
		platform.clear_messages()
		var result := platform.export_project(preset, false, "C:/tmp/pixel-observatory-web-diagnostic/index.html", 0, false)
		print("WEB_EXPORT_RESULT=", result)
		for index in range(platform.get_message_count()):
			print("WEB_EXPORT_MESSAGE=", platform.get_message_type(index), "|", platform.get_message_category(index), "|", platform.get_message_text(index))
	quit()
