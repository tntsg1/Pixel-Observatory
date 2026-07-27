shader_type canvas_item;

// One clean target master drives every focus state. Defocus changes the
// optical point-spread function and brightness; it never swaps the object for
// unrelated art.
uniform float blur_radius_px : hint_range(0.0, 320.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.4) = 1.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float wobble = turbulence * 0.0035;
	uv.x += sin(uv.y * 31.0 + TIME * 2.1) * wobble;
	uv.y += cos(uv.x * 27.0 + TIME * 1.7) * wobble * 0.7;

	// Dense 5x5 Gaussian approximation. Solid bodies are often rendered from
	// a large transparent science master at a small screen scale, so sparse
	// samples looked like shifted sharp disks instead of true defocus.
	vec2 step_px = TEXTURE_PIXEL_SIZE * blur_radius_px * 0.5;
	vec4 sample_sum = vec4(0.0);
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-2.0, -2.0)) * 0.00390625;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-1.0, -2.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 0.0, -2.0)) * 0.02343750;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 1.0, -2.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 2.0, -2.0)) * 0.00390625;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-2.0, -1.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-1.0, -1.0)) * 0.06250000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 0.0, -1.0)) * 0.09375000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 1.0, -1.0)) * 0.06250000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 2.0, -1.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-2.0,  0.0)) * 0.02343750;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-1.0,  0.0)) * 0.09375000;
	sample_sum += texture(TEXTURE, uv) * 0.14062500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 1.0,  0.0)) * 0.09375000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 2.0,  0.0)) * 0.02343750;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-2.0,  1.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-1.0,  1.0)) * 0.06250000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 0.0,  1.0)) * 0.09375000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 1.0,  1.0)) * 0.06250000;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 2.0,  1.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-2.0,  2.0)) * 0.00390625;
	sample_sum += texture(TEXTURE, uv + step_px * vec2(-1.0,  2.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 0.0,  2.0)) * 0.02343750;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 1.0,  2.0)) * 0.01562500;
	sample_sum += texture(TEXTURE, uv + step_px * vec2( 2.0,  2.0)) * 0.00390625;
	COLOR = vec4(sample_sum.rgb * brightness, sample_sum.a) * COLOR;
}
