shader_type canvas_item;

// Recolors bright center-rune pixels to a rarity base tint, then blinks
// toward a darker tint in unison (TIME + PULSE_SPEED).
// Note: canvas_item fragment() cannot use return.

uniform float center_radius : hint_range(0.0, 0.6) = 0.28;
uniform float luma_cutoff : hint_range(0.0, 1.0) = 0.82;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 tint_dark : source_color = vec4(0.7, 0.7, 0.7, 1.0);

const float PULSE_SPEED = 2.2;

void fragment() {
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, pixel_uv);
	COLOR = tex * COLOR;

	if (glow > 0.001 && COLOR.a >= 0.01) {
		float dist = distance(pixel_uv, vec2(0.5));
		float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		if (dist <= center_radius && luma > luma_cutoff) {
			float wave = sin(TIME * PULSE_SPEED) * 0.5 + 0.5;
			// Peak = base tint; trough = darker tint when pulse is on.
			float dark_mix = pulse * (1.0 - wave);
			vec3 pulsed = mix(tint.rgb, tint_dark.rgb, dark_mix);
			// Hard replace so the authored Color matches on-screen (no white bleed).
			COLOR.rgb = pulsed;
		}
	}
}
