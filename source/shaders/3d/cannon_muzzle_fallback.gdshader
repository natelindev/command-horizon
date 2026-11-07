shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

#include "res://source/shaders/3d/muzzle_envelope.gdshaderinc"

void fragment() {
	vec3 envelope = muzzle_envelope(UV * 2.0 - 1.0);
	ALBEDO = vec3(.7, .62, .46);
	ALPHA = (envelope.x * .22 + envelope.y * .08) * envelope.z;
}
