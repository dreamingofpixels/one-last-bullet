shader_type canvas_item;

// Per-pixel crumble: each opaque texel gets a staggered start, then falls
// downward with light horizontal drift and fades near the sprite "ground".

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 tex_size = vec2(16.0, 16.0);
uniform float fall_distance : hint_range(0.0, 2.0) = 1.15;
uniform float delay_spread : hint_range(0.0, 0.9) = 0.45;
uniform float horizontal_drift : hint_range(0.0, 0.5) = 0.12;
uniform float ground_fade : hint_range(0.0, 0.5) = 0.12;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return vec2(hash21(p), hash21(p + vec2(19.19, 37.37)));
}

void fragment() {
	vec2 pixel = floor(UV * tex_size);
	vec2 rnd = hash22(pixel);

	float delay = rnd.x * delay_spread;
	float denom = max(1.0 - delay_spread, 0.001);
	float t = clamp((progress - delay) / denom, 0.0, 1.0);
	float fall_t = t * t;

	float fall_uv = fall_t * fall_distance;
	float drift_uv = (rnd.y - 0.5) * 2.0 * horizontal_drift * fall_t;

	// Sample from where this pixel came from (above / opposite drift).
	vec2 source_uv = UV - vec2(drift_uv, fall_uv);

	if (source_uv.x < 0.0 || source_uv.x > 1.0 || source_uv.y < 0.0 || source_uv.y > 1.0) {
		discard;
	}

	// Snap sample to the source pixel center so colors stay crisp.
	vec2 source_pixel = floor(source_uv * tex_size);
	vec2 sample_uv = (source_pixel + vec2(0.5)) / tex_size;
	vec4 col = texture(TEXTURE, sample_uv);

	if (col.a < 0.01) {
		discard;
	}

	// Fade as pixels approach the bottom of the sprite ("ground").
	float ground_line = 1.0 - ground_fade;
	float ground_alpha = 1.0;
	if (UV.y > ground_line) {
		ground_alpha = 1.0 - smoothstep(ground_line, 1.0, UV.y);
	}

	// Soft fade-out near the end of the effect.
	float end_fade = 1.0 - smoothstep(0.75, 1.0, progress);

	col.a *= ground_alpha * end_fade;
	if (col.a < 0.01) {
		discard;
	}

	COLOR = col;
}
