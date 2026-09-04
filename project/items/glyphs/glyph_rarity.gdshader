shader_type canvas_item;

// Lights only the dark center rune; element fill stays as authored.
// All rarities pulse in unison via shared TIME + hardcoded PULSE_SPEED.
// Tint carries rarity color. Note: canvas_item fragment() cannot use return.

uniform float center_radius : hint_range(0.0, 0.6) = 0.28;
uniform float luma_cutoff : hint_range(0.0, 1.0) = 0.25;
uniform float glow : hint_range(0.0, 2.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

// Shared by every glyph material so blink phase never drifts.
const float PULSE_SPEED = 2.2;

void fragment() {
	vec2 pixel_uv = (floor(UV / TEXTURE_PIXEL_SIZE) + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	vec4 tex = texture(TEXTURE, pixel_uv);
	COLOR = tex * COLOR;

	if (glow > 0.001 && COLOR.a >= 0.01) {
		float dist = distance(pixel_uv, vec2(0.5));
		float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		if (dist <= center_radius && luma < luma_cutoff) {
			// Wave 0..1. Milder trough so blink isn't harsh; peak still hits tint.
			float wave = sin(TIME * PULSE_SPEED) * 0.5 + 0.5;
			float blink = mix(1.0 - pulse * 0.55, 1.0, wave);
			float dark = 1.0 - clamp(luma / max(luma_cutoff, 0.001), 0.0, 1.0);
			float mix_amount = clamp(glow * dark * blink, 0.0, 1.0);
			COLOR.rgb = mix(COLOR.rgb, tint.rgb, mix_amount);
		}
	}
}
