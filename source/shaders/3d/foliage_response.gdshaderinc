// Four camera-local impulses shared by native meshes and rigid GPU batches,
// plus rolling wind gusts anchored at ground contact.
global uniform vec4 foliage_strengths;
global uniform vec4 foliage_impulse_0;
global uniform vec4 foliage_impulse_1;
global uniform vec4 foliage_impulse_2;
global uniform vec4 foliage_impulse_3;
global uniform float foliage_wind_time;

vec3 foliage_push(vec3 world, vec4 impulse, float strength) {
	vec2 offset = world.xz - impulse.xz;
	float distance = length(offset);
	float reach = max(impulse.w, .001);
	float weight = pow(max(0.0, 1.0 - distance / reach), 2.0);
	vec2 direction = offset / max(distance, .1);
	return vec3(direction.x, -.12, direction.y) * strength * weight * min(reach * .09, .6);
}

vec3 foliage_wind(vec3 world, float local_height) {
	float flex = smoothstep(0.08, 1.15, max(local_height, 0.0));
	float gust = sin(dot(world.xz, vec2(0.095, 0.062)) + foliage_wind_time * 1.35);
	float flutter = cos(dot(world.xz, vec2(-0.24, 0.19)) + foliage_wind_time * 2.65);
	float sway = (gust * 0.72 + flutter * 0.28) * flex;
	float amp = mix(0.032, 0.095, clamp(local_height * 0.22, 0.0, 1.0));
	return vec3(sway * amp, -abs(sway) * amp * 0.14, sway * amp * 0.58);
}
