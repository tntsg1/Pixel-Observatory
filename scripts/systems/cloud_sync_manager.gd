extends Node

signal sync_status_changed(status: String, detail: String)
signal session_changed(user: Dictionary)
signal progress_availability_resolved

const SESSION_PATH := "/api/auth/session"
const SAVE_PATH := "/api/cloud-save"
const UPLOAD_DEBOUNCE_SECONDS := 1.25
const MERGED_ARRAY_KEYS := [
	"owned_optical_telescope_families",
	"completed_levels",
	"unlocked_parts",
	"observed_objects",
	"badges",
	"journal_entries",
	"remote_observation_archive",
	"remote_free_intro_seen",
	"completed_concept_cards",
	"seen_teaching_steps",
	"seen_concept_briefs",
	"seen_story_events",
	"pending_unlock_notice",
	"unlocked_equipment_stages",
]
const MAXIMUM_NUMBER_KEYS := [
	"campaign_version",
	"save_revision",
	"save_updated_at",
	"cloud_synced_revision",
	"current_level",
	"credits",
	"optical_ownership_transfer_version",
]
const MONOTONIC_BOOL_KEYS := [
	"save_initialized",
	"program_completed",
	"graduation_pending",
	"graduation_seen",
	"tutorial_free_confirmation_seen",
]

var _api_origin := ""
var _request: HTTPRequest
var _session_user: Dictionary = {}
var _cloud_version := 0
var _pending_progress: Dictionary = {}
var _upload_clock := -1.0
var _busy := false
var _operation := ""
var _progress_availability_is_resolved := false
var _local_progress_belongs_to_session := false
var _guest_progress_candidate: Dictionary = {}
var _cloud_progress_candidate: Dictionary = {}
var _merge_pending := false
var _session_refresh_requested := false
var _browser_session_callback
var _browser_merge_callback
var _browser_use_cloud_callback
var _browser_http_callback


func _ready() -> void:
	sync_status_changed.connect(_publish_web_sync_status)
	if _study_mode_requested():
		_progress_availability_is_resolved = true
		set_process(false)
		return
	if not OS.has_feature("web"):
		_progress_availability_is_resolved = true
		set_process(false)
		return
	_api_origin = _browser_origin()
	if _api_origin.is_empty():
		set_process(false)
		return
	_request = HTTPRequest.new()
	_request.timeout = 12.0
	_request.request_completed.connect(_on_request_completed)
	add_child(_request)
	_install_browser_bridge()
	call_deferred("_check_session")


func _study_mode_requested() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--study" or argument.begins_with("--study="):
			return true
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		return bool(JavaScriptBridge.eval("new URL(location.href).searchParams.get('mode') === 'study'", true))
	return false


func _install_browser_bridge() -> void:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	var window = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_browser_session_callback = JavaScriptBridge.create_callback(_on_browser_session_changed)
	_browser_merge_callback = JavaScriptBridge.create_callback(_on_browser_merge_guest_save)
	_browser_use_cloud_callback = JavaScriptBridge.create_callback(_on_browser_use_cloud_save)
	_browser_http_callback = JavaScriptBridge.create_callback(_on_browser_http_response)
	window.pixelObservatorySessionChanged = _browser_session_callback
	window.pixelObservatoryMergeGuestSave = _browser_merge_callback
	window.pixelObservatoryUseCloudSave = _browser_use_cloud_callback
	window.pixelObservatoryCloudResponse = _browser_http_callback


func _on_browser_session_changed(_arguments: Array) -> void:
	_session_refresh_requested = true
	if not _busy:
		_restart_session_check()


func _on_browser_merge_guest_save(_arguments: Array) -> void:
	merge_guest_progress()


func _on_browser_use_cloud_save(_arguments: Array) -> void:
	keep_cloud_progress()


func _on_browser_http_response(arguments: Array) -> void:
	if arguments.size() < 3:
		return
	var operation := str(arguments[0])
	var response_code := int(arguments[1])
	var body := str(arguments[2]).to_utf8_buffer()
	_complete_request(operation, response_code, body)


