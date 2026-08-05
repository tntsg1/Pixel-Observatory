shader_type canvas_item;

// Turns a full science image into a faint finder-view signature. Dark pixels
// become transparent so rectangular source frames disappear into the sky,
// while the target's real morphology remains recognizable at small sizes.
uniform float exposure : hint_range(0.5, 3.0) = 1.45;
uniform float saturation : hint_range(0.0, 1.0) = 0.42;
uniform float black_point : hint_range(0.0, 0.2) = 0.018;
uniform float soft_edge : hint_range(0.01, 0.4) = 0.16;
uniform vec2 focus = vec2(0.5, 0.5);
uniform float zoom : hint_range(1.0, 4.0) = 1.0;

void fragment() {
	vec2 sample_uv = (UV - focus) / zoom + focus;
	float inside = step(0.0, sample_uv.x) * step(sample_uv.x, 1.0)
		* step(0.0, sample_uv.y) * step(sample_uv.y, 1.0);
	vec4 source = texture(TEXTURE, clamp(sample_uv, vec2(0.0), vec2(1.0)));
	float peak = max(source.r, max(source.g, source.b));
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float signal_alpha = smoothstep(black_point, black_point + soft_edge, peak);
	vec3 neutral = vec3(luminance);
	vec3 low_light = mix(neutral, source.rgb, saturation) * exposure;
	COLOR = vec4(low_light, source.a * signal_alpha * inside) * COLOR;
}
