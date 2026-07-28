extends SceneTree

# Verifies the copyright-safe audio policy for every FAST campaign level.

const RETIRED_REMOTE_BGM := "res://assets/audio/music/space_fast_theme.mp3"
const RETIRED_FAST_AMBIENCE := "res://assets/audio/ambient/fast_terminal_hum.ogg"
var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	var game_manager := root.get_node_or_null("/root/GameManager")
	_check(audio != null, "AudioManager autoload exists")
	_check(game_manager != null, "GameManager autoload exists")
	if audio == null or game_manager == null:
		_finish()
		return

	_check(game_manager.levels_data.size() >= 85, "campaign contains FAST L76-L85")
	for level_number in range(76, 86):
		var level: Dictionary = game_manager.levels_data[level_number - 1]
		_check(
			str(level.get("telescope_family", "")) == "fast_radio",
			"L%d is a FAST radio level" % level_number
		)
		_check(
			str(level.get("observation_mode", "")) == "radio",
			"L%d uses the shared radio observation route" % level_number
		)

	var category: String = audio._music_category_for_scene(
		"res://scenes/radio_observation.tscn"
	)
	_check(category == audio.SILENT_MUSIC_CATEGORY, "the shared FAST route is explicitly silent")
	_check(not audio.MUSIC_PATHS.has("giant"), "no remote BGM path remains in MUSIC_PATHS")
	_check(
		not FileAccess.file_exists(RETIRED_REMOTE_BGM)
			and not ResourceLoader.exists(RETIRED_REMOTE_BGM),
		"unlicensed shared remote BGM is absent from the project"
	)
	_check(
		not FileAccess.file_exists(RETIRED_FAST_AMBIENCE)
			and not ResourceLoader.exists(RETIRED_FAST_AMBIENCE),
		"undocumented FAST ambience is absent from the project"
	)

	var scene_source := FileAccess.get_file_as_string("res://scenes/radio_observation.tscn")
	_check(
		not scene_source.contains("AudioStreamPlayer")
			and not scene_source.contains("space_fast_theme")
			and not scene_source.contains("fast_terminal_hum"),
		"FAST scene has no direct hidden music or ambience player"
	)
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/radio_observation.gd")
	_check(
		not ui_source.contains("space_fast_theme")
			and not ui_source.contains("fast_terminal_hum"),
		"all five FAST stages contain no direct music load"
	)

	audio.music_enabled = true
	audio._stop_music(true)
	audio.play_music(str(audio.MUSIC_PATHS["lobby"]))
	await create_timer(0.25).timeout
	_check(
		audio._active_music_player != null and audio._active_music_player.playing,
		"fixture begins with approved lobby music"
	)
	audio._enforce_music_policy("")
	audio._fade_music_to_silence()
	await create_timer(audio.MUSIC_FADE_SECONDS + 0.15).timeout
	var runtime_state: Dictionary = audio.music_runtime_state()
	print("FAST RIGHTS AUDIT RUNTIME: %s" % JSON.stringify(runtime_state))
	_check(
		str(runtime_state.get("current_path", "")).is_empty()
			and str(runtime_state.get("active_stream_path", "")).is_empty(),
		"FAST policy leaves no current or active music path"
	)

	audio._stop_music(true)
	_finish()


func _finish() -> void:
	print(
		"FAST MUSIC RIGHTS AUDIT TEST %s"
		% ("PASS" if failures == 0 else "FAIL (%d)" % failures)
	)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  fail: " + label)
