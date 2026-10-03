shader_type canvas_item;
// The world behind a choice: blurred through the backbuffer's mips, darkened, vignetted.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec4 tint = vec4(0.03, 0.02, 0.04, 1.0);

void fragment() {
	// HDR 2D renders in linear light: mix in display space, write linear.
	// Highlights are clamped so nothing blooms through the veil.
	vec3 col = pow(clamp(textureLod(screen, SCREEN_UV, 3.2 * amount).rgb, 0.0, 1.0), vec3(1.0 / 2.2));
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma) * vec3(0.9, 0.82, 0.86), 0.55 * amount);
	vec2 c = UV - 0.5;
	float edge = smoothstep(0.2, 0.8, length(c));
	col = mix(col, tint.rgb, amount * (0.62 + 0.3 * edge));
	COLOR = vec4(pow(col, vec3(2.2)), 1.0);
}
