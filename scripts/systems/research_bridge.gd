extends Node

signal checkpoint_resolved(action: String, node_id: String)

const RESEARCH_SESSION_KEY := "pixel-observatory:research-session:v2"
const NODE_BY_COMPLETED_LEVEL := {
	1: "baseline",
	6: "A",
	11: "B",
	16: "C",
	21: "D",
	24: "E",
}

var _pending_continue_scene := ""
var _pending_node_id := ""
var _continue_callback: JavaScriptObject
var _exit_callback: JavaScriptObject


func _ready() -> void:
	_install_browser_callbacks()


func node_for_level(level_number: int) -> String:
	return str(NODE_BY_COMPLETED_LEVEL.get(level_number, ""))


func offer_after_level(level_number: int, continue_scene: String) -> bool:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return false
	var node_id := node_for_level(level_number)
	if node_id.is_empty() or not _browser_reports_active_research():
		return false
	_install_browser_callbacks()
	_pending_continue_scene = continue_scene
	_pending_node_id = node_id
	var detail := {
		"nodeId": node_id,
		"completedLevel": level_number,
		"continueScene": continue_scene,
		"language": GameManager.language_mode,
		"participantId": GameManager.research_participant_id(),
		"routeArm": GameManager.research_route_arm(),
	}
	JavaScriptBridge.eval(
		"window.dispatchEvent(new CustomEvent('observatory:research-checkpoint',{detail:%s}));" % JSON.stringify(detail),
		true
	)
	return true


func _install_browser_callbacks() -> void:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_continue_callback = JavaScriptBridge.create_callback(_on_browser_continue)
	_exit_callback = JavaScriptBridge.create_callback(_on_browser_exit_to_archive)
	window.__poResearchContinue = _continue_callback
	window.__poResearchExitToArchive = _exit_callback


func _browser_reports_active_research() -> bool:
	var value: Variant = JavaScriptBridge.eval(
		"(()=>{try{const bridge=window.PixelObservatoryResearch;if(bridge&&typeof bridge.hasActiveInvitationOrSession==='function')return !!bridge.hasActiveInvitationOrSession();const session=JSON.parse(localStorage.getItem('%s')||'null');return !!(session&&typeof session==='object'&&typeof session.participantId==='string'&&session.participantId.length>0)}catch(_){return false}})()" % RESEARCH_SESSION_KEY,
		true
	)
	return bool(value)


func _on_browser_continue(arguments: Array) -> void:
	if _pending_node_id.is_empty() or _payload_node_id(arguments) != _pending_node_id:
		return
	var node_id := _pending_node_id
	var continue_scene := _pending_continue_scene
	_pending_node_id = ""
	_pending_continue_scene = ""
	checkpoint_resolved.emit("continue", node_id)
	if not continue_scene.is_empty():
		GameManager.go(continue_scene)


func _on_browser_exit_to_archive(_arguments: Array) -> void:
	if _pending_node_id.is_empty():
		return
	var node_id := _pending_node_id
	_pending_node_id = ""
	_pending_continue_scene = ""
	GameManager.save()
	checkpoint_resolved.emit("exit_to_archive", node_id)
	JavaScriptBridge.eval("window.top.location.assign('/study/');", true)


func _payload_node_id(arguments: Array) -> String:
	if arguments.is_empty():
		return ""
	var payload: Variant = JSON.parse_string(str(arguments[0]))
	if not payload is Dictionary:
		return ""
	return str((payload as Dictionary).get("nodeId", ""))
