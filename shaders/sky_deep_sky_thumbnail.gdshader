shader_type canvas_item;

// Progressive low-light rendering for acquisition views. The same distinct
// source morphology is reduced to a point/smudge for the naked eye, a coarse
// pixel signature in the finder, and a restrained preview in the telescope.
// Full colour and resolved detail belong to the observation result scene.
uniform float exposure : hint_range(0.5, 3.0) = 1.45;
uniform float saturation : hint_range(0.0, 1.0) = 0.16;
uniform float black_point : hint_range(0.0, 0.2) = 0.018;
uniform float soft_edge : hint_range(0.01, 0.4) = 0.16;
uniform vec2 focus = vec2(0.5, 0.5);
uniform float zoom : hint_range(1.0, 4.0) = 1.0;
uniform float morphology_reveal : hint_range(0.0, 1.0) = 0.70;
uniform float pixel_grid : hint_range(4.0, 48.0) = 24.0;
uniform float value_steps : hint_range(2.0, 16.0) = 9.0;
uniform float halo_strength : hint_range(0.0, 1.0) = 0.20;

void fragment() {
	vec2 raster_uv = (floor(UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	vec2 sample_uv = (raster_uv - focus) / zoom + focus;
	float inside = step(0.0, sample_uv.x) * step(sample_uv.x, 1.0)
		* step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
	vec4 source = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
	float peak = max(source.r, max(source.g, source.b));
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float signal_alpha = smoothstep(black_point, black_point + soft_edge, peak);
	vec2 center_delta = UV - vec2(0.5);
	float radius = length(center_delta);
	float point_core = 1.0 - smoothstep(0.025, 0.115, radius);
	float point_halo = 1.0 - smoothstep(0.04, 0.34, radius);
	float unresolved_alpha = max(point_core, point_halo * halo_strength);
	float morphology_alpha = source.a * signal_alpha * inside;
	float final_alpha = mix(unresolved_alpha, morphology_alpha, morphology_reveal);

	vec3 neutral = vec3(luminance) * vec3(0.88, 0.94, 1.0);
	vec3 low_light = mix(neutral, source.rgb, saturation) * exposure;
	low_light = floor(clamp(low_light, 0.0, 1.0) * value_steps + 0.5) / value_steps;
	vec3 point_colour = vec3(0.72, 0.80, 0.86) * (0.55 + point_core * 0.45);
	vec3 final_colour = mix(point_colour, low_light, morphology_reveal);
	COLOR = vec4(final_colour, final_alpha) * COLOR;
}
