shader_type canvas_item;

// One clean target master drives every focus state. Defocus changes the
// optical point-spread function and brightness; it never swaps the object for
// unrelated art.
uniform float blur_radius_px : hint_range(0.0, 480.0) = 0.0;
uniform float defocus_amount : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.4) = 1.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;
uniform float source_uv_scale : hint_range(1.0, 3.0) = 1.0;

void fragment() {
	// Solid-body sprites render on an oversized transparent optical canvas.
	// Mapping the source into its centre gives the PSF room to expand beyond
	// the original PNG bounds instead of merely darkening the planet in place.
	vec2 uv = (UV - vec2(0.5)) * source_uv_scale + vec2(0.5);
	float wobble = turbulence * 0.0035;
	uv.x += sin(uv.y * 31.0 + TIME * 2.1) * wobble;
	uv.y += cos(uv.x * 27.0 + TIME * 1.7) * wobble * 0.7;

	// A solid body's defocused image is its sharp image convolved with a
	// circular point-spread function. The disk kernel removes high-frequency
	// bands and limb detail while naturally spreading the edge into the
	// transparent padding. The clear source only survives near true focus.
	// Twenty-four golden-angle taps are enough to read as a circular PSF while
	// remaining practical on the Web compatibility renderer.
	const int PSF_SAMPLE_COUNT = 24;
	const float GOLDEN_ANGLE = 2.39996323;
	vec2 radius_uv = TEXTURE_PIXEL_SIZE * blur_radius_px;
	vec3 weighted_rgb = vec3(0.0);
	float weighted_alpha = 0.0;
	float kernel_weight = 0.0;
	for (int i = 0; i < PSF_SAMPLE_COUNT; i++) {
		float sample_index = float(i) + 0.5;
		float sample_radius = sqrt(sample_index / float(PSF_SAMPLE_COUNT));
		float sample_angle = sample_index * GOLDEN_ANGLE;
		vec2 offset = vec2(cos(sample_angle), sin(sample_angle)) * sample_radius * radius_uv;
		float sample_weight = mix(1.0, 0.62, sample_radius);
		vec2 sample_uv = uv + offset;
		vec4 optical_ray = vec4(0.0);
		if (
			sample_uv.x >= 0.0 && sample_uv.x <= 1.0
			&& sample_uv.y >= 0.0 && sample_uv.y <= 1.0
		) {
			optical_ray = texture(TEXTURE, sample_uv);
		}
		weighted_rgb += optical_ray.rgb * optical_ray.a * sample_weight;
		weighted_alpha += optical_ray.a * sample_weight;
		kernel_weight += sample_weight;
	}
	vec4 source = vec4(0.0);
	if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
		source = texture(TEXTURE, uv);
	}
	float average_alpha = weighted_alpha / max(kernel_weight, 0.0001);
	vec3 blurred_rgb = weighted_rgb / max(weighted_alpha, 0.0001);
	// Preserve an opaque core while allowing a short, naturally fading PSF
	// edge. This keeps stars from shining through a planet without retaining
	// the source PNG's sharp silhouette.
	float blurred_alpha = smoothstep(0.015, 0.42, average_alpha);
	vec4 defocused = vec4(blurred_rgb, blurred_alpha);
	float convolution_mix = smoothstep(0.0, 0.55, defocus_amount);
	vec4 optical_sample = mix(source, defocused, convolution_mix);
	COLOR = vec4(optical_sample.rgb * brightness, optical_sample.a) * COLOR;
}
