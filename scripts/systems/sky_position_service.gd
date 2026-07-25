extends RefCounted
class_name SkyPositionService

const CONFIG_PATH := "res://data/observing_config.json"
const CATALOG_PATH := "res://data/celestial_catalog.json"
const EXPANSION_CATALOG_PATH := "res://data/expansion/celestial_catalog.json"
const API_KEYS_PATH := "res://data/local_api_keys.json"
const ASTRONOMY_API_URL := "https://api.astronomyapi.com/api/v2/bodies/positions"
const ONLINE_SOLAR_SYSTEM_IDS := [
	"moon", "mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"
]

var config: Dictionary = {}
var catalog: Array = []


func _init() -> void:
	load_config()
	load_catalog()


func load_config() -> Dictionary:
	config = _load_json_dict(CONFIG_PATH)
	return config


func load_catalog() -> Array:
	catalog = _load_json_array(CATALOG_PATH)
	catalog.append_array(_load_json_array(EXPANSION_CATALOG_PATH))
	return catalog


func load_local_api_keys() -> Dictionary:
	return _astronomy_api_credentials()


func get_sky_positions(screen_rect: Rect2, utc_datetime: Dictionary = {}, lat_override: float = NAN, lon_override: float = NAN) -> Dictionary:
	if utc_datetime.is_empty():
		utc_datetime = Time.get_datetime_dict_from_system(true)
	# The active observing location drives every position; it defaults to the
	# home site config but the world map can relocate the player.
	var latitude: float = lat_override if not is_nan(lat_override) else float(config.get("default_latitude", 34.0522))
	var longitude: float = lon_override if not is_nan(lon_override) else float(config.get("default_longitude", -118.2437))
	var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var result: Dictionary = {}

	for entry_value in catalog:
		var entry: Dictionary = entry_value
		var id: String = str(entry.get("id", ""))
		if id == "":
			continue
		var item: Dictionary = _fallback_item(entry, minimum_altitude)
		# Planets without baked RA/Dec: offline Keplerian ephemeris makes
		# their position follow the real date instead of a frozen fallback.
		if not entry.has("ra_hours") and entry.has("planet_body"):
			var ephemeris: Dictionary = planet_ra_dec(str(entry.get("planet_body", "")), utc_datetime)
			if not ephemeris.is_empty():
				entry = entry.duplicate()
				entry["ra_hours"] = ephemeris["ra_hours"]
				entry["dec_degrees"] = ephemeris["dec_degrees"]
		if entry.has("ra_hours") and entry.has("dec_degrees"):
			var alt_az: Dictionary = calculate_alt_az_from_ra_dec(
				float(entry.get("ra_hours", 0.0)),
				float(entry.get("dec_degrees", 0.0)),
				latitude,
				longitude,
				utc_datetime
			)
			# REAL SKY: the computed position is always used, at every altitude.
			# Objects below the horizon are reported as not visible rather than
			# being frozen at a teaching position - callers (the sky view, the
			# horizon gate, the world map) decide what to do about that.
			var altitude := float(alt_az["altitude"])
			item["altitude"] = altitude
			item["azimuth"] = alt_az["azimuth"]
			item["screen_pos"] = map_alt_az_to_screen(altitude, float(alt_az["azimuth"]), screen_rect)
			item["visible"] = altitude >= minimum_altitude
			item["below_horizon"] = altitude < 0.0
			item["visibility_text"] = _visibility_text(altitude, minimum_altitude)
			item["direction_text"] = direction_text(float(alt_az["azimuth"]))
			item["source"] = "calculated"
		# Otherwise keep the fallback item: it already carries the catalog's
		# fallback alt/az estimate and source "fallback". Valid AstronomyAPI
		# solar-system rows can replace it later.
		result[id] = item
	# Surface-feature entries (lunar craters, maria, terminator) ride their
	# parent body's live position instead of a private frozen fallback.
	for entry_value in catalog:
		var entry: Dictionary = entry_value
		var follow_id := str(entry.get("follows", ""))
		var id := str(entry.get("id", ""))
		if follow_id == "" or id == "" or not result.has(follow_id) or not result.has(id):
			continue
		var parent: Dictionary = result[follow_id]
		var item: Dictionary = result[id]
		item["altitude"] = parent.get("altitude", item.get("altitude"))
		item["azimuth"] = parent.get("azimuth", item.get("azimuth"))
		item["screen_pos"] = parent.get("screen_pos", item.get("screen_pos"))
		item["visible"] = parent.get("visible", item.get("visible"))
		item["visibility_text"] = parent.get("visibility_text", item.get("visibility_text"))
		item["direction_text"] = parent.get("direction_text", item.get("direction_text"))
		item["source"] = str(parent.get("source", "fallback"))
	return result