func _restart_session_check() -> void:
	_session_refresh_requested = false
	_upload_clock = -1.0
	_pending_progress.clear()
	_session_user.clear()
	_cloud_version = 0
	_guest_progress_candidate.clear()
	_cloud_progress_candidate.clear()
	_merge_pending = false
	_local_progress_belongs_to_session = false
	call_deferred("_check_session")


func notify_local_saved(progress: Dictionary) -> void:
	if _merge_pending:
		_guest_progress_candidate = progress.duplicate(true)
		_emit_status("merge_required", "Local progress is waiting to be merged.")
	elif _session_user.is_empty():
		_emit_status("local_saved", "Saved locally just now.")
	else:
		_emit_status("syncing", "Syncing progress.")


func _publish_web_sync_status(status: String, detail: String) -> void:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return
	var payload := {
		"status": status,
		"detail": detail,
		"mergeRequired": _merge_pending,
		"guestLevel": int(_guest_progress_candidate.get("current_level", 1)),
		"cloudLevel": int(_cloud_progress_candidate.get("current_level", 1)),
		"hasCloudSave": not _cloud_progress_candidate.is_empty(),
	}
	var encoded := JSON.stringify(payload)
	JavaScriptBridge.eval(
		"window.__pixelObservatoryCloudSave=" + encoded
		+ ";window.dispatchEvent(new CustomEvent('observatory:cloud-save-status',{detail:" + encoded + "}));"
		+ "window.dispatchEvent(new CustomEvent('observatory:cloud-sync',{detail:" + encoded + "}));",
		true
	)


func _emit_status(status: String, detail: String) -> void:
	sync_status_changed.emit(status, detail)


func is_progress_availability_resolved() -> bool:
	return not OS.has_feature("web") or _progress_availability_is_resolved


func merge_required() -> bool:
	return _merge_pending


func _process(delta: float) -> void:
	if _upload_clock < 0.0:
		return
	_upload_clock -= delta
	if _upload_clock <= 0.0:
		_upload_clock = -1.0
		_flush_upload()


func queue_upload(progress: Dictionary) -> void:
	if GameManager.has_method("developer_sandbox_active") and GameManager.developer_sandbox_active():
		return
	if not OS.has_feature("web") or _session_user.is_empty():
		return
	if _merge_pending:
		_guest_progress_candidate = progress.duplicate(true)
		_emit_status("merge_required", "Local progress is waiting to be merged.")
		return
	var owned_progress := progress.duplicate(true)
	owned_progress["cloud_owner_id"] = str(_session_user.get("id", ""))
	_pending_progress = owned_progress
	if str(GameManager.progress.get("cloud_owner_id", "")) != str(_session_user.get("id", "")):
		GameManager.progress["cloud_owner_id"] = str(_session_user.get("id", ""))
		SaveManager.save_progress(GameManager.progress, false, false)
	_upload_clock = UPLOAD_DEBOUNCE_SECONDS
	_emit_status("syncing", "Syncing progress.")


func signed_in() -> bool:
	return not _session_user.is_empty()


func username() -> String:
	return str(_session_user.get("username", ""))


func session_role() -> String:
	return str(_session_user.get("role", "")).to_lower()


func is_admin() -> bool:
	return signed_in() and session_role() == "admin"


func set_test_session_role_for_tests(role: String) -> void:
	if OS.has_feature("web"):
		return
	_session_user = {"id": "test-user", "username": "test-user", "role": role.to_lower()}
	session_changed.emit(_session_user.duplicate(true))


func _browser_origin() -> String:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var value = JavaScriptBridge.eval("window.location.origin", true)
	var origin := str(value)
	if not origin.begins_with("http"):
		return ""
	return origin


func _check_session() -> void:
	_set_progress_availability_resolved(false)
	_start_request("session", SESSION_PATH, HTTPClient.METHOD_GET)


func _download_cloud_save() -> void:
	_start_request("download", SAVE_PATH, HTTPClient.METHOD_GET)


