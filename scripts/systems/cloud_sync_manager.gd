extends Node

signal sync_status_changed(status: String, detail: String)
signal session_changed(user: Dictionary)
signal progress_availability_resolved

const SESSION_PATH := "/api/auth/session"
const SAVE_PATH := "/api/cloud-save"
const UPLOAD_DEBOUNCE_SECONDS := 1.25

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


func _ready() -> void:
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
	call_deferred("_check_session")


func is_progress_availability_resolved() -> bool:
	# Native/editor saves are immediately local. A web menu must wait until the
	# authenticated account's cloud archive has been accepted or rejected.
	return not OS.has_feature("web") or _progress_availability_is_resolved


func _process(delta: float) -> void:
	if _upload_clock < 0.0:
		return
	_upload_clock -= delta
	if _upload_clock <= 0.0:
		_upload_clock = -1.0
		_flush_upload()


func queue_upload(progress: Dictionary) -> void:
	if not OS.has_feature("web") or _session_user.is_empty():
		return
	var owned_progress := progress.duplicate(true)
	owned_progress["cloud_owner_id"] = str(_session_user.get("id", ""))
	_pending_progress = owned_progress
	if str(GameManager.progress.get("cloud_owner_id", "")) != str(_session_user.get("id", "")):
		GameManager.progress["cloud_owner_id"] = str(_session_user.get("id", ""))
		# This local write is ownership metadata only; do not enqueue a second
		# upload while the original write is already being debounced.
		SaveManager.save_progress(GameManager.progress, false)
	_upload_clock = UPLOAD_DEBOUNCE_SECONDS
	sync_status_changed.emit("queued", tr("Cloud save queued"))


func signed_in() -> bool:
	return not _session_user.is_empty()


func username() -> String:
	return str(_session_user.get("username", ""))


func session_role() -> String:
	# The worker supplies this from the authenticated database session. Never
	# derive elevated access from a local save, username, or browser storage.
	return str(_session_user.get("role", "")).to_lower()


func is_admin() -> bool:
	return signed_in() and session_role() == "admin"


func set_test_session_role_for_tests(role: String) -> void:
	# Headless/editor tests may explicitly inject a role. Web builds must always
	# wait for the server-backed /api/auth/session response above.
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
	if _busy or _pending_progress.is_empty() or _session_user.is_empty():
		if _busy and not _pending_progress.is_empty():
			_upload_clock = 0.35
		return
	var payload := {
		"progress": _pending_progress,
		"baseVersion": _cloud_version,
		"schemaVersion": int(_pending_progress.get("campaign_version", 1)),
		"clientUpdatedAt": int(Time.get_unix_time_from_system()),
	}
	_start_request("upload", SAVE_PATH, HTTPClient.METHOD_PUT, JSON.stringify(payload))


func _start_request(operation: String, path: String, method: HTTPClient.Method, body: String = "") -> void:
	if _busy or _request == null:
		return
	_busy = true
	_operation = operation
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var error := _request.request(_api_origin + path, headers, method, body)
	if error != OK:
		_busy = false
		_operation = ""
		sync_status_changed.emit("offline", tr("Cloud archive is unavailable; local progress is safe."))
		if operation in ["session", "download"]:
			_set_progress_availability_resolved(true)


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var operation := _operation
	_operation = ""
	_busy = false
	var payload = JSON.parse_string(body.get_string_from_utf8())
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	if response_code < 200 or response_code >= 300:
		if response_code == 409 and operation == "upload":
			_download_cloud_save()
			return
		sync_status_changed.emit("offline", tr("Cloud archive is unavailable; local progress is safe."))
		if operation in ["session", "download"]:
			_set_progress_availability_resolved(true)
		return
	match operation:
		"session":
			var user_value = payload.get("user")
			if typeof(user_value) == TYPE_DICTIONARY:
				_session_user = (user_value as Dictionary).duplicate(true)
				_prepare_local_progress_for_session()
				sync_status_changed.emit("signed_in", tr("Cloud archive connected: %s") % username())
				session_changed.emit(_session_user.duplicate(true))
				_download_cloud_save()
			else:
				_session_user.clear()
				_local_progress_belongs_to_session = false
				_discard_cloud_owned_local_progress()
				sync_status_changed.emit("signed_out", tr("Sign in on the website to enable cloud saves."))
				session_changed.emit({})
				_set_progress_availability_resolved(true)
		"download":
			_apply_cloud_payload(payload)
		"upload":
			_cloud_version = int(payload.get("version", _cloud_version + 1))
			_pending_progress.clear()
			sync_status_changed.emit("synced", tr("Cloud archive up to date."))


func _apply_cloud_payload(payload: Dictionary) -> void:
	var save_value = payload.get("save")
	if typeof(save_value) != TYPE_DICTIONARY:
		_cloud_version = 0
		# Do not turn a blank bootstrap archive into a cloud save. A new game
		# will queue its first upload explicitly, after its owner is known.
		if _local_progress_belongs_to_session and SaveManager.has_resumable_save():
			queue_upload(GameManager.progress)
		_set_progress_availability_resolved(true)
		return
	var cloud_save: Dictionary = save_value
	var cloud_progress_value = cloud_save.get("progress")
	if typeof(cloud_progress_value) != TYPE_DICTIONARY:
		return
	_cloud_version = int(cloud_save.get("version", 0))
	var cloud_progress: Dictionary = cloud_progress_value
	cloud_progress["cloud_owner_id"] = str(_session_user.get("id", ""))
	var local_progress: Dictionary = GameManager.progress
	var cloud_score := _progress_score(cloud_progress)
	var local_score := _progress_score(local_progress)
	if not _local_progress_belongs_to_session or cloud_score >= local_score:
		var merged: Dictionary = SaveManager._merge_defaults(GameManager.default_progress(), cloud_progress)
		GameManager.progress = merged
		GameManager.call("_normalize_progress")
		SaveManager.save_progress(GameManager.progress, false)
		GameManager.progress_changed.emit()
		sync_status_changed.emit("downloaded", tr("Cloud progress restored from %s.") % username())
	else:
		queue_upload(local_progress)
	_set_progress_availability_resolved(true)


func _prepare_local_progress_for_session() -> void:
	var session_id := str(_session_user.get("id", ""))
	_local_progress_belongs_to_session = session_id != "" and str(GameManager.progress.get("cloud_owner_id", "")) == session_id
	if _local_progress_belongs_to_session:
		return
	# Browser storage is shared by accounts. Until this account's cloud save
	# arrives, never let a previous account's local campaign appear as Continue
	# or become an upload candidate. Preserve only the explicit UI language.
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
	SaveManager.save_progress(GameManager.progress, false)
	GameManager.progress_changed.emit()


func _set_progress_availability_resolved(resolved: bool) -> void:
	if _progress_availability_is_resolved == resolved:
		return
	_progress_availability_is_resolved = resolved
	progress_availability_resolved.emit()


func _progress_score(progress: Dictionary) -> int:
	var score := int(progress.get("current_level", 1)) * 100000
	score += (progress.get("completed_levels", []) as Array).size() * 1000
	score += (progress.get("observed_objects", []) as Array).size() * 100
	score += (progress.get("journal_entries", []) as Array).size() * 10
	score += int(progress.get("credits", 0))
	if bool(progress.get("program_completed", false)):
		score += 10000000
	return score
