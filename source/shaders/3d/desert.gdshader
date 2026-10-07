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
	float fine = grain(floor(p * 7.0));
	float broad = sin(p.x * 0.17 + sin(p.y * 0.24)) * 0.025;
	ALBEDO = vec3(0.42, 0.31, 0.19) + broad + fine * 0.035;
	ROUGHNESS = 0.95;
}
