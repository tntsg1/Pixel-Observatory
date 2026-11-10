class_name StoryVisualResolver
extends RefCounted

const OBSERVATORY_VISUAL := "res://assets/reference/observatory_room_hall_1024.png"
const ROLE_PATHS := {
	"observatory": OBSERVATORY_VISUAL,
	"workflow": OBSERVATORY_VISUAL,
	"naked_eye": "res://assets/learning_diagrams/naked_eye_limits_diagram.png",
	"observation_pad": "res://assets/ui_extracted/observation_pad_prop.png",
	"mission_board": "res://assets/ui_extracted/mission_board_prop.png",
	"parts_cabinet": "res://assets/ui_extracted/parts_cabinet_prop.png",
	"focus": "res://assets/learning_diagrams/focus_focal_plane_diagram.png",
	"collimation": "res://assets/learning_diagrams/collimation_alignment_diagram.png",
	"site_map": "res://assets/learning_diagrams/site_map.png",
	"logbook": "res://assets/ui_extracted/learning_journal_prop.png",
	"space_console": "res://assets/learning_diagrams/jwst_instruments_diagram.png",
	"radio_console": "res://assets/telescope_parts/fast_radio/pulsar_timing_console.png"
}
const FAMILY_BLUEPRINTS := {
	"refractor": "res://assets/learning_diagrams/refractor_light_path.png",
	"newtonian": "res://assets/assembly/newtonian_main_blueprint.png",
	"dobsonian": "res://assets/assembly/dobsonian_main_blueprint.png",
	"cassegrain": "res://assets/assembly/cassegrain_main_blueprint_cropped.png",
	"gregorian": "res://assets/learning_diagrams/gregorian_folded_path.svg",
	"space_segmented": "res://assets/assembly/space_main_blueprint.png",
	"fast_radio": "res://assets/assembly/fast_blueprint_center_cropped.png"
}
const FAMILY_NAMES := {
	"refractor": ["Refractor", "折射望远镜"],
	"newtonian": ["Newtonian reflector", "牛顿反射望远镜"],
	"dobsonian": ["Dobsonian telescope", "多布森望远镜"],
	"cassegrain": ["Cassegrain telescope", "卡塞格林望远镜"],
	"gregorian": ["Gregorian telescope", "格里高利望远镜"],
	"space_segmented": ["Space infrared observatory", "太空红外天文台"],
	"fast_radio": ["FAST radio telescope", "FAST 射电望远镜"]
}
const BASE_TARGET_PATHS := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"vega": "res://assets/telescope_view/star_blue_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"arcturus": "res://assets/telescope_view/star_red_large.png",
	"canopus": "res://assets/telescope_view/star_white_large.png",
	"alpha_centauri": "res://assets/telescope_view/star_white_large.png",
	"proxima": "res://assets/telescope_view/star_red_large.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_clear.png",
	"andromeda": "res://assets/telescope_view/andromeda_clear.png",
	"pulsar_b0329": "res://assets/learning_media/fast/pulsar_science.jpg"
}
const CONSTELLATION_PATHS := {
	"ursa_major": "res://assets/learning_diagrams/constellation_ursa_major.svg",
	"cassiopeia": "res://assets/learning_diagrams/constellation_cassiopeia.svg",
	"cygnus": "res://assets/learning_diagrams/constellation_cygnus.svg",
	"lyra": "res://assets/learning_diagrams/constellation_lyra.svg",
	"aquila": "res://assets/learning_diagrams/constellation_aquila.svg",
	"taurus": "res://assets/learning_diagrams/constellation_taurus.svg",
	"scorpius": "res://assets/learning_diagrams/constellation_scorpius.svg",
	"orion_constellation": "res://assets/learning_diagrams/constellation_orion.svg",
	"leo": "res://assets/learning_diagrams/constellation_leo.svg"
}
const PATH_COPY := {
	"refractor_light_path": ["Refractor light path", "折射镜光路", "A lens gathers light and brings it to the eyepiece.", "物镜汇聚光线，再由目镜放大焦平面上的像。"],
	"newtonian_light_path": ["Newtonian light path", "牛顿反射镜光路", "Primary and secondary mirrors redirect one shared optical axis.", "主镜与副镜沿同一光轴收集并折转光线。"],
	"finder_scope_alignment_diagram": ["Finder alignment", "寻星镜校准", "The wide finder and narrow main scope must agree on one target.", "宽视场寻星镜必须与窄视场主镜指向同一个目标。"],
	"magnification_tradeoff": ["Useful magnification", "有效放大率", "More power helps only while aperture and the atmosphere preserve detail.", "只有口径与大气仍能保留细节时，提高倍率才有意义。"],
	"magnification_field_of_view_diagram": ["Magnification and field", "倍率与视场", "Higher magnification narrows the patch of sky that remains visible.", "倍率越高，能够看见的天区就越窄。"],
	"seeing_turbulence": ["Atmospheric seeing", "大气视宁度", "Moving air distorts the wavefront before it reaches the telescope.", "流动空气会在光线进入望远镜前扰乱波前。"],
	"moon_crater_impact": ["Lunar impact record", "月面撞击记录", "Craters preserve the Moon's long impact history.", "环形山保存着月球漫长的撞击历史。"],
	"jupiter_anatomy": ["Jupiter's visible structure", "木星可见结构", "Bands and large storms become evidence when focus and seeing agree.", "焦点与视宁度合适时，云带和巨大风暴才会成为可辨认的证据。"],
	"cloud_waiting": ["Cloud interruption", "云层遮挡", "Some observing problems are solved by waiting, not by touching the instrument.", "有些观测问题需要等待，而不是继续调整仪器。"],
	"nebula_nursery": ["Stellar nursery", "恒星育婴区", "Nebular gas and dust can hide the stars forming inside it.", "星云中的气体和尘埃会遮住正在形成的恒星。"],
	"light_pollution_compare": ["Sky brightness comparison", "光污染对比", "A brighter sky erases faint contrast before the telescope can recover it.", "明亮的天空会先抹去微弱对比，望远镜无法凭空恢复。"],
	"dark_adaptation_curve": ["Dark adaptation", "暗适应", "Sensitivity rises gradually after bright light leaves the eye.", "离开强光后，眼睛的暗处敏感度会逐渐恢复。"],
	"earth_rotation_drift": ["Apparent sky drift", "地球自转漂移", "Earth's rotation moves an untracked target across the field.", "地球自转会让未追踪的目标穿过视场。"],
	"tracking_mount_idea": ["Tracking correction", "追踪修正", "A drive counters steady sky motion with small continuous corrections.", "追踪支架用细小而连续的修正抵消天空漂移。"],
	"jwst_spectrum": ["Infrared evidence", "红外证据", "Infrared instruments measure wavelengths the eye cannot see.", "红外仪器测量的是人眼看不见的波段。"],
	"jwst_instruments_diagram": ["Space observatory instruments", "太空天文台仪器", "Each instrument answers a different wavelength and science question.", "不同仪器分别回答不同波段与科学问题。"],
	"fast_blueprint_center_cropped": ["FAST engineering blueprint", "FAST 工程蓝图", "The active reflector, suspended feed cabin, and receiver form one signal chain.", "主动反射面、悬索馈源舱和接收机构成一条完整信号链。"],
	"dobsonian_main_blueprint": ["Dobsonian blueprint", "多布森蓝图", "A Newtonian tube rides directly on a simple manual rocker mount.", "牛顿式镜筒直接安装在简洁的手动摇臂底座上。"],
	"cassegrain_main_blueprint_cropped": ["Cassegrain blueprint", "卡塞格林蓝图", "Two mirrors fold a long focal length into a compact tube.", "两面镜子把长焦距折叠进紧凑镜筒。"],
	"observatory_room_hall_1024": ["The club observatory", "天文俱乐部大厅", "Every observing session begins with a question and ends with a record.", "每次观测都从一个问题开始，以一份记录结束。"]
}


