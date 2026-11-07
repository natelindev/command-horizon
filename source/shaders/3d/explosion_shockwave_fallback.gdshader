shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float progress = 0.0;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	float age = clamp(progress, 0.0, 1.0);
	float expansion = 1.0 - pow(1.0 - age, 2.2);
	float wave = exp(-pow((radius - mix(0.08, 0.94, expansion)) / mix(0.028, 0.075, age), 2.0));
	ALBEDO = vec3(0.72, 0.63, 0.48);
	ALPHA = wave * pow(1.0 - age, 1.7) * 0.24;
}
