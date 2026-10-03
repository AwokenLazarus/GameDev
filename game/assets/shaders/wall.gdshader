shader_type canvas_item;
// Standing masonry. UV.x is world units along the wall, UV.y runs 0 at the foot to 1 at
// the top; the vertex colour carries the face's moon/shadow tint.
#include "res://assets/shaders/noise.gdshaderinc"

uniform float height = 120.0;
uniform vec4 stone : source_color = vec4(0.3, 0.27, 0.27, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.55, 0.2, 1.0);
// World units between lancet niches (0 = plain wall).
uniform float bay = 150.0;

void fragment() {
	float y = UV.y;
	vec2 p = vec2(UV.x, y * height);
	// Ashlar courses of uneven length; a taller plinth course at the foot.
	float course = p.y < 22.0 ? 22.0 : 13.0;
	float row = floor(p.y / course) + (p.y < 22.0 ? 40.0 : 0.0);
	float len = 30.0 + 16.0 * hash21(vec2(row, 3.0));
	vec2 b = vec2(p.x / len + hash21(vec2(row, 9.0)), p.y / course);
	vec2 cell = vec2(floor(b.x), row);
	vec2 f = fract(b);
	float rnd = hash21(cell);
	vec2 e = min(f, 1.0 - f) * vec2(len, course);
	float joint = smoothstep(0.3, 1.5, min(e.x, e.y) - fbm(p / 6.0) * 0.9);
	vec3 col = stone.rgb * (0.8 + 0.3 * rnd) * (0.78 + 0.4 * fbm(p / 23.0 + rnd * 11.0));
	col *= mix(0.42, 1.0, joint);
	// Rain streaks and soot.
	col *= 0.74 + 0.4 * fbm(vec2(p.x / 14.0, p.y / 90.0));
	// Coping, its shadow line, and grime climbing from the foot.
	col *= 1.0 + 0.55 * smoothstep(0.93, 0.96, y);
	col *= 1.0 - 0.45 * smoothstep(0.88, 0.92, y) * smoothstep(0.945, 0.92, y);
	col *= mix(0.5, 1.0, smoothstep(0.0, 0.34, y));
	float lum = 0.0;
	if (bay > 0.0 && height > 70.0) {
		float x = (fract(UV.x / bay + 0.5) - 0.5) * bay;
		// Pilaster between niches.
		float px = abs(abs(x) - bay * 0.5);
		col *= 1.0 + 0.16 * smoothstep(12.0, 10.0, px);
		col *= 1.0 - 0.3 * smoothstep(13.5, 12.0, px) * smoothstep(10.5, 12.0, px);
		// Lancet niche: a recess with a pointed head and a votive flame at its sill.
		float hy = p.y;
		float sill = height * 0.24;
		float top = height * 0.76;
		float spring = top - 24.0;
		float w = 10.0;
		float half_w = hy < spring ? w : w * sqrt(max(0.0, 1.0 - pow((hy - spring) / 24.0, 1.7)));
		float inside = smoothstep(half_w + 0.8, half_w - 0.8, abs(x)) * step(sill, hy) * step(hy, top);
		float jamb = smoothstep(half_w + 4.0, half_w + 1.0, abs(x)) * step(sill - 3.0, hy) * step(hy, top + 3.0);
		col *= 1.0 + 0.22 * jamb * (1.0 - inside);
		col = mix(col, stone.rgb * 0.08, inside * 0.94);
		vec2 q = vec2(x, hy - sill - 7.0);
		float flame = exp(-dot(q * vec2(1.0, 0.55), q * vec2(1.0, 0.55)) / 22.0);
		float spill = exp(-dot(q, q) / 900.0);
		lum = inside * flame * 2.6 + spill * 0.16;
		col += glow.rgb * stone.rgb * spill * inside * 3.0;
	}
	col *= COLOR.rgb;
	col += glow.rgb * lum;
	COLOR = vec4(col, COLOR.a);
}
