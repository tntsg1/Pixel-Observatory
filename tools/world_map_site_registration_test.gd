extends SceneTree

# Verifies both halves of world-map placement:
# 1. real observatory coordinates remain geographically valid;
# 2. the authored map's calibrated projection lands each marker on its region.

var failures := 0

const EXPECTED_IMAGE_RECTS := {
	"home_san_gabriel": Rect2(342, 410, 28, 28),
	"mauna_kea": Rect2(238, 466, 30, 28),
	"kitt_peak": Rect2(365, 420, 28, 28),
	"atacama_paranal": Rect2(512, 638, 28, 28),
	"cerro_tololo": Rect2(508, 660, 28, 28),
	"la_palma": Rect2(695, 430, 28, 28),
	"sutherland": Rect2(832, 668, 28, 28),
	"siding_spring": Rect2(1294, 664, 30, 30),
	"lake_tekapo": Rect2(1370, 716, 30, 34),
	"ali_tibet": Rect2(1045, 418, 30, 30),
	"gamsberg": Rect2(815, 632, 28, 30),
	"la_silla": Rect2(508, 656, 28, 28),
	"svalbard": Rect2(814, 250, 30, 30),
	"ushuaia": Rect2(516, 758, 30, 34),
	"greenwich": Rect2(758, 348, 30, 30),
}


func _initialize() -> void:
	await process_frame
	var gm := root.get_node("/root/GameManager")
	var packed := load("res://scenes/world_map.tscn") as PackedScene
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame

	var all_sites: Array = [gm.home_location()]
	all_sites.append_array(gm.location_sites())
	_check(all_sites.size() == EXPECTED_IMAGE_RECTS.size(), "all configured locations have registration checks")
	var ids := {}
	for site_value in all_sites:
		var site := site_value as Dictionary
		var id := str(site.get("id", ""))
		ids[id] = true
		var lat := float(site.get("lat", 999.0))
		var lon := float(site.get("lon", 999.0))
		_check(lat >= -90.0 and lat <= 90.0, "%s latitude is valid" % id)
		_check(lon >= -180.0 and lon <= 180.0, "%s longitude is valid" % id)
		_check(EXPECTED_IMAGE_RECTS.has(id), "%s has a painted-map region" % id)
		if EXPECTED_IMAGE_RECTS.has(id):
			var p: Vector2 = map.call("debug_image_position_for_coordinates", lat, lon)
			_check((EXPECTED_IMAGE_RECTS[id] as Rect2).has_point(p), "%s marker is registered to its land/island region (%s)" % [id, p])
	for id_value in EXPECTED_IMAGE_RECTS:
		_check(ids.has(id_value), "%s registration is not stale" % id_value)

	# Cardinal anchors prove the frame is no longer treated as geography.
	var prime: Vector2 = map.call("debug_image_position_for_coordinates", 0.0, 0.0)
	var north: Vector2 = map.call("debug_image_position_for_coordinates", 90.0, 0.0)
	var south: Vector2 = map.call("debug_image_position_for_coordinates", -60.0, 0.0)
	_check(prime.distance_to(Vector2(772.0, 551.0)) < 0.1, "prime meridian/equator matches the painted graticule")
	_check(north.y < prime.y and south.y > prime.y, "latitude increases upward on the map")

	map.queue_free()
	await process_frame
	if failures == 0:
		print("WORLD MAP SITE REGISTRATION TEST PASS")
		quit(0)
	else:
		print("WORLD MAP SITE REGISTRATION TEST FAIL (%d)" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		print("  FAIL: " + label)
