// Four camera-local impulses shared by native meshes and rigid GPU batches.
global uniform vec4 foliage_strengths;
global uniform vec4 foliage_impulse_0;
global uniform vec4 foliage_impulse_1;
global uniform vec4 foliage_impulse_2;
global uniform vec4 foliage_impulse_3;

vec3 foliage_push(vec3 world, vec4 impulse, float strength) {
	vec2 offset = world.xz - impulse.xz;
	float distance = length(offset);
	float reach = max(impulse.w, .001);
	float weight = pow(max(0.0, 1.0 - distance / reach), 2.0);
	vec2 direction = offset / max(distance, .1);
	return vec3(direction.x, -.12, direction.y) * strength * weight * min(reach * .09, .6);
}
