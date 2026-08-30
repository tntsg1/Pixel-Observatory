class_name UiKit
extends RefCounted

# Shared visual language for the game's panels and controls.
#
# The problem this solves: beautiful painted backgrounds were being covered with
# Godot's DEFAULT widget theme - grey system toggles, a stock dropdown, a flat
# box - which reads as an unfinished editor overlay. Everything here is drawn
# procedurally (no art assets) in the game's brass-and-navy palette, so a panel
# looks like it belongs to the observatory instead of to the engine.

# --- palette ---------------------------------------------------------------
const INK        := Color(0.020, 0.032, 0.058)   # deep panel body
const INK_SOFT   := Color(0.040, 0.058, 0.098)   # lighter top of the gradient
const BRASS      := Color(0.83, 0.63, 0.28)
const BRASS_HI   := Color(1.00, 0.86, 0.52)
const BRASS_DIM  := Color(0.44, 0.33, 0.16)
const PARCHMENT  := Color(0.94, 0.91, 0.83)
const MUTED      := Color(0.64, 0.71, 0.80)
const SKY        := Color(0.45, 0.80, 1.00)


# --- switch icons ----------------------------------------------------------
# CheckButton draws its state with the `checked` / `unchecked` icons. Swapping
# those for a hand-drawn brass pill keeps the node a real CheckButton (tests and
# accessibility still see a toggle) while removing the stock grey look entirely.
static func switch_texture(on: bool) -> ImageTexture:
	var w := 52
	var h := 26
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := 11.0
	var cy := h * 0.5
	var left := Vector2(r + 1.0, cy)
	var right := Vector2(w - r - 1.0, cy)
	var knob: Vector2 = right if on else left

	var track_fill: Color = Color(0.42, 0.30, 0.12) if on else Color(0.055, 0.075, 0.115)
	var track_edge: Color = BRASS if on else Color(0.24, 0.30, 0.40)
	var knob_fill: Color = BRASS_HI if on else Color(0.40, 0.46, 0.56)

	for y in range(h):
		for x in range(w):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			# capsule signed distance = distance to the segment minus radius
			var d_track: float = _seg_dist(p, left, right) - r
			if d_track > 1.5:
				continue
			var col := track_fill
			var a: float = clampf(1.0 - d_track, 0.0, 1.0)
			# rim
			if d_track > -1.8:
				col = track_edge
			# inner glow along the top edge reads as a lit, glassy track
			elif on and p.y < cy:
				col = track_fill.lerp(BRASS, 0.35 * (1.0 - p.y / cy))
			var d_knob: float = p.distance_to(knob) - (r - 2.5)
			if d_knob < 1.0:
				var ka: float = clampf(1.0 - d_knob, 0.0, 1.0)
				var kc: Color = knob_fill
				# a soft top highlight so the knob looks rounded, not flat
				if p.y < knob.y:
					kc = knob_fill.lerp(Color(1, 1, 1), 0.30 * (1.0 - p.y / knob.y))
				col = col.lerp(kc, ka)
				a = maxf(a, ka)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- styleboxes ------------------------------------------------------------