static func resolve(
	event_id: String,
	line: Dictionary,
	context: Dictionary,
	target: Dictionary,
	telescope_family: String,
	line_index: int = 0
) -> Dictionary:
	var explicit_path := str(line.get("image", ""))
	var role := str(line.get("visual_role", "")).strip_edges()
	var resolved_family := str(line.get("visual_family", telescope_family)).strip_edges()
	if resolved_family == "":
		resolved_family = telescope_family
	if role == "":
		role = _infer_role(event_id, context, line_index, explicit_path)
	var path := _path_for_role(role, target, resolved_family)
	if role == "explicit":
		path = explicit_path
	elif path == "" and explicit_path != "":
		path = explicit_path
	if path == "" or not ResourceLoader.exists(path):
		role = "observatory"
		path = OBSERVATORY_VISUAL
	var copy := _copy_for(role, path, target, resolved_family)
	return {
		"path": path,
		"role": role,
		"title_en": str(line.get("visual_title_en", copy[0])),
		"title_zh": str(line.get("visual_title_zh", copy[1])),
		"caption_en": str(line.get("visual_caption_en", copy[2])),
		"caption_zh": str(line.get("visual_caption_zh", copy[3])),
		"fit": "cover" if role in ["observatory", "workflow"] else "contain"
	}


static func _infer_role(event_id: String, context: Dictionary, line_index: int, explicit_path: String) -> String:
	if explicit_path != "":
		return "explicit"
	if event_id == "intro":
		return ["observatory", "naked_eye", "workflow", "observation_pad", "naked_eye", "target", "observation_pad"][mini(line_index, 6)]
	if event_id.contains("before_assembly") or str(context.get("to_id", "")) == "assembly_table":
		return "assembly"
	if event_id.contains("before_focus"):
		return "focus"
	if event_id == "first_collimation" or str(context.get("to_id", "")) == "collimation_bench":
		return "collimation"
	if event_id == "first_tube_subassembly":
		return "assembly"
	if event_id == "first_below_horizon" or str(context.get("to_id", "")) == "site_map":
		return "site_map"
	if str(context.get("phase", "")) == "after":
		return "result"
	match str(context.get("to_id", "")):
		"mission_board":
			return "mission_board"
		"parts_cabinet":
			return "parts_cabinet"
		"space_console":
			return "target"
		"radio_console":
			return "target"
	return "target"


