shader_type canvas_item;
render_mode unshaded;

// Texture must have 'Filter'-flag enabled!
// https://github.com/CptPotato/GodotThings/tree/master/SmoothPixelFiltering

// Automatic smoothing
// independent of geometry and perspective
vec4 texturePointSmooth(sampler2D smp, vec2 uv, vec2 pixel_size) {
	vec2 ddx = dFdx(uv);
	vec2 ddy = dFdy(uv);
	vec2 lxy = sqrt(ddx * ddx + ddy * ddy);

	vec2 uv_pixels = uv / pixel_size;

	vec2 uv_pixels_floor = round(uv_pixels) - vec2(0.5);
	vec2 uv_dxy_pixels = uv_pixels - uv_pixels_floor;

	uv_dxy_pixels = clamp((uv_dxy_pixels - vec2(0.5)) * pixel_size / lxy + vec2(0.5), 0.0, 1.0);

	uv = uv_pixels_floor * pixel_size;

	return textureGrad(smp, uv + uv_dxy_pixels * pixel_size, ddx, ddy);
}

void fragment() {
	COLOR = texturePointSmooth(TEXTURE, UV, TEXTURE_PIXEL_SIZE);
}
