uniform float glow = 0.0;
uniform float rough_edge = 0.45;
uniform bool flame = false;
uniform bool exhaust = false;
uniform bool vapor = false;
uniform float elongation = 1.0;
varying vec2 life_seed;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 v = fract(sin(vec4(dot(i, vec2(127.1,311.7)), dot(i+vec2(1,0), vec2(127.1,311.7)), dot(i+vec2(0,1), vec2(127.1,311.7)), dot(i+vec2(1,1), vec2(127.1,311.7)))) * 43758.5453);
	return mix(mix(v.x,v.y,f.x), mix(v.z,v.w,f.x), f.y);
}

void fragment() {
	float angle = life_seed.y * 6.283 + life_seed.x * (life_seed.y - 0.5);
	vec2 p = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * (UV * 2.0 - 1.0);
	vec2 flow = p * 3.0 + vec2(life_seed.y * 71.0, -life_seed.x * 1.8);
	float cloud = noise(flow) * 0.57 + noise(flow * 2.1) * 0.28 + noise(flow * 4.3) * 0.15;
	float edge = length(p) + (cloud - 0.48) * rough_edge;
	float density = (1.0 - smoothstep(0.2, 1.0, edge)) * mix(1.0, cloud * 1.5, rough_edge * 0.65);
	vec3 tint = COLOR.rgb * mix(0.48, 1.18, cloud);
	if (vapor) {
		// Broad rolling lobes retain volume as the wispy outer edge dissolves.
		float body = exp(-dot(p, p) * 1.9);
		float lobes = noise(flow * 0.65 + vec2(life_seed.x * 0.45, 0.0));
		density *= mix(0.65, 1.15, lobes) * (0.65 + body * 0.35);
		float light = 0.72 + cloud * 0.35 + clamp(-p.y, -0.6, 0.6) * 0.18;
		tint = COLOR.rgb * light;
	}
	if (flame) {
		tint = mix(vec3(1.0, 0.75, 0.3), vec3(0.3, 0.065, 0.018), clamp(life_seed.x * 1.3 + (1.0 - cloud) * 0.4, 0.0, 1.0));
	}
	if (exhaust) {
		float cooling = smoothstep(0.0, 0.8, life_seed.x);
		vec3 hot = mix(vec3(2.4, 1.8, 0.95), vec3(1.2, 0.28, 0.035), cooling);
		tint = mix(hot, vec3(0.25, 0.24, 0.22), smoothstep(0.45, 1.0, life_seed.x));
	}
	ALBEDO = tint;
	EMISSION = tint * glow * density * ((flame || exhaust) ? pow(1.0 - life_seed.x, 2.0) : 1.0);
	ALPHA = COLOR.a * density;
}