static func panel_box(shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = INK
	s.border_color = BRASS
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 14.0
	s.content_margin_bottom = 14.0
	if shadow:
		# lifts the card off the painting behind it
		s.shadow_color = Color(0, 0, 0, 0.55)
		s.shadow_size = 18
		s.shadow_offset = Vector2(0, 6)
	return s


static func field_box(fill: Color, edge: Color, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0
	return s


# --- control styling -------------------------------------------------------
static func style_check(cb: CheckButton) -> void:
	cb.add_theme_icon_override("checked", switch_texture(true))
	cb.add_theme_icon_override("unchecked", switch_texture(false))
	# CheckButton also consults these when hovered/pressed
	cb.add_theme_icon_override("checked_disabled", switch_texture(true))
	cb.add_theme_icon_override("unchecked_disabled", switch_texture(false))
	cb.add_theme_color_override("font_color", PARCHMENT)
	cb.add_theme_color_override("font_hover_color", BRASS_HI)
	cb.add_theme_color_override("font_pressed_color", BRASS_HI)
	cb.add_theme_color_override("font_focus_color", PARCHMENT)
	cb.add_theme_font_size_override("font_size", 15)
	# a faint ruled row, brightening on hover, instead of a naked label
	cb.add_theme_stylebox_override("normal", field_box(Color(1, 1, 1, 0.014), Color(1, 1, 1, 0.05)))
	cb.add_theme_stylebox_override("hover", field_box(Color(1, 0.86, 0.5, 0.07), Color(0.83, 0.63, 0.28, 0.55)))
	cb.add_theme_stylebox_override("pressed", field_box(Color(1, 0.86, 0.5, 0.10), BRASS))
	cb.add_theme_stylebox_override("focus", field_box(Color(0, 0, 0, 0), Color(0.83, 0.63, 0.28, 0.35)))


static func style_option(ob: OptionButton) -> void:
	ob.add_theme_stylebox_override("normal", field_box(Color(0.055, 0.078, 0.125), BRASS_DIM))
	ob.add_theme_stylebox_override("hover", field_box(Color(0.085, 0.115, 0.175), BRASS))
	ob.add_theme_stylebox_override("pressed", field_box(Color(0.10, 0.13, 0.19), BRASS_HI))
	ob.add_theme_stylebox_override("focus", field_box(Color(0, 0, 0, 0), Color(0.83, 0.63, 0.28, 0.4)))
	ob.add_theme_color_override("font_color", PARCHMENT)
	ob.add_theme_color_override("font_hover_color", BRASS_HI)
	ob.add_theme_font_size_override("font_size", 14)


static func style_button(b: Button, primary: bool = false) -> void:
	var fill: Color = Color(0.20, 0.145, 0.055) if primary else Color(0.055, 0.078, 0.125)
	b.add_theme_stylebox_override("normal", field_box(fill, BRASS_DIM if not primary else BRASS))
	b.add_theme_stylebox_override("hover", field_box(fill.lightened(0.12), BRASS_HI, 2))
	b.add_theme_stylebox_override("pressed", field_box(fill.darkened(0.15), BRASS_HI, 2))
	b.add_theme_stylebox_override("focus", field_box(Color(0, 0, 0, 0), Color(0.83, 0.63, 0.28, 0.4)))
	b.add_theme_color_override("font_color", PARCHMENT if not primary else BRASS_HI)
	b.add_theme_color_override("font_hover_color", BRASS_HI)
	b.add_theme_font_size_override("font_size", 15)


# --- ornament --------------------------------------------------------------
## Brass corner brackets, matching the observatory's framed signage.
static func add_corner_brackets(host: Control, inset: float = 6.0, arm: float = 16.0) -> void:
	var w: float = host.size.x
	var h: float = host.size.y
	var corners := [
		[Vector2(inset, inset), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(w - inset, inset), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(inset, h - inset), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(w - inset, h - inset), Vector2(-1, 0), Vector2(0, -1)],
	]
	for entry in corners:
		var origin: Vector2 = entry[0]
		var dx: Vector2 = entry[1]
		var dy: Vector2 = entry[2]
		_bracket_arm(host, origin, dx * arm, 2.0)
		_bracket_arm(host, origin, dy * arm, 2.0)


static func _bracket_arm(host: Control, origin: Vector2, span: Vector2, thick: float) -> void:
	var bar := ColorRect.new()
	bar.color = BRASS
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w: float = absf(span.x) if absf(span.x) > 0.0 else thick
	var h: float = absf(span.y) if absf(span.y) > 0.0 else thick
	bar.size = Vector2(w, h)
	bar.position = Vector2(minf(origin.x, origin.x + span.x), minf(origin.y, origin.y + span.y))
	host.add_child(bar)

# --- depth helpers ---------------------------------------------------------
## A vertical gradient strip. StyleBoxFlat can only do a single flat fill, which
## is exactly why the old panels looked like coloured paper; a real gradient is
## what makes a surface read as lit metal.
static func gradient_texture(top: Color, bottom: Color, height: int = 48) -> ImageTexture:
	var img := Image.create(1, maxi(2, height), false, Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		var t: float = float(y) / float(img.get_height() - 1)
		img.set_pixel(0, y, top.lerp(bottom, t))
	return ImageTexture.create_from_image(img)


## Brass nameplate: gradient body, a lit top hairline and a shadow underline.
## Replaces the flat brown bar that made every panel header look muddy.
static func header_plate(parent: Control, rect: Rect2, title: String, font_size: int = 16) -> Label:
	var plate := TextureRect.new()
	plate.texture = gradient_texture(Color(0.28, 0.20, 0.09), Color(0.14, 0.10, 0.05), 40)
	plate.position = rect.position
	plate.size = rect.size
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plate)
	_hairline(parent, Vector2(rect.position.x, rect.position.y), rect.size.x, Color(0.86, 0.66, 0.32, 0.85))
	_hairline(parent, Vector2(rect.position.x, rect.end.y - 1.0), rect.size.x, Color(0, 0, 0, 0.45))
	var label := Label.new()
	label.text = title
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.84))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func _hairline(parent: Control, at: Vector2, width: float, col: Color) -> void:
	var line := ColorRect.new()
	line.color = col
	line.position = at
	line.size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


## Adds the lit top edge that turns a flat rectangle into a bevelled surface.
static func add_bevel(parent: Control, rect: Rect2) -> void:
	_hairline(parent, rect.position + Vector2(2, 1), rect.size.x - 4.0, Color(1, 1, 1, 0.07))


## List row styling with a real selected state: a brass left accent bar plus a
## brighter body, so the chosen item is unmistakable at a glance.
static func style_list_card(b: Button, selected: bool, unlocked: bool = true) -> void:
	var base: Color = Color(0.052, 0.075, 0.120) if unlocked else Color(0.038, 0.045, 0.058)
	var edge: Color = BRASS if selected else (BRASS_DIM if unlocked else Color(0.19, 0.22, 0.28))
	var fill: Color = Color(0.10, 0.13, 0.20) if selected else base
	b.add_theme_stylebox_override("normal", field_box(fill, edge, 2 if selected else 1))
	b.add_theme_stylebox_override("hover", field_box(Color(0.12, 0.16, 0.24), BRASS_HI, 2))
	b.add_theme_stylebox_override("pressed", field_box(Color(0.14, 0.18, 0.26), BRASS_HI, 2))
	b.add_theme_stylebox_override("disabled", field_box(Color(0.030, 0.036, 0.048), Color(0.16, 0.19, 0.24), 1))
	b.add_theme_color_override("font_color", PARCHMENT if unlocked else Color(0.42, 0.47, 0.55))
	b.add_theme_color_override("font_hover_color", BRASS_HI)
	b.add_theme_color_override("font_disabled_color", Color(0.40, 0.45, 0.52))