static func _path_for_role(role: String, target: Dictionary, telescope_family: String) -> String:
	if role == "assembly":
		return str(FAMILY_BLUEPRINTS.get(telescope_family, ROLE_PATHS["observatory"]))
	if role in ["target", "result"]:
		return _target_path(target)
	return str(ROLE_PATHS.get(role, ""))


static func _target_path(target: Dictionary) -> String:
	for key in ["result_sprite_path", "sky_icon_source_path", "sprite_path"]:
		var path := str(target.get(key, ""))
		if path != "" and ResourceLoader.exists(path):
			return path
	var target_id := str(target.get("id", ""))
	var mapped := str(BASE_TARGET_PATHS.get(target_id, CONSTELLATION_PATHS.get(target_id, "")))
	if mapped != "" and ResourceLoader.exists(mapped):
		return mapped
	return "res://assets/learning_diagrams/deep_sky_observation_diagram.png"


static func _copy_for(role: String, path: String, target: Dictionary, telescope_family: String) -> Array:
	if role == "workflow":
		return ["One observing night", "一晚的观测流程", "QUESTION  >  PARTS  >  ASSEMBLY  >  OBSERVE  >  RECORD", "领题  >  选件  >  组装  >  观测  >  记录"]
	if role == "naked_eye":
		return ["Start with your own eyes", "先用自己的眼睛", "The first record establishes what unaided vision can and cannot reveal.", "第一份记录先确认肉眼能看见什么、又看不见什么。"]
	if role == "observation_pad":
		return ["Observation Pad", "中央观测台", "Walk to the central platform to aim, compare, and record the sky.", "前往中央圆台，在那里瞄准、比较并记录天空。"]
	if role == "mission_board":
		return ["Mission Board", "任务板", "Take the question first; the instrument choice follows from it.", "先领取科学问题，再由问题决定该使用哪种仪器。"]
	if role == "parts_cabinet":
		return ["Parts Cabinet", "零件柜", "Choose components for the observation you are about to attempt.", "根据即将进行的观测选择合适零件。"]
	if role == "assembly":
		var names: Array = FAMILY_NAMES.get(telescope_family, ["Telescope blueprint", "望远镜蓝图"])
		return [str(names[0]) + " blueprint", str(names[1]) + "蓝图", "Every highlighted component belongs to one physical light or signal path.", "每个高亮部件都属于同一条真实的光路或信号链。"]
	if role == "focus":
		return ["Focal plane", "焦平面", "Best focus is the point where the smallest real detail becomes stable.", "最佳焦点是最小真实细节能够稳定呈现的位置。"]
	if role == "collimation":
		return ["Optical-axis alignment", "光轴准直", "Mirrors must agree on one axis before their resolution can add together.", "各面镜子必须先对准同一条光轴，分辨率才能真正叠加。"]
	if role == "site_map":
		return ["Observation Site Map", "观测地点图", "A target below one horizon may be observable from another real site.", "在一个地点低于地平线的目标，可能在另一个真实台址可见。"]
	if role == "logbook":
		return ["Club Logbook", "俱乐部观测日志", "Keep the evidence so the next observation can be compared with this one.", "保存证据，下一次观测才能与这一次进行比较。"]
	if role == "space_console":
		return ["Space Telescope Console", "太空望远镜控制台", "Deployment, thermal control, guidance, and processing are one observing chain.", "展开、热控、导星和处理共同构成一条观测链。"]
	if role == "radio_console":
		return ["Radio timing evidence", "射电计时证据", "FAST records repeating arrival times rather than a visible-light photograph.", "FAST 记录的是重复到达时间，而不是可见光照片。"]
	if role in ["target", "result"]:
		var name_en := str(target.get("name_en", str(target.get("id", "Target")).capitalize()))
		var name_zh := str(target.get("name_zh", "观测目标"))
		if str(target.get("id", "")) == "pulsar_b0329":
			return [name_en + " radio record", name_zh + "射电记录", "The recovered pulse pattern is the observation; there is no eyepiece photograph.", "恢复出的脉冲节律就是观测成果，这里不会出现目镜照片。"]
		if role == "result":
			return [name_en + " — recorded evidence", name_zh + " · 已记录证据", "This is the evidence the dialogue is interpreting and carrying into the logbook.", "这就是当前台词正在解释、并将写入日志的观测证据。"]
		return [name_en + " — observing target", name_zh + " · 当前目标", "The visual now shows the object being discussed, not an unrelated fallback image.", "画面显示的正是当前台词所讨论的天体，不再使用无关兜底图。"]
	var key := path.get_file().get_basename()
	if PATH_COPY.has(key):
		return PATH_COPY[key]
	return [key.replace("_", " ").capitalize(), "教学参考图", "This authored reference supports the current explanation.", "这张原始教学参考图对应当前讲解内容。"]
