shader_type canvas_item;
render_mode unshaded;
// Screen-space finish over the stage (under the HUD): split-tone grade, vignette,
// a breath of chromatic fringe at the corners, and film grain.

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform vec4 shadow_tint = vec4(0.07, 0.05, 0.12, 1.0);
uniform vec4 light_tint = vec4(1.0, 0.92, 0.82, 1.0);
uniform float contrast = 1.12;
uniform float saturation = 0.92;
uniform float vignette = 0.62;
uniform float fringe = 1.6;
uniform float grain = 0.035;

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	vec2 off = c * r2 * fringe * SCREEN_PIXEL_SIZE * 6.0;
	vec3 col = vec3(
		texture(screen, uv + off).r, texture(screen, uv).g, texture(screen, uv - off).b
	);
	// HDR 2D renders in linear light: grade in display space, then hand linear HDR back.
	col = pow(max(col, vec3(0.0)), vec3(1.0 / 2.2));
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col = mix(col + shadow_tint.rgb * (1.0 - luma) * 0.5, col * light_tint.rgb, smoothstep(0.0, 0.7, luma));
	// Wide screens keep the same corner falloff: measure in the short axis.
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 q = c * vec2(min(res.x / res.y, 2.0) * 0.62, 1.0);
	col *= 1.0 - vignette * smoothstep(0.22, 0.95, dot(q, q) * 2.0);
	col += (rnd(uv * res + fract(TIME) * 61.0) - 0.5) * grain;
	COLOR = vec4(pow(max(col, vec3(0.0)), vec3(2.2)), 1.0);
}
