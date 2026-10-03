shader_type canvas_item;
// Blood closing in from the screen edge as HP runs low.

uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 blood : source_color = vec4(0.45, 0.02, 0.05, 1.0);

void fragment() {
	vec2 c = UV - 0.5;
	float edge = smoothstep(0.28, 0.75, length(c * vec2(1.0, 1.15)));
	float pulse = 0.75 + 0.25 * sin(TIME * 5.0);
	COLOR = vec4(blood.rgb, edge * amount * pulse * 0.8);
}