func get_sky_data(screen_rect: Rect2, utc_datetime: Dictionary = {}) -> Dictionary:
	return get_sky_positions(screen_rect, utc_datetime)


func fallback_positions(screen_rect: Rect2 = Rect2()) -> Dictionary:
	var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var result: Dictionary = {}
	for entry_value in catalog:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var item: Dictionary = _fallback_item(entry, minimum_altitude)
		if screen_rect.size != Vector2.ZERO and item.has("screen_pos"):
			var pos: Vector2 = item["screen_pos"]
			item["screen_pos"] = Vector2(
				clampf(pos.x, screen_rect.position.x, screen_rect.end.x),
				clampf(pos.y, screen_rect.position.y, screen_rect.end.y)
			)
		result[str(entry.get("id", ""))] = item
	return result


func request_online_planet_data(parent: Node, screen_rect: Rect2, callback: Callable, latitude := NAN, longitude := NAN) -> bool:
	if bool(config.get("offline_mode", false)) or not bool(config.get("use_online_planet_data", true)):
		return false
	var credentials: Dictionary = _astronomy_api_credentials()
	if credentials.is_empty():
		return false
	var local_datetime: Dictionary = Time.get_datetime_dict_from_system(false)
	var query := _astronomy_api_query(local_datetime, latitude, longitude)
	var request := HTTPRequest.new()
	request.timeout = 5.0
	parent.add_child(request)
	request.request_completed.connect(_on_online_positions_completed.bind(request, screen_rect, callback))
	var auth_text := "%s:%s" % [str(credentials.get("app_id", "")), str(credentials.get("app_secret", ""))]
	var headers := PackedStringArray(["Authorization: Basic " + Marshalls.utf8_to_base64(auth_text)])
	var error := request.request(ASTRONOMY_API_URL + "?" + query, headers, HTTPClient.METHOD_GET)
	if error != OK:
		request.queue_free()
		return false
	return true


func calculate_alt_az_from_ra_dec(ra_hours: float, dec_degrees: float, latitude_degrees: float, longitude_degrees: float, utc_datetime: Dictionary) -> Dictionary:
	var jd: float = julian_date(utc_datetime)
	var gmst: float = gmst_degrees(jd)
	var lst: float = wrap_degrees(gmst + longitude_degrees)
	var hour_angle: float = wrap_degrees(lst - ra_hours * 15.0)
	if hour_angle > 180.0:
		hour_angle -= 360.0

	var ha: float = deg_to_rad(hour_angle)
	var dec: float = deg_to_rad(dec_degrees)
	var lat: float = deg_to_rad(latitude_degrees)
	var sin_alt: float = sin(dec) * sin(lat) + cos(dec) * cos(lat) * cos(ha)
	var altitude: float = rad_to_deg(asin(clamp(sin_alt, -1.0, 1.0)))

	var az_y: float = -sin(ha)
	var az_x: float = tan(dec) * cos(lat) - sin(lat) * cos(ha)
	var azimuth: float = wrap_degrees(rad_to_deg(atan2(az_y, az_x)))
	return {
		"altitude": altitude,
		"azimuth": azimuth
	}


func radec_to_altaz(ra_hours: float, dec_degrees: float, latitude_degrees: float, longitude_degrees: float, utc_datetime: Dictionary) -> Dictionary:
	return calculate_alt_az_from_ra_dec(ra_hours, dec_degrees, latitude_degrees, longitude_degrees, utc_datetime)


# --------------------------------------------------- horizon / location logic


