shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform float progress = 0.0;
uniform vec3 hit_direction = vec3(0.0, 0.0, 1.0);
varying vec3 shell_position;

void vertex() {
	shell_position = VERTEX;
}

void fragment() {
	float age = clamp(progress, 0.0, 1.0);
	float distance_to_hit = length(normalize(shell_position) - hit_direction);
	float expansion = 1.0 - pow(1.0 - age, 2.4);
	float radius = mix(0.035, 1.35, expansion);
	float width = mix(0.055, 0.16, age);
	float ripple = exp(-pow((distance_to_hit - radius) / width, 2.0));
	float contact = exp(-distance_to_hit * distance_to_hit * 18.0)
		* (1.0 - smoothstep(0.0, 0.32, age));
	float fade = pow(1.0 - age, 1.6);
	vec3 tint = mix(vec3(0.19, 0.66, 0.88), vec3(0.72, 0.95, 1.0), contact);
	ALBEDO = tint;
	EMISSION = tint * (ripple * 0.75 + contact * 1.5) * fade;
	ALPHA = (ripple * 0.55 + contact * 0.32) * fade;
}
