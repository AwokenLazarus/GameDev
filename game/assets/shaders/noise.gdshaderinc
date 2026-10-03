// Shared noise helpers. Fractal noise comes from a baked, seamless texture
// (assets/visuals/grain_noise.tres) so full-screen shaders stay cheap at 3440x1440.
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;

// Fractal noise in 0..1 whose largest features are about one unit of `p` across.
#define FBM(p) texture(grain, (p) * 0.1621).r

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n * 31.7));
}

// x: distance to the nearest cell border, y: cell id hash.
vec2 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash22(n + g);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash21(n + g + 3.3);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(d2 - d1, id);
}