func visibility_at(ra_hours: float, dec_degrees: float, lat: float, lon: float, utc_datetime: Dictionary = {}) -> Dictionary:
	# Real altitude/azimuth of a target from a site, plus a plain visibility
	# verdict. This is the single source of truth for "is it up right now".
	if utc_datetime.is_empty():
		utc_datetime = Time.get_datetime_dict_from_system(true)
	var minimum: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var alt_az := calculate_alt_az_from_ra_dec(ra_hours, dec_degrees, lat, lon, utc_datetime)
	var altitude := float(alt_az["altitude"])
	var azimuth := float(alt_az["azimuth"])
	return {
		"altitude": altitude,
		"azimuth": azimuth,
		"below_horizon": altitude < 0.0,
		"visible": altitude >= minimum,
		"minimum": minimum,
		"direction_text": direction_text(azimuth)
	}


func visible_duration_hours(ra_hours: float, dec_degrees: float, lat: float, lon: float, utc_datetime: Dictionary = {}) -> float:
	# How many of the next 24 hours the target sits above the minimum altitude
	# (coarse 30-minute scan - enough for a "visible for ~N h" readout).
	if utc_datetime.is_empty():
		utc_datetime = Time.get_datetime_dict_from_system(true)
	var minimum: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var jd0 := julian_date(utc_datetime)
	var above := 0
	var samples := 48
	for i in range(samples):
		var jd := jd0 + float(i) * (0.5 / 24.0)
		var dt := datetime_from_julian(jd)
		var alt_az := calculate_alt_az_from_ra_dec(ra_hours, dec_degrees, lat, lon, dt)
		if float(alt_az["altitude"]) >= minimum:
			above += 1
	return float(above) * 0.5


func local_time_string(lon: float, utc_datetime: Dictionary = {}) -> String:
	# Approximate local clock from longitude (15 deg per hour). Good enough for
	# a flavor readout; not a timezone database.
	if utc_datetime.is_empty():
		utc_datetime = Time.get_datetime_dict_from_system(true)
	var utc_hour := float(utc_datetime.get("hour", 0)) + float(utc_datetime.get("minute", 0)) / 60.0
	var local := fposmod(utc_hour + lon / 15.0, 24.0)
	var h := int(floor(local))
	var m := int(round((local - float(h)) * 60.0)) % 60
	return "%02d:%02d" % [h, m]


func recommend_location(ra_hours: float, dec_degrees: float, sites: Array, utc_datetime: Dictionary = {}) -> Dictionary:
	# Pick the site where the target rides highest right now (best comfort +
	# darkest sky as a tie-break). Returns {} only if nowhere on the list has
	# it above the minimum - callers then keep the player where they are.
	if utc_datetime.is_empty():
		utc_datetime = Time.get_datetime_dict_from_system(true)
	var minimum: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	var best: Dictionary = {}
	var best_score := -1000.0
	for site_value in sites:
		var site: Dictionary = site_value
		var vis := visibility_at(ra_hours, dec_degrees, float(site.get("lat", 0.0)), float(site.get("lon", 0.0)), utc_datetime)
		var altitude := float(vis["altitude"])
		if altitude < minimum + 3.0:
			continue
		# Reward altitude, gently prefer darker skies (low Bortle).
		var score := altitude - float(site.get("bortle", 5)) * 1.5
		if score > best_score:
			best_score = score
			best = {
				"site": site,
				"altitude": altitude,
				"azimuth": float(vis["azimuth"]),
				"direction_text": str(vis["direction_text"]),
				"local_time": local_time_string(float(site.get("lon", 0.0)), utc_datetime),
				"visible_hours": visible_duration_hours(ra_hours, dec_degrees, float(site.get("lat", 0.0)), float(site.get("lon", 0.0)), utc_datetime)
			}
	return best


func datetime_from_julian(jd: float) -> Dictionary:
	# Inverse of julian_date for UTC civil time (Fliegel-Van Flandern).
	var z := int(floor(jd + 0.5))
	var f := (jd + 0.5) - float(z)
	var a := z
	if z >= 2299161:
		var alpha := int(floor((float(z) - 1867216.25) / 36524.25))
		a = z + 1 + alpha - int(floor(float(alpha) / 4.0))
	var b := a + 1524
	var c := int(floor((float(b) - 122.1) / 365.25))
	var d := int(floor(365.25 * float(c)))
	var e := int(floor((float(b) - float(d)) / 30.6001))
	var day_frac := float(b) - float(d) - float(int(floor(30.6001 * float(e)))) + f
	var day := int(floor(day_frac))
	var hours_f := (day_frac - float(day)) * 24.0
	var hour := int(floor(hours_f))
	var minute := int(floor((hours_f - float(hour)) * 60.0))
	var month := e - 1 if e < 14 else e - 13
	var year := c - 4716 if month > 2 else c - 4715
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0}


