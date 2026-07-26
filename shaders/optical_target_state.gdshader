shader_type canvas_item;

// One clean target master drives every focus state. Defocus changes the
// optical point-spread function and brightness; it never swaps the object for
// unrelated art.
uniform float blur_radius_px : hint_range(0.0, 24.0) = 0.0;
uniform float brightness : hint_range(0.0, 1.4) = 1.0;
uniform float turbulence : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float wobble = turbulence * 0.0035;
	uv.x += sin(uv.y * 31.0 + TIME * 2.1) * wobble;
	uv.y += cos(uv.x * 27.0 + TIME * 1.7) * wobble * 0.7;

	vec2 px = TEXTURE_PIXEL_SIZE * blur_radius_px;
	vec2 half_px = px * 0.46;
	vec4 sample_sum = texture(TEXTURE, uv) * 0.16;
	sample_sum += texture(TEXTURE, uv + vec2(half_px.x, 0.0)) * 0.10;
	sample_sum += texture(TEXTURE, uv - vec2(half_px.x, 0.0)) * 0.10;
	sample_sum += texture(TEXTURE, uv + vec2(0.0, half_px.y)) * 0.10;
	sample_sum += texture(TEXTURE, uv - vec2(0.0, half_px.y)) * 0.10;
	sample_sum += texture(TEXTURE, uv + px * vec2(0.707, 0.707)) * 0.085;
	sample_sum += texture(TEXTURE, uv + px * vec2(-0.707, 0.707)) * 0.085;
	sample_sum += texture(TEXTURE, uv + px * vec2(0.707, -0.707)) * 0.085;
	sample_sum += texture(TEXTURE, uv - px * vec2(0.707, 0.707)) * 0.085;
	COLOR = vec4(sample_sum.rgb * brightness, sample_sum.a) * COLOR;
}
