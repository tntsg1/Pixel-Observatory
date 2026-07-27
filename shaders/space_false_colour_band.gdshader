shader_type canvas_item;
render_mode unshaded, blend_add;

uniform int band_mode = 0;
uniform vec4 mapped_color : source_color = vec4(1.0);
uniform vec4 feature_weights = vec4(1.0);
uniform float reveal_progress : hint_range(0.0, 1.0) = 1.0;
uniform float signal_strength : hint_range(0.0, 1.0) = 1.0;
uniform bool direct_band_source = false;

float luminance(vec3 value) {
	return dot(value, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
	float center = luminance(source.rgb);
	float north = luminance(texture(TEXTURE, UV + vec2(0.0, -px.y)).rgb);
	float south = luminance(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb);
	float east = luminance(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb);
	float west = luminance(texture(TEXTURE, UV + vec2(-px.x, 0.0)).rgb);
	float local_mean = (center * 2.0 + north + south + east + west) / 6.0;
	float high_pass = max(center - local_mean, 0.0);
	float edge = abs(center - local_mean);

	float compact = smoothstep(0.58, 0.94, center) + high_pass * 4.2;
	float compact_rejection = 1.0 - smoothstep(0.56, 0.88, center);
	float embedded = smoothstep(0.11, 0.62, local_mean)
		* compact_rejection * (0.48 + edge * 1.6);
	float dust = smoothstep(
		0.045,
		0.29,
		edge * 1.35 + max(local_mean - center, 0.0) * 0.82
	) * compact_rejection;
	float diffuse = smoothstep(0.045, 0.58, local_mean) * compact_rejection;

	float intensity = 0.0;
	if (direct_band_source) {
		// Dedicated wavelength frames already contain the physical spatial
		// structure for this band. Convert that frame to intensity instead of
		// trying to infer stars/dust from one shared colour photograph.
		intensity = pow(clamp(center * 1.35 + high_pass * 1.15, 0.0, 1.0), 0.82);
	} else if (band_mode == 0) {
		intensity = compact * feature_weights.x + diffuse * feature_weights.w * 0.035;
	} else if (band_mode == 1) {
		intensity = embedded * feature_weights.y + compact * feature_weights.x * 0.08
			+ diffuse * feature_weights.w * 0.18;
	} else {
		intensity = dust * feature_weights.z + embedded * feature_weights.y * 0.055
			+ diffuse * feature_weights.w * 0.16;
	}

	float reveal = smoothstep(UV.y - 0.055, UV.y + 0.012, reveal_progress);
	intensity = clamp(intensity * signal_strength, 0.0, 1.0) * reveal;
	COLOR = vec4(mapped_color.rgb * intensity, intensity * mapped_color.a * source.a);
}
