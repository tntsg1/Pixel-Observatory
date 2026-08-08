shader_type canvas_item;
render_mode unshaded;

// Result-card preview blur for stars and extended deep-sky photographs.
// This shader deliberately preserves the source's own shape and alpha. The
// solid-body shader has separate severe-defocus logic that must never flatten
// a star, cluster, nebula, or galaxy into a planetary circle of confusion.
uniform float blur_radius_px : hint_range(0.0, 24.0) = 0.0;
uniform float defocus_amount : hint_range(0.0, 1.0) = 0.0;
uniform float brightness : hint_range(0.2, 1.2) = 1.0;

void fragment() {
	vec2 step_px = TEXTURE_PIXEL_SIZE * blur_radius_px * 0.5;
	vec4 source = texture(TEXTURE, UV);
	vec4 sum = vec4(0.0);
	sum += texture(TEXTURE, UV + step_px * vec2(-2.0, -2.0)) * 0.00390625;
	sum += texture(TEXTURE, UV + step_px * vec2(-1.0, -2.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2( 0.0, -2.0)) * 0.02343750;
	sum += texture(TEXTURE, UV + step_px * vec2( 1.0, -2.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2( 2.0, -2.0)) * 0.00390625;
	sum += texture(TEXTURE, UV + step_px * vec2(-2.0, -1.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2(-1.0, -1.0)) * 0.06250000;
	sum += texture(TEXTURE, UV + step_px * vec2( 0.0, -1.0)) * 0.09375000;
	sum += texture(TEXTURE, UV + step_px * vec2( 1.0, -1.0)) * 0.06250000;
	sum += texture(TEXTURE, UV + step_px * vec2( 2.0, -1.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2(-2.0,  0.0)) * 0.02343750;
	sum += texture(TEXTURE, UV + step_px * vec2(-1.0,  0.0)) * 0.09375000;
	sum += source                                                   * 0.14062500;
	sum += texture(TEXTURE, UV + step_px * vec2( 1.0,  0.0)) * 0.09375000;
	sum += texture(TEXTURE, UV + step_px * vec2( 2.0,  0.0)) * 0.02343750;
	sum += texture(TEXTURE, UV + step_px * vec2(-2.0,  1.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2(-1.0,  1.0)) * 0.06250000;
	sum += texture(TEXTURE, UV + step_px * vec2( 0.0,  1.0)) * 0.09375000;
	sum += texture(TEXTURE, UV + step_px * vec2( 1.0,  1.0)) * 0.06250000;
	sum += texture(TEXTURE, UV + step_px * vec2( 2.0,  1.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2(-2.0,  2.0)) * 0.00390625;
	sum += texture(TEXTURE, UV + step_px * vec2(-1.0,  2.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2( 0.0,  2.0)) * 0.02343750;
	sum += texture(TEXTURE, UV + step_px * vec2( 1.0,  2.0)) * 0.01562500;
	sum += texture(TEXTURE, UV + step_px * vec2( 2.0,  2.0)) * 0.00390625;

	float blend = smoothstep(0.02, 0.82, defocus_amount);
	vec4 optical = mix(source, sum, blend);
	COLOR = vec4(optical.rgb * brightness, optical.a) * COLOR;
}
