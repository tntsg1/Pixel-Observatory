shader_type canvas_item;

// Full-colour curved optical glass. This samples only the observation region
// behind the overlay; mission panels, labels and reticles are drawn above it.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec2 region_uv_size = vec2(0.615234375, 0.729166667);
uniform float curvature : hint_range(0.0, 0.15) = 0.035;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.14;
uniform float chroma_px : hint_range(0.0, 1.5) = 0.18;
uniform float glass_highlight : hint_range(0.0, 0.25) = 0.055;
uniform float circular_lens : hint_range(0.0, 1.0) = 0.0;
uniform float edge_bloom : hint_range(0.0, 0.5) = 0.08;
uniform float scanline_strength : hint_range(0.0, 0.12) = 0.018;
uniform float lens_rim_strength : hint_range(0.0, 0.35) = 0.0;
uniform float lens_caustic_strength : hint_range(0.0, 0.25) = 0.0;

vec2 curved_uv(vec2 uv) {
	vec2 p = uv * 2.0 - 1.0;
	float r2 = dot(p, p);
	p *= 1.0 + curvature * r2;
	return p * 0.5 + 0.5;
}

void fragment() {
	vec2 warped = curved_uv(UV);
	vec2 sample_uv = SCREEN_UV + (warped - UV) * region_uv_size;
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);

	if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
		COLOR = vec4(0.002, 0.004, 0.010, 1.0);
	} else {
		float edge = mix(max(abs(p.x), abs(p.y)), radius, circular_lens);
		float edge_amount = smoothstep(0.52, 1.0, edge);
		vec2 chroma_shift = vec2(SCREEN_PIXEL_SIZE.x * chroma_px * edge_amount, 0.0);

		// Preserve the scene's actual colour. The tiny channel separation reads
		// as imperfect optics at the rim, not as a CRT or monochrome filter.
		float red = texture(screen_tex, sample_uv + chroma_shift).r;
		float green = texture(screen_tex, sample_uv).g;
		float blue = texture(screen_tex, sample_uv - chroma_shift).b;
		vec3 colour = vec3(red, green, blue);
		vec3 neighbour = (
			texture(screen_tex, sample_uv + vec2(SCREEN_PIXEL_SIZE.x * 2.0, 0.0)).rgb +
			texture(screen_tex, sample_uv - vec2(SCREEN_PIXEL_SIZE.x * 2.0, 0.0)).rgb +
			texture(screen_tex, sample_uv + vec2(0.0, SCREEN_PIXEL_SIZE.y * 2.0)).rgb +
			texture(screen_tex, sample_uv - vec2(0.0, SCREEN_PIXEL_SIZE.y * 2.0)).rgb
		) * 0.25;
		// Full-colour glass bloom: borrow the pleasing tube depth from the
		// space console without converting the optical view to monochrome.
		colour += max(neighbour - vec3(0.46), vec3(0.0)) * edge_bloom;
		float scan = 0.5 + 0.5 * sin(UV.y / max(SCREEN_PIXEL_SIZE.y, 0.0001) * 3.14159265);
		colour *= 1.0 - scanline_strength * scan;
		colour *= 1.0 - vignette_strength * edge_amount;

		// A restrained cold reflection near the upper-left edge gives the glass
		// volume without covering stars or turning the view into a bright blob.
		float reflection = exp(-18.0 * dot(p - vec2(-0.34, -0.38), p - vec2(-0.34, -0.38)));
		reflection *= smoothstep(0.15, 0.72, edge);
		colour += vec3(0.28, 0.52, 0.72) * reflection * glass_highlight;

		// A visible but transparent full-colour fisheye rim. It gives a dark
		// sky optical volume without drawing an opaque barrel over the target.
		float angle = atan(p.y, p.x);
		float rim = exp(-pow((radius - 0.955) / 0.020, 2.0));
		float inner_rim = exp(-pow((radius - 0.875) / 0.040, 2.0));
		float rim_sweep = 0.72 + 0.28 * sin(angle * 3.0 - TIME * 0.55);
		vec3 rim_colour = mix(vec3(0.12, 0.58, 0.78), vec3(0.90, 0.57, 0.20), 0.5 + 0.5 * sin(angle - 0.8));
		colour += rim_colour * (rim + inner_rim * 0.24) * rim_sweep * lens_rim_strength * circular_lens;

		float caustic_a = exp(-24.0 * dot(p - vec2(-0.28 + 0.04 * sin(TIME * 0.31), -0.42), p - vec2(-0.28 + 0.04 * sin(TIME * 0.31), -0.42)));
		float caustic_b = exp(-34.0 * dot(p - vec2(0.46, 0.22 + 0.03 * cos(TIME * 0.27)), p - vec2(0.46, 0.22 + 0.03 * cos(TIME * 0.27))));
		colour += vec3(0.16, 0.42, 0.62) * (caustic_a + caustic_b * 0.55) * lens_caustic_strength * circular_lens;

		COLOR = vec4(colour, 1.0);
	}
}
