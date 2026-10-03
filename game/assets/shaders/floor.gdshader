shader_type canvas_item;
// Stage floor, shaded in world units so the canvas projection turns the square paving
// into iso diamonds. Ruined flagstones (whole stones present or lost, never cut) lie in
// cracked hardpan under drifts of dust; the rim gets a kerb and the far walls shade it.
#include "res://assets/shaders/noise.gdshaderinc"

uniform vec2 half_size = vec2(480.0, 320.0);
uniform float tile = 72.0;
// 0 = bare ground, 1 = fully paved.
uniform float paving : hint_range(0.0, 1.0) = 0.7;
uniform vec4 stone_a : source_color = vec4(0.36, 0.31, 0.28, 1.0);
uniform vec4 stone_b : source_color = vec4(0.25, 0.22, 0.22, 1.0);
uniform vec4 earth_a : source_color = vec4(0.34, 0.26, 0.18, 1.0);
uniform vec4 earth_b : source_color = vec4(0.2, 0.15, 0.12, 1.0);
uniform vec4 stain : source_color = vec4(0.3, 0.03, 0.05, 1.0);
uniform float stain_amount : hint_range(0.0, 1.0) = 0.25;
// 1 = the far (negative) edges carry walls that shade the floor at their foot.
uniform float walled = 1.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world;
	float fine = FBM(p / 14.0);
	float mottle = FBM(p / 64.0 + 5.3);
	float drift = FBM(p / 300.0 + 3.1);

	// Hardpan: wide cracks, hairlines between them, scattered pebbles.
	vec2 warp = vec2(FBM(p / 130.0 + 0.7), FBM(p / 130.0 + 19.3)) - 0.5;
	vec2 big = voronoi(p / 68.0 + warp * 0.9);
	float crack = smoothstep(0.0, 0.05, big.x);
	float hairline = smoothstep(0.0, 0.012, abs(FBM(p / 46.0 + 11.9) - 0.5));
	vec3 earth = mix(earth_b.rgb, earth_a.rgb, clamp(mottle * 0.9 + big.y * 0.3 + fine * 0.25, 0.0, 1.0));
	earth *= mix(0.3, 1.0, crack) * mix(0.72, 1.0, hairline);
	vec2 pc = p / 15.0;
	vec2 pid = floor(pc);
	float pebble = step(0.9, hash21(pid)) * smoothstep(0.24, 0.1, length(fract(pc) - 0.3 - 0.4 * hash22(pid)));
	earth = mix(earth, earth_a.rgb * 1.5, pebble * 0.7);
	float earth_h = crack * 0.34 + hairline * 0.05 + pebble * 0.2 + fine * 0.06;

	// Flagstones: 2x2 blocks split at random into one, two or four stones.
	vec2 g = p / (tile * 2.0);
	vec2 gid = floor(g);
	vec2 f = fract(g);
	float k = hash21(gid);
	vec2 span = vec2(2.0);
	vec2 sub = vec2(0.0);
	if (k > 0.3) {
		if (k < 0.55 || k > 0.8) {
			sub.x = floor(f.x * 2.0);
			f.x = fract(f.x * 2.0);
			span.x = 1.0;
		}
		if (k > 0.55) {
			sub.y = floor(f.y * 2.0);
			f.y = fract(f.y * 2.0);
			span.y = 1.0;
		}
	}
	vec2 sid = gid * 2.0 + sub;
	float rnd = hash21(sid + 0.37);
	vec2 centre = (gid + (sub + 0.5) * span * 0.5) * tile * 2.0;
	// A stone is laid or lost as a whole, by the paving noise at its centre.
	float keep = step(FBM(centre / 380.0 + 7.0) + (rnd - 0.5) * 0.3, 0.2 + paving * 0.62);
	vec2 e = min(f, 1.0 - f) * span * tile;
	float worn = (FBM(p / 17.0 + rnd * 30.0) - 0.5) * 7.0;
	float edge = min(e.x, e.y) + worn;
	float body = smoothstep(1.6, 4.2, edge);
	float bevel = smoothstep(4.2, 11.0, edge);
	vec3 stone = mix(stone_b.rgb, stone_a.rgb, clamp(rnd * 0.75 + mottle * 0.4, 0.0, 1.0));
	stone *= 0.74 + 0.5 * fine;
	stone *= mix(0.72, 1.0, bevel);
	// Hairline fracture across some stones.
	stone *= mix(1.0, mix(0.7, 1.0, hairline), step(0.7, rnd));
	float stone_h = body * (0.62 + 0.3 * bevel + 0.08 * rnd);
	float laid = keep * body;

	vec3 albedo = mix(earth * mix(1.0, 0.55, keep), stone, laid);
	float h = mix(earth_h, stone_h, laid);
	// Dust settles over everything in drifts; old blood soaks in.
	float dust = smoothstep(0.52, 0.78, drift + fine * 0.12) * (1.0 - 0.45 * laid);
	albedo = mix(albedo, earth_a.rgb * (0.92 + 0.3 * fine), dust * 0.62);
	float blot = smoothstep(0.6, 0.76, FBM(p / 170.0 + 31.0) + fine * 0.08) * stain_amount;
	albedo = mix(albedo, stain.rgb * (0.55 + 0.6 * fine), blot * 0.85);

	// Relief from screen derivatives, taken back to world space for the 2D lights.
	mat2 jac = mat2(dFdx(world), dFdy(world));
	vec2 grad = inverse(transpose(jac)) * vec2(dFdx(h), dFdy(h));
	vec3 n = normalize(vec3(-grad * 2.2, 1.0));
	NORMAL = normalize(vec3((n.x - n.y) * 0.7071, (n.x + n.y) * 0.4243, n.z));
	albedo *= 0.74 + 0.5 * clamp(dot(n, normalize(vec3(0.5, 0.62, 0.6))), 0.0, 1.0);

	// Kerb at the rim; the far walls shade their foot.
	vec2 d2 = half_size - abs(world);
	float d = min(d2.x, d2.y);
	float kerb = smoothstep(15.0, 12.0, d);
	albedo = mix(albedo, stone_b.rgb * (0.7 + 0.5 * fine), kerb * 0.9);
	albedo *= 1.0 - 0.5 * smoothstep(17.0, 14.5, d) * smoothstep(12.0, 14.5, d);
	float back = min(world.x + half_size.x, world.y + half_size.y);
	albedo *= mix(1.0, mix(0.5, 1.0, smoothstep(0.0, 110.0, back)), walled);
	COLOR = vec4(albedo, 1.0);
}
