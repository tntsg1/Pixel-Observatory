extends SceneTree

const TEST_TIMEOUT_SECONDS := 45.0
const TARGETS := ['moon', 'jupiter', 'saturn', 'sirius', 'pleiades', 'orion_nebula']
const FAMILY_FIXTURES := [
	{'family': 'refractor', 'level': 3},
	{'family': 'newtonian', 'level': 30},
	{'family': 'dobsonian', 'level': 39},
	{'family': 'cassegrain', 'level': 49},
]
const QUALITY_RANK := {'Failed': 0, 'Poor': 1, 'Fair': 2, 'Good': 3, 'Excellent': 4}

var failures := 0
var finished := false
var had_save := false
var saved_bytes := PackedByteArray()


func _initialize() -> void:
	_start_watchdog()
	_backup_save()
	await process_frame
	var gm: Node = root.get_node_or_null('/root/GameManager')
	if gm == null:
		_finish(1)
		return
	for target_id in TARGETS:
		var baseline_rank := -1
		for fixture_value in FAMILY_FIXTURES:
			var fixture: Dictionary = fixture_value
			gm.new_game()
			var fixture_level := 4 if target_id == 'moon' and str(fixture['family']) == 'refractor' else int(fixture['level'])
			gm.debug_jump_to_level(fixture_level, true)
			gm.set_collimation_score(100.0)
			gm.selected_object_id = str(target_id)
			_check(gm.is_free_observation(), '%s is free observation in %s fixture' % [target_id, fixture['family']])
			var stats: Dictionary = gm.calculate_stats()
			var result: Dictionary = gm.evaluate_selected_object({
				'observation_mode': 'telescope',
				'environment': {'seeing': 'good', 'cloud_cover': 0.0, 'sky_brightness': 'dark'},
				'altitude': 65.0,
				'magnification': float(stats.get('magnification', 0.0)),
				'focus_error': 0.0,
				'focus_tolerance': 0.06,
				'dark_adaptation': 1.0,
				'averted_vision': true,
				'tracking_rate': gm.tracking_rate(),
				'observation_elapsed': 120.0,
				'cloud_attenuation': 0.0,
				'target_off_center': false,
			})
			var quality := str(result.get('quality', 'Failed'))
			var rank := int(QUALITY_RANK.get(quality, 0))
			print('  %s %s aperture=%.0fmm mag=%.1fx quality=%s ratios=%s' % [target_id, fixture['family'], float(stats.get('aperture_mm', 0.0)), float(stats.get('magnification', 0.0)), quality, str(result.get('ratios', {}))])
			_check(str(result.get('technique_failure', {}).get('code', '')) != 'filter', '%s %s does not inherit a mission filter' % [target_id, fixture['family']])
			if baseline_rank < 0:
				baseline_rank = rank
			else:
				_check(rank >= baseline_rank, '%s remains at least as clear with %s as the starter refractor' % [target_id, fixture['family']])
	print('FREE OBSERVATION UPGRADE CONSISTENCY TEST %s' % ('PASS' if failures == 0 else 'FAIL'))
	_finish(0 if failures == 0 else 1)


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not finished:
			push_error('FREE OBSERVATION UPGRADE CONSISTENCY TEST TIMEOUT')
			_finish(1)
	)


func _backup_save() -> void:
	had_save = FileAccess.file_exists('user://savegame.json')
	if had_save:
		saved_bytes = FileAccess.get_file_as_bytes('user://savegame.json')


func _restore_save() -> void:
	if had_save:
		var file := FileAccess.open('user://savegame.json', FileAccess.WRITE)
		if file != null:
			file.store_buffer(saved_bytes)
	elif FileAccess.file_exists('user://savegame.json'):
		DirAccess.remove_absolute(ProjectSettings.globalize_path('user://savegame.json'))


func _finish(exit_code: int) -> void:
	if finished:
		return
	finished = true
	_restore_save()
	quit(exit_code)


func _check(condition: bool, label: String) -> void:
	if condition:
		print('  ok: ' + label)
	else:
		print('  FAIL: ' + label)
		failures += 1
