shader_type canvas_item;

/// 9×9 dashed square outline; dashes march clockwise.
uniform float size_px : hint_range(3.0, 32.0) = 9.0;
uniform float dash_px : hint_range(1.0, 8.0) = 2.0;
uniform float gap_px : hint_range(1.0, 8.0) = 2.0;
uniform float speed_px : hint_range(0.0, 32.0) = 8.0;
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 p = UV * size_px;
	float edge = min(min(p.x, size_px - p.x), min(p.y, size_px - p.y));
	float on_border = step(edge, 0.999);

	// Clockwise perimeter from top-left outer corner (length = size * 4).
	float peri;
	float s = size_px;
	if (p.y < 1.0 && p.x < s) {
		peri = p.x;
	} else if (p.x >= s - 1.0) {
		peri = s + p.y;
	} else if (p.y >= s - 1.0) {
		peri = 2.0 * s + (s - p.x);
	} else {
		peri = 3.0 * s + (s - p.y);
	}

	float period = dash_px + gap_px;
	float phase = peri - TIME * speed_px;
	float in_dash = step(mod(phase, period), dash_px - 0.001);
	COLOR = vec4(line_color.rgb, line_color.a * on_border * in_dash);
}