func _flush_upload() -> void:
	if _busy or _pending_progress.is_empty() or _session_user.is_empty() or _merge_pending:
		if _busy and not _pending_progress.is_empty():
			_upload_clock = 0.35
		return
	var payload := {
		"progress": _pending_progress,
		"baseVersion": _cloud_version,
		"schemaVersion": int(_pending_progress.get("campaign_version", 1)),
		"clientUpdatedAt": int(_pending_progress.get("save_updated_at", Time.get_unix_time_from_system())),
	}
	_start_request("upload", SAVE_PATH, HTTPClient.METHOD_PUT, JSON.stringify(payload))


func _start_request(operation: String, path: String, method: HTTPClient.Method, body: String = "") -> void:
	if _busy:
		return
	_busy = true
	_operation = operation
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var request_payload := {
			"operation": operation,
			"path": path,
			"method": "PUT" if method == HTTPClient.METHOD_PUT else "GET",
			"body": body,
		}
		var started = JavaScriptBridge.eval(
			"typeof window.pixelObservatoryCloudRequest==='function'"
			+ "&&(window.pixelObservatoryCloudRequest(" + JSON.stringify(request_payload) + "),true)",
			true
		)
		if bool(started):
			return
		_busy = false
		_operation = ""
		_emit_status("offline", "Offline save. Local progress is safe.")
		if operation in ["session", "download"]:
			_set_progress_availability_resolved(true)
		return
	if _request == null:
		_busy = false
		_operation = ""
		return
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var error := _request.request(_api_origin + path, headers, method, body)
	if error != OK:
		_busy = false
		_operation = ""
		_emit_status("offline", "Offline save. Local progress is safe.")
		if operation in ["session", "download"]:
			_set_progress_availability_resolved(true)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_complete_request(_operation, response_code, body)


func _complete_request(operation: String, response_code: int, body: PackedByteArray) -> void:
	if operation != _operation:
		return
	_operation = ""
	_busy = false
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	if response_code < 200 or response_code >= 300:
		if response_code == 409 and operation == "upload":
			_pending_progress.clear()
			_emit_status("syncing", "Checking the newer cloud archive.")
			_download_cloud_save()
		else:
			_emit_status("offline", "Offline save. Local progress is safe.")
			if operation in ["session", "download"]:
				_set_progress_availability_resolved(true)
		_finish_session_refresh_if_requested()
		return
	match operation:
		"session":
			var user_value = payload.get("user")
			if typeof(user_value) == TYPE_DICTIONARY:
				_session_user = (user_value as Dictionary).duplicate(true)
				_prepare_local_progress_for_session()
				session_changed.emit(_session_user.duplicate(true))
				_download_cloud_save()
			else:
				_session_user.clear()
				_local_progress_belongs_to_session = false
				_discard_cloud_owned_local_progress()
				_emit_status("local_saved", "Saved locally just now.")
				session_changed.emit({})
				_set_progress_availability_resolved(true)
		"download":
			_apply_cloud_payload(payload)
		"upload":
			_cloud_version = int(payload.get("version", _cloud_version + 1))
			_pending_progress.clear()
			GameManager.progress["cloud_synced_revision"] = int(GameManager.progress.get("save_revision", 0))
			SaveManager.save_progress(GameManager.progress, false, false)
			_emit_status("saved", "Saved just now.")
	_finish_session_refresh_if_requested()


func _finish_session_refresh_if_requested() -> void:
	if _session_refresh_requested and not _busy:
		_restart_session_check()


