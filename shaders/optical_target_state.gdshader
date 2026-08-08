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
	// Close to focus, retain a solid centre. Far from focus, do not threshold
	// the convolution back into a recognisable hard-edged planet disk.
	float blurred_alpha = smoothstep(0.010, 0.36, average_alpha);

	// At severe defocus the detector receives a broad, low-contrast circle of
	// confusion, not a larger copy of the source photograph. Flatten local
	// surface markings toward a small central colour average and replace the
	// source silhouette with a long Gaussian falloff. The centre stays opaque
	// enough to prevent background stars leaking through, while the limb no
	// longer reveals whether the sharp source was a disk, crescent, or rings.
	vec4 tone_0 = texture(TEXTURE, vec2(0.500, 0.500));
	vec4 tone_1 = texture(TEXTURE, vec2(0.475, 0.500));
	vec4 tone_2 = texture(TEXTURE, vec2(0.525, 0.500));
	vec4 tone_3 = texture(TEXTURE, vec2(0.500, 0.475));
	vec4 tone_4 = texture(TEXTURE, vec2(0.500, 0.525));
	float tone_alpha = tone_0.a + tone_1.a + tone_2.a + tone_3.a + tone_4.a;
	vec3 flat_rgb = (
		tone_0.rgb * tone_0.a
		+ tone_1.rgb * tone_1.a
		+ tone_2.rgb * tone_2.a
		+ tone_3.rgb * tone_3.a
		+ tone_4.rgb * tone_4.a
	) / max(tone_alpha, 0.0001);
	float severe_mix = smoothstep(0.48, 0.92, defocus_amount);
	vec2 haze_axis = (UV - vec2(0.5)) / vec2(0.34, 0.31);
	float severe_haze = exp(-dot(haze_axis, haze_axis) * 1.18);
	blurred_rgb = mix(blurred_rgb, flat_rgb, severe_mix * 0.90);
	blurred_alpha = mix(blurred_alpha, severe_haze, severe_mix * 0.94);
	vec4 defocused = vec4(blurred_rgb, blurred_alpha);
	float convolution_mix = smoothstep(0.0, 0.55, defocus_amount);
	vec4 optical_sample = mix(source, defocused, convolution_mix);
	// COLOR already contains a texture lookup at the control's unexpanded UV.
	// Multiplying by it sampled the source twice with two different UV maps:
	// the transformed Venus crescent was masked by a dark/transparent pixel
	// from the oversized canvas. Brightness is supplied explicitly, and solid
	// bodies keep node alpha at one, so write the optical sample directly.
	COLOR = vec4(optical_sample.rgb * brightness, optical_sample.a);
}