func map_alt_az_to_screen(altitude: float, azimuth: float, screen_rect: Rect2) -> Vector2:
	var center: Vector2 = screen_rect.position + screen_rect.size * 0.5
	var max_radius: float = min(screen_rect.size.x, screen_rect.size.y) * 0.46
	var radius: float = clamp((90.0 - altitude) / 90.0, 0.0, 1.0) * max_radius
	var angle: float = deg_to_rad(azimuth - 90.0)
	return center + Vector2(cos(angle), sin(angle)) * radius


func altaz_to_screen(altitude: float, azimuth: float, screen_rect: Rect2) -> Vector2:
	return map_alt_az_to_screen(altitude, azimuth, screen_rect)


# ---- Offline planetary ephemeris (mean Keplerian elements, J2000 + rates
# per Julian century). Accuracy ~1 degree over decades - ample for aiming
# gameplay, and it makes planet positions genuinely DATE-DRIVEN offline.
const PLANET_ELEMENTS := {
	"mercury": [0.38710, 0.20563, 7.005, 252.251, 149472.674, 77.457, 48.331],
	"venus": [0.72333, 0.00677, 3.395, 181.980, 58517.816, 131.564, 76.680],
	"earth": [1.00000, 0.01671, 0.0, 100.464, 35999.372, 102.937, 0.0],
	"mars": [1.52371, 0.09339, 1.850, 355.447, 19140.303, 336.041, 49.559],
	"jupiter": [5.20289, 0.04839, 1.304, 34.397, 3034.746, 14.728, 100.474],
	"saturn": [9.53707, 0.05415, 2.494, 34.396, 1222.494, 92.598, 113.662],
	"uranus": [19.19126, 0.04717, 0.773, 313.238, 428.482, 170.954, 74.017],
	"neptune": [30.06896, 0.00859, 1.770, 304.880, 218.459, 44.965, 131.784],
}


func _heliocentric_position(elements: Array, T: float) -> Vector3:
	var a: float = float(elements[0])
	var e: float = float(elements[1])
	var inclination: float = deg_to_rad(float(elements[2]))
	var mean_longitude: float = wrap_degrees(float(elements[3]) + float(elements[4]) * T)
	var perihelion_longitude: float = float(elements[5])
	var node_longitude: float = deg_to_rad(float(elements[6]))
	var perihelion_arg: float = deg_to_rad(perihelion_longitude) - node_longitude
	var mean_anomaly: float = deg_to_rad(wrap_degrees(mean_longitude - perihelion_longitude))
	var eccentric: float = mean_anomaly
	for _iteration in range(6):
		eccentric = eccentric - (eccentric - e * sin(eccentric) - mean_anomaly) / (1.0 - e * cos(eccentric))
	var true_anomaly: float = 2.0 * atan2(sqrt(1.0 + e) * sin(eccentric * 0.5), sqrt(1.0 - e) * cos(eccentric * 0.5))
	var radius: float = a * (1.0 - e * cos(eccentric))
	var u: float = true_anomaly + perihelion_arg
	return Vector3(
		radius * (cos(node_longitude) * cos(u) - sin(node_longitude) * sin(u) * cos(inclination)),
		radius * (sin(node_longitude) * cos(u) + cos(node_longitude) * sin(u) * cos(inclination)),
		radius * sin(u) * sin(inclination)
	)


