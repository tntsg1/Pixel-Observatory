extends SceneTree

const TEST_TIMEOUT_SECONDS := 30.0

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
	gm.new_game()
	var mission_manager: Node = root.get_node_or_null('/root/MissionManager')
	gm.progress['current_level'] = 85
	gm.progress['completed_levels'] = (mission_manager.get('campaign_order') as Array).duplicate() if mission_manager != null else [85]
	gm.progress['program_completed'] = true
	gm.progress['graduation_seen'] = true
	gm.progress['graduation_pending'] = false
	var all_parts: Array = []
	for part_value in gm.parts_data:
		if part_value is Dictionary:
			all_parts.append(str((part_value as Dictionary).get('id', '')))
	gm._normalize_progress()
	gm.progress['current_level'] = 85
	gm.progress['unlocked_parts'] = all_parts

	_check(gm.postgraduate_free_build(), 'completed graduate save enters postgraduate free build')
	_check(not gm.has_locked_required_equipment(), 'finished L85 recipe no longer pins free-build equipment')
	_check(gm.pinned_part_id('receiver') == '', 'finished mission cannot pin a receiver in free build')

	gm.select_assembly_family('newtonian')
	_check(gm.assembly_context_family() == 'newtonian', 'selected Newtonian family owns assembly context')
	_check(gm.equip_part('newtonian_reflector_tube'), 'graduate can equip unlocked Newtonian parts')
	gm.progress['assembly_state']['mount'] = {'installed': true, 'alignment_score': 91, 'wrong_attempts': 0}

	gm.select_assembly_family('dobsonian')
	_check(gm.assembly_context_family() == 'dobsonian', 'family switch changes assembly context without changing L85')
	_check(not bool(gm.progress['assembly_state'].get('mount', {}).get('installed', false)), 'new family starts with its own assembly state')
	_check(gm.equip_part('dobsonian_reflector_tube'), 'graduate can equip unlocked Dobsonian parts')
	gm.progress['assembly_state']['mount'] = {'installed': true, 'alignment_score': 73, 'wrong_attempts': 1}

	gm.select_assembly_family('newtonian')
	_check(gm.equipped_part_id('reflector_tube') == 'newtonian_reflector_tube', 'Newtonian equipment is restored after family round trip')
	_check(int(gm.progress['assembly_state'].get('mount', {}).get('alignment_score', 0)) == 91, 'Newtonian installation state is restored independently')
	gm.select_assembly_family('dobsonian')
	_check(gm.equipped_part_id('reflector_tube') == 'dobsonian_reflector_tube', 'Dobsonian equipment remains independent')
	_check(int(gm.progress['assembly_state'].get('mount', {}).get('alignment_score', 0)) == 73, 'Dobsonian installation state remains independent')

	var selector: Node = load('res://scenes/telescope_types.tscn').instantiate()
	root.add_child(selector)
	await process_frame
	_check(bool(selector.get('postgraduate_free_build')), 'telescope family screen exposes explicit postgraduate mode')
	selector.call('_select', 'newtonian')
	var proceed := selector.get('proceed_button') as Button
	_check(proceed != null and not proceed.disabled, 'unlocked graduate family can open its bench')
	_check(proceed != null and ('free' in proceed.text.to_lower() or '自由组装' in proceed.text), 'family screen labels the bench as free build')
	_check(_collect_text(selector).contains('keep a separate build for each') or _collect_text(selector).contains('分别保存每套装配'), 'family screen explains per-family saved builds')
	selector.queue_free()
	await process_frame

	gm.progress.erase('family_assembly_states')
	gm.progress.erase('family_selected_parts')
	gm._normalize_progress()
	_check(gm.progress.get('family_assembly_states') is Dictionary, 'old graduate save migrates family assembly states')
	_check(gm.progress.get('family_selected_parts') is Dictionary, 'old graduate save migrates family equipment states')

	print('POSTGRADUATE FREE BUILD TEST %s' % ('PASS' if failures == 0 else 'FAIL'))
	_finish(0 if failures == 0 else 1)


func _collect_text(node: Node) -> String:
	if node == null:
		return ''
	var result := ''
	if node is Label:
		result += (node as Label).text + '\n'
	elif node is Button:
		result += (node as Button).text + '\n'
	for child in node.get_children():
		result += _collect_text(child)
	return result


func _start_watchdog() -> void:
	var timer := create_timer(TEST_TIMEOUT_SECONDS)
	timer.timeout.connect(func() -> void:
		if not finished:
			push_error('POSTGRADUATE FREE BUILD TEST TIMEOUT')
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
