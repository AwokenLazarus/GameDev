shader_type canvas_item;
render_mode unshaded;
// Full-bleed painted vista behind the stage: cover-fitted to any aspect (16:9 and 21:9
// crop, never stretch), softened and sunk into drifting ground mist so the floor reads.
#include "res://assets/shaders/noise.gdshaderinc"

uniform sampler2D vista : filter_linear, repeat_disable;
uniform float vista_aspect = 1.7778;
uniform vec4 haze : source_color = vec4(0.09, 0.07, 0.1, 1.0);
uniform float dim = 0.62;
uniform float blur = 1.6;
uniform float horizon = 0.46;

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = res.x / res.y;
	vec2 uv = UV - 0.5;
	if (aspect > vista_aspect) {
		uv.y *= vista_aspect / aspect;
	} else {
		uv.x *= aspect / vista_aspect;
	}
	// Favour the sky: the stage covers the lower half.
	uv = uv * 0.94 + vec2(0.5, 0.44);
	vec2 px = blur / res;
	vec3 col = texture(vista, uv).rgb * 0.28;
	col += texture(vista, uv + vec2(px.x, px.y)).rgb * 0.18;
	col += texture(vista, uv + vec2(-px.x, px.y)).rgb * 0.18;
	col += texture(vista, uv + vec2(px.x, -px.y)).rgb * 0.18;
	col += texture(vista, uv + vec2(-px.x, -px.y)).rgb * 0.18;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 0.82) * dim;
	// Mist pools below the horizon and drifts.
	float drift = fbm(vec2(UV.x * 3.0 + TIME * 0.012, UV.y * 5.0 - TIME * 0.006));
	float low = smoothstep(horizon - 0.12, 1.0, UV.y + (drift - 0.5) * 0.22);
	col = mix(col, haze.rgb, clamp(low * 1.08, 0.0, 0.96));
	col += haze.rgb * 0.5 * smoothstep(0.55, 0.9, drift) * (1.0 - low) * 0.35;
	COLOR = vec4(col, 1.0);
}