func _apply_cloud_payload(payload: Dictionary) -> void:
	var save_value = payload.get("save")
	_cloud_progress_candidate.clear()
	if typeof(save_value) == TYPE_DICTIONARY:
		var cloud_save: Dictionary = save_value
		_cloud_version = int(cloud_save.get("version", 0))
		var cloud_progress_value = cloud_save.get("progress")
		if typeof(cloud_progress_value) == TYPE_DICTIONARY:
			_cloud_progress_candidate = (cloud_progress_value as Dictionary).duplicate(true)
			_cloud_progress_candidate["cloud_owner_id"] = str(_session_user.get("id", ""))
	else:
		_cloud_version = 0

	if not _guest_progress_candidate.is_empty():
		_merge_pending = true
		_emit_status("merge_required", "Merge this browser's progress into your cloud archive.")
		_set_progress_availability_resolved(true)
		return

	if _cloud_progress_candidate.is_empty():
		if _local_progress_belongs_to_session and SaveManager.has_resumable_save():
			queue_upload(GameManager.progress)
		else:
			_emit_status("saved", "Cloud archive connected.")
		_set_progress_availability_resolved(true)
		return

	var local_progress: Dictionary = GameManager.progress
	if not _local_progress_belongs_to_session:
		_apply_progress(_cloud_progress_candidate, false)
		_emit_status("saved", "Cloud progress restored.")
	elif _compare_progress(local_progress, _cloud_progress_candidate) > 0:
		var merged_local := _merge_progress(local_progress, _cloud_progress_candidate)
		_apply_progress(merged_local, true)
		queue_upload(GameManager.progress)
	else:
		var merged_cloud := _merge_progress(local_progress, _cloud_progress_candidate)
		_apply_progress(merged_cloud, false)
		if _progress_signature(merged_cloud) != _progress_signature(_cloud_progress_candidate):
			queue_upload(GameManager.progress)
		else:
			_emit_status("saved", "Cloud progress restored.")
	_set_progress_availability_resolved(true)


func merge_guest_progress() -> void:
	if not _merge_pending or _guest_progress_candidate.is_empty() or _session_user.is_empty():
		return
	var merged := _merge_progress(_guest_progress_candidate, _cloud_progress_candidate)
	merged["cloud_owner_id"] = str(_session_user.get("id", ""))
	_merge_pending = false
	_guest_progress_candidate.clear()
	_apply_progress(merged, true)
	_emit_status("syncing", "Syncing merged progress.")
	queue_upload(GameManager.progress)


func keep_cloud_progress() -> void:
	if not _merge_pending or _session_user.is_empty():
		return
	_merge_pending = false
	_guest_progress_candidate.clear()
	if _cloud_progress_candidate.is_empty():
		var selected_language := GameManager.language_mode
		var blank := GameManager.default_progress()
		blank["language_mode"] = selected_language
		blank["cloud_owner_id"] = str(_session_user.get("id", ""))
		_apply_progress(blank, false)
	else:
		_apply_progress(_cloud_progress_candidate, false)
	_emit_status("saved", "Cloud archive kept on this browser.")
	_set_progress_availability_resolved(true)


func _prepare_local_progress_for_session() -> void:
	var session_id := str(_session_user.get("id", ""))
	var local_owner := str(GameManager.progress.get("cloud_owner_id", ""))
	_local_progress_belongs_to_session = session_id != "" and local_owner == session_id
	_guest_progress_candidate.clear()
	_merge_pending = false
	if _local_progress_belongs_to_session:
		return
	if local_owner.is_empty() and SaveManager.is_resumable_progress(GameManager.progress):
		_guest_progress_candidate = GameManager.progress.duplicate(true)
		return
	# Browser storage can contain another account's local archive. Keep it out of
	# this session and never offer it as a merge candidate.
	var selected_language := GameManager.language_mode
	GameManager.progress = GameManager.default_progress()
	GameManager.progress["language_mode"] = selected_language
	GameManager.language_mode = selected_language


func _discard_cloud_owned_local_progress() -> void:
	if str(GameManager.progress.get("cloud_owner_id", "")).is_empty():
		return
	var selected_language := GameManager.language_mode
	GameManager.progress = GameManager.default_progress()
	GameManager.progress["language_mode"] = selected_language
	GameManager.language_mode = selected_language
	SaveManager.save_progress(GameManager.progress, false, false)
	GameManager.progress_changed.emit()


