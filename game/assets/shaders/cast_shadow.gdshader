shader_type canvas_item;
render_mode unshaded;
// Silhouette laid on the ground away from the moon; fades toward the head.

// Alpha is high because the stage blends in linear light, where dark overlays read weak.
uniform float strength = 0.8;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(0.02, 0.01, 0.03, a * strength * mix(0.35, 1.0, UV.y * UV.y));
}