func planet_ra_dec(body: String, utc_datetime: Dictionary) -> Dictionary:
	if body == "moon":
		return moon_ra_dec(utc_datetime)
	if not PLANET_ELEMENTS.has(body):
		return {}
	var T: float = (julian_date(utc_datetime) - 2451545.0) / 36525.0
	var planet: Vector3 = _heliocentric_position(PLANET_ELEMENTS[body], T)
	var earth: Vector3 = _heliocentric_position(PLANET_ELEMENTS["earth"], T)
	var geo: Vector3 = planet - earth
	var obliquity: float = deg_to_rad(23.4393)
	var x: float = geo.x
	var y: float = geo.y * cos(obliquity) - geo.z * sin(obliquity)
	var z: float = geo.y * sin(obliquity) + geo.z * cos(obliquity)
	var ra_hours: float = wrap_degrees(rad_to_deg(atan2(y, x))) / 15.0
	var dec_degrees: float = rad_to_deg(atan2(z, sqrt(x * x + y * y)))
	return {"ra_hours": ra_hours, "dec_degrees": dec_degrees}


func moon_ra_dec(utc_datetime: Dictionary) -> Dictionary:
	# Low-precision lunar position (Meeus, a few arc-minutes). Good enough for a
	# game horizon check - the Moon is a real body with a real, moving altitude.
	var d: float = julian_date(utc_datetime) - 2451545.0
	var deg := deg_to_rad(1.0)
	var L: float = deg_to_rad(fposmod(218.316 + 13.176396 * d, 360.0))
	var M: float = deg_to_rad(fposmod(134.963 + 13.064993 * d, 360.0))
	var F: float = deg_to_rad(fposmod(93.272 + 13.229350 * d, 360.0))
	var lon: float = L + deg_to_rad(6.289) * sin(M)
	var lat: float = deg_to_rad(5.128) * sin(F)
	var obliquity: float = deg_to_rad(23.4393)
	var x: float = cos(lat) * cos(lon)
	var y: float = cos(obliquity) * cos(lat) * sin(lon) - sin(obliquity) * sin(lat)
	var z: float = sin(obliquity) * cos(lat) * sin(lon) + cos(obliquity) * sin(lat)
	var ra_hours: float = wrap_degrees(rad_to_deg(atan2(y, x))) / 15.0
	var dec_degrees: float = rad_to_deg(atan2(z, sqrt(x * x + y * y)))
	return {"ra_hours": ra_hours, "dec_degrees": dec_degrees}


func julian_date(utc_datetime: Dictionary) -> float:
	var year: int = int(utc_datetime.get("year", 2026))
	var month: int = int(utc_datetime.get("month", 1))
	var day: int = int(utc_datetime.get("day", 1))
	var hour: int = int(utc_datetime.get("hour", 0))
	var minute: int = int(utc_datetime.get("minute", 0))
	var second: int = int(utc_datetime.get("second", 0))
	if month <= 2:
		year -= 1
		month += 12
	var a: int = floori(float(year) / 100.0)
	var b: int = 2 - a + floori(float(a) / 4.0)
	var day_fraction: float = (float(hour) + float(minute) / 60.0 + float(second) / 3600.0) / 24.0
	return floor(365.25 * float(year + 4716)) + floor(30.6001 * float(month + 1)) + float(day) + day_fraction + float(b) - 1524.5


func gmst_degrees(julian: float) -> float:
	var d: float = julian - 2451545.0
	var t: float = d / 36525.0
	return wrap_degrees(280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - t * t * t / 38710000.0)


func wrap_degrees(value: float) -> float:
	var wrapped: float = fmod(value, 360.0)
	if wrapped < 0.0:
		wrapped += 360.0
	return wrapped


func direction_text(azimuth: float) -> String:
	var directions: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index: int = int(floor((wrap_degrees(azimuth) + 22.5) / 45.0)) % directions.size()
	return directions[index]


func _astronomy_api_query(utc_datetime: Dictionary, latitude_override := NAN, longitude_override := NAN) -> String:
	var latitude: String = str(latitude_override if not is_nan(latitude_override) else float(config.get("default_latitude", 34.0522)))
	var longitude: String = str(longitude_override if not is_nan(longitude_override) else float(config.get("default_longitude", -118.2437)))
	var year: int = int(utc_datetime.get("year", 2026))
	var month: int = int(utc_datetime.get("month", 1))
	var day: int = int(utc_datetime.get("day", 1))
	var hour: int = int(utc_datetime.get("hour", 0))
	var minute: int = int(utc_datetime.get("minute", 0))
	var second: int = int(utc_datetime.get("second", 0))
	var date_text := "%04d-%02d-%02d" % [year, month, day]
	var time_text := "%02d:%02d:%02d" % [hour, minute, second]
	var params := {
		"latitude": latitude,
		"longitude": longitude,
		"elevation": "0",
		"from_date": date_text,
		"to_date": date_text,
		"time": time_text,
		"output": "rows"
	}
	var parts: Array[String] = []
	for key_value in params.keys():
		var key: String = str(key_value)
		parts.append(key.uri_encode() + "=" + str(params[key]).uri_encode())
	return "&".join(parts)


