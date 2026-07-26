extends Control
class_name SpaceFalseColourDisplay

const BAND_SHADER := preload("res://shaders/space_false_colour_band.gdshader")
const CHANNEL_COLORS := {
	# A restrained scientific palette. The channels remain easy to compare,
	# without turning the image into fluorescent red/green/blue silhouettes.
	"R": Color(0.94, 0.31, 0.17, 0.76),
	"G": Color(0.43, 0.68, 0.49, 0.66),
	"B": Color(0.24, 0.48, 0.86, 0.74),
}
const BAND_MODES := {
	"nir_short": 0,
	"nir_long": 1,
	"miri_dust": 2,
}

var source_texture: Texture2D
var band_textures: Dictionary = {}
var channel_map: Dictionary = {}
var signatures: Dictionary = {}
var target_kind := "galaxy"
var target_seed := 0
var signal_strength := 1.0
var preview_band := ""
var reveal_progress := 1.0:
	set(value):
		reveal_progress = clampf(value, 0.0, 1.0)
		_update_reveal()

var _layers: Array[TextureRect] = []


func configure(
	texture: Texture2D,
	mapping: Dictionary,
	band_signatures: Dictionary,
	kind: String,
	seed: int,
	strength: float,
	preview := "",
	separate_band_textures: Dictionary = {}
) -> void:
	source_texture = texture
	band_textures = separate_band_textures.duplicate()
	channel_map = mapping.duplicate(true)
	signatures = band_signatures.duplicate(true)
	target_kind = kind
	target_seed = seed
	signal_strength = clampf(strength, 0.15, 1.0)
	preview_band = preview
	_rebuild_layers()
	queue_redraw()


func _rebuild_layers() -> void:
	for layer in _layers:
		if is_instance_valid(layer):
			remove_child(layer)
			layer.queue_free()
	_layers.clear()
	if source_texture == null and band_textures.is_empty():
		return
	if preview_band != "":
		_add_band_layer(preview_band, Color(0.92, 0.96, 1.0, 0.96), "Preview")
		return
	for channel in ["R", "G", "B"]:
		var band_id := str(channel_map.get(channel, ""))
		if BAND_MODES.has(band_id):
			_add_band_layer(band_id, CHANNEL_COLORS[channel], channel)


func _add_band_layer(band_id: String, color: Color, suffix: String) -> void:
	var layer_texture := band_textures.get(band_id, source_texture) as Texture2D
	if layer_texture == null:
		return
	var layer := TextureRect.new()
	layer.name = "BandLayer_%s_%s" % [band_id, suffix]
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.texture = layer_texture
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BAND_SHADER
	material.set_shader_parameter("band_mode", int(BAND_MODES[band_id]))
	material.set_shader_parameter("mapped_color", color)
	material.set_shader_parameter("feature_weights", _signature_vector(band_id))
	material.set_shader_parameter("signal_strength", signal_strength)
	material.set_shader_parameter("reveal_progress", reveal_progress)
	material.set_shader_parameter("direct_band_source", band_textures.has(band_id))
	layer.material = material
	add_child(layer)
	_layers.append(layer)


func _signature_vector(band_id: String) -> Vector4:
	var value: Variant = signatures.get(band_id, {})
	var signature: Dictionary = value if value is Dictionary else {}
	return Vector4(
		float(signature.get("compact", 0.0)),
		float(signature.get("embedded", 0.0)),
		float(signature.get("dust", 0.0)),
		float(signature.get("diffuse", 0.0))
	)


func _update_reveal() -> void:
	for layer in _layers:
		if is_instance_valid(layer) and layer.material is ShaderMaterial:
			(layer.material as ShaderMaterial).set_shader_parameter("reveal_progress", reveal_progress)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("02060c"), true)
	if not _layers.is_empty():
		return
	var mapped_bands: Array[String] = []
	if preview_band != "":
		mapped_bands.append(preview_band)
	else:
		for channel in ["R", "G", "B"]:
			var band_id := str(channel_map.get(channel, ""))
			if BAND_MODES.has(band_id):
				mapped_bands.append(band_id)
	for band_id in mapped_bands:
		_draw_fallback_band(band_id, _band_color(band_id))


func _band_color(band_id: String) -> Color:
	if preview_band != "":
		return Color(0.88, 0.92, 0.96, 0.82)
	for channel in ["R", "G", "B"]:
		if str(channel_map.get(channel, "")) == band_id:
			return CHANNEL_COLORS[channel]
	return Color(0.75, 0.80, 0.88, 0.65)


func _draw_fallback_band(band_id: String, color: Color) -> void:
	var center := size * 0.5
	var reveal_y := size.y * reveal_progress
	var signature := _signature_vector(band_id)
	if band_id == "nir_short":
		for index in range(13):
			var angle := float(index) * 2.399 + float(target_seed % 17) * 0.07
			var radius := 18.0 + float((index * 29 + target_seed) % 120)
			var point := center + Vector2(cos(angle), sin(angle) * 0.62) * radius
			if point.y <= reveal_y:
				var star_radius := 1.2 + 2.2 * signature.x * float((index % 3) + 1) / 3.0
				draw_circle(point, star_radius, color)
	elif band_id == "nir_long":
		for index in range(7):
			var radius := Vector2(150.0 - index * 17.0, 62.0 - index * 6.0)
			var alpha := (0.035 + float(index) * 0.025) * signature.y
			_draw_ellipse(center + Vector2(index * 2 - 6, 0), radius, Color(color, alpha), reveal_y)
	else:
		for index in range(5):
			var offset := Vector2(-120.0 + index * 60.0, sin(float(index) * 1.7) * 32.0)
			var arc_center := center + offset
			if arc_center.y <= reveal_y + 60.0:
				draw_arc(
					arc_center,
					48.0 + index * 7.0,
					-1.15,
					1.25,
					28,
					Color(color, 0.24 + signature.z * 0.12),
					5.0
				)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, reveal_y: float) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		var angle := TAU * float(index) / 48.0
		var point := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		if point.y > reveal_y:
			point.y = reveal_y
		points.append(point)
	if points.size() >= 3:
		draw_colored_polygon(points, color)
