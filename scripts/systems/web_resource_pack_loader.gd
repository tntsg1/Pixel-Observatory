extends Node

# The browser shell preloads these immutable packs into Emscripten's virtual
# filesystem before Godot starts. Mount them before any other autoload or the
# main scene resolves resources that live outside the small core PCK.
const WEB_PACK_PATHS: PackedStringArray = [
	"/resource-packs/audio.pck",
	"/resource-packs/astronomy-media.pck",
	"/resource-packs/star-catalog.pck",
]
const RESOURCE_PROBES: PackedStringArray = [
	"res://assets/audio/music/lobby.ogg",
	"res://assets/telescope_view/andromeda_clear.png",
]

func _init() -> void:
	if not OS.has_feature("web"):
		return
	for pack_path in WEB_PACK_PATHS:
		if not FileAccess.file_exists(pack_path):
			push_error("Incremental Web resource pack was not preloaded: %s" % pack_path)
			continue
		if not ProjectSettings.load_resource_pack(pack_path, false):
			push_error("Incremental Web resource pack could not be mounted: %s" % pack_path)
			continue
		print("Mounted incremental Web resource pack: %s" % pack_path)
	for resource_path in RESOURCE_PROBES:
		if not ResourceLoader.exists(resource_path):
			push_error("Mounted Web resource is unavailable: %s" % resource_path)
	if not FileAccess.file_exists("res://data/deep_stars.json"):
		push_error("Mounted Web star catalogue is unavailable")
