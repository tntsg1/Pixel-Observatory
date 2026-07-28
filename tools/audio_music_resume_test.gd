extends SceneTree

# Run:
# godot --headless --path <project> --script res://tools/audio_music_resume_test.gd

var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	_check(audio != null, "AudioManager autoload exists")
	if audio == null:
		quit(1)
		return

	audio.music_enabled = true
	audio._stop_music(true)
	var lobby_path := str(audio.MUSIC_PATHS["lobby"])
	var assembly_path := str(audio.MUSIC_PATHS["assembly"])
	_check(
		audio._music_category_for_scene("res://scenes/space_observation.tscn")
			== audio.SILENT_MUSIC_CATEGORY
			and audio._music_category_for_scene("res://scenes/radio_observation.tscn")
			== audio.SILENT_MUSIC_CATEGORY,
		"Space and every FAST observation use the explicit cleared-audio route"
	)
	_check(
		audio._music_category_for_scene("res://scenes/telescope_view.tscn")
			== audio.SILENT_MUSIC_CATEGORY,
		"eyepiece telescope view has an explicit silent music route"
	)
	_check(
		audio._music_category_for_scene("res://scenes/sky_observation.tscn") == "outdoor",
		"outdoor sky observation keeps its approved music route"
	)

	audio.play_music(lobby_path)
	await create_timer(0.75).timeout
	var lobby_leave_position: float = audio._active_music_player.get_playback_position()
	_check(lobby_leave_position > 0.1, "lobby music advances before leaving")

	audio.play_music(assembly_path)
	await create_timer(0.15).timeout
	var cached_position := float(audio._music_playback_positions.get(lobby_path, 0.0))
	_check(
		absf(cached_position - lobby_leave_position) < 0.25,
		"leaving lobby caches its playback position"
	)

	audio.play_music(lobby_path)
	await create_timer(0.15).timeout
	var resumed_position: float = audio._active_music_player.get_playback_position()
	_check(resumed_position > 0.1, "returning to lobby does not restart at zero")
	_check(
		resumed_position >= cached_position - 0.12
			and resumed_position <= cached_position + 0.65,
		"lobby resumes near the position recorded before assembly"
	)

	# Let the newest crossfade finish. A callback from either killed transition
	# must not stop the player that reclaimed its channel.
	await create_timer(audio.MUSIC_FADE_SECONDS + 0.15).timeout
	_check(audio._current_music_path == lobby_path, "rapid return keeps lobby as the current path")
	_check(
		audio._active_music_player != null and audio._active_music_player.playing,
		"stale crossfade callbacks do not stop the resumed music"
	)

	var lobby_stream := load(lobby_path) as AudioStream
	var lobby_length := lobby_stream.get_length()
	if lobby_length > 0.1:
		audio._music_playback_positions[lobby_path] = lobby_length + 0.25
		var wrapped_position: float = audio._resume_position_for(lobby_path, lobby_stream)
		_check(
			wrapped_position >= 0.0 and wrapped_position < lobby_length,
			"saved positions beyond the MP3 duration wrap to a legal offset"
		)

	audio.clear_music_progress(false)
	_check(audio._music_playback_positions.is_empty(), "session progress can be cleared without audio.cfg")

	audio.play_music(lobby_path)
	await create_timer(0.35).timeout
	var pre_silence_position: float = audio._active_music_player.get_playback_position()
	audio._fade_music_to_silence()
	_check(
		float(audio._music_playback_positions.get(lobby_path, 0.0))
			>= pre_silence_position - 0.12,
		"entering a silent scene remembers the music position before fading"
	)
	await create_timer(audio.MUSIC_FADE_SECONDS + 0.15).timeout
	_check(
		audio._current_music_path.is_empty()
			and (audio._active_music_player == null or not audio._active_music_player.playing),
		"silent scene completes its fade without an empty-path load"
	)

	_check(
		not ResourceLoader.exists("res://assets/audio/music/giant_telescope.mp3"),
		"retired telescope BGM is absent from distributable resources"
	)
	_check(
		not ResourceLoader.exists("res://assets/audio/music/space_fast_theme.mp3"),
		"unlicensed remote-observatory BGM is absent from distributable resources"
	)
	_check(
		not ResourceLoader.exists("res://assets/audio/ambient/fast_terminal_hum.ogg"),
		"undocumented FAST ambience is absent from distributable resources"
	)
	audio._stop_music(true)
	print("AUDIO MUSIC RESUME TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  fail: " + label)
