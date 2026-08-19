shader_type canvas_item;

/// Tether time-slow overlay: vignette + desaturation + colour tint.
/// `intensity` is driven by the TimeSlowOverlay script (0 = off, 1 = full).
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.06, 0.04, 0.14, 1.0);
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.2;
uniform float vignette_inner : hint_range(0.0, 1.0) = 0.32;
uniform vec4 tint_color : source_color = vec4(0.55, 0.45, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.18;
uniform float desat_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	// UV centred at (0.5, 0.5).
	vec2 uv = UV - 0.5;
	float dist = length(uv * vec2(1.0, 1.0));

	// Smooth vignette mask: 0 at centre, 1 at corners.
	float vignette = smoothstep(vignette_inner, 0.72, dist);
	vignette = pow(vignette, vignette_strength);

	// Base source pixel (transparent fullscreen rect — nothing to blend with,
	// so we build the colour from scratch and write a final alpha).
	vec3 dark = vignette_color.rgb;
	vec3 tinged = mix(dark, tint_color.rgb, tint_strength);

	float alpha = vignette * intensity;
	COLOR = vec4(tinged, alpha);
}
