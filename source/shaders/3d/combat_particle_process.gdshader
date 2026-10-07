shader_type particles;
render_mode disable_force;
uniform vec3 gravity = vec3(0.0);
uniform float growth_start = 1.0;
uniform float growth_end = 0.2;
uniform float damping = 0.8;

void start() {
	// emit_particle supplies world position, velocity, tint and scale. Preserve them.
	CUSTOM = vec4(0.0, COLOR.a, length(TRANSFORM[0].xyz), 0.0);
}

void process() {
	CUSTOM.x += DELTA / LIFETIME;
	if (CUSTOM.x >= 1.0) {
		ACTIVE = false;
	}
	VELOCITY += gravity * DELTA;
	VELOCITY *= exp(-damping * DELTA);
	float size = CUSTOM.z * mix(growth_start, growth_end, CUSTOM.x);
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
	COLOR.a = CUSTOM.y * (1.0 - smoothstep(0.15, 1.0, CUSTOM.x));
}
