extends Node

signal checkpoint_resolved(action: String, node_id: String)

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
var _pending_continue_action: Callable
var _resolved_node_ids: Dictionary = {}
var _resume_node_ids: Dictionary = {}
var _continue_callback: JavaScriptObject
var _exit_callback: JavaScriptObject


func _ready() -> void:
	_install_browser_callbacks()


func node_for_level(level_number: int) -> String:
	return str(NODE_BY_COMPLETED_LEVEL.get(level_number, ""))


func offer_after_level(level_number: int, continue_scene: String, continue_action: Callable = Callable()) -> bool:
	if not OS.has_feature("web") or not ClassDB.class_exists("JavaScriptBridge"):
		return false
	var action := continue_action
	if not action.is_valid():
		action = func() -> void:
			GameManager.go(continue_scene)
	var detail := _prepare_checkpoint(level_number, continue_scene, _browser_research_context(), action)
	if detail.is_empty():
		return false
	_install_browser_callbacks()
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


func _browser_research_context() -> Dictionary:
	var value: Variant = JavaScriptBridge.eval(
		"(()=>{try{const bridge=window.PixelObservatoryResearch;if(!bridge)return '{}';const context=typeof bridge.activeResearchContext==='function'?(bridge.activeResearchContext()||{}):{};return JSON.stringify({canOfferBaseline:typeof bridge.canOfferBaseline==='function'&&bridge.canOfferBaseline()===true,hasVerifiedGameplaySession:typeof bridge.hasVerifiedGameplaySession==='function'&&bridge.hasVerifiedGameplaySession()===true,participantId:typeof context.participantId==='string'?context.participantId:'',routeArm:typeof context.routeArm==='string'?context.routeArm:''});}catch(_){return '{}'}})()",
		true
	)
	var context: Variant = JSON.parse_string(str(value))
	return context if context is Dictionary else {}


func _can_offer_checkpoint(level_number: int, context: Dictionary) -> bool:
	if node_for_level(level_number).is_empty():
		return false
	if level_number == 1:
		return bool(context.get("canOfferBaseline", false))
	return bool(context.get("hasVerifiedGameplaySession", false))


func _prepare_checkpoint(level_number: int, continue_scene: String, context: Dictionary, continue_action: Callable = Callable()) -> Dictionary:
	var node_id := node_for_level(level_number)
	if node_id.is_empty() or _resolved_node_ids.has(node_id) or not _can_offer_checkpoint(level_number, context):
		return {}
	_pending_continue_scene = continue_scene
	_pending_node_id = node_id
	_pending_continue_action = continue_action
	return {
		"nodeId": node_id,
		"completedLevel": level_number,
		"continueScene": continue_scene,
		"language": GameManager.language_mode,
		"participantId": str(context.get("participantId", "")),
		"routeArm": str(context.get("routeArm", "")),
	}


func consume_resolved_checkpoint(node_id: String) -> bool:
	if not _resume_node_ids.has(node_id):
		return false
	_resume_node_ids.erase(node_id)
	return true


func _on_browser_continue(arguments: Array) -> void:
	if _pending_node_id.is_empty() or _payload_node_id(arguments) != _pending_node_id:
		return
	var node_id := _pending_node_id
	var continue_scene := _pending_continue_scene
	var continue_action := _pending_continue_action
	_pending_node_id = ""
	_pending_continue_scene = ""
	_pending_continue_action = Callable()
	_resolved_node_ids[node_id] = true
	_resume_node_ids[node_id] = true
	checkpoint_resolved.emit("continue", node_id)
	if continue_action.is_valid():
		continue_action.call()


func _on_browser_exit_to_archive(_arguments: Array) -> void:
	if _pending_node_id.is_empty():
		return
	var node_id := _pending_node_id
	_pending_node_id = ""
	_pending_continue_scene = ""
	_pending_continue_action = Callable()
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
