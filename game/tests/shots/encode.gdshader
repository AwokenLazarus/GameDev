shader_type canvas_item;
render_mode unshaded;
// Screenshot helper: the HDR 2D viewport is linear and only the window blit encodes it.
// Drawn over everything for the captured frame, this writes display-encoded values into
// the float buffer so the PNG matches the screen without 8-bit banding in the darks.

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;

void fragment() {
	vec3 c = clamp(texture(screen, SCREEN_UV).rgb, 0.0, 1.0);
	vec3 lo = c * 12.92;
	vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
	COLOR = vec4(mix(hi, lo, step(c, vec3(0.0031308))), 1.0);
}
