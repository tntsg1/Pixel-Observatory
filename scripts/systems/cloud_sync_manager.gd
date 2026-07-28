extends Node

signal sync_status_changed(status: String, detail: String)

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


func _ready() -> void:
	if not OS.has_feature("web"):
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
	_pending_progress = progress.duplicate(true)
	_upload_clock = UPLOAD_DEBOUNCE_SECONDS
	sync_status_changed.emit("queued", tr("Cloud save queued"))


func signed_in() -> bool:
	return not _session_user.is_empty()


func username() -> String:
	return str(_session_user.get("username", ""))


func _browser_origin() -> String:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var value = JavaScriptBridge.eval("window.location.origin", true)
	var origin := str(value)
	if not origin.begins_with("http"):
		return ""
	return origin


func _check_session() -> void:
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
		return
	match operation:
		"session":
			var user_value = payload.get("user")
			if typeof(user_value) == TYPE_DICTIONARY:
				_session_user = user_value
				sync_status_changed.emit("signed_in", tr("Cloud archive connected: %s") % username())
				_download_cloud_save()
			else:
				_session_user.clear()
				sync_status_changed.emit("signed_out", tr("Sign in on the website to enable cloud saves."))
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
		queue_upload(GameManager.progress)
		return
	var cloud_save: Dictionary = save_value
	var cloud_progress_value = cloud_save.get("progress")
	if typeof(cloud_progress_value) != TYPE_DICTIONARY:
		return
	_cloud_version = int(cloud_save.get("version", 0))
	var cloud_progress: Dictionary = cloud_progress_value
	var local_progress: Dictionary = GameManager.progress
	var cloud_score := _progress_score(cloud_progress)
	var local_score := _progress_score(local_progress)
	if cloud_score > local_score:
		var merged: Dictionary = SaveManager._merge_defaults(GameManager.default_progress(), cloud_progress)
		GameManager.progress = merged
		GameManager.call("_normalize_progress")
		SaveManager.save_progress(GameManager.progress, false)
		GameManager.progress_changed.emit()
		sync_status_changed.emit("downloaded", tr("Cloud progress restored from %s.") % username())
	else:
		queue_upload(local_progress)


func _progress_score(progress: Dictionary) -> int:
	var score := int(progress.get("current_level", 1)) * 100000
	score += (progress.get("completed_levels", []) as Array).size() * 1000
	score += (progress.get("observed_objects", []) as Array).size() * 100
	score += (progress.get("journal_entries", []) as Array).size() * 10
	score += int(progress.get("credits", 0))
	if bool(progress.get("program_completed", false)):
		score += 10000000
	return score
