extends SceneTree

# Run:
# godot --headless --path <project> --script res://tools/telescope_music_removal_test.gd

const RETIRED_BGM := "res://assets/audio/music/giant_telescope.mp3"
const RETIRED_REMOTE_BGM := "res://assets/audio/music/space_fast_theme.mp3"
const RETIRED_FAST_AMBIENCE := "res://assets/audio/ambient/fast_terminal_hum.ogg"
var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	_check(audio != null, "AudioManager autoload exists")
	if audio == null:
		_finish()
		return

	var expected_routes := {
		"res://scenes/telescope_view.tscn": "outdoor",
		"res://scenes/space_observation.tscn": "remote",
		"res://scenes/radio_observation.tscn": "remote",
		"res://scenes/multi_observation.tscn": "remote",
	}
	for scene_path in expected_routes:
		_check(
			audio._music_category_for_scene(scene_path) == expected_routes[scene_path],
			"%s resolves to its approved full-score route" % scene_path.get_file()
		)
	_check(
		audio._music_category_for_scene("res://scenes/sky_observation.tscn") == "outdoor",
		"sky observation still resolves to outdoor music"
	)
	_check(
		audio.MUSIC_PATHS.has("remote")
			and ResourceLoader.exists(str(audio.MUSIC_PATHS["remote"])),
		"remote scenes have an approved distributable score"
	)
	for path in [RETIRED_BGM, RETIRED_REMOTE_BGM, RETIRED_FAST_AMBIENCE]:
		_check(not ResourceLoader.exists(path), "retired audio is not importable: " + path)
		_check(not FileAccess.file_exists(path), "retired audio file is absent: " + path)
	_check(
		audio.RETIRED_MUSIC_UIDS.has("uid://b4x44bsg33mdj")
			and audio.RETIRED_MUSIC_UIDS.has("uid://b1qu5girwevff"),
		"both retired music UIDs are permanently blocked"
	)
	_check(
		audio.RETIRED_AMBIENCE_UIDS.has("uid://c7hv8ifvlw2uf"),
		"retired FAST ambience UID is permanently blocked"
	)

	audio.music_enabled = true
	audio._stop_music(true)
	audio.play_music(str(audio.MUSIC_PATHS["remote"]))
	await create_timer(0.35).timeout
	var remote_position: float = audio._active_music_player.get_playback_position()
	_check(remote_position > 0.05, "remote-observatory music is playing before FAST entry")

	var radio_scene := load("res://scenes/radio_observation.tscn") as PackedScene
	_check(radio_scene != null, "FAST scene loads")
	if radio_scene != null:
		var radio_view := radio_scene.instantiate()
		root.add_child(radio_view)
		current_scene = radio_view
		await process_frame
		audio._refresh_music_for_scene()
		audio._refresh_ambience_for_scene()
		await process_frame
		_check(
			audio._current_music_path == str(audio.MUSIC_PATHS["remote"]),
			"FAST entry keeps the approved remote-observatory score"
		)
		_check(
			audio._active_music_player != null
				and audio._active_music_player.playing
				and audio._active_music_player.get_playback_position() >= remote_position - 0.12,
			"FAST entry continues the remote score instead of restarting it"
		)
		_check(
			audio._ambient_player == null
				or (not audio._ambient_player.playing and audio._ambient_player.stream == null),
			"FAST entry has no undocumented ambience decoder"
		)
		await create_timer(audio.MUSIC_FADE_SECONDS + 0.15).timeout
		var state: Dictionary = audio.music_runtime_state()
		print("FAST MUSIC RUNTIME STATE: %s" % JSON.stringify(state))
		_check(
			str(state.get("current_path", "")) == str(audio.MUSIC_PATHS["remote"])
				and str(state.get("active_stream_path", "")) == str(audio.MUSIC_PATHS["remote"]),
			"FAST runtime keeps the approved full BGM stream"
		)
		for channel in state.get("channels", []):
			var channel_path := str(channel.get("stream_path", ""))
			_check(
				channel_path.is_empty() or channel_path == str(audio.MUSIC_PATHS["remote"]),
				"FAST music channels contain no retired stream"
			)
		current_scene = null
		radio_view.queue_free()
		await process_frame
		await process_frame

	# Reproduce an older Autoload carrying the newly retired remote theme.
	audio._stop_music(true)
	var stale_player := audio._music_players[0] as AudioStreamPlayer
	stale_player.stream = AudioStreamGenerator.new()
	stale_player.play()
	audio._active_music_player = stale_player
	audio._current_music_path = RETIRED_REMOTE_BGM
	audio._music_player_paths[stale_player.get_instance_id()] = RETIRED_REMOTE_BGM
	audio._music_playback_positions[RETIRED_REMOTE_BGM] = 42.0
	audio._enforce_music_policy("")
	_check(not stale_player.playing, "FAST entry immediately stops a retired persistent stream")
	_check(stale_player.stream == null, "retired decoder is detached from the music channel")
	_check(
		not audio._music_playback_positions.has(RETIRED_REMOTE_BGM),
		"retired playback position cannot leak through session resume"
	)

	audio._stop_music(true)
	audio.stop_all_event_loops(0.0)
	await process_frame
	_finish()


func _finish() -> void:
	print(
		"TELESCOPE MUSIC REMOVAL TEST %s"
		% ("PASS" if failures == 0 else "FAIL (%d)" % failures)
	)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		push_error("  fail: " + label)
