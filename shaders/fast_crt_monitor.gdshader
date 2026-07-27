shader_type canvas_item;
render_mode unshaded, blend_mix;

// This material is a transparent glass overlay. It never samples the rendered
// screen, so labels, plots, buttons and terminal text remain at their exact
// 1:1 positions. The old mipmapped warp made the instrument illegible.
uniform float scanline_strength : hint_range(0.0, 0.12) = 0.022;
uniform float vignette_strength : hint_range(0.0, 0.45) = 0.20;
uniform float rolling_refresh : hint_range(0.0, 0.12) = 0.018;
uniform float flicker_strength : hint_range(0.0, 0.06) = 0.004;
uniform float instability : hint_range(0.0, 1.0) = 0.25;
uniform float lock_stability : hint_range(0.0, 1.0) = 0.0;

float hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float edge_axis = max(abs(uv.x * 2.0 - 1.0), abs(uv.y * 2.0 - 1.0));

	// Scanlines are a very low-alpha overlay, not a resampling pass.
	float scan = 0.5 + 0.5 * sin(uv.y / max(SCREEN_PIXEL_SIZE.y, 0.00001) * 3.14159265);
	float scan_alpha = scanline_strength * scan;

	// The cabinet-glass darkening lives only in the outer 10% of the frame.
	float edge = smoothstep(0.80, 1.0, edge_axis);
	float edge_alpha = edge * vignette_strength;

	// A restrained refresh line can respond to receiver instability without
	// moving any underlying pixel or changing any Control rectangle.
	float refresh_y = fract(TIME * (0.08 + instability * 0.05));
	float refresh = exp(-pow(uv.y - refresh_y, 2.0) * 900.0);
	float refresh_alpha = refresh * rolling_refresh * (0.35 + instability * 0.65);

	float tick = floor(TIME * 8.0);
	float flicker = flicker_strength * instability * hash(tick);
	float alpha = clamp(scan_alpha + edge_alpha + flicker, 0.0, 0.32);

	vec3 glass_tint = mix(vec3(0.015, 0.020, 0.022), vec3(0.010, 0.025, 0.022), lock_stability * 0.35);
	vec3 refresh_tint = vec3(0.42, 0.54, 0.52);
	COLOR = vec4(mix(glass_tint, refresh_tint, refresh_alpha), alpha + refresh_alpha * 0.08);
}
