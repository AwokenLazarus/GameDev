shader_type canvas_item;
// Painterly cutout actor: even-width outline for readability and a moonlit rim on the
// side facing the light. The quad is grown in vertex() because the frames have no margin.

uniform vec4 outline_color : source_color = vec4(1.0, 0.86, 0.72, 0.9);
uniform float outline_px = 3.0;
uniform vec4 rim_color : source_color = vec4(0.72, 0.8, 1.0, 1.0);
uniform float rim_strength = 0.55;
// Direction to the light in texture space (y down).
uniform vec2 rim_dir = vec2(0.55, -0.83);

varying vec4 tint;
varying flat float flip;

void vertex() {
	tint = COLOR;
	vec2 corner = UV * 2.0 - 1.0;
	float pad = outline_px + 1.0;
	UV += corner * pad * TEXTURE_PIXEL_SIZE;
	VERTEX += corner * pad;
	// Facing is a negative x scale on the sprite; keep the rim on the light's side.
	flip = determinant(mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy)) < 0.0 ? -1.0 : 1.0;
}

// 1 inside the frame, 0 in the grown border (the frames have opaque edges, so clamping
// the lookup would smear them outward).
float inside(vec2 uv) {
	vec2 s = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return s.x * s.y;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 base = texture(TEXTURE, UV) * inside(UV);
	float around = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5235988;
		vec2 at = UV + vec2(cos(a), sin(a)) * px * outline_px;
		around += texture(TEXTURE, at).a * inside(at);
	}
	around = smoothstep(0.0, 0.45, around / 12.0);
	vec2 dir = normalize(rim_dir) * vec2(flip, 1.0);
	vec2 up = UV + dir * px * (outline_px * 2.0);
	float lit = 1.0 - texture(TEXTURE, up).a * inside(up);
	vec3 body = base.rgb * tint.rgb + rim_color.rgb * rim_strength * lit * base.a;
	float edge = clamp(around - base.a, 0.0, 1.0) * outline_color.a;
	COLOR = vec4(mix(outline_color.rgb, body, base.a), max(base.a, edge) * tint.a);
}
