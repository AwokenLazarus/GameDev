shader_type canvas_item;
render_mode unshaded;
// The cut edge of the stage: strata dropping into the mist. UV.y is 0 at the lip, 1 below.
#include "res://assets/shaders/noise.gdshaderinc"

uniform vec4 rock : source_color = vec4(0.2, 0.17, 0.16, 1.0);
uniform vec4 mist : source_color = vec4(0.1, 0.09, 0.13, 1.0);

void fragment() {
	vec2 p = vec2(UV.x, UV.y * 120.0);
	float strata = fbm(vec2(p.x / 70.0, p.y / 9.0));
	float cut = smoothstep(0.35, 0.6, fbm(vec2(p.x / 16.0, p.y / 46.0)));
	vec3 col = rock.rgb * (0.5 + 0.7 * strata) * mix(0.6, 1.0, cut);
	col *= COLOR.rgb;
	col *= 1.0 + 0.5 * smoothstep(0.06, 0.0, UV.y);
	float fade = smoothstep(1.0, 0.15, UV.y);
	COLOR = vec4(mix(mist.rgb, col, fade), fade * fade * COLOR.a);
}
