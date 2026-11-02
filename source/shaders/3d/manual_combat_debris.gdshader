shader_type spatial;
#include "res://source/shaders/3d/manual_particle_motion.gdshaderinc"
uniform float metalness = 0.45;
uniform bool soil = false;

mat3 rotation_axis(vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	float t = 1.0 - c;
	return mat3(vec3(t*axis.x*axis.x+c, t*axis.x*axis.y+s*axis.z, t*axis.x*axis.z-s*axis.y),
		vec3(t*axis.x*axis.y-s*axis.z, t*axis.y*axis.y+c, t*axis.y*axis.z+s*axis.x),
		vec3(t*axis.x*axis.z+s*axis.y, t*axis.y*axis.z-s*axis.x, t*axis.z*axis.z+c));
}

void vertex() {
	float seconds = max(0.0, particle_clock - MODEL_MATRIX[2].x);
	float age = clamp(seconds / particle_lifetime, 0.0, 1.0);
	float seed = INSTANCE_CUSTOM.y;
	vec3 point = particle_position(MODEL_MATRIX[3].xyz, MODEL_MATRIX[0].xyz, seconds, 0.0);
	mat3 spin = rotation_axis(normalize(vec3(0.3+seed, 0.7, 1.0-seed)), seed * 6.283 + seconds * 4.5);
	vec3 scale = mix(vec3(0.04, 0.025, 0.08), vec3(0.09, 0.045, 0.18), seed)
		* MODEL_MATRIX[1].x * (1.0 - smoothstep(0.65, 1.0, age));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(spin[0]*scale.x, 0.0), vec4(spin[1]*scale.y, 0.0),
		vec4(spin[2]*scale.z, 0.0), vec4(point, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * spin;
}

void fragment() {
	ALBEDO = vec3(0.404, 0.349, 0.290) * (soil ? COLOR.rgb : vec3(1.0));
	METALLIC = metalness;
	ROUGHNESS = 0.7;
}
