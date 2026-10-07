shader_type spatial;
varying vec3 world_position;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float speckle = grain(floor(p * 14.0));
	float stain = sin(p.x * 0.31 + sin(p.y * 0.19)) * 0.017;
	vec3 gravel = vec3(0.22, 0.26, 0.27) + stain + speckle * 0.028;
	vec2 joints = abs(fract(p / 6.0) - 0.5);
	float seam = smoothstep(0.488, 0.497, max(joints.x, joints.y));
	vec3 concrete = vec3(0.32, 0.365, 0.375) + speckle * 0.025 - seam * 0.06;
	float apron = (1.0 - smoothstep(43.0, 46.0, p.x)) * step(18.0, p.y) * step(p.y, 83.0);
	float quarry = (1.0 - smoothstep(7.0, 13.0, abs(p.x - 66.0))) * step(23.0, p.y) * step(p.y, 80.0);
	ALBEDO = mix(mix(gravel, concrete, apron), vec3(0.13, 0.16, 0.175) + speckle * 0.018, quarry);
	ROUGHNESS = 0.96;
}
