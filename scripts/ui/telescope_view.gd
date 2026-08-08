extends Control

const TURBULENCE_SHADER := preload("res://shaders/turbulence.gdshader")
const GRAIN_SHADER := preload("res://shaders/grain.gdshader")
const LENS_RING_OCCLUDER_SHADER := preload("res://shaders/lens_ring_occluder.gdshader")
const NAKED_EYE_OUTER_RING_SHADER := preload("res://shaders/naked_eye_outer_ring.gdshader")
const OPTICAL_LENS_SHADER := preload("res://shaders/optical_lens.gdshader")
const OPTICAL_TARGET_STATE_SHADER := preload("res://shaders/optical_target_state.gdshader")
const EXTENDED_FIELD_ENVIRONMENT_SHADER_CODE := """
shader_type canvas_item;
uniform float sky_lift : hint_range(0.0, 1.0) = 0.0;
uniform float faint_suppression : hint_range(0.0, 1.0) = 0.0;
uniform float contrast_loss : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float emission_filter_gain : hint_range(0.0, 1.0) = 0.0;
uniform float cluster_mode : hint_range(0.0, 1.0) = 0.0;
uniform float seeing_strength : hint_range(0.0, 1.0) = 0.0;
uniform float magnification_zoom : hint_range(0.65, 2.6) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec4 environment_response(vec4 source, vec2 uv) {
	vec3 rgb = source.rgb;
	float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float bright_core = smoothstep(0.30, 0.78, lum);
	float faint_structure = 1.0 - bright_core;
	rgb *= 1.0 - faint_suppression * faint_structure * 0.76;
	float gray = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(rgb, vec3(gray), desaturation);
	vec3 lifted_floor = vec3(0.030, 0.034, 0.052) * sky_lift;
	rgb = mix(rgb, max(rgb, lifted_floor), contrast_loss * faint_structure);
	float emission_structure = smoothstep(0.05, 0.42, max(rgb.r, rgb.b) - rgb.g * 0.28);
	rgb *= 1.0 + emission_filter_gain * emission_structure * 0.22;
	if (cluster_mode > 0.5) {
		float cell = hash21(floor(uv * 150.0));
		float faint_star = smoothstep(0.06, 0.42, gray) * (1.0 - bright_core);
		float resolved_fraction = step(seeing_strength * 0.72, cell);
		rgb *= 1.0 - faint_star * seeing_strength * (1.0 - resolved_fraction) * 0.82;
		float scintillation = sin(TIME * (2.1 + cell * 2.6) + cell * 31.0);
		rgb *= 1.0 + bright_core * seeing_strength * scintillation * 0.055;
	}
	float structure_visibility = mix(1.0, mix(0.16, 1.0, bright_core), faint_suppression);
	return vec4(rgb, source.a * structure_visibility);
}

void fragment() {
	vec2 source_uv = (UV - vec2(0.5)) / magnification_zoom + vec2(0.5);
	vec4 source = texture(TEXTURE, source_uv);
	COLOR = environment_response(source, source_uv) * COLOR;
}
"""
const EXTENDED_FIELD_DEFOCUS_SHADER_CODE := """
shader_type canvas_item;
uniform float blur_radius_px : hint_range(0.0, 36.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.4) = 1.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
uniform float sky_lift : hint_range(0.0, 1.0) = 0.0;
uniform float faint_suppression : hint_range(0.0, 1.0) = 0.0;
uniform float contrast_loss : hint_range(0.0, 1.0) = 0.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.0;
uniform float emission_filter_gain : hint_range(0.0, 1.0) = 0.0;
uniform float cluster_mode : hint_range(0.0, 1.0) = 0.0;
uniform float seeing_strength : hint_range(0.0, 1.0) = 0.0;
uniform float magnification_zoom : hint_range(0.65, 2.6) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec4 environment_response(vec4 source, vec2 uv) {
	vec3 rgb = source.rgb;
	float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	float bright_core = smoothstep(0.30, 0.78, lum);
	float faint_structure = 1.0 - bright_core;
	rgb *= 1.0 - faint_suppression * faint_structure * 0.76;
	float gray = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
	rgb = mix(rgb, vec3(gray), desaturation);
	vec3 lifted_floor = vec3(0.030, 0.034, 0.052) * sky_lift;
	rgb = mix(rgb, max(rgb, lifted_floor), contrast_loss * faint_structure);
	float emission_structure = smoothstep(0.05, 0.42, max(rgb.r, rgb.b) - rgb.g * 0.28);
	rgb *= 1.0 + emission_filter_gain * emission_structure * 0.22;
	if (cluster_mode > 0.5) {
		float cell = hash21(floor(uv * 150.0));
		float faint_star = smoothstep(0.06, 0.42, gray) * (1.0 - bright_core);
		float resolved_fraction = step(seeing_strength * 0.72, cell);
		rgb *= 1.0 - faint_star * seeing_strength * (1.0 - resolved_fraction) * 0.82;
		float scintillation = sin(TIME * (2.1 + cell * 2.6) + cell * 31.0);
		rgb *= 1.0 + bright_core * seeing_strength * scintillation * 0.055;
	}
	float structure_visibility = mix(1.0, mix(0.16, 1.0, bright_core), faint_suppression);
	return vec4(rgb, source.a * structure_visibility);
}

void fragment() {
	vec2 uv = (UV - vec2(0.5)) / magnification_zoom + vec2(0.5);
	// Extended targets should lose fine structure, not behave like rubber.
	// Cluster registration stays fixed so individual stellar PSFs, rather
	// than the whole photograph, carry the seeing response.
	float wobble = turbulence * 0.0007 * (1.0 - cluster_mode);
	uv.x += sin(uv.y * 29.0 + TIME * 1.7) * wobble;
	uv.y += cos(uv.x * 25.0 + TIME * 1.4) * wobble * 0.7;
	// A dense 5x5 Gaussian approximation removes high-frequency structure.
	// The previous sparse ring of samples left every star and dust filament
	// intact, so severe defocus looked like several shifted sharp pictures.
	vec2 step_px = TEXTURE_PIXEL_SIZE * blur_radius_px * 0.5;
	vec4 sum = vec4(0.0);
	sum += texture(TEXTURE, uv + step_px * vec2(-2.0, -2.0)) * 0.00390625;
	sum += texture(TEXTURE, uv + step_px * vec2(-1.0, -2.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2( 0.0, -2.0)) * 0.02343750;
	sum += texture(TEXTURE, uv + step_px * vec2( 1.0, -2.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2( 2.0, -2.0)) * 0.00390625;
	sum += texture(TEXTURE, uv + step_px * vec2(-2.0, -1.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2(-1.0, -1.0)) * 0.06250000;
	sum += texture(TEXTURE, uv + step_px * vec2( 0.0, -1.0)) * 0.09375000;
	sum += texture(TEXTURE, uv + step_px * vec2( 1.0, -1.0)) * 0.06250000;
	sum += texture(TEXTURE, uv + step_px * vec2( 2.0, -1.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2(-2.0,  0.0)) * 0.02343750;
	sum += texture(TEXTURE, uv + step_px * vec2(-1.0,  0.0)) * 0.09375000;
	sum += texture(TEXTURE, uv)                                  * 0.14062500;
	sum += texture(TEXTURE, uv + step_px * vec2( 1.0,  0.0)) * 0.09375000;
	sum += texture(TEXTURE, uv + step_px * vec2( 2.0,  0.0)) * 0.02343750;
	sum += texture(TEXTURE, uv + step_px * vec2(-2.0,  1.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2(-1.0,  1.0)) * 0.06250000;
	sum += texture(TEXTURE, uv + step_px * vec2( 0.0,  1.0)) * 0.09375000;
	sum += texture(TEXTURE, uv + step_px * vec2( 1.0,  1.0)) * 0.06250000;
	sum += texture(TEXTURE, uv + step_px * vec2( 2.0,  1.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2(-2.0,  2.0)) * 0.00390625;
	sum += texture(TEXTURE, uv + step_px * vec2(-1.0,  2.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2( 0.0,  2.0)) * 0.02343750;
	sum += texture(TEXTURE, uv + step_px * vec2( 1.0,  2.0)) * 0.01562500;
	sum += texture(TEXTURE, uv + step_px * vec2( 2.0,  2.0)) * 0.00390625;
	COLOR = environment_response(vec4(sum.rgb * brightness, sum.a), UV) * COLOR;
}
"""
const STAR_FIELD_PSF_SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform float defocus : hint_range(0.0, 1.0) = 0.0;
uniform float seeing : hint_range(0.0, 1.0) = 0.0;
uniform float sharp_sigma : hint_range(0.02, 0.14) = 0.055;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float optical_error = clamp(max(defocus, seeing * 0.28), 0.0, 1.0);
	float sigma = mix(sharp_sigma, 0.18, pow(optical_error, 0.72));
	float profile = exp(-dot(centered, centered) / max(2.0 * sigma * sigma, 0.0001));
	// Preserve approximate point-source energy: an unfocused star becomes a
	// broad, dim disk rather than a larger equally-bright square.
	float energy_peak = min(1.0, (sharp_sigma * sharp_sigma) / max(sigma * sigma, 0.0001));
	// A badly focused star is dimmer per pixel, but it must remain visible as
	// a broad circular PSF instead of disappearing behind the grain layer.
	energy_peak = max(energy_peak, 0.16);
	vec4 source = COLOR;
	COLOR = vec4(source.rgb, source.a * profile * energy_peak);
}
"""

const TARGET_STAR_PSF_SHADER_CODE := """
shader_type canvas_item;
render_mode unshaded;

