shader_type spatial;
#include "res://source/shaders/3d/rock_detail.gdshaderinc"
uniform vec4 stone_tint : source_color = vec4(0.43, 0.30, 0.19, 1.0);
varying vec3 world_point;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), t.x),
		mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), t.x), t.y),
		mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), t.x),
		mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), t.x), t.y), t.z);
}
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float weather = noise(world_point * vec3(0.8, 2.8, 0.8));
	float pits = noise(world_point * 5.5);
	float veins = sin(world_point.y * 23.0 + noise(world_point * 0.42) * 7.0);
	float layer = smoothstep(0.92, 0.99, veins);
	ALBEDO = stone_tint.rgb * (0.79 + weather * 0.30 + pits * 0.10 - layer * 0.09);
	ROUGHNESS = 0.98;
	ALBEDO = rock_albedo(ALBEDO, world_point, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	NORMAL = rock_relief(world_point, NORMAL, VIEW_MATRIX, INV_VIEW_MATRIX);
}
