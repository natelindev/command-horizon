shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float progress = 0.0;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float ring = exp(-pow((r - mix(.06, .95, progress)) / .06, 2.0));
	ALBEDO = vec3(.7, .62, .46);
	ALPHA = ring * pow(1.0 - progress, 2.0) * .22;
}