func _on_online_positions_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, screen_rect: Rect2, callback: Callable) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return
	var online_data: Dictionary = _parse_astronomy_api_positions(parsed, screen_rect)
	if online_data.is_empty():
		return
	callback.call(online_data)


func _parse_astronomy_api_positions(payload: Dictionary, screen_rect: Rect2) -> Dictionary:
	var output: Dictionary = {}
	var data: Dictionary = payload.get("data", {})
	var table: Dictionary = data.get("table", {})
	var rows: Array = table.get("rows", [])
	if rows.is_empty():
		rows = data.get("rows", [])
	for row_value in rows:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var astronomy_item: Dictionary = _parse_astronomy_api_row(row, screen_rect)
		if not astronomy_item.is_empty():
			output[str(astronomy_item.get("id", ""))] = astronomy_item
			continue
		var entry: Dictionary = row.get("entry", {})
		var object_id: String = str(entry.get("id", "")).to_lower()
		if not ONLINE_SOLAR_SYSTEM_IDS.has(object_id):
			continue
		var cells: Array = row.get("cells", [])
		if cells.is_empty() or not cells[0] is Dictionary:
			continue
		var cell: Dictionary = cells[0]
		var position: Dictionary = cell.get("position", {})
		var horizontal: Dictionary = position.get("horizontal", {})
		var horizontal_values := _validated_online_horizontal(horizontal)
		if horizontal_values.is_empty():
			continue
		var altitude: float = float(horizontal_values["altitude"])
		var azimuth: float = float(horizontal_values["azimuth"])
		var item: Dictionary = _catalog_item_for_id(object_id)
		if item.is_empty():
			continue
		var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
		output[object_id] = {
			"id": object_id,
			"name": str(item.get("name", object_id)),
			"type": str(item.get("type", "planet")),
			"icon_type": str(item.get("icon_type", "white_star")),
			"altitude": altitude,
			"azimuth": azimuth,
			"screen_pos": map_alt_az_to_screen(altitude, azimuth, screen_rect),
			"visible": altitude >= minimum_altitude,
			"below_horizon": altitude < 0.0,
			"visibility_text": _visibility_text(altitude, minimum_altitude),
			"direction_text": direction_text(azimuth),
			"source": "online"
		}
	return output


func _parse_astronomy_api_row(row: Dictionary, screen_rect: Rect2) -> Dictionary:
	var body: Dictionary = row.get("body", {})
	var object_id: String = str(body.get("id", "")).to_lower()
	if not ONLINE_SOLAR_SYSTEM_IDS.has(object_id):
		return {}
	var positions: Array = row.get("positions", [])
	if positions.is_empty() or not positions[0] is Dictionary:
		return {}
	var position_row: Dictionary = positions[0]
	var position: Dictionary = position_row.get("position", {})
	var horizontal: Dictionary = position.get("horizontal", {})
	if horizontal.is_empty():
		horizontal = position.get("horizonal", {})
	var horizontal_values := _validated_online_horizontal(horizontal)
	if horizontal_values.is_empty():
		return {}
	var altitude: float = float(horizontal_values["altitude"])
	var azimuth: float = float(horizontal_values["azimuth"])
	var item: Dictionary = _catalog_item_for_id(object_id)
	if item.is_empty():
		return {}
	var minimum_altitude: float = float(config.get("minimum_visible_altitude_degrees", 10.0))
	return {
		"id": object_id,
		"name": str(item.get("name", body.get("name", object_id))),
		"type": str(item.get("type", "planet")),
		"icon_type": str(item.get("icon_type", "white_star")),
		"altitude": altitude,
		"azimuth": azimuth,
		"screen_pos": map_alt_az_to_screen(altitude, azimuth, screen_rect),
		"visible": altitude >= minimum_altitude,
		"below_horizon": altitude < 0.0,
		"visibility_text": _visibility_text(altitude, minimum_altitude),
		"direction_text": direction_text(azimuth),
		"source": "online"
	}


