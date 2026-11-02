shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://source/shaders/3d/combat_particle_surface.gdshaderinc"

void vertex() {
	life_seed = vec2(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.w);
	vec2 direction = (VIEW_MATRIX * vec4(MODEL_MATRIX[0].xyz, 0.0)).xy;
	direction = length(direction) > 0.001 ? normalize(direction) : vec2(1.0, 0.0);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	if (elongation > 1.0) {
		right = (INV_VIEW_MATRIX[0].xyz * direction.x + INV_VIEW_MATRIX[1].xyz * direction.y) * elongation;
		up = INV_VIEW_MATRIX[0].xyz * -direction.y + INV_VIEW_MATRIX[1].xyz * direction.x;
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(up * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
}
