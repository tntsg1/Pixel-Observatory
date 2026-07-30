extends SceneTree

# Ensures a persisted FAST science product remains reviewable, rather than
# degrading into a generic journal completion after the observation scene ends.

var failures := 0


func _initialize() -> void:
	await process_frame
	root.size = Vector2i(1024, 768)
	var journal := load("res://scripts/ui/learning_journal.gd").new() as Control
	root.add_child(journal)
	await process_frame
	var product := {
		"corrected_spectrum": [[0.08, 0.14, 0.78, 0.12], [0.10, 0.20, 0.82, 0.10], [0.09, 0.16, 0.76, 0.11]],
		"folded_two_cycles": [0.05, 0.12, 0.92, 0.30, 0.08, 0.06, 0.12, 0.82, 0.28, 0.05],
		"confidence": 0.94,
		"pulse_width_ms": 28.6,
		"report": {
			"trial_period_ms": 714.5,
			"trial_dm": 26.8,
			"candidate_model": "PSR B0329",
			"sky_position": {"label": "AZ 92.0 / ALT 58.0"},
		}
	}
	var observation := {
		"radio_data_product": product,
		"pulse_period_ms": 714.5,
		"dispersion_measure": 26.8,
		"pulse_width_ms": 28.6,
		"snr": 44.3,
		"confidence": 0.94,
		"candidate_model": "PSR B0329",
		"sky_position": {"label": "AZ 92.0 / ALT 58.0"},
		"observed_at_unix": 1780000000.0,
	}
	var entry := {
		"object_name_en": "Pulsar B0329+54",
		"object_name_zh": "脉冲星 B0329+54",
		"radio_observation": observation,
		"observation_mode": "radio",
	}
	var card := journal.call("_build_radio_archive_card", 1, entry, observation) as Control
	root.add_child(card)
	await process_frame
	_check(card.find_child("RadioArchiveThumbnail", true, false) != null, "journal card reconstructs dynamic-spectrum and folded-profile thumbnail from saved packet")
	_check(_contains_label(card, "714.500") and _contains_label(card, "PSR B0329"), "journal card exposes the same measured period and candidate model")
	_check(_contains_label(card, "AZ 92.0"), "journal card exposes the saved sky position")
	card.queue_free()
	journal.queue_free()
	await process_frame
	print("FAST RADIO ARCHIVE JOURNAL TEST %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _contains_label(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text.contains(needle):
		return true
	for child in node.get_children():
		if _contains_label(child, needle):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
