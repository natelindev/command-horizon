shader_type spatial;
#include "res://source/shaders/3d/terrain_layers.gdshaderinc"

varying vec3 world_position;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float weathering(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(grain(cell), grain(cell + vec2(1, 0)), t.x),
		mix(grain(cell + vec2(0, 1)), grain(cell + vec2(1, 1)), t.x), t.y);
}

float strata(vec2 p) {
	return weathering(p) * 0.58 + weathering(p * 2.07 + vec2(19, 7)) * 0.28
		+ weathering(p * 4.13 + vec2(2, 31)) * 0.14;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	// Macro dune tone, medium wind-scoured patches and fine detail that fades with distance.
	float macro = strata(p * 0.05);
	float medium = strata(p * 0.36 + vec2(7, 3));
	float detail = 1.0 - smoothstep(0.25, 1.0, length(fwidth(p)) * 5.0);
	vec3 sand = mix(vec3(0.46, 0.345, 0.215), vec3(0.37, 0.27, 0.165), smoothstep(0.4, 0.7, macro));
	sand += (medium - 0.5) * vec3(0.06, 0.052, 0.038);
	float ripples = sin(p.x * 5.1 + p.y * 1.9 + medium * 7.0) * 0.5 + 0.5;
	sand += (ripples - 0.5) * 0.016 * detail * smoothstep(0.35, 0.6, macro);
	float pebbles = smoothstep(0.8, 0.93, weathering(p * 4.5 + vec2(31, 11))) * detail;
	sand = mix(sand, vec3(0.30, 0.245, 0.185), pebbles * 0.5);
	float hardpan = smoothstep(0.6, 0.75, strata(p * 0.12 + vec2(3, 41)));
	sand = mix(sand, vec3(0.43, 0.36, 0.27), hardpan * 0.35);
	// Hardpan and pebble beds take the rock scan; this ground has no roads.
	TerrainSurface ground = terrain_surface(p, sand, 0.0, max(hardpan, pebbles), 0.96);
	ALBEDO = ground.albedo;
	ROUGHNESS = ground.roughness;
	AO = ground.occlusion;
	NORMAL = terrain_normal(ground, NORMAL, VIEW_MATRIX, INV_VIEW_MATRIX);
}