func _validated_online_horizontal(horizontal: Dictionary) -> Dictionary:
	# Missing API fields must not silently become 0 degrees. A bad response is
	# ignored so the caller keeps the locally calculated ephemeris position.
	if horizontal.is_empty():
		return {}
	var altitude_data: Variant = horizontal.get("altitude", null)
	var azimuth_data: Variant = horizontal.get("azimuth", null)
	if not altitude_data is Dictionary or not azimuth_data is Dictionary:
		return {}
	if not altitude_data.has("degrees") or not azimuth_data.has("degrees"):
		return {}
	var altitude_value: Variant = altitude_data.get("degrees")
	var azimuth_value: Variant = azimuth_data.get("degrees")
	if not _is_valid_number(altitude_value) or not _is_valid_number(azimuth_value):
		return {}
	var altitude := float(altitude_value)
	var azimuth := float(azimuth_value)
	if altitude < -90.0 or altitude > 90.0 or azimuth < 0.0 or azimuth > 360.0:
		return {}
	return {"altitude": altitude, "azimuth": wrapf(azimuth, 0.0, 360.0)}


func is_valid_position_item(item: Variant) -> bool:
	if not item is Dictionary or not item.has("altitude") or not item.has("azimuth"):
		return false
	if not _is_valid_number(item.get("altitude")) or not _is_valid_number(item.get("azimuth")):
		return false
	var altitude := float(item.get("altitude"))
	var azimuth := float(item.get("azimuth"))
	return altitude >= -90.0 and altitude <= 90.0 and azimuth >= 0.0 and azimuth < 360.0


func _is_valid_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number)


func _catalog_item_for_id(object_id: String) -> Dictionary:
	for entry_value in catalog:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("id", "")) == object_id:
			return entry
	return {}


func _astronomy_api_credentials() -> Dictionary:
	var keys: Dictionary = _load_json_dict(API_KEYS_PATH)
	if keys.is_empty():
		return {}
	var nested: Dictionary = keys.get("astronomyapi", {})
	var app_id: String = str(nested.get("app_id", keys.get("astronomyapi_app_id", "")))
	var app_secret: String = str(nested.get("app_secret", keys.get("astronomyapi_app_secret", "")))
	if app_id == "" or app_secret == "":
		return {}
	return {
		"app_id": app_id,
		"app_secret": app_secret
	}


func _fallback_item(entry: Dictionary, minimum_altitude: float) -> Dictionary:
	var pos: Vector2 = Vector2(float(entry.get("fallback_x", 100.0)), float(entry.get("fallback_y", 100.0)))
	var has_fallback_altaz: bool = entry.has("fallback_altitude") and entry.has("fallback_azimuth")
	var altitude: float = float(entry.get("fallback_altitude", 0.0))
	var azimuth: float = float(entry.get("fallback_azimuth", 0.0))
	return {
		"id": str(entry.get("id", "")),
		"name": str(entry.get("name", entry.get("id", ""))),
		"type": str(entry.get("type", "object")),
		"icon_type": str(entry.get("icon_type", "white_star")),
		"altitude": altitude,
		"azimuth": azimuth,
		"screen_pos": pos,
		"visible": has_fallback_altaz and altitude >= minimum_altitude,
		"visibility_text": "Teaching simulation" if has_fallback_altaz else "Offline fallback",
		"direction_text": direction_text(azimuth) if has_fallback_altaz else "Estimate",
		"source": "fallback"
	}


func _visibility_text(altitude: float, minimum_altitude: float) -> String:
	if altitude < 0.0:
		return "Below horizon"
	if altitude < minimum_altitude:
		return "Low on horizon"
	return "Visible tonight"


func _has_local_api_keys() -> bool:
	if not FileAccess.file_exists(API_KEYS_PATH):
		return false
	var keys: Dictionary = _load_json_dict(API_KEYS_PATH)
	return not keys.is_empty()


func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text().trim_prefix("\uFEFF")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text().trim_prefix("\uFEFF")
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []
