shader_type spatial;
#include "res://source/shaders/3d/terrain_layers.gdshaderinc"

uniform bool exterior = false;
uniform int road_count = 0;
uniform vec4 roads[16];
uniform vec2 relays[3];
varying vec3 world_point;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(hash(cell), hash(cell + vec2(1, 0)), t.x),
		mix(hash(cell + vec2(0, 1)), hash(cell + vec2(1, 1)), t.x), t.y);
}
float weather(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.13 + vec2(19, 7)) * 0.28
		+ noise(p * 4.1 + vec2(3, 41)) * 0.12;
}
float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 v = b - a;
	return length(p - a - v * clamp(dot(p - a, v) / max(dot(v,v), 0.001), 0.0, 1.0));
}
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_point.xz;
	float macro = weather(p * 0.065);
	float medium = weather(p * 0.38);
	float fine = noise(p * 7.0);
	float exposed = smoothstep(0.53, 0.70, macro + medium * 0.13);
	vec3 snow = mix(vec3(0.49, 0.57, 0.61), vec3(0.66, 0.71, 0.73), medium);
	vec3 gravel = mix(vec3(0.205, 0.255, 0.28), vec3(0.30, 0.35, 0.37), fine);
	vec3 color = mix(snow, gravel, exposed * 0.83);
	float detail = 1.0 - smoothstep(0.3, 1.1, length(fwidth(p)) * 5.0);
	float drift = sin(p.x * 4.6 + p.y * 1.5 + medium * 6.0);
	color += ((fine - 0.5) * 0.014 + drift * 0.008) * detail;
	float path = 0.0;
	if (!exterior) {
		float lane = 1000.0;
		for (int index=0; index<16; index++) {
			if (index >= road_count) { break; }
			lane = min(lane, segment_distance(p, roads[index].xy, roads[index].zw));
		}
		float edge = lane + (medium - 0.5) * 1.3;
		float shoulder = 1.0 - smoothstep(3.5, 5.8, edge);
		float plowed = 1.0 - smoothstep(2.2, 3.9, edge);
		vec3 grit = vec3(0.20, 0.255, 0.285) + medium * 0.035;
		float ice = smoothstep(0.49, 0.67, medium) * 0.40;
		grit = mix(grit, vec3(0.34, 0.46, 0.52), ice);
		color = mix(color, gravel, shoulder * 0.48);
		color = mix(color, grit, plowed * 0.84);
		path = max(plowed, shoulder * 0.5);
		float tyre = 1.0 - smoothstep(0.08, 0.22, abs(lane - 1.15));
		color *= 1.0 - tyre * (0.06 + medium * 0.07);
		for (int index=0; index<3; index++) {
			vec2 relay = relays[index];
			vec2 q = abs(p - relay);
			float octagon = max(max(q.x,q.y), (q.x+q.y)*0.7071);
			float pad = 1.0 - smoothstep(4.0,4.12,octagon);
			vec3 concrete = mix(vec3(0.24,0.30,0.33), snow, smoothstep(0.45,0.72,medium) * 0.55);
			float joint = smoothstep(0.47,0.50,max(abs(fract(p.x/2.0)-0.5),abs(fract(p.y/2.0)-0.5)));
			concrete *= 1.0 - joint*0.10;
			float marking = (1.0 - smoothstep(0.07,0.13,abs(octagon-3.55)))
				* smoothstep(0.32,0.55,medium);
			concrete = mix(concrete,vec3(0.58,0.63,0.63),marking*0.62);
			vec2 hatch = abs((p - relay) - vec2(2.8,0));
			float lid = 1.0 - smoothstep(0.55,0.60,max(hatch.x,hatch.y));
			concrete = mix(concrete,gravel*0.75,lid*0.7);
			color = mix(color,concrete,pad);
			path = max(path, pad);
		}
	}
	// Exposed gravel takes the rock scan; plowed roads and pads the packed dirt.
	TerrainSurface ground = terrain_surface(p, color, path, exposed, 0.94);
	ALBEDO = ground.albedo;
	ROUGHNESS = ground.roughness;
	AO = ground.occlusion;
	NORMAL = terrain_normal(ground, NORMAL, VIEW_MATRIX, INV_VIEW_MATRIX);
}
