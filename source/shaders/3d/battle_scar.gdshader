shader_type spatial;
render_mode depth_draw_never, cull_disabled;
uniform float seed = 0.0;
uniform float opacity = 1.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float grain = noise(p * 19.0 + seed);
	float broad = noise(p * 5.0 + seed);
	float radius = length(p) + (broad - 0.5) * 0.24;
	float bowl = 1.0 - smoothstep(0.12, 0.55, radius);
	float rim = smoothstep(0.28, 0.45, radius) * (1.0 - smoothstep(0.45, 0.67, radius));
	float angle = atan(p.y, p.x);
	float fractures = pow(max(0.0, sin(angle * 17.0 + broad * 7.0 + seed)), 24.0);
	float ejecta = fractures * smoothstep(0.25, 0.5, radius) * (1.0 - smoothstep(0.55, 0.95, radius));
	ALBEDO = mix(vec3(0.11, 0.095, 0.075), vec3(0.045, 0.038, 0.032), bowl);
	ALBEDO += rim * vec3(0.10, 0.082, 0.059) * grain;
	ROUGHNESS = 1.0;
	ALPHA = opacity * clamp((1.0 - smoothstep(0.4, 0.82, radius)) * (0.6 + grain * 0.22) + ejecta * 0.6, 0.0, 0.88);
	NORMAL_MAP = normalize(vec3(p * rim * 0.35, 1.0)) * 0.5 + 0.5;
}
