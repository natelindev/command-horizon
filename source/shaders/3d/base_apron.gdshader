shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform vec2 span = vec2(12.0);
uniform vec2 pad_half = vec2(2.5);
uniform vec3 concrete : source_color = vec3(0.36, 0.38, 0.37);
uniform vec3 soil : source_color = vec3(0.38, 0.30, 0.22);
uniform int faction = 0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = (UV - 0.5) * span;
	float n = noise(p * 3.0);
	float edge = max(max(abs(p.x) - pad_half.x, abs(p.y) - pad_half.y),
		(abs(p.x) + abs(p.y) - pad_half.x - pad_half.y + 0.32) * 0.707);
	float pad = 1.0 - smoothstep(-0.03, 0.09, edge);
	float verge = (1.0 - smoothstep(0.0, 0.65 + n * 0.3, edge)) * 0.38;
	vec2 grid = abs(fract((p + 20.0) / (faction == 1 ? 1.15 : 1.8)) - 0.5);
	float joint = smoothstep(0.47, 0.49, max(grid.x, grid.y));
	float wear = noise(p * 0.9) * 0.18 + n * 0.08;
	vec3 surface = mix(concrete, soil, wear);
	surface *= 1.0 - joint * (faction == 1 ? 0.28 : 0.18);
	// Frontier uses offset repaired plates and gravel, with restrained variation.
	if (faction == 2) {
		float plate = hash(floor((p + 20.0) / 1.8));
		surface = mix(surface, soil, plate * 0.4);
		surface *= 0.85 + plate * 0.28;
	}
	// A worn service approach follows the structure's entrance, fading into terrain.
	float approach = smoothstep(pad_half.y - 0.2, pad_half.y + 0.2, p.y);
	approach *= 1.0 - smoothstep(pad_half.y + 0.3, span.y * 0.49, p.y);
	float tracks = (1.0 - smoothstep(0.12, 0.3, abs(abs(p.x) - pad_half.x * 0.42))) * approach;
	float yard = (1.0 - smoothstep(pad_half.x * 0.7, pad_half.x + 0.2, abs(p.x))) * approach;
	float alpha = max(pad * 0.94, max(verge, yard * 0.18 + tracks * 0.35));
	ALBEDO = mix(soil * (0.88 + n * 0.18), surface, pad);
	ROUGHNESS = 0.95;
	ALPHA = alpha;
}