func _apply_progress(candidate: Dictionary, touch_metadata: bool) -> void:
	# Do not let a delayed cloud response replace the selected developer lesson
	# halfway through equipment preparation. The persisted archive remains the
	# source used when the player explicitly resumes the campaign.
	if GameManager.has_method("developer_sandbox_active") and GameManager.developer_sandbox_active():
		return
	var merged: Dictionary = SaveManager._merge_defaults(GameManager.default_progress(), candidate)
	merged["cloud_owner_id"] = str(_session_user.get("id", ""))
	GameManager.progress = merged
	GameManager.call("_normalize_progress")
	SaveManager.save_progress(GameManager.progress, false, touch_metadata)
	GameManager.progress_changed.emit()
	_local_progress_belongs_to_session = true


func _merge_progress(local_progress: Dictionary, cloud_progress: Dictionary) -> Dictionary:
	if cloud_progress.is_empty():
		return local_progress.duplicate(true)
	if local_progress.is_empty():
		return cloud_progress.duplicate(true)
	var local_is_primary := _compare_progress(local_progress, cloud_progress) >= 0
	var primary: Dictionary = local_progress if local_is_primary else cloud_progress
	var secondary: Dictionary = cloud_progress if local_is_primary else local_progress
	var merged: Dictionary = _merge_missing(primary, secondary)
	merged = SaveManager._merge_defaults(GameManager.default_progress(), merged)
	for key in MERGED_ARRAY_KEYS:
		merged[key] = _union_arrays(local_progress.get(key, []), cloud_progress.get(key, []))
	for key in MAXIMUM_NUMBER_KEYS:
		merged[key] = maxi(int(local_progress.get(key, 0)), int(cloud_progress.get(key, 0)))
	for key in MONOTONIC_BOOL_KEYS:
		merged[key] = bool(local_progress.get(key, false)) or bool(cloud_progress.get(key, false))
	return merged


func _merge_missing(primary: Dictionary, secondary: Dictionary) -> Dictionary:
	var result := secondary.duplicate(true)
	for key in primary.keys():
		if typeof(primary[key]) == TYPE_DICTIONARY and typeof(result.get(key)) == TYPE_DICTIONARY:
			result[key] = _merge_missing(primary[key], result[key])
		else:
			result[key] = primary[key]
	return result


func _union_arrays(local_value: Variant, cloud_value: Variant) -> Array:
	var result: Array = []
	var seen := {}
	for source in [local_value, cloud_value]:
		if typeof(source) != TYPE_ARRAY:
			continue
		for value in source:
			var key := JSON.stringify(value)
			if seen.has(key):
				continue
			seen[key] = true
			result.append(value)
	return result


func _compare_progress(left: Dictionary, right: Dictionary) -> int:
	var left_revision := int(left.get("save_revision", 0))
	var right_revision := int(right.get("save_revision", 0))
	if left_revision != right_revision:
		return 1 if left_revision > right_revision else -1
	var left_updated := int(left.get("save_updated_at", 0))
	var right_updated := int(right.get("save_updated_at", 0))
	if left_updated != right_updated:
		return 1 if left_updated > right_updated else -1
	var left_score := _progress_score(left)
	var right_score := _progress_score(right)
	if left_score != right_score:
		return 1 if left_score > right_score else -1
	return 0


func _progress_signature(progress: Dictionary) -> String:
	var copy := progress.duplicate(true)
	copy.erase("cloud_owner_id")
	copy.erase("cloud_synced_revision")
	return JSON.stringify(copy)


func _set_progress_availability_resolved(resolved: bool) -> void:
	if _progress_availability_is_resolved == resolved:
		return
	_progress_availability_is_resolved = resolved
	progress_availability_resolved.emit()


func _progress_score(progress: Dictionary) -> int:
	var score := int(progress.get("current_level", 1)) * 100000
	for key in ["completed_levels", "observed_objects", "journal_entries", "unlocked_parts"]:
		var values = progress.get(key, [])
		if typeof(values) == TYPE_ARRAY:
			score += (values as Array).size() * (1000 if key == "completed_levels" else 100)
	score += int(progress.get("credits", 0))
	if bool(progress.get("program_completed", false)):
		score += 10000000
	return score
