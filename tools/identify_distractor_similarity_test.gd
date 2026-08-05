extends SceneTree

const OUTPUT_PATH := "res://artifacts/identify_distractors/01_double_cluster_similar_choices.png"
const CASES := [
	"double_cluster",
	"pleiades",
	"m13",
	"sombrero_galaxy",
	"ring_nebula",
	"crab_nebula",
	"betelgeuse",
	"jupiter",
]

var failures := 0
var view: Control


func _initialize() -> void:
	await process_frame
	var gm := root.get_node_or_null("/root/GameManager")
	_check(gm != null, "GameManager is available")
	if gm == null:
		_finish()
		return

	var classifier: Control = load("res://scripts/ui/telescope_view.gd").new() as Control
	for target_id in CASES:
		var ranked: Array = classifier.call("_distractors_for", target_id)
		var top_three: Array = ranked.slice(0, 3)
		_check(top_three.size() == 3, "%s receives three distractors" % target_id)
		_check(not top_three.has(target_id), "%s never repeats the correct answer" % target_id)
		var unique := {}
		var target_family := str(classifier.call("_identify_visual_family", gm.get_object(target_id)))
		var same_family := 0
		for candidate_id_value in top_three:
			var candidate_id := str(candidate_id_value)
			unique[candidate_id] = true
			var candidate: Dictionary = gm.get_object(candidate_id)
			if str(classifier.call("_identify_visual_family", candidate)) == target_family:
				same_family += 1
			_check(not candidate_id.contains("infrared") and not candidate_id.begins_with("pulsar_"), "%s keeps incompatible instruments out of the optical quiz" % target_id)
		_check(unique.size() == 3, "%s distractors are unique" % target_id)
		var required_same_family := 2 if target_family == "cluster" else 3
		_check(same_family >= required_same_family, "%s prioritizes visually related %s targets" % [target_id, target_family])

	var double_ranked: Array = classifier.call("_distractors_for", "double_cluster")
	var double_top: Array = double_ranked.slice(0, 3)
	for expected_id in ["pleiades", "m13", "albireo"]:
		_check(double_top.has(expected_id), "Double Cluster can be confused with %s" % expected_id)

	# Regression for L30: the Crab Nebula must not be surrounded by visually
	# unrelated naked-eye stars and planets, which makes the answer obvious.
	var crab_ranked: Array = classifier.call("_distractors_for", "crab_nebula")
	var crab_top: Array = crab_ranked.slice(0, 3)
	for candidate_id_value in crab_top:
		var candidate_id := str(candidate_id_value)
		_check(
			str(classifier.call("_identify_visual_family", gm.get_object(candidate_id))) == "nebula",
			"Crab Nebula distractor %s is another nebula-like target" % candidate_id
		)
		_check(
			not candidate_id in ["sirius", "jupiter", "betelgeuse"],
			"Crab Nebula no longer uses an obvious star/planet distractor (%s)" % candidate_id
		)
	classifier.free()

	gm.new_game()
	gm.language_mode = "zh"
	gm.debug_jump_to_level(38, true)
	gm.selected_object_id = "double_cluster"
	view = (load("res://scenes/telescope_view.tscn") as PackedScene).instantiate() as Control
	root.add_child(view)
	await process_frame
	await process_frame
	if view.get("quiz_brief_overlay") != null:
		view.call("_dismiss_pre_quiz_guide")
		await create_timer(0.30).timeout
	var choice_ids: Array = view.get("identify_choice_ids")
	_check(choice_ids.size() == 4 and choice_ids.has("double_cluster"), "L38 presents one correct answer among four choices")
	var actual_distractors := choice_ids.duplicate()
	actual_distractors.erase("double_cluster")
	for expected_id in ["pleiades", "m13", "albireo"]:
		_check(actual_distractors.has(expected_id), "L38 UI includes the similar alternative %s" % expected_id)

	if DisplayServer.get_name() != "headless":
		await _capture()
	view.queue_free()
	await process_frame
	_finish()


func _capture() -> void:
	await create_timer(0.25).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/identify_distractors"))
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	_check(error == OK, "saved similar-choice UI evidence")
	if error == OK:
		print("CAPTURE ", ProjectSettings.globalize_path(OUTPUT_PATH))


func _finish() -> void:
	print("IDENTIFY DISTRACTOR SIMILARITY TEST %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		failures += 1
		print("  FAIL: ", label)
