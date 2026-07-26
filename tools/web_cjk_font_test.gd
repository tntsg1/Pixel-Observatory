extends SceneTree


func _init() -> void:
	var path := str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	if path == "":
		push_error("WEB CJK FONT TEST FAIL: gui/theme/custom_font is empty")
		quit(1)
		return

	var font := load(path) as Font
	if font == null:
		push_error("WEB CJK FONT TEST FAIL: cannot load %s" % path)
		quit(1)
		return

	var required_codepoints := [
		0x4E2D, 0x6587, 0x5929, 0x53F0, 0x671B,
		0x8FDC, 0x955C, 0x89C2, 0x6D4B, 0x7EC4,
		0x88C5, 0x5C04, 0x7535, 0x7EA2, 0x5916
	]
	for codepoint in required_codepoints:
		if not font.has_char(codepoint):
			push_error("WEB CJK FONT TEST FAIL: missing glyph U+%04X" % codepoint)
			quit(1)
			return

	var scripts := [
		"res://scripts/audio_manager.gd"
	]
	for script_path in scripts:
		if load(script_path) == null:
			push_error("WEB CJK FONT TEST FAIL: cannot load %s" % script_path)
			quit(1)
			return

	var music_paths := [
		"res://assets/audio/music/lobby.mp3",
		"res://assets/audio/music/giant_telescope.mp3",
		"res://assets/audio/music/outdoor_stargazing.mp3",
		"res://assets/audio/music/telescope_assembly.mp3"
	]
	for music_path in music_paths:
		if load(music_path) == null:
			push_error("WEB CJK FONT TEST FAIL: cannot load %s" % music_path)
			quit(1)
			return

	var audio_manager_script := load("res://scripts/audio_manager.gd") as GDScript
	var audio_manager: Node = audio_manager_script.new()
	var expected_music := {
		"res://scenes/observatory_room.tscn": "lobby",
		"res://scenes/telescope_assembly.tscn": "assembly",
		"res://scenes/sky_observation.tscn": "outdoor",
		"res://scenes/radio_observation.tscn": "giant"
	}
	for scene_path in expected_music:
		if audio_manager._music_category_for_scene(scene_path) != expected_music[scene_path]:
			push_error("WEB CJK FONT TEST FAIL: wrong music route for %s" % scene_path)
			quit(1)
			return
	audio_manager.free()

	print("WEB CJK FONT TEST PASS: %s" % path)
	quit(0)
