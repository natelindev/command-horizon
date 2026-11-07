shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://source/shaders/3d/combat_particle_surface.gdshaderinc"
#include "res://source/shaders/3d/manual_particle_motion.gdshaderinc"
#include "res://source/shaders/3d/particle_envelope.gdshaderinc"

uniform float growth_start = 1.0;
uniform float growth_end = 0.2;
uniform bool directional = false;

void vertex() {
	float seconds = max(0.0, particle_clock - MODEL_MATRIX[2].x);
	float age = clamp(seconds / particle_lifetime, 0.0, 1.0);
	life_seed = vec2(age, INSTANCE_CUSTOM.y);
	vec3 velocity = MODEL_MATRIX[0].xyz;
	float size = MODEL_MATRIX[1].x * mix(growth_start, growth_end, particle_growth(age));
	if (seconds >= particle_lifetime) { size = 0.0; }
	vec3 point = particle_position(MODEL_MATRIX[3].xyz, velocity, seconds, MODEL_MATRIX[1].y);
	float decay = exp(-damping * seconds);
	vec3 current_velocity = velocity * decay
		+ gravity * (damping > 0.0001 ? (1.0 - decay) / damping : seconds);
	vec2 direction = (VIEW_MATRIX * vec4(current_velocity, 0.0)).xy;
	direction = directional && length(direction) > 0.001 ? normalize(direction) : vec2(1.0, 0.0);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	if (elongation > 1.0) {
		right = (INV_VIEW_MATRIX[0].xyz * direction.x + INV_VIEW_MATRIX[1].xyz * direction.y) * elongation;
		up = INV_VIEW_MATRIX[0].xyz * -direction.y + INV_VIEW_MATRIX[1].xyz * direction.x;
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * size, 0.0), vec4(up * size, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * size, 0.0), vec4(point, 1.0));
	COLOR.a *= particle_opacity(age);
}
