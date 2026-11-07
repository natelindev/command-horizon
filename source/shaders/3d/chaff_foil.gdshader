shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float phase = 0.0;
uniform bool steady = false;
varying float glint;
void vertex() {
	float angle = INSTANCE_CUSTOM.x * 6.283185 + (steady ? 0.0 : phase * 1.7);
	VERTEX.x += sin(angle) * 0.07;
	VERTEX.y += sin(angle * 0.7) * 0.16;
	glint = steady ? 0.65 : 0.55 + 0.45 * sin(angle);
}
void fragment() {
	ALBEDO = vec3(0.65, 0.77, 0.8);
	METALLIC = 0.85;
	ROUGHNESS = 0.22;
	EMISSION = vec3(0.4, 0.55, 0.6) * glint * 0.35;
	ALPHA = 0.7;
}
