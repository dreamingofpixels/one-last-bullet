shader_type canvas_item;

// Lights only the dark center rune; element fill stays as authored.
// Common: glow=0. Rare: hot white rune. Unique: hotter + TIME pulse.
// Note: canvas_item fragment() cannot use return — nest conditions instead.

uniform float center_radius : hint_range(0.0, 0.6) = 0.38;
uniform float luma_cutoff : hint_range(0.0, 1.0) = 0.42;
uniform float pulse_speed : hint_range(0.1, 8.0) = 2.2;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, pixel_uv);
	COLOR = tex * COLOR;

	if (glow > 0.001 && COLOR.a >= 0.01) {
		float dist = distance(pixel_uv, vec2(0.5));
		float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		if (dist <= center_radius && luma < luma_cutoff) {
			float wave = sin(TIME * pulse_speed) * 0.5 + 0.5;
			float strength = glow * (1.0 + pulse * wave * 0.35);
			float dark = 1.0 - clamp(luma / max(luma_cutoff, 0.001), 0.0, 1.0);
			// Rare ~0.65 white, Unique ~0.9+ with pulse — hot rune, no rarity hue.
			float mix_amount = clamp(strength * dark * 0.65, 0.0, 1.0);
			COLOR.rgb = mix(COLOR.rgb, vec3(1.0), mix_amount);
		}
	}
}
