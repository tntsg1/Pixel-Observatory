extends SceneTree

# Run:
# godot --headless --path <project> --script res://tools/telescope_music_removal_test.gd

const RETIRED_BGM := "res://assets/audio/music/giant_telescope.mp3"
var failures := 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var audio := root.get_node_or_null("/root/AudioManager")
	_check(audio != null, "AudioManager autoload exists")
	if audio == null:
		_finish()
		return

	_check(
		audio._music_category_for_scene("res://scenes/telescope_view.tscn")
			== audio.SILENT_MUSIC_CATEGORY,
		"telescope view resolves to the explicit silent route"
	)
	_check(
		audio._music_category_for_scene("res://scenes/sky_observation.tscn") == "outdoor",
		"sky observation still resolves to outdoor music"
	)
	_check(
		audio._music_category_for_scene("res://scenes/space_observation.tscn") == "giant"
			and audio._music_category_for_scene("res://scenes/radio_observation.tscn") == "giant",
		"Space and FAST keep their shared approved theme"
	)
	_check(not ResourceLoader.exists(RETIRED_BGM), "retired BGM source is not importable")
	_check(not FileAccess.file_exists(RETIRED_BGM), "retired BGM file is absent")
	_check(
		audio.RETIRED_MUSIC_UIDS.has("uid://b4x44bsg33mdj"),
		"retired BGM UID is permanently blocked"
	)

	audio.music_enabled = true
	audio._stop_music(true)
	audio.play_music(str(audio.MUSIC_PATHS["outdoor"]))
	await create_timer(0.35).timeout
	var outdoor_position: float = audio._active_music_player.get_playback_position()
	_check(outdoor_position > 0.05, "outdoor music is playing before telescope entry")

	var telescope_scene := load("res://scenes/telescope_view.tscn") as PackedScene
	_check(telescope_scene != null, "telescope view scene loads")
	if telescope_scene != null:
		var telescope_view := telescope_scene.instantiate()
		root.add_child(telescope_view)
		current_scene = telescope_view
		await process_frame
		audio._refresh_music_for_scene()
		await process_frame
		_check(
			audio._current_music_path.is_empty(),
			"real telescope scene entry starts a fade to silence"
		)
		_check(
			float(audio._music_playback_positions.get(str(audio.MUSIC_PATHS["outdoor"]), 0.0))
				>= outdoor_position - 0.12,
			"telescope entry preserves the outdoor theme position for return"
		)
		await create_timer(audio.MUSIC_FADE_SECONDS + 0.15).timeout
		_check(
			audio._active_music_player == null or not audio._active_music_player.playing,
			"telescope scene is silent after the crossfade"
		)
		current_scene = null
		telescope_view.queue_free()
		await process_frame

	# Reproduce an older persistent Autoload player carrying a stream under the
	# retired path. Entering FAST must stop it immediately before the approved
	# remote-observatory theme is requested.
	audio._stop_music(true)
	var stale_player := audio._music_players[0] as AudioStreamPlayer
	stale_player.stream = AudioStreamGenerator.new()
	stale_player.play()
	audio._active_music_player = stale_player
	audio._current_music_path = RETIRED_BGM
	audio._music_player_paths[stale_player.get_instance_id()] = RETIRED_BGM
	audio._music_playback_positions[RETIRED_BGM] = 42.0
	audio._enforce_music_policy(str(audio.MUSIC_PATHS["giant"]))
	_check(not stale_player.playing, "FAST entry immediately stops a retired persistent stream")
	_check(stale_player.stream == null, "retired decoder is detached from the music channel")
	_check(
		not audio._music_playback_positions.has(RETIRED_BGM),
		"retired playback position cannot leak through session resume"
	)

	audio.play_music(str(audio.MUSIC_PATHS["giant"]))
	await create_timer(0.2).timeout
	var fast_state: Dictionary = audio.music_runtime_state()
	print("FAST MUSIC RUNTIME STATE: %s" % JSON.stringify(fast_state))
	_check(
		str(fast_state.get("current_path", "")) == str(audio.MUSIC_PATHS["giant"]),
		"FAST resolves to the approved remote-observatory path"
	)
	_check(
		str(fast_state.get("active_stream_path", "")) == str(audio.MUSIC_PATHS["giant"]),
		"FAST active decoder resource path matches the whitelist"
	)

	audio._stop_music(true)
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
