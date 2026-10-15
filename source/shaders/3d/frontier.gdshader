shader_type spatial;

uniform bool exterior = false;
uniform int road_count = 0;
uniform vec4 roads[16];
// Enlarged layouts move landmarks away from the origin without resizing them.
uniform float layout_scale = 1.0;
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

float road(vec2 p, vec2 a, vec2 b) {
	vec2 v = b - a;
	return length(p - a - v * clamp(dot(p - a, v) / max(dot(v, v), 0.001), 0.0, 1.0));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float macro = strata(p * 0.067);
	float medium = strata(p * 0.38);
	float fine = weathering(p * 6.0);
	float ripples = sin(p.x * 5.5 + p.y * 2.2 + medium * 7.0) * 0.5 + 0.5;
	float iron = smoothstep(0.44, 0.67, macro);
	vec3 sand = mix(vec3(0.47, 0.365, 0.24), vec3(0.37, 0.255, 0.155), iron);
	sand += (medium - 0.5) * vec3(0.065, 0.058, 0.042);
	sand += (fine - 0.5) * 0.017;
	// Fine wind ripples fade at a distance instead of becoming a noisy checkerboard.
	float ripple_detail = 1.0 - smoothstep(0.25, 1.0, length(fwidth(p)) * 5.0);
	sand += (ripples - 0.5) * 0.014 * ripple_detail;
	vec3 color = sand;
	float lane = 1000.0;
	if (!exterior) {
		for (int index = 0; index < 16; index++) {
			if (index >= road_count) { break; }
			lane = min(lane, road(p, roads[index].xy, roads[index].zw));
		}
		float road_edge = lane + (medium - 0.5) * 1.4;
		float shoulder = 1.0 - smoothstep(3.0, 5.2, road_edge);
		float travelled = 1.0 - smoothstep(1.8, 3.4, road_edge);
		vec3 gravel = mix(vec3(0.36, 0.30, 0.225), vec3(0.45, 0.375, 0.275), fine);
		color = mix(color, gravel, shoulder * 0.72);
		color = mix(color, vec3(0.245, 0.226, 0.188) + medium * 0.045, travelled * 0.66);
		float tracks = 1.0 - smoothstep(0.10, 0.24, abs(lane - 1.02));
		color *= 1.0 - tracks * (0.04 + medium * 0.06);
		// The freight apron is worn, continuous terrain, with broken paint and sand incursions.
		vec2 q = p - vec2(64, 48) * layout_scale;
		float patch = weathering(p * 0.45);
		float apron = 1.0 - smoothstep(7.5, 8.4, max(abs(q.x), abs(q.y)) + patch * 0.4);
		vec2 joints = abs(fract((q + 8.0) / 4.0) - 0.5);
		float seam = smoothstep(0.485, 0.498, max(joints.x, joints.y));
		vec3 concrete = mix(vec3(0.27, 0.255, 0.215), vec3(0.37, 0.34, 0.27), medium);
		concrete = mix(concrete, sand, patch * 0.35 + seam * 0.22);
		float stripe = 1.0 - smoothstep(0.07, 0.14, abs(abs(q.x) - 6.3));
		stripe *= step(abs(q.y), 6.4) * step(1.0, mod(q.y + 6.4, 3.2));
		concrete = mix(concrete, vec3(0.66, 0.52, 0.27), stripe * smoothstep(0.22, 0.6, patch) * 0.68);
		float crack = 1.0 - smoothstep(0.02, 0.06, abs(q.y - sin(q.x * 1.3) * 0.22 - q.x * 0.4));
		concrete *= 1.0 - crack * 0.20;
		color = mix(color, concrete, apron);
	}
	ALBEDO = color;
	ROUGHNESS = 0.97;
}