uniform float defocus : hint_range(0.0, 1.0) = 0.0;
uniform float seeing : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.2, 1.4) = 1.0;
uniform vec4 psf_tint : source_color = vec4(1.0);
uniform vec4 source_tint : source_color = vec4(0.78, 0.84, 1.0, 1.0);
uniform float sharp_core_sigma : hint_range(0.003, 0.02) = 0.0065;
uniform float halo_strength : hint_range(0.0, 0.3) = 0.10;
uniform float source_art_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 sharp = texture(TEXTURE, UV);
	float optical_error = clamp(max(defocus, seeing * 0.06), 0.0, 1.0);
	float sigma = mix(0.012, 0.14, pow(optical_error, 0.72));
	vec2 centered = UV - vec2(0.5);
	float profile = exp(-dot(centered, centered) / max(2.0 * sigma * sigma, 0.0001));
	float sharp_core = exp(-dot(centered, centered) / max(2.0 * sharp_core_sigma * sharp_core_sigma, 0.0001));
	float soft_halo = exp(-dot(centered, centered) / (2.0 * 0.026 * 0.026));
	float horizontal_spike = exp(-abs(centered.y) / 0.006) * exp(-abs(centered.x) / 0.095);
	float vertical_spike = exp(-abs(centered.x) / 0.006) * exp(-abs(centered.y) / 0.095);
	float diffraction = max(sharp_core, max(soft_halo * halo_strength, (horizontal_spike + vertical_spike) * 0.10));
	// A strictly energy-normalized stellar PSF becomes imperceptible on an
	// SDR game display long before the player reaches focus. Keep a continuous
	// perceptual peak for bright guide stars while still reducing brightness
	// and spreading the footprint as focus error grows.
	float energy_peak = mix(1.0, 0.58, pow(optical_error, 0.78));
	// Preserve the catalog hue. A per-channel minimum turned an orange giant
	// into a pink star by lifting blue much more than red. The source image is
	// used only to locate its compact core; its baked low-alpha halo is omitted
	// so no circular texture boundary can appear in the eyepiece.
	vec3 star_color = source_tint.rgb;
	vec3 core_color = mix(vec3(1.0), star_color, 0.34);
	vec3 analytical_color = mix(star_color, core_color, sharp_core);
	vec4 analytical_core = vec4(analytical_color * brightness, diffraction);
	float source_art_alpha = smoothstep(0.006, 0.055, sharp.a);
	vec4 source_art = vec4(sharp.rgb * brightness, source_art_alpha);
	vec4 sharp_response = mix(analytical_core, source_art, source_art_mix);
	vec4 spread = vec4(star_color * brightness, profile * energy_peak);
	float spread_mix = smoothstep(0.015, 0.34, optical_error);
	// TextureRect input COLOR can already contain source alpha. Multiplying
	// the analytical PSF by it would crop the expanded light back to the
	// original tiny star footprint. source_tint also avoids a second built-in
	// TEXTURE sample, which is unreliable in the Web compatibility renderer.
	COLOR = mix(sharp_response, spread, spread_mix) * psf_tint;
}
"""

# Covers the 436 px field stop plus the full playable drift envelope even
# when a low-power eyepiece zooms the source field out to 0.72x.
const EXTENDED_FIELD_OVERSCAN_SIZE := 1440.0
const STAR_FIELD_PSF_BOX_SIZE := 64.0
const SOLID_BODY_OPTICAL_CANVAS_SCALE := 2.2

const COL_BG := Color(0.004, 0.006, 0.014)
const COL_NAVY := Color(0.030, 0.045, 0.085, 0.96)
const COL_PANEL := Color(0.050, 0.070, 0.120, 0.96)
const COL_GOLD := Color(0.78, 0.56, 0.28)
const COL_GOLD_LIGHT := Color(0.95, 0.76, 0.42)
const COL_BLUE_BORDER := Color(0.17, 0.25, 0.40)
const COL_TEXT := Color(0.96, 0.94, 0.88)
const COL_CROSSHAIR := Color(0.50, 0.70, 0.90, 0.22)

# Large pixel-art sprites shown through the eyepiece.
const SPRITE_MAP := {
	"moon": "res://assets/telescope_view/moon_large.png",
	"mars": "res://assets/telescope_view/mars_large.png",
	"jupiter": "res://assets/telescope_view/jupiter_large.png",
	"polaris": "res://assets/telescope_view/star_white_large.png",
	"sirius": "res://assets/telescope_view/star_blue_large.png",
	"betelgeuse": "res://assets/telescope_view/star_red_large.png",
	"vega": "res://assets/telescope_view/vega_chromatic_demo.png",
	"orion_nebula": "res://assets/telescope_view/orion_nebula_large.png",
	"andromeda": "res://assets/telescope_view/andromeda_large.png",
	"arcturus": "res://assets/telescope_view/arcturus_clear.png",
	"canopus": "res://assets/telescope_view/canopus_clear.png",
	"alpha_centauri": "res://assets/telescope_view/alpha_cen_clear.png",
	"proxima": "res://assets/telescope_view/proxima_clear.png",
	"mercury": "res://assets/telescope_view/expansion/mercury.svg",
	"venus": "res://assets/telescope_view/expansion/venus.svg",
	"saturn": "res://assets/telescope_view/expansion/saturn.svg",
	"uranus": "res://assets/telescope_view/expansion/uranus.svg",
	"neptune": "res://assets/telescope_view/expansion/neptune.svg",
	"moon_crater_copernicus": "res://assets/telescope_view/expansion/moon_crater.svg",
	"moon_mare_tranquillitatis": "res://assets/telescope_view/expansion/moon_mare.svg",
	"moon_terminator": "res://assets/telescope_view/expansion/moon_terminator.svg",
	"albireo": "res://assets/telescope_view/expansion/albireo.svg",
	"pleiades": "res://assets/telescope_view/expansion/pleiades.svg",
	"m13": "res://assets/telescope_view/expansion/m13.svg",
	"ring_nebula": "res://assets/telescope_view/expansion/ring_nebula.svg",
	"lagoon_nebula": "res://assets/telescope_view/expansion/lagoon_nebula.svg",
	"sombrero_galaxy": "res://assets/telescope_view/expansion/sombrero.svg",
	"crab_nebula": "res://assets/telescope_view/temporary/crab_nebula.svg",
	"dumbbell_nebula": "res://assets/telescope_view/temporary/dumbbell_nebula.svg",
	"double_cluster": "res://assets/telescope_view/temporary/double_cluster.svg",
	"whirlpool_galaxy": "res://assets/telescope_view/temporary/whirlpool_galaxy.svg",
	"needle_galaxy": "res://assets/telescope_view/temporary/needle_galaxy.svg"
}

# Per-object state textures: clear (sharp art) / blurry (defocus photo,
# cross-fade overlay) / dim (light shortage). Add an entry here and the
# whole three-state pipeline picks it up automatically.
const STATE_TEXTURES := {
	"jupiter": {
		"clear": "res://assets/telescope_view/jupiter_clear.png",
		"blurry": "res://assets/telescope_view/jupiter_blurry.png",
		"dim": "res://assets/telescope_view/jupiter_dim.png"
	},
	"mars": {
		"clear": "res://assets/telescope_view/mars_clear.png",
		"blurry": "res://assets/telescope_view/mars_blurry.png",
		"dim": "res://assets/telescope_view/mars_dim.png"
	},
	"moon": {
		"clear": "res://assets/telescope_view/moon_clear.png",
		"blurry": "res://assets/telescope_view/moon_blurry.png",
		"dim": "res://assets/telescope_view/moon_dim.png"
	},
	"andromeda": {
		"clear": "res://assets/telescope_view/andromeda_clear.png",
		"blurry": "res://assets/telescope_view/andromeda_blurry.png",
		"dim": "res://assets/telescope_view/andromeda_dim.png"
	},
	"vega": {
		"clear": "res://assets/telescope_view/vega_user_clear.png",
		"blurry": "res://assets/telescope_view/vega_user_blurry.png",
		"dim": "res://assets/telescope_view/vega_user_dim.png"
	},
	"orion_nebula": {
		"clear": "res://assets/telescope_view/orion_nebula_clear.png",
		"blurry": "res://assets/telescope_view/orion_nebula_blurry.png",
		"dim": "res://assets/telescope_view/orion_nebula_dim.png"
	},
	"polaris": {
		"clear": "res://assets/telescope_view/star_white_clear.png",
		"blurry": "res://assets/telescope_view/star_white_blurry.png",
		"dim": "res://assets/telescope_view/star_white_dim.png"
	},
	"sirius": {
		"clear": "res://assets/telescope_view/star_blue_clear.png",
		"blurry": "res://assets/telescope_view/star_blue_blurry.png",
		"dim": "res://assets/telescope_view/star_blue_dim.png"
	},
	"betelgeuse": {
		"clear": "res://assets/telescope_view/star_red_clear.png",
		"blurry": "res://assets/telescope_view/star_red_blurry.png",
		"dim": "res://assets/telescope_view/star_red_dim.png"
	},
	"arcturus": {
		"clear": "res://assets/telescope_view/arcturus_clear.png",
		"blurry": "res://assets/telescope_view/arcturus_blurry.png",
		"dim": "res://assets/telescope_view/arcturus_dim.png"
	},
	"canopus": {
		"clear": "res://assets/telescope_view/canopus_clear.png",
		"blurry": "res://assets/telescope_view/canopus_blurry.png",
		"dim": "res://assets/telescope_view/canopus_dim.png"
	},
	"alpha_centauri": {
		"clear": "res://assets/telescope_view/alpha_cen_clear.png",
		"blurry": "res://assets/telescope_view/alpha_cen_blurry.png",
		"dim": "res://assets/telescope_view/alpha_cen_dim.png"
	},
	"proxima": {
		"clear": "res://assets/telescope_view/proxima_clear.png",
		"blurry": "res://assets/telescope_view/proxima_blurry.png",
		"dim": "res://assets/telescope_view/proxima_dim.png"
	}
}

# Right panel layout (1024x768): everything must stay above y = 700.
const PANEL_POS := Vector2(752, 106)
const PANEL_SIZE := Vector2(236, 594)
const CONTENT_X := 772.0
const CONTENT_W := 194.0
const FOCUS_ADJUST_SPEED := 0.22
const OBS_UI_DIR := "res://assets/ui/observation/suc/processed/"
const Z_MODAL_OVERLAY := 1000
const EYE_RETICLE_TEXTURE := OBS_UI_DIR + "eye_large_center.png"


class ConstellationField extends Control:
	var pattern: Array = []

	func _draw() -> void:
		if pattern.is_empty():
			return
		var area := Rect2(Vector2(120, 105), Vector2(396, 350))
		for star_value in pattern:
			var star: Dictionary = star_value
			var position := area.position + Vector2(float(star.get("x", 0.5)), float(star.get("y", 0.5))) * area.size
			var magnitude := float(star.get("magnitude", 2.0))
			var radius := clampf(5.0 - magnitude * 0.8, 2.0, 4.2)
			draw_circle(position, radius * 2.5, Color(0.58, 0.78, 1.0, 0.15))
			draw_circle(position, radius, Color(0.97, 0.98, 1.0, 0.98))


class AvertedVisionGuide extends Control:
	var target_position := Vector2.ZERO
	var lens_center := Vector2.ZERO
	var lens_radius := 218.0
	var enabled := false
	var active := false
	var confirmed := false
	var adaptation := 0.0
	var hold_visual := 0.0
	var cursor_progress := 0.0
	var phase := 0.0

	func _process(delta: float) -> void:
		if not enabled:
			return
		phase += delta
		queue_redraw()

	func _draw() -> void:
		if not enabled:
			return
		var offset_direction := Vector2(0.84, -0.54)
		# This cue lives in the same lens-space as the drifting target.  Its
		# position is constrained before drawing, rather than being hidden by
		# the barrel overlay that clips the scientific image underneath it.
		var safe_radius := maxf(18.0, lens_radius - 30.0)
		var display_target := target_position
		var target_delta := display_target - lens_center
		if target_delta.length() > safe_radius:
			display_target = lens_center + target_delta.normalized() * safe_radius
		var gaze_position := display_target + offset_direction * 58.0
		var gaze_delta := gaze_position - lens_center
		if gaze_delta.length() > safe_radius:
			gaze_position = lens_center + gaze_delta.normalized() * safe_radius
		var guide_color := Color(0.38, 0.86, 1.0, 0.72)
		if active:
			guide_color = Color(1.0, 0.76, 0.30, 0.94)
		if confirmed:
			guide_color = Color(0.46, 1.0, 0.70, 0.98)
		var start := display_target + offset_direction * 17.0
		var end := gaze_position - offset_direction * 17.0
		for index in range(5):
			var t0 := float(index) / 5.0
			var t1 := minf(1.0, t0 + 0.10)
			var alpha := 0.24 + float(index) * 0.08
			draw_line(start.lerp(end, t0), start.lerp(end, t1), Color(guide_color.r, guide_color.g, guide_color.b, alpha), 1.0)
		var pulse := 1.0 if InteractionFeedback.is_reduced_motion() else 1.0 + sin(phase * 3.4) * 0.08
		var marker_radius := 15.0 * pulse
		draw_arc(gaze_position, marker_radius, 0.0, TAU, 28, guide_color, 1.5)
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(gaze_position + direction * 19.0, gaze_position + direction * 25.0, guide_color, 1.5)
		draw_arc(gaze_position, marker_radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * hold_visual, 32, Color(0.42, 1.0, 0.62, 0.94), 2.0)
		var cursor_position := display_target.lerp(gaze_position, cursor_progress)
		var cursor_radius := lerpf(9.0, 5.0, cursor_progress)
		draw_arc(cursor_position, cursor_radius, 0.0, TAU, 22, Color(0.86, 0.97, 1.0, 0.92), 1.25)
		draw_circle(cursor_position, 1.5, Color(0.86, 0.97, 1.0, 0.92))
		if active:
			for index in range(3):
				var angle := phase * (0.35 + float(index) * 0.08) + float(index) * TAU / 3.0
				var radius := 26.0 + adaptation * 9.0
				draw_circle(display_target + Vector2.RIGHT.rotated(angle) * radius, 1.5, Color(0.50, 1.0, 0.72, 0.46))


var feedback_label: Label
var quality_label: Label
var mission_step_label: Label
var choices_box: VBoxContainer
var identify_title_label: Label
var identify_choice_ids: Array[String] = []
var quiz_brief_overlay: Control
var quiz_brief_dismissed := false
var is_free_observation := false
var free_result_label: Label
var free_quality_label: Label
var mission_return_in_progress := false
var observation: Dictionary
var selected_object: Dictionary

static var _last_correct_choice_index := -1

var observation_mode := "telescope"
var requires_focus := false
var allow_focus_input := true
var focus_value := 0.5
var target_focus_value := 0.5
var focus_tolerance := 0.06
var focus_error := 0.0
var focus_locked := false

var focus_slider: HSlider
var focus_knob_status: TextureRect
var focus_state_label: Label
var focus_pct_label: Label
var updating_slider := false
var focus_guide_panel: Panel
var focus_guide_text: Label
var focus_guide_zone: ColorRect
var focus_guide_active := false
var focus_adjustment_count := 0
var focus_direction_changes := 0
var last_focus_adjust_direction := 0
var best_focus_error := 1.0
var last_focus_improvement_adjustment := 0
var focus_lock_feedback_played := false
var focus_missing_feedback_cooldown := 0.0
var identify_transition_active := false
var stat_bar_fills: Array[ColorRect] = []

var lens_center := Vector2.ZERO
var target_center := Vector2.ZERO
var main_sprite: TextureRect
var ghost_a: TextureRect
var ghost_b: TextureRect
var blur_overlay: TextureRect
var base_alpha := 1.0
var current_sprite_path := ""
var noise_quality := ""
var constellation_field: ConstellationField

# Smoothed display values: inputs are quantized (slider steps, quality
# tiers), so visuals chase their targets each frame instead of snapping.
var visual_focus_error := 0.0
var visual_target_center := Vector2.ZERO
var visual_base_alpha := 1.0
var blur_weight := 0.0
# Final on-screen scale for the target sprites (magnification vs fit cap).
var display_scale := 1.0

# L18 dark adaptation + averted vision (nebula/galaxy targets only). These
# techniques affect the observer's ability to detect low-surface-brightness
# structure, so they feed both the visual treatment and the science result.
const DARK_ADAPTATION_SECONDS := 8.0
const DARK_ADAPTATION_ALPHA_BONUS := 0.10
const AVERTED_VISION_ALPHA_BONUS := 0.10
const AVERTED_VISION_BRIGHTEN := 1.06
const AVERTED_VISION_HOLD_SECONDS := 1.25
const AVERTED_VISION_RELEASE_SECONDS := 0.55
var dark_adaptation := 0.0
var averted_vision_active := false
var averted_hold_visual := 0.0
var averted_vision_hold_seconds := 0.0
var averted_vision_confirmed := false
var averted_vision_success_played := false
var averted_vision_guide: AvertedVisionGuide
var dark_adaptation_label: Label
var averted_vision_label: Label
var exposure_value := 0.5
var active_filter := "none"
var observation_elapsed := 0.0
var technique_reevaluate_timer := 0.0
var technique_status_label: Label
var technique_filter_button: Button
var star_layer_nodes: Array[ColorRect] = []
var star_layer_container: Control
var star_field_psf_shader: Shader
var star_field_psf_materials: Array[ShaderMaterial] = []
var target_star_psf_material: ShaderMaterial
var target_star_psf_ghost_materials: Array[ShaderMaterial] = []

# --- Observation-condition realism (E1): conditions snapshot, all smoothed.
var cond_turbulence := 0.0     # 0-1, atmospheric turbulence (seeing x mag x altitude)
var cond_cloud_atten := 0.0    # 0-1, instantaneous cloud attenuation on the target
var cond_sky_lift := 0.0       # 0-1, background brightening (city 1.0 / suburban 0.5 / dark 0)
var effect_seed := 0.0         # per-observation random phase so breathing/jitter don't sync
var turbulence_material_main: ShaderMaterial
var turbulence_material_blur: ShaderMaterial
var turbulence_material_ghost: ShaderMaterial
var extended_field_environment_shader: Shader
var extended_field_defocus_shader: Shader
var extended_field_materials: Array[ShaderMaterial] = []
var grain_layer: ColorRect
var grain_material: ShaderMaterial
var grain_intensity := 0.0
var target_grain_intensity := 0.0
var cloud_nodes: Array[TextureRect] = []
var cloud_velocities: Array[Vector2] = []
var cloud_strengths: Array[float] = []
var cloud_veil: Panel
var cloud_cover_level := 0.0
var cloud_visual_coverage := 0.0
var cloud_reevaluate_timer := 0.0
const CLOUD_TEXTURES := [
	"res://assets/telescope_view/cloud_wisp_a.png",
	"res://assets/telescope_view/cloud_wisp_b.png",
	"res://assets/telescope_view/cloud_wisp_c.png"
]

# Real-sky background stars (deep HYG catalog, mag <= 8).
const DEEP_STARS_PATH := "res://data/deep_stars.json"
const SCOPE_FOV_RADIUS_DEG := 2.6   # eyepiece circle spans ~5.2 deg of sky
const CATALOG_TARGET_DEDUP_RADIUS_DEG := 0.01
const EYE_FOV_RADIUS_DEG := 24.0    # naked-eye circle spans ~48 deg

# --- Earth-drift and tracking (E2). drift_enabled levels move the target and
# the scope's star field together (the sky is turning); the player fights it
# with WASD/arrows, or a tracking mount cancels it automatically.
# NOTE: Vector2.rotated() is not a constant expression in GDScript 4.7, so
# the drift direction is computed once in _init_drift() instead of const.
var drift_direction := Vector2.RIGHT
const DRIFT_SPEED_BASE := 6.0            # px/s at magnification 35x
const DRIFT_CORRECTION_SPEED := 90.0     # px/s, player nudging the offset back
const DRIFT_OUT_OF_VIEW := 250.0         # px, |offset| beyond this = Failed
const DRIFT_HOLD_RADIUS := 46.0          # px, inside this counts toward hold
var drift_enabled := false
var drift_offset := Vector2.ZERO
var hold_seconds_required := 0.0
var hold_timer := 0.0
var hold_strict := false
var drift_reevaluate_timer := 0.0
var tracking_slider: HSlider
var tracking_knob_status: TextureRect
var tracking_enabled_status: TextureRect
var tracking_label: Label
var hold_label: Label
var hold_bar_fill: ColorRect
var drift_label: Label
var drift_instruction_label: Label
var target_off_center := false
var tracking_feedback_enabled := false
var tracking_feedback_aligned := false
const MANUAL_DRIFT_TUTORIAL_ID := "manual_earth_drift_correction_v2"
const MANUAL_DRIFT_OBSERVE_PX := 10.0
const MANUAL_DRIFT_RECENTER_PX := 6.0
var manual_drift_tutorial_active := false
var manual_drift_tutorial_observed := false
var manual_drift_tutorial_corrected := false
var manual_drift_tutorial_improvement := 0.0


func _ready() -> void:
	GameManager.language_changed.connect(_on_language_changed)
	GameManager.sync_newtonian_installed_equipment()
	selected_object = GameManager.get_object(GameManager.selected_object_id)
	if selected_object.is_empty():
		selected_object = GameManager.current_target()
		GameManager.selected_object_id = str(selected_object.get("id", ""))
	# Free observation: the player is looking at a non-mission object. It shares
	# every optical mechanic but never runs the identify quiz or completes the
	# mission.
	is_free_observation = GameManager.is_free_observation()
	observation_mode = GameManager.current_observation_mode()
	requires_focus = observation_mode == "telescope" and GameManager.current_requires_focus()
	allow_focus_input = _focus_knob_installed()
	_init_drift()
	if requires_focus:
		_init_focus()
	observation = _evaluate()
	_check_mission_step_progress()
	_build()
	InteractionFeedback.page_enter(self)
	call_deferred("_show_focus_tutorial")


func _active_observation_requirements() -> Dictionary:
	if not is_free_observation:
		return GameManager.current_level().get("observation_requirements", {})
	var free_requirements = selected_object.get("free_observation_requirements", {})
	if free_requirements is Dictionary:
		return (free_requirements as Dictionary).duplicate(true)
	return {}


func _show_focus_tutorial() -> void:
	# The object guide is modal. Queue first-use focus/weather/tracking help
	# until it closes so the shared tutorial layer cannot pierce the dialog.
	if quiz_brief_overlay != null and is_instance_valid(quiz_brief_overlay):
		return
	var requirements: Dictionary = _active_observation_requirements()
	if requirements.has("filter") and not InteractionFeedback.was_tutorial_seen("first_nebula_filter"):
		InteractionFeedback.tutorial_highlight_once(
			technique_filter_button,
			"first_nebula_filter",
			GameManager.text(
				"A nebula filter is not an automatic upgrade: it darkens part of the sky glow so emission nebulae stand out. Click FILTER: OFF to switch it to NEBULA before observing.",
				"星云滤镜不是自动加成：它会压暗部分天空背景，让发射星云更容易分辨。观测前点击“滤镜：关闭”，把它切换为“星云”。"
			),
			self
		)
		return
	if _visual_detection_techniques_available() and not InteractionFeedback.was_tutorial_seen("first_averted_vision"):
		var technique_target: Control = averted_vision_guide if averted_vision_guide != null else technique_status_label
		InteractionFeedback.tutorial_highlight_once(
			technique_target,
			"first_averted_vision",
			GameManager.text(
				"Do not stare at the faint object. Hold Shift for 1.25 seconds and keep the target near the side-view marker while you guide the telescope.",
				"不要直盯暗弱天体。按住 Shift 1.25 秒，并让目标保持在侧视标记附近。"
			),
			self
		)
		return
	if manual_drift_tutorial_active and not InteractionFeedback.was_tutorial_seen(MANUAL_DRIFT_TUTORIAL_ID):
		var manual_target: Control = drift_instruction_label if drift_instruction_label != null else drift_label
		InteractionFeedback.tutorial_highlight_once(
			manual_target,
			MANUAL_DRIFT_TUTORIAL_ID,
			GameManager.text(
				"Earth's rotation is carrying Sirius across the eyepiece. Watch it drift, then use short A/D corrections to bring it back and hold it near the center.",
				"地球自转正在让天狼星滑过目镜。先看它自行漂移，再短按 A/D 把它拉回并保持在中心附近。"
			),
			self
		)
		return
	if drift_enabled and not InteractionFeedback.was_tutorial_seen("first_earth_drift"):
		var drift_target: Control = tracking_slider if tracking_slider != null else drift_label
		InteractionFeedback.tutorial_highlight_once(drift_target, "first_earth_drift", GameManager.text(
			"Earth rotation makes the target drift. Use A/D or the arrow keys to recenter it by hand, or tune a tracking mount near 1.0x.",
			"地球自转会让目标漂移。用 A/D 或方向键手动拉回中心；装有追踪支架时，也可以把速率调到接近 1.0 倍。"
		), self)
		return
	if cloud_cover_level > 0.0 and not InteractionFeedback.was_tutorial_seen("first_scope_cloud"):
		InteractionFeedback.tutorial_highlight_once(quality_label, "first_scope_cloud", GameManager.text(
			"Cloud attenuation changes continuously. Focus cannot remove cloud cover.",
			"云层遮挡会连续变化，调焦不能消除云层。"
		), self)
		return
	InteractionFeedback.tutorial_highlight_once(
		focus_slider,
		"first_focus_control",
		GameManager.text("Turn the focus control until the image becomes sharp.", "调整调焦旋钮，直到图像变得清晰。"),
		self
	)


func _init_drift() -> void:
	var level := GameManager.current_level()
	drift_enabled = observation_mode == "telescope" and bool(level.get("drift_enabled", false))
	hold_seconds_required = float(level.get("hold_seconds", 0.0)) if drift_enabled else 0.0
	hold_strict = drift_enabled and bool(level.get("hold_strict", false))
	drift_offset = Vector2.ZERO
	drift_direction = Vector2.RIGHT.rotated(0.08)
	hold_timer = 0.0
	target_off_center = false
	manual_drift_tutorial_active = (
		drift_enabled
		and bool(level.get("teach_manual_drift_correction", false))
		and GameManager.allows_tutorial_hints()
		and not _has_seen_teaching_step(MANUAL_DRIFT_TUTORIAL_ID)
	)
	manual_drift_tutorial_observed = false
	manual_drift_tutorial_corrected = not manual_drift_tutorial_active
	manual_drift_tutorial_improvement = 0.0


func _has_seen_teaching_step(step_id: String) -> bool:
	var seen_value = GameManager.progress.get("seen_teaching_steps", [])
	return seen_value is Array and (seen_value as Array).has(step_id)


func _complete_manual_drift_tutorial() -> void:
	if manual_drift_tutorial_corrected:
		return
	manual_drift_tutorial_corrected = true
	manual_drift_tutorial_active = false
	var seen: Array = GameManager.progress.get("seen_teaching_steps", [])
	if not seen.has(MANUAL_DRIFT_TUTORIAL_ID):
		seen.append(MANUAL_DRIFT_TUTORIAL_ID)
		GameManager.progress["seen_teaching_steps"] = seen
		GameManager.save()
	if drift_instruction_label != null:
		InteractionFeedback.success(drift_instruction_label, "manual_drift_corrected")


func _focus_knob_installed() -> bool:
	return GameManager.focus_control_installed()


func _focus_control_score() -> float:
	var stats: Dictionary = GameManager.calculate_stats()
	return float(stats.get("focus_control_score", 0.0))


func _is_dark_adaptation_target() -> bool:
	if not requires_focus:
		return false
	var requirements: Dictionary = _active_observation_requirements()
	return _is_diffuse_target() or requirements.has("dark_adaptation_min")


func _visual_detection_techniques_available() -> bool:
	if not requires_focus or not _is_visual_detection_target():
		return false
	var requirements := _active_observation_requirements()
	if requirements.has("dark_adaptation_min") or bool(requirements.get("require_averted_vision", false)):
		return true
	# Level 18 explicitly teaches these observer techniques. Earlier aperture
	# lessons must not be bypassed by a bonus the player has not learned yet.
	var current_number := int(GameManager.current_level().get(
		"level_number",
		GameManager.progress.get("current_level", 1)
	))
	if current_number >= 18:
		return true
	var completed: Array = GameManager.progress.get("completed_levels", [])
	return completed.has(18) or completed.has("18")


func _is_visual_detection_target() -> bool:
	if _is_diffuse_target():
		return true
	# M13 is catalogued as a star cluster, not a nebula or galaxy.  When a
	# mission explicitly asks for peripheral vision on its faint grainy halo,
	# it uses the exact same Shift hold, guide, and evaluation route as a galaxy.
	return _is_cluster_target() and bool(
		_active_observation_requirements().get("require_averted_vision", false)
	)


# ------------------------------------------------------- object-type dispatch


func _is_star_target() -> bool:
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("star")


func _is_diffuse_target() -> bool:
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	var visual_profile := str(selected_object.get("visual_profile", "")).to_lower()
	return (
		type_lower.contains("nebula")
		or type_lower.contains("galaxy")
		or type_lower.contains("supernova remnant")
		or visual_profile == "supernova_remnant"
	)


func _is_cluster_target() -> bool:
	var object_id := str(selected_object.get("id", ""))
	var type_lower := str(selected_object.get("type_en", "")).to_lower()
	return type_lower.contains("cluster") or object_id in ["pleiades", "m13", "double_cluster"]


func _is_emission_nebula_target() -> bool:
	var object_id := str(selected_object.get("id", ""))
	return object_id in [
		"orion_nebula",
		"ring_nebula",
		"lagoon_nebula",
		"dumbbell_nebula",
	]


func _collimation_severity() -> float:
	if observation_mode != "telescope" or not bool(GameManager.current_level().get("requires_collimation", false)):
		return 0.0
	# Residual error at the normal acceptance threshold remains visible but
	# modest; badly tilted mirrors quickly reach the full coma treatment.
	return clampf((100.0 - GameManager.collimation_score()) / 50.0, 0.0, 1.0)


func _collimation_direction() -> Vector2:
	# Existing saves retain only alignment magnitude. Use a stable per-target
	# direction so the aberration never flips while the player is observing.
	var seed := absi(str(selected_object.get("id", "star")).hash())
	return Vector2.from_angle(deg_to_rad(fmod(float(seed), 360.0)))


# --------------------------------------------------------- conditions snapshot


func _seeing_severity() -> float:
	var environment: Dictionary = GameManager.current_environment()
	if environment.is_empty():
		return 0.06
	var seeing_label := str(observation.get("seeing_label", "Good"))
	match seeing_label:
		"Poor":
			return 0.8
		"Average":
			return 0.35
	return 0.06


func _current_altitude() -> float:
	var aim: Dictionary = GameManager.last_sky_aim
	if bool(aim.get("valid", false)):
		return float(aim.get("altitude", 45.0))
	return 45.0


func _target_turbulence() -> float:
	var stats := GameManager.calculate_stats()
	var magnification := float(stats.get("magnification", 0.0))
	var severity := _seeing_severity()
	var mag_factor := clampf(magnification / 55.0, 0.4, 1.6)
	var altitude_factor := clampf(1.6 - _current_altitude() / 60.0, 0.7, 1.3)
	var turbulence := clampf(severity * mag_factor * altitude_factor, 0.0, 1.0)
	if _is_star_target():
		# The atmosphere is never perfectly still: a point source always
		# scintillates at the eyepiece, even under "good" seeing.
		turbulence = maxf(turbulence, 0.16)
	return turbulence


func _target_sky_lift() -> float:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	match sky_key:
		"city":
			return 1.0
		"suburban":
			return 0.5
	return 0.0


func _light_pollution_profile() -> Dictionary:
	var sky_key := str(GameManager.current_environment().get("sky_brightness", "dark")).to_lower()
	match sky_key:
		"city":
			return {
				"sky_lift": 1.0,
				"faint_suppression": 0.82,
				"contrast_loss": 0.72,
				"desaturation": 0.32,
			}
		"suburban":
			return {
				"sky_lift": 0.48,
				"faint_suppression": 0.42,
				"contrast_loss": 0.34,
				"desaturation": 0.14,
			}
	return {
		"sky_lift": 0.0,
		"faint_suppression": 0.0,
		"contrast_loss": 0.0,
		"desaturation": 0.0,
	}


func _apply_extended_field_environment() -> void:
	if extended_field_materials.is_empty():
		return
	var profile := _light_pollution_profile()
	var filter_gain := 0.0
	var sky_lift_multiplier := 1.0
	if active_filter == "nebula" and _is_emission_nebula_target():
		filter_gain = 1.0
		# A nebula filter suppresses part of the artificial sky background; it
		# does not remove the site penalty or brighten galaxies and clusters.
		sky_lift_multiplier = 0.78
		profile["faint_suppression"] = float(profile["faint_suppression"]) * 0.82
		profile["contrast_loss"] = float(profile["contrast_loss"]) * 0.78
	var cluster_mode := 1.0 if _is_cluster_target() else 0.0
	for material in extended_field_materials:
		if material == null:
			continue
		material.set_shader_parameter("sky_lift", cond_sky_lift * sky_lift_multiplier)
		material.set_shader_parameter("faint_suppression", float(profile["faint_suppression"]))
		material.set_shader_parameter("contrast_loss", float(profile["contrast_loss"]))
		material.set_shader_parameter("desaturation", float(profile["desaturation"]))
		material.set_shader_parameter("emission_filter_gain", filter_gain)
		material.set_shader_parameter("cluster_mode", cluster_mode)
		material.set_shader_parameter("seeing_strength", cond_turbulence if cluster_mode > 0.5 else 0.0)


func _cloud_cover() -> float:
	var environment: Dictionary = GameManager.current_environment()
	return clampf(float(environment.get("cloud_cover", 0.0)), 0.0, 1.0)


func _cloud_tier_label() -> Dictionary:
	# UI + numeric agreement: Clear / Thin / Moderate / Heavy.
	var cover := cloud_cover_level
	if cover <= 0.0:
		return {"en": "Clear", "zh": "晴朗"}
	if cover < 0.34:
		return {"en": "Thin", "zh": "薄云"}
	if cover < 0.67:
		return {"en": "Moderate", "zh": "中云"}
	return {"en": "Heavy", "zh": "厚云"}


func _sky_tier_label() -> Dictionary:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	match sky_key:
		"city":
			return {"en": "City", "zh": "城市"}
		"suburban":
			return {"en": "Suburban", "zh": "郊区"}
	return {"en": "Dark", "zh": "暗夜"}


func _contrast_label() -> Dictionary:
	var environment: Dictionary = GameManager.current_environment()
	var sky_key := str(environment.get("sky_brightness", "")).to_lower()
	var rank := 2  # 0=Low 1=Medium 2=High
	match sky_key:
		"city":
			rank = 0
		"suburban":
			rank = 1
	if cloud_tier_index() >= 2:  # Moderate or Heavy
		rank = maxi(rank - 1, 0)
	match rank:
		0:
			return {"en": "Low", "zh": "低"}
		1:
			return {"en": "Medium", "zh": "中"}
	return {"en": "High", "zh": "高"}


func cloud_tier_index() -> int:
	var cover := cloud_cover_level
	if cover <= 0.0:
		return 0
	if cover < 0.34:
		return 1
	if cover < 0.67:
		return 2
	return 3


func _process(delta: float) -> void:
	observation_elapsed += delta
	technique_reevaluate_timer += delta
	focus_missing_feedback_cooldown = maxf(0.0, focus_missing_feedback_cooldown - delta)
	if _is_dark_adaptation_target():
		_advance_dark_adaptation(delta)
		_update_averted_vision_guide(delta)
	if technique_reevaluate_timer >= 0.25 and (
		not _active_observation_requirements().is_empty()
		or _visual_detection_techniques_available()
	):
		technique_reevaluate_timer = 0.0
		observation = _evaluate()
		_refresh_target_sprite()
		_refresh_focus_ui()
		_refresh_technique_status()
	if requires_focus or drift_enabled:
		# The chase also repositions the target sprite: on drift levels it
		# must run even without focus, or the star field slides while the
		# target itself stays frozen.
		_advance_visual_smoothing(delta)
	if observation_mode != "naked_eye" and not _is_constellation_observation():
		_advance_conditions(delta)
	if drift_enabled:
		_advance_drift(delta)
	_handle_focus_input(delta)


func _handle_focus_input(delta: float) -> void:
	if not requires_focus or focus_locked or quiz_brief_overlay != null:
		return
	var direction := 0.0
	if Input.is_key_pressed(KEY_Q):
		direction -= 1.0
	if Input.is_key_pressed(KEY_E):
		direction += 1.0
	if not drift_enabled:
		# Non-drift levels keep A/D and move_left/move_right as focus aliases
		# (unchanged behavior).
		if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
			direction -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
			direction += 1.0
	# Mobile focus nudge buttons feed the same continuous adjustment path.
	if TouchInput.is_mobile():
		direction = clampf(direction + TouchInput.focus_direction, -1.0, 1.0)
	if direction == 0.0:
		return
	if not allow_focus_input:
		if focus_missing_feedback_cooldown <= 0.0:
			focus_missing_feedback_cooldown = 0.7
			feedback_label.text = GameManager.text("Focus knob required. Install it at the Assembly Table.", "需要调焦旋钮。请先在组装台安装。")
			InteractionFeedback.error(focus_state_label if focus_state_label != null else feedback_label)
		return
	_set_focus_value(clampf(focus_value + direction * FOCUS_ADJUST_SPEED * delta, 0.0, 1.0))


func _advance_drift(delta: float) -> void:
	# The sky turns; drift_offset accumulates the apparent motion. Q/E stay
	# focus-only on drift levels (see _handle_focus_input) - WASD / arrow
	# keys become the centering correction instead.
	var magnification := float(GameManager.calculate_stats().get("magnification", 0.0))
	var mag_factor := magnification / 35.0 if magnification > 0.0 else 1.0
	var tracking_cancel := 0.0
	if GameManager.has_tracking_mount_equipped():
		tracking_cancel = GameManager.tracking_rate()
	var drift_speed := DRIFT_SPEED_BASE * mag_factor * (1.0 - tracking_cancel)
	# Shift changes the observer's gaze, not the telescope drive. Earth drift,
	# tracking compensation, keyboard correction, and the touch stick all keep
	# running while averted vision is held.
	drift_offset += drift_direction * drift_speed * delta
	if manual_drift_tutorial_active and drift_offset.length() >= MANUAL_DRIFT_OBSERVE_PX:
		manual_drift_tutorial_observed = true

	var correction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("move_left"):
		correction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("move_right"):
		correction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("move_up"):
		correction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("move_down"):
		correction.y += 1.0
	# Mobile: the virtual joystick doubles as the drift-correction stick.
	if correction == Vector2.ZERO:
		correction = TouchInput.move_vector()
	if correction != Vector2.ZERO:
		var distance_before_correction := drift_offset.length()
		drift_offset -= correction.normalized() * DRIFT_CORRECTION_SPEED * delta
		if manual_drift_tutorial_active and manual_drift_tutorial_observed:
			var improvement := distance_before_correction - drift_offset.length()
			if improvement > 0.0:
				manual_drift_tutorial_improvement += improvement
				if (
					manual_drift_tutorial_improvement >= MANUAL_DRIFT_RECENTER_PX
					and drift_offset.length() < DRIFT_HOLD_RADIUS
				):
					_complete_manual_drift_tutorial()

	# Past 300px the target is long lost (off-view Failed hits at 250) -
	# clamping keeps the sprite within the ring occluder's 900px cover and
	# spares the player an endless walk back.
	if drift_offset.length() > 300.0:
		drift_offset = drift_offset.normalized() * 300.0

	_apply_drift_offset()
	_advance_hold(delta)
	_refresh_drift_ui()

	if cloud_cover_level <= 0.0:
		# Cloud levels already re-evaluate on their own 0.6s timer; drift-only
		# levels need their own re-evaluate cadence so target_off_center /
		# hold-gated quality stays current without spamming every frame.
		drift_reevaluate_timer += delta
		if drift_reevaluate_timer >= 0.3:
			drift_reevaluate_timer = 0.0
			observation = _evaluate()
			_refresh_focus_ui()


func _apply_drift_offset() -> void:
	# Target and star field move together - "the sky is turning", not the
	# telescope. target_center just gets the new offset baked in directly;
	# the existing _advance_visual_smoothing() exponential chase (E1) is what
	# turns this into smooth on-screen motion, same as every other visual
	# target change - no separate drift-specific smoothing needed.
	target_off_center = drift_offset.length() > DRIFT_OUT_OF_VIEW
	if star_layer_container != null:
		star_layer_container.position = drift_offset
	var effect := str(observation.get("visual_effect", "clear"))
	var quality := str(observation.get("quality", "Unknown"))
	target_center = lens_center + _effect_offset(effect, quality) + drift_offset


func _advance_hold(delta: float) -> void:
	if hold_seconds_required <= 0.0:
		return
	if drift_offset.length() < DRIFT_HOLD_RADIUS:
		hold_timer = minf(hold_timer + delta, hold_seconds_required)
	elif hold_strict:
		# L24: drifting out of the hold radius actively drains progress
		# (2x delta) instead of just pausing.
		hold_timer = maxf(hold_timer - delta * 2.0, 0.0)
	# Loose mode (default): pauses outside the radius, does not reset.


func is_hold_satisfied() -> bool:
	if hold_seconds_required <= 0.0:
		return true
	return hold_timer >= hold_seconds_required


func _hold_progress_text() -> String:
	return GameManager.text(
		"Hold it steady a little longer: %.1f / %.1fs" % [hold_timer, hold_seconds_required],
		"再稳住 %.1f / %.1f 秒" % [hold_timer, hold_seconds_required]
	)


func _advance_dark_adaptation(delta: float) -> void:
	var moving := false
	if dark_adaptation < 1.0:
		dark_adaptation = clampf(dark_adaptation + delta / DARK_ADAPTATION_SECONDS, 0.0, 1.0)
		moving = true
	var input_held := _averted_vision_input_held()
	if input_held != averted_vision_active:
		averted_vision_active = input_held
		moving = true
	if moving:
		var eased := _eased_dark_adaptation()
		for star_rect in star_layer_nodes:
			star_rect.modulate.a = lerpf(1.0, 0.55, eased)
		if averted_vision_label != null:
			_refresh_averted_vision_label()
		_update_target_visuals()
	_refresh_dark_adaptation_label()


func _refresh_dark_adaptation_label() -> void:
	if dark_adaptation_label == null:
		return
	if dark_adaptation >= 0.999:
		dark_adaptation_label.text = GameManager.text(
			"Dark 100% · effective",
			"暗适应 100% · 生效"
		)
	else:
		dark_adaptation_label.text = GameManager.text(
			"Dark %d%%",
			"暗适应 %d%%"
		) % int(round(_eased_dark_adaptation() * 100.0))


func _averted_vision_input_held() -> bool:
	return (
		Input.is_action_pressed("dodge")
		or Input.is_key_pressed(KEY_SHIFT)
		or bool(TouchInput.boost_held)
	)


func _update_averted_vision_guide(delta: float) -> void:
	if not _visual_detection_techniques_available():
		return
	var was_confirmed := averted_vision_confirmed
	var target_stable := not drift_enabled or drift_offset.length() <= DRIFT_HOLD_RADIUS
	if averted_vision_active and target_stable:
		averted_vision_hold_seconds = minf(
			averted_vision_hold_seconds + delta,
			AVERTED_VISION_HOLD_SECONDS
		)
		if averted_vision_hold_seconds >= AVERTED_VISION_HOLD_SECONDS - 0.001:
			averted_vision_confirmed = true
			if not averted_vision_success_played:
				averted_vision_success_played = true
				InteractionFeedback.success(
					technique_status_label if technique_status_label != null else averted_vision_label,
					"averted_vision_confirmed"
				)
	else:
		averted_vision_hold_seconds = maxf(
			0.0,
			averted_vision_hold_seconds - delta * AVERTED_VISION_HOLD_SECONDS / AVERTED_VISION_RELEASE_SECONDS
		)
		if averted_vision_hold_seconds <= 0.001:
			averted_vision_confirmed = false
			averted_vision_success_played = false
	averted_hold_visual = clampf(
		averted_vision_hold_seconds / AVERTED_VISION_HOLD_SECONDS,
		0.0,
		1.0
	)
	if averted_vision_guide != null:
		averted_vision_guide.enabled = true
		averted_vision_guide.active = averted_vision_active
		averted_vision_guide.confirmed = averted_vision_confirmed
		averted_vision_guide.adaptation = _eased_dark_adaptation()
		averted_vision_guide.hold_visual = averted_hold_visual
		averted_vision_guide.cursor_progress = move_toward(
			averted_vision_guide.cursor_progress,
			1.0 if averted_vision_active else 0.0,
			delta * (2.4 if averted_vision_active else 3.2)
		)
		averted_vision_guide.target_position = visual_target_center
		averted_vision_guide.queue_redraw()
	_refresh_averted_vision_label()
	if was_confirmed != averted_vision_confirmed:
		observation = _evaluate()
	_refresh_technique_status()


func _refresh_averted_vision_label() -> void:
	if averted_vision_label == null:
		return
	if averted_vision_confirmed:
		averted_vision_label.text = GameManager.text(
			"Averted · confirmed",
			"偏视法 · 已确认"
		)
		averted_vision_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
	elif averted_vision_active:
		if drift_enabled and drift_offset.length() > DRIFT_HOLD_RADIUS:
			averted_vision_label.text = GameManager.text("Center target first", "请先让目标居中")
		else:
			averted_vision_label.text = GameManager.text(
				"Averted: %d%%" % roundi(averted_hold_visual * 100.0),
				"偏视保持：%d%%" % roundi(averted_hold_visual * 100.0)
			)
		averted_vision_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	else:
		averted_vision_label.text = GameManager.text("Averted · ready", "偏视法 · 待操作")
		averted_vision_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.80))


func _eased_dark_adaptation() -> float:
	# Non-linear ease: adaptation feels slow to start, then catches up
	# (spec: ease(dark_adaptation, 0.6)).
	return pow(dark_adaptation, 0.6)


func _dark_adaptation_alpha_bonus() -> float:
	if not _is_dark_adaptation_target():
		return 0.0
	var bonus := DARK_ADAPTATION_ALPHA_BONUS * _eased_dark_adaptation()
	if averted_vision_active:
		# Averted vision (spec): contour boost via alpha, not a flat add-on.
		bonus += AVERTED_VISION_ALPHA_BONUS
	return bonus


func _advance_visual_smoothing(delta: float) -> void:
	# Exponential chase toward the current targets - frame-rate independent.
	var weight := 1.0 - exp(-10.0 * delta)
	var target_blur := _target_blur_weight()
	var moving := false
	# SHARPNESS (focus_error + blur_weight) follows focus DIRECTLY, no lag.
	# focus_error is already a continuous, finely-quantized input (slider
	# step 0.005); smoothing it only added a lag that read as "blurry while
	# dragging, sharp once you release" regardless of the actual focus. Only
	# the quality-driven quantities below (position offset, brightness tier)
	# still ease, since those DO step discretely between quality tiers.
	if visual_focus_error != focus_error:
		visual_focus_error = focus_error
		moving = true
	if blur_weight != target_blur:
		blur_weight = target_blur
		moving = true
	if visual_target_center.distance_to(target_center) > 0.25:
		visual_target_center = visual_target_center.lerp(target_center, weight)
		moving = true
	elif visual_target_center != target_center:
		visual_target_center = target_center
		moving = true
	if absf(visual_base_alpha - base_alpha) > 0.004:
		visual_base_alpha = lerpf(visual_base_alpha, base_alpha, weight)
		moving = true
	elif visual_base_alpha != base_alpha:
		visual_base_alpha = base_alpha
		moving = true
	if moving:
		_update_target_visuals()


func _target_blur_weight() -> float:
	# 0 = fully sharp art, 1 = fully blurry photo. This is deliberately
	# driven by focus only: a faint Fair-quality nebula can still be in focus.
	# Telescope quality affects brightness and contrast elsewhere, never which
	# focus texture is visible.
	return _optical_defocus_amount()


func _optical_defocus_amount() -> float:
	# Every object in the eyepiece and the catalog star field are effectively
	# at infinity. Their focus response must come from one optical value, never
	# from whether a target happens to create a same-source blur overlay.
	if not requires_focus or observation_mode == "naked_eye":
		return 0.0
	# Keep the success tolerance forgiving, but do not make that whole range
	# visually identical. The image now improves continuously all the way to
	# the true focal plane; at the edge of the accepted zone a small residual
	# blur remains, while exact focus is fully sharp.
	if focus_error <= focus_tolerance:
		return smoothstep(0.0, focus_tolerance, focus_error) * 0.22
	return 0.22 + smoothstep(focus_tolerance, focus_tolerance * 2.8, focus_error) * 0.78


func _advance_conditions(delta: float) -> void:
	# Conditions snapshot: chase targets exponentially, same pattern as
	# _advance_visual_smoothing, so nothing ever hard-cuts.
	var weight := 1.0 - exp(-6.0 * delta)
	var t := Time.get_ticks_msec() / 1000.0
	var moving := false
	var target_turb := _target_turbulence()
	if absf(cond_turbulence - target_turb) > 0.002:
		cond_turbulence = lerpf(cond_turbulence, target_turb, weight)
		moving = true
	elif cond_turbulence != target_turb:
		cond_turbulence = target_turb
		moving = true
	var target_lift := _target_sky_lift()
	if absf(cond_sky_lift - target_lift) > 0.002:
		cond_sky_lift = lerpf(cond_sky_lift, target_lift, weight)
		moving = true
	elif cond_sky_lift != target_lift:
		cond_sky_lift = target_lift
		moving = true
	_advance_clouds(delta)
	if absf(cond_cloud_atten - _cloud_target_atten()) > 0.002:
		cond_cloud_atten = lerpf(cond_cloud_atten, _cloud_target_atten(), weight)
		moving = true
	if cloud_veil != null:
		# Dark absorption veil: the thicker the cloud over the target, the
		# darker the whole field. Attenuation stays the score's source of truth.
		cloud_veil.modulate.a = clampf(cond_cloud_atten * 0.50 + cloud_cover_level * 0.10, 0.0, 0.62)
	if absf(grain_intensity - target_grain_intensity) > 0.001:
		grain_intensity = lerpf(grain_intensity, target_grain_intensity, weight)
		if grain_material != null:
			grain_material.set_shader_parameter("intensity", grain_intensity)
	if moving:
		_apply_turbulence_uniforms()
		_apply_breathing_and_jitter(t)
		_apply_star_twinkle(t)
	elif cond_turbulence > 0.001:
		# Even when converged, the low-frequency breathing/jitter/twinkle
		# keeps animating every frame (that IS the effect).
		_apply_breathing_and_jitter(t)
		_apply_star_twinkle(t)
	if cloud_cover_level > 0.0:
		cloud_reevaluate_timer += delta
		if cloud_reevaluate_timer >= 0.6:
			cloud_reevaluate_timer = 0.0
			observation = _evaluate()
			_refresh_target_sprite()
			# Full focus-panel refresh (quality label included): on cloudy
			# DRIFT levels this is the only steady refresh path - the 0.3s
			# drift cadence is gated to cloudless levels - so without it the
			# hold/ready status under the focus slider only updated while a
			# focus key was held.
			_refresh_focus_ui()


func _apply_turbulence_uniforms() -> void:
	if turbulence_material_main != null:
		turbulence_material_main.set_shader_parameter("turbulence", cond_turbulence)
	if turbulence_material_blur != null:
		turbulence_material_blur.set_shader_parameter("turbulence", cond_turbulence)
	if turbulence_material_ghost != null:
		turbulence_material_ghost.set_shader_parameter("turbulence", cond_turbulence)
	if target_star_psf_material != null:
		target_star_psf_material.set_shader_parameter("defocus", _optical_defocus_amount())
		target_star_psf_material.set_shader_parameter("seeing", cond_turbulence)
	for material in target_star_psf_ghost_materials:
		material.set_shader_parameter("defocus", _optical_defocus_amount())
		material.set_shader_parameter("seeing", cond_turbulence)
	_apply_extended_field_environment()
	_update_star_field_optics()


func _apply_breathing_and_jitter(t: float) -> void:
	if cond_turbulence <= 0.001 or main_sprite == null:
		return
	var cloud_mult := _cloud_alpha_multiplier()
	if _is_star_target():
		# Stars: flicker via alpha, tiny position jitter, no UV shader.
		var flicker := 0.875 + 0.125 * sin(t * (2.2 + cond_turbulence * 3.0) + effect_seed)
		main_sprite.modulate.a = visual_base_alpha * flicker * cloud_mult
		var jitter := Vector2(
			sin(t * 3.7 + effect_seed) * cond_turbulence * 2.5,
			cos(t * 2.9 + effect_seed * 1.3) * cond_turbulence * 2.5
		)
		main_sprite.position = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
		_sync_target_star_psf_tints()
	elif _is_cluster_target():
		# A star cluster is not one elastic object. Keep the field registration
		# fixed while the material suppresses faint members, expands their PSFs
		# and gives individual bright stars a restrained scintillation.
		var cluster_alpha := visual_base_alpha * cloud_mult
		var seeing_blur := cond_turbulence * 0.30
		var combined_blur := clampf(blur_weight + seeing_blur, 0.0, 1.0)
		main_sprite.position = visual_target_center - main_sprite.size * display_scale * 0.5
		if blur_overlay != null:
			blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5
			main_sprite.modulate.a = cluster_alpha * (1.0 - combined_blur)
			blur_overlay.modulate.a = cluster_alpha * combined_blur
		else:
			main_sprite.modulate.a = cluster_alpha
		_apply_extended_field_environment()
	elif _is_diffuse_target():
		# Nebula/galaxy: low-frequency contrast + blur breathing and a tiny
		# image wander. Extended targets should not ripple like planets, but
		# average/poor seeing must still be visibly different from still air.
		# Keep the focus cross-fade intact here. Previously this branch restored
		# the clear base art to full opacity every frame, so a defocused nebula
		# could look sharp as soon as the focus input stopped moving.
		var breathe := 1.0 + 0.05 * cond_turbulence * sin(t * 1.1 + effect_seed)
		var diffuse_alpha := clampf(visual_base_alpha * breathe * cloud_mult, 0.0, 1.0)
		var seeing_blur := cond_turbulence * 0.16 * (0.5 + 0.5 * sin(t * 1.35 + effect_seed * 0.8))
		var combined_blur := clampf(blur_weight + seeing_blur, 0.0, 1.0)
		var jitter := Vector2(
			sin(t * 1.7 + effect_seed) * cond_turbulence * 1.8,
			cos(t * 1.3 + effect_seed * 0.6) * cond_turbulence * 1.2
		)
		main_sprite.position = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
		if blur_overlay != null:
			blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5 + jitter
			main_sprite.modulate.a = diffuse_alpha * (1.0 - combined_blur)
			blur_overlay.modulate.a = diffuse_alpha * combined_blur
		else:
			main_sprite.modulate.a = diffuse_alpha
	else:
		# Planet/Moon: shader-driven UV wobble + breathing blur + jitter.
		var breathing := cond_turbulence * 0.18 * (0.5 + 0.5 * sin(t * 1.3 + effect_seed))
		var jitter_scale: float = cond_turbulence * (1.2 if str(selected_object.get("id", "")) == "moon" else 2.5)
		var jitter := Vector2(
			sin(t * 2.6 + effect_seed) * jitter_scale,
			cos(t * 1.9 + effect_seed * 0.7) * jitter_scale * 0.6
		)
		var origin: Vector2 = visual_target_center - main_sprite.size * display_scale * 0.5 + jitter
		main_sprite.position = origin
		if _is_solid_body_target() and observation_mode != "naked_eye":
			# A cloud removes photons, not planetary opacity. Keep the body
			# opaque and drive dimming/softening through RGB so background stars
			# can never shine through a planet or the Moon.
			main_sprite.modulate.a = 1.0
			if blur_overlay != null:
				blur_overlay.modulate.a = 0.0
			if turbulence_material_main != null:
				var solid_amount := clampf(blur_weight + breathing, 0.0, 1.0)
				var solid_blur := _solid_body_defocus_texture_radius(solid_amount)
				turbulence_material_main.set_shader_parameter("blur_radius_px", solid_blur)
				turbulence_material_main.set_shader_parameter("defocus_amount", solid_amount)
				turbulence_material_main.set_shader_parameter(
					"brightness",
					_solid_body_brightness(
						str(observation.get("quality", "Unknown")),
						str(observation.get("visual_effect", "clear"))
					) * _solid_body_defocus_brightness(solid_amount)
				)
		elif blur_overlay != null:
			blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5 + jitter
			blur_overlay.modulate.a = visual_base_alpha * clampf(blur_weight + breathing, 0.0, 1.0) * cloud_mult
			main_sprite.modulate.a = visual_base_alpha * (1.0 - clampf(blur_weight + breathing, 0.0, 1.0) * 0.85) * cloud_mult


func _apply_star_twinkle(t: float) -> void:
	# Background scope stars twinkle a little too, scaled by seeing severity.
	var severity := _seeing_severity()
	var base_a := lerpf(1.0, 0.55, _eased_dark_adaptation())
	for i in range(star_layer_nodes.size()):
		var star_rect := star_layer_nodes[i]
		var twinkle := 1.0 + 0.18 * severity * sin(t * (1.5 + fmod(float(i), 5.0) * 0.3) + float(i))
		star_rect.modulate.a = clampf(base_a * twinkle, 0.0, 1.0)


func _update_star_field_optics() -> void:
	# Catalog stars and the selected target are effectively at the same
	# infinity focus. Reticle/UI nodes are separate, so only photons inside the
	# eyepiece receive this PSF response.
	var field_defocus := _optical_defocus_amount()
	var field_seeing := _seeing_severity() if observation_mode != "naked_eye" else 0.0
	for material in star_field_psf_materials:
		material.set_shader_parameter("defocus", field_defocus)
		material.set_shader_parameter("seeing", field_seeing)


func _cloud_target_atten() -> float:
	if cloud_nodes.is_empty():
		cloud_visual_coverage = 0.0
		return 0.0
	if not _is_extended_target():
		cloud_visual_coverage = _cloud_at_point(target_center)
		return cloud_visual_coverage
	# Extended nebulae, galaxies and clusters cover a measurable part of the
	# eyepiece. Sample their main structure instead of pretending all their
	# photons originate at one center pixel. The same coverage drives both
	# the image response and ObservationSystem's score.
	var offsets := [
		Vector2.ZERO,
		Vector2(108, 0), Vector2(-108, 0),
		Vector2(0, 108), Vector2(0, -108),
		Vector2(76, 76), Vector2(-76, 76),
		Vector2(76, -76), Vector2(-76, -76),
	]
	var weights := [0.20, 0.12, 0.12, 0.12, 0.12, 0.08, 0.08, 0.08, 0.08]
	var total := 0.0
	for i in range(offsets.size()):
		total += _cloud_at_point(target_center + offsets[i]) * weights[i]
	cloud_visual_coverage = clampf(total, 0.0, 1.0)
	return cloud_visual_coverage


func _cloud_at_point(sample_position: Vector2) -> float:
	var total := 0.0
	for i in range(cloud_nodes.size()):
		var cloud := cloud_nodes[i]
		var cloud_center: Vector2 = cloud.position + cloud.size * 0.5
		var sample_radius := maxf(cloud.size.x, cloud.size.y) * 0.45 + 44.0
		var d := cloud_center.distance_to(sample_position)
		var falloff := clampf(1.0 - d / maxf(sample_radius, 1.0), 0.0, 1.0)
		total += falloff * cloud_strengths[i]
	return clampf(total, 0.0, 1.0)


func _advance_clouds(delta: float) -> void:
	if cloud_nodes.is_empty():
		return
	for i in range(cloud_nodes.size()):
		var cloud := cloud_nodes[i]
		cloud.position += cloud_velocities[i] * delta
		# Recycle once fully outside the scope circle (diameter ~436, radius
		# 218 around lens_center) - re-enter from the opposite side.
		var c := cloud.position + cloud.size * 0.5
		if c.distance_to(lens_center) > 340.0:
			var angle: float = atan2(cloud_velocities[i].y, cloud_velocities[i].x) + PI
			cloud.position = lens_center + Vector2(cos(angle), sin(angle)) * 260.0 - cloud.size * 0.5


func _init_focus() -> void:
	var stage := GameManager.current_equipment_stage()
	var id := str(selected_object.get("id", ""))
	var eyepiece_id := GameManager.equipped_part_id("eyepiece")
	# Deterministic per target + stage + eyepiece: same level always needs
	# the same focus, but swapping the eyepiece shifts the focal plane and
	# forces a real re-focus.
	target_focus_value = 0.35 + fmod(float(absi((id + stage + eyepiece_id).hash())), 300.0) / 1000.0
	# Quantize to the slider grid so dragging can land EXACTLY on target.
	target_focus_value = snappedf(target_focus_value, 0.005)
	focus_tolerance = _tolerance_for(selected_object)
	var requirements: Dictionary = _active_observation_requirements()
	focus_tolerance *= float(requirements.get("focus_multiplier", 1.0))
	focus_value = 0.5
	if absf(focus_value - target_focus_value) < 0.12:
		# Always start visibly out of focus so the player learns the knob.
		focus_value = fmod(focus_value + 0.27, 1.0)
	focus_error = absf(focus_value - target_focus_value)
	best_focus_error = focus_error
	focus_adjustment_count = 0
	focus_direction_changes = 0
	last_focus_adjust_direction = 0
	last_focus_improvement_adjustment = 0
	focus_guide_active = false
	if not allow_focus_input:
		# No focus knob installed: the image stays clearly defocused.
		focus_error = maxf(focus_error, 0.25)


func _tolerance_for(obj: Dictionary) -> float:
	var object_type := str(obj.get("type_en", "")).to_lower()
	var id := str(obj.get("id", ""))
	if id == "moon":
		return 0.08
	if object_type.contains("planet"):
		return 0.05
	if object_type.contains("nebula") or object_type.contains("galaxy"):
		return 0.07
	return 0.06


func _evaluate() -> Dictionary:
	if _is_constellation_observation():
		return {
			"quality": "Good",
			"success": true,
			"visual_effect": "clear",
			"feedback_en": "The full star pattern is clear enough to identify.",
			"feedback_zh": "完整星群图形足够清晰，可以识别。",
			"observation_mode": "constellation",
			"seeing_label": "Good",
			"ratios": {"light": 1.0, "clarity": 1.0, "stability": 1.0}
		}
	var context := {"observation_mode": observation_mode}
	context["observation_requirements"] = _active_observation_requirements()
	context["exposure"] = exposure_value
	context["filter"] = active_filter
	context["dark_adaptation"] = dark_adaptation
	# The science check only receives a completed 1.25-second peripheral-gaze
	# hold. A raw Shift press is input, not evidence that the technique worked.
	context["averted_vision"] = averted_vision_confirmed
	context["visual_detection_techniques_enabled"] = _visual_detection_techniques_available()
	context["tracking_rate"] = GameManager.tracking_rate()
	context["observation_elapsed"] = observation_elapsed
	if requires_focus:
		context["focus_error"] = focus_error
		context["requires_focus"] = true
		context["focus_tolerance"] = focus_tolerance
	if cloud_cover_level > 0.0:
		# Real-time cloud attenuation: as clouds drift across the target the
		# instantaneous darkening feeds back into the actual quality math
		# (observation_system uses this key when present; the static
		# cloud_cover formula stays untouched for callers that don't pass it,
		# e.g. flow_test's direct evaluate() calls).
		context["cloud_attenuation"] = cond_cloud_atten
	if drift_enabled and target_off_center:
		# E2: drifted out of the eyepiece entirely - hard Failed. Only this
		# live telescope_view loop ever sets this key; GameManager's own
		# evaluate_selected_object() call (used by flow_test) never passes
		# it, so the 24-level numeric regression path is unaffected.
		context["target_off_center"] = true
	return GameManager.evaluate_selected_object(context)


func _focus_state() -> String:
	# Focus state depends ONLY on focus_error vs tolerance - never on the
	# overall observation quality. Inside tolerance is always "sharp".
	if is_focus_acceptable():
		return "sharp"
	if focus_error <= focus_tolerance * 1.75:
		return "slightly_blurry"
	if focus_error <= focus_tolerance * 3.0:
		return "blurry"
	return "very_blurry"


# Single source of truth for "can this observation be identified".
# Selection + centering are enforced by Sky Observation before entering
# this scene; here the remaining gates are focus and overall quality.


func is_focus_acceptable() -> bool:
	if not requires_focus:
		return true
	if not allow_focus_input:
		return false
	return focus_error <= focus_tolerance


func is_quality_acceptable() -> bool:
	return bool(observation.get("success", false))


func can_identify_object() -> bool:
	return is_focus_acceptable() and is_quality_acceptable() and _missing_required_parts().is_empty() and is_hold_satisfied()


# Checks whether the CURRENTLY equipped part satisfies the level's next
# pending mission step (e.g. L10: step 1 needs the 20mm, step 2 the 10mm),
# and if the observation itself is good enough, marks that step done.
# Only advances forward - never un-marks a step that was already completed.
func _check_mission_step_progress() -> void:
	if not is_focus_acceptable() or not is_quality_acceptable():
		return
	# ORDER-INDEPENDENT: the lesson is comparing magnifications, not doing
	# them in declared order - a player who equipped the 10mm first must get
	# credit for that observation too. Any pending step whose required part
	# is currently equipped completes.
	var done := GameManager.completed_mission_steps()
	for step_value in GameManager.mission_steps():
		if not step_value is Dictionary:
			continue
		var step: Dictionary = step_value
		var step_id := str(step.get("id", ""))
		if step_id == "" or done.has(step_id):
			continue
		var require_part_id := str(step.get("require_part_id", ""))
		if require_part_id == "":
			continue
		var part := GameManager.get_part(require_part_id)
		var part_type := str(part.get("type", ""))
		if part_type == "" or GameManager.equipped_part_id(part_type) != require_part_id:
			continue
		GameManager.mark_mission_step_done(step_id)
		_announce_step_complete(step)


func _announce_step_complete(step: Dictionary) -> void:
	# Positive milestone feedback the moment a step lands - the player must
	# never have to deduce progress from the tiny Step x/y header alone.
	if feedback_label == null:
		return
	var step_label := GameManager.dict_text(step, "label").replace("\n", " ")
	var next_step := GameManager.next_pending_mission_step()
	if next_step.is_empty():
		feedback_label.text = GameManager.text(
			"Step complete: %s. All steps done - identify the target!" % step_label,
			"✓ 步骤完成：%s。全部步骤已完成——识别目标吧！" % step_label
		)
	else:
		var next_label := GameManager.dict_text(next_step, "label").replace("\n", " ")
		feedback_label.text = GameManager.text(
			"Step complete: %s. Next: %s" % [step_label, next_label],
			"✓ 步骤完成：%s。下一步：%s" % [step_label, next_label]
		)
	feedback_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))


func _pending_step_label() -> String:
	var step := GameManager.next_pending_mission_step()
	if step.is_empty():
		return ""
	return GameManager.dict_text(step, "label")


func _mission_step_progress_text() -> String:
	var steps := GameManager.mission_steps()
	if steps.is_empty():
		return ""
	var done := GameManager.completed_mission_steps().size()
	var total := steps.size()
	var label := _pending_step_label()
	if label == "":
		return GameManager.text(
			"Completed %d/%d: All experiments complete" % [total, total],
			"已完成 %d/%d：全部实验完成" % [total, total]
		)
	return GameManager.text(
		"Completed %d/%d · Now: %s" % [done, total, label],
		"已完成 %d/%d · 当前：%s" % [done, total, label]
	)


func _missing_required_parts() -> Array[String]:
	var missing: Array[String] = GameManager.missing_required_parts()
	return missing


func _missing_required_parts_text() -> String:
	var missing := _missing_required_parts()
	var names_en: Array[String] = []
	var names_zh: Array[String] = []
	for part_id in missing:
		var part := GameManager.get_part(part_id)
		names_en.append(str(part.get("name_en", part_id)))
		names_zh.append(str(part.get("name_zh", part_id)))
	return GameManager.text(
		"This mission requires: " + ", ".join(names_en) + ". Equip it at the Parts Cabinet and reassemble.",
		"本次任务需要：" + "、".join(names_zh) + "。请到零件柜换装并重新组装。"
	)


func _quality_shortfall_text() -> String:
	if target_off_center:
		return GameManager.text(
			"The target has drifted out of the field. Use A/D and W/S to bring it back to the center.",
			"目标已经漂出视场。请用 A/D 和 W/S 把它移回中央。"
		)
	if cond_cloud_atten > 0.35:
		return GameManager.text(
			"Clouds are crossing the target. Keep the aim steady and wait for a clear gap.",
			"云层正在遮挡目标。请保持瞄准，等待云隙经过。"
		)
	if str(observation.get("seeing_label", "Good")) != "Good":
		return GameManager.text(
			"Focus is correct, but the air is unsteady. Lower the magnification and wait for a steadier moment.",
			"焦点已经正确，但大气仍不稳定。请降低倍率，并等待更平稳的时刻。"
		)
	var technique_failure: Dictionary = observation.get("technique_failure", {})
	if not technique_failure.is_empty():
		return GameManager.text(
			str(technique_failure.get("en", "Complete the observing method shown below.")),
			str(technique_failure.get("zh", "请完成下方标出的观测方法。"))
		)
	# Focus is fine - name the real limiting factor in actionable order.
	var ratios: Dictionary = observation.get("ratios", {})
	var light_ratio := float(ratios.get("light", 1.0))
	var clarity_ratio := float(ratios.get("clarity", 1.0))
	var stability_ratio := float(ratios.get("stability", 1.0))
	var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
	if sky_key == "city" and light_ratio <= clarity_ratio and light_ratio <= stability_ratio:
		return GameManager.text(
			"City sky-glow is hiding faint structure. Use the nebula filter when applicable, or choose a darker site.",
			"城市光污染正在淹没微弱结构。若目标适用，请开启星云滤镜；否则更换到更暗的地点。"
		)
	if _collimation_severity() > 0.28:
		return GameManager.text(
			"The image is focused, but coma remains. Return to collimation and align the mirrors.",
			"图像已经对焦，但仍有明显彗差。请返回准直界面对齐镜面。"
		)
	if light_ratio <= clarity_ratio and light_ratio <= stability_ratio:
		if _is_emission_nebula_target() and active_filter != "nebula":
			return GameManager.text(
				"The faint emission is being lost in the sky background. Enable the nebula filter.",
				"微弱发射结构正被天空背景淹没。请开启星云滤镜。"
			)
		return GameManager.text(
			"The image is focused, but not enough light is reaching the eyepiece. Use the mission's unlocked larger aperture.",
			"图像已经对焦，但进入目镜的光线仍不足。请使用本关已经解锁的更大口径部件。"
		)
	if clarity_ratio <= stability_ratio:
		return GameManager.text(
			"Focus is correct, but optical detail is still low. Lower magnification or check collimation.",
			"焦点已经正确，但光学细节仍不足。请降低倍率，或检查准直状态。"
		)
	return GameManager.text(
		"The target is focused, but the image is not stable enough. Re-center it and use the mission's stable mount.",
		"目标已经对焦，但画面仍不够稳定。请重新居中，并使用本关已解锁的稳定支架。"
	)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	quiz_brief_overlay = null
	focus_knob_status = null
	tracking_knob_status = null
	tracking_enabled_status = null
	drift_instruction_label = null
	stat_bar_fills.clear()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect(self, Vector2.ZERO, Vector2(1024, 768), COL_BG)
	_pixel_frame(self, Vector2(12, 10), Vector2(1000, 744), Color(0.006, 0.008, 0.018), COL_BLUE_BORDER, COL_GOLD)

	var view := _scope_visual()
	view.position = Vector2(54, 98)
	add_child(view)
	# Wood frame AFTER the scope view: the ring occluder's clip container
	# reaches the screen edges and would repaint over the frame strips.
	_add_wood_frame()
	# Title bar AFTER the scope view: the ring occluder inside the view is
	# oversized and would otherwise paint over the title strip.
	if observation_mode == "naked_eye":
		_title_bar(GameManager.text("Naked Eye Observation", "肉眼观测"))
	elif _is_constellation_observation():
		_title_bar(GameManager.text("Constellation Field", "星座星域"))
	else:
		_title_bar(GameManager.text("Telescope View", "望远镜视野"))
	_build_observation_panel()
	if _uses_observation_method(_active_observation_requirements()):
		_build_technique_panel()
	if drift_enabled:
		_build_drift_panel()
	if requires_focus and allow_focus_input:
		_build_focus_novice_guide()
	if requires_focus:
		_refresh_focus_ui()
	if TouchInput.is_mobile():
		_build_mobile_view_controls()


func _build_mobile_view_controls() -> void:
	TouchInput.focus_direction = 0.0
	# Drift levels reuse the virtual joystick as the centering stick.
	if drift_enabled:
		var overlay: Control = preload("res://scripts/ui/mobile_controls.gd").new()
		add_child(overlay)
	# Focus nudge buttons (Q/E equivalent) beside the drift panel, clear of
	# the observation panel and identify buttons.
	if requires_focus and allow_focus_input:
		for spec in [["−", -1.0, Vector2(624, 690)], ["＋", 1.0, Vector2(684, 690)]]:
			var nudge := Button.new()
			nudge.text = str(spec[0])
			nudge.position = spec[2]
			nudge.size = Vector2(52, 52)
			nudge.focus_mode = Control.FOCUS_NONE
			nudge.add_theme_font_size_override("font_size", 22)
			nudge.z_index = 90
			var nudge_direction: float = float(spec[1])
			nudge.button_down.connect(func() -> void: TouchInput.focus_direction = nudge_direction)
			nudge.button_up.connect(func() -> void: TouchInput.focus_direction = 0.0)
			add_child(nudge)
	call_deferred("_animate_stat_bars")


const SKY_BG_TEXTURE := "res://assets/reference/sky_observation_ui_bg_v2_1024.png"
const COL_BRASS := Color(0.72, 0.53, 0.26)


func _add_wood_frame() -> void:
	# Reuses the finder view's baked wooden frame (edge strips via
	# AtlasTexture regions - no new art). The top strip is the bottom strip
	# flipped, because the baked top edge carries the compass ornament.
	var base := load(SKY_BG_TEXTURE) as Texture2D
	if base == null:
		return
	# Only the LEFT column and the left 748px of the bottom edge are pure
	# wood in the baked art (the rest carries panel borders), so the frame
	# is built from those clean regions: bottom stretched full-width, top =
	# bottom flipped, right = left mirrored.
	var strips := [
		[Rect2(0, 734, 748, 34), Rect2(0, 734, 1024, 34), false, false],
		[Rect2(0, 734, 748, 34), Rect2(0, 0, 1024, 34), true, false],
		[Rect2(0, 0, 34, 768), Rect2(0, 0, 34, 768), false, false],
		[Rect2(0, 0, 34, 768), Rect2(990, 0, 34, 768), false, true],
	]
	for strip_value in strips:
		var atlas := AtlasTexture.new()
		atlas.atlas = base
		atlas.region = strip_value[0]
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2.ZERO
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.flip_v = bool(strip_value[2])
		rect.flip_h = bool(strip_value[3])
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.texture = atlas
		rect.position = (strip_value[1] as Rect2).position
		rect.size = (strip_value[1] as Rect2).size
		add_child(rect)


func _title_bar(title_text: String) -> void:
	# Brass plaque, matching the finder view's ornament styling.
	var plaque := Panel.new()
	plaque.position = Vector2(312, 16)
	plaque.size = Vector2(400, 54)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.075, 0.038, 0.97)
	style.border_color = COL_BRASS
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	plaque.add_theme_stylebox_override("panel", style)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plaque)
	var title := _plabel(title_text, Vector2(312, 22), Vector2(400, 42), 25, Color(0.96, 0.86, 0.58), HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF


# ------------------------------------------------------------- right panel


func _build_observation_panel() -> void:
	_gold_panel(self, PANEL_POS, PANEL_SIZE)
	var quality := str(observation.get("quality", "Unknown"))

	var header := _plabel(GameManager.text("Observation Quality", "观测质量"), Vector2(CONTENT_X - 4, 118), Vector2(CONTENT_W + 8, 30), 19, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF

	var has_mission_steps := not GameManager.mission_steps().is_empty()
	if has_mission_steps:
		# The current experiment is primary guidance, not diagnostic fine print.
		mission_step_label = _plabel(
			_mission_step_progress_text(),
			Vector2(CONTENT_X, 154),
			Vector2(CONTENT_W, 38),
			14,
			Color(0.70, 0.92, 1.0),
			HORIZONTAL_ALIGNMENT_CENTER
		)
		mission_step_label.name = "MissionStepLabel"
		mission_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mission_step_label.max_lines_visible = 2
		mission_step_label.clip_text = false
	else:
		var mystery := _mystery_description(selected_object)
		var observed := _plabel(
			GameManager.text("Observed: " + str(mystery.get("en", "")), "观测到：" + str(mystery.get("zh", ""))),
			Vector2(CONTENT_X, 162), Vector2(CONTENT_W, 32), 10, COL_TEXT
		)
		observed.max_lines_visible = 2

	quality_label = _plabel(GameManager.text("Quality: ", "质量: ") + quality, Vector2(CONTENT_X, 198), Vector2(CONTENT_W, 22), 15, _quality_color(quality))

	var feedback_y := 320.0
	if observation_mode == "naked_eye":
		_plabel(GameManager.text("Equipment: Naked Eye", "装备：肉眼"), Vector2(CONTENT_X, 232), Vector2(CONTENT_W, 40), 13, COL_GOLD_LIGHT)
	else:
		_add_stat_bars()
		var rows_end := _add_condition_rows()
		# 4 slots max (283/295/307/319); once slot 4 is used, feedback must
		# shift down from 320 to 332 and shrink to a single line to still
		# fit above the Focus block at y=348.
		if rows_end > CONDITION_ROW_Y + CONDITION_ROW_H * 3.0 + 0.5:
			feedback_y = 332.0

	var feedback_h := 26.0 if feedback_y <= 320.0 else 14.0
	feedback_label = _plabel(_current_feedback(), Vector2(CONTENT_X, feedback_y), Vector2(CONTENT_W, feedback_h), 9, Color(0.86, 0.90, 0.88))
	feedback_label.max_lines_visible = 1 if feedback_y > 320.0 else 2

	if requires_focus:
		_build_focus_block()

	if is_free_observation:
		_build_free_observation_panel()
		return

	identify_title_label = _plabel(GameManager.text("Identify", "识别"), Vector2(CONTENT_X, 414), Vector2(CONTENT_W, 20), 16, Color(0.98, 0.82, 0.50))

	choices_box = VBoxContainer.new()
	choices_box.position = Vector2(CONTENT_X, 436)
	choices_box.size = Vector2(CONTENT_W, 146)
	choices_box.add_theme_constant_override("separation", 6)
	add_child(choices_box)
	_add_identify_choices()

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(CONTENT_X, 600)
	bottom.size = Vector2(CONTENT_W, 38)
	bottom.add_theme_constant_override("separation", 10)
	add_child(bottom)

	var retry := _pixel_button(GameManager.text("Retry", "重试"), Vector2(92, 38), 14)
	retry.pressed.connect(func() -> void: GameManager.go("sky"))
	bottom.add_child(retry)

	var back := _pixel_button(GameManager.text("Back", "返回"), Vector2(92, 38), 14)
	back.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("telescope")
		GameManager.go("observatory")
	)
	bottom.add_child(back)
	_add_change_equipment_button()

	if quiz_brief_dismissed:
		_set_identify_choices_visible(true)
	else:
		_show_pre_quiz_guide()


func _build_free_observation_panel() -> void:
	# Non-mission target: no identify quiz. The player can log the result, return
	# directly to the mission target, or leave for the wider sky view.
	identify_title_label = _plabel(GameManager.text("Free Observation", "自由观测"), Vector2(CONTENT_X, 414), Vector2(CONTENT_W, 22), 17, Color(0.42, 0.82, 1.0))
	var name_line := GameManager.dict_text(selected_object, "name")
	var identity := _plabel(name_line + "  ·  " + GameManager.dict_text(selected_object, "type"), Vector2(CONTENT_X, 440), Vector2(CONTENT_W, 34), 12, COL_TEXT)
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.max_lines_visible = 2
	var q := str(observation.get("quality", "Good"))
	free_quality_label = _plabel(GameManager.text("Quality: ", "观测质量：") + q, Vector2(CONTENT_X, 478), Vector2(CONTENT_W, 20), 13, _quality_color(q))
	free_quality_label.name = "FreeObservationQualityLabel"
	var learn := _plabel(GameManager.dict_text(selected_object, "learning_text") if selected_object.has("learning_text_en") else GameManager.dict_text(selected_object, "short_hint"), Vector2(CONTENT_X, 502), Vector2(CONTENT_W, 54), 12, Color(0.82, 0.88, 0.92))
	learn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learn.max_lines_visible = 3
	free_result_label = _plabel("", Vector2(CONTENT_X, 558), Vector2(CONTENT_W, 18), 11, Color(0.55, 1.0, 0.68))

	var mission_id := GameManager.current_target_object_id()
	var mission_object: Dictionary = GameManager.get_object(mission_id)
	var mission_name := GameManager.dict_text(mission_object, "name")
	var mission_button := _pixel_button(GameManager.text("Return to Mission", "返回任务目标"), Vector2(CONTENT_W, 34), 12)
	mission_button.name = "FreeObservationMissionButton"
	mission_button.position = Vector2(CONTENT_X, 580)
	mission_button.tooltip_text = GameManager.text(
		"Return to the sky view and point the telescope toward %s." % mission_name,
		"返回天空视角，再自行把望远镜指向%s。" % mission_name
	)
	mission_button.disabled = mission_id == "" or mission_object.is_empty()
	mission_button.pressed.connect(_return_to_mission_target)
	add_child(mission_button)

	var bottom := HBoxContainer.new()
	bottom.position = Vector2(CONTENT_X, 620)
	bottom.size = Vector2(CONTENT_W, 34)
	var button_gap := 8.0
	var button_width := (CONTENT_W - button_gap) * 0.5
	bottom.add_theme_constant_override("separation", int(button_gap))
	add_child(bottom)
	var log_btn := _pixel_button(GameManager.text("Add to Logbook", "加入日志"), Vector2(button_width, 34), 11)
	log_btn.name = "FreeObservationLogButton"
	log_btn.tooltip_text = GameManager.text("Record this observation in the Club Logbook.", "将本次观测记录到俱乐部日志。")
	log_btn.pressed.connect(_add_free_observation_to_logbook)
	bottom.add_child(log_btn)
	var back := _pixel_button(GameManager.text("Back to Sky", "返回星图"), Vector2(button_width, 34), 11)
	back.name = "FreeObservationBackButton"
	back.pressed.connect(func() -> void: GameManager.go("sky"))
	bottom.add_child(back)
	_add_change_equipment_button(658.0, 30.0)


func _add_change_equipment_button(y := 650.0, height := 34.0) -> void:
	if observation_mode == "naked_eye":
		return
	var equipment := _pixel_button(GameManager.text("Change Equipment", "更换装备"), Vector2(CONTENT_W, height), 12)
	equipment.position = Vector2(CONTENT_X, y)
	equipment.tooltip_text = GameManager.text(
		"Open the Parts Cabinet. Reassemble after changing a component.",
		"打开零件柜。更换零件后需要重新组装。"
	)
	equipment.pressed.connect(func() -> void:
		GameManager.set_observatory_spawn("cabinet")
		GameManager.go("parts")
	)
	add_child(equipment)


func _return_to_mission_target() -> void:
	if mission_return_in_progress:
		return
	var mission_id := GameManager.current_target_object_id()
	var mission_object: Dictionary = GameManager.get_object(mission_id)
	if mission_id == "" or mission_object.is_empty():
		InteractionFeedback.error(free_result_label if free_result_label != null else self)
		return

	mission_return_in_progress = true
	GameManager.selected_object_id = mission_id
	GameManager.selected_object_level = int(GameManager.progress.get("current_level", 1))
	# Restore only the mission target context. The observing site and the mount's
	# last real aim remain untouched, so Sky Observation can apply the current
	# hemisphere/horizon and the player must acquire and lock the target again.
	GameManager.world_map_target_id = mission_id
	GameManager.world_map_observation_context.clear()
	GameManager.go_to_observation("telescope")


func _add_free_observation_to_logbook() -> void:
	var result: Dictionary = GameManager.record_free_observation(str(selected_object.get("id", "")), observation)
	if free_result_label != null:
		if bool(result.get("repeat", false)):
			free_result_label.text = GameManager.text("Already logged with this setup. Change eyepiece or family for a new record.", "该设备下已记录。换目镜或望远镜类型可添加新记录。")
			free_result_label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.52))
		else:
			var awarded := int(result.get("credits_awarded", 0))
			var total := int(result.get("credits_total", GameManager.progress.get("credits", 0)))
			free_result_label.text = GameManager.text(
				"New observation record added (+%d credits, total %d)." % [awarded, total],
				"已新增观测记录（+%d 积分，共 %d）。" % [awarded, total]
			)
			free_result_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
			InteractionFeedback.success(free_result_label, "free_observation_logged")


func _build_focus_block() -> void:
	if not allow_focus_input:
		_plabel(GameManager.text("Focus", "对焦"), Vector2(CONTENT_X, 348), Vector2(70, 18), 13, COL_GOLD_LIGHT)
		var missing := _plabel(GameManager.text("Knob: not installed", "旋钮：未安装"), Vector2(CONTENT_X + 60, 346), Vector2(CONTENT_W - 60, 26), 9, Color(1.0, 0.45, 0.32), HORIZONTAL_ALIGNMENT_RIGHT)
		missing.max_lines_visible = 2
		focus_state_label = _plabel(
			GameManager.text("Install it at the Assembly Table.", "请回组装台安装调焦旋钮。"),
			Vector2(CONTENT_X, 378), Vector2(CONTENT_W, 32), 9, Color(1.0, 0.62, 0.40)
		)
		focus_state_label.max_lines_visible = 3
		return

	# Equipment property, deliberately constant: the knob's mechanical
	# precision (finer slider steps at >=60), NOT a live focus readout.
	focus_knob_status = _hud_asset(OBS_UI_DIR + "focus_knob_ui.png", Rect2(Vector2(CONTENT_X, 343), Vector2(28, 28)))
	focus_knob_status.pivot_offset = focus_knob_status.size * 0.5
	focus_knob_status.rotation = lerpf(-PI * 0.72, PI * 0.72, focus_value)
	_plabel(GameManager.text("Knob precision %d%%" % int(_focus_control_score()), "旋钮精度 %d%%" % int(_focus_control_score())), Vector2(CONTENT_X + 32, 350), Vector2(94, 18), 10, COL_GOLD_LIGHT)
	focus_pct_label = _plabel("", Vector2(CONTENT_X + 126, 351), Vector2(CONTENT_W - 126, 18), 11, COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

	focus_slider = HSlider.new()
	focus_slider.min_value = 0.0
	focus_slider.max_value = 1.0
	# A better focus knob gives finer slider control.
	focus_slider.step = 0.005 if _focus_control_score() >= 60.0 else 0.015
	focus_slider.value = focus_value
	focus_slider.position = Vector2(CONTENT_X, 370)
	focus_slider.size = Vector2(CONTENT_W, 18)
	var clear_start := clampf(target_focus_value - focus_tolerance, 0.0, 1.0)
	var clear_end := clampf(target_focus_value + focus_tolerance, 0.0, 1.0)
	focus_guide_zone = _rect(
		self,
		Vector2(CONTENT_X + CONTENT_W * clear_start, 368),
		Vector2(maxf(4.0, CONTENT_W * (clear_end - clear_start)), 22),
		Color(0.28, 0.95, 0.48, 0.28)
	)
	focus_guide_zone.visible = false
	focus_slider.value_changed.connect(func(value: float) -> void:
		if not updating_slider:
			_set_focus_value(value)
	)
	add_child(focus_slider)

	focus_state_label = _plabel("", Vector2(CONTENT_X, 388), Vector2(CONTENT_W, 24), 9, COL_TEXT)
	focus_state_label.max_lines_visible = 2


func _set_focus_value(value: float) -> void:
	var old_value := focus_value
	var was_acceptable := is_focus_acceptable()
	focus_value = clampf(value, 0.0, 1.0)
	if focus_knob_status != null:
		InteractionFeedback.tween_rotation(focus_knob_status, lerpf(-PI * 0.72, PI * 0.72, focus_value), 0.11)
	focus_error = absf(focus_value - target_focus_value)
	_track_focus_attempt(old_value)
	observation = _evaluate()
	# Web builds can deliver slider changes between sparse process ticks. Apply
	# the common infinity-focus response immediately so the target and field
	# stars both react while the knob is moving, not after release.
	visual_focus_error = focus_error
	blur_weight = _optical_defocus_amount()
	_update_target_visuals()
	_refresh_focus_ui()
	if not was_acceptable and is_focus_acceptable() and not focus_lock_feedback_played:
		focus_lock_feedback_played = true
		InteractionFeedback.success(focus_slider, "focus_locked")
		if main_sprite != null:
			InteractionFeedback.pulse(main_sprite, Color(1.08, 1.06, 0.88, 1.0), 0.46)


func _track_focus_attempt(old_value: float) -> void:
	var movement := focus_value - old_value
	if absf(movement) < 0.0005:
		return
	focus_adjustment_count += 1
	var direction := 1 if movement > 0.0 else -1
	if last_focus_adjust_direction != 0 and direction != last_focus_adjust_direction:
		focus_direction_changes += 1
	last_focus_adjust_direction = direction
	if focus_error + 0.002 < best_focus_error:
		best_focus_error = focus_error
		last_focus_improvement_adjustment = focus_adjustment_count

	if is_focus_acceptable():
		focus_guide_active = false
		_update_focus_novice_guide()
		return

	var near_miss := best_focus_error <= focus_tolerance * 2.25
	var oscillating := focus_direction_changes >= 2
	var stalled := focus_adjustment_count - last_focus_improvement_adjustment >= 5
	if (focus_adjustment_count >= 6 and near_miss) \
			or (focus_adjustment_count >= 8 and oscillating) \
			or (focus_adjustment_count >= 14 and stalled):
		focus_guide_active = true
	_update_focus_novice_guide()


func _build_focus_novice_guide() -> void:
	var guide_y := 558.0 if drift_enabled else 584.0
	focus_guide_panel = _styled_panel(
		self,
		Vector2(84, guide_y), Vector2(576, 94),
		Color(0.025, 0.050, 0.085, 0.98), Color(0.35, 0.78, 1.0),
		3, 4, false, Color(0.35, 0.78, 1.0)
	)
	focus_guide_panel.z_index = 120
	var title := _plabel(GameManager.text("Focus Help", "调焦帮助"), Vector2(104, guide_y + 12), Vector2(536, 22), 16, Color(0.55, 0.88, 1.0))
	title.z_index = 121
	focus_guide_text = _plabel("", Vector2(104, guide_y + 36), Vector2(536, 46), 12, COL_TEXT)
	focus_guide_text.z_index = 121
	focus_guide_text.max_lines_visible = 3
	focus_guide_panel.visible = false
	title.visible = false
	focus_guide_text.visible = false
	focus_guide_panel.set_meta("title_label", title)
	_update_focus_novice_guide()


func _update_focus_novice_guide() -> void:
	if focus_guide_panel == null:
		return
	var show_guide := focus_guide_active and not is_focus_acceptable()
	focus_guide_panel.visible = show_guide
	var title := focus_guide_panel.get_meta("title_label") as Label
	if title != null:
		title.visible = show_guide
	if focus_guide_text != null:
		focus_guide_text.visible = show_guide
	if focus_guide_zone != null:
		focus_guide_zone.visible = show_guide
	if not show_guide:
		return
	var remaining := int(round(focus_error * 100.0))
	if focus_value < target_focus_value:
		focus_guide_text.text = GameManager.text(
			"Hold E to move right about %d%%. Stop inside the green clear zone; if the image worsens, tap Q back." % remaining,
			"按住 E 向右调约 %d%%。进入绿色清晰区就停下；如果画面变糊，轻按 Q 往回调。" % remaining
		)
	else:
		focus_guide_text.text = GameManager.text(
			"Hold Q to move left about %d%%. Stop inside the green clear zone; if the image worsens, tap E back." % remaining,
			"按住 Q 向左调约 %d%%。进入绿色清晰区就停下；如果画面变糊，轻按 E 往回调。" % remaining
		)


# --------------------------------------------------------- E2 drift / track


const DRIFT_PANEL_POS := Vector2(54, 664)
const DRIFT_PANEL_SIZE := Vector2(560, 72)
const DRIFT_ROW_H := 20.0


func _build_technique_panel() -> void:
	var requirements: Dictionary = _active_observation_requirements()
	var panel_pos := Vector2(54, 614)
	var panel_size := Vector2(680, 44)
	_pixel_panel(self, panel_pos, panel_size, COL_NAVY, COL_BRASS)
	_plabel(GameManager.text("METHOD", "观测方法"), panel_pos + Vector2(10, 5), Vector2(82, 16), 10, COL_GOLD_LIGHT)
	var x := panel_pos.x + 92.0
	if requirements.has("exposure_min") or requirements.has("exposure_max"):
		_plabel(GameManager.text("Exposure", "曝光"), Vector2(x, panel_pos.y + 5), Vector2(58, 14), 9, COL_TEXT)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.02
		slider.value = exposure_value
		slider.position = Vector2(x + 60, panel_pos.y + 2)
		slider.size = Vector2(118, 20)
		slider.value_changed.connect(func(value: float) -> void:
			exposure_value = value
			observation = _evaluate()
			_refresh_target_sprite()
			_refresh_technique_status()
		)
		add_child(slider)
		x += 190.0
	if requirements.has("filter"):
		technique_filter_button = _pixel_button(GameManager.text("Filter: Off", "滤镜：关闭"), Vector2(112, 26), 9)
		technique_filter_button.position = Vector2(x, panel_pos.y + 4)
		technique_filter_button.tooltip_text = GameManager.text(
			"Nebula filter: reduces part of the sky glow to improve emission-nebula contrast. Click to toggle.",
			"星云滤镜：削弱部分天空背景光，提高发射星云的对比度。点击切换。"
		)
		technique_filter_button.pressed.connect(func() -> void:
			active_filter = "nebula" if active_filter == "none" else "none"
			technique_filter_button.text = GameManager.text("Filter: Nebula", "滤镜：星云") if active_filter == "nebula" else GameManager.text("Filter: Off", "滤镜：关闭")
			observation = _evaluate()
			_refresh_target_sprite()
			_refresh_technique_status()
		)
		add_child(technique_filter_button)
		x += 122.0
	if _visual_detection_techniques_available():
		var shift_hint := _plabel(
			GameManager.text(
				"Hold SHIFT 1.25s · keep target near the side marker",
				"按住 Shift 1.25 秒，让目标保持在侧视标记附近"
			),
			Vector2(x, panel_pos.y + 4), Vector2(240, 14), 9,
			Color(0.48, 0.88, 1.0)
		)
		shift_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
		shift_hint.clip_text = true
		x += 246.0
	technique_status_label = _plabel("", Vector2(x, panel_pos.y + 4), Vector2(panel_pos.x + panel_size.x - x - 8, 32), 9, Color(0.74, 0.86, 0.96))
	technique_status_label.max_lines_visible = 2
	_refresh_technique_status()


func _uses_observation_method(requirements: Dictionary) -> bool:
	if _visual_detection_techniques_available():
		return true
	for key in ["exposure_min", "exposure_max", "filter", "dark_adaptation_min", "require_averted_vision", "seeing_patience"]:
		if requirements.has(key):
			return true
	return false


func _refresh_technique_status() -> void:
	if technique_status_label == null:
		return
	var requirements: Dictionary = _active_observation_requirements()
	var pending: Array[String] = []
	var ready: Array[String] = []
	if requirements.has("filter"):
		var required_filter := str(requirements.get("filter", "nebula"))
		if active_filter != required_filter:
			pending.append(GameManager.text("Click to enable the nebula filter", "点击开启星云滤镜"))
		else:
			ready.append(GameManager.text("Nebula filter ON", "星云滤镜：已开启"))
	if requirements.has("exposure_min") or requirements.has("exposure_max"):
		var exposure_low := float(requirements.get("exposure_min", 0.0))
		var exposure_high := float(requirements.get("exposure_max", 1.0))
		if exposure_value < exposure_low:
			pending.append(GameManager.text("Raise exposure", "提高曝光"))
		elif exposure_value > exposure_high:
			pending.append(GameManager.text("Reduce exposure", "降低曝光"))
		else:
			ready.append(GameManager.text("Exposure %d%%" % roundi(exposure_value * 100.0), "曝光：%d%%" % roundi(exposure_value * 100.0)))
	var required_adaptation := float(requirements.get("dark_adaptation_min", 0.0))
	if required_adaptation > 0.0:
		if dark_adaptation + 0.001 < required_adaptation:
			pending.append(GameManager.text(
				"Dark adapt %d / %d%%" % [roundi(dark_adaptation * 100.0), roundi(required_adaptation * 100.0)],
				"暗适应 %d / %d%%" % [roundi(dark_adaptation * 100.0), roundi(required_adaptation * 100.0)]
			))
		else:
			ready.append(GameManager.text(
				"Dark adaptation %d%% threshold met · effective" % roundi(dark_adaptation * 100.0),
				"暗适应：%d%% 已达标 · 已生效" % roundi(dark_adaptation * 100.0)
			))
	elif _visual_detection_techniques_available():
		if dark_adaptation < 0.999:
			pending.append(GameManager.text(
				"Dark adapting %d%%" % roundi(dark_adaptation * 100.0),
				"暗适应进行中：%d%%" % roundi(dark_adaptation * 100.0)
			))
		else:
			ready.append(GameManager.text(
				"Dark adaptation 100% · effective",
				"暗适应：100% · 已生效"
			))
	if _visual_detection_techniques_available():
		if averted_vision_confirmed:
			ready.append(GameManager.text("Averted vision confirmed", "偏视结构已确认"))
		elif averted_vision_active:
			if drift_enabled and drift_offset.length() > DRIFT_HOLD_RADIUS:
				pending.append(GameManager.text(
					"Keep SHIFT held; guide the target back toward the side-view marker",
					"继续按住 Shift，把目标带回侧视标记附近"
				))
			else:
				pending.append(GameManager.text(
					"Keep holding SHIFT · %d%%" % roundi(averted_hold_visual * 100.0),
					"继续按住 Shift，让目标保持在侧视标记附近 · %d%%" % roundi(averted_hold_visual * 100.0)
				))
		else:
			pending.append(GameManager.text(
				"Hold SHIFT for 1.25s; keep the target near the side-view marker",
				"按住 Shift 1.25 秒，让目标保持在侧视标记附近"
			))
	if requirements.has("seeing_patience"):
		var steady_seconds := 4.0 + float(requirements.get("seeing_patience", 0.0)) * 4.0
		if observation_elapsed + 0.001 < steady_seconds:
			pending.append(GameManager.text(
				"Hold steady %.1f / %.1fs" % [observation_elapsed, steady_seconds],
				"等待视宁度稳定 %.1f / %.1f 秒" % [observation_elapsed, steady_seconds]
			))
		else:
			ready.append(GameManager.text("Seeing window found", "已等到稳定视宁度"))
	if not pending.is_empty():
		technique_status_label.text = " · ".join(ready + pending)
		technique_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.36))
		return
	var failure: Dictionary = observation.get("technique_failure", {})
	if not failure.is_empty():
		technique_status_label.text = GameManager.text(
			str(failure.get("en", "Complete the highlighted observing method.")),
			str(failure.get("zh", "请完成高亮显示的观测方法。"))
		)
		technique_status_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.36))
		return
	technique_status_label.text = " · ".join(ready)
	technique_status_label.add_theme_color_override("font_color", Color(0.48, 0.96, 0.60))


func _build_drift_panel() -> void:
	# Center Hold / tracking UI lives below the scope circle, left of the
	# right-hand observation panel - never competes with it for space.
	# Three fixed, non-wrapping rows: Drift+Track status / Hold bar / rate slider.
	var panel_h := DRIFT_PANEL_SIZE.y
	_pixel_panel(self, DRIFT_PANEL_POS, Vector2(DRIFT_PANEL_SIZE.x, panel_h), COL_NAVY, COL_BRASS)
	var x := DRIFT_PANEL_POS.x + 12.0
	var y := DRIFT_PANEL_POS.y + 8.0

	drift_label = _plabel(_drift_status_text(), Vector2(x, y), Vector2(DRIFT_PANEL_SIZE.x - 24.0, 14), 10, Color(0.90, 0.86, 0.60))
	drift_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	drift_label.clip_text = true
	if GameManager.has_tracking_mount_equipped():
		tracking_enabled_status = _hud_asset(OBS_UI_DIR + "tracking_enabled_icon.png", Rect2(Vector2(DRIFT_PANEL_POS.x + DRIFT_PANEL_SIZE.x - 32, y - 3), Vector2(20, 20)))
	y += DRIFT_ROW_H

	if hold_seconds_required > 0.0:
		_rect(self, Vector2(x, y + 3.0), Vector2(74, 8), Color(0.10, 0.14, 0.22))
		hold_bar_fill = _rect(self, Vector2(x, y + 3.0), Vector2(0, 8), Color(0.45, 0.80, 0.95))
		hold_label = _plabel("", Vector2(x + 84.0, y - 2.0), Vector2(DRIFT_PANEL_SIZE.x - 24.0 - 84.0, 14), 9, Color(0.80, 0.90, 0.95))
		hold_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		hold_label.clip_text = true
		y += DRIFT_ROW_H

	if GameManager.has_tracking_mount_equipped():
		var rate_label := _plabel(GameManager.text("Rate", "速率"), Vector2(x, y + 2.0), Vector2(52, 14), 9, Color(0.75, 0.85, 0.95))
		rate_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		tracking_knob_status = _hud_asset(OBS_UI_DIR + "tracking_rate_knob.png", Rect2(Vector2(x + 54.0, y - 4.0), Vector2(26, 26)))
		tracking_knob_status.pivot_offset = tracking_knob_status.size * 0.5
		tracking_knob_status.rotation = lerpf(-PI * 0.72, PI * 0.72, clampf(GameManager.tracking_rate() / 2.0, 0.0, 1.0))
		tracking_slider = HSlider.new()
		tracking_slider.min_value = 0.0
		tracking_slider.max_value = 2.0
		tracking_slider.step = 0.05
		tracking_slider.value = GameManager.tracking_rate()
		tracking_slider.position = Vector2(x + 88.0, y)
		tracking_slider.size = Vector2(200, 18)
		tracking_slider.value_changed.connect(func(value: float) -> void:
			GameManager.set_tracking_rate(value)
			if tracking_knob_status != null:
				InteractionFeedback.tween_rotation(tracking_knob_status, lerpf(-PI * 0.72, PI * 0.72, clampf(value / 2.0, 0.0, 1.0)), 0.11)
			_refresh_drift_ui()
		)
		add_child(tracking_slider)
		tracking_label = _plabel("", Vector2(x + 294.0, y + 2.0), Vector2(DRIFT_PANEL_SIZE.x - 24.0 - 294.0, 14), 9, Color(0.80, 0.90, 0.95))
		tracking_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		drift_instruction_label = _plabel(
			_manual_drift_instruction_text(),
			Vector2(x, y + 1.0),
			Vector2(DRIFT_PANEL_SIZE.x - 24.0, 18),
			11,
			Color(0.50, 0.88, 1.0)
		)
		drift_instruction_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		drift_instruction_label.clip_text = true

	_refresh_drift_ui()


func _drift_status_text() -> String:
	return GameManager.text("Earth drift: On", "地球自转漂移：开启")


func _manual_drift_instruction_text() -> String:
	if manual_drift_tutorial_corrected:
		return GameManager.text(
			"Manual tracking learned · use small A/D or arrow-key corrections",
			"已掌握手动跟随 · 用 A/D 或方向键小幅修正"
		)
	if not manual_drift_tutorial_active:
		return GameManager.text(
			"Manual correction: A/D or Left/Right arrows",
			"手动修正：A/D 或左右方向键"
		)
	if not manual_drift_tutorial_observed:
		return GameManager.text(
			"Step 1: watch Sirius drift before touching the controls",
			"第 1 步：先看天狼星自行漂移，暂时不要按键"
		)
	var key := "D" if drift_offset.x >= 0.0 else "A"
	var direction_en := "right" if drift_offset.x >= 0.0 else "left"
	var direction_zh := "右" if drift_offset.x >= 0.0 else "左"
	return GameManager.text(
		"Step 2: drifting %s · tap %s to pull it back; release near center" % [direction_en, key],
		"第 2 步：目标正向%s漂移 · 短按 %s 拉回，接近中心就松开" % [direction_zh, key]
	)


func _tracking_state_label() -> Dictionary:
	if not GameManager.has_tracking_mount_equipped():
		return {"en": "Manual mount / Hand-guided", "zh": "手动支架 / 手动跟随"}
	var rate := GameManager.tracking_rate()
	if rate < 0.05:
		return {"en": "Motor off", "zh": "追踪电机关闭"}
	if absf(rate - 1.0) <= 0.1:
		return {"en": "Matched 1x", "zh": "已匹配 1 倍速"}
	if rate < 1.0:
		return {"en": "Too slow", "zh": "追踪过慢"}
	return {"en": "Too fast", "zh": "追踪过快"}


func _refresh_drift_ui() -> void:
	if drift_label != null:
		var tracking_state := _tracking_state_label()
		var track_text := GameManager.text(
			"Tracking: %s" % str(tracking_state.get("en", "")),
			"追踪：%s" % str(tracking_state.get("zh", ""))
		)
		if GameManager.has_tracking_mount_equipped():
			var rate_error := absf(GameManager.tracking_rate() - 1.0)
			track_text += "  Δ%.2fx" % rate_error
		drift_label.text = "%s   %s" % [_drift_status_text(), track_text]
	if hold_bar_fill != null and hold_seconds_required > 0.0:
		var ratio := clampf(hold_timer / hold_seconds_required, 0.0, 1.0)
		hold_bar_fill.size = Vector2(74.0 * ratio, 8)
	if hold_label != null:
		hold_label.text = GameManager.text(
			"Centered: %.1f/%.1fs" % [hold_timer, hold_seconds_required],
			"居中保持：%.1f/%.1f 秒" % [hold_timer, hold_seconds_required]
		)
	if tracking_label != null:
		tracking_label.text = "%.2fx" % GameManager.tracking_rate()
	if drift_instruction_label != null:
		drift_instruction_label.text = _manual_drift_instruction_text()
	if tracking_enabled_status != null:
		var enabled := GameManager.tracking_rate() >= 0.05
		var aligned := absf(GameManager.tracking_rate() - 1.0) <= 0.1
		tracking_enabled_status.visible = enabled
		tracking_enabled_status.modulate = Color(0.58, 1.0, 0.72, 1.0) if aligned else Color(1.0, 0.76, 0.34, 0.78)
		if enabled and not tracking_feedback_enabled:
			InteractionFeedback.pulse(tracking_enabled_status, Color(0.70, 1.0, 0.78), 0.38)
		elif aligned and not tracking_feedback_aligned:
			InteractionFeedback.success(tracking_enabled_status, "tracking_rate_matched")
		tracking_feedback_enabled = enabled
		tracking_feedback_aligned = aligned


func _refresh_focus_ui() -> void:
	_check_mission_step_progress()
	if mission_step_label != null:
		mission_step_label.text = _mission_step_progress_text()
	if focus_slider != null:
		updating_slider = true
		focus_slider.value = focus_value
		updating_slider = false
	if focus_pct_label != null:
		focus_pct_label.text = "%d%%  (Q/E)" % int(round(focus_value * 100.0))
	if focus_state_label != null and allow_focus_input:
		var state := _focus_state()
		match state:
			"sharp":
				# Sharp focus alone is not permission to identify - the
				# overall quality (and, on drift levels, the hold timer) must
				# also pass.
				if _collimation_severity() > 0.28:
					focus_state_label.text = GameManager.text("Coma: collimate mirrors.", "彗差：请准直镜面。")
					focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
				elif drift_enabled and not is_hold_satisfied():
					focus_state_label.text = _hold_progress_text()
					focus_state_label.add_theme_color_override("font_color", Color(0.70, 0.85, 1.0))
				elif is_quality_acceptable():
					focus_state_label.text = _focus_ready_text()
					focus_state_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55))
				else:
					focus_state_label.text = _quality_shortfall_text()
					focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			"slightly_blurry":
				focus_state_label.text = GameManager.text("Almost sharp. Fine-tune Q/E a little more.", "已经接近清晰，请用 Q/E 再微调一点。")
				focus_state_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
			"blurry":
				focus_state_label.text = GameManager.text("Blurry. Keep adjusting.", "模糊，继续调整。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.30))
			_:
				focus_state_label.text = GameManager.text("Very blurry. Turn the focus knob.", "非常模糊，请转动调焦旋钮。")
				focus_state_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.30))
	var quality := str(observation.get("quality", "Unknown"))
	if quality_label != null:
		quality_label.text = GameManager.text("Quality: ", "质量: ") + quality
		quality_label.add_theme_color_override("font_color", _quality_color(quality))
	if free_quality_label != null:
		free_quality_label.text = GameManager.text("Quality: ", "观测质量：") + quality
		free_quality_label.add_theme_color_override("font_color", _quality_color(quality))
	if feedback_label != null:
		InteractionFeedback.crossfade_text(feedback_label, _current_feedback())
	if drift_enabled:
		_refresh_drift_ui()
	_update_target_visuals()


func _current_feedback() -> String:
	if requires_focus and not allow_focus_input:
		return GameManager.text(
			"A focus knob is required. Return to the Assembly Table and install it near the eyepiece.",
			"需要调焦旋钮。请回到组装台，把它安装在目镜附近。"
		)
	if not _missing_required_parts().is_empty():
		return _missing_required_parts_text()
	var requirements: Dictionary = _active_observation_requirements()
	if bool(requirements.get("require_averted_vision", false)) and not averted_vision_confirmed:
		if averted_vision_active:
			if drift_enabled and drift_offset.length() > DRIFT_HOLD_RADIUS:
				return GameManager.text(
					"Keep Shift held and guide the target back toward the side-view marker.",
					"继续按住 Shift，把目标带回侧视标记附近。"
				)
			return GameManager.text(
				"Keep holding Shift; keep the target near the side marker: %.2f / %.2fs.",
				"继续按住 Shift，让目标保持在侧视标记附近：%.2f / %.2f 秒。"
			) % [averted_vision_hold_seconds, AVERTED_VISION_HOLD_SECONDS]
		return GameManager.text(
			"Hold Shift for 1.25 seconds and keep the target near the side marker.",
			"按住 Shift 1.25 秒，让目标保持在旁边的偏视标记附近。"
		)
	if is_focus_acceptable() and _collimation_severity() > 0.28:
		return _quality_shortfall_text()
	if drift_enabled and not is_hold_satisfied():
		return _hold_progress_text()
	if not is_focus_acceptable():
		return GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
	if requires_focus and not is_quality_acceptable():
		# The feedback box names the REAL limiting factor, in priority order
		# (cloud > seeing > sky brightness > aperture/stability): see
		# _quality_shortfall_text(). Only fall back to the generic "equip a
		# bigger lens" nebula copy when none of those environmental causes
		# are the dominant one.
		var type_lower := str(selected_object.get("type_en", "")).to_lower()
		var is_diffuse := type_lower.contains("nebula") or type_lower.contains("galaxy")
		var environmental_cause := _collimation_severity() > 0.28 or cond_cloud_atten > 0.35 or str(observation.get("seeing_label", "Good")) != "Good"
		if is_diffuse and not environmental_cause:
			return GameManager.text(
				"Focus aligned, but the image is too faint. Equip a bigger lens / stable mount at the Parts Cabinet, then reassemble.",
				"焦点已对准，但图像太暗。请到零件柜换装大口径物镜和稳定支架，再重新组装。"
			)
		return _quality_shortfall_text()
	if requires_focus and can_identify_object():
		return _focus_ready_text()
	return _short_feedback(str(observation.get("quality", "Unknown")))


func _focus_ready_text() -> String:
	var level := GameManager.current_level()
	return GameManager.text(
		"Image clear enough. Ready to identify.",
		str(level.get("focus_ready_text_zh", "图像已足够清晰，可以识别。"))
	)


func _add_stat_bars() -> void:
	var stats := GameManager.calculate_stats()
	var rows: Array = [
		{"name": GameManager.text("Light", "集光"), "value": float(stats.get("light_score", 0.0))},
		{"name": GameManager.text("Clarity", "清晰"), "value": float(stats.get("clarity_score", 0.0))},
		{"name": GameManager.text("Stability", "稳定"), "value": float(stats.get("stability_score", 0.0))}
	]
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var value: float = float(row.get("value", 0.0))
		var y := 224.0 + float(index) * 20.0
		_plabel("%s %s" % [str(row.get("name", "")), snapped(value, 0.1)], Vector2(CONTENT_X, y), Vector2(96, 15), 10, Color(0.78, 0.86, 0.90))
		_rect(self, Vector2(CONTENT_X + 100, y + 3), Vector2(94, 8), Color(0.10, 0.14, 0.22))
		var fill_width := clampf(value, 0.0, 100.0) * 0.94
		var fill := _rect(self, Vector2(CONTENT_X + 100, y + 3), Vector2(0, 8), Color(0.45, 0.75, 0.50))
		fill.set_meta("result_width", fill_width)
		stat_bar_fills.append(fill)


func _animate_stat_bars() -> void:
	if stat_bar_fills.is_empty():
		return
	await get_tree().process_frame
	for fill in stat_bar_fills:
		if fill == null or not is_instance_valid(fill):
			continue
		InteractionFeedback.tween_size(fill, Vector2(float(fill.get_meta("result_width", 0.0)), 8), 0.28)
		await get_tree().create_timer(0.08 if not InteractionFeedback.is_reduced_motion() else 0.02).timeout


# Dynamic condition-row slots (spec: UI 条件行重构). Slot 1 (equipment) is
# always shown; slots 2-4 (condition A / condition B / dark adaptation)
# appear only when there is something real to report. Returns the Y
# position immediately below the last slot used, so the caller can place
# feedback_label without overlapping.
const CONDITION_ROW_Y := 283.0
const CONDITION_ROW_H := 12.0


func _add_condition_rows() -> float:
	var y := CONDITION_ROW_Y
	y = _add_equipment_row(y)
	y = _add_condition_row_a(y)
	y = _add_condition_row_b(y)
	y = _add_dark_adaptation_row(y)
	return y


func _add_equipment_row(y: float) -> float:
	# Slot 1: "100mm · 10mm · 80.0x" - always shown.
	var stats := GameManager.calculate_stats()
	var objective := GameManager.get_part(GameManager.equipped_part_id("objective"))
	var eyepiece := GameManager.get_part(GameManager.equipped_part_id("eyepiece"))
	var objective_mm := int(objective.get("aperture_mm", 0))
	var eyepiece_mm := int(eyepiece.get("focal_length_mm", 0))
	var magnification := float(stats.get("magnification", 0.0))
	var equip_line := "%dmm · %dmm · %sx" % [objective_mm, eyepiece_mm, snapped(magnification, 0.1)]
	var font_size := 9
	if bool(GameManager.current_level().get("requires_collimation", false)):
		equip_line += GameManager.text("  Coll. %d%%" % roundi(GameManager.collimation_score()), "  准直 %d%%" % roundi(GameManager.collimation_score()))
		font_size = 8
	_plabel(equip_line, Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), font_size, Color(0.72, 0.80, 0.88))
	return y + CONDITION_ROW_H


func _add_condition_row_a(y: float) -> float:
	# Slot 2: "Seeing视宁度: Poor·差  Cloud云: Thin·薄" - shown when either
	# seeing or cloud cover is defined for this level.
	var environment: Dictionary = GameManager.current_environment()
	var parts: Array[String] = []
	if environment.has("seeing"):
		var seeing_label := str(observation.get("seeing_label", ""))
		if seeing_label == "":
			seeing_label = str(environment.get("seeing", "")).capitalize()
		var seeing_zh := "好"
		match seeing_label:
			"Poor": seeing_zh = "差"
			"Average": seeing_zh = "中"
		parts.append(GameManager.text("Seeing: %s" % seeing_label, "视宁度：%s" % seeing_zh))
	if cloud_cover_level > 0.0:
		var cloud_tier := _cloud_tier_label()
		parts.append(GameManager.text(
			"Clouds: %s" % str(cloud_tier.get("en", "")),
			"云层：%s" % str(cloud_tier.get("zh", ""))
		))
	if parts.is_empty():
		return y
	_plabel("  ".join(parts), Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.95, 0.78, 0.45))
	return y + CONDITION_ROW_H


func _add_condition_row_b(y: float) -> float:
	# Slot 3: "Sky天空: City·城市  Contrast对比: Low·低" - shown when the
	# level defines a sky_brightness tier.
	var environment: Dictionary = GameManager.current_environment()
	if not environment.has("sky_brightness"):
		return y
	var sky_tier := _sky_tier_label()
	var contrast_tier := _contrast_label()
	var line := GameManager.text(
		"Sky: %s  Contrast: %s" % [str(sky_tier.get("en", "")), str(contrast_tier.get("en", ""))],
		"天空：%s  对比度：%s" % [str(sky_tier.get("zh", "")), str(contrast_tier.get("zh", ""))]
	)
	_plabel(line, Vector2(CONTENT_X, y), Vector2(CONTENT_W, CONDITION_ROW_H), 9, Color(0.95, 0.78, 0.45))
	return y + CONDITION_ROW_H


func _add_dark_adaptation_row(y: float) -> float:
	# Compact paired readouts share one narrow condition row. Each owns a real
	# half-width rect so translations cannot draw through one another.
	if not _is_dark_adaptation_target():
		return y
	dark_adaptation_label = _plabel(
		GameManager.text("Dark adaptation: %d%%", "暗适应：%d%%") % int(round(dark_adaptation * 100.0)),
		Vector2(CONTENT_X, y), Vector2(CONTENT_W * 0.49, CONDITION_ROW_H), 7, Color(0.70, 0.82, 0.98)
	)
	averted_vision_label = _plabel(
		GameManager.text("Averted vision: Confirmed", "偏视法：已确认") if averted_vision_confirmed else GameManager.text("Averted vision: Ready", "偏视法：待操作"),
		Vector2(CONTENT_X + CONTENT_W * 0.51, y), Vector2(CONTENT_W * 0.49, CONDITION_ROW_H), 7, Color(0.66, 0.72, 0.80), HORIZONTAL_ALIGNMENT_RIGHT
	)
	_refresh_dark_adaptation_label()
	_refresh_averted_vision_label()
	return y + CONDITION_ROW_H


func _short_feedback(quality: String) -> String:
	if _is_constellation_observation():
		return GameManager.text("Trace the shape you centered, then identify the constellation.", "观察刚才居中的星群形状，再识别对应星座。")
	if observation_mode == "naked_eye":
		return GameManager.text(str(observation.get("feedback_en", "")), str(observation.get("feedback_zh", "")))
	match quality:
		"Excellent":
			return GameManager.text("Clear image. Ready to identify.", "图像清晰，可以识别目标。")
		"Good":
			return GameManager.text("Stable enough to identify.", "足够稳定，可以识别目标。")
		"Fair":
			return GameManager.text("Visible, but slightly unclear.", "可以看到目标，但略有不清。")
		"Poor":
			return GameManager.text("Too blurry. Improve alignment.", "太模糊了，请改进安装对齐。")
		"Failed":
			return GameManager.text("Observation failed. Reassemble or retry.", "观测失败，请重新组装或重试。")
	return GameManager.text("Observation complete.", "观测完成。")


func _add_identify_choices() -> void:
	if identify_choice_ids.is_empty():
		identify_choice_ids = _build_identify_choice_ids()
	var letters := ["A", "B", "C", "D"]
	for index in range(identify_choice_ids.size()):
		var id := identify_choice_ids[index]
		var obj := GameManager.get_object(id)
		if obj.is_empty():
			continue
		var letter := str(letters[index]) if index < letters.size() else str(index + 1)
		var label := "%s. %s" % [letter, GameManager.dict_text(obj, "name").replace("\n", " · ")]
		var button := _pixel_button(label, Vector2(CONTENT_W, 32), 12)
		button.clip_text = true
		button.set_meta("object_id", id)
		button.set_meta("choice_index", index)
		button.pressed.connect(_identify.bind(id))
		choices_box.add_child(button)


func _build_identify_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	var correct_id := str(selected_object.get("id", ""))
	if _is_constellation_observation():
		for data_value in GameManager.constellations_data:
			var data: Dictionary = data_value
			_add_unique(ids, str(data.get("id", "")))
		ids.erase(correct_id)
		ids.shuffle()
		while ids.size() > 3:
			ids.pop_back()
		ids.insert(0, correct_id)
		ids.shuffle()
		return ids
	_add_unique(ids, correct_id)
	_add_unique(ids, str(GameManager.current_target().get("id", "")))
	for id in _distractors_for(correct_id):
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	for id in ["sirius", "betelgeuse", "jupiter", "polaris"]:
		if ids.size() >= 4:
			break
		_add_unique(ids, id)
	if ids.size() > 4:
		ids.resize(4)
	ids.erase(correct_id)
	ids.shuffle()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var correct_index := rng.randi_range(0, ids.size())
	if ids.size() > 0 and correct_index == _last_correct_choice_index:
		correct_index = (correct_index + rng.randi_range(1, ids.size())) % (ids.size() + 1)
	ids.insert(correct_index, correct_id)
	_last_correct_choice_index = correct_index
	return ids


func _set_identify_choices_visible(show_choices: bool) -> void:
	if identify_title_label != null:
		identify_title_label.visible = show_choices
	if choices_box != null:
		choices_box.visible = show_choices


func _show_pre_quiz_guide() -> void:
	_set_identify_choices_visible(false)
	quiz_brief_overlay = Control.new()
	quiz_brief_overlay.name = "PreQuizObjectGuide"
	quiz_brief_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	quiz_brief_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	quiz_brief_overlay.z_index = Z_MODAL_OVERLAY
	add_child(quiz_brief_overlay)
	InteractionFeedback.page_enter(quiz_brief_overlay, Vector2(0, 8))

	_rect(quiz_brief_overlay, Vector2.ZERO, Vector2(1024, 768), Color(0.0, 0.0, 0.0, 0.82))
	_styled_panel(quiz_brief_overlay, Vector2(132, 62), Vector2(760, 642), Color(0.018, 0.032, 0.058, 0.995), COL_GOLD, 3, 2, true)
	_rect(quiz_brief_overlay, Vector2(152, 82), Vector2(720, 2), COL_GOLD.darkened(0.45))
	_plabel_on(quiz_brief_overlay, "OBSERVATORY FIELD MANUAL  //  01", Vector2(162, 88), Vector2(700, 16), 9, Color(0.50, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	_plabel_on(quiz_brief_overlay, GameManager.text("Object Field Guide", "天体辨识指南"), Vector2(164, 108), Vector2(696, 32), 23, COL_GOLD_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	_rect(quiz_brief_overlay, Vector2(180, 146), Vector2(664, 1), Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.48))
	var intro := _plabel_on(
		quiz_brief_overlay,
		GameManager.text(
			"Compare the observed silhouette with these reference records: shape, colour, brightness and object class.",
			"把刚才看到的轮廓与参考记录比较：形状、颜色、亮度和天体类别。"
		),
		Vector2(178, 154), Vector2(668, 38), 11, Color(0.74, 0.84, 0.91), HORIZONTAL_ALIGNMENT_CENTER
	)
	intro.max_lines_visible = 2

	for index in range(identify_choice_ids.size()):
		var id := identify_choice_ids[index]
		var obj := GameManager.get_object(id)
		var column := index % 2
		var row := index / 2
		var card_pos := Vector2(164 + column * 354, 202 + row * 174)
		var card := _styled_panel(quiz_brief_overlay, card_pos, Vector2(338, 156), Color(0.035, 0.060, 0.096, 1.0), Color(0.24, 0.43, 0.62), 2, 1, false)
		_corner(card, Vector2(0, 0), Color(0.44, 0.72, 0.88))
		_corner(card, Vector2(324, 142), Color(0.44, 0.72, 0.88))
		_rect(card, Vector2(10, 36), Vector2(318, 1), Color(0.24, 0.43, 0.62, 0.74))
		var name_text := "%s. %s" % [String.chr(65 + index), GameManager.dict_text(obj, "name").replace("\n", " · ")]
		_plabel_on(card, name_text, Vector2(14, 8), Vector2(306, 24), 14, COL_GOLD_LIGHT)
		var thumbnail_well := _styled_panel(card, Vector2(12, 48), Vector2(76, 94), Color(0.006, 0.014, 0.030, 1.0), Color(0.18, 0.34, 0.50), 1, 0, false)
		var thumbnail_path := _guide_thumbnail_path(id)
		if thumbnail_path != "" and ResourceLoader.exists(thumbnail_path):
			var thumbnail := TextureRect.new()
			thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumbnail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumbnail.texture = load(thumbnail_path) as Texture2D
			thumbnail.position = Vector2(7, 8)
			thumbnail.size = Vector2(62, 62)
			thumbnail_well.add_child(thumbnail)
		_plabel_on(thumbnail_well, GameManager.dict_text(obj, "type").to_upper(), Vector2(4, 72), Vector2(68, 16), 7, Color(0.52, 0.78, 0.90), HORIZONTAL_ALIGNMENT_CENTER)
		var feature := _object_guide_text(obj)
		var feature_label := _plabel_on(card, feature, Vector2(98, 47), Vector2(226, 98), 9, COL_TEXT)
		feature_label.max_lines_visible = 7
		if not InteractionFeedback.is_reduced_motion():
			var final_pos := card.position
			card.position = final_pos + Vector2(0, 8)
			card.modulate.a = 0.0
			var reveal := create_tween().bind_node(card)
			reveal.tween_interval(0.05 + float(index) * 0.055)
			reveal.set_parallel(true)
			reveal.tween_property(card, "position", final_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			reveal.tween_property(card, "modulate:a", 1.0, 0.16)

	var start_button := _pixel_button(GameManager.text("Start Identification", "开始识别"), Vector2(250, 42), 14)
	start_button.position = Vector2(387, 646)
	start_button.pressed.connect(_dismiss_pre_quiz_guide)
	quiz_brief_overlay.add_child(start_button)
	start_button.grab_focus()


func _object_guide_text(obj: Dictionary) -> String:
	var type_text := GameManager.dict_text(obj, "type")
	var clue := GameManager.dict_text(obj, "short_hint")
	var learning := GameManager.dict_text(obj, "learning_text")
	return GameManager.text("Type: %s\n%s\n%s", "类型：%s\n%s\n%s") % [type_text, clue, learning]


func _guide_thumbnail_path(object_id: String) -> String:
	var master_path := OpticalMediaRegistry.master_path(object_id)
	if master_path != "":
		return master_path
	if STATE_TEXTURES.has(object_id):
		return str((STATE_TEXTURES[object_id] as Dictionary).get("clear", ""))
	return str(SPRITE_MAP.get(object_id, ""))


func _dismiss_pre_quiz_guide() -> void:
	quiz_brief_dismissed = true
	if quiz_brief_overlay != null:
		var overlay := quiz_brief_overlay
		quiz_brief_overlay = null
		InteractionFeedback.fade_then(overlay, func() -> void:
			overlay.queue_free()
			call_deferred("_show_focus_tutorial")
		)
	_set_identify_choices_visible(true)


func _identify(choice_id: String) -> void:
	if identify_transition_active:
		return
	call_deferred("_animate_identify_failure_if_needed")
	# Reset any lingering milestone-green from _announce_step_complete.
	feedback_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.88))
	# Concept brief tied to the identification moment (e.g. chromatic
	# aberration on L25): explain what the player is looking at, then let
	# them come back and answer.
	if GameManager.try_story_for_trigger("before_identify", "telescope"):
		return
	if GameManager.try_teaching_intercept("before_identify", "telescope"):
		return
	if requires_focus and not allow_focus_input:
		feedback_label.text = GameManager.text(
			"Install the Focus Knob before trying to identify this target.",
			"请先安装调焦旋钮，再尝试识别这个目标。"
		)
		return
	if not _missing_required_parts().is_empty():
		feedback_label.text = _missing_required_parts_text()
		return
	if drift_enabled and not is_hold_satisfied():
		feedback_label.text = _hold_progress_text()
		return
	if not is_focus_acceptable():
		feedback_label.text = GameManager.text(
			"Adjust focus before identifying.",
			"请先调焦。"
		)
		return
	if choice_id != str(selected_object.get("id", "")):
		feedback_label.text = GameManager.text("Not what you observed. Try again.", "与观测到的目标不符，再试一次。")
		return
	if not is_quality_acceptable():
		# Correct answer, but the observation itself is not good enough:
		# the mission must not complete.
		if requires_focus:
			feedback_label.text = _quality_shortfall_text()
		else:
			feedback_label.text = GameManager.text(
				"Identified, but the observation quality is too low.",
				"识别正确，但观测质量不足。"
			)
		return
	var pending_step := GameManager.next_pending_mission_step()
	if not pending_step.is_empty():
		feedback_label.text = GameManager.text(
			"Not yet - complete: " + GameManager.dict_text(pending_step, "label"),
			"还没完成：" + GameManager.dict_text(pending_step, "label")
		)
		return
	# Observation confirmation is visual only; mission conditions and the
	# completion call remain unchanged.
	identify_transition_active = true
	feedback_label.text = GameManager.text("Observation confirmed...", "观测已确认...")
	feedback_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
	InteractionFeedback.success(choices_box, "observation_confirmed")
	if main_sprite != null:
		InteractionFeedback.pulse(main_sprite, Color(1.10, 1.06, 0.82, 1.0), 0.42)
	await get_tree().create_timer(0.38 if not InteractionFeedback.is_reduced_motion() else 0.10).timeout
	# On success GameManager routes to the Mission Complete card itself.
	var completed := GameManager.complete_current_mission(choice_id, observation)
	if completed:
		return
	identify_transition_active = false
	var target := GameManager.current_target()
	if choice_id != str(target.get("id", "")):
		feedback_label.text = GameManager.text("Correct, but not the mission target.", "识别正确，但不是当前任务目标。")
	else:
		feedback_label.text = GameManager.text("Identified, but quality is too low.", "识别正确，但观测质量不足。")


func _animate_identify_failure_if_needed() -> void:
	if identify_transition_active or not is_inside_tree():
		return
	var control: Control = choices_box
	if requires_focus and not allow_focus_input:
		control = focus_state_label if focus_state_label != null else feedback_label
	elif drift_enabled and not is_hold_satisfied():
		control = tracking_slider if tracking_slider != null else drift_label
	elif not is_focus_acceptable():
		control = focus_slider if focus_slider != null else focus_state_label
	elif not is_quality_acceptable():
		control = cloud_veil if cond_cloud_atten > 0.35 and cloud_veil != null else quality_label
	InteractionFeedback.error(control if control != null else feedback_label)


# ------------------------------------------------------------- scope visual


func _scope_visual() -> Control:
	var root := Control.new()
	root.size = Vector2(640, 620)
	var center := Vector2(318, 300)
	lens_center = center
	effect_seed = fmod(float(str(selected_object.get("id", "")).hash()), 100.0)
	cloud_cover_level = _cloud_cover() if observation_mode != "naked_eye" else 0.0
	if _is_constellation_observation():
		_add_sky_background(root, center)
		_add_scope_stars(root, center)
		_add_constellation_field(root)
		return root
	if observation_mode == "naked_eye":
		# Open night sky, no telescope barrel.
		_circle(root, center - Vector2(262, 262), Vector2(524, 524), Color(0.006, 0.012, 0.032), Color.TRANSPARENT, 0)
	else:
		_circle(root, center - Vector2(218, 218), Vector2(436, 436), Color(0.0, 0.0, 0.0), Color.TRANSPARENT, 0)
		_add_sky_background(root, center)
	_add_scope_stars(root, center)
	_add_target_visual(root, center)
	if observation_mode != "naked_eye":
		_add_cloud_layer(root, center)
	_add_quality_noise(root, center)
	_add_optical_lens_effect(root, center)
	if observation_mode != "naked_eye":
		# Ring occluder ABOVE all lens content: clips drifting sprites /
		# clouds / stars to the circle by repainting the barrel on top.
		# Wrapped in a clipper so the oversized rect never paints over the
		# outer pixel frame (screen-safe rect 16,14 .. 748,748; this root
		# sits at screen 54,98).
		var clipper := Control.new()
		clipper.name = "LensRingOccluderClipper"
		clipper.position = Vector2(-38, -84)
		clipper.size = Vector2(732, 734)
		clipper.clip_contents = true
		clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var occluder := ColorRect.new()
		occluder.position = center - Vector2(450, 450) - clipper.position
		occluder.size = Vector2(900, 900)
		occluder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var occluder_mat := ShaderMaterial.new()
		occluder_mat.shader = LENS_RING_OCCLUDER_SHADER
		occluder.material = occluder_mat
		clipper.add_child(occluder)
		root.add_child(clipper)
	# The peripheral-gaze guide is an operator overlay, not part of the
	# scientific image. It must remain above the ring occluder while its own
	# lens-space clamping keeps it inside the usable circular field.
	_add_averted_vision_guide(root)
	# The detailed telescope image stays optically clean: no barrel artwork,
	# crosshair, or center circle over the observed object. Naked-eye sessions
	# retain their dedicated wide-field reference overlay.
	if observation_mode == "naked_eye":
		_add_observation_reticle(root, center)
	return root


func _add_optical_lens_effect(parent: Control, center: Vector2) -> void:
	if _is_constellation_observation():
		return
	var lens_size := 524.0 if observation_mode == "naked_eye" else 436.0
	var overlay := ColorRect.new()
	overlay.name = "OpticalLensOverlay"
	overlay.position = center - Vector2.ONE * lens_size * 0.5
	overlay.size = Vector2.ONE * lens_size
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = OPTICAL_LENS_SHADER
	material.set_shader_parameter("region_uv_size", Vector2(lens_size / 1024.0, lens_size / 768.0))
	material.set_shader_parameter("circular_lens", 1.0)
	if observation_mode == "naked_eye":
		material.set_shader_parameter("curvature", 0.020)
		material.set_shader_parameter("vignette_strength", 0.075)
		material.set_shader_parameter("chroma_px", 0.06)
		material.set_shader_parameter("glass_highlight", 0.024)
		material.set_shader_parameter("edge_bloom", 0.025)
		material.set_shader_parameter("scanline_strength", 0.004)
		material.set_shader_parameter("lens_rim_strength", 0.028)
		material.set_shader_parameter("lens_caustic_strength", 0.018)
	else:
		material.set_shader_parameter("curvature", 0.088)
		material.set_shader_parameter("vignette_strength", 0.22)
		material.set_shader_parameter("chroma_px", 0.32)
		material.set_shader_parameter("glass_highlight", 0.074)
		material.set_shader_parameter("edge_bloom", 0.12)
		material.set_shader_parameter("scanline_strength", 0.016)
		material.set_shader_parameter("lens_rim_strength", 0.19)
		material.set_shader_parameter("lens_caustic_strength", 0.13)
	overlay.material = material
	parent.add_child(overlay)


func _add_averted_vision_guide(parent: Control) -> void:
	if not _visual_detection_techniques_available():
		return
	averted_vision_guide = AvertedVisionGuide.new()
	averted_vision_guide.name = "AvertedVisionGuide"
	averted_vision_guide.size = Vector2(640, 620)
	averted_vision_guide.z_index = 24
	averted_vision_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	averted_vision_guide.enabled = true
	averted_vision_guide.active = averted_vision_active
	averted_vision_guide.confirmed = averted_vision_confirmed
	averted_vision_guide.adaptation = _eased_dark_adaptation()
	averted_vision_guide.hold_visual = averted_hold_visual
	averted_vision_guide.cursor_progress = averted_hold_visual
	averted_vision_guide.target_position = visual_target_center
	averted_vision_guide.lens_center = lens_center
	averted_vision_guide.lens_radius = 262.0 if observation_mode == "naked_eye" else 218.0
	parent.add_child(averted_vision_guide)


func _is_constellation_observation() -> bool:
	return observation_mode == "constellation" and not GameManager.get_constellation(str(selected_object.get("id", ""))).is_empty()


func _add_constellation_field(parent: Control) -> void:
	constellation_field = ConstellationField.new()
	constellation_field.name = "ConstellationField"
	constellation_field.size = Vector2(640, 620)
	constellation_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	constellation_field.pattern = GameManager.get_constellation(str(selected_object.get("id", ""))).get("stars", [])
	parent.add_child(constellation_field)


func _add_observation_reticle(parent: Control, center: Vector2) -> void:
	var overlay := TextureRect.new()
	overlay.name = "ObservationReticleOverlay"
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.texture = load(EYE_RETICLE_TEXTURE) as Texture2D
	# The open-sky observation stage needs one quiet perimeter reference, not
	# the focusing rings baked into the source artwork.
	var outer_ring_material := ShaderMaterial.new()
	outer_ring_material.shader = NAKED_EYE_OUTER_RING_SHADER
	overlay.material = outer_ring_material
	overlay.position = center - Vector2(280, 280)
	overlay.size = Vector2(560, 560)
	parent.add_child(overlay)


func _add_sky_background(parent: Control, center: Vector2) -> void:
	# Light-pollution background fill, clipped to the inner scope circle.
	# Even a dark site keeps a faint navy glass floor so the curved lens and
	# full-colour rim remain visible instead of reading as a flat black disc.
	var lift := _target_sky_lift()
	var color := Color(0.004, 0.008, 0.020).lerp(Color(0.045, 0.052, 0.075), lift)
	var panel := Panel.new()
	panel.position = center - Vector2(218, 218)
	panel.size = Vector2(436, 436)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(218)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)


func _add_crosshair(parent: Control, center: Vector2) -> void:
	# Thin reticle lines with a wide gap so the target stays unobstructed.
	_rect(parent, center + Vector2(-170, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(55, -1), Vector2(115, 2), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, -170), Vector2(2, 115), COL_CROSSHAIR)
	_rect(parent, center + Vector2(-1, 55), Vector2(2, 115), COL_CROSSHAIR)


func _add_target_visual(parent: Control, scope_center: Vector2) -> void:
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = scope_center + _effect_offset(effect, quality) + drift_offset
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif _is_solid_body_target(id):
		base_alpha = 1.0
	elif effect == "dim" and quality in ["Poor", "Failed"] and not _city_glow_diffuse_target():
		base_alpha *= 0.55
	base_alpha = clampf(base_alpha + _dark_adaptation_alpha_bonus(), 0.0, 1.0)
	# Brightness floor: a solid target never fades below identifiability.
	base_alpha = maxf(base_alpha, _target_alpha_floor())
	if _active_observation_requirements().has("exposure_max"):
		base_alpha = clampf(base_alpha * lerpf(0.42, 1.35, exposure_value), 0.0, 1.0)
	if _is_solid_body_target(id) and observation_mode != "naked_eye":
		base_alpha = 1.0

	var path: String = _sprite_path_for_target(id, quality, effect)
	current_sprite_path = path
	var texture: Texture2D = _load_target_texture(path)

	var has_blur_variant := _has_blur_variant(id)
	var ghost_texture := texture
	if has_blur_variant and STATE_TEXTURES.has(id) and OpticalMediaRegistry.master_path(id) == "":
		var state_textures: Dictionary = STATE_TEXTURES[id]
		ghost_texture = _load_target_texture(str(state_textures["blurry"]))

	var sprite_scale := 1.0
	if observation_mode == "naked_eye":
		sprite_scale = _naked_eye_scale(id)
	else:
		sprite_scale = _magnification_scale() * _object_view_scale(id)
		if base_alpha > 0.0 and _magnification_scale() > 1.0 and not _is_solid_body_target(id):
			# Higher magnification spreads the same light over a larger
			# image: bigger but dimmer, same real telescope trade-off.
			base_alpha *= 0.85
		# The scaled sprite must stay inside the 436px scope circle - the
		# large state textures are already 300-360px at scale 1.0.
		var largest_dim := maxf(
			maxf(texture.get_size().x, texture.get_size().y),
			maxf(ghost_texture.get_size().x, ghost_texture.get_size().y)
		)
		if largest_dim > 0.0:
			if _target_render_mode(id) == "extended_surface":
				# The circular field stop is fixed in lens space above this
				# sprite. Give the science image enough cover for the full
				# allowed +/-300px sky drift plus seeing/effect offsets, so its
				# own rectangular edges can never enter the 436px eyepiece.
				# Keep the fixed lens-space mask fully covered during drift.
				# Magnification is applied inside the material so the science
				# field can zoom without moving its circular boundary.
				sprite_scale = EXTENDED_FIELD_OVERSCAN_SIZE / largest_dim
			elif _target_render_mode(id) == "extended_subject":
				var crop := OpticalMediaRegistry.crop_metadata(id)
				var subject_scale := clampf(float(crop.get("scale", 0.88)), 0.50, 1.20)
				sprite_scale = 436.0 * subject_scale * _magnification_scale() / largest_dim
			elif _is_solid_body_target(id):
				# A fixed field stop is meant to crop high-power lunar and
				# planetary views. The old 380px texture-size cap forced every
				# sufficiently powerful eyepiece back to the same apparent
				# size, so 12mm and 40mm views could become indistinguishable.
				# Keep the transparent source canvas free to grow behind the
				# fixed circular mask; its opaque body remains physically solid.
				sprite_scale = _magnification_scale() * _object_view_scale(id)
			else:
				sprite_scale = minf(sprite_scale, 380.0 / largest_dim)
	display_scale = sprite_scale

	ghost_a = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	ghost_b = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	main_sprite = _add_sprite(parent, texture, target_center, base_alpha, sprite_scale)
	if _is_solid_body_target(id) and observation_mode != "naked_eye":
		# The official planet images use tight transparent canvases. Expand only
		# the drawing control; the shader keeps the sharp source at its original
		# apparent size and uses the added area for a real outward-spreading PSF.
		main_sprite.size = texture.get_size() * SOLID_BODY_OPTICAL_CANVAS_SCALE
		main_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	if has_blur_variant:
		blur_overlay = _add_sprite(parent, ghost_texture, target_center, 0.0, sprite_scale)
	if effect == "dim" and quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, base_alpha)
	if effect == "shaky":
		ghost_a.modulate.a = base_alpha * 0.30
		ghost_a.position += Vector2(-9, 5)
	_setup_turbulence_materials()
	# Environment response is material-driven and refreshed continuously.
	# A one-time city alpha multiplier is incorrect because later focus/cloud
	# refreshes overwrite it and uniformly fading a photo also erases its core.
	# Start the smoothed values converged so the scene doesn't animate in.
	visual_focus_error = focus_error
	visual_target_center = target_center
	visual_base_alpha = base_alpha
	blur_weight = _target_blur_weight()
	cond_turbulence = _target_turbulence()
	cond_sky_lift = _target_sky_lift()
	cond_cloud_atten = 0.0
	_apply_turbulence_uniforms()
	_update_target_visuals()


func _has_blur_variant(id: String) -> bool:
	return (
		(STATE_TEXTURES.has(id) or OpticalMediaRegistry.master_path(id) != "")
		and requires_focus
		and observation_mode != "naked_eye"
	)


func _sprite_path_for_target(id: String, quality: String, effect: String) -> String:
	var clean_master := OpticalMediaRegistry.master_path(id)
	if clean_master != "":
		return clean_master
	if STATE_TEXTURES.has(id):
		var textures: Dictionary = STATE_TEXTURES[id]
		if _has_blur_variant(id):
			# Focus blur is handled by the cross-fade overlay; the base
			# sprite only distinguishes light shortage (dim) vs sharp art.
			# Quality verdict only - visual_effect is a relative hint.
			if quality in ["Poor", "Failed"] and is_focus_acceptable():
				# City glow destroys contrast, not focus. Using the already-dark
				# asset here and then applying the city alpha/noise penalties made
				# a correctly focused galaxy disappear completely. Preserve its
				# focused contour; the sky lift, grain, tint and alpha still show
				# how difficult the observation is.
				var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
				if _is_diffuse_target() and sky_key == "city":
					return str(textures["clear"])
				return str(textures["dim"])
			return str(textures["clear"])
		# Quality verdict ONLY - visual_effect is a relative weakest-stat
		# hint and can read "blurry"/"dim" even at Excellent (same bug class
		# as the L11 mars fix, this is the no-focus/naked-eye branch).
		if quality in ["Poor", "Failed"]:
			return str(textures["dim"])
		if quality == "Fair":
			return str(textures["blurry"])
		return str(textures["clear"])
	return str(SPRITE_MAP.get(id, SPRITE_MAP["polaris"]))


func _load_target_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path)
		if loaded != null:
			return loaded
	var image := Image.load_from_file(path)
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return load(SPRITE_MAP["polaris"])


func _target_render_mode(object_id := "") -> String:
	var resolved_id := object_id
	if resolved_id == "":
		resolved_id = str(selected_object.get("id", ""))
	var registry_entry := OpticalMediaRegistry.entry(resolved_id)
	var declared_mode := str(registry_entry.get("render_mode", "")).strip_edges().to_lower()
	var media_object := selected_object if resolved_id == str(selected_object.get("id", "")) else GameManager.get_object(resolved_id)
	var type_lower := str(media_object.get("type_en", "")).to_lower()
	if declared_mode != "":
		if declared_mode.contains("transparent") or declared_mode.contains("isolated"):
			return "transparent_sprite"
		if declared_mode.contains("field") or declared_mode.contains("extended"):
			# Lunar close-ups are continuous surfaces and need cover/overscan.
			# Deep-sky media is a true-alpha science structure layer rendered
			# over the realtime star field, so no photo boundary exists.
			if resolved_id.begins_with("moon_") or type_lower.contains("lunar"):
				return "extended_surface"
			return "extended_subject"
		return declared_mode
	if str(registry_entry.get("media_class", "")).to_lower().contains("extended"):
		if resolved_id.begins_with("moon_") or type_lower.contains("lunar"):
			return "extended_surface"
		return "extended_subject"
	if type_lower.contains("nebula") or type_lower.contains("galaxy") or type_lower.contains("cluster"):
		return "extended_subject"
	return "transparent_sprite"


func _is_extended_target(object_id := "") -> bool:
	return _target_render_mode(object_id).begins_with("extended_")


func _is_solid_body_target(object_id := "") -> bool:
	var resolved_id := object_id
	if resolved_id == "":
		resolved_id = str(selected_object.get("id", ""))
	if OpticalMediaRegistry.is_isolated_planet(resolved_id):
		return true
	var media_object := selected_object if resolved_id == str(selected_object.get("id", "")) else GameManager.get_object(resolved_id)
	var type_lower := str(media_object.get("type_en", "")).to_lower()
	# "Planetary nebula" is a historical morphology term, not a planet.
	# Substring matching routed M57/M27 through the opaque solid-body branch,
	# which disabled their same-source defocus layer entirely.
	if (
		type_lower.contains("nebula")
		or type_lower.contains("galaxy")
		or type_lower.contains("cluster")
	):
		return false
	return type_lower == "planet" or type_lower == "natural satellite" or type_lower == "moon"


func _solid_body_brightness(quality: String, effect: String) -> float:
	var luminance := 1.0
	match quality:
		"Good":
			luminance = 0.94
		"Fair":
			luminance = 0.84
		"Poor":
			luminance = 0.66
		"Failed":
			luminance = 0.50
	if effect == "dim":
		luminance *= 0.82
	if str(selected_object.get("id", "")) == "saturn":
		# The official Saturn master is intentionally restrained, but at eyepiece
		# scale its rings and globe must remain readable without making the body
		# translucent. Lift RGB only; alpha remains fully opaque on the globe.
		luminance *= 1.28
	# Clouds and low quality attenuate photons, but never turn an opaque
	# planetary surface into a translucent decal over the star field.
	luminance *= lerpf(1.0, 0.55, cond_cloud_atten)
	return clampf(luminance, 0.28, 1.20)


func _solid_body_defocus_screen_radius(weight: float, object_id := "") -> float:
	# Planet masters are large transparent canvases rendered at a small scale.
	# Define the PSF in final eyepiece pixels so distant planets do not receive
	# a token one-pixel blur while larger lunar targets become over-softened.
	var resolved_id := object_id if object_id != "" else str(selected_object.get("id", ""))
	var maximum_radius := 88.0
	match resolved_id:
		"moon", "moon_crater_copernicus", "moon_mare_tranquillitatis", "moon_terminator":
			maximum_radius = 132.0
		"jupiter", "saturn":
			maximum_radius = 188.0
		"mercury", "venus", "mars":
			maximum_radius = 138.0
		"uranus", "neptune":
			maximum_radius = 96.0
	# Keep tiny seeing/collimation residuals from softening a correctly focused
	# planet, while preserving the full broad disk at genuine defocus.
	# A steeper curve decouples tiny seeing residuals from the much larger
	# severe-defocus ceiling: best focus stays crisp, while the far end still
	# blooms quickly enough to lose the source silhouette.
	return lerpf(0.0, maximum_radius, pow(clampf(weight, 0.0, 1.0), 1.55))


func _solid_body_defocus_brightness(weight: float) -> float:
	# Spreading the same photons over a much wider circle lowers surface
	# brightness. Keep enough haze to steer the knob, but never leave a bright,
	# easily identified planet photograph at the far end of the focus travel.
	return lerpf(1.0, 0.38, smoothstep(0.18, 1.0, clampf(weight, 0.0, 1.0)))


func _solid_body_defocus_texture_radius(weight: float, object_id := "") -> float:
	# TextureRect scale is applied after its shader. Compensating here makes
	# the visible blur radius independent of the 1024px source-canvas scale.
	return _solid_body_defocus_screen_radius(weight, object_id) / maxf(display_scale, 0.01)


func _extended_field_environment_shader() -> Shader:
	if extended_field_environment_shader == null:
		extended_field_environment_shader = Shader.new()
		extended_field_environment_shader.code = EXTENDED_FIELD_ENVIRONMENT_SHADER_CODE
	return extended_field_environment_shader


func _extended_field_defocus_shader() -> Shader:
	if extended_field_defocus_shader == null:
		extended_field_defocus_shader = Shader.new()
		extended_field_defocus_shader.code = EXTENDED_FIELD_DEFOCUS_SHADER_CODE
	return extended_field_defocus_shader


func _extended_field_material(defocus := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _extended_field_defocus_shader() if defocus else _extended_field_environment_shader()
	material.set_shader_parameter("magnification_zoom", _magnification_scale())
	if defocus:
		material.set_shader_parameter("blur_radius_px", 0.0)
		material.set_shader_parameter("brightness", 1.0)
	extended_field_materials.append(material)
	return material


func _naked_eye_alpha() -> float:
	# What your eyes can actually see: bright targets clear, deep sky ~gone.
	var visible := bool(selected_object.get("naked_eye_visible", false))
	if not visible:
		return 0.06
	var brightness := float(selected_object.get("brightness", 50.0))
	return clampf(0.35 + brightness / 130.0, 0.35, 1.0)


func _object_view_scale(id: String) -> float:
	# Relative apparent size in the eyepiece - keeps the REAL ordering even
	# though absolute angular scale is compressed for gameplay: the Moon is
	# the only object that fills the view; planets are small resolved discs
	# (Jupiter > Mars); Andromeda is an extended glow, not a wall of light.
	match id:
		"moon":
			return 1.0
		"jupiter":
			return 0.60
		"mars":
			return 0.46
		"andromeda":
			return 0.62
		"sirius":
			return 1.50
		"orion_nebula":
			return 0.70
		# Licensed planet masters are 1024px transparent canvases. These values
		# scale the measured opaque subject, not the canvas, so distant planets
		# remain small resolved discs instead of large photographic decals.
		"mercury": return 0.09
		"venus": return 0.11
		"saturn": return 0.14
		"uranus": return 0.075
		"neptune": return 0.07
		"moon_crater_copernicus", "moon_mare_tranquillitatis", "moon_terminator": return 0.92
		"albireo": return 0.46
		"pleiades": return 0.90
		"m13": return 0.55
		"ring_nebula": return 0.42
		"lagoon_nebula": return 0.82
		"sombrero_galaxy": return 0.68
		"crab_nebula": return 0.62
		"dumbbell_nebula": return 0.58
		"double_cluster": return 0.92
		"whirlpool_galaxy": return 0.66
		"needle_galaxy": return 0.76
	return 1.0


func _magnification_scale() -> float:
	# Higher magnification makes the target visibly larger in the eyepiece
	# (and, per base_alpha above, dimmer) - a real trade-off, not just text.
	# Stars stay point-like regardless of magnification (verdict 9): higher
	# power never turns a star into a resolvable disc.
	var stats: Dictionary = GameManager.calculate_stats()
	var magnification := float(stats.get("magnification", 0.0))
	return _magnification_visual_scale(magnification, _is_star_target())


func _magnification_visual_scale(magnification: float, point_source := false) -> float:
	if point_source:
		return 1.0
	if magnification <= 0.0:
		return 1.0
	# A sub-linear optical scale keeps high-power views usable while making
	# common eyepiece swaps (20/10 mm and 40/12 mm) unmistakable. The fixed
	# field stop clips enlarged subjects naturally; stars remain point sources.
	return clampf(pow(magnification / 40.0, 0.72), 0.72, 2.35)


func _naked_eye_scale(id: String) -> float:
	# No magnification: the Moon is small, planets are just points of light.
	match id:
		"moon":
			return 0.34
		"mars", "jupiter":
			return 0.28
		"orion_nebula", "andromeda":
			return 0.45
	return 0.55


func _refresh_target_sprite() -> void:
	# Re-pick the state texture (clear/blurry/dim) whenever the evaluation
	# changes - the build-time pick goes stale as soon as focus improves.
	if main_sprite == null:
		return
	var id := str(selected_object.get("id", ""))
	var quality := str(observation.get("quality", "Unknown"))
	var effect := str(observation.get("visual_effect", "clear"))
	target_center = lens_center + _effect_offset(effect, quality) + drift_offset
	base_alpha = _quality_alpha(quality)
	if observation_mode == "naked_eye":
		base_alpha = _naked_eye_alpha()
	elif _is_solid_body_target(id):
		base_alpha = 1.0
	elif effect == "dim" and quality in ["Poor", "Failed"] and not _city_glow_diffuse_target():
		base_alpha *= 0.55
	base_alpha = clampf(base_alpha + _dark_adaptation_alpha_bonus(), 0.0, 1.0)
	# Brightness floor: a solid target never fades below identifiability.
	base_alpha = maxf(base_alpha, _target_alpha_floor())
	if _active_observation_requirements().has("exposure_max"):
		base_alpha = clampf(base_alpha * lerpf(0.42, 1.35, exposure_value), 0.0, 1.0)
	if _is_solid_body_target(id) and observation_mode != "naked_eye":
		base_alpha = 1.0
	var path := _sprite_path_for_target(id, quality, effect)
	if path != current_sprite_path:
		current_sprite_path = path
		var texture: Texture2D = _load_target_texture(path)
		main_sprite.texture = texture
		main_sprite.size = texture.get_size()
		if blur_overlay == null:
			# No cross-fade overlay: ghosts share the base texture.
			ghost_a.texture = texture
			ghost_a.size = texture.get_size()
			ghost_b.texture = texture
			ghost_b.size = texture.get_size()
	if _is_solid_body_target(id) and observation_mode != "naked_eye":
		var solid_luminance := _solid_body_brightness(quality, effect)
		main_sprite.modulate = Color(solid_luminance, solid_luminance, solid_luminance, 1.0)
	elif effect == "dim" and quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
		main_sprite.modulate = Color(0.62, 0.62, 0.74, main_sprite.modulate.a)
	else:
		var rgb := 1.0
		if quality in ["Poor", "Failed"] and observation_mode != "naked_eye":
			# Contrast flattening for poor/failed quality (grain layer above
			# handles the noise half of this; this is the color-desaturation half).
			rgb *= 0.85
		if averted_vision_active and _is_visual_detection_target():
			# Averted vision: subtle contour brighten, not a flat clean-up.
			rgb *= AVERTED_VISION_BRIGHTEN
		main_sprite.modulate = Color(rgb, rgb, rgb, main_sprite.modulate.a)
	_apply_extended_field_environment()
	_rebuild_quality_noise()


func _cloud_alpha_multiplier() -> float:
	# Clouds crossing the target darken it in real time - the 0.6s
	# re-evaluation loop (_advance_conditions) applies the same factor to
	# the actual quality math via extra_context["cloud_attenuation"].
	# Solid bright bodies (Moon, planets, stars) keep a floor so a cloud dims
	# them but can never turn them into an unreadable black disc. Faint diffuse
	# targets keep the full range - fading out IS their observing challenge.
	var raw := 1.0 - 0.75 * cond_cloud_atten
	if _is_extended_target():
		# Local cloud sprites and the dark veil already provide spatial
		# obstruction. A restrained integrated attenuation keeps the picture
		# aligned with the area-sampled score instead of dimming it twice.
		return 1.0 - 0.25 * cond_cloud_atten
	return maxf(raw, 0.45)


func _target_alpha_floor() -> float:
	# Minimum brightness a lit target may reach after seeing/cloud/low-light so
	# it is always still IDENTIFIABLE. Diffuse deep-sky is allowed to go faint.
	if _is_extended_target():
		return 0.12
	return 0.55


func _city_glow_diffuse_target() -> bool:
	return _is_diffuse_target() and str(GameManager.current_environment().get("sky_brightness", "")).to_lower() == "city"


func _update_target_visuals() -> void:
	if main_sprite == null:
		return
	_refresh_target_sprite()
	_update_star_field_optics()
	var collimation_severity := _collimation_severity()
	if not requires_focus and collimation_severity <= 0.001:
		return
	# Defocus rendering, driven by SMOOTHED values so quantized inputs
	# (slider steps, quality tiers) never snap the image around.
	# NOTE: TextureRect scales from its top-left corner, so centering must
	# use size * display_scale, not the raw texture size.
	var spread := visual_focus_error * 130.0
	var solid_body := _is_solid_body_target() and observation_mode != "naked_eye"
	var cloud_mult := 1.0 if solid_body else _cloud_alpha_multiplier()
	var ghost_alpha := clampf(visual_focus_error * 2.6, 0.0, 0.55) * visual_base_alpha * cloud_mult
	var collimation_blur := collimation_severity * (0.24 if _is_star_target() else 0.42)
	var combined_blur := maxf(blur_weight, collimation_blur)
	if blur_overlay != null:
		# The same-source optical blur is the primary defocus cue. Ghosts remain
		# a restrained secondary aberration instead of carrying the whole effect.
		ghost_alpha *= 0.34
	var origin := visual_target_center - main_sprite.size * display_scale * 0.5
	var point_source := _is_star_target() and observation_mode != "naked_eye"
	if solid_body:
		# Opaque bodies use one continuously blurred source. Cross-fading two
		# translucent copies would let background stars leak through the disk.
		main_sprite.modulate.a = 1.0
		if blur_overlay != null:
			blur_overlay.visible = false
			blur_overlay.modulate.a = 0.0
		if turbulence_material_main != null:
			var solid_blur := _solid_body_defocus_texture_radius(combined_blur)
			turbulence_material_main.set_shader_parameter("blur_radius_px", solid_blur)
			turbulence_material_main.set_shader_parameter("defocus_amount", combined_blur)
			turbulence_material_main.set_shader_parameter("brightness", _solid_body_defocus_brightness(combined_blur))
	elif point_source:
		# A star is a point source at the same infinity focus as the catalog
		# field. Preserve its photon energy while the PSF expands; fading the
		# clear sprite against a sparse blur copy made Sirius disappear halfway
		# through a focus adjustment.
		main_sprite.modulate.a = visual_base_alpha * cloud_mult
		if blur_overlay != null:
			blur_overlay.visible = false
			blur_overlay.modulate.a = 0.0
		if target_star_psf_material != null:
			target_star_psf_material.set_shader_parameter("defocus", combined_blur)
			target_star_psf_material.set_shader_parameter("seeing", cond_turbulence)
			target_star_psf_material.set_shader_parameter("brightness", lerpf(1.0, 0.82, combined_blur))
		for material in target_star_psf_ghost_materials:
			material.set_shader_parameter("defocus", combined_blur)
			material.set_shader_parameter("seeing", cond_turbulence)
			material.set_shader_parameter("brightness", lerpf(1.0, 0.82, combined_blur))
	elif blur_overlay != null:
		# Cross-fade: blurry photo dissolves into the sharp art.
		# At full defocus the sharp base must be completely hidden. Leaving even
		# a small clear-art alpha made some diffuse targets appear to switch back
		# to their sharp texture after the focus input stopped.
		blur_overlay.visible = combined_blur > 0.002
		main_sprite.modulate.a = visual_base_alpha * (1.0 - combined_blur) * cloud_mult
		blur_overlay.modulate.a = visual_base_alpha * combined_blur * cloud_mult
		blur_overlay.position = visual_target_center - blur_overlay.size * display_scale * 0.5
		if turbulence_material_blur != null:
			# A continuous, inexpensive multi-sample PSF removes high-frequency
			# detail on Web builds. Radius and brightness both follow real focus.
			var optical_blur := lerpf(0.8, 32.0, pow(combined_blur, 0.72))
			turbulence_material_blur.set_shader_parameter("blur_radius_px", optical_blur)
			turbulence_material_blur.set_shader_parameter("brightness", lerpf(1.0, 0.48, combined_blur))
			if not _is_extended_target():
				turbulence_material_blur.set_shader_parameter("defocus_amount", combined_blur)
	else:
		main_sprite.modulate.a = visual_base_alpha * clampf(1.0 - visual_focus_error * 1.1, 0.30, 1.0) * cloud_mult
	main_sprite.position = origin
	ghost_a.scale = Vector2.ONE * display_scale
	ghost_b.scale = Vector2.ONE * display_scale
	ghost_a.rotation = 0.0
	ghost_b.rotation = 0.0
	if solid_body:
		# Planets and the Moon are one opaque optical image. Defocus is already
		# applied by OPTICAL_TARGET_STATE_SHADER, so offset duplicate sprites
		# would create a false multi-image "sticker" instead of a broadened PSF.
		ghost_a.modulate.a = 0.0
		ghost_b.modulate.a = 0.0
		return
	if bool(GameManager.current_level().get("chromatic_aberration", false)):
		# The separation remains visible at best focus. Extended targets need a
		# wider split than star points so the colored rims read at the same scale.
		var target_scale := 1.65 if _is_diffuse_target() else (1.30 if not _is_star_target() else 1.0)
		var chroma_offset := (12.0 + visual_focus_error * 20.0) * target_scale
		# Colour separation is an edge aberration, not three equally bright
		# candidate stars. Keep the real stellar core dominant so its intrinsic
		# blue/white/yellow/red colour remains usable for identification.
		var chroma_alpha := 0.50 if _is_diffuse_target() else (0.44 if _is_star_target() else 0.60)
		ghost_a.modulate = Color(1.0, 0.12, 0.18, visual_base_alpha * chroma_alpha * cloud_mult)
		ghost_b.modulate = Color(0.10, 0.36, 1.0, visual_base_alpha * chroma_alpha * cloud_mult)
		ghost_a.position = visual_target_center - ghost_a.size * display_scale * 0.5 + Vector2(chroma_offset, 0)
		ghost_b.position = visual_target_center - ghost_b.size * display_scale * 0.5 - Vector2(chroma_offset, 0)
	else:
		var coma_direction := _collimation_direction()
		var coma_tail := coma_direction * collimation_severity * (34.0 if _is_star_target() else 20.0)
		# Keep severe coma legible even when the quality verdict has already
		# dimmed the core; otherwise the player only sees "dark" and cannot
		# diagnose the mirror alignment problem from the star shape.
		var coma_alpha := collimation_severity * (0.48 if _is_star_target() else 0.30) * maxf(visual_base_alpha, 0.65) * cloud_mult
		ghost_a.modulate = Color(0.72, 0.88, 1.0, maxf(ghost_alpha, coma_alpha))
		ghost_a.position = visual_target_center - ghost_a.size * display_scale * 0.5 + Vector2(spread, spread * 0.6) + coma_tail
		ghost_b.modulate = Color(1.0, 0.78, 0.40, maxf(ghost_alpha * 0.8, coma_alpha * 0.55))
		ghost_b.position = visual_target_center - ghost_b.size * display_scale * 0.5 + Vector2(-spread * 0.8, spread * 0.4) + coma_tail * 0.48
		if _is_star_target() and collimation_severity > 0.01:
			ghost_a.pivot_offset = ghost_a.size * 0.5
			ghost_b.pivot_offset = ghost_b.size * 0.5
			ghost_a.rotation = coma_direction.angle()
			ghost_b.rotation = coma_direction.angle()
			ghost_a.scale = Vector2(display_scale * (1.0 + collimation_severity * 0.55), display_scale * (1.0 - collimation_severity * 0.12))
			ghost_b.scale = Vector2(display_scale * (1.0 + collimation_severity * 0.28), display_scale)
		elif point_source:
			# Defocus is already represented by the physical point-spread
			# material. Duplicate offset stars would stay artificially sharp
			# and make the target look detached from the surrounding field.
			ghost_a.modulate.a = 0.0
			ghost_b.modulate.a = 0.0
	if point_source:
		_sync_target_star_psf_tints()


func _setup_turbulence_materials() -> void:
	# Only planets/moon get the UV-distortion shader (verdict 9): stars
	# flicker via alpha/position only, nebula/galaxy breathe via alpha only.
	turbulence_material_main = null
	turbulence_material_blur = null
	turbulence_material_ghost = null
	target_star_psf_material = null
	target_star_psf_ghost_materials.clear()
	extended_field_materials.clear()
	var extended_field := _is_extended_target()
	var solid_body := _is_solid_body_target() and observation_mode != "naked_eye"
	if extended_field and main_sprite != null:
		var field_main := _extended_field_material(false)
		main_sprite.material = field_main
		if ghost_a != null:
			ghost_a.material = _extended_field_material(false)
			ghost_b.material = _extended_field_material(false)
	elif solid_body and main_sprite != null:
		var solid_material := ShaderMaterial.new()
		solid_material.shader = OPTICAL_TARGET_STATE_SHADER
		solid_material.set_shader_parameter("blur_radius_px", 0.0)
		solid_material.set_shader_parameter("defocus_amount", 0.0)
		solid_material.set_shader_parameter("brightness", 1.0)
		solid_material.set_shader_parameter("source_uv_scale", SOLID_BODY_OPTICAL_CANVAS_SCALE)
		main_sprite.material = solid_material
		turbulence_material_main = solid_material
	elif _is_star_target() and observation_mode != "naked_eye" and main_sprite != null:
		var point_shader := Shader.new()
		point_shader.code = TARGET_STAR_PSF_SHADER_CODE
		var point_material := _target_star_material(point_shader)
		main_sprite.material = point_material
		target_star_psf_material = point_material
		if ghost_a != null and ghost_b != null:
			var ghost_a_material := _target_star_material(point_shader)
			var ghost_b_material := _target_star_material(point_shader)
			ghost_a.material = ghost_a_material
			ghost_b.material = ghost_b_material
			target_star_psf_ghost_materials.append(ghost_a_material)
			target_star_psf_ghost_materials.append(ghost_b_material)
	elif not _is_star_target() and not _is_diffuse_target() and main_sprite != null:
		var mat_main := ShaderMaterial.new()
		mat_main.shader = TURBULENCE_SHADER
		main_sprite.material = mat_main
		turbulence_material_main = mat_main
	if blur_overlay != null and not _is_star_target():
		var mat_blur := _extended_field_material(true) if extended_field else ShaderMaterial.new()
		if not extended_field:
			mat_blur.shader = OPTICAL_TARGET_STATE_SHADER
		mat_blur.set_shader_parameter("blur_radius_px", 5.0)
		if not extended_field:
			mat_blur.set_shader_parameter("defocus_amount", 0.0)
		mat_blur.set_shader_parameter("brightness", 0.76)
		blur_overlay.material = mat_blur
		turbulence_material_blur = mat_blur
	elif blur_overlay != null:
		# Point sources are rendered entirely by TARGET_STAR_PSF_SHADER_CODE.
		# Keep the legacy state texture hidden and material-free so WebGL never
		# compiles the solid-body convolution shader for an unused star layer.
		blur_overlay.material = null
		blur_overlay.visible = false
		blur_overlay.modulate.a = 0.0
	if not extended_field and not _is_star_target() and not _is_diffuse_target() and ghost_a != null:
		var mat_ghost := ShaderMaterial.new()
		mat_ghost.shader = TURBULENCE_SHADER
		ghost_a.material = mat_ghost
		ghost_b.material = mat_ghost
		turbulence_material_ghost = mat_ghost
	_apply_extended_field_environment()


func _target_star_material(point_shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = point_shader
	material.set_shader_parameter("defocus", 0.0)
	material.set_shader_parameter("seeing", 0.0)
	material.set_shader_parameter("brightness", 1.0)
	material.set_shader_parameter("psf_tint", Color.WHITE)
	material.set_shader_parameter("source_tint", _target_star_source_tint())
	material.set_shader_parameter("sharp_core_sigma", 0.0065)
	material.set_shader_parameter("halo_strength", 0.10)
	material.set_shader_parameter("source_art_mix", 1.0 if str(selected_object.get("id", "")) == "sirius" else 0.0)
	return material


func _target_star_source_tint() -> Color:
	# The analytical out-of-focus PSF cannot sample a second center texel on
	# every Web renderer. Keep the star's catalog colour explicit instead.
	# These are deliberately display-calibrated rather than near-white RGB
	# values: on an SDR canvas the old pale tints clipped perceptually to the
	# same white core, making a colour-identification quiz impossible.
	match str(selected_object.get("id", "")):
		"sirius", "vega":
			return Color(0.34, 0.62, 1.0, 1.0)
		"polaris":
			return Color(0.94, 0.90, 0.78, 1.0)
		"betelgeuse":
			return Color(1.0, 0.28, 0.10, 1.0)
		"arcturus":
			return Color(1.0, 0.46, 0.14, 1.0)
		"canopus":
			return Color(1.0, 0.72, 0.30, 1.0)
		"alpha_centauri":
			return Color(1.0, 0.78, 0.42, 1.0)
		"proxima":
			return Color(1.0, 0.20, 0.08, 1.0)
	var color_name := str(selected_object.get("color", "")).to_lower()
	if color_name.contains("red") or color_name.contains("orange"):
		return Color(1.0, 0.38, 0.14, 1.0)
	if color_name.contains("blue"):
		return Color(0.38, 0.66, 1.0, 1.0)
	if color_name.contains("yellow"):
		return Color(1.0, 0.76, 0.36, 1.0)
	return Color(0.90, 0.92, 0.96, 1.0)


func _sync_target_star_psf_tints() -> void:
	# The point-source shader intentionally ignores CanvasItem COLOR because
	# TextureRect can feed source alpha through it and crop the analytical PSF.
	# Pass each image's tint explicitly so main and chromatic/coma images keep
	# independent colors and alpha while sharing the same optical focus.
	if target_star_psf_material != null and main_sprite != null:
		target_star_psf_material.set_shader_parameter("psf_tint", main_sprite.modulate)
	if target_star_psf_ghost_materials.size() >= 2 and ghost_a != null and ghost_b != null:
		target_star_psf_ghost_materials[0].set_shader_parameter("psf_tint", ghost_a.modulate)
		target_star_psf_ghost_materials[1].set_shader_parameter("psf_tint", ghost_b.modulate)


func _add_sprite(parent: Control, texture: Texture2D, center: Vector2, alpha: float, sprite_scale: float = 1.0) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	# These are photographic observation masters. Linear sampling keeps their
	# short alpha edge and limb gradient clean; pixel UI assets use separate
	# controls and retain nearest-neighbour filtering.
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	icon.size = texture.get_size()
	icon.scale = Vector2.ONE * sprite_scale
	icon.position = center - icon.size * sprite_scale * 0.5
	icon.modulate = Color(1, 1, 1, alpha)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _add_scope_stars(parent: Control, scope_center: Vector2) -> void:
	star_layer_nodes.clear()
	star_field_psf_materials.clear()
	star_field_psf_shader = Shader.new()
	star_field_psf_shader.code = STAR_FIELD_PSF_SHADER_CODE
	for sharp_sigma in [0.020, 0.027, 0.035]:
		var material := ShaderMaterial.new()
		material.shader = star_field_psf_shader
		material.set_shader_parameter("sharp_sigma", sharp_sigma)
		star_field_psf_materials.append(material)
	# All star dots live inside one container so drift (E2) can translate the
	# whole star field with a single position set - "the sky is turning",
	# not each star repositioned individually.
	star_layer_container = Control.new()
	star_layer_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_layer_container.position = drift_offset
	parent.add_child(star_layer_container)
	# REAL sky: stars come from the deep HYG catalog (mag <= 8) projected
	# around the current aim direction - the same star field the player saw
	# at the sky observation deck, never a random sprinkle.
	var fov_radius := SCOPE_FOV_RADIUS_DEG
	var mag_limit := 8.0
	if observation_mode == "naked_eye":
		fov_radius = EYE_FOV_RADIUS_DEG
		mag_limit = 5.0
	else:
		# Light pollution raises the limiting magnitude: faint stars drown
		# in the bright sky first - "fewer, brighter dots survive".
		var sky_key := str(GameManager.current_environment().get("sky_brightness", "")).to_lower()
		match sky_key:
			"city":
				mag_limit = 6.2
			"suburban":
				mag_limit = 7.2
	_add_real_sky_stars(star_layer_container, scope_center, fov_radius, mag_limit)
	_update_star_field_optics()


static var _deep_stars_cache: Array = []


func _load_deep_stars() -> Array:
	# Parsed once per session (static): {"stars": [[ra_hours, dec_deg, mag],
	# ...]} sorted by magnitude ascending (brightest first).
	if not _deep_stars_cache.is_empty():
		return _deep_stars_cache
	var file := FileAccess.open(DEEP_STARS_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		var data: Dictionary = parsed
		_deep_stars_cache = data.get("stars", [])
	return _deep_stars_cache


func _current_aim() -> Vector2:
	# (azimuth, altitude) the telescope is pointed at. Capture tools / tests
	# enter without a sky aim - fall back to a fixed patch of real sky so the
	# view stays deterministic.
	var aim: Dictionary = GameManager.last_sky_aim
	if bool(aim.get("valid", false)):
		return Vector2(float(aim.get("azimuth", 150.0)), float(aim.get("altitude", 45.0)))
	return Vector2(150.0, 45.0)


func _add_real_sky_stars(parent: Control, scope_center: Vector2, fov_radius: float, mag_limit: float) -> void:
	var stars: Array = _load_deep_stars()
	if stars.is_empty():
		return
	# Point-source targets are rendered separately with their intrinsic colour
	# and optical response.  The HYG field contains the same bright stars, so
	# leaving the selected entry here stacks a neutral-white PSF over the target
	# (Sirius consequently looked white in the eyepiece but blue in the result).
	var selected_target_radec: Dictionary = {}
	if _is_star_target():
		selected_target_radec = GameManager.object_radec(str(selected_object.get("id", "")))
	var service := SkyPositionService.new()
	service.load_config()
	# Eyepiece star field uses the player's actual observing site too.
	var loc: Dictionary = GameManager.observing_location()
	var latitude: float = float(loc.get("lat", 34.0522))
	var longitude: float = float(loc.get("lon", -118.2437))
	var utc_now: Dictionary = Time.get_datetime_dict_from_system(true)
	var aim := _current_aim()
	var aim_alt_rad := deg_to_rad(aim.y)
	var az_scale := cos(aim_alt_rad)
	# Cheap declination pre-filter: the aim direction's declination band is
	# the only place FOV stars can live, so 41k catalog rows shrink to a few
	# hundred full alt/az computations.
	var lat_rad := deg_to_rad(latitude)
	var aim_dec_rad := asin(
		sin(aim_alt_rad) * sin(lat_rad)
		+ cos(aim_alt_rad) * cos(lat_rad) * cos(deg_to_rad(aim.x))
	)
	var aim_dec := rad_to_deg(aim_dec_rad)
	var dec_margin := fov_radius + 2.0
	var added := 0
	for star_value in stars:
		if not star_value is Array:
			continue
		var star: Array = star_value
		if star.size() < 3:
			continue
		if _catalog_star_matches_selected_target(star, selected_target_radec):
			continue
		var magnitude := float(star[2])
		if magnitude > mag_limit:
			break  # sorted by magnitude - nothing fainter can qualify
		if absf(float(star[1]) - aim_dec) > dec_margin:
			continue
		var alt_az: Dictionary = service.calculate_alt_az_from_ra_dec(
			float(star[0]), float(star[1]), latitude, longitude, utc_now
		)
		var d_alt := float(alt_az.get("altitude", -90.0)) - aim.y
		var d_az := wrapf(float(alt_az.get("azimuth", 0.0)) - aim.x, -180.0, 180.0) * az_scale
		if Vector2(d_az, d_alt).length() > fov_radius:
			continue
		var pos := scope_center + Vector2(d_az, -d_alt) / fov_radius * 205.0
		# Brightness from real magnitude: alpha lives in the rect color so
		# modulate stays free for the twinkle/dark-adaptation channel.
		var alpha := clampf(0.95 - magnitude * 0.088, 0.22, 0.95)
		var dot_size := 2.0
		if magnitude <= 1.5:
			dot_size = 4.0
		elif magnitude <= 3.5:
			dot_size = 3.0
		var material_index := 0
		if dot_size >= 4.0:
			material_index = 2
		elif dot_size >= 3.0:
			material_index = 1
		var render_size := Vector2.ONE * STAR_FIELD_PSF_BOX_SIZE
		var star_rect := _rect(
			parent,
			pos - render_size * 0.5,
			render_size,
			Color(0.88, 0.90, 0.97, alpha)
		)
		star_rect.material = star_field_psf_materials[material_index]
		star_layer_nodes.append(star_rect)
		added += 1
		if added >= 170:
			break  # brightest-first cap keeps the node count sane


func _catalog_star_matches_selected_target(star: Array, target_radec: Dictionary) -> bool:
	if star.size() < 2 or target_radec.is_empty():
		return false
	var target_ra_hours := float(target_radec.get("ra_hours", NAN))
	var target_dec_degrees := float(target_radec.get("dec_degrees", NAN))
	if is_nan(target_ra_hours) or is_nan(target_dec_degrees):
		return false
	var delta_ra_degrees := wrapf(
		(float(star[0]) - target_ra_hours) * 15.0,
		-180.0,
		180.0
	) * cos(deg_to_rad(target_dec_degrees))
	var delta_dec_degrees := float(star[1]) - target_dec_degrees
	return Vector2(delta_ra_degrees, delta_dec_degrees).length() <= CATALOG_TARGET_DEDUP_RADIUS_DEG


func _add_cloud_layer(parent: Control, scope_center: Vector2) -> void:
	# Moving translucent wisps make the current cloud attenuation legible.
	# Their overlap is also what lowers the actual observation score.
	cloud_nodes.clear()
	cloud_velocities.clear()
	cloud_strengths.clear()
	if cloud_cover_level <= 0.0:
		return
	var tier := cloud_tier_index()  # 1 Thin / 2 Moderate / 3 Heavy
	var alpha_for_tier := 0.28
	match tier:
		2:
			alpha_for_tier = 0.5
		3:
			alpha_for_tier = 0.75

	cloud_veil = Panel.new()
	cloud_veil.position = scope_center - Vector2(218, 218)
	cloud_veil.size = Vector2(436, 436)
	var veil_style := StyleBoxFlat.new()
	# ABSORPTION, not reflection: at night an eyepiece cloud shows as the
	# field going DARK (starlight absorbed), never as a bright gray haze.
	veil_style.bg_color = Color(0.010, 0.014, 0.026)
	veil_style.set_corner_radius_all(218)
	cloud_veil.add_theme_stylebox_override("panel", veil_style)
	cloud_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud_veil.modulate.a = 0.0
	parent.add_child(cloud_veil)

	var count: int = clampi(1 + tier, 2, 4)
	for i in range(count):
		var tex_path: String = CLOUD_TEXTURES[i % CLOUD_TEXTURES.size()]
		var texture: Texture2D = _load_target_texture(tex_path)
		var cloud := TextureRect.new()
		cloud.texture = texture
		cloud.size = texture.get_size()
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Near-black wisps: clouds OCCLUDE starlight (the target goes patchy
		# and dark as one drifts across), they do not glow white.
		cloud.modulate = Color(0.012, 0.016, 0.030, 0.50 + alpha_for_tier * 0.40)
		# Deterministic per-index seed: same level always drifts the same
		# way, but the field still fills the scope circle unevenly.
		var seed_angle: float = fmod(float(i) * 137.5 + effect_seed, 360.0) * PI / 180.0
		var start_offset := Vector2(cos(seed_angle), sin(seed_angle) * 0.5) * (60.0 + float(i) * 35.0)
		cloud.position = scope_center + start_offset - cloud.size * 0.5
		var speed: float = 8.0 + fmod(float(i) * 3.7, 8.0)
		var direction := Vector2(1.0, 0.15 + fmod(float(i), 3.0) * 0.05).normalized()
		if i % 2 == 1:
			direction.x = -direction.x
		cloud_velocities.append(direction * speed)
		cloud_strengths.append(alpha_for_tier)
		parent.add_child(cloud)
		cloud_nodes.append(cloud)


func _add_quality_noise(parent: Control, scope_center: Vector2) -> void:
	# Quality "grain" shader layer replaces the old white-dot noise system:
	# a single shimmering ColorRect masked to the scope circle, intensity
	# smoothly chased toward the current quality tier (never a hard cut).
	if observation_mode == "naked_eye":
		return
	grain_layer = ColorRect.new()
	grain_layer.position = scope_center - Vector2(218, 218)
	grain_layer.size = Vector2(436, 436)
	grain_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GRAIN_SHADER
	mat.set_shader_parameter("intensity", 0.0)
	grain_layer.material = mat
	grain_material = mat
	parent.add_child(grain_layer)
	target_grain_intensity = _grain_intensity_for_quality(str(observation.get("quality", "Unknown")))
	grain_intensity = target_grain_intensity
	mat.set_shader_parameter("intensity", grain_intensity)


func _grain_intensity_for_quality(quality: String) -> float:
	match quality:
		"Excellent":
			return 0.0
		"Good":
			return 0.03
		"Fair":
			return 0.08
		"Poor":
			return 0.16
		"Failed":
			return 0.30
	return 0.0


func _rebuild_quality_noise() -> void:
	# Retarget the grain intensity toward the current quality tier; the
	# actual value is chased in _advance_conditions (no hard cuts).
	var quality := str(observation.get("quality", "Unknown"))
	target_grain_intensity = _grain_intensity_for_quality(quality)
	if grain_material == null:
		return
	if noise_quality == quality:
		return
	noise_quality = quality


# ------------------------------------------------------------------- logic


func _distractors_for(id: String) -> Array[String]:
	match id:
		"moon": return ["jupiter", "sirius"]
		"mars": return ["jupiter", "betelgeuse"]
		"jupiter": return ["mars", "moon"]
		"orion_nebula": return ["andromeda", "betelgeuse"]
		"andromeda": return ["orion_nebula", "sirius"]
		# Star vs star confusions teach color/context identification.
		"sirius": return ["canopus", "polaris"]
		"arcturus": return ["betelgeuse", "canopus"]
		"canopus": return ["sirius", "arcturus"]
		"alpha_centauri": return ["proxima", "sirius"]
		"proxima": return ["alpha_centauri", "betelgeuse"]
	return ["sirius", "betelgeuse"]


func _mystery_description(obj: Dictionary) -> Dictionary:
	var id := str(obj.get("id", ""))
	if _is_constellation_observation():
		return {"en": "a complete pattern of bright field stars", "zh": "一整组明亮的星群图形"}
	match id:
		"moon":
			if str(GameManager.current_level().get("variation", "")) == "lunar_detail_comparison":
				return {
					"en": "a resolved lunar disk with dark maria and a cratered bright rim",
					"zh": "能分辨暗色月海与明亮撞击坑边缘的月面圆盘"
				}
			return {"en": "bright round object", "zh": "明亮圆形目标"}
		"mars", "jupiter":
			return {"en": "small disk-like object", "zh": "小圆盘状目标"}
		"orion_nebula":
			return {"en": "faint cloud-like object", "zh": "淡淡云雾状目标"}
		"andromeda":
			return {"en": "faint oval glow", "zh": "淡淡椭圆光斑"}
	return {"en": "star-like object", "zh": "星点状目标"}


func _effect_offset(effect: String, quality: String) -> Vector2:
	if effect == "shaky":
		return Vector2(10, -7)
	match quality:
		"Fair":
			return Vector2(6, -4)
		"Poor":
			return Vector2(12, 8)
	return Vector2.ZERO


func _quality_alpha(quality: String) -> float:
	match quality:
		"Excellent": return 1.0
		"Good": return 0.92
		"Fair": return 0.62
		"Poor": return 0.36
		"Failed": return 0.14
	return 0.80


func _quality_color(quality: String) -> Color:
	match quality:
		"Excellent": return Color(0.35, 1.0, 0.55)
		"Good": return Color(0.58, 0.92, 0.36)
		"Fair": return Color(0.95, 0.82, 0.28)
		"Poor": return Color(1.0, 0.55, 0.28)
		"Failed": return Color(1.0, 0.24, 0.24)
	return COL_TEXT


func _add_unique(ids: Array[String], id: String) -> void:
	if id != "" and not ids.has(id):
		ids.append(id)


# ----------------------------------------------------------------- helpers


func _pixel_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 3, false)


func _gold_panel(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	return _styled_panel(parent, pos, size, COL_PANEL, COL_GOLD, 3, 3, true)


func _pixel_frame(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, corner: Color) -> Panel:
	return _styled_panel(parent, pos, size, fill, border, 3, 4, true, corner)


func _styled_panel(parent: Control, pos: Vector2, size: Vector2, fill: Color, border: Color, border_width: int, radius: int, decorated: bool, corner_color: Color = COL_GOLD) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	if decorated:
		_corner(parent, pos, corner_color)
		_corner(parent, pos + Vector2(size.x - 14, 0), corner_color)
		_corner(parent, pos + Vector2(0, size.y - 14), corner_color)
		_corner(parent, pos + size - Vector2(14, 14), corner_color)
	return panel


func _corner(parent: Control, pos: Vector2, color: Color) -> void:
	_rect(parent, pos, Vector2(12, 4), color)
	_rect(parent, pos, Vector2(4, 12), color)


func _pixel_button(text: String, min_size: Vector2 = Vector2(194, 32), font_size: int = 13) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.09, 0.15, 0.25), COL_BLUE_BORDER))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.13, 0.23, 0.34), COL_GOLD_LIGHT))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.15, 0.08), COL_GOLD_LIGHT))
	return button


func _hud_asset(path: String, rect: Rect2) -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load(path) as Texture2D
	icon.position = rect.position
	icon.size = rect.size
	add_child(icon)
	return icon


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _circle(parent: Control, pos: Vector2, size: Vector2, color: Color, border: Color, border_width: int) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(int(max(size.x, size.y) * 0.5))
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _rect(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _plabel(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return _plabel_on(self, text, pos, size, font_size, color, align)


func _plabel_on(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	# autowrap BEFORE size, otherwise the text's minimum width clamps the
	# label wider than the panel.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = pos
	label.size = size
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _on_language_changed() -> void:
	_build()
