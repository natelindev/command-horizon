shader_type particles;
render_mode disable_force;

uniform sampler2D emission_points : filter_nearest, repeat_disable;
uniform int point_count = 1;

float random_value(uint value) {
	value = ((value >> 16u) ^ value) * 73244475u;
	value = ((value >> 16u) ^ value) * 73244475u;
	return float((value >> 16u) ^ value) / 4294967295.0;
}

void start() {
	uint seed = NUMBER ^ RANDOM_SEED;
	vec3 upward = normalize(vec3(0.15, 1.0, 0.08));
	vec3 across = normalize(cross(upward, vec3(0.0, 0.0, 1.0)));
	vec3 along = cross(upward, across);
	float angle = random_value(seed) * TAU;
	float cosine = mix(1.0, cos(radians(18.0)), random_value(seed + 1u));
	float sine = sqrt(max(0.0, 1.0 - cosine * cosine));
	vec3 direction = upward * cosine + (across * cos(angle) + along * sin(angle)) * sine;
	VELOCITY = (EMISSION_TRANSFORM * vec4(direction * mix(0.5, 1.3, random_value(seed + 2u)), 0.0)).xyz;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = texelFetch(emission_points, ivec2(int(INDEX) % point_count, 0), 0).rgb;
	TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	CUSTOM = vec4(0.0);
	COLOR = vec4(1.0, 0.35, 0.035, 0.0);
}

void process() {
	CUSTOM.x += DELTA / LIFETIME;
	float age = clamp(CUSTOM.x, 0.0, 1.0);
	VELOCITY += vec3(0.05, 0.1, 0.02) * DELTA;
	vec4 glow = vec4(1.0, 0.6, 0.12, 0.9);
	COLOR = age < 0.15
		? mix(vec4(1.0, 0.35, 0.035, 0.0), glow, age / 0.15)
		: mix(glow, vec4(0.7, 0.1, 0.01, 0.0), (age - 0.15) / 0.85);
	ACTIVE = CUSTOM.x < 1.0;
}
